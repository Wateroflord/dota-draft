import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
import 'hero_picker.dart';
import 'hero_screen.dart';

/// Сравнение двух героев бок о бок.
class CompareScreen extends StatefulWidget {
  final DHero? first;
  const CompareScreen({super.key, this.first});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  DHero? a, b;

  @override
  void initState() {
    super.initState();
    a = widget.first;
  }

  Future<void> _pick(bool left) async {
    final s = StateScope.read(context);
    final other = left ? b : a;
    final id = await pickHero(context, title: left ? 'Первый герой' : 'Второй герой', disabled: {if (other != null) other.id});
    if (id == null) return;
    setState(() {
      if (left) {
        a = s.data!.byId[id];
      } else {
        b = s.data!.byId[id];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final g = s.group;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Сравнение героев', style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(children: [
            Expanded(child: _slot(a, () => _pick(true))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('vs', style: T.h2)),
            Expanded(child: _slot(b, () => _pick(false))),
          ]),
          const SizedBox(height: 6),
          Text('Ранг: ${rankGroups[g]} (меняется на вкладке «Драфт»)', style: T.small),
          if (a != null && b != null) ..._body(s, a!, b!),
          if (a == null || b == null)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Text('Выбери двух героев, нажав на пустые карточки.', textAlign: TextAlign.center, style: T.small),
            ),
        ],
      ),
    );
  }

  Widget _slot(DHero? h, VoidCallback onTap) => AppCard(
        padding: const EdgeInsets.all(8),
        onTap: onTap,
        child: h == null
            ? const SizedBox(
                height: 86,
                child: Center(child: Icon(Icons.add, color: C.muted, size: 30)),
              )
            : Column(children: [
                LayoutBuilder(builder: (_, c) => HeroImg(h, width: c.maxWidth)),
                const SizedBox(height: 6),
                Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontWeight: FontWeight.w700)),
              ]),
      );

  List<Widget> _body(AppState s, DHero a, DHero b) {
    final d = s.data!;
    final g = s.group;
    final e = s.engine;
    final my = s.myRankGroup;
    final ba = s.bench.row(a.id, my), bb = s.bench.row(b.id, my);
    final rows = <(String, double, double, int, bool)>[
      ('Винрейт', a.wrAt(g) * 100, b.wrAt(g) * 100, 1, true),
      ('Популярность', a.prAt(g) * 100, b.prAt(g) * 100, 1, true),
      if (a.trendAt(g) != null && b.trendAt(g) != null) ('Тренд за неделю', a.trendAt(g)! * 100, b.trendAt(g)! * 100, 1, true),
      if (a.proPicks + b.proPicks > 0) ('Пики на про-сцене', a.proPicks.toDouble(), b.proPicks.toDouble(), 0, true),
      if (a.proPicks > 0 && b.proPicks > 0) ('Винрейт в про', a.proWr * 100, b.proWr * 100, 1, true),
      if (ba != null && bb != null) ...[
        ('Золото/мин*', ba.gpm, bb.gpm, 0, true),
        ('Опыт/мин*', ba.xpm, bb.xpm, 0, true),
        ('Добивания за 10 мин*', ba.lh10, bb.lh10, 1, true),
        ('KDA*', ba.kda, bb.kda, 2, true),
        ('Урон героям/мин*', ba.hdm, bb.hdm, 0, true),
        ('Урон по вышкам*', ba.td, bb.td, 0, true),
      ],
    ];
    final adv = d.advantage(a, b);
    final syn = d.synergy(a, b);
    final pa = s.played[a.id], pb = s.played[b.id];

    List<DHero> counters(DHero h) => e.matchups(h, best: false).take(4).map((r) => r.$1).toList();

    return [
      const SectionLabel('Друг против друга'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            adv.abs() < 0.005
                ? 'Примерно на равных в прямом противостоянии.'
                : '${adv > 0 ? a.name : b.name} сильнее в матчах друг против друга: ${signedPct(adv.abs())} к победе.',
            style: T.body,
          ),
          const SizedBox(height: 6),
          Text(
            'В одной команде: ${syn >= 0.005 ? 'хорошо сочетаются (${signedPct(syn)})' : syn <= -0.005 ? 'сочетаются плохо (${signedPct(syn)})' : 'нейтрально'}.',
            style: T.small,
          ),
        ]),
      ),
      const SectionLabel('Цифры'),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 64, child: Text(fmtNum(r.$2, r.$4), style: T.num(13.5, color: _c(r.$2, r.$3)))),
                Expanded(child: Text(r.$1, textAlign: TextAlign.center, style: T.small)),
                SizedBox(
                  width: 64,
                  child: Text(fmtNum(r.$3, r.$4), textAlign: TextAlign.right, style: T.num(13.5, color: _c(r.$3, r.$2))),
                ),
              ]),
            ),
          if (pa != null || pb != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 64, child: Text(pa == null ? '—' : '${pa[0]} / ${pct(pa[1] / pa[0], digits: 0)}', style: T.num(12))),
                const Expanded(child: Text('Твои игры / винрейт', textAlign: TextAlign.center, style: T.small)),
                SizedBox(
                    width: 64,
                    child: Text(pb == null ? '—' : '${pb[0]} / ${pct(pb[1] / pb[0], digits: 0)}', textAlign: TextAlign.right, style: T.num(12))),
              ]),
            ),
        ]),
      ),
      if (ba != null) ...[
        const SizedBox(height: 4),
        Text('* средние игроков группы «${rankGroupsShort[my]}»', style: T.small),
      ],
      if (a.dur.length == 4 && b.dur.length == 4) ...[
        const SectionLabel('Сила по времени игры'),
        AppCard(
          child: Column(children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(width: 56, child: Text(pct(a.dur[i], digits: 0), style: T.num(13, color: _c(a.dur[i], b.dur[i])))),
                  Expanded(child: _bar(a.dur[i], b.dur[i])),
                  SizedBox(
                      width: 56,
                      child: Text(pct(b.dur[i], digits: 0), textAlign: TextAlign.right, style: T.num(13, color: _c(b.dur[i], a.dur[i])))),
                ]),
              ),
            const SizedBox(height: 4),
            Row(children: [
              for (final l in durationLabels) Expanded(child: Text(l, textAlign: TextAlign.center, style: T.small.copyWith(fontSize: 10.5))),
            ]),
          ]),
        ),
      ],
      const SectionLabel('Кто их контрит'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _heroList(counters(a))),
        const SizedBox(width: 8),
        Expanded(child: _heroList(counters(b))),
      ]),
      if ((s.bench.neutral[a.id] ?? const []).isNotEmpty || (s.bench.neutral[b.id] ?? const []).isNotEmpty) ...[
        const SectionLabel('Нейтральные предметы'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: NeutralRow(hero: a, compact: true)),
          const SizedBox(width: 8),
          Expanded(child: NeutralRow(hero: b, compact: true)),
        ]),
      ],
    ];
  }

  Widget _bar(double l, double r) => LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth / 2 - 4;
        double len(double v) => ((v - 0.40) / 0.20).clamp(0.05, 1.0) * w;
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: len(l), height: 8, decoration: BoxDecoration(color: C.ally.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Container(width: len(r), height: 8, decoration: BoxDecoration(color: C.intel.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4))),
        ]);
      });

  Color _c(double mine, double other) => mine > other * 1.01 ? C.ally : (mine < other * 0.99 ? C.muted : C.text);

  Widget _heroList(List<DHero> hs) => Column(children: [
        for (final h in hs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding: const EdgeInsets.all(6),
              onTap: () => openHero(context, h),
              child: Row(children: [
                HeroImg(h, width: 44),
                const SizedBox(width: 6),
                Expanded(child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(color: C.text))),
              ]),
            ),
          ),
      ]);
}
