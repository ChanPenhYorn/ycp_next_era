import '../domain/catalog_entities.dart';

ProductKind productKindFrom(String raw) => switch (raw) {
  'instant_stock' => ProductKind.instantStock,
  'auto_topup' => ProductKind.autoTopup,
  _ => ProductKind.manualSetup,
};

Map<String, dynamic> requiredFieldToJson(RequiredField field) => {
  'key': field.key,
  'label_km': field.labelKm,
  'label_en': field.labelEn,
  if (field.placeholder != null) 'placeholder': field.placeholder,
  if (field.pattern != null) 'pattern': field.pattern,
  if (field.helpKm != null) 'help_km': field.helpKm,
  if (field.helpEn != null) 'help_en': field.helpEn,
  if (field.guideImageUrl != null) 'guide_image_url': field.guideImageUrl,
};

RequiredField requiredFieldFromJson(Map<String, dynamic> json) => RequiredField(
  key: json['key'] as String? ?? '',
  labelKm: (json['label_km'] ?? json['key'] ?? '') as String,
  labelEn: (json['label_en'] ?? json['key'] ?? '') as String,
  placeholder: json['placeholder'] as String?,
  pattern: json['pattern'] as String?,
  helpKm: json['help_km'] as String?,
  helpEn: json['help_en'] as String?,
  guideImageUrl: json['guide_image_url'] as String?,
);

Category categoryFromJson(Map<String, dynamic> json) => Category(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String? ?? '',
  nameKm: json['name_km'] as String? ?? '',
  nameEn: json['name_en'] as String? ?? '',
);

Variant variantFromJson(Map<String, dynamic> json) => Variant(
  id: (json['id'] as num).toInt(),
  // Display fields tolerate a partial payload: a missing label must not
  // take down the whole catalogue, and `id` is the only structural key.
  sku: json['sku'] as String? ?? '',
  labelKm: json['label_km'] as String? ?? '',
  labelEn: json['label_en'] as String? ?? '',
  priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0,
  compareAtPriceUsd: (json['compare_at_price_usd'] as num?)?.toDouble(),
  stockMode: json['stock_mode'] == 'unlimited'
      ? StockMode.unlimited
      : StockMode.stock,
  minQty: (json['min_qty'] as num?)?.toInt() ?? 1,
  maxQty: (json['max_qty'] as num?)?.toInt() ?? 1,
  inStock: (json['in_stock'] as num?)?.toInt(),
);
