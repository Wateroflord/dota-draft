import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../info.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_screen.dart';

/// Справочник предметов.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final search = TextEditingController();
  int cat = 0; // 0 все, 1 дешёвые, 2 средние, 3 дорогие, 4 нейтральные

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final q = search.text.trim().toLowerCase();
    final all = s.itemRef.values.where((it) {
      if (q.isNotEmpty && !it.ru.toLowerCase().contains(q) && !it.en.toLowerCase().contains(q)) return false;
      return switch (cat) {
        1 => !it.neutral && it.cost < 1000,
        2 => !it.neutral && it.cost >= 1000 && it.cost < 3000,
        3 => !it.neutral && it.cost >= 3000,
        4 => it.neutral,
        _ => true,
      };
    }).toList()
      ..sort((a, b) => a.neutral != b.neutral ? (a.neutral ? 1 : -1) : (a.neutral ? a.tier.compareTo(b.tier) : a.cost.compareTo(b.cost)));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Справочник предметов', 'Item reference'), style: T.h2),
      ),
      body: s.itemRef.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L('Справочник загрузится после обновления данных («О данных» → «Обновить сейчас»).',
                    'The reference loads after a data update (About the data → Update now).'), textAlign: TextAlign.center, style: T.body),
              ),
            )
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  style: T.body,
                  decoration: fieldDeco(L('Поиск предмета', 'Search items'), icon: Icons.search),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  for (final c in [
                    (0, L('Все', 'All')),
                    (1, L('До 1000', 'Under 1000')),
                    (2, '1000–3000'),
                    (3, L('3000+', '3000+')),
                    (4, L('Нейтральные', 'Neutral')),
                  ]) ...[
                    Pill(c.$2, color: C.accent, filled: cat == c.$1, onTap: () => setState(() => cat = c.$1)),
                    const SizedBox(width: 6),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 92, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.82),
                  itemCount: all.length,
                  itemBuilder: (_, i) {
                    final it = all[i];
                    return InkWell(
                      onTap: () => openItem(context, it),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: it.image,
                            width: 64,
                            height: 47,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(width: 64, height: 47, color: C.surface2),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(it.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                            style: T.small.copyWith(fontSize: 10.5, color: C.text)),
                        Text(it.neutral ? 'T${it.tier}' : '${it.cost}',
                            style: T.small.copyWith(fontSize: 10, color: it.neutral ? C.intel : C.gold)),
                      ]),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}

/// Карточка предмета.
Future<void> openItem(BuildContext context, ItemRef it) {
  final s = StateScope.read(context);
  final d = s.data!;
  final id = it.id;
  final buyers = [
    for (final h in d.heroes)
      if (h.items.values.any((l) => l.contains(id))) h,
  ]..sort((a, b) => b.prAt(s.group).compareTo(a.prAt(s.group)));
  return showSheet<void>(
    context,
    DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SheetHandle(),
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(imageUrl: it.image, width: 72, height: 53, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(width: 72, height: 53)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.name, style: T.h2),
                Text(
                  it.neutral ? L('Нейтральный предмет, уровень ${it.tier}', 'Neutral item, tier ${it.tier}') : L('Цена: ${it.cost}', 'Cost: ${it.cost}'),
                  style: T.small.copyWith(color: it.neutral ? C.intel : C.gold),
                ),
                if (it.cd > 0 || it.mana > 0)
                  Text(
                    [if (it.cd > 0) L('перезарядка ${it.cd} с', 'cooldown ${it.cd}s'), if (it.mana > 0) L('мана ${it.mana}', 'mana ${it.mana}')].join(' · '),
                    style: T.small,
                  ),
              ]),
            ),
          ]),
          if (it.attrs.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final a in it.attrs) Text(a, style: T.body.copyWith(fontSize: 13, color: C.ally)),
          ],
          if (it.desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(it.desc, style: T.body.copyWith(fontSize: 13.5)),
          ],
          if (it.comps.isNotEmpty) ...[
            SectionLabel(L('Из чего собирается', 'Recipe')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in it.comps)
                GestureDetector(
                  onTap: () {
                    final r = s.itemRef[c];
                    if (r != null) {
                      Navigator.pop(ctx);
                      openItem(context, r);
                    }
                  },
                  child: Column(children: [
                    ItemImg(c, width: 44),
                    Text(s.itemRef[c]?.cost.toString() ?? '', style: T.small.copyWith(fontSize: 10, color: C.gold)),
                  ]),
                ),
            ]),
          ],
          if (buyers.isNotEmpty) ...[
            SectionLabel(L('Кто чаще покупает', 'Who buys it most')),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in buyers.take(12))
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    openHero(context, h);
                  },
                  child: HeroImg(h, width: 56, radius: 4),
                ),
            ]),
          ],
        ],
      ),
    ),
  );
}

/// Удобный поиск DItem → ItemRef (по ключу).
ItemRef? refOf(AppState s, DItem it) => s.itemRef[it.key];
