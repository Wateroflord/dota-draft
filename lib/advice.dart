import 'analysis.dart';
import 'data.dart';
import 'i18n.dart';

/// Совет, что купить дальше.
class ItemAdvice {
  final DItem item;
  final String reason;
  final int need; // сколько золота не хватает (0 — хватает)
  const ItemAdvice(this.item, this.reason, this.need);
}

/// Предметы, которые герой обычно собирает на этой стадии, плюс предметы против вражеского состава.
List<ItemAdvice> nextItems({
  required StatsData data,
  required DHero hero,
  required List<DHero> enemies,
  required Set<String> owned,
  required int gold,
  required int clock,
  int limit = 3,
}) {
  final byKey = {for (final it in data.items.values) it.key: it};
  final phases = clock < 600
      ? ['e', 'm']
      : clock < 1500
          ? ['m', 'l']
          : ['l', 'm'];
  final out = <ItemAdvice>[];
  final seen = <String>{...owned};
  // Предметы против врагов — в приоритете, если герой их вообще покупает или они дешёвые.
  for (final tip in itemTips(enemies)) {
    for (final k in tip.items) {
      final it = byKey[k];
      if (it == null || seen.contains(k) || it.cost <= 0) continue;
      final popular = hero.items.values.any((l) => l.contains(it.id));
      if (!popular && it.cost > 3000) continue;
      seen.add(k);
      out.add(ItemAdvice(it, L('против врагов: ${tip.title.toLowerCase()}', 'vs enemies: ${tip.title.toLowerCase()}'),
          (it.cost - gold).clamp(0, 99999)));
      break;
    }
    if (out.length >= 1) break;
  }
  for (final ph in phases) {
    for (final id in hero.items[ph] ?? const <int>[]) {
      final it = data.items[id];
      if (it == null || seen.contains(it.key) || it.cost <= 0) continue;
      seen.add(it.key);
      out.add(ItemAdvice(
          it,
          ph == phases.first
              ? L('популярно у ${hero.name} сейчас', 'popular on ${hero.name} now')
              : L('следующий этап', 'next stage'),
          (it.cost - gold).clamp(0, 99999)));
      if (out.length >= limit) return out;
    }
  }
  return out;
}
