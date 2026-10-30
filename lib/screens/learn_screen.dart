import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';

class _Cand {
  final DHero h;
  final double score;
  final List<String> why;
  _Cand(this.h, this.score, this.why);
}

/// «Какого героя выучить»: сильный в мете на твоей позиции, контрит тех, против кого ты проигрываешь, и дополняет твой пул.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int? pos;

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final d = s.data!;
    final e = s.engine;
    final p = pos ?? (s.myPos == 0 ? 1 : s.myPos);
    // Мои «немезиды»: против них я играл 4+ раз с винрейтом ниже 45%.
    final nemesis = <DHero, double>{};
    s.vsHeroes.forEach((id, v) {
      if (v.length < 4) return;
      final g = v[2], w = v[3];
      if (g < 4) return;
      final wr = w / g;
      final h = d.byId[id];
      if (h != null && wr < 0.45) nemesis[h] = (0.5 - wr) * g;
    });
    final top = nemesis.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final nem = top.take(8).toList();
    final pool = [for (final id in s.pool) if (d.byId[id] != null) d.byId[id]!];

    final cands = <_Cand>[];
    for (final h in d.heroes) {
      if (!h.positions.contains(p)) continue;
      if (s.inPool(h.id) || (s.played[h.id]?[0] ?? 0) >= 15) continue;
      final why = <String>[];
      final meta = e.wr(h) - 0.5;
      var score = meta * 4;
      if (meta > 0.01) why.add(L('силён в мете: ${pct(e.wr(h))} побед на твоём ранге', 'strong in the meta: ${pct(e.wr(h))} win rate at your rank'));
      // Контрит моих немезид.
      var counter = 0.0;
      final beats = <String>[];
      for (final n in nem) {
        final a = d.advantage(h, n.key);
        counter += a * n.value;
        if (a > 0.015) beats.add(n.key.name);
      }
      score += counter;
      if (beats.isNotEmpty) why.add(L('контрит тех, кто тебя обыгрывает: ${beats.take(3).join(', ')}', 'counters heroes that beat you: ${beats.take(3).join(', ')}'));
      // Связки с моими героями.
      var syn = 0.0;
      for (final m in pool) {
        syn += d.synergy(h, m);
      }
      if (pool.isNotEmpty) {
        syn /= pool.length;
        score += syn * 2;
        if (syn > 0.01) why.add(L('хорошо сочетается с твоими героями', 'pairs well with your heroes'));
      }
      final trend = h.trendAt(s.group);
      if (trend != null && trend > 0.01) {
        score += trend;
        why.add(L('растёт за неделю: ${signedPct(trend)}', 'rising this week: ${signedPct(trend)}'));
      }
      if ((s.played[h.id]?[0] ?? 0) > 0) why.add(L('ты уже пробовал: ${s.played[h.id]![0]} игр', 'you tried it: ${s.played[h.id]![0]} games'));
      cands.add(_Cand(h, score, why));
    }
    cands.sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Какого героя выучить', 'Which hero to learn'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          Wrap(spacing: 6, children: [
            for (final x in [1, 2, 3, 4, 5]) Pill(L('Поз. $x', 'Pos. $x'), color: C.accent, filled: p == x, onTap: () => setState(() => pos = x)),
          ]),
          const SizedBox(height: 8),
          Text(
            nem.isEmpty
                ? L('Подбор по мете и твоим героям. Укажи Steam ID во вкладке «Мои герои» — тогда учту, против кого ты чаще проигрываешь.',
                    'Based on the meta and your heroes. Add your Steam ID on My heroes — then I will consider who you lose to most.')
                : L('Учитываю мету на твоём ранге, твоих героев и тех, против кого ты чаще проигрываешь: ${nem.take(4).map((e) => e.key.name).join(', ')}.',
                    'Considers the meta at your rank, your heroes, and heroes you often lose to: ${nem.take(4).map((e) => e.key.name).join(', ')}.'),
            style: T.small,
          ),
          const SizedBox(height: 10),
          for (final (i, c) in cands.take(8).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.all(10),
                onTap: () => openHero(context, c.h),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  HeroImg(c.h, width: 64),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i + 1}. ${c.h.name}', style: T.body.copyWith(fontWeight: FontWeight.w700)),
                      for (final w in c.why.take(3)) Text('• $w', style: T.small.copyWith(fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    tooltip: L('В мои герои', 'Add to my heroes'),
                    icon: const Icon(Icons.star_border, color: C.gold),
                    onPressed: () {
                      s.togglePool(c.h.id);
                      showToast(context, L('${c.h.name} добавлен в «Мои герои»', '${c.h.name} added to My heroes'));
                    },
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
