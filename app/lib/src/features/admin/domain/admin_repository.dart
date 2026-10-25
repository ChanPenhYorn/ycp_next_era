import 'admin_entities.dart';

/// Staff-side reads and actions.
///
/// Every write goes to an RPC that re-checks `is_staff()` in the database. The
/// app deciding to draw the screen is a convenience, not the control. Business
/// failures are thrown as `OrderException`.
abstract class AdminRepository {
  /// Orders where the buyer has asked to pay by transfer.
  Future<List<ManualPaymentRequest>> manualPaymentRequests();

  /// Confirms a transfer that was checked against the bank app. Returns the
  /// RPC's own answer: `ok: false` means the order was already settled.
  Future<Map<String, dynamic>> confirmManualPayment({
    required String orderId,
    required double amountUsd,
    required String abaRef,
    String? note,
  });

  /// Drops a request that will not be paid, so the queue does not only grow.
  Future<void> clearManualPaymentRequest({
    required String orderId,
    required String reason,
  });

  Future<AdminOverview> overview();

  Future<List<AdminOrderSummary>> orders({
    String? status,
    String? search,
    int limit,
  });

  /// One order with the lines, the payments and the append-only history.
  Future<AdminOrderDetail?> orderDetail(String orderId);

  /// Agrees a refund. Moves no money: the reversal happens in the bank.
  Future<Map<String, dynamic>> setRefundPending({
    required String orderId,
    String? reason,
  });

  /// Records a reversal that already happened outside the app.
  Future<Map<String, dynamic>> markRefunded({
    required String orderId,
    String? reference,
  });

  /// Closes one line by hand — what a `manual_waiting` row is waiting for.
  Future<void> resolveItem({required int itemId, String delivery});

  Future<List<AdminCatalogueProduct>> catalogue();

  Future<void> setProductActive({required int productId, required bool active});

  /// Resolves wide banner art through the `game-banner` function and returns
  /// the mirrored URL, or null when the banner was cleared. Pass [url] to use a
  /// specific image instead of asking IGDB.
  Future<String?> resolveBanner({
    required int productId,
    String? url,
    bool force,
  });

  /// Refused in the database when the price is below the supplier cost.
  Future<void> setVariantPrice({
    required int variantId,
    required double priceUsd,
  });

  Future<List<SupplierQueueItem>> supplierQueue({int limit});

  Future<List<StaffMember>> staffMembers();

  /// Finds a sign-up by email. Throws `user_not_found` when there is none.
  Future<StaffMember> findUserByEmail(String email);

  /// The database refuses a self-change and removing the last admin.
  Future<void> setRole({required String userId, required String role});

  Future<List<SupportTicket>> supportTickets({String? status});

  Future<void> setSupportStatus({
    required int ticketId,
    String? status,
    String? note,
    String? priority,
  });
}
