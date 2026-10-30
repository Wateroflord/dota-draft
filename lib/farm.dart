import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'coach.dart';
import 'i18n.dart';
import 'map_data.dart';
import 'theme.dart';
import 'tools_state.dart';

/// Лагерь на схеме (с учётом правок пользователя).
class Camp {
  final String id, kind, title;
  final double x, y;
  final bool own; // в своём лесу
  final bool safeSide; // лес у лёгкой линии
  const Camp(this.id, this.kind, this.title, this.x, this.y, this.own, this.safeSide);

  double get value => switch (kind) { 'small' => 1.0, 'medium' => 1.5, 'large' => 2.2, 'ancient' => 3.0, _ => 0.0 };
}

bool _rotatedId(String id) => id.startsWith('d_') || id.startsWith('e_');
String _baseId(String id) => _rotatedId(id) ? id.substring(2) : id;

/// Лагеря для стороны [radiant] в координатах схемы (0–100).
List<Camp> campsFor(bool radiant, ToolsState tools) {
  final out = <Camp>[];
  for (final p in mapObjects(radiant)) {
    if (!campKinds.contains(p.kind)) continue;
    final b = _baseId(p.id);
    if (tools.hidden.contains(b)) continue;
    var x = p.x, y = p.y;
    final m = tools.moved[b];
    if (m != null) {
      final rot = _rotatedId(p.id);
      x = rot ? 100 - m[0] : m[0];
      y = rot ? 100 - m[1] : m[1];
    }
    final own = radiant ? !p.id.startsWith('e_') : p.id.startsWith('d_');
    out.add(Camp(p.id, p.kind, p.title, x, y, own, b.contains('safe') || b.contains('ancient')));
  }
  return out;
}

double _dist(double ax, double ay, double bx, double by) => math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));

/// Совет по маршруту фарма: куда идти дальше.
class FarmPlan {
  final List<Camp> route;
  final Set<String> farmed;
  final String tip;
  const FarmPlan(this.route, this.farmed, this.tip);
}

/// Какие лагеря уже зачищены в текущей минуте (герой постоял рядом 3+ секунды).
Set<String> farmedThisMinute(List<Sample> samples, List<Camp> camps, int now) {
  final minuteStart = now - (now % 60);
  final out = <String>{};
  for (final c in camps) {
    var close = 0;
    for (final s in samples.reversed) {
      if (s.t < minuteStart) break;
      if (s.x != null && s.alive && _dist(s.x!, s.y!, c.x, c.y) < 5) close++;
    }
    if (close >= 1) out.add(c.id);
  }
  return out;
}

/// Роль: из настроек или по тому, где герой стоял в начале игры.
int roleFor(MatchRecord? rec, int myPos, bool radiant) {
  if (myPos >= 1 && myPos <= 3) return myPos;
  if (rec == null) return 0;
  final early = rec.samples.where((s) => s.t >= 60 && s.t <= 480 && s.x != null && s.alive).toList();
  if (early.isEmpty) return 0;
  final ax = early.map((s) => s.x!).reduce((a, b) => a + b) / early.length;
  final ay = early.map((s) => s.y!).reduce((a, b) => a + b) / early.length;
  // Мид — около диагонали, лёгкая линия Света — внизу, у Тьмы — вверху.
  if ((ax + ay - 100).abs() < 18 && (ax - ay).abs() < 40) return 2;
  final bottom = ay > 60 && ax > 40;
  final top = ay < 40 && ax < 60;
  if (radiant) return bottom ? 1 : (top ? 3 : 0);
  return top ? 1 : (bottom ? 3 : 0);
}

FarmPlan planFarm({
  required double x,
  required double y,
  required int clock,
  required int role,
  required List<Camp> camps,
  required Set<String> farmed,
}) {
  // Кандидаты по роли.
  bool allowed(Camp c) {
    if (c.kind == 'ancient' && clock < 600) return false;
    return switch (role) {
      1 => c.own && (c.safeSide || clock > 1200),
      2 => c.own ? (_dist(c.x, c.y, 50, 50) < 30 || clock > 900) : clock > 1500,
      3 => c.own ? (!c.safeSide || clock > 1200) : clock > 1500,
      _ => c.own,
    };
  }

  final cand = camps.where((c) => allowed(c) && !farmed.contains(c.id)).toList();
  final route = <Camp>[];
  var cx = x, cy = y;
  for (var i = 0; i < 3 && cand.isNotEmpty; i++) {
    cand.sort((a, b) => (b.value / (_dist(cx, cy, b.x, b.y) + 8)).compareTo(a.value / (_dist(cx, cy, a.x, a.y) + 8)));
    final c = cand.removeAt(0);
    route.add(c);
    cx = c.x;
    cy = c.y;
  }
  final toSpawn = 60 - (clock % 60);
  final toWave = 30 - (clock % 30);
  String tip;
  if (role == 2 && clock > 0 && (clock % 120) > 105) {
    tip = L('Через ${120 - clock % 120} с руна силы — будь у реки', 'Power rune in ${120 - clock % 120}s — be near the river');
  } else if (route.isEmpty) {
    tip = L('Лагеря рядом зачищены — возьми волну на линии, новые появятся через $toSpawn с',
        'Nearby camps are cleared — take a lane wave, camps respawn in ${toSpawn}s');
  } else if (clock < 600 && role != 2) {
    tip = L('Не уходи далеко от линии: новая волна выходит каждые 30 с (через $toWave с)',
        'Stay close to the lane: a new wave every 30s (next in ${toWave}s)');
  } else {
    tip = L('Лагеря появляются в начале каждой минуты (через $toSpawn с). Между лагерями забирай волны.',
        'Camps respawn at the start of every minute (in ${toSpawn}s). Take waves between camps.');
  }
  return FarmPlan(route, farmed, tip);
}

