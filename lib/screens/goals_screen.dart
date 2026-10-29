import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
import 'hero_picker.dart';

/// Показатель для целей.
class GoalMetric {
  final String key;
  final String Function() title;
  final double Function(List<PlayerMatch> ms) value;
  final bool higherBetter;
  final int digits;
  const GoalMetric(this.key, this.title, this.value, {this.higherBetter = true, this.digits = 0});
}

double _avg(List<PlayerMatch> ms, double Function(PlayerMatch m) f) =>
    ms.isEmpty ? 0 : ms.map(f).reduce((a, b) => a + b) / ms.length;

final goalMetrics = <GoalMetric>[
  GoalMetric('lh10', () => L('Добивания за 10 минут', 'Last hits per 10 min'), (ms) => _avg(ms, (m) => m.lh10), digits: 1),
  GoalMetric('gpm', () => L('Золото в минуту (GPM)', 'Gold per minute (GPM)'), (ms) => _avg(ms, (m) => m.gpm.toDouble())),
  GoalMetric('xpm', () => L('Опыт в минуту (XPM)', 'XP per minute (XPM)'), (ms) => _avg(ms, (m) => m.xpm.toDouble())),
  GoalMetric('deaths', () => L('Смертей за игру', 'Deaths per game'), (ms) => _avg(ms, (m) => m.deaths.toDouble()),
      higherBetter: false, digits: 1),
  GoalMetric('kda', () => 'KDA', (ms) => _avg(ms, (m) => (m.kills + m.assists) / math.max(1, m.deaths)), digits: 2),
  GoalMetric('hdm', () => L('Урон героям в минуту', 'Hero damage per minute'), (ms) => _avg(ms, (m) => m.hdm)),
  GoalMetric('wr', () => L('Винрейт, %', 'Win rate, %'),
      (ms) => ms.isEmpty ? 0 : ms.where((m) => m.win).length / ms.length * 100, digits: 1),
];

GoalMetric metricByKey(String k) => goalMetrics.firstWhere((m) => m.key == k, orElse: () => goalMetrics.first);

