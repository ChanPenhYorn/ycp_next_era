import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/core/format.dart';
import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/features/orders/data/order_mappers.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/widgets/home_bento.dart';
import 'package:ycp_store/src/ui/widgets/home_sections.dart';
import 'package:ycp_store/src/ui/widgets/product_card.dart';
import 'package:ycp_store/src/ui/widgets/skeleton.dart';

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

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
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
Future<void> _at320(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(child, locale: locale));
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
        await _at320(tester, const HomeIntroBand());

        expect(find.text('Automatic delivery'), findsOneWidget);
        expect(find.text('Pay with ABA KHQR'), findsOneWidget);
        expect(find.text('Support on Telegram'), findsOneWidget);

        expect(find.textContaining('24/7'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('home motion', () {
    // Timed pumps, not pumpAndSettle: the ticker animates on an infinite loop, so
    // settling never happens. What matters here is that the band lays out at
    // 320px and paints its copy.
    testWidgets(
      'the intro band lays out at 320px with its promise and action',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(const HomeIntroBand()));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Automatic delivery'), findsOneWidget);
        expect(find.text('Top up your games in seconds'), findsOneWidget);
        expect(find.text('Browse games'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // 800px, not 320: the strip is a lazy list, so at phone width the second
    // rank is simply off-screen and never built.
    testWidgets('trending ticker ranks the real sellers', (tester) async {
      tester.view.physicalSize = const Size(800 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          TrendingTicker(products: [_card(soldCount: 5), _card(soldCount: 2)]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trending now'), findsOneWidget);
      // Two of each: the strip holds two copies of the list so the drift can
      // wrap without a visible seam.
      expect(find.text('#1'), findsNWidgets(2));
      expect(find.text('#2'), findsNWidgets(2));
      expect(find.textContaining('· 5'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('product grid', () {
    late SharedPreferences preferences;

    // A name long enough to wrap to two lines, plus a category and a sold
    // count, so the tile is laid out at its tallest.
    final longName = ProductCard(
      id: 2,
      slug: 'mlbb-exclusive',
      nameKm: 'ពេជ្រ Mobile Legends Exclusive',
      nameEn: 'Mobile Legends Exclusive',
      imageUrl: null,
      kind: ProductKind.instantStock,
      ratingAvg: 4.5,
      ratingCount: 12,
      soldCount: 671,
      minPriceUsd: 0.76,
      maxPriceUsd: 4.64,
      compareAtPriceUsd: 0.99,
      totalStock: 5,
    );

    final soldOut = ProductCard(
      id: 3,
      slug: 'gone',
      nameKm: 'អស់',
      nameEn: 'Gone',
      imageUrl: null,
      kind: ProductKind.instantStock,
      ratingAvg: 0,
      ratingCount: 0,
      soldCount: 0,
      minPriceUsd: 1,
      maxPriceUsd: 1,
      compareAtPriceUsd: null,
      totalStock: 0,
    );

    Widget grid(ProductCard card, double width) => ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 720,
            child: GridView.builder(
              gridDelegate: productGridDelegate,
              itemCount: 6,
              itemBuilder: (context, index) =>
                  ProductCardTile(product: card, index: index),
            ),
          ),
        ),
      ),
    );

    // The cell height cannot be a fixed ratio: the art tracks the column width
    // but the text under it does not, so every width is checked. Khmer is the
    // taller locale, which is why one grid has to satisfy both.
    for (final locale in ['en', 'km']) {
      for (final width in [320.0, 390.0, 480.0, 768.0, 1024.0, 1440.0]) {
        testWidgets('$locale tiles fit at ${width.toInt()}px', (tester) async {
          SharedPreferences.setMockInitialValues({'app_locale': locale});
          preferences = await SharedPreferences.getInstance();
          tester.view.physicalSize = Size(width * 2, 900 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(grid(longName, width));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // The cell must be exactly the art box plus the text block, or the
          // delegate and the tile have drifted apart.
          final tile = tester.getSize(find.byType(ProductCardTile).first);
          expect(
            tile.height,
            closeTo(
              (tile.width - 2) / kProductArtRatio + 2 + kProductTextBlockHeight,
              0.5,
            ),
          );

          // The name sits in an Expanded, so too little room clips it silently
          // instead of overflowing. Assert it really has its two lines.
          final name = locale == 'en' ? longName.nameEn : longName.nameKm;
          final nameBox = tester.getSize(find.text(name).first);
          expect(
            nameBox.height,
            greaterThanOrEqualTo(2 * 13.5 * 1.3 - 0.01),
            reason: 'a two-line name needs room at ${width.toInt()}px',
          );
          expect(find.text('\$0.76'), findsWidgets);
        });
      }
    }

    testWidgets('a sold-out tile fits too', (tester) async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      preferences = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(320 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(grid(soldOut, 320));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the loading skeleton fits at every width', (tester) async {
      // This is the skeleton that overflowed when the grid ratio was tightened.
      SharedPreferences.setMockInitialValues({'app_locale': 'km'});
      preferences = await SharedPreferences.getInstance();

      for (final width in [320.0, 480.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width * 2, 900 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: MaterialApp(
              supportedLocales: AppL10n.supportedLocales,
              localizationsDelegates: AppL10n.localizationsDelegates,
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  height: 720,
                  child: const ProductGridSkeleton(count: 6),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'skeleton at $width');
      }
    });
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
