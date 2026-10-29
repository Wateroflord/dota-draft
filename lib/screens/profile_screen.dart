import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';
import 'hero_screen.dart';
import 'history_screen.dart';
import 'info_screen.dart';
import 'matches_screen.dart';

/// «Мои герои»: приоритетные герои (вручную и из Steam), профиль, матчи, история драфтов.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final idCtrl = TextEditingController();

  @override
  void dispose() {
    idCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(AppState s) async {
    FocusScope.of(context).unfocus();
    final err = await s.loadPlayer(idCtrl.text.isEmpty ? '${s.accountId ?? ''}' : idCtrl.text);
    if (!mounted) return;
    if (err != null) {
      showToast(context, err);
    } else {
      idCtrl.clear();
      showToast(context, 'Загружено героев: ${s.played.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final pool = s.pool.map((id) => s.data!.byId[id]).whereType<DHero>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final top = s.playedSorted.take(15).toList();
    final drafts = s.history;
    final rated = drafts.where((d) => d.win != null).toList();

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Мои герои', style: T.h2),
        actions: [
          IconButton(
            tooltip: 'О данных',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          const Text(
            'Отметь героев, на которых хорошо играешь. В режиме «приоритет» они поднимаются в рекомендациях, '
            'в режиме «только мои» — советуются только они.',
            style: T.small,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in const [0, 1, 2])
              Pill(const ['Не учитывать', 'Приоритет', 'Только мои'][m],
                  color: C.gold, filled: s.comfortMode == m, onTap: () => s.setComfortMode(m)),
          ]),
          SectionLabel(
            'Приоритетные герои · ${pool.length}',
            trailing: GestureDetector(
              onTap: () async {
                final id = await pickHero(context, title: 'Добавить в мои герои', disabled: s.pool);
                if (id != null) s.togglePool(id);
              },
              child: const Text('+ Добавить', style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          if (pool.isEmpty)
            const AppCard(
              child: Text('Пока пусто. Нажми «+ Добавить» или звёздочку на странице героя. '
                  'Можно и без Steam — просто выбери своих героев.', style: T.small),
            )
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final h in pool)
                GestureDetector(
                  onTap: () => openHero(context, h),
                  onLongPress: () => s.togglePool(h.id),
                  child: SizedBox(
                    width: 76,
                    child: Column(children: [
                      Stack(children: [
                        HeroImg(h, width: 76),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: GestureDetector(
                            onTap: () => s.togglePool(h.id),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                ),
            ]),
          const SectionLabel('Профиль Steam (необязательно)'),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.accountId != null) ...[
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: s.playerAvatar.isEmpty
                        ? Container(width: 44, height: 44, color: C.surface2)
                        : CachedNetworkImage(imageUrl: s.playerAvatar, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.playerName, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                      Text('${rankName(s.rankTier)} · ID ${s.accountId} · героев ${s.played.length}', style: T.small),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Обновить',
                    icon: s.playerLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    onPressed: s.playerLoading ? null : () => _load(s),
                  ),
                ]),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: idCtrl,
                style: T.body,
                decoration: fieldDeco(s.accountId == null ? 'Friend ID или ссылка на профиль Steam' : 'Другой профиль',
                    icon: Icons.person_search),
                onSubmitted: (_) => _load(s),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: s.playerLoading ? null : () => _load(s),
                    child: Text(s.playerLoading ? 'Загрузка…' : 'Загрузить'),
                  ),
                ),
                if (s.accountId != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: s.forgetPlayer, child: const Text('Отвязать', style: TextStyle(color: C.muted))),
                ],
              ]),
              const SizedBox(height: 8),
              const Text(
                'Friend ID — число в Dota 2 у тебя в профиле (или ссылка steamcommunity.com/profiles/7656…). '
                'В игре должно быть включено: Настройки → Общение → «Открыть общий доступ к данным матчей».',
                style: T.small,
              ),
              if (s.playerError != null) ...[
                const SizedBox(height: 6),
                Text(s.playerError!, style: T.small.copyWith(color: C.enemy)),
              ],
            ]),
          ),
          if (top.isNotEmpty) ...[
            SectionLabel(
              'Твои самые игранные',
              trailing: GestureDetector(
                onTap: () {
                  s.addTopToPool(10);
                  showToast(context, 'Топ-10 добавлены в мои герои');
                },
                child: const Text('Топ-10 в мои', style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final e in top)
                  if (s.data!.byId[e.key] != null)
                    InkWell(
                      onTap: () => openHero(context, s.data!.byId[e.key]!),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(children: [
                          HeroImg(s.data!.byId[e.key]!, width: 54),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.data!.byId[e.key]!.name, style: T.body.copyWith(fontSize: 13.5))),
                          Text('${e.value[0]} игр  ', style: T.small),
                          Text(pct(e.value[1] / e.value[0], digits: 0),
                              style: T.num(13.5, color: e.value[1] * 2 >= e.value[0] ? C.ally : C.enemy)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(s.inPool(e.key) ? Icons.star : Icons.star_border, color: C.gold, size: 20),
                            onPressed: () => s.togglePool(e.key),
                          ),
                        ]),
                      ),
                    ),
              ]),
            ),
          ],
          const SectionLabel('Ещё'),
          AppCard(
            onTap: s.accountId == null
                ? () => showToast(context, 'Сначала загрузи профиль Steam')
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MatchesScreen())),
            child: const Row(children: [
              Icon(Icons.history_edu, color: C.accent),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Разбор последних матчей', style: T.body),
                  Text('Шанс победы на драфте и кого лучше было взять', style: T.small),
                ]),
              ),
              Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
          const SizedBox(height: 8),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
            child: Row(children: [
              const Icon(Icons.bookmarks_outlined, color: C.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('История драфтов', style: T.body),
                  Text(
                    drafts.isEmpty
                        ? 'Сохраняй драфты кнопкой 🔖 на вкладке «Драфт»'
                        : 'Сохранено ${drafts.length}, с результатом ${rated.length}',
                    style: T.small,
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
        ],
      ),
    );
  }
}