/// Цели и прогресс по неделям.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => StateScope.read(context).loadMyMatches());
  }

  Future<void> _add() async {
    final s = StateScope.read(context);
    var metric = goalMetrics.first;
    int? hero;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final current = s.myMatches == null
              ? null
              : metric.value(s.myMatches!.where((m) => hero == null || m.heroId == hero).take(20).toList());
          return AlertDialog(
            backgroundColor: C.surface,
            title: Text(L('Новая цель', 'New goal'), style: T.h2),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in goalMetrics)
                    Pill(m.title(), color: C.accent, filled: metric.key == m.key, onTap: () => setD(() => metric = m)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text(
                      hero == null ? L('На любом герое', 'Any hero') : s.data!.byId[hero]?.name ?? '',
                      style: T.body,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final id = await pickHero(ctx, title: L('Герой для цели', 'Hero for the goal'));
                      setD(() => hero = id);
                    },
                    child: Text(L('Выбрать героя', 'Choose hero')),
                  ),
                  if (hero != null) IconButton(onPressed: () => setD(() => hero = null), icon: const Icon(Icons.close, size: 18)),
                ]),
                if (current != null && current > 0)
                  Text(L('Сейчас (последние 20 игр): ${fmtNum(current, metric.digits)}', 'Now (last 20 games): ${fmtNum(current, metric.digits)}'),
                      style: T.small),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: fieldDeco(L('Цель, например 60', 'Target, e.g. 60')),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Добавить', 'Add'))),
            ],
          );
        },
      ),
    );
    final t = double.tryParse(ctrl.text.replaceAll(',', '.'));
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok == true && t != null) {
      s.addGoal(Goal('${DateTime.now().microsecondsSinceEpoch}', metric.key, t, hero, DateTime.now().millisecondsSinceEpoch));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Цели и прогресс', 'Goals & progress'), style: T.h2),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))],
      ),
      body: s.accountId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L('Сначала укажи Steam ID во вкладке «Мои герои».', 'Add your Steam ID on the My heroes tab first.'),
                    textAlign: TextAlign.center, style: T.body),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
              children: [
                if (s.myMatchesLoading) const LinearProgressIndicator(color: C.accent, backgroundColor: C.surface2),
                if (s.goals.isEmpty)
                  AppCard(
                    onTap: _add,
                    child: Text(
                      L('Поставь цель — например «60 добиваний к 10-й минуте на керри» — и следи, как растут цифры неделя за неделей.',
                          'Set a goal — e.g. "60 last hits by 10 minutes" — and watch your numbers grow week by week.'),
                      style: T.body,
                    ),
                  ),
                for (final g in s.goals) _goal(s, g),
              ],
            ),
    );
  }

  Widget _goal(AppState s, Goal g) {
    final m = metricByKey(g.metric);
    final ms = (s.myMatches ?? const <PlayerMatch>[]).where((x) => g.heroId == null || x.heroId == g.heroId).toList();
    // По неделям (последние 8).
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final weeks = <double?>[];
    for (var w = 7; w >= 0; w--) {
      final from = now - (w + 1) * 7 * 86400, to = now - w * 7 * 86400;
      final list = ms.where((x) => x.startTime >= from && x.startTime < to).toList();
      weeks.add(list.isEmpty ? null : m.value(list));
    }
    final recent = ms.take(10).toList();
    final cur = recent.isEmpty ? null : m.value(recent);
    final reached = cur != null && (m.higherBetter ? cur >= g.target : cur <= g.target);
    final hero = g.heroId == null ? null : s.data!.byId[g.heroId];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        borderColor: reached ? C.ally.withValues(alpha: 0.6) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (hero != null) ...[HeroImg(hero, width: 44), const SizedBox(width: 8)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title(), style: T.body.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${L('Цель', 'Target')}: ${m.higherBetter ? '≥' : '≤'} ${fmtNum(g.target, m.digits)}'
                  '${hero == null ? '' : ' · ${hero.name}'}',
                  style: T.small,
                ),
              ]),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18, color: C.muted),
              onPressed: () => s.removeGoal(g.id),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(cur == null ? '—' : fmtNum(cur, m.digits), style: T.num(24, color: reached ? C.ally : C.text)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cur == null
                    ? L('нет матчей', 'no matches')
                    : reached
                        ? L('цель достигнута в последних ${recent.length} играх!', 'goal reached in the last ${recent.length} games!')
                        : L('сейчас (последние ${recent.length} игр)', 'now (last ${recent.length} games)'),
                style: T.small,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: CustomPaint(size: Size.infinite, painter: _WeeksPainter(weeks, g.target, m.higherBetter)),
          ),
          const SizedBox(height: 4),
          Text(L('8 недель, справа — текущая. Линия — цель.', '8 weeks, current on the right. Line — target.'), style: T.small),
        ]),
      ),
    );
  }
}

class _WeeksPainter extends CustomPainter {
  final List<double?> weeks;
  final double target;
  final bool higherBetter;
  _WeeksPainter(this.weeks, this.target, this.higherBetter);

  @override
  void paint(Canvas canvas, Size size) {
    final vals = [...weeks.whereType<double>(), target];
    final maxV = vals.reduce(math.max) * 1.15;
    if (maxV <= 0) return;
    final bw = size.width / weeks.length;
    for (var i = 0; i < weeks.length; i++) {
      final v = weeks[i];
      if (v == null) continue;
      final h = v / maxV * size.height;
      final ok = higherBetter ? v >= target : v <= target;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * bw + bw * 0.18, size.height - h, bw * 0.64, h), const Radius.circular(3)),
        Paint()..color = (ok ? C.ally : C.accent2).withValues(alpha: i == weeks.length - 1 ? 0.95 : 0.55),
      );
    }
    final ty = size.height - target / maxV * size.height;
    canvas.drawLine(Offset(0, ty), Offset(size.width, ty), Paint()
      ..color = C.gold
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _WeeksPainter old) => true;
}

/// Нужен для открытия цели из других экранов.
DHero? goalHero(AppState s, Goal g) => g.heroId == null ? null : s.data!.byId[g.heroId];
