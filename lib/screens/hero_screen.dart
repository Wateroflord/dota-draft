import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

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
            tooltip: s.inPool(h.id) ? 'Убрать из моих героев' : 'В мои герои',
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
            Text('Роли: ${h.roles.join(', ')}', style: T.small),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _Btn(inAllies ? 'В команде' : 'В команду', Icons.add, C.ally, inAllies ? null : () {
                if (!s.add(true, h.id)) showToast(context, 'Твоя команда уже полная');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Btn(inEnemies ? 'У врагов' : 'Во враги', Icons.add, C.enemy, inEnemies ? null : () {
                if (!s.add(false, h.id)) showToast(context, 'У противников уже 5 героев');
              }),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Btn(banned ? 'Снять бан' : 'Бан', Icons.block, C.muted, () => s.toggleBan(h.id))),
          ]),
          const SectionLabel('Винрейт и популярность по рангам'),
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
                    SizedBox(width: 64, child: Text('в ${pct(h.prAt(g))}', textAlign: TextAlign.right, style: T.small)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          const Text('Справа — в какой доле матчей берут героя.', style: T.small),
          if (h.trendAt(s.group) != null) ...[
            const SizedBox(height: 6),
            Text(
              'За неделю винрейт ${h.trendAt(s.group)! >= 0 ? 'вырос' : 'упал'} на ${pct(h.trendAt(s.group)!.abs())}',
              style: T.small.copyWith(color: h.trendAt(s.group)! >= 0 ? C.ally : C.enemy),
            ),
          ],
          if (s.played[h.id] != null) ...[
            const SectionLabel('Твоя игра на герое'),
            AppCard(
              child: Row(children: [
                const Icon(Icons.person, color: C.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('${s.played[h.id]![0]} игр', style: T.body)),
                Text('винрейт ${pct(s.played[h.id]![1] / s.played[h.id]![0])}',
                    style: T.num(14, color: s.played[h.id]![1] * 2 >= s.played[h.id]![0] ? C.ally : C.enemy)),
              ]),
            ),
          ],
          if (h.items.isNotEmpty) ...[
            const SectionLabel('Популярные предметы'),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final ph in const [('s', 'Старт'), ('e', 'Начало игры'), ('m', 'Середина'), ('l', 'Поздняя игра')])
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
                const Text('Нажми и удерживай предмет, чтобы увидеть название.', style: T.small),
              ]),
            ),
          ],
          if (h.dur.length == 4) ...[
            const SectionLabel('Сила по времени игры'),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Винрейт героя в зависимости от длины матча', style: T.small),
                const SizedBox(height: 8),
                ChanceBars(values: h.dur, labels: durationLabels),
              ]),
            ),
          ],
          if (h.proPicks > 0 || h.proBans > 0) ...[
            const SectionLabel('Про-сцена'),
            AppCard(
              child: Row(children: [
                Expanded(child: Text('Пики: ${h.proPicks}\nБаны: ${h.proBans}', style: T.body)),
                Text(h.proPicks > 0 ? 'винрейт ${pct(h.proWr)}' : '—', style: T.num(14, color: h.proWr >= 0.5 ? C.ally : C.enemy)),
              ]),
            ),
          ],
          _list(context, 'Силён против', e.matchups(h, best: true), C.ally),
          _list(context, 'Его контрят', e.matchups(h, best: false), C.enemy, invert: true),
          _list(context, 'Лучшие союзники', e.partners(h), C.gold),
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
