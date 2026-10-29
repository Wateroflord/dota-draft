import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'bench.dart';
import 'data.dart';
import 'engine.dart';
import 'opendota.dart';

/// Сохранённый драфт для истории и проверки точности.
class SavedDraft {
  final String id;
  final int ts; // ms
  final List<int> allies;
  final List<int> enemies;
  final int group;
  final double chance;
  final bool? win; // null — результат не отмечен
  const SavedDraft(this.id, this.ts, this.allies, this.enemies, this.group, this.chance, this.win);

  SavedDraft withResult(bool? w) => SavedDraft(id, ts, allies, enemies, group, chance, w);

  Map<String, dynamic> toJson() =>
      {'id': id, 'ts': ts, 'a': allies, 'e': enemies, 'g': group, 'c': chance, 'w': win};

  static SavedDraft fromJson(Map j) => SavedDraft(
        j['id']?.toString() ?? '',
        (j['ts'] as num?)?.toInt() ?? 0,
        ((j['a'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList(),
        ((j['e'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList(),
        (j['g'] as num?)?.toInt() ?? 0,
        (j['c'] as num?)?.toDouble() ?? 0.5,
        j['w'] is bool ? j['w'] as bool : null,
      );
}

/// Состояние приложения: данные, драфт, настройки. Драфт сохраняется между запусками.
class AppState extends ChangeNotifier {
  StatsData? data;
  bool loading = true;
  bool updating = false;
  String? error;

  final List<int?> allies = List.filled(5, null);
  final List<int?> enemies = List.filled(5, null);
  final Set<int> bans = {};
  int group = 0; // ранг
  int? stageOverride; // null — автоматически по числу союзников
  bool roleFilter = true;

  // Мои герои
  final Set<int> pool = {};
  int comfortMode = 1; // 0 — не учитывать, 1 — приоритет, 2 — только мои
  int? accountId;
  String playerName = '';
  String playerAvatar = '';
  int? rankTier;
  final Map<int, List<int>> played = {};
  bool playerLoading = false;
  String? playerError;

  // История драфтов
  final List<SavedDraft> history = [];

  // Средние показатели игроков по рангам + мои подробные матчи (загружаются по запросу)
  BenchData bench = BenchData.empty;
  List<PlayerMatch>? myMatches;
  bool myMatchesLoading = false;
  String? myMatchesError;

  /// Моя группа рангов для сравнения (1–3), по рангу из профиля; если ранг скрыт — выбранная в драфте.
  int get myRankGroup => rankGroupOf(rankTier) ?? (group >= 1 && group <= 3 ? group : 2);

  Future<void> loadMyMatches({bool force = false}) async {
    if (accountId == null || myMatchesLoading) return;
    if (myMatches != null && !force) return;
    myMatchesLoading = true;
    myMatchesError = null;
    notifyListeners();
    try {
      myMatches = await OpenDota.matches(accountId!, limit: 300);
      if (myMatches!.isEmpty) myMatchesError = 'Матчи не найдены — проверь, открыт ли доступ к данным матчей.';
    } on OdException catch (e) {
      myMatchesError = e.message;
    } finally {
      myMatchesLoading = false;
      notifyListeners();
    }
  }

  Comfort get comfort => Comfort(pool: pool, played: played, mode: comfortMode);

  Engine get engine => Engine(data!, group, comfort);

  List<DHero> heroesOf(List<int?> ids) => [
        for (final id in ids)
          if (id != null && data!.byId[id] != null) data!.byId[id]!,
      ];

  List<DHero> get allyHeroes => heroesOf(allies);
  List<DHero> get enemyHeroes => heroesOf(enemies);

  Set<int> get unavailable => {...bans, ...allies.whereType<int>(), ...enemies.whereType<int>()};

  /// 1 — первые пики, 2 — середина драфта, 3 — последний пик.
  int get autoStage {
    final n = allies.whereType<int>().length;
    if (n == 0) return 1;
    if (n >= 4) return 3;
    return 2;
  }

  int get stage => stageOverride ?? autoStage;

  // ---------- загрузка ----------

  Future<void> init() async {
    await _loadPrefs();
    try {
      data = await DataRepo.loadLocal();
    } catch (e) {
      error = 'Не удалось загрузить данные: $e';
    }
    bench = await BenchRepo.loadLocal();
    loading = false;
    notifyListeners();
    refresh();
  }

  Future<bool> refresh({bool force = false}) async {
    if (updating) return false;
    updating = true;
    notifyListeners();
    final fresh = await DataRepo.fetch(currentUpdated: force ? null : data?.updated, force: force);
    if (fresh != null) data = fresh;
    final b = await BenchRepo.fetch(force ? '' : bench.updated);
    if (b != null) bench = b;
    updating = false;
    notifyListeners();
    return fresh != null;
  }

  // ---------- драфт ----------

  void setSlot(bool ally, int slot, int? heroId) {
    if (heroId != null) _removeEverywhere(heroId);
    (ally ? allies : enemies)[slot] = heroId;
    _changed();
  }

  /// Добавить в первую свободную ячейку. false — команда уже полная.
  bool add(bool ally, int heroId) {
    final list = ally ? allies : enemies;
    if (list.contains(heroId)) return true;
    final i = list.indexOf(null);
    if (i < 0) return false;
    _removeEverywhere(heroId);
    list[i] = heroId;
    _changed();
    return true;
  }

  void toggleBan(int heroId) {
    if (!bans.remove(heroId)) {
      _removeEverywhere(heroId);
      bans.add(heroId);
    }
    _changed();
  }

  void _removeEverywhere(int id) {
    for (var i = 0; i < 5; i++) {
      if (allies[i] == id) allies[i] = null;
      if (enemies[i] == id) enemies[i] = null;
    }
    bans.remove(id);
  }

  void applyTeam(List<DHero> team) {
    final ids = team.map((h) => h.id).toList();
    for (final id in ids) {
      if (!allies.contains(id)) add(true, id);
    }
  }

  void clear() {
    for (var i = 0; i < 5; i++) {
      allies[i] = null;
      enemies[i] = null;
    }
    bans.clear();
    stageOverride = null;
    _changed();
  }

  void swapSides() {
    for (var i = 0; i < 5; i++) {
      final t = allies[i];
      allies[i] = enemies[i];
      enemies[i] = t;
    }
    _changed();
  }

  void setGroup(int g) {
    group = g;
    _changed();
  }

  void setStage(int? s) {
    stageOverride = s;
    _changed();
  }

  // ---------- мои герои ----------

  bool inPool(int id) => pool.contains(id);

  void togglePool(int id) {
    if (!pool.remove(id)) pool.add(id);
    _changed();
  }

  void setComfortMode(int m) {
    comfortMode = m;
    _changed();
  }

  /// Самые игранные герои из профиля (сортировка по числу игр).
  List<MapEntry<int, List<int>>> get playedSorted =>
      played.entries.toList()..sort((a, b) => b.value[0].compareTo(a.value[0]));

  void addTopToPool(int n) {
    for (final e in playedSorted.take(n)) {
      pool.add(e.key);
    }
    _changed();
  }

  /// Загрузить профиль и статистику героев. Возвращает текст ошибки или null.
  Future<String?> loadPlayer(String input) async {
    final id = OpenDota.parseAccountId(input);
    if (id == null) {
      return 'Нужен числовой ID: Friend ID из Dota 2 или ссылка вида steamcommunity.com/profiles/7656…';
    }
    playerLoading = true;
    playerError = null;
    notifyListeners();
    try {
      final p = await OpenDota.profile(id);
      final h = await OpenDota.heroes(id);
      if (accountId != id) myMatches = null;
      accountId = id;
      playerName = p.name;
      playerAvatar = p.avatar;
      rankTier = p.rankTier;
      played
        ..clear()
        ..addAll(h);
      if (h.isEmpty) {
        playerError = 'Матчи не найдены. Включи в Dota 2: Настройки → Общение → «Открыть общий доступ к данным матчей».';
      }
    } on OdException catch (e) {
      playerError = e.message;
    } finally {
      playerLoading = false;
      _changed();
    }
    return playerError;
  }

  void forgetPlayer() {
    accountId = null;
    playerName = '';
    playerAvatar = '';
    rankTier = null;
    played.clear();
    myMatches = null;
    _changed();
  }

  // ---------- история драфтов ----------

  void saveDraft() {
    if (data == null) return;
    final a = allies.whereType<int>().toList(), e = enemies.whereType<int>().toList();
    if (a.isEmpty && e.isEmpty) return;
    history.insert(
        0,
        SavedDraft('${DateTime.now().microsecondsSinceEpoch}', DateTime.now().millisecondsSinceEpoch, a, e, group,
            engine.winChance(allyHeroes, enemyHeroes), null));
    _changed();
  }

  void setResult(String id, bool? win) {
    final i = history.indexWhere((d) => d.id == id);
    if (i < 0) return;
    history[i] = history[i].withResult(win);
    _changed();
  }

  void deleteDraft(String id) {
    history.removeWhere((d) => d.id == id);
    _changed();
  }

  void loadDraft(SavedDraft d) {
    for (var i = 0; i < 5; i++) {
      allies[i] = i < d.allies.length ? d.allies[i] : null;
      enemies[i] = i < d.enemies.length ? d.enemies[i] : null;
    }
    group = d.group.clamp(0, rankGroups.length - 1);
    _changed();
  }

  // ---------- поделиться драфтом ----------

  /// Код драфта, например: DD1;a=1,14,8;e=2,74;b=19;g=2
  String get shareCode {
    String ids(Iterable<int> xs) => xs.join(',');
    return 'DD1;a=${ids(allies.whereType<int>())};e=${ids(enemies.whereType<int>())};b=${ids(bans)};g=$group';
  }

  /// Применить код. false — код не распознан.
  bool applyCode(String code) {
    final t = code.trim();
    final start = t.indexOf('DD1;');
    if (start < 0 || data == null) return false;
    final parts = t.substring(start).split(RegExp(r'\s')).first.split(';');
    List<int> ids(String? v) => (v ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((id) => data!.byId.containsKey(id))
        .toList();
    final m = <String, String>{};
    for (final p in parts.skip(1)) {
      final i = p.indexOf('=');
      if (i > 0) m[p.substring(0, i)] = p.substring(i + 1);
    }
    final a = ids(m['a']), e = ids(m['e']), b = ids(m['b']);
    if (a.isEmpty && e.isEmpty && b.isEmpty) return false;
    for (var i = 0; i < 5; i++) {
      allies[i] = i < a.length ? a[i] : null;
      enemies[i] = i < e.length ? e[i] : null;
    }
    bans
      ..clear()
      ..addAll(b.where((id) => !a.contains(id) && !e.contains(id)));
    final g = int.tryParse(m['g'] ?? '');
    if (g != null) group = g.clamp(0, rankGroups.length - 1);
    stageOverride = null;
    _changed();
    return true;
  }

  void setRoleFilter(bool v) {
    roleFilter = v;
    _changed();
  }

  // ---------- сохранение ----------

  Timer? _t;
  void _changed() {
    notifyListeners();
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 500), _savePrefs);
  }

  Future<File?> _prefsFile() async {
    try {
      final d = await getApplicationDocumentsDirectory();
      return File('${d.path}/draft_state.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePrefs() async {
    final f = await _prefsFile();
    try {
      await f?.writeAsString(jsonEncode({
        'allies': allies,
        'enemies': enemies,
        'bans': bans.toList(),
        'group': group,
        'roleFilter': roleFilter,
        'pool': pool.toList(),
        'comfortMode': comfortMode,
        'accountId': accountId,
        'playerName': playerName,
        'playerAvatar': playerAvatar,
        'rankTier': rankTier,
        'played': played.map((k, v) => MapEntry('$k', v)),
        'history': history.map((d) => d.toJson()).toList(),
      }));
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final f = await _prefsFile();
    if (f == null || !await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      List<int?> ids(dynamic v) => ((v as List?) ?? const []).map((e) => e is num ? e.toInt() : null).toList();
      final a = ids(j['allies']), e = ids(j['enemies']);
      for (var i = 0; i < 5; i++) {
        allies[i] = i < a.length ? a[i] : null;
        enemies[i] = i < e.length ? e[i] : null;
      }
      bans.addAll(((j['bans'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()));
      group = ((j['group'] as num?)?.toInt() ?? 0).clamp(0, rankGroups.length - 1);
      roleFilter = j['roleFilter'] != false;
      pool.addAll(((j['pool'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()));
      comfortMode = ((j['comfortMode'] as num?)?.toInt() ?? 1).clamp(0, 2);
      accountId = (j['accountId'] as num?)?.toInt();
      playerName = j['playerName']?.toString() ?? '';
      playerAvatar = j['playerAvatar']?.toString() ?? '';
      rankTier = (j['rankTier'] as num?)?.toInt();
      final pl = j['played'];
      if (pl is Map) {
        pl.forEach((k, v) {
          final id = int.tryParse('$k');
          if (id != null && v is List && v.length >= 2) {
            played[id] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
          }
        });
      }
      history.addAll(((j['history'] as List?) ?? const []).whereType<Map>().map(SavedDraft.fromJson));
    } catch (_) {}
  }
}

class StateScope extends InheritedNotifier<AppState> {
  const StateScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StateScope>()!.notifier!;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<StateScope>()!.notifier!;
}
