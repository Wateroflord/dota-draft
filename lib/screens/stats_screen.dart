import '../i18n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../bench.dart';
import '../data.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import 'bench_widgets.dart';
import 'hero_screen.dart';

/// Личная статистика по последним матчам из Steam (OpenDota).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _Agg {
  int n = 0, w = 0;
  void add(bool win) {
    n++;
    if (win) w++;
  }

  double get wr => n == 0 ? 0 : w / n;
}

class _StatsScreenState extends State<StatsScreen> {
  List<Peer>? peers;
  String? peersError;
  bool peersLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = StateScope.read(context);
      s.loadMyMatches();
      _loadPeers(s);
    });
  }

  Future<void> _loadPeers(AppState s) async {
    if (s.accountId == null) return;
    setState(() => peersLoading = true);
    try {
      final p = await OpenDota.peers(s.accountId!);
      if (mounted) setState(() => peers = p);
    } on OdException catch (e) {
      if (mounted) setState(() => peersError = e.message);
    } finally {
      if (mounted) setState(() => peersLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final ms = s.myMatches;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Моя статистика', 'My stats'), style: T.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: s.myMatchesLoading
                ? null
                : () {
                    s.loadMyMatches(force: true);
                    _loadPeers(s);
                  },
          ),
        ],
      ),
      body: s.accountId == null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(L('Сначала укажи Steam ID во вкладке «Мои герои».', 'Add your Steam ID on the My heroes tab first.'), textAlign: TextAlign.center, style: T.body),
              ),
            )
          : ms == null
              ? Center(
                  child: s.myMatchesLoading
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(L('Загружаю последние матчи…', 'Loading recent matches…'), style: T.small),
                        ])
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(s.myMatchesError ?? L('Нет данных', 'No data'), textAlign: TextAlign.center, style: T.body),
                        ),
                )
              : _content(s, ms),
    );
  }

  Widget _content(AppState s, List<PlayerMatch> ms) {
    if (ms.isEmpty) {
      return Center(child: Text(s.myMatchesError ?? L('Матчей нет', 'No matches'), style: T.body));
    }
    final d = s.data!;
    final total = _Agg();
    for (final m in ms) {
      total.add(m.win);
    }
    final me = BenchRow.ofMatches(ms)!;

    // Серия (матчи идут от новых к старым)
    var streak = 0;
    final streakWin = ms.first.win;
    for (final m in ms) {
      if (m.win != streakWin) break;
      streak++;
    }

    // Тильт: винрейт в игре сразу после двух поражений подряд в одной сессии (перерыв < 1 часа)
    final afterTwoLosses = _Agg();
    final chrono = ms.reversed.toList();
    for (var i = 2; i < chrono.length; i++) {
      final a = chrono[i - 2], b = chrono[i - 1], c = chrono[i];
      final gap1 = b.startTime - (a.startTime + a.duration), gap2 = c.startTime - (b.startTime + b.duration);
      if (!a.win && !b.win && gap1 < 3600 && gap2 < 3600) afterTwoLosses.add(c.win);
    }
    // Сегодняшняя сессия
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final today = <PlayerMatch>[];
    for (final m in ms) {
      final last = today.isEmpty ? now : today.last.startTime;
      if (last - (m.startTime + m.duration) > 3 * 3600) break;
      today.add(m);
    }
    final todayLosses = today.where((m) => !m.win).length;

    // По позиции (основная позиция героя), времени суток, дням недели, длительности, пати
    final byPos = <int, _Agg>{};
    final byTime = List.generate(4, (_) => _Agg());
    final byDay = List.generate(7, (_) => _Agg());
    final byDur = List.generate(4, (_) => _Agg());
    final solo = _Agg(), party = _Agg();
    final byHero = <int, List<PlayerMatch>>{};
    for (final m in ms) {
      final h = d.byId[m.heroId];
      if (h != null && h.positions.isNotEmpty) byPos.putIfAbsent(h.positions.first, _Agg.new).add(m.win);
      final t = DateTime.fromMillisecondsSinceEpoch(m.startTime * 1000);
      byTime[t.hour ~/ 6].add(m.win);
      byDay[t.weekday - 1].add(m.win);
      final mins = m.duration / 60;
      byDur[mins < 25 ? 0 : mins < 35 ? 1 : mins < 45 ? 2 : 3].add(m.win);
      (m.partySize > 1 ? party : solo).add(m.win);
      byHero.putIfAbsent(m.heroId, () => []).add(m);
    }

    // Сравнение со средними игроками (на тех же героях, взвешено по числу твоих игр)
    final my = s.myRankGroup;
    final groupsToShow = [if (my > 1) my - 1, my, if (my < 3) my + 1];
    final cmp = <int, Map<String, double>>{};
    for (final g in groupsToShow) {
      final sums = <String, double>{}, weights = <String, double>{};
      byHero.forEach((hid, list) {
        final ref = s.bench.row(hid, g);
        final mine = BenchRow.ofMatches(list);
        if (ref == null || mine == null || ref.n < 5) return;
        for (final m in benchMetrics) {
          final r = m.get(ref);
          if (r == 0) continue;
          sums[m.label] = (sums[m.label] ?? 0) + (m.get(mine) - r) / r * list.length;
          weights[m.label] = (weights[m.label] ?? 0) + list.length;
        }
      });
      cmp[g] = {for (final k in sums.keys) k: sums[k]! / weights[k]!};
    }

    final times = [L('Ночь 0–6', 'Night 0–6'), L('Утро 6–12', 'Morning 6–12'), L('День 12–18', 'Day 12–18'), L('Вечер 18–24', 'Evening 18–24')];
    final days = [L('Пн', 'Mon'), L('Вт', 'Tue'), L('Ср', 'Wed'), L('Чт', 'Thu'), L('Пт', 'Fri'), L('Сб', 'Sat'), L('Вс', 'Sun')];
    final heroRows = byHero.entries.where((e) => e.value.length >= 2).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        AppCard(
          child: Row(children: [
            _big('${total.n}', L('игр', 'games')),
            _big(pct(total.wr), L('винрейт', 'win rate'), color: total.wr >= 0.5 ? C.ally : C.enemy),
            _big(fmtNum(me.kda, 2), 'KDA'),
            _big('$streak${streakWin ? 'W' : 'L'}', L('серия', 'streak'), color: streakWin ? C.ally : C.enemy),
          ]),
        ),
        const SizedBox(height: 4),
        Text(L('Последние ${ms.length} рейтинговых и обычных матчей · ${rankName(s.rankTier)}', 'Last ${ms.length} ranked and normal matches · ${rankName(s.rankTier)}'), style: T.small),
        if (todayLosses >= 3 && today.length >= 3 || (!streakWin && streak >= 3)) ...[
          const SizedBox(height: 10),
          AppCard(
            borderColor: C.enemy.withValues(alpha: 0.6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.local_fire_department, color: C.enemy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L('Похоже на тильт: ${!streakWin && streak >= 3 ? '$streak поражений подряд' : '$todayLosses поражений за сессию'}. '
                  'Сделай перерыв 15–30 минут — после серии поражений винрейт обычно ниже.', 'Looks like tilt: ${!streakWin && streak >= 3 ? '$streak losses in a row' : '$todayLosses losses this session'}. '
                  'Take a 15–30 minute break — win rate is usually lower after a losing streak.'),
                  style: T.body.copyWith(fontSize: 13.5),
                ),
              ),
            ]),
          ),
        ],
        if (afterTwoLosses.n >= 5) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              L('После двух поражений подряд ты выигрываешь ${pct(afterTwoLosses.wr, digits: 0)} '
              '(${afterTwoLosses.n} игр) против ${pct(total.wr, digits: 0)} в среднем. '
              '${afterTwoLosses.wr < total.wr - 0.04 ? 'Лучше делать паузу после двух проигрышей.' : 'Ты хорошо держишь удар.'}', 'After two losses in a row you win ${pct(afterTwoLosses.wr, digits: 0)} '
              '(${afterTwoLosses.n} games) vs ${pct(total.wr, digits: 0)} on average. '
              '${afterTwoLosses.wr < total.wr - 0.04 ? 'Better take a break after two losses.' : 'You handle losses well.'}'),
              style: T.body.copyWith(fontSize: 13.5),
            ),
          ),
        ],
        SectionLabel(L('Время в игре', 'Time played')),
        _playtime(ms),
        SectionLabel(L('Ты против среднего игрока на тех же героях', 'You vs the average player on the same heroes')),
        if (cmp.values.every((m) => m.isEmpty))
          AppCard(
            child: Text(
              s.bench.isEmpty
                  ? L('Средние цифры по рангам ещё собираются — появятся после ближайшего обновления данных.', 'Average numbers by rank are still being collected — they will appear after the next data update.')
                  : L('Мало данных по твоим героям для сравнения.', 'Not enough data on your heroes to compare.'),
              style: T.small,
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(children: [
              Row(children: [
                const Expanded(child: SizedBox()),
                for (final g in groupsToShow)
                  SizedBox(
                    width: 70,
                    child: Text(
                      g < my ? L('ниже\n${rankGroupsShort[g]}', 'lower\n${rankGroupsShort[g]}') : g == my ? L('твой ранг\n${rankGroupsShort[g]}', 'your rank\n${rankGroupsShort[g]}') : L('выше\n${rankGroupsShort[g]}', 'higher\n${rankGroupsShort[g]}'),
                      textAlign: TextAlign.right,
                      style: T.small.copyWith(fontSize: 10, color: g == my ? C.accent : C.muted),
                    ),
                  ),
              ]),
              Divider(color: C.border, height: 14),
              for (final m in benchMetrics.where((m) => m.label != 'KDA'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(m.label, style: T.body.copyWith(fontSize: 12.5))),
                    for (final g in groupsToShow)
                      SizedBox(
                        width: 70,
                        child: Text(
                          cmp[g]?[m.label] == null ? '—' : signedPct(cmp[g]![m.label]!, digits: 0),
                          textAlign: TextAlign.right,
                          style: T.num(12.5, color: _good(m, cmp[g]?[m.label])),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 6),
              Text(
                L('Насколько твои цифры больше (+) или меньше (−) средних на тех же героях. '
                'Зелёный — лучше среднего, красный — хуже. Для смертей меньше — лучше.', 'How much your numbers are above (+) or below (−) the average on the same heroes. '
                'Green — better than average, red — worse. For deaths, fewer is better.'),
                style: T.small,
              ),
            ]),
          ),
        SectionLabel(L('По позиции героя', 'By hero position')),
        _aggCard([
          for (final p in [1, 2, 3, 4, 5])
            if (byPos[p] != null) (positionNames[p]!, byPos[p]!),
        ]),
        SectionLabel(L('По времени суток', 'By time of day')),
        _aggCard([for (var i = 0; i < 4; i++) (times[i], byTime[i])]),
        SectionLabel(L('По дням недели', 'By weekday')),
        _aggCard([for (var i = 0; i < 7; i++) (days[i], byDay[i])]),
        SectionLabel(L('По длине матча', 'By match length')),
        _aggCard([for (var i = 0; i < 4; i++) (durationLabels[i], byDur[i])]),
        SectionLabel(L('Соло или с друзьями', 'Solo or with friends')),
        _aggCard([(L('Соло', 'Solo'), solo), (L('В пати', 'In party'), party)]),
        SectionLabel(L('Герои в этих матчах', 'Heroes in these matches')),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final e in heroRows.take(12))
              if (d.byId[e.key] != null) _heroRow(s, d.byId[e.key]!, e.value),
          ]),
        ),
        SectionLabel(L('С кем играешь', 'Who you play with'),
            trailing: peersLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null),
        if (peersError != null) Text(peersError!, style: T.small.copyWith(color: C.enemy)),
        if (peers != null) _peers(peers!),
      ],
    );
  }

  Widget _playtime(List<PlayerMatch> ms) {
    final tools = ToolsScope.of(context);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    double hours(int days) =>
        ms.where((m) => now - m.startTime < days * 86400).fold<int>(0, (s, m) => s + m.duration) / 3600;
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch ~/ 1000;
    final todayGames = ms.where((m) => m.startTime >= midnight).length;
    // Самая длинная сессия: матчи с перерывом меньше часа.
    var longest = 0, cur = 0;
    final chrono = ms.reversed.toList();
    for (var i = 0; i < chrono.length; i++) {
      if (i > 0 && chrono[i].startTime - (chrono[i - 1].startTime + chrono[i - 1].duration) > 3600) cur = 0;
      cur++;
      if (cur > longest) longest = cur;
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _big(hours(7).toStringAsFixed(1), L('часов за неделю', 'hours this week')),
          _big((hours(30) / 30).toStringAsFixed(1), L('в день (30 дн.)', 'per day (30d)')),
          _big('$todayGames', L('игр сегодня', 'games today')),
          _big('$longest', L('макс. подряд', 'max in a row')),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(L('Напомнить о перерыве после', 'Remind me to rest after'), style: T.small),
          for (final n in const [0, 3, 5, 7])
            Pill(n == 0 ? L('нет', 'off') : L('$n игр', '$n games'),
                color: C.gold, filled: tools.breakAfter == n, onTap: () => tools.setBreakAfter(n)),
        ]),
        const SizedBox(height: 4),
        Text(L('Напоминание работает, когда включена связь с Dota (экран «Живой матч»).',
            'The reminder works when the Dota link is on (Live match page).'), style: T.small.copyWith(fontSize: 11)),
      ]),
    );
  }

  Color _good(BenchMetric m, double? v) {
    if (v == null) return C.muted;
    final x = m.higherBetter ? v : -v;
    if (x > 0.05) return C.ally;
    if (x < -0.05) return C.enemy;
    return C.text;
  }

  Widget _big(String v, String l, {Color? color}) => Expanded(
        child: Column(children: [
          Text(v, style: T.num(19, color: color)),
          const SizedBox(height: 2),
          Text(l, style: T.small),
        ]),
      );

  Widget _aggCard(List<(String, _Agg)> rows) {
    final best = rows.where((r) => r.$2.n >= 5).fold<(String, _Agg)?>(null, (a, r) => a == null || r.$2.wr > a.$2.wr ? r : a);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              SizedBox(
                width: 108,
                child: Text(r.$1,
                    style: T.body.copyWith(fontSize: 13, fontWeight: r == best ? FontWeight.w700 : FontWeight.w400)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: r.$2.n == 0 ? 0 : r.$2.wr,
                    minHeight: 6,
                    backgroundColor: C.surface2,
                    color: r.$2.n < 5 ? C.muted : (r.$2.wr >= 0.5 ? C.ally : C.enemy),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 44, child: Text(r.$2.n == 0 ? '—' : pct(r.$2.wr, digits: 0), textAlign: TextAlign.right, style: T.num(13))),
              SizedBox(width: 44, child: Text('${r.$2.n}', textAlign: TextAlign.right, style: T.small)),
            ]),
          ),
      ]),
    );
  }

  Widget _heroRow(AppState s, DHero h, List<PlayerMatch> list) {
    final mine = BenchRow.ofMatches(list)!;
    final ref = s.bench.row(h.id, s.myRankGroup);
    final gpmDiff = ref == null || ref.gpm == 0 ? null : (mine.gpm - ref.gpm) / ref.gpm;
    return InkWell(
      onTap: () => openHero(context, h),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          HeroImg(h, width: 54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name, style: T.body.copyWith(fontSize: 13.5)),
              Text(
                L('${list.length} игр · KDA ${fmtNum(mine.kda, 1)} · ${mine.gpm.round()} GPM'
                '${gpmDiff == null ? '' : ' (${signedPct(gpmDiff, digits: 0)})'}', '${list.length} games · KDA ${fmtNum(mine.kda, 1)} · ${mine.gpm.round()} GPM'
                '${gpmDiff == null ? '' : ' (${signedPct(gpmDiff, digits: 0)})'}'),
                style: T.small,
              ),
            ]),
          ),
          Text(pct(mine.wr, digits: 0), style: T.num(13.5, color: mine.wr >= 0.5 ? C.ally : C.enemy)),
        ]),
      ),
    );
  }

  Widget _peers(List<Peer> ps) {
    final list = ps.where((p) => p.withGames >= 3).toList()..sort((a, b) => b.withGames.compareTo(a.withGames));
    if (list.isEmpty) return AppCard(child: Text(L('Нет игроков, с которыми ты сыграл хотя бы 3 матча.', 'No players you played at least 3 matches with.'), style: T.small));
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        for (final p in list.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: p.avatar.isEmpty
                    ? Container(width: 32, height: 32, color: C.surface2)
                    : CachedNetworkImage(
                        imageUrl: p.avatar,
                        width: 32,
                        height: 32,
                        errorWidget: (_, __, ___) => Container(width: 32, height: 32, color: C.surface2),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5))),
              Text(L('${p.withGames} игр  ', '${p.withGames} games  '), style: T.small),
              Text(pct(p.withWins / p.withGames, digits: 0),
                  style: T.num(13.5, color: p.withWins * 2 >= p.withGames ? C.ally : C.enemy)),
            ]),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Text(L('Винрейт, когда вы в одной команде.', 'Win rate when you are on the same team.'), style: T.small),
        ),
      ]),
    );
  }
}
