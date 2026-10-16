import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';
import 'motion.dart';

/// One game tile. On desktop it lifts and lights up under the pointer; on touch
/// it scales down while pressed. The art zooms a little on hover so the tile
/// feels alive without any motion on load.
class ProductCardTile extends ConsumerStatefulWidget {
  const ProductCardTile({required this.product, this.index = 0, super.key});

  final ProductCard product;

  /// Position in the grid, used to stagger the entrance.
  final int index;

  @override
  ConsumerState<ProductCardTile> createState() => _ProductCardTileState();
}

class _ProductCardTileState extends ConsumerState<ProductCardTile> {
  bool _hovered = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final product = widget.product;
    final locale = ref.watch(localeControllerProvider).languageCode;
    final off = discountPercent(product.minPriceUsd, product.compareAtPriceUsd);

    return StaggeredEntrance(
      index: widget.index,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _down = false;
        }),
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerUp: (_) => setState(() => _down = false),
          onPointerCancel: (_) => setState(() => _down = false),
          child: GestureDetector(
            onTap: () => context.go('/products/${product.slug}'),
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.ease,
              transform: Matrix4.identity()
                ..translateByDouble(0, _hovered ? -5 : 0, 0, 1)
                ..scaleByDouble(
                  _down
                      ? 0.97
                      : _hovered
                      ? 1.02
                      : 1,
                  _down
                      ? 0.97
                      : _hovered
                      ? 1.02
                      : 1,
                  1,
                  1,
                ),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: _hovered
                      ? AppColors.brand.withValues(alpha: 0.55)
                      : AppColors.ink800,
                ),
                color: AppColors.ink900,
                boxShadow: _hovered
                    ? AppGlow.of(AppColors.brand, strength: 0.32)
                    : const [],
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
                        AnimatedScale(
                          scale: _hovered ? 1.07 : 1,
                          duration: AppMotion.slow,
                          curve: AppMotion.ease,
                          child: product.imageUrl == null
                              ? const _ArtPlaceholder()
                              : CachedNetworkImage(
                                  imageUrl: product.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      const ColoredBox(color: AppColors.ink850),
                                  errorWidget: (_, _, _) =>
                                      const _ArtPlaceholder(),
                                ),
                        ),
                        // Bottom scrim, so the price line never fights the art.
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 42,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0x66000000)],
                              ),
                            ),
                          ),
                        ),
                        if (off != null)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Transform.rotate(
                              angle: -0.055,
                              child: _Badge(
                                text: '-$off%',
                                gradient: const [
                                  AppColors.pink,
                                  AppColors.violet,
                                ],
                              ),
                            ),
                          ),
                        if (product.isSoldOut)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _Badge(
                              text: l10n.outOfStock,
                              background: AppColors.ink950.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.category != null)
                            Text(
                              product.category!.name(locale).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.ink400,
                              ),
                            ),
                          const SizedBox(height: 3),
                          // The name takes whatever the price and stock rows
                          // leave behind, so those two rows always sit on the
                          // same line in every tile, however the name wraps.
                          Expanded(
                            child: Text(
                              product.name(locale),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (product.hasPriceRange)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    '${l10n.from} ',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.ink400,
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  money(product.minPriceUsd),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (product.ratingCount > 0)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: AppColors.warn,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      product.ratingAvg.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warn,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: product.isSoldOut
                                      ? AppColors.danger
                                      : AppColors.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: product.isSoldOut
                                      ? null
                                      : AppGlow.tight(AppColors.accent),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                product.isSoldOut
                                    ? l10n.outOfStock
                                    : l10n.inStock,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: product.isSoldOut
                                      ? AppColors.danger
                                      : AppColors.accent,
                                ),
                              ),
                              if (product.soldCount > 0)
                                Expanded(
                                  child: Text(
                                    l10n.soldCount(
                                      compactCount(product.soldCount),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.ink400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.ink850,
      child: Center(
        child: Icon(
          Icons.sports_esports_outlined,
          size: 34,
          color: AppColors.ink400,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.background, this.gradient});

  final String text;
  final Color? background;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient == null ? null : LinearGradient(colors: gradient!),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: gradient == null ? null : AppGlow.tight(gradient!.first),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
