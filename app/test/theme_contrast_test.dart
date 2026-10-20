import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycp_store/src/core/theme.dart';

/// WCAG 2.1 relative luminance for an opaque colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio. Must reach 4.5 for normal text, 3.0 for large.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Surfaces that actually carry text, darkest to lightest.
const _surfaces = <Color>[
  AppColors.ink950,
  AppColors.ink900,
  AppColors.ink850,
  AppColors.ink800,
  AppColors.ink700,
];

void main() {
  group('text tokens on every surface they are used on', () {
    test('ink200 clears AA everywhere', () {
      for (final surface in _surfaces) {
        expect(
          _contrast(AppColors.ink200, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'ink200 on $surface',
        );
      }
    });

    test('ink300, the muted step, clears AA everywhere', () {
      for (final surface in _surfaces) {
        expect(
          _contrast(AppColors.ink300, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'ink300 on $surface',
        );
      }
    });

    test('ink400 stays decor-only, as documented', () {
      // It is fine on the flat background...
      expect(
        _contrast(AppColors.ink400, AppColors.ink950),
        greaterThanOrEqualTo(4.5),
      );
      // ...and this is why it must not carry text on a raised surface. If a
      // future palette change makes ink400 pass here, move this assertion and
      // delete the warning on AppColors.ink400 rather than leaving it stale.
      expect(_contrast(AppColors.ink400, AppColors.ink700), lessThan(4.5));
    });
  });

  group('theme', () {
    test('the primary button label clears AA on its own fill', () {
      for (final locale in [const Locale('km'), const Locale('en')]) {
        final style = AppTheme.build(locale).filledButtonTheme.style!;
        final fg = style.foregroundColor!.resolve(<WidgetState>{})!;
        final bg = style.backgroundColor!.resolve(<WidgetState>{})!;

        expect(
          _contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'filled button label in $locale',
        );
      }
    });

    test('the disabled button label clears AA on its fill', () {
      final style = AppTheme.build(const Locale('en')).filledButtonTheme.style!;
      final fg = style.foregroundColor!.resolve({WidgetState.disabled})!;
      final bg = style.backgroundColor!.resolve({WidgetState.disabled})!;

      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });

    test('colourScheme.onPrimary matches the button foreground', () {
      expect(
        AppTheme.build(const Locale('en')).colorScheme.onPrimary,
        AppColors.onBrand,
      );
    });
  });
}
