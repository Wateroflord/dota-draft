import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'i18n.dart';

/// Последнее состояние матча, присланное Dota 2 через Game State Integration.
class GsiState {
  final int? clock; // игровое время, сек (может быть отрицательным до 0:00)
  final String gameState;
  final bool daytime;
  final String matchId;
  final int heroId;
  final String heroName;
  final int level;
  final bool alive;
  final int respawn;
  final int buybackCost, buybackCd;
  final int gold, gpm, xpm;
  final int kills, deaths, assists, lastHits, denies;
  final String team; // radiant / dire
  final List<String> items; // ключи предметов (без item_), включая рюкзак и тайник
  final String winTeam;
  final int? x, y; // позиция героя в мировых координатах (примерно −8300…8300)
  final List<GsiAbility> abilities;
  final int talentsTaken;
  final bool hasTp;
  final int wardCd; // через сколько секунд в лавке снова появятся варды (0 — есть)
  final int wardsHeld;
  final int netWorth;
  final DateTime received;
  const GsiState({
    this.x,
    this.y,
    this.abilities = const [],
    this.talentsTaken = 0,
    this.hasTp = true,
    this.wardCd = 0,
    this.wardsHeld = 0,
    this.netWorth = 0,
    this.clock,
    this.gameState = '',
    this.daytime = true,
    this.matchId = '',
    this.heroId = 0,
    this.heroName = '',
    this.level = 0,
    this.alive = true,
    this.respawn = 0,
    this.buybackCost = 0,
    this.buybackCd = 0,
    this.gold = 0,
    this.gpm = 0,
    this.xpm = 0,
    this.kills = 0,
    this.deaths = 0,
    this.assists = 0,
    this.lastHits = 0,
    this.denies = 0,
    this.team = '',
    this.items = const [],
    this.winTeam = '',
    required this.received,
  });

  bool get inGame => gameState.contains('GAME_IN_PROGRESS') || gameState.contains('PRE_GAME');
  bool get inDraft => gameState.contains('HERO_SELECTION') || gameState.contains('STRATEGY_TIME');
  bool get postGame => gameState.contains('POST_GAME');

  /// Позиция на схеме карты (0–100, Свет внизу слева). null — нет данных.
  (double, double)? get mapPos =>
      x == null || y == null ? null : (((x! + 8300) / 166).clamp(0.0, 100.0), (100 - (y! + 8300) / 166).clamp(0.0, 100.0));

  /// Сколько очков умений вложено (без талантов).
  int get skillPoints => abilities.where((a) => !a.name.startsWith('special_bonus')).fold(0, (s, a) => s + a.level);

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static GsiState parse(Map j) {
    final map = j['map'] is Map ? j['map'] as Map : const {};
    final player = j['player'] is Map ? j['player'] as Map : const {};
    final hero = j['hero'] is Map ? j['hero'] as Map : const {};
    final items = <String>[];
    var hasTp = false;
    var wards = 0;
    if (j['items'] is Map) {
      (j['items'] as Map).forEach((slot, v) {
        if (v is Map) {
          final n = '${v['name'] ?? ''}';
          if (n.isNotEmpty && n != 'empty') {
            final k = n.replaceFirst('item_', '');
            items.add(k);
            if (k == 'tpscroll' || k.startsWith('travel_boots')) hasTp = true;
            if (k == 'ward_observer' || k == 'ward_dispenser') wards += _i(v['charges']) == 0 ? 1 : _i(v['charges']);
          }
        }
      });
    }
    final abilities = <GsiAbility>[];
    if (j['abilities'] is Map) {
      (j['abilities'] as Map).forEach((k, v) {
        if (v is Map) {
          abilities.add(GsiAbility('${v['name'] ?? ''}', _i(v['level']), v['ultimate'] == true, _i(v['cooldown'])));
        }
      });
    }
    var talents = 0;
    for (var i = 1; i <= 8; i++) {
      if (hero['talent_$i'] == true) talents++;
    }
    return GsiState(
      clock: map['clock_time'] is num ? (map['clock_time'] as num).toInt() : null,
      gameState: '${map['game_state'] ?? ''}',
      daytime: map['daytime'] != false,
      matchId: '${map['matchid'] ?? ''}',
      heroId: _i(hero['id']),
      heroName: '${hero['name'] ?? ''}'.replaceFirst('npc_dota_hero_', ''),
      level: _i(hero['level']),
      alive: hero['alive'] != false,
      respawn: _i(hero['respawn_seconds']),
      buybackCost: _i(hero['buyback_cost']),
      buybackCd: _i(hero['buyback_cooldown']),
      gold: _i(player['gold']),
      gpm: _i(player['gpm']),
      xpm: _i(player['xpm']),
      kills: _i(player['kills']),
      deaths: _i(player['deaths']),
      assists: _i(player['assists']),
      lastHits: _i(player['last_hits']),
      denies: _i(player['denies']),
      team: '${player['team_name'] ?? ''}',
      items: items,
      winTeam: '${map['win_team'] ?? ''}',
      x: hero['xpos'] is num ? (hero['xpos'] as num).toInt() : null,
      y: hero['ypos'] is num ? (hero['ypos'] as num).toInt() : null,
      abilities: abilities,
      talentsTaken: talents,
      hasTp: hasTp || j['items'] is! Map,
      wardCd: _i(map['ward_purchase_cooldown']),
      wardsHeld: wards,
      netWorth: _i(player['net_worth']),
      received: DateTime.now(),
    );
  }
}

