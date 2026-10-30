import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'advice.dart';
import 'gsi.dart';
import 'i18n.dart';
import 'info.dart';
import 'opendota.dart';
import 'platform.dart';
import 'state.dart';
import 'storage.dart';
import 'tools_state.dart';
import 'winutil.dart';

/// Точка записи матча: время, позиция, жив ли, золото.
class Sample {
  final int t; // игровое время, сек
  final double? x, y; // схема 0–100
  final bool alive;
  final int gold, gpm, xpm, lh, nw;
  const Sample(this.t, this.x, this.y, this.alive, this.gold, this.gpm, this.xpm, this.lh, this.nw);

  List<num?> toJson() => [t, x == null ? null : double.parse(x!.toStringAsFixed(1)), y == null ? null : double.parse(y!.toStringAsFixed(1)), alive ? 1 : 0, gold, gpm, xpm, lh, nw];
  static Sample fromJson(List j) => Sample((j[0] as num).toInt(), (j[1] as num?)?.toDouble(), (j[2] as num?)?.toDouble(), j[3] == 1,
      (j[4] as num).toInt(), (j[5] as num).toInt(), (j[6] as num).toInt(), (j[7] as num).toInt(), j.length > 8 ? (j[8] as num).toInt() : 0);
}

/// Записанный матч (из живых данных Dota).
class MatchRecord {
  final String matchId;
  int heroId;
  String team;
  final int started; // unix
  final List<Sample> samples = [];
  final List<(int, double?, double?)> deaths = []; // время, позиция
  bool? won;
  int pos; // роль: 1 керри, 2 мид, 3 хард, 4/5 саппорт, 0 — неизвестно
  MatchRecord(this.matchId, this.heroId, this.team, this.started, {this.pos = 0});

  Map<String, dynamic> toJson() => {
        'm': matchId,
        'h': heroId,
        't': team,
        's': started,
        'w': won,
        'p': pos,
        'smp': [for (final s in samples) s.toJson()],
        'd': [for (final d in deaths) [d.$1, d.$2, d.$3]],
      };

  static MatchRecord fromJson(Map j) {
    final r = MatchRecord('${j['m']}', (j['h'] as num?)?.toInt() ?? 0, '${j['t'] ?? ''}', (j['s'] as num?)?.toInt() ?? 0,
        pos: (j['p'] as num?)?.toInt() ?? 0);
    r.won = j['w'] is bool ? j['w'] as bool : null;
    for (final s in (j['smp'] as List? ?? const []).whereType<List>()) {
      r.samples.add(Sample.fromJson(s));
    }
    for (final d in (j['d'] as List? ?? const []).whereType<List>()) {
      r.deaths.add(((d[0] as num).toInt(), (d[1] as num?)?.toDouble(), (d[2] as num?)?.toDouble()));
    }
    return r;
  }
}

class CoachAlert {
  final int t;
  final String text;
  final String kind; // skill, talent, tp, buyback, item, ward, plan
  final DateTime at;
  CoachAlert(this.t, this.text, this.kind) : at = DateTime.now();
}

/// Подсказки во время игры поверх данных GSI: прокачка, таланты, предупреждения, план по минутам; запись матча.
class Coach extends ChangeNotifier {
  AppState? state;
  ToolsState? tools;
  void Function(int matchId, int heroId)? openMatch;

  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  MatchRecord? current;
  final List<MatchRecord> history = [];
  final List<CoachAlert> alerts = [];
  final Map<String, int> _lastAlert = {}; // вид -> игровое время последней подсказки
  final Set<String> _done = {};
  GsiState? _prev;
  int _lastSampleT = -9999;
  bool _loaded = false;

  void attach(AppState s, ToolsState t) {
    state = s;
    tools = t;
    gsi.addListener(_onGsi);
    _load();
  }

  Future<void> _say(String text) async {
    if (tools?.voice == false) return;
    try {
      if (!_ttsReady) {
        await _tts.setLanguage(isEn ? 'en-US' : 'ru-RU');
        await _tts.setSpeechRate(0.55);
        _ttsReady = true;
      }
      await _tts.speak(text);
    } catch (_) {}
  }

