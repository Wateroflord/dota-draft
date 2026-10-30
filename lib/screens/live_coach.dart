import 'package:flutter/material.dart';

import '../coach.dart';
import '../data.dart';
import '../farm.dart';
import '../gsi.dart';
import '../i18n.dart';
import '../info.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import 'hero_screen.dart';
import 'timer_screen.dart' show mmss;

/// Подсказки тренера во время матча (прокачка, таланты, ТП, выкуп, предметы, варды, план по минутам).
class CoachAlertsCard extends StatelessWidget {
  final bool compact;
  const CoachAlertsCard({super.key, this.compact = false});

  static IconData _icon(String kind) => switch (kind) {
        'skill' => Icons.upgrade,
        'talent' => Icons.account_tree_outlined,
        'tp' => Icons.my_location,
        'buyback' => Icons.replay,
        'item' => Icons.shopping_bag_outlined,
        'ward' => Icons.visibility_outlined,
        _ => Icons.flag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coach,
      builder: (context, _) {
        final list = coach.alerts.take(compact ? 3 : 6).toList();
        if (list.isEmpty) return const SizedBox();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionLabel(L('Подсказки', 'Hints')),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(children: [
              for (final (i, a) in list.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(_icon(a.kind), size: compact ? 15 : 18, color: i == 0 ? C.gold : C.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.text,
                          style: T.body.copyWith(fontSize: compact ? 12 : 13.5, color: i == 0 ? C.text : C.muted)),
                    ),
                    Text(mmss(a.t), style: T.small.copyWith(fontSize: compact ? 10.5 : 11.5)),
                  ]),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Карточка героя сразу после выбора: стартовые предметы, порядок прокачки, враги.
class LiveHeroCard extends StatelessWidget {
  final DHero hero;
  final bool compact;
  const LiveHeroCard({super.key, required this.hero, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final d = s.data!;
    final info = s.info.heroes[hero.id];
    final seq = s.bench.skills[hero.id] ?? const [];
    final abil = {for (final a in info?.abilities ?? const <Ability>[]) a.id: a};
    final order = [
      for (final step in seq.take(compact ? 6 : 10))
        if (step.isNotEmpty && abil[step.first.$1] != null) abil[step.first.$1]!,
    ];
    final start = [for (final id in hero.items['s'] ?? const <int>[]) if (d.items[id] != null) d.items[id]!];
    final enemies = s.enemyHeroes;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Шпаргалка на героя', 'Hero cheat sheet')),
      AppCard(
        padding: EdgeInsets.all(compact ? 8 : 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (start.isNotEmpty) ...[
            Text(L('Старт', 'Starting items'), style: T.small),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final it in start.take(6)) Tooltip(message: it.name, child: ItemImg(it.key, width: compact ? 30 : 38)),
            ]),
            const SizedBox(height: 8),
          ],
          if (order.isNotEmpty) ...[
            Text(L('Прокачка (самая частая)', 'Skill order (most common)'), style: T.small),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final (i, a) in order.indexed)
                Tooltip(
                  message: '${i + 1}. ${a.name}',
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(a.image, width: compact ? 26 : 32, height: compact ? 26 : 32, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => SizedBox(width: compact ? 26 : 32, height: compact ? 26 : 32)),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 0,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(blurRadius: 2)])),
                    ),
                  ]),
                ),
            ]),
            const SizedBox(height: 8),
          ],
          if (enemies.isNotEmpty) ...[
            Text(L('Враги — нажми, чтобы узнать, как против них играть', 'Enemies — tap to see how to play against them'), style: T.small),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final e in enemies)
                GestureDetector(onTap: () => openHero(context, e), child: HeroImg(e, width: compact ? 40 : 52, radius: 4)),
            ]),
          ],
          if (start.isEmpty && order.isEmpty && enemies.isEmpty) Text(L('Нет данных по герою', 'No hero data'), style: T.small),
        ]),
      ),
    ]);
  }
}

/// Журнал смертей текущего матча: когда и где.
class DeathLogCard extends StatelessWidget {
  final bool compact;
  const DeathLogCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final rec = coach.current;
    if (rec == null || rec.deaths.isEmpty) return const SizedBox();
    final radiant = rec.team != 'dire';
    final enemyJ = rec.deaths.where((d) => zoneName(d.$2, d.$3, radiant) == L('в чужом лесу', 'enemy jungle')).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Смерти (${rec.deaths.length})', 'Deaths (${rec.deaths.length})')),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final d in rec.deaths.reversed.take(compact ? 3 : 8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Text(mmss(d.$1), style: T.num(compact ? 11.5 : 13, color: C.enemy)),
                const SizedBox(width: 10),
                Expanded(child: Text(zoneName(d.$2, d.$3, radiant), style: T.body.copyWith(fontSize: compact ? 12 : 13.5))),
              ]),
            ),
          if (enemyJ >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(L('$enemyJ смерти в чужом лесу — заходи туда только с вардами или командой.',
                  '$enemyJ deaths in the enemy jungle — go there only with wards or your team.'), style: T.small.copyWith(color: C.gold)),
            ),
        ]),
      ),
    ]);
  }
}

