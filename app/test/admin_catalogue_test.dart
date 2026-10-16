import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/src/features/admin/data/admin_mappers.dart';

void main() {
  group('AdminCatalogueProduct', () {
    test('reads hidden state, supplier code and variants in sort order', () {
      final product = adminCatalogueProductFromJson({
        'id': 7,
        'slug': 'bay2game-mlbb',
        'name_en': 'Mobile Legends',
        'is_active': false,
        'kind': 'auto_topup',
        'supplier': {'code': 'bay2game'},
        'variants': [
          {
            'id': 2,
            'sku': 'MLBB_500',
            'label_en': '500 Diamonds',
            'price_usd': 7.5,
            'cost_usd': 7.0,
            'is_active': true,
            'sort_order': 2,
          },
          {
            'id': 1,
            'sku': 'MLBB_100',
            'label_en': '100 Diamonds',
            'price_usd': 1.5,
            'cost_usd': 1.4,
            'is_active': true,
            'sort_order': 1,
          },
        ],
      });

      expect(product.isActive, isFalse);
      expect(product.supplierCode, 'bay2game');
      expect(product.variants.map((v) => v.sku), ['MLBB_100', 'MLBB_500']);
    });

    test('a product with no supplier and no variants still parses', () {
      final product = adminCatalogueProductFromJson({
        'id': 1,
        'slug': 'steam-wallet',
        'name_en': 'Steam Wallet',
        'is_active': true,
        'kind': 'instant_stock',
        'supplier': null,
        'variants': null,
      });

      expect(product.supplierCode, isNull);
      expect(product.variants, isEmpty);
    });
  });

  group('AdminCatalogueVariant', () {
    test('margin is price minus cost', () {
      final variant = adminCatalogueVariantFromJson({
        'id': 1,
        'sku': 'X',
        'label_en': 'X',
        'price_usd': 7.5,
        'cost_usd': 7.0,
        'is_active': true,
      });

      expect(variant.marginUsd, closeTo(0.5, 0.0001));
    });

    test('a sale below cost shows a negative margin', () {
      final variant = adminCatalogueVariantFromJson({
        'id': 1,
        'sku': 'X',
        'label_en': 'X',
        'price_usd': 6.0,
        'cost_usd': 7.0,
        'is_active': true,
      });

      expect(variant.marginUsd, lessThan(0));
    });

    test('margin is unknown, not zero, when cost is missing', () {
      final variant = adminCatalogueVariantFromJson({
        'id': 1,
        'sku': 'X',
        'label_en': 'X',
        'price_usd': 6.0,
        'cost_usd': null,
        'is_active': true,
      });

      expect(variant.marginUsd, isNull);
    });
  });

  group('SupplierQueueItem', () {
    test('manual_waiting needs a person; retrying does not', () {
      final manual = supplierQueueItemFromJson({
        'item_id': 9,
        'order_id': 'o-1',
        'order_no': 'CP-1',
        'product_name': 'MLBB',
        'variant_label': '500 Diamonds',
        'qty': 1,
        'state': 'manual_waiting',
        'supplier_code': 'bay2game',
        'supplier_attempts': 5,
        'supplier_last_error': 'supplier_error: Invalid API key',
        'created_at': '2026-10-15T03:00:00Z',
      });
      final retrying = supplierQueueItemFromJson({
        'item_id': 10,
        'order_id': 'o-2',
        'order_no': 'CP-2',
        'product_name': 'MLBB',
        'variant_label': '100 Diamonds',
        'qty': 2,
        'state': 'retrying',
        'supplier_attempts': 1,
        'created_at': '2026-10-15T03:05:00Z',
      });

      expect(manual.needsPerson, isTrue);
      expect(manual.lastError, 'supplier_error: Invalid API key');
      expect(retrying.needsPerson, isFalse);
      expect(retrying.qty, 2);
      expect(retrying.lastError, isNull);
    });
  });
}
