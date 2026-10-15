// Plain data classes mirroring the Postgres schema. Kept hand-written rather
// than generated so the shapes stay readable next to the migrations.

enum ProductKind { instantStock, autoTopup, manualSetup }

ProductKind productKindFrom(String raw) => switch (raw) {
  'instant_stock' => ProductKind.instantStock,
  'auto_topup' => ProductKind.autoTopup,
  _ => ProductKind.manualSetup,
};

enum StockMode { stock, unlimited }

enum OrderStatus {
  pending,
  paid,
  delivering,
  delivered,
  failed,
  refundPending,
  refunded,
  expired,
}

OrderStatus orderStatusFrom(String raw) => switch (raw) {
  'paid' => OrderStatus.paid,
  'delivering' => OrderStatus.delivering,
  'delivered' => OrderStatus.delivered,
  'failed' => OrderStatus.failed,
  // A refund staff have agreed but not yet paid out. Reading this as
  // 'pending' would tell a buyer who already paid that they have not.
  'refund_pending' => OrderStatus.refundPending,
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

  Map<String, dynamic> toJson() => {
    'key': key,
    'label_km': labelKm,
    'label_en': labelEn,
    if (placeholder != null) 'placeholder': placeholder,
    if (pattern != null) 'pattern': pattern,
    if (helpKm != null) 'help_km': helpKm,
    if (helpEn != null) 'help_en': helpEn,
    if (guideImageUrl != null) 'guide_image_url': guideImageUrl,
  };

  factory RequiredField.fromJson(Map<String, dynamic> json) => RequiredField(
    key: json['key'] as String? ?? '',
    labelKm: (json['label_km'] ?? json['key'] ?? '') as String,
    labelEn: (json['label_en'] ?? json['key'] ?? '') as String,
    placeholder: json['placeholder'] as String?,
    pattern: json['pattern'] as String?,
    helpKm: json['help_km'] as String?,
    helpEn: json['help_en'] as String?,
    guideImageUrl: json['guide_image_url'] as String?,
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
    id: (json['id'] as num).toInt(),
    slug: json['slug'] as String? ?? '',
    nameKm: json['name_km'] as String? ?? '',
    nameEn: json['name_en'] as String? ?? '',
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
    required this.productId,
    required this.productName,
    required this.variantLabel,
    required this.qty,
    required this.unitPriceUsd,
    required this.lineTotalUsd,
    required this.deliveryStatus,
    this.codes = const [],
  });

  final int id;

  /// Needed to attach a review to the right product.
  final int? productId;
  final String productName;
  final String variantLabel;
  final int qty;
  final double unitPriceUsd;
  final double lineTotalUsd;
  final DeliveryStatus deliveryStatus;

  /// Only a delivered line for a real product can be reviewed; RLS enforces
  /// the same rule server-side.
  bool get canBeReviewed =>
      productId != null && deliveryStatus == DeliveryStatus.delivered;

  /// Populated by reveal_order once the order is paid.
  final List<String> codes;

  OrderLine copyWith({List<String>? codes}) => OrderLine(
    id: id,
    productId: productId,
    productName: productName,
    variantLabel: variantLabel,
    qty: qty,
    unitPriceUsd: unitPriceUsd,
    lineTotalUsd: lineTotalUsd,
    deliveryStatus: deliveryStatus,
    codes: codes ?? this.codes,
  );

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] as Map<String, dynamic>?;
    return OrderLine(
      id: (json['id'] as num).toInt(),
      productId: (variant?['product_id'] as num?)?.toInt(),
      productName: json['product_name'] as String? ?? '',
      variantLabel: json['variant_label'] as String? ?? '',
      qty: (json['qty'] as num).toInt(),
      unitPriceUsd: (json['unit_price_usd'] as num).toDouble(),
      lineTotalUsd: (json['line_total_usd'] as num).toDouble(),
      deliveryStatus: deliveryStatusFrom(
        json['delivery_status'] as String? ?? '',
      ),
    );
  }
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
    this.manualPaymentRequestedAt,
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

  /// Set when the buyer has asked to pay by transfer, so the panel can show
  /// "waiting for confirmation" instead of offering to ask again.
  final DateTime? manualPaymentRequestedAt;

  bool get isPending => status == OrderStatus.pending;
  bool get isPaid =>
      status != OrderStatus.pending && status != OrderStatus.expired;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    orderNo: json['order_no'] as String? ?? '',
    status: orderStatusFrom(json['status'] as String? ?? 'pending'),
    subtotalUsd: (json['subtotal_usd'] as num?)?.toDouble() ?? 0,
    discountUsd: (json['discount_usd'] as num?)?.toDouble() ?? 0,
    totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
    couponCode: json['coupon_code'] as String?,
    expiresAt:
        DateTime.tryParse(json['expires_at'] as String? ?? '') ??
        DateTime.now(),
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
    manualPaymentRequestedAt: DateTime.tryParse(
      json['manual_payment_requested_at'] as String? ?? '',
    ),
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

