import 'dart:io';

import 'opendota.dart';

/// Игрок в лобби: слот 0–4 — Свет, 5–9 — Тьма.
class LobbySlot {
  final int slot;
  final int accountId;
  final int party; // 0 — играет один
  const LobbySlot(this.slot, this.accountId, this.party);
  bool get radiant => slot < 5;
}

class Lobby {
  final String id;
  final String mode;
  final List<LobbySlot> slots;
  const Lobby(this.id, this.mode, this.slots);

  List<LobbySlot> side(bool radiant) => slots.where((s) => s.radiant == radiant).toList();
}

/// Чтение лобби из server_log.txt: Dota пишет туда ID всех 10 игроков, как только матч загрузится
/// (ещё до выбора героев).
class LobbyReader {
  static String? _dotaDir;

  /// Папка …\steamapps\common\dota 2 beta\game\dota или null.
  static Future<String?> dotaDir() async {
    if (_dotaDir != null) return _dotaDir;
    if (!Platform.isWindows) return null;
    final libs = <String>[];
    try {
      final r = await Process.run('reg', ['query', r'HKCU\Software\Valve\Steam', '/v', 'SteamPath']);
      final m = RegExp(r'SteamPath\s+REG_SZ\s+(.+)').firstMatch('${r.stdout}');
      if (m != null) libs.add(m.group(1)!.trim().replaceAll('/', r'\'));
    } catch (_) {}
    libs.addAll([r'C:\Program Files (x86)\Steam', r'C:\Program Files\Steam', r'D:\Steam', r'D:\SteamLibrary', r'E:\SteamLibrary']);
    for (final base in [...libs]) {
      try {
        final vdf = File('$base\\steamapps\\libraryfolders.vdf');
        if (await vdf.exists()) {
          for (final mm in RegExp(r'"path"\s+"([^"]+)"').allMatches(await vdf.readAsString())) {
            libs.add(mm.group(1)!.replaceAll(r'\\', r'\'));
          }
        }
      } catch (_) {}
    }
    for (final lib in libs.toSet()) {
      final d = Directory('$lib\\steamapps\\common\\dota 2 beta\\game\\dota');
      if (await d.exists()) return _dotaDir = d.path;
    }
    return null;
  }

  static Future<File?> logFile() async {
    final d = await dotaDir();
    return d == null ? null : File('$d\\server_log.txt');
  }

  /// Последнее лобби из текста лога.
  static Lobby? parse(String text) {
    final at = text.lastIndexOf('(Lobby ');
    if (at < 0) return null;
    final lineEnd = text.indexOf('\n', at);
    final line = text.substring(at, lineEnd < 0 ? text.length : lineEnd);
    final close = line.indexOf(')');
    final lobbyPart = close < 0 ? line : line.substring(0, close);
    final head = RegExp(r'\(Lobby (\d+) (\S+)').firstMatch(lobbyPart);

    // Пати: (Party 123 0:[U:1:111] 1:[U:1:222])
    final partyOf = <int, int>{};
    var pn = 0;
    for (final pm in RegExp(r'\(Party \d+ ([^)]*)\)').allMatches(line)) {
      final ids = RegExp(r'\[U:1:(\d+)\]').allMatches(pm.group(1)!).map((m) => int.parse(m.group(1)!)).toList();
      if (ids.length < 2) continue;
      pn++;
      for (final id in ids) {
        partyOf[id] = pn;
      }
    }

    final slots = <LobbySlot>[];
    for (final m in RegExp(r'(\d+):\[U:1:(\d+)\]').allMatches(lobbyPart)) {
      final slot = int.parse(m.group(1)!);
      final id = int.parse(m.group(2)!);
      if (slot > 9 || id <= 0) continue;
      slots.add(LobbySlot(slot, id, partyOf[id] ?? 0));
    }
    if (slots.isEmpty) return null;
    slots.sort((a, b) => a.slot.compareTo(b.slot));
    return Lobby(head?.group(1) ?? '', head?.group(2) ?? '', slots);
  }

  /// Прочитать конец лога (файл бывает большим).
  static Future<Lobby?> read() async {
    final f = await logFile();
    if (f == null || !await f.exists()) return null;
    final raf = await f.open();
    try {
      final len = await raf.length();
      const tail = 64 * 1024;
      await raf.setPosition(len > tail ? len - tail : 0);
      final bytes = await raf.read(tail);
      return parse(String.fromCharCodes(bytes));
    } finally {
      await raf.close();
    }
  }

  /// Ввод вручную: ID или ссылки через запятую/пробел.
  static List<int> parseIds(String text) => text
      .split(RegExp(r'[\s,;]+'))
      .map((t) => OpenDota.parseAccountId(t))
      .whereType<int>()
      .toSet()
      .toList();
}

/// Игрок лобби с данными OpenDota.
class LobbyPlayer {
  final int accountId;
  final String name;
  final int? rankTier;
  final bool hidden; // профиль закрыт
  final Map<int, List<int>> heroes; // за последние 90 дней: hero -> [игр, побед]
  const LobbyPlayer(this.accountId, this.name, this.rankTier, this.hidden, this.heroes);

  int get games => heroes.values.fold<int>(0, (s, v) => s + v[0]);
  int get wins => heroes.values.fold<int>(0, (s, v) => s + v[1]);

  /// Самые частые герои: (герой, игр, побед).
  List<(int, int, int)> top([int n = 4]) {
    final l = heroes.entries.where((e) => e.value[0] > 0).toList()..sort((a, b) => b.value[0].compareTo(a.value[0]));
    return [for (final e in l.take(n)) (e.key, e.value[0], e.value[1])];
  }

  static Future<LobbyPlayer> load(int id) async {
    String name = '';
    int? rank;
    var hidden = false;
    try {
      final p = await OpenDota.profile(id);
      name = p.name;
      rank = p.rankTier;
    } catch (_) {
      hidden = true;
    }
    final heroes = <int, List<int>>{};
    if (!hidden) {
      try {
        final h = await OpenDota.heroes(id, days: 90);
        h.forEach((k, v) {
          if (v[0] > 0) heroes[k] = [v[0], v[1]];
        });
      } catch (_) {}
    }
    return LobbyPlayer(id, name, rank, hidden, heroes);
  }
}

/// Кого банить: сигнатурные герои соперников за последние 3 месяца.
class BanIdea {
  final int heroId;
  final double score;
  final List<(String, int, int)> who; // ник, игр, побед
  const BanIdea(this.heroId, this.score, this.who);
}

List<BanIdea> banIdeas(List<LobbyPlayer> enemies, {Set<int> skip = const {}, int limit = 6}) {
  final score = <int, double>{};
  final who = <int, List<(String, int, int)>>{};
  for (final p in enemies) {
    final total = p.games;
    if (total == 0) continue;
    for (final e in p.heroes.entries) {
      final g = e.value[0], w = e.value[1];
      if (g < 3 || skip.contains(e.key)) continue;
      final wr = (w + 2) / (g + 4); // сглаживание: 3 из 3 ≠ 100%
      if (wr <= 0.5) continue;
      final share = g / total; // насколько это «его» герой
      final s = ((wr - 0.42).clamp(0.0, 1.0) * (g < 30 ? g : 30) * (0.5 + share)).toDouble();
      if (s <= 0) continue;
      score[e.key] = (score[e.key] ?? 0) + s;
      (who[e.key] ??= []).add((p.name.isEmpty ? '${p.accountId}' : p.name, g, w));
    }
  }
  final list = score.entries.map((e) => BanIdea(e.key, e.value, who[e.key]!)).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  return list.take(limit).toList();
}
