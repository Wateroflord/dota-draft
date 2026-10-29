import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';
import 'hero_screen.dart';
import 'info_screen.dart';
import 'meta_screen.dart';

const stageTitles = {1: '1 пик', 2: '2 пик', 3: '3 пик'};
const stageHints = {
  1: 'Первые пики: сильные и надёжные герои, которых трудно законтрить.',
  2: 'Середина драфта: учитываем и врагов, и союзников, но не открываемся под контрпик.',
  3: 'Последний пик: максимальный контрпик против уже выбранных врагов.',
};

class DraftScreen extends StatelessWidget {
  const DraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    if (s.loading || s.data == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: s.error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(s.error!, style: T.body))
              : const CircularProgressIndicator(color: C.accent),
        ),
      );
    }
    final e = s.engine;
    final allies = s.allyHeroes, enemies = s.enemyHeroes;
    final chance = e.winChance(allies, enemies);
    final pos = Engine.assign(allies).$2;
    final missing = allies.length >= 5 ? <int>[] : Engine.missingPositions(allies);
    final picks = allies.length >= 5
        ? <Pick>[]
        : e.recommend(
            allies: allies,
            enemies: enemies,
            unavailable: s.unavailable,
            stage: s.stage,
            roleFilter: s.roleFilter,
            limit: 12,
          );

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Dota Draft', style: T.h2),
        actions: [
          IconButton(
            tooltip: 'Лучшие пики',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MetaScreen())),
          ),
          IconButton(
            tooltip: 'Поменять команды местами',
            icon: const Icon(Icons.swap_vert),
            onPressed: s.swapSides,
          ),
          IconButton(
            tooltip: 'Очистить драфт',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: s.clear,
          ),
          IconButton(
            tooltip: 'О данных',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var g = 0; g < rankGroupsShort.length; g++) ...[
                Pill(rankGroupsShort[g], filled: g == s.group, onTap: () => s.setGroup(g)),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          _WinCard(chance: chance, us: e.strength(allies), them: e.strength(enemies), empty: allies.isEmpty && enemies.isEmpty),
          const SizedBox(height: 10),
          _TeamRow(ally: true, ids: s.allies, positions: pos),
          const SizedBox(height: 8),
          _TeamRow(ally: false, ids: s.enemies, positions: Engine.assign(enemies).$2),
          const SizedBox(height: 8),
          _Bans(),
          SectionLabel(
            'Кого брать',
            trailing: Text(s.stageOverride == null ? 'авто' : 'вручную', style: T.small),
          ),
          Row(children: [
            for (final st in const [1, 2, 3]) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => s.setStage(s.stageOverride == st ? null : st),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.stage == st ? C.accent : C.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: s.stage == st ? C.accent : C.border),
                    ),
                    child: Text(stageTitles[st]!,
                        style: TextStyle(fontWeight: FontWeight.w700, color: s.stage == st ? Colors.white : C.muted)),
                  ),
                ),
              ),
              if (st < 3) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 6),
          Text(stageHints[s.stage]!, style: T.small),
          if (missing.isNotEmpty && allies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('Свободные позиции: ${missing.map((p) => positionNames[p]).join(', ')}', style: T.small),
              ),
              const Text('только они', style: T.small),
              Switch(
                value: s.roleFilter,
                activeTrackColor: C.accent,
                onChanged: s.setRoleFilter,
              ),
            ]),
          ],
          const SizedBox(height: 8),
          if (allies.length >= 5)
            const AppCard(child: Text('Твоя команда собрана. Смотри шанс победы вверху.', style: T.body))
          else
            for (final p in picks) _PickCard(p: p, stage: s.stage),
          if (allies.length < 5) ...[
            const SectionLabel('Лучшая команда для победы'),
            _BestTeam(),
          ],
          SectionLabel(enemies.length >= 5 ? 'Опасные герои' : 'Опасные пики противника — кандидаты в бан'),
          _Threats(),
          const SizedBox(height: 14),
          Text(
            'Нажми на героя в рекомендациях, чтобы добавить его в свою команду. Долгое нажатие — другие действия.',
            style: T.small,
          ),
        ],
      ),
    );
  }
}

class _WinCard extends StatelessWidget {
  final double chance, us, them;
  final bool empty;
  const _WinCard({required this.chance, required this.us, required this.them, required this.empty});

