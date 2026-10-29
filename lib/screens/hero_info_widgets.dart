import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../analysis.dart';
import '../data.dart';
import '../i18n.dart';
import '../info.dart';
import '../knowledge.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

Widget abilityIcon(Ability a, {double size = 34}) => ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: CachedNetworkImage(
        imageUrl: a.image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: C.surface2,
          alignment: Alignment.center,
          child: Text(a.name.isEmpty ? '?' : a.name[0], style: const TextStyle(color: C.muted, fontWeight: FontWeight.w800)),
        ),
      ),
    );

String _cdText(Ability a) {
  if (a.cd.isEmpty || a.cd.every((c) => c == 0)) return L('пассивная', 'passive');
  final uniq = a.cd.toSet();
  return '${uniq.length == 1 ? a.cd.first : a.cd.join('/')} ${L('с', 's')}';
}

/// Умения героя с перезарядкой и описанием.
class AbilitiesSection extends StatefulWidget {
  final HeroInfo info;
  const AbilitiesSection({super.key, required this.info});

  @override
  State<AbilitiesSection> createState() => _AbilitiesSectionState();
}

class _AbilitiesSectionState extends State<AbilitiesSection> {
  int? open;

  @override
  Widget build(BuildContext context) {
    final list = widget.info.basic.where((a) => a.desc.isNotEmpty || a.cd.isNotEmpty).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        for (var i = 0; i < list.length; i++)
          InkWell(
            onTap: () => setState(() => open = open == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  abilityIcon(list[i]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text(list[i].name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        ),
                        if (list[i].ult) ...[
                          const SizedBox(width: 6),
                          Pill(L('ульт', 'ult'), color: C.gold),
                        ],
                      ]),
                      Text(L('Перезарядка: ', 'Cooldown: ') + _cdText(list[i]), style: T.small.copyWith(fontSize: 11.5)),
                    ]),
                  ),
                  Icon(open == i ? Icons.expand_less : Icons.expand_more, color: C.muted, size: 18),
                ]),
                if (open == i && list[i].desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(list[i].desc, style: T.body.copyWith(fontSize: 13)),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Порядок прокачки и таланты по победам игроков.
class SkillBuildSection extends StatelessWidget {
  final DHero hero;
  const SkillBuildSection({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final info = s.info.heroes[hero.id];
    final seq = s.bench.skills[hero.id] ?? const [];
    final tal = s.bench.talents[hero.id] ?? const {};
    if (info == null || (seq.isEmpty && tal.isEmpty)) return const SizedBox.shrink();
    final abil = {for (final a in info.abilities) a.id: a};
    final steps = [for (final st in seq) if (abil[st.$1] != null) (abil[st.$1]!, st.$2)];
    final tiers = <int, List<Talent>>{};
    for (final t in info.talents) {
      tiers.putIfAbsent(t.tier, () => []).add(t);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (steps.isNotEmpty) ...[
        SectionLabel(L('Порядок прокачки', 'Skill order')),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 8, children: [
              for (var i = 0; i < steps.length; i++)
                Column(children: [
                  abilityIcon(steps[i].$1, size: 32),
                  const SizedBox(height: 2),
                  Text('${i + 1}', style: T.small.copyWith(fontSize: 10)),
                ]),
            ]),
            const SizedBox(height: 8),
            Text(L('Что чаще всего качают победители на каждом уровне.', 'What winners level up most often at each level.'),
                style: T.small),
          ]),
        ),
      ],
      if (tiers.isNotEmpty && tal.isNotEmpty) ...[
        SectionLabel(L('Таланты', 'Talents')),
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(children: [
            for (final tier in [3, 2, 1, 0])
              if ((tiers[tier]?.length ?? 0) >= 2) _talentRow(tiers[tier]!, tal),
            const SizedBox(height: 4),
            Text(L('Подсвечен самый популярный выбор; ниже — как часто берут и винрейт.',
                'The most popular choice is highlighted; below — pick rate and win rate.'), style: T.small),
          ]),
        ),
      ],
    ]);
  }

  Widget _talentRow(List<Talent> pair, Map<int, (double, double)> tal) {
    final a = pair[0], b = pair[1];
    final na = tal[a.id]?.$1 ?? 0, nb = tal[b.id]?.$1 ?? 0;
    final tot = na + nb;
    Widget side(Talent t, double n, bool best, bool right) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: best ? C.gold.withValues(alpha: 0.12) : C.surface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: best ? C.gold.withValues(alpha: 0.6) : C.border),
            ),
            child: Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              Text(t.name, textAlign: right ? TextAlign.right : TextAlign.left, style: T.body.copyWith(fontSize: 12)),
              if (tot > 0)
                Text(
                  '${(n / tot * 100).round()}%${tal[t.id] != null ? ' · ${L('вр', 'wr')} ${pct(tal[t.id]!.$2, digits: 0)}' : ''}',
                  style: T.small.copyWith(fontSize: 10.5),
                ),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          side(a, na, tot > 0 && na >= nb, false),
          Container(
            width: 34,
            alignment: Alignment.center,
            child: Text('${a.level}', style: T.num(13, color: C.gold)),
          ),
          side(b, nb, tot > 0 && nb > na, true),
        ]),
      ),
    );
  }
}

