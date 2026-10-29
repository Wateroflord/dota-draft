import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/draft_screen.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final state = AppState();
  runApp(StateScope(state: state, child: const DotaDraftApp()));
  state.init();
}

class DotaDraftApp extends StatelessWidget {
  const DotaDraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dota Draft',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Всё приложение — выше системных кнопок телефона.
      builder: (context, child) => ColoredBox(
        color: C.bg,
        child: SafeArea(top: false, left: false, right: false, child: child ?? const SizedBox()),
      ),
      home: const DraftScreen(),
    );
  }
}