/// Разбор маршрута после матча.
class FarmReport {
  final double base, lane, ownJungle, enemyJungle, dead; // доли времени
  final int idleSec;
  final List<String> tips;
  final List<(int, int)> gpm; // (минута, gpm)
  const FarmReport(this.base, this.lane, this.ownJungle, this.enemyJungle, this.dead, this.idleSec, this.tips, this.gpm);
}

bool _inBase(double x, double y, bool radiant) => radiant ? (x < 20 && y > 80) : (x > 80 && y < 20);

bool _onLane(double x, double y) {
  // Линии схемы: верх (x≈8 или y≈8), низ (y≈92 или x≈92), мид (x+y≈100).
  return x < 13 || y < 13 || x > 87 || y > 87 || (x + y - 100).abs() < 7;
}

FarmReport reportFor(MatchRecord r, {double? benchGpm}) {
  final radiant = r.team != 'dire';
  var base = 0, lane = 0, own = 0, enemy = 0, dead = 0, total = 0, idle = 0;
  final s = r.samples.where((e) => e.t >= 0).toList();
  for (var i = 0; i < s.length; i++) {
    final e = s[i];
    total++;
    if (!e.alive) {
      dead++;
      continue;
    }
    if (e.x == null) continue;
    final x = e.x!, y = e.y!;
    if (_inBase(x, y, radiant)) {
      base++;
    } else if (_onLane(x, y)) {
      lane++;
    } else {
      final ownHalf = radiant ? y > x : y < x;
      if (ownHalf) {
        own++;
      } else {
        enemy++;
      }
    }
    // Простой: за 20 секунд почти не сдвинулся и золото не выросло (не на базе и жив).
    if (i >= 7) {
      final p = s[i - 7];
      if (p.x != null && p.alive && !_inBase(x, y, radiant) && _dist(p.x!, p.y!, x, y) < 2.5 && e.gold - p.gold < 25 && e.lh == p.lh) {
        idle += e.t - s[i - 1].t;
      }
    }
  }
  double f(int v) => total == 0 ? 0 : v / total;
  final gpm = <(int, int)>[];
  for (final e in s) {
    final m = e.t ~/ 60;
    if (gpm.isEmpty || gpm.last.$1 != m) gpm.add((m, e.gpm));
  }
  final tips = <String>[];
  final role = r.pos;
  if (f(base) + f(dead) > 0.3) {
    tips.add(L('${((f(base) + f(dead)) * 100).round()}% времени ты был на базе или мёртв — это потерянный фарм.',
        '${((f(base) + f(dead)) * 100).round()}% of the time you were at base or dead — lost farm.'));
  }
  if (idle > 120) {
    tips.add(L('Около ${idle ~/ 60} мин простоя: стоял на месте без добиваний. Между волнами иди в лес.',
        'About ${idle ~/ 60} min idle: standing without last hits. Farm the jungle between waves.'));
  }
  final mid = s.where((e) => e.t >= 600 && e.t < 1200 && e.alive && e.x != null).toList();
  if (mid.isNotEmpty && (role == 1 || role == 0)) {
    final jungle = mid.where((e) => !_onLane(e.x!, e.y!) && !_inBase(e.x!, e.y!, radiant)).length / mid.length;
    if (jungle < 0.25) {
      tips.add(L('С 10 по 20 минуту ты был в лесу только ${(jungle * 100).round()}% времени — добавь лес между волнами.',
          'Between minutes 10 and 20 you spent only ${(jungle * 100).round()}% of the time in the jungle — add jungle between waves.'));
    }
  }
  if (f(enemy) > 0.25 && r.deaths.length >= 5) {
    tips.add(L('Много времени в чужом лесу и ${r.deaths.length} смертей — фарми там только с вардами.',
        'Lots of time in the enemy jungle and ${r.deaths.length} deaths — farm there only with wards.'));
  }
  if (benchGpm != null && gpm.isNotEmpty && gpm.last.$2 < benchGpm * 0.85) {
    tips.add(L('Итоговый GPM ${gpm.last.$2} ниже среднего на герое (${benchGpm.round()}).', 'Final GPM ${gpm.last.$2} is below the hero average (${benchGpm.round()}).'));
  }
  if (tips.isEmpty) tips.add(L('Маршрут без явных провалов — так держать.', 'No obvious gaps in your route — keep it up.'));
  return FarmReport(f(base), f(lane), f(own), f(enemy), f(dead), idle, tips, gpm);
}

