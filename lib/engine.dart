import 'dart:math' as math;

import 'data.dart';

double logit(double p) {
  final q = p.clamp(0.02, 0.98);
  return math.log(q / (1 - q));
}

double sigmoid(double x) => 1 / (1 + math.exp(-x));

/// Перевод «процентов» синергии/контры в логиты с осторожным коэффициентом,
/// чтобы шанс победы не улетал в крайности.
const kPair = 2.4;

/// Причина рекомендации: «сильный против X», «хорошо с Y», «боится Z».
class Reason {
  final DHero hero;
  final double value; // доля вероятности (+0.021 = +2,1%)
  final int kind; // 0 — против врага, 1 — с союзником, 2 — опасный контрпик
  const Reason(this.hero, this.value, this.kind);
}

class Pick {
  final DHero hero;
  final double score; // для сортировки
  final double winDelta; // изменение шанса победы, доли
  final double vulnerability; // насколько легко законтрить (доли)
  final List<Reason> reasons;
  final List<DHero> counters; // кто его контрит из доступных
  final bool fitsRole;
  final int? position; // какую позицию закроет
  const Pick(this.hero, this.score, this.winDelta, this.vulnerability, this.reasons, this.counters, this.fitsRole,
      this.position);
}

class TeamResult {
  final List<DHero> heroes;
  final Map<int, int> positions; // hero.id -> позиция
  final double winChance;
  const TeamResult(this.heroes, this.positions, this.winChance);
}

class Engine {
  final StatsData d;
  final int group;
  Engine(this.d, this.group);

  double wr(DHero h) => h.wr.length > group ? h.wr[group] : 0.5;
  double pr(DHero h) => h.pr.length > group ? h.pr[group] : 0;

  /// Вклад героя «сам по себе» (логит его винрейта).
  double base(DHero h) {
    // Очень редких героев не переоцениваем: тянем винрейт к 50%.
    final p = pr(h);
    final trust = (p / (p + 0.01)).clamp(0.0, 1.0);
    return logit(0.5 + (wr(h) - 0.5) * trust);
  }

  double teamLogit(List<DHero> a, List<DHero> e) {
    var s = 0.0;
    for (final h in a) {
      s += base(h);
    }
    for (final h in e) {
      s -= base(h);
    }
    var pair = 0.0;
    for (var i = 0; i < a.length; i++) {
      for (var j = i + 1; j < a.length; j++) {
        pair += d.synergy(a[i], a[j]);
      }
    }
    for (var i = 0; i < e.length; i++) {
      for (var j = i + 1; j < e.length; j++) {
        pair -= d.synergy(e[i], e[j]);
      }
    }
    for (final x in a) {
      for (final y in e) {
        pair += d.advantage(x, y);
      }
    }
    return s + kPair * pair;
  }

  double winChance(List<DHero> a, List<DHero> e) => sigmoid(teamLogit(a, e)).clamp(0.05, 0.95);

