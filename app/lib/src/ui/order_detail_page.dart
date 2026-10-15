import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/khqr_sheet.dart';
import 'widgets/manual_payment_panel.dart';
import 'widgets/review_sheet.dart';
import 'widgets/status_chip.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  Map<int, List<String>> _codes = const {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final order = ref.watch(orderProvider(widget.orderId));
    // Falls back to empty so the review button simply stays hidden until the
    // set of already-reviewed products has loaded.
    final reviewed = ref
        .watch(reviewedProductsProvider(widget.orderId))
        .maybeWhen(data: (ids) => ids, orElse: () => const <int>{});

    return AsyncValueView(
      value: order,
      onRetry: () => ref.invalidate(orderProvider(widget.orderId)),
      builder: (value) {
        if (value == null) {
          return Center(child: Text(l10n.orderEmpty));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(
                  value.orderNo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                OrderStatusChip(status: value.status),
              ],
            ),
            const SizedBox(height: 14),
            for (final item in value.items)
              _OrderItemTile(
                item: item,
                codes: _codes[item.id] ?? const [],
                l10n: l10n,
                canReview:
                    value.status == OrderStatus.delivered &&
                    item.canBeReviewed &&
                    !reviewed.contains(item.productId),
                onReview: () => _writeReview(value, item),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.ink900,
                border: Border.all(color: AppColors.ink800),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row(l10n.subtotal, money(value.subtotalUsd)),
                  if (value.discountUsd > 0)
                    _row(
                      l10n.discount,
                      '-${money(value.discountUsd)}',
                      color: AppColors.accent,
                    ),
                  _row(l10n.total, money(value.totalUsd), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (value.isPending) ...[
              FilledButton.icon(
                onPressed: _busy ? null : () => _resumePayment(value),
                icon: const Icon(Icons.qr_code_2, size: 20),
                label: Text(l10n.payWithKhqr),
              ),
              const SizedBox(height: 8),
              // The fallback, under the QR rather than instead of it. Renders
              // only when settings carry an account to transfer to.
              ManualPaymentPanel(order: value),
            ],
            if (value.isPaid) ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _reveal(value),
                icon: const Icon(Icons.key_outlined, size: 18),
                label: Text(l10n.yourCodes),
              ),
            ],
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (bold ? Colors.white : null),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reveal(Order order) async {
    setState(() => _busy = true);
    try {
      final codes = await ref.read(orderRepositoryProvider).reveal(order.id);
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _busy = false;
      });
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.code)));
    }
  }

  Future<void> _writeReview(Order order, OrderLine item) async {
    final productId = item.productId;
    if (productId == null) return;

    final submitted = await ReviewSheet.show(
      context,
      productId: productId,
      orderId: order.id,
      productName: item.productName,
    );

    if (submitted && mounted) {
      ref.invalidate(reviewedProductsProvider(order.id));
    }
  }

  Future<void> _resumePayment(Order order) async {
    if (order.expiresAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).statusExpired)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final payment = await ref
          .read(paymentRepositoryProvider)
          .initKhqr(order.id);
      if (!mounted) return;
      setState(() => _busy = false);

      final paid = await KhqrSheet.show(
        context,
        orderId: order.id,
        payment: payment,
      );

      if (!mounted) return;
      if (paid) {
        ref.invalidate(orderProvider(order.id));
        ref.invalidate(ordersProvider);
        await _reveal(order);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).somethingWentWrong)),
      );
    }
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
    required this.item,
    required this.codes,
    required this.l10n,
    required this.canReview,
    required this.onReview,
  });

  final OrderLine item;
  final List<String> codes;
  final AppL10n l10n;
  final bool canReview;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final needsSetup = item.deliveryStatus == DeliveryStatus.manualWaiting;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.productName} · ${item.variantLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Text('x${item.qty}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          if (codes.isEmpty) ...[
            if (needsSetup)
              Row(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 14,
                    color: AppColors.warn,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.manualWaiting,
                    style: const TextStyle(fontSize: 11, color: AppColors.warn),
                  ),
                ],
              )
            else
              Text(
                money(item.lineTotalUsd),
                style: const TextStyle(fontSize: 12, color: AppColors.ink400),
              ),
          ] else ...[
            for (final code in codes) _CodeChip(code: code),
            if (canReview)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: Text(
                    l10n.writeReview,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink850,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.accent,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
          ),
        ],
      ),
    );
  }
}
