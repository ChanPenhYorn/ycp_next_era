import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/data/models.dart';
import 'package:ycp_store/src/data/order_repository.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/admin_order_detail_page.dart';
import 'package:ycp_store/src/ui/admin_orders_page.dart';
import 'package:ycp_store/src/ui/admin_page.dart';
import 'package:ycp_store/src/ui/admin_refunds_page.dart';
import 'package:ycp_store/src/ui/admin_support_page.dart';

Widget _wrap(Widget child, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: AppL10n.localizationsDelegates,
    // No scroll view: the admin screens are ListViews, and nesting one in a
    // scroll view gives its viewport an unbounded height.
    home: Scaffold(body: child),
  ),
);

Override _staff() => profileProvider.overrideWith(
  (ref) async => const Profile(
    id: 'staff',
    walletBalance: 0,
    coins: 0,
    displayName: 'Staff',
    role: 'staff',
  ),
);

Override _customer() => profileProvider.overrideWith(
  (ref) async => const Profile(
    id: 'buyer',
    walletBalance: 0,
    coins: 0,
    displayName: 'Buyer',
  ),
);

final _overview = {
  'timezone': 'Asia/Phnom_Penh',
  'generated_at': '2026-10-15T09:00:00Z',
  'orders_pending': 3,
  'orders_refund_pending': 1,
  'transfers_waiting': 2,
  'support_open': 4,
  'items_manual_waiting': 5,
  'received_today': 2,
  'received_today_usd': 11.34,
  'received_7d_usd': 100.5,
  'received_30d_usd': 250.75,
  'wallet_spent_30d_usd': 20.0,
  'refunds_30d': 1,
  'refunded_30d_usd': 1.89,
};

Map<String, dynamic> _orderJson({
  String status = 'paid',
  String? refundReason,
}) => {
  'id': '11111111-1111-1111-1111-111111111111',
  'order_no': 'YP260101ABCDEF',
  'status': status,
  'kind': 'purchase',
  'total_usd': 1.89,
  'created_at': '2026-10-14T09:00:00Z',
  'paid_at': '2026-10-14T09:05:00Z',
  'refund_reason': refundReason,
  'contact_email': 'buyer@example.com',
  'manual_payment_requested_at': null,
  'items': [
    {'id': 7},
  ],
};

