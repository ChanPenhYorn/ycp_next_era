import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/status_chip.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final orders = ref.watch(ordersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ordersProvider),
      child: AsyncValueView(
        value: orders,
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      const Text('🧾', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 10),
                      Text(
                        l10n.orderEmpty,
                        style: const TextStyle(color: AppColors.ink400),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = items[index];

              return InkWell(
                onTap: () => context.go('/orders/${order.id}'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
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
                          Text(
                            order.orderNo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.ink400,
                            ),
                          ),
                          const Spacer(),
                          OrderStatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.items
                            .map((item) => '${item.productName} x${item.qty}')
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _formatDate(order.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink400,
                            ),
                          ),
                          const Spacer(),
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
