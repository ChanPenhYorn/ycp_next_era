import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';

/// The staff hub.
///
/// It answers two questions and nothing else: what is waiting for a person, and
/// what money has actually moved. Every figure comes from `admin_overview()`,
/// which counts rows and sums payments — there is no growth percentage, no
/// "active users", nothing that would have to be invented to be shown.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final overview = ref.watch(adminOverviewProvider);

    return AdminGate(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminOverviewProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminHeader(
              title: l10n.adminTitle,
              subtitle: l10n.adminOverview,
            ),
            const SizedBox(height: 14),
            AsyncValueView(
              value: overview,
              onRetry: () => ref.invalidate(adminOverviewProvider),
              builder: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminSection(
                    title: l10n.adminNeedsAttention,
                    subtitle: l10n.adminCountsNote,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AdminStat(
                          label: l10n.adminPendingOrders,
                          value: '${data.ordersPending}',
                          onTap: () => context.go('/admin/orders?status=pending'),
                        ),
                        AdminStat(
                          label: l10n.statusRefundPending,
                          value: '${data.ordersRefundPending}',
                          tone: data.ordersRefundPending > 0
                              ? AppColors.warn
                              : null,
                          onTap: () => context.go('/admin/refunds'),
                        ),
                        AdminStat(
                          label: l10n.adminManualPayments,
                          value: '${data.transfersWaiting}',
                          tone: data.transfersWaiting > 0
                              ? AppColors.warn
                              : null,
                          onTap: () => context.go('/admin/transfers'),
                        ),
                        AdminStat(
                          label: l10n.adminSupportOpen,
                          value: '${data.supportOpen}',
                          onTap: () => context.go('/admin/support?status=open'),
                        ),
                        AdminStat(
                          label: l10n.adminManualWaiting,
                          value: '${data.itemsManualWaiting}',
                        ),
                      ],
                    ),
                  ),
                  AdminSection(
                    title: l10n.adminMoney,
                    subtitle: l10n.adminReceivedNote,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AdminStat(
                              label: l10n.adminReceivedToday,
                              value: money(data.receivedTodayUsd),
                            ),
                            AdminStat(
                              label: l10n.adminReceived7d,
                              value: money(data.received7dUsd),
                            ),
                            AdminStat(
                              label: l10n.adminReceived30d,
                              value: money(data.received30dUsd),
                            ),
                            AdminStat(
                              label: l10n.adminWalletSpent30d,
                              value: money(data.walletSpent30dUsd),
                            ),
                            AdminStat(
                              label: l10n.adminRefunded30d,
                              value: money(data.refunded30dUsd),
                              tone: data.refunded30dUsd > 0
                                  ? AppColors.danger
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Which day "today" means is stated rather than assumed:
                        // the store is in Phnom Penh and the server is not.
                        Text(
                          '${data.timezone} · ${adminStamp(data.generatedAt)}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.ink400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdminSection(
                    title: l10n.adminTitle,
                    child: Column(
                      children: [
                        AdminTile(
                          icon: Icons.receipt_long_outlined,
                          title: l10n.adminOrdersTitle,
                          count: data.ordersPending,
                          onTap: () => context.go('/admin/orders'),
                        ),
                        AdminTile(
                          icon: Icons.assignment_return_outlined,
                          title: l10n.adminRefundsTitle,
                          count: data.ordersRefundPending,
                          onTap: () => context.go('/admin/refunds'),
                        ),
                        AdminTile(
                          icon: Icons.support_agent_outlined,
                          title: l10n.adminSupportTitle,
                          count: data.supportOpen,
                          onTap: () => context.go('/admin/support'),
                        ),
                        AdminTile(
                          icon: Icons.account_balance_outlined,
                          title: l10n.adminManualPayments,
                          count: data.transfersWaiting,
                          onTap: () => context.go('/admin/transfers'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