  @override
  Widget build(BuildContext context) {
    final good = chance >= 0.5;
    return AppCard(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ШАНС ПОБЕДЫ', style: T.label),
            const SizedBox(height: 4),
            Text(empty ? '—' : pct(chance, digits: 0), style: T.num(34, color: empty ? C.muted : (good ? C.ally : C.enemy))),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('СИЛА КОМАНД', style: T.label),
            const SizedBox(height: 6),
            Row(children: [
              Text(us == 0 ? '—' : us.round().toString(), style: T.num(18, color: C.ally)),
              const Text('  vs  ', style: T.small),
              Text(them == 0 ? '—' : them.round().toString(), style: T.num(18, color: C.enemy)),
            ]),
          ]),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              Expanded(flex: (chance * 1000).round(), child: Container(color: C.ally)),
              Expanded(flex: ((1 - chance) * 1000).round(), child: Container(color: C.enemy)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Оценка по статистике матчей: винрейты героев, контрпики и синергия. Игра решает больше драфта.',
            style: T.small),
      ]),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final bool ally;
  final List<int?> ids;
  final Map<int, int> positions;
  const _TeamRow({required this.ally, required this.ids, required this.positions});

  Future<void> _tap(BuildContext context, int slot) async {
    final s = StateScope.read(context);
    final id = ids[slot];
    if (id == null) {
      final h = await pickHero(context,
          title: ally ? 'Герой в твою команду' : 'Герой противника', disabled: s.unavailable);
      if (h != null) s.setSlot(ally, slot, h);
      return;
    }
    final hero = s.data!.byId[id]!;
    if (!context.mounted) return;
    await showSheet<void>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Row(children: [
            HeroImg(hero, width: 80),
            const SizedBox(width: 12),
            Expanded(child: Text(hero.name, style: T.h2)),
          ]),
          const SizedBox(height: 12),
          _sheetBtn(context, Icons.swap_horiz, 'Заменить', () async {
            Navigator.pop(context);
            final h = await pickHero(context, title: 'Заменить ${hero.name}', disabled: s.unavailable);
            if (h != null) s.setSlot(ally, slot, h);
          }),
          _sheetBtn(context, Icons.close, 'Убрать', () {
            s.setSlot(ally, slot, null);
            Navigator.pop(context);
          }),
          _sheetBtn(context, Icons.info_outline, 'Подробнее о герое', () {
            Navigator.pop(context);
            openHero(context, hero);
          }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final color = ally ? C.ally : C.enemy;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      borderColor: color.withValues(alpha: 0.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ally ? 'ТВОЯ КОМАНДА' : 'ПРОТИВНИКИ', style: T.label.copyWith(color: color)),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 5; i++) ...[
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                final id = ids[i];
                final h = id == null ? null : s.data!.byId[id];
                return GestureDetector(
                  onTap: () => _tap(context, i),
                  child: Column(children: [
                    h == null
                        ? Container(
                            width: c.maxWidth,
                            height: c.maxWidth * 0.5625,
                            decoration: BoxDecoration(
                              color: C.surface2,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: C.border),
                            ),
                            child: Icon(Icons.add, size: 18, color: color),
                          )
                        : HeroImg(h, width: c.maxWidth),
                    const SizedBox(height: 4),
                    Text(
                      h == null ? '' : (positions[h.id] == null ? h.name : 'поз. ${positions[h.id]}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: C.muted),
                    ),
                  ]),
                );
              }),
            ),
            if (i < 4) const SizedBox(width: 6),
          ],
        ]),
      ]),
    );
  }
}

Widget _sheetBtn(BuildContext context, IconData icon, String text, VoidCallback onTap, {Color color = C.text}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: T.body.copyWith(color: color)),
        ]),
      ),
    );

class _Bans extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final banned = s.bans.map((id) => s.data!.byId[id]).whereType<Hero>().toList();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        const Text('БАНЫ', style: T.label),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (banned.isEmpty) const Text('нет', style: T.small),
              for (final h in banned) ...[
                GestureDetector(
                  onTap: () => s.toggleBan(h.id),
                  child: Stack(alignment: Alignment.center, children: [
                    HeroImg(h, width: 44, dim: true, radius: 4),
                    const Icon(Icons.close, size: 16, color: C.enemy),
                  ]),
                ),
                const SizedBox(width: 4),
              ],
            ]),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Забанить героя',
          icon: const Icon(Icons.add_circle_outline, color: C.accent2),
          onPressed: () async {
            final h = await pickHero(context, title: 'Бан', disabled: s.unavailable);
            if (h != null) s.toggleBan(h);
          },
        ),
      ]),
    );
  }
}

