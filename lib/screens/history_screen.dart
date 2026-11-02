import '../i18n.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// История сохранённых драфтов и точность предсказаний.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(silent: true));
  }

  Future<void> _check({bool silent = false}) async {
    final s = StateScope.read(context);
    if (s.accountId == null) {
      if (!silent) showToast(context, L('Сначала загрузи профиль Steam во вкладке «Мои герои»', 'Load your Steam profile on the My heroes tab first'));
      return;
    }
    setState(() => checking = true);
    final n = await s.autoFillResults();
    if (!mounted) return;
    setState(() => checking = false);
    if (n > 0 || !silent) {
      showToast(context, n > 0 ? L('Результаты отмечены по матчам: $n', 'Results filled from matches: $n') : L('Новых совпадений с матчами нет', 'No new matches found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final d = s.data!;
    final rated = s.history.where((x) => x.win != null).toList();
    final correct = rated.where((x) => (x.chance >= 0.5) == x.win).length;
    final wins = rated.where((x) => x.win == true).length;
    final avgPred = rated.isEmpty ? 0.0 : rated.map((x) => x.chance).reduce((a, b) => a + b) / rated.length;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, surfaceTintColor: Colors.transparent, title: Text(L('История драфтов', 'Draft history'), style: T.h2)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
        children: [
          AppCard(
            child: Row(children: [
              _stat(L('Точность', 'Accuracy'), rated.isEmpty ? '—' : pct(correct / rated.length, digits: 0), C.gold),
              _stat(L('Побед', 'Wins'), rated.isEmpty ? '—' : L('$wins из ${rated.length}', '$wins of ${rated.length}'), C.ally),
              _stat(L('Ожидалось', 'Expected'), rated.isEmpty ? '—' : pct(avgPred, digits: 0), C.accent2),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            L('Точность — как часто фаворит по драфту действительно побеждал. Отмечай результат после каждой игры: '
            'через 20–30 матчей станет понятно, насколько подсказкам можно доверять.', 'Accuracy — how often the draft favourite actually won. Mark the result after each game: '
            'after 20–30 matches you will see how much the advice can be trusted.'),
            style: T.small,
          ),
          if (rated.length >= 4) ...[
            const SizedBox(height: 10),
            _calibration(rated),
          ],
          const SizedBox(height: 10),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L('Сохранять драфт сам', 'Save drafts automatically'), style: T.body),
                    Text(L('Когда выбраны все 10 героев', 'When all 10 heroes are picked'), style: T.small),
                  ]),
                ),
                Switch(value: s.autoSaveDraft, activeTrackColor: C.accent, onChanged: s.setAutoSaveDraft),
              ]),
              const SizedBox(height: 6),
              Text(
                L('Результат отмечается сам по твоим матчам из OpenDota (нужен профиль Steam). Матчи появляются там через несколько минут после игры.',
                    'Results are filled in from your OpenDota matches (needs a Steam profile). Matches appear there a few minutes after the game.'),
                style: T.small,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: checking ? null : () => _check(),
                  icon: checking
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  label: Text(L('Проверить по матчам', 'Check against matches')),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          if (s.history.isEmpty)
            AppCard(child: Text(L('Пока пусто. Сохраняй драфт кнопкой 🔖 на вкладке «Драфт».', 'Empty for now. Save drafts with the 🔖 button on the Draft tab.'), style: T.small)),
          for (final x in s.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(10),
                borderColor: x.win == null ? null : (x.win! ? C.ally : C.enemy).withValues(alpha: 0.4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(_date(x.ts), style: T.small),
                    const Spacer(),
                    Text(L('шанс ${pct(x.chance, digits: 0)}', 'chance ${pct(x.chance, digits: 0)}'), style: T.num(13.5, color: x.chance >= 0.5 ? C.ally : C.enemy)),
                  ]),
                  const SizedBox(height: 6),
                  _row(d, x.allies),
                  const SizedBox(height: 4),
                  _row(d, x.enemies),
                  const SizedBox(height: 8),
                  Row(children: [
                    Pill(L('Победа', 'Win'), color: C.ally, filled: x.win == true, onTap: () => s.setResult(x.id, x.win == true ? null : true)),
                    const SizedBox(width: 6),
                    Pill(L('Поражение', 'Loss'),
                        color: C.enemy, filled: x.win == false, onTap: () => s.setResult(x.id, x.win == false ? null : false)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: L('Открыть в драфте', 'Open in draft'),
                      icon: Icon(Icons.open_in_new, size: 18, color: C.accent2),
                      onPressed: () {
                        s.loadDraft(x);
                        Navigator.pop(context);
                        showToast(context, L('Драфт открыт на вкладке «Драфт»', 'Draft opened on the Draft tab'));
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: L('Удалить', 'Delete'),
                      icon: Icon(Icons.delete_outline, size: 18, color: C.muted),
                      onPressed: () => s.deleteDraft(x.id),
                    ),
                  ]),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  /// Насколько честен шанс: в каждой группе прогнозов — сколько побед было на самом деле.
  Widget _calibration(List<SavedDraft> rated) {
    final groups = [
      (L('Шанс до 45%', 'Chance under 45%'), rated.where((x) => x.chance < 0.45).toList()),
      (L('45–55%', '45–55%'), rated.where((x) => x.chance >= 0.45 && x.chance <= 0.55).toList()),
      (L('Шанс больше 55%', 'Chance over 55%'), rated.where((x) => x.chance > 0.55).toList()),
    ];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L('ПРОГНОЗ И РЕАЛЬНОСТЬ', 'FORECAST VS REALITY'), style: T.label),
        const SizedBox(height: 8),
        for (final g in groups)
          if (g.$2.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Builder(builder: (_) {
                final n = g.$2.length;
                final w = g.$2.where((x) => x.win == true).length;
                final exp = g.$2.map((x) => x.chance).reduce((a, b) => a + b) / n;
                final real = w / n;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(g.$1, style: T.body.copyWith(fontSize: 13))),
                    Text(L('ждали ${pct(exp, digits: 0)} · было ${pct(real, digits: 0)} ($w из $n)', 'expected ${pct(exp, digits: 0)} · got ${pct(real, digits: 0)} ($w of $n)'),
                        style: T.num(12.5, color: (real - exp).abs() <= 0.1 ? C.ally : C.gold)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: real, minHeight: 6, backgroundColor: C.surface2, color: C.accent),
                  ),
                ]);
              }),
            ),
        const SizedBox(height: 4),
        Text(
          L('Если «было» близко к «ждали» — шанс победы можно принимать всерьёз. Нужно хотя бы 10 игр в группе.',
              'If “got” is close to “expected”, the win chance can be trusted. Needs at least 10 games per group.'),
          style: T.small,
        ),
      ]),
    );
  }

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _stat(String label, String value, Color c) => Expanded(
        child: Column(children: [
          Text(label, style: T.small),
          const SizedBox(height: 4),
          Text(value, style: T.num(18, color: c)),
        ]),
      );

  Widget _row(StatsData d, List<int> ids) => Row(children: [
        for (final id in ids)
          if (d.byId[id] != null) ...[
            Expanded(child: LayoutBuilder(builder: (_, c) => HeroImg(d.byId[id]!, width: c.maxWidth))),
            const SizedBox(width: 4),
          ],
        for (var i = ids.length; i < 5; i++) ...[const Expanded(child: SizedBox()), const SizedBox(width: 4)],
      ]);
}
