import 'package:flutter/material.dart';

import '../coach.dart';
import '../export.dart';
import '../farm.dart';
import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'matches_screen.dart';

/// Итоги игровой сессии: сегодняшние игры подряд (перерыв меньше 2 часов).
List<PlayerMatch> currentSession(List<PlayerMatch> all) {
  final ms = [...all]..sort((a, b) => b.startTime.compareTo(a.startTime));
  if (ms.isEmpty) return const [];
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final out = <PlayerMatch>[];
  var edge = now;
  for (final m in ms) {
    final end = m.startTime + m.duration;
    if (edge - end > 2 * 3600) break;
    out.add(m);
    edge = m.startTime;
  }
  return out;
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => StateScope.read(context).loadMyMatches(force: true));
  }

  Future<void> _export(AppState s) async {
    final ms = s.myMatches ?? const <PlayerMatch>[];
    if (ms.isEmpty) {
      showToast(context, L('Матчей пока нет', 'No matches yet'));
      return;
    }
    final path = await saveExport('dota_matches.csv', matchesCsv(s, ms));
    if (coach.history.isNotEmpty) await saveExport('dota_routes.csv', routesCsv(coach.history));
    if (!mounted) return;
    showToast(context, path.isEmpty ? L('Не удалось сохранить файл — таблица скопирована в буфер', 'Could not save — table copied to clipboard') : L('Сохранено: $path', 'Saved: $path'));
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final all = s.myMatches ?? const <PlayerMatch>[];
    final ses = currentSession(all);
    Widget body;
    if (s.accountId == null) {
      body = _msg(L('Укажи Steam ID во вкладке «Мои герои».', 'Add your Steam ID on the My heroes tab.'));
    } else if (s.myMatchesLoading && all.isEmpty) {
      body = const Center(child: CircularProgressIndicator(color: C.accent));
    } else if (ses.isEmpty) {
      body = _msg(L('За последние 2 часа игр не было. Итоги появятся после первой игры сессии.\n\nМатч попадает в OpenDota через несколько минут после конца.',
          'No games in the last 2 hours. The summary appears after the first game of a session.\n\nA match reaches OpenDota a few minutes after it ends.'));
    } else {
      body = _summary(context, s, ses, all);
    }
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Итоги сессии', 'Session summary'), style: T.h2),
        actions: [
          IconButton(
            tooltip: L('Экспорт матчей в CSV (Excel)', 'Export matches to CSV (Excel)'),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _export(s),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _msg(String t) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t, textAlign: TextAlign.center, style: T.body)));

  Widget _summary(BuildContext context, AppState s, List<PlayerMatch> ses, List<PlayerMatch> all) {
    final d = s.data!;
    final wins = ses.where((m) => m.win).length;
    final losses = ses.length - wins;
    final ranked = ses.where((m) => m.ranked).toList();
    final mmr = ranked.fold<int>(0, (a, m) => a + (m.win ? 25 : -25));
    // Обычные показатели — по прошлым играм вне сессии.
    final before = all.where((m) => !ses.contains(m)).take(100).toList();
    double avg(Iterable<num> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    final gpmNow = avg(ses.map((m) => m.gpm)), gpmUsual = avg(before.map((m) => m.gpm));
    final deathsNow = avg(ses.map((m) => m.deaths)), deathsUsual = avg(before.map((m) => m.deaths));
    // Лучший матч сессии: победа и KDA.
    final best = [...ses]..sort((a, b) {
        double sc(PlayerMatch m) => (m.win ? 10 : 0) + (m.kills + m.assists) / (m.deaths + 1);
        return sc(b).compareTo(sc(a));
      });
    // Серия поражений в конце.
    var streak = 0;
    for (final m in ses) {
      if (m.win) break;
      streak++;
    }
    // Главная ошибка: из записей маршрута этой сессии или по статистике.
    final start = ses.last.startTime;
    final recs = coach.history.where((r) => r.started >= start - 600).toList();
    final tips = <String>[];
    for (final r in recs) {
      final t = reportFor(r).tips.first;
      if (!tips.contains(t)) tips.add(t);
    }
    if (deathsUsual > 0 && deathsNow > deathsUsual * 1.25) {
      tips.add(L('Смертей в среднем ${deathsNow.toStringAsFixed(1)} — больше обычного (${deathsUsual.toStringAsFixed(1)}). Играй осторожнее без обзора.',
          'Average deaths ${deathsNow.toStringAsFixed(1)} — more than usual (${deathsUsual.toStringAsFixed(1)}). Play safer without vision.'));
    }
    if (gpmUsual > 0 && gpmNow < gpmUsual * 0.88) {
      tips.add(L('Фарм ниже обычного: ${gpmNow.round()} GPM против ${gpmUsual.round()}.', 'Farm below usual: ${gpmNow.round()} GPM vs ${gpmUsual.round()}.'));
    }
    final hours = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) - ses.last.startTime) / 3600;

    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(children: [
            Text(value, style: T.num(20, color: color)),
            Text(label, textAlign: TextAlign.center, style: T.small.copyWith(fontSize: 11)),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        AppCard(
          child: Row(children: [
            stat(L('игр', 'games'), '${ses.length}'),
            stat(L('побед', 'wins'), '$wins', color: C.ally),
            stat(L('поражений', 'losses'), '$losses', color: C.enemy),
            stat(L('рейтинг ≈', 'MMR ≈'), ranked.isEmpty ? '—' : (mmr >= 0 ? '+$mmr' : '$mmr'), color: mmr >= 0 ? C.ally : C.enemy),
          ]),
        ),
        const SizedBox(height: 6),
        Text(L('Сессия идёт ${hours.toStringAsFixed(1)} ч.', 'Session length: ${hours.toStringAsFixed(1)} h.'), style: T.small),
        if (streak >= 3) ...[
          const SizedBox(height: 8),
          AppCard(
            color: C.enemy.withValues(alpha: 0.12),
            child: Text(L('$streak поражения подряд — сделай перерыв хотя бы 15 минут. С тильтом рейтинг чаще падает.',
                '$streak losses in a row — take at least a 15-minute break. Tilt usually costs rating.'), style: T.body),
          ),
        ],
        SectionLabel(L('Как сыграл', 'How you played')),
        AppCard(
          child: Column(children: [
            _row(L('Золото в минуту', 'Gold per minute'), gpmNow.round().toString(), gpmUsual == 0 ? null : gpmUsual.round().toString(), gpmNow >= gpmUsual),
            _row(L('Смерти за игру', 'Deaths per game'), deathsNow.toStringAsFixed(1), deathsUsual == 0 ? null : deathsUsual.toStringAsFixed(1), deathsNow <= deathsUsual),
          ]),
        ),
        SectionLabel(L('Лучший матч', 'Best match')),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(matchId: best.first.matchId, myHero: best.first.heroId))),
          child: Row(children: [
            if (d.byId[best.first.heroId] case final h?) ...[HeroImg(h, width: 60), const SizedBox(width: 10)],
            Expanded(
              child: Text(
                '${d.byId[best.first.heroId]?.name ?? ''} · ${best.first.kills}/${best.first.deaths}/${best.first.assists} · ${best.first.gpm} GPM',
                style: T.body,
              ),
            ),
            Pill(best.first.win ? L('Победа', 'Win') : L('Поражение', 'Loss'), color: best.first.win ? C.ally : C.enemy),
          ]),
        ),
        SectionLabel(L('Над чем поработать', 'What to work on')),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (tips.isEmpty)
              Text(L('Явных проблем не видно — хорошая сессия.', 'No obvious problems — a good session.'), style: T.body)
            else
              for (final t in tips.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('•  $t', style: T.body.copyWith(fontSize: 13.5)),
                ),
          ]),
        ),
        SectionLabel(L('Игры сессии', 'Session games')),
        for (final m in ses)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppCard(
              padding: const EdgeInsets.all(8),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(matchId: m.matchId, myHero: m.heroId))),
              child: Row(children: [
                if (d.byId[m.heroId] case final h?) ...[HeroImg(h, width: 46), const SizedBox(width: 8)],
                Expanded(child: Text('${m.kills}/${m.deaths}/${m.assists} · ${m.gpm} GPM · ${(m.duration / 60).round()} ${L('мин', 'min')}', style: T.body.copyWith(fontSize: 13))),
                Text(m.win ? L('В', 'W') : L('П', 'L'), style: T.num(14, color: m.win ? C.ally : C.enemy)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _row(String label, String now, String? usual, bool good) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: T.body.copyWith(fontSize: 13.5))),
          Text(now, style: T.num(14, color: usual == null ? null : good ? C.ally : C.enemy)),
          if (usual != null) Text(L('  обычно $usual', '  usually $usual'), style: T.small),
        ]),
      );
}
