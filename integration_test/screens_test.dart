// Прогон всех экранов на эмуляторе: скриншоты и список ошибок (для проверки перед выпуском).
import 'package:dota_draft/main.dart' as app;
import 'package:dota_draft/screens/cm_screen.dart';
import 'package:dota_draft/screens/compare_screen.dart';
import 'package:dota_draft/screens/cooldowns_screen.dart';
import 'package:dota_draft/screens/friend_compare_screen.dart';
import 'package:dota_draft/screens/goals_screen.dart';
import 'package:dota_draft/screens/hero_screen.dart';
import 'package:dota_draft/screens/map_screen.dart';
import 'package:dota_draft/screens/matches_screen.dart';
import 'package:dota_draft/screens/quiz_screen.dart';
import 'package:dota_draft/screens/rank_screen.dart';
import 'package:dota_draft/screens/scan_draft_screen.dart';
import 'package:dota_draft/screens/share_screen.dart';
import 'package:dota_draft/screens/stats_screen.dart';
import 'package:dota_draft/screens/timer_screen.dart';
import 'package:dota_draft/screens/who_won_screen.dart';
import 'package:dota_draft/screens/home_shell.dart';
import 'package:dota_draft/state.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];

  testWidgets('all screens', (tester) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/shots');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final log = File('${dir.path}/errors.txt');
    void note(String m) {
      errors.add(m);
      // ignore: avoid_print
      print('SHOT-ERROR: $m');
      log.writeAsStringSync('$m\n', mode: FileMode.append);
    }

    final old = FlutterError.onError;
    FlutterError.onError = (d) {
      note('${d.exceptionAsString().split('\n').take(3).join(' | ')} @ ${d.context?.toDescription() ?? ''}\n${d.stack.toString().split('\n').take(6).join('\n')}');
    };
    app.main();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(HomeShell).evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(seconds: 3));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    var n = 0;
    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1500));
      n++;
      final file = '${n.toString().padLeft(2, '0')}_$name';
      try {
        final bytes = await binding.takeScreenshot(file);
        File('${dir.path}/$file.png').writeAsBytesSync(bytes);
        // ignore: avoid_print
        print('SHOT: $file');
      } catch (e) {
        note('screenshot $name: $e');
      }
    }

    BuildContext ctx() => tester.element(find.byType(HomeShell));
    AppState st() => StateScope.read(ctx());
    NavigatorState nav() => Navigator.of(ctx());

    Future<void> open(String name, Widget w, {Future<void> Function()? then}) async {
      try {
        nav().push(MaterialPageRoute(builder: (_) => w));
        await tester.pump(const Duration(seconds: 2));
        await shot(name);
        if (then != null) await then();
      } catch (e) {
        note('open $name: $e');
      }
      nav().popUntil((r) => r.isFirst);
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> tab(String label) async {
      final f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.last);
        await tester.pump(const Duration(seconds: 1));
      } else {
        note('tab not found: $label');
      }
    }

    final s = st();
    final ids = s.data!.heroes.map((h) => h.id).toList();
    s.setSlot(true, 0, ids[0]);
    s.setSlot(true, 1, ids[10]);
    s.setSlot(true, 2, ids[20]);
    s.setSlot(false, 0, ids[30]);
    s.setSlot(false, 1, ids[40]);
    s.setSlot(false, 2, ids[50]);
    s.setSlot(false, 3, ids[60]);
    await shot('draft');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await shot('draft_picks');
    await tab('Анализ');
    await shot('analysis');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await shot('analysis_more');
    await tab('Мета');
    await shot('meta');
    final patch = find.text('Патч');
    if (patch.evaluate().isNotEmpty) {
      await tester.tap(patch.first);
      await shot('meta_patch');
    }
    await tab('Игра');
    await shot('game');
    await tab('Мои герои');
    await shot('profile');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await shot('profile_more');
    await tab('Драфт');

    final hero = s.data!.byId[ids[10]]!;
    await open('hero', HeroScreen(hero: hero), then: () async {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await shot('hero_more');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await shot('hero_more2');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await shot('hero_more3');
    });
    await open('compare', CompareScreen(first: hero));
    await open('cm', const CmScreen(), then: () async {
      final start = find.byIcon(Icons.play_arrow);
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start);
        await shot('cm_started');
      }
    });
    await open('cooldowns', const CooldownsScreen());
    await open('scan', const ScanDraftScreen());
    await open('share', const ShareScreen());
    await open('timer', const TimerScreen());
    await open('farm', const MapScreen(wards: false));
    await open('wards', const MapScreen(wards: true));
    await open('quiz', const QuizScreen());
    await open('who_won', const WhoWonScreen());
    if (s.proDrafts.isNotEmpty) {
      await open('match', MatchScreen(matchId: s.proDrafts.first.id), then: () async {
        await tester.pump(const Duration(seconds: 6));
        await shot('match_loaded');
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
        await shot('match_more');
      });
    }
    // Профиль с открытыми данными (публичный аккаунт).
    try {
      await s.loadPlayer('105248644');
    } catch (e) {
      note('loadPlayer: $e');
    }
    await open('stats', const StatsScreen(), then: () async {
      await tester.pump(const Duration(seconds: 8));
      await shot('stats_loaded');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
      await shot('stats_more');
    });
    await open('rank', const RankScreen());
    await open('goals', const GoalsScreen());
    await open('friend', const FriendCompareScreen());
    s.setLang('en');
    await tester.pump(const Duration(seconds: 2));
    await shot('english_draft');
    await tab('Game');
    await shot('english_game');
    s.setLang('ru');
    await tester.pump(const Duration(seconds: 1));

    FlutterError.onError = old;
    binding.reportData = {'errors': errors};
    // ignore: avoid_print
    print('ERRORS: ${errors.length}\n${errors.join('\n')}');
  });
}
