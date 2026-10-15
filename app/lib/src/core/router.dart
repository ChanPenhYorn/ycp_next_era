import 'package:flutter/material.dart';
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

/// One transition for every route: a short fade with a small rise. The default
/// platform slide reads as a jump on this dark UI, and tabs should not slide
/// sideways at all.
Page<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

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
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _fadePage(state, const HomePage()),
          ),
          GoRoute(
            path: '/products',
            pageBuilder: (context, state) => _fadePage(
              state,
              CatalogPage(
                categorySlug: state.uri.queryParameters['category'],
                search: state.uri.queryParameters['q'],
              ),
            ),
          ),
          GoRoute(
            path: '/products/:slug',
            pageBuilder: (context, state) => _fadePage(
              state,
              ProductPage(slug: state.pathParameters['slug']!),
            ),
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) => _fadePage(state, const CartPage()),
          ),
          GoRoute(
            path: '/wallet',
            pageBuilder: (context, state) =>
                _fadePage(state, const WalletPage()),
          ),
          GoRoute(
            path: '/account',
            pageBuilder: (context, state) =>
                _fadePage(state, const AccountPage()),
          ),
          GoRoute(
            path: '/checkout',
            pageBuilder: (context, state) =>
                _fadePage(state, const CheckoutPage()),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) =>
                _fadePage(state, const OrdersPage()),
          ),
          GoRoute(
            path: '/orders/:id',
            pageBuilder: (context, state) => _fadePage(
              state,
              OrderDetailPage(orderId: state.pathParameters['id']!),
            ),
          ),
          // Staff surface. Every page re-checks the role before it reads
          // anything, and the database re-checks it on every RPC.
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) =>
                _fadePage(state, const AdminPage()),
          ),
          GoRoute(
            path: '/admin/orders',
            pageBuilder: (context, state) => _fadePage(
              state,
              AdminOrdersPage(
                initialStatus: state.uri.queryParameters['status'],
              ),
            ),
          ),
          GoRoute(
            path: '/admin/orders/:id',
            pageBuilder: (context, state) => _fadePage(
              state,
              AdminOrderDetailPage(orderId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/admin/refunds',
            pageBuilder: (context, state) =>
                _fadePage(state, const AdminRefundsPage()),
          ),
          GoRoute(
            path: '/admin/support',
            pageBuilder: (context, state) => _fadePage(
              state,
              AdminSupportPage(
                initialStatus: state.uri.queryParameters['status'],
              ),
            ),
          ),
          GoRoute(
            path: '/admin/transfers',
            pageBuilder: (context, state) =>
                _fadePage(state, const AdminTransfersPage()),
          ),
        ],
      ),
      // Full-screen routes: no bottom navigation while paying or signing in.
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(state, const LoginPage()),
      ),
    ],
  );
});