/// График золота в минуту по ходу матча против среднего на герое.
class GpmGraph extends StatelessWidget {
  final List<Sample> samples;
  final double? bench;
  final double height;
  const GpmGraph({super.key, required this.samples, this.bench, this.height = 110});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(painter: _GpmPainter(samples, bench, C.border, C.muted), size: Size.infinite),
      );
}

class _GpmPainter extends CustomPainter {
  final List<Sample> s;
  final double? bench;
  final Color grid, label;
  _GpmPainter(this.s, this.bench, this.grid, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = s.where((e) => e.t > 60).toList();
    if (pts.length < 2) return;
    final maxT = pts.last.t.toDouble();
    final maxV = [...pts.map((e) => e.gpm.toDouble()), bench ?? 0].reduce((a, b) => a > b ? a : b) * 1.15 + 1;
    Offset at(num t, num v) => Offset(t / maxT * size.width, size.height - v / maxV * size.height);
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    if (bench != null) {
      final p = Paint()
        ..color = C.gold
        ..strokeWidth = 1.5;
      final y = at(0, bench!).dy;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
      }
    }
    final path = Path()..moveTo(at(pts.first.t, pts.first.gpm).dx, at(pts.first.t, pts.first.gpm).dy);
    for (final e in pts.skip(1)) {
      final o = at(e.t, e.gpm);
      path.lineTo(o.dx, o.dy);
    }
    final good = bench == null || pts.last.gpm >= bench!;
    canvas.drawPath(
        path,
        Paint()
          ..color = good ? C.ally : C.enemy
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    final tp = TextPainter(
      text: TextSpan(text: '${maxV.round()}', style: TextStyle(fontSize: 9, color: label)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(2, 0));
  }

  @override
  bool shouldRepaint(covariant _GpmPainter old) => true;
}

/// Золото в минуту сейчас против среднего игрока твоего ранга на этом герое.
class LiveGpmCard extends StatelessWidget {
  final DHero? hero;
  final bool compact;
  const LiveGpmCard({super.key, this.hero, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final rec = coach.current;
    if (rec == null || rec.samples.where((e) => e.t > 60).length < 3) return const SizedBox();
    final bench = hero == null ? null : s.bench.row(hero!.id, s.myRankGroup)?.gpm;
    final now = rec.samples.last.gpm;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Золото в минуту', 'Gold per minute')),
      AppCard(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$now GPM', style: T.num(compact ? 14 : 16, color: bench == null || now >= bench ? C.ally : C.enemy)),
            const Spacer(),
            if (bench != null) Text(L('средний: ${bench.round()}', 'average: ${bench.round()}'), style: T.small.copyWith(color: C.gold)),
          ]),
          const SizedBox(height: 6),
          GpmGraph(samples: rec.samples, bench: bench, height: compact ? 70 : 110),
        ]),
      ),
    ]);
  }
}

/// Маршрут фарма в реальном времени: куда идти дальше с учётом роли и позиции героя.
class LiveFarmCard extends StatelessWidget {
  final GsiState g;
  final bool compact;
  const LiveFarmCard({super.key, required this.g, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final tools = ToolsScope.of(context);
    final radiant = g.team != 'dire';
    final camps = campsFor(radiant, tools);
    final pos = g.mapPos;
    final clock = g.clock ?? 0;
    final rec = coach.current;
    final role = s.myPos >= 1 && s.myPos <= 3 ? s.myPos : roleFor(rec, s.myPos, radiant);
    final farmed = rec == null ? <String>{} : farmedThisMinute(rec.samples, camps, clock);
    final plan = pos == null ? null : planFarm(x: pos.$1, y: pos.$2, clock: clock, role: role, camps: camps, farmed: farmed);
    final trail = rec == null ? const <Sample>[] : rec.samples.where((e) => e.t >= clock - 90).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Маршрут фарма', 'Farm route')),
      Wrap(spacing: 6, children: [
        for (final r in [(1, L('Керри', 'Carry')), (2, L('Мид', 'Mid')), (3, L('Хард', 'Offlane'))])
          Pill(r.$2, color: C.accent, filled: role == r.$1, onTap: () => s.setMyPos(r.$1)),
      ]),
      const SizedBox(height: 6),
      if (pos == null)
        Text(L('Позиция героя пока не пришла из Dota.', 'Hero position has not arrived from Dota yet.'), style: T.small)
      else
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 230 : 360),
                child: FarmMap(x: pos.$1, y: pos.$2, camps: camps, farmed: farmed, route: plan!.route, trail: trail),
              ),
            ),
            const SizedBox(height: 6),
            for (final (i, c) in plan.route.indexed)
              Text('${i + 1}. ${c.title}', style: T.body.copyWith(fontSize: compact ? 12 : 13.5)),
            const SizedBox(height: 4),
            Text(plan.tip, style: T.small.copyWith(color: C.gold, fontSize: compact ? 11 : 12)),
          ]),
        ),
    ]);
  }
}
