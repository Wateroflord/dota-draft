import 'data.dart';
import 'knowledge.dart';

/// Разбор голосовой команды: «Пудж врагам», «добавь Инвокера нам», «бан Войд».
/// Возвращает список (герой, куда: 0 — нам, 1 — врагам, 2 — бан).
List<(DHero, int)> parseVoice(String text, List<DHero> heroes) {
  final t = ' ${text.toLowerCase().replaceAll('ё', 'е')} ';
  var side = 0;
  if (RegExp(r'враг|противник|соперник|enemy|them|opponent').hasMatch(t)) side = 1;
  if (RegExp(r'\bбан|забань|ban\b').hasMatch(t)) side = 2;
  // Имена героев: английское и русские варианты, длинные — первыми.
  final names = <(String, DHero)>[];
  for (final h in heroes) {
    names.add((h.name.toLowerCase(), h));
    for (final r in ruNames[h.key] ?? const <String>[]) {
      final n = r.toLowerCase().replaceAll('ё', 'е');
      if (n.length >= 3) names.add((n, h));
    }
  }
  names.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  final found = <(int, DHero)>[];
  var rest = t;
  for (final n in names) {
    // Учитываем окончания: «пуджа», «инвокера».
    final stem = n.$1.length > 4 ? n.$1.substring(0, n.$1.length - 1) : n.$1;
    final i = rest.indexOf(stem);
    if (i >= 0 && !found.any((f) => f.$2.id == n.$2.id)) {
      found.add((i, n.$2));
      rest = rest.replaceRange(i, i + stem.length, ' ' * stem.length);
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found) (f.$2, side)];
}
