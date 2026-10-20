import 'dart:ui' show FontFeature;

import 'package:intl/intl.dart';

/// Currency formatting. Every price in the app comes from here, so a currency
/// or a decimal rule never drifts between screens.
///
/// Digits stay Latin in both currencies: that is what the Cambodian market
/// quotes, and mixing Khmer numerals into money is what made admin rows read as
/// two numeral systems side by side. Khmer numerals belong in prose, not prices.
class Money {
  const Money._();

  static final _usd = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final _khr = NumberFormat.decimalPattern('en_US');

  /// US dollars, always two decimals.
  static String usd(num value) => _usd.format(value);

  /// Riel, rounded to the nearest ៛1 at the given rate.
  static String khr(num value, num rate) =>
      '៛${_khr.format((value * rate).round())}';

  /// Both currencies on one line. Use where the buyer quotes in riel: the
  /// checkout total, the wallet, the order confirmation.
  static String both(num value, num rate) =>
      '${usd(value)} · ${khr(value, rate)}';

  /// Lining figures of equal width, so a money column aligns down the decimal
  /// point instead of ragging. Apply to the style of any table cell holding a
  /// price, cost or margin.
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];
}

/// Shorthand for [Money.usd], kept because it reads well at the call site.
String money(num value) => Money.usd(value);

/// Shorthand for [Money.khr]. Prefer [Money.both] on buyer-facing screens.
String riel(num value, num rate) => Money.khr(value, rate);

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
