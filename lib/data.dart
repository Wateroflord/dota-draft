import 'storage.dart';
import 'i18n.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Группы рангов (как в данных): 0 — все, 1 — Рекрут–Страж, 2 — Рыцарь–Легенда, 3 — Властелин–Титан, 4 — Турбо.
List<String> get rankGroups => [L('Все ранги', 'All ranks'), L('Рекрут – Страж', 'Herald – Guardian'), L('Рыцарь – Легенда', 'Crusader – Legend'), L('Властелин – Титан', 'Ancient – Immortal'), L('Турбо', 'Turbo')];
List<String> get rankGroupsShort => [L('Все', 'All'), L('Рекрут–Страж', 'Herald–Guardian'), L('Рыцарь–Легенда', 'Crusader–Legend'), L('Властелин–Титан', 'Ancient–Immortal'), L('Турбо', 'Turbo')];

Map<int, String> get positionNames => {1: L('Керри', 'Carry'), 2: L('Мид', 'Mid'), 3: L('Хард', 'Offlane'), 4: L('Полусаппорт', 'Soft support'), 5: L('Саппорт', 'Hard support')};

Map<String, String> get attrNames => {'str': L('Сила', 'Strength'), 'agi': L('Ловкость', 'Agility'), 'int': L('Интеллект', 'Intelligence'), 'all': L('Универсал', 'Universal')};

/// Отрезки длительности матча для «силы по времени».
List<String> get durationLabels => [L('до 25 мин', 'under 25 min'), '25–35', '35–45', L('45+ мин', '45+ min')];

class DItem {
  final int id;
  final String key;
  final String name;
  final int cost;
  const DItem(this.id, this.key, this.name, this.cost);

  String get image => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/$key.png';
}

class DHero {
  final int index; // позиция в матрицах
  final int id;
  final String name;
  final String key; // antimage
  final String attr;
  final List<String> roles;
  final List<int> positions;
  final List<double> wr; // по группам рангов
  final List<double> pr; // доля матчей с героем
  final List<double> wrd; // изменение винрейта за неделю по группам (может быть пустым)
  final List<int> pro; // пики, победы, баны на про-сцене
  final List<double> dur; // винрейт по длительности матча
  final Map<String, List<int>> items; // s, e, m, l — популярные предметы по стадиям

  const DHero({
    required this.index,
    required this.id,
    required this.name,
    required this.key,
    required this.attr,
    required this.roles,
    required this.positions,
    required this.wr,
    required this.pr,
    this.wrd = const [],
    this.pro = const [],
    this.dur = const [],
    this.items = const {},
  });

  double wrAt(int g) => g < wr.length ? wr[g] : (wr.isEmpty ? 0.5 : wr[0]);
  double prAt(int g) => g < pr.length ? pr[g] : (pr.isEmpty ? 0 : pr[0]);
  double? trendAt(int g) => g < wrd.length ? wrd[g] : null;

  int get proPicks => pro.isNotEmpty ? pro[0] : 0;
  int get proWins => pro.length > 1 ? pro[1] : 0;
  int get proBans => pro.length > 2 ? pro[2] : 0;
  double get proWr => proPicks > 0 ? proWins / proPicks : 0;

  bool has(String role) => roles.contains(role);

  String get image => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/$key.png';
  String get icon => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/icons/$key.png';
}

double _d(dynamic v, [double def = 0]) => v is num ? v.toDouble() : def;

class StatsData {
  final String updated;
  final int matches;
  final String? trendFrom;
  final List<DHero> heroes;
  final Map<int, DItem> items;
  final List<List<int>> adv; // ×10000, преимущество строки против столбца
  final List<List<int>> syn; // ×10000, синергия пары

  StatsData(this.updated, this.matches, this.trendFrom, this.heroes, this.items, this.adv, this.syn);

  late final Map<int, DHero> byId = {for (final h in heroes) h.id: h};

