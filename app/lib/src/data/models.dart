// Plain data classes mirroring the Postgres schema. Kept hand-written rather
// than generated so the shapes stay readable next to the migrations.

enum ProductKind { instantStock, autoTopup, manualSetup }

ProductKind productKindFrom(String raw) => switch (raw) {
      'instant_stock' => ProductKind.instantStock,
      'auto_topup' => ProductKind.autoTopup,
      _ => ProductKind.manualSetup,
    };

enum StockMode { stock, unlimited }

enum OrderStatus { pending, paid, delivering, delivered, failed, refunded, expired }

OrderStatus orderStatusFrom(String raw) => switch (raw) {
      'paid' => OrderStatus.paid,
      'delivering' => OrderStatus.delivering,
      'delivered' => OrderStatus.delivered,
      'failed' => OrderStatus.failed,
      'refunded' => OrderStatus.refunded,
      'expired' => OrderStatus.expired,
      _ => OrderStatus.pending,
    };

enum DeliveryStatus { pending, delivered, failed, manualWaiting }

DeliveryStatus deliveryStatusFrom(String raw) => switch (raw) {
      'delivered' => DeliveryStatus.delivered,
      'failed' => DeliveryStatus.failed,
      'manual_waiting' => DeliveryStatus.manualWaiting,
      _ => DeliveryStatus.pending,
    };

class RequiredField {
  const RequiredField({
    required this.key,
    required this.labelKm,
    required this.labelEn,
    this.placeholder,
    this.pattern,
  });

  final String key;
  final String labelKm;
  final String labelEn;
  final String? placeholder;
  final String? pattern;

  String label(String locale) => locale == 'km' ? labelKm : labelEn;

  factory RequiredField.fromJson(Map<String, dynamic> json) => RequiredField(
        key: json['key'] as String,
        labelKm: (json['label_km'] ?? json['key']) as String,
        labelEn: (json['label_en'] ?? json['key']) as String,
        placeholder: json['placeholder'] as String?,
        pattern: json['pattern'] as String?,
      );
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

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        slug: json['slug'] as String,
        nameKm: json['name_km'] as String,
        nameEn: json['name_en'] as String,
      );
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

  factory Variant.fromJson(Map<String, dynamic> json) => Variant(
        id: json['id'] as int,
        sku: json['sku'] as String,
        labelKm: json['label_km'] as String,
        labelEn: json['label_en'] as String,
        priceUsd: (json['price_usd'] as num).toDouble(),
        compareAtPriceUsd: (json['compare_at_price_usd'] as num?)?.toDouble(),
        stockMode: json['stock_mode'] == 'unlimited'
            ? StockMode.unlimited
            : StockMode.stock,
        minQty: (json['min_qty'] as num?)?.toInt() ?? 1,
        maxQty: (json['max_qty'] as num?)?.toInt() ?? 1,
        inStock: (json['in_stock'] as num?)?.toInt(),
      );
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

class OrderLine {
  const OrderLine({
    required this.id,
    required this.productName,
    required this.variantLabel,
    required this.qty,
    required this.unitPriceUsd,
    required this.lineTotalUsd,
    required this.deliveryStatus,
    this.codes = const [],
  });  final int id;
  final String productName;
  final String variantLabel;
  final int qty;
  final double unitPriceUsd;
  final double lineTotalUsd;
  final DeliveryStatus deliveryStatus;

  /// Populated by reveal_order once the order is paid.
  final List<String> codes;

  OrderLine copyWith({List<String>? codes}) => OrderLine(
        id: id,
        productName: productName,
        variantLabel: variantLabel,
        qty: qty,
        unitPriceUsd: unitPriceUsd,
        lineTotalUsd: lineTotalUsd,
        deliveryStatus: deliveryStatus,
        codes: codes ?? this.codes,
      );

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        id: (json['id'] as num).toInt(),
        productName: json['product_name'] as String? ?? '',
        variantLabel: json['variant_label'] as String? ?? '',
        qty: (json['qty'] as num).toInt(),
        unitPriceUsd: (json['unit_price_usd'] as num).toDouble(),
        lineTotalUsd: (json['line_total_usd'] as num).toDouble(),
        deliveryStatus: deliveryStatusFrom(json['delivery_status'] as String? ?? ''),
      );
}

