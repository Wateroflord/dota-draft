import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Событие таймера матча. Время — в секундах игрового времени.
class TimerEvent {
  final String id;
  final String title;
  final int first; // когда впервые
  final int every; // период (0 — один раз)
  final int until; // до какого времени повторять (0 — всегда)
  final int lead; // за сколько секунд предупредить
  final bool enabled;
  const TimerEvent(this.id, this.title, this.first, this.every,
      {this.until = 0, this.lead = 15, this.enabled = true});

  TimerEvent copyWith({int? first, int? every, int? lead, bool? enabled}) => TimerEvent(
        id,
        title,
        first ?? this.first,
        every ?? this.every,
        until: until,
        lead: lead ?? this.lead,
        enabled: enabled ?? this.enabled,
      );

  /// Ближайшее наступление события не раньше [t].
  int? nextAt(int t) {
    if (first >= t) return first;
    if (every <= 0) return null;
    final n = ((t - first) / every).ceil();
    final v = first + n * every;
    if (until > 0 && v > until) return null;
    return v;
  }

  Map<String, dynamic> toJson() => {'id': id, 'first': first, 'every': every, 'lead': lead, 'enabled': enabled};
}

/// Значения по умолчанию. В новых патчах тайминги могут меняться — их можно поправить в приложении.
const defaultTimerEvents = [
  TimerEvent('bounty', 'Руны богатства', 0, 180, lead: 15),
  TimerEvent('power', 'Руна силы', 360, 120, lead: 15),
  TimerEvent('water', 'Водные руны', 120, 120, until: 240, lead: 10),
  TimerEvent('wisdom', 'Руны мудрости', 420, 420, lead: 30),
  TimerEvent('lotus', 'Лотосы', 180, 180, lead: 10, enabled: false),
  TimerEvent('stack', 'Стак лагеря', 53, 60, lead: 0, enabled: false),
  TimerEvent('night', 'Наступает ночь', 300, 600, lead: 0, enabled: false),
  TimerEvent('day', 'Наступает день', 600, 600, lead: 0, enabled: false),
  TimerEvent('tormentor', 'Торментор', 1200, 0, lead: 30),
];

/// Точка на карте (координаты 0–100, начало — левый верхний угол; Свет внизу слева).
class MapPoint {
  final String id;
  final String kind; // obs, sen, small, medium, large, ancient, rune, roshan, tormentor, note
  final double x, y;
  final String title;
  final String note;
  final int phase; // для вардов: 0 ранняя, 1 середина, 2 Рошан/торментор, 3 поздняя; для остального 0
  final bool custom;
  const MapPoint(this.id, this.kind, this.x, this.y, this.title,
      {this.note = '', this.phase = 0, this.custom = false});

  MapPoint moved(double nx, double ny) => MapPoint(id, kind, nx, ny, title, note: note, phase: phase, custom: custom);

  Map<String, dynamic> toJson() =>
      {'id': id, 'k': kind, 'x': x, 'y': y, 't': title, 'n': note, 'p': phase, 'c': custom};

  static MapPoint fromJson(Map j) => MapPoint(
        j['id']?.toString() ?? '',
        j['k']?.toString() ?? 'note',
        (j['x'] as num?)?.toDouble() ?? 50,
        (j['y'] as num?)?.toDouble() ?? 50,
        j['t']?.toString() ?? '',
        note: j['n']?.toString() ?? '',
        phase: (j['p'] as num?)?.toInt() ?? 0,
        custom: j['c'] == true,
      );
}

class FarmRoute {
  final String id;
  final String title;
  final String desc;
  final List<List<double>> points; // [[x, y], ...]
  final bool custom;
  const FarmRoute(this.id, this.title, this.desc, this.points, {this.custom = false});

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'd': desc, 'p': points, 'c': custom};

  static FarmRoute fromJson(Map j) => FarmRoute(
        j['id']?.toString() ?? '',
        j['t']?.toString() ?? '',
        j['d']?.toString() ?? '',
        ((j['p'] as List?) ?? const [])
            .whereType<List>()
            .map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
            .toList(),
        custom: j['c'] == true,
      );
}

/// Настройки инструментов: таймеры, правки карты, свой фон карты, рекорд квиза.
class ToolsState extends ChangeNotifier {
  final Map<String, TimerEvent> timerOverrides = {};
  bool voice = true;

