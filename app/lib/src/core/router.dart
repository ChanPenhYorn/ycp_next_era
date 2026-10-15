import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';
import '../ui/cart_page.dart';
import '../ui/catalog_page.dart';
import '../ui/checkout_page.dart';
import '../ui/login_page.dart';
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
      final isProtected = state.matchedLocation == '/checkout' ||
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
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
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
        ],
      ),
      // Full-screen routes: no bottom navigation while paying or signing in.
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    ],
  );
});
