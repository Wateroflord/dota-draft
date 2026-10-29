import '../i18n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../bench.dart';
import '../data.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

String fmtNum(double v, int digits) => isEn ? v.toStringAsFixed(digits) : v.toStringAsFixed(digits).replaceAll('.', ',');

/// «Как играют на этом герое»: средние по трём группам рангов и твои цифры.
class BenchSection extends StatefulWidget {
  final DHero hero;
  const BenchSection({super.key, required this.hero});

  @override
  State<BenchSection> createState() => _BenchSectionState();
}

class _BenchSectionState extends State<BenchSection> {
  List<PlayerMatch>? mine;
  bool loading = false;
  bool started = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final s = StateScope.read(context);
    if (s.accountId != null && (s.played[widget.hero.id]?[0] ?? 0) > 0) {
      final id = s.accountId!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(id);
      });
    }
  }

  Future<void> _load(int id) async {
    // Если общие матчи уже загружены — берём из них, иначе спрашиваем матчи на этом герое.
    final s = StateScope.read(context);
    final cached = s.myMatches?.where((m) => m.heroId == widget.hero.id).toList();
    if (cached != null && cached.length >= 5) {
      setState(() => mine = cached);
      return;
    }
    setState(() => loading = true);
    try {
      final ms = await OpenDota.matches(id, limit: 50, heroId: widget.hero.id);
      if (mounted) setState(() => mine = ms);
    } on OdException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final b = s.bench;
    final rows = [for (var g = 1; g <= 3; g++) b.row(widget.hero.id, g)];
    final me = mine == null ? null : BenchRow.ofMatches(mine!);
    final my = s.myRankGroup;
    if (rows.every((r) => r == null) && me == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(L('Как играют на герое', 'How players perform on this hero')),
        AppCard(
          child: Text(
            b.isEmpty
                ? L('Средние цифры игроков по рангам ещё собираются — появятся после ближайшего обновления данных.', 'Average numbers by rank are still being collected — they will appear after the next data update.')
                : L('По этому герою пока мало матчей в выборке.', 'Not enough matches for this hero yet.'),
            style: T.small,
          ),
        ),
      ]);
    }
    const colW = 58.0;
    Widget head(String t, {bool hl = false}) => SizedBox(
          width: colW,
          child: Text(t,
              textAlign: TextAlign.right,
              maxLines: 2,
              style: T.small.copyWith(fontSize: 10.5, color: hl ? C.accent : C.muted, fontWeight: hl ? FontWeight.w700 : null)),
        );
    final short = ['', L('Рекрут–\nСтраж', 'Herald–\nGuardian'), L('Рыцарь–\nЛегенда', 'Crusader–\nLegend'), L('Властелин–\nТитан', 'Ancient–\nImmortal')];

    final tips = <String>[];
    final ref = rows[my - 1];
    if (me != null && ref != null && me.n >= 3) {
      String cmp(double a, double b) {
        final d = b == 0 ? 0.0 : (a - b) / b;
        return d >= 0 ? L('на ${(d * 100).round()}% больше', '${(d * 100).round()}% more') : L('на ${(-d * 100).round()}% меньше', '${(-d * 100).round()}% less');
      }

      tips.add(L('Золота в минуту — ${cmp(me.gpm, ref.gpm)}, чем у среднего игрока твоего ранга.', 'Gold per minute — ${cmp(me.gpm, ref.gpm)} than an average player of your rank.'));
      tips.add(L('Добиваний — ${cmp(me.lh10, ref.lh10)}.', 'Last hits — ${cmp(me.lh10, ref.lh10)}.'));
      if (me.d > ref.d * 1.15) {
        tips.add(L('Умираешь чаще среднего (${fmtNum(me.d, 1)} против ${fmtNum(ref.d, 1)}) — осторожнее с позицией.', 'You die more than average (${fmtNum(me.d, 1)} vs ${fmtNum(ref.d, 1)}) — watch your positioning.'));
      } else if (me.d < ref.d * 0.85) {
        tips.add(L('Умираешь реже среднего — хорошо.', 'You die less than average — good.'));
      }
      final hi = my < 3 ? rows[my] : null;
      if (hi != null) {
        tips.add(L('Ранг выше в среднем делает ${hi.gpm.round()} золота/мин и ${fmtNum(hi.lh10, 1)} добиваний за 10 мин — это цель.', 'The rank above averages ${hi.gpm.round()} GPM and ${fmtNum(hi.lh10, 1)} last hits per 10 min — that is your target.'));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(L('Как играют на герое', 'How players perform on this hero'), trailing: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: SizedBox()),
            for (var g = 1; g <= 3; g++) head(short[g], hl: g == my),
            if (me != null) head(L('Ты\n(${me.n.round()} игр)', 'You\n(${me.n.round()} games)'), hl: true),
          ]),
          Divider(color: C.border, height: 14),
          for (final m in benchMetrics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(m.label, style: T.body.copyWith(fontSize: 12.5))),
                for (var g = 1; g <= 3; g++)
                  SizedBox(
                    width: colW,
                    child: Text(
                      rows[g - 1] == null ? '—' : fmtNum(m.get(rows[g - 1]!), m.digits),
                      textAlign: TextAlign.right,
                      style: T.num(12.5, color: g == my ? C.text : C.muted),
                    ),
                  ),
                if (me != null)
                  SizedBox(
                    width: colW,
                    child: Text(fmtNum(m.get(me), m.digits),
                        textAlign: TextAlign.right, style: T.num(12.5, color: _cmpColor(m, me, ref))),
                  ),
              ]),
            ),
          const SizedBox(height: 6),
          Text(
            L('Средние по рейтинговым матчам за последние недели'
            '${rows[my - 1] != null ? ' · в твоём ранге ${rows[my - 1]!.n.round()} игр на герое' : ''}.'
            '${s.rankTier == null ? ' Твой ранг скрыт — выделена группа, выбранная в драфте.' : ''}', 'Averages from ranked matches of recent weeks'
            '${rows[my - 1] != null ? ' · ${rows[my - 1]!.n.round()} games on this hero in your rank' : ''}.'
            '${s.rankTier == null ? ' Your rank is hidden — the group chosen in the draft is highlighted.' : ''}'),
            style: T.small,
          ),
          if (error != null) Text(error!, style: T.small.copyWith(color: C.enemy)),
        ]),
      ),
      if (tips.isNotEmpty) ...[
        const SizedBox(height: 8),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final t in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.lightbulb_outline, size: 15, color: C.gold)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: T.body.copyWith(fontSize: 13))),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }

  Color _cmpColor(BenchMetric m, BenchRow me, BenchRow? ref) {
    if (ref == null) return C.text;
    final a = m.get(me), b = m.get(ref);
    if (b == 0) return C.text;
    final d = (a - b) / b * (m.higherBetter ? 1 : -1);
    if (d > 0.07) return C.ally;
    if (d < -0.07) return C.enemy;
    return C.text;
  }
}

