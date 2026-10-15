// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sela';

  @override
  String get searchHint => 'Search products';

  @override
  String get all => 'All';

  @override
  String get inStock => 'In stock';

  @override
  String get outOfStock => 'Sold out';

  @override
  String get buyNow => 'Buy now';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signUp => 'Create account';

  @override
  String get account => 'Account';

  @override
  String get orders => 'Orders';

  @override
  String get wallet => 'Wallet';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get instant => 'Instant';

  @override
  String soldCount(int count) {
    return '$count sold';
  }

  @override
  String get from => 'From';

  @override
  String get heroTitle => 'Game top-ups and digital cards, instantly';

  @override
  String get heroSubtitle => 'Pay with ABA KHQR, receive your code in seconds';

  @override
  String get featured => 'Popular';

  @override
  String get categories => 'Categories';

  @override
  String get allProducts => 'All products';

  @override
  String get noProducts => 'Nothing here yet';

  @override
  String get trustInstant => 'Automatic 24/7 delivery';

  @override
  String get trustPayment => 'Pay with ABA KHQR';

  @override
  String get trustSupport => '24/7 support on Telegram';

  @override
  String get description => 'Description';

  @override
  String get deliveryTime => 'Delivery';

  @override
  String get deliveryInstant => 'Instant';

  @override
  String get deliveryManual => 'Manual, within 15 minutes';

  @override
  String get quantity => 'Quantity';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get requiredInfo => 'Required information';

  @override
  String get reviews => 'Reviews';

  @override
  String get noReviews => 'No reviews yet';

  @override
  String get checkout => 'Checkout';

  @override
  String get cart => 'Cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get contactEmail => 'Email';

  @override
  String get contactTelegram => 'Telegram';

  @override
  String get note => 'Note';

  @override
  String get orderSummary => 'Order summary';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get total => 'Total';

  @override
  String get coupon => 'Coupon code';

  @override
  String get apply => 'Apply';

  @override
  String get couponInvalid => 'That coupon code is not valid';

  @override
  String get payWithKhqr => 'Pay with ABA KHQR';

  @override
  String get payWithWallet => 'Pay from wallet';

  @override
  String get scanQr => 'Scan with any banking app';

  @override
  String get openAbaMobile => 'Open ABA Mobile';

  @override
  String get waitingPayment => 'Waiting for payment...';

  @override
  String get khqrExpired => 'This QR has expired';

  @override
  String get newQr => 'Generate a new QR';

  @override
  String get insufficientBalance => 'Not enough wallet balance';

  @override
  String get orderNo => 'Order number';

  @override
  String get status => 'Status';

  @override
  String get statusPending => 'Awaiting payment';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusDelivering => 'Delivering';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get statusExpired => 'Expired';

  @override
  String get yourCodes => 'Your codes';

  @override
  String get manualWaiting => 'Waiting for staff setup';

  @override
  String get orderEmpty => 'No orders yet';

  @override
  String get orderPaidSuccess => 'Payment received';

  @override
  String get about => 'About us';

  @override
  String get aboutText =>
      'Digital goods and game cards at fair prices with instant delivery.';

  @override
  String get quickLinks => 'Quick links';

  @override
  String get help => 'Help';

  @override
  String get contact => 'Contact';

  @override
  String get weAccept => 'We accept';

  @override
  String get rights => 'All rights reserved';

  @override
  String get loginTitle => 'Sign in to your account';

  @override
  String get loginSubtitle =>
      'We email you a one-time code. No password to remember.';

  @override
  String get emailLabel => 'Email address';

  @override
  String get sendCode => 'Send code';

  @override
  String get otpLabel => '6-digit code';

  @override
  String get verify => 'Verify and continue';

  @override
  String codeSent(String email) {
    return 'Code sent to $email';
  }

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get guestMustSignIn => 'Please sign in to continue';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletBalance => 'Balance';

  @override
  String get walletTopup => 'Top up';

  @override
  String get walletAmount => 'Amount';

  @override
  String get walletHistory => 'Activity';

  @override
  String get walletEmpty => 'No wallet activity yet';

  @override
  String get walletTopupNote =>
      'Top-ups are credited the moment the KHQR is paid.';

  @override
  String get walletCredited => 'Top-up complete';

  @override
  String get walletTopupFailed => 'Top-up was not completed';

  @override
  String walletLimits(String min, String max) {
    return 'Between $min and $max';
  }

  @override
  String walletSpent(Object orderNo) {
    return 'Order $orderNo';
  }

  @override
  String get writeReview => 'Write a review';

  @override
  String get reviewRating => 'Your rating';

  @override
  String get reviewBody => 'Tell other buyers how it went';

  @override
  String get reviewSubmit => 'Submit review';

  @override
  String get reviewPending =>
      'Thanks. Your review appears once staff approve it.';

  @override
  String get reviewThanks => 'Thanks for the review';

  @override
  String get reviewFailed => 'Could not submit the review';

  @override
  String get notDeliveredYet => 'Not delivered yet';
}
