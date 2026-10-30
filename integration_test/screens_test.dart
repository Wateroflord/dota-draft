// Прогон всех экранов на эмуляторе: скриншоты и список ошибок (для проверки перед выпуском).
import 'package:dota_draft/storage.dart';
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
import 'package:dota_draft/screens/live_screen.dart';
import 'package:dota_draft/screens/personal_screen.dart';
import 'package:dota_draft/screens/item_timings_screen.dart';
import 'package:dota_draft/screens/items_screen.dart';
import 'package:dota_draft/screens/trainer_screen.dart';
import 'package:dota_draft/screens/checklist_screen.dart';
import 'package:dota_draft/screens/home_shell.dart';
import 'package:dota_draft/state.dart';
import 'package:dota_draft/coach.dart';
import 'package:dota_draft/gsi.dart';
import 'package:dota_draft/tools_state.dart';
import 'package:dota_draft/screens/farm_report_screen.dart';
import 'package:dota_draft/screens/learn_screen.dart';
import 'package:dota_draft/screens/lasthit_screen.dart';
import 'package:dota_draft/screens/session_screen.dart';
import 'package:dota_draft/screens/desktop_settings_screen.dart';
import 'package:dota_draft/screens/transfer_screen.dart';
import 'package:dota_draft/screens/dashboard_screen.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];

  testWidgets('all screens', (tester) async {
    final dir = Directory('${(await appDir()).path}/shots');
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

    BuildContext ctx() => tester.element(find.byType(HomeShell, skipOffstage: false));
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
    await open('matches_browser', const MatchesScreen(), then: () async {
      await tester.pump(const Duration(seconds: 6));
      await shot('matches_loaded');
    });
    await open('personal', const PersonalScreen());
    await open('item_timings', const ItemTimingsScreen(), then: () async {
      await tester.pump(const Duration(seconds: 10));
      await shot('item_timings_loaded');
    });
    await open('items', const ItemsScreen());
    await open('trainer', const TrainerScreen(), then: () async {
      final start = find.byIcon(Icons.play_arrow);
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start);
        await shot('trainer_started');
      }
    });
    await open('checklist', const ChecklistScreen(position: 5));
    await open('live', const LiveScreen());
    await open('goals', const GoalsScreen());
    await open('friend', const FriendCompareScreen());
    // Новые экраны.
    await open('learn', const LearnScreen());
    await open('lasthit', const LastHitScreen(), then: () async {
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump(const Duration(seconds: 2));
      await shot('lasthit_running');
    });
    await open('session', const SessionScreen(), then: () async {
      await tester.pump(const Duration(seconds: 6));
      await shot('session_loaded');
    });
    await open('hints_settings', const DesktopSettingsScreen());
    await open('transfer', const TransferScreen());

    // Имитация матча через Game State Integration: герой фармит лес, тренер даёт подсказки, маршрут записывается.
    try {
      final tools = ToolsScope.read(ctx());
      tools.setFlags(autoBreakdown: false, coachVoice: false);
      s.setMyPos(1);
      await gsi.start(onPort: 3000);
      final hero = s.data!.heroes.first;
      final info = s.info.heroes[hero.id];
      Future<void> post(Map<String, dynamic> j) async {
        final c = HttpClient();
        final r = await c.post('127.0.0.1', 3000, '/');
        r.headers.contentType = ContentType.json;
        r.write(jsonEncode(j));
        await (await r.close()).drain<void>();
        c.close();
      }

      Map<String, dynamic> state(int clock, double sx, double sy, {int level = 6, int deaths = 0, String gs = 'DOTA_GAMERULES_STATE_GAME_IN_PROGRESS', bool alive = true}) => {
            'map': {'clock_time': clock, 'game_state': gs, 'matchid': '7777777777', 'daytime': true, 'win_team': gs.contains('POST') ? 'radiant' : 'none', 'ward_purchase_cooldown': 0},
            'player': {'team_name': 'radiant', 'gold': 900 + clock, 'gpm': 300 + clock ~/ 6, 'xpm': 400, 'kills': 2, 'deaths': deaths, 'assists': 3, 'last_hits': clock ~/ 8, 'denies': 4, 'net_worth': 4000 + clock * 3},
            'hero': {'id': hero.id, 'name': 'npc_dota_hero_${hero.key}', 'level': level, 'alive': alive, 'respawn_seconds': alive ? 0 : 20, 'buyback_cost': 600, 'buyback_cooldown': 0,
              'xpos': (sx * 166 - 8300).round(), 'ypos': ((100 - sy) * 166 - 8300).round()},
            'items': {'slot0': {'name': 'item_power_treads'}, 'slot1': {'name': 'empty'}},
            'abilities': {
              for (final (i, a) in (info?.abilities.where((a) => a.granted.isEmpty).take(4).toList() ?? []).indexed)
                'ability$i': {'name': a.key, 'level': i < 3 ? 2 : 0, 'ultimate': a.ult, 'cooldown': 0},
            },
          };
      // Путь по лесу Света: с линии в лес и обратно.
      final path = [for (var i = 0; i <= 40; i++) (40 + i * 0.6, 88 - i * 0.4)];
      var clock = 540;
      for (final (i, p) in path.indexed) {
        await post(state(clock, p.$1, p.$2, level: i < 20 ? 6 : 7, deaths: i < 30 ? 0 : 1, alive: i < 30 || i > 33));
        clock += 3;
        if (i % 8 == 0) await tester.pump(const Duration(milliseconds: 50));
      }
      await open('live_coach', const LiveScreen(), then: () async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await shot('live_coach_more');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await shot('live_coach_more2');
      });
      await open('dashboard', const DashboardScreen());
      await post(state(clock, 60, 72, level: 7, deaths: 1, gs: 'DOTA_GAMERULES_STATE_POST_GAME'));
      await tester.pump(const Duration(seconds: 1));
      await open('farm_list', const FarmReportScreen());
      if (coach.history.isNotEmpty) {
        await open('farm_report', FarmReportDetail(rec: coach.history.first), then: () async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
          await shot('farm_report_more');
        });
      } else {
        note('coach history is empty after fake match');
      }
      await gsi.stop();
    } catch (e) {
      note('gsi sim: $e');
    }

    s.setLang('en');
    await tester.pump(const Duration(seconds: 2));
    await shot('english_draft');
    await tab('Game');
    await shot('english_game');
    s.setLang('ru');
    await tester.pump(const Duration(seconds: 1));
    s.setTheme('light');
    await tester.pump(const Duration(seconds: 2));
    await shot('light_draft');
    await tab('Мои герои');
    await shot('light_profile');
    s.setTheme('dark');
    await tester.pump(const Duration(seconds: 1));

    FlutterError.onError = old;
    binding.reportData = {...?binding.reportData, 'errors': errors};
    // ignore: avoid_print
    print('ERRORS: ${errors.length}\n${errors.join('\n')}');
  });
}
