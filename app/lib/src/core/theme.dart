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

  static const brand = Color(0xFF5B7CFF);
  static const brandDark = Color(0xFF2A44C9);
  static const accent = Color(0xFF2BD98A);
  static const danger = Color(0xFFFF4D6D);
  static const warn = Color(0xFFFFB020);

  /// Neon layer. Used for glows, gradients and highlights, never for body text
  /// on its own: these are bright enough to vibrate against the dark base.
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFFF4D9D);

  /// The two-stop ramp most glows and gradient tiles are built from.
  static const gradient = [brand, violet];
}

/// One radius scale, so cards, inputs and buttons read as one family.
class AppRadius {
  const AppRadius._();

  static const hero = 24.0;
  static const card = 20.0;
  static const control = 16.0;
  static const tile = 14.0;

  /// Fully rounded. Buttons and chips use this on the neon theme.
  static const pill = 999.0;
}

/// Soft coloured light behind a surface. Kept in one place so every glow on the
/// site has the same falloff.
class AppGlow {
  const AppGlow._();

  static List<BoxShadow> of(
    Color color, {
    double strength = 0.35,
    double blur = 28,
    double spread = -6,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: strength),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 10),
    ),
  ];

  /// A tighter halo for small controls.
  static List<BoxShadow> tight(Color color) =>
      of(color, strength: 0.4, blur: 16, spread: -4);
}

/// Motion constants. Short and springy: nothing on this site should feel slow.
class AppMotion {
  const AppMotion._();

  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);

  static const ease = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
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

    // Headings get a display face: tighter, more designed. Body stays Inter
    // because it has to stay legible at 11px in tables and stamps.
    final headingFont = isKhmer
        ? GoogleFonts.notoSansKhmer
        : GoogleFonts.spaceGrotesk;

    final tightened = textTheme.apply(
      bodyColor: AppColors.ink200,
      displayColor: Colors.white,
    );

    final displayTheme = tightened.copyWith(
      displayLarge: headingFont(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -1.2,
        color: Colors.white,
      ),
      displayMedium: headingFont(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: -0.9,
        color: Colors.white,
      ),
      displaySmall: headingFont(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.6,
        color: Colors.white,
      ),
      headlineMedium: headingFont(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.4,
        color: Colors.white,
      ),
      headlineSmall: headingFont(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
        color: Colors.white,
      ),
      titleLarge: headingFont(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.2,
        color: Colors.white,
      ),
      titleMedium: headingFont(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: Colors.white,
      ),
    );

    return base.copyWith(
      textTheme: displayTheme,
      scaffoldBackgroundColor: AppColors.ink950,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brand,
        secondary: AppColors.accent,
        surface: AppColors.ink900,
        error: AppColors.danger,
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
          shadowColor: AppColors.brand.withValues(alpha: 0.55),
          elevation: 6,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.ink700),
          foregroundColor: AppColors.ink200,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: const StadiumBorder(),
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
