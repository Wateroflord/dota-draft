import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Группы рангов (как в данных): 0 — все, 1 — Рекрут–Страж, 2 — Рыцарь–Легенда, 3 — Властелин–Титан.
const rankGroups = ['Все ранги', 'Рекрут – Страж', 'Рыцарь – Легенда', 'Властелин – Титан'];
const rankGroupsShort = ['Все', 'Рекрут–Страж', 'Рыцарь–Легенда', 'Властелин–Титан'];

const positionNames = {1: 'Керри', 2: 'Мид', 3: 'Хард', 4: 'Полусаппорт', 5: 'Саппорт'};

const attrNames = {'str': 'Сила', 'agi': 'Ловкость', 'int': 'Интеллект', 'all': 'Универсал'};

class Hero {
  final int index; // позиция в матрицах
  final int id;
  final String name;
  final String key; // antimage
  final String attr;
  final List<String> roles;
  final List<int> positions;
  final List<double> wr; // по группам рангов
  final List<double> pr; // доля матчей с героем

  const Hero({
    required this.index,
    required this.id,
    required this.name,
    required this.key,
    required this.attr,
    required this.roles,
    required this.positions,
    required this.wr,
    required this.pr,
  });

  String get image => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/$key.png';
  String get icon => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/icons/$key.png';
}

double _d(dynamic v, [double def = 0]) => v is num ? v.toDouble() : def;

class StatsData {
  final String updated;
  final int matches;
  final List<Hero> heroes;
  final List<List<int>> adv; // ×10000, преимущество строки против столбца
  final List<List<int>> syn; // ×10000, синергия пары

  StatsData(this.updated, this.matches, this.heroes, this.adv, this.syn);

  late final Map<int, Hero> byId = {for (final h in heroes) h.id: h};

  /// Преимущество a против b (в долях вероятности, напр. 0.021 = +2,1%).
  double advantage(Hero a, Hero b) => adv[a.index][b.index] / 10000;

  double synergy(Hero a, Hero b) => syn[a.index][b.index] / 10000;

  static StatsData parse(String txt) {
    final j = jsonDecode(txt) as Map<String, dynamic>;
    final list = (j['heroes'] as List).cast<Map>();
    final heroes = <Hero>[];
    for (var i = 0; i < list.length; i++) {
      final h = list[i];
      heroes.add(Hero(
        index: i,
        id: (h['id'] as num).toInt(),
        name: h['n']?.toString() ?? '',
        key: h['k']?.toString() ?? '',
        attr: h['a']?.toString() ?? 'all',
        roles: ((h['r'] as List?) ?? const []).map((e) => e.toString()).toList(),
        positions: ((h['p'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        wr: ((h['wr'] as List?) ?? const []).map((e) => _d(e, 0.5)).toList(),
        pr: ((h['pr'] as List?) ?? const []).map((e) => _d(e)).toList(),
      ));
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
      heroes,
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
      final d = await getApplicationDocumentsDirectory();
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
