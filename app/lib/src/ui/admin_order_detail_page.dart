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
import 'widgets/confirm_action.dart';
import 'widgets/status_chip.dart';

/// One order, with everything a person needs to act on it: the lines and their
/// supplier state, the payments, and the append-only history.
class AdminOrderDetailPage extends ConsumerWidget {
  const AdminOrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final detail = ref.watch(adminOrderDetailProvider(orderId));

    void refresh() {
      ref.invalidate(adminOrderDetailProvider(orderId));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminRefundQueueProvider);
      ref.invalidate(adminOverviewProvider);
    }

    return AdminGate(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminHeader(
            title: detail.maybeWhen(
              data: (value) => value?.summary.orderNo ?? l10n.adminOrdersTitle,
              orElse: () => l10n.adminOrdersTitle,
            ),
            onBack: () => context.go('/admin/orders'),
            action: IconButton(
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: refresh,
            ),
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: detail,
            onRetry: refresh,
            builder: (data) => data == null
                ? AdminEmpty(l10n.somethingWentWrong)
                : _Body(detail: data, onChanged: refresh),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.detail, required this.onChanged});

  final AdminOrderDetail detail;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final detail = widget.detail;
    final order = detail.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSection(
          title: l10n.adminSummary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OrderStatusChip(status: order.status),
                  const SizedBox(width: 8),
                  Text(
                    money(order.totalUsd),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _kv(
                l10n.adminKind,
                order.kind == 'wallet_topup'
                    ? l10n.adminKindWalletTopup
                    : l10n.adminKindPurchase,
              ),
              _kv(l10n.adminCreatedAt, adminStamp(order.createdAt)),
              if (order.paidAt != null)
                _kv(l10n.adminPaidAt, adminStamp(order.paidAt!)),
              if (order.refundReason != null)
                _kv(l10n.adminRefundReason, order.refundReason!),
              if (order.contactEmail != null)
                _kv(l10n.adminBuyerTitle, order.contactEmail!),
            ],
          ),
        ),
        if (detail.customerFields.isNotEmpty || detail.customerNote != null)
          AdminSection(
            title: l10n.adminBuyerFields,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in detail.customerFields.entries)
                  _kv(entry.key, entry.value),
                if (detail.customerNote != null)
                  _kv(l10n.adminCustomerNote, detail.customerNote!),
              ],
            ),
          ),
        AdminSection(
          title: l10n.adminItemsTitle,
          child: Column(
            children: [
              for (final item in detail.items)
                _ItemRow(item: item, busy: _busy, onResolve: _resolve),
            ],
          ),
        ),
        if (detail.payments.isNotEmpty)
          AdminSection(
            title: l10n.adminPaymentsTitle,
            child: Column(
              children: [
                for (final payment in detail.payments)
                  _PaymentRow(payment: payment),
              ],
            ),
          ),
        AdminSection(
          title: l10n.adminTimeline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final event in detail.events) _EventRow(event: event),
            ],
          ),
        ),
        _Actions(
          order: order,
          busy: _busy,
          onAgree: _agreeRefund,
          onRecord: _recordRefund,
        ),
      ],
    );
  }

  Widget _kv(String key, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            key,
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

  Future<void> _resolve(AdminOrderItem item, String delivery) async {
    final l10n = AppL10n.of(context);

    // Failing a line is not a status change like the others: it is the point at
    // which someone has to decide whether the buyer gets their money back, and
    // it used to sit as a low-emphasis text button beside "Mark delivered" and
    // apply on one tap.
    if (delivery == 'failed') {
      final confirmed = await confirmAction(
        context,
        title: l10n.adminResolveFailedTitle,
        confirmLabel: l10n.adminResolveFailed,
        message: l10n.adminResolveFailedBody,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveItem(itemId: item.id, delivery: delivery);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
    } on OrderException catch (error) {
      _fail(_humanise(error.code));
    } catch (_) {
      _fail(AppL10n.of(context).somethingWentWrong);
    }
  }

  Future<void> _agreeRefund() async {
    final l10n = AppL10n.of(context);
    final reason = await askAdminText(
      context,
      title: l10n.adminAgreeRefund,
      label: l10n.adminRefundReason,
      mandatory: true,
    );
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setRefundPending(orderId: widget.detail.summary.id, reason: reason);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged();
    } on OrderException catch (error) {
      _fail(_humanise(error.code));
    } catch (_) {
      _fail(l10n.somethingWentWrong);
    }
  }

  Future<void> _recordRefund() async {
    final l10n = AppL10n.of(context);
    final reference = await askAdminText(
      context,
      title: l10n.adminMarkRefunded,
      label: l10n.adminRefundReference,
      helper: l10n.adminRefundReferenceHint,
      confirmLabel: l10n.adminMarkRefunded,
    );
    if (reference == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .markRefunded(
            orderId: widget.detail.summary.id,
            reference: reference.isEmpty ? null : reference,
          );
      if (!mounted) return;
      setState(() => _busy = false);

      // The RPC reports an order that is not refund_pending instead of raising.
      if (result['ok'] == true) {
        _toast(l10n.adminRefundRecorded);
      } else {
        _toast(l10n.somethingWentWrong);
      }
      widget.onChanged();
    } on OrderException catch (error) {
      _fail(_humanise(error.code));
    } catch (_) {
      _fail(l10n.somethingWentWrong);
    }
  }

  String _humanise(String code) {
    final l10n = AppL10n.of(context);
    return switch (code) {
      'not_authorized' => l10n.adminOnly,
      'order_not_found' => l10n.somethingWentWrong,
      'item_not_found' => l10n.somethingWentWrong,
      _ => l10n.somethingWentWrong,
    };
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(message);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The database's own word for a line's state. Kept rather than translated:
/// it is the value the supplier worker writes and the queue filters on.
String _deliveryWord(DeliveryStatus status) => switch (status) {
  DeliveryStatus.pending => 'pending',
  DeliveryStatus.delivered => 'delivered',
  DeliveryStatus.failed => 'failed',
  DeliveryStatus.manualWaiting => 'manual_waiting',
};

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.busy,
    required this.onResolve,
  });

  final AdminOrderItem item;
  final bool busy;
  final void Function(AdminOrderItem item, String delivery) onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final done = item.deliveryStatus == DeliveryStatus.delivered;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.productName} · ${item.variantLabel}',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              Text(
                '${item.qty} × ${money(item.unitPriceUsd)}',
                style: const TextStyle(fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _deliveryWord(item.deliveryStatus),
                style: TextStyle(
                  fontSize: 11,
                  color: done ? AppColors.accent : AppColors.warn,
                ),
              ),
              if (item.supplierAttempts > 0)
                Text(
                  '${item.supplierAttempts} ×',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink400),
                ),
              if (item.supplierRef != null)
                Text(
                  item.supplierRef!,
                  style: const TextStyle(fontSize: 11, color: AppColors.ink400),
                ),
            ],
          ),
          // The supplier's own words. Staff need them to decide whether to
          // retry or to deliver by hand, and they are the same words the worker
          // wrote into the queue.
          if (item.supplierLastError != null &&
              item.supplierLastError!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.supplierLastError!,
              style: const TextStyle(fontSize: 10.5, color: AppColors.danger),
            ),
          ],
          if (!done) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => onResolve(item, 'delivered'),
                  child: Text(l10n.adminResolveDelivered),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: busy ? null : () => onResolve(item, 'failed'),
                  child: Text(l10n.adminResolveFailed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final AdminPaymentRow payment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Raw database words on purpose: these are the values that appear
              // in the bank statement and the logs.
              Text(
                '${payment.provider} · ${payment.status}',
                style: const TextStyle(fontSize: 12),
              ),
              if (payment.providerRef != null)
                SelectableText(
                  payment.providerRef!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.ink400,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(payment.amountUsd),
              style: const TextStyle(fontSize: 12),
            ),
            if (payment.verifiedAt != null)
              Text(
                adminStamp(payment.verifiedAt!),
                style: const TextStyle(fontSize: 10, color: AppColors.ink400),
              ),
          ],
        ),
      ],
    ),
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final AdminOrderEvent event;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            adminStamp(event.createdAt),
            style: const TextStyle(fontSize: 10.5, color: AppColors.ink400),
          ),
        ),
        Expanded(
          child: Text(
            '${event.event} · ${event.actor}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.busy,
    required this.onAgree,
    required this.onRecord,
  });

  final AdminOrderSummary order;
  final bool busy;
  final VoidCallback onAgree;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // 'pending' has taken no money to return, and expired/refunded are terminal.
    final canAgree = const [
      OrderStatus.paid,
      OrderStatus.delivering,
      OrderStatus.delivered,
      OrderStatus.failed,
    ].contains(order.status);

    if (!canAgree && order.status != OrderStatus.refundPending) {
      return const SizedBox.shrink();
    }

    return AdminSection(
      title: l10n.adminRefundsTitle,
      subtitle: l10n.adminRefundNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canAgree)
            FilledButton(
              onPressed: busy ? null : onAgree,
              child: Text(l10n.adminAgreeRefund),
            )
          else
            FilledButton(
              onPressed: busy ? null : onRecord,
              child: Text(l10n.adminMarkRefunded),
            ),
        ],
      ),
    );
  }
}
