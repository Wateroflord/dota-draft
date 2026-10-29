import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data.dart';
import '../engine.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';
import 'hero_screen.dart';
import 'info_screen.dart';
import 'share_screen.dart';
import 'cm_screen.dart';
import 'scan_draft_screen.dart';
import '../i18n.dart';
import '../overlay.dart';
import '../platform.dart';
import '../voice.dart';
import 'personal_screen.dart';
import 'trainer_screen.dart';

Map<int, String> get stageTitles => {1: L('1 пик', '1st pick'), 2: L('2 пик', '2nd pick'), 3: L('3 пик', '3rd pick')};
Map<int, String> get stageHints => {
  1: L('Первые пики: сильные и надёжные герои, которых трудно законтрить.', 'First picks: strong, safe heroes that are hard to counter.'),
  2: L('Середина драфта: учитываем и врагов, и союзников, но не открываемся под контрпик.', 'Mid draft: considers both enemies and allies without exposing you to counters.'),
  3: L('Последний пик: максимальный контрпик против уже выбранных врагов.', 'Last pick: the strongest counter to the enemies already picked.'),
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
            myPos: s.myPos,
          );

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Dota Draft', style: T.h2),
        actions: [
          IconButton(
            tooltip: L('Драфт по скриншоту', 'Draft from screenshot'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanDraftScreen())),
          ),
          IconButton(
            tooltip: L('Поделиться драфтом / открыть по QR', 'Share draft / open QR'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShareScreen())),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: L('Сохранить драфт в историю', 'Save draft to history'),
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () {
              if (allies.isEmpty && enemies.isEmpty) {
                showToast(context, L('Сначала выбери героев', 'Pick some heroes first'));
                return;
              }
              s.saveDraft();
              showToast(context, L('Драфт сохранён. Отметь результат в «Мои герои» → История драфтов',
                  'Draft saved. Mark the result in My heroes → Draft history'));
            },
          ),
          if (isAndroid)
            IconButton(
              tooltip: L('Голосом: «Пудж врагам»', 'By voice: "Pudge to enemies"'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.mic_none),
              onPressed: () => voiceInput(context),
            ),
          if (isWindows)
            IconButton(
              tooltip: L('Оверлей поверх игры (Ctrl+Shift+O)', 'Overlay on top of the game (Ctrl+Shift+O)'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
              onPressed: overlay.enter,
            ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            color: C.surface2,
            onSelected: (v) {
              switch (v) {
                case 0:
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CmScreen()));
                case 1:
                  s.swapSides();
                case 2:
                  s.clear();
                case 3:
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen()));
                case 4:
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainerScreen()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 0, child: Text(L('Captains Mode (пики и баны по очереди)', 'Captains Mode (step by step)'))),
              PopupMenuItem(value: 1, child: Text(L('Поменять команды местами', 'Swap teams'))),
              PopupMenuItem(value: 2, child: Text(L('Очистить драфт', 'Clear draft'))),
              PopupMenuItem(value: 4, child: Text(L('Тренировка драфта против бота', 'Draft practice vs bot'))),
              PopupMenuItem(value: 3, child: Text(L('О данных', 'About the data'))),
            ],
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
            L('Кого брать', 'What to pick'),
            trailing: Text(s.stageOverride == null ? L('авто', 'auto') : L('вручную', 'manual'), style: T.small),
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
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Icon(Icons.star_border, size: 16, color: C.gold),
            Text(L('Мои герои:', 'My heroes:'), style: T.small),
            for (final m in const [0, 1, 2])
              Pill([L('не учитывать', 'ignore'), L('приоритет', 'priority'), L('только мои', 'only mine')][m],
                  color: C.gold, filled: s.comfortMode == m, onTap: () => s.setComfortMode(m)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Icon(Icons.person_pin_circle_outlined, size: 16, color: C.accent2),
            Text(L('Я играю:', 'I play:'), style: T.small),
            for (final p in const [0, 1, 2, 3, 4, 5])
              Pill(p == 0 ? L('любую', 'any') : '$p', color: C.accent2, filled: s.myPos == p, onTap: () => s.setMyPos(p)),
          ]),
          if (s.friends.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Icon(Icons.groups_outlined, size: 16, color: C.intel),
              Pill(L('Пати: ${s.friends.length + 1} чел.', 'Party: ${s.friends.length + 1}'),
                  color: C.intel, filled: s.partyMode, onTap: () => s.setPartyMode(!s.partyMode)),
              Text(s.partyMode ? L('учитываю героев друзей', 'using friends\' heroes') : L('выключено', 'off'),
                  style: T.small),
            ]),
          ],
          if (missing.isNotEmpty && allies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(L('Свободные позиции: ${missing.map((p) => positionNames[p]).join(', ')}', 'Open positions: ${missing.map((p) => positionNames[p]).join(', ')}'), style: T.small),
              ),
              Text(L('только они', 'only these'), style: T.small),
              Switch(
                value: s.roleFilter,
                activeTrackColor: C.accent,
                onChanged: s.setRoleFilter,
              ),
            ]),
          ],
          const SizedBox(height: 8),
          if (allies.length >= 5)
            AppCard(child: Text(L('Твоя команда собрана. Смотри шанс победы вверху.', 'Your team is complete. See the win chance above.'), style: T.body))
          else
            for (final p in picks) _PickCard(p: p, stage: s.stage),
          if (allies.length < 5) ...[
            SectionLabel(L('Лучшая команда для победы', 'Best team to win')),
            _BestTeam(),
          ],
          SectionLabel(enemies.length >= 5 ? L('Опасные герои', 'Dangerous heroes') : L('Опасные пики противника — кандидаты в бан', 'Dangerous enemy picks — ban candidates')),
          _Threats(),
          const PersonalDraftCard(),
          const SizedBox(height: 14),
          Text(
            L('Нажми на героя в рекомендациях, чтобы добавить его в свою команду. Долгое нажатие — другие действия.', 'Tap a recommended hero to add it to your team. Long press for other actions.'),
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
            Text(L('ШАНС ПОБЕДЫ', 'WIN CHANCE'), style: T.label),
            const SizedBox(height: 4),
            Text(empty ? '—' : pct(chance, digits: 0), style: T.num(34, color: empty ? C.muted : (good ? C.ally : C.enemy))),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(L('СИЛА КОМАНД', 'TEAM STRENGTH'), style: T.label),
            const SizedBox(height: 6),
            Row(children: [
              Text(us == 0 ? '—' : us.round().toString(), style: T.num(18, color: C.ally)),
              Text('  vs  ', style: T.small),
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
        Text(L('Оценка по статистике матчей: винрейты героев, контрпики и синергия. Игра решает больше драфта.', 'Estimated from match stats: hero win rates, counters and synergy. The game matters more than the draft.'),
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
          title: ally ? L('Герой в твою команду', 'Hero for your team') : L('Герой противника', 'Enemy hero'), disabled: s.unavailable);
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
          _sheetBtn(context, Icons.swap_horiz, L('Заменить', 'Replace'), () async {
            Navigator.pop(context);
            final h = await pickHero(context, title: L('Заменить ${hero.name}', 'Replace ${hero.name}'), disabled: s.unavailable);
            if (h != null) s.setSlot(ally, slot, h);
          }),
          _sheetBtn(context, Icons.close, L('Убрать', 'Remove'), () {
            s.setSlot(ally, slot, null);
            Navigator.pop(context);
          }),
          _sheetBtn(context, Icons.info_outline, L('Подробнее о герое', 'Hero details'), () {
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
        Text(ally ? L('ТВОЯ КОМАНДА', 'YOUR TEAM') : L('ПРОТИВНИКИ', 'ENEMIES'), style: T.label.copyWith(color: color)),
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
                      h == null ? '' : (positions[h.id] == null ? h.name : L('поз. ${positions[h.id]}', 'pos. ${positions[h.id]}')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: C.muted),
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

Widget _sheetBtn(BuildContext context, IconData icon, String text, VoidCallback onTap, {Color? color}) => InkWell(
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
    final banned = s.bans.map((id) => s.data!.byId[id]).whereType<DHero>().toList();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        Text(L('БАНЫ', 'BANS'), style: T.label),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (banned.isEmpty) Text(L('нет', 'none'), style: T.small),
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
          tooltip: L('Забанить героя', 'Ban a hero'),
          icon: Icon(Icons.add_circle_outline, color: C.accent2),
          onPressed: () async {
            final h = await pickHero(context, title: L('Бан', 'Ban'), disabled: s.unavailable);
            if (h != null) s.toggleBan(h);
          },
        ),
      ]),
    );
  }
}

