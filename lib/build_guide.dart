import 'dart:io';

import 'analysis.dart';
import 'data.dart';
import 'gsi.dart';
import 'i18n.dart';
import 'platform.dart';
import 'state.dart';

/// Один раздел билда (как в магазине Dota).
class BuildSection {
  final String token; // заголовок для файла Dota (#DOTA_… или свой текст)
  final String title; // заголовок в приложении
  final List<DItem> items;
  const BuildSection(this.token, this.title, this.items);
}

/// Билд героя: популярные предметы по стадиям + предметы против вражеского состава.
class HeroBuild {
  final DHero hero;
  final List<DHero> enemies;
  final List<BuildSection> sections;
  const HeroBuild(this.hero, this.enemies, this.sections);

  bool get isEmpty => sections.every((s) => s.items.isEmpty);

  /// Текст файла в формате Dota (KeyValues), как `itembuilds/default_<герой>.txt`.
  String toKeyValues() {
    final b = StringBuffer()
      ..writeln('"itembuilds"')
      ..writeln('{')
      ..writeln('\t"author"\t\t"Dota Draft"')
      ..writeln('\t"hero"\t\t\t"npc_dota_hero_${hero.key}"')
      ..writeln('\t"Title"\t\t\t"Dota Draft: ${hero.name}${enemies.isEmpty ? '' : ' vs ${enemies.map((e) => e.name).join(', ')}'}"')
      ..writeln()
      ..writeln('\t"Items"')
      ..writeln('\t{');
    for (final s in sections) {
      if (s.items.isEmpty) continue;
      b
        ..writeln('\t\t"${s.token}"')
        ..writeln('\t\t{');
      for (final it in s.items) {
        b.writeln('\t\t\t"item"\t\t"item_${it.key}"');
      }
      b.writeln('\t\t}');
    }
    b
      ..writeln('\t}')
      ..writeln('}');
    return b.toString();
  }
}

/// Собрать билд: стартовые/ранние/средние/поздние предметы героя из статистики и отдельный раздел против врагов.
HeroBuild makeBuild(StatsData data, DHero hero, List<DHero> enemies) {
  final byKey = {for (final it in data.items.values) it.key: it};
  final used = <String>{};

  List<DItem> stage(String code, int limit) {
    final out = <DItem>[];
    for (final id in hero.items[code] ?? const <int>[]) {
      final it = data.items[id];
      if (it == null || (it.cost <= 0 && code != 's')) continue;
      if (code != 's' && used.contains(it.key)) continue;
      used.add(it.key);
      out.add(it);
      if (out.length >= limit) break;
    }
    return out;
  }

  // Против врагов: по одному предмету на каждую угрозу, предпочитая те, что герой и так покупает.
  final counters = <DItem>[];
  for (final tip in itemTips(enemies)) {
    DItem? pick;
    for (final k in tip.items) {
      final it = byKey[k];
      if (it == null || used.contains(k)) continue;
      final popular = hero.items.values.any((l) => l.contains(it.id));
      if (popular) {
        pick = it;
        break;
      }
      pick ??= it.cost <= 3000 ? it : null;
    }
    if (pick != null) {
      used.add(pick.key);
      counters.add(pick);
    }
    if (counters.length >= 4) break;
  }

  final start = stage('s', 8);
  final early = stage('e', 5);
  // Предметы против врагов ставим сразу после ранней игры, чтобы их было видно.
  final mid = stage('m', 5);
  final late = stage('l', 5);
  return HeroBuild(hero, enemies, [
    BuildSection('#DOTA_Item_Build_Starting_Items', L('Старт', 'Starting'), start),
    BuildSection('#DOTA_Item_Build_Early_Game', L('Ранняя игра', 'Early game'), early),
    BuildSection(L('Против этих врагов', 'Against these enemies'), L('Против этих врагов', 'Against these enemies'), counters),
    BuildSection('#DOTA_Item_Build_Core_Items', L('Основные', 'Core'), mid),
    BuildSection('#DOTA_Item_Build_Luxury', L('Поздняя игра', 'Late game'), late),
  ]);
}

