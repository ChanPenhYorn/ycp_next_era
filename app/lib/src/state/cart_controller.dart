import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import 'providers.dart';

/// Client-side cart. Nothing here is trusted: `create_order` recomputes every
/// price and stock check on the server.
class CartController extends Notifier<List<CartLine>> {
  static const _key = 'cart_v1';

  @override
  List<CartLine> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => CartLine.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode([for (final line in state) line.toJson()]);
    await ref.read(sharedPreferencesProvider).setString(_key, encoded);
  }

  /// Adds a variant, merging with an existing line and clamping to maxQty.
  Future<void> add({
    required int variantId,
    required String productSlug,
    required String productName,
    required String variantLabel,
    required double unitPriceUsd,
    required int minQty,
    required int maxQty,
    int qty = 1,
    Map<String, String> fields = const {},
  }) async {
    final existing = state.indexWhere((line) => line.variantId == variantId);

    if (existing >= 0) {
      final line = state[existing];
      final merged = (line.qty + qty).clamp(line.minQty, line.maxQty);
      final next = [...state];
      next[existing] = line.copyWith(qty: merged);
      state = next;
    } else {
      state = [
        ...state,
        CartLine(
          variantId: variantId,
          productSlug: productSlug,
          productName: productName,
          variantLabel: variantLabel,
          unitPriceUsd: unitPriceUsd,
          qty: qty.clamp(minQty, maxQty),
          maxQty: maxQty,
          minQty: minQty,
          fields: fields,
        ),
      ];
    }

    await _persist();
  }

  Future<void> setQty(int variantId, int qty) async {
    state = [
      for (final line in state)
        if (line.variantId == variantId)
          line.copyWith(qty: qty.clamp(line.minQty, line.maxQty))
        else
          line,
    ];
    await _persist();
  }

  Future<void> remove(int variantId) async {
    state = state.where((line) => line.variantId != variantId).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}