/// An order where the buyer has asked to pay by bank transfer, as the staff
/// queue sees it. Read from `staff_manual_payments`, which is a
/// `security_invoker` view: a non-staff session gets no rows from it.
class ManualPaymentRequest {
  const ManualPaymentRequest({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.totalUsd,
    required this.kind,
    required this.expiresAt,
    this.requestedAt,
    this.buyerNote,
    this.customerFields = const {},
    this.contactEmail,
  });

  final String orderId;
  final String orderNo;
  final OrderStatus status;
  final double totalUsd;
  final String kind;
  final DateTime expiresAt;
  final DateTime? requestedAt;
  final String? buyerNote;
  final Map<String, String> customerFields;
  final String? contactEmail;

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  factory ManualPaymentRequest.fromJson(Map<String, dynamic> json) =>
      ManualPaymentRequest(
        orderId: json['order_id'] as String,
        orderNo: json['order_no'] as String? ?? '',
        status: orderStatusFrom(json['status'] as String? ?? 'pending'),
        totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
        kind: json['kind'] as String? ?? '',
        expiresAt:
            DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.now(),
        requestedAt: DateTime.tryParse(json['requested_at'] as String? ?? ''),
        buyerNote: json['buyer_note'] as String?,
        customerFields: ((json['customer_fields'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
        contactEmail: json['contact_email'] as String?,
      );
}

/// The staff overview, exactly as `admin_overview()` returns it.
///
/// Field names mirror the JSON so there is no second naming scheme to keep in
/// step. `timezone` is carried through deliberately: the screen has to be able
/// to say which day "today" means.
class AdminOverview {
  const AdminOverview({
    required this.timezone,
    required this.generatedAt,
    required this.ordersPending,
    required this.ordersRefundPending,
    required this.transfersWaiting,
    required this.supportOpen,
    required this.itemsManualWaiting,
    required this.receivedToday,
    required this.receivedTodayUsd,
    required this.received7dUsd,
    required this.received30dUsd,
    required this.walletSpent30dUsd,
    required this.refunds30d,
    required this.refunded30dUsd,
  });

  final String timezone;
  final DateTime generatedAt;

  final int ordersPending;
  final int ordersRefundPending;
  final int transfersWaiting;
  final int supportOpen;
  final int itemsManualWaiting;

  /// Payments, not orders: see the migration for why the two differ.
  final int receivedToday;
  final double receivedTodayUsd;
  final double received7dUsd;
  final double received30dUsd;
  final double walletSpent30dUsd;
  final int refunds30d;
  final double refunded30dUsd;

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
        timezone: json['timezone'] as String? ?? 'UTC',
        generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
            DateTime.now(),
        ordersPending: (json['orders_pending'] as num?)?.toInt() ?? 0,
        ordersRefundPending:
            (json['orders_refund_pending'] as num?)?.toInt() ?? 0,
        transfersWaiting: (json['transfers_waiting'] as num?)?.toInt() ?? 0,
        supportOpen: (json['support_open'] as num?)?.toInt() ?? 0,
        itemsManualWaiting: (json['items_manual_waiting'] as num?)?.toInt() ?? 0,
        receivedToday: (json['received_today'] as num?)?.toInt() ?? 0,
        receivedTodayUsd: (json['received_today_usd'] as num?)?.toDouble() ?? 0,
        received7dUsd: (json['received_7d_usd'] as num?)?.toDouble() ?? 0,
        received30dUsd: (json['received_30d_usd'] as num?)?.toDouble() ?? 0,
        walletSpent30dUsd: (json['wallet_spent_30d_usd'] as num?)?.toDouble() ?? 0,
        refunds30d: (json['refunds_30d'] as num?)?.toInt() ?? 0,
        refunded30dUsd: (json['refunded_30d_usd'] as num?)?.toDouble() ?? 0,
      );
}

/// One row of the staff order list. Deliberately lighter than `Order`: the list
/// shows a count of lines, not the lines.
class AdminOrderSummary {
  const AdminOrderSummary({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.kind,
    required this.totalUsd,
    required this.createdAt,
    required this.itemCount,
    this.paidAt,
    this.refundedAt,
    this.refundReason,
    this.contactEmail,
    this.manualPaymentRequestedAt,
  });

  final String id;
  final String orderNo;
  final OrderStatus status;
  final String kind;
  final double totalUsd;
  final DateTime createdAt;
  final int itemCount;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final String? refundReason;
  final String? contactEmail;
  final DateTime? manualPaymentRequestedAt;

  factory AdminOrderSummary.fromJson(Map<String, dynamic> json) =>
      AdminOrderSummary(
        id: json['id'] as String,
        orderNo: json['order_no'] as String? ?? '',
        status: orderStatusFrom(json['status'] as String? ?? 'pending'),
        kind: json['kind'] as String? ?? 'purchase',
        totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        itemCount: ((json['items'] as List?) ?? const []).length,
        paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
        refundedAt: DateTime.tryParse(json['refunded_at'] as String? ?? ''),
        refundReason: json['refund_reason'] as String?,
        contactEmail: json['contact_email'] as String?,
        manualPaymentRequestedAt:
            DateTime.tryParse(json['manual_payment_requested_at'] as String? ?? ''),
      );
}

class AdminOrderItem {
  const AdminOrderItem({
    required this.id,
    required this.productName,
    required this.variantLabel,
    required this.qty,
    required this.unitPriceUsd,
    required this.lineTotalUsd,
    required this.deliveryStatus,
    required this.supplierAttempts,
    this.supplierLastError,
    this.supplierRef,
    this.supplierNextAttemptAt,
  });

  final int id;
  final String productName;
  final String variantLabel;
  final int qty;
  final double unitPriceUsd;
  final double lineTotalUsd;
  final DeliveryStatus deliveryStatus;

  /// How many times the supplier worker has tried, and what it last said. This
  /// is the only view of a failing line a person has.
  final int supplierAttempts;
  final String? supplierLastError;
  final String? supplierRef;
  final DateTime? supplierNextAttemptAt;

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) => AdminOrderItem(
        id: (json['id'] as num).toInt(),
        productName: json['product_name'] as String? ?? '',
        variantLabel: json['variant_label'] as String? ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        unitPriceUsd: (json['unit_price_usd'] as num?)?.toDouble() ?? 0,
        lineTotalUsd: (json['line_total_usd'] as num?)?.toDouble() ?? 0,
        deliveryStatus:
            deliveryStatusFrom(json['delivery_status'] as String? ?? 'pending'),
        supplierAttempts: (json['supplier_attempts'] as num?)?.toInt() ?? 0,
        supplierLastError: json['supplier_last_error'] as String?,
        supplierRef: json['supplier_ref'] as String?,
        supplierNextAttemptAt:
            DateTime.tryParse(json['supplier_next_attempt_at'] as String? ?? ''),
      );
}

class AdminPaymentRow {
  const AdminPaymentRow({
    required this.provider,
    required this.status,
    required this.amountUsd,
    this.providerRef,
    this.paywayMethod,
    this.verifiedAt,
    this.refundedAt,
  });