  // Правки карты: перемещённые/скрытые стандартные точки и свои точки/маршруты.
  final Map<String, List<double>> moved = {}; // id -> [x, y] (для стороны Света)
  final Set<String> hidden = {};
  final List<MapPoint> customPoints = [];
  final List<FarmRoute> customRoutes = [];
  String? mapImage; // путь к своей картинке карты

  int quizBest = 0;

  List<TimerEvent> get timerEvents => [
        for (final d in defaultTimerEvents) timerOverrides[d.id] ?? d,
      ];

  void updateTimer(TimerEvent e) {
    timerOverrides[e.id] = e;
    _changed();
  }

  void resetTimers() {
    timerOverrides.clear();
    _changed();
  }

  void setVoice(bool v) {
    voice = v;
    _changed();
  }

  void movePoint(MapPoint p, double x, double y) {
    if (p.custom) {
      final i = customPoints.indexWhere((c) => c.id == p.id);
      if (i >= 0) customPoints[i] = p.moved(x, y);
    } else {
      moved[p.id] = [x, y];
    }
    _changed();
  }

  void removePoint(MapPoint p) {
    if (p.custom) {
      customPoints.removeWhere((c) => c.id == p.id);
    } else {
      hidden.add(p.id);
    }
    _changed();
  }

  void addPoint(MapPoint p) {
    customPoints.add(p);
    _changed();
  }

  void addRoute(FarmRoute r) {
    customRoutes.add(r);
    _changed();
  }

  void removeRoute(String id) {
    customRoutes.removeWhere((r) => r.id == id);
    _changed();
  }

  void resetMap() {
    moved.clear();
    hidden.clear();
    _changed();
  }

  void setMapImage(String? path) {
    mapImage = path;
    _changed();
  }

  void setQuizBest(int v) {
    if (v <= quizBest) return;
    quizBest = v;
    _changed();
  }

  // ---------- сохранение ----------

  Timer? _t;
  void _changed() {
    notifyListeners();
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<File?> _file() async {
    try {
      final d = await getApplicationDocumentsDirectory();
      return File('${d.path}/tools_state.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f?.writeAsString(jsonEncode({
        'timers': timerOverrides.values.map((e) => e.toJson()).toList(),
        'voice': voice,
        'moved': moved,
        'hidden': hidden.toList(),
        'points': customPoints.map((p) => p.toJson()).toList(),
        'routes': customRoutes.map((r) => r.toJson()).toList(),
        'mapImage': mapImage,
        'quizBest': quizBest,
      }));
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final t in ((j['timers'] as List?) ?? const []).whereType<Map>()) {
        final id = t['id']?.toString();
        final base = defaultTimerEvents.where((d) => d.id == id).firstOrNull;
        if (base == null) continue;
        timerOverrides[base.id] = base.copyWith(
          first: (t['first'] as num?)?.toInt(),
          every: (t['every'] as num?)?.toInt(),
          lead: (t['lead'] as num?)?.toInt(),
          enabled: t['enabled'] is bool ? t['enabled'] as bool : null,
        );
      }
      voice = j['voice'] != false;
      final mv = j['moved'];
      if (mv is Map) {
        mv.forEach((k, v) {
          if (v is List && v.length == 2) moved['$k'] = [(v[0] as num).toDouble(), (v[1] as num).toDouble()];
        });
      }
      hidden.addAll(((j['hidden'] as List?) ?? const []).map((e) => '$e'));
      customPoints.addAll(((j['points'] as List?) ?? const []).whereType<Map>().map(MapPoint.fromJson));
      customRoutes.addAll(((j['routes'] as List?) ?? const []).whereType<Map>().map(FarmRoute.fromJson));
      mapImage = j['mapImage']?.toString();
      if (mapImage != null && !File(mapImage!).existsSync()) mapImage = null;
      quizBest = (j['quizBest'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {}
  }
}

class ToolsScope extends InheritedNotifier<ToolsState> {
  const ToolsScope({super.key, required ToolsState state, required super.child}) : super(notifier: state);

  static ToolsState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ToolsScope>()!.notifier!;
  static ToolsState read(BuildContext c) => c.getInheritedWidgetOfExactType<ToolsScope>()!.notifier!;
}
