import '../i18n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../knowledge.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';

class _Opt {
  final String label;
  final DHero? hero;
  final String? item;
  const _Opt(this.label, {this.hero, this.item});
}

class _Q {
  final String text;
  final DHero? hero;
  final List<_Opt> options;
  final int correct;
  final String explain;
  const _Q(this.text, this.hero, this.options, this.correct, this.explain);
}

/// Квиз по знанию героев на основе свежей статистики.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const total = 10;
  final rnd = math.Random();
  List<_Q> qs = [];
  int i = 0, score = 0;
  int? picked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (qs.isEmpty) _start();
  }

  void _start() {
    final s = StateScope.read(context);
    final out = <_Q>[];
    var guard = 0;
    while (out.length < total && guard++ < 200) {
      final q = _make(s);
      if (q != null && !out.any((o) => o.text == q.text)) out.add(q);
    }
    setState(() {
      qs = out;
      i = 0;
      score = 0;
      picked = null;
    });
  }

  E _pick<E>(List<E> xs) => xs[rnd.nextInt(xs.length)];

  // Герои, у которых достаточно матчей, чтобы цифры были надёжными.
  List<DHero> _pool(AppState s) => s.data!.heroes.where((h) => h.prAt(0) > 0.02).toList();

  _Q? _make(AppState s) {
    final d = s.data!;
    final e = s.engine;
    final pool = _pool(s);
    if (pool.length < 10) return null;
    switch (rnd.nextInt(5)) {
      case 0: // контрпик
        final h = _pick(pool);
        final c = e.matchups(h, best: false);
        if (c.isEmpty) return null;
        final right = c.first.$1;
        final wrong = (pool.where((x) => x.id != h.id && x.id != right.id && d.advantage(x, h) <= 0.002).toList()..shuffle(rnd))
            .take(3)
            .toList();
        if (wrong.length < 3) return null;
        final opts = [right, ...wrong]..shuffle(rnd);
        return _Q(L('Кто сильнее всего против ${h.name}?', 'Who is strongest against ${h.name}?'), h, [for (final o in opts) _Opt(o.name, hero: o)], opts.indexOf(right),
            L('${right.name} повышает шанс победы против ${h.name} на ${signedPct(d.advantage(right, h))}.', '${right.name} raises the win chance against ${h.name} by ${signedPct(d.advantage(right, h))}.'));
      case 1: // синергия
        final h = _pick(pool);
        final p = e.partners(h);
        if (p.isEmpty) return null;
        final right = p.first.$1;
        final wrong = (pool.where((x) => x.id != h.id && x.id != right.id && d.synergy(h, x) <= 0).toList()..shuffle(rnd))
            .take(3)
            .toList();
        if (wrong.length < 3) return null;
        final opts = [right, ...wrong]..shuffle(rnd);
        return _Q(L('Кто лучше всего сочетается с ${h.name} в одной команде?', 'Who works best with ${h.name} on the same team?'), h,
            [for (final o in opts) _Opt(o.name, hero: o)], opts.indexOf(right),
            L('Вместе с ${right.name} шанс победы выше на ${signedPct(d.synergy(h, right))}.', 'With ${right.name} the win chance is higher by ${signedPct(d.synergy(h, right))}.'));
      case 2: // у кого выше винрейт
        final g = s.group == 4 ? 0 : s.group;
        final four = (pool.toList()..shuffle(rnd)).take(4).toList();
        four.sort((a, b) => b.wrAt(g).compareTo(a.wrAt(g)));
        if (four[0].wrAt(g) - four[1].wrAt(g) < 0.012) return null;
        final right = four[0];
        final opts = four.toList()..shuffle(rnd);
        return _Q(L('У кого сейчас самый высокий винрейт (${rankGroupsShort[g]})?', 'Who has the highest win rate now (${rankGroupsShort[g]})?'), null,
            [for (final o in opts) _Opt(o.name, hero: o)], opts.indexOf(right),
            [for (final o in four) '${o.name} — ${pct(o.wrAt(g))}'].join('\n'));
      case 3: // позиция
        final cand = pool.where((x) => x.positions.length == 1 || x.positions.length == 2).toList();
        if (cand.isEmpty) return null;
        final h = _pick(cand);
        final right = h.positions.first;
        final opts = [1, 2, 3, 4, 5]..shuffle(rnd);
        final four = [right, ...opts.where((p) => !h.positions.contains(p)).take(3)]..shuffle(rnd);
        return _Q(L('На какой позиции чаще всего играют ${h.name}?', 'Which position is ${h.name} played in most?'), h,
            [for (final p in four) _Opt('$p — ${positionNames[p]}')], four.indexOf(right),
            '${h.name}: ${h.positions.map((p) => positionNames[p]).join(', ')}.');
      default: // предмет против героя
        final traits = [
          (invisible, const ['dust', 'gem', 'ward_sentry'], L('становится невидимым — нужна истинная видимость', 'turns invisible — you need true sight')),
          (evasion, const ['monkey_king_bar', 'bloodthorn'], L('уклоняется от атак — нужна true strike', 'evades attacks — you need true strike')),
          (breakTargets, const ['silver_edge'], L('силён за счёт пассивки — Silver Edge её выключает', 'relies on a passive — Silver Edge breaks it')),
          (illusions, const ['bfury', 'mjollnir', 'radiance'], L('создаёт иллюзии или призывы — нужен урон по области', 'creates illusions or summons — you need area damage')),
          (healers, const ['spirit_vessel', 'shivas_guard', 'skadi'], L('сильно лечится — нужно снижение лечения', 'heals a lot — you need healing reduction')),
          (singleTarget, const ['sphere', 'lotus_orb'], L('кастует опасные заклинания в цель — их можно заблокировать', 'casts dangerous targeted spells — they can be blocked')),
        ];
        final t = _pick(traits);
        final heroes = d.heroes.where((h) => t.$1.contains(h.key)).toList();
        if (heroes.isEmpty) return null;
        final h = _pick(heroes);
        // Исключаем предметы, которые тоже подходят против этого героя.
        final alsoGood = <String>{
          for (final tr in traits)
            if (tr.$1.contains(h.key)) ...tr.$2,
        };
        final right = _pick(t.$2);
        final wrong = (itemNames.keys.where((k) => !alsoGood.contains(k)).toList()..shuffle(rnd)).take(3).toList();
        final opts = [right, ...wrong]..shuffle(rnd);
        return _Q(L('Какой предмет особенно полезен против ${h.name}?', 'Which item is especially useful against ${h.name}?'), h,
            [for (final k in opts) _Opt(itemNames[k] ?? k, item: k)], opts.indexOf(right),
            '${h.name} ${t.$3}: ${t.$2.map((k) => itemNames[k] ?? k).join(', ')}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Квиз', 'Quiz'), style: T.h2),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text(L('Рекорд: ${tools.quizBest}/$total', 'Best: ${tools.quizBest}/$total'), style: T.small))),
        ],
      ),
      body: qs.isEmpty
          ? Center(child: Text(L('Не удалось составить вопросы — нет данных.', 'Could not build questions — no data.'), style: T.body))
          : i >= qs.length
              ? _result(tools)
              : _question(qs[i]),
    );
  }

  Widget _result(ToolsState tools) {
    final msg = score >= 9
        ? L('Отлично! Ты знаешь мету как про.', 'Excellent! You know the meta like a pro.')
        : score >= 6
            ? L('Хорошо! Ещё немного — и будешь драфтить как капитан.', 'Good! A little more and you will draft like a captain.')
            : L('Есть куда расти — загляни в карточки героев: там контрпики и союзники.', 'Room to grow — check hero pages for counters and allies.');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$score / ${qs.length}', style: T.num(48, color: score >= 6 ? C.ally : C.gold)),
        const SizedBox(height: 10),
        Text(msg, textAlign: TextAlign.center, style: T.body),
        const SizedBox(height: 6),
        Text(L('Рекорд: ${tools.quizBest}', 'Best: ${tools.quizBest}'), style: T.small),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.accent),
          onPressed: _start,
          icon: const Icon(Icons.replay),
          label: Text(L('Ещё раз', 'Again')),
        ),
      ]),
    );
  }

  Widget _question(_Q q) {
    final answered = picked != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(children: [
          Text(L('Вопрос ${i + 1} из ${qs.length}', 'Question ${i + 1} of ${qs.length}'), style: T.small),
          const Spacer(),
          Text(L('Счёт: $score', 'Score: $score'), style: T.small.copyWith(color: C.text)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: (i + 1) / qs.length, minHeight: 4, backgroundColor: C.surface2, color: C.accent),
        ),
        const SizedBox(height: 16),
        if (q.hero != null) ...[
          Center(child: HeroImg(q.hero!, width: 160, radius: 10)),
          const SizedBox(height: 12),
        ],
        Text(q.text, textAlign: TextAlign.center, style: T.h2),
        const SizedBox(height: 16),
        for (var k = 0; k < q.options.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(10),
              borderColor: !answered
                  ? null
                  : k == q.correct
                      ? C.ally
                      : k == picked
                          ? C.enemy
                          : null,
              color: answered && k == q.correct ? C.ally.withValues(alpha: 0.10) : null,
              onTap: answered
                  ? null
                  : () => setState(() {
                        picked = k;
                        if (k == q.correct) score++;
                      }),
              child: Row(children: [
                if (q.options[k].hero != null) ...[HeroImg(q.options[k].hero!, width: 56), const SizedBox(width: 10)],
                if (q.options[k].item != null) ...[ItemImg(q.options[k].item!, width: 44), const SizedBox(width: 10)],
                Expanded(child: Text(q.options[k].label, style: T.body.copyWith(fontWeight: FontWeight.w600))),
                if (answered && k == q.correct) const Icon(Icons.check_circle, color: C.ally),
                if (answered && k == picked && k != q.correct) const Icon(Icons.cancel, color: C.enemy),
              ]),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 6),
          AppCard(
            child: Text(L('${picked == q.correct ? 'Верно! ' : 'Не совсем. '}${q.explain}', '${picked == q.correct ? 'Correct! ' : 'Not quite. '}${q.explain}'), style: T.body.copyWith(fontSize: 13.5)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.accent),
              onPressed: () {
                setState(() {
                  i++;
                  picked = null;
                });
                if (i >= qs.length) ToolsScope.read(context).setQuizBest(score);
              },
              child: Text(i + 1 >= qs.length ? L('Результат', 'Result') : L('Дальше', 'Next')),
            ),
          ),
        ],
      ],
    );
  }
}
