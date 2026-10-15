import 'package:intl/intl.dart';

final _usd = NumberFormat.currency(
  locale: 'en_US',
  symbol: r'$',
  decimalDigits: 2,
);
final _khr = NumberFormat.decimalPattern('en_US');

String money(num value) => _usd.format(value);
String riel(num value, num rate) => '៛${_khr.format((value * rate).round())}';

/// Returns null when there is no genuine discount to show.
int? discountPercent(num price, num? compareAt) {
  if (compareAt == null || compareAt <= price) return null;
  return (((compareAt - price) / compareAt) * 100).round();
}

String compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
