import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/product_card.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({this.categorySlug, this.search, super.key});

  final String? categorySlug;
  final String? search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final categories = ref.watch(categoriesProvider);
    final query = ProductQuery(categorySlug: categorySlug, search: search);
    final products = ref.watch(productsProvider(query));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          search != null && search!.isNotEmpty
              ? '"$search"'
              : l10n.allProducts,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        AsyncValueView(
          value: categories,
          builder: (items) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.all),
                selected: categorySlug == null,
                onSelected: (_) => context.go('/products'),
              ),
              for (final category in items)
                ChoiceChip(
                  label: Text(category.name(locale)),
                  selected: categorySlug == category.slug,
                  onSelected: (_) =>
                      context.go('/products?category=${category.slug}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AsyncValueView(
          value: products,
          onRetry: () => ref.invalidate(productsProvider(query)),
          builder: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    l10n.noProducts,
                    style: const TextStyle(color: AppColors.ink400),
                  ),
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
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  ProductCardTile(product: items[index]),
            );
          },
        ),
      ],
    );
  }
}