  /// Raw database values. The staff screen shows them as they are: these are the
  /// words that appear in the bank reconciliation and in the logs, and a
  /// translated synonym would be a second name for the same thing.
  final String provider;
  final String status;
  final double amountUsd;
  final String? providerRef;
  final String? paywayMethod;
  final DateTime? verifiedAt;
  final DateTime? refundedAt;

  factory AdminPaymentRow.fromJson(Map<String, dynamic> json) => AdminPaymentRow(
        provider: json['provider'] as String? ?? '',
        status: json['status'] as String? ?? '',
        amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0,
        providerRef: json['provider_ref'] as String?,
        paywayMethod: json['payway_method'] as String?,
        verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? ''),
        refundedAt: DateTime.tryParse(json['refunded_at'] as String? ?? ''),
      );
}

/// One `order_events` row: the append-only history the trigger writes.
class AdminOrderEvent {
  const AdminOrderEvent({
    required this.event,
    required this.actor,
    required this.createdAt,
    this.fromStatus,
    this.toStatus,
    this.detail,
  });

  final String event;
  final String actor;
  final DateTime createdAt;
  final OrderStatus? fromStatus;
  final OrderStatus? toStatus;
  final Map<String, dynamic>? detail;

  factory AdminOrderEvent.fromJson(Map<String, dynamic> json) => AdminOrderEvent(
        event: json['event'] as String? ?? '',
        actor: json['actor'] as String? ?? 'system',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        fromStatus: json['from_status'] == null
            ? null
            : orderStatusFrom(json['from_status'] as String),
        toStatus: json['to_status'] == null
            ? null
            : orderStatusFrom(json['to_status'] as String),
        detail: (json['detail'] as Map?)?.cast<String, dynamic>(),
      );
}

