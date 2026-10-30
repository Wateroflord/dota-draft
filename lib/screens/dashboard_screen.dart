import 'package:flutter/material.dart';

import '../engine.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cooldowns_screen.dart';
import 'live_screen.dart';

/// Панель для второго монитора: живой матч, драфт и ульты врагов на одном широком экране.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final allies = s.allyHeroes, enemies = s.enemyHeroes;
    final chance = s.engine.winChance(allies, enemies);
    final draft = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(L('Шанс победы', 'Win chance'), style: T.body),
          const Spacer(),
          Text(allies.isEmpty && enemies.isEmpty ? '—' : pct(chance, digits: 0), style: T.num(26, color: chance >= 0.5 ? C.ally : C.enemy)),
        ]),
        const SizedBox(height: 8),
        for (final team in [(true, allies), (false, enemies)])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(
                width: 60,
                child: Text(team.$1 ? L('Мы', 'Us') : L('Враги', 'Enemy'),
                    style: T.small.copyWith(color: team.$1 ? C.ally : C.enemy, fontWeight: FontWeight.w700)),
              ),
              for (final h in team.$2) Padding(padding: const EdgeInsets.only(right: 4), child: HeroImg(h, width: 64, radius: 4)),
            ]),
          ),
        if (allies.length < 5)
          Wrap(spacing: 6, runSpacing: 6, children: [
            Text(L('Лучшие пики:', 'Best picks:'), style: T.small),
            for (final Pick p in s.engine.recommend(allies: allies, enemies: enemies, unavailable: s.unavailable, stage: s.stage, limit: 6, myPos: s.myPos))
              Tooltip(message: '${p.hero.name} ${signedPct(p.winDelta)}', child: HeroImg(p.hero, width: 52, radius: 4)),
          ]),
      ]),
    );
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Панель для второго монитора', 'Second monitor dashboard'), style: T.h2),
      ),
      body: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 900) {
          return ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 32), children: [
            draft,
            const SizedBox(height: 8),
            const LivePanel(),
            const SizedBox(height: 500, child: CooldownsScreen(embedded: true)),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(flex: 5, child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(14, 0, 8, 24), child: LivePanel())),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
              child: Column(children: [
                draft,
                const SizedBox(height: 8),
                const Expanded(child: CooldownsScreen(embedded: true)),
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}
