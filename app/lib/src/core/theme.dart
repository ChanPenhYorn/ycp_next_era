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

/// One radius scale, so cards, inputs and buttons read as one family.
class AppRadius {
  const AppRadius._();

  static const hero = 22.0;
  static const card = 18.0;
  static const control = 14.0;
  static const tile = 12.0;
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
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.ink900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.ink800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ink900,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.ink800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.ink800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.ink400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ink700,
          disabledForegroundColor: AppColors.ink400,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.ink700),
          foregroundColor: AppColors.ink200,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.ink900,
        surfaceTintColor: Colors.transparent,
        height: 68,
        indicatorColor: AppColors.brand.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.ink400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : AppColors.ink400,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.ink850,
        selectedColor: AppColors.brand.withValues(alpha: 0.2),
        checkmarkColor: AppColors.brand,
        side: const BorderSide(color: AppColors.ink700),
        labelStyle: const TextStyle(color: AppColors.ink200, fontSize: 12),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.ink800, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink800,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[],
    );
  }
}
