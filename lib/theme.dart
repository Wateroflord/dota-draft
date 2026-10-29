import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Тёмный плоский стиль: почти чёрный фон, графитовые панели, красный акцент.
class C {
  static const bg = Color(0xFF0B0B0D);
  static const surface = Color(0xFF131416);
  static const surface2 = Color(0xFF1A1A1E);
  static const border = Color(0xFF26272B);
  static const text = Color(0xFFEDEDEF);
  static const muted = Color(0xFF7A7D82);
  static const accent = Color(0xFFCE3535);
  static const accent2 = Color(0xFFAFB3BA);

  static const ally = Color(0xFF3DD68C); // моя команда
  static const enemy = Color(0xFFFF5C7A); // противники
  static const gold = Color(0xFFF2B14C);

  static const str = Color(0xFFE5533D);
  static const agi = Color(0xFF3DD68C);
  static const intel = Color(0xFF5B9DFF);
  static const uni = Color(0xFFC79BFF);

  static Color attr(String a) => switch (a) {
        'str' => str,
        'agi' => agi,
        'int' => intel,
        _ => uni,
      };
}

class T {
  static const tab = [FontFeature.tabularFigures()];

  static TextStyle num(double size, {Color color = C.text, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color, fontFeatures: tab, letterSpacing: -0.3, height: 1.1);

  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: C.muted);
  static const section = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text);
  static const h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: C.text);
  static const h2 = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: C.text);
  static const body = TextStyle(fontSize: 14, color: C.text, height: 1.35);
  static const small = TextStyle(fontSize: 12, color: C.muted, height: 1.3);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: Colors.white,
      secondary: C.accent2,
      surface: C.surface,
      onSurface: C.text,
      error: C.enemy,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    dividerColor: C.border,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.accent, selectionHandleColor: C.accent),
  );
}

InputDecoration fieldDeco(String hint, {IconData? icon}) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: C.surface2,
    prefixIcon: icon == null ? null : Icon(icon, color: C.muted, size: 20),
    hintStyle: const TextStyle(color: C.muted, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: b(C.border),
    enabledBorder: b(C.border),
    focusedBorder: b(C.accent, 1.4),
  );
}
