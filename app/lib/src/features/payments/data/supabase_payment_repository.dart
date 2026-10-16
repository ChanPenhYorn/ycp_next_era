import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/payment_entities.dart';
import '../domain/payment_exception.dart';
import '../domain/payment_repository.dart';
import 'payment_mappers.dart';

class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<KhqrPayment> initKhqr(String orderId) async {
    final response = await _invoke('payway-init', {'orderId': orderId});
    return khqrPaymentFromJson(response);
  }

  @override
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

  @override
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
