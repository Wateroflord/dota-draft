import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';

/// Шаг драфта Captains Mode: бан или пик, команда A (первый пик) или B.
class CmStep {
  final bool pick;
  final bool teamA;
  const CmStep(this.pick, this.teamA);
}

// Порядок Captains Mode (с патча 7.34): баны 7 → пики 2 → баны 3 → пики 6 → баны 4 → пики 2.
const cmOrder = <CmStep>[
  CmStep(false, true), CmStep(false, false), CmStep(false, false), CmStep(false, true), //
  CmStep(false, false), CmStep(false, false), CmStep(false, true),
  CmStep(true, true), CmStep(true, false),
  CmStep(false, true), CmStep(false, true), CmStep(false, false),
  CmStep(true, false), CmStep(true, true), CmStep(true, true), CmStep(true, false), CmStep(true, false), CmStep(true, true),
  CmStep(false, true), CmStep(false, false), CmStep(false, true), CmStep(false, false),
  CmStep(true, true), CmStep(true, false),
];

/// Captains Mode: подсказки на каждый ход по очереди драфта.
class CmScreen extends StatefulWidget {
  const CmScreen({super.key});

  @override
  State<CmScreen> createState() => _CmScreenState();
}

class _CmScreenState extends State<CmScreen> {
  bool started = false;
  bool weFirst = true;
  int step = 0;
  final List<(int, CmStep, bool)> done = []; // hero, шаг, наш ли ход
  final Map<int, bool> flipped = {}; // если в игре порядок отличается — можно поменять, кто ходит
  Timer? timer;
  int left = 30;
  int reserveUs = 130, reserveThem = 130;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  bool ourTurn(int i) {
    final st = cmOrder[i];
    final us = st.teamA == weFirst;
    return (flipped[i] ?? false) ? !us : us;
  }

