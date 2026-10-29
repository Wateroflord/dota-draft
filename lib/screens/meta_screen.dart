import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';

/// «Лучшие пики»: тир-лист героев по выбранному рангу.
class MetaScreen extends StatefulWidget {
  const MetaScreen({super.key});

  @override
  State<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends State<MetaScreen> {
  int sort = 0; // 0 — мета (винрейт с учётом популярности), 1 — винрейт, 2 — популярность
  int pos = 0; // 0 — все позиции

  /// Оценка «силы в мете»: винрейт, слегка поднятый за популярность (популярных сложнее «разыграть случайно»).
  static double metaScore(DHero h, int g) => (h.wr[g] - 0.5) * 100 + 1.2 * math.log(1 + h.pr[g] * 100);

  static String tier(double score, List<double> all) {
    if (all.isEmpty) return 'C';
    final sorted = [...all]..sort((a, b) => b.compareTo(a));
    final rank = sorted.indexOf(score) / sorted.length;
    if (rank < 0.08) return 'S';
    if (rank < 0.25) return 'A';
    if (rank < 0.55) return 'B';
    if (rank < 0.8) return 'C';
    return 'D';
  }

  static Color tierColor(String t) => switch (t) {
        'S' => C.gold,
        'A' => C.ally,
        'B' => C.intel,
        'C' => C.accent2,
        _ => C.muted,
      };

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final g = s.group;
    final heroes = s.data!.heroes.where((h) => pos == 0 || h.positions.contains(pos)).toList();
    final scores = {for (final h in s.data!.heroes) h.id: metaScore(h, g)};
    final allScores = scores.values.toList();
    heroes.sort((a, b) => switch (sort) {
          1 => b.wr[g].compareTo(a.wr[g]),
          2 => b.pr[g].compareTo(a.pr[g]),
          _ => scores[b.id]!.compareTo(scores[a.id]!),
        });

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: const Text('Лучшие пики', style: T.h2)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        itemCount: heroes.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chips(['Все', ...rankGroupsShort.skip(1)], g, s.setGroup),
                const SizedBox(height: 8),
                _chips(const ['Любая', 'Керри', 'Мид', 'Хард', 'Поз. 4', 'Поз. 5'], pos, (v) => setState(() => pos = v)),
                const SizedBox(height: 8),
                _chips(const ['Мета', 'Винрейт', 'Популярность'], sort, (v) => setState(() => sort = v)),
                const SizedBox(height: 10),
                Text(
                  'Тир — винрейт с поправкой на популярность. S — лучшие 8% героев, D — слабейшие.',
                  style: T.small,
                ),
                const SizedBox(height: 10),
              ],
            );
          }
          final h = heroes[i - 1];
          final t = tier(scores[h.id]!, allScores);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding: const EdgeInsets.all(8),
              onTap: () => openHero(context, h),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  child: Text(t, textAlign: TextAlign.center, style: T.num(18, color: tierColor(t), weight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                HeroImg(h, width: 64),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                    Text(positionsText(h), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pct(h.wr[g]), style: T.num(14, color: h.wr[g] >= 0.5 ? C.ally : C.enemy)),
                  Text('в ${pct(h.pr[g])} игр', style: T.small.copyWith(fontSize: 11)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chips(List<String> labels, int selected, ValueChanged<int> onTap) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            Pill(labels[i], color: C.accent, filled: i == selected, onTap: () => onTap(i)),
            const SizedBox(width: 6),
          ],
        ]),
      );
}
