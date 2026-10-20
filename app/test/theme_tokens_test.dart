import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:ycp_store/src/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the fonts are in the bundle, not fetched at runtime', () {
    // google_fonts resolves a family+weight by looking for an asset whose path
    // ends with `<Family>-<Weight>`, so these names are load-bearing.
    const expected = <String>[
      'NotoSansKhmer-Regular',
      'NotoSansKhmer-Medium',
      'NotoSansKhmer-SemiBold',
      'NotoSansKhmer-Bold',
      'NotoSansKhmer-ExtraBold',
      'Inter-Regular',
      'Inter-Medium',
      'Inter-SemiBold',
      'Inter-Bold',
      'Inter-ExtraBold',
      'SpaceGrotesk-Bold',
    ];

    test(
      'every asset the theme needs is resolvable through rootBundle',
      () async {
        for (final name in expected) {
          final key = 'assets/google_fonts/$name.ttf';
          final data = await rootBundle.load(key);
          expect(
            data.lengthInBytes,
            greaterThan(1000),
            reason: '$key is bundled but empty',
          );
        }
      },
    );

    test('the files are on disk with matching names', () {
      for (final name in expected) {
        final file = File('assets/google_fonts/$name.ttf');
        expect(file.existsSync(), isTrue, reason: '$name.ttf is missing');
      }
    });

    test('no more than 2 MB of fonts ship', () {
      final dir = Directory('assets/google_fonts');
      final bytes = dir.listSync().whereType<File>().fold<int>(
        0,
        (sum, f) => sum + f.lengthSync(),
      );

      expect(bytes, lessThan(2 * 1024 * 1024));
    });
  });

  group('Khmer gets a looser line box than Latin', () {
    test('lineHeight adds to the Khmer box', () {
      expect(AppTheme.lineHeight(true, 1.4), greaterThan(1.4));
      expect(AppTheme.lineHeight(false, 1.4), 1.4);
      expect(
        AppTheme.lineHeight(true, 1.4),
        greaterThan(AppTheme.lineHeight(false, 1.4)),
      );
    });

    test('every style in the Khmer theme has a roomy height', () {
      final km = AppTheme.build(const Locale('km')).textTheme;
      final styles = <String, TextStyle?>{
        'displayLarge': km.displayLarge,
        'displayMedium': km.displayMedium,
        'displaySmall': km.displaySmall,
        'headlineMedium': km.headlineMedium,
        'headlineSmall': km.headlineSmall,
        'titleLarge': km.titleLarge,
        'titleMedium': km.titleMedium,
        'bodyLarge': km.bodyLarge,
        'bodyMedium': km.bodyMedium,
        'bodySmall': km.bodySmall,
        'labelLarge': km.labelLarge,
        'labelMedium': km.labelMedium,
      };

      for (final entry in styles.entries) {
        expect(
          entry.value?.height,
          isNotNull,
          reason: '${entry.key} has no line height in km',
        );
        expect(
          entry.value!.height,
          greaterThanOrEqualTo(1.5),
          reason: '${entry.key} is too tight for Khmer',
        );
      }
    });

    test('the Latin theme is tighter than the Khmer one', () {
      final km = AppTheme.build(const Locale('km')).textTheme;
      final en = AppTheme.build(const Locale('en')).textTheme;
      expect(en.displaySmall!.height!, lessThan(km.displaySmall!.height!));
      expect(en.bodyMedium!.height!, lessThan(km.bodyMedium!.height!));
    });

    test('Khmer headings are never tracked in', () {
      final km = AppTheme.build(const Locale('km')).textTheme;
      for (final style in [
        km.displayLarge,
        km.displayMedium,
        km.displaySmall,
        km.headlineMedium,
        km.headlineSmall,
        km.titleLarge,
      ]) {
        final spacing = style!.letterSpacing;
        expect(
          spacing == null || spacing >= 0,
          isTrue,
          reason: 'negative tracking overlaps Khmer clusters',
        );
      }
    });
  });

  group('layout tokens', () {
    test('breakpoints are ordered and distinct', () {
      expect(AppBreakpoints.phone, lessThan(AppBreakpoints.tablet));
      expect(AppBreakpoints.tablet, lessThan(AppBreakpoints.wide));
      expect(AppBreakpoints.wide, lessThan(AppBreakpoints.expanded));
    });

    test('isWide matches the wide breakpoint', () {
      expect(AppBreakpoints.isWide(AppBreakpoints.wide), isTrue);
      expect(AppBreakpoints.isWide(AppBreakpoints.wide - 1), isFalse);
    });

    test('columnsFor derives a count instead of using a magic width', () {
      // Three 108 px tiles plus 12 px gaps need 348 px of content width.
      expect(
        AppBreakpoints.columnsFor(
          width: 348,
          minTile: 108,
          max: 6,
          spacing: 12,
        ),
        3,
      );
      expect(
        AppBreakpoints.columnsFor(
          width: 900,
          minTile: 108,
          max: 6,
          spacing: 12,
        ),
        6,
      );
      expect(
        AppBreakpoints.columnsFor(
          width: 120,
          minTile: 108,
          max: 6,
          spacing: 12,
        ),
        1,
      );
    });

    test('spacing steps increase', () {
      expect(AppSpace.xs, lessThan(AppSpace.sm));
      expect(AppSpace.sm, lessThan(AppSpace.md));
      expect(AppSpace.md, lessThan(AppSpace.lg));
      expect(AppSpace.lg, lessThan(AppSpace.xl));
      expect(AppSpace.xl, lessThan(AppSpace.xxl));
      expect(AppSpace.xxl, lessThan(AppSpace.huge));
    });
  });

  group('guardrail: the UI does not re-tighten Khmer line boxes', () {
    test('no inline line height below 1.4 in lib/src/ui', () {
      // The theme sets a locale-aware line box. An inline `height:` below 1.4 is
      // what clipped Khmer stacked vowels in 15 files, so it is banned outright:
      // drop the override and inherit from the theme, or raise it above the
      // Khmer floor.
      final pattern = RegExp(r'height:\s*([01]\.\d{1,3})\s*[,)]');
      final offenders = <String>[];

      final files = Directory('lib/src/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final match = pattern.firstMatch(lines[i]);
          if (match == null) continue;
          if (double.parse(match.group(1)!) < 1.4) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these line heights clip Khmer: ${offenders.join(', ')}',
      );
    });
  });
}
