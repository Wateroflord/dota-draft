import 'dart:io';

import 'package:flutter/services.dart';

import 'coach.dart';
import 'opendota.dart';
import 'platform.dart';
import 'state.dart';
import 'storage.dart';

String _csvCell(Object? v) {
  final s = '${v ?? ''}';
  return s.contains(RegExp('[",;\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// Таблица моих матчей (CSV, открывается в Excel/Google Таблицах).
String matchesCsv(AppState s, List<PlayerMatch> ms) {
  final names = {for (final h in s.data?.heroes ?? const []) h.id: h.name};
  final b = StringBuffer('﻿'); // чтобы Excel понял UTF-8
  b.writeln(['match_id', 'date', 'hero', 'win', 'duration_min', 'kills', 'deaths', 'assists', 'gpm', 'xpm', 'last_hits', 'hero_damage',
    'tower_damage', 'lane_role', 'party_size', 'ranked', 'note'].join(';'));
  for (final m in ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(m.startTime * 1000);
    b.writeln([
      m.matchId,
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
      names[m.heroId] ?? m.heroId,
      m.win ? 1 : 0,
      (m.duration / 60).toStringAsFixed(1),
      m.kills,
      m.deaths,
      m.assists,
      m.gpm,
      m.xpm,
      m.lastHits,
      m.heroDamage,
      m.towerDamage,
      m.laneRole,
      m.partySize,
      m.ranked ? 1 : 0,
      s.notes['${m.matchId}'] ?? '',
    ].map(_csvCell).join(';'));
  }
  return b.toString();
}

/// Записи маршрутов (из живого режима): по строке на каждые 3 секунды.
String routesCsv(List<MatchRecord> recs) {
  final b = StringBuffer('﻿');
  b.writeln('match_id;hero_id;t;x;y;alive;gold;gpm;xpm;last_hits;net_worth');
  for (final r in recs) {
    for (final e in r.samples) {
      b.writeln([r.matchId, r.heroId, e.t, e.x?.toStringAsFixed(1), e.y?.toStringAsFixed(1), e.alive ? 1 : 0, e.gold, e.gpm, e.xpm, e.lh, e.nw]
          .map(_csvCell)
          .join(';'));
    }
  }
  return b.toString();
}

/// Сохранить файл в «Загрузки» (если можно) и вернуть путь. На Windows — сразу показать в проводнике.
Future<String> saveExport(String name, String content) async {
  final candidates = <Directory>[];
  if (isWindows) {
    final home = Platform.environment['USERPROFILE'];
    if (home != null) candidates.add(Directory('$home\\Downloads'));
  } else if (isAndroid) {
    candidates.add(Directory('/storage/emulated/0/Download'));
  }
  candidates.add(await appDir());
  for (final d in candidates) {
    try {
      if (!await d.exists()) continue;
      final f = File('${d.path}${Platform.pathSeparator}$name');
      await f.writeAsString(content);
      if (isWindows) {
        Process.run('explorer', ['/select,', f.path]);
      }
      return f.path;
    } catch (_) {}
  }
  await Clipboard.setData(ClipboardData(text: content));
  return '';
}
