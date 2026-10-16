import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Bank transfers the buyer says they have made.
///
/// The screen is a convenience, not the control: every action goes to an RPC
/// that re-checks `is_staff()`, and `staff_manual_payments` is a
/// security-invoker view, so a customer session gets no rows even if it reaches
/// this route.
class AdminTransfersPage extends ConsumerWidget {
  const AdminTransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final requests = ref.watch(manualPaymentRequestsProvider);

    return AdminGate(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(manualPaymentRequestsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminHeader(
              title: l10n.adminManualPayments,
              subtitle: l10n.adminManualQueue,
              onBack: () => context.go('/admin'),
            ),
            const SizedBox(height: 14),
            AsyncValueView(
              value: requests,
              onRetry: () => ref.invalidate(manualPaymentRequestsProvider),
              builder: (items) => items.isEmpty
                  ? AdminEmpty(l10n.adminNoManualRequests)
                  : Column(
                      children: [
                        for (final request in items)
                          _RequestCard(
                            request: request,
                            onDone: () =>
                                ref.invalidate(manualPaymentRequestsProvider),
                          ),
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

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.request, required this.onDone});

  final ManualPaymentRequest request;
  final VoidCallback onDone;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.request.totalUsd.toStringAsFixed(2),
  );
  final _ref = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final request = widget.request;

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
                  request.orderNo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                money(request.totalUsd),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.adminExpiresIn} ${adminStamp(request.expiresAt)}',
            style: TextStyle(
              fontSize: 11,
              color: request.isExpired ? AppColors.danger : AppColors.ink400,
            ),
          ),
          if (request.requestedAt != null)
            Text(
              '${l10n.statusPending} · ${adminStamp(request.requestedAt!)}',
              style: const TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
          if (request.contactEmail != null && request.contactEmail!.isNotEmpty)
            Text(
              request.contactEmail!,
              style: const TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
          // What the buyer typed into the game-id fields: staff need it to
          // fulfil the order once the money is confirmed.
          if (request.customerFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in request.customerFields.entries)
                  Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
              ],
            ),
          ],
          if (request.buyerNote != null && request.buyerNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.buyerNote!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.ink400,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.adminAmountReceived,
              helperText: l10n.adminAmountReceivedHint,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ref,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.adminAbaRef,
              helperText: l10n.adminAbaRefHint,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: Text(l10n.adminConfirmPayment),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _dismiss,
                child: Text(l10n.adminDismissRequest),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = AppL10n.of(context);
    final amount = double.tryParse(_amount.text.trim());

    if (amount == null) {
      _toast(l10n.adminAmountReceived);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .confirmManualPayment(
            orderId: widget.request.orderId,
            amountUsd: amount,
            abaRef: _ref.text,
          );

      if (!mounted) return;
      setState(() => _busy = false);

      // The RPC reports an already-settled order instead of raising, so a
      // double click says so rather than looking like a failure.
      _toast(result['ok'] == true ? l10n.orderPaidSuccess : l10n.statusPaid);
      widget.onDone();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_humanise(error.code, l10n));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  Future<void> _dismiss() async {
    final l10n = AppL10n.of(context);
    final reason = await _askReason(l10n);
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .clearManualPaymentRequest(
            orderId: widget.request.orderId,
            reason: reason,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onDone();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_humanise(error.code, l10n));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  Future<String?> _askReason(AppL10n l10n) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.adminDismissRequest),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.adminDismissReason),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(l10n.adminDismissRequest),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// The reason is required in the database; refusing an empty one here too
  /// means the buyer's history explains itself.
  String _humanise(String code, AppL10n l10n) => switch (code) {
    'manual_underpaid' => l10n.adminUnderpaid,
    'manual_reference_used' => l10n.adminReferenceUsed,
    'manual_reference_required' => l10n.adminAbaRef,
    'order_expired' => l10n.adminExpired,
    'not_authorized' => l10n.adminOnly,
    'reason_required' => l10n.adminDismissReason,
    _ => l10n.somethingWentWrong,
  };

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
