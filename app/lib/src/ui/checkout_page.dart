import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/order_repository.dart';
import '../data/payment_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/khqr_sheet.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _coupon = TextEditingController();

  double? _couponDiscount;
  String? _couponError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(currentUserProvider)?.email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    _coupon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lines = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final profile = ref.watch(profileProvider);
    final total = (subtotal - (_couponDiscount ?? 0)).clamp(0, double.infinity);

    if (lines.isEmpty) {
      return Center(child: Text(l10n.cartEmpty));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.checkout,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: l10n.orderSummary,
          child: Column(
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.productName} · ${line.variantLabel} x${line.qty}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(money(line.lineTotal),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              const Divider(),
              _row(l10n.subtotal, money(subtotal)),
              if ((_couponDiscount ?? 0) > 0)
                _row(l10n.discount, '-${money(_couponDiscount!)}',
                    color: AppColors.accent),
              _row(
                l10n.total,
                money(total),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: l10n.contactEmail,
          child: Column(
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.contactEmail),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.note),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coupon,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.coupon,
                        errorText: _couponError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _applyCoupon(subtotal),
                      child: Text(l10n.apply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _payWithKhqr,
          icon: const Icon(Icons.qr_code_2, size: 20),
          label: Text(l10n.payWithKhqr),
        ),
        const SizedBox(height: 10),
        profile.maybeWhen(
          data: (value) => value == null
              ? const SizedBox.shrink()
              : OutlinedButton.icon(
                  onPressed: _busy || value.walletBalance < total
                      ? null
                      : () => _payWithWallet(value.walletBalance),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: Text(
                    '${l10n.payWithWallet} · ${money(value.walletBalance)}',
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
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

  Future<void> _applyCoupon(double subtotal) async {
    final code = _coupon.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _couponError = null;
    });

    try {
      final (ok, discount, reason) = await ref
          .read(orderRepositoryProvider)
          .validateCoupon(code, subtotal);

      setState(() {
        if (ok) {
          _couponDiscount = discount;
        } else {
          _couponDiscount = null;
          _couponError = reason == null
              ? AppL10n.of(context).couponInvalid
              : _humanise(reason, AppL10n.of(context));
        }
      });
    } catch (_) {
      setState(() => _couponError = AppL10n.of(context).couponInvalid);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payWithKhqr() async {
    final l10n = AppL10n.of(context);
    final order = await _createOrder();
    if (order == null) return;

    setState(() => _busy = true);
    try {
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
        await ref.read(cartControllerProvider.notifier).clear();
        ref.invalidate(ordersProvider);
        ref.invalidate(profileProvider);
        if (!mounted) return;
        context.go('/orders/${order.orderId}');
      } else {
        // Keep the order so the buyer can retry without rebuilding the cart.
        context.go('/orders/${order.orderId}');
      }
    } on PaymentException catch (error) {
      _toast(_humanise(error.code, l10n));
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      _toast(l10n.somethingWentWrong);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payWithWallet(double balance) async {
    final l10n = AppL10n.of(context);
    final order = await _createOrder();
    if (order == null) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(orderRepositoryProvider).payWithWallet(order.orderId);

      if (!mounted) return;
      setState(() => _busy = false);

      if (result.ok) {
        await ref.read(cartControllerProvider.notifier).clear();
        ref.invalidate(ordersProvider);
        ref.invalidate(profileProvider);
        if (!mounted) return;
        context.go('/orders/${order.orderId}');
      } else {
        _toast(l10n.insufficientBalance);
        context.go('/orders/${order.orderId}');
      }
    } catch (_) {
      _toast(l10n.somethingWentWrong);
      setState(() => _busy = false);
    }
  }

  Future<CreatedOrder?> _createOrder() async {
    final l10n = AppL10n.of(context);
    final lines = ref.read(cartControllerProvider);
    if (lines.isEmpty) return null;

    // create_order validates every product's required fields against one
    // payload, so merge the per-line values here.
    final fields = <String, String>{};
    for (final line in lines) {
      fields.addAll(line.fields);
    }

    setState(() => _busy = true);

    try {
      final order = await ref.read(orderRepositoryProvider).createOrder(
            lines: lines,
            coupon: _coupon.text.trim().isEmpty ? null : _coupon.text.trim(),
            fields: fields,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) setState(() => _busy = false);
      return order;
    } on OrderException catch (error) {
      _toast(_humanise(error.code, l10n));
      if (mounted) setState(() => _busy = false);
      ref.invalidate(productsProvider);
      return null;
    } catch (_) {
      _toast(l10n.somethingWentWrong);
      if (mounted) setState(() => _busy = false);
      return null;
    }
  }

  /// Database error codes are stable identifiers; this maps them to copy.
  String _humanise(String code, AppL10n l10n) => switch (code) {
        'out_of_stock' => l10n.outOfStock,
        'coupon_invalid' => l10n.couponInvalid,
        'coupon_exhausted' => l10n.couponInvalid,
        'coupon_user_limit' => l10n.couponInvalid,
        'coupon_min_order' => l10n.couponInvalid,
        'qty_out_of_range' => l10n.somethingWentWrong,
        'missing_fields' => l10n.requiredInfo,
        'empty_cart' => l10n.cartEmpty,
        'auth_required' => l10n.guestMustSignIn,
        'account_blocked' => l10n.somethingWentWrong,
        'order_expired' => l10n.statusExpired,
        'payway_not_configured' => l10n.somethingWentWrong,
        'payway_rejected' => l10n.somethingWentWrong,
        _ => l10n.somethingWentWrong,
      };

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
