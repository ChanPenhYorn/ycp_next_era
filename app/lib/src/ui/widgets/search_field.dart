import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';
import 'product_art.dart';

/// Search that answers while you type. Matches the game name in either
/// language and the slug, then shows a small results panel under the field.
/// Picking a result opens the game; pressing Enter goes to the full results.
class GameSearchField extends ConsumerStatefulWidget {
  const GameSearchField({
    this.initialText,
    this.hint,
    this.autofocus = false,
    this.onSubmit,
    this.pill = false,
    super.key,
  });

  final String? initialText;
  final String? hint;
  final bool autofocus;

  /// Called with the raw term when the field is submitted.
  final ValueChanged<String>? onSubmit;

  /// Fully rounded, for the top bar. Square-ish otherwise.
  final bool pill;

  @override
  ConsumerState<GameSearchField> createState() => _GameSearchFieldState();
}

class _GameSearchFieldState extends ConsumerState<GameSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText ?? '',
  );
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<ProductCard> _matches(String raw) {
    final term = raw.trim().toLowerCase();
    if (term.isEmpty) return const [];
    final all = ref.read(productsProvider(const ProductQuery())).valueOrNull;
    if (all == null) return const [];

    return all
        .where(
          (p) =>
              p.nameEn.toLowerCase().contains(term) ||
              p.nameKm.toLowerCase().contains(term) ||
              p.slug.contains(term),
        )
        .take(7)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = ref.watch(localeControllerProvider).languageCode;
    final radius = widget.pill ? AppRadius.pill : AppRadius.control;

    return RawAutocomplete<ProductCard>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: (value) => _matches(value.text),
      displayStringForOption: (option) => option.name(locale),
      onSelected: (option) => context.go('/products/${option.slug}'),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _focus.unfocus();
            widget.onSubmit?.call(value);
          },
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint ?? l10n.searchGames,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.2),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList();
        if (items.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: AppColors.ink850,
              elevation: 12,
              shadowColor: Colors.black,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: Container(
                  width: 360,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: AppColors.ink700),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final product = items[index];
                      final price = money(product.minPriceUsd);

                      return InkWell(
                        onTap: () => onSelected(product),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: AppColors.ink900,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.tile,
                                  ),
                                ),
                                child: product.imageUrl == null
                                    ? const ProductArtFallback()
                                    : CachedNetworkImage(
                                        imageUrl: product.imageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => const SizedBox(),
                                        errorWidget: (_, _, _) =>
                                            const ProductArtFallback(),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  product.name(locale),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                product.hasPriceRange
                                    ? '${l10n.from} $price'
                                    : price,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink200,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
