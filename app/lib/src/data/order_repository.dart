import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Thrown for the business-rule failures the database raises by name, so the UI
/// can show the right message instead of a raw Postgres string.
class OrderException implements Exception {
  OrderException(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() =>
      'OrderException($code${detail == null ? '' : ':$detail'})';
}

class Profile {
  const Profile({
    required this.id,
    required this.walletBalance,
    required this.coins,
    required this.displayName,
    this.role = 'customer',
    this.telegramChatId,
    this.telegramUsername,
  });

  final String id;
  final double walletBalance;
  final int coins;
  final String? displayName;

  /// `profiles.role`. Read through the self-select policy, which is also what
  /// gates the staff screens: the database re-checks it on every RPC, so this
  /// only decides what the app bothers to draw.
  final String role;

  final int? telegramChatId;
  final String? telegramUsername;

  bool get telegramLinked => telegramChatId != null;
  bool get isStaff => role == 'staff' || role == 'admin';
}

/// Returned by create_telegram_link_code.
class TelegramLinkCode {
  const TelegramLinkCode({
    required this.code,
    required this.expiresInMinutes,
    this.botUsername,
    this.deepLink,
  });

  final String code;
  final int expiresInMinutes;
  final String? botUsername;
  final String? deepLink;

  factory TelegramLinkCode.fromJson(Map<String, dynamic> json) =>
      TelegramLinkCode(
        code: json['code'] as String? ?? '',
        expiresInMinutes: (json['expires_in_minutes'] as num?)?.toInt() ?? 15,
        botUsername: json['bot_username'] as String?,
        deepLink: json['deep_link'] as String?,
      );
}

class OrderRepository {
  OrderRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> profile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select(
          'id, wallet_balance, coins, display_name, role, telegram_chat_id, telegram_username',
        )
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    return Profile(
      id: row['id'] as String,
      walletBalance: (row['wallet_balance'] as num?)?.toDouble() ?? 0,
      coins: (row['coins'] as num?)?.toInt() ?? 0,
      displayName: row['display_name'] as String?,
      role: row['role'] as String? ?? 'customer',
      telegramChatId: (row['telegram_chat_id'] as num?)?.toInt(),
      telegramUsername: row['telegram_username'] as String?,
    );
  }

  // -------------------------------------------------------------------------
  // Telegram linking
  //
  // Only the webhook can set telegram_chat_id: profiles grants the app update
  // rights on display_name, phone and locale and nothing else. That is why
  // unlinking lives in the bot (/unlink) rather than here.
  // -------------------------------------------------------------------------

  Future<TelegramLinkCode> createTelegramLinkCode() async {
    try {
      final result = await _client.rpc('create_telegram_link_code');
      return TelegramLinkCode.fromJson((result as Map).cast<String, dynamic>());
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
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
          'coupon_code, expires_at, created_at, paid_at, manual_payment_requested_at, '
          'items:order_items ( id, product_name, variant_label, qty, unit_price_usd, '
          'line_total_usd, delivery_status, variant:product_variants ( product_id ) )',
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
          'coupon_code, expires_at, created_at, paid_at, manual_payment_requested_at, '
          'items:order_items ( id, product_name, variant_label, qty, unit_price_usd, '
          'line_total_usd, delivery_status, variant:product_variants ( product_id ) )',
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
        out[(map['item_id'] as num)
            .toInt()] = ((map['payloads'] as List?) ?? const [])
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

  // -------------------------------------------------------------------------
  // Wallet
  // -------------------------------------------------------------------------

  /// Creates a pending order of kind 'wallet_topup'. Settling it credits the
  /// wallet instead of delivering goods, so top-ups reuse the whole payment
  /// pipeline and inherit its idempotency.
  /// Requests staff check a bank transfer. Returns when the order now expires,
  /// which the RPC has extended so the money can arrive before housekeeping
  /// cancels the order.
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
      throw _mapError(error);
    }
  }

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
      throw _mapError(error);
    }
  }

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

    return rows.map(WalletTransaction.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // Reviews
  // -------------------------------------------------------------------------

  /// RLS enforces that only a buyer with a delivered order containing this
  /// product can insert, and that `is_approved` stays false.
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

  /// Which products in this order the buyer has already reviewed.
  Future<Set<int>> reviewedProductIds(String orderId) async {
    final rows = await _client
        .from('reviews')
        .select('product_id')
        .eq('order_id', orderId);

    return rows.map((row) => (row['product_id'] as num).toInt()).toSet();
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
