import 'storage.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'background.dart';
import 'bench.dart';
import 'data.dart';
import 'engine.dart';
import 'i18n.dart';
import 'info.dart';
import 'opendota.dart';
import 'theme.dart';

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

/// Друг для драфта в пати.
class Friend {
  final int id;
  final String name, avatar;
  final int? rankTier;
  final Map<int, List<int>> played; // hero.id -> [игр, побед]
  const Friend(this.id, this.name, this.avatar, this.rankTier, this.played);

  /// Герои, на которых друг уверенно играет.
  Set<int> get comfort {
    final top = played.entries.toList()..sort((a, b) => b.value[0].compareTo(a.value[0]));
    return {for (final e in top.take(15)) if (e.value[0] >= 5) e.key};
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'n': name, 'a': avatar, 'r': rankTier, 'p': played.map((k, v) => MapEntry('$k', v))};

  static Friend fromJson(Map j) {
    final pl = <int, List<int>>{};
    final p = j['p'];
    if (p is Map) {
      p.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null && v is List && v.length >= 2) pl[id] = [(v[0] as num).toInt(), (v[1] as num).toInt()];
      });
    }
    return Friend((j['id'] as num?)?.toInt() ?? 0, j['n']?.toString() ?? '', j['a']?.toString() ?? '',
        (j['r'] as num?)?.toInt(), pl);
  }
}

/// Цель игрока: показатель, значение, (необязательно) герой.
class Goal {
  final String id;
  final String metric; // lh10, gpm, xpm, deaths, kda, wr, hdm
  final double target;
  final int? heroId;
  final int created; // ms
  const Goal(this.id, this.metric, this.target, this.heroId, this.created);

  Map<String, dynamic> toJson() => {'id': id, 'm': metric, 't': target, 'h': heroId, 'c': created};
  static Goal fromJson(Map j) => Goal(j['id']?.toString() ?? '', j['m']?.toString() ?? 'gpm',
      (j['t'] as num?)?.toDouble() ?? 0, (j['h'] as num?)?.toInt(), (j['c'] as num?)?.toInt() ?? 0);
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
  // Личная статистика с героями: [игр вместе, побед вместе, игр против, побед против]
  final Map<int, List<int>> vsHeroes = {};
  // Заметки к матчам: id матча -> текст
  final Map<String, String> notes = {};
  bool playerLoading = false;
  String? playerError;

  // История драфтов
  final List<SavedDraft> history = [];

  // Моя позиция в драфте (0 — любая), друзья для пати, цели, история ранга, язык
  int myPos = 0;
  final List<Friend> friends = [];
  bool partyMode = false;
  final List<Goal> goals = [];
  final List<List<int>> rankHistory = []; // [время (сек), rank_tier]
  String lang = 'ru';
  String theme = 'dark'; // dark / light
  bool notify = false;

  // Справочные данные
  HeroInfoData info = HeroInfoData.empty;
  List<PatchNotes> patches = const [];
  List<ProDraft> proDrafts = const [];
  Portraits portraits = Portraits.empty;
  Map<String, ItemRef> itemRef = const {};

  Map<int, List<String>> get friendHeroes {
    final out = <int, List<String>>{};
    if (!partyMode) return out;
    for (final f in friends) {
      for (final id in f.comfort) {
        out.putIfAbsent(id, () => []).add(f.name);
      }
    }
    return out;
  }

  void setMyPos(int p) {
    myPos = p;
    _changed();
  }

  void setPartyMode(bool v) {
    partyMode = v;
    _changed();
  }