/// Лучшие нейтральные предметы героя.
class NeutralRow extends StatelessWidget {
  final DHero hero;
  final bool compact;
  const NeutralRow({super.key, required this.hero, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final b = StateScope.of(context).bench;
    final rows = (b.neutral[hero.id] ?? const <NeutralStat>[]).where((r) => b.items[r.itemId] != null).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = rows.fold<double>(0, (a, r) => a + r.n);
    rows.sort((a, c) => c.n.compareTo(a.n));
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final r in rows.take(compact ? 4 : 6))
        Tooltip(
          message: L('${b.items[r.itemId]!.name} · уровень ${b.items[r.itemId]!.tier}', '${b.items[r.itemId]!.name} · tier ${b.items[r.itemId]!.tier}'),
          child: SizedBox(
            width: compact ? 46 : 58,
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CachedNetworkImage(
                  imageUrl: b.items[r.itemId]!.image,
                  width: compact ? 40 : 50,
                  height: (compact ? 40 : 50) * 0.73,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: C.surface2, width: 40, height: 29),
                ),
              ),
              const SizedBox(height: 2),
              Text(compact ? L('Т${b.items[r.itemId]!.tier}', 'T${b.items[r.itemId]!.tier}') : '${(r.n / total * 100).round()}% · T${b.items[r.itemId]!.tier}',
                  style: T.small.copyWith(fontSize: 10)),
              if (!compact)
                Text(pct(r.wr, digits: 0), style: T.num(10.5, color: r.wr >= 0.5 ? C.ally : C.enemy)),
            ]),
          ),
        ),
    ]);
  }
}
