import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark storefront palette, tuned so Khmer script stays legible: Khmer has tall
/// ascenders and stacked vowels, so line height is deliberately generous.
class AppColors {
  const AppColors._();

  static const ink950 = Color(0xFF0B0F19);
  static const ink900 = Color(0xFF101623);
  static const ink850 = Color(0xFF151C2C);
  static const ink800 = Color(0xFF1B2437);
  static const ink700 = Color(0xFF263149);
  static const ink400 = Color(0xFF7B88A4);
  static const ink200 = Color(0xFFC3CBE0);

  static const brand = Color(0xFF2F6BFF);
  static const brandDark = Color(0xFF1F52D6);
  static const accent = Color(0xFF17C07F);
  static const danger = Color(0xFFF0506B);
  static const warn = Color(0xFFF2A33C);
}

class AppTheme {
  const AppTheme._();

  static ThemeData build(Locale locale) {
    final isKhmer = locale.languageCode == 'km';
    final base = ThemeData.dark(useMaterial3: true);

    // Khmer needs a font that actually has the script; Inter/Noto for Latin.
    final textTheme = isKhmer
        ? GoogleFonts.notoSansKhmerTextTheme(base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink950,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brand,
        secondary: AppColors.accent,
        surface: AppColors.ink900,
        error: AppColors.danger,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.ink200,
        displayColor: Colors.white,
        fontSizeFactor: isKhmer ? 1.0 : 1.0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink950,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.ink900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.ink800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ink900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.ink800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.ink800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand),
        ),
        hintStyle: const TextStyle(color: AppColors.ink400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.ink700),
          foregroundColor: AppColors.ink200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.ink850,
        side: const BorderSide(color: AppColors.ink700),
        labelStyle: const TextStyle(color: AppColors.ink200, fontSize: 12),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.ink800, space: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink800,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      extensions: const <ThemeExtension<dynamic>>[],
    );
  }
}
