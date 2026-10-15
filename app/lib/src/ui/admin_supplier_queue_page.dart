import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';

/// Order lines the supplier worker could not finish.
///
/// `retrying` lines are backing off and will try again without anyone. Only
/// `manual_waiting` lines need a person, and they are listed first. Marking one
/// delivered closes the line; it does not refund the buyer, so the dialog says
/// so before it runs.
class AdminSupplierQueuePage extends ConsumerWidget {
  const AdminSupplierQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final queue = ref.watch(adminSupplierQueueProvider);

    void refresh() {
      ref.invalidate(adminSupplierQueueProvider);
      ref.invalidate(adminOverviewProvider);
    }

    return AdminGate(
      child: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminHeader(
              title: l10n.adminQueueTitle,
              subtitle: l10n.adminQueueNote,
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
              builder: (items) => items.isEmpty
                  ? AdminEmpty(l10n.adminQueueEmpty)
                  : Column(
                      children: [
                        for (final item in items)
                          _QueueCard(item: item, onDone: refresh),
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

class _QueueCard extends ConsumerStatefulWidget {
  const _QueueCard({required this.item, required this.onDone});

  final SupplierQueueItem item;
  final VoidCallback onDone;

  @override
  ConsumerState<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends ConsumerState<_QueueCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final item = widget.item;
    final needsYou = item.needsPerson;
    final tone = needsYou ? AppColors.danger : AppColors.warn;

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
                  '${item.orderNo} · ${item.productName} · ${item.variantLabel}'
                  '${item.qty > 1 ? ' ×${item.qty}' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  needsYou ? l10n.adminQueueNeedsYou : l10n.adminQueueRetrying,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (item.supplierCode != null) item.supplierCode!,
              if (item.attempts > 0) '${item.attempts} ×',
              adminStamp(item.createdAt),
            ].join(' · '),
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
          if (item.lastError != null && item.lastError!.isNotEmpty) ...[
            const SizedBox(height: 8),
            // The supplier's own words. They are the fastest route to a cause.
            SelectableText(
              item.lastError!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.ink200,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (needsYou)
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _markDelivered,
                    child: Text(l10n.adminResolveDelivered),
                  ),
                ),
              if (needsYou) const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.go('/admin/orders/${item.orderId}'),
                child: Text(l10n.adminTicketOpenOrder),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markDelivered() async {
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.adminQueueConfirmTitle),
        content: Text(l10n.adminQueueConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.adminResolveDelivered),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveItem(itemId: widget.item.itemId, delivery: 'delivered');
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.adminQueueDelivered);
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
