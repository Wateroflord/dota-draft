import 'data.dart';

/// Исходы линии из STRATZ (data/stratz.json): кто кого выигрывает на линии.
class LaneData {
  final String updated;
  final Map<int, Map<int, List<int>>> vs; // герой -> соперник -> [матчей, побед, поражений]
  final Map<int, Map<int, List<int>>> withHero; // герой -> напарник по линии -> [...]
  const LaneData(this.updated, this.vs, this.withHero);

  static const empty = LaneData('', {}, {});

  bool get isEmpty => vs.isEmpty;
  bool has(int hero) => vs.containsKey(hero);

  static Map<int, Map<int, List<int>>> _table(dynamic v) {
    final out = <int, Map<int, List<int>>>{};
    if (v is! Map) return out;
    v.forEach((k, row) {
      final h = int.tryParse('$k');
      if (h == null || row is! Map) return;
      final m = <int, List<int>>{};
      row.forEach((k2, x) {
        final o = int.tryParse('$k2');
        if (o != null && x is List && x.length >= 3) m[o] = [for (final e in x.take(3)) e is num ? e.toInt() : 0];
      });
      if (m.isNotEmpty) out[h] = m;
    });
    return out;
  }

  static LaneData parse(dynamic j) {
    if (j is! Map) return empty;
    return LaneData(j['updated']?.toString() ?? '', _table(j['vs']), _table(j['with']));
  }

  /// Доля выигранных линий (ничья — половина). null — мало данных.
  static double? _wr(List<int>? r) {
    if (r == null || r[0] <= 0) return null;
    final draws = r[0] - r[1] - r[2];
    return (r[1] + 0.5 * (draws < 0 ? 0 : draws)) / r[0];
  }

  /// Шанс выиграть линию героем [hero] против [enemy].
  double? laneVs(int hero, int enemy) => _wr(vs[hero]?[enemy]);

  double? laneWith(int hero, int ally) => _wr(withHero[hero]?[ally]);

  /// Отклонение от 50%: + — линия в пользу героя.
  List<(DHero, double)> _top(StatsData d, Map<int, List<int>>? row, {required bool best, int n = 6}) {
    if (row == null) return const [];
    final l = <(DHero, double)>[];
    row.forEach((o, r) {
      final h = d.byId[o];
      final wr = _wr(r);
      if (h != null && wr != null) l.add((h, wr - 0.5));
    });
    l.sort((a, b) => best ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2));
    return l.take(n).toList();
  }

  List<(DHero, double)> easiest(StatsData d, int hero) => _top(d, vs[hero], best: true);
  List<(DHero, double)> hardest(StatsData d, int hero) => _top(d, vs[hero], best: false);
  List<(DHero, double)> partners(StatsData d, int hero) => _top(d, withHero[hero], best: true);
}
