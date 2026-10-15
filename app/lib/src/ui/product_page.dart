import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';

class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  int? _selectedVariantId;
  int _qty = 1;
  final _fieldControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final detail = ref.watch(productDetailProvider((widget.slug, locale)));

    return AsyncValueView(
      value: detail,
      onRetry: () => ref.invalidate(productDetailProvider((widget.slug, locale))),
      builder: (product) {
        if (product == null) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                l10n.noProducts,
                style: const TextStyle(color: AppColors.ink400),
              ),
            ),
          );
        }

        final variants = product.variants;
        final selected = variants.firstWhere(
          (v) => v.id == _selectedVariantId,
          orElse: () => variants.firstWhere(
            (v) => !v.isSoldOut,
            orElse: () => variants.first,
          ),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Gallery(product: product),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name(locale),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MetaRow(product: product, l10n: l10n),
            if (product.description != null) ...[
              const SizedBox(height: 14),
              Text(
                product.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.ink200,
                  height: 1.7,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              l10n.deliveryTime,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              product.card.kind == ProductKind.instantStock
                  ? l10n.deliveryInstant
                  : l10n.deliveryManual,
              style: const TextStyle(fontSize: 12, color: AppColors.accent),
            ),
            if (variants.length > 1) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variant in variants)
                    ChoiceChip(
                      label: Text(
                        '${variant.label(locale)} · ${money(variant.priceUsd)}',
                      ),
                      selected: variant.id == selected.id,
                      onSelected: variant.isSoldOut
                          ? null
                          : (_) => setState(() {
                                _selectedVariantId = variant.id;
                                _qty = variant.minQty;
                              }),
                    ),
                ],
              ),
            ],
            if (product.requiresFields.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.requiredInfo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              for (final field in product.requiresFields) ...[
                TextField(
                  controller: _fieldControllers.putIfAbsent(
                    field.key,
                    TextEditingController.new,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: field.label(locale),
                    hintText: field.placeholder,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 20),
            _QuantityRow(
              label: l10n.quantity,
              variant: selected,
              qty: _qty,
              onChanged: (value) => setState(() => _qty = value),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selected.isSoldOut
                        ? null
                        : () => _addToCart(l10n, product, selected),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(l10n.addToCart),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        selected.isSoldOut ? null : () => _buyNow(l10n, product, selected),
                    child: Text(l10n.buyNow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _Reviews(productId: product.card.id, l10n: l10n),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  /// Returns the collected values, or null if a required field is missing or
  /// does not match the pattern the catalogue declares.
  Map<String, String>? _collectFields(AppL10n l10n, ProductDetail product) {
    final values = <String, String>{};

    for (final field in product.requiresFields) {
      final raw = _fieldControllers[field.key]?.text.trim() ?? '';

      if (raw.isEmpty) {
        _toast('${l10n.requiredInfo}: ${field.label(_locale())}');
        return null;
      }

      final pattern = field.pattern;
      if (pattern != null && !RegExp(pattern).hasMatch(raw)) {
        _toast('${field.label(_locale())}: ${field.placeholder ?? pattern}');
        return null;
      }

      values[field.key] = raw;
    }

    return values;
  }

  String _locale() => ref.read(localeControllerProvider).languageCode;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _addToCart(AppL10n l10n, ProductDetail product, Variant variant) {
    final fields = _collectFields(l10n, product);
    if (fields == null) return;
    final locale = _locale();

    ref.read(cartControllerProvider.notifier).add(
          variantId: variant.id,
          productSlug: product.card.slug,
          productName: product.name(locale),
          variantLabel: variant.label(locale),
          unitPriceUsd: variant.priceUsd,
          minQty: variant.minQty,
          maxQty: variant.maxQty,
          qty: _qty,
          fields: fields,
        );

    _toast(l10n.addToCart);
  }

  void _buyNow(AppL10n l10n, ProductDetail product, Variant variant) {
    final fields = _collectFields(l10n, product);
    if (fields == null) return;

    ref.read(cartControllerProvider.notifier).add(
          variantId: variant.id,
          productSlug: product.card.slug,
          productName: product.name(_locale()),
          variantLabel: variant.label(_locale()),
          unitPriceUsd: variant.priceUsd,
          minQty: variant.minQty,
          maxQty: variant.maxQty,
          qty: _qty,
          fields: fields,
        );

    context.go('/checkout');
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.label,
    required this.variant,
    required this.qty,
    required this.onChanged,
  });

  final String label;
  final Variant variant;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = variant.isUnlimited
        ? variant.maxQty
        : (variant.inStock ?? 0).clamp(0, variant.maxQty);

    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 14),
        IconButton.filledTonal(
          onPressed: qty > variant.minQty ? () => onChanged(qty - 1) : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$qty', style: const TextStyle(fontSize: 16)),
        ),
        IconButton.filledTonal(
          onPressed: qty < max ? () => onChanged(qty + 1) : null,
          icon: const Icon(Icons.add, size: 18),
        ),
        const Spacer(),
        Text(
          money(variant.priceUsd * qty),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.product, required this.l10n});

  final ProductDetail product;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final card = product.card;

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        if (card.ratingCount > 0)
          Text(
            '★ ${card.ratingAvg.toStringAsFixed(1)} (${card.ratingCount})',
            style: const TextStyle(fontSize: 12, color: AppColors.warn),
          ),
        Text(
          l10n.soldCount(card.soldCount),
          style: const TextStyle(fontSize: 12, color: AppColors.ink400),
        ),
        Text(
          card.isSoldOut ? l10n.outOfStock : '✓ ${l10n.inStock}',
          style: TextStyle(
            fontSize: 12,
            color: card.isSoldOut ? AppColors.danger : AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.product});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: product.card.imageUrl == null
            ? const ColoredBox(
                color: AppColors.ink850,
                child: Center(child: Text('📦', style: TextStyle(fontSize: 44))),
              )
            : CachedNetworkImage(
                imageUrl: product.card.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: AppColors.ink850),
              ),
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.productId, required this.l10n});

  final int productId;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider(productId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reviews,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        AsyncValueView(
          value: reviews,
          builder: (items) {
            if (items.isEmpty) {
              return Text(
                l10n.noReviews,
                style: const TextStyle(fontSize: 12, color: AppColors.ink400),
              );
            }

            return Column(
              children: [
                for (final review in items)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
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
                              review.authorName ?? '—',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              '★' * review.rating,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warn,
                              ),
                            ),
                          ],
                        ),
                        if (review.body != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            review.body!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.ink400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
