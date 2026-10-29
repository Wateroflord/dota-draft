import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';
import 'hero_screen.dart';
import 'history_screen.dart';
import 'info_screen.dart';
import 'matches_screen.dart';
import 'stats_screen.dart';

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
      showToast(context, L('Загружено героев: ${s.played.length}', 'Heroes loaded: ${s.played.length}'));
    }
  }

  Future<void> _addFriend(AppState s) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(L('Добавить друга', 'Add a friend'), style: T.h2),
        content: TextField(controller: c, decoration: fieldDeco(L('Friend ID или ссылка Steam', 'Friend ID or Steam link'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Добавить', 'Add'))),
        ],
      ),
    );
    final text = c.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
    if (ok != true) return;
    if (mounted) showToast(context, L('Загружаю профиль друга…', 'Loading friend profile…'));
    final err = await s.addFriend(text);
    if (!mounted) return;
    showToast(context, err ?? L('Друг добавлен', 'Friend added'));
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
        title: Text(L('Мои герои', 'My heroes'), style: T.h2),
        actions: [
          IconButton(
            tooltip: L('О данных', 'About the data'),
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          Text(
            L('Отметь героев, на которых хорошо играешь. В режиме «приоритет» они поднимаются в рекомендациях, '
            'в режиме «только мои» — советуются только они.', 'Mark heroes you play well. In priority mode they rise in recommendations, '
            'in only-mine mode only they are suggested.'),
            style: T.small,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in const [0, 1, 2])
              Pill([L('Не учитывать', 'Ignore'), L('Приоритет', 'Priority'), L('Только мои', 'Only mine')][m],
                  color: C.gold, filled: s.comfortMode == m, onTap: () => s.setComfortMode(m)),
          ]),
          SectionLabel(
            L('Приоритетные герои · ${pool.length}', 'Priority heroes · ${pool.length}'),
            trailing: GestureDetector(
              onTap: () async {
                final id = await pickHero(context, title: L('Добавить в мои герои', 'Add to my heroes'), disabled: s.pool);
                if (id != null) s.togglePool(id);
              },
              child: Text(L('+ Добавить', '+ Add'), style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          if (pool.isEmpty)
            AppCard(
              child: Text(L('Пока пусто. Нажми «+ Добавить» или звёздочку на странице героя. '
                  'Можно и без Steam — просто выбери своих героев.', 'Empty for now. Tap + Add or the star on a hero page. '
                  'Works without Steam too — just choose your heroes.'), style: T.small),
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
          SectionLabel(L('Профиль Steam (необязательно)', 'Steam profile (optional)')),
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
                      Text(L('${rankName(s.rankTier)} · ID ${s.accountId} · героев ${s.played.length}', '${rankName(s.rankTier)} · ID ${s.accountId} · ${s.played.length} heroes'), style: T.small),
                    ]),
                  ),
                  IconButton(
                    tooltip: L('Обновить', 'Refresh'),
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
                decoration: fieldDeco(s.accountId == null ? L('Friend ID или ссылка на профиль Steam', 'Friend ID or Steam profile link') : L('Другой профиль', 'Another profile'),
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
                    child: Text(s.playerLoading ? L('Загрузка…', 'Loading…') : L('Загрузить', 'Load')),
                  ),
                ),
                if (s.accountId != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: s.forgetPlayer, child: Text(L('Отвязать', 'Unlink'), style: TextStyle(color: C.muted))),
                ],
              ]),
              const SizedBox(height: 8),
              Text(
                L('Friend ID — число в Dota 2 у тебя в профиле (или ссылка steamcommunity.com/profiles/7656…). '
                'В игре должно быть включено: Настройки → Общение → «Открыть общий доступ к данным матчей».', 'Friend ID is the number on your Dota 2 profile (or a steamcommunity.com/profiles/7656… link). '
                'In the game enable: Settings → Social → "Expose Public Match Data".'),
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
              L('Твои самые игранные', 'Your most played'),
              trailing: GestureDetector(
                onTap: () {
                  s.addTopToPool(10);
                  showToast(context, L('Топ-10 добавлены в мои герои', 'Top 10 added to my heroes'));
                },
                child: Text(L('Топ-10 в мои', 'Top 10 to mine'), style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 13)),
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
                          Text(L('${e.value[0]} игр  ', '${e.value[0]} games  '), style: T.small),
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
          SectionLabel(L('Друзья для пати · ${s.friends.length}', 'Party friends · ${s.friends.length}'),
              trailing: GestureDetector(
                onTap: () => _addFriend(s),
                child: Text(L('+ Добавить', '+ Add'),
                    style: const TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 13)),
              )),
          if (s.friends.isEmpty)
            AppCard(
              child: Text(
                L('Добавь друзей, с которыми играешь в пати. На вкладке «Драфт» включи «Пати» — советы учтут и их героев.',
                    'Add friends you party with. Turn on "Party" on the Draft tab — advice will include their heroes too.'),
                style: T.small,
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final f in s.friends)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: f.avatar.isEmpty
                            ? Container(width: 32, height: 32, color: C.surface2)
                            : CachedNetworkImage(
                                imageUrl: f.avatar,
                                width: 32,
                                height: 32,
                                errorWidget: (_, __, ___) => Container(width: 32, height: 32, color: C.surface2)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5)),
                          Text(
                            '${rankName(f.rankTier)} · ${f.comfort.map((id) => s.data!.byId[id]?.name).whereType<String>().take(3).join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.small.copyWith(fontSize: 11),
                          ),
                        ]),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18, color: C.muted),
                        onPressed: () => s.removeFriend(f.id),
                      ),
                    ]),
                  ),
              ]),
            ),
          SectionLabel(L('Настройки', 'Settings')),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(L('Язык', 'Language'), style: T.body)),
                Pill('Русский', color: C.accent, filled: s.lang == 'ru', onTap: () => s.setLang('ru')),
                const SizedBox(width: 6),
                Pill('English', color: C.accent, filled: s.lang == 'en', onTap: () => s.setLang('en')),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L('Уведомления', 'Notifications'), style: T.body),
                    Text(L('Новый патч и изменения твоих героев в мете', 'New patch and changes of your heroes in the meta'),
                        style: T.small),
                  ]),
                ),
                Switch(
                  value: s.notify,
                  activeTrackColor: C.accent,
                  onChanged: (v) async {
                    final ok = await s.setNotify(v);
                    if (!ok && context.mounted) {
                      showToast(context, L('Разреши уведомления для Dota Draft в настройках телефона', 'Allow notifications for Dota Draft in phone settings'));
                    }
                  },
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                L('Виджет: зажми пустое место на главном экране → «Виджеты» → Dota Draft.',
                    'Widget: long-press the home screen → Widgets → Dota Draft.'),
                style: T.small,
              ),
            ]),
          ),
          SectionLabel(L('Ещё', 'More')),
          AppCard(
            onTap: s.accountId == null
                ? () => showToast(context, L('Сначала загрузи профиль Steam', 'Load your Steam profile first'))
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen())),
            child: Row(children: [
              Icon(Icons.query_stats, color: C.accent),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(L('Моя статистика', 'My stats'), style: T.body),
                  Text(L('Ты против игроков своего, выше и ниже ранга; позиции, время, тильт, друзья', 'You vs players of your, higher and lower rank; positions, time, tilt, friends'), style: T.small),
                ]),
              ),
              Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
          const SizedBox(height: 8),
          AppCard(
            onTap: s.accountId == null
                ? () => showToast(context, L('Сначала загрузи профиль Steam', 'Load your Steam profile first'))
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MatchesScreen())),
            child: Row(children: [
              Icon(Icons.history_edu, color: C.accent),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(L('Разбор последних матчей', 'Recent match breakdowns'), style: T.body),
                  Text(L('Шанс победы на драфте и кого лучше было взять', 'Draft win chance and better picks'), style: T.small),
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
                  Text(L('История драфтов', 'Draft history'), style: T.body),
                  Text(
                    drafts.isEmpty
                        ? L('Сохраняй драфты кнопкой 🔖 на вкладке «Драфт»', 'Save drafts with the 🔖 button on the Draft tab')
                        : L('Сохранено ${drafts.length}, с результатом ${rated.length}', 'Saved ${drafts.length}, with result ${rated.length}'),
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
