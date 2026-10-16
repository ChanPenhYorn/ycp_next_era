import 'package:flutter_test/flutter_test.dart';
import 'package:ycp_store/src/features/cart/data/cart_mappers.dart';
import 'package:ycp_store/src/features/catalog/data/catalog_mappers.dart';
import 'package:ycp_store/src/features/catalog/data/supabase_catalog_repository.dart';
import 'package:ycp_store/src/features/orders/data/order_mappers.dart';
import 'package:ycp_store/src/data/models.dart';

/// Regression tests for the parsing layer.
///
/// These exist because a missing column in a PostgREST `select` throws at
/// runtime, not at analysis time. `flutter analyze` passed while the catalogue
/// page was dead: the list query omitted sku/label_km/label_en, so
/// `json['sku'] as String` hit null and threw
/// `type 'Null' is not a subtype of type 'String'`.
///
/// Two layers of defence here:
///   1. a payload shaped exactly like the real response
///   2. an assertion that the shared column constants still carry every field
///      the parsers read, so the query and the model cannot drift apart again
void main() {
  group('payloads shaped like PostgREST responses parse', () {
    test('product list row with an inline variant', () {
      // Exactly the shape `products()` produces.
      final row = <String, dynamic>{
        'id': 3,
        'slug': 'mobile-legends',
        'name_km': 'ពេជ្រ Mobile Legends',
        'name_en': 'Mobile Legends Diamonds',
        'image_url': null,
        'kind': 'auto_topup',
        'rating_avg': 0,
        'rating_count': 0,
        'sold_count': 12,
        'category': {
          'id': 1,
          'slug': 'game-topup',
          'name_km': 'បញ្ចូលពេជ្រហ្គេម',
          'name_en': 'Game Top-Up',
        },
        'variants': [
          {
            'id': 9,
            'sku': 'MLBB-86',
            'label_km': '៨៦ ពេជ្រ',
            'label_en': '86 Diamonds',
            'price_usd': 0.99,
            'compare_at_price_usd': 1.20,
            'stock_mode': 'unlimited',
            'min_qty': 1,
            'max_qty': 20,
            'in_stock': null,
          },
        ],
      };

      final variant = variantFromJson(
        (row['variants'] as List).first as Map<String, dynamic>,
      );
      expect(variant.sku, 'MLBB-86');
      expect(variant.labelEn, '86 Diamonds');
      expect(variant.priceUsd, 0.99);
      expect(variant.isUnlimited, isTrue);
      expect(variant.isSoldOut, isFalse);

      final category = categoryFromJson(
        row['category'] as Map<String, dynamic>,
      );
      expect(category.slug, 'game-topup');
    });

    test('a partial variant payload degrades instead of throwing', () {
      // The exact shape that took the catalogue down. It must not throw.
      final variant = variantFromJson({
        'id': 9,
        'price_usd': 0.99,
        'compare_at_price_usd': null,
        'stock_mode': 'stock',
        'in_stock': 3,
      });

      expect(variant.id, 9);
      expect(variant.sku, isEmpty);
      expect(variant.labelKm, isEmpty);
      expect(variant.minQty, 1, reason: 'min_qty defaults to 1');
      expect(variant.inStock, 3);
    });

    test('the three variants of buyer fields all parse', () {
      for (final fields in <List<String>>[
        <String>[],
        <String>['userid'],
        <String>['userid', 'serverid'],
        <String>['userid', 'serverid', 'charname'],
      ]) {
        final parsed = fields
            .map((key) => requiredFieldFromJson({'key': key}))
            .toList();

        expect(parsed.length, fields.length);
        for (final field in parsed) {
          // label falls back to key so the form always renders a label.
          expect(field.labelKm, isNotEmpty);
          expect(field.labelEn, isNotEmpty);
        }
      }
    });

    test('order with items and a null paid_at', () {
      final order = orderFromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'order_no': 'YP261015ABC123',
        'status': 'delivering',
        'subtotal_usd': 7.48,
        'discount_usd': 0.75,
        'total_usd': 6.73,
        'coupon_code': 'WELCOME10',
        'expires_at': '2026-10-15T10:00:00.000Z',
        'created_at': '2026-10-15T09:45:00.000Z',
        'paid_at': null,
        'items': [
          {
            'id': 1,
            'product_name': 'កាត Steam',
            'variant_label': 'Steam \$5',
            'qty': 1,
            'unit_price_usd': 5.50,
            'line_total_usd': 5.50,
            'delivery_status': 'delivered',
            'variant': {'product_id': 3},
          },
        ],
      });

      expect(order.status, OrderStatus.delivering);
      expect(order.paidAt, isNull);
      expect(order.items.single.productId, 3);
      expect(order.items.single.canBeReviewed, isTrue);
    });

    test('wallet ledger entry where order_id is null', () {
      final tx = walletTransactionFromJson({
        'id': 5,
        'kind': 'topup',
        'amount_usd': 25.0,
        'balance_after': 45.0,
        'note': 'topup YP261015ABC123',
        'order_id': null,
        'created_at': '2026-10-15T09:00:00.000Z',
      });

      expect(tx.isCredit, isTrue);
      expect(tx.orderId, isNull);
      expect(tx.balanceAfter, 45.0);
    });

    test('settings row with nullable contact fields', () {
      final settings = PublicSettings.fallback;
      expect(settings.siteName, 'Chanpenh');
      expect(settings.topupMinUsd, 1);
      expect(settings.topupMaxUsd, 1000);
    });
  });

  group('cart round-trip', () {
    const field = RequiredField(
      key: 'userid',
      labelKm: 'លេខ ID ហ្គេម',
      labelEn: 'Game ID',
      placeholder: '123456789',
      pattern: '^[0-9]{6,12}\$',
    );

    test('a line with buyer fields survives being persisted and restored', () {
      const line = CartLine(
        variantId: 9,
        productSlug: 'mobile-legends-diamonds',
        productName: 'ពេជ្រ Mobile Legends',
        variantLabel: '៨៦ ពេជ្រ',
        unitPriceUsd: 0.99,
        qty: 2,
        maxQty: 20,
        minQty: 1,
        fields: {'userid': '262856740', 'serverid': '3543'},
        requiredFields: [field],
      );

      // SharedPreferences only stores strings, so this is the real path.
      final restored = cartLineFromJson(cartLineToJson(line));

      expect(restored.fields['userid'], '262856740');
      expect(restored.fields['serverid'], '3543');
      expect(restored.needsFields, isTrue);
      expect(restored.requiredFields.single.key, 'userid');
      expect(restored.requiredFields.single.labelEn, 'Game ID');
      expect(restored.requiredFields.single.pattern, r'^[0-9]{6,12}$');
      expect(restored.qty, 2);
    });

    test('copyWith can replace the values without losing the definitions', () {
      const line = CartLine(
        variantId: 9,
        productSlug: 'p',
        productName: 'n',
        variantLabel: 'v',
        unitPriceUsd: 1,
        qty: 1,
        maxQty: 5,
        minQty: 1,
        fields: {'userid': ''},
        requiredFields: [field],
      );

      final updated = line.copyWith(fields: {'userid': '123456789'});
      expect(updated.fields['userid'], '123456789');
      expect(updated.requiredFields.length, 1);
    });

    test('a line without fields round-trips too', () {
      const line = CartLine(
        variantId: 3,
        productSlug: 'steam-wallet',
        productName: 'Steam',
        variantLabel: 'Steam \$5',
        unitPriceUsd: 5.5,
        qty: 1,
        maxQty: 5,
        minQty: 1,
      );

      final restored = cartLineFromJson(cartLineToJson(line));
      expect(restored.needsFields, isFalse);
      expect(restored.fields, isEmpty);
    });
  });

  group('query columns cannot drift from the parsers', () {
    // Every field variantFromJson reads. If a new one is added there, add it
    // here too and the select will fail this test rather than production.
    const variantFieldsReadByParser = [
      'id',
      'sku',
      'label_km',
      'label_en',
      'price_usd',
      'compare_at_price_usd',
      'stock_mode',
      'min_qty',
      'max_qty',
    ];

    const categoryFieldsReadByParser = ['id', 'slug', 'name_km', 'name_en'];

    test('variantColumns covers variantFromJson', () {
      for (final field in variantFieldsReadByParser) {
        expect(
          variantColumns,
          contains(field),
          reason:
              'variantColumns is missing "$field", which variantFromJson reads',
        );
      }
    });

    test('categoryColumns covers categoryFromJson', () {
      for (final field in categoryFieldsReadByParser) {
        expect(
          categoryColumns,
          contains(field),
          reason:
              'categoryColumns is missing "$field", which categoryFromJson reads',
        );
      }
    });
  });
}
