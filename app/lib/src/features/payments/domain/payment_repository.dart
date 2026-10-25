import 'payment_entities.dart';

/// Talks to the payment Edge Functions. The PayWay API key never leaves the
/// server, so the app only ever receives a QR string and a status.
abstract class PaymentRepository {
  Future<KhqrPayment> initKhqr(String orderId);

  /// Opens a hosted card checkout through `dodo-checkout`.
  Future<CardCheckout> initCard(String orderId);

  Future<SettleResult> verify(String orderId);

  /// Server-side check against Dodo. Same answer shape as [verify], so the
  /// sheet can render it with the same state machine.
  Future<SettleResult> verifyCard(String orderId);

  /// Polls Dodo until the card payment is approved, declined, or the deadline
  /// passes. Settling happens on the server, never from the browser redirect.
  Stream<SettleResult> pollCard(
    String orderId, {
    Duration interval,
    required DateTime deadline,
  });

  /// Polls until the transaction is approved, declined, or the deadline passes.
  Stream<SettleResult> poll(
    String orderId, {
    Duration interval,
    required DateTime deadline,
  });
}
