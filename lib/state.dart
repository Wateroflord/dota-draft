import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'data.dart';
import 'engine.dart';

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

  Engine get engine => Engine(data!, group);

  List<Hero> heroesOf(List<int?> ids) => [
        for (final id in ids)
          if (id != null && data!.byId[id] != null) data!.byId[id]!,
      ];

  List<Hero> get allyHeroes => heroesOf(allies);
  List<Hero> get enemyHeroes => heroesOf(enemies);

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

  void applyTeam(List<Hero> team) {
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
    } catch (_) {}
  }
}

class StateScope extends InheritedNotifier<AppState> {
  const StateScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StateScope>()!.notifier!;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<StateScope>()!.notifier!;
}
