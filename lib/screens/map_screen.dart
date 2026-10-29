import '../i18n.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../map_data.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';

bool _rotatedId(String id) => id.startsWith('d_') || id.startsWith('e_');
String _baseId(String id) => _rotatedId(id) ? id.substring(2) : id;

Color kindColor(String k) => switch (k) {
      'obs' => C.gold,
      'sen' => C.intel,
      'small' => const Color(0xFF9BE39B),
      'medium' => const Color(0xFF3DD68C),
      'large' => const Color(0xFF1FA463),
      'ancient' => const Color(0xFFC79BFF),
      'rune' => const Color(0xFF4CC9F0),
      'roshan' => C.accent,
      'tormentor' => const Color(0xFF5B9DFF),
      _ => C.accent2,
    };

String kindTitle(String k) => switch (k) {
      'obs' => L('Обсервер', 'Observer'),
      'sen' => L('Сентри', 'Sentry'),
      'small' => L('Малый лагерь', 'Small camp'),
      'medium' => L('Средний лагерь', 'Medium camp'),
      'large' => L('Большой лагерь', 'Large camp'),
      'ancient' => L('Древние', 'Ancients'),
      'rune' => L('Руна', 'Rune'),
      'roshan' => L('Рошан', 'Roshan'),
      'tormentor' => L('Торментор', 'Tormentor'),
      _ => L('Заметка', 'Note'),
    };

/// Карта: маршруты фарма (wards = false) или варды (wards = true).
class MapScreen extends StatefulWidget {
  final bool wards;
  const MapScreen({super.key, required this.wards});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool radiant = true;
  bool edit = false;
  int phase = -1; // для вардов: -1 — все
  String? routeId;
  List<List<double>>? drawing; // новый маршрут
  MapPoint? selected;
  Map<String, Map<String, int>>? myObs, mySen;
  bool loadingWards = false;

  // Координаты в «системе Света»: для стороны Тьмы поворачиваем на 180°.
  List<double> _toView(double x, double y, bool rotated) => rotated ? [100 - x, 100 - y] : [x, y];

  List<MapPoint> _points(ToolsState tools) {
    final base = widget.wards ? wardSpots(radiant) : mapObjects(radiant);
    final out = <MapPoint>[];
    for (final p in base) {
      final b = _baseId(p.id);
      if (tools.hidden.contains(b)) continue;
      final m = tools.moved[b];
      if (m != null) {
        final v = _toView(m[0], m[1], _rotatedId(p.id));
        out.add(p.moved(v[0], v[1]));
      } else {
        out.add(p);
      }
    }
    for (final c in tools.customPoints) {
      final isWard = c.kind == 'obs' || c.kind == 'sen';
      if (isWard != widget.wards) continue;
      final v = _toView(c.x, c.y, !radiant);
      out.add(c.moved(v[0], v[1]));
    }
    if (widget.wards && phase >= 0) return out.where((p) => p.phase == phase || p.custom).toList();
    return out;
  }

  List<FarmRoute> _routes(ToolsState tools) => [
        ...farmRoutes(radiant),
        for (final r in tools.customRoutes)
          FarmRoute(r.id, r.title, r.desc, [for (final p in r.points) _toView(p[0], p[1], !radiant)], custom: true),
      ];

  void _move(ToolsState tools, MapPoint p, double x, double y) {
    // Сохраняем в системе Света.
    final rotated = p.custom ? !radiant : _rotatedId(p.id);
    final v = _toView(x.clamp(0, 100).toDouble(), y.clamp(0, 100).toDouble(), rotated);
    if (p.custom) {
      final orig = tools.customPoints.firstWhere((c) => c.id == p.id);
      tools.movePoint(orig, v[0], v[1]);
    } else {
      tools.movePoint(MapPoint(_baseId(p.id), p.kind, 0, 0, p.title), v[0], v[1]);
    }
  }

