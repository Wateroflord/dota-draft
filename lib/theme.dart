import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Тёмный плоский стиль: почти чёрный фон, графитовые панели, красный акцент.
class C {
  /// Тёмная тема (по умолчанию) или светлая.
  static bool dark = true;

  static Color get bg => dark ? const Color(0xFF0B0B0D) : const Color(0xFFF4F4F6);
  static Color get surface => dark ? const Color(0xFF131416) : const Color(0xFFFFFFFF);
  static Color get surface2 => dark ? const Color(0xFF1A1A1E) : const Color(0xFFECECEF);
  static Color get border => dark ? const Color(0xFF26272B) : const Color(0xFFD9D9DE);
  static Color get text => dark ? const Color(0xFFEDEDEF) : const Color(0xFF16171A);
  static Color get muted => dark ? const Color(0xFF7A7D82) : const Color(0xFF6A6D73);
  static const accent = Color(0xFFCE3535);
  static Color get accent2 => dark ? const Color(0xFFAFB3BA) : const Color(0xFF5A5E66);

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

  static TextStyle num(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color ?? C.text, fontFeatures: tab, letterSpacing: -0.3, height: 1.1);

  static TextStyle get label => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: C.muted);
  static TextStyle get section => TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text);
  static TextStyle get h1 => TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: C.text);
  static TextStyle get h2 => TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: C.text);
  static TextStyle get body => TextStyle(fontSize: 14, color: C.text, height: 1.35);
  static TextStyle get small => TextStyle(fontSize: 12, color: C.muted, height: 1.3);
}

ThemeData buildTheme() {
  final scheme = C.dark
      ? ColorScheme.dark(
          primary: C.accent, onPrimary: Colors.white, secondary: C.accent2, surface: C.surface, onSurface: C.text, error: C.enemy)
      : ColorScheme.light(
          primary: C.accent, onPrimary: Colors.white, secondary: C.accent2, surface: C.surface, onSurface: C.text, error: C.enemy);
  final base = ThemeData(
    brightness: C.dark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    colorScheme: scheme,
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
    hintStyle: TextStyle(color: C.muted, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: b(C.border),
    enabledBorder: b(C.border),
    focusedBorder: b(C.accent, 1.4),
  );
}
