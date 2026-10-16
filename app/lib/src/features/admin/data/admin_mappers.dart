import '../../orders/data/order_mappers.dart';
import '../domain/admin_entities.dart';

ManualPaymentRequest manualPaymentRequestFromJson(Map<String, dynamic> json) =>
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

AdminOverview adminOverviewFromJson(Map<String, dynamic> json) => AdminOverview(
  timezone: json['timezone'] as String? ?? 'UTC',
  generatedAt:
      DateTime.tryParse(json['generated_at'] as String? ?? '') ??
      DateTime.now(),
  ordersPending: (json['orders_pending'] as num?)?.toInt() ?? 0,
  ordersRefundPending: (json['orders_refund_pending'] as num?)?.toInt() ?? 0,
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

AdminOrderSummary adminOrderSummaryFromJson(Map<String, dynamic> json) =>
    AdminOrderSummary(
      id: json['id'] as String,
      orderNo: json['order_no'] as String? ?? '',
      status: orderStatusFrom(json['status'] as String? ?? 'pending'),
      kind: json['kind'] as String? ?? 'purchase',
      totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      itemCount: ((json['items'] as List?) ?? const []).length,
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
      refundedAt: DateTime.tryParse(json['refunded_at'] as String? ?? ''),
      refundReason: json['refund_reason'] as String?,
      contactEmail: json['contact_email'] as String?,
      manualPaymentRequestedAt: DateTime.tryParse(
        json['manual_payment_requested_at'] as String? ?? '',
      ),
    );

AdminOrderItem adminOrderItemFromJson(Map<String, dynamic> json) =>
    AdminOrderItem(
      id: (json['id'] as num).toInt(),
      productName: json['product_name'] as String? ?? '',
      variantLabel: json['variant_label'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      unitPriceUsd: (json['unit_price_usd'] as num?)?.toDouble() ?? 0,
      lineTotalUsd: (json['line_total_usd'] as num?)?.toDouble() ?? 0,
      deliveryStatus: deliveryStatusFrom(
        json['delivery_status'] as String? ?? 'pending',
      ),
      supplierAttempts: (json['supplier_attempts'] as num?)?.toInt() ?? 0,
      supplierLastError: json['supplier_last_error'] as String?,
      supplierRef: json['supplier_ref'] as String?,
      supplierNextAttemptAt: DateTime.tryParse(
        json['supplier_next_attempt_at'] as String? ?? '',
      ),
    );

AdminPaymentRow adminPaymentRowFromJson(Map<String, dynamic> json) =>
    AdminPaymentRow(
      provider: json['provider'] as String? ?? '',
      status: json['status'] as String? ?? '',
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0,
      providerRef: json['provider_ref'] as String?,
      paywayMethod: json['payway_method'] as String?,
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? ''),
      refundedAt: DateTime.tryParse(json['refunded_at'] as String? ?? ''),
    );

AdminOrderEvent adminOrderEventFromJson(Map<String, dynamic> json) =>
    AdminOrderEvent(
      event: json['event'] as String? ?? '',
      actor: json['actor'] as String? ?? 'system',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      fromStatus: json['from_status'] == null
          ? null
          : orderStatusFrom(json['from_status'] as String),
      toStatus: json['to_status'] == null
          ? null
          : orderStatusFrom(json['to_status'] as String),
      detail: (json['detail'] as Map?)?.cast<String, dynamic>(),
    );

AdminOrderDetail adminOrderDetailFromJson(
  Map<String, dynamic> order,
  List<Map<String, dynamic>> payments,
  List<Map<String, dynamic>> events,
) => AdminOrderDetail(
  summary: adminOrderSummaryFromJson(order),
  items: ((order['items'] as List?) ?? const [])
      .map((e) => adminOrderItemFromJson((e as Map).cast<String, dynamic>()))
      .toList(),
  payments: payments.map(adminPaymentRowFromJson).toList(),
  events: events.map(adminOrderEventFromJson).toList(),
  customerNote: order['customer_note'] as String?,
  customerFields: ((order['customer_fields'] as Map?) ?? const {}).map(
    (key, value) => MapEntry(key.toString(), value.toString()),
  ),
);

SupportTicket supportTicketFromJson(Map<String, dynamic> json) => SupportTicket(
  id: (json['id'] as num).toInt(),
  subject: json['subject'] as String? ?? '',
  status: json['status'] as String? ?? 'open',
  priority: json['priority'] as String? ?? 'normal',
  createdAt:
      DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
  updatedAt:
      DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
  body: json['body'] as String?,
  contact: json['contact'] as String?,
  adminNote: json['admin_note'] as String?,
  orderId: json['order_id'] as String?,
  orderNo: (json['orders'] as Map?)?['order_no'] as String?,
  resolvedAt: DateTime.tryParse(json['resolved_at'] as String? ?? ''),
);

AdminCatalogueProduct adminCatalogueProductFromJson(Map<String, dynamic> json) {
  final supplier = json['supplier'] as Map<String, dynamic>?;
  return AdminCatalogueProduct(
    id: (json['id'] as num).toInt(),
    slug: json['slug'] as String? ?? '',
    name: json['name_en'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? false,
    kind: json['kind'] as String? ?? '',
    supplierCode: supplier?['code'] as String?,
    variants:
        (((json['variants'] as List?) ?? const [])
            .map(
              (e) => adminCatalogueVariantFromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
  );
}

AdminCatalogueVariant adminCatalogueVariantFromJson(
  Map<String, dynamic> json,
) => AdminCatalogueVariant(
  id: (json['id'] as num).toInt(),
  sku: json['sku'] as String? ?? '',
  label: json['label_en'] as String? ?? '',
  priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0,
  costUsd: (json['cost_usd'] as num?)?.toDouble(),
  isActive: json['is_active'] as bool? ?? false,
  sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
);

SupplierQueueItem supplierQueueItemFromJson(Map<String, dynamic> json) =>
    SupplierQueueItem(
      itemId: (json['item_id'] as num).toInt(),
      orderId: json['order_id'] as String,
      orderNo: json['order_no'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      variantLabel: json['variant_label'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      state: json['state'] as String? ?? 'retrying',
      attempts: (json['supplier_attempts'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      supplierCode: json['supplier_code'] as String?,
      lastError: json['supplier_last_error'] as String?,
      nextAttemptAt: DateTime.tryParse(
        json['supplier_next_attempt_at'] as String? ?? '',
      ),
    );

StaffMember staffMemberFromJson(Map<String, dynamic> json) => StaffMember(
  id: json['id'] as String,
  displayName: json['display_name'] as String? ?? '',
  role: json['role'] as String? ?? 'customer',
);
