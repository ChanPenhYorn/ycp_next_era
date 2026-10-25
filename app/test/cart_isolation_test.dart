import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ycp_store/src/features/cart/data/cart_mappers.dart';
import 'package:ycp_store/src/features/cart/domain/cart_line.dart';
import 'package:ycp_store/src/state/providers.dart';

/// The cart lives in shared_preferences, which is per device rather than per
/// account. It used to survive a sign-out, so the next person to sign in on the
/// same browser saw the previous buyer's lines and could check out with them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cartKey = 'cart_v1';
  const ownerKey = 'cart_v1_owner';

  final line = CartLine(
    variantId: 7,
    productSlug: 'mlbb',
    productName: 'Mobile Legends',
    variantLabel: '86 diamonds',
    unitPriceUsd: 1.5,
    qty: 1,
    maxQty: 5,
    minQty: 1,
    sku: 'MLBB-86',
  );

  Future<SharedPreferences> seeded({
    String? owner,
    bool withLine = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    if (withLine) {
      await preferences.setString(cartKey, jsonEncode([cartLineToJson(line)]));
    }
    if (owner != null) await preferences.setString(ownerKey, owner);
    return preferences;
  }

  ProviderContainer containerFor(
    SharedPreferences preferences, {
    String? userId,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        currentUserIdProvider.overrideWithValue(userId),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the same account gets its cart back', () async {
    final preferences = await seeded(owner: 'user-a');
    final container = containerFor(preferences, userId: 'user-a');

    expect(container.read(cartControllerProvider).single.variantId, 7);
  });

  test('a different account never sees the previous cart', () async {
    final preferences = await seeded(owner: 'user-a');
    final container = containerFor(preferences, userId: 'user-b');

    expect(container.read(cartControllerProvider), isEmpty);
    // Discarding is async (two preference removals); let it finish.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(preferences.getString(cartKey), isNull);
    expect(preferences.getString(ownerKey), isNull);
  });

  test('a guest cart carries into the first sign-in', () async {
    // No owner key at all: items added before logging in.
    final preferences = await seeded();
    final container = containerFor(preferences, userId: 'user-b');

    expect(container.read(cartControllerProvider).single.variantId, 7);
  });

  test('signing out clears the cart, so the next visit starts empty', () async {
    final preferences = await seeded(owner: 'user-a');
    final signedIn = containerFor(preferences, userId: 'user-a');
    expect(signedIn.read(cartControllerProvider), isNotEmpty);

    // What the account screen does, in order.
    await signedIn.read(cartControllerProvider.notifier).clear();

    expect(preferences.getString(cartKey), isNull);
    expect(preferences.getString(ownerKey), isNull);

    final guest = containerFor(preferences);
    expect(guest.read(cartControllerProvider), isEmpty);
  });

  test(
    'adding a line stamps the owner, so a later account cannot claim it',
    () async {
      final preferences = await seeded(withLine: false);
      final container = containerFor(preferences, userId: 'user-a');

      await container
          .read(cartControllerProvider.notifier)
          .add(
            variantId: 9,
            productSlug: 'steam',
            productName: 'Steam Wallet',
            variantLabel: '5 USD',
            unitPriceUsd: 5,
            minQty: 1,
            maxQty: 10,
            sku: 'STEAM-5',
          );

      expect(preferences.getString(ownerKey), 'user-a');

      final other = containerFor(preferences, userId: 'user-b');
      expect(other.read(cartControllerProvider), isEmpty);
    },
  );
}