/// Запись билда в папку Dota 2 (только Windows).
class BuildWriter {
  /// Ключ последнего записанного билда (герой + враги), чтобы не перезаписывать одно и то же.
  static String? lastKey;
  static String? lastPath;
  static String? lastError;

  static Future<Directory> _dir() async => Directory('${(await GsiService.dotaGameDir()).path}\\itembuilds');

  /// Записать билд как дефолтный для героя. Оригинал Valve сохраняется рядом (.dotadraft_backup) один раз.
  static Future<String> write(HeroBuild b) async {
    if (!isWindows) throw Exception(L('Только для Windows', 'Windows only'));
    final dir = await _dir();
    await dir.create(recursive: true);
    final f = File('${dir.path}\\default_${b.hero.key}.txt');
    final backup = File('${f.path}.dotadraft_backup');
    if (await f.exists() && !await backup.exists()) {
      final old = await f.readAsString();
      if (!old.contains('"Dota Draft"')) await f.copy(backup.path);
    }
    await f.writeAsString(b.toKeyValues());
    lastPath = f.path;
    return f.path;
  }

  /// Вернуть все оригинальные билды Valve. Возвращает, сколько файлов восстановлено.
  static Future<int> restoreAll() async {
    final dir = await _dir();
    if (!await dir.exists()) return 0;
    var n = 0;
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.dotadraft_backup')) {
        final orig = e.path.substring(0, e.path.length - '.dotadraft_backup'.length);
        await e.copy(orig);
        await e.delete();
        n++;
      }
    }
    // Файлы, которых у Valve не было (созданы приложением), просто удаляем.
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.txt')) {
        try {
          if ((await e.readAsString()).contains('"author"\t\t"Dota Draft"')) {
            await e.delete();
            n++;
          }
        } catch (_) {}
      }
    }
    lastKey = null;
    return n;
  }

  /// Вызывается на каждое сообщение GSI: как только известен мой герой (и до начала игры), пишет билд против текущих врагов.
  static Future<String?> autoWrite(AppState s, GsiState g) async {
    if (!isWindows || s.data == null || g.spectating || g.heroId <= 0) return null;
    // После 0:00 магазин уже открыт — не трогаем, чтобы билд не менялся посреди игры.
    if ((g.clock ?? -1) > 0) return null;
    final hero = s.data!.byId[g.heroId];
    if (hero == null) return null;
    final enemies = s.enemyHeroes;
    final key = '${hero.id}:${enemies.map((e) => e.id).join(',')}';
    if (key == lastKey) return null;
    lastKey = key;
    try {
      await write(makeBuild(s.data!, hero, enemies));
      lastError = null;
      return enemies.isEmpty
          ? L('Билд для ${hero.name} записан в Dota', 'Build for ${hero.name} written to Dota')
          : L('Билд для ${hero.name} против ${enemies.length} врагов записан в Dota',
              'Build for ${hero.name} vs ${enemies.length} enemies written to Dota');
    } catch (e) {
      lastError = '$e';
      return null;
    }
  }
}

/// Перенести пики/баны из GSI в драфт приложения (только для своего матча, не для зрителя).
void applyGsiDraft(AppState s, GsiState g) {
  final d = g.draft;
  if (d == null || g.spectating || s.data == null) return;
  // Только во время драфта и до 0:00 — потом пользователь может сам править драфт.
  if (!g.inDraft && (g.clock ?? -1) >= 0) return;
  final team = g.team.toLowerCase();
  if (team != 'radiant' && team != 'dire') return;
  final radiant = team == 'radiant';
  final mine = radiant ? d.radiantPicks : d.direPicks;
  final theirs = radiant ? d.direPicks : d.radiantPicks;
  for (final id in mine) {
    if (!s.allies.contains(id) && s.data!.byId[id] != null) s.add(true, id);
  }
  for (final id in theirs) {
    if (!s.enemies.contains(id) && s.data!.byId[id] != null) s.add(false, id);
  }
  for (final id in d.bans) {
    if (!s.bans.contains(id) && s.data!.byId[id] != null) s.toggleBan(id);
  }
  // Мой герой выбран — ставим его в союзники.
  if (g.heroId > 0 && !s.allies.contains(g.heroId) && s.data!.byId[g.heroId] != null) s.add(true, g.heroId);
}
