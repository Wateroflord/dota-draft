import 'package:flutter/material.dart';

import '../analysis.dart';
import '../data.dart';
import '../knowledge.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
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
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: const Text('Анализ драфта', style: T.h2)),
      body: allies.isEmpty && enemies.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.insights, color: C.muted, size: 48),
                  const SizedBox(height: 12),
                  const Text('Выбери героев на вкладке «Драфт» — здесь появится разбор составов, линий и предметов.',
                      textAlign: TextAlign.center, style: T.body),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.accent),
                    onPressed: onOpenDraft,
                    child: const Text('К драфту'),
                  ),
                ]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
              children: [
                _teamsRow(allies, enemies),
                const SectionLabel('Состав твоей команды'),
                _CompositionCard(team: allies, color: C.ally),
                if (enemies.isNotEmpty) ...[
                  const SectionLabel('Состав противников'),
                  _CompositionCard(team: enemies, color: C.enemy),
                ],
                const SectionLabel('Сила по времени игры'),
                _TimeCard(curve: timeCurve(e, allies, enemies)),
                const SectionLabel('Линии'),
                _LanesCard(plan: lanes(s.data!, allies, enemies)),
                const SectionLabel('Предметы против врагов'),
                _TipsCard(tips: itemTips(enemies)),
                if (allies.isNotEmpty) ...[
                  const SectionLabel('Популярные сборки твоих героев'),
                  for (final h in allies) _BuildRow(hero: h, items: s.data!.items),
                ],
                if (allies.any((h) => (s.bench.neutral[h.id] ?? const []).isNotEmpty)) ...[
                  const SectionLabel('Нейтральные предметы'),
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
                      const Text('Самые частые нейтралки у героев твоей команды (T — уровень). Подробнее — в карточке героя.',
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
    if (team.isEmpty) return const AppCard(child: Text('Героев пока нет.', style: T.small));
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
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Состав ещё не полный — пустые пункты можно закрыть следующими пиками.', style: T.small),
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
      return const AppCard(child: Text('Данные о длительности матчей появятся после ближайшего обновления статистики.', style: T.small));
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
      advice = 'Сила команд почти не зависит от времени — играйте от карты.';
    } else if (best == 0) {
      advice = 'Твоя команда сильнее в начале. Деритесь рано и старайтесь закончить до 30 минут.';
    } else if (best == curve.length - 1) {
      advice = 'Твоя команда сильнее в поздней игре. Не рискуйте рано, фармите и защищайте вышки.';
    } else {
      advice = 'Пик силы — в середине игры (${durationLabels[best]} мин). Тогда и берите Рошана, ломайте вышки.';
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Шанс победы, если матч закончится в это время', style: T.small),
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
      return const AppCard(child: Text('Нужно хотя бы по 3 героя в каждой команде.', style: T.small));
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
        const Text('Позиции угаданы по типичным ролям героев. Оценка — по статистике противостояний этих героев.',
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
      return const AppCard(child: Text('Добавь героев противника — подскажу, какие предметы против них.', style: T.small));
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
                ? Text('${hero.name}: сборка появится после обновления данных', style: T.small)
                : Wrap(spacing: 4, runSpacing: 4, children: [for (final it in list.take(6)) ItemImg(it.key, width: 36)]),
          ),
          const Icon(Icons.chevron_right, color: C.muted, size: 18),
        ]),
      ),
    );
  }
}
