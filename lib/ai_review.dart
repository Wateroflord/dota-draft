import 'package:flutter/material.dart';

import 'data.dart';
import 'gemini.dart';
import 'i18n.dart';
import 'info.dart';
import 'opendota.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Текст запроса к ИИ: цифры матча, драфт и выводы приложения.
String matchReviewPrompt({
  required MatchInfo m,
  required MatchPlayer me,
  required StatsData d,
  required Map<String, ItemRef> items,
  required List<String> reasons,
  required double draftChance,
  int? score,
}) {
  final itemById = {for (final i in items.values) i.id: i.en};
  String hero(int id) => d.byId[id]?.name ?? 'hero $id';
  final allies = m.players.where((p) => p.radiant == me.radiant && p != me).toList();
  final enemies = m.players.where((p) => p.radiant != me.radiant).toList();
  final won = me.radiant == m.radiantWin;
  final mins = m.duration / 60;
  String line(MatchPlayer p) => '${hero(p.heroId)}: ${p.kills}/${p.deaths}/${p.assists}, LH ${p.lastHits}, '
      'GPM ${p.gpm}, XPM ${p.xpm}, net worth ${p.netWorth}, hero dmg ${p.heroDamage}, level ${p.level}';
  final myItems = me.items.where((i) => i > 0).map((i) => itemById[i] ?? 'item $i').join(', ');
  final pct = me.pct.entries.map((e) => '${e.key} ${(e.value * 100).round()}%').join(', ');
  final teamNw = [...allies, me].fold<int>(0, (s, p) => s + p.netWorth);
  final share = teamNw > 0 ? (me.netWorth / teamNw * 100).round() : 0;

  final b = StringBuffer()
    ..writeln('You are an experienced Dota 2 coach. Review one public match of the player.')
    ..writeln('Result: ${won ? 'WIN' : 'LOSS'}, duration ${mins.toStringAsFixed(0)} min, '
        'score ${me.radiant ? m.radiantScore : m.direScore}:${me.radiant ? m.direScore : m.radiantScore}.')
    ..writeln('Player hero: ${line(me)}. Denies ${me.denies}, tower dmg ${me.towerDamage}, healing ${me.heroHealing}.')
    ..writeln('Net worth share in team: $share% (high share = core, low = support).')
    ..writeln('Final items: ${myItems.isEmpty ? 'unknown' : myItems}.')
    ..writeln('Percentiles vs all players on this hero (OpenDota benchmarks): ${pct.isEmpty ? 'unknown' : pct}.');
  if (me.rankTier > 0) b.writeln('Player rank tier (OpenDota rank_tier): ${me.rankTier}.');
  if (score != null) b.writeln('App rating of the player in this match: $score/100 (50 = average for the hero).');
  b
    ..writeln('Allies: ${allies.map(line).join('; ')}.')
    ..writeln('Enemies: ${enemies.map(line).join('; ')}.')
    ..writeln('Draft win chance by statistics: ${(draftChance * 100).round()}%.')
    ..writeln('Automatic observations: ${reasons.join(' ')}')
    ..writeln()
    ..writeln('Write the review in ${isEn ? 'English' : 'Russian'} for a regular ranked player, plain text, no markdown, '
        'no headings, no tables. Format:')
    ..writeln('1) One sentence: the main reason the game was won or lost.')
    ..writeln('2) "+" line: one or two things the player did well (with numbers).')
    ..writeln('3) Three lines starting with "→": concrete things to change next game on this hero, each with a measurable '
        'target (e.g. last hits by minute 10, timing of a key item, fewer deaths), based on the numbers above.')
    ..writeln('4) One line about items: what to buy instead or earlier against these enemies, if anything.')
    ..writeln('Keep it under 130 words. Do not invent events you cannot see in the numbers.');
  return b.toString();
}

/// Карточка «Разбор от ИИ» на экране матча.
class AiReviewCard extends StatefulWidget {
  final MatchInfo match;
  final MatchPlayer me;
  final List<String> reasons;
  final double draftChance;
  final int? score;
  const AiReviewCard({super.key, required this.match, required this.me, required this.reasons, required this.draftChance, this.score});

