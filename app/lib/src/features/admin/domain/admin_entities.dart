// Staff-side entities as the app uses them. Pure Dart: no JSON, no SDK types.
// Parsing from the database lives in `../data/admin_mappers.dart`.

import '../../orders/domain/order_entities.dart';

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
}

/// A product as staff see it: including hidden ones, with its variants and the
/// supplier cost next to the price. Keep it on staff screens only: the cost is
/// a business figure, and the column is readable by every role (see the note
/// in the catalogue migration).
class AdminCatalogueProduct {
  const AdminCatalogueProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.isActive,
    required this.kind,
    required this.variants,
    this.supplierCode,
  });

  final int id;
  final String slug;
  final String name;
  final bool isActive;
  final String kind;
  final String? supplierCode;
  final List<AdminCatalogueVariant> variants;
}

class AdminCatalogueVariant {
  const AdminCatalogueVariant({
    required this.id,
    required this.sku,
    required this.label,
    required this.priceUsd,
    required this.costUsd,
    required this.isActive,
    this.sortOrder = 0,
  });

  final int id;
  final String sku;
  final String label;
  final double priceUsd;
  final double? costUsd;
  final bool isActive;
  final int sortOrder;

  /// Price minus cost, or null when cost is unknown. A negative value means
  /// the variant is sold at a loss.
  double? get marginUsd => costUsd == null ? null : priceUsd - costUsd!;
}

/// One line the supplier worker could not finish. `state` is the database's
/// word: `manual_waiting` needs a person, `retrying` will try again by itself.
class SupplierQueueItem {
  const SupplierQueueItem({
    required this.itemId,
    required this.orderId,
    required this.orderNo,
    required this.productName,
    required this.variantLabel,
    required this.qty,
    required this.state,
    required this.attempts,
    required this.createdAt,
    this.supplierCode,
    this.lastError,
    this.nextAttemptAt,
  });

  final int itemId;
  final String orderId;
  final String orderNo;
  final String productName;
  final String variantLabel;
  final int qty;
  final String state;
  final int attempts;
  final DateTime createdAt;
  final String? supplierCode;
  final String? lastError;
  final DateTime? nextAttemptAt;

  bool get needsPerson => state == 'manual_waiting';
}

/// A staff or admin account as the role screen shows it. `role` is the
/// database's own word: `customer`, `staff` or `admin`.
class StaffMember {
  const StaffMember({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final String role;

  bool get isAdmin => role == 'admin';
}
