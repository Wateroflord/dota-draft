import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'background.dart';

import 'screens/draft_screen.dart';
import 'screens/home_shell.dart';
import 'state.dart';
import 'theme.dart';
import 'tools_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final state = AppState();
  final tools = ToolsState();
  runApp(StateScope(state: state, child: ToolsScope(state: tools, child: const DotaDraftApp())));
  tools.load();
  await state.init();
  try {
    await AndroidAlarmManager.initialize();
    await initNotifications();
    if (state.notify) await scheduleBackground(true);
  } catch (_) {}
}

class DotaDraftApp extends StatelessWidget {
  const DotaDraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return MaterialApp(
      key: ValueKey(s.lang),
      title: 'Dota Draft',
      debugShowCheckedModeBanner: false,
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

/// Пока данные грузятся — экран загрузки, потом приложение.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    if (s.loading || s.data == null) return const DraftScreen();
    return const HomeShell();
  }
}
