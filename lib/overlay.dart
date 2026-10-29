import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'gsi.dart';
import 'platform.dart';
import 'screens/live_screen.dart';

/// Режим оверлея на Windows: маленькое окно поверх всех окон, полупрозрачное, можно сделать «сквозным» для мыши.
class OverlayController extends ChangeNotifier {
  bool active = false;
  bool clickThrough = false;
  double opacity = 0.9;
  Size? _size;
  Offset? _pos;

  Future<void> enter() async {
    if (!isWindows || active) return;
    try {
      _size = await windowManager.getSize();
      _pos = await windowManager.getPosition();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setMinimumSize(const Size(300, 260));
      await windowManager.setSize(const Size(360, 600));
      await windowManager.setOpacity(opacity);
    } catch (_) {}
    active = true;
    notifyListeners();
  }

  Future<void> exit() async {
    if (!isWindows || !active) return;
    try {
      if (clickThrough) await windowManager.setIgnoreMouseEvents(false);
      clickThrough = false;
      await windowManager.setOpacity(1);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setMinimumSize(const Size(360, 480));
      if (_size != null) await windowManager.setSize(_size!);
      if (_pos != null) await windowManager.setPosition(_pos!);
    } catch (_) {}
    active = false;
    notifyListeners();
  }

  Future<void> toggle() => active ? exit() : enter();

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
    opacity = v.clamp(0.3, 1.0);
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

/// Подготовка окна и горячих клавиш на Windows.
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
  try {
    await hotKeyManager.unregisterAll();
    HotKey key(PhysicalKeyboardKey k) =>
        HotKey(key: k, modifiers: [HotKeyModifier.control, HotKeyModifier.shift], scope: HotKeyScope.system);
    await hotKeyManager.register(key(PhysicalKeyboardKey.keyO), keyDownHandler: (_) => overlay.toggle());
    await hotKeyManager.register(key(PhysicalKeyboardKey.keyX), keyDownHandler: (_) => overlay.toggleClickThrough());
    await hotKeyManager.register(key(PhysicalKeyboardKey.keyH), keyDownHandler: (_) => overlay.toggleVisible());
    await hotKeyManager.register(key(PhysicalKeyboardKey.keyR), keyDownHandler: (_) {
      final c = gsi.last?.clock;
      if (c != null) liveMarks.roshan(c);
    });
  } catch (_) {}
}
