import 'payment_entities.dart';

/// Talks to the payment Edge Functions. The PayWay API key never leaves the
/// server, so the app only ever receives a QR string and a status.
abstract class PaymentRepository {
  Future<KhqrPayment> initKhqr(String orderId);

  Future<SettleResult> verify(String orderId);

  /// Polls until the transaction is approved, declined, or the deadline passes.
  Stream<SettleResult> poll(
    String orderId, {
    Duration interval,
    required DateTime deadline,
  });
}