  /// Сила команды без учёта соперника: 0–100, 50 — средняя.
  double strength(List<DHero> team) {
    if (team.isEmpty) return 0;
    var s = 0.0;
    for (final h in team) {
      s += base(h);
    }
    for (var i = 0; i < team.length; i++) {
      for (var j = i + 1; j < team.length; j++) {
        s += kPair * d.synergy(team[i], team[j]);
      }
    }
    // Нормируем на полный состав, чтобы 2 героя не выглядели «слабее» 5.
    s = s * 5 / team.length;
    return (50 + 50 * _tanh(s / 0.6)).clamp(1, 99).toDouble();
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  // ---------------- позиции ----------------

  static double _posWeight(DHero h, int pos) {
    final i = h.positions.indexOf(pos);
    if (i < 0) return -0.6;
    return const [1.0, 0.75, 0.55, 0.45][math.min(i, 3)];
  }

  static final List<List<int>> _perms = _permutations([1, 2, 3, 4, 5]);

  static List<List<int>> _permutations(List<int> xs) {
    if (xs.length <= 1) return [xs];
    final out = <List<int>>[];
    for (var i = 0; i < xs.length; i++) {
      final rest = [...xs]..removeAt(i);
      for (final p in _permutations(rest)) {
        out.add([xs[i], ...p]);
      }
    }
    return out;
  }

  /// Лучшая расстановка героев по позициям: (оценка, hero.id -> позиция).
  static (double, Map<int, int>) assign(List<DHero> team) {
    if (team.isEmpty) return (0, {});
    var best = -1e9;
    List<int>? bestPerm;
    for (final p in _perms) {
      var s = 0.0;
      for (var i = 0; i < team.length; i++) {
        s += _posWeight(team[i], p[i]);
      }
      if (s > best) {
        best = s;
        bestPerm = p;
      }
    }
    return (best, {for (var i = 0; i < team.length; i++) team[i].id: bestPerm![i]});
  }

  /// Свободные позиции в команде.
  static List<int> missingPositions(List<DHero> team) {
    final used = assign(team).$2.values.toSet();
    return [for (var p = 1; p <= 5; p++) if (!used.contains(p)) p];
  }

  // ---------------- рекомендации ----------------

  /// Кого взять. [stage]: 1 — первые пики (надёжно, сложно законтрить), 2 — середина, 3 — последний пик (контрпик).
  List<Pick> recommend({
    required List<DHero> allies,
    required List<DHero> enemies,
    required Set<int> unavailable,
    required int stage,
    bool roleFilter = true,
    int limit = 20,
  }) {
    final pool = d.heroes.where((h) => !unavailable.contains(h.id)).toList();
    final missing = allies.length >= 5 ? <int>[] : missingPositions(allies);
    final now = teamLogit(allies, enemies);
    final p0 = sigmoid(now);
    final out = <Pick>[];
    for (final h in pool) {
      var adv = 0.0, syn = 0.0;
      final reasons = <Reason>[];
      for (final e in enemies) {
        final v = d.advantage(h, e);
        adv += v;
        if (v.abs() >= 0.008) reasons.add(Reason(e, v, 0));
      }
      for (final a in allies) {
        final v = d.synergy(h, a);
        syn += v;
        if (v >= 0.006) reasons.add(Reason(a, v, 1));
      }
      // Кто из ещё доступных героев сильнее всего его контрит.
      final threats = <(DHero, double)>[];
      for (final x in pool) {
        if (x.id == h.id) continue;
        final v = d.advantage(x, h);
        if (v > 0) threats.add((x, v));
      }
      threats.sort((a, b) => b.$2.compareTo(a.$2));
      final top = threats.take(3).toList();
      final vuln = top.isEmpty ? 0.0 : top.map((t) => t.$2).reduce((a, b) => a + b) / top.length;

      final delta = base(h) + kPair * (adv + syn);
      final fits = missing.isEmpty || h.positions.any(missing.contains);
      final raw = switch (stage) {
        1 => delta - 0.9 * kPair * vuln + 0.15 * math.log(1 + pr(h) * 20),
        2 => delta - 0.45 * kPair * vuln,
        _ => base(h) + kPair * (1.4 * adv + syn),
      };
      final score = raw - (roleFilter && !fits ? 0.25 : 0.0);
      final pDelta = sigmoid(now + delta) - p0;
      reasons.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
      int? pos;
      for (final p in h.positions) {
        if (missing.contains(p)) {
          pos = p;
          break;
        }
      }
      out.add(Pick(h, score, pDelta, vuln, reasons.take(4).toList(), [for (final t in top) t.$1], fits,
          pos ?? (h.positions.isEmpty ? null : h.positions.first)));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    if (roleFilter && missing.isNotEmpty) {
      final fit = out.where((p) => p.fitsRole).toList();
      if (fit.length >= 5) return fit.take(limit).toList();
    }
    return out.take(limit).toList();
  }

  /// Самые опасные герои, которых могут взять противники (кандидаты в бан).
  List<Pick> threats({
    required List<DHero> allies,
    required List<DHero> enemies,
    required Set<int> unavailable,
    int limit = 8,
  }) {
    final view = recommend(
      allies: enemies,
      enemies: allies,
      unavailable: unavailable,
      stage: allies.isEmpty ? 1 : 3,
      roleFilter: enemies.isNotEmpty,
      limit: limit,
    );
    return view;
  }

  /// Лучший состав: дополняет свободные слоты так, чтобы шанс победы был максимальным
  /// и позиции 1–5 были закрыты.
  TeamResult bestTeam({
    required List<DHero> allies,
    required List<DHero> enemies,
    required Set<int> unavailable,
  }) {
    final free = 5 - allies.length;
    if (free <= 0) {
      return TeamResult(allies, assign(allies).$2, winChance(allies, enemies));
    }
    var beam = <List<DHero>>[allies];
    for (var step = 0; step < free; step++) {
      final next = <(List<DHero>, double)>[];
      for (final team in beam) {
        final taken = {...unavailable, ...team.map((h) => h.id)};
        final picks = recommend(
          allies: team,
          enemies: enemies,
          unavailable: taken,
          stage: 2,
          roleFilter: true,
          limit: 18,
        );
        for (final p in picks) {
          final t = [...team, p.hero];
          final fit = assign(t).$1;
          next.add((t, teamLogit(t, enemies) + 0.35 * fit));
        }
      }
      next.sort((a, b) => b.$2.compareTo(a.$2));
      final seen = <String>{};
      beam = [];
      for (final n in next) {
        final key = (n.$1.map((h) => h.id).toList()..sort()).join(',');
        if (!seen.add(key)) continue;
        beam.add(n.$1);
        if (beam.length >= 6) break;
      }
      if (beam.isEmpty) break;
    }
    final team = beam.first;
    return TeamResult(team, assign(team).$2, winChance(team, enemies));
  }

  /// Лучшие и худшие противостояния героя.
  List<(DHero, double)> matchups(DHero h, {bool best = true, int limit = 8}) {
    final list = [
      for (final x in d.heroes)
        if (x.id != h.id) (x, d.advantage(h, x)),
    ];
    list.sort((a, b) => best ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2));
    return list.take(limit).toList();
  }

  List<(DHero, double)> partners(DHero h, {int limit = 8}) {
    final list = [
      for (final x in d.heroes)
        if (x.id != h.id) (x, d.synergy(h, x)),
    ];
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(limit).toList();
  }
}
