import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data.dart';
import '../i18n.dart';
import '../platform.dart';
import '../recognize.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hero_picker.dart';

/// Полоса с портретами по умолчанию (доли от экрана) — зависит от соотношения сторон.
Rect defaultBand(double ratio) => ratio > 2.0
    ? const Rect.fromLTWH(0.31, 0.0, 0.38, 0.05)
    : ratio < 1.5
        ? const Rect.fromLTWH(0.18, 0.0, 0.64, 0.045)
        : const Rect.fromLTWH(0.25, 0.0, 0.5, 0.05);

const defaultLeft = Rect.fromLTWH(0.068, 0.08, 0.348, 0.84);
const defaultRight = Rect.fromLTWH(0.584, 0.08, 0.348, 0.84);

/// Драфт по скриншоту: выделяешь полосу с портретами героев вверху экрана, приложение их узнаёт.
class ScanDraftScreen extends StatefulWidget {
  final Uint8List? initial; // готовый снимок экрана (Windows)
  final bool? weLeft;
  const ScanDraftScreen({super.key, this.initial, this.weLeft});

  @override
  State<ScanDraftScreen> createState() => _ScanDraftScreenState();
}

class _ScanDraftScreenState extends State<ScanDraftScreen> {
  Uint8List? bytes;
  ui.Image? image;
  // Полоса с портретами (доли от картинки) и две команды внутри полосы (доли от полосы).
  Rect band = const Rect.fromLTWH(0.25, 0.0, 0.5, 0.05);
  Rect left = const Rect.fromLTWH(0.068, 0.08, 0.348, 0.84);
  Rect right = const Rect.fromLTWH(0.584, 0.08, 0.348, 0.84);
  bool weLeft = true; // мы — Свет (слева)
  bool busy = false;
  List<List<List<num>>>? result;
  final List<int?> chosen = List.filled(10, null);

