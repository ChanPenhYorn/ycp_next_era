import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'money_text.dart';

/// Confirms an action that moves money or changes a role, naming what is about
/// to change.
///
/// The admin audit found five actions that committed on a single tap —
/// confirming a bank transfer, changing a member's role, marking a refund
/// recorded — with no echo of the order number or the amount. This is the one
/// gate for all of them.
///
/// Returns true only when the operator confirmed. A false return is also what a
/// dismissed dialog gives, so callers cannot mistake a tap-away for consent.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,

  /// Order number, account, or any identifier the operator must read back.
  String? reference,
  String? referenceLabel,

  /// Pre-built amount widget, so the caller controls the currency shown.
  Widget? amount,
  String? amountLabel,

  /// Shown in the danger colour, above the buttons. Use for "cannot be undone".
  String? warning,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppL10n.of(dialogContext);

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: AppType.body(dialogContext)),
              const SizedBox(height: AppSpace.md),
            ],
            if (reference != null)
              MoneyRow(
                label: referenceLabel ?? l10n.orderNo,
                value: Text(
                  reference,
                  style: AppType.bodyStrong(
                    dialogContext,
                  ).copyWith(fontFeatures: Money.tabular),
                ),
              ),
            if (amount != null)
              MoneyRow(label: amountLabel ?? l10n.total, value: amount),
            if (warning != null) ...[
              const SizedBox(height: AppSpace.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warn,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      warning,
                      style: AppType.bodySmall(
                        dialogContext,
                      ).copyWith(color: AppColors.warn),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.close),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