class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.subtotalUsd,
    required this.discountUsd,
    required this.totalUsd,
    required this.expiresAt,
    required this.createdAt,
    required this.items,
    this.couponCode,
    this.paidAt,
  });

  final String id;
  final String orderNo;
  final OrderStatus status;
  final double subtotalUsd;
  final double discountUsd;
  final double totalUsd;
  final DateTime expiresAt;
  final DateTime createdAt;
  final List<OrderLine> items;
  final String? couponCode;
  final DateTime? paidAt;

  bool get isPending => status == OrderStatus.pending;
  bool get isPaid => status != OrderStatus.pending && status != OrderStatus.expired;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNo: json['order_no'] as String? ?? '',
        status: orderStatusFrom(json['status'] as String? ?? 'pending'),
        subtotalUsd: (json['subtotal_usd'] as num?)?.toDouble() ?? 0,
        discountUsd: (json['discount_usd'] as num?)?.toDouble() ?? 0,
        totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
        couponCode: json['coupon_code'] as String?,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.now(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => OrderLine.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class PublicSettings {
  const PublicSettings({
    required this.siteName,
    required this.usdToKhr,
    required this.orderTtlMinutes,
    this.supportTelegram,
    this.supportEmail,
  });

  final String siteName;
  final double usdToKhr;
  final int orderTtlMinutes;
  final String? supportTelegram;
  final String? supportEmail;

  static const fallback = PublicSettings(
    siteName: 'YCP Store',
    usdToKhr: 4100,
    orderTtlMinutes: 15,
  );
}

/// Result of payway-init.
class KhqrPayment {
  const KhqrPayment({
    required this.tranId,
    required this.qrString,
    required this.totalUsd,
    required this.expiresAt,
    this.deepLink,
    this.checkoutQrUrl,
  });

  final String tranId;
  final String qrString;
  final double totalUsd;
  final DateTime expiresAt;
  final String? deepLink;
  final String? checkoutQrUrl;

  factory KhqrPayment.fromJson(Map<String, dynamic> json) => KhqrPayment(
        tranId: json['tran_id'] as String? ?? '',
        qrString: json['qr_string'] as String? ?? '',
        totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.now().add(const Duration(minutes: 15)),
        deepLink: json['abapay_deeplink'] as String?,
        checkoutQrUrl: json['checkout_qr_url'] as String?,
      );
}

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

  double get lineTotal => unitPriceUsd * qty;

  CartLine copyWith({int? qty}) => CartLine(
        variantId: variantId,
        productSlug: productSlug,
        productName: productName,
        variantLabel: variantLabel,
        unitPriceUsd: unitPriceUsd,
        qty: qty ?? this.qty,
        maxQty: maxQty,
        minQty: minQty,
        fields: fields,
      );

  Map<String, dynamic> toJson() => {
        'variant_id': variantId,
        'product_slug': productSlug,
        'product_name': productName,
        'variant_label': variantLabel,
        'unit_price_usd': unitPriceUsd,
        'qty': qty,
        'max_qty': maxQty,
        'min_qty': minQty,
        'fields': fields,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        variantId: (json['variant_id'] as num).toInt(),
        productSlug: json['product_slug'] as String? ?? '',
        productName: json['product_name'] as String? ?? '',
        variantLabel: json['variant_label'] as String? ?? '',
        unitPriceUsd: (json['unit_price_usd'] as num).toDouble(),
        qty: (json['qty'] as num).toInt(),
        maxQty: (json['max_qty'] as num?)?.toInt() ?? 10,
        minQty: (json['min_qty'] as num?)?.toInt() ?? 1,
        fields: ((json['fields'] as Map?) ?? const {})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );
}
