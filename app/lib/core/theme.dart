import 'package:flutter/material.dart';

// Modern, high-craft executive palette
const kBrand = Color(0xFF2563EB); // Vibrant Royal Indigo
const kBrandLight = Color(0xFFEFF6FF); // Soft blue tint
const kGreen = Color(0xFF10B981); // Emerald Green for Present / Success
const kGreenLight = Color(0xFFECFDF5);
const kRed = Color(0xFFEF4444); // Crimson Rose for Absent / Danger
const kRedLight = Color(0xFFFEF2F2);
const kAmber = Color(0xFFF59E0B); // Amber for Partial / Warning
const kAmberLight = Color(0xFFFFFBEB);
const kSlate = Color(0xFF64748B); // Slate Muted
const kSlateDark = Color(0xFF0F172A); // Dark Slate Primary text
const kSlateLight = Color(0xFFF8FAFC); // Card background secondary
const kBorder = Color(0xFFE2E8F0); // Subtle crisp border

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
    surface: Colors.white,
    primary: kBrand,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kSlateDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kSlateDark, letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBrand, width: 1.8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 3,
      indicatorColor: kBrandLight,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSlateDark)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kBrand);
        }
        return const IconThemeData(color: kSlate);
      }),
    ),
  );
}

