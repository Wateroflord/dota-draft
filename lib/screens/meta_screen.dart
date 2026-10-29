import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';
import '../i18n.dart';

/// «Мета»: тир-лист по рангу, про-сцена, тренды за неделю.
class MetaScreen extends StatefulWidget {
  const MetaScreen({super.key});

  @override
  State<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends State<MetaScreen> {
  int mode = 0; // 0 — тир-лист, 1 — про-сцена, 2 — тренды
  int sort = 0; // 0 — мета, 1 — винрейт, 2 — популярность
  int pos = 0; // 0 — все позиции

  static double metaScore(DHero h, int g) => (h.wrAt(g) - 0.5) * 100 + 1.2 * math.log(1 + h.prAt(g) * 100);

  static String tier(double score, List<double> sorted) {
    if (sorted.isEmpty) return 'C';
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
    final d = s.data!;
    final all = d.heroes.where((h) => pos == 0 || h.positions.contains(pos)).toList();
    final scores = {for (final h in d.heroes) h.id: metaScore(h, g)};
    final sortedScores = scores.values.toList()..sort((a, b) => b.compareTo(a));

    List<DHero> list;
    String hint;
    switch (mode) {
      case 1:
        list = all.where((h) => h.proPicks + h.proBans > 0).toList()
          ..sort((a, b) => (b.proPicks + b.proBans).compareTo(a.proPicks + a.proBans));
        hint = d.hasPro
            ? 'Самые популярные герои профессиональных матчей: пики + баны, винрейт на про-сцене.'
            : 'Данные про-сцены появятся после ближайшего обновления статистики.';
      case 3:
        final patch = s.patches.isEmpty ? null : s.patches.first;
        list = all.where((h) => patch != null && patch.forHero(h.id).isNotEmpty).toList()
          ..sort((a, b) {
            final pa = s.inPool(a.id) ? 1 : 0, pb = s.inPool(b.id) ? 1 : 0;
            if (pa != pb) return pb.compareTo(pa);
            return patch!.forHero(b.id).length.compareTo(patch.forHero(a.id).length);
          });
        hint = patch == null
            ? L('Изменения патча появятся после обновления данных.', 'Patch changes will appear after a data update.')
            : L('Патч ${patch.version}: герои с изменениями. Твои герои (★) — вверху. Нажми, чтобы увидеть все правки.',
                'Patch ${patch.version}: changed heroes. Your heroes (★) are on top. Tap to see all changes.');
      case 2:
        list = all.where((h) => h.trendAt(g) != null).toList()
          ..sort((a, b) => b.trendAt(g)!.compareTo(a.trendAt(g)!));
        hint = d.hasTrends
            ? 'Изменение винрейта с ${d.trendFrom ?? 'прошлой недели'}. Вверху — кто растёт, внизу — кто падает.'
            : 'Тренды появятся через несколько дней: нужна статистика минимум за два дня.';
      default:
        list = [...all]..sort((a, b) => switch (sort) {
              1 => b.wrAt(g).compareTo(a.wrAt(g)),
              2 => b.prAt(g).compareTo(a.prAt(g)),
              _ => scores[b.id]!.compareTo(scores[a.id]!),
            });
        hint = 'Тир — винрейт с поправкой на популярность. S — лучшие 8% героев, D — слабейшие.';
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: const Text('Мета', style: T.h2)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        itemCount: list.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _chips(['Тир-лист', 'Про-сцена', 'Тренды', L('Патч', 'Patch')], mode, (v) => setState(() => mode = v)),
              const SizedBox(height: 8),
              if (mode != 1) ...[
                _chips(rankGroupsShort, g, s.setGroup),
                const SizedBox(height: 8),
              ],
              _chips(const ['Любая', 'Керри', 'Мид', 'Хард', 'Поз. 4', 'Поз. 5'], pos, (v) => setState(() => pos = v)),
              if (mode == 0) ...[
                const SizedBox(height: 8),
                _chips(const ['Мета', 'Винрейт', 'Популярность'], sort, (v) => setState(() => sort = v)),
              ],
              const SizedBox(height: 10),
              Text(hint, style: T.small),
              const SizedBox(height: 10),
            ]);
          }
          final h = list[i - 1];
          final t = tier(scores[h.id]!, sortedScores);
          final trend = h.trendAt(g);
          Widget right;
          if (mode == 3) {
            right = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(signedPct(trend ?? 0), style: T.num(13, color: (trend ?? 0) >= 0 ? C.ally : C.enemy)),
              Text(L('за неделю', 'this week'), style: T.small.copyWith(fontSize: 10.5)),
            ]);
          } else if (mode == 1) {
            right = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(h.proPicks > 0 ? pct(h.proWr) : '—', style: T.num(14, color: h.proWr >= 0.5 ? C.ally : C.enemy)),
              Text('П ${h.proPicks} · Б ${h.proBans}', style: T.small.copyWith(fontSize: 11)),
            ]);
          } else if (mode == 2) {
            right = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(signedPct(trend ?? 0), style: T.num(14, color: (trend ?? 0) >= 0 ? C.ally : C.enemy)),
              Text('сейчас ${pct(h.wrAt(g))}', style: T.small.copyWith(fontSize: 11)),
            ]);
          } else {
            right = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (trend != null && trend.abs() >= 0.005)
                  Icon(trend > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: trend > 0 ? C.ally : C.enemy),
                Text(pct(h.wrAt(g)), style: T.num(14, color: h.wrAt(g) >= 0.5 ? C.ally : C.enemy)),
              ]),
              Text('в ${pct(h.prAt(g))} игр', style: T.small.copyWith(fontSize: 11)),
            ]);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding: const EdgeInsets.all(8),
              onTap: () => openHero(context, h),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  child: mode == 0
                      ? Text(t, textAlign: TextAlign.center, style: T.num(18, color: tierColor(t), weight: FontWeight.w800))
                      : Text('$i', textAlign: TextAlign.center, style: T.num(13, color: C.muted)),
                ),
                const SizedBox(width: 6),
                HeroImg(h, width: 64),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (s.inPool(h.id)) ...[const Icon(Icons.star, size: 13, color: C.gold), const SizedBox(width: 3)],
                      Expanded(
                        child: Text(h.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    Text(
                      mode == 3 && s.patches.isNotEmpty ? s.patches.first.forHero(h.id).first : positionsText(h),
                      maxLines: mode == 3 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.small,
                    ),
                  ]),
                ),
                right,
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
