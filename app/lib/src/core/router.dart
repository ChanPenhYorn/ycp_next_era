import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../ui/admin_order_detail_page.dart';
import '../ui/admin_orders_page.dart';
import '../ui/admin_page.dart';
import '../ui/admin_refunds_page.dart';
import '../ui/admin_support_page.dart';
import '../ui/admin_transfers_page.dart';
import '../ui/cart_page.dart';
import '../ui/catalog_page.dart';
import '../ui/checkout_page.dart';
import '../ui/account_page.dart';
import '../ui/login_page.dart';
import '../ui/wallet_page.dart';
import '../ui/order_detail_page.dart';
import '../ui/orders_page.dart';
import '../ui/product_page.dart';
import '../ui/home_page.dart';
import '../ui/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isProtected =
          state.matchedLocation == '/checkout' ||
          state.matchedLocation == '/wallet' ||
          state.matchedLocation == '/account' ||
          state.matchedLocation.startsWith('/admin') ||
          state.matchedLocation.startsWith('/orders');

      if (isProtected && user == null) {
        return '/login?next=${Uri.encodeComponent(state.uri.toString())}';
      }

      if (state.matchedLocation == '/login' && user != null) {
        final next = state.uri.queryParameters['next'];
        return next == null || next.isEmpty ? '/' : next;
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/products',
            builder: (context, state) => CatalogPage(
              categorySlug: state.uri.queryParameters['category'],
              search: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: '/products/:slug',
            builder: (context, state) =>
                ProductPage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
          GoRoute(
            path: '/wallet',
            builder: (context, state) => const WalletPage(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountPage(),
          ),
          GoRoute(
            path: '/checkout',
            builder: (context, state) => const CheckoutPage(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (context, state) =>
                OrderDetailPage(orderId: state.pathParameters['id']!),
          ),
          // Staff surface. Every page re-checks the role before it reads
          // anything, and the database re-checks it on every RPC.
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminPage(),
          ),
          GoRoute(
            path: '/admin/orders',
            builder: (context, state) => AdminOrdersPage(
              initialStatus: state.uri.queryParameters['status'],
            ),
          ),
          GoRoute(
            path: '/admin/orders/:id',
            builder: (context, state) =>
                AdminOrderDetailPage(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/refunds',
            builder: (context, state) => const AdminRefundsPage(),
          ),
          GoRoute(
            path: '/admin/support',
            builder: (context, state) => AdminSupportPage(
              initialStatus: state.uri.queryParameters['status'],
            ),
          ),
          GoRoute(
            path: '/admin/transfers',
            builder: (context, state) => const AdminTransfersPage(),
          ),
        ],
      ),
      // Full-screen routes: no bottom navigation while paying or signing in.
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    ],
  );
});
