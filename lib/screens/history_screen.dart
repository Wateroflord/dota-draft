import '../i18n.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// История сохранённых драфтов и точность предсказаний.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
