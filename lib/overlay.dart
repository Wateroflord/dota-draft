import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'i18n.dart';
import 'platform.dart';
import 'tools_state.dart';

/// Режим оверлея на Windows: маленькое окно поверх всех окон, полупрозрачное, можно сделать «сквозным» для мыши.
class OverlayController extends ChangeNotifier with WindowListener {
  ToolsState? tools;
  bool active = false;
  bool strip = false; // узкая полоса с таймерами
  bool clickThrough = false;
  double get opacity => tools?.overlayOpacity ?? 0.9;
  Size? _size;
  Offset? _pos;

  void attach(ToolsState t) {
    tools = t;
    if (isWindows) windowManager.addListener(this);
  }

  Future<void> enter({bool asStrip = false}) async {
    if (!isWindows) return;
    try {
      if (!active) {
        _size = await windowManager.getSize();
        _pos = await windowManager.getPosition();
      }
      strip = asStrip;
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      if (strip) {
        await windowManager.setMinimumSize(const Size(260, 40));
        await windowManager.setSize(Size(560 * (tools?.overlayScale ?? 1), 46 * (tools?.overlayScale ?? 1)));
      } else {
        await windowManager.setMinimumSize(const Size(280, 240));
        final r = tools?.overlayRect;
        if (r != null && (tools?.overlayCorner ?? 0) == 0) {
          await windowManager.setBounds(Rect.fromLTWH(r[0], r[1], r[2], r[3]));
        } else {
          await windowManager.setSize(Size(360 * (tools?.overlayScale ?? 1), 600 * (tools?.overlayScale ?? 1)));
        }
      }
      await placeInCorner();
      await windowManager.setOpacity(opacity);
      await windowManager.show();
    } catch (_) {}
    active = true;
    notifyListeners();
  }

  /// Поставить окно в выбранный угол экрана.
  Future<void> placeInCorner([int? corner]) async {
    final c = corner ?? tools?.overlayCorner ?? 0;
    if (c == 0 || !isWindows) return;
    try {
      final d = await screenRetriever.getPrimaryDisplay();
      final area = d.visibleSize ?? d.size;
      final origin = d.visiblePosition ?? Offset.zero;
      final sz = await windowManager.getSize();
      const m = 12.0;
      final x = c == 1 || c == 3 ? origin.dx + m : origin.dx + area.width - sz.width - m;
      final y = c == 1 || c == 2 ? origin.dy + m : origin.dy + area.height - sz.height - m;
      await windowManager.setPosition(Offset(x, y));
    } catch (_) {}
  }

  Future<void> exit() async {
    if (!isWindows || !active) return;
    await _saveRect();
    try {
      if (clickThrough) await windowManager.setIgnoreMouseEvents(false);
      clickThrough = false;
      await windowManager.setOpacity(1);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setMinimumSize(const Size(360, 480));
      if (_size != null) await windowManager.setSize(_size!);
      if (_pos != null) await windowManager.setPosition(_pos!);
    } catch (_) {}
    active = false;
    strip = false;
    notifyListeners();
  }

  Future<void> toggle() => active && !strip ? exit() : enter();

  Future<void> toggleStrip() async {
    if (active && strip) {
      await enter();
    } else {
      await _saveRect();
      await enter(asStrip: true);
    }
  }

  Future<void> _saveRect() async {
    if (!active || strip || tools == null) return;
    try {
      final b = await windowManager.getBounds();
      tools!.setOverlay(rect: [b.left, b.top, b.width, b.height]);
    } catch (_) {}
  }

  @override
  void onWindowMoved() => _saveRect();

  @override
  void onWindowResized() => _saveRect();

