import 'package:flutter/material.dart';

import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cm_screen.dart';
import 'compare_screen.dart';
import 'cooldowns_screen.dart';
import 'friend_compare_screen.dart';
import 'goals_screen.dart';
import 'matches_screen.dart';
import 'rank_screen.dart';
import 'scan_draft_screen.dart';
import 'who_won_screen.dart';
import 'map_screen.dart';
import 'quiz_screen.dart';
import 'stats_screen.dart';
import 'timer_screen.dart';

/// Вкладка «Игра»: инструменты на время матча и для тренировки.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Игра', 'Game'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          SectionLabel(L('Драфт', 'Draft')),
          _tile(Icons.photo_camera_outlined, L('Драфт по скриншоту', 'Draft from screenshot'),
              L('Сфотографируй экран драфта — герои заполнятся сами', 'Photo of the draft screen — heroes fill in automatically'), C.gold,
              () => go(const ScanDraftScreen())),
          _tile(Icons.format_list_numbered, 'Captains Mode',
              L('Пики и баны по очереди с подсказками на каждый ход', 'Step-by-step picks and bans with advice on every turn'), C.accent,
              () => go(const CmScreen())),
          SectionLabel(L('Во время матча', 'During the match')),
          _tile(Icons.timer_outlined, L('Таймеры матча', 'Match timers'),
              L('Руны, стаки, Рошан, Аегис, Торментор, день и ночь — с голосом', 'Runes, stacks, Roshan, Aegis, Tormentor, day/night — with voice'),
              C.gold, () => go(const TimerScreen())),
          _tile(Icons.bolt, L('Ульты и байбэки врагов', 'Enemy ults & buybacks'),
              L('Отсчёт перезарядки ультов и выкупа — понятно, когда драться', 'Ult and buyback cooldowns — know when to fight'), C.enemy,
              () => go(const CooldownsScreen())),
          _tile(Icons.alt_route, L('Маршруты фарма', 'Farm routes'),
              L('Для керри: лагеря, порядок фарма, стаки, свои маршруты', 'For carries: camps, farm order, stacks, custom routes'), C.ally,
              () => go(const MapScreen(wards: false))),
          _tile(Icons.visibility_outlined, L('Карта вардов', 'Ward map'),
              L('Для саппорта: обсы и сентри по стадиям игры + твои варды из Steam', 'For supports: obs and sentries by game phase + your wards'),
              C.intel, () => go(const MapScreen(wards: true))),
          SectionLabel(L('После матча', 'After the match')),
          _tile(Icons.fact_check_outlined, L('Разбор последнего матча', 'Last match breakdown'),
              L('MVP, кто недоиграл, кто руинил, почему проиграли', 'MVP, who underperformed, who ruined, why you lost'), C.gold,
              () => _openLast(context)),
          _tile(Icons.query_stats, L('Моя статистика', 'My stats'),
              L('Ты против игроков своего ранга, выше и ниже; тильт; друзья', 'You vs players of your rank, above and below; tilt; friends'),
              C.accent, () => go(const StatsScreen())),
          _tile(Icons.flag_outlined, L('Цели и прогресс', 'Goals & progress'),
              L('Например, 60 добиваний к 10 минуте — график по неделям', 'E.g. 60 last hits by 10 minutes — weekly chart'), C.ally,
              () => go(const GoalsScreen())),
          _tile(Icons.military_tech_outlined, L('Мой ранг', 'My rank'),
              L('История медали и прогноз, куда поднимешься', 'Medal history and where you are heading'), C.gold,
              () => go(const RankScreen())),
          _tile(Icons.people_outline, L('Сравнение с другом', 'Compare with a friend'),
              L('Кто лучше фармит, реже умирает и на каких героях', 'Who farms better, dies less and on which heroes'), C.intel,
              () => go(const FriendCompareScreen())),
          SectionLabel(L('Тренировка', 'Practice')),
          _tile(Icons.compare_arrows, L('Сравнить героев', 'Compare heroes'),
              L('Два героя бок о бок: винрейт, фарм, время игры, контрпики', 'Two heroes side by side: win rate, farm, timing, counters'),
              C.accent2, () => go(const CompareScreen())),
          _tile(Icons.quiz_outlined, L('Квиз', 'Quiz'),
              L('10 вопросов: контрпики, связки, предметы, позиции', '10 questions: counters, combos, items, positions'), C.uni,
              () => go(const QuizScreen())),
          _tile(Icons.emoji_events_outlined, L('Кто победил?', 'Who won?'),
              L('Реальные драфты про-матчей — угадай победителя', 'Real pro drafts — guess the winner'), C.gold,
              () => go(const WhoWonScreen())),
        ],
      ),
    );
  }

  Future<void> _openLast(BuildContext context) async {
    final s = StateScope.read(context);
    if (s.accountId == null) {
      showToast(context, L('Сначала укажи Steam ID во вкладке «Мои герои»', 'Add your Steam ID on the My heroes tab first'));
      return;
    }
    showToast(context, L('Загружаю последний матч…', 'Loading the last match…'));
    try {
      final r = await OpenDota.recent(s.accountId!);
      if (!context.mounted) return;
      if (r.isEmpty) {
        showToast(context, L('Матчей не найдено', 'No matches found'));
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(matchId: r.first.matchId, myHero: r.first.heroId)));
    } on OdException catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  Widget _tile(IconData icon, String title, String sub, Color color, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: T.small),
              ]),
            ),
            const Icon(Icons.chevron_right, color: C.muted),
          ]),
        ),
      );
}
