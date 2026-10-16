import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/order_entities.dart';
import '../domain/order_exception.dart';

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

DeliveryStatus deliveryStatusFrom(String raw) => switch (raw) {
  'delivered' => DeliveryStatus.delivered,
  'failed' => DeliveryStatus.failed,
  'manual_waiting' => DeliveryStatus.manualWaiting,
  _ => DeliveryStatus.pending,
};

OrderLine orderLineFromJson(Map<String, dynamic> json) {
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

Order orderFromJson(Map<String, dynamic> json) => Order(
  id: json['id'] as String,
  orderNo: json['order_no'] as String? ?? '',
  status: orderStatusFrom(json['status'] as String? ?? 'pending'),
  subtotalUsd: (json['subtotal_usd'] as num?)?.toDouble() ?? 0,
  discountUsd: (json['discount_usd'] as num?)?.toDouble() ?? 0,
  totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
  couponCode: json['coupon_code'] as String?,
  expiresAt:
      DateTime.tryParse(json['expires_at'] as String? ?? '') ?? DateTime.now(),
  createdAt:
      DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
  paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
  manualPaymentRequestedAt: DateTime.tryParse(
    json['manual_payment_requested_at'] as String? ?? '',
  ),
  items: ((json['items'] as List?) ?? const [])
      .map((e) => orderLineFromJson((e as Map).cast<String, dynamic>()))
      .toList(),
);

WalletTransaction walletTransactionFromJson(Map<String, dynamic> json) =>
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

/// The database raises business rules by name: `raise exception 'out_of_stock'
/// using detail = sku`. The first word of the message is the code.
OrderException orderExceptionFrom(PostgrestException error) {
  final raw = error.message.trim();
  final code = raw.split(RegExp(r'[\s:]')).first;
  return OrderException(code, detail: error.details?.toString());
}
