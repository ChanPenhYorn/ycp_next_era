import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../features/admin/data/supabase_admin_repository.dart';
import '../features/admin/domain/admin_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/catalog/data/supabase_catalog_repository.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/orders/data/supabase_order_repository.dart';
import '../features/orders/domain/order_repository.dart';
import '../features/payments/data/supabase_payment_repository.dart';
import '../features/payments/domain/payment_repository.dart';
import '../features/profile/data/supabase_profile_repository.dart';
import '../features/profile/domain/profile.dart';
import '../features/profile/domain/profile_repository.dart';
import 'cart_controller.dart';
import 'locale_controller.dart';

/// Overridden in main() once SharedPreferences has resolved.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseProvider)),
);

/// Which sign-in methods are switched on. Read from the project, so enabling
/// Google in the dashboard is enough to make the button appear.
final authCapabilitiesProvider = FutureProvider<AuthCapabilities>(
  (ref) => ref.watch(authRepositoryProvider).capabilities(),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => SupabaseCatalogRepository(ref.watch(supabaseProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => SupabaseOrderRepository(ref.watch(supabaseProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseProvider)),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => SupabasePaymentRepository(ref.watch(supabaseProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseProvider)),
);

/// Orders waiting for a human to check a bank transfer. Staff-only in the
/// database: a non-staff session gets an empty list, not an error.
final manualPaymentRequestsProvider =
    FutureProvider<List<ManualPaymentRequest>>((ref) {
      ref.watch(currentUserProvider);
      return ref.watch(adminRepositoryProvider).manualPaymentRequests();
    });

/// The overview figures. Refetched rather than cached across sign-in: the
/// numbers are money, and a stale figure is worse than a spinner.
final adminOverviewProvider = FutureProvider<AdminOverview>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(adminRepositoryProvider).overview();
});

/// Filter for the staff order list. Value equality so Riverpod caches one
/// result per distinct filter.
class AdminOrderQuery {
  const AdminOrderQuery({this.status, this.search});

  /// A raw `order_status` value, or null for every status.
  final String? status;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is AdminOrderQuery &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

final adminOrdersProvider =
    FutureProvider.family<List<AdminOrderSummary>, AdminOrderQuery>((
      ref,
      query,
    ) {
      ref.watch(currentUserProvider);
      return ref
          .watch(adminRepositoryProvider)
          .orders(status: query.status, search: query.search);
    });

/// Orders staff have agreed to refund but not yet reversed. Same query as the
/// list, different question.
final adminRefundQueueProvider = FutureProvider<List<AdminOrderSummary>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(adminRepositoryProvider).orders(status: 'refund_pending');
});

final adminOrderDetailProvider =
    FutureProvider.family<AdminOrderDetail?, String>((ref, orderId) {
      return ref.watch(adminRepositoryProvider).orderDetail(orderId);
    });

/// A `support_tickets` status filter, or null for everything. `'open'` means
/// both open and in_progress.
final adminTicketsProvider =
    FutureProvider.family<List<SupportTicket>, String?>((ref, status) {
      ref.watch(currentUserProvider);
      return ref.watch(adminRepositoryProvider).supportTickets(status: status);
    });

/// Every product for the staff catalogue, hidden ones included.
final adminCatalogueProvider = FutureProvider<List<AdminCatalogueProduct>>((
  ref,
) {
  ref.watch(currentUserProvider);
  return ref.watch(adminRepositoryProvider).catalogue();
});

/// Supplier lines that are retrying or waiting for a person.
final adminSupplierQueueProvider = FutureProvider<List<SupplierQueueItem>>((
  ref,
) {
  ref.watch(currentUserProvider);
  return ref.watch(adminRepositoryProvider).supplierQueue();
});

/// Staff and admin accounts. Admins only; a staff session gets an error.
final adminStaffProvider = FutureProvider<List<StaffMember>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(adminRepositoryProvider).staffMembers();
});

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

final cartControllerProvider = NotifierProvider<CartController, List<CartLine>>(
  CartController.new,
);

/// Emits on sign-in, sign-out and token refresh.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authChanges(),
);

final currentUserProvider = Provider<AppUser?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser;
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
  const ProductQuery({
    this.categorySlug,
    this.search,
    this.featuredOnly = false,
    this.popularFirst = false,
  });

  final String? categorySlug;
  final String? search;
  final bool featuredOnly;

  /// Order by real `sold_count` instead of the staff `sort_order`.
  final bool popularFirst;

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.categorySlug == categorySlug &&
      other.search == search &&
      other.featuredOnly == featuredOnly &&
      other.popularFirst == popularFirst;

  @override
  int get hashCode =>
      Object.hash(categorySlug, search, featuredOnly, popularFirst);
}

final productsProvider = FutureProvider.family<List<ProductCard>, ProductQuery>(
  (ref, query) {
    return ref
        .watch(catalogRepositoryProvider)
        .products(
          categorySlug: query.categorySlug,
          search: query.search,
          featuredOnly: query.featuredOnly,
          popularFirst: query.popularFirst,
        );
  },
);

/// Games ordered by units actually sold. `sold_count` moves on delivery, so
/// this can be empty on a store with no orders — that is honest, and the home
/// page falls back to the featured grid rather than inventing a ranking.
final popularGamesProvider = FutureProvider<List<ProductCard>>((ref) {
  return ref
      .watch(catalogRepositoryProvider)
      .products(popularFirst: true, limit: 12);
});

/// True when a product carries a genuine, in-stock discount: a
/// `compare_at_price_usd` that beats the live price. Extracted so the rule is
/// testable without a database, and so "promotions" can never drift into
/// showing a price that is not a reduction.
bool isPromoted(ProductCard product) =>
    discountPercent(product.minPriceUsd, product.compareAtPriceUsd) != null &&
    !product.isSoldOut;

/// Products with a genuine discount: a variant whose `compare_at_price_usd`
/// beats its live price. Nothing is hardcoded here, so an empty list means the
/// promotions section is omitted entirely instead of showing a fake banner.
final promotionsProvider = FutureProvider<List<ProductCard>>((ref) async {
  final all = await ref.watch(catalogRepositoryProvider).products(limit: 48);

  return all.where(isPromoted).toList()..sort((a, b) {
    final offA = discountPercent(a.minPriceUsd, a.compareAtPriceUsd)!;
    final offB = discountPercent(b.minPriceUsd, b.compareAtPriceUsd)!;
    return offB.compareTo(offA);
  });
});

/// Locale matters because the DB stores both km and en copy.
final productDetailProvider =
    FutureProvider.family<ProductDetail?, (String slug, String locale)>((
      ref,
      arg,
    ) {
      return ref.watch(catalogRepositoryProvider).productBySlug(arg.$1, arg.$2);
    });

final reviewsProvider = FutureProvider.family<List<Review>, int>(
  (ref, productId) => ref.watch(catalogRepositoryProvider).reviews(productId),
);

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(profileRepositoryProvider).profile();
});

final ordersProvider = FutureProvider<List<Order>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(orderRepositoryProvider).listOrders();
});

final walletTransactionsProvider = FutureProvider<List<WalletTransaction>>((
  ref,
) {
  ref.watch(currentUserProvider);
  return ref.watch(orderRepositoryProvider).walletTransactions();
});

/// Product ids already reviewed within one order, so the UI can hide the
/// button instead of letting the unique index reject the insert.
final reviewedProductsProvider = FutureProvider.family<Set<int>, String>((
  ref,
  orderId,
) {
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
