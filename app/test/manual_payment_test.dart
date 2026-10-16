import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/features/admin/data/admin_mappers.dart';
import 'package:ycp_store/src/features/orders/data/order_mappers.dart';
import 'package:ycp_store/src/features/profile/domain/profile.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/admin_transfers_page.dart';
import 'package:ycp_store/src/ui/widgets/manual_payment_panel.dart';

const _withAccount = PublicSettings(
  siteName: 'Chanpenh',
  usdToKhr: 4100,
  orderTtlMinutes: 15,
  khqrAccountId: '000123456789',
  khqrMerchantName: 'Chanpenh Store',
);

const _withoutAccount = PublicSettings(
  siteName: 'Chanpenh',
  usdToKhr: 4100,
  orderTtlMinutes: 15,
);

Order _order({DateTime? requestedAt}) => Order(
  id: '11111111-1111-1111-1111-111111111111',
  orderNo: 'YP260101ABCDEF',
  status: OrderStatus.pending,
  subtotalUsd: 1.89,
  discountUsd: 0,
  totalUsd: 1.89,
  expiresAt: DateTime.now().add(const Duration(hours: 24)),
  createdAt: DateTime.now(),
  items: const [],
  manualPaymentRequestedAt: requestedAt,
);

Widget _wrap(
  Widget child, {
  required List<Override> overrides,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: AppL10n.localizationsDelegates,
    // No scroll view here: the transfers page is a ListView and nesting it in one
    // gives the viewport an unbounded height.
    home: Scaffold(body: child),
  ),
);

Override _settings(PublicSettings value) =>
    settingsProvider.overrideWith((ref) => value);

void main() {
  group('settings decide whether the fallback can exist at all', () {
    test('both the account and a name are needed', () {
      expect(_withAccount.hasTransferAccount, isTrue);

      // A bare account number is not something a buyer can safely pay into:
      // they cannot check the name matches who they mean to pay.
      expect(
        const PublicSettings(
          siteName: 'Chanpenh',
          usdToKhr: 4100,
          orderTtlMinutes: 15,
          khqrAccountId: '000123456789',
        ).hasTransferAccount,
        isFalse,
      );
      expect(_withoutAccount.hasTransferAccount, isFalse);
      expect(
        const PublicSettings(
          siteName: 'Chanpenh',
          usdToKhr: 4100,
          orderTtlMinutes: 15,
          khqrAccountId: '   ',
          khqrMerchantName: 'Chanpenh Store',
        ).hasTransferAccount,
        isFalse,
      );
    });
  });

  group('order state', () {
    test('the request timestamp is read, and absent means never asked', () {
      final asked = orderFromJson({
        'id': 'x',
        'total_usd': 1.89,
        'manual_payment_requested_at': '2026-10-15T09:00:00Z',
      });
      expect(asked.manualPaymentRequestedAt, isNotNull);

      final notAsked = orderFromJson({'id': 'x', 'total_usd': 1.89});
      expect(notAsked.manualPaymentRequestedAt, isNull);
    });

    test('the staff row carries what is needed to fulfil it', () {
      final request = manualPaymentRequestFromJson({
        'order_id': 'x',
        'order_no': 'YP1',
        'status': 'pending',
        'total_usd': 1.89,
        'kind': 'auto_topup',
        'requested_at': '2026-10-15T09:00:00Z',
        'buyer_note': 'paid at 10:20',
        'expires_at': '2026-10-16T09:00:00Z',
        'customer_fields': {'userid': '262856740', 'serverid': '2001'},
        'contact_email': 'buyer@example.test',
      });

      expect(request.customerFields['userid'], '262856740');
      expect(request.requestedAt, isNotNull);
      expect(request.isExpired, isFalse);

      // A row whose window has closed is flagged rather than confirmed against.
      final closed = manualPaymentRequestFromJson({
        'order_id': 'x',
        'total_usd': 1.89,
        'kind': 'auto_topup',
        'expires_at': '2020-01-01T00:00:00Z',
      });
      expect(closed.isExpired, isTrue);
    });

    test('only staff roles open the staff screens', () {
      Profile withRole(String role) => Profile(
        id: 'x',
        walletBalance: 0,
        coins: 0,
        displayName: null,
        role: role,
      );

      expect(withRole('customer').isStaff, isFalse);
      expect(withRole('staff').isStaff, isTrue);
      expect(withRole('admin').isStaff, isTrue);
    });
  });

  group('ManualPaymentPanel', () {
    testWidgets('renders nothing when the store has no account to pay into', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ManualPaymentPanel(order: _order()),
          overrides: [_settings(_withoutAccount)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Transfer'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('shows the account, the amount and the order number', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ManualPaymentPanel(order: _order()),
          overrides: [_settings(_withAccount)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('000123456789'), findsOneWidget);
      expect(find.text('Chanpenh Store'), findsOneWidget);
      expect(find.text('YP260101ABCDEF'), findsOneWidget);
      expect(find.text('I have paid — check it'), findsOneWidget);
    });

    testWidgets('an order already asked about shows the wait, not the button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ManualPaymentPanel(order: _order(requestedAt: DateTime.now())),
          overrides: [_settings(_withAccount)],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Waiting for us to check your transfer'),
        findsOneWidget,
      );
      expect(find.text('I have paid — check it'), findsNothing);
    });
  });

  group('AdminTransfersPage', () {
    Override staff() => profileProvider.overrideWith(
      (ref) async => const Profile(
        id: 'x',
        walletBalance: 0,
        coins: 0,
        displayName: 'Admin',
        role: 'admin',
      ),
    );

    Override customer() => profileProvider.overrideWith(
      (ref) async => const Profile(
        id: 'x',
        walletBalance: 0,
        coins: 0,
        displayName: 'Buyer',
      ),
    );

    testWidgets('a customer sees the gate and no queue', (tester) async {
      await tester.pumpWidget(
        _wrap(const AdminTransfersPage(), overrides: [customer()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('This page is for staff accounts.'), findsOneWidget);
      expect(find.text('Transfers to check'), findsNothing);
    });

    testWidgets('an empty queue says so rather than looking broken', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminTransfersPage(),
          overrides: [
            staff(),
            manualPaymentRequestsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Nothing waiting. No buyer has asked to pay by transfer.'),
        findsOneWidget,
      );
    });

    testWidgets('a request shows the game id, the amount and both actions', (
      tester,
    ) async {
      final request = ManualPaymentRequest(
        orderId: 'x',
        orderNo: 'YP260101ABCDEF',
        status: OrderStatus.pending,
        totalUsd: 1.89,
        kind: 'auto_topup',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        requestedAt: DateTime.now(),
        buyerNote: 'paid at 10:20',
        customerFields: const {'userid': '262856740'},
      );

      await tester.pumpWidget(
        _wrap(
          const AdminTransfersPage(),
          overrides: [
            staff(),
            manualPaymentRequestsProvider.overrideWith(
              (ref) async => [request],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YP260101ABCDEF'), findsOneWidget);
      expect(find.text('userid: 262856740'), findsOneWidget);
      expect(find.text('paid at 10:20'), findsOneWidget);
      // Prefilled with the total, so the common case is one tap.
      expect(find.text('1.89'), findsWidgets);
      expect(find.text('Confirm payment'), findsOneWidget);
      expect(find.text('Dismiss request'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
