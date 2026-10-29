import 'package:flutter/material.dart';

import '../data.dart';
import '../knowledge.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Выбор героя: поиск, фильтр по атрибуту, сетка картинок. Возвращает id героя.
Future<int?> pickHero(BuildContext context, {required String title, Set<int> disabled = const {}}) =>
    showSheet<int>(context, _Picker(title: title, disabled: disabled));

class _Picker extends StatefulWidget {
  final String title;
  final Set<int> disabled;
  const _Picker({required this.title, required this.disabled});

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final search = TextEditingController();
  String attr = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final q = search.text.trim().toLowerCase();
    final list = s.data!.heroes
        .where((h) => (attr.isEmpty || h.attr == attr) && (q.isEmpty || heroMatches(h, q)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(widget.title, style: T.h2),
            const SizedBox(height: 10),
            TextField(
              controller: search,
              autofocus: false,
              onChanged: (_) => setState(() {}),
              style: T.body,
              decoration: fieldDeco('Поиск: Pudge, Пудж, АМ, Войд…', icon: Icons.search),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final a in const ['', 'str', 'agi', 'int', 'all']) ...[
                  Pill(
                    a.isEmpty ? 'Все' : attrNames[a]!,
                    color: a.isEmpty ? C.accent2 : C.attr(a),
                    filled: attr == a,
                    onTap: () => setState(() => attr = a),
                  ),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final h = list[i];
                  final off = widget.disabled.contains(h.id);
                  return GestureDetector(
                    onTap: off ? null : () => Navigator.pop(context, h.id),
                    child: Column(
                      children: [
                        LayoutBuilder(builder: (_, c) => HeroImg(h, width: c.maxWidth, dim: off)),
                        const SizedBox(height: 4),
                        Text(
                          h.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, height: 1.15, color: off ? C.muted : C.text),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Поиск по английскому имени, внутреннему ключу, русскому названию и сленгу.
bool heroMatches(DHero h, String q) {
  if (h.name.toLowerCase().contains(q) || h.key.replaceAll('_', ' ').contains(q)) return true;
  for (final n in ruNames[h.key] ?? const <String>[]) {
    final l = n.toLowerCase();
    // Короткий сленг («ам», «сф») — только точное совпадение, иначе «ам» найдёт и Шамана.
    if (l.length <= 3 ? l == q : l.contains(q)) return true;
  }
  // Первые буквы слов: «pa» → Phantom Assassin.
  final initials = h.name.split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty).map((w) => w[0].toLowerCase()).join();
  return q.length >= 2 && initials == q;
}
