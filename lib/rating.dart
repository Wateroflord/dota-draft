import 'bench.dart';
import 'data.dart';
import 'i18n.dart';
import 'opendota.dart';

/// Оценка игрока в матче.
class PlayerRating {
  final MatchPlayer p;
  final bool core;
  final double score; // 0..100, 50 — как средний игрок на этом герое
  final List<String> good, bad;
  final String verdict; // mvp, best, good, ok, weak, ruiner, leaver
  const PlayerRating(this.p, this.core, this.score, this.good, this.bad, this.verdict);
}

class MatchVerdict {
  final List<PlayerRating> players;
  final List<String> reasons; // почему победили/проиграли
  const MatchVerdict(this.players, this.reasons);
}

/// Перцентиль показателя: из OpenDota, иначе — сравнение со средним игроком на герое из нашей выборки.
double? _pct(MatchPlayer p, String key, BenchRow? ref, double minutes) {
  // Перцентиль смертей у OpenDota трактуется неоднозначно — смерти считаем сами.
  final v = key == 'deaths_per_min' ? null : p.pct[key];
  if (v != null) return v;
  if (ref == null) return null;
  double ratio(double mine, double avg) => avg <= 0 ? 0.5 : (0.5 + (mine / avg - 1) * 0.6).clamp(0.02, 0.98);
  return switch (key) {
    'gold_per_min' => ratio(p.gpm.toDouble(), ref.gpm),
    'xp_per_min' => ratio(p.xpm.toDouble(), ref.xpm),
    'kills_per_min' => ratio(p.kills.toDouble(), ref.k),
    'deaths_per_min' => ratio(p.deaths.toDouble(), ref.d),
    'assists_per_min' => ratio(p.assists.toDouble(), ref.a),
    'last_hits_per_min' => ratio(p.lastHits / minutes * 10, ref.lh10),
    'hero_damage_per_min' => ratio(p.heroDamage / minutes, ref.hdm),
    'tower_damage' => ratio(p.towerDamage.toDouble(), ref.td),
    _ => null,
  };
}