class AdminOrderDetail {
  const AdminOrderDetail({
    required this.summary,
    required this.items,
    required this.payments,
    required this.events,
    this.customerNote,
    this.customerFields = const {},
  });

  final AdminOrderSummary summary;
  final List<AdminOrderItem> items;
  final List<AdminPaymentRow> payments;
  final List<AdminOrderEvent> events;
  final String? customerNote;
  final Map<String, String> customerFields;

  factory AdminOrderDetail.fromJson(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> events,
  ) =>
      AdminOrderDetail(
        summary: AdminOrderSummary.fromJson(order),
        items: ((order['items'] as List?) ?? const [])
            .map((e) => AdminOrderItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        payments: payments.map(AdminPaymentRow.fromJson).toList(),
        events: events.map(AdminOrderEvent.fromJson).toList(),
        customerNote: order['customer_note'] as String?,
        customerFields: ((order['customer_fields'] as Map?) ?? const {})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );
}

/// A `support_tickets` row. Status and priority stay as the database's own
/// words for the same reason payment status does.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.body,
    this.contact,
    this.adminNote,
    this.orderId,
    this.orderNo,
    this.resolvedAt,
  });

  final int id;
  final String subject;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? body;
  final String? contact;
  final String? adminNote;
  final String? orderId;
  final String? orderNo;
  final DateTime? resolvedAt;

  bool get isOpen => status == 'open' || status == 'in_progress';

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: (json['id'] as num).toInt(),
        subject: json['subject'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        priority: json['priority'] as String? ?? 'normal',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.now(),
        body: json['body'] as String?,
        contact: json['contact'] as String?,
        adminNote: json['admin_note'] as String?,
        orderId: json['order_id'] as String?,
        orderNo: (json['orders'] as Map?)?['order_no'] as String?,
        resolvedAt: DateTime.tryParse(json['resolved_at'] as String? ?? ''),
      );
}

/// One entry in the wallet ledger. Append-only, so this reads as a statement.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.kind,
    required this.amountUsd,
    required this.balanceAfter,
    required this.createdAt,
    this.note,
    this.orderId,
  });

  final int id;

  /// topup | purchase | refund | admin_adjust | coin_reward
  final String kind;
  final double amountUsd;
  final double balanceAfter;
  final DateTime createdAt;
  final String? note;
  final String? orderId;

  bool get isCredit => amountUsd > 0;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: (json['id'] as num).toInt(),
        kind: json['kind'] as String? ?? 'admin_adjust',
        amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        note: json['note'] as String?,
        orderId: json['order_id'] as String?,
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
    expiresAt:
        DateTime.tryParse(json['expires_at'] as String? ?? '') ??
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
    'required_fields': [for (final field in requiredFields) field.toJson()],
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
    fields: ((json['fields'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    ),
    requiredFields: ((json['required_fields'] as List?) ?? const [])
        .map((e) => RequiredField.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}