  Future<void> _addPoint(ToolsState tools, double x, double y) async {
    final title = TextEditingController();
    final note = TextEditingController();
    var kind = widget.wards ? 'obs' : 'note';
    var ph = phase < 0 ? 0 : phase;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: C.surface,
          title: Text(widget.wards ? L('Новый вард', 'New ward') : L('Новая точка', 'New point'), style: T.h2),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in widget.wards ? const ['obs', 'sen'] : const ['note', 'small', 'medium', 'large', 'ancient'])
                  Pill(kindTitle(k), color: kindColor(k), filled: kind == k, onTap: () => setD(() => kind = k)),
              ]),
              if (widget.wards) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < wardPhases.length; i++)
                    Pill(wardPhases[i], color: C.accent2, filled: ph == i, onTap: () => setD(() => ph = i)),
                ]),
              ],
              const SizedBox(height: 10),
              TextField(controller: title, decoration: fieldDeco(L('Название', 'Name'))),
              const SizedBox(height: 8),
              TextField(controller: note, decoration: fieldDeco(L('Заметка (необязательно)', 'Note (optional)'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Добавить', 'Add'))),
          ],
        ),
      ),
    );
    if (ok == true) {
      final v = _toView(x, y, !radiant);
      tools.addPoint(MapPoint('c_${DateTime.now().microsecondsSinceEpoch}', kind, v[0], v[1],
          title.text.trim().isEmpty ? kindTitle(kind) : title.text.trim(),
          note: note.text.trim(), phase: ph, custom: true));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      title.dispose();
      note.dispose();
    });
  }

  Future<void> _saveRoute(ToolsState tools) async {
    final pts = drawing ?? const [];
    if (pts.length < 2) {
      setState(() => drawing = null);
      return;
    }
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(L('Сохранить маршрут', 'Save route'), style: T.h2),
        content: TextField(controller: title, autofocus: true, decoration: fieldDeco(L('Название, например «Мой фарм на AM»', 'Name, e.g. "My AM farm"'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Отмена', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Сохранить', 'Save'))),
        ],
      ),
    );
    if (ok == true) {
      final id = 'cr_${DateTime.now().microsecondsSinceEpoch}';
      tools.addRoute(FarmRoute(id, title.text.trim().isEmpty ? L('Мой маршрут', 'My route') : title.text.trim(), L('Свой маршрут', 'Custom route'),
          [for (final p in pts) _toView(p[0], p[1], !radiant)],
          custom: true));
      setState(() => routeId = id);
    }
    setState(() => drawing = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => title.dispose());
  }

  Future<void> _pickBackground(ToolsState tools) async {
    if (tools.mapImage != null) {
      final reset = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: C.surface,
          title: Text(L('Фон карты', 'Map background'), style: T.h2),
          content: Text(L('Сейчас стоит твоя картинка. Заменить её или вернуть схему?', 'Your picture is set now. Replace it or go back to the scheme?'), style: T.body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L('Вернуть схему', 'Back to scheme'))),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L('Заменить', 'Replace'))),
          ],
        ),
      );
      if (reset == null) return;
      if (reset) {
        tools.setMapImage(null);
        return;
      }
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/map_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(path);
    tools.setMapImage(path);
    if (mounted) showToast(context, L('Фон заменён. Если точки не совпадают — подвинь их в режиме правки.', 'Background replaced. If points do not match, move them in edit mode.'));
  }

  Future<void> _loadMyWards() async {
    final s = StateScope.read(context);
    if (s.accountId == null) {
      showToast(context, L('Сначала загрузи профиль Steam во вкладке «Мои герои»', 'Load your Steam profile on the My heroes tab first'));
      return;
    }
    setState(() => loadingWards = true);
    try {
      final w = await OpenDota.wardmap(s.accountId!);
      setState(() {
        myObs = w.$1;
        mySen = w.$2;
      });
      if ((myObs?.isEmpty ?? true) && (mySen?.isEmpty ?? true)) {
        if (mounted) showToast(context, L('OpenDota пока не разобрал твои матчи подробно — вардов нет.', 'OpenDota has not parsed your matches in detail yet — no wards.'));
      }
    } on OdException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => loadingWards = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    final points = _points(tools);
    final routes = widget.wards ? <FarmRoute>[] : _routes(tools);
    final route = routes.where((r) => r.id == routeId).firstOrNull;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.wards ? L('Карта вардов', 'Ward map') : L('Маршруты фарма', 'Farm routes'), style: T.h2),
        actions: [
          IconButton(
            tooltip: L('Фон карты', 'Map background'),
            icon: const Icon(Icons.image_outlined),
            onPressed: () => _pickBackground(tools),
          ),
          IconButton(
            tooltip: edit ? L('Готово', 'Done') : L('Править точки', 'Edit points'),
            icon: Icon(edit ? Icons.check : Icons.edit_location_alt_outlined, color: edit ? C.accent : null),
            onPressed: () => setState(() {
              edit = !edit;
              drawing = null;
            }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          Row(children: [
            Pill(L('Свет', 'Radiant'), color: C.ally, filled: radiant, onTap: () => setState(() => radiant = true)),
            const SizedBox(width: 6),
            Pill(L('Тьма', 'Dire'), color: C.enemy, filled: !radiant, onTap: () => setState(() => radiant = false)),
            const Spacer(),
            if (widget.wards)
              TextButton.icon(
                onPressed: loadingWards ? null : _loadMyWards,
                icon: loadingWards
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person, size: 16),
                label: Text(L('Мои варды', 'My wards')),
              ),
          ]),
          if (widget.wards) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Pill(L('Все', 'All'), color: C.accent, filled: phase == -1, onTap: () => setState(() => phase = -1)),
                for (var i = 0; i < wardPhases.length; i++) ...[
                  const SizedBox(width: 6),
                  Pill(wardPhases[i], color: C.accent, filled: phase == i, onTap: () => setState(() => phase = i)),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(builder: (_, c) {
            final size = c.maxWidth;
            return GestureDetector(
              onTapUp: (d) {
                final x = d.localPosition.dx / size * 100, y = d.localPosition.dy / size * 100;
                if (drawing != null) {
                  setState(() => drawing = [...drawing!, [x, y]]);
                } else if (edit) {
                  _addPoint(tools, x, y);
                } else {
                  setState(() => selected = null);
                }
              },
              child: SizedBox(
                width: size,
                height: size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(children: [
                    Positioned.fill(
                      child: tools.mapImage != null
                          ? Image.file(File(tools.mapImage!), fit: BoxFit.cover)
                          : const CustomPaint(painter: _MapPainter()),
                    ),
                    if (myObs != null || mySen != null)
                      Positioned.fill(child: CustomPaint(painter: _HeatPainter(myObs ?? {}, mySen ?? {}))),
                    if (route != null || drawing != null)
                      Positioned.fill(
                        child: CustomPaint(painter: _RoutePainter(drawing ?? route!.points, drawing != null)),
                      ),
                    for (var i = 0; i < points.length; i++) _marker(tools, points[i], size, i),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          if (selected != null) _infoCard(tools, selected!),
          if (edit)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                drawing != null
                    ? L('Нажимай по карте по порядку — так рисуется маршрут. Потом «Сохранить маршрут».', 'Tap the map in order to draw the route. Then tap Save route.')
                    : L('Режим правки: перетаскивай точки, нажми на пустое место — добавить свою, '
                        'нажми на точку — удалить или подробнее.', 'Edit mode: drag points, tap an empty spot to add your own, '
                        'tap a point to delete it or see details.'),
                style: T.small,
              ),
            ),
          if (!widget.wards) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: drawing == null
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
                        onPressed: () => setState(() {
                          drawing = [];
                          routeId = null;
                        }),
                        icon: const Icon(Icons.gesture, size: 18),
                        label: Text(L('Нарисовать свой маршрут', 'Draw your own route')),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: C.accent),
                        onPressed: () => _saveRoute(tools),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(L('Сохранить маршрут (${drawing!.length})', 'Save route (${drawing!.length})')),
                      ),
              ),
              if (drawing != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => drawing = null), child: Text(L('Отмена', 'Cancel'))),
              ],
            ]),
            SectionLabel(L('Маршруты', 'Routes')),
            for (final r in routes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: r.id == routeId ? C.accent : null,
                  onTap: () => setState(() => routeId = r.id == routeId ? null : r.id),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(r.custom ? Icons.gesture : Icons.alt_route, color: r.id == routeId ? C.accent : C.muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(r.desc, style: T.small),
                      ]),
                    ),
                    if (r.custom)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.delete_outline, size: 18, color: C.muted),
                        onPressed: () => tools.removeRoute(r.id),
                      ),
                  ]),
                ),
              ),
          ],
          if (widget.wards) ...[
            SectionLabel(L('Точки', 'Points')),
            for (final p in points.where((p) => p.kind == 'obs' || p.kind == 'sen'))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  padding: const EdgeInsets.all(10),
                  onTap: () => setState(() => selected = p),
                  child: Row(children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: kindColor(p.kind), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p.title} · ${kindTitle(p.kind)}', style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        if (p.note.isNotEmpty) Text(p.note, style: T.small),
                      ]),
                    ),
                    Text(wardPhases[p.phase.clamp(0, 3)], style: T.small),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            L('Схема примерная: в больших патчах Valve двигает лагеря и объекты. Поправь точки под текущую карту '
            '(иконка с карандашом) или поставь фоном скриншот миникарты (иконка с картинкой).', 'The scheme is approximate: big patches move camps and objects. Adjust points to the current map '
            '(pencil icon) or set a minimap screenshot as the background (picture icon).'),
            style: T.small,
          ),
          if (edit) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: tools.resetMap, child: Text(L('Вернуть стандартные точки', 'Restore default points'))),
          ],
        ],
      ),
    );
  }

  Widget _marker(ToolsState tools, MapPoint p, double size, int index) {
    final isWard = p.kind == 'obs' || p.kind == 'sen';
    final enemyCamp = !widget.wards && campKinds.contains(p.kind) && (radiant ? p.id.startsWith('e_') : !p.id.startsWith('d_') && p.id.startsWith('r_'));
    final d = isWard ? 22.0 : (p.kind == 'ancient' || p.kind == 'roshan' ? 18.0 : 14.0);
    final color = kindColor(p.kind);
    return Positioned(
      left: p.x / 100 * size - d / 2,
      top: p.y / 100 * size - d / 2,
      child: GestureDetector(
        onTap: () => setState(() => selected = p),
        onPanUpdate: edit
            ? (det) {
                final nx = p.x + det.delta.dx / size * 100, ny = p.y + det.delta.dy / size * 100;
                _move(tools, p, nx, ny);
              }
            : null,
        child: Opacity(
          opacity: enemyCamp ? 0.45 : 1,
          child: Container(
            width: d,
            height: d,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isWard ? color.withValues(alpha: 0.25) : color,
              shape: p.kind == 'rune' ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: p.kind == 'rune' ? BorderRadius.circular(3) : null,
              border: Border.all(color: selected?.id == p.id ? Colors.white : color, width: selected?.id == p.id ? 2 : 1.5),
            ),
            child: isWard
                ? Icon(p.kind == 'obs' ? Icons.visibility : Icons.visibility_off, size: 12, color: color)
                : (p.kind == 'roshan'
                    ? const Text('R', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white))
                    : null),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(ToolsState tools, MapPoint p) => AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        borderColor: kindColor(p.kind).withValues(alpha: 0.6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: T.body.copyWith(fontWeight: FontWeight.w700)),
              Text(
                L('${kindTitle(p.kind)}${(p.kind == 'obs' || p.kind == 'sen') ? ' · ${wardPhases[p.phase.clamp(0, 3)]}' : ''}'
                '${p.custom ? ' · твоя точка' : ''}', '${kindTitle(p.kind)}${(p.kind == 'obs' || p.kind == 'sen') ? ' · ${wardPhases[p.phase.clamp(0, 3)]}' : ''}'
                '${p.custom ? ' · your point' : ''}'),
                style: T.small,
              ),
              if (p.note.isNotEmpty) ...[const SizedBox(height: 4), Text(p.note, style: T.body.copyWith(fontSize: 13))],
            ]),
          ),
          if (edit)
            IconButton(
              icon: Icon(Icons.delete_outline, color: C.muted),
              onPressed: () {
                final orig = p.custom ? tools.customPoints.firstWhere((c) => c.id == p.id) : MapPoint(_baseId(p.id), p.kind, 0, 0, '');
                tools.removePoint(orig);
                setState(() => selected = null);
              },
            ),
        ]),
      );
}

