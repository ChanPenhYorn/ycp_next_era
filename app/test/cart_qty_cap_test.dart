import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/features/catalog/domain/catalog_entities.dart';
import 'package:ycp_store/src/features/catalog/domain/catalog_repository.dart';
import 'package:ycp_store/src/state/providers.dart';

/// A cart saved before the catalogue knew a supplier delivers one unit per
/// line would hold two. `create_order` refuses it - the database is right and
/// the stale cart is wrong - so the client has to correct the line rather than
/// hand the buyer an error that repeats on every retry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container({CatalogRepository? catalogue}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (catalogue != null)
          catalogRepositoryProvider.overrideWithValue(catalogue),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> addLine(
    ProviderContainer scoped, {
    required int variantId,
    required int qty,
    required int maxQty,
    String sku = '',
  }) => scoped
      .read(cartControllerProvider.notifier)
      .add(
        variantId: variantId,
        productSlug: 'bay2game-mlbb',
        productName: 'MLBB',
        variantLabel: '100 Diamonds',
        unitPriceUsd: 1.5,
        minQty: 1,
        maxQty: maxQty,
        sku: sku,
        qty: qty,
      );

  group('capToOne', () {
    test('corrects the line and its bounds', () async {
      final scoped = await container();
      await addLine(scoped, variantId: 7, qty: 2, maxQty: 50, sku: 'MLBB_100');

      expect(scoped.read(cartControllerProvider).single.qty, 2);

      await scoped.read(cartControllerProvider.notifier).capToOne(7);

      final line = scoped.read(cartControllerProvider).single;
      expect(line.qty, 1);
      // The bounds move with the quantity, so the stepper is not drawn as a
      // control that can only stay at 1.
      expect(line.maxQty, 1);
      expect(line.sku, 'MLBB_100');
    });

    test('leaves other lines alone', () async {
      final scoped = await container();
      await addLine(scoped, variantId: 7, qty: 2, maxQty: 50, sku: 'MLBB_100');
      await addLine(scoped, variantId: 8, qty: 3, maxQty: 5, sku: 'STEAM_5');

      await scoped.read(cartControllerProvider.notifier).capToOne(7);

      final lines = scoped.read(cartControllerProvider);
      expect(lines.firstWhere((line) => line.variantId == 7).qty, 1);
      expect(lines.firstWhere((line) => line.variantId == 8).qty, 3);
    });
  });

  group('reconcileWithCatalogue', () {
    test('lowers a stale quantity and fills in the SKU it lacked', () async {
      // The upgrade path that matters: the line was saved by a build before
      // SKUs were carried, so it has neither a SKU to match an error against
      // nor the cap the supplier now applies.
      final scoped = await container(
        catalogue: _FakeCatalogue({
          7: const LiveVariant(id: 7, sku: 'FIT_100', minQty: 1, maxQty: 1),
        }),
      );
      await addLine(scoped, variantId: 7, qty: 2, maxQty: 50);

      final result = await scoped
          .read(cartControllerProvider.notifier)
          .reconcileWithCatalogue();

      final line = scoped.read(cartControllerProvider).single;
      expect(result.capped.single.variantId, 7);
      expect(result.removed, isEmpty);
      expect(line.qty, 1);
      expect(line.maxQty, 1);
      expect(line.sku, 'FIT_100');
    });

    test('drops a line the catalogue no longer answers for', () async {
      final scoped = await container(catalogue: _FakeCatalogue(const {}));
      await addLine(scoped, variantId: 7, qty: 1, maxQty: 1, sku: 'GONE');

      final result = await scoped
          .read(cartControllerProvider.notifier)
          .reconcileWithCatalogue();

      expect(result.removed.single.variantId, 7);
      expect(scoped.read(cartControllerProvider), isEmpty);
    });

    test(
      'a cap that arrived as zero removes the line, it does not clamp',
      () async {
        // Clamping into an impossible range would throw; a range the buyer cannot
        // satisfy means the SKU is not sellable, which is what a removal says.
        final scoped = await container(
          catalogue: _FakeCatalogue({
            7: const LiveVariant(id: 7, sku: 'DEAD', minQty: 1, maxQty: 0),
          }),
        );
        await addLine(scoped, variantId: 7, qty: 1, maxQty: 50, sku: 'DEAD');

        final result = await scoped
            .read(cartControllerProvider.notifier)
            .reconcileWithCatalogue();

        expect(result.removed.single.variantId, 7);
        expect(scoped.read(cartControllerProvider), isEmpty);
      },
    );

    test('a failed read leaves the cart untouched', () async {
      // Offline is not evidence that anything is wrong. Emptying the cart here
      // would cost the buyer their basket for a dropped connection.
      final scoped = await container(
        catalogue: _FakeCatalogue(const {}, fails: true),
      );
      await addLine(scoped, variantId: 7, qty: 2, maxQty: 50, sku: 'MLBB_100');

      final result = await scoped
          .read(cartControllerProvider.notifier)
          .reconcileWithCatalogue();

      expect(result.isEmpty, isTrue);
      final line = scoped.read(cartControllerProvider).single;
      expect(line.qty, 2);
    });

    test('nothing to report when the line already matches', () async {
      final scoped = await container(
        catalogue: _FakeCatalogue({
          7: const LiveVariant(id: 7, sku: 'MLBB_100', minQty: 1, maxQty: 5),
        }),
      );
      await addLine(scoped, variantId: 7, qty: 2, maxQty: 5, sku: 'MLBB_100');

      final result = await scoped
          .read(cartControllerProvider.notifier)
          .reconcileWithCatalogue();

      expect(result.isEmpty, isTrue);
      expect(scoped.read(cartControllerProvider).single.qty, 2);
    });
  });
}

class _FakeCatalogue implements CatalogRepository {
  _FakeCatalogue(this.live, {this.fails = false});

  final Map<int, LiveVariant> live;
  final bool fails;

  @override
  Future<Map<int, LiveVariant>> liveVariants(List<int> variantIds) async {
    if (fails) throw StateError('offline');
    return {
      for (final entry in live.entries)
        if (variantIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