Future<void> heroActions(BuildContext context, Hero h) {
  final s = StateScope.read(context);
  return showSheet<void>(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHandle(),
        Row(children: [
          HeroImg(h, width: 80),
          const SizedBox(width: 12),
          Expanded(child: Text(h.name, style: T.h2)),
        ]),
        const SizedBox(height: 10),
        _sheetBtn(context, Icons.add, 'В мою команду', () {
          Navigator.pop(context);
          if (!s.add(true, h.id)) showToast(context, 'Твоя команда уже полная');
        }, color: C.ally),
        _sheetBtn(context, Icons.add, 'Противнику', () {
          Navigator.pop(context);
          if (!s.add(false, h.id)) showToast(context, 'У противников уже 5 героев');
        }, color: C.enemy),
        _sheetBtn(context, Icons.block, 'Забанить', () {
          Navigator.pop(context);
          s.toggleBan(h.id);
        }),
        _sheetBtn(context, Icons.info_outline, 'Подробнее о герое', () {
          Navigator.pop(context);
          openHero(context, h);
        }),
      ]),
    ),
  );
}

class _PickCard extends StatelessWidget {
  final Pick p;
  final int stage;
  const _PickCard({required this.p, required this.stage});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.read(context);
    final h = p.hero;
    final g = s.group;
    final lines = <Widget>[];
    for (final r in p.reasons.take(3)) {
      final text = switch (r.kind) {
        0 => r.value > 0 ? 'Силён против ${r.hero.name}' : 'Слаб против ${r.hero.name}',
        _ => 'Хорошо с ${r.hero.name}',
      };
      lines.add(Text('$text ${signedPct(r.value)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: T.small.copyWith(fontSize: 11.5, color: r.value >= 0 ? C.accent2 : C.enemy)));
    }
    if (stage < 3 && p.counters.isNotEmpty) {
      lines.add(Text('Контрят: ${p.counters.take(3).map((x) => x.name).join(', ')}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5)));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: () {
          if (!s.add(true, h.id)) showToast(context, 'Твоя команда уже полная');
        },
        onLongPress: () => heroActions(context, h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HeroImg(h, width: 78),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(signedPct(p.winDelta), style: T.num(14, color: p.winDelta >= 0 ? C.ally : C.enemy)),
              ]),
              const SizedBox(height: 2),
              Text(
                '${p.position == null ? '' : '${positionNames[p.position]} · '}винрейт ${pct(h.wr[g])}',
                style: T.small.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 3),
              ...lines,
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.more_vert, color: C.muted, size: 20),
            onPressed: () => heroActions(context, h),
          ),
        ]),
      ),
    );
  }
}

class _BestTeam extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final e = s.engine;
    final res = e.bestTeam(allies: s.allyHeroes, enemies: s.enemyHeroes, unavailable: s.unavailable);
    final have = s.allies.whereType<int>().toSet();
    final sorted = [...res.heroes]..sort((a, b) => (res.positions[a.id] ?? 9).compareTo(res.positions[b.id] ?? 9));
    return AppCard(
      borderColor: C.gold.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, color: C.gold, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Дополнить команду', style: T.section)),
          Text('шанс ${pct(res.winChance, digits: 0)}', style: T.num(14, color: C.gold)),
        ]),
        const SizedBox(height: 10),
        for (final h in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => openHero(context, h),
              child: Row(children: [
                HeroImg(h, width: 56),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(h.name,
                      style: T.body.copyWith(fontSize: 13.5, color: have.contains(h.id) ? C.muted : C.text)),
                ),
                Text(positionNames[res.positions[h.id]] ?? '', style: T.small),
                if (!have.contains(h.id)) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.fiber_new, size: 16, color: C.gold),
                ],
              ]),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          s.enemyHeroes.isEmpty
              ? 'Подобрано по силе героев и синергии. Когда добавишь врагов, учтутся и контрпики.'
              : 'Подобрано с учётом врагов, синергии и позиций 1–5.',
          style: T.small,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => s.applyTeam(res.heroes),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Поставить этих героев', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Threats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    if (s.enemyHeroes.length >= 5) {
      return const AppCard(child: Text('Противники выбрали всех героев.', style: T.small));
    }
    final list = s.engine.threats(allies: s.allyHeroes, enemies: s.enemyHeroes, unavailable: s.unavailable, limit: 8);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = list[i];
          return GestureDetector(
            onTap: () => heroActions(context, p.hero),
            child: SizedBox(
              width: 86,
              child: Column(children: [
                HeroImg(p.hero, width: 86),
                const SizedBox(height: 4),
                Text(p.hero.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                Text(signedPct(-p.winDelta), style: T.num(11, color: C.enemy)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
