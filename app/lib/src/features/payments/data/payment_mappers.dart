import '../domain/payment_entities.dart';

KhqrPayment khqrPaymentFromJson(Map<String, dynamic> json) => KhqrPayment(
  tranId: json['tran_id'] as String? ?? '',
  qrString: json['qr_string'] as String? ?? '',
  totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
  expiresAt:
      DateTime.tryParse(json['expires_at'] as String? ?? '') ??
      DateTime.now().add(const Duration(minutes: 15)),
  deepLink: json['abapay_deeplink'] as String?,
  checkoutQrUrl: json['checkout_qr_url'] as String?,
);

CardCheckout cardCheckoutFromJson(Map<String, dynamic> json) => CardCheckout(
  sessionId: json['session_id'] as String? ?? '',
  checkoutUrl: json['checkout_url'] as String? ?? '',
  totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
  expiresAt:
      DateTime.tryParse(json['expires_at'] as String? ?? '') ??
      DateTime.now().add(const Duration(minutes: 24)),
);
