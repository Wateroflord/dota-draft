import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
import 'hero_screen.dart';

/// Сравнение с другом: два профиля бок о бок.
class FriendCompareScreen extends StatefulWidget {
  const FriendCompareScreen({super.key});

  @override
  State<FriendCompareScreen> createState() => _FriendCompareScreenState();
}

class _FriendCompareScreenState extends State<FriendCompareScreen> {
  Friend? friend;
  List<PlayerMatch>? theirs;
  Peer? together;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = StateScope.read(context);
      s.loadMyMatches();
      if (s.friends.isNotEmpty) _select(s.friends.first);
    });
  }

  Future<void> _select(Friend f) async {
    final s = StateScope.read(context);
    setState(() {
      friend = f;
      theirs = null;
      together = null;
      loading = true;
      error = null;
    });
    try {
      final ms = await OpenDota.matches(f.id, limit: 300);
      Peer? t;
      if (s.accountId != null) {
        try {
          final peers = await OpenDota.peers(s.accountId!);
          t = peers.where((p) => p.accountId == f.id).firstOrNull;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          theirs = ms;
          together = t;
        });
      }
    } on OdException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addFriend() async {
    final s = StateScope.read(context);
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
    final err = await s.addFriend(text);
    if (!mounted) return;
    if (err != null) {
      showToast(context, err);
    } else {
      _select(s.friends.last);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Сравнение с другом', 'Compare with a friend'), style: T.h2),
        actions: [IconButton(onPressed: _addFriend, icon: const Icon(Icons.person_add_alt))],
      ),
      body: s.accountId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L('Сначала укажи свой Steam ID во вкладке «Мои герои».', 'Add your own Steam ID on the My heroes tab first.'),
                    textAlign: TextAlign.center, style: T.body),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
              children: [
                if (s.friends.isEmpty)
                  AppCard(
                    onTap: _addFriend,
                    child: Text(L('Добавь друга по Friend ID или ссылке на профиль Steam.', 'Add a friend by Friend ID or Steam profile link.'),
                        style: T.body),
                  )
                else
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final f in s.friends)
                      Pill(f.name, color: C.intel, filled: friend?.id == f.id, onTap: () => _select(f)),
                  ]),
                if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: C.accent))),
                if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: T.body.copyWith(color: C.enemy))),
                if (friend != null && theirs != null && s.myMatches != null) ..._compare(s, friend!, s.myMatches!, theirs!),
              ],
            ),
    );
  }

  List<Widget> _compare(AppState s, Friend f, List<PlayerMatch> mine, List<PlayerMatch> other) {
    double avg(List<PlayerMatch> ms, double Function(PlayerMatch) g) => ms.isEmpty ? 0 : ms.map(g).reduce((a, b) => a + b) / ms.length;
    final a = mine.take(100).toList(), b = other.take(100).toList();
    final rows = <(String, double, double, int, bool)>[
      (L('Винрейт, %', 'Win rate, %'), avg(a, (m) => m.win ? 100 : 0), avg(b, (m) => m.win ? 100 : 0), 1, true),
      ('KDA', avg(a, (m) => (m.kills + m.assists) / math.max(1, m.deaths)), avg(b, (m) => (m.kills + m.assists) / math.max(1, m.deaths)), 2, true),
      (L('Золото/мин', 'GPM'), avg(a, (m) => m.gpm.toDouble()), avg(b, (m) => m.gpm.toDouble()), 0, true),
      (L('Опыт/мин', 'XPM'), avg(a, (m) => m.xpm.toDouble()), avg(b, (m) => m.xpm.toDouble()), 0, true),
      (L('Добивания за 10 мин', 'LH per 10 min'), avg(a, (m) => m.lh10), avg(b, (m) => m.lh10), 1, true),
      (L('Смерти', 'Deaths'), avg(a, (m) => m.deaths.toDouble()), avg(b, (m) => m.deaths.toDouble()), 1, false),
      (L('Урон героям/мин', 'Hero dmg/min'), avg(a, (m) => m.hdm), avg(b, (m) => m.hdm), 0, true),
      (L('Урон по вышкам', 'Tower damage'), avg(a, (m) => m.towerDamage.toDouble()), avg(b, (m) => m.towerDamage.toDouble()), 0, true),
    ];
    var meWins = 0, themWins = 0;
    for (final r in rows) {
      final better = r.$5 ? r.$2 > r.$3 : r.$2 < r.$3;
      if (r.$2 == r.$3) continue;
      better ? meWins++ : themWins++;
    }
    Map<int, List<int>> heroStats(List<PlayerMatch> ms) {
      final out = <int, List<int>>{};
      for (final m in ms) {
        final v = out.putIfAbsent(m.heroId, () => [0, 0]);
        v[0]++;
        if (m.win) v[1]++;
      }
      return out;
    }

    final ha = heroStats(mine), hb = heroStats(other);
    final common = ha.keys.where((k) => (ha[k]![0] >= 3) && (hb[k]?[0] ?? 0) >= 3).toList()
      ..sort((x, y) => (ha[y]![0] + hb[y]![0]).compareTo(ha[x]![0] + hb[x]![0]));
    List<int> top(Map<int, List<int>> h) => (h.keys.toList()..sort((x, y) => h[y]![0].compareTo(h[x]![0]))).take(5).toList();

    Widget heroCol(List<int> ids, Map<int, List<int>> h) => Column(children: [
          for (final id in ids)
            if (s.data!.byId[id] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => openHero(context, s.data!.byId[id]!),
                  child: Row(children: [
                    HeroImg(s.data!.byId[id]!, width: 40),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${h[id]![0]} · ${pct(h[id]![1] / h[id]![0], digits: 0)}', style: T.small)),
                  ]),
                ),
              ),
        ]);

    return [
      const SizedBox(height: 12),
      AppCard(
        child: Row(children: [
          Expanded(
            child: Column(children: [
              _avatar(s.playerAvatar),
              const SizedBox(height: 4),
              Text(s.playerName.isEmpty ? L('Ты', 'You') : s.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body),
              Text(rankName(s.rankTier), style: T.small),
            ]),
          ),
          Text('$meWins : $themWins', style: T.num(26, color: meWins >= themWins ? C.ally : C.enemy)),
          Expanded(
            child: Column(children: [
              _avatar(f.avatar),
              const SizedBox(height: 4),
              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body),
              Text(rankName(f.rankTier), style: T.small),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      Text(L('Счёт — у кого лучше больше показателей (последние 100 матчей).', 'Score — who is better in more stats (last 100 matches).'),
          style: T.small),
      SectionLabel(L('Показатели', 'Stats')),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 60, child: Text(fmtNum(r.$2, r.$4), style: T.num(13.5, color: _c(r.$2, r.$3, r.$5)))),
                Expanded(child: Text(r.$1, textAlign: TextAlign.center, style: T.small)),
                SizedBox(
                    width: 60,
                    child: Text(fmtNum(r.$3, r.$4), textAlign: TextAlign.right, style: T.num(13.5, color: _c(r.$3, r.$2, r.$5)))),
              ]),
            ),
        ]),
      ),
      if (together != null && together!.withGames > 0) ...[
        SectionLabel(L('Вместе', 'Together')),
        AppCard(
          child: Text(
            L('В одной команде: ${together!.withGames} игр, винрейт ${pct(together!.withWins / together!.withGames, digits: 0)}.'
                '${together!.againstGames > 0 ? ' Друг против друга: ${together!.againstGames} игр, ты выиграл ${together!.againstWins}.' : ''}',
                'Same team: ${together!.withGames} games, win rate ${pct(together!.withWins / together!.withGames, digits: 0)}.'
                '${together!.againstGames > 0 ? ' Against each other: ${together!.againstGames} games, you won ${together!.againstWins}.' : ''}'),
            style: T.body,
          ),
        ),
      ],
      SectionLabel(L('Любимые герои', 'Favourite heroes')),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: heroCol(top(ha), ha)),
        const SizedBox(width: 10),
        Expanded(child: heroCol(top(hb), hb)),
      ]),
      if (common.isNotEmpty) ...[
        SectionLabel(L('Общие герои: кто играет лучше', 'Shared heroes: who plays better')),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final id in common.take(8))
              if (s.data!.byId[id] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(children: [
                    SizedBox(
                        width: 54,
                        child: Text(pct(ha[id]![1] / ha[id]![0], digits: 0),
                            style: T.num(13, color: ha[id]![1] / ha[id]![0] >= hb[id]![1] / hb[id]![0] ? C.ally : C.muted))),
                    Expanded(
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        HeroImg(s.data!.byId[id]!, width: 40),
                        const SizedBox(width: 6),
                        Flexible(child: Text(s.data!.byId[id]!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small)),
                      ]),
                    ),
                    SizedBox(
                        width: 54,
                        child: Text(pct(hb[id]![1] / hb[id]![0], digits: 0),
                            textAlign: TextAlign.right,
                            style: T.num(13, color: hb[id]![1] / hb[id]![0] > ha[id]![1] / ha[id]![0] ? C.ally : C.muted))),
                  ]),
                ),
          ]),
        ),
      ],
    ];
  }

  Color _c(double mine, double other, bool higherBetter) {
    if (mine == other) return C.text;
    final better = higherBetter ? mine > other : mine < other;
    return better ? C.ally : C.muted;
  }

  Widget _avatar(String url) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: url.isEmpty
            ? Container(width: 48, height: 48, color: C.surface2)
            : CachedNetworkImage(
                imageUrl: url, width: 48, height: 48, errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: C.surface2)),
      );
}
