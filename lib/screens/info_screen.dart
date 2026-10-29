import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final d = s.data!;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: const Text('О данных', style: T.h2)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('СТАТИСТИКА', style: T.label),
              const SizedBox(height: 8),
              Text('Обновлено: ${d.updated}', style: T.body),
              Text('Героев: ${d.heroes.length}', style: T.body),
              Text('Матчей в выборке для контрпиков и синергии: ~${d.matches}', style: T.body),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: s.updating
                      ? null
                      : () async {
                          final ok = await s.refresh(force: true);
                          if (context.mounted) {
                            showToast(context, ok ? 'Данные обновлены' : 'Не удалось обновить — проверь интернет');
                          }
                        },
                  icon: s.updating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Обновить сейчас', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          const SectionLabel('Откуда данные'),
          const AppCard(
            child: Text(
              'Статистика берётся из открытого API OpenDota (публичные рейтинговые матчи Dota 2) и обновляется '
              'автоматически раз в сутки. Приложение само скачивает свежую версию при запуске.\n\n'
              'Винрейт и популярность героя считаются отдельно для каждой группы рангов. Контрпики и синергия — по '
              'свежей выборке матчей всех рангов за последние 2–3 недели.',
              style: T.body,
            ),
          ),
          const SectionLabel('Как считается'),
          const AppCard(
            child: Text(
              '• Преимущество против героя — насколько чаще побеждают в этом противостоянии, чем ожидалось бы по общим '
              'винрейтам обоих героев.\n'
              '• Синергия — то же для пары героев в одной команде.\n'
              '• Шанс победы складывает силу героев, синергию и контрпики. Это ориентир: исход игры решают игроки.\n'
              '• 1 пик — сильные и трудно контрящиеся герои; 3 пик — лучший контрпик против выбранных врагов.\n'
              '• Лучшая команда подбирается перебором, чтобы были закрыты позиции 1–5.',
              style: T.body,
            ),
          ),
        ],
      ),
    );
  }
}
