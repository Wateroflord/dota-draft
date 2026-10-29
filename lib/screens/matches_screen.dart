import 'package:flutter/material.dart';

import '../data.dart';
import '../engine.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';
import '../i18n.dart';
import '../rating.dart';

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
        title: Text(L('Последние матчи', 'Recent matches'), style: T.h2),
        actions: [
          IconButton(
            tooltip: L('Открыть матч по номеру', 'Open match by ID'),
            icon: const Icon(Icons.tag),
            onPressed: () => openMatchById(context),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: T.body, textAlign: TextAlign.center)))
          : matches == null
              ? const Center(child: CircularProgressIndicator(color: C.accent))
              : matches!.isEmpty
                  ? Center(child: Text(L('Матчей нет или они скрыты.', 'No matches or they are hidden.'), style: T.body))
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
                                  Text(h?.name ?? L('Герой ${m.heroId}', 'Hero ${m.heroId}'), style: T.body.copyWith(fontWeight: FontWeight.w700)),
                                  Text(L('${m.kills}/${m.deaths}/${m.assists} · ${m.duration ~/ 60} мин · ${_date(m.startTime)}', '${m.kills}/${m.deaths}/${m.assists} · ${m.duration ~/ 60} min · ${_date(m.startTime)}'),
                                      style: T.small),
                                ]),
                              ),
                              Text(m.win ? L('Победа', 'Win') : L('Поражение', 'Loss'),
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

/// Открыть любой матч по номеру (например, матч друга).
Future<void> openMatchById(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.surface,
      title: Text(L('Номер матча', 'Match ID'), style: T.h2),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: fieldDeco(L('Например 8012345678 или ссылка', 'e.g. 8012345678 or a link')),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Открыть', 'Open'))),
      ],
    ),
  );
  final id = int.tryParse(RegExp(r'(\d{6,})').firstMatch(c.text)?.group(1) ?? '');
  WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  if (ok == true && id != null && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchScreen(matchId: id)));
  }
}