/// Мини-карта: позиция героя, лагеря, предлагаемый маршрут или след за матч.
class FarmMap extends StatelessWidget {
  final double? x, y;
  final List<Camp> camps;
  final Set<String> farmed;
  final List<Camp> route;
  final List<Sample> trail;
  final List<(int, double?, double?)> deaths;
  const FarmMap({super.key, this.x, this.y, this.camps = const [], this.farmed = const {}, this.route = const [], this.trail = const [], this.deaths = const []});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: _FarmPainter(this)),
        ),
      );
}

class _FarmPainter extends CustomPainter {
  final FarmMap m;
  _FarmPainter(this.m);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset o(double x, double y) => Offset(x * s, y * s);
    canvas.drawRect(Offset.zero & size, Paint()..color = C.dark ? const Color(0xFF16201A) : const Color(0xFFDDE8DF));
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(0, size.height)..lineTo(size.width, size.height)..close(),
        Paint()..color = (C.dark ? const Color(0xFF1B2A1F) : const Color(0xFFCFE3D3)));
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width, size.height)..close(),
        Paint()..color = (C.dark ? const Color(0xFF22191A) : const Color(0xFFEBD6D6)));
    canvas.drawLine(o(2, 2), o(98, 98), Paint()
      ..color = const Color(0xFF1E4C6B)
      ..strokeWidth = 6 * s
      ..strokeCap = StrokeCap.round);
    final lane = Paint()
      ..color = const Color(0xFF6D6A5E)
      ..strokeWidth = 2 * s
      ..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(8 * s, 86 * s)..lineTo(8 * s, 8 * s)..lineTo(86 * s, 8 * s), lane);
    canvas.drawPath(Path()..moveTo(14 * s, 92 * s)..lineTo(92 * s, 92 * s)..lineTo(92 * s, 14 * s), lane);
    canvas.drawLine(o(14, 86), o(86, 14), lane);
    // След за матч.
    if (m.trail.isNotEmpty) {
      final dot = Paint()..color = C.gold.withValues(alpha: 0.18);
      for (final t in m.trail) {
        if (t.x != null && t.alive) canvas.drawCircle(o(t.x!, t.y!), 1.3 * s, dot);
      }
    }
    // Лагеря.
    for (final c in m.camps) {
      final farmed = m.farmed.contains(c.id);
      canvas.drawCircle(
          o(c.x, c.y),
          (c.kind == 'ancient' ? 2.4 : 1.8) * s,
          Paint()
            ..color = farmed
                ? Colors.grey.withValues(alpha: 0.5)
                : (c.own ? const Color(0xFF3DD68C) : const Color(0xFF3DD68C).withValues(alpha: 0.4)));
    }
    // Маршрут.
    if (m.x != null && m.route.isNotEmpty) {
      final path = Path()..moveTo(m.x! * s, m.y! * s);
      for (final c in m.route) {
        path.lineTo(c.x * s, c.y * s);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = C.accent
            ..strokeWidth = 1.2 * s
            ..style = PaintingStyle.stroke);
      for (var i = 0; i < m.route.length; i++) {
        final c = m.route[i];
        canvas.drawCircle(o(c.x, c.y), 2.6 * s, Paint()..color = C.accent);
        final tp = TextPainter(
          text: TextSpan(text: '${i + 1}', style: TextStyle(color: Colors.white, fontSize: 2.8 * s, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o(c.x, c.y) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // Смерти.
    for (final d in m.deaths) {
      if (d.$2 == null) continue;
      final c = o(d.$2!, d.$3!);
      final p = Paint()
        ..color = const Color(0xFFFF5C7A)
        ..strokeWidth = 0.8 * s;
      canvas.drawLine(c - Offset(1.6 * s, 1.6 * s), c + Offset(1.6 * s, 1.6 * s), p);
      canvas.drawLine(c - Offset(-1.6 * s, 1.6 * s), c + Offset(-1.6 * s, 1.6 * s), p);
    }
    // Герой.
    if (m.x != null) {
      canvas.drawCircle(o(m.x!, m.y!), 2.6 * s, Paint()..color = Colors.white);
      canvas.drawCircle(o(m.x!, m.y!), 1.6 * s, Paint()..color = C.gold);
    }
  }

  @override
  bool shouldRepaint(covariant _FarmPainter old) => true;
}

/// Где на карте точка: база, линия, свой или чужой лес.
String zoneName(double? x, double? y, bool radiant) {
  if (x == null || y == null) return '';
  if (_inBase(x, y, radiant)) return L('у своей базы', 'near own base');
  if (_inBase(x, y, !radiant)) return L('у вражеской базы', 'near enemy base');
  if ((x + y - 100).abs() < 7 && x > 20 && x < 80) return L('на миду', 'mid lane');
  if (_onLane(x, y)) {
    final top = x < 13 || y < 13;
    return top ? L('на верхней линии', 'top lane') : L('на нижней линии', 'bottom lane');
  }
  final ownHalf = radiant ? y > x : y < x;
  return ownHalf ? L('в своём лесу', 'own jungle') : L('в чужом лесу', 'enemy jungle');
}
