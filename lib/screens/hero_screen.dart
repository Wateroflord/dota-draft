import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
import 'compare_screen.dart';
import 'hero_info_widgets.dart';
import '../i18n.dart';

void openHero(BuildContext context, DHero h) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeroScreen(hero: h)));

class HeroScreen extends StatelessWidget {
  final DHero hero;
  const HeroScreen({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final e = s.engine;
    final h = hero;
    final inAllies = s.allies.contains(h.id), inEnemies = s.enemies.contains(h.id), banned = s.bans.contains(h.id);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(h.name, style: T.h2),
        actions: [
          IconButton(
            tooltip: L('Сравнить с другим героем', 'Compare with another hero'),
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompareScreen(first: h))),
          ),
          IconButton(
            tooltip: s.inPool(h.id) ? L('Убрать из моих героев', 'Remove from my heroes') : L('В мои герои', 'Add to my heroes'),
            icon: Icon(s.inPool(h.id) ? Icons.star : Icons.star_border, color: C.gold),
            onPressed: () => s.togglePool(h.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          LayoutBuilder(builder: (_, c) => HeroImg(h, width: c.maxWidth, radius: 10)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill(attrNames[h.attr] ?? h.attr, color: C.attr(h.attr)),
            for (final p in h.positions) Pill(positionNames[p] ?? '$p', color: C.accent2),
          ]),
          if (h.roles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(L('Роли: ${h.roles.join(', ')}', 'Roles: ${h.roles.join(', ')}'), style: T.small),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _Btn(inAllies ? L('В команде', 'In team') : L('В команду', 'To team'), Icons.add, C.ally, inAllies ? null : () {
                if (!s.add(true, h.id)) showToast(context, L('Твоя команда уже полная', 'Your team is already full'));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Btn(inEnemies ? L('У врагов', 'Enemy has') : L('Во враги', 'To enemies'), Icons.add, C.enemy, inEnemies ? null : () {
                if (!s.add(false, h.id)) showToast(context, L('У противников уже 5 героев', 'The enemy already has 5 heroes'));
              }),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Btn(banned ? L('Снять бан', 'Unban') : L('Бан', 'Ban'), Icons.block, C.muted, () => s.toggleBan(h.id))),
          ]),
          if (s.info.heroes[h.id] != null) ...[
            if (s.info.heroes[h.id]!.npe.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(s.info.heroes[h.id]!.npe, style: T.body.copyWith(color: C.accent2)),
            ],
            SectionLabel(L('Умения', 'Abilities')),
            AbilitiesSection(info: s.info.heroes[h.id]!),
          ],
          SectionLabel(L('Винрейт и популярность по рангам', 'Win rate and popularity by rank')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var g = 0; g < rankGroups.length; g++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(rankGroups[g],
                          style: T.body.copyWith(fontSize: 13, color: g == s.group ? C.accent : C.text,
                              fontWeight: g == s.group ? FontWeight.w700 : FontWeight.w400)),
                    ),
                    Text(pct(h.wrAt(g)), style: T.num(14, color: h.wrAt(g) >= 0.5 ? C.ally : C.enemy)),
                    const SizedBox(width: 14),
                    SizedBox(width: 64, child: Text(L('в ${pct(h.prAt(g))}', 'in ${pct(h.prAt(g))}'), textAlign: TextAlign.right, style: T.small)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(L('Справа — в какой доле матчей берут героя.', 'On the right — share of matches where the hero is picked.'), style: T.small),
          if (h.trendAt(s.group) != null) ...[
            const SizedBox(height: 6),
            Text(
              L('За неделю винрейт ${h.trendAt(s.group)! >= 0 ? 'вырос' : 'упал'} на ${pct(h.trendAt(s.group)!.abs())}', 'This week the win rate ${h.trendAt(s.group)! >= 0 ? 'rose' : 'fell'} by ${pct(h.trendAt(s.group)!.abs())}'),
              style: T.small.copyWith(color: h.trendAt(s.group)! >= 0 ? C.ally : C.enemy),
            ),
          ],
          if (s.played[h.id] != null) ...[
            SectionLabel(L('Твоя игра на герое', 'Your games on this hero')),
            AppCard(
              child: Row(children: [
                const Icon(Icons.person, color: C.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(L('${s.played[h.id]![0]} игр', '${s.played[h.id]![0]} games'), style: T.body)),
                Text(L('винрейт ${pct(s.played[h.id]![1] / s.played[h.id]![0])}', 'win rate ${pct(s.played[h.id]![1] / s.played[h.id]![0])}'),
                    style: T.num(14, color: s.played[h.id]![1] * 2 >= s.played[h.id]![0] ? C.ally : C.enemy)),
              ]),
            ),
          ],
          PatchSection(hero: h),
          BenchSection(hero: h),
          SkillBuildSection(hero: h),
          if ((s.bench.neutral[h.id] ?? const []).isNotEmpty) ...[
            SectionLabel(L('Нейтральные предметы', 'Neutral items')),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NeutralRow(hero: h),
                const SizedBox(height: 6),
                Text(L('Что чаще всего берут из нейтральных: доля и винрейт с предметом. T — уровень.', 'Most taken neutral items: share and win rate with the item. T — tier.'), style: T.small),
              ]),
            ),
          ],
          if (h.items.isNotEmpty) ...[
            SectionLabel(L('Популярные предметы', 'Popular items')),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final ph in [('s', L('Старт', 'Start')), ('e', L('Начало игры', 'Early game')), ('m', L('Середина', 'Mid game')), ('l', L('Поздняя игра', 'Late game'))])
                  if ((h.items[ph.$1] ?? const []).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 92, child: Text(ph.$2, style: T.small)),
                        Expanded(
                          child: Wrap(spacing: 4, runSpacing: 4, children: [
                            for (final id in h.items[ph.$1]!)
                              if (s.data!.items[id] != null)
                                Tooltip(message: s.data!.items[id]!.name, child: ItemImg(s.data!.items[id]!.key, width: 38)),
                          ]),
                        ),
                      ]),
                    ),
                const SizedBox(height: 4),
                Text(L('Нажми и удерживай предмет, чтобы увидеть название.', 'Long-press an item to see its name.'), style: T.small),
              ]),
            ),
          ],
          if (h.dur.length == 4) ...[
            SectionLabel(L('Сила по времени игры', 'Strength by game time')),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L('Винрейт героя в зависимости от длины матча', 'Hero win rate by match length'), style: T.small),
                const SizedBox(height: 8),
                ChanceBars(values: h.dur, labels: durationLabels),
              ]),
            ),
          ],
          if (h.proPicks > 0 || h.proBans > 0) ...[
            SectionLabel(L('Про-сцена', 'Pro scene')),
            AppCard(
              child: Row(children: [
                Expanded(child: Text(L('Пики: ${h.proPicks}\nБаны: ${h.proBans}', 'Picks: ${h.proPicks}\nBans: ${h.proBans}'), style: T.body)),
                Text(h.proPicks > 0 ? L('винрейт ${pct(h.proWr)}', 'win rate ${pct(h.proWr)}') : '—', style: T.num(14, color: h.proWr >= 0.5 ? C.ally : C.enemy)),
              ]),
            ),
          ],
          VersusSection(hero: h),
          _list(context, L('Силён против', 'Strong against'), e.matchups(h, best: true), C.ally),
          _list(context, L('Его контрят', 'Countered by'), e.matchups(h, best: false), C.enemy, invert: true),
          _list(context, L('Лучшие союзники', 'Best allies'), e.partners(h), C.gold),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, String title, List<(DHero, double)> rows, Color color, {bool invert = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final r in rows)
                InkWell(
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HeroScreen(hero: r.$1))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      HeroImg(r.$1, width: 54),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.$1.name, style: T.body.copyWith(fontSize: 13.5))),
                      Text(signedPct(invert ? -r.$2 : r.$2), style: T.num(13.5, color: color)),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
      );
}

class _Btn extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _Btn(this.text, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: onTap == null ? 0.3 : 0.7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      );
}
