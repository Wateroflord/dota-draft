import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'personal_screen.dart';
import 'timer_screen.dart' show mmss;

class _Row {
  final DHero hero;
  final DItem item;
  final List<int> mine; // секунды
  List<(int, int, int)>? all; // (время, игр, побед)
  _Row(this.hero, this.item, this.mine);
}

/// Тайминги ключевых предметов: твои против всех игроков на этом герое.
class ItemTimingsScreen extends StatefulWidget {
  const ItemTimingsScreen({super.key});

  @override
  State<ItemTimingsScreen> createState() => _ItemTimingsScreenState();
}

class _ItemTimingsScreenState extends State<ItemTimingsScreen> {
  List<_Row>? rows;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = StateScope.read(context);
    if (s.accountId == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final d = s.data!;
      final byKey = {for (final it in d.items.values) it.key: it};
      final buys = await OpenDota.purchaseTimes(s.accountId!, limit: 80);
      final map = <String, _Row>{};
      for (final b in buys) {
        final h = d.byId[b.$1];
        if (h == null) continue;
        b.$2.forEach((key, t) {
          final it = byKey[key];
          if (it == null || it.cost < 2000 || t <= 0) return;
          map.putIfAbsent('${h.id}:$key', () => _Row(h, it, [])).mine.add(t);
        });
      }
      final list = map.values.where((r) => r.mine.length >= 2).toList()..sort((a, b) => b.mine.length.compareTo(a.mine.length));
      final top = list.take(10).toList();
      setState(() => rows = top);
      for (final r in top) {
        try {
          r.all = await OpenDota.itemTimings(r.hero.id, r.item.key);
          if (mounted) setState(() {});
        } catch (_) {}
      }
      if (top.isEmpty) {
        error = L('Не нашёл подробных матчей с покупками. OpenDota разбирает не все игры — можно запросить разбор в «Разборе матча».',
            'No detailed matches with purchases found. OpenDota does not parse every game — you can request a parse in the match breakdown.');
      }
    } on OdException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
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
        title: Text(L('Тайминги предметов', 'Item timings'), style: T.h2),
      ),
      body: s.accountId == null
          ? Center(child: Text(L('Сначала укажи Steam ID во вкладке «Мои герои».', 'Add your Steam ID first.'), style: T.body))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
              children: [
                if (loading) LinearProgressIndicator(color: C.accent, backgroundColor: C.surface2),
                Text(
                  L('Когда ты собираешь ключевые предметы по сравнению со всеми игроками на этом герое, '
                      'и как время покупки влияет на победу.',
                      'When you complete key items compared with all players on the hero, '
                      'and how purchase time affects winning.'),
                  style: T.small,
                ),
                if (error != null) ...[const SizedBox(height: 10), AppCard(child: Text(error!, style: T.small))],
                for (final r in rows ?? const <_Row>[]) _card(r),
              ],
            ),
    );
  }

  Widget _card(_Row r) {
    final mine = median(r.mine.map((e) => e.toDouble()).toList()).round();
    String? typical;
    String? verdict;
    final all = r.all;
    if (all != null && all.isNotEmpty) {
      final med = weightedMedian([for (final a in all) (a.$1.toDouble(), a.$2.toDouble())]).round();
      typical = mmss(med);
      final early = all.where((a) => a.$1 <= med).fold<(int, int)>((0, 0), (s, a) => (s.$1 + a.$2, s.$2 + a.$3));
      final late = all.where((a) => a.$1 > med).fold<(int, int)>((0, 0), (s, a) => (s.$1 + a.$2, s.$2 + a.$3));
      final diff = mine - med;
      verdict = diff > 120
          ? L('Ты собираешь на ${mmss(diff)} позже обычного.', 'You finish it ${mmss(diff)} later than usual.')
          : diff < -120
              ? L('Ты собираешь на ${mmss(-diff)} раньше обычного — отлично.', 'You finish it ${mmss(-diff)} earlier than usual — great.')
              : L('Примерно как все.', 'About the same as everyone.');
      if (early.$1 >= 20 && late.$1 >= 20) {
        verdict +=
            L(' Винрейт при покупке до ${mmss(med)}: ${pct(early.$2 / early.$1, digits: 0)}, позже: ${pct(late.$2 / late.$1, digits: 0)}.',
                ' Win rate if bought by ${mmss(med)}: ${pct(early.$2 / early.$1, digits: 0)}, later: ${pct(late.$2 / late.$1, digits: 0)}.');
      }
    }
    final late = typical != null && all != null && mine > weightedMedian([for (final a in all) (a.$1.toDouble(), a.$2.toDouble())]) + 120;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            HeroImg(r.hero, width: 50),
            const SizedBox(width: 6),
            ItemImg(r.item.key, width: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.item.name, style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(L('${r.hero.name} · ${r.mine.length} игр', '${r.hero.name} · ${r.mine.length} games'), style: T.small),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(mmss(mine), style: T.num(16, color: late ? C.enemy : C.text)),
              Text(typical == null ? '…' : L('обычно $typical', 'usually $typical'), style: T.small.copyWith(fontSize: 11)),
            ]),
          ]),
          if (verdict != null) ...[const SizedBox(height: 6), Text(verdict, style: T.body.copyWith(fontSize: 12.5))],
        ]),
      ),
    );
  }
}
