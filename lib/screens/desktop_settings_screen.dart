import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../i18n.dart';
import '../overlay.dart';
import '../platform.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import '../winutil.dart';
import 'transfer_screen.dart';

/// Настройки подсказок во время игры и (на Windows) оверлея, горячих клавиш, трея.
class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
  bool? startup;

  @override
  void initState() {
    super.initState();
    if (isWindows) {
      startupEnabled().then((v) {
        if (mounted) setState(() => startup = v);
      });
    }
  }

  Widget _switch(String title, String? sub, bool v, ValueChanged<bool> f) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeTrackColor: C.accent,
        title: Text(title, style: T.body.copyWith(fontSize: 14)),
        subtitle: sub == null ? null : Text(sub, style: T.small),
        value: v,
        onChanged: f,
      );

  Future<void> _record(ToolsState t, HotAction a) async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}
    if (!mounted) return;
    final combo = await showDialog<KeyCombo>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(a.title, style: T.h2),
        content: Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            final c = comboFromEvent(e);
            if (c != null) {
              if (c.mods.isEmpty && e.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(ctx);
              } else if (c.mods.isEmpty) {
                // Без Ctrl/Alt/Shift клавиша мешала бы игре.
                return KeyEventResult.handled;
              } else {
                Navigator.pop(ctx, c);
              }
            }
            return KeyEventResult.handled;
          },
          child: Text(
            L('Нажми новое сочетание (обязательно с Ctrl, Alt или Shift). Esc — отмена.',
                'Press a new combination (with Ctrl, Alt or Shift). Esc — cancel.'),
            style: T.body,
          ),
        ),
      ),
    );
    if (combo != null) t.setHotkey(a.id, combo.toJson());
    await registerHotkeys(t);
  }

  @override
  Widget build(BuildContext context) {
    final t = ToolsScope.of(context);
    final blocks = [
      ('alerts', L('Подсказки', 'Hints')),
      ('hero', L('Шпаргалка на героя', 'Hero cheat sheet')),
      ('farm', L('Маршрут фарма', 'Farm route')),
      ('items', L('Что купить', 'What to buy')),
      ('gpm', L('График золота', 'Gold graph')),
      ('deaths', L('Смерти', 'Deaths')),
      ('events', L('Ближайшие события', 'Upcoming events')),
      ('buttons', L('Кнопки Рошан/Торментор', 'Roshan/Tormentor buttons')),
    ];
    final corners = [
      (0, L('где оставил', 'where I left it')),
      (1, '↖'),
      (2, '↗'),
      (3, '↙'),
      (4, '↘'),
    ];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(isWindows ? L('Оверлей и подсказки', 'Overlay and hints') : L('Подсказки в игре', 'In-game hints'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          SectionLabel(L('Подсказки во время матча', 'Hints during a match')),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              _switch(L('Озвучивать подсказки', 'Speak hints'), L('прокачка, таланты, ТП, выкуп, варды, план по минутам', 'skills, talents, TP, buyback, wards, timeline'),
                  t.coachVoice, (v) => t.setFlags(coachVoice: v)),
              if (isWindows)
                _switch(L('Уведомления Windows', 'Windows notifications'), L('всплывающие сообщения возле часов', 'pop-ups near the clock'), t.toasts,
                    (v) => t.setFlags(toasts: v)),
              _switch(L('Открывать разбор после матча', 'Open breakdown after the match'),
                  L('через 2 минуты после конца игры (просит OpenDota разобрать запись)', '2 minutes after the game ends (asks OpenDota to parse)'),
                  t.autoBreakdown, (v) => t.setFlags(autoBreakdown: v)),
            ]),
          ),
          if (isWindows) ...[
            SectionLabel(L('Windows', 'Windows')),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                _switch(L('Оверлей сам, когда запущена Dota', 'Overlay automatically when Dota runs'),
                    L('и обычное окно, когда Dota закрыта', 'and the normal window when Dota closes'), t.autoOverlay, (v) => t.setFlags(autoOverlay: v)),
                _switch(L('Враги с экрана в начале матча', 'Enemies from screen at game start'),
                    L('по верхней полосе с портретами (нужен режим «окно без рамки»)', 'from the top hero bar (needs borderless window mode)'),
                    t.autoEnemies, (v) => t.setFlags(autoEnemies: v)),
                _switch(L('Крестик сворачивает в трей', 'Close button hides to tray'), L('выйти — правой кнопкой по значку возле часов', 'quit via the tray icon menu'),
                    t.trayOnClose, (v) => t.setFlags(trayOnClose: v)),
                _switch(L('Запускать вместе с Windows', 'Launch with Windows'), null, startup ?? false, (v) async {
                  await setStartup(v);
                  final now = await startupEnabled();
                  if (mounted) setState(() => startup = now);
                }),
                _switch(L('Страница для OBS', 'OBS page'), t.obsServer ? 'http://127.0.0.1:3001/' : L('драфт и шанс победы для стрима', 'draft and win chance for your stream'),
                    t.obsServer, (v) async {
                  t.setFlags(obsServer: v);
                  if (v) {
                    await obs.start();
                  } else {
                    await obs.stop();
                  }
                }),
                if (t.obsServer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      L('В OBS: Источники → + → Браузер → URL http://127.0.0.1:3001/ , ширина 700, высота 200.',
                          'In OBS: Sources → + → Browser → URL http://127.0.0.1:3001/ , width 700, height 200.'),
                      style: T.small,
                    ),
                  ),
              ]),
            ),
            SectionLabel(L('Оверлей', 'Overlay')),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(L('Непрозрачность: ${(t.overlayOpacity * 100).round()}%', 'Opacity: ${(t.overlayOpacity * 100).round()}%'), style: T.small),
                Slider(
                  value: t.overlayOpacity.clamp(0.3, 1.0),
                  min: 0.3,
                  max: 1,
                  activeColor: C.accent,
                  onChanged: overlay.setOpacity,
                ),
                Text(L('Размер текста: ${(t.overlayScale * 100).round()}%', 'Text size: ${(t.overlayScale * 100).round()}%'), style: T.small),
                Slider(
                  value: t.overlayScale.clamp(0.7, 1.6),
                  min: 0.7,
                  max: 1.6,
                  divisions: 9,
                  activeColor: C.accent,
                  onChanged: (v) => t.setOverlay(scale: v),
                ),
                Text(L('Где ставить окно оверлея', 'Where to place the overlay'), style: T.small),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in corners)
                    Pill(c.$2, color: C.accent, filled: t.overlayCorner == c.$1, onTap: () {
                      t.setOverlay(corner: c.$1);
                      if (overlay.active) overlay.placeInCorner(c.$1);
                    }),
                ]),
                const SizedBox(height: 10),
                Text(L('Что показывать в оверлее', 'What to show in the overlay'), style: T.small),
                for (final b in blocks)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: C.accent,
                    title: Text(b.$2, style: T.body.copyWith(fontSize: 13.5)),
                    value: !t.overlayHidden.contains(b.$1),
                    onChanged: (_) => t.setOverlay(toggleBlock: b.$1),
                  ),
              ]),
            ),
            SectionLabel(L('Горячие клавиши', 'Hotkeys'),
                trailing: TextButton(
                  onPressed: () async {
                    for (final a in hotActions) {
                      t.setHotkey(a.id, null);
                    }
                    await registerHotkeys(t);
                  },
                  child: Text(L('Сбросить', 'Reset'), style: const TextStyle(color: C.accent)),
                )),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (final a in hotActions)
                  InkWell(
                    onTap: () => _record(t, a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(children: [
                        Expanded(child: Text(a.title, style: T.body.copyWith(fontSize: 13.5))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.border)),
                          child: Text(comboFor(t, a).label, style: T.num(12)),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(L('Нажми на действие, чтобы назначить свою клавишу. Клавиши работают, даже когда открыта игра.',
                'Tap an action to set your own key. Hotkeys work while the game is open.'), style: T.small),
          ],
          SectionLabel(L('Перенос между устройствами', 'Transfer between devices')),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransferScreen())),
            child: Row(children: [
              const Icon(Icons.sync_alt, color: C.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(L('Перенести настройки телефон ↔ ПК (код или QR)', 'Move settings phone ↔ PC (code or QR)'),
                    style: T.body.copyWith(fontSize: 14)),
              ),
              Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
        ],
      ),
    );
  }
}
