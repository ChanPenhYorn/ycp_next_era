import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/home_sections.dart';
import 'widgets/product_card.dart';
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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    final term = value.trim();
    if (term.isEmpty) return;
    context.go('/products?q=${Uri.encodeComponent(term)}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
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
          const HomeHero(),
          const SizedBox(height: 14),
          // Wide screens already carry the search in the top bar.
          if (MediaQuery.sizeOf(context).width < 900) ...[
            _SearchField(
              controller: _searchController,
              hint: l10n.searchGames,
              onSubmitted: _submitSearch,
            ),
            const SizedBox(height: 12),
          ],
          const TrustRow(),
          const SizedBox(height: 22),
          AsyncValueView(
            value: categories,
            onRetry: () => ref.invalidate(categoriesProvider),
            builder: (items) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in items)
                  ActionChip(
                    label: Text(category.name(locale)),
                    onPressed: () =>
                        context.go('/products?category=${category.slug}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(hasSales ? l10n.popularGames : l10n.featured),
          const SizedBox(height: 10),
          AsyncValueView(
            value: topShelf,
            onRetry: () => ref.invalidate(popularGamesProvider),
            builder: (items) => _Grid(products: items),
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
          const PartnerCard(),
          const SizedBox(height: 26),
          SectionTitle(l10n.allProducts, trailing: l10n.allProducts),
          const SizedBox(height: 10),
          AsyncValueView(
            value: all,
            onRetry: () => ref.invalidate(productsProvider),
            builder: (items) => _Grid(products: items),
          ),
          const StoreFooter(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: hint,
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => onSubmitted(controller.text),
        ),
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Slightly taller than the old ratio: each card now carries a real
        // sold count on its footer line.
        childAspectRatio: 0.66,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          ProductCardTile(product: products[index]),
    );
  }
}
