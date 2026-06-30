import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CreateCart Admin palette — a clean, professional SaaS console look
/// (indigo primary on a soft slate canvas). Deliberately neutral so it sits
/// above any single tenant's brand.
class Ui {
  static const indigo = Color(0xFF4F46E5);
  static const indigoDark = Color(0xFF3730A3);
  static const night = Color(0xFF0B1020); // splash / dark headers
  static const canvas = Color(0xFFF5F6FB);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE6E8F0);
  static const fieldFill = Color(0xFFF8FAFC);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const warn = Color(0xFFD97706);
  static const warnBg = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFDBEAFE);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Ui.indigo,
    primary: Ui.indigo,
    secondary: Ui.indigoDark,
    surface: Ui.surface,
    brightness: Brightness.light,
  );

  final body = GoogleFonts.plusJakartaSansTextTheme();
  final display = GoogleFonts.spaceGroteskTextTheme();

  final text = body.copyWith(
    displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w700, color: Ui.ink),
    headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: Ui.ink),
    titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Ui.ink),
    titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Ui.ink),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ui.canvas,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Ui.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Ui.ink,
      titleTextStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700, fontSize: 20, color: Ui.ink),
    ),
    cardTheme: CardThemeData(
      color: Ui.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Ui.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Ui.indigo,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        minimumSize: const Size(0, 50),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Ui.inkSoft,
        side: const BorderSide(color: Ui.border),
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(0, 50),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Ui.surface,
      indicatorColor: const Color(0xFFE0E7FF),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Ui.fieldFill,
      hintStyle: const TextStyle(color: Ui.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Ui.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Ui.indigo, width: 1.6)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Ui.danger)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Ui.ink,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: Ui.border, thickness: 1, space: 1),
  );
}

String rupees(num v) => '₹${v.toStringAsFixed(0)}';
