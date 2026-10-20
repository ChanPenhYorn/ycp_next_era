import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/home_bento.dart';
import 'widgets/home_sections.dart';
import 'widgets/motion.dart';
import 'widgets/product_card.dart';
import 'widgets/search_field.dart';
import 'widgets/skeleton.dart';
import 'widgets/store_footer.dart';

/// Home, in the order `implement.md` §6 asks for: search, popular games,
/// promotions, how it works, trust and support.
///
/// Every section that carries a claim is driven by data: popular ordering by
/// real `sold_count`, and promotions by a variant whose `compare_at_price_usd`
/// beats its live price. An empty list hides the section rather than showing a
/// banner nobody can back up.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  void _submitSearch(String value) {
    final term = value.trim();
    if (term.isEmpty) return;
    context.go('/products?q=${Uri.encodeComponent(term)}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(settingsProvider);
    final categories = ref.watch(categoriesProvider);
    final popular = ref.watch(popularGamesProvider);
    final featured = ref.watch(
      productsProvider(const ProductQuery(featuredOnly: true)),
    );
    final promotions = ref.watch(promotionsProvider);
    final all = ref.watch(productsProvider(const ProductQuery()));

    // Sold-count ordering has nothing to say on a store with no orders yet, so
    // fall back to the staff-curated list and label it as such.
    final hasSales = (popular.valueOrNull ?? const <ProductCard>[]).isNotEmpty;
    final topShelf = hasSales ? popular : featured;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        ref.invalidate(popularGamesProvider);
        ref.invalidate(promotionsProvider);
        ref.invalidate(productsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StaggeredEntrance(child: HomeIntroBand()),
          const SizedBox(height: AppSpace.lg),
          // Wide screens already carry the search in the top bar.
          if (MediaQuery.sizeOf(context).width < 900) ...[
            GameSearchField(hint: l10n.searchGames, onSubmit: _submitSearch),
            const SizedBox(height: AppSpace.lg),
          ],
          AsyncValueView(
            value: categories,
            onRetry: () => ref.invalidate(categoriesProvider),
            builder: (items) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final category in items) ...[
                    CategoryPill(category: category),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          // What is actually selling, straight after the categories. Reads as
          // social proof before the first game tile.
          AsyncValueView(
            value: all,
            skeleton: const SkeletonBlock(height: 40, radius: AppRadius.card),
            onRetry: () => ref.invalidate(productsProvider),
            builder: (items) => TrendingTicker(products: items),
          ),
          const SizedBox(height: 22),
          const BuyAgainRow(),
          const SizedBox(height: 24),
          SectionTitle(hasSales ? l10n.popularGames : l10n.featured),
          const SizedBox(height: 12),
          // A bento top: the top few games rotate through one spotlight, then
          // the rest of the shelf becomes the grid. The spotlighted games are
          // dropped from the grid so the same art never appears twice on one
          // screen.
          AsyncValueView(
            value: topShelf,
            skeleton: const ProductGridSkeleton(),
            onRetry: () => ref.invalidate(popularGamesProvider),
            builder: (items) {
              final spotlights = items.take(spotlightSlides).toList();
              final rest = items.skip(spotlights.length).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (spotlights.isNotEmpty) ...[
                    SpotlightCarousel(
                      products: spotlights,
                      badge: hasSales ? l10n.popularGames : l10n.featured,
                    ),
                    // A short shelf is fully consumed by the spotlight, so the
                    // grid is omitted rather than printing "no products"
                    // directly under four games.
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Grid(products: rest),
                    ],
                  ],
                ],
              );
            },
          ),
          // Rendered only when a real discount exists.
          AsyncValueView(
            value: promotions,
            onRetry: () => ref.invalidate(promotionsProvider),
            builder: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),
                      SectionTitle(
                        l10n.promotions,
                        subtitle: l10n.promotionsSubtitle,
                      ),
                      const SizedBox(height: 10),
                      _Grid(products: items),
                    ],
                  ),
          ),
          const SizedBox(height: 26),
          const HowItWorksSection(),
          const SizedBox(height: 26),
          AsyncValueView(
            value: settings,
            onRetry: () => ref.invalidate(settingsProvider),
            builder: (value) => TrustAndSupportSection(settings: value),
          ),
          const SizedBox(height: 26),
          SectionTitle(l10n.allProducts, trailing: l10n.allProducts),
          const SizedBox(height: 10),
          AsyncValueView(
            value: all,
            skeleton: const ProductGridSkeleton(),
            onRetry: () => ref.invalidate(productsProvider),
            builder: (items) => _Grid(products: items),
          ),
          const StoreFooter(),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.products});

  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          AppL10n.of(context).noProducts,
          style: const TextStyle(color: AppColors.ink400),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: productGridDelegate,
      itemCount: products.length,
      itemBuilder: (context, index) =>
          ProductCardTile(product: products[index], index: index),
    );
  }
}
