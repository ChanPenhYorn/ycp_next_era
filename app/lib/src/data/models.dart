/// Compatibility barrel. The entities now live beside the feature that owns
/// them; this file only re-exports them so existing imports keep working.
///
/// Prefer importing the feature path directly, e.g.
/// `package:ycp_store/src/features/orders/domain/order_entities.dart`.
library;

export '../features/admin/domain/admin_entities.dart';
export '../features/cart/domain/cart_line.dart';
export '../features/catalog/domain/catalog_entities.dart';
export '../features/orders/domain/order_entities.dart';
export '../features/payments/domain/payment_entities.dart';