/// Разбор матча: кто сыграл лучше всех, кто недоиграл, почему победили или проиграли, драфт.
class MatchScreen extends StatefulWidget {
  final int matchId;
  final int? myHero;
  const MatchScreen({super.key, required this.matchId, this.myHero});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  MatchInfo? info;
  String? error;
  bool parseRequested = false;
  int? open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await OpenDota.match(widget.matchId);
      if (mounted) setState(() => info = v);
    } on OdException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
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
        title: Text(L('Матч ${widget.matchId}', 'Match ${widget.matchId}'), style: T.h2),
      ),
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
    // Кто «я»: по аккаунту, иначе по переданному герою.
    final mePlayer = m.players.where((p) => s.accountId != null && p.accountId == s.accountId).firstOrNull ??
        m.players.where((p) => p.heroId == widget.myHero).firstOrNull;
    final myHero = mePlayer?.heroId ?? widget.myHero;
    final iAmRadiant = mePlayer?.radiant ?? (myHero == null ? true : m.radiant.contains(myHero));
    final allies = heroes(iAmRadiant ? m.radiant : m.dire);
    final enemies = heroes(iAmRadiant ? m.dire : m.radiant);
    final won = iAmRadiant == m.radiantWin;
    final e = Engine(d, s.group);
    final chance = e.winChance(allies, enemies);
    final radiantChance = iAmRadiant ? chance : 1 - chance;
    final verdict = rateMatch(m, d, s.bench, draftChanceRadiant: radiantChance);
    final me = myHero == null ? null : d.byId[myHero];
    final others = allies.where((h) => h.id != myHero).toList();
    final myPart = me == null ? 0.0 : chance - e.winChance(others, enemies);
    final alts = me == null
        ? <Pick>[]
        : e
            .recommend(allies: others, enemies: enemies, unavailable: {...m.radiant, ...m.dire}, stage: 3, roleFilter: true, limit: 30)
            .where((p) => p.hero.positions.any(me.positions.contains))
            .take(4)
            .toList();
    final myRating = verdict.players.where((r) => mePlayer != null && r.p == mePlayer).firstOrNull;
    final place = myRating == null
        ? null
        : ([...verdict.players]..sort((a, b) => b.score.compareTo(a.score))).indexOf(myRating) + 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
      children: [
        AppCard(
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(won ? L('ПОБЕДА', 'VICTORY') : L('ПОРАЖЕНИЕ', 'DEFEAT'),
                  style: T.label.copyWith(color: won ? C.ally : C.enemy, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${iAmRadiant ? m.radiantScore : m.direScore} : ${iAmRadiant ? m.direScore : m.radiantScore}',
                style: T.num(28),
              ),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(L('${m.duration ~/ 60} мин', '${m.duration ~/ 60} min'), style: T.small),
              const SizedBox(height: 4),
              Text(L('шанс на драфте ${pct(chance, digits: 0)}', 'draft chance ${pct(chance, digits: 0)}'),
                  style: T.num(13, color: chance >= 0.5 ? C.ally : C.enemy)),
            ]),
          ]),
        ),
        if (myRating != null) ...[
          const SizedBox(height: 8),
          AppCard(
            borderColor: _vColor(myRating.verdict).withValues(alpha: 0.6),
            child: Row(children: [
              Expanded(
                child: Text(
                  L('Твоя игра: ${verdictTitle(myRating.verdict).toLowerCase()} — $place-е место из 10 по цифрам.',
                      'Your game: ${verdictTitle(myRating.verdict).toLowerCase()} — #$place of 10 by the numbers.'),
                  style: T.body,
                ),
              ),
              Text('${myRating.score.round()}', style: T.num(24, color: _vColor(myRating.verdict))),
            ]),
          ),
        ],
        SectionLabel(won ? L('Почему победили', 'Why we won') : L('Почему проиграли', 'Why we lost')),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in verdict.reasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.circle, size: 6, color: C.accent2)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: T.body.copyWith(fontSize: 13.5))),
                ]),
              ),
            if (m.goldAdv == null) ...[
              const SizedBox(height: 6),
              Text(
                L('График золота появится, когда OpenDota разберёт запись матча.', 'The gold graph appears once OpenDota parses the replay.'),
                style: T.small,
              ),
              TextButton.icon(
                onPressed: parseRequested
                    ? null
                    : () {
                        OpenDota.requestParse(m.matchId);
                        setState(() => parseRequested = true);
                        showToast(context, L('Запрос отправлен. Открой матч снова через 5–10 минут.', 'Requested. Reopen the match in 5–10 minutes.'));
                      },
                icon: const Icon(Icons.downloading, size: 18),
                label: Text(parseRequested ? L('Запрошено', 'Requested') : L('Запросить разбор', 'Request parse')),
              ),
            ],
          ]),
        ),
        if (m.goldAdv != null && m.goldAdv!.length > 2) ...[
          SectionLabel(L('Преимущество по золоту', 'Gold advantage')),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: Column(children: [
              SizedBox(height: 140, child: CustomPaint(size: Size.infinite, painter: _AdvPainter(m.goldAdv!, iAmRadiant))),
              const SizedBox(height: 4),
              Text(L('Выше нуля — твоя команда впереди. По горизонтали — минуты.', 'Above zero — your team is ahead. Horizontal — minutes.'),
                  style: T.small),
            ]),
          ),
        ],
        SectionLabel(L('Твоя команда', 'Your team')),
        for (final r in verdict.players.where((r) => r.p.radiant == iAmRadiant)) _player(d, r, r.p == mePlayer),
        SectionLabel(L('Противники', 'Enemies')),
        for (final r in verdict.players.where((r) => r.p.radiant != iAmRadiant)) _player(d, r, false),
        const SizedBox(height: 6),
        Text(
          L('Оценка 0–100 сравнивает игрока со всеми, кто играет на этом герое (50 — средний уровень). '
              'Цифры не видят вардов, сейвов, стаков и решений: саппорт может умирать, спасая керри. '
              'Кор/саппорт определяется по богатству в команде.',
              'The 0–100 score compares a player with everyone on that hero (50 is average). '
              'Numbers miss wards, saves, stacks and decisions: a support may die saving the carry. '
              'Core/support is detected by net worth in the team.'),
          style: T.small,
        ),
        if (me != null) ...[
          SectionLabel(L('Драфт: твой пик ${me.name}', 'Draft: your pick ${me.name}')),
          AppCard(
            child: Text(
              myPart >= 0
                  ? L('${me.name} добавил команде ${signedPct(myPart)} к шансу победы против этого состава.',
                      '${me.name} added ${signedPct(myPart)} win chance against this lineup.')
                  : L('${me.name} в этом драфте отнимал ${pct(myPart.abs())} шанса — против этих врагов он слабее среднего.',
                      '${me.name} cost ${pct(myPart.abs())} win chance — weaker than average against these enemies.'),
              style: T.body,
            ),
          ),
          if (alts.isNotEmpty) SectionLabel(L('Кого можно было взять на эту позицию', 'Who could have been picked instead')),
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
                    L('шанс ${pct(e.winChance([...others, p.hero], enemies), digits: 0)}', 'chance ${pct(e.winChance([...others, p.hero], enemies), digits: 0)}'),
                    style: T.num(13.5, color: e.winChance([...others, p.hero], enemies) > chance ? C.ally : C.accent2),
                  ),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  Color _vColor(String v) => switch (v) {
        'mvp' => C.gold,
        'best' => C.gold,
        'good' => C.ally,
        'weak' => const Color(0xFFFF9F43),
        'ruiner' || 'leaver' => C.enemy,
        _ => C.accent2,
      };

  Widget _player(StatsData d, PlayerRating r, bool me) {
    final h = d.byId[r.p.heroId];
    final key = r.p.heroId;
    final isOpen = open == key;
    final color = _vColor(r.verdict);
    final name = r.p.name.isEmpty ? L('Аноним', 'Anonymous') : r.p.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        borderColor: me ? C.gold : (r.verdict == 'ok' ? null : color.withValues(alpha: 0.5)),
        onTap: () => setState(() => open = isOpen ? null : key),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (h != null) HeroImg(h, width: 58) else const SizedBox(width: 58),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${me ? L('Ты · ', 'You · ') : ''}$name',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                  '${r.p.kills}/${r.p.deaths}/${r.p.assists} · ${r.p.gpm} GPM · ${r.p.lastHits} LH · ${(r.p.netWorth / 1000).toStringAsFixed(1)}k',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.small.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  if (r.verdict != 'ok') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4)),
                      child: Text(verdictTitle(r.verdict), style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(r.core ? L('кор', 'core') : L('саппорт', 'support'), style: T.small.copyWith(fontSize: 10.5)),
                ]),
              ]),
            ),
            Column(children: [
              Text('${r.score.round()}', style: T.num(20, color: color)),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 16, color: C.muted),
            ]),
          ]),
          if (isOpen) ...[
            const SizedBox(height: 8),
            for (final g in r.good)
              Text('+ $g', style: T.body.copyWith(fontSize: 12.5, color: C.ally)),
            for (final b in r.bad)
              Text('− $b', style: T.body.copyWith(fontSize: 12.5, color: C.enemy)),
            if (r.good.isEmpty && r.bad.isEmpty)
              Text(L('Всё примерно на среднем уровне для этого героя.', 'Everything is about average for this hero.'),
                  style: T.small),
            const SizedBox(height: 4),
            Text(
              L('Урон героям ${r.p.heroDamage} · по вышкам ${r.p.towerDamage} · лечение ${r.p.heroHealing} · уровень ${r.p.level}',
                  'Hero dmg ${r.p.heroDamage} · tower ${r.p.towerDamage} · healing ${r.p.heroHealing} · level ${r.p.level}'),
              style: T.small.copyWith(fontSize: 11),
            ),
          ],
        ]),
      ),
    );
  }
}

