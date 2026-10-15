import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Thrown for the business-rule failures the database raises by name, so the UI
/// can show the right message instead of a raw Postgres string.
class OrderException implements Exception {
  OrderException(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() => 'OrderException($code${detail == null ? '' : ':$detail'})';
}

class Profile {
  const Profile({
    required this.id,
    required this.walletBalance,
    required this.coins,
    required this.displayName,
  });

  final String id;
  final double walletBalance;
  final int coins;
  final String? displayName;
}

class OrderRepository {
  OrderRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> profile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select('id, wallet_balance, coins, display_name')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    return Profile(
      id: row['id'] as String,
      walletBalance: (row['wallet_balance'] as num?)?.toDouble() ?? 0,
      coins: (row['coins'] as num?)?.toInt() ?? 0,
      displayName: row['display_name'] as String?,
    );
  }

  /// Creates a pending order. Prices, stock and coupon rules are all resolved
  /// server-side inside the `create_order` function.
  Future<CreatedOrder> createOrder({
    required List<CartLine> lines,
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
            for (final line in lines)
              {'variant_id': line.variantId, 'qty': line.qty},
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
      throw _mapError(error);
    }
  }

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

  Future<List<Order>> listOrders({int limit = 30}) async {
    final rows = await _client
        .from('orders')
        .select(
          'id, order_no, status, subtotal_usd, discount_usd, total_usd, '
          'coupon_code, expires_at, created_at, paid_at, '
          'items:order_items ( id, product_name, variant_label, qty, unit_price_usd, '
          'line_total_usd, delivery_status )',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(Order.fromJson).toList();
  }

  Future<Order?> getOrder(String orderId) async {
    final row = await _client
        .from('orders')
        .select(
          'id, order_no, status, subtotal_usd, discount_usd, total_usd, '
          'coupon_code, expires_at, created_at, paid_at, '
          'items:order_items ( id, product_name, variant_label, qty, unit_price_usd, '
          'line_total_usd, delivery_status )',
        )
        .eq('id', orderId)
        .maybeSingle();

    return row == null ? null : Order.fromJson(row);
  }

  /// Decrypted credentials. The RPC re-checks ownership and paid status, and
  /// the payloads stay encrypted at rest until this exact call.
  Future<Map<int, List<String>>> reveal(String orderId) async {
    try {
      final result = await _client.rpc(
        'reveal_order',
        params: {'p_order_id': orderId},
      );

      final out = <int, List<String>>{};
      for (final item in (result as List)) {
        final map = (item as Map).cast<String, dynamic>();
        out[(map['item_id'] as num).toInt()] = ((map['payloads'] as List?) ?? const [])
            .map((p) => p.toString())
            .toList();
      }
      return out;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

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
      throw _mapError(error);
    }
  }

  OrderException _mapError(PostgrestException error) {
    // `raise exception 'out_of_stock' using detail = sku`
    final raw = error.message.trim();
    final code = raw.split(RegExp(r'[\s:]')).first;
    return OrderException(code, detail: error.details?.toString());
  }
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
