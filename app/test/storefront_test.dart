import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/core/format.dart';
import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/widgets/home_sections.dart';

ProductCard _card({
  double price = 10,
  double? compareAt,
  int totalStock = 5,
  int soldCount = 0,
}) => ProductCard(
  id: 1,
  slug: 'test',
  nameKm: 'Test',
  nameEn: 'Test',
  imageUrl: null,
  kind: ProductKind.instantStock,
  ratingAvg: 0,
  ratingCount: 0,
  soldCount: soldCount,
  minPriceUsd: price,
  maxPriceUsd: price,
  compareAtPriceUsd: compareAt,
  totalStock: totalStock,
);

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: AppL10n.localizationsDelegates,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

/// 320 CSS pixels is the narrowest width `implement.md` §5 names.
Future<void> _at320(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(child));
  await tester.pumpAndSettle();
}

void main() {
  group('order status', () {
    test('maps the refund_pending state added to the schema', () {
      expect(orderStatusFrom('refund_pending'), OrderStatus.refundPending);
    });

    test('keeps the known states', () {
      expect(orderStatusFrom('pending'), OrderStatus.pending);
      expect(orderStatusFrom('paid'), OrderStatus.paid);
      expect(orderStatusFrom('delivering'), OrderStatus.delivering);
      expect(orderStatusFrom('delivered'), OrderStatus.delivered);
      expect(orderStatusFrom('failed'), OrderStatus.failed);
      expect(orderStatusFrom('refunded'), OrderStatus.refunded);
      expect(orderStatusFrom('expired'), OrderStatus.expired);
    });

    test('falls back to pending rather than inventing a state', () {
      // An unknown value would otherwise read as a state the buyer is in.
      expect(orderStatusFrom('mystery'), OrderStatus.pending);
      expect(orderStatusFrom(''), OrderStatus.pending);
    });
  });

  group('promotions', () {
    test(
      'a discount only counts when the compare price is genuinely higher',
      () {
        expect(discountPercent(10, 12), 17);
        expect(discountPercent(10, 10), isNull);
        expect(discountPercent(10, 8), isNull);
        expect(discountPercent(10, null), isNull);
      },
    );

    test('never promotes a product with no real reduction', () {
      expect(isPromoted(_card(price: 10)), isFalse);
      expect(isPromoted(_card(price: 10, compareAt: 10)), isFalse);
      expect(isPromoted(_card(price: 10, compareAt: 12)), isTrue);
    });

    test('never promotes a sold-out product', () {
      expect(
        isPromoted(_card(price: 10, compareAt: 12, totalStock: 0)),
        isFalse,
      );
    });
  });

  group('counts', () {
    test('compacts large numbers for the card footer', () {
      expect(compactCount(42), '42');
      expect(compactCount(1500), '1.5K');
      expect(compactCount(2400000), '2.4M');
    });
  });

  group('product query', () {
    test('is value-based so Riverpod caches each filter once', () {
      const a = ProductQuery(search: 'mlbb', popularFirst: true);
      const b = ProductQuery(search: 'mlbb', popularFirst: true);
      const c = ProductQuery(search: 'mlbb');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('how it works', () {
    testWidgets('shows exactly the three documented steps at 320px', (
      tester,
    ) async {
      await _at320(tester, const HowItWorksSection());

      expect(find.text('Choose your game and package'), findsOneWidget);
      expect(find.text('Enter your player ID'), findsOneWidget);
      expect(find.text('Pay and track your top-up'), findsOneWidget);

      // The section must state the rule as well: never a password.
      expect(find.textContaining('Never your password.'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('trust and support', () {
    testWidgets('shows no dead button when support is not configured', (
      tester,
    ) async {
      await _at320(
        tester,
        const TrustAndSupportSection(settings: PublicSettings.fallback),
      );

      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Refunds'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps both contact buttons at 320px', (tester) async {
      const settings = PublicSettings(
        siteName: 'Chanpenh',
        usdToKhr: 4100,
        orderTtlMinutes: 15,
        supportTelegram: 'https://t.me/example',
        supportEmail: 'help@example.test',
      );

      await _at320(tester, const TrustAndSupportSection(settings: settings));

      expect(find.byType(OutlinedButton), findsNWidgets(2));
      expect(find.text('Contact support'), findsOneWidget);

      // Two full-width buttons side by side is the classic 320px overflow.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'never advertises a support hours claim the store has not made',
      (tester) async {
        await _at320(tester, const TrustRow());

        expect(find.text('Automatic delivery'), findsOneWidget);
        expect(find.text('Pay with ABA KHQR'), findsOneWidget);
        expect(find.text('Support on Telegram'), findsOneWidget);

        expect(find.textContaining('24/7'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('localisation', () {
    test('the two locales carry the same keys', () {
      final en =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final km =
          jsonDecode(File('lib/l10n/app_km.arb').readAsStringSync())
              as Map<String, dynamic>;

      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final kmKeys = km.keys.where((k) => !k.startsWith('@')).toSet();

      expect(
        kmKeys.difference(enKeys),
        isEmpty,
        reason: 'app_km.arb is missing keys the English template has',
      );
      expect(
        enKeys.difference(kmKeys),
        isEmpty,
        reason: 'app_en.arb is missing keys the Khmer file has',
      );
    });

    test('the navigation the spec names exists in both languages', () {
      final en =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final km =
          jsonDecode(File('lib/l10n/app_km.arb').readAsStringSync())
              as Map<String, dynamic>;

      expect(en['navHome'], 'Home');
      expect(km['navHome'], 'ទំព័រដើម');
      expect(en['navGames'], 'Games');
      expect(km['navGames'], 'ហ្គេម');
      expect(en['searchGames'], 'Search games...');
      expect(km['searchGames'], 'ស្វែងរកហ្គេម...');
      expect(en['contactSupport'], 'Contact support');
      expect(km['contactSupport'], 'ទាក់ទងជំនួយ');
    });

    test('no locale still claims 24/7', () {
      for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_km.arb']) {
        final text = File(path).readAsStringSync();
        expect(
          text,
          isNot(contains('24/7')),
          reason: '$path carries an availability claim the store has not made',
        );
      }
    });
  });
}
