import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Задание для распознавания: картинка и прямоугольники команд (доли 0..1 от размера картинки).
class RecognizeJob {
  final Uint8List bytes;
  final List<List<double>> rects; // [[x, y, w, h], ...] — по 5 героев в каждом
  final Map<int, List<Uint8List>> portraits;
  final int pw, ph;
  const RecognizeJob(this.bytes, this.rects, this.portraits, this.pw, this.ph);
}

/// Для каждой ячейки — список (героя, расстояние) от лучшего к худшему; пустая ячейка — пустой список.
List<List<List<num>>> recognize(RecognizeJob job) {
  var image = img.decodeImage(job.bytes);
  if (image == null) return [];
  image = img.bakeOrientation(image);
  final w = job.pw, h = job.ph;

  // Отпечатки героев, нормализованные по яркости и контрасту.
  final refs = <int, List<Float32List>>{};
  job.portraits.forEach((id, list) {
    refs[id] = [for (final b in list) if (b.length == w * h * 3) _norm(b)];
  });

  final out = <List<List<num>>>[];
  for (final r in job.rects) {
    final x0 = r[0] * image.width, y0 = r[1] * image.height;
    final cw = r[2] * image.width / 5, ch = r[3] * image.height;
    for (var i = 0; i < 5; i++) {
      // Небольшой отступ внутрь ячейки — между портретами бывают рамки.
      final cx = x0 + i * cw + cw * 0.04, cy = y0 + ch * 0.04;
      final raw = _sample(image, cx, cy, cw * 0.92, ch * 0.92, w, h);
      if (_std(raw) < 12) {
        out.add(const []); // пустой слот (тёмная/однотонная ячейка)
        continue;
      }
      final v = _norm(raw);
      final scores = <List<num>>[];
      refs.forEach((id, list) {
        var best = double.infinity;
        for (final ref in list) {
          var d = 0.0;
          for (var k = 0; k < v.length; k++) {
            final x = v[k] - ref[k];
            d += x * x;
          }
          if (d < best) best = d;
        }
        scores.add([id, best / v.length]);
      });
      scores.sort((a, b) => a[1].compareTo(b[1]));
      out.add(scores.take(8).toList());
    }
  }
  return out;
}

/// Средний цвет по сетке w×h внутри прямоугольника.
Uint8List _sample(img.Image im, double x0, double y0, double cw, double ch, int w, int h) {
  final out = Uint8List(w * h * 3);
  for (var gy = 0; gy < h; gy++) {
    for (var gx = 0; gx < w; gx++) {
      final sx0 = (x0 + gx * cw / w).floor().clamp(0, im.width - 1);
      final sx1 = (x0 + (gx + 1) * cw / w).ceil().clamp(sx0 + 1, im.width);
      final sy0 = (y0 + gy * ch / h).floor().clamp(0, im.height - 1);
      final sy1 = (y0 + (gy + 1) * ch / h).ceil().clamp(sy0 + 1, im.height);
      var r = 0, g = 0, b = 0, n = 0;
      final stepX = math.max(1, (sx1 - sx0) ~/ 6), stepY = math.max(1, (sy1 - sy0) ~/ 6);
      for (var y = sy0; y < sy1; y += stepY) {
        for (var x = sx0; x < sx1; x += stepX) {
          final p = im.getPixel(x, y);
          r += p.r.toInt();
          g += p.g.toInt();
          b += p.b.toInt();
          n++;
        }
      }
      final o = (gy * w + gx) * 3;
      out[o] = r ~/ math.max(n, 1);
      out[o + 1] = g ~/ math.max(n, 1);
      out[o + 2] = b ~/ math.max(n, 1);
    }
  }
  return out;
}

double _std(Uint8List v) {
  var m = 0.0;
  for (final x in v) {
    m += x;
  }
  m /= v.length;
  var s = 0.0;
  for (final x in v) {
    s += (x - m) * (x - m);
  }
  return math.sqrt(s / v.length);
}

Float32List _norm(Uint8List v) {
  // Общая нормализация яркости и контраста (цвет между каналами сохраняется).
  var m = 0.0;
  for (final x in v) {
    m += x;
  }
  m /= v.length;
  var s = 0.0;
  for (final x in v) {
    s += (x - m) * (x - m);
  }
  s = math.sqrt(s / v.length);
  if (s < 1) s = 1;
  final out = Float32List(v.length);
  for (var i = 0; i < v.length; i++) {
    out[i] = (v[i] - m) / s;
  }
  return out;
}