/// Шпаргалка «Как играть против».
class VersusSection extends StatelessWidget {
  final DHero hero;
  const VersusSection({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final info = s.info.heroes[hero.id];
    final h = hero;
    final points = <(IconData, String)>[];
    final ult = info?.ultimate;
    if (ult != null) {
      points.add((
        Icons.bolt,
        L('Главная угроза — ${ult.name} (перезарядка ${_cdText(ult)}). Дерись, когда он потрачен.',
            'Main threat — ${ult.name} (cooldown ${_cdText(ult)}). Fight when it is on cooldown.')
      ));
    }
    if (invisible.contains(h.key)) {
      points.add((Icons.visibility_off, L('Бывает невидимым — держи пыль и сентри.', 'Can turn invisible — carry Dust and Sentries.')));
    }
    if (illusions.contains(h.key)) {
      points.add((Icons.people_alt_outlined, L('Иллюзии и призывы — нужен урон по области.', 'Illusions/summons — you need area damage.')));
    }
    if (evasion.contains(h.key)) {
      points.add((Icons.shield_moon_outlined, L('Уклоняется от атак — нужен MKB.', 'Evades attacks — get MKB.')));
    }
    if (breakTargets.contains(h.key)) {
      points.add((Icons.heart_broken_outlined, L('Сила в пассивке — Silver Edge её выключает.', 'Relies on a passive — Silver Edge breaks it.')));
    }
    if (healers.contains(h.key)) {
      points.add((Icons.healing, L('Сильно лечится — Spirit Vessel или Shiva\'s режут лечение.', 'Heals a lot — Spirit Vessel / Shiva\'s cut healing.')));
    }
    if (singleTarget.contains(h.key)) {
      points.add((Icons.gps_fixed, L('Опасное заклинание в цель — Linken\'s Sphere или Lotus Orb.', 'Dangerous targeted spell — Linken\'s Sphere or Lotus Orb.')));
    }
    if (silencers.contains(h.key)) {
      points.add((Icons.volume_off, L('Накладывает сайленс — Manta или Eul\'s снимают.', 'Silences — Manta or Eul\'s dispel it.')));
    }
    if (savers.contains(h.key)) {
      points.add((Icons.health_and_safety_outlined, L('Спасает союзников — сначала убивай или сбивай его.', 'Saves allies — kill or disable him first.')));
    }
    if (h.dur.length == 4) {
      var best = 0;
      for (var i = 1; i < 4; i++) {
        if (h.dur[i] > h.dur[best]) best = i;
      }
      final early = best <= 1;
      points.add((
        Icons.schedule,
        early
            ? L('Силён в начале (${durationLabels[best]}) — затягивай игру, не давай ему темп.',
                'Strong early (${durationLabels[best]}) — drag the game out, deny his tempo.')
            : L('Силён в поздней игре (${durationLabels[best]}) — заканчивай игру раньше.',
                'Strong late (${durationLabels[best]}) — try to end the game earlier.')
      ));
    }
    if (info != null) {
      points.add((
        info.melee ? Icons.sports_mma : Icons.gps_not_fixed,
        info.melee
            ? L('Ближний бой — на линии харассь его и не давай подойти.', 'Melee — harass him in lane and keep distance.')
            : L('Дальний бой (${info.range}) — ищи момент, чтобы прыгнуть на него.', 'Ranged (${info.range}) — look for a moment to jump on him.')
      ));
    }
    final tips = itemTips([h]);
    final counters = s.engine.matchups(h, best: false).take(4).map((r) => r.$1).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Как играть против', 'How to play against')),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (info != null && info.hype.isNotEmpty) ...[
            Text(info.hype, style: T.body.copyWith(fontSize: 13, color: C.accent2)),
            const SizedBox(height: 8),
          ],
          for (final p in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(p.$1, size: 16, color: C.gold),
                const SizedBox(width: 8),
                Expanded(child: Text(p.$2, style: T.body.copyWith(fontSize: 13))),
              ]),
            ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(L('Предметы против него:', 'Items against him:'), style: T.small),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final k in {for (final t in tips) ...t.items}.take(8))
                Tooltip(message: itemNames[k] ?? k, child: ItemImg(k, width: 38)),
            ]),
          ],
          if (counters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(L('Кем контрить: ', 'Counter with: ') + counters.map((c) => c.name).join(', '), style: T.small.copyWith(color: C.text)),
          ],
        ]),
      ),
    ]);
  }
}

/// Изменения героя в последних патчах.
class PatchSection extends StatelessWidget {
  final DHero hero;
  const PatchSection({super.key, required this.hero});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final rows = [
      for (final p in s.patches)
        if (p.forHero(hero.id).isNotEmpty) (p.version, p.forHero(hero.id)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Изменения в патчах', 'Patch changes')),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final r in rows) ...[
            Text(L('Патч ${r.$1}', 'Patch ${r.$1}'), style: T.section.copyWith(color: C.gold)),
            const SizedBox(height: 4),
            for (final n in r.$2.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $n', style: T.body.copyWith(fontSize: 12.5)),
              ),
            const SizedBox(height: 6),
          ],
        ]),
      ),
    ]);
  }
}
