import 'package:flutter/material.dart';

import '../analysis.dart';
import '../data.dart';
import '../knowledge.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
import '../i18n.dart';
import 'hero_screen.dart';

/// Вкладка «Анализ»: состав, сила по времени, линии, предметы.
class AnalysisScreen extends StatelessWidget {
  final VoidCallback onOpenDraft;
  const AnalysisScreen({super.key, required this.onOpenDraft});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final allies = s.allyHeroes, enemies = s.enemyHeroes;
    final e = s.engine;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: Text(L('Анализ драфта', 'Draft analysis'), style: T.h2)),
      body: allies.isEmpty && enemies.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.insights, color: C.muted, size: 48),
                  const SizedBox(height: 12),
                  Text(L('Выбери героев на вкладке «Драфт» — здесь появится разбор составов, линий и предметов.', 'Pick heroes on the Draft tab — the lineup, lanes and items breakdown will appear here.'),
                      textAlign: TextAlign.center, style: T.body),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.accent),
                    onPressed: onOpenDraft,
                    child: Text(L('К драфту', 'To the draft')),
                  ),
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
              children: [
                _teamsRow(allies, enemies),
                SectionLabel(L('Состав твоей команды', 'Your team lineup')),
                _CompositionCard(team: allies, color: C.ally),
                if (enemies.isNotEmpty) ...[
                  SectionLabel(L('Состав противников', 'Enemy lineup')),
                  _CompositionCard(team: enemies, color: C.enemy),
                ],
                _CombosCard(allies: allies, enemies: enemies),
                SectionLabel(L('Сила по времени игры', 'Strength by game time')),
                _TimeCard(curve: timeCurve(e, allies, enemies)),
                SectionLabel(L('Линии', 'Lanes')),
                _LanesCard(plan: lanes(s.data!, allies, enemies)),
                SectionLabel(L('Предметы против врагов', 'Items against the enemies')),
                _TipsCard(tips: itemTips(enemies)),
                if (allies.isNotEmpty) ...[
                  SectionLabel(L('Популярные сборки твоих героев', 'Popular builds of your heroes')),
                  for (final h in allies) _BuildRow(hero: h, items: s.data!.items),
                ],
                if (allies.any((h) => (s.bench.neutral[h.id] ?? const []).isNotEmpty)) ...[
                  SectionLabel(L('Нейтральные предметы', 'Neutral items')),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final h in allies)
                        if ((s.bench.neutral[h.id] ?? const []).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              HeroImg(h, width: 54),
                              const SizedBox(width: 10),
                              Expanded(child: NeutralRow(hero: h, compact: true)),
                            ]),
                          ),
                      const SizedBox(height: 4),
                      Text(L('Самые частые нейтралки у героев твоей команды (T — уровень). Подробнее — в карточке героя.', 'Most common neutral items of your team (T — tier). More in the hero page.'),
                          style: T.small),
                    ]),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _teamsRow(List<DHero> a, List<DHero> e) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(children: [
          Row(children: [
            for (final h in a) ...[HeroImg(h, width: 50), const SizedBox(width: 4)],
            const Spacer(),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (final h in e) ...[HeroImg(h, width: 50), const SizedBox(width: 4)],
            const Spacer(),
          ]),
        ]),
      );
}

class _CompositionCard extends StatelessWidget {
  final List<DHero> team;
  final Color color;
  const _CompositionCard({required this.team, required this.color});

  @override
  Widget build(BuildContext context) {
    if (team.isEmpty) return AppCard(child: Text(L('Героев пока нет.', 'No heroes yet.'), style: T.small));
    final c = analyzeTeam(team);
    return AppCard(
      borderColor: color.withValues(alpha: 0.35),
      child: Column(children: [
        for (final ch in c.checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                ch.level == 2 ? Icons.check_circle : (ch.level == 1 ? Icons.remove_circle_outline : Icons.warning_amber_rounded),
                size: 18,
                color: ch.level == 2 ? C.ally : (ch.level == 1 ? C.gold : C.enemy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ch.title, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(ch.detail, style: T.small),
                ]),
              ),
            ]),
          ),
        if (team.length < 5)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(L('Состав ещё не полный — пустые пункты можно закрыть следующими пиками.', 'The lineup is not complete — missing points can be covered by the next picks.'), style: T.small),
          ),
      ]),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final List<double> curve;
  const _TimeCard({required this.curve});

  @override
  Widget build(BuildContext context) {
    if (curve.isEmpty) {
      return AppCard(child: Text(L('Данные о длительности матчей появятся после ближайшего обновления статистики.', 'Match duration data will appear after the next stats update.'), style: T.small));
    }
    var best = 0;
    for (var i = 1; i < curve.length; i++) {
      if (curve[i] > curve[best]) best = i;
    }
    var worst = 0;
    for (var i = 1; i < curve.length; i++) {
      if (curve[i] < curve[worst]) worst = i;
    }
    final String advice;
    if (curve[best] - curve[worst] < 0.03) {
      advice = L('Сила команд почти не зависит от времени — играйте от карты.', 'Team strength barely depends on time — play the map.');
    } else if (best == 0) {
      advice = L('Твоя команда сильнее в начале. Деритесь рано и старайтесь закончить до 30 минут.', 'Your team is stronger early. Fight early and try to finish before 30 minutes.');
    } else if (best == curve.length - 1) {
      advice = L('Твоя команда сильнее в поздней игре. Не рискуйте рано, фармите и защищайте вышки.', 'Your team is stronger late. Avoid early risks, farm and defend towers.');
    } else {
      advice = L('Пик силы — в середине игры (${durationLabels[best]} мин). Тогда и берите Рошана, ломайте вышки.', 'Peak strength is mid game (${durationLabels[best]} min). Take Roshan and towers then.');
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L('Шанс победы, если матч закончится в это время', 'Win chance if the match ends at this time'), style: T.small),
        const SizedBox(height: 10),
        ChanceBars(values: curve, labels: durationLabels),
        const SizedBox(height: 10),
        Text(advice, style: T.body.copyWith(fontSize: 13.5)),
      ]),
    );
  }
}

