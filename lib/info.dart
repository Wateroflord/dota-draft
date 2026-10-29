import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'i18n.dart';

/// Справочные файлы из data/: встроены в приложение и обновляются из GitHub.
class JsonRepo {
  static const base = 'https://raw.githubusercontent.com/Wateroflord/dota-draft/main/data/';

  static Future<File?> _file(String name) async {
    try {
      final d = await getApplicationDocumentsDirectory();
      return File('${d.path}/$name');
    } catch (_) {
      return null;
    }
  }

  static Future<dynamic> load(String name) async {
    try {
      final f = await _file(name);
      if (f != null && await f.exists()) return jsonDecode(await f.readAsString());
    } catch (_) {}
    try {
      return jsonDecode(await rootBundle.loadString('assets/$name'));
    } catch (_) {
      return null;
    }
  }

  /// Скачать свежую версию (не чаще раза в 6 часов). null — не изменилось или ошибка.
  static Future<dynamic> fetch(String name, {bool force = false}) async {
    try {
      final f = await _file(name);
      if (!force && f != null && await f.exists()) {
        final age = DateTime.now().difference(await f.lastModified());
        if (age.inHours < 6) return null;
      }
      final res = await http
          .get(Uri.parse('$base$name?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final txt = utf8.decode(res.bodyBytes);
      final j = jsonDecode(txt);
      await f?.writeAsString(txt, flush: true);
      return j;
    } catch (_) {
      return null;
    }
  }
}

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

class Ability {
  final int id;
  final String key, ru, en, descRu, descEn;
  final List<num> cd, mana;
  final bool ult;
  final int maxLevel;
  final String granted; // '', 'scepter', 'shard'
  const Ability(this.id, this.key, this.ru, this.en, this.descRu, this.descEn, this.cd, this.mana, this.ult, this.maxLevel,
      this.granted);

  String get name => L(ru, en);
  String get desc => L(descRu, descEn);
  String get image => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/abilities/$key.png';

  /// Перезарядка на уровне (1..n); 0 — нет.
  num cdAt(int level) {
    if (cd.isEmpty) return 0;
    return cd[(level - 1).clamp(0, cd.length - 1)];
  }

  static Ability fromJson(Map j) {
    List<num> nl(dynamic v) => ((v as List?) ?? const []).whereType<num>().toList();
    return Ability(_i(j['id']), _s(j['key']), _s(j['ru']), _s(j['en']), _s(j['dru']), _s(j['den']), nl(j['cd']),
        nl(j['mana']), j['ult'] == true, _i(j['lvl']), _s(j['g']));
  }
}

class Talent {
  final int id, tier; // tier 0 — 10 ур., 1 — 15, 2 — 20, 3 — 25
  final String ru, en;
  const Talent(this.id, this.tier, this.ru, this.en);
  String get name => L(ru, en);
  int get level => 10 + tier * 5;
}

class HeroInfo {
  final String hypeRu, hypeEn, npeRu, npeEn;
  final int range, moveSpeed;
  final double armor;
  final List<Ability> abilities;
  final List<Talent> talents;
  const HeroInfo(this.hypeRu, this.hypeEn, this.npeRu, this.npeEn, this.range, this.moveSpeed, this.armor, this.abilities,
      this.talents);

  String get hype => L(hypeRu, hypeEn);
  String get npe => L(npeRu, npeEn);

  /// Основные умения (без выданных Аганимом/Шардом).
  List<Ability> get basic => abilities.where((a) => a.granted.isEmpty).toList();

  Ability? get ultimate {
    final u = abilities.where((a) => a.ult && a.granted.isEmpty && a.cd.isNotEmpty).toList();
    if (u.isNotEmpty) return u.last;
    // Запасной вариант: умение с самой большой перезарядкой.
    final withCd = abilities.where((a) => a.cd.isNotEmpty && a.granted.isEmpty).toList()
      ..sort((a, b) => b.cd.first.compareTo(a.cd.first));
    return withCd.isEmpty ? null : withCd.first;
  }

  bool get melee => range <= 200;
}

class HeroInfoData {
  final String patch;
  final Map<int, HeroInfo> heroes;
  final Map<int, Ability> abilityById;
  final Map<int, Talent> talentById;
  HeroInfoData(this.patch, this.heroes)
      : abilityById = {for (final h in heroes.values) for (final a in h.abilities) a.id: a},
        talentById = {for (final h in heroes.values) for (final t in h.talents) t.id: t};

  static final empty = HeroInfoData('', {});

  static HeroInfoData parse(dynamic j) {
    if (j is! Map || j['heroes'] is! Map) return empty;
    final out = <int, HeroInfo>{};
    (j['heroes'] as Map).forEach((k, v) {
      final id = int.tryParse('$k');
      if (id == null || v is! Map) return;
      out[id] = HeroInfo(
        _s(v['hype_ru']),
        _s(v['hype_en']),
        _s(v['npe_ru']),
        _s(v['npe_en']),
        _i(v['range']),
        _i(v['ms']),
        (v['armor'] as num?)?.toDouble() ?? 0,
        [for (final a in ((v['abilities'] as List?) ?? const []).whereType<Map>()) Ability.fromJson(a)],
        [
          for (final t in ((v['talents'] as List?) ?? const []).whereType<Map>())
            Talent(_i(t['id']), _i(t['tier']), _s(t['ru']), _s(t['en'])),
        ],
      );
    });
    return HeroInfoData(_s(j['patch']), out);
  }
}

class PatchNotes {
  final String version;
  final int ts;
  final Map<int, (List<String>, List<String>)> heroes;
  const PatchNotes(this.version, this.ts, this.heroes);

  List<String> forHero(int id) {
    final h = heroes[id];
    if (h == null) return const [];
    final l = isEn ? h.$2 : h.$1;
    return l.isEmpty ? (isEn ? h.$1 : h.$2) : l;
  }

  static List<PatchNotes> parse(dynamic j) {
    if (j is! Map || j['patches'] is! List) return const [];
    return [
      for (final p in (j['patches'] as List).whereType<Map>())
        PatchNotes(_s(p['version']), _i(p['ts']), {
          for (final e in ((p['heroes'] as Map?) ?? const {}).entries)
            if (int.tryParse('${e.key}') != null && e.value is Map)
              int.parse('${e.key}'): (
                ((e.value['ru'] as List?) ?? const []).map((x) => '$x').toList(),
                ((e.value['en'] as List?) ?? const []).map((x) => '$x').toList(),
              ),
        }),
    ];
  }
}

class ProDraft {
  final int id, time, duration;
  final String league, radiantName, direName;
  final List<int> radiant, dire;
  final bool radiantWin;
  const ProDraft(this.id, this.time, this.duration, this.league, this.radiantName, this.direName, this.radiant, this.dire,
      this.radiantWin);

  static List<ProDraft> parse(dynamic j) {
    if (j is! Map || j['matches'] is! List) return const [];
    List<int> ids(dynamic v) => ((v as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toList();
    return [
      for (final m in (j['matches'] as List).whereType<Map>())
        if (ids(m['r']).length == 5 && ids(m['d']).length == 5)
          ProDraft(_i(m['id']), _i(m['t']), _i(m['dur']), _s(m['league']), _s(m['rn']), _s(m['dn']), ids(m['r']),
              ids(m['d']), m['w'] == true),
    ];
  }
}

/// Уменьшенные картинки героев (RGB) для распознавания по скриншоту.
class Portraits {
  final int w, h;
  final Map<int, List<Uint8List>> heroes;
  const Portraits(this.w, this.h, this.heroes);

  static const empty = Portraits(16, 9, {});

  static Portraits parse(dynamic j) {
    if (j is! Map || j['heroes'] is! Map) return empty;
    final out = <int, List<Uint8List>>{};
    (j['heroes'] as Map).forEach((k, v) {
      final id = int.tryParse('$k');
      if (id == null || v is! List) return;
      out[id] = [for (final s in v) base64Decode('$s')];
    });
    return Portraits(_i(j['w']) == 0 ? 16 : _i(j['w']), _i(j['h']) == 0 ? 9 : _i(j['h']), out);
  }
}

/// Предмет в справочнике.
class ItemRef {
  final String key;
  final int id;
  final String ru, en, descRu, descEn;
  final int cost, tier, cd, mana;
  final List<String> comps, attrs;
  final String qual;
  const ItemRef(this.key, this.id, this.ru, this.en, this.descRu, this.descEn, this.cost, this.tier, this.cd, this.mana, this.comps,
      this.attrs, this.qual);

  String get name => L(ru, en);
  String get desc => L(descRu.isEmpty ? descEn : descRu, descEn.isEmpty ? descRu : descEn);
  bool get neutral => tier >= 0;
  String get image => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/$key.png';

  static Map<String, ItemRef> parse(dynamic j) {
    if (j is! Map || j['items'] is! Map) return const {};
    final out = <String, ItemRef>{};
    (j['items'] as Map).forEach((k, v) {
      if (v is! Map) return;
      List<String> sl(dynamic x) => ((x as List?) ?? const []).map((e) => '$e').toList();
      out['$k'] = ItemRef('$k', _i(v['id']), _s(v['ru']), _s(v['en']), _s(v['dru']), _s(v['den']), _i(v['cost']),
          v['tier'] is num ? (v['tier'] as num).toInt() : -1, _i(v['cd']), _i(v['mc']), sl(v['comps']), sl(v['attrs']), _s(v['qual']));
    });
    return out;
  }
}
