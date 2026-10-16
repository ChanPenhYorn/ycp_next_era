// Order entities as the app uses them. Pure Dart: no JSON, no SDK types.
// Parsing from the database lives in `../data/order_mappers.dart`.

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

enum DeliveryStatus { pending, delivered, failed, manualWaiting }

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
}

/// One line the buyer asks for. Prices are resolved server-side, never sent.
class OrderItemRequest {
  const OrderItemRequest({required this.variantId, required this.qty});

  final int variantId;
  final int qty;
}

class CreatedOrder {
  const CreatedOrder({
    required this.orderId,
    required this.orderNo,
    required this.subtotalUsd,
    required this.discountUsd,
    required this.totalUsd,
    required this.expiresInMinutes,
  });

  final String orderId;
  final String orderNo;
  final double subtotalUsd;
  final double discountUsd;
  final double totalUsd;
  final int expiresInMinutes;
}

class WalletPaymentResult {
  const WalletPaymentResult({
    required this.ok,
    this.reason,
    this.balance,
    this.required,
  });

  final bool ok;
  final String? reason;
  final double? balance;
  final double? required;
}
