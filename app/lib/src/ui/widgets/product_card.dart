import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

class ProductCardTile extends ConsumerWidget {
  const ProductCardTile({required this.product, super.key});

  final ProductCard product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final off = discountPercent(product.minPriceUsd, product.compareAtPriceUsd);

    return InkWell(
      onTap: () => context.go('/products/${product.slug}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ink900,
          border: Border.all(color: AppColors.ink800),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl == null
                      ? const ColoredBox(
                          color: AppColors.ink850,
                          child: Center(child: Text('📦', style: TextStyle(fontSize: 30))),
                        )
                      : CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppColors.ink850),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: AppColors.ink850,
                            child: Center(child: Text('📦', style: TextStyle(fontSize: 30))),
                          ),
                        ),
                  if (off != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _Badge(
                        text: '-$off%',
                        background: AppColors.danger,
                      ),
                    ),
                  if (product.isSoldOut)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _Badge(
                        text: l10n.outOfStock,
                        background: AppColors.ink950.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.category != null)
                    Text(
                      product.category!.name(locale).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: AppColors.ink400,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    product.name(locale),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (product.hasPriceRange)
                        Text(
                          '${l10n.from} ',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.ink400,
                          ),
                        ),
                      Text(
                        money(product.minPriceUsd),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (product.compareAtPriceUsd != null &&
                          product.compareAtPriceUsd! > product.minPriceUsd) ...[
                        const SizedBox(width: 5),
                        Text(
                          money(product.compareAtPriceUsd!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ink400,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (product.ratingCount > 0)
                        Text(
                          '★ ${product.ratingAvg.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.warn,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.isSoldOut ? l10n.outOfStock : '✓ ${l10n.inStock}',
                    style: TextStyle(
                      fontSize: 10,
                      color: product.isSoldOut
                          ? AppColors.danger
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.background});

  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
