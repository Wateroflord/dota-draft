import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';

String _date(int unix) {
  final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Последние матчи игрока.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<RecentMatch>? matches;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = StateScope.read(context).accountId;
    if (id == null) return;
    setState(() {
      error = null;
      matches = null;
    });
    try {
      final m = await OpenDota.recent(id);
      if (mounted) setState(() => matches = m);
    } on OdException catch (e) {
      if (mounted) setState(() => error = e.message);
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
        title: const Text('Последние матчи', style: T.h2),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: T.body, textAlign: TextAlign.center)))
          : matches == null
              ? const Center(child: CircularProgressIndicator(color: C.accent))
              : matches!.isEmpty
                  ? const Center(child: Text('Матчей нет или они скрыты.', style: T.body))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
                      itemCount: matches!.length,
                      itemBuilder: (_, i) {
                        final m = matches![i];
                        final h = s.data!.byId[m.heroId];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: AppCard(
                            padding: const EdgeInsets.all(8),
                            borderColor: (m.win ? C.ally : C.enemy).withValues(alpha: 0.35),
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => MatchScreen(matchId: m.matchId, myHero: m.heroId))),
                            child: Row(children: [
                              if (h != null) HeroImg(h, width: 64) else const SizedBox(width: 64),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(h?.name ?? 'Герой ${m.heroId}', style: T.body.copyWith(fontWeight: FontWeight.w700)),
                                  Text('${m.kills}/${m.deaths}/${m.assists} · ${m.duration ~/ 60} мин · ${_date(m.startTime)}',
                                      style: T.small),
                                ]),
                              ),
                              Text(m.win ? 'Победа' : 'Поражение',
                                  style: TextStyle(color: m.win ? C.ally : C.enemy, fontWeight: FontWeight.w700, fontSize: 12.5)),
                              const Icon(Icons.chevron_right, color: C.muted, size: 18),
                            ]),
                          ),
                        );
                      },
                    ),
    );
  }
}

/// Разбор драфта одного матча.
class MatchScreen extends StatefulWidget {
  final int matchId;
  final int myHero;
  const MatchScreen({super.key, required this.matchId, required this.myHero});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  MatchInfo? info;
  String? error;

  @override
  void initState() {
    super.initState();
    OpenDota.match(widget.matchId).then((v) {
      if (mounted) setState(() => info = v);
    }).catchError((Object e) {
      if (mounted) setState(() => error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
          backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: Text('Матч ${widget.matchId}', style: T.h2)),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: T.body)))
          : info == null
              ? const Center(child: CircularProgressIndicator(color: C.accent))
              : _body(context, s, info!),
    );
  }

  Widget _body(BuildContext context, AppState s, MatchInfo m) {
    final d = s.data!;
    List<DHero> heroes(List<int> ids) => ids.map((id) => d.byId[id]).whereType<DHero>().toList();
    final iAmRadiant = m.radiant.contains(widget.myHero);
    final allies = heroes(iAmRadiant ? m.radiant : m.dire);
    final enemies = heroes(iAmRadiant ? m.dire : m.radiant);
    final won = iAmRadiant == m.radiantWin;
    final e = Engine(d, s.group);
    final chance = e.winChance(allies, enemies);
    final me = d.byId[widget.myHero];
    final others = allies.where((h) => h.id != widget.myHero).toList();

    final myPart = me == null ? 0.0 : chance - e.winChance(others, enemies);
    final alts = me == null
        ? <Pick>[]
        : e
            .recommend(
              allies: others,
              enemies: enemies,
              unavailable: {...m.radiant, ...m.dire},
              stage: 3,
              roleFilter: true,
              limit: 30,
            )
            .where((p) => p.hero.positions.any(me.positions.contains))
            .take(4)
            .toList();

    Widget team(String title, List<DHero> t, Color c) => AppCard(
          borderColor: c.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.label.copyWith(color: c)),
            const SizedBox(height: 6),
            Row(children: [
              for (final h in t) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => openHero(context, h),
                    child: Container(
                      decoration: BoxDecoration(
                        border: h.id == widget.myHero ? Border.all(color: C.gold, width: 2) : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: LayoutBuilder(builder: (_, cs) => HeroImg(h, width: cs.maxWidth)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ]),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      children: [
        AppCard(
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ШАНС НА ДРАФТЕ', style: T.label),
              const SizedBox(height: 4),
              Text(pct(chance, digits: 0), style: T.num(30, color: chance >= 0.5 ? C.ally : C.enemy)),
            ]),
            const Spacer(),
            Text(won ? 'Победа' : 'Поражение',
                style: TextStyle(color: won ? C.ally : C.enemy, fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
        ),
        const SizedBox(height: 8),
        team('ТВОЯ КОМАНДА', allies, C.ally),
        const SizedBox(height: 8),
        team('ПРОТИВНИКИ', enemies, C.enemy),
        if (me != null) ...[
          SectionLabel('Твой пик: ${me.name}'),
          AppCard(
            child: Text(
              myPart >= 0
                  ? '${me.name} добавил команде ${signedPct(myPart)} к шансу победы против этого состава.'
                  : '${me.name} в этом драфте отнимал ${pct(myPart.abs())} шанса — против этих врагов он слабее среднего.',
              style: T.body,
            ),
          ),
          const SectionLabel('Кого можно было взять на эту позицию'),
          for (final p in alts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.all(8),
                onTap: () => openHero(context, p.hero),
                child: Row(children: [
                  HeroImg(p.hero, width: 64),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.hero.name, style: T.body.copyWith(fontWeight: FontWeight.w700))),
                  Text(
                    'шанс ${pct(e.winChance([...others, p.hero], enemies), digits: 0)}',
                    style: T.num(13.5, color: e.winChance([...others, p.hero], enemies) > chance ? C.ally : C.accent2),
                  ),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 8),
        const Text('Шанс считается по статистике героев, контрпиков и синергии без учёта игроков.', style: T.small),
      ],
    );
  }
}
