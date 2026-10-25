import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/features/catalog/domain/catalog_entities.dart';
import 'package:ycp_store/src/features/catalog/domain/catalog_repository.dart';
import 'package:ycp_store/src/features/orders/domain/order_entities.dart';
import 'package:ycp_store/src/features/orders/domain/order_repository.dart';
import 'package:ycp_store/src/features/profile/domain/profile.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/checkout_page.dart';

/// The tiles follow `settings`, not a compile-time choice. Retiring ABA or
/// launching cards is a settings change, and the checkout must not keep
/// drawing a rail the store switched off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpCheckout(
    WidgetTester tester, {
    required bool dodo,
    required bool khqr,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        currentUserProvider.overrideWithValue(null),
        profileProvider.overrideWith(
          (ref) async => const Profile(
            id: 'buyer',
            walletBalance: 0,
            coins: 0,
            displayName: 'Buyer',
          ),
        ),
        settingsProvider.overrideWith(
          (ref) async => PublicSettings(
            siteName: 'Chanpenh',
            usdToKhr: 4100,
            orderTtlMinutes: 15,
            dodoEnabled: dodo,
            khqrEnabled: khqr,
          ),
        ),
        catalogRepositoryProvider.overrideWithValue(_FakeCatalogue()),
        orderRepositoryProvider.overrideWithValue(_FakeOrders()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(cartControllerProvider.notifier)
        .add(
          variantId: 7,
          productSlug: 'mobile-legends',
          productName: 'Mobile Legends',
          variantLabel: '100 Diamonds',
          unitPriceUsd: 1.5,
          minQty: 1,
          maxQty: 5,
        );

    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const Scaffold(body: CheckoutPage()),
        ),
        GoRoute(
          path: '/wallet',
          builder: (context, state) => const Text('wallet'),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('en'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cards and KHQR both show when both are enabled', (tester) async {
    await pumpCheckout(tester, dodo: true, khqr: true);

    expect(find.text('Pay with ABA KHQR'), findsOneWidget);
    expect(find.text('Pay by card'), findsOneWidget);
  });

  testWidgets('retiring ABA leaves the card option in its place', (
    tester,
  ) async {
    await pumpCheckout(tester, dodo: true, khqr: false);

    expect(find.text('Pay with ABA KHQR'), findsNothing);
    expect(find.text('Pay by card'), findsOneWidget);
    expect(find.textContaining('Pay by card ·'), findsOneWidget);
  });

  testWidgets('a card-only store does not fall back to a hidden QR', (
    tester,
  ) async {
    await pumpCheckout(tester, dodo: true, khqr: false);

    await tester.tap(find.text('Pay from wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay by card'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pay by card ·'), findsOneWidget);
  });

  testWidgets('no rail at all shows a wallet-only checkout', (tester) async {
    await pumpCheckout(tester, dodo: false, khqr: false);

    expect(find.text('Pay with ABA KHQR'), findsNothing);
    expect(find.text('Pay by card'), findsNothing);
    expect(find.text('Pay from wallet'), findsOneWidget);
  });
}

class _FakeOrders implements OrderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCatalogue implements CatalogRepository {
  @override
  Future<Map<int, LiveVariant>> liveVariants(List<int> variantIds) async => {
    7: const LiveVariant(id: 7, sku: 'MLBB_100', minQty: 1, maxQty: 5),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
