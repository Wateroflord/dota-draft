import 'dart:io';

import 'package:window_manager/window_manager.dart';

import 'data.dart';
import 'gsi.dart';
import 'i18n.dart';
import 'overlay.dart';
import 'platform.dart';
import 'screen_draft.dart';
import 'screens/live_screen.dart';
import 'state.dart';
import 'tools_state.dart';
import 'winutil.dart';

/// Сообщение на экране + уведомление Windows (если окно спрятано).
void Function(String text)? desktopMessage;

class _CloseGuard with WindowListener {
  final ToolsState tools;
  _CloseGuard(this.tools);

  @override
  void onWindowClose() async {
    if (tools.trayOnClose) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }
}

/// Запуск всего, что есть только на Windows: трей, горячие клавиши, слежение за Dota, OBS.
Future<void> desktopStart(AppState s, ToolsState t) async {
  if (!isWindows) return;

  void say(String text) {
    desktopMessage?.call(text);
    showToastWin('Dota Draft', text);
  }

  hotkeyHandlers['roshan'] = () {
    final c = gsi.last?.clock;
    if (c != null) {
      liveMarks.roshan(c);
      say(L('Рошан отмечен', 'Roshan marked'));
    }
  };
  hotkeyHandlers['tormentor'] = () {
    final c = gsi.last?.clock;
    if (c != null) {
      liveMarks.tormentor(c);
      say(L('Торментор отмечен', 'Tormentor marked'));
    }
  };
  hotkeyHandlers['draft'] = () async => say(await draftFromScreen(s));
  hotkeyHandlers['enemies'] = () async => say(await draftFromScreen(s, enemiesOnly: true));
  await registerHotkeys(t);

  // Закрытие окна — в трей.
  try {
    await windowManager.setPreventClose(true);
    windowManager.addListener(_CloseGuard(t));
  } catch (_) {}

  // Иконка в трее.
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final icon = '$exeDir\\data\\flutter_assets\\assets\\tray.ico';
  tray.onShow = () async {
    await windowManager.show();
    await windowManager.focus();
  };
  tray.onOverlay = () => overlay.toggle();
  tray.onQuit = () async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  };
  await tray.init(icon);

  // Dota запущена → оверлей; закрыта → обычное окно.
  dotaWatcher.onChange = (running) {
    if (!t.autoOverlay) return;
    if (running) {
      overlay.enter();
    } else {
      overlay.exit();
    }
  };
  dotaWatcher.start();

  // Враги с экрана в начале матча (один раз за игру).
  String? scannedMatch;
  gsi.addListener(() async {
    final g = gsi.last;
    if (g == null || !t.autoEnemies) return;
    final c = g.clock ?? -1;
    if (g.matchId.isEmpty || g.matchId == scannedMatch) return;
    if (c >= 5 && c <= 150 && s.enemies.every((e) => e == null)) {
      scannedMatch = g.matchId;
      final msg = await draftFromScreen(s, enemiesOnly: true);
      say(msg);
    }
  });

  // Страница для OBS.
  obs.state = () => obsState(s);
  if (t.obsServer) await obs.start();
}

/// Данные для страницы OBS.
Map<String, dynamic> obsState(AppState s) {
  final allies = s.allyHeroes, enemies = s.enemyHeroes;
  final e = s.engine;
  final chance = allies.isEmpty && enemies.isEmpty ? 0.0 : e.winChance(allies, enemies);
  Map<String, String> h(DHero x) => {'name': x.name, 'img': x.image};
  return {
    'allies': [for (final x in allies) h(x)],
    'enemies': [for (final x in enemies) h(x)],
    'chance': chance,
    'label': L('Шанс победы', 'Win chance'),
    'la': L('МЫ', 'US'),
    'le': L('ВРАГИ', 'THEM'),
  };
}
