import '../../catalog/data/catalog_mappers.dart';
import '../domain/cart_line.dart';

Map<String, dynamic> cartLineToJson(CartLine line) => {
  'variant_id': line.variantId,
  'product_slug': line.productSlug,
  'product_name': line.productName,
  'variant_label': line.variantLabel,
  'unit_price_usd': line.unitPriceUsd,
  'qty': line.qty,
  'max_qty': line.maxQty,
  'min_qty': line.minQty,
  'fields': line.fields,
  'required_fields': [
    for (final field in line.requiredFields) requiredFieldToJson(field),
  ],
};

CartLine cartLineFromJson(Map<String, dynamic> json) => CartLine(
  variantId: (json['variant_id'] as num).toInt(),
  productSlug: json['product_slug'] as String? ?? '',
  productName: json['product_name'] as String? ?? '',
  variantLabel: json['variant_label'] as String? ?? '',
  unitPriceUsd: (json['unit_price_usd'] as num).toDouble(),
  qty: (json['qty'] as num).toInt(),
  maxQty: (json['max_qty'] as num?)?.toInt() ?? 10,
  minQty: (json['min_qty'] as num?)?.toInt() ?? 1,
  fields: ((json['fields'] as Map?) ?? const {}).map(
    (key, value) => MapEntry(key.toString(), value.toString()),
  ),
  requiredFields: ((json['required_fields'] as List?) ?? const [])
      .map((e) => requiredFieldFromJson((e as Map).cast<String, dynamic>()))
      .toList(),
);
