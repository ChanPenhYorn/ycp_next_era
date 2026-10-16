import 'order_entities.dart';

/// Orders, wallet and reviews for the signed-in buyer. Business-rule failures
/// are thrown as [OrderException].
abstract class OrderRepository {
  /// Creates a pending order. Prices, stock and coupon rules are all resolved
  /// server-side.
  Future<CreatedOrder> createOrder({
    required List<OrderItemRequest> items,
    String? coupon,
    Map<String, String> fields = const {},
    String? email,
    String? note,
  });

  Future<(bool ok, double discount, String? reason)> validateCoupon(
    String code,
    double subtotal,
  );

  Future<List<Order>> listOrders({int limit = 30});

  Future<Order?> getOrder(String orderId);

  /// Decrypted credentials, keyed by order line id.
  Future<Map<int, List<String>>> reveal(String orderId);

  Future<WalletPaymentResult> payWithWallet(String orderId);

  /// Requests staff check a bank transfer. Returns when the order now expires,
  /// which the server has extended so the money can arrive before housekeeping
  /// cancels the order.
  Future<DateTime> requestManualPayment(String orderId, {String? note});

  /// Creates a pending order of kind 'wallet_topup'. Settling it credits the
  /// wallet instead of delivering goods, so top-ups reuse the whole payment
  /// pipeline and inherit its idempotency.
  Future<CreatedOrder> createWalletTopup({
    required double amountUsd,
    String? email,
  });

  Future<List<WalletTransaction>> walletTransactions({int limit = 50});

  Future<void> submitReview({
    required int productId,
    required String orderId,
    required int rating,
    String? body,
  });

  /// Which products in this order the buyer has already reviewed.
  Future<Set<int>> reviewedProductIds(String orderId);
}
