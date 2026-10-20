import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/widgets/app_shell.dart';
import 'package:ycp_store/src/ui/widgets/search_field.dart';

/// A shell over a miniature route tree: the storefront tabs, the buyer's
/// account, and one admin screen. Enough to tell which chrome is on screen.
GoRouter _router(String start) => GoRouter(
  initialLocation: start,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('storefront-home'),
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) => const Text('storefront-games'),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const Text('storefront-orders'),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => const Text('storefront-account'),
        ),
        GoRoute(
          path: '/admin/orders',
          builder: (context, state) => const Text('admin-orders'),
        ),
      ],
    ),
  ],
);

Widget _app(GoRouter router, SharedPreferences preferences) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    // Signed out, empty cart: the chrome under test then has nothing to fetch
    // and no Supabase client to talk to.
    currentUserProvider.overrideWithValue(null),
    profileProvider.overrideWith((ref) async => null),
    cartCountProvider.overrideWithValue(0),
  ],
  child: MaterialApp.router(
    locale: const Locale('en'),
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: AppL10n.localizationsDelegates,
    routerConfig: router,
  ),
);

/// Preference store for one test, fresh so the locale starts at its default.
Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('the console hides the buyer chrome on a narrow screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_router('/admin/orders'), await _preferences()),
    );
    await tester.pumpAndSettle();

    expect(find.text('admin-orders'), findsOneWidget);
    // Shop navigation: gone, both the tab bar and its destinations.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.grid_view_outlined), findsNothing);
    // Balance and cart belong to the buyer, not to staff at work.
    expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    expect(find.byIcon(Icons.monetization_on_rounded), findsNothing);
    // Language and the account link (sign-out) stay reachable.
    expect(find.text('EN'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('the storefront button leaves the console', (tester) async {
    await tester.pumpWidget(
      _app(_router('/admin/orders'), await _preferences()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    expect(find.text('storefront-home'), findsOneWidget);
    // Back in the shop, the buyer's chrome is back.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
  });

  testWidgets('a wide console drops the links and the game search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(_router('/admin/orders'), await _preferences()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GameSearchField), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });

  testWidgets('the storefront keeps its links and search', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_router('/'), await _preferences()));
    await tester.pumpAndSettle();

    expect(find.byType(GameSearchField), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
  });
}