  void _alert(GsiState g, String kind, String text, {int every = 0, bool speak = true}) {
    final t = g.clock ?? 0;
    if (every > 0) {
      final last = _lastAlert[kind];
      if (last != null && t - last < every) return;
    }
    _lastAlert[kind] = t;
    alerts.insert(0, CoachAlert(t, text, kind));
    if (alerts.length > 8) alerts.removeLast();
    if (speak && (tools?.coachVoice ?? true)) _say(text);
    if (isWindows && (tools?.toasts ?? false)) showToastWin('Dota Draft', text);
    notifyListeners();
  }

  void _onGsi() {
    final g = gsi.last;
    if (g == null) return;
    final prev = _prev;
    _prev = g;
    final s = state;
    if (s == null || s.data == null) return;
    final t = g.clock ?? 0;

    // Новый матч.
    if (g.matchId.isNotEmpty && g.matchId != '0' && (current == null || current!.matchId != g.matchId)) {
      current = MatchRecord(g.matchId, g.heroId, g.team, DateTime.now().millisecondsSinceEpoch ~/ 1000, pos: s.myPos);
      alerts.clear();
      _lastAlert.clear();
      _done.clear();
      _lastSampleT = -9999;
    }
    final rec = current;
    if (rec == null) return;
    if (rec.heroId == 0 && g.heroId != 0) rec.heroId = g.heroId;
    if (rec.team.isEmpty) rec.team = g.team;

    if (g.inGame) {
      // Запись каждые ~3 секунды.
      if (t - _lastSampleT >= 3) {
        _lastSampleT = t;
        final p = g.mapPos;
        rec.samples.add(Sample(t, p?.$1, p?.$2, g.alive, g.gold, g.gpm, g.xpm, g.lastHits, g.netWorth));
      }
      if (prev != null && g.deaths > prev.deaths) {
        final p = g.mapPos;
        rec.deaths.add((t, p?.$1, p?.$2));
      }
      _hints(g, prev, s);
    }

    // Конец матча.
    if (prev != null && !prev.postGame && g.postGame) {
      if (g.winTeam.isNotEmpty) rec.won = g.winTeam == g.team;
      _finish(rec);
    }
  }

  void _hints(GsiState g, GsiState? prev, AppState s) {
    final t = g.clock ?? 0;
    final d = s.data!;
    final hero = d.byId[g.heroId];
    final info = s.info.heroes[g.heroId];

    // Прокачка на новом уровне.
    if (prev != null && g.level > prev.level && hero != null && info != null) {
      final step = g.skillPoints; // сколько уже вложено = номер следующего шага
      final seq = s.bench.skills[hero.id] ?? const [];
      final next = _nextSkill(seq, info, g, step);
      if (next != null) _alert(g, 'skill', L('Качай: ${next.name}', 'Level up: ${next.name}'));
    }
    // Таланты.
    final need = g.level >= 25 ? 4 : g.level >= 20 ? 3 : g.level >= 15 ? 2 : g.level >= 10 ? 1 : 0;
    if (need > g.talentsTaken && info != null && !_done.contains('talent$need')) {
      _done.add('talent$need');
      final tier = need - 1;
      final pair = info.talents.where((x) => x.tier == tier).toList();
      final tal = s.bench.talents[g.heroId] ?? const {};
      if (pair.length >= 2) {
        final a = pair[0], b = pair[1];
        final best = (tal[a.id]?.$1 ?? 0) >= (tal[b.id]?.$1 ?? 0) ? a : b;
        _alert(g, 'talent', L('Талант ${best.level}: ${best.name}', 'Talent ${best.level}: ${best.name}'));
      }
    }
    if (!g.alive) return;
    // Нет свитка телепорта.
    if (t > 300 && !g.hasTp) {
      _alert(g, 'tp', L('Нет свитка телепорта — купи', 'No TP scroll — buy one'), every: 180);
    }
    // Не хватает на выкуп.
    if (t > 1800 && g.buybackCd == 0 && g.buybackCost > 0 && g.gold < g.buybackCost) {
      _alert(g, 'buyback', L('Не хватает золота на выкуп', 'Not enough gold for buyback'), every: 240);
    }
    // Хватает на следующий предмет.
    if (hero != null) {
      final adv = nextItems(data: d, hero: hero, enemies: s.enemyHeroes, owned: g.items.toSet(), gold: g.gold, clock: t, limit: 1);
      if (adv.isNotEmpty && adv.first.need == 0 && adv.first.item.cost >= 1000 && !_done.contains('item_${adv.first.item.key}')) {
        _done.add('item_${adv.first.item.key}');
        _alert(g, 'item', L('Хватает на ${adv.first.item.name} — пора за предметом', 'Enough gold for ${adv.first.item.name}'));
      }
    }
    // Варды для саппорта.
    if ((s.myPos == 4 || s.myPos == 5) && t > 120 && g.wardCd == 0 && g.wardsHeld == 0) {
      _alert(g, 'ward', L('Варды в лавке есть — купи и поставь', 'Wards are in stock — buy and place them'), every: 180);
    }
    // План по минутам (чек-лист позиции).
    for (final p in planFor(s.myPos)) {
      if (t >= p.$1 - 10 && t < p.$1 && !_done.contains('plan${p.$1}')) {
        _done.add('plan${p.$1}');
        _alert(g, 'plan', p.$2);
      }
    }
  }

