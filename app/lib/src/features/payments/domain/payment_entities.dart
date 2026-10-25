// Payment entities as the app uses them. Pure Dart: no JSON, no SDK types.
// Parsing from the functions response lives in `../data/payment_mappers.dart`.

/// The KHQR the buyer scans, as payway-init returns it.
class KhqrPayment {
  const KhqrPayment({
    required this.tranId,
    required this.qrString,
    required this.totalUsd,
    required this.expiresAt,
    this.deepLink,
    this.checkoutQrUrl,
  });

  final String tranId;
  final String qrString;
  final double totalUsd;
  final DateTime expiresAt;
  final String? deepLink;
  final String? checkoutQrUrl;
}

/// The hosted card checkout, as `dodo-checkout` returns it.
///
/// It carries a URL, never a secret: the buyer finishes on Dodo's page and the
/// app only learns the outcome from the server.
class CardCheckout {
  const CardCheckout({
    required this.sessionId,
    required this.checkoutUrl,
    required this.totalUsd,
    required this.expiresAt,
  });

  final String sessionId;
  final String checkoutUrl;
  final double totalUsd;
  final DateTime expiresAt;

  Uri get uri => Uri.parse(checkoutUrl);
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
