import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class PaymentException implements Exception {
  PaymentException(this.code, {this.detail});

  final String code;
  final Object? detail;

  @override
  String toString() => 'PaymentException($code)';
}

class SettleResult {
  const SettleResult({
    required this.ok,
    required this.state,
    this.orderStatus,
    this.reason,
  });

  /// True once the transaction is APPROVED and the order has been settled.
  final bool ok;

  /// APPROVED / PENDING / DECLINED / EXPIRED / UNKNOWN
  final String state;
  final String? orderStatus;
  final String? reason;

  bool get isFinal => state == 'DECLINED' || state == 'CANCELLED';
  bool get isWaiting => state == 'PENDING';
}

/// Talks to the two Edge Functions. The PayWay API key never leaves the server,
/// so the app only ever receives a QR string and a status.
class PaymentRepository {
  PaymentRepository(this._client);

  final SupabaseClient _client;

  Future<KhqrPayment> initKhqr(String orderId) async {
    final response = await _invoke('payway-init', {'orderId': orderId});
    return KhqrPayment.fromJson(response);
  }

  Future<SettleResult> verify(String orderId) async {
    // A 202 means "still pending", which is a normal answer here.
    final result = await _client.functions.invoke(
      'payway-verify',
      body: {'orderId': orderId},
    );

    final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
    return SettleResult(
      ok: data['ok'] as bool? ?? false,
      state: data['state'] as String? ?? 'UNKNOWN',
      orderStatus: data['order_status'] as String?,
      reason: data['reason'] as String?,
    );
  }

  /// Polls until the transaction is approved, declined, or the deadline passes.
  Stream<SettleResult> poll(
    String orderId, {
    Duration interval = const Duration(seconds: 3),
    required DateTime deadline,
  }) async* {
    while (DateTime.now().isBefore(deadline)) {
      SettleResult result;
      try {
        result = await verify(orderId);
      } catch (_) {
        // Network blips must not kill the sheet; the next tick retries.
        await Future<void>.delayed(interval);
        continue;
      }

      yield result;
      if (result.ok || result.isFinal) return;

      await Future<void>.delayed(interval);
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke(name, body: body);
    final data = (response.data as Map?)?.cast<String, dynamic>() ?? const {};

    if (response.status < 200 ||
        response.status >= 300 ||
        data['error'] != null) {
      throw PaymentException(
        data['error'] as String? ?? 'http_${response.status}',
        detail: data['detail'],
      );
    }
    return data;
  }
}
