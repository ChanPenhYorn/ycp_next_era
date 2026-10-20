import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../features/orders/domain/order_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';
import 'widgets/money_text.dart';

/// Refunds that were agreed but not yet paid back.
///
/// Two states exist on purpose: `refund_pending` says staff decided, `refunded`
/// says the money actually left. Collapsing them is how a store reports a
/// refund it never made — so this screen moves nothing and only records the
/// reversal a person has already done in the bank.
class AdminRefundsPage extends ConsumerWidget {
  const AdminRefundsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final queue = ref.watch(adminRefundQueueProvider);

    void refresh() {
      ref.invalidate(adminRefundQueueProvider);
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminOverviewProvider);
    }

    return AdminGate(
      child: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminHeader(
              title: l10n.adminRefundsTitle,
              subtitle: l10n.adminRefundNote,
              onBack: () => context.go('/admin'),
              action: IconButton(
                tooltip: l10n.retry,
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: refresh,
              ),
            ),
            const SizedBox(height: 14),
            AsyncValueView(
              value: queue,
              onRetry: refresh,
              builder: (rows) => rows.isEmpty
                  ? AdminEmpty(l10n.adminRefundsEmpty)
                  : Column(
                      children: [
                        for (final row in rows)
                          _RefundCard(order: row, onDone: refresh),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _RefundCard extends ConsumerStatefulWidget {
  const _RefundCard({required this.order, required this.onDone});

  final AdminOrderSummary order;
  final VoidCallback onDone;

  @override
  ConsumerState<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends ConsumerState<_RefundCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final order = widget.order;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  order.orderNo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                money(order.totalUsd),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warn,
                ),
              ),
            ],
          ),
          if (order.refundReason != null && order.refundReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              order.refundReason!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.ink200,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            adminStamp(order.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _record,
                  child: Text(l10n.adminMarkRefunded),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.go('/admin/orders/${order.id}'),
                child: Text(l10n.adminTicketOpenOrder),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _record() async {
    final l10n = AppL10n.of(context);
    final order = widget.order;
    final reference = await askAdminText(
      context,
      title: l10n.adminMarkRefunded,
      label: l10n.adminRefundReference,
      helper: l10n.adminRefundReferenceHint,
      confirmLabel: l10n.adminMarkRefunded,
      // Recording a refund is money-affecting and cannot be taken back from this
      // screen, so the order, the amount and the fact that no money moves here
      // are all on screen before the field.
      details: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoneyRow(
            label: l10n.orderNo,
            value: Text(order.orderNo, style: AppType.bodyStrong(context)),
          ),
          MoneyRow(
            label: l10n.total,
            value: Text(
              money(order.totalUsd),
              style: AppType.bodyStrong(context),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(l10n.adminRefundNote, style: AppType.bodySmall(context)),
        ],
      ),
    );
    if (reference == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .markRefunded(
            orderId: widget.order.id,
            reference: reference.isEmpty ? null : reference,
          );

      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        result['ok'] == true
            ? l10n.adminRefundRecorded
            : l10n.somethingWentWrong,
      );
      widget.onDone();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        error.code == 'not_authorized'
            ? l10n.adminOnly
            : l10n.somethingWentWrong,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
