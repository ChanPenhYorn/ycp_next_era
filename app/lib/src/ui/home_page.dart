import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/product_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final categories = ref.watch(categoriesProvider);
    final featured = ref.watch(
      productsProvider(const ProductQuery(featuredOnly: true)),
    );
    final all = ref.watch(productsProvider(const ProductQuery()));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        ref.invalidate(productsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroBanner(l10n: l10n),
          const SizedBox(height: 16),
          _TrustRow(l10n: l10n),
          const SizedBox(height: 22),
          _SectionTitle(l10n.categories),
          const SizedBox(height: 10),
          AsyncValueView(
            value: categories,
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
          _SectionTitle(l10n.featured, trailing: l10n.allProducts),
          const SizedBox(height: 10),
          AsyncValueView(
            value: featured,
            builder: (items) => _Grid(products: items),
          ),
          const SizedBox(height: 22),
          _SectionTitle(l10n.allProducts),
          const SizedBox(height: 10),
          AsyncValueView(
            value: all,
            builder: (items) => _Grid(products: items),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.products});

  final List<dynamic> products;

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
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          ProductCardTile(product: products[index]),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink800),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16224A), AppColors.ink900],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Chip(label: Text('ABA KHQR')),
          const SizedBox(height: 12),
          Text(
            l10n.heroTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.heroSubtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.ink400),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: FilledButton(
              onPressed: () => context.go('/products'),
              child: Text(l10n.buyNow),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final items = [l10n.trustInstant, l10n.trustPayment, l10n.trustSupport];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.ink900,
              border: Border.all(color: AppColors.ink800),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 15, color: AppColors.accent),
                const SizedBox(width: 7),
                Text(item, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          TextButton(
            onPressed: () => context.go('/products'),
            child: Text(trailing!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
