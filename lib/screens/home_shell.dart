import 'package:flutter/material.dart';

import '../theme.dart';
import 'analysis_screen.dart';
import 'draft_screen.dart';
import 'game_screen.dart';
import 'meta_screen.dart';
import 'profile_screen.dart';

/// Нижнее меню: Драфт, Анализ, Мета, Игра, Мои герои.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const _tabs = [
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Драфт'),
    (Icons.insights_outlined, Icons.insights, 'Анализ'),
    (Icons.leaderboard_outlined, Icons.leaderboard, 'Мета'),
    (Icons.sports_esports_outlined, Icons.sports_esports, 'Игра'),
    (Icons.person_outline, Icons.person, 'Мои герои'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(
        index: index,
        children: [
          const DraftScreen(),
          AnalysisScreen(onOpenDraft: () => setState(() => index = 0)),
          const MetaScreen(),
          const GameScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
        child: SizedBox(
          height: 60,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => index = i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(index == i ? _tabs[i].$2 : _tabs[i].$1, color: index == i ? C.accent : C.muted, size: 22),
                    const SizedBox(height: 3),
                    Text(_tabs[i].$3,
                        style: TextStyle(
                            fontSize: 11,
                            color: index == i ? C.text : C.muted,
                            fontWeight: index == i ? FontWeight.w600 : FontWeight.w500)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