  Future<String?> addFriend(String input) async {
    final id = OpenDota.parseAccountId(input);
    if (id == null) return L('Нужен Friend ID или ссылка на профиль Steam', 'Need a Friend ID or Steam profile link');
    if (friends.any((f) => f.id == id) || id == accountId) return L('Этот игрок уже добавлен', 'Already added');
    try {
      final p = await OpenDota.profile(id);
      final h = await OpenDota.heroes(id);
      friends.add(Friend(id, p.name, p.avatar, p.rankTier, {
        for (final e in h.entries)
          if (e.value[0] > 0) e.key: [e.value[0], e.value[1]],
      }));
      partyMode = true;
      _changed();
      return null;
    } on OdException catch (e) {
      return e.message;
    }
  }

  void removeFriend(int id) {
    friends.removeWhere((f) => f.id == id);
    if (friends.isEmpty) partyMode = false;
    _changed();
  }

  void addGoal(Goal g) {
    goals.add(g);
    _changed();
  }

  void removeGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    _changed();
  }

  /// Уведомления о патчах и изменениях меты (фоновая проверка раз в ~12 часов).
  Future<bool> setNotify(bool v) async {
    if (v) {
      final ok = await requestNotificationPermission();
      if (!ok) return false;
    }
    notify = v;
    _changed();
    await _savePrefs();
    await scheduleBackground(v);
    return true;
  }

  /// Обновить виджет на главном экране по свежим данным.
  Future<void> refreshWidget() async {
    final d = data;
    if (d == null) return;
    final g = group;
    double score(DHero h) => (h.wrAt(g) - 0.5) * 100 + 1.2 * math.log(1 + h.prAt(g) * 100);
    final top = [...d.heroes]..sort((a, b) => score(b).compareTo(score(a)));
    final line1 = L('Топ меты: ${top.take(3).map((h) => h.name).join(', ')}', 'Top meta: ${top.take(3).map((h) => h.name).join(', ')}');
    var line2 = '';
    final ms = myMatches;
    if (ms != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final week = ms.where((m) => now - m.startTime < 7 * 86400).toList();
      line2 = week.isEmpty
          ? L('За неделю игр нет', 'No games this week')
          : L('Неделя: ${week.length} игр, винрейт ${(week.where((m) => m.win).length / week.length * 100).round()}%',
              'Week: ${week.length} games, win rate ${(week.where((m) => m.win).length / week.length * 100).round()}%');
    }
    await updateWidget(line1, line2);
  }

  void setTheme(String t) {
    theme = t;
    C.dark = t != 'light';
    _changed();
  }

  void setLang(String l) {
    lang = l;
    isEn = l == 'en';
    _changed();
  }

  Future<void> _loadInfo() async {
    info = HeroInfoData.parse(await JsonRepo.load('heroinfo.json'));
    patches = PatchNotes.parse(await JsonRepo.load('patch.json'));
    proDrafts = ProDraft.parse(await JsonRepo.load('pro_drafts.json'));
    portraits = Portraits.parse(await JsonRepo.load('portraits.json'));
    itemRef = ItemRef.parse(await JsonRepo.load('items.json'));
  }

  Future<void> _fetchInfo({bool force = false}) async {
    final i = await JsonRepo.fetch('heroinfo.json', force: force);
    if (i != null) info = HeroInfoData.parse(i);
    final p = await JsonRepo.fetch('patch.json', force: force);
    if (p != null) patches = PatchNotes.parse(p);
    final d = await JsonRepo.fetch('pro_drafts.json', force: force);
    if (d != null) proDrafts = ProDraft.parse(d);
    final po = await JsonRepo.fetch('portraits.json', force: force);
    if (po != null) portraits = Portraits.parse(po);
    final it = await JsonRepo.fetch('items.json', force: force);
    if (it != null) itemRef = ItemRef.parse(it);
  }

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
      if (myMatches!.isEmpty) myMatchesError = L('Матчи не найдены — проверь, открыт ли доступ к данным матчей.', 'No matches found — check that public match data is enabled.');
    } on OdException catch (e) {
      myMatchesError = e.message;
    } finally {
      myMatchesLoading = false;
      notifyListeners();
    }
  }

  Comfort get comfort => Comfort(pool: pool, played: played, mode: comfortMode, friends: friendHeroes);

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
      error = L('Не удалось загрузить данные: $e', 'Could not load data: $e');
    }
    bench = await BenchRepo.loadLocal();
    await _loadInfo();
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
    await _fetchInfo(force: force);
    refreshWidget();
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
      return L('Нужен числовой ID: Friend ID из Dota 2 или ссылка вида steamcommunity.com/profiles/7656…', 'Need a numeric ID: Friend ID from Dota 2 or a link like steamcommunity.com/profiles/7656…');
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
      if (p.rankTier != null &&
          (rankHistory.isEmpty || rankHistory.last[1] != p.rankTier)) {
        rankHistory.add([DateTime.now().millisecondsSinceEpoch ~/ 1000, p.rankTier!]);
      }
      played
        ..clear()
        ..addAll({
          for (final e in h.entries)
            if (e.value[0] > 0) e.key: [e.value[0], e.value[1]],
        });
      vsHeroes
        ..clear()
        ..addAll({
          for (final e in h.entries)
            if (e.value.length >= 6) e.key: e.value.sublist(2, 6),
        });
      if (h.isEmpty) {
        playerError = L('Матчи не найдены. Включи в Dota 2: Настройки → Общение → «Открыть общий доступ к данным матчей».', 'No matches found. In Dota 2 enable: Settings → Social → "Expose Public Match Data".');
      }
    } on OdException catch (e) {
      playerError = e.message;
    } finally {
      playerLoading = false;
      _changed();
    }
    return playerError;
  }

  void setNote(int matchId, String text) {
    if (text.trim().isEmpty) {
      notes.remove('$matchId');
    } else {
      notes['$matchId'] = text.trim();
    }
    _changed();
  }

  void forgetPlayer() {
    accountId = null;
    playerName = '';
    playerAvatar = '';
    rankTier = null;
    played.clear();
    vsHeroes.clear();
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
      final d = await appDir();
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
        'vs': vsHeroes.map((k, v) => MapEntry('$k', v)),
        'notes': notes,
        'history': history.map((d) => d.toJson()).toList(),
        'myPos': myPos,
        'friends': friends.map((f) => f.toJson()).toList(),
        'partyMode': partyMode,
        'goals': goals.map((g) => g.toJson()).toList(),
        'rankHistory': rankHistory,
        'lang': lang,
        'notify': notify,
        'theme': theme,
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
      final vs = j['vs'];
      if (vs is Map) {
        vs.forEach((k, v) {
          final id = int.tryParse('$k');
          if (id != null && v is List && v.length >= 4) vsHeroes[id] = [for (final x in v.take(4)) x is num ? x.toInt() : 0];
        });
      }
      final nt = j['notes'];
      if (nt is Map) nt.forEach((k, v) => notes['$k'] = '$v');
      myPos = ((j['myPos'] as num?)?.toInt() ?? 0).clamp(0, 5);
      friends.addAll(((j['friends'] as List?) ?? const []).whereType<Map>().map(Friend.fromJson));
      partyMode = j['partyMode'] == true && friends.isNotEmpty;
      goals.addAll(((j['goals'] as List?) ?? const []).whereType<Map>().map(Goal.fromJson));
      for (final r in ((j['rankHistory'] as List?) ?? const []).whereType<List>()) {
        if (r.length >= 2 && r[0] is num && r[1] is num) rankHistory.add([(r[0] as num).toInt(), (r[1] as num).toInt()]);
      }
      lang = j['lang'] == 'en' ? 'en' : 'ru';
      notify = j['notify'] == true;
      theme = j['theme'] == 'light' ? 'light' : 'dark';
      C.dark = theme != 'light';
      isEn = lang == 'en';
    } catch (_) {}
  }
}

class StateScope extends InheritedNotifier<AppState> {
  const StateScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StateScope>()!.notifier!;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<StateScope>()!.notifier!;
}