  @override
  void initState() {
    super.initState();
    if (widget.weLeft != null) weLeft = widget.weLeft!;
    if (widget.initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _use(widget.initial!);
        if (mounted) _recognize();
      });
    }
  }

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 2560);
    if (x == null) return;
    await _use(await x.readAsBytes());
  }

  Future<void> _use(Uint8List b) async {
    final im = await decodeImageFromList(b);
    if (!mounted) return;
    setState(() {
      bytes = b;
      image = im;
      result = null;
      band = defaultBand(im.width / im.height);
    });
  }

  Future<void> _recognize() async {
    final s = StateScope.read(context);
    if (s.portraits.heroes.isEmpty) {
      showToast(context, L('Нет данных для распознавания — обнови данные в «О данных».', 'No recognition data — refresh data first.'));
      return;
    }
    setState(() => busy = true);
    List<double> abs(Rect r) =>
        [band.left + r.left * band.width, band.top + r.top * band.height, r.width * band.width, r.height * band.height];
    final job = RecognizeJob(bytes!, [abs(left), abs(right)], s.portraits.heroes, s.portraits.w, s.portraits.h);
    final res = await compute(recognize, job);
    // Без повторов: один герой — одна ячейка (жадно по уверенности).
    final used = <int>{};
    final order = [for (var i = 0; i < res.length; i++) i]
      ..sort((a, b) => (res[a].isEmpty ? 99 : res[a][0][1]).compareTo(res[b].isEmpty ? 99 : res[b][0][1]));
    for (final i in order) {
      chosen[i] = null;
      for (final c in res[i]) {
        final id = c[0].toInt();
        if (used.add(id)) {
          chosen[i] = id;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      result = res;
      busy = false;
    });
  }

  void _apply() {
    final s = StateScope.read(context);
    final l = chosen.sublist(0, 5), r = chosen.sublist(5, 10);
    final ours = weLeft ? l : r, theirs = weLeft ? r : l;
    for (var i = 0; i < 5; i++) {
      s.setSlot(true, i, null);
      s.setSlot(false, i, null);
    }
    for (var i = 0; i < 5; i++) {
      if (ours[i] != null) s.setSlot(true, i, ours[i]);
      if (theirs[i] != null) s.setSlot(false, i, theirs[i]);
    }
    Navigator.of(context).pop();
    showToast(context, L('Драфт заполнен по скриншоту', 'Draft filled from the screenshot'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Драфт по скриншоту', 'Draft from screenshot'), style: T.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          if (image == null) ...[
            Text(
              L('Сделай скриншот драфта на ПК (в Steam — F12) и перешли его на телефон, или сфотографируй экран. '
                  'Потом отметь полосу с портретами героев вверху экрана — приложение узнает героев.',
                  'Take a screenshot of the draft on PC (F12 in Steam) and send it to your phone, or photograph the screen. '
                  'Then mark the strip with hero portraits at the top — the app will recognize the heroes.'),
              style: T.body,
            ),
            const SizedBox(height: 16),
          ],
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(44)),
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined),
                label: Text(isWindows ? L('Выбрать скриншот', 'Choose screenshot') : L('Из галереи', 'From gallery')),
              ),
            ),
            if (!isWindows) const SizedBox(width: 8),
            if (!isWindows)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: BorderSide(color: C.border), minimumSize: const Size.fromHeight(44)),
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(L('Камера', 'Camera')),
              ),
            ),
          ]),
          if (image != null) ...[
            SectionLabel(L('1. Выдели полосу с героями (тяни рамку и уголок)', '1. Mark the hero strip (drag the box and its corner)')),
            LayoutBuilder(builder: (_, c) {
              final w = c.maxWidth, h = w * image!.height / image!.width;
              return SizedBox(
                width: w,
                height: h,
                child: Stack(children: [
                  Positioned.fill(child: RawImage(image: image, fit: BoxFit.fill)),
                  _RectEditor(
                    rect: band,
                    area: Size(w, h),
                    color: C.gold,
                    onChanged: (r) => setState(() {
                      band = r;
                      result = null;
                    }),
                  ),
                ]),
              );
            }),
            SectionLabel(L('2. Поставь рамки на 5 героев каждой команды', '2. Place the boxes over 5 heroes of each team')),
            LayoutBuilder(builder: (_, c) {
              final w = c.maxWidth;
              final bw = band.width * image!.width, bh = band.height * image!.height;
              final h = (w * bh / bw).clamp(40.0, 220.0);
              return SizedBox(
                width: w,
                height: h,
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _CropPainter(image!, band))),
                  _RectEditor(
                    rect: left,
                    area: Size(w, h),
                    color: weLeft ? C.ally : C.enemy,
                    cells: 5,
                    onChanged: (r) => setState(() {
                      left = r;
                      result = null;
                    }),
                  ),
                  _RectEditor(
                    rect: right,
                    area: Size(w, h),
                    color: weLeft ? C.enemy : C.ally,
                    cells: 5,
                    onChanged: (r) => setState(() {
                      right = r;
                      result = null;
                    }),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(L('Моя команда:', 'My team:'), style: T.small),
              Pill(L('слева (Свет)', 'left (Radiant)'), color: C.ally, filled: weLeft, onTap: () => setState(() => weLeft = true)),
              Pill(L('справа (Тьма)', 'right (Dire)'), color: C.ally, filled: !weLeft, onTap: () => setState(() => weLeft = false)),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.accent, minimumSize: const Size.fromHeight(46)),
              onPressed: busy ? null : _recognize,
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high),
              label: Text(L('Распознать героев', 'Recognize heroes')),
            ),
          ],
          if (result != null) ...[
            SectionLabel(L('3. Проверь и поправь (нажми на героя)', '3. Check and fix (tap a hero)')),
            _resultRow(0, weLeft ? C.ally : C.enemy),
            const SizedBox(height: 8),
            _resultRow(5, weLeft ? C.enemy : C.ally),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.ally, minimumSize: const Size.fromHeight(46)),
              onPressed: _apply,
              icon: const Icon(Icons.check),
              label: Text(L('Перенести в драфт', 'Apply to draft')),
            ),
            const SizedBox(height: 8),
            Text(
              L('Распознавание примерное: при фото экрана или необычном интерфейсе герой может определиться неверно — '
                  'нажми на него и выбери правильного.',
                  'Recognition is approximate: with a photo of the screen or an unusual HUD a hero may be wrong — tap it to fix.'),
              style: T.small,
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(int start, Color color) {
    final s = StateScope.of(context);
    return Row(children: [
      for (var i = start; i < start + 5; i++) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => _fix(i),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(6)),
              child: LayoutBuilder(builder: (_, c) {
                final h = chosen[i] == null ? null : s.data!.byId[chosen[i]];
                return Column(children: [
                  h == null
                      ? SizedBox(height: c.maxWidth * 0.5625, child: Icon(Icons.help_outline, color: C.muted, size: 18))
                      : HeroImg(h, width: c.maxWidth),
                  const SizedBox(height: 2),
                  Text(h?.name ?? L('пусто', 'empty'),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: C.muted)),
                ]);
              }),
            ),
          ),
        ),
        if (i < start + 4) const SizedBox(width: 4),
      ],
    ]);
  }

  Future<void> _fix(int i) async {
    final s = StateScope.read(context);
    final cands = (result != null && i < result!.length ? result![i] : const <List<num>>[])
        .map((c) => s.data!.byId[c[0].toInt()])
        .whereType<DHero>()
        .take(5)
        .toList();
    final picked = await showSheet<int>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text(L('Кто это?', 'Who is it?'), style: T.h2),
          const SizedBox(height: 8),
          for (final h in cands)
            InkWell(
              onTap: () => Navigator.pop(context, h.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [HeroImg(h, width: 64), const SizedBox(width: 10), Text(h.name, style: T.body)]),
              ),
            ),
          TextButton(onPressed: () => Navigator.pop(context, -1), child: Text(L('Другой герой…', 'Another hero…'))),
          TextButton(onPressed: () => Navigator.pop(context, -2), child: Text(L('Пустой слот', 'Empty slot'))),
        ]),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked == -2) {
      setState(() => chosen[i] = null);
    } else if (picked == -1) {
      final id = await pickHero(context, title: L('Выбери героя', 'Choose a hero'));
      if (id != null) setState(() => chosen[i] = id);
    } else {
      setState(() => chosen[i] = picked);
    }
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect band;
  _CropPainter(this.image, this.band);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(band.left * image.width, band.top * image.height, band.width * image.width,
        band.height * image.height);
    canvas.drawImageRect(image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) => old.band != band || old.image != image;
}

