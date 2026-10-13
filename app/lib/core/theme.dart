import 'package:flutter/material.dart';

const kBrand = Color(0xFF1B6EF3);
const kGreen = Color(0xFF16A34A);
const kRed = Color(0xFFDC2626);
const kAmber = Color(0xFFD97706);
const kSlate = Color(0xFF64748B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kBrand, brightness: Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF5F7FB),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Color(0xFF0F172A), elevation: 0, scrolledUnderElevation: 0.5),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0)))),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
  );
}
