import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycp_store/src/ui/widgets/product_art.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget art, Size size) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: size.width, height: size.height, child: art),
        ),
      ),
    );
  }

  group('ProductArtFallback', () {
    testWidgets('a card-sized tile names the product', (tester) async {
      await pump(
        tester,
        const ProductArtFallback(name: 'Google Play Gift Card'),
        const Size(300, 225),
      );

      expect(find.text('Google Play Gift Card'), findsOneWidget);
      expect(find.byIcon(Icons.sports_esports_outlined), findsNothing);
    });

    testWidgets('a thumbnail falls back to the icon', (tester) async {
      await pump(
        tester,
        const ProductArtFallback(name: 'Google Play Gift Card'),
        const Size(50, 50),
      );

      expect(find.text('Google Play Gift Card'), findsNothing);
      expect(find.byIcon(Icons.sports_esports_outlined), findsOneWidget);
    });

    testWidgets('no name still renders something', (tester) async {
      await pump(tester, const ProductArtFallback(), const Size(300, 225));

      expect(find.byIcon(Icons.sports_esports_outlined), findsOneWidget);
    });
  });
}
