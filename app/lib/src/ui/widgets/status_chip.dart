import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final (label, color) = switch (status) {
      OrderStatus.pending => (l10n.statusPending, AppColors.warn),
      OrderStatus.paid => (l10n.statusPaid, AppColors.brand),
      OrderStatus.delivering => (l10n.statusDelivering, AppColors.brand),
      OrderStatus.delivered => (l10n.statusDelivered, AppColors.accent),
      OrderStatus.failed => (l10n.statusFailed, AppColors.danger),
      OrderStatus.refunded => (l10n.statusRefunded, AppColors.ink400),
      OrderStatus.expired => (l10n.statusExpired, AppColors.ink400),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
