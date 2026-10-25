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

/// A completed checkout must empty the cart. It used to be cleared only when
/// the payment was confirmed, so an order whose QR was closed, expired or paid
/// late left every line in the cart: the buyer saw a full cart after buying,
/// and checking out again created a second order for the same items.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the cart is emptied once the order exists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final orders = _FakeOrders();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        catalogRepositoryProvider.overrideWithValue(_FakeCatalogue()),
        orderRepositoryProvider.overrideWithValue(orders),
        currentUserProvider.overrideWithValue(null),
        profileProvider.overrideWith(
          (ref) async => const Profile(
            id: 'buyer',
            walletBalance: 100,
            coins: 0,
            displayName: 'Buyer',
          ),
        ),
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
    expect(container.read(cartControllerProvider), isNotEmpty);

    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const Scaffold(body: CheckoutPage()),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) => const Text('order-page'),
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

    await tester.ensureVisible(find.text('Pay from wallet'));
    await tester.tap(find.text('Pay from wallet'));
    await tester.pumpAndSettle();
    final pay = find.textContaining('Pay from wallet ·');
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await tester.pumpAndSettle();

    expect(orders.created, 1);
    expect(
      container.read(cartControllerProvider),
      isEmpty,
      reason: 'the order owns the lines as soon as create_order succeeds',
    );
  });
}

class _FakeOrders implements OrderRepository {
  int created = 0;

  @override
  Future<CreatedOrder> createOrder({
    required List<OrderItemRequest> items,
    String? coupon,
    Map<String, String> fields = const {},
    String? email,
    String? note,
  }) async {
    created++;
    return const CreatedOrder(
      orderId: 'order-1',
      orderNo: 'YCP-1',
      subtotalUsd: 1.5,
      discountUsd: 0,
      totalUsd: 1.5,
      expiresInMinutes: 15,
    );
  }

  // Wallet short of the total: the order is pending, which is exactly the case
  // where the cart used to be kept "for a retry".
  @override
  Future<WalletPaymentResult> payWithWallet(String orderId) async =>
      const WalletPaymentResult(ok: false, reason: 'insufficient_balance');

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