  @override
  State<AiReviewCard> createState() => _AiReviewCardState();
}

class _AiReviewCardState extends State<AiReviewCard> {
  bool loading = false;
  String? error;

  String get _id => '${widget.match.matchId}_${widget.me.accountId}_$lang';
  String get lang => isEn ? 'en' : 'ru';

  Future<void> _run() async {
    final s = StateScope.read(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final text = await Gemini.generate(
        s.geminiKey,
        matchReviewPrompt(
          m: widget.match,
          me: widget.me,
          d: s.data!,
          items: s.itemRef,
          reasons: widget.reasons,
          draftChance: widget.draftChance,
          score: widget.score,
        ),
      );
      s.saveReview(_id, text);
    } on GeminiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final text = s.aiReviews[_id];
    final hasKey = s.geminiKey.isNotEmpty;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (text != null) ...[
          for (final l in text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(l,
                  style: T.body.copyWith(
                    fontSize: 13.5,
                    color: l.startsWith('→') ? C.gold : (l.startsWith('+') ? C.ally : C.text),
                  )),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: loading ? null : _run,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(L('Разобрать заново', 'Review again')),
            ),
          ),
        ] else if (!hasKey)
          Text(
            L('Добавь бесплатный ключ Gemini во вкладке «Мои герои» → «ИИ-разбор матчей» — и ИИ-тренер разберёт игру: что получилось, что поменять и какие цифры держать.',
                'Add a free Gemini key in My heroes → AI match review and an AI coach will break the game down: what went well, what to change and which numbers to aim for.'),
            style: T.small,
          )
        else ...[
          Text(L('ИИ-тренер посмотрит цифры матча и скажет, что поменять в следующей игре.',
              'An AI coach looks at the match numbers and tells you what to change next game.'), style: T.small),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: loading ? null : _run,
            icon: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(loading ? L('Разбираю…', 'Reviewing…') : L('Разобрать матч с ИИ', 'Review with AI')),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error!, style: T.small.copyWith(color: C.enemy)),
        ],
      ]),
    );
  }
}

/// Настройка ключа Gemini (вкладка «Мои герои»).
class GeminiKeyCard extends StatefulWidget {
  const GeminiKeyCard({super.key});

  @override
  State<GeminiKeyCard> createState() => _GeminiKeyCardState();
}

class _GeminiKeyCardState extends State<GeminiKeyCard> {
  final ctrl = TextEditingController();
  bool hidden = true, testing = false, loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      ctrl.text = StateScope.read(context).geminiKey;
      loaded = true;
    }
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = StateScope.read(context);
    final key = ctrl.text.trim();
    if (key.isEmpty) {
      s.setGeminiKey('');
      showToast(context, L('Ключ удалён', 'Key removed'));
      return;
    }
    setState(() => testing = true);
    final err = await Gemini.testKey(key);
    if (!mounted) return;
    setState(() => testing = false);
    if (err == null) {
      s.setGeminiKey(key);
      showToast(context, L('Ключ работает и сохранён ✓', 'Key works and is saved ✓'));
    } else {
      showToast(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          L('Бесплатный ключ: aistudio.google.com/apikey → Create API key. С ним в «Разборе матчей» появится кнопка «Разобрать матч с ИИ».',
              'Free key: aistudio.google.com/apikey → Create API key. Then “Review with AI” appears in match breakdowns.'),
          style: T.small,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: hidden,
          style: T.body,
          decoration: fieldDeco(L('Ключ Gemini', 'Gemini key'), icon: Icons.key).copyWith(
            suffixIcon: IconButton(
              icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.muted),
              onPressed: () => setState(() => hidden = !hidden),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: testing ? null : _save,
          child: Text(testing ? L('Проверяю…', 'Checking…') : L('Проверить и сохранить', 'Check and save')),
        ),
      ]),
    );
  }
}
