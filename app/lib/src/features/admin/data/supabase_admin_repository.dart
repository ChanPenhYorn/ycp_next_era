import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/data/order_mappers.dart';
import '../../orders/domain/order_exception.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_repository.dart';
import 'admin_mappers.dart';

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  /// The view filters to pending orders and its policies hide everything from a
  /// non-staff session, so this returns an empty list rather than failing.
  @override
  Future<List<ManualPaymentRequest>> manualPaymentRequests() async {
    final rows = await _client
        .from('staff_manual_payments')
        .select(
          'order_id, order_no, status, total_usd, kind, requested_at, '
          'buyer_note, expires_at, customer_fields, contact_email',
        )
        .order('requested_at', ascending: true);

    return rows.map(manualPaymentRequestFromJson).toList();
  }

  @override
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
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<void> clearManualPaymentRequest({
    required String orderId,
    required String reason,
  }) async {
    await _voidRpc('admin_clear_manual_payment_request', {
      'p_order_id': orderId,
      'p_reason': reason,
    });
  }

  @override
  Future<AdminOverview> overview() async {
    final result = await _client.rpc('admin_overview');
    return adminOverviewFromJson((result as Map).cast<String, dynamic>());
  }

  /// Staff see every order: `orders_select_own` includes `is_staff()`. The rows
  /// are summaries — a count of lines, not the lines.
  @override
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
    return rows.map(adminOrderSummaryFromJson).toList();
  }

  @override
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

    return adminOrderDetailFromJson(order, payments, events);
  }

  @override
  Future<Map<String, dynamic>> setRefundPending({
    required String orderId,
    String? reason,
  }) {
    return _jsonRpc('admin_order_set_refund_pending', {
      'p_order_id': orderId,
      'p_reason': reason,
    });
  }

  @override
  Future<Map<String, dynamic>> markRefunded({
    required String orderId,
    String? reference,
  }) {
    return _jsonRpc('admin_order_mark_refunded', {
      'p_order_id': orderId,
      'p_reference': reference,
    });
  }

  @override
  Future<void> resolveItem({
    required int itemId,
    String delivery = 'delivered',
  }) {
    return _voidRpc('admin_resolve_item', {
      'p_item_id': itemId,
      'p_delivery': delivery,
    });
  }

  /// Every product, hidden ones included: `products_admin_all` lets staff read
  /// what customers cannot see.
  @override
  Future<List<AdminCatalogueProduct>> catalogue() async {
    final rows = await _client
        .from('products')
        .select(
          'id, slug, name_en, is_active, kind, sort_order, '
          'supplier:suppliers ( code ), '
          'variants:product_variants ( id, sku, label_en, price_usd, cost_usd, '
          'is_active, sort_order )',
        )
        .order('sort_order', ascending: true)
        .order('name_en', ascending: true);

    return rows.map(adminCatalogueProductFromJson).toList();
  }

  @override
  Future<void> setProductActive({
    required int productId,
    required bool active,
  }) {
    return _voidRpc('admin_product_set_active', {
      'p_product_id': productId,
      'p_active': active,
    });
  }

  @override
  Future<void> setVariantPrice({
    required int variantId,
    required double priceUsd,
  }) {
    return _voidRpc('admin_variant_set_price', {
      'p_variant_id': variantId,
      'p_price_usd': priceUsd,
    });
  }

  @override
  Future<String?> resolveBanner({
    required int productId,
    String? url,
    bool force = false,
  }) async {
    final response = await _client.functions.invoke(
      'game-banner',
      body: {
        'productId': productId,
        if (url != null && url.isNotEmpty) 'url': url,
        if (force) 'force': true,
      },
    );

    final data = (response.data as Map?)?.cast<String, dynamic>() ?? const {};
    if (response.status < 200 ||
        response.status >= 300 ||
        data['error'] != null) {
      throw OrderException(
        data['error'] as String? ?? 'http_${response.status}',
        detail: data['detail'] as String?,
      );
    }
    return data['banner_url'] as String?;
  }

  @override
  Future<List<SupplierQueueItem>> supplierQueue({int limit = 50}) async {
    try {
      final result = await _client.rpc(
        'admin_supplier_queue',
        params: {'p_limit': limit},
      );
      return ((result as List?) ?? const [])
          .map(
            (e) =>
                supplierQueueItemFromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<List<StaffMember>> staffMembers() async {
    final result = await _client.rpc('admin_list_staff');
    return ((result as List?) ?? const [])
        .map((e) => staffMemberFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<StaffMember> findUserByEmail(String email) async {
    final result = await _jsonRpc('admin_find_user', {'p_email': email});
    return staffMemberFromJson(result);
  }

  @override
  Future<void> setRole({required String userId, required String role}) {
    return _voidRpc('admin_set_role', {'p_user_id': userId, 'p_role': role});
  }

  @override
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
    return rows.map(supportTicketFromJson).toList();
  }

  @override
  Future<void> setSupportStatus({
    required int ticketId,
    String? status,
    String? note,
    String? priority,
  }) {
    return _voidRpc('admin_support_set_status', {
      'p_ticket_id': ticketId,
      'p_status': status,
      'p_note': note,
      'p_priority': priority,
    });
  }

  Future<void> _voidRpc(String name, Map<String, dynamic> params) async {
    try {
      await _client.rpc(name, params: params);
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
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
      throw orderExceptionFrom(error);
    }
  }
}
