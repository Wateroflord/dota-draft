import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';

/// Личные контрпики и союзники по твоим матчам (OpenDota).
class PersonalScreen extends StatelessWidget {
  const PersonalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final d = s.data!;
    List<(DHero, int, double)> rows(int gi, int wi, {required bool asc, int min = 6}) {
      final out = <(DHero, int, double)>[];
      s.vsHeroes.forEach((id, v) {
        final h = d.byId[id];
        if (h == null || v[gi] < min) return;
        out.add((h, v[gi], v[wi] / v[gi]));
      });
      out.sort((a, b) => asc ? a.$3.compareTo(b.$3) : b.$3.compareTo(a.$3));
      return out.take(8).toList();
    }

    Widget list(String title, String hint, List<(DHero, int, double)> r) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(title),
            if (r.isEmpty)
              AppCard(child: Text(L('Мало игр для выводов.', 'Not enough games yet.'), style: T.small))
            else
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final x in r)
                    InkWell(
                      onTap: () => openHero(context, x.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(children: [
                          HeroImg(x.$1, width: 54),
                          const SizedBox(width: 10),
                          Expanded(child: Text(x.$1.name, style: T.body.copyWith(fontSize: 13.5))),
                          Text(L('${x.$2} игр  ', '${x.$2} games  '), style: T.small),
                          Text(pct(x.$3, digits: 0), style: T.num(14, color: x.$3 >= 0.5 ? C.ally : C.enemy)),
                        ]),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 4),
            Text(hint, style: T.small),
          ],
        );

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Мои контрпики', 'My counters'), style: T.h2),
      ),
      body: s.vsHeroes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  L('Нужен профиль Steam: на вкладке «Мои герои» нажми «Обновить», и здесь появятся твои личные контрпики.',
                      'Steam profile needed: tap Refresh on the My heroes tab and your personal counters will appear here.'),
                  textAlign: TextAlign.center,
                  style: T.body,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
              children: [
                list(L('Против кого ты чаще проигрываешь', 'Who you lose against most'),
                    L('Твой винрейт, когда этот герой у врагов. Их стоит банить или контрить.', 'Your win rate when this hero is on the enemy team. Ban or counter them.'),
                    rows(2, 3, asc: true)),
                list(L('Кого ты обыгрываешь', 'Who you beat'),
                    L('Против этих героев у тебя лучший винрейт.', 'Your best win rate against these heroes.'), rows(2, 3, asc: false)),
                list(L('С кем ты побеждаешь', 'Who you win with'),
                    L('Твой винрейт, когда этот герой в твоей команде.', 'Your win rate when this hero is on your team.'),
                    rows(0, 1, asc: false)),
                list(L('С кем тебе хуже', 'Who you struggle with'),
                    L('С этими союзниками ты выигрываешь реже всего.', 'You win least often with these allies.'), rows(0, 1, asc: true)),
              ],
            ),
    );
  }
}

/// Блок на вкладке «Драфт»: твои лучшие герои против этого состава и твоя статистика против врагов.
class PersonalDraftCard extends StatelessWidget {
  const PersonalDraftCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final allies = s.allyHeroes, enemies = s.enemyHeroes;
    if (s.played.isEmpty || allies.length >= 5) return const SizedBox.shrink();
    final e = Engine(s.data!, s.group);
    final all = e.recommend(
        allies: allies, enemies: enemies, unavailable: s.unavailable, stage: s.stage, limit: 200, roleFilter: false, useComfort: false);
    final best = <(Pick, int, double, double)>[];
    for (final p in all) {
      final pl = s.played[p.hero.id];
      if (pl == null || pl[0] < 8) continue;
      final wr = pl[1] / pl[0];
      // Твой винрейт на герое (с поправкой на число игр) + вклад героя в драфт.
      final personal = (wr - 0.5) * pl[0] / (pl[0] + 20);
      best.add((p, pl[0], wr, p.winDelta + personal));
    }
    best.sort((a, b) => b.$4.compareTo(a.$4));
    final vs = [
      for (final h in enemies)
        if ((s.vsHeroes[h.id]?[2] ?? 0) >= 6) (h, s.vsHeroes[h.id]![2], s.vsHeroes[h.id]![3] / s.vsHeroes[h.id]![2]),
    ];
    if (best.isEmpty && vs.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Лично для тебя', 'Just for you')),
      AppCard(
        borderColor: C.intel.withValues(alpha: 0.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (best.isNotEmpty) ...[
            Text(L('Твои лучшие герои против этого драфта', 'Your best heroes against this draft'), style: T.section),
            const SizedBox(height: 6),
            for (final b in best.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: InkWell(
                  onTap: () {
                    if (!s.add(true, b.$1.hero.id)) showToast(context, L('Твоя команда уже полная', 'Your team is already full'));
                  },
                  child: Row(children: [
                    HeroImg(b.$1.hero, width: 50),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.$1.hero.name, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        Text(L('ты: ${pct(b.$3, digits: 0)} в ${b.$2} играх · драфт ${signedPct(b.$1.winDelta)}',
                            'you: ${pct(b.$3, digits: 0)} in ${b.$2} games · draft ${signedPct(b.$1.winDelta)}'),
                            style: T.small.copyWith(fontSize: 11.5)),
                      ]),
                    ),
                    const Icon(Icons.add, size: 18, color: C.ally),
                  ]),
                ),
              ),
          ],
          if (vs.isNotEmpty) ...[
            if (best.isNotEmpty) const SizedBox(height: 8),
            Text(L('Твой винрейт против этих врагов', 'Your win rate against these enemies'), style: T.section),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final v in vs)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  HeroImg(v.$1, width: 34, radius: 4),
                  const SizedBox(width: 4),
                  Text('${pct(v.$3, digits: 0)} (${v.$2})', style: T.num(12, color: v.$3 >= 0.5 ? C.ally : C.enemy)),
                ]),
            ]),
          ],
        ]),
      ),
    ]);
  }
}

/// Медиана по взвешенным значениям.
double weightedMedian(List<(double, double)> values) {
  if (values.isEmpty) return 0;
  final v = [...values]..sort((a, b) => a.$1.compareTo(b.$1));
  final total = v.fold<double>(0, (s, x) => s + x.$2);
  var acc = 0.0;
  for (final x in v) {
    acc += x.$2;
    if (acc >= total / 2) return x.$1;
  }
  return v.last.$1;
}

double median(List<double> xs) {
  if (xs.isEmpty) return 0;
  final v = [...xs]..sort();
  return v.length.isOdd ? v[v.length ~/ 2] : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
}

int clampInt(int v, int lo, int hi) => math.max(lo, math.min(hi, v));
