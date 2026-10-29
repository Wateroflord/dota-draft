import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class OdException implements Exception {
  final String message;
  OdException(this.message);
  @override
  String toString() => message;
}

class PlayerProfile {
  final int accountId;
  final String name;
  final String avatar;
  final int? rankTier;
  const PlayerProfile(this.accountId, this.name, this.avatar, this.rankTier);
}

class RecentMatch {
  final int matchId;
  final int heroId;
  final bool radiant;
  final bool win;
  final int kills, deaths, assists;
  final int duration;
  final int startTime;
  const RecentMatch(this.matchId, this.heroId, this.radiant, this.win, this.kills, this.deaths, this.assists,
      this.duration, this.startTime);
}

class MatchInfo {
  final int matchId;
  final bool radiantWin;
  final List<int> radiant;
  final List<int> dire;
  final int duration;
  const MatchInfo(this.matchId, this.radiantWin, this.radiant, this.dire, this.duration);
}

/// Подробная строка матча игрока (для личной статистики и сравнения со средними).
class PlayerMatch {
  final int matchId, heroId, startTime, duration;
  final bool win;
  final int kills, deaths, assists, gpm, xpm, lastHits, heroDamage, towerDamage;
  final int laneRole; // 1 лёгкая, 2 мид, 3 сложная, 4 лес; 0 — нет данных
  final int partySize;
  const PlayerMatch(this.matchId, this.heroId, this.startTime, this.duration, this.win, this.kills, this.deaths,
      this.assists, this.gpm, this.xpm, this.lastHits, this.heroDamage, this.towerDamage, this.laneRole, this.partySize);

  double get minutes => duration <= 0 ? 1 : duration / 60;
  double get lh10 => lastHits / minutes * 10;
  double get hdm => heroDamage / minutes;
}

class Peer {
  final int accountId;
  final String name, avatar;
  final int withGames, withWins, againstGames, againstWins;
  const Peer(this.accountId, this.name, this.avatar, this.withGames, this.withWins, this.againstGames, this.againstWins);
}

/// Данные игрока с OpenDota (бесплатно, без ключа). Профиль Dota 2 должен открывать данные матчей.
class OpenDota {
  static const _base = 'https://api.opendota.com/api';
  static const _steam64 = 76561197960265728;