MatchVerdict rateMatch(MatchInfo m, StatsData d, BenchData bench, {double? draftChanceRadiant}) {
  final minutes = m.duration <= 0 ? 30.0 : m.duration / 60;
  final out = <PlayerRating>[];
  for (final radiant in [true, false]) {
    final team = m.players.where((p) => p.radiant == radiant).toList()..sort((a, b) => b.netWorth.compareTo(a.netWorth));
    final teamKills = team.fold<int>(0, (s, p) => s + p.kills);
    final avgDeaths = team.isEmpty ? 0 : team.fold<int>(0, (s, p) => s + p.deaths) / team.length;
    for (var i = 0; i < team.length; i++) {
      final p = team[i];
      final core = i < 3;
      final g = p.rankTier > 0 ? (rankGroupOf(p.rankTier) ?? 0) : 0;
      final ref = bench.row(p.heroId, g) ?? bench.row(p.heroId, 0);
      final weights = core
          ? {
              'gold_per_min': 0.22,
              'xp_per_min': 0.12,
              'last_hits_per_min': 0.16,
              'hero_damage_per_min': 0.16,
              'kills_per_min': 0.08,
              'deaths_per_min': 0.12,
              'tower_damage': 0.08,
              'assists_per_min': 0.06,
            }
          : {
              'assists_per_min': 0.24,
              'deaths_per_min': 0.2,
              'hero_damage_per_min': 0.14,
              'xp_per_min': 0.14,
              'hero_healing_per_min': 0.08,
              'kills_per_min': 0.08,
              'gold_per_min': 0.06,
              'tower_damage': 0.06,
            };
      var sum = 0.0, wsum = 0.0;
      final good = <String>[], bad = <String>[];
      weights.forEach((k, w) {
        var v = _pct(p, k, ref, minutes);
        if (v == null && k == 'deaths_per_min') {
          final avg = m.players.fold<int>(0, (s, x) => s + x.deaths) / (m.players.isEmpty ? 1 : m.players.length);
          v = avg <= 0 ? 0.5 : (0.5 + (p.deaths / avg - 1) * 0.6).clamp(0.02, 0.98);
        }
        if (v == null) return;
        if (k == 'hero_healing_per_min' && p.heroHealing < 500) return; // герой не лечит — не учитываем
        if (k == 'deaths_per_min') v = 1 - v; // меньше смертей — лучше
        sum += v * w;
        wsum += w;
        final name = _metricName(k);
        if (v >= 0.8) good.add(L('$name — лучше ${(v * 100).round()}% игроков на герое', '$name — better than ${(v * 100).round()}% of players on this hero'));
        if (v <= 0.2) bad.add(L('$name — хуже ${((1 - v) * 100).round()}% игроков на герое', '$name — worse than ${((1 - v) * 100).round()}% of players on this hero'));
      });
      // Участие в убийствах команды.
      final kp = teamKills == 0 ? 0.5 : (p.kills + p.assists) / teamKills;
      final kpScore = ((kp - 0.25) / 0.5).clamp(0.0, 1.0);
      sum += kpScore * 0.12;
      wsum += 0.12;
      if (kp >= 0.75) good.add(L('участвовал в ${(kp * 100).round()}% убийств команды', 'took part in ${(kp * 100).round()}% of team kills'));
      if (kp < 0.3 && teamKills >= 10) bad.add(L('участвовал всего в ${(kp * 100).round()}% убийств команды', 'only took part in ${(kp * 100).round()}% of team kills'));
      var score = wsum == 0 ? 50.0 : sum / wsum * 100;

      var verdict = 'ok';
      if (p.left) {
        verdict = 'leaver';
        score = 0;
        bad.insert(0, L('покинул игру', 'abandoned the game'));
      } else {
        final feeding = p.deaths >= 10 && p.deaths >= avgDeaths * 1.6 && (p.kills + p.assists) / (p.deaths == 0 ? 1 : p.deaths) < 0.8;
        if (feeding) bad.insert(0, L('умер ${p.deaths} раз — намного больше команды', 'died ${p.deaths} times — far more than the team'));
        if (score < 28 || (feeding && score < 40)) {
          verdict = 'ruiner';
        } else if (score < 40) {
          verdict = 'weak';
        } else if (score >= 66) {
          verdict = 'good';
        }
      }
      out.add(PlayerRating(p, core, score, good, bad, verdict));
    }
  }
  // MVP — лучший у победителей, «лучший в команде» — у проигравших.
  if (out.isNotEmpty) {
    final sorted = [...out]..sort((a, b) => b.score.compareTo(a.score));
    final mvp = sorted.where((r) => r.p.radiant == m.radiantWin && r.verdict != 'leaver').firstOrNull;
    if (mvp != null) {
      final i = out.indexOf(mvp);
      out[i] = PlayerRating(mvp.p, mvp.core, mvp.score, mvp.good, mvp.bad, 'mvp');
    }
    final other = sorted.where((r) => r.p.radiant != m.radiantWin && r.verdict != 'leaver').firstOrNull;
    if (other != null) {
      final j = out.indexOf(other);
      out[j] = PlayerRating(other.p, other.core, other.score, other.good, other.bad, 'best');
    }
  }

  // Причины исхода.
  final reasons = <String>[];
  final winners = m.radiantWin;
  String side(bool r) => r ? L('Свет', 'Radiant') : L('Тьма', 'Dire');
  final losers = out.where((r) => r.p.radiant != winners).toList();
  final leavers = losers.where((r) => r.verdict == 'leaver').toList();
  final ruiners = losers.where((r) => r.verdict == 'ruiner').toList();
  if (leavers.isNotEmpty) {
    reasons.add(L('У ${side(!winners)} был ливер — игра 4 на 5.', '${side(!winners)} had a leaver — it was 4v5.'));
  }
  if (ruiners.isNotEmpty) {
    reasons.add(L(
        'Слабее всех у проигравших сыграл ${_heroName(d, ruiners.first.p.heroId)}${ruiners.length > 1 ? ' и ещё ${ruiners.length - 1}' : ''}.',
        'Weakest on the losing side: ${_heroName(d, ruiners.first.p.heroId)}${ruiners.length > 1 ? ' and ${ruiners.length - 1} more' : ''}.'));
  }
  if (draftChanceRadiant != null) {
    final wc = winners ? draftChanceRadiant : 1 - draftChanceRadiant;
    if (wc < 0.45) {
      reasons.add(L('Победители выиграли с более слабым драфтом (${(wc * 100).round()}%) — переиграли по игре.',
          'The winners had the weaker draft (${(wc * 100).round()}%) — they outplayed.'));
    } else if (wc > 0.55) {
      reasons.add(L('Драфт был на стороне победителей (${(wc * 100).round()}%).', 'The draft favoured the winners (${(wc * 100).round()}%).'));
    }
  }
  final adv = m.goldAdv;
  if (adv != null && adv.length > 5) {
    // Знак: плюс — преимущество победителей.
    final w = [for (final v in adv) winners ? v : -v];
    final minV = w.reduce((a, b) => a < b ? a : b);
    final minAt = w.indexOf(minV);
    final at10 = w.length > 10 ? w[10] : w.last;
    if (minV < -5000) {
      reasons.add(L('Победители проигрывали ${(-minV / 1000).toStringAsFixed(1)}k золота на $minAt-й минуте, но отыгрались.',
          'The winners were ${(-minV / 1000).toStringAsFixed(1)}k gold behind at minute $minAt but came back.'));
      // Где потерян перевес.
      var bestSwing = 0, swingAt = 0;
      for (var i = minAt + 1; i < w.length; i++) {
        final sw = w[i] - w[i - 1];
        if (sw > bestSwing) {
          bestSwing = sw;
          swingAt = i;
        }
      }
      if (bestSwing > 2500) {
        reasons.add(L('Перелом — на $swingAt-й минуте (${(bestSwing / 1000).toStringAsFixed(1)}k золота за минуту): выигранная драка или Рошан.',
            'Turning point at minute $swingAt (${(bestSwing / 1000).toStringAsFixed(1)}k gold in a minute): a won fight or Roshan.'));
      }
    } else if (at10 > 2500) {
      reasons.add(L('Победители выиграли линии: +${(at10 / 1000).toStringAsFixed(1)}k золота к 10-й минуте.',
          'The winners won the lanes: +${(at10 / 1000).toStringAsFixed(1)}k gold by minute 10.'));
    } else if (at10 < -1500) {
      reasons.add(L('Проигравшие выиграли линии, но не удержали преимущество.', 'The losers won the lanes but could not hold the lead.'));
    }
  }
  final score = winners ? (m.radiantScore, m.direScore) : (m.direScore, m.radiantScore);
  if (score.$1 + score.$2 > 0) {
    reasons.add(L('Счёт по убийствам: ${score.$1} — ${score.$2}.', 'Kill score: ${score.$1} — ${score.$2}.'));
  }
  return MatchVerdict(out, reasons);
}

String _heroName(StatsData d, int id) => d.byId[id]?.name ?? '#$id';

String _metricName(String k) => switch (k) {
      'gold_per_min' => L('Фарм (золото/мин)', 'Farm (GPM)'),
      'xp_per_min' => L('Опыт/мин', 'XPM'),
      'last_hits_per_min' => L('Добивания', 'Last hits'),
      'hero_damage_per_min' => L('Урон по героям', 'Hero damage'),
      'kills_per_min' => L('Убийства', 'Kills'),
      'deaths_per_min' => L('Смерти', 'Deaths'),
      'assists_per_min' => L('Помощь', 'Assists'),
      'tower_damage' => L('Урон по вышкам', 'Tower damage'),
      'hero_healing_per_min' => L('Лечение', 'Healing'),
      _ => k,
    };

String verdictTitle(String v) => switch (v) {
      'mvp' => 'MVP',
      'best' => L('Лучший в команде', 'Best on team'),
      'good' => L('Хорошо сыграл', 'Played well'),
      'weak' => L('Недоиграл', 'Underperformed'),
      'ruiner' => L('Руинер', 'Ruiner'),
      'leaver' => L('Ливер', 'Leaver'),
      _ => L('Нормально', 'Okay'),
    };
