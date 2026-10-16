import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shows where an order is on its way: waiting, paid, delivering, delivered.
/// Terminal states (failed, refunded, expired) carry their own chip, so this
/// renders nothing for them rather than a half-finished track.
class OrderProgress extends StatelessWidget {
  const OrderProgress({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final stage = switch (status) {
      OrderStatus.pending => 0,
      OrderStatus.paid => 1,
      OrderStatus.delivering => 2,
      OrderStatus.delivered => 3,
      _ => -1,
    };
    if (stage < 0) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);
    final steps = [
      l10n.statusPending,
      l10n.statusPaid,
      l10n.statusDelivering,
      l10n.statusDelivered,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Line(
                        done: i > 0 && i - 1 < stage,
                        hidden: i == 0,
                      ),
                    ),
                    _Node(done: i < stage, current: i == stage),
                    Expanded(
                      child: _Line(
                        done: i < stage,
                        hidden: i == steps.length - 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: i == stage ? FontWeight.w700 : FontWeight.w500,
                    color: i <= stage ? Colors.white : AppColors.ink400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.done, required this.current});

  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.accent
        : current
        ? AppColors.brand
        : AppColors.ink700;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: done || current ? color : AppColors.ink850,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: done
          ? const Icon(Icons.check, size: 13, color: AppColors.ink950)
          : null,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.done, required this.hidden});

  final bool done;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: hidden
          ? Colors.transparent
          : done
          ? AppColors.accent
          : AppColors.ink700,
    );
  }
}
