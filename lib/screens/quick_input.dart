import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../i18n.dart';
import '../knowledge.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Быстрый ввод героев с клавиатуры (Windows): Enter — нам, Shift+Enter — врагам, Ctrl+Enter — бан.
class QuickHeroInput extends StatefulWidget {
  const QuickHeroInput({super.key});

  @override
  State<QuickHeroInput> createState() => _QuickHeroInputState();
}

class _QuickHeroInputState extends State<QuickHeroInput> {
  final ctrl = TextEditingController();
  final focus = FocusNode();

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  List<DHero> _match(List<DHero> heroes, String q) {
    q = q.trim().toLowerCase().replaceAll('ё', 'е');
    if (q.isEmpty) return const [];
    final scored = <(int, DHero)>[];
    for (final h in heroes) {
      final names = [h.name.toLowerCase(), for (final r in ruNames[h.key] ?? const <String>[]) r.toLowerCase().replaceAll('ё', 'е')];
      var best = 99;
      for (final n in names) {
        if (n.startsWith(q)) {
          best = 0;
        } else if (n.split(' ').any((w) => w.startsWith(q))) {
          best = best < 1 ? best : 1;
        } else if (n.contains(q)) {
          best = best < 2 ? best : 2;
        }
      }
      if (best < 99) scored.add((best, h));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.name.compareTo(b.$2.name));
    return [for (final x in scored.take(6)) x.$2];
  }

  void _put(DHero h, int where) {
    final s = StateScope.read(context);
    if (where == 2) {
      s.toggleBan(h.id);
    } else if (!s.add(where == 0, h.id)) {
      showToast(context, L('Команда уже полная', 'The team is full'));
    }
    ctrl.clear();
    setState(() {});
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final found = _match(s.data!.heroes, ctrl.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl,
        focusNode: focus,
        style: T.body,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (found.isEmpty) {
            focus.requestFocus();
            return;
          }
          final hw = HardwareKeyboard.instance;
          _put(found.first, hw.isControlPressed ? 2 : hw.isShiftPressed ? 1 : 0);
        },
        decoration: fieldDeco(L('Герой с клавиатуры: Enter — нам, Shift+Enter — врагам, Ctrl+Enter — бан', 'Type a hero: Enter — us, Shift+Enter — enemy, Ctrl+Enter — ban'),
            icon: Icons.keyboard_outlined),
      ),
      if (found.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (i, h) in found.indexed)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: i == 0 ? C.accent : C.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                HeroImg(h, width: 40, radius: 4),
                const SizedBox(width: 6),
                Text(h.name, style: T.small.copyWith(color: C.text)),
                const SizedBox(width: 4),
                _btn(Icons.add, C.ally, L('Нам', 'Us'), () => _put(h, 0)),
                _btn(Icons.add, C.enemy, L('Врагам', 'Enemy'), () => _put(h, 1)),
                _btn(Icons.block, C.muted, L('Бан', 'Ban'), () => _put(h, 2)),
              ]),
            ),
        ]),
      ],
    ]);
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback f) => Tooltip(
        message: tip,
        child: InkWell(onTap: f, child: Padding(padding: const EdgeInsets.all(3), child: Icon(i, size: 16, color: c))),
      );
}