class _LanesCard extends StatelessWidget {
  final LanePlan plan;
  const _LanesCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    if (plan.lanes.isEmpty) {
      return AppCard(child: Text(L('Нужно хотя бы по 3 героя в каждой команде.', 'Need at least 3 heroes on each team.'), style: T.small));
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in plan.lanes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.name, style: T.section)),
                if (l.ours.isNotEmpty && l.theirs.isNotEmpty)
                  Text(signedPct(l.score), style: T.num(14, color: l.score >= 0 ? C.ally : C.enemy)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                for (final h in l.ours) ...[HeroImg(h, width: 48), const SizedBox(width: 3)],
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('vs', style: T.small)),
                for (final h in l.theirs) ...[HeroImg(h, width: 48), const SizedBox(width: 3)],
              ]),
            ]),
          ),
        if (plan.tip != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline, color: C.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(plan.tip!, style: T.body.copyWith(fontSize: 13))),
          ]),
        ],
        const SizedBox(height: 6),
        Text(L('Позиции угаданы по типичным ролям героев. Оценка — по статистике противостояний этих героев.', 'Positions are guessed from typical hero roles. The estimate uses matchup stats of these heroes.'),
            style: T.small),
      ]),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final List<ItemTip> tips;
  const _TipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) {
      return AppCard(child: Text(L('Добавь героев противника — подскажу, какие предметы против них.', 'Add enemy heroes — I will suggest items against them.'), style: T.small));
    }
    return Column(children: [
      for (final t in tips)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: T.section),
              const SizedBox(height: 2),
              Text(t.reason, style: T.small),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in t.items)
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    ItemImg(k, width: 44),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 64,
                      child: Text(itemNames[k] ?? k,
                          maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: C.muted)),
                    ),
                  ]),
              ]),
            ]),
          ),
        ),
    ]);
  }
}

class _BuildRow extends StatelessWidget {
  final DHero hero;
  final Map<int, DItem> items;
  const _BuildRow({required this.hero, required this.items});

  @override
  Widget build(BuildContext context) {
    final ids = [...?hero.items['m'], ...?hero.items['l']];
    final list = <DItem>[];
    for (final id in ids) {
      final it = items[id];
      if (it != null && !list.any((x) => x.id == id)) list.add(it);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: () => openHero(context, hero),
        child: Row(children: [
          HeroImg(hero, width: 56),
          const SizedBox(width: 10),
          Expanded(
            child: list.isEmpty
                ? Text(L('${hero.name}: сборка появится после обновления данных', '${hero.name}: build will appear after a data update'), style: T.small)
                : Wrap(spacing: 4, runSpacing: 4, children: [for (final it in list.take(6)) ItemImg(it.key, width: 36)]),
          ),
          const Icon(Icons.chevron_right, color: C.muted, size: 18),
        ]),
      ),
    );
  }
}


/// Известные связки у нас и у врагов, плюс кого можно добавить для связки.
class _CombosCard extends StatelessWidget {
  final List<DHero> allies, enemies;
  const _CombosCard({required this.allies, required this.enemies});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final ours = combosIn(allies.map((h) => h.key));
    final theirs = combosIn(enemies.map((h) => h.key));
    final byKey = {for (final h in s.data!.heroes) h.key: h};
    final taken = s.unavailable;
    final possible = <(DHero, DHero, Combo)>[];
    if (allies.length < 5) {
      for (final c in combos) {
        for (final pair in [(c.a, c.b), (c.b, c.a)]) {
          final have = allies.where((h) => h.key == pair.$1).firstOrNull;
          final add = byKey[pair.$2];
          if (have != null && add != null && !taken.contains(add.id)) possible.add((have, add, c));
        }
      }
    }
    if (ours.isEmpty && theirs.isEmpty && possible.isEmpty) return const SizedBox.shrink();
    Widget row(Combo c, Color color, String prefix) {
      final a = byKey[c.a], b = byKey[c.b];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (a != null) HeroImg(a, width: 40),
          const SizedBox(width: 3),
          if (b != null) HeroImg(b, width: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$prefix${c.why}', style: T.body.copyWith(fontSize: 12.5, color: color)),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Связки героев', 'Hero combos')),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final c in theirs) row(c, C.enemy, L('Осторожно: ', 'Watch out: ')),
          for (final c in ours) row(c, C.ally, ''),
          for (final p in possible.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                HeroImg(p.$2, width: 40),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L('Можно взять ${p.$2.name} — связка с ${p.$1.name}: ${p.$3.why}',
                        'Consider ${p.$2.name} — combo with ${p.$1.name}: ${p.$3.why}'),
                    style: T.body.copyWith(fontSize: 12.5, color: C.gold),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