class GsiAbility {
  final String name;
  final int level;
  final bool ultimate;
  final int cooldown;
  const GsiAbility(this.name, this.level, this.ultimate, this.cooldown);
}

/// Приёмник данных от Dota 2 (Game State Integration). Игра шлёт POST-запросы на http://<адрес>:<порт>/.
class GsiService extends ChangeNotifier {
  HttpServer? _server;
  int port = 3000;
  GsiState? last;
  String? error;
  int gamesFinished = 0; // за эту сессию приложения
  DateTime? sessionStart;
  final List<VoidCallback> _onGameEnd = [];
  Timer? _staleTimer;

  bool get running => _server != null;
  bool get live => last != null && DateTime.now().difference(last!.received).inSeconds < 40;

  void onGameEnd(VoidCallback cb) => _onGameEnd.add(cb);

  Future<void> start({int? onPort}) async {
    if (onPort != null) port = onPort;
    if (_server != null) return;
    try {
      // На Windows слушаем только этот ПК (без запроса брандмауэра), на телефоне — всю локальную сеть.
      _server = await HttpServer.bind(Platform.isWindows ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4, port, shared: true);
      error = null;
      _server!.listen(_handle, onError: (_) {});
      _staleTimer ??= Timer.periodic(const Duration(seconds: 10), (_) => notifyListeners());
    } catch (e) {
      error = '$e';
      _server = null;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    notifyListeners();
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      if (req.method == 'POST') {
        final body = await utf8.decoder.bind(req).join();
        final j = jsonDecode(body);
        if (j is Map) {
          final prev = last;
          final st = GsiState.parse(j);
          // Сохраняем поля, которые игра присылает не в каждом сообщении.
          last = st;
          sessionStart ??= DateTime.now();
          if (prev != null && !prev.postGame && st.postGame) {
            gamesFinished++;
            for (final cb in _onGameEnd) {
              cb();
            }
          }
          notifyListeners();
        }
      }
      req.response
        ..statusCode = 200
        ..write('ok');
    } catch (_) {
      req.response.statusCode = 400;
    }
    await req.response.close();
  }

  /// IPv4-адреса устройства в локальной сети (для настройки на ПК).
  static Future<List<String>> addresses() async {
    try {
      final list = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final i in list)
          for (final a in i.addresses)
            if (!a.isLoopback) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Текст файла настройки для Dota 2.
  String cfgText(String host) => '''"Dota Draft"
{
    "uri"        "http://$host:$port/"
    "timeout"    "5.0"
    "buffer"     "0.1"
    "throttle"   "0.5"
    "heartbeat"  "30.0"
    "data"
    {
        "provider"   "1"
        "map"        "1"
        "player"     "1"
        "hero"       "1"
        "abilities"  "1"
        "items"      "1"
        "draft"      "1"
    }
}
''';

  static const cfgFileName = 'gamestate_integration_dotadraft.cfg';

  /// Windows: найти папку Dota 2 через реестр Steam и записать файл настройки. Возвращает путь или бросает ошибку.
  Future<String> installCfgOnWindows() async {
    if (!Platform.isWindows) throw Exception(L('Только для Windows', 'Windows only'));
    final r = await Process.run('reg', ['query', r'HKCU\Software\Valve\Steam', '/v', 'SteamPath']);
    final m = RegExp(r'SteamPath\s+REG_SZ\s+(.+)').firstMatch('${r.stdout}');
    final libs = <String>[];
    if (m != null) libs.add(m.group(1)!.trim().replaceAll('/', r'\'));
    libs.addAll([r'C:\Program Files (x86)\Steam', r'C:\Program Files\Steam', r'D:\Steam', r'D:\SteamLibrary', r'E:\SteamLibrary']);
    // Дополнительные библиотеки Steam.
    for (final base in [...libs]) {
      final vdf = File('$base\\steamapps\\libraryfolders.vdf');
      if (await vdf.exists()) {
        for (final mm in RegExp(r'"path"\s+"([^"]+)"').allMatches(await vdf.readAsString())) {
          libs.add(mm.group(1)!.replaceAll(r'\\', r'\'));
        }
      }
    }
    for (final lib in libs.toSet()) {
      final cfg = Directory('$lib\\steamapps\\common\\dota 2 beta\\game\\dota\\cfg');
      if (await cfg.exists()) {
        final dir = Directory('${cfg.path}\\gamestate_integration');
        await dir.create(recursive: true);
        final f = File('${dir.path}\\$cfgFileName');
        await f.writeAsString(cfgText('127.0.0.1'));
        return f.path;
      }
    }
    throw Exception(L('Папка Dota 2 не найдена', 'Dota 2 folder not found'));
  }
}

/// Один приёмник на всё приложение.
final gsi = GsiService();
