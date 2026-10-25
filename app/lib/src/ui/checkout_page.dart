import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/field_validation.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../features/orders/domain/order_exception.dart';
import '../features/payments/domain/payment_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/card_sheet.dart';
import 'widgets/khqr_sheet.dart';
import 'widgets/required_fields_form.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _coupon = TextEditingController();

  /// Per-line buyer inputs, keyed `variantId:fieldKey`. Collected here
  /// rather than on the product page because this is where the buyer commits,
  /// and because a value stashed earlier was never editable again.
  final _fieldControllers = <String, TextEditingController>{};

  double? _couponDiscount;
  String? _couponError;

  /// Message per `variantId:fieldKey`. A single shared error string used to be
  /// painted under every input on the page, so a bad game id also highlighted
  /// the server box.
  Map<String, String?> _fieldErrors = const {};

  bool _busy = false;

  _PayMethod _method = _PayMethod.khqr;

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(currentUserProvider)?.email ?? '';

    // Seed from the cart so anything entered on the product page carries over.
    for (final line in ref.read(cartControllerProvider)) {
      for (final field in line.requiredFields) {
        final controller = _fieldControllers.putIfAbsent(
          _fieldKey(line.variantId, field.key),
          TextEditingController.new,
        );
        controller.text = line.fields[field.key] ?? '';
      }
    }

    // A cart line can outlive its product (staff hide it, a supplier sync drops
    // the SKU), and its quantity range can go stale the same way. Correct both
    // before the buyer commits, and say so, rather than letting `create_order`
    // fail later with a generic error.
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
    _toast(
      result.removed.isNotEmpty ? l10n.itemUnavailable : l10n.qtyOnePerOrder,
    );
  }

  /// Corrects the lines `create_order` refused for their quantity, and reports
  /// whether anything was actually changed.
  ///
  /// The database names the SKU it refused, which finds the line directly. A
  /// line saved before SKUs were carried has none, so the catalogue is read
  /// again instead: that fills in the SKU and the current cap, and is what the
  /// failed line needed anyway.
  Future<bool> _correctOutOfRangeLines(String? skus) async {
    final wanted = (skus ?? '')
        .split(',')
        .map((sku) => sku.trim())
        .where((sku) => sku.isNotEmpty)
        .toSet();

    final controller = ref.read(cartControllerProvider.notifier);

    if (wanted.isNotEmpty) {
      final targets = ref
          .read(cartControllerProvider)
          .where((line) => wanted.contains(line.sku))
          .map((line) => line.variantId)
          .toList();
      if (targets.isNotEmpty) {
        for (final variantId in targets) {
          await controller.capToOne(variantId);
        }
        return true;
      }
    }

    final result = await controller.reconcileWithCatalogue();
    return result.capped.isNotEmpty || result.removed.isNotEmpty;
  }

  @override
  void dispose() {
    _email.dispose();
    _note.dispose();
    _coupon.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _fieldKey(int variantId, String key) => '$variantId:$key';

  TextEditingController _controllerFor(int variantId, RequiredField field) =>
      _fieldControllers.putIfAbsent(
        _fieldKey(variantId, field.key),
        TextEditingController.new,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lines = ref.watch(cartControllerProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final cardEnabled =
        ref.watch(settingsProvider).valueOrNull?.dodoEnabled ?? false;
    final total = (subtotal - (_couponDiscount ?? 0)).clamp(0, double.infinity);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (lines.isEmpty) {
      return Center(child: Text(l10n.cartEmpty));
    }

    final needsFields = lines.where((line) => line.needsFields).toList();
    final balance = profile?.walletBalance;

    final sections = <({String title, Widget child})>[
      if (needsFields.isNotEmpty)
        (
          title: l10n.requiredInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in needsFields) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${line.productName} · ${line.variantLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.ink400,
                    ),
                  ),
                ),
                RequiredFieldsForm(
                  fields: line.requiredFields,
                  locale: Localizations.localeOf(context).languageCode,
                  controllerFor: (field) =>
                      _controllerFor(line.variantId, field),
                  // Keyed per line, because two lines can declare the same
                  // field name and only one of them may be the problem.
                  errors: {
                    for (final field in line.requiredFields)
                      field.key:
                          _fieldErrors[_fieldKey(line.variantId, field.key)],
                  },
                  onChanged: (field) {
                    final key = _fieldKey(line.variantId, field.key);
                    if (_fieldErrors[key] != null) {
                      setState(
                        () => _fieldErrors = {..._fieldErrors}..remove(key),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      (
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
                  height: 52,
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
      (
        title: l10n.paymentMethod,
        child: Column(
          children: [
            _MethodTile(
              icon: Icons.qr_code_2,
              title: l10n.payWithKhqr,
              subtitle: l10n.scanQr,
              selected: _method == _PayMethod.khqr,
              onTap: () => setState(() => _method = _PayMethod.khqr),
            ),
            const SizedBox(height: 8),
            if (cardEnabled) ...[
              _MethodTile(
                icon: Icons.credit_card,
                title: l10n.payByCard,
                subtitle: l10n.payByCardSubtitle,
                selected: _method == _PayMethod.card,
                onTap: () => setState(() => _method = _PayMethod.card),
              ),
              const SizedBox(height: 8),
            ],
            _MethodTile(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.payWithWallet,
              subtitle: balance == null
                  ? l10n.loading
                  : '${l10n.walletBalance} · ${money(balance)}',
              selected: _method == _PayMethod.wallet,
              onTap: () => setState(() => _method = _PayMethod.wallet),
            ),
          ],
        ),
      ),
    ];

    final summary = _Panel(
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
                  Text(
                    money(line.lineTotal),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(),
          _row(l10n.subtotal, money(subtotal)),
          if ((_couponDiscount ?? 0) > 0)
            _row(
              l10n.discount,
              '-${money(_couponDiscount!)}',
              color: AppColors.accent,
            ),
          _row(l10n.total, money(total), bold: true),
          const SizedBox(height: 16),
          _payButton(l10n, total, balance),
          if (_busy) ...[
            const SizedBox(height: 14),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );

    final stepPanels = [
      for (var i = 0; i < sections.length; i++) ...[
        _Panel(step: i + 1, title: sections[i].title, child: sections[i].child),
        const SizedBox(height: 12),
      ],
    ];

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Text(
                    l10n.checkout,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...stepPanels,
                ],
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(width: 340, child: summary),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.checkout,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        ...stepPanels,
        summary,
        const SizedBox(height: 30),
      ],
    );
  }

  /// One button, whose action follows the selected method. Wallet short on
  /// balance becomes a top-up link instead of a dead-end disabled button.
  Widget _payButton(AppL10n l10n, num total, double? balance) {
    final wallet = _method == _PayMethod.wallet;
    final walletEnough = balance != null && balance >= total;

    if (_method == _PayMethod.card) {
      return FilledButton.icon(
        onPressed: _busy ? null : _payWithCard,
        icon: const Icon(Icons.credit_card, size: 20),
        label: Text('${l10n.payByCard} · ${money(total)}'),
      );
    }

    if (!wallet) {
      return FilledButton.icon(
        onPressed: _busy ? null : _payWithKhqr,
        icon: const Icon(Icons.qr_code_2, size: 20),
        label: Text('${l10n.payWithKhqr} · ${money(total)}'),
      );
    }

    if (balance == null) {
      return FilledButton(onPressed: null, child: Text(l10n.loading));
    }

    if (!walletEnough) {
      return FilledButton.icon(
        onPressed: _busy ? null : () => context.go('/wallet'),
        icon: const Icon(Icons.add_card, size: 20),
        label: Text('${l10n.walletTopup} · ${money(balance)}'),
      );
    }

    return FilledButton.icon(
      onPressed: _busy ? null : () => _payWithWallet(balance),
      icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
      label: Text('${l10n.payWithWallet} · ${money(total)}'),
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
        ref.invalidate(ordersProvider);
        ref.invalidate(profileProvider);
        if (!mounted) return;
        context.go('/orders/${order.orderId}');
      } else {
        // The cart was emptied when the order was created. Retrying happens on
        // the order page, which already holds the lines and the payment state.
        context.go('/orders/${order.orderId}');
      }
    } on PaymentException catch (error) {
      if (mounted) setState(() => _busy = false);
      _toast(_humanise(error.code, l10n));
      // The order exists by now. Leaving the buyer on a checkout page whose QR
      // cannot open would strand them with a pending order and no way to pay
      // for it; the order page is where the transfer fallback lives.
      if (mounted) context.go('/orders/${order.orderId}');
    } catch (_) {
      // The order exists: createOrder already succeeded. "Something went
      // wrong" would leave the buyer staring at a QR that never opened with no
      // idea that their order is sitting there payable, so say what happened
      // and where to go next.
      if (mounted) setState(() => _busy = false);
      _toast(l10n.paymentUnreachable);
      if (mounted) context.go('/orders/${order.orderId}');
    }
  }

  Future<void> _payWithCard() async {
    final l10n = AppL10n.of(context);
    final order = await _createOrder();
    if (order == null) return;

    setState(() => _busy = true);
    try {
      final checkout = await ref
          .read(paymentRepositoryProvider)
          .initCard(order.orderId);

      if (!mounted) return;
      setState(() => _busy = false);

      final paid = await CardSheet.show(
        context,
        orderId: order.orderId,
        checkout: checkout,
      );

      if (!mounted) return;
      if (paid) {
        ref.invalidate(ordersProvider);
        ref.invalidate(profileProvider);
        if (!mounted) return;
        context.go('/orders/${order.orderId}');
      } else {
        context.go('/orders/${order.orderId}');
      }
    } on PaymentException catch (error) {
      if (mounted) setState(() => _busy = false);
      _toast(_humanise(error.code, l10n));
      if (mounted) context.go('/orders/${order.orderId}');
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _toast(l10n.paymentUnreachable);
      if (mounted) context.go('/orders/${order.orderId}');
    }
  }

  Future<void> _payWithWallet(double balance) async {
    final l10n = AppL10n.of(context);
    final order = await _createOrder();
    if (order == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .payWithWallet(order.orderId);

      if (!mounted) return;
      setState(() => _busy = false);

      if (result.ok) {
        ref.invalidate(ordersProvider);
        ref.invalidate(profileProvider);
        if (!mounted) return;
        context.go('/orders/${order.orderId}');
      } else {
        // Two failures reach here: not enough balance, or the order is no
        // longer payable (already paid, expired, cancelled). Saying "not enough
        // balance" for the second one sends the buyer to top up a wallet that
        // was never the problem.
        _toast(
          result.reason == 'insufficient_balance'
              ? l10n.insufficientBalance
              : l10n.orderNotPayable,
        );
        context.go('/orders/${order.orderId}');
      }
    } catch (_) {
      // The order exists by then, so send the buyer to where it can still be
      // paid rather than leaving them on a checkout page that looks broken.
      if (mounted) setState(() => _busy = false);
      _toast(l10n.paymentUnreachable);
      if (mounted) context.go('/orders/${order.orderId}');
    }
  }

  /// Reads the per-line inputs, records them on the cart, and returns the merged
  /// payload create_order expects. Null when something is missing, with the
  /// offending field named under the input that carries it.
  Map<String, String>? _collectBuyerFields() {
    final l10n = AppL10n.of(context);
    final merged = <String, String>{};
    final problems = <String, String?>{};

    for (final line in ref.read(cartControllerProvider)) {
      final values = <String, String>{};

      for (final field in line.requiredFields) {
        final raw = _controllerFor(line.variantId, field).text;
        final problem = fieldProblem(field, raw);

        if (problem != null) {
          problems[_fieldKey(line.variantId, field.key)] = fieldProblemMessage(
            l10n,
            field,
            problem,
          );
          continue;
        }

        values[field.key] = raw.trim();
      }

      merged.addAll(values);
      // Keep the cart in step, so leaving and returning does not lose it.
      ref
          .read(cartControllerProvider.notifier)
          .setFields(line.variantId, values);
    }

    if (problems.isNotEmpty) {
      setState(() => _fieldErrors = problems);
      return null;
    }

    setState(() => _fieldErrors = const {});
    return merged;
  }

  Future<CreatedOrder?> _createOrder() async {
    final l10n = AppL10n.of(context);
    final lines = ref.read(cartControllerProvider);
    if (lines.isEmpty) return null;

    final fields = _collectBuyerFields();
    if (fields == null) return null;

    setState(() => _busy = true);

    // Read the notifier before the request so the clear below still works if
    // the buyer leaves the page while `create_order` is in flight.
    final cart = ref.read(cartControllerProvider.notifier);

    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .createOrder(
            items: [
              for (final line in lines)
                OrderItemRequest(variantId: line.variantId, qty: line.qty),
            ],
            coupon: _coupon.text.trim().isEmpty ? null : _coupon.text.trim(),
            fields: fields,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) setState(() => _busy = false);
      // The order now owns the lines, fields and prices. Leaving the cart
      // populated after a successful checkout made it look as though nothing
      // had been bought, and a second checkout would create a duplicate order.
      // Payment that is still pending, failed or expired is resumed from the
      // order page, not by rebuilding the cart.
      await cart.clear();
      return order;
    } on OrderException catch (error) {
      if (error.code == 'missing_fields' || error.code == 'invalid_fields') {
        // The database is the authority and it names the fields it rejected, by
        // key. Put each message under the input that carries it rather than in a
        // toast at the bottom of a long page.
        final problem = error.code == 'missing_fields'
            ? FieldProblem.empty
            : FieldProblem.format;
        final errors = _errorsForReportedKeys(error.detail, problem);

        setState(() {
          _busy = false;
          _fieldErrors = errors;
        });

        if (errors.isEmpty) _toast(l10n.requiredInfo);
        return null;
      }

      if (error.code == 'qty_out_of_range') {
        // A cart saved before this line's per-line cap was known: the buyer has
        // two of something the supplier only delivers once. Retrying the same
        // cart can only fail again, so the line is corrected here and the buyer
        // is told what changed.
        final corrected = await _correctOutOfRangeLines(error.detail);
        if (mounted) {
          setState(() => _busy = false);
          _toast(corrected ? l10n.qtyOnePerOrder : l10n.somethingWentWrong);
        }
        return null;
      }

      if (error.code == 'product_unavailable' ||
          error.code == 'variant_unavailable') {
        // The catalogue changed between load and submit. Reconcile again so the
        // next attempt is honest, and name the reason instead of "something
        // went wrong".
        await _reconcile();
        ref.invalidate(productsProvider);
        if (mounted) setState(() => _busy = false);
        return null;
      }

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

  /// Maps the field keys `create_order` reports onto the inputs that hold them.
  Map<String, String?> _errorsForReportedKeys(
    String? detail,
    FieldProblem problem,
  ) {
    final l10n = AppL10n.of(context);
    final reported = (detail ?? '')
        .split(',')
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();

    final errors = <String, String?>{};
    for (final line in ref.read(cartControllerProvider)) {
      for (final field in line.requiredFields) {
        if (reported.contains(field.key)) {
          errors[_fieldKey(line.variantId, field.key)] = fieldProblemMessage(
            l10n,
            field,
            problem,
          );
        }
      }
    }

    return errors;
  }

  /// Database error codes are stable identifiers; this maps them to copy.
  String _humanise(String code, AppL10n l10n) => switch (code) {
    'out_of_stock' => l10n.outOfStock,
    'coupon_invalid' => l10n.couponInvalid,
    'coupon_exhausted' => l10n.couponInvalid,
    'coupon_user_limit' => l10n.couponInvalid,
    'coupon_min_order' => l10n.couponInvalid,
    'qty_out_of_range' => l10n.qtyOnePerOrder,
    'product_unavailable' => l10n.itemUnavailable,
    'variant_unavailable' => l10n.itemUnavailable,
    'missing_fields' => l10n.requiredInfo,
    'invalid_fields' => l10n.fieldWrongFormat,
    'empty_cart' => l10n.cartEmpty,
    'auth_required' => l10n.guestMustSignIn,
    'account_blocked' => l10n.accountBlocked,
    'order_expired' => l10n.statusExpired,
    'too_many_lines' => l10n.tooManyLines,
    // Naming the real problem beats "Something went wrong": this one means a
    // credential is missing on the project, not that the user did anything
    // wrong, and it is the first thing hit on a fresh environment.
    'payway_not_configured' => l10n.paywayNotConfigured,
    'payway_rejected' => l10n.paywayRejected,
    'dodo_not_configured' => l10n.cardNotConfigured,
    'store_url_not_configured' => l10n.paymentUnreachable,
    'checkout_url_missing' => l10n.paymentUnreachable,
    'payment_record_failed' => l10n.paymentUnreachable,
    'dodo_unreachable' => l10n.paymentUnreachable,
    'dodo_http_400' => l10n.paymentUnreachable,
    'dodo_http_422' => l10n.paymentUnreachable,
    // Transport failures on the QR step. The order exists by then, so the
    // message points at the transfer fallback instead of just failing.
    'network_error' => l10n.paymentUnreachable,
    'non_json_response' => l10n.paymentUnreachable,
    'order_lookup_failed' => l10n.paymentUnreachable,
    _ => l10n.somethingWentWrong,
  };

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PayMethod { khqr, card, wallet }

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.12)
              : AppColors.ink850,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.ink700,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.brand : AppColors.ink200,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.ink400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.brand : AppColors.ink400,
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.step});

  final String title;
  final Widget child;
  final int? step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (step != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // Solid, not a brand tint: brand-on-brand-tint measured
                    // about 2.4:1. The dark ink on the brand fill is 5.26:1.
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBrand,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
