import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';
import 'widgets/status_chip.dart';

/// Every order, filterable by status and searchable by order number.
///
/// The list is real rows: `orders_select_own` includes `is_staff()`, so staff
/// read any order directly rather than through a reporting view that could
/// disagree with the order screen.
class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({this.initialStatus, super.key});

  final String? initialStatus;

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  late String? _status = widget.initialStatus;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final query = AdminOrderQuery(status: _status, search: _search.text);
    final orders = ref.watch(adminOrdersProvider(query));

    return AdminGate(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminHeader(
            title: l10n.adminOrdersTitle,
            onBack: () => context.go('/admin'),
            action: IconButton(
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => ref.invalidate(adminOrdersProvider(query)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.adminSearchOrder,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _search.clear();
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          AdminChipRow(
            selected: _status,
            onSelected: (value) => setState(() => _status = value),
            options: [
              AdminChipOption(null, l10n.adminFilterAll),
              AdminChipOption('pending', l10n.statusPending),
              AdminChipOption('paid', l10n.statusPaid),
              AdminChipOption('delivering', l10n.statusDelivering),
              AdminChipOption('delivered', l10n.statusDelivered),
              AdminChipOption('failed', l10n.statusFailed),
              AdminChipOption('refund_pending', l10n.statusRefundPending),
              AdminChipOption('refunded', l10n.statusRefunded),
              AdminChipOption('expired', l10n.statusExpired),
            ],
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: orders,
            onRetry: () => ref.invalidate(adminOrdersProvider(query)),
            builder: (rows) => rows.isEmpty
                ? AdminEmpty(l10n.adminNoOrders)
                : Column(
                    children: [
                      for (final row in rows)
                        _OrderRow(
                          order: row,
                          onTap: () => context.go('/admin/orders/${row.id}'),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final AdminOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ink900,
          border: Border.all(
            color: order.manualPaymentRequestedAt != null
                ? AppColors.warn.withValues(alpha: 0.5)
                : AppColors.ink800,
          ),
          borderRadius: BorderRadius.circular(12),
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  money(order.totalUsd),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OrderStatusChip(status: order.status),
                Text(
                  order.kind == 'wallet_topup'
                      ? l10n.adminKindWalletTopup
                      : l10n.adminKindPurchase,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.ink400,
                  ),
                ),
                Text(
                  '${order.itemCount} ×',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.ink400,
                  ),
                ),
                Text(
                  adminStamp(order.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.ink400,
                  ),
                ),
              ],
            ),
            // A transfer the buyer says they made jumps the queue, so it is
            // marked here rather than only on the transfers screen.
            if (order.manualPaymentRequestedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                '${l10n.adminManualPayments} · '
                '${adminStamp(order.manualPaymentRequestedAt!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.warn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
