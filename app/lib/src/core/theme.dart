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

  /// Muted text that still clears 4.5:1 on the raised surfaces. Use this for
  /// anything read on `ink800` or `ink700`; [ink400] fails there (4.36 and 3.65).
  static const ink300 = Color(0xFF93A0BA);

  /// Decor only. Clears 4.5:1 on `ink950` and `ink900`, but drops to 4.36 on
  /// `ink800` and 3.65 on `ink700`, so it must never carry text on a raised
  /// surface. Reach for [ink300] there instead.
  static const ink400 = Color(0xFF7B88A4);
  static const ink200 = Color(0xFFC3CBE0);

  static const brand = Color(0xFF5B7CFF);
  static const brandDark = Color(0xFF2A44C9);
  static const accent = Color(0xFF2BD98A);
  static const danger = Color(0xFFFF4D6D);
  static const warn = Color(0xFFFFB020);

  /// Foreground for anything painted *on* [brand]. White only reaches 3.64:1
  /// there, which fails AA for every button label in the app; the dark ink
  /// reaches 5.26:1 and keeps the brand fill exactly as designed.
  static const onBrand = ink950;

  /// Neon layer. Used for glows, gradients and highlights, never for body text
  /// on its own: these are bright enough to vibrate against the dark base.
  /// Violet is one step lighter than the original `#8B5CF6` so it also clears
  /// AA when it does end up as text on a raised surface (4.93 on `ink800`).
  static const violet = Color(0xFF9B7BFF);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFFF4D9D);

  /// The two-stop ramp most glows and gradient tiles are built from.
  static const gradient = [brand, violet];
}

/// One layout scale, so a page never invents its own magic width. Every
/// responsive decision in the app reads from here.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Narrow phones. Below this, stack and drop secondary chrome.
  static const phone = 600.0;

  /// Large phones and small tablets.
  static const tablet = 700.0;

  /// The width at which the desktop chrome (top-bar links, inline search,
  /// side-by-side checkout) takes over from the bottom tabs.
  static const wide = 900.0;

  /// Full desktop. Wider gutters, wider grids.
  static const expanded = 1200.0;

  static bool isPhone(double width) => width < phone;
  static bool isWide(double width) => width >= wide;

  /// Column count from the width a tile actually wants, rather than a magic
  /// breakpoint. Clamped so a grid never collapses to one huge tile.
  static int columnsFor({
    required double width,
    required double minTile,
    int max = 4,
    int min = 1,
    double spacing = 0,
  }) {
    if (width <= 0 || minTile <= 0) return min;
    final fits = ((width + spacing) / (minTile + spacing)).floor();
    return fits.clamp(min, max);
  }
}

/// One spacing scale. Cards, sections and stacks step through this, so vertical
/// rhythm is consistent instead of hand-tuned per widget.
class AppSpace {
  const AppSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const huge = 48.0;
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

/// Named text styles for the sizes the app actually uses.
///
/// Each one takes its line height from the theme's locale-tuned text style, so
/// no call site has to hardcode `height:` — which is how Khmer stacked vowels
/// and ascenders were being clipped in 15 files. Prefer these over a raw
/// `TextStyle`; reach for `Theme.of(context).textTheme` when a headline size is
/// genuinely needed.
class AppType {
  const AppType._();

  /// Smallest readable step. Table stamps, counts, captions.
  static TextStyle caption(BuildContext context) =>
      _of(context, 11.5, FontWeight.w500, AppColors.ink300);

  /// Field labels, chips, dense table headers.
  static TextStyle label(BuildContext context) =>
      _of(context, 12.5, FontWeight.w600, AppColors.ink300);

  /// Secondary copy that still has to be read.
  static TextStyle bodySmall(BuildContext context) =>
      _of(context, 13, FontWeight.w400, AppColors.ink200);

  /// Default paragraph copy.
  static TextStyle body(BuildContext context) =>
      _of(context, 14, FontWeight.w400, AppColors.ink200);

  /// Emphasised body, for the value side of a label/value pair.
  static TextStyle bodyStrong(BuildContext context) =>
      _of(context, 14, FontWeight.w600, Colors.white);

  /// Card and row titles.
  static TextStyle title(BuildContext context) =>
      _of(context, 16, FontWeight.w700, Colors.white);

  static TextStyle _of(
    BuildContext context,
    double size,
    FontWeight weight,
    Color color,
  ) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(fontSize: size, fontWeight: weight, color: color);
  }
}

class AppTheme {
  const AppTheme._();

  /// Khmer stacks vowels above and below the base glyph and carries tall
  /// ascenders, so it needs a visibly looser line box than Latin at the same
  /// point size. Everything that sets a line height goes through here.
  ///
  /// 0.4 puts the tightest style (a 40px display line, 1.1 in Latin) at 1.5,
  /// which is the floor `theme_tokens_test.dart` enforces. Small body sizes end
  /// up near 1.8, where the stacked vowels need the most relative room.
  static double lineHeight(bool isKhmer, double latin) =>
      isKhmer ? latin + 0.4 : latin;

  static ThemeData build(Locale locale) {
    final isKhmer = locale.languageCode == 'km';
    final base = ThemeData.dark(useMaterial3: true);

    // Headings on Khmer must not be tracked in: negative letter spacing pulls
    // stacked vowels into each other.
    final track = isKhmer ? 0.0 : 1.0;

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
        height: lineHeight(isKhmer, 1.1),
        letterSpacing: -1.2 * track,
        color: Colors.white,
      ),
      displayMedium: headingFont(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: lineHeight(isKhmer, 1.15),
        letterSpacing: -0.9 * track,
        color: Colors.white,
      ),
      displaySmall: headingFont(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: lineHeight(isKhmer, 1.2),
        letterSpacing: -0.6 * track,
        color: Colors.white,
      ),
      headlineMedium: headingFont(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: lineHeight(isKhmer, 1.25),
        letterSpacing: -0.4 * track,
        color: Colors.white,
      ),
      headlineSmall: headingFont(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: lineHeight(isKhmer, 1.3),
        letterSpacing: -0.3 * track,
        color: Colors.white,
      ),
      titleLarge: headingFont(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: lineHeight(isKhmer, 1.35),
        letterSpacing: -0.2 * track,
        color: Colors.white,
      ),
      titleMedium: headingFont(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: lineHeight(isKhmer, 1.35),
        color: Colors.white,
      ),
      // Body also needs the looser box: these carry the long Khmer strings in
      // lists, tables and notes where a clipped vowel is easiest to hit.
      bodyLarge: tightened.bodyLarge?.copyWith(
        height: lineHeight(isKhmer, 1.4),
      ),
      bodyMedium: tightened.bodyMedium?.copyWith(
        height: lineHeight(isKhmer, 1.4),
      ),
      bodySmall: tightened.bodySmall?.copyWith(
        height: lineHeight(isKhmer, 1.4),
      ),
      labelLarge: tightened.labelLarge?.copyWith(
        height: lineHeight(isKhmer, 1.35),
      ),
      labelMedium: tightened.labelMedium?.copyWith(
        height: lineHeight(isKhmer, 1.35),
      ),
    );

    return base.copyWith(
      textTheme: displayTheme,
      scaffoldBackgroundColor: AppColors.ink950,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brand,
        onPrimary: AppColors.onBrand,
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
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: AppColors.ink700,
          disabledForegroundColor: AppColors.ink300,
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
