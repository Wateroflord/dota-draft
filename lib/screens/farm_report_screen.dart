import 'package:flutter/material.dart';

import '../coach.dart';
import '../farm.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import 'live_coach.dart';
import 'matches_screen.dart';
import 'timer_screen.dart' show mmss;

String roleName(int pos) => switch (pos) {
      1 => L('керри', 'carry'),
      2 => L('мид', 'mid'),
      3 => L('хард', 'offlane'),
      4 => L('четвёрка', 'pos 4'),
      5 => L('пятёрка', 'pos 5'),
      _ => L('роль не указана', 'no role'),
    };

/// Разбор маршрута фарма по сыгранным матчам (записи идут из Dota во время игры).
class FarmReportScreen extends StatelessWidget {
  const FarmReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Разбор маршрута фарма', 'Farm route review'), style: T.h2),
      ),
      body: ListenableBuilder(
        listenable: coach,
        builder: (context, _) {
          final list = coach.history;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  L('Здесь появятся твои матчи с маршрутом героя по карте.\n\nВключи «Живой матч» (связь с Dota 2) и сыграй игру — '
                      'приложение запишет, где ходил герой, когда умирал и сколько фармил, и после матча покажет разбор.',
                      'Your matches with the hero route will appear here.\n\nTurn on Live match (link with Dota 2) and play a game — '
                      'the app records where your hero went, deaths and farm, and shows a review after the match.'),
                  textAlign: TextAlign.center,
                  style: T.body,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            children: [
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    padding: const EdgeInsets.all(10),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FarmReportDetail(rec: r))),
                    child: Row(children: [
                      if (s.data?.byId[r.heroId] case final h?) ...[HeroImg(h, width: 56), const SizedBox(width: 10)],
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.data?.byId[r.heroId]?.name ?? '—', style: T.body.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '${_date(r.started)} · ${roleName(r.pos)} · ${mmss(r.samples.isEmpty ? 0 : r.samples.last.t)}',
                            style: T.small,
                          ),
                        ]),
                      ),
                      if (r.won != null)
                        Pill(r.won! ? L('Победа', 'Win') : L('Поражение', 'Loss'), color: r.won! ? C.ally : C.enemy),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _date(int unix) {
  final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

class FarmReportDetail extends StatefulWidget {
  final MatchRecord rec;
  const FarmReportDetail({super.key, required this.rec});

  @override
  State<FarmReportDetail> createState() => _FarmReportDetailState();
}

class _FarmReportDetailState extends State<FarmReportDetail> {
  double minute = -1; // -1 — весь матч

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final tools = ToolsScope.of(context);
    final r = widget.rec;
    final hero = s.data?.byId[r.heroId];
    final bench = hero == null ? null : s.bench.row(hero.id, s.myRankGroup)?.gpm;
    final rep = reportFor(r, benchGpm: bench);
    final radiant = r.team != 'dire';
    final camps = campsFor(radiant, tools);
    final total = r.samples.isEmpty ? 0 : r.samples.last.t;
    final trail = minute < 0 ? r.samples : r.samples.where((e) => e.t >= minute * 60 && e.t < minute * 60 + 300).toList();
    final matchId = int.tryParse(r.matchId);

    Widget bar(String label, double v, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 120, child: Text(label, style: T.small)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: v, minHeight: 8, color: c, backgroundColor: C.surface2),
              ),
            ),
            SizedBox(width: 44, child: Text('${(v * 100).round()}%', textAlign: TextAlign.right, style: T.num(12))),
          ]),
        );

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(hero?.name ?? L('Матч', 'Match'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          Text('${_date(r.started)} · ${roleName(r.pos)} · ${mmss(total)}', style: T.small),
          SectionLabel(L('Где ходил герой', 'Where your hero went')),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FarmMap(camps: camps, trail: trail, deaths: r.deaths),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text(minute < 0 ? L('Весь матч', 'Whole match') : '${mmss((minute * 60).round())}–${mmss((minute * 60 + 300).round())}',
                    style: T.small),
                Expanded(
                  child: Slider(
                    value: minute,
                    min: -1,
                    max: (total / 60).floorToDouble().clamp(0, 200),
                    divisions: (total ~/ 60 + 1).clamp(1, 200),
                    activeColor: C.accent,
                    onChanged: (v) => setState(() => minute = v),
                  ),
                ),
              ]),
              Text(L('Линия — путь героя (по 5 минут, ползунком), крестики — смерти.', 'Line — hero path (5-minute windows via the slider), crosses — deaths.'),
                  style: T.small.copyWith(fontSize: 11)),
            ]),
          ),
          SectionLabel(L('Как распределилось время', 'How the time was spent')),
          AppCard(
            child: Column(children: [
              bar(L('Линии', 'Lanes'), rep.lane, C.accent),
              bar(L('Свой лес', 'Own jungle'), rep.ownJungle, C.ally),
              bar(L('Чужой лес', 'Enemy jungle'), rep.enemyJungle, C.gold),
              bar(L('База', 'Base'), rep.base, C.muted),
              bar(L('Мёртв', 'Dead'), rep.dead, C.enemy),
              const SizedBox(height: 4),
              Row(children: [
                Text(L('Простой (стоял без фарма)', 'Idle (no farm)'), style: T.small),
                const Spacer(),
                Text(mmss(rep.idleSec), style: T.num(13, color: rep.idleSec > 120 ? C.enemy : C.text)),
              ]),
            ]),
          ),
          SectionLabel(L('Золото в минуту', 'Gold per minute')),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GpmGraph(samples: r.samples, bench: bench, height: 130),
              const SizedBox(height: 4),
              Text(
                bench == null
                    ? L('Зелёная/красная линия — твой GPM.', 'Line — your GPM.')
                    : L('Пунктир — средний GPM игроков твоего ранга на этом герое (${bench.round()}).',
                        'Dashed — average GPM of your rank on this hero (${bench.round()}).'),
                style: T.small.copyWith(fontSize: 11),
              ),
            ]),
          ),
          SectionLabel(L('Что улучшить', 'What to improve')),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final t in rep.tips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  ', style: TextStyle(color: C.accent)),
                    Expanded(child: Text(t, style: T.body.copyWith(fontSize: 13.5))),
                  ]),
                ),
            ]),
          ),
          if (r.deaths.isNotEmpty) ...[
            SectionLabel(L('Смерти', 'Deaths')),
            AppCard(
              child: Column(children: [
                for (final d in r.deaths)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Text(mmss(d.$1), style: T.num(13, color: C.enemy)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(zoneName(d.$2, d.$3, radiant), style: T.body.copyWith(fontSize: 13.5))),
                    ]),
                  ),
              ]),
            ),
          ],
          if (matchId != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MatchScreen(matchId: matchId, myHero: r.heroId, accountId: s.accountId))),
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: Text(L('Полный разбор матча', 'Full match breakdown')),
            ),
          ],
        ],
      ),
    );
  }
}
