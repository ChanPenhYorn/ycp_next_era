import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/order_entities.dart';
import '../domain/order_exception.dart';
import '../domain/order_repository.dart';
import 'order_mappers.dart';

const _orderColumns =
    'id, order_no, status, subtotal_usd, discount_usd, total_usd, '
    'coupon_code, expires_at, created_at, paid_at, manual_payment_requested_at, '
    'items:order_items ( id, product_name, variant_label, qty, unit_price_usd, '
    'line_total_usd, delivery_status, variant:product_variants ( product_id ) )';

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CreatedOrder> createOrder({
    required List<OrderItemRequest> items,
    String? coupon,
    Map<String, String> fields = const {},
    String? email,
    String? note,
  }) async {
    try {
      final result = await _client.rpc(
        'create_order',
        params: {
          'p_items': [
            for (final item in items)
              {'variant_id': item.variantId, 'qty': item.qty},
          ],
          'p_coupon': coupon,
          'p_fields': fields,
          'p_email': email,
          'p_note': note,
        },
      );

      final map = (result as Map).cast<String, dynamic>();
      return CreatedOrder(
        orderId: map['order_id'] as String,
        orderNo: map['order_no'] as String,
        subtotalUsd: (map['subtotal_usd'] as num).toDouble(),
        discountUsd: (map['discount_usd'] as num).toDouble(),
        totalUsd: (map['total_usd'] as num).toDouble(),
        expiresInMinutes: (map['expires_in_minutes'] as num?)?.toInt() ?? 15,
      );
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<(bool ok, double discount, String? reason)> validateCoupon(
    String code,
    double subtotal,
  ) async {
    final result = await _client.rpc(
      'validate_coupon',
      params: {'p_code': code, 'p_subtotal': subtotal},
    );
    final map = (result as Map).cast<String, dynamic>();
    final ok = map['ok'] as bool? ?? false;
    return (
      ok,
      (map['discount_usd'] as num?)?.toDouble() ?? 0,
      map['reason'] as String?,
    );
  }

  @override
  Future<List<Order>> listOrders({int limit = 30}) async {
    final rows = await _client
        .from('orders')
        .select(_orderColumns)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(orderFromJson).toList();
  }

  @override
  Future<Order?> getOrder(String orderId) async {
    final row = await _client
        .from('orders')
        .select(_orderColumns)
        .eq('id', orderId)
        .maybeSingle();

    return row == null ? null : orderFromJson(row);
  }

  /// The RPC re-checks ownership and paid status, and the payloads stay
  /// encrypted at rest until this exact call.
  @override
  Future<Map<int, List<String>>> reveal(String orderId) async {
    try {
      final result = await _client.rpc(
        'reveal_order',
        params: {'p_order_id': orderId},
      );

      final out = <int, List<String>>{};
      for (final item in (result as List)) {
        final map = (item as Map).cast<String, dynamic>();
        out[(map['item_id'] as num)
            .toInt()] = ((map['payloads'] as List?) ?? const [])
            .map((p) => p.toString())
            .toList();
      }
      return out;
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<WalletPaymentResult> payWithWallet(String orderId) async {
    try {
      final result = await _client.rpc(
        'pay_order_with_wallet',
        params: {'p_order_id': orderId},
      );
      final map = (result as Map).cast<String, dynamic>();
      return WalletPaymentResult(
        ok: map['ok'] as bool? ?? false,
        reason: map['reason'] as String?,
        balance: (map['balance'] as num?)?.toDouble(),
        required: (map['required'] as num?)?.toDouble(),
      );
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<DateTime> requestManualPayment(String orderId, {String? note}) async {
    try {
      final result = await _client.rpc(
        'request_manual_payment',
        params: {'p_order_id': orderId, 'p_note': note},
      );

      final map = (result as Map).cast<String, dynamic>();
      return DateTime.tryParse(map['expires_at'] as String? ?? '') ??
          DateTime.now();
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<CreatedOrder> createWalletTopup({
    required double amountUsd,
    String? email,
  }) async {
    try {
      final result = await _client.rpc(
        'create_wallet_topup',
        params: {'p_amount_usd': amountUsd, 'p_email': email},
      );
      final map = (result as Map).cast<String, dynamic>();
      return CreatedOrder(
        orderId: map['order_id'] as String,
        orderNo: map['order_no'] as String,
        subtotalUsd: (map['total_usd'] as num).toDouble(),
        discountUsd: 0,
        totalUsd: (map['total_usd'] as num).toDouble(),
        expiresInMinutes: (map['expires_in_minutes'] as num?)?.toInt() ?? 15,
      );
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }

  @override
  Future<List<WalletTransaction>> walletTransactions({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('wallet_transactions')
        .select(
          'id, kind, amount_usd, balance_after, note, order_id, created_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(walletTransactionFromJson).toList();
  }

  /// RLS enforces that only a buyer with a delivered order containing this
  /// product can insert, and that `is_approved` stays false.
  @override
  Future<void> submitReview({
    required int productId,
    required String orderId,
    required int rating,
    String? body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw OrderException('auth_required');

    try {
      await _client.from('reviews').insert({
        'product_id': productId,
        'user_id': userId,
        'order_id': orderId,
        'rating': rating,
        'body': (body == null || body.trim().isEmpty) ? null : body.trim(),
      });
    } on PostgrestException catch (error) {
      // A duplicate hits the (product_id, user_id, order_id) unique index.
      if (error.code == '23505') {
        throw OrderException('review_exists');
      }
      throw OrderException('review_rejected', detail: error.message);
    }
  }

  @override
  Future<Set<int>> reviewedProductIds(String orderId) async {
    final rows = await _client
        .from('reviews')
        .select('product_id')
        .eq('order_id', orderId);

    return rows.map((row) => (row['product_id'] as num).toInt()).toSet();
  }
}
