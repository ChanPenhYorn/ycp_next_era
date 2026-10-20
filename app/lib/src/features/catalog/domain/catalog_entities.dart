// Catalogue entities as the app uses them. Pure Dart: no JSON, no SDK types.
// Parsing from the database lives in `../data/catalog_mappers.dart`.

enum ProductKind { instantStock, autoTopup, manualSetup }

enum StockMode { stock, unlimited }

/// What the catalogue currently says about a variant a saved cart still holds.
///
/// A cart is stored in `shared_preferences` and outlives the catalogue, so a
/// line can disagree with the database: staff hide the product, a supplier sync
/// deactivates the SKU, or a supplier cap arrives that the line was built
/// before. Reading the live values back lets the cart correct itself and say
/// what changed, instead of sending a stale line to `create_order` to be
/// refused.
class LiveVariant {
  const LiveVariant({
    required this.id,
    required this.sku,
    required this.minQty,
    required this.maxQty,
  });

  final int id;
  final String sku;
  final int minQty;
  final int maxQty;
}

class RequiredField {
  const RequiredField({
    required this.key,
    required this.labelKm,
    required this.labelEn,
    this.placeholder,
    this.pattern,
    this.helpKm,
    this.helpEn,
    this.guideImageUrl,
  });

  final String key;
  final String labelKm;
  final String labelEn;
  final String? placeholder;
  final String? pattern;

  /// Optional longer instructions, from the catalogue. When absent the app
  /// falls back to the copy for this field's key, then to a general answer.
  final String? helpKm;
  final String? helpEn;

  /// Optional screenshot for the help sheet. Only rendered when the catalogue
  /// carries one: the app ships no screenshots of a game it does not run.
  final String? guideImageUrl;

  String label(String locale) => locale == 'km' ? labelKm : labelEn;

  String? help(String locale) {
    final value = locale == 'km' ? helpKm : helpEn;
    return (value == null || value.trim().isEmpty) ? null : value;
  }
}

class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.nameKm,
    required this.nameEn,
  });

  final int id;
  final String slug;
  final String nameKm;
  final String nameEn;

  String name(String locale) => locale == 'km' ? nameKm : nameEn;
}

class Variant {
  const Variant({
    required this.id,
    required this.sku,
    required this.labelKm,
    required this.labelEn,
    required this.priceUsd,
    required this.compareAtPriceUsd,
    required this.stockMode,
    required this.minQty,
    required this.maxQty,
    required this.inStock,
  });

  final int id;
  final String sku;
  final String labelKm;
  final String labelEn;
  final double priceUsd;
  final double? compareAtPriceUsd;
  final StockMode stockMode;
  final int minQty;
  final int maxQty;

  /// null means unlimited (supplier-fulfilled), not "unknown".
  final int? inStock;

  String label(String locale) => locale == 'km' ? labelKm : labelEn;

  bool get isSoldOut => inStock != null && inStock! <= 0;
  bool get isUnlimited => stockMode == StockMode.unlimited;
}

class ProductCard {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.nameKm,
    required this.nameEn,
    required this.imageUrl,
    required this.kind,
    required this.ratingAvg,
    required this.ratingCount,
    required this.soldCount,
    required this.minPriceUsd,
    required this.maxPriceUsd,
    required this.compareAtPriceUsd,
    required this.totalStock,
    this.category,
  });

  final int id;
  final String slug;
  final String nameKm;
  final String nameEn;
  final String? imageUrl;
  final ProductKind kind;
  final double ratingAvg;
  final int ratingCount;
  final int soldCount;
  final double minPriceUsd;
  final double maxPriceUsd;
  final double? compareAtPriceUsd;
  final int? totalStock;
  final Category? category;

  String name(String locale) => locale == 'km' ? nameKm : nameEn;
  bool get isSoldOut => totalStock != null && totalStock! <= 0;
  bool get hasPriceRange => maxPriceUsd > minPriceUsd;
}

class ProductDetail {
  const ProductDetail({
    required this.card,
    required this.description,
    required this.requiresFields,
    required this.variants,
  });

  final ProductCard card;
  final String? description;
  final List<RequiredField> requiresFields;
  final List<Variant> variants;

  Category? get category => card.category;
  String name(String locale) => card.name(locale);
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.body,
    required this.authorName,
    required this.createdAt,
  });

  final int id;
  final int rating;
  final String? body;
  final String? authorName;
  final DateTime createdAt;
}

class PublicSettings {
  const PublicSettings({
    required this.siteName,
    required this.usdToKhr,
    required this.orderTtlMinutes,
    this.topupMinUsd = 1,
    this.topupMaxUsd = 1000,
    this.supportTelegram,
    this.supportEmail,
    this.khqrAccountId,
    this.khqrMerchantName,
    this.manualGraceMinutes = 1440,
  });

  final String siteName;
  final double usdToKhr;
  final int orderTtlMinutes;
  final double topupMinUsd;
  final double topupMaxUsd;
  final String? supportTelegram;
  final String? supportEmail;

  /// The ABA account a manual transfer goes to, and the name on it. Both come
  /// from settings, so a store that has not filled them in shows no transfer
  /// option rather than an instruction the buyer cannot act on.
  final String? khqrAccountId;
  final String? khqrMerchantName;

  /// How long an order stays payable after the buyer asks to pay by transfer.
  final int manualGraceMinutes;

  /// True only when there is an account to pay into and something to call it.
  bool get hasTransferAccount =>
      (khqrAccountId?.trim().isNotEmpty ?? false) &&
      (khqrMerchantName?.trim().isNotEmpty ?? false);

  static const fallback = PublicSettings(
    siteName: 'Chanpenh',
    usdToKhr: 4100,
    orderTtlMinutes: 15,
  );
}
