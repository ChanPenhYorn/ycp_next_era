/// Thrown when a payment Edge Function refuses the request or errors.
class PaymentException implements Exception {
  PaymentException(this.code, {this.detail});

  final String code;
  final Object? detail;

  @override
  String toString() => 'PaymentException($code)';
}