void main() {
  // --------------------------------------------------------------------------
  // Parsing
  // --------------------------------------------------------------------------

  group('the overview JSON is read as the worker wrote it', () {
    test('every figure maps, and nothing is invented', () {
      final overview = AdminOverview.fromJson(_overview);

      expect(overview.timezone, 'Asia/Phnom_Penh');
      expect(overview.ordersPending, 3);
      expect(overview.ordersRefundPending, 1);
      expect(overview.transfersWaiting, 2);
      expect(overview.supportOpen, 4);
      expect(overview.itemsManualWaiting, 5);
      expect(overview.receivedToday, 2);
      expect(overview.receivedTodayUsd, 11.34);
      expect(overview.received30dUsd, 250.75);
      expect(overview.walletSpent30dUsd, 20.0);
      expect(overview.refunds30d, 1);
      expect(overview.refunded30dUsd, 1.89);
    });

    test('a missing field is zero, not a crash and not a guess', () {
      final overview = AdminOverview.fromJson(const {});

      expect(overview.ordersPending, 0);
      expect(overview.receivedTodayUsd, 0);
      // An absent timezone is UTC, which is what the JSON claims by omission.
      expect(overview.timezone, 'UTC');
    });
  });

  group('an order row carries what the list needs and no more', () {
    test('status, kind, line count and the transfer flag', () {
      final row = AdminOrderSummary.fromJson({
        ..._orderJson(),
        'manual_payment_requested_at': '2026-10-14T09:10:00Z',
      });

      expect(row.orderNo, 'YP260101ABCDEF');
      expect(row.status, OrderStatus.paid);
      expect(row.kind, 'purchase');
      expect(row.totalUsd, 1.89);
      expect(row.itemCount, 1);
      expect(row.contactEmail, 'buyer@example.com');
      expect(row.manualPaymentRequestedAt, isNotNull);
    });

    test('a refund pending row keeps the reason staff wrote', () {
      final row = AdminOrderSummary.fromJson(
        _orderJson(status: 'refund_pending', refundReason: 'supplier failed'),
      );

      expect(row.status, OrderStatus.refundPending);
      expect(row.refundReason, 'supplier failed');
    });
  });

  group('the detail view joins three tables', () {
    test('items, payments and history arrive separately', () {
      final detail = AdminOrderDetail.fromJson(
        {
          ..._orderJson(),
          'customer_note': 'please hurry',
          'customer_fields': {'userid': '262856740'},
          'items': [
            {
              'id': 7,
              'product_name': 'Mobile Legends',
              'variant_label': '172 diamonds',
              'qty': 1,
              'unit_price_usd': 1.89,
              'line_total_usd': 1.89,
              'delivery_status': 'manual_waiting',
              'supplier_attempts': 3,
              'supplier_last_error': 'supplier_timeout',
              'supplier_ref': null,
              'supplier_next_attempt_at': null,
            },
          ],
        },
        [
          {
            'provider': 'manual',
            'status': 'succeeded',
            'amount_usd': 1.89,
            'provider_ref': 'ABA-REF-1',
            'verified_at': '2026-10-14T09:05:00Z',
          },
        ],
        [
          {
            'event': 'paid',
            'actor': 'staff',
            'from_status': 'pending',
            'to_status': 'paid',
            'created_at': '2026-10-14T09:05:00Z',
          },
        ],
      );

      expect(detail.summary.orderNo, 'YP260101ABCDEF');
      expect(detail.customerNote, 'please hurry');
      expect(detail.customerFields['userid'], '262856740');
      expect(detail.items.single.deliveryStatus, DeliveryStatus.manualWaiting);
      // The supplier's own words are kept: they are what tells staff whether to
      // retry or to deliver by hand.
      expect(detail.items.single.supplierAttempts, 3);
      expect(detail.items.single.supplierLastError, 'supplier_timeout');
      expect(detail.payments.single.provider, 'manual');
      expect(detail.payments.single.providerRef, 'ABA-REF-1');
      expect(detail.events.single.event, 'paid');
      expect(detail.events.single.actor, 'staff');
      expect(detail.events.single.fromStatus, OrderStatus.pending);
      expect(detail.events.single.toStatus, OrderStatus.paid);
    });
  });

  group('a ticket', () {
    test('is open while it is open or in progress', () {
      SupportTicket read(String status) => SupportTicket.fromJson({
        'id': 1,
        'subject': 'Wrong id',
        'status': status,
        'priority': 'high',
        'created_at': '2026-10-14T09:00:00Z',
        'updated_at': '2026-10-14T09:00:00Z',
        'orders': {'order_no': 'YP260101ABCDEF'},
      });

      expect(read('open').isOpen, isTrue);
      expect(read('in_progress').isOpen, isTrue);
      expect(read('resolved').isOpen, isFalse);
      expect(read('closed').isOpen, isFalse);
      // The order the ticket points at, read through the FK rather than a
      // second query.
      expect(read('open').orderNo, 'YP260101ABCDEF');
      expect(read('open').priority, 'high');
    });
  });

  group('the order filter is compared by value', () {
    test('equal filters are one cache entry, different ones are not', () {
      expect(
        const AdminOrderQuery(status: 'paid'),
        const AdminOrderQuery(status: 'paid'),
      );
      expect(
        const AdminOrderQuery(status: 'paid'),
        isNot(const AdminOrderQuery(status: 'pending')),
      );
      expect(
        const AdminOrderQuery(status: 'paid', search: 'YP'),
        isNot(const AdminOrderQuery(status: 'paid')),
      );
    });
  });

  // --------------------------------------------------------------------------
  // Screens
  // --------------------------------------------------------------------------

  group('the hub', () {
    testWidgets('a customer gets the gate and no figures', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminPage(),
          overrides: [
            _customer(),
            adminOverviewProvider.overrideWith(
              (ref) async => AdminOverview.fromJson(_overview),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This page is for staff accounts.'), findsOneWidget);
      expect(find.text('Received today'), findsNothing);
    });

    testWidgets('staff see the queues and the money', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminPage(),
          overrides: [
            _staff(),
            adminOverviewProvider.overrideWith(
              (ref) async => AdminOverview.fromJson(_overview),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What needs doing'), findsOneWidget);
      expect(find.text('Received today'), findsOneWidget);
      // Money, formatted, from payments — not from orders.
      expect(find.text(r'$11.34'), findsOneWidget);
      expect(find.text(r'$250.75'), findsOneWidget);
      // The day boundary is stated rather than assumed.
      expect(find.textContaining('Asia/Phnom_Penh'), findsOneWidget);
      // Queue counts, and the hub entry points.
      expect(find.text('Pending orders'), findsOneWidget);
      expect(find.text('Refund pending'), findsWidgets);
      expect(find.text('Support'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('the order list', () {
    testWidgets('a customer sees the gate, not rows', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminOrdersPage(),
          overrides: [
            _customer(),
            adminOrdersProvider.overrideWith(
              (ref, query) async => [
                AdminOrderSummary.fromJson(_orderJson()),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This page is for staff accounts.'), findsOneWidget);
      expect(find.text('YP260101ABCDEF'), findsNothing);
    });

    testWidgets('staff see the row, its status and the filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminOrdersPage(),
          overrides: [
            _staff(),
            adminOrdersProvider.overrideWith(
              (ref, query) async => [
                AdminOrderSummary.fromJson(_orderJson()),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YP260101ABCDEF'), findsOneWidget);
      // Once in the row's status chip, once in the filter row.
      expect(find.text('Paid'), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Refund pending'), findsWidgets);
      expect(find.text(r'$1.89'), findsOneWidget);
    });

    testWidgets('an empty result says so rather than showing nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminOrdersPage(),
          overrides: [
            _staff(),
            adminOrdersProvider.overrideWith((ref, query) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No orders match.'), findsOneWidget);
    });
  });

  group('the refund queue', () {
    testWidgets('a pending refund shows the reason and the record action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminRefundsPage(),
          overrides: [
            _staff(),
            adminRefundQueueProvider.overrideWith(
              (ref) async => [
                AdminOrderSummary.fromJson(
                  _orderJson(
                    status: 'refund_pending',
                    refundReason: 'supplier could not deliver',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YP260101ABCDEF'), findsOneWidget);
      expect(find.text('supplier could not deliver'), findsOneWidget);
      expect(find.text('Record the refund'), findsOneWidget);
      // The screen says out loud that it does not move money.
      expect(
        find.textContaining('does not move money'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty queue says so', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminRefundsPage(),
          overrides: [
            _staff(),
            adminRefundQueueProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No refunds are waiting.'), findsOneWidget);
    });
  });

  group('the support queue', () {
    testWidgets('a ticket shows its state, its body and the actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminSupportPage(),
          overrides: [
            _staff(),
            adminTicketsProvider.overrideWith(
              (ref, status) async => [
                SupportTicket.fromJson({
                  'id': 4,
                  'subject': 'Wrong game id',
                  'body': 'I typed the wrong id.',
                  'status': 'open',
                  'priority': 'high',
                  'contact': 'buyer@example.com',
                  'created_at': '2026-10-14T09:00:00Z',
                  'updated_at': '2026-10-14T09:00:00Z',
                }),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wrong game id'), findsOneWidget);
      expect(find.text('I typed the wrong id.'), findsOneWidget);
      expect(find.text('buyer@example.com'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      // Priority is a staff decision, so it is offered here.
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty queue says so', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminSupportPage(),
          overrides: [
            _staff(),
            adminTicketsProvider.overrideWith((ref, status) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tickets.'), findsOneWidget);
    });
  });

  group('the order detail', () {
    testWidgets('shows the line, the payment and the history', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminOrderDetailPage(orderId: 'x'),
          overrides: [
            _staff(),
            adminOrderDetailProvider.overrideWith(
              (ref, orderId) async => AdminOrderDetail.fromJson(
                {
                  ..._orderJson(),
                  'items': [
                    {
                      'id': 7,
                      'product_name': 'Mobile Legends',
                      'variant_label': '172 diamonds',
                      'qty': 1,
                      'unit_price_usd': 1.89,
                      'line_total_usd': 1.89,
                      'delivery_status': 'manual_waiting',
                      'supplier_attempts': 3,
                      'supplier_last_error': 'supplier_timeout',
                    },
                  ],
                },
                [
                  {
                    'provider': 'manual',
                    'status': 'succeeded',
                    'amount_usd': 1.89,
                    'provider_ref': 'ABA-REF-1',
                  },
                ],
                [
                  {
                    'event': 'paid',
                    'actor': 'staff',
                    'from_status': 'pending',
                    'to_status': 'paid',
                    'created_at': '2026-10-14T09:05:00Z',
                  },
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YP260101ABCDEF'), findsOneWidget);
      expect(find.text('Mobile Legends · 172 diamonds'), findsOneWidget);
      // A line that has not been delivered can be closed by hand.
      expect(find.text('Mark delivered'), findsOneWidget);
      expect(find.text('manual_waiting'), findsOneWidget);
      // The supplier's own words, unedited.
      expect(find.text('supplier_timeout'), findsOneWidget);
      // Payment rows keep the database's words.
      expect(find.text('manual · succeeded'), findsOneWidget);
      expect(find.text('ABA-REF-1'), findsOneWidget);
      // History, with who did it.
      expect(find.text('paid · staff'), findsOneWidget);
      // A paid order can be marked for refund.
      expect(find.text('Agree a refund'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refund pending order offers the record action, not agree', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminOrderDetailPage(orderId: 'x'),
          overrides: [
            _staff(),
            adminOrderDetailProvider.overrideWith(
              (ref, orderId) async => AdminOrderDetail.fromJson(
                _orderJson(
                  status: 'refund_pending',
                  refundReason: 'supplier failed',
                ),
                const [],
                const [],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refund pending'), findsOneWidget);
      expect(find.text('Record the refund'), findsOneWidget);
      expect(find.text('Agree a refund'), findsNothing);
    });

    testWidgets('an expired order offers neither refund action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AdminOrderDetailPage(orderId: 'x'),
          overrides: [
            _staff(),
            adminOrderDetailProvider.overrideWith(
              (ref, orderId) async => AdminOrderDetail.fromJson(
                _orderJson(status: 'expired'),
                const [],
                const [],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agree a refund'), findsNothing);
      expect(find.text('Record the refund'), findsNothing);
    });
  });
}
