import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/empty_state.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  void initState() {
    super.initState();
    // A line can outlive its product (staff hide it, a supplier sync drops the
    // SKU), and its quantity range can go stale the same way. Correct it here,
    // where the buyer sees the cart, rather than at checkout where the only
    // feedback is a failed order.
    unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    final result = await ref
        .read(cartControllerProvider.notifier)
        .reconcileWithCatalogue();
    if (!mounted || result.isEmpty) return;
    final l10n = AppL10n.of(context);
    // A removed line matters more than a lowered quantity, so it wins when both
    // happened in one reconciliation.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.removed.isNotEmpty
              ? l10n.itemUnavailable
              : l10n.qtyOnePerOrder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lines = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartSubtotalProvider);

    if (lines.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        message: l10n.cartEmpty,
        action: FilledButton(
          onPressed: () => context.go('/products'),
          child: Text(l10n.allProducts),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                decoration: BoxDecoration(
                  color: AppColors.ink900,
                  border: Border.all(color: AppColors.ink800),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.productName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.variantLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.ink400,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            money(line.unitPriceUsd * line.qty),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // A fixed-quantity line (a top-up the supplier will only
                    // deliver once) gets no stepper: there is nothing to
                    // change, and a dead control invites a tap that does
                    // nothing.
                    if (line.maxQty > line.minQty)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.ink850,
                          border: Border.all(color: AppColors.ink700),
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: line.qty > line.minQty
                                  ? () => ref
                                        .read(cartControllerProvider.notifier)
                                        .setQty(line.variantId, line.qty - 1)
                                  : null,
                              icon: const Icon(Icons.remove, size: 16),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${line.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: line.qty < line.maxQty
                                  ? () => ref
                                        .read(cartControllerProvider.notifier)
                                        .setQty(line.variantId, line.qty + 1)
                                  : null,
                              icon: const Icon(Icons.add, size: 16),
                            ),
                          ],
                        ),
                      ),
                    IconButton(
                      tooltip: l10n.remove,
                      onPressed: () => ref
                          .read(cartControllerProvider.notifier)
                          .remove(line.variantId),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: AppColors.ink900,
            border: Border(top: BorderSide(color: AppColors.ink800)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.subtotal,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.ink400,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      money(subtotal),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/checkout'),
                  child: Text(l10n.checkout),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
