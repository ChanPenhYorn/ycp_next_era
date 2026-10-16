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
}