  /// Преимущество a против b (в долях вероятности, напр. 0.021 = +2,1%).
  double advantage(DHero a, DHero b) => adv[a.index][b.index] / 10000;

  double synergy(DHero a, DHero b) => syn[a.index][b.index] / 10000;

  bool get hasDurations => heroes.any((h) => h.dur.length == 4);
  bool get hasTrends => heroes.any((h) => h.wrd.isNotEmpty);
  bool get hasPro => heroes.any((h) => h.proPicks > 0);

  static StatsData parse(String txt) {
    final j = jsonDecode(txt) as Map<String, dynamic>;
    final list = (j['heroes'] as List).cast<Map>();
    List<double> dl(dynamic v, [double def = 0]) => ((v as List?) ?? const []).map((e) => _d(e, def)).toList();
    List<int> il(dynamic v) => ((v as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList();
    final heroes = <DHero>[];
    for (var i = 0; i < list.length; i++) {
      final h = list[i];
      final items = <String, List<int>>{};
      final rawItems = h['items'];
      if (rawItems is Map) {
        rawItems.forEach((k, v) => items[k.toString()] = il(v));
      }
      heroes.add(DHero(
        index: i,
        id: (h['id'] as num).toInt(),
        name: h['n']?.toString() ?? '',
        key: h['k']?.toString() ?? '',
        attr: h['a']?.toString() ?? 'all',
        roles: ((h['r'] as List?) ?? const []).map((e) => e.toString()).toList(),
        positions: il(h['p']),
        wr: dl(h['wr'], 0.5),
        pr: dl(h['pr']),
        wrd: dl(h['wrd']),
        pro: il(h['pro']),
        dur: dl(h['dur'], 0.5),
        items: items,
      ));
    }
    final items = <int, DItem>{};
    final rawItems = j['items'];
    if (rawItems is Map) {
      rawItems.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v is List && v.length >= 3) {
          items[id] = DItem(id, v[0].toString(), v[1].toString(), (v[2] as num?)?.toInt() ?? 0);
        }
      });
    }
    List<List<int>> mat(dynamic m) => ((m as List?) ?? const [])
        .map((row) => (row as List).map((e) => (e as num).toInt()).toList())
        .toList();
    final adv = mat(j['adv']);
    final syn = mat(j['syn']);
    final n = heroes.length;
    List<List<int>> fix(List<List<int>> m) =>
        m.length == n && m.every((r) => r.length == n) ? m : List.generate(n, (_) => List.filled(n, 0));
    return StatsData(
      j['updated']?.toString() ?? '',
      (j['matches'] as num?)?.toInt() ?? 0,
      j['trend_from']?.toString(),
      heroes,
      items,
      fix(adv),
      fix(syn),
    );
  }
}

/// Загрузка данных: сначала сохранённые на телефоне (или встроенные), потом свежие из интернета.
class DataRepo {
  static const url = 'https://raw.githubusercontent.com/Wateroflord/dota-draft/main/data/draft.json';

  static Future<File?> _file() async {
    try {
      final d = await appDir();
      return File('${d.path}/draft.json');
    } catch (_) {
      return null;
    }
  }

  static Future<StatsData> loadLocal() async {
    final f = await _file();
    if (f != null && await f.exists()) {
      try {
        return StatsData.parse(await f.readAsString());
      } catch (_) {}
    }
    return StatsData.parse(await rootBundle.loadString('assets/draft.json'));
  }

  /// Скачать свежие данные. null — не удалось или данные не новее текущих.
  static Future<StatsData?> fetch({String? currentUpdated, bool force = false}) async {
    try {
      final res = await http
          .get(Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final txt = utf8.decode(res.bodyBytes);
      final data = StatsData.parse(txt);
      if (data.heroes.isEmpty) return null;
      if (!force && currentUpdated != null && data.updated.compareTo(currentUpdated) <= 0) return null;
      final f = await _file();
      await f?.writeAsString(txt, flush: true);
      return data;
    } catch (_) {
      return null;
    }
  }
}
