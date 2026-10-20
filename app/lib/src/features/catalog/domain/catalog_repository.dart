import 'catalog_entities.dart';

/// Read-only access to the public catalogue.
abstract class CatalogRepository {
  Future<PublicSettings> settings();

  Future<List<Category>> categories();

  Future<List<ProductCard>> products({
    String? categorySlug,
    String? search,
    bool featuredOnly = false,
    bool popularFirst = false,
    int limit = 48,
  });

  Future<ProductDetail?> productBySlug(String slug, String locale);

  Future<List<Review>> reviews(int productId);

  /// The live catalogue answer for [variantIds], keyed by variant id.
  ///
  /// Both halves of `create_order`'s availability check are visible from the one
  /// query: `variants_public_read` hides inactive variants, and the embedded
  /// `products` row arrives null when `products_public_read` hides the product.
  /// An id with no entry is one the buyer cannot order any more.
  ///
  /// A saved cart carries the SKU and quantity range it was built with, and
  /// those go stale: a supplier sync that caps a line at one unit, or renames a
  /// SKU, happens after the line was stored. This is where the cart re-reads
  /// them.
  Future<Map<int, LiveVariant>> liveVariants(List<int> variantIds);
}
