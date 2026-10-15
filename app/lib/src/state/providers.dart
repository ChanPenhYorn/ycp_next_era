import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../data/payment_repository.dart';
import 'cart_controller.dart';
import 'locale_controller.dart';

/// Overridden in main() once SharedPreferences has resolved.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(supabaseProvider)),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(supabaseProvider)),
);

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

final cartControllerProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);

/// Emits on sign-in, sign-out and token refresh.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});

final settingsProvider = FutureProvider<PublicSettings>(
  (ref) => ref.watch(catalogRepositoryProvider).settings(),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

/// Arguments for the product grid. Equality is value-based so Riverpod caches
/// one result per distinct filter combination.
class ProductQuery {
  const ProductQuery({this.categorySlug, this.search, this.featuredOnly = false});

  final String? categorySlug;
  final String? search;
  final bool featuredOnly;

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.categorySlug == categorySlug &&
      other.search == search &&
      other.featuredOnly == featuredOnly;

  @override
  int get hashCode => Object.hash(categorySlug, search, featuredOnly);
}

final productsProvider =
    FutureProvider.family<List<ProductCard>, ProductQuery>((ref, query) {
  return ref.watch(catalogRepositoryProvider).products(
        categorySlug: query.categorySlug,
        search: query.search,
        featuredOnly: query.featuredOnly,
      );
});

/// Locale matters because the DB stores both km and en copy.
final productDetailProvider =
    FutureProvider.family<ProductDetail?, (String slug, String locale)>((ref, arg) {
  return ref
      .watch(catalogRepositoryProvider)
      .productBySlug(arg.$1, arg.$2);
});

final reviewsProvider = FutureProvider.family<List<Review>, int>(
  (ref, productId) => ref.watch(catalogRepositoryProvider).reviews(productId),
);

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(orderRepositoryProvider).profile();
});

final ordersProvider = FutureProvider<List<Order>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(orderRepositoryProvider).listOrders();
});

final walletTransactionsProvider = FutureProvider<List<WalletTransaction>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(orderRepositoryProvider).walletTransactions();
});

/// Product ids already reviewed within one order, so the UI can hide the
/// button instead of letting the unique index reject the insert.
final reviewedProductsProvider =
    FutureProvider.family<Set<int>, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).reviewedProductIds(orderId);
});

final orderProvider = FutureProvider.family<Order?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).getOrder(orderId);
});

/// Total of the local cart, before any coupon.
final cartSubtotalProvider = Provider<double>((ref) {
  final lines = ref.watch(cartControllerProvider);
  return lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
});

final cartCountProvider = Provider<int>((ref) {
  final lines = ref.watch(cartControllerProvider);
  return lines.fold<int>(0, (sum, line) => sum + line.qty);
});
