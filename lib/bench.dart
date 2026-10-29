import 'storage.dart';
import 'i18n.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;


import 'opendota.dart';

/// Средние показатели на герое в группе рангов.
class BenchRow {
  final double n, wr, gpm, xpm, k, d, a, lh10, hdm, td;
  const BenchRow(this.n, this.wr, this.gpm, this.xpm, this.k, this.d, this.a, this.lh10, this.hdm, this.td);

  double get kda => (k + a) / (d < 1 ? 1 : d);

  static BenchRow? fromList(List v) {
    if (v.length < 10) return null;
    double f(int i) => (v[i] as num?)?.toDouble() ?? 0;
    return BenchRow(f(0), f(1), f(2), f(3), f(4), f(5), f(6), f(7), f(8), f(9));
  }

  /// Средние по своим матчам (n — число игр).
  static BenchRow? ofMatches(List<PlayerMatch> ms) {
    if (ms.isEmpty) return null;
    double avg(double Function(PlayerMatch m) f) => ms.map(f).reduce((a, b) => a + b) / ms.length;
    return BenchRow(
      ms.length.toDouble(),
      ms.where((m) => m.win).length / ms.length,
      avg((m) => m.gpm.toDouble()),
      avg((m) => m.xpm.toDouble()),
      avg((m) => m.kills.toDouble()),
      avg((m) => m.deaths.toDouble()),
      avg((m) => m.assists.toDouble()),
      avg((m) => m.lh10),
      avg((m) => m.hdm),
      avg((m) => m.towerDamage.toDouble()),
    );
  }
}

/// Показатели для сравнения: подпись, как достать значение, больше — лучше?
class BenchMetric {
  final String label;
  final double Function(BenchRow r) get;
  final bool higherBetter;
  final int digits;
  const BenchMetric(this.label, this.get, {this.higherBetter = true, this.digits = 0});
}

List<BenchMetric> get benchMetrics => [
  BenchMetric(L('Винрейт', 'Win rate'), (r) => r.wr * 100, digits: 1),
  BenchMetric(L('Золото/мин (GPM)', 'Gold/min (GPM)'), (r) => r.gpm),
  BenchMetric(L('Опыт/мин (XPM)', 'XP/min (XPM)'), (r) => r.xpm),
  BenchMetric(L('Добивания за 10 мин', 'Last hits per 10 min'), (r) => r.lh10, digits: 1),
  BenchMetric(L('Убийства', 'Kills'), (r) => r.k, digits: 1),
  BenchMetric(L('Смерти', 'Deaths'), (r) => r.d, higherBetter: false, digits: 1),
  BenchMetric(L('Помощь', 'Assists'), (r) => r.a, digits: 1),
  BenchMetric('KDA', (r) => r.kda, digits: 2),
  BenchMetric(L('Урон героям/мин', 'Hero damage/min'), (r) => r.hdm),
  BenchMetric(L('Урон по вышкам', 'Tower damage'), (r) => r.td),
];

class NeutralStat {
  final int itemId;
  final double n, wr;
  const NeutralStat(this.itemId, this.n, this.wr);
}

class NeutralItem {
  final String key, name;
  final int tier;
  const NeutralItem(this.key, this.name, this.tier);
  String get image => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/$key.png';
}

class BenchData {
  final String updated;
  final Map<int, Map<int, BenchRow>> heroes; // heroId -> group (0..3) -> row
  final Map<int, List<NeutralStat>> neutral;
  final Map<int, NeutralItem> items;
  final Map<int, List<List<(int, double)>>> skills; // heroId -> шаги прокачки -> варианты (id умения, доля победителей)
  final Map<int, Map<int, (double, double)>> talents; // heroId -> id таланта -> (игр, винрейт)
  const BenchData(this.updated, this.heroes, this.neutral, this.items, [this.skills = const {}, this.talents = const {}]);

  static const empty = BenchData('', {}, {}, {});

  bool get isEmpty => heroes.isEmpty;

  BenchRow? row(int heroId, int group) => heroes[heroId]?[group];

