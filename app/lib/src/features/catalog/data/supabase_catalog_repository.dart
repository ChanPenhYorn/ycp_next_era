import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models.dart';
import 'catalog_mappers.dart';
import '../domain/catalog_repository.dart';

/// Columns every `variantFromJson` read depends on.
///
/// Kept as a constant and reused by each query so the two cannot drift. They
/// did once: the list query omitted sku/label_km/label_en, so parsing threw
/// `type 'Null' is not a subtype of type 'String'` and the whole catalogue
/// page failed as soon as real data existed. `test/parsing_test.dart` guards it.
const variantColumns =
    'id, sku, label_km, label_en, price_usd, '
    'compare_at_price_usd, stock_mode, min_qty, max_qty';

/// Columns `categoryFromJson` reads.
const categoryColumns = 'id, slug, name_km, name_en';

/// Read-only access to the public catalogue. Every query here maps to a
/// `select` policy in `0002_rls.sql`; no privileged key is involved.
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PublicSettings> settings() async {
    final row = await _client
        .from('public_settings')
        .select(
          'site_name, support_telegram, support_email, usd_to_khr, order_ttl_minutes, '
          'topup_min_usd, topup_max_usd, khqr_account_id, khqr_merchant_name, '
          'manual_grace_minutes',
        )
        .maybeSingle();

    if (row == null) return PublicSettings.fallback;

    return PublicSettings(
      siteName: row['site_name'] as String? ?? 'Chanpenh',
      usdToKhr: (row['usd_to_khr'] as num?)?.toDouble() ?? 4100,
      orderTtlMinutes: (row['order_ttl_minutes'] as num?)?.toInt() ?? 15,
      topupMinUsd: (row['topup_min_usd'] as num?)?.toDouble() ?? 1,
      topupMaxUsd: (row['topup_max_usd'] as num?)?.toDouble() ?? 1000,
      supportTelegram: row['support_telegram'] as String?,
      supportEmail: row['support_email'] as String?,
      khqrAccountId: row['khqr_account_id'] as String?,
      khqrMerchantName: row['khqr_merchant_name'] as String?,
      manualGraceMinutes:
          (row['manual_grace_minutes'] as num?)?.toInt() ?? 1440,
    );
  }

  @override
  Future<List<Category>> categories() async {
    final rows = await _client
        .from('categories')
        .select('id, slug, name_km, name_en')
        // supabase-dart's order() defaults to DESCENDING, which silently
        // reversed every sort_order list: the catalogue read right to left and
        // a supplier game showed its 112 packs highest-price-first.
        .order('sort_order', ascending: true);

    return rows.map(categoryFromJson).toList();
  }

  @override
  Future<List<ProductCard>> products({
    String? categorySlug,
    String? search,
    bool featuredOnly = false,
    bool popularFirst = false,
    int limit = 48,
  }) async {
    var query = _client
        .from('products')
        .select(
          'id, slug, name_km, name_en, image_url, banner_url, kind, rating_avg, rating_count, '
          'sold_count, category:categories ( $categoryColumns ), '
          'variants:product_variants ( $variantColumns )',
        );

    // Filters must be applied before order/limit: those return a transform
    // builder that no longer accepts `.eq`.
    if (featuredOnly) query = query.eq('is_featured', true);
    if (categorySlug != null) query = query.eq('categories.slug', categorySlug);
    if (search != null && search.trim().isNotEmpty) {
      final term = search.replaceAll(RegExp(r'[%,]'), ' ').trim();
      query = query.or(
        'name_km.ilike.%$term%,name_en.ilike.%$term%,slug.ilike.%$term%',
      );
    }

    // `popular` is real, not a curated list: sold_count is incremented on
    // delivery, so the row order is the store's own sales history.
    final ordered = popularFirst
        ? query
              .order('sold_count', ascending: false)
              .order('sort_order', ascending: true)
        : query.order('sort_order', ascending: true);

    final rows = await ordered.limit(limit);

    final stock = await _stockFor([
      for (final row in rows)
        for (final v in (row['variants'] as List? ?? const []))
          ((v as Map)['id'] as num).toInt(),
    ]);

    return rows.map((row) => _cardFrom(row, stock)).toList();
  }

  @override
  Future<ProductDetail?> productBySlug(String slug, String locale) async {
    final row = await _client
        .from('products')
        .select(
          'id, slug, name_km, name_en, summary_km, summary_en, description_km, '
          'description_en, image_url, banner_url, kind, requires_fields, rating_avg, '
          'rating_count, sold_count, '
          'category:categories ( $categoryColumns ), '
          'variants:product_variants ( $variantColumns )',
        )
        .eq('slug', slug)
        .maybeSingle();

    if (row == null) return null;

    final variantRows = await _client
        .from('product_variants')
        .select('$variantColumns, sort_order')
        .eq('product_id', row['id'])
        .order('sort_order', ascending: true);

    final stock = await _stockFor(
      variantRows.map((v) => (v['id'] as num).toInt()).toList(),
    );

    final variants = variantRows.map((v) {
      final mode = v['stock_mode'] as String? ?? 'stock';
      return variantFromJson({
        ...v,
        'in_stock': mode == 'unlimited'
            ? null
            : (stock[(v['id'] as num).toInt()] ?? 0),
      });
    }).toList();

    final card = _cardFrom(row, stock, overrideVariants: variants);

    final rawDescription = locale == 'km'
        ? row['description_km']
        : row['description_en'];
    final rawSummary = locale == 'km' ? row['summary_km'] : row['summary_en'];

    return ProductDetail(
      card: card,
      description: (rawDescription ?? rawSummary) as String?,
      requiresFields: ((row['requires_fields'] as List?) ?? const [])
          .map((e) => requiredFieldFromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      variants: variants,
    );
  }

  /// `variants_public_read` filters inactive variants, and the embedded
  /// `products` row arrives null when `products_public_read` hides it, so a
  /// variant of a hidden product is the row with a null product. Both halves of
  /// `create_order`'s check are therefore visible from this single query, along
  /// with the quantity range the line has to satisfy.
  @override
  Future<Map<int, LiveVariant>> liveVariants(List<int> variantIds) async {
    if (variantIds.isEmpty) return const {};

    final rows = await _client
        .from('product_variants')
        .select('id, sku, min_qty, max_qty, product:products ( is_active )')
        .inFilter('id', variantIds);

    return {
      for (final row in rows)
        if ((row['product'] as Map?)?['is_active'] == true)
          (row['id'] as num).toInt(): LiveVariant(
            id: (row['id'] as num).toInt(),
            sku: row['sku'] as String? ?? '',
            minQty: (row['min_qty'] as num?)?.toInt() ?? 1,
            maxQty: (row['max_qty'] as num?)?.toInt() ?? 1,
          ),
    };
  }

  @override
  Future<List<Review>> reviews(int productId) async {
    final rows = await _client
        .from('reviews')
        .select(
          'id, rating, body, created_at, author:profile_names ( display_name )',
        )
        .eq('product_id', productId)
        .eq('is_approved', true)
        .order('created_at', ascending: false)
        .limit(20);

    return rows.map((row) {
      final author = row['author'] as Map<String, dynamic>?;
      return Review(
        id: row['id'] as int,
        rating: (row['rating'] as num).toInt(),
        body: row['body'] as String?,
        authorName: author?['display_name'] as String?,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<Map<int, int>> _stockFor(List<int> variantIds) async {
    if (variantIds.isEmpty) return {};

    final rows = await _client
        .from('variant_stock')
        .select('variant_id, in_stock')
        .inFilter('variant_id', variantIds);

    return {
      for (final row in rows)
        (row['variant_id'] as num).toInt():
            (row['in_stock'] as num?)?.toInt() ?? 0,
    };
  }

  /// Builds a card from a product row that carries its variants inline.
  /// [overrideVariants] is used by the detail page, which already resolved
  /// per-variant stock.
  ProductCard _cardFrom(
    Map<String, dynamic> row,
    Map<int, int> stock, {
    List<Variant>? overrideVariants,
  }) {
    final rawVariants = (row['variants'] as List? ?? const [])
        .map((v) => (v as Map).cast<String, dynamic>())
        .toList();

    final variants =
        overrideVariants ??
        rawVariants.map((v) {
          final mode = v['stock_mode'] as String? ?? 'stock';
          return variantFromJson({
            ...v,
            'in_stock': mode == 'unlimited'
                ? null
                : (stock[(v['id'] as num).toInt()] ?? 0),
          });
        }).toList();

    final prices = variants.map((v) => v.priceUsd).toList();
    final compares = variants
        .map((v) => v.compareAtPriceUsd)
        .whereType<double>()
        .toList();

    // Unlimited variants mean "never sells out", so the aggregate is null.
    final allUnlimited =
        variants.isNotEmpty && variants.every((v) => v.isUnlimited);
    final totalStock = allUnlimited
        ? null
        : variants.fold<int>(0, (sum, v) => sum + (v.inStock ?? 0));

    final categoryRow = row['category'] as Map<String, dynamic>?;

    return ProductCard(
      id: (row['id'] as num).toInt(),
      slug: row['slug'] as String? ?? '',
      nameKm: row['name_km'] as String? ?? '',
      nameEn: row['name_en'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      bannerUrl: row['banner_url'] as String?,
      kind: productKindFrom(row['kind'] as String? ?? 'manual_setup'),
      ratingAvg: (row['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
      soldCount: (row['sold_count'] as num?)?.toInt() ?? 0,
      minPriceUsd: prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b),
      maxPriceUsd: prices.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b),
      compareAtPriceUsd: compares.isEmpty
          ? null
          : compares.reduce((a, b) => a > b ? a : b),
      totalStock: totalStock,
      category: categoryRow == null ? null : categoryFromJson(categoryRow),
    );
  }
}