class _AdvPainter extends CustomPainter {
  final List<int> adv;
  final bool radiant;
  _AdvPainter(this.adv, this.radiant);

  @override
  void paint(Canvas canvas, Size size) {
    final v = [for (final x in adv) radiant ? x : -x];
    final maxAbs = v.map((x) => x.abs()).fold<int>(1000, (a, b) => a > b ? a : b).toDouble();
    final mid = size.height / 2;
    final dx = size.width / (v.length - 1);
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), Paint()..color = C.border);
    for (var m = 10; m < v.length; m += 10) {
      final x = m * dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = C.border.withValues(alpha: 0.5));
      final tp = TextPainter(
        text: TextSpan(text: '$m', style: const TextStyle(color: C.muted, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 2, size.height - tp.height));
    }
    final path = Path()..moveTo(0, mid);
    for (var i = 0; i < v.length; i++) {
      path.lineTo(i * dx, mid - v[i] / maxAbs * (mid - 6));
    }
    path.lineTo((v.length - 1) * dx, mid);
    path.close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, mid));
    canvas.drawPath(path, Paint()..color = C.ally.withValues(alpha: 0.45));
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, mid, size.width, size.height));
    canvas.drawPath(path, Paint()..color = C.enemy.withValues(alpha: 0.45));
    canvas.restore();
    final line = Path()..moveTo(0, mid - v[0] / maxAbs * (mid - 6));
    for (var i = 1; i < v.length; i++) {
      line.lineTo(i * dx, mid - v[i] / maxAbs * (mid - 6));
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = C.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final tp = TextPainter(
      text: TextSpan(text: '±${(maxAbs / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: C.muted, fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(2, 0));
  }

  @override
  bool shouldRepaint(covariant _AdvPainter old) => old.adv != adv;
}
