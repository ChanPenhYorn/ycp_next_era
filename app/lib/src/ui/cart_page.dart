import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/providers.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final lines = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartSubtotalProvider);

    if (lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              l10n.cartEmpty,
              style: const TextStyle(color: AppColors.ink400),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/products'),
              child: Text(l10n.allProducts),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.ink900,
                  border: Border.all(color: AppColors.ink800),
                  borderRadius: BorderRadius.circular(12),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            line.variantLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink400,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            money(line.unitPriceUsd),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: line.qty > line.minQty
                          ? () => ref
                              .read(cartControllerProvider.notifier)
                              .setQty(line.variantId, line.qty - 1)
                          : null,
                      icon: const Icon(Icons.remove, size: 16),
                    ),
                    Text('${line.qty}'),
                    IconButton(
                      onPressed: line.qty < line.maxQty
                          ? () => ref
                              .read(cartControllerProvider.notifier)
                              .setQty(line.variantId, line.qty + 1)
                          : null,
                      icon: const Icon(Icons.add, size: 16),
                    ),
                    IconButton(
                      onPressed: () => ref
                          .read(cartControllerProvider.notifier)
                          .remove(line.variantId),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
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
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.ink900,
            border: Border(top: BorderSide(color: AppColors.ink800)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(l10n.subtotal, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      money(subtotal),
                      style: const TextStyle(
                        fontSize: 18,
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
