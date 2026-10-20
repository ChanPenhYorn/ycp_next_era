import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../features/cart/data/cart_mappers.dart';
import 'providers.dart';

/// What a cart reconciliation changed, so the pages can say why.
class CartReconcile {
  const CartReconcile({this.removed = const [], this.capped = const []});

  static const none = CartReconcile();

  /// Lines the catalogue no longer sells.
  final List<CartLine> removed;

  /// Lines whose quantity was above what the catalogue now accepts, and was
  /// lowered to fit.
  final List<CartLine> capped;

  /// True when nothing the buyer needs to be told about happened.
  bool get isEmpty => removed.isEmpty && capped.isEmpty;
}

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
          .map((e) => cartLineFromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode([
      for (final line in state) cartLineToJson(line),
    ]);
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
    String sku = '',
    int qty = 1,
    Map<String, String> fields = const {},
    List<RequiredField> requiredFields = const [],
  }) async {
    final existing = state.indexWhere((line) => line.variantId == variantId);

    if (existing >= 0) {
      final line = state[existing];
      final merged = (line.qty + qty).clamp(line.minQty, line.maxQty);
      final next = [...state];
      // Merge the values too. Previously the second add dropped them, so a line
      // could sit in the cart with qty 2 and no game id.
      next[existing] = line.copyWith(
        qty: merged,
        fields: fields.isEmpty ? null : fields,
      );
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
          sku: sku,
          fields: fields,
          requiredFields: requiredFields,
        ),
      ];
    }

    await _persist();
  }

  /// Records the buyer fields for a line, edited at checkout.
  Future<void> setFields(int variantId, Map<String, String> fields) async {
    state = [
      for (final line in state)
        if (line.variantId == variantId)
          line.copyWith(fields: fields)
        else
          line,
    ];
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

  /// Caps a line to one unit, moving its bounds with it.
  ///
  /// Used when the database refuses a line quantity, which is what happens to
  /// a cart saved before a supplier's per-line cap was known: the buyer had
  /// two of something the supplier only delivers once. Retrying unchanged can
  /// only fail again, so the line is corrected and the buyer is told, rather
  /// than being left with an error they cannot act on. `maxQty` follows `qty`
  /// so the stepper disappears instead of sitting there dead.
  Future<void> capToOne(int variantId) async {
    state = [
      for (final line in state)
        if (line.variantId == variantId)
          line.copyWith(qty: line.minQty, maxQty: line.minQty)
        else
          line,
    ];
    await _persist();
  }

  Future<void> remove(int variantId) async {
    state = state.where((line) => line.variantId != variantId).toList();
    await _persist();
  }

  /// Drops lines the catalogue no longer sells and returns the lines removed.
  ///
  /// The cart outlives the catalogue: it is stored in `shared_preferences`, so a
  /// line survives staff hiding its product or a supplier sync deactivating its
  /// SKU. `create_order` refuses those with `product_unavailable` /
  /// `variant_unavailable`, so the buyer is only told after committing. Reading
  /// the same rules back lets the cart heal itself and say why.
  ///
  /// It also re-reads each line's quantity range and SKU, which go stale the
  /// same way: a sync that caps a supplier top-up at one unit leaves a saved
  /// line asking for two, and `create_order` refuses that for ever. Correcting
  /// it here means the buyer sees a cart that matches what the database will
  /// actually accept.
  Future<CartReconcile> reconcileWithCatalogue() async {
    if (state.isEmpty) return CartReconcile.none;

    final Map<int, LiveVariant> live;
    try {
      live = await ref.read(catalogRepositoryProvider).liveVariants([
        for (final line in state) line.variantId,
      ]);
    } catch (_) {
      // Offline, or the read failed. Nothing is known to be wrong, so the cart
      // is left alone rather than emptied on a guess: `create_order` remains
      // the authority on what is sellable.
      return CartReconcile.none;
    }

    final removed = <CartLine>[];
    final capped = <CartLine>[];
    final next = <CartLine>[];
    var drifted = false;

    for (final line in state) {
      final variant = live[line.variantId];
      // A range the buyer cannot satisfy at all (a cap that arrived as zero)
      // counts as no longer sellable, not as a quantity to clamp into.
      if (variant == null || variant.minQty > variant.maxQty) {
        removed.add(line);
        continue;
      }

      final qty = line.qty.clamp(variant.minQty, variant.maxQty);
      if (qty < line.qty) capped.add(line);
      if (qty != line.qty ||
          variant.maxQty != line.maxQty ||
          variant.minQty != line.minQty ||
          variant.sku != line.sku) {
        drifted = true;
      }

      next.add(
        line.copyWith(
          qty: qty,
          maxQty: variant.maxQty,
          minQty: variant.minQty,
          sku: variant.sku,
        ),
      );
    }

    if (removed.isEmpty && capped.isEmpty && !drifted) {
      return CartReconcile.none;
    }

    state = next;
    await _persist();
    // Silent drift (a renamed SKU, a wider cap) is not worth interrupting the
    // buyer over, so it is not reported: only a drop or a reduced quantity is.
    return CartReconcile(removed: removed, capped: capped);
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}
