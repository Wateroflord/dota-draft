import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../coach.dart';
import '../gsi.dart';
import '../screen_draft.dart';
import '../tools_state.dart';
import 'desktop_settings_screen.dart';
import 'timer_screen.dart' show mmss;

import '../engine.dart';
import '../i18n.dart';
import '../overlay.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cooldowns_screen.dart';
import 'live_screen.dart';

/// Компактный оверлей поверх игры (Windows).
class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  int tab = 0;

  Future<void> _scan() async {
    final s = StateScope.read(context);
    final msg = await draftFromScreen(s, enemiesOnly: (gsi.last?.clock ?? -1) > 0);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12))));
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(tools.overlayScale.clamp(0.7, 1.6))),
      child: ListenableBuilder(
      listenable: overlay,
      builder: (context, _) => overlay.strip ? const _Strip() : Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          // Полоса, за которую окно можно перетаскивать.
          DragToMoveArea(
            child: Container(
              height: 34,
              color: C.surface,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Icon(Icons.drag_indicator, size: 16, color: C.muted),
                const SizedBox(width: 4),
                const Text('Dota Draft', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.accent)),
                const Spacer(),
                _icon(overlay.clickThrough ? Icons.mouse_outlined : Icons.mouse, L('Сквозной для мыши (Ctrl+Shift+X)', 'Click-through (Ctrl+Shift+X)'),
                    overlay.toggleClickThrough, active: overlay.clickThrough),
                _icon(Icons.screenshot_monitor_outlined, L('Герои с экрана (Ctrl+Shift+D / E)', 'Heroes from screen (Ctrl+Shift+D / E)'), _scan),
                _icon(Icons.view_stream_outlined, L('Полоса таймеров (Ctrl+Shift+M)', 'Timer strip (Ctrl+Shift+M)'), overlay.toggleStrip),
                _icon(Icons.tune, L('Настройки оверлея', 'Overlay settings'),
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DesktopSettingsScreen()))),
                _icon(Icons.open_in_full, L('Обычное окно (Ctrl+Shift+O)', 'Normal window (Ctrl+Shift+O)'), overlay.exit),
              ]),
            ),
          ),
          Container(
            color: C.surface,
            child: Row(children: [
              for (final t in [(0, L('Матч', 'Match')), (1, L('Драфт', 'Draft')), (2, L('Ульты', 'Ults'))])
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => tab = t.$1),
                    child: Container(
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: tab == t.$1 ? C.accent : C.border, width: 2)),
                      ),
                      child: Text(t.$2, style: TextStyle(fontSize: 12, color: tab == t.$1 ? C.text : C.muted)),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: IndexedStack(index: tab, children: [
              const SingleChildScrollView(padding: EdgeInsets.all(8), child: LivePanel(compact: true)),
              const SingleChildScrollView(padding: EdgeInsets.all(8), child: _DraftCompact()),
              const CooldownsScreen(embedded: true),
            ]),
          ),
          if (overlay.clickThrough)
            Container(
              color: C.accent.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(4),
              child: Text(L('Мышь проходит сквозь окно. Вернуть: Ctrl+Shift+X', 'Mouse passes through. Undo: Ctrl+Shift+X'),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: C.text)),
            ),
        ]),
      ),
    ),
    );
  }

  Widget _icon(IconData i, String tip, VoidCallback onTap, {bool active = false}) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(i, size: 17, color: active ? C.accent : C.accent2),
          ),
        ),
      );
}

/// Драфт в оверлее: шанс победы и лучшие пики.
class _DraftCompact extends StatelessWidget {
  const _DraftCompact();

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final e = s.engine;
    final allies = s.allyHeroes, enemies = s.enemyHeroes;
    final picks = allies.length >= 5
        ? const <Pick>[]
        : e.recommend(allies: allies, enemies: enemies, unavailable: s.unavailable, stage: s.stage, limit: 6, myPos: s.myPos);
    final chance = e.winChance(allies, enemies);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Text(L('Шанс победы', 'Win chance'), style: T.small),
          const Spacer(),
          Text(allies.isEmpty && enemies.isEmpty ? '—' : pct(chance, digits: 0),
              style: T.num(18, color: chance >= 0.5 ? C.ally : C.enemy)),
        ]),
      ),
      const SizedBox(height: 6),
      Text(L('Героев выбирай в обычном окне (Ctrl+Shift+O) или по скриншоту.', 'Pick heroes in the normal window (Ctrl+Shift+O) or from a screenshot.'),
          style: T.small.copyWith(fontSize: 10.5)),
      const SizedBox(height: 6),
      for (final p in picks)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: AppCard(
            padding: const EdgeInsets.all(6),
            onTap: () => s.add(true, p.hero.id),
            child: Row(children: [
              HeroImg(p.hero, width: 46),
              const SizedBox(width: 8),
              Expanded(child: Text(p.hero.name, style: T.body.copyWith(fontSize: 12.5))),
              Text(signedPct(p.winDelta), style: T.num(12, color: p.winDelta >= 0 ? C.ally : C.enemy)),
            ]),
          ),
        ),
    ]);
  }
}

/// Узкая полоса поверх игры: время, ближайшее событие, золото, последняя подсказка.
class _Strip extends StatefulWidget {
  const _Strip();

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    final g = gsi.live ? gsi.last : null;
    final clock = g?.clock ?? 0;
    final ev = <(String, int)>[];
    for (final e in tools.timerEvents.where((e) => e.enabled)) {
      final n = e.nextAt(clock);
      if (n != null) ev.add((e.title, n));
    }
    final r = liveMarks.roshanAt;
    if (r != null && r + 660 >= clock) ev.add((L('Рошан', 'Roshan'), r + 480 >= clock ? r + 480 : r + 660));
    final tm = liveMarks.tormentorAt;
    if (tm != null && tm + 600 >= clock) ev.add((L('Торментор', 'Tormentor'), tm + 600));
    ev.sort((a, b) => a.$2.compareTo(b.$2));
    final alert = coach.alerts.isEmpty ? null : coach.alerts.first;
    return Scaffold(
      backgroundColor: C.bg,
      body: DragToMoveArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Text(g == null ? '--:--' : mmss(clock), style: T.num(16)),
            const SizedBox(width: 10),
            for (final e in ev.take(2)) ...[
              Text('${e.$1} ', style: T.small.copyWith(fontSize: 11)),
              Text(mmss(e.$2 - clock), style: T.num(12, color: e.$2 - clock <= 30 ? C.gold : C.text)),
              const SizedBox(width: 10),
            ],
            if (g != null) Text('${g.gold}', style: T.num(12, color: C.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(alert?.text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11, color: C.text)),
            ),
            InkWell(onTap: overlay.toggleStrip, child: Icon(Icons.unfold_more, size: 16, color: C.accent2)),
          ]),
        ),
      ),
    );
  }
}