/// Схематичная карта: лес, река, линии, базы.
class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset o(double x, double y) => Offset(x * s, y * s);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF16201A));
    // Половины карты
    final rad = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(rad, Paint()..color = const Color(0xFF1B2A1F));
    final dire = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(dire, Paint()..color = const Color(0xFF22191A));
    // Река
    canvas.drawLine(o(2, 2), o(98, 98), Paint()
      ..color = const Color(0xFF1E4C6B)
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round);
    // Линии
    final lane = Paint()
      ..color = const Color(0xFF6D6A5E)
      ..strokeWidth = 2.2 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final top = Path()
      ..moveTo(8 * s, 86 * s)
      ..lineTo(8 * s, 8 * s)
      ..lineTo(86 * s, 8 * s);
    final bot = Path()
      ..moveTo(14 * s, 92 * s)
      ..lineTo(92 * s, 92 * s)
      ..lineTo(92 * s, 14 * s);
    canvas.drawPath(top, lane);
    canvas.drawPath(bot, lane);
    canvas.drawLine(o(14, 86), o(86, 14), lane);
    // Базы
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1 * s, 81 * s, 18 * s, 18 * s), Radius.circular(3 * s)),
        Paint()..color = const Color(0xFF2F7D4A));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(81 * s, 1 * s, 18 * s, 18 * s), Radius.circular(3 * s)),
        Paint()..color = const Color(0xFF8A2E2E));
    // Вышки
    final tower = Paint()..color = const Color(0xFFBFBFBF);
    for (final t in const [
      [8, 62], [8, 40], [8, 22], [38, 92], [60, 92], [78, 92], [30, 70], [40, 60], [22, 78],
    ]) {
      canvas.drawCircle(o(t[0].toDouble(), t[1].toDouble()), 1.1 * s, tower);
      canvas.drawCircle(o(100 - t[0].toDouble(), 100 - t[1].toDouble()), 1.1 * s, tower);
    }
    _label(canvas, L('Свет', 'Radiant'), o(10, 90), s, const Color(0xFFBFF0CF));
    _label(canvas, L('Тьма', 'Dire'), o(90, 10), s, const Color(0xFFF3C0C0));
  }

  void _label(Canvas c, String t, Offset at, double s, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: 3.2 * s, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Маршрут с номерами шагов.
class _RoutePainter extends CustomPainter {
  final List<List<double>> pts;
  final bool drawing;
  _RoutePainter(this.pts, this.drawing);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    final s = size.width / 100;
    final paint = Paint()
      ..color = (drawing ? C.gold : C.accent).withValues(alpha: 0.9)
      ..strokeWidth = 1.4 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first[0] * s, pts.first[1] * s);
    for (final p in pts.skip(1)) {
      path.lineTo(p[0] * s, p[1] * s);
    }
    canvas.drawPath(path, paint);
    // Стрелки на отрезках
    for (var i = 1; i < pts.length; i++) {
      final a = Offset(pts[i - 1][0] * s, pts[i - 1][1] * s), b = Offset(pts[i][0] * s, pts[i][1] * s);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final l = 2.4 * s;
      final arrow = Path()
        ..moveTo(mid.dx + l * math.cos(ang), mid.dy + l * math.sin(ang))
        ..lineTo(mid.dx + l * math.cos(ang + 2.5), mid.dy + l * math.sin(ang + 2.5))
        ..lineTo(mid.dx + l * math.cos(ang - 2.5), mid.dy + l * math.sin(ang - 2.5))
        ..close();
      canvas.drawPath(arrow, Paint()..color = paint.color);
    }
    for (var i = 0; i < pts.length; i++) {
      final c = Offset(pts[i][0] * s, pts[i][1] * s);
      canvas.drawCircle(c, 2.4 * s, Paint()..color = Colors.black.withValues(alpha: 0.7));
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: TextStyle(color: Colors.white, fontSize: 2.6 * s, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => true;
}

/// Тепловая карта вардов игрока (координаты OpenDota ~64–192).
class _HeatPainter extends CustomPainter {
  final Map<String, Map<String, int>> obs, sen;
  _HeatPainter(this.obs, this.sen);

  @override
  void paint(Canvas canvas, Size size) {
    void draw(Map<String, Map<String, int>> m, Color c) {
      var max = 1;
      m.forEach((_, ys) => ys.forEach((_, n) => max = math.max(max, n)));
      m.forEach((xs, ys) {
        final x = double.tryParse(xs) ?? 0;
        ys.forEach((yv, n) {
          final y = double.tryParse(yv) ?? 0;
          final px = ((x - 64) / 128 * 100).clamp(0, 100) * size.width / 100;
          final py = (100 - (y - 64) / 128 * 100).clamp(0, 100) * size.height / 100;
          canvas.drawCircle(Offset(px.toDouble(), py.toDouble()), size.width * 0.012 + size.width * 0.02 * n / max,
              Paint()..color = c.withValues(alpha: 0.25 + 0.5 * n / max));
        });
      });
    }

    draw(obs, C.gold);
    draw(sen, C.intel);
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) => true;
}
