import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import 'compare_screen.dart';
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
        title: const Text('Игра', style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          const SectionLabel('Во время матча'),
          _tile(Icons.timer_outlined, 'Таймеры матча', 'Руны, стаки, Рошан, Аегис, Торментор, день и ночь — с голосом', C.gold,
              () => go(const TimerScreen())),
          _tile(Icons.alt_route, 'Маршруты фарма', 'Для керри: лагеря, порядок фарма, стаки, свои маршруты', C.ally,
              () => go(const MapScreen(wards: false))),
          _tile(Icons.visibility_outlined, 'Карта вардов', 'Для саппорта: обсы и сентри по стадиям игры + твои варды из Steam',
              C.intel, () => go(const MapScreen(wards: true))),
          const SectionLabel('Подготовка'),
          _tile(Icons.query_stats, 'Моя статистика', 'Ты против игроков своего ранга, выше и ниже; тильт; друзья', C.accent,
              () => go(const StatsScreen())),
          _tile(Icons.compare_arrows, 'Сравнить героев', 'Два героя бок о бок: винрейт, фарм, время игры, контрпики',
              C.accent2, () => go(const CompareScreen())),
          _tile(Icons.quiz_outlined, 'Квиз', '10 вопросов: контрпики, связки, предметы, позиции', C.uni,
              () => go(const QuizScreen())),
        ],
      ),
    );
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
