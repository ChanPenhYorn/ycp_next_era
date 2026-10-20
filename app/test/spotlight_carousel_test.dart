import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/features/catalog/domain/catalog_entities.dart';
import 'package:ycp_store/src/ui/widgets/home_bento.dart';

ProductCard _game(int id, String name) => ProductCard(
  id: id,
  slug: 'game-$id',
  nameKm: name,
  nameEn: name,
  imageUrl: null,
  kind: ProductKind.autoTopup,
  ratingAvg: 0,
  ratingCount: 0,
  soldCount: 0,
  minPriceUsd: 1,
  maxPriceUsd: 1,
  compareAtPriceUsd: null,
  totalStock: null,
);

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: AppL10n.localizationsDelegates,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

/// The spotlight panel showed `items.first` forever, so a store with a dozen
/// games looked like it sold one. It rotates now; these pin the two ways that
/// can go wrong: never advancing, and advancing when the platform asked for
/// reduced motion.
void main() {
  final games = [
    _game(1, 'Game One'),
    _game(2, 'Game Two'),
    _game(3, 'Game Three'),
  ];

  testWidgets('the spotlight advances to the next game on its own', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(SpotlightCarousel(products: games)));

    expect(find.text('Game One'), findsOneWidget);
    expect(find.text('Game Two'), findsNothing);

    // Dwell, then the slide animation itself.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Game Two'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe switches the game by hand', (tester) async {
    await tester.pumpWidget(_wrap(SpotlightCarousel(products: games)));

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();

    expect(find.text('Game Two'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion leaves the first game in place', (tester) async {
    await tester.pumpWidget(
      _wrap(SpotlightCarousel(products: games), reduceMotion: true),
    );

    await tester.pump(const Duration(seconds: 20));

    expect(find.text('Game One'), findsOneWidget);
    expect(find.text('Game Two'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a single game gets no dots and does not advance', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(SpotlightCarousel(products: [games.first])));

    await tester.pump(const Duration(seconds: 20));

    expect(find.text('Game One'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
