import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/brand.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../data/payment_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/khqr_sheet.dart';

/// Wallet balance, top-up, and the ledger that explains the balance.
class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  double? _amount;
  bool _busy = false;

  static const _quickAmounts = [5.0, 10.0, 20.0, 50.0, 100.0];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    final transactions = ref.watch(walletTransactionsProvider);

    final min = settings.maybeWhen(
      data: (s) => s.topupMinUsd,
      orElse: () => 1.0,
    );
    final max = settings.maybeWhen(
      data: (s) => s.topupMaxUsd,
      orElse: () => 1000.0,
    );
    final selected = _amount ?? min;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileProvider);
        ref.invalidate(walletTransactionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // The wallet lost its bottom-nav tab in favour of Account, so the
          // page needs a heading of its own.
          Text(
            l10n.walletTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.ink800),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16224A), AppColors.ink900],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.walletBalance,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink400),
                ),
                const SizedBox(height: 6),
                AsyncValueView(
                  value: profile,
                  builder: (value) => Text(
                    money(value?.walletBalance ?? 0),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (settings.maybeWhen(
                  data: (s) => s.usdToKhr > 0,
                  orElse: () => false,
                ))
                  Text(
                    riel(
                      profile.maybeWhen(
                        data: (value) => value?.walletBalance ?? 0,
                        orElse: () => 0,
                      ),
                      settings.maybeWhen(
                        data: (s) => s.usdToKhr,
                        orElse: () => 4100,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink400,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.walletTopup,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.walletLimits(money(min), money(max)),
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in _quickAmounts)
                if (amount >= min && amount <= max)
                  ChoiceChip(
                    label: Text(money(amount)),
                    selected: selected == amount,
                    onSelected: (_) => setState(() => _amount = amount),
                  ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : () => _startTopup(selected, min, max),
            icon: const Icon(Icons.qr_code_2, size: 20),
            label: Text('${l10n.walletTopup} ${money(selected)}'),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.walletTopupNote,
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.walletHistory,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          AsyncValueView(
            value: transactions,
            onRetry: () => ref.invalidate(walletTransactionsProvider),
            builder: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    l10n.walletEmpty,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink400,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final tx in items)
                    _LedgerRow(transaction: tx, l10n: l10n),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _startTopup(double amount, double min, double max) async {
    final l10n = AppL10n.of(context);

    if (amount < min || amount > max) {
      _toast(l10n.walletLimits(money(min), money(max)));
      return;
    }

    setState(() => _busy = true);

    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .createWalletTopup(
            amountUsd: amount,
            email: ref.read(currentUserProvider)?.email,
          );

      final payment = await ref
          .read(paymentRepositoryProvider)
          .initKhqr(order.orderId);

      if (!mounted) return;
      setState(() => _busy = false);

      final paid = await KhqrSheet.show(
        context,
        orderId: order.orderId,
        payment: payment,
      );

      if (!mounted) return;

      if (paid) {
        // mark_order_paid credited the wallet; refetch rather than guess.
        ref.invalidate(profileProvider);
        ref.invalidate(walletTransactionsProvider);
        _toast(l10n.walletCredited);
      } else {
        _toast(l10n.walletTopupFailed);
      }
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_humanise(error.code, l10n, min, max));
    } on PaymentException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        error.code == 'payway_not_configured'
            ? l10n.paywayNotConfigured
            : l10n.somethingWentWrong,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  String _humanise(String code, AppL10n l10n, double min, double max) =>
      switch (code) {
        'topup_below_minimum' ||
        'topup_above_maximum' => l10n.walletLimits(money(min), money(max)),
        'auth_required' => l10n.guestMustSignIn,
        'account_blocked' => l10n.somethingWentWrong,
        _ => l10n.somethingWentWrong,
      };

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.transaction, required this.l10n});

  final WalletTransaction transaction;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (transaction.kind) {
      'topup' => (Icons.add_circle_outline, l10n.walletTopup),
      'purchase' => (Icons.shopping_bag_outlined, l10n.checkout),
      'refund' => (Icons.undo, l10n.statusRefunded),
      'coin_reward' => (Icons.stars_outlined, l10n.reviewThanks),
      _ => (Icons.tune, Brand.name),
    };

    final credit = transaction.isCredit;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: credit ? AppColors.accent : AppColors.ink400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                if (transaction.note != null)
                  Text(
                    transaction.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
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
                '${credit ? '+' : ''}${money(transaction.amountUsd)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: credit ? AppColors.accent : AppColors.ink200,
                ),
              ),
              Text(
                money(transaction.balanceAfter),
                style: const TextStyle(fontSize: 10, color: AppColors.ink400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
