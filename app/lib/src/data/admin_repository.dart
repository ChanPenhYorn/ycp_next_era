import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'order_repository.dart';

/// Staff-side reads and actions.
///
/// Every write here goes to an RPC that re-checks `is_staff()` in the database.
/// The app deciding to draw the screen is a convenience, not the control.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  /// Orders where the buyer has asked to pay by transfer. The view filters to
  /// pending orders and its policies hide everything from a non-staff session,
  /// so this returns an empty list rather than failing.
  Future<List<ManualPaymentRequest>> manualPaymentRequests() async {
    final rows = await _client
        .from('staff_manual_payments')
        .select(
          'order_id, order_no, status, total_usd, kind, requested_at, '
          'buyer_note, expires_at, customer_fields, contact_email',
        )
        .order('requested_at', ascending: true);

    return rows.map(ManualPaymentRequest.fromJson).toList();
  }

  /// Confirms a transfer that was checked against the bank app.
  ///
  /// Returns the RPC's own answer. `ok: false` with a status means the order was
  /// already settled somewhere else, which the screen reports rather than
  /// treating as an error.
  Future<Map<String, dynamic>> confirmManualPayment({
    required String orderId,
    required double amountUsd,
    required String abaRef,
    String? note,
  }) async {
    try {
      final result = await _client.rpc(
        'admin_confirm_manual_payment',
        params: {
          'p_order_id': orderId,
          'p_amount_usd': amountUsd,
          'p_aba_ref': abaRef,
          'p_note': note,
        },
      );

      return (result as Map).cast<String, dynamic>();
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  /// Drops a request that will not be paid, so the queue does not only grow.
  Future<void> clearManualPaymentRequest({
    required String orderId,
    required String reason,
  }) async {
    try {
      await _client.rpc(
        'admin_clear_manual_payment_request',
        params: {'p_order_id': orderId, 'p_reason': reason},
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  // --------------------------------------------------------------------------
  // Overview
  // --------------------------------------------------------------------------

  /// The counts and sums the overview screen shows. Every figure comes from a
  /// row; the migration explains why received and wallet spend are separate.
  Future<AdminOverview> overview() async {
    final result = await _client.rpc('admin_overview');
    return AdminOverview.fromJson((result as Map).cast<String, dynamic>());
  }

  // --------------------------------------------------------------------------
  // Orders
  // --------------------------------------------------------------------------

  /// Staff see every order: `orders_select_own` includes `is_staff()`. The rows
  /// are summaries — a count of lines, not the lines.
  Future<List<AdminOrderSummary>> orders({
    String? status,
    String? search,
    int limit = 60,
  }) async {
    var query = _client
        .from('orders')
        .select(
          'id, order_no, status, kind, total_usd, created_at, paid_at, '
          'refunded_at, refund_reason, contact_email, '
          'manual_payment_requested_at, items:order_items(id)',
        );

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final term = search?.trim() ?? '';
    if (term.isNotEmpty) {
      // `%` and `_` are wildcards to PostgREST; a buyer's own paste must not
      // turn into "match everything".
      final escaped = term.replaceAll('%', r'\%').replaceAll('_', r'\_');
      query = query.ilike('order_no', '%$escaped%');
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(AdminOrderSummary.fromJson).toList();
  }

  /// One order with everything a person needs to act on it: the lines and their
  /// supplier state, the payments, and the append-only history.
  Future<AdminOrderDetail?> orderDetail(String orderId) async {
    final order = await _client
        .from('orders')
        .select(
          'id, order_no, status, kind, total_usd, created_at, paid_at, '
          'refunded_at, refund_reason, contact_email, customer_note, '
          'customer_fields, manual_payment_requested_at, '
          'items:order_items(id, product_name, variant_label, qty, '
          'unit_price_usd, line_total_usd, delivery_status, supplier_attempts, '
          'supplier_last_error, supplier_ref, supplier_next_attempt_at)',
        )
        .eq('id', orderId)
        .maybeSingle();

    if (order == null) return null;

    final payments = await _client
        .from('payments')
        .select(
          'provider, status, amount_usd, provider_ref, payway_method, '
          'verified_at, refunded_at',
        )
        .eq('order_id', orderId)
        .order('initiated_at', ascending: false);

    final events = await _client
        .from('order_events')
        .select('event, actor, from_status, to_status, detail, created_at')
        .eq('order_id', orderId)
        .order('created_at', ascending: true)
        .order('id', ascending: true);

    return AdminOrderDetail.fromJson(order, payments, events);
  }

  /// Agrees a refund. Moves no money: the reversal happens in the bank, and
  /// `admin_order_mark_refunded` records that it did.
  Future<Map<String, dynamic>> setRefundPending({
    required String orderId,
    String? reason,
  }) async {
    return _jsonRpc('admin_order_set_refund_pending', {
      'p_order_id': orderId,
      'p_reason': reason,
    });
  }

  /// Records a reversal that already happened outside the app.
  Future<Map<String, dynamic>> markRefunded({
    required String orderId,
    String? reference,
  }) async {
    return _jsonRpc('admin_order_mark_refunded', {
      'p_order_id': orderId,
      'p_reference': reference,
    });
  }

  /// Closes one line by hand — what a `manual_waiting` row is waiting for.
  Future<void> resolveItem({
    required int itemId,
    String delivery = 'delivered',
  }) async {
    try {
      await _client.rpc(
        'admin_resolve_item',
        params: {'p_item_id': itemId, 'p_delivery': delivery},
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  // --------------------------------------------------------------------------
  // Support
  // --------------------------------------------------------------------------

  Future<List<SupportTicket>> supportTickets({String? status}) async {
    var query = _client
        .from('support_tickets')
        .select(
          'id, subject, body, status, priority, contact, admin_note, order_id, '
          'resolved_at, created_at, updated_at, orders(order_no)',
        );

    if (status == 'open') {
      query = query.inFilter('status', ['open', 'in_progress']);
    } else if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final rows = await query.order('created_at', ascending: false).limit(100);
    return rows.map(SupportTicket.fromJson).toList();
  }

  Future<void> setSupportStatus({
    required int ticketId,
    String? status,
    String? note,
    String? priority,
  }) async {
    try {
      await _client.rpc(
        'admin_support_set_status',
        params: {
          'p_ticket_id': ticketId,
          'p_status': status,
          'p_note': note,
          'p_priority': priority,
        },
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> _jsonRpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _client.rpc(name, params: params);
      return (result as Map).cast<String, dynamic>();
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  /// The same mapping the customer side uses: the database raises business
  /// rules by name, and the UI is expected to translate them.
  OrderException _mapError(PostgrestException error) {
    // `raise exception 'manual_underpaid' using detail = total`
    final raw = error.message.trim();
    final code = raw.split(RegExp(r'[\s:]')).first;
    return OrderException(code, detail: error.details?.toString());
  }
}