  /// Мышь проходит сквозь окно к игре. Вернуть — Ctrl+Shift+X.
  Future<void> toggleClickThrough() async {
    if (!isWindows) return;
    clickThrough = !clickThrough;
    try {
      await windowManager.setIgnoreMouseEvents(clickThrough, forward: clickThrough);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setOpacity(double v) async {
    tools?.setOverlay(opacity: v.clamp(0.3, 1.0));
    if (active) {
      try {
        await windowManager.setOpacity(opacity);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> toggleVisible() async {
    try {
      if (await windowManager.isVisible()) {
        await windowManager.hide();
      } else {
        await windowManager.show();
      }
    } catch (_) {}
  }
}

final overlay = OverlayController();

/// Горячие клавиши: действие, подпись, клавиша по умолчанию (Ctrl+Shift+…).
class HotAction {
  final String id;
  final String ru, en;
  final PhysicalKeyboardKey key;
  const HotAction(this.id, this.ru, this.en, this.key);
  String get title => L(ru, en);
}

const hotActions = [
  HotAction('overlay', 'Оверлей вкл/выкл', 'Toggle overlay', PhysicalKeyboardKey.keyO),
  HotAction('click', 'Сквозной для мыши', 'Click-through', PhysicalKeyboardKey.keyX),
  HotAction('hide', 'Спрятать/показать окно', 'Hide/show window', PhysicalKeyboardKey.keyH),
  HotAction('strip', 'Полоса таймеров', 'Timer strip', PhysicalKeyboardKey.keyM),
  HotAction('roshan', 'Рошан убит', 'Roshan killed', PhysicalKeyboardKey.keyR),
  HotAction('tormentor', 'Торментор убит', 'Tormentor killed', PhysicalKeyboardKey.keyT),
  HotAction('draft', 'Драфт с экрана', 'Draft from screen', PhysicalKeyboardKey.keyD),
  HotAction('enemies', 'Враги с экрана', 'Enemies from screen', PhysicalKeyboardKey.keyE),
];

/// Сохранённая клавиша: {"k": usbHidUsage, "m": ["control","shift"], "l": "Ctrl+Shift+O"}.
class KeyCombo {
  final int usage;
  final List<String> mods;
  final String label;
  const KeyCombo(this.usage, this.mods, this.label);

  static KeyCombo defaultFor(HotAction a) =>
      KeyCombo(a.key.usbHidUsage, const ['control', 'shift'], 'Ctrl+Shift+${a.id == 'overlay' ? 'O' : _letter(a.key)}');

  static String _letter(PhysicalKeyboardKey k) {
    const a = 0x00070004; // keyA
    final i = k.usbHidUsage - a;
    return i >= 0 && i < 26 ? String.fromCharCode(65 + i) : '?';
  }

  String toJson() => jsonEncode({'k': usage, 'm': mods, 'l': label});

  static KeyCombo? parse(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map;
      return KeyCombo((j['k'] as num).toInt(), [for (final m in (j['m'] as List)) '$m'], '${j['l']}');
    } catch (_) {
      return null;
    }
  }

  HotKey? toHotKey() {
    final k = PhysicalKeyboardKey.findKeyByCode(usage);
    if (k == null) return null;
    return HotKey(
      key: k,
      modifiers: [
        for (final m in mods)
          switch (m) {
            'control' => HotKeyModifier.control,
            'shift' => HotKeyModifier.shift,
            'alt' => HotKeyModifier.alt,
            _ => HotKeyModifier.meta,
          },
      ],
      scope: HotKeyScope.system,
    );
  }
}

KeyCombo comboFor(ToolsState t, HotAction a) => KeyCombo.parse(t.hotkeys[a.id]) ?? KeyCombo.defaultFor(a);

/// Обработчики горячих клавиш (заполняются при запуске).
final Map<String, VoidCallback> hotkeyHandlers = {
  'overlay': () => overlay.toggle(),
  'click': () => overlay.toggleClickThrough(),
  'hide': () => overlay.toggleVisible(),
  'strip': () => overlay.toggleStrip(),
};

/// Зарегистрировать горячие клавиши по настройкам.
Future<void> registerHotkeys(ToolsState t) async {
  if (!isWindows) return;
  try {
    await hotKeyManager.unregisterAll();
  } catch (_) {}
  for (final a in hotActions) {
    final hk = comboFor(t, a).toHotKey();
    if (hk == null) continue;
    try {
      await hotKeyManager.register(hk, keyDownHandler: (_) => hotkeyHandlers[a.id]?.call());
    } catch (_) {}
  }
}

/// Подготовка окна на Windows.
Future<void> initDesktop() async {
  if (!isWindows) return;
  try {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(480, 900),
      minimumSize: Size(360, 480),
      title: 'Dota Draft',
      backgroundColor: Color(0xFF0B0B0D),
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (_) {}
}

/// Подпись клавиши из нажатия (для записи своей комбинации).
String keyLabel(KeyEvent e) {
  final l = e.logicalKey.keyLabel;
  return l.isEmpty ? '#${e.physicalKey.usbHidUsage & 0xFFFF}' : l.toUpperCase();
}

bool isModifierKey(PhysicalKeyboardKey k) => <PhysicalKeyboardKey>{
      PhysicalKeyboardKey.controlLeft,
      PhysicalKeyboardKey.controlRight,
      PhysicalKeyboardKey.shiftLeft,
      PhysicalKeyboardKey.shiftRight,
      PhysicalKeyboardKey.altLeft,
      PhysicalKeyboardKey.altRight,
      PhysicalKeyboardKey.metaLeft,
      PhysicalKeyboardKey.metaRight,
    }.contains(k);

/// Комбинация из события клавиатуры (null — нажата только клавиша-модификатор).
KeyCombo? comboFromEvent(KeyEvent e) {
  if (e is! KeyDownEvent || isModifierKey(e.physicalKey)) return null;
  final hw = HardwareKeyboard.instance;
  final mods = <String>[
    if (hw.isControlPressed) 'control',
    if (hw.isShiftPressed) 'shift',
    if (hw.isAltPressed) 'alt',
    if (hw.isMetaPressed) 'meta',
  ];
  final names = {'control': 'Ctrl', 'shift': 'Shift', 'alt': 'Alt', 'meta': 'Win'};
  return KeyCombo(e.physicalKey.usbHidUsage, mods, [...mods.map((m) => names[m]!), keyLabel(e)].join('+'));
}
