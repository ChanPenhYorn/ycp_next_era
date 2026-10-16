import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../core/theme.dart';
import '../state/providers.dart';
import 'widgets/async_value_view.dart';
import 'widgets/empty_state.dart';
import 'widgets/product_card.dart';
import 'widgets/skeleton.dart';

/// The game list. Search and category live here, so a buyer can narrow the
/// catalogue without going back to home.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({this.categorySlug, this.search, super.key});

  final String? categorySlug;
  final String? search;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  late final TextEditingController _search = TextEditingController(
    text: widget.search ?? '',
  );

  @override
  void didUpdateWidget(covariant CatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A search from the header lands here with a new term; mirror it.
    if ((widget.search ?? '') != _search.text) {
      _search.text = widget.search ?? '';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _url({String? category, String? query}) {
    final term = query?.trim();
    final params = <String, String>{
      'category': ?category,
      'q': ?(term == null || term.isEmpty ? null : term),
    };
    return params.isEmpty
        ? '/products'
        : Uri(path: '/products', queryParameters: params).toString();
  }

  void _clearSearch() {
    _search.clear();
    context.go(_url(category: widget.categorySlug));
  }

  void _submit(String value) {
    context.go(_url(category: widget.categorySlug, query: value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final categories = ref.watch(categoriesProvider);
    final term = (widget.search ?? '').trim();
    final query = ProductQuery(
      categorySlug: widget.categorySlug,
      search: term.isEmpty ? null : term,
    );
    final products = ref.watch(productsProvider(query));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Wide screens already carry the search in the top bar, so the field
        // here is for phones only. An active term is shown on every size.
        if (MediaQuery.sizeOf(context).width < 900) ...[
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: l10n.searchGames,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.clearSearch,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _clearSearch,
                    ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (term.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(l10n.searchActive(term)),
              onDeleted: _clearSearch,
              deleteIconColor: AppColors.ink400,
            ),
          ),
          const SizedBox(height: 12),
        ],
        AsyncValueView(
          value: categories,
          builder: (items) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.all),
                  selected: widget.categorySlug == null,
                  onSelected: (_) => context.go(_url(query: term)),
                ),
                const SizedBox(width: 8),
                for (final category in items) ...[
                  ChoiceChip(
                    label: Text(category.name(locale)),
                    selected: widget.categorySlug == category.slug,
                    onSelected: (_) =>
                        context.go(_url(category: category.slug, query: term)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        AsyncValueView(
          value: products,
          skeleton: const ProductGridSkeleton(count: 6),
          onRetry: () => ref.invalidate(productsProvider(query)),
          builder: (items) {
            if (items.isEmpty) {
              return term.isEmpty
                  ? EmptyState(
                      icon: Icons.sports_esports_outlined,
                      message: l10n.noProducts,
                    )
                  : EmptyState(
                      icon: Icons.search_off_rounded,
                      message: l10n.searchNoResults,
                      action: OutlinedButton(
                        onPressed: _clearSearch,
                        child: Text(l10n.clearSearch),
                      ),
                    );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: productGridDelegate,
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  ProductCardTile(product: items[index], index: index),
            );
          },
        ),
      ],
    );
  }
}
