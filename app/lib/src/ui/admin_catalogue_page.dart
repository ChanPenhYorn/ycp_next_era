import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';

/// Show or hide a product, and set retail prices.
///
/// Hiding is reversible and changes nothing for buyers who already ordered.
/// A price is checked twice: here for a sensible number, and in the database
/// against the supplier cost, which is the rule that matters.
class AdminCataloguePage extends ConsumerWidget {
  const AdminCataloguePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final catalogue = ref.watch(adminCatalogueProvider);

    void refresh() {
      ref.invalidate(adminCatalogueProvider);
      ref.invalidate(adminOverviewProvider);
    }

    return AdminGate(
      child: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminHeader(
              title: l10n.adminCatalogueTitle,
              subtitle: l10n.adminCatalogueNote,
              onBack: () => context.go('/admin'),
              action: IconButton(
                tooltip: l10n.retry,
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: refresh,
              ),
            ),
            const SizedBox(height: 14),
            AsyncValueView(
              value: catalogue,
              onRetry: refresh,
              builder: (products) => products.isEmpty
                  ? AdminEmpty(l10n.adminCatalogueEmpty)
                  : Column(
                      children: [
                        for (final product in products)
                          _ProductCard(product: product, onDone: refresh),
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

class _ProductCard extends ConsumerStatefulWidget {
  const _ProductCard({required this.product, required this.onDone});

  final AdminCatalogueProduct product;
  final VoidCallback onDone;

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final product = widget.product;

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
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Switch(
                value: product.isActive,
                onChanged: _busy ? null : _setActive,
              ),
            ],
          ),
          Text(
            [
              product.slug,
              if (product.supplierCode != null) product.supplierCode!,
              product.isActive
                  ? l10n.adminProductShown
                  : l10n.adminProductHidden,
            ].join(' · '),
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
          const SizedBox(height: 8),
          for (final variant in product.variants)
            _VariantRow(
              variant: variant,
              busy: _busy,
              onEdit: () => _editPrice(variant),
            ),
        ],
      ),
    );
  }

  Future<void> _setActive(bool active) async {
    final l10n = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setProductActive(productId: widget.product.id, active: active);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onDone();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        error.code == 'not_authorized'
            ? l10n.adminOnly
            : l10n.somethingWentWrong,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  Future<void> _editPrice(AdminCatalogueVariant variant) async {
    final l10n = AppL10n.of(context);
    final input = await askAdminText(
      context,
      title: '${variant.label} · ${variant.sku}',
      label: l10n.adminVariantPrice,
      helper: l10n.adminVariantPriceHint,
      confirmLabel: l10n.adminSavePrice,
      initialValue: variant.priceUsd.toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      mandatory: true,
    );
    if (input == null) return;

    final price = double.tryParse(input.trim());
    if (price == null || price <= 0) {
      _toast(l10n.adminPriceInvalid);
      return;
    }
    if (variant.costUsd != null && price < variant.costUsd!) {
      _toast(l10n.adminPriceBelowCost);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setVariantPrice(variantId: variant.id, priceUsd: price);
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.adminPriceSaved);
      widget.onDone();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(switch (error.code) {
        'price_below_cost' => l10n.adminPriceBelowCost,
        'invalid_price' => l10n.adminPriceInvalid,
        'not_authorized' => l10n.adminOnly,
        _ => l10n.somethingWentWrong,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({
    required this.variant,
    required this.busy,
    required this.onEdit,
  });

  final AdminCatalogueVariant variant;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final margin = variant.marginUsd;

    return InkWell(
      onTap: busy ? null : onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                variant.label,
                style: const TextStyle(fontSize: 12, color: AppColors.ink200),
              ),
            ),
            Text(
              money(variant.priceUsd),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${l10n.adminCostLabel} ${variant.costUsd == null ? '—' : money(variant.costUsd!)}',
              style: const TextStyle(fontSize: 10.5, color: AppColors.ink400),
            ),
            const SizedBox(width: 8),
            if (margin != null)
              Text(
                '${l10n.adminMarginLabel} ${money(margin)}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: margin < 0 ? AppColors.danger : AppColors.ink400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