  static BenchData parse(String txt) {
    final j = jsonDecode(txt);
    if (j is! Map) return empty;
    final heroes = <int, Map<int, BenchRow>>{};
    final hs = j['heroes'];
    if (hs is Map) {
      hs.forEach((hid, groups) {
        final id = int.tryParse('$hid');
        if (id == null || groups is! Map) return;
        final m = <int, BenchRow>{};
        groups.forEach((g, v) {
          final gi = int.tryParse('$g');
          final r = v is List ? BenchRow.fromList(v) : null;
          if (gi != null && r != null) m[gi] = r;
        });
        heroes[id] = m;
      });
    }
    final neutral = <int, List<NeutralStat>>{};
    final ns = j['neutral'];
    if (ns is Map) {
      ns.forEach((hid, rows) {
        final id = int.tryParse('$hid');
        if (id == null || rows is! List) return;
        neutral[id] = [
          for (final r in rows.whereType<List>())
            if (r.length >= 3)
              NeutralStat((r[0] as num).toInt(), (r[1] as num).toDouble(), (r[2] as num).toDouble()),
        ];
      });
    }
    final items = <int, NeutralItem>{};
    final its = j['items'];
    if (its is Map) {
      its.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id != null && v is List && v.length >= 3) {
          items[id] = NeutralItem('${v[0]}', '${v[1]}', (v[2] as num?)?.toInt() ?? 0);
        }
      });
    }
    final skills = <int, List<List<(int, double)>>>{};
    final sk = j['skills'];
    (int, double)? opt(dynamic r) => r is List && r.length >= 2 && r[0] is num
        ? ((r[0] as num).toInt(), (r[1] as num?)?.toDouble() ?? 0)
        : null;
    if (sk is Map) {
      sk.forEach((hid, rows) {
        final id = int.tryParse('$hid');
        if (id == null || rows is! List) return;
        skills[id] = [
          for (final r in rows.whereType<List>())
            // Старый формат: [id, доля]; новый: [[id, доля], ...].
            if (r.isNotEmpty && r[0] is List)
              [for (final o in r) if (opt(o) case final x?) x]
            else
              [if (opt(r) case final x?) x],
        ];
      });
    }
    final talents = <int, Map<int, (double, double)>>{};
    final tl = j['talents'];
    if (tl is Map) {
      tl.forEach((hid, m) {
        final id = int.tryParse('$hid');
        if (id == null || m is! Map) return;
        final out = <int, (double, double)>{};
        m.forEach((aid, v) {
          final a = int.tryParse('$aid');
          if (a != null && v is List && v.length >= 2) {
            out[a] = ((v[0] as num?)?.toDouble() ?? 0, (v[1] as num?)?.toDouble() ?? 0);
          }
        });
        talents[id] = out;
      });
    }
    return BenchData(j['updated']?.toString() ?? '', heroes, neutral, items, skills, talents);
  }
}

/// Группа рангов (1–3) по rank_tier игрока. null — ранг скрыт.
int? rankGroupOf(int? rankTier) {
  if (rankTier == null || rankTier <= 0) return null;
  final t = rankTier ~/ 10;
  if (t <= 2) return 1;
  if (t <= 5) return 2;
  return 3;
}

class BenchRepo {
  static const url = 'https://raw.githubusercontent.com/Wateroflord/dota-draft/main/data/bench.json';

  static Future<File?> _file() async {
    try {
      final d = await appDir();
      return File('${d.path}/bench.json');
    } catch (_) {
      return null;
    }
  }

  static Future<BenchData> loadLocal() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) {
        final b = BenchData.parse(await f.readAsString());
        if (!b.isEmpty) return b;
      }
    } catch (_) {}
    try {
      return BenchData.parse(await rootBundle.loadString('assets/bench.json'));
    } catch (_) {
      return BenchData.empty;
    }
  }

  static Future<BenchData?> fetch(String current) async {
    try {
      final res = await http
          .get(Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final txt = utf8.decode(res.bodyBytes);
      final b = BenchData.parse(txt);
      if (b.isEmpty || b.updated.compareTo(current) <= 0) return null;
      final f = await _file();
      await f?.writeAsString(txt, flush: true);
      return b;
    } catch (_) {
      return null;
    }
  }
}
