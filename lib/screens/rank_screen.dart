import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Примерный MMR по медали (Рекрут–Древний: 154 за звезду, Божество: 200 за звезду).
int approxMmr(int tier) {
  final t = tier ~/ 10, s = (tier % 10).clamp(1, 5);
  if (t <= 0) return 0;
  if (t <= 6) return ((t - 1) * 5 + (s - 1)) * 154 + 77;
  if (t == 7) return 4620 + (s - 1) * 200 + 100;
  return 5700;
}

/// Медаль по MMR.
int tierFromMmr(int mmr) {
  if (mmr >= 5620) return 80;
  if (mmr >= 4620) return 70 + ((mmr - 4620) ~/ 200 + 1).clamp(1, 5);
  final step = (mmr ~/ 154).clamp(0, 29);
  return (step ~/ 5 + 1) * 10 + step % 5 + 1;
}

/// Отслеживание ранга и прогноз.
class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => StateScope.read(context).loadMyMatches());
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final ranked = (s.myMatches ?? const <PlayerMatch>[]).where((m) => m.ranked).toList(); // от новых к старым
    final tier = s.rankTier;
    final mmr = tier == null ? null : approxMmr(tier);
    const perGame = 25;
    final last = ranked.take(50).toList();
    final wins = last.where((m) => m.win).length;
    final wr = last.isEmpty ? 0.5 : wins / last.length;
    final per = (2 * wr - 1) * perGame;
    final in100 = mmr == null ? null : (mmr + per * 100).round();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final month = ranked.where((m) => now - m.startTime < 30 * 86400).toList();
    final monthDelta = (month.where((m) => m.win).length - month.where((m) => !m.win).length) * perGame;

    // Оценка MMR по последним рейтинговым играм (от текущего назад).
    final curve = <int>[];
    if (mmr != null && ranked.isNotEmpty) {
      var v = mmr;
      final chrono = ranked.take(80).toList();
      final pts = <int>[v];
      for (final m in chrono) {
        v -= m.win ? perGame : -perGame;
        pts.add(v);
      }
      curve.addAll(pts.reversed);
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Мой ранг', 'My rank'), style: T.h2),
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
                AppCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(L('СЕЙЧАС', 'NOW'), style: T.label),
                        const SizedBox(height: 4),
                        Text(rankName(tier), style: T.h1.copyWith(fontSize: 22)),
                        if (mmr != null) Text(L('≈ $mmr MMR', '≈ $mmr MMR'), style: T.small),
                      ]),
                    ),
                    if (in100 != null)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(L('ЧЕРЕЗ 100 ИГР', 'IN 100 GAMES'), style: T.label),
                        const SizedBox(height: 4),
                        Text(rankName(tierFromMmr(in100)), style: T.h2.copyWith(color: per >= 0 ? C.ally : C.enemy)),
                        Text('${per >= 0 ? '+' : ''}${(per * 100).round()} MMR', style: T.small),
                      ]),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(
                  L('Прогноз — если продолжишь с текущим винрейтом в рейтинге (${pct(wr, digits: 0)} за последние ${last.length} игр). '
                      'Valve скрывает точный MMR, поэтому числа примерные (±25 за игру).',
                      'Forecast — if you keep your current ranked win rate (${pct(wr, digits: 0)} over the last ${last.length} games). '
                      'Valve hides exact MMR, so numbers are approximate (±25 per game).'),
                  style: T.small,
                ),
                SectionLabel(L('За последние 30 дней', 'Last 30 days')),
                AppCard(
                  child: Row(children: [
                    _stat('${month.length}', L('рейтинговых', 'ranked')),
                    _stat('${month.where((m) => m.win).length}–${month.where((m) => !m.win).length}', L('побед–поражений', 'W–L')),
                    _stat('${monthDelta >= 0 ? '+' : ''}$monthDelta', 'MMR', color: monthDelta >= 0 ? C.ally : C.enemy),
                  ]),
                ),
                if (curve.length > 3) ...[
                  SectionLabel(L('Примерный MMR по играм', 'Estimated MMR by game')),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    child: SizedBox(height: 150, child: CustomPaint(size: Size.infinite, painter: _CurvePainter(curve))),
                  ),
                ],
                if (s.rankHistory.length > 1) ...[
                  SectionLabel(L('Изменения медали', 'Medal changes')),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final r in s.rankHistory.reversed.take(20))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Row(children: [
                            Expanded(child: Text(rankName(r[1]), style: T.body)),
                            Text(_date(r[0]), style: T.small),
                          ]),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  L('Медаль записывается каждый раз, когда обновляется профиль на вкладке «Мои герои».',
                      'The medal is recorded every time the profile is refreshed on the My heroes tab.'),
                  style: T.small,
                ),
              ],
            ),
    );
  }

  String _date(int unix) {
    final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Widget _stat(String v, String l, {Color color = C.text}) => Expanded(
        child: Column(children: [
          Text(v, style: T.num(18, color: color)),
          const SizedBox(height: 2),
          Text(l, textAlign: TextAlign.center, style: T.small),
        ]),
      );
}

class _CurvePainter extends CustomPainter {
  final List<int> v;
  _CurvePainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = v.reduce(math.min) - 50, hi = v.reduce(math.max) + 50;
    double y(int x) => size.height - (x - lo) / (hi - lo) * size.height;
    final dx = size.width / (v.length - 1);
    final p = Path()..moveTo(0, y(v[0]));
    for (var i = 1; i < v.length; i++) {
      p.lineTo(i * dx, y(v[i]));
    }
    canvas.drawPath(
        p,
        Paint()
          ..color = v.last >= v.first ? C.ally : C.enemy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (final t in [lo + 50, hi - 50]) {
      final tp = TextPainter(
        text: TextSpan(text: '$t', style: const TextStyle(color: C.muted, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y(t) - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
