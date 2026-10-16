// Cart entity as the app uses it. Pure Dart: no JSON, no SDK types.
// Persistence lives in `../data/cart_mappers.dart`.

import '../../catalog/domain/catalog_entities.dart';

/// One line in the local cart. Purely client-side until checkout.
class CartLine {
  const CartLine({
    required this.variantId,
    required this.productSlug,
    required this.productName,
    required this.variantLabel,
    required this.unitPriceUsd,
    required this.qty,
    required this.maxQty,
    required this.minQty,
    this.fields = const {},
    this.requiredFields = const [],
  });

  final int variantId;
  final String productSlug;
  final String productName;
  final String variantLabel;
  final double unitPriceUsd;
  final int qty;
  final int maxQty;
  final int minQty;

  /// Values for the product's `requires_fields` entries, e.g. game id and
  /// server. Merged into a single object at checkout because `create_order`
  /// validates them per product against one payload.
  final Map<String, String> fields;

  /// The definitions behind [fields]. Carried on the line so checkout can
  /// render the inputs itself instead of relying on whatever the product page
  /// happened to collect, which was not editable afterwards.
  final List<RequiredField> requiredFields;

  bool get needsFields => requiredFields.isNotEmpty;

  double get lineTotal => unitPriceUsd * qty;

  CartLine copyWith({int? qty, Map<String, String>? fields}) => CartLine(
    variantId: variantId,
    productSlug: productSlug,
    productName: productName,
    variantLabel: variantLabel,
    unitPriceUsd: unitPriceUsd,
    qty: qty ?? this.qty,
    maxQty: maxQty,
    minQty: minQty,
    fields: fields ?? this.fields,
    requiredFields: requiredFields,
  );
}
