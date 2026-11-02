import 'package:flutter/material.dart';

import '../build_guide.dart';
import '../data.dart';
import '../gsi.dart';
import '../i18n.dart';
import '../platform.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import 'hero_picker.dart';

/// Карточка «Билд под драфт»: предметы по стадиям и раздел против врагов. На Windows — кнопка записи в Dota.
class BuildCard extends StatefulWidget {
  final DHero hero;
  final bool compact;
  const BuildCard({super.key, required this.hero, this.compact = false});

  @override
  State<BuildCard> createState() => _BuildCardState();
}

class _BuildCardState extends State<BuildCard> {
  bool busy = false;

  Future<void> _write(HeroBuild b) async {
    setState(() => busy = true);
    try {
      await BuildWriter.write(b);
      if (mounted) {
        showToast(context, L('Записано. В Dota открой магазин → гайды → «Dota Draft». Если не видно — перезапусти Dota.',
            'Written. In Dota open the shop → guides → "Dota Draft". If missing, restart Dota.'));
      }
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    if (s.data == null) return const SizedBox.shrink();
    final b = makeBuild(s.data!, widget.hero, s.enemyHeroes);
    final c = widget.compact;
    return AppCard(
      padding: EdgeInsets.all(c ? 8 : 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          HeroImg(widget.hero, width: c ? 40 : 52),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L('Билд: ${widget.hero.name}', 'Build: ${widget.hero.name}'),
                  style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: c ? 12.5 : 14)),
              Text(
                b.enemies.isEmpty
                    ? L('враги ещё не выбраны — обычный билд', 'no enemies yet — standard build')
                    : L('против: ${b.enemies.map((e) => e.name).join(', ')}', 'vs: ${b.enemies.map((e) => e.name).join(', ')}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: T.small.copyWith(fontSize: c ? 10.5 : 11.5),
              ),
            ]),
          ),
        ]),
        for (final sec in b.sections)
          if (sec.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sec.title, style: T.label.copyWith(color: sec.token.startsWith('#') ? C.muted : C.enemy)),
            const SizedBox(height: 3),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final it in sec.items)
                Tooltip(message: '${it.name} · ${it.cost}', child: ItemImg(it.key, width: c ? 32 : 40)),
            ]),
          ],
        if (b.isEmpty)
          Text(L('Нет данных о предметах — обнови данные («О данных» → «Обновить сейчас»).',
              'No item data — update the data (About the data → Update now).'), style: T.small),
        if (isWindows && !b.isEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.accent, visualDensity: VisualDensity.compact),
              onPressed: busy ? null : () => _write(b),
              icon: const Icon(Icons.download_done, size: 18),
              label: Text(L('Записать билд в Dota', 'Write build to Dota')),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Экран «Билд под драфт»: выбрать героя (по умолчанию — из игры или первый союзник) и посмотреть/записать билд.
class BuildScreen extends StatefulWidget {
  const BuildScreen({super.key});

  @override
  State<BuildScreen> createState() => _BuildScreenState();
}

class _BuildScreenState extends State<BuildScreen> {
  int? heroId;

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final tools = ToolsScope.of(context);
    final g = gsi.last;
    final id = heroId ?? (g != null && g.heroId > 0 ? g.heroId : s.allyHeroes.firstOrNull?.id);
    final hero = id == null ? null : s.data?.byId[id];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Билд под драфт', 'Build for the draft'), style: T.h2),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 32), children: [
        Text(
          L('Предметы берутся из статистики героя, а раздел «Против этих врагов» — из вражеского драфта. '
              'Врагов выбери на экране драфта (или они подтянутся из игры).',
              'Items come from hero statistics; the "Against these enemies" section comes from the enemy draft. '
              'Pick enemies on the draft page (or they come from the game).'),
          style: T.small,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
          onPressed: () async {
            final v = await pickHero(context, title: L('Для какого героя билд?', 'Build for which hero?'));
            if (v != null) setState(() => heroId = v);
          },
          icon: const Icon(Icons.person_search),
          label: Text(hero == null ? L('Выбрать героя', 'Pick a hero') : L('Другой герой', 'Another hero')),
        ),
        const SizedBox(height: 8),
        if (hero != null) BuildCard(hero: hero),
        if (isWindows) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(children: [
              Expanded(
                child: Text(L('Сам записывать билд, когда в игре выбран герой (до 0:00)', 'Auto-write the build when a hero is picked in game (before 0:00)'),
                    style: T.body.copyWith(fontSize: 13)),
              ),
              Switch(value: tools.autoBuild, activeTrackColor: C.accent, onChanged: (v) => tools.setFlags(autoBuild: v)),
            ]),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
            onPressed: () async {
              try {
                final n = await BuildWriter.restoreAll();
                if (context.mounted) showToast(context, L('Восстановлено файлов: $n', 'Files restored: $n'));
              } catch (e) {
                if (context.mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
              }
            },
            icon: const Icon(Icons.restore),
            label: Text(L('Вернуть билды Valve', 'Restore Valve builds')),
          ),
          if (BuildWriter.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(L('Последняя ошибка записи: ${BuildWriter.lastError}', 'Last write error: ${BuildWriter.lastError}'),
                  style: T.small.copyWith(color: C.enemy)),
            ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            L('Записать билд прямо в Dota может только версия для Windows (она стоит на том же ПК, что и игра). '
                'Если она запущена и включён «Сам записывать билд», он появится в игре автоматически.',
                'Only the Windows version can write the build into Dota (it runs on the same PC as the game). '
                'If it is running with auto-write on, the build appears in game automatically.'),
            style: T.small,
          ),
        ],
      ]),
    );
  }
}
