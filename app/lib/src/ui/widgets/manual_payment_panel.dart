import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../features/orders/domain/order_exception.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

/// The fallback payment option: a transfer a human checks.
///
/// It is a fallback, so it sits under the KHQR button rather than replacing it,
/// and it renders only when the store has put an account in settings. A store
/// that has not done that shows nothing here — no instruction the buyer cannot
/// act on, and no "contact us and we will sort it out" promise the app cannot
/// keep on its own.
///
/// Nothing here settles anything. The buyer's click books a request; staff
/// confirm the money afterwards in the staff screen.
class ManualPaymentPanel extends ConsumerStatefulWidget {
  const ManualPaymentPanel({required this.order, super.key});

  final Order order;

  @override
  ConsumerState<ManualPaymentPanel> createState() => _ManualPaymentPanelState();
}

class _ManualPaymentPanelState extends ConsumerState<ManualPaymentPanel> {
  bool _busy = false;
  bool _justRequested = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(settingsProvider);
    final order = widget.order;

    // Already asked: say what happens next instead of inviting a second request.
    if (order.manualPaymentRequestedAt != null || _justRequested) {
      return _Box(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule, size: 17, color: AppColors.warn),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.manualWaiting,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _justRequested
                        ? l10n.manualRequested
                        : l10n.manualWaitingBody,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.ink400,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return settings.maybeWhen(
      data: (value) => value.hasTransferAccount
          ? _instructions(context, l10n, value, order)
          : const SizedBox.shrink(),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _instructions(
    BuildContext context,
    AppL10n l10n,
    PublicSettings settings,
    Order order,
  ) {
    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.payByTransfer,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.transferIntro,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.ink400,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _Line(l10n.transferTo, settings.khqrMerchantName!.trim()),
          _Line(
            l10n.transferAccount,
            settings.khqrAccountId!.trim(),
            mono: true,
          ),
          _Line(l10n.transferAmount, money(order.totalUsd), bold: true),
          _Line(l10n.transferRemark, order.orderNo, mono: true),
          const SizedBox(height: 4),
          Text(
            l10n.transferRemarkHint,
            style: const TextStyle(fontSize: 10.5, color: AppColors.ink400),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _request(order),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(l10n.iHavePaid),
            ),
          ),
          const SizedBox(height: 6),
          // The buyer pays to an account this app does not control, so it says
          // what it cannot promise: the confirmation is a person, not a webhook.
          Text(
            l10n.trustPaymentBody,
            style: const TextStyle(fontSize: 10.5, color: AppColors.ink400),
          ),
        ],
      ),
    );
  }

  Future<void> _request(Order order) async {
    final l10n = AppL10n.of(context);
    setState(() => _busy = true);

    try {
      await ref.read(orderRepositoryProvider).requestManualPayment(order.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _justRequested = true;
      });
      // The RPC extended the expiry, so the page underneath is now stale.
      ref.invalidate(orderProvider(order.id));
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanise(error.code, l10n))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
    }
  }

  String _humanise(String code, AppL10n l10n) => switch (code) {
    'manual_rate_limited' => l10n.manualRateLimited,
    'order_not_found' => l10n.orderEmpty,
    'order_not_pending' => l10n.statusPending,
    _ => l10n.somethingWentWrong,
  };
}

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.mono = false});

  final String label;
  final String value;
  final bool bold;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink400),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 15 : 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                letterSpacing: mono ? 0.5 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