  /// Из ссылки или числа достаёт account_id (Friend ID). null — не получилось.
  static int? parseAccountId(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'(?:profiles|players|matches/player)/(\d+)').firstMatch(t);
    final digits = m?.group(1) ?? (RegExp(r'^\d+$').hasMatch(t) ? t : null);
    if (digits == null) return null;
    final v = int.tryParse(digits);
    if (v == null || v <= 0) return null;
    return v >= _steam64 ? v - _steam64 : v;
  }

  static Future<dynamic> _get(String path) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw OdException('OpenDota не ответил. Попробуй ещё раз.');
    } catch (_) {
      throw OdException('Нет соединения с интернетом.');
    }
    if (res.statusCode == 429) throw OdException('Слишком много запросов к OpenDota. Подожди минуту.');
    if (res.statusCode == 404) throw OdException('Не найдено.');
    if (res.statusCode != 200) throw OdException('Ошибка OpenDota (${res.statusCode}).');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static Future<PlayerProfile> profile(int id) async {
    final j = await _get('/players/$id');
    final p = j is Map ? j['profile'] : null;
    if (p is! Map) {
      throw OdException('Профиль не найден или скрыт. В Dota 2: Настройки → Общение → «Открыть общий доступ к данным матчей».');
    }
    return PlayerProfile(
      id,
      p['personaname']?.toString() ?? 'Игрок $id',
      p['avatarmedium']?.toString() ?? '',
      j['rank_tier'] is num ? (j['rank_tier'] as num).toInt() : null,
    );
  }

  /// hero_id -> [игр, побед]
  static Future<Map<int, List<int>>> heroes(int id) async {
    final j = await _get('/players/$id/heroes');
    final out = <int, List<int>>{};
    if (j is List) {
      for (final r in j.whereType<Map>()) {
        final hid = _i(r['hero_id']);
        final g = _i(r['games']);
        if (hid > 0 && g > 0) out[hid] = [g, _i(r['win'])];
      }
    }
    return out;
  }

  static Future<List<RecentMatch>> recent(int id) async {
    final j = await _get('/players/$id/recentMatches');
    final out = <RecentMatch>[];
    if (j is List) {
      for (final r in j.whereType<Map>()) {
        final slot = _i(r['player_slot']);
        final radiant = slot < 128;
        final rw = r['radiant_win'] == true;
        out.add(RecentMatch(_i(r['match_id']), _i(r['hero_id']), radiant, radiant == rw, _i(r['kills']),
            _i(r['deaths']), _i(r['assists']), _i(r['duration']), _i(r['start_time'])));
      }
    }
    return out;
  }

  /// Последние матчи с подробными цифрами. [limit] до 500.
  static Future<List<PlayerMatch>> matches(int id, {int limit = 200, int? heroId}) async {
    const fields = [
      'hero_id', 'start_time', 'duration', 'kills', 'deaths', 'assists', 'gold_per_min', 'xp_per_min',
      'last_hits', 'hero_damage', 'tower_damage', 'lane_role', 'party_size', 'radiant_win', 'player_slot',
    ];
    final q = [
      'limit=$limit',
      if (heroId != null) 'hero_id=$heroId',
      for (final f in fields) 'project=$f',
    ].join('&');
    final j = await _get('/players/$id/matches?$q');
    final out = <PlayerMatch>[];
    if (j is List) {
      for (final r in j.whereType<Map>()) {
        final radiant = _i(r['player_slot']) < 128;
        out.add(PlayerMatch(
          _i(r['match_id']),
          _i(r['hero_id']),
          _i(r['start_time']),
          _i(r['duration']),
          radiant == (r['radiant_win'] == true),
          _i(r['kills']),
          _i(r['deaths']),
          _i(r['assists']),
          _i(r['gold_per_min']),
          _i(r['xp_per_min']),
          _i(r['last_hits']),
          _i(r['hero_damage']),
          _i(r['tower_damage']),
          _i(r['lane_role']),
          _i(r['party_size']),
        ));
      }
    }
    return out;
  }

  /// С кем игрок чаще всего играет.
  static Future<List<Peer>> peers(int id) async {
    final j = await _get('/players/$id/peers?limit=100');
    final out = <Peer>[];
    if (j is List) {
      for (final r in j.whereType<Map>()) {
        out.add(Peer(_i(r['account_id']), r['personaname']?.toString() ?? 'Игрок', r['avatar']?.toString() ?? '',
            _i(r['with_games']), _i(r['with_win']), _i(r['against_games']), _i(r['against_win'])));
      }
    }
    return out;
  }

  /// Где игрок ставит варды: (обсы, сентри) в виде {x: {y: count}}.
  static Future<(Map<String, Map<String, int>>, Map<String, Map<String, int>>)> wardmap(int id) async {
    final j = await _get('/players/$id/wardmap');
    Map<String, Map<String, int>> conv(dynamic m) {
      final out = <String, Map<String, int>>{};
      if (m is Map) {
        m.forEach((x, ys) {
          if (ys is Map) out['$x'] = {for (final e in ys.entries) '${e.key}': _i(e.value)};
        });
      }
      return out;
    }

    if (j is! Map) return (<String, Map<String, int>>{}, <String, Map<String, int>>{});
    return (conv(j['obs']), conv(j['sen']));
  }

  static Future<MatchInfo> match(int matchId) async {
    final j = await _get('/matches/$matchId');
    if (j is! Map || j['players'] is! List) throw OdException('Матч не найден.');
    final r = <int>[], d = <int>[];
    for (final p in (j['players'] as List).whereType<Map>()) {
      final hid = _i(p['hero_id']);
      final isRad = p['isRadiant'] is bool ? p['isRadiant'] as bool : _i(p['player_slot']) < 128;
      (isRad ? r : d).add(hid);
    }
    return MatchInfo(matchId, j['radiant_win'] == true, r, d, _i(j['duration']));
  }
}

/// Название ранга по rank_tier (например, 54 → Легенда 4).
String rankName(int? tier) {
  if (tier == null || tier <= 0) return 'ранг скрыт';
  const names = ['', 'Рекрут', 'Страж', 'Рыцарь', 'Герой', 'Легенда', 'Властелин', 'Божество', 'Титан'];
  final t = tier ~/ 10, s = tier % 10;
  if (t < 1 || t > 8) return 'ранг скрыт';
  return t == 8 || s == 0 ? names[t] : '${names[t]} $s';
}
