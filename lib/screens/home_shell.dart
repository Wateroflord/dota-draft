import '../i18n.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../update.dart';
import '../widgets.dart';
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
  UpdateInfo? update;
  double? progress; // скачивание установщика (Windows)

  @override
  void initState() {
    super.initState();
    checkUpdate().then((u) {
      if (mounted && u != null) setState(() => update = u);
    });
  }

  static List<(IconData, IconData, String)> get _tabs => [
    (Icons.grid_view_outlined, Icons.grid_view_rounded, L('Драфт', 'Draft')),
    (Icons.insights_outlined, Icons.insights, L('Анализ', 'Analysis')),
    (Icons.leaderboard_outlined, Icons.leaderboard, L('Мета', 'Meta')),
    (Icons.sports_esports_outlined, Icons.sports_esports, L('Игра', 'Game')),
    (Icons.person_outline, Icons.person, L('Мои герои', 'My heroes')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        if (update != null)
          Material(
            color: C.accent,
            child: InkWell(
              onTap: () async {
                if (progress != null) return;
                if (update!.setup != null) setState(() => progress = 0);
                final err = await installUpdate(update!, progress: (p) {
                  if (mounted) setState(() => progress = p);
                });
                if (err != null && mounted) {
                  setState(() => progress = null);
                  showToast(context, err);
                }
              },
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.system_update, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          progress != null
                              ? L('Скачиваю обновление… ${(progress! * 100).round()}%', 'Downloading the update… ${(progress! * 100).round()}%')
                              : update!.setup != null
                                  ? L('Вышла новая версия (build-${update!.build}). Нажми — обновлю сам.', 'A new version is out (build-${update!.build}). Tap to update.')
                                  : L('Вышла новая версия (build-${update!.build}). Нажми, чтобы скачать.',
                                      'A new version is out (build-${update!.build}). Tap to download.'),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    InkWell(onTap: () => setState(() => update = null), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                  ]),
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: update != null,
            child: IndexedStack(
            index: index,
            children: [
              const DraftScreen(),
              AnalysisScreen(onOpenDraft: () => setState(() => index = 0)),
              const MetaScreen(),
              const GameScreen(),
              const ProfileScreen(),
            ],
          ),
          ),
        ),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
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
