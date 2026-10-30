import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background.dart';
import 'coach.dart';
import 'desktop.dart';
import 'gsi.dart';
import 'i18n.dart';
import 'overlay.dart';
import 'platform.dart';
import 'screens/draft_screen.dart';
import 'screens/home_shell.dart';
import 'screens/matches_screen.dart';
import 'screens/overlay_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'tools_state.dart';

/// Для сообщений без контекста (например, напоминание о перерыве после матча).
final messengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktop();
  if (isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: C.bg,
      systemNavigationBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
    ));
  }
  final state = AppState();
  final tools = ToolsState();
  runApp(StateScope(state: state, child: ToolsScope(state: tools, child: const DotaDraftApp())));
  await tools.load();
  overlay.attach(tools);
  coach.attach(state, tools);
  // После матча — сам открыть разбор.
  coach.openMatch = (id, hero) => navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => MatchScreen(matchId: id, myHero: hero == 0 ? null : hero)));
  desktopMessage = (text) => messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
  if (tools.gsiOn) gsi.start(onPort: tools.gsiPort);
  gsi.onGameEnd(() {
    final n = tools.breakAfter;
    if (n > 0 && gsi.gamesFinished > 0 && gsi.gamesFinished % n == 0) {
      final msg = L('Ты сыграл ${gsi.gamesFinished} игр подряд — сделай перерыв 15 минут.',
          'You played ${gsi.gamesFinished} games in a row — take a 15-minute break.');
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 10)));
      if (isAndroid) notify(3, L('Пора отдохнуть', 'Time for a break'), msg);
    }
  });
  await state.init();
  await desktopStart(state, tools);
  if (isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
      await initNotifications();
      if (state.notify) await scheduleBackground(true);
    } catch (_) {}
  }
}

class DotaDraftApp extends StatelessWidget {
  const DotaDraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return MaterialApp(
      key: ValueKey('${s.lang}-${s.theme}'),
      title: 'Dota Draft',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      // Всё приложение — выше системных кнопок телефона.
      builder: (context, child) => ColoredBox(
        color: C.bg,
        child: SafeArea(top: false, left: false, right: false, child: child ?? const SizedBox()),
      ),
      home: const _Gate(),
    );
  }
}

/// Пока данные грузятся — экран загрузки, потом приложение (или компактный оверлей на Windows).
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    if (s.loading || s.data == null) return const DraftScreen();
    return ListenableBuilder(
      listenable: overlay,
      builder: (_, __) => overlay.active ? const OverlayScreen() : const HomeShell(),
    );
  }
}
