/// Thrown for the business-rule failures the backend raises by name, so the UI
/// can show the right message instead of a raw server string.
class OrderException implements Exception {
  OrderException(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() =>
      'OrderException($code${detail == null ? '' : ':$detail'})';
}