  Ability? _nextSkill(List<List<(int, double)>> seq, HeroInfo info, GsiState g, int step) {
    final current = {for (final a in g.abilities) a.name: a.level};
    final abil = {for (final a in info.abilities) a.id: a};
    // Начиная с текущего шага берём популярный вариант, который ещё можно качать.
    if (step < seq.length) {
      for (final o in seq[step]) {
        final a = abil[o.$1];
        if (a == null) continue;
        final max = a.maxLevel > 0 ? a.maxLevel : (a.ult ? 3 : 4);
        if ((current[a.key] ?? 0) < max) return a;
      }
    }
    return null;
  }

  Future<void> _finish(MatchRecord rec) async {
    if (rec.samples.length < 10) return;
    history.insert(0, rec);
    while (history.length > 20) {
      history.removeLast();
    }
    current = null;
    notifyListeners();
    await _save();
    // Разбор матча: просим OpenDota разобрать запись и через пару минут открываем разбор.
    final id = int.tryParse(rec.matchId);
    if (id != null && (tools?.autoBreakdown ?? true)) {
      OpenDota.requestParse(id);
      Timer(const Duration(minutes: 2), () => openMatch?.call(id, rec.heroId));
    }
  }

  Future<File?> _file() async {
    try {
      return File('${(await appDir()).path}/coach_records.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    try {
      await (await _file())?.writeAsString(jsonEncode([for (final r in history) r.toJson()]));
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      if (j is List) history.addAll(j.whereType<Map>().map(MatchRecord.fromJson));
      notifyListeners();
    } catch (_) {}
  }
}

/// План по минутам для позиции (для голосовых подсказок).
List<(int, String)> planFor(int pos) => switch (pos) {
      1 => [
          (180, L('Скоро 3 минуты — купи сапоги и Magic Stick', 'Almost 3 minutes — buy boots and Magic Stick')),
          (600, L('10 минут — проверь добивания и иди в лес между волнами', '10 minutes — check last hits, farm the jungle between waves')),
          (1200, L('20 минут — фарми там, где есть варды, готовься к Рошану', '20 minutes — farm where wards are, prepare for Roshan')),
        ],
      2 => [
          (120, L('Водная руна на миде', 'Water rune at mid')),
          (360, L('Руна силы — ганк с руной', 'Power rune — gank with it')),
          (480, L('Руна силы через 10 секунд', 'Power rune in 10 seconds')),
        ],
      3 => [
          (300, L('5 минут — не умирай, копи на инициирующий предмет', '5 minutes — stay alive, save for your initiation item')),
          (900, L('15 минут — дави вышки с командой', '15 minutes — pressure towers with your team')),
        ],
      4 => [
          (120, L('Водная руна — помоги миду', 'Water rune — help mid')),
          (360, L('Руна силы — контролируй реку', 'Power rune — control the river')),
          (420, L('Руна мудрости — забери с саппортом', 'Wisdom rune — take it with the support')),
        ],
      5 => [
          (120, L('Водная руна', 'Water rune')),
          (420, L('Руна мудрости — опыт для тебя', 'Wisdom rune — experience for you')),
          (900, L('Скоро Рошан — поставь варды', 'Roshan soon — place wards')),
        ],
      _ => const [],
    };

final coach = Coach();
