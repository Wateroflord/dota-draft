import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../i18n.dart';
import '../info.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Квиз «Кто победил?»: реальные драфты про-матчей — угадай победителя.
class WhoWonScreen extends StatefulWidget {
  const WhoWonScreen({super.key});

  @override
  State<WhoWonScreen> createState() => _WhoWonScreenState();
}

class _WhoWonScreenState extends State<WhoWonScreen> {
  static const rounds = 10;
  final rnd = math.Random();
  List<ProDraft> games = [];
  int i = 0, score = 0, modelScore = 0;
  bool? pickedRadiant;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (games.isEmpty) _start();
  }

  void _start() {
    final s = StateScope.read(context);
    final all = s.proDrafts.where((g) => [...g.radiant, ...g.dire].every((id) => s.data!.byId[id] != null)).toList()..shuffle(rnd);
    setState(() {
      games = all.take(rounds).toList();
      i = 0;
      score = 0;
      modelScore = 0;
      pickedRadiant = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Кто победил?', 'Who won?'), style: T.h2),
      ),
      body: games.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L('Про-матчи ещё не загружены — обнови данные.', 'Pro matches are not loaded yet — refresh data.'),
                    textAlign: TextAlign.center, style: T.body),
              ),
            )
          : i >= games.length
              ? _result()
              : _round(games[i]),
    );
  }

  Widget _result() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$score / ${games.length}', style: T.num(48, color: score >= 6 ? C.ally : C.gold)),
          const SizedBox(height: 10),
          Text(L('А модель приложения угадала $modelScore из ${games.length}.', 'The app\'s model guessed $modelScore of ${games.length}.'),
              textAlign: TextAlign.center, style: T.body),
          const SizedBox(height: 6),
          Text(
            L('Даже лучшие аналитики угадывают по драфту около 60% — игра решает больше.',
                'Even the best analysts guess about 60% from the draft alone — the game matters more.'),
            textAlign: TextAlign.center,
            style: T.small,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.accent),
            onPressed: _start,
            icon: const Icon(Icons.replay),
            label: Text(L('Ещё раз', 'Again')),
          ),
        ]),
      );

  Widget _round(ProDraft g) {
    final s = StateScope.of(context);
    final d = s.data!;
    List<DHero> hs(List<int> ids) => ids.map((id) => d.byId[id]).whereType<DHero>().toList();
    final r = hs(g.radiant), di = hs(g.dire);
    final e = Engine(d, 3);
    final chanceR = e.winChance(r, di);
    final answered = pickedRadiant != null;

    Widget team(String name, List<DHero> t, bool radiant) {
      final won = g.radiantWin == radiant;
      final chosen = pickedRadiant == radiant;
      return AppCard(
        padding: const EdgeInsets.all(10),
        borderColor: !answered
            ? (radiant ? C.ally : C.enemy).withValues(alpha: 0.4)
            : won
                ? C.ally
                : (chosen ? C.enemy : C.border),
        onTap: answered
            ? null
            : () => setState(() {
                  pickedRadiant = radiant;
                  if (radiant == g.radiantWin) score++;
                  if ((chanceR >= 0.5) == g.radiantWin) modelScore++;
                }),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(radiant ? L('Свет', 'Radiant') : L('Тьма', 'Dire'), style: T.small),
            if (answered && won) ...[const SizedBox(width: 6), const Icon(Icons.emoji_events, color: C.gold, size: 18)],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (var k = 0; k < t.length; k++) ...[
              Expanded(child: LayoutBuilder(builder: (_, c) => HeroImg(t[k], width: c.maxWidth))),
              if (k < t.length - 1) const SizedBox(width: 4),
            ],
          ]),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      children: [
        Row(children: [
          Text(L('Матч ${i + 1} из ${games.length}', 'Match ${i + 1} of ${games.length}'), style: T.small),
          const Spacer(),
          Text(L('Счёт: $score', 'Score: $score'), style: T.small.copyWith(color: C.text)),
        ]),
        const SizedBox(height: 4),
        Text(g.league, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
        const SizedBox(height: 10),
        Text(L('Кто выиграл этот матч? Нажми на команду.', 'Who won this match? Tap a team.'), style: T.h2),
        const SizedBox(height: 10),
        team(g.radiantName, r, true),
        const SizedBox(height: 8),
        team(g.direName, di, false),
        if (answered) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              '${pickedRadiant == g.radiantWin ? L('Верно! ', 'Correct! ') : L('Не угадал. ', 'Wrong. ')}'
              '${L('Победили', 'Winner')}: ${g.radiantWin ? g.radiantName : g.direName} '
              '(${L('${g.duration ~/ 60} мин', '${g.duration ~/ 60} min')}). '
              '${L('По драфту приложение давало Свету', 'The app gave Radiant')} ${pct(chanceR, digits: 0)}.',
              style: T.body.copyWith(fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(46)),
            onPressed: () => setState(() {
              i++;
              pickedRadiant = null;
            }),
            child: Text(i + 1 >= games.length ? L('Результат', 'Result') : L('Дальше', 'Next')),
          ),
        ],
      ],
    );
  }
}
