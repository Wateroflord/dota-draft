import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'gsi.dart';
import 'i18n.dart';
import 'overlay.dart';
import 'recognize.dart';
import 'screens/scan_draft_screen.dart';
import 'state.dart';
import 'winutil.dart';

/// Последний снимок экрана (чтобы открыть его для проверки).
Uint8List? lastShot;

/// Снять экран и распознать героев в верхней полосе. Возвращает текст для уведомления.
Future<String> draftFromScreen(AppState s, {bool enemiesOnly = false}) async {
  if (s.portraits.heroes.isEmpty) return L('Нет данных для распознавания', 'No recognition data');
  var hidden = false;
  try {
    if (overlay.active && await windowManager.isVisible()) {
      await windowManager.hide();
      hidden = true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  } catch (_) {}
  final bytes = await captureScreen();
  if (hidden) {
    try {
      await windowManager.show();
    } catch (_) {}
  }
  if (bytes == null) return L('Не удалось снять экран', 'Screen capture failed');
  lastShot = bytes;
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final band = defaultBand(frame.image.width / frame.image.height);
  List<double> abs(Rect r) => [band.left + r.left * band.width, band.top + r.top * band.height, r.width * band.width, r.height * band.height];
  final res = await compute(recognize, RecognizeJob(bytes, [abs(defaultLeft), abs(defaultRight)], s.portraits.heroes, s.portraits.w, s.portraits.h));
  // Уверенные совпадения, без повторов.
  final ids = List<int?>.filled(10, null);
  final used = <int>{};
  final order = [for (var i = 0; i < res.length; i++) i]
    ..sort((a, b) => (res[a].isEmpty ? 99 : res[a][0][1]).compareTo(res[b].isEmpty ? 99 : res[b][0][1]));
  for (final i in order) {
    if (res[i].isEmpty) continue;
    final best = res[i][0];
    final second = res[i].length > 1 ? res[i][1][1] : 99;
    if (!(best[1] < 0.8 || (best[1] < 1.2 && second - best[1] > 0.12))) continue; // не уверены
    final id = best[0].toInt();
    if (used.add(id)) ids[i] = id;
  }
  final weLeft = gsi.last?.team != 'dire';
  final l = ids.sublist(0, 5), r = ids.sublist(5, 10);
  final ours = weLeft ? l : r, theirs = weLeft ? r : l;
  var n = 0;
  for (var i = 0; i < 5; i++) {
    if (!enemiesOnly && ours[i] != null) {
      s.setSlot(true, i, ours[i]);
      n++;
    }
    if (theirs[i] != null) {
      s.setSlot(false, i, theirs[i]);
      n++;
    }
  }
  if (n == 0) return L('Героев на экране не нашёл — открой драфт по скриншоту и поправь рамки', 'No heroes found — open Draft from screenshot and adjust the boxes');
  return enemiesOnly
      ? L('Враги из экрана: ${s.enemyHeroes.map((h) => h.name).join(', ')}', 'Enemies from screen: ${s.enemyHeroes.map((h) => h.name).join(', ')}')
      : L('Распознано героев: $n. Проверь вкладку «Драфт».', 'Recognized heroes: $n. Check the Draft tab.');
}

/// Открыть последний снимок для ручной проверки.
void openLastShot(BuildContext context) {
  final b = lastShot;
  if (b == null) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScanDraftScreen(initial: b, weLeft: gsi.last?.team != 'dire')));
}
