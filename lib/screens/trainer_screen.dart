import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';

/// Тренировка драфта против бота: бот пикает контрпики, ты отвечаешь, в конце — оценка.
class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  // Порядок All Pick: 1-2-2-2-2-1 (true — команда, которая пикает первой).
  static const order = [true, false, false, true, true, false, false, true, true, false];
  final rnd = math.Random();
  bool started = false;
  bool meFirst = true;
  int level = 1; // 0 легко, 1 нормально, 2 сложно
  final List<DHero> me = [], bot = [];
  final List<(DHero, DHero?)> myPicks = []; // мой пик и лучший возможный на тот момент
  int step = 0;

  bool get myTurn => step < order.length && order[step] == meFirst;

  Engine _engine(AppState s) => Engine(s.data!, s.group);

  Set<int> get taken => {...me.map((h) => h.id), ...bot.map((h) => h.id)};

  void _start() {
    setState(() {
      started = true;
      me.clear();
      bot.clear();
      myPicks.clear();
      step = 0;
    });
    _botMoves();
  }

  void _botMoves() {
    final s = StateScope.read(context);
    final e = _engine(s);
    while (step < order.length && !myTurn) {
      final opts = e.recommend(
        allies: bot,
        enemies: me,
        unavailable: taken,
        stage: bot.isEmpty ? 1 : (bot.length >= 4 ? 3 : 2),
        limit: level == 0 ? 15 : (level == 1 ? 5 : 1),
        useComfort: false,
      );
      if (opts.isEmpty) break;
      bot.add(opts[rnd.nextInt(opts.length)].hero);
      step++;
    }
    setState(() {});
  }

  Future<void> _myPick({DHero? hero}) async {
    final s = StateScope.read(context);
    final e = _engine(s);
    final best = e
        .recommend(allies: me, enemies: bot, unavailable: taken, stage: me.isEmpty ? 1 : (me.length >= 4 ? 3 : 2), limit: 1, useComfort: false)
        .firstOrNull
        ?.hero;
    var h = hero;
    if (h == null) {
      final id = await pickHero(context, title: L('Твой пик', 'Your pick'), disabled: taken);
      if (id == null) return;
      h = s.data!.byId[id];
    }
    if (h == null) return;
    me.add(h);
    myPicks.add((h, best));
    step++;
    _botMoves();
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Тренировка драфта', 'Draft practice'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: !started ? _setup() : _game(s),
      ),
    );
  }

  List<Widget> _setup() => [
        Text(
          L('Бот выбирает героев против тебя по статистике контрпиков. Твоя задача — собрать команду, у которой шанс победы выше. '
              'Порядок как в All Pick: 1-2-2-2-2-1.',
              'The bot picks heroes against you using counter stats. Your goal is a team with a higher win chance. '
              'All Pick order: 1-2-2-2-2-1.'),
          style: T.body,
        ),
        const SizedBox(height: 14),
        Text(L('Сложность', 'Difficulty'), style: T.section),
        const SizedBox(height: 6),
        Row(children: [
          for (final l in [(0, L('Лёгкий', 'Easy')), (1, L('Нормальный', 'Normal')), (2, L('Сложный', 'Hard'))]) ...[
            Pill(l.$2, color: C.accent, filled: level == l.$1, onTap: () => setState(() => level = l.$1)),
            const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 12),
        Text(L('Кто пикает первым', 'Who picks first'), style: T.section),
        const SizedBox(height: 6),
        Row(children: [
          Pill(L('Я', 'Me'), color: C.ally, filled: meFirst, onTap: () => setState(() => meFirst = true)),
          const SizedBox(width: 6),
          Pill(L('Бот', 'Bot'), color: C.enemy, filled: !meFirst, onTap: () => setState(() => meFirst = false)),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(46)),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(L('Начать', 'Start')),
        ),
      ];

  List<Widget> _game(AppState s) {
    final e = _engine(s);
    final done = step >= order.length;
    final chance = e.winChance(me, bot);
    Widget team(String title, List<DHero> t, Color c) => AppCard(
          padding: const EdgeInsets.all(10),
          borderColor: c.withValues(alpha: 0.4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.label.copyWith(color: c)),
            const SizedBox(height: 6),
            Row(children: [
              for (var i = 0; i < 5; i++) ...[
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, cs) => i < t.length
                        ? HeroImg(t[i], width: cs.maxWidth)
                        : Container(height: cs.maxWidth * 0.5625, decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(6))),
                  ),
                ),
                if (i < 4) const SizedBox(width: 4),
              ],
            ]),
          ]),
        );
    final out = <Widget>[
      team(L('ТЫ', 'YOU'), me, C.ally),
      const SizedBox(height: 8),
      team(L('БОТ', 'BOT'), bot, C.enemy),
      const SizedBox(height: 10),
    ];
    if (!done) {
      final hints = e.recommend(allies: me, enemies: bot, unavailable: taken, stage: me.isEmpty ? 1 : (me.length >= 4 ? 3 : 2), limit: 3, useComfort: false);
      out.addAll([
        Text(L('Твой ход: пик ${me.length + 1} из 5', 'Your turn: pick ${me.length + 1} of 5'), style: T.h2),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(46)),
          onPressed: () => _myPick(),
          icon: const Icon(Icons.search),
          label: Text(L('Выбрать героя', 'Choose a hero')),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(L('Подсказка (не честно 🙂)', 'Hint (cheating 🙂)'), style: T.small),
          children: [
            for (final p in hints)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: HeroImg(p.hero, width: 54),
                title: Text(p.hero.name, style: T.body),
                trailing: Text(signedPct(p.winDelta), style: T.num(13, color: C.ally)),
                onTap: () => _myPick(hero: p.hero),
              ),
          ],
        ),
      ]);
    } else {
      final grade = chance >= 0.6
          ? 'A'
          : chance >= 0.55
              ? 'B'
              : chance >= 0.5
                  ? 'C'
                  : chance >= 0.45
                      ? 'D'
                      : 'E';
      out.addAll([
        AppCard(
          child: Row(children: [
            Text(grade, style: T.num(48, color: chance >= 0.5 ? C.ally : C.enemy)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L('Шанс победы: ${pct(chance, digits: 0)}', 'Win chance: ${pct(chance, digits: 0)}'), style: T.h2),
                Text(
                  chance >= 0.55
                      ? L('Ты переиграл бота на драфте!', 'You outdrafted the bot!')
                      : chance >= 0.5
                          ? L('Чуть лучше бота.', 'Slightly better than the bot.')
                          : L('Бот собрал команду сильнее — посмотри, что можно было взять.', 'The bot drafted better — see what you could have picked.'),
                  style: T.small,
                ),
              ]),
            ),
          ]),
        ),
        SectionLabel(L('Твои пики и лучший вариант в тот момент', 'Your picks and the best option at the time')),
        for (final p in myPicks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                HeroImg(p.$1, width: 56),
                const SizedBox(width: 8),
                Expanded(child: Text(p.$1.name, style: T.body.copyWith(fontSize: 13))),
                if (p.$2 != null && p.$2!.id != p.$1.id) ...[
                  Text('→ ', style: T.small),
                  HeroImg(p.$2!, width: 56),
                ] else
                  const Icon(Icons.check_circle, color: C.ally, size: 20),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(46)),
          onPressed: _start,
          icon: const Icon(Icons.replay),
          label: Text(L('Ещё раз', 'Again')),
        ),
      ]);
    }
    return out;
  }
}
