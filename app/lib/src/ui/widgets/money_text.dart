import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

/// A price, formatted in one place.
///
/// Lining figures keep a column of these aligned down the decimal point, which
/// three separate hand-built `Text`s per row never managed. Set [showKhr] where
/// the buyer quotes in riel; the equivalent appears only when the store has a
/// positive exchange rate configured.
class MoneyText extends ConsumerWidget {
  const MoneyText(
    this.value, {
    this.style,
    this.showKhr = false,
    this.khrStyle,
    this.alignment = TextAlign.start,
    this.semanticsPrefix,
    super.key,
  });

  final num value;
  final TextStyle? style;
  final bool showKhr;
  final TextStyle? khrStyle;
  final TextAlign alignment;

  /// Read before the amount, e.g. a row label, so a screen reader announces
  /// "Total, $12.50" rather than a bare number.
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = style ?? AppType.bodyStrong(context);
    final tabular = base.copyWith(fontFeatures: Money.tabular);

    final usd = Text(money(value), style: tabular, textAlign: alignment);

    final rate = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.usdToKhr ?? 0),
    );

    final body = !showKhr || rate <= 0
        ? usd
        : Column(
            crossAxisAlignment: alignment == TextAlign.end
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              usd,
              Text(
                Money.khr(value, rate),
                style: (khrStyle ?? AppType.caption(context)).copyWith(
                  fontFeatures: Money.tabular,
                ),
                textAlign: alignment,
              ),
            ],
          );

    if (semanticsPrefix == null) return body;

    return Semantics(
      label: '$semanticsPrefix ${money(value)}',
      excludeSemantics: true,
      child: body,
    );
  }
}

/// A label/value row for a money detail, so a confirm dialog and an order
/// summary show the same shape.
class MoneyRow extends StatelessWidget {
  const MoneyRow({
    required this.label,
    required this.value,
    this.emphasised = false,
    super.key,
  });

  final String label;
  final Widget value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasised
                  ? AppType.bodyStrong(context)
                  : AppType.bodySmall(context),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          value,
        ],
      ),
    );
  }
}