/// Рамка, которую можно двигать и растягивать за правый нижний угол. Координаты — доли от области.
class _RectEditor extends StatelessWidget {
  final Rect rect;
  final Size area;
  final Color color;
  final int cells;
  final ValueChanged<Rect> onChanged;
  const _RectEditor({required this.rect, required this.area, required this.color, required this.onChanged, this.cells = 0});

  @override
  Widget build(BuildContext context) {
    final r = Rect.fromLTWH(rect.left * area.width, rect.top * area.height, rect.width * area.width, rect.height * area.height);
    return Stack(children: [
      Positioned(
        left: r.left,
        top: r.top,
        width: r.width,
        height: r.height,
        child: GestureDetector(
          onPanUpdate: (d) {
            final nl = (rect.left + d.delta.dx / area.width).clamp(0.0, 1 - rect.width);
            final nt = (rect.top + d.delta.dy / area.height).clamp(0.0, 1 - rect.height);
            onChanged(Rect.fromLTWH(nl, nt, rect.width, rect.height));
          },
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: color, width: 2), color: color.withValues(alpha: 0.08)),
            child: cells > 1
                ? Row(children: [
                    for (var i = 0; i < cells; i++)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                              border: i < cells - 1 ? Border(right: BorderSide(color: color.withValues(alpha: 0.7))) : null),
                        ),
                      ),
                  ])
                : null,
          ),
        ),
      ),
      Positioned(
        left: r.right - 14,
        top: r.bottom - 14,
        child: GestureDetector(
          onPanUpdate: (d) {
            final nw = (rect.width + d.delta.dx / area.width).clamp(0.03, 1 - rect.left);
            final nh = (rect.height + d.delta.dy / area.height).clamp(0.01, 1 - rect.top);
            onChanged(Rect.fromLTWH(rect.left, rect.top, nw, nh));
          },
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
            ),
          ),
        ),
      ),
    ]);
  }
}