Future<void> heroActions(BuildContext context, DHero h) {
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
        _sheetBtn(context, Icons.add, L('В мою команду', 'To my team'), () {
          Navigator.pop(context);
          if (!s.add(true, h.id)) showToast(context, L('Твоя команда уже полная', 'Your team is already full'));
        }, color: C.ally),
        _sheetBtn(context, Icons.add, L('Противнику', 'To the enemy'), () {
          Navigator.pop(context);
          if (!s.add(false, h.id)) showToast(context, L('У противников уже 5 героев', 'The enemy already has 5 heroes'));
        }, color: C.enemy),
        _sheetBtn(context, Icons.block, L('Забанить', 'Ban'), () {
          Navigator.pop(context);
          s.toggleBan(h.id);
        }),
        _sheetBtn(context, Icons.info_outline, L('Подробнее о герое', 'Hero details'), () {
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
        0 => r.value > 0 ? L('Силён против ${r.hero.name}', 'Strong vs ${r.hero.name}') : L('Слаб против ${r.hero.name}', 'Weak vs ${r.hero.name}'),
        3 => L('Связка с ${r.hero.name}', 'Combo with ${r.hero.name}'),
        _ => L('Хорошо с ${r.hero.name}', 'Good with ${r.hero.name}'),
      };
      lines.add(Text('$text ${signedPct(r.value)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: T.small.copyWith(fontSize: 11.5, color: r.value >= 0 ? C.accent2 : C.enemy)));
    }
    if (stage < 3 && p.counters.isNotEmpty) {
      lines.add(Text(L('Контрят: ${p.counters.take(3).map((x) => x.name).join(', ')}', 'Countered by: ${p.counters.take(3).map((x) => x.name).join(', ')}'),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5)));
    }
    if (p.friends.isNotEmpty) {
      lines.add(Text(L('Играет: ${p.friends.join(', ')}', 'Played by: ${p.friends.join(', ')}'),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5, color: C.intel)));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: () {
          if (!s.add(true, h.id)) showToast(context, L('Твоя команда уже полная', 'Your team is already full'));
        },
        onLongPress: () => heroActions(context, h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HeroImg(h, width: 78),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (p.mine) ...[
                  const Icon(Icons.star, size: 14, color: C.gold),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(signedPct(p.winDelta), style: T.num(14, color: p.winDelta >= 0 ? C.ally : C.enemy)),
              ]),
              const SizedBox(height: 2),
              Text(
                L('${p.position == null ? '' : '${positionNames[p.position]} · '}винрейт ${pct(h.wrAt(g))}', '${p.position == null ? '' : '${positionNames[p.position]} · '}win rate ${pct(h.wrAt(g))}'),
                style: T.small.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 3),
              ...lines,
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.more_vert, color: C.muted, size: 20),
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
          Expanded(child: Text(L('Дополнить команду', 'Complete the team'), style: T.section)),
          Text(L('шанс ${pct(res.winChance, digits: 0)}', 'chance ${pct(res.winChance, digits: 0)}'), style: T.num(14, color: C.gold)),
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
              ? L('Подобрано по силе героев и синергии. Когда добавишь врагов, учтутся и контрпики.', 'Chosen by hero strength and synergy. Add enemies to include counters too.')
              : L('Подобрано с учётом врагов, синергии и позиций 1–5.', 'Chosen considering enemies, synergy and positions 1–5.'),
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
            label: Text(L('Поставить этих героев', 'Use these heroes'), style: TextStyle(fontWeight: FontWeight.w700)),
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
      return AppCard(child: Text(L('Противники выбрали всех героев.', 'The enemy has picked all heroes.'), style: T.small));
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


/// Голосовой ввод героев: «Пудж врагам», «Инвокер нам», «бан Войд».
Future<void> voiceInput(BuildContext context) async {
  final s = StateScope.read(context);
  final stt = SpeechToText();
  var ok = false;
  try {
    ok = await stt.initialize();
  } catch (_) {}
  if (!context.mounted) return;
  if (!ok) {
    showToast(context, L('Распознавание речи недоступно — разреши микрофон для приложения.', 'Speech recognition unavailable — allow the microphone.'));
    return;
  }
  showToast(context, L('Говори: «Пудж врагам», «Инвокер нам», «бан Войд»', 'Say: "Pudge enemy", "Invoker us", "ban Void"'));
  await stt.listen(
    localeId: isEn ? 'en_US' : 'ru_RU',
    listenFor: const Duration(seconds: 7),
    onResult: (r) {
      if (!r.finalResult) return;
      final found = parseVoice(r.recognizedWords, s.data!.heroes);
      if (found.isEmpty) {
        if (context.mounted) showToast(context, L('Не понял героя: «${r.recognizedWords}»', 'Did not catch a hero: "${r.recognizedWords}"'));
        return;
      }
      for (final f in found) {
        if (f.$2 == 2) {
          if (!s.bans.contains(f.$1.id)) s.toggleBan(f.$1.id);
        } else {
          s.add(f.$2 == 0, f.$1.id);
        }
      }
      if (context.mounted) {
        showToast(context, found.map((f) => '${f.$1.name} → ${[L('нам', 'us'), L('врагам', 'enemy'), L('бан', 'ban')][f.$2]}').join(', '));
      }
    },
  );
}
