import '../i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: Text(L('О данных', 'About the data'), style: T.h2)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L('СТАТИСТИКА', 'STATS'), style: T.label),
              const SizedBox(height: 8),
              Text(L('Обновлено: ${d.updated}', 'Updated: ${d.updated}'), style: T.body),
              Text(L('Героев: ${d.heroes.length}', 'Heroes: ${d.heroes.length}'), style: T.body),
              Text(L('Матчей в выборке для контрпиков и синергии: ~${d.matches}', 'Matches sampled for counters and synergy: ~${d.matches}'), style: T.body),
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
                            showToast(context, ok ? L('Данные обновлены', 'Data updated') : L('Не удалось обновить — проверь интернет', 'Update failed — check your internet'));
                          }
                        },
                  icon: s.updating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(L('Обновить сейчас', 'Update now'), style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
          SectionLabel(L('Офлайн-режим', 'Offline mode')),
          const _OfflineCard(),
          SectionLabel(L('Откуда данные', 'Where the data comes from')),
          AppCard(
            child: Text(
              L('Статистика берётся из открытого API OpenDota (публичные рейтинговые матчи Dota 2) и обновляется '
              'автоматически раз в сутки. Приложение само скачивает свежую версию при запуске.\n\n'
              'Винрейт и популярность героя считаются отдельно для каждой группы рангов и для Турбо. Контрпики, '
              'синергия и сила по времени игры — по свежей выборке рейтинговых матчей за последние 2–3 недели. '
              'Предметы — самые популярные покупки героя на каждой стадии игры. Про-сцена — пики и баны '
              'профессиональных матчей. Тренды — изменение винрейта примерно за неделю.\n\n'
              'Твой профиль и матчи загружаются из OpenDota напрямую с телефона, только когда ты сам нажмёшь «Загрузить».', 'Stats come from the open OpenDota API (public ranked Dota 2 matches) and update '
              'automatically once a day. The app downloads the fresh version on launch.\n\n'
              'Hero win rate and popularity are computed separately for each rank group and for Turbo. Counters, '
              'synergy and strength by game time use a fresh sample of ranked matches from the last 2–3 weeks. '
              'Items are the most popular purchases at each game stage. Pro scene — picks and bans '
              'of professional matches. Trends — win rate change over about a week.\n\n'
              'Abilities, talents and patch notes come from the official Dota 2 data feed. '
              'Your profile and matches load from OpenDota directly on your phone, only when you tap Load.'),
              style: T.body,
            ),
          ),
          SectionLabel(L('Как считается', 'How it is calculated')),
          AppCard(
            child: Text(
              L('• Преимущество против героя — насколько чаще побеждают в этом противостоянии, чем ожидалось бы по общим '
              'винрейтам обоих героев.\n'
              '• Синергия — то же для пары героев в одной команде.\n'
              '• Шанс победы складывает силу героев, синергию и контрпики. Это ориентир: исход игры решают игроки.\n'
              '• 1 пик — сильные и трудно контрящиеся герои; 3 пик — лучший контрпик против выбранных врагов.\n'
              '• Лучшая команда подбирается перебором, чтобы были закрыты позиции 1–5.', '• Advantage vs a hero — how much more often this matchup is won than expected from both heroes\' '
              'overall win rates.\n'
              '• Synergy — the same for a pair of heroes on one team.\n'
              '• Win chance adds up hero strength, synergy and counters. It is a guide: players decide the game.\n'
              '• 1st pick — strong heroes that are hard to counter; 3rd pick — the best counter to picked enemies.\n'
              '• The best team is found by search so that positions 1–5 are covered.'),
              style: T.body,
            ),
          ),
        ],
      ),
    );
  }
}


/// Скачать все картинки, чтобы приложение работало без интернета.
class _OfflineCard extends StatefulWidget {
  const _OfflineCard();

  @override
  State<_OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<_OfflineCard> {
  int done = 0, total = 0;
  bool busy = false;

  Future<void> _download() async {
    final s = StateScope.read(context);
    final urls = <String>{
      for (final h in s.data!.heroes) h.image,
      for (final it in s.data!.items.values) it.image,
      for (final it in s.itemRef.values) it.image,
      for (final h in s.info.heroes.values)
        for (final a in h.abilities) a.image,
    }.toList();
    setState(() {
      busy = true;
      done = 0;
      total = urls.length;
    });
    final cm = DefaultCacheManager();
    for (var i = 0; i < urls.length; i += 6) {
      await Future.wait([
        for (final u in urls.skip(i).take(6))
          cm.downloadFile(u).then((_) {}, onError: (_) {}),
      ]);
      if (!mounted) return;
      setState(() => done = (i + 6).clamp(0, total));
    }
    if (mounted) {
      setState(() => busy = false);
      showToast(context, L('Готово: картинки сохранены на устройстве', 'Done: images saved on the device'));
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            L('Статистика уже хранится на устройстве. Скачай ещё картинки героев, предметов и умений — '
                'тогда приложение полностью работает без интернета (кроме профиля Steam и разбора матчей).',
                'Stats are already stored on the device. Download hero, item and ability images too — '
                'then the app works fully offline (except Steam profile and match breakdowns).'),
            style: T.small,
          ),
          const SizedBox(height: 8),
          if (busy) ...[
            LinearProgressIndicator(value: total == 0 ? null : done / total, color: C.accent, backgroundColor: C.surface2),
            const SizedBox(height: 4),
            Text('$done / $total', style: T.small),
          ] else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
              onPressed: _download,
              icon: const Icon(Icons.download_for_offline_outlined, size: 18),
              label: Text(L('Скачать картинки для офлайна', 'Download images for offline')),
            ),
        ]),
      );
}
