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

/// The one big tile at the top of home. Full-bleed art, a gradient scrim, and
/// the price and action over it, so the first thing on the page is a game
/// rather than a row of text.
class SpotlightTile extends StatelessWidget {
  const SpotlightTile({required this.product, super.key});

  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return PressScale(
      child: GestureDetector(
        onTap: () => context.go('/products/${product.slug}'),
        child: Container(
          height: wide ? 260 : 200,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.hero),
            border: Border.all(color: AppColors.ink800),
            boxShadow: AppGlow.of(AppColors.violet, strength: 0.22, blur: 40),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (product.imageUrl != null)
                CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.ink850),
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: AppColors.ink850),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.ink950.withValues(alpha: 0.96),
                      AppColors.ink950.withValues(alpha: 0.7),
                      AppColors.ink950.withValues(alpha: 0.05),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 28 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.brand, AppColors.violet],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        l10n.featured,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 420 : 230),
                      child: Text(
                        product.name(locale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: wide ? 30 : 22,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${l10n.from} ',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ink400,
                          ),
                        ),
                        Text(
                          money(product.minPriceUsd),
                          style: TextStyle(
                            fontSize: wide ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/products/${product.slug}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(l10n.buyNow),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Games this buyer has ordered before, newest first. One tap back to the game
/// they already know. Hidden entirely for a signed-out visitor or a first
/// order, rather than showing an empty shelf.
class BuyAgainRow extends ConsumerWidget {
  const BuyAgainRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final orders = ref.watch(ordersProvider).valueOrNull;
    if (orders == null || orders.isEmpty) return const SizedBox.shrink();

    final catalogue = ref.watch(productsProvider(const ProductQuery()));
    final byId = <int, ProductCard>{
      for (final product in catalogue.valueOrNull ?? const <ProductCard>[])
        product.id: product,
    };

    final seen = <int>{};
    final recent = <ProductCard>[];
    for (final order in orders) {
      for (final line in order.items) {
        final id = line.productId;
        if (id == null || !seen.add(id)) continue;
        final product = byId[id];
        if (product != null) recent.add(product);
        if (recent.length == 6) break;
      }
      if (recent.length == 6) break;
    }

    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.buyAgain, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = recent[index];

              return PressScale(
                child: GestureDetector(
                  onTap: () => context.go('/products/${product.slug}'),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.ink900,
                      border: Border.all(color: AppColors.ink800),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: product.imageUrl == null
                                ? const ColoredBox(
                                    color: AppColors.ink850,
                                    child: Icon(
                                      Icons.sports_esports_outlined,
                                      size: 20,
                                      color: AppColors.ink400,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => const ColoredBox(
                                      color: AppColors.ink850,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.name(
                                  Localizations.localeOf(context).languageCode,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                money(product.minPriceUsd),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.replay_rounded,
                          size: 16,
                          color: AppColors.ink400,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// What is actually selling, from the real `sold_count` on each product. This
/// is a ranking, not a live feed: the store exposes no recent-purchase stream,
/// so nothing here claims to be happening right now.
class TrendingTicker extends StatelessWidget {
  const TrendingTicker({required this.products, super.key});

  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final selling = products.where((p) => p.soldCount > 0).toList()
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final top = selling.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: AppGlow.tight(AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.trendingNow,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 18,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: top.length,
                separatorBuilder: (_, _) => const VerticalDivider(
                  width: 18,
                  thickness: 1,
                  color: AppColors.ink800,
                ),
                itemBuilder: (context, index) {
                  final product = top[index];

                  return Center(
                    child: Text(
                      '${product.name(locale)} · '
                      '${compactCount(product.soldCount)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink200,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