  void _startTimer() {
    timer?.cancel();
    left = step < 7 ? 15 : 30;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || step >= cmOrder.length) return;
      setState(() {
        if (left > 0) {
          left--;
        } else if (ourTurn(step)) {
          if (reserveUs > 0) reserveUs--;
        } else {
          if (reserveThem > 0) reserveThem--;
        }
      });
    });
  }

  void _start() {
    final s = StateScope.read(context);
    s.clear();
    setState(() {
      started = true;
      step = 0;
      done.clear();
      flipped.clear();
      reserveUs = 130;
      reserveThem = 130;
    });
    _startTimer();
  }

  void _apply(int heroId) {
    final s = StateScope.read(context);
    final st = cmOrder[step];
    final us = ourTurn(step);
    if (st.pick) {
      if (!s.add(us, heroId)) {
        showToast(context, L('В команде уже 5 героев', 'Team already has 5 heroes'));
        return;
      }
    } else {
      if (!s.bans.contains(heroId)) s.toggleBan(heroId);
    }
    setState(() {
      done.add((heroId, st, us));
      step++;
    });
    if (step < cmOrder.length) {
      _startTimer();
    } else {
      timer?.cancel();
    }
  }

  void _undo() {
    if (done.isEmpty) return;
    final s = StateScope.read(context);
    final last = done.removeLast();
    if (last.$2.pick) {
      final list = last.$3 ? s.allies : s.enemies;
      final i = list.indexOf(last.$1);
      if (i >= 0) s.setSlot(last.$3, i, null);
    } else {
      if (s.bans.contains(last.$1)) s.toggleBan(last.$1);
    }
    setState(() => step--);
    _startTimer();
  }

  Future<void> _pickOther() async {
    final s = StateScope.read(context);
    final st = cmOrder[step];
    final id = await pickHero(context,
        title: st.pick
            ? (ourTurn(step) ? L('Наш пик', 'Our pick') : L('Пик противника', 'Enemy pick'))
            : (ourTurn(step) ? L('Наш бан', 'Our ban') : L('Бан противника', 'Enemy ban')),
        disabled: s.unavailable);
    if (id != null) _apply(id);
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Captains Mode', style: T.h2),
        actions: [
          if (started && done.isNotEmpty)
            IconButton(tooltip: L('Отменить ход', 'Undo'), icon: const Icon(Icons.undo), onPressed: _undo),
        ],
      ),
      body: !started ? _setup() : _draft(s),
    );
  }

  Widget _setup() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            L('Пошаговый драфт как в турнирах: 7 банов → 2 пика → 3 бана → 6 пиков → 4 бана → 2 пика. '
                'На твоём ходу — советы, кого банить или брать. На ходу соперника отмечаешь, что они выбрали.',
                'Tournament-style draft: 7 bans → 2 picks → 3 bans → 6 picks → 4 bans → 2 picks. '
                'On your turn you get ban/pick advice. On the enemy turn you mark what they chose.'),
            style: T.body,
          ),
          const SizedBox(height: 16),
          Text(L('Кто выбирает первым?', 'Who has first pick?'), style: T.section),
          const SizedBox(height: 8),
          Row(children: [
            Pill(L('Мы', 'Us'), color: C.ally, filled: weFirst, onTap: () => setState(() => weFirst = true)),
            const SizedBox(width: 8),
            Pill(L('Соперники', 'Them'), color: C.enemy, filled: !weFirst, onTap: () => setState(() => weFirst = false)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.accent),
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(L('Начать (текущий драфт очистится)', 'Start (current draft will be cleared)')),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            L('Если в игре порядок окажется другим — на каждом шаге можно поменять, чей ход (значок ⇄).',
                'If the in-game order differs, you can switch whose turn it is on any step (⇄ icon).'),
            style: T.small,
          ),
        ],
      );

  Widget _draft(AppState s) {
    final e = s.engine;
    final allies = s.allyHeroes, enemies = s.enemyHeroes;
    final chance = e.winChance(allies, enemies);
    final finished = step >= cmOrder.length;
    final st = finished ? null : cmOrder[step];
    final us = finished ? false : ourTurn(step);

    List<Pick> options = const [];
    if (!finished) {
      if (st!.pick) {
        final a = us ? allies : enemies, en = us ? enemies : allies;
        options = us
            ? e.recommend(
                allies: a,
                enemies: en,
                unavailable: s.unavailable,
                stage: a.isEmpty ? 1 : (a.length >= 4 ? 3 : 2),
                limit: 8,
                myPos: s.myPos)
            : e.threats(allies: allies, enemies: enemies, unavailable: s.unavailable, limit: 8);
      } else {
        options = us
            ? e.threats(allies: allies, enemies: enemies, unavailable: s.unavailable, limit: 8)
            : e.recommend(allies: allies, enemies: enemies, unavailable: s.unavailable, stage: 1, limit: 8, useComfort: false);
      }
    }

    String hint() {
      if (st == null) return '';
      if (st.pick && us) return L('Наш пик — лучшие варианты:', 'Our pick — best options:');
      if (st.pick) return L('Пик соперника — скорее всего возьмут:', 'Enemy pick — likely choices:');
      if (us) return L('Наш бан — самые опасные для нас:', 'Our ban — most dangerous for us:');
      return L('Бан соперника — что могут забанить у нас:', 'Enemy ban — what they may ban from us:');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          borderColor: finished ? C.gold : (us ? C.ally : C.enemy).withValues(alpha: 0.6),
          child: finished
              ? Row(children: [
                  Text(L('Драфт завершён', 'Draft finished'), style: T.h2),
                  const Spacer(),
                  Text(pct(chance, digits: 0), style: T.num(26, color: chance >= 0.5 ? C.ally : C.enemy)),
                ])
              : Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(L('ШАГ ${step + 1} ИЗ ${cmOrder.length}', 'STEP ${step + 1} OF ${cmOrder.length}'), style: T.label),
                      const SizedBox(height: 4),
                      Text(
                        '${st!.pick ? L('Пик', 'Pick') : L('Бан', 'Ban')} · ${us ? L('мы', 'us') : L('соперники', 'enemy')}',
                        style: T.h2.copyWith(color: us ? C.ally : C.enemy),
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: L('Поменять, чей ход', 'Switch whose turn'),
                    icon: const Icon(Icons.swap_horiz, color: C.muted),
                    onPressed: () => setState(() => flipped[step] = !(flipped[step] ?? false)),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$left', style: T.num(26, color: left <= 5 ? C.enemy : C.text)),
                    Text(L('резерв ${us ? reserveUs : reserveThem} с', 'reserve ${us ? reserveUs : reserveThem}s'),
                        style: T.small),
                  ]),
                ]),
        ),
        const SizedBox(height: 8),
        _teams(s, allies, enemies, chance),
        if (!finished) ...[
          SectionLabel(hint()),
          for (final p in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.all(8),
                onTap: () => _apply(p.hero.id),
                child: Row(children: [
                  HeroImg(p.hero, width: 64),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (p.mine) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.star, size: 14, color: C.gold)),
                        Expanded(child: Text(p.hero.name, style: T.body.copyWith(fontWeight: FontWeight.w700))),
                      ]),
                      if (p.reasons.isNotEmpty)
                        Text(
                          p.reasons.take(2).map((r) => r.kind == 0
                              ? (r.value > 0 ? L('силён против ${r.hero.name}', 'strong vs ${r.hero.name}') : L('слаб против ${r.hero.name}', 'weak vs ${r.hero.name}'))
                              : L('хорошо с ${r.hero.name}', 'good with ${r.hero.name}')).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.small.copyWith(fontSize: 11.5),
                        ),
                    ]),
                  ),
                  Text(signedPct(us && st!.pick ? p.winDelta : -p.winDelta),
                      style: T.num(13, color: (us && st!.pick) ? C.ally : C.enemy)),
                ]),
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: C.border), minimumSize: const Size.fromHeight(44)),
            onPressed: _pickOther,
            icon: const Icon(Icons.search, size: 18),
            label: Text(us ? L('Выбрать другого героя', 'Choose another hero') : L('Что выбрал соперник?', 'What did they choose?')),
          ),
        ],
        if (finished) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(46)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L('Открыть разбор на вкладке «Драфт»', 'Open the result on the Draft tab')),
          ),
        ],
        const SizedBox(height: 14),
        _timeline(s),
      ],
    );
  }

  Widget _teams(AppState s, List<DHero> allies, List<DHero> enemies, double chance) {
    Widget row(List<DHero> hs, Color c) => Row(children: [
          for (var i = 0; i < 5; i++) ...[
            Expanded(
              child: LayoutBuilder(
                builder: (_, cs) => i < hs.length
                    ? HeroImg(hs[i], width: cs.maxWidth)
                    : Container(
                        height: cs.maxWidth * 0.5625,
                        decoration: BoxDecoration(
                            color: C.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.3))),
                      ),
              ),
            ),
            if (i < 4) const SizedBox(width: 4),
          ],
        ]);
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(L('МЫ', 'US'), style: T.label.copyWith(color: C.ally)),
          const Spacer(),
          if (allies.isNotEmpty || enemies.isNotEmpty)
            Text(L('шанс ${pct(chance, digits: 0)}', 'chance ${pct(chance, digits: 0)}'),
                style: T.num(13, color: chance >= 0.5 ? C.ally : C.enemy)),
        ]),
        const SizedBox(height: 4),
        row(allies, C.ally),
        const SizedBox(height: 8),
        Text(L('СОПЕРНИКИ', 'ENEMY'), style: T.label.copyWith(color: C.enemy)),
        const SizedBox(height: 4),
        row(enemies, C.enemy),
      ]),
    );
  }

  Widget _timeline(AppState s) => Wrap(spacing: 4, runSpacing: 4, children: [
        for (var i = 0; i < cmOrder.length; i++)
          Builder(builder: (_) {
            final d = i < done.length ? done[i] : null;
            final h = d == null ? null : s.data!.byId[d.$1];
            final us = d?.$3 ?? ourTurn(i);
            final color = us ? C.ally : C.enemy;
            return Container(
              width: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: i == step ? Colors.white : color.withValues(alpha: 0.5), width: i == step ? 1.6 : 1),
              ),
              child: Column(children: [
                h == null
                    ? SizedBox(
                        height: 20,
                        child: Center(
                            child: Text(cmOrder[i].pick ? 'P' : 'B',
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800))),
                      )
                    : HeroImg(h, width: 36, radius: 3, dim: !cmOrder[i].pick),
              ]),
            );
          }),
      ]);
}
