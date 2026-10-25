// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chanpenh';

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
  String soldCount(String count) {
    return '$count sold';
  }

  @override
  String get from => 'From';

  @override
  String get featured => 'Popular';

  @override
  String get categories => 'Categories';

  @override
  String get allProducts => 'All products';

  @override
  String get searchNoResults => 'No games match this search. Try another name.';

  @override
  String get clearSearch => 'Clear search';

  @override
  String searchActive(String term) {
    return 'Search: $term';
  }

  @override
  String get noProducts => 'Nothing here yet';

  @override
  String get trustInstant => 'Automatic delivery';

  @override
  String get heroTitle => 'Top up your games in seconds';

  @override
  String get heroSubtitle =>
      'Game top-ups and gift cards. Pay with ABA KHQR and get your order delivered automatically.';

  @override
  String get heroCta => 'Browse games';

  @override
  String get trustPayment => 'Pay with ABA KHQR';

  @override
  String get trustSupport => 'Support on Telegram';

  @override
  String get description => 'Description';

  @override
  String get deliveryTime => 'Delivery';

  @override
  String get deliveryInstant => 'Instant';

  @override
  String get deliveryManual => 'Manual, within 15 minutes';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get quantity => 'Quantity';

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

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
  String get paymentMethod => 'Payment method';

  @override
  String get scanQr => 'Scan with any banking app';

  @override
  String get payByCard => 'Pay by card';

  @override
  String get payByCardSubtitle => 'Visa, Mastercard · Dodo';

  @override
  String get cardSheetTitle => 'Card payment';

  @override
  String get cardSheetIntro =>
      'Finish on Dodo\'s secure checkout. Keep this window open — it updates by itself when the payment lands.';

  @override
  String get cardOpenCheckout => 'Open secure checkout';

  @override
  String get cardWaiting => 'Waiting for the payment…';

  @override
  String get cardPaid => 'Payment received. Opening your order…';

  @override
  String get cardDeclined =>
      'The card payment did not go through. Try again or pick another method.';

  @override
  String get cardExpired => 'This checkout expired. Start a new order.';

  @override
  String get cardNotConfigured =>
      'Card payments are not switched on yet. Please use another method.';

  @override
  String get cardOpenFailed =>
      'Could not open the checkout page. Check your browser\'s pop-up blocker and try again.';

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
  String get manualWaiting => 'Waiting for us to check your transfer';

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
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle =>
      'Sign in with Google, or your email and password.';

  @override
  String get emailLabel => 'Email address';

  @override
  String get emailHint => 'you@example.com';

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
  String get itemUnavailable =>
      'Some items are no longer available. We removed them from your cart.';

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

  @override
  String get accountTitle => 'Account';

  @override
  String get accountEmail => 'Signed in as';

  @override
  String get coins => 'Coins';

  @override
  String get connectTelegram => 'Connect Telegram';

  @override
  String get telegramConnected => 'Telegram connected';

  @override
  String get telegramHint =>
      'Get a message the moment your order is ready, and check your codes in chat.';

  @override
  String get telegramUnlinkHint => 'Send /unlink in the chat to disconnect.';

  @override
  String get telegramCodeHint =>
      'Send this code to the bot to link your account';

  @override
  String get telegramWait => 'Waiting for you to send the code...';

  @override
  String get copyCode => 'Copy code';

  @override
  String get copied => 'Copied';

  @override
  String get openTelegram => 'Open Telegram';

  @override
  String get telegramRefresh => 'I have sent it';

  @override
  String get telegramDisconnect => 'Disconnect';

  @override
  String get telegramLinkFailed => 'Could not start linking. Please try again.';

  @override
  String get invalidEmail =>
      'That doesn\'t look like an email address. Check for a missing @.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get orDivider => 'or';

  @override
  String otpSentTo(Object email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get useDifferentEmail => 'Use a different email';

  @override
  String get emailRateLimited =>
      'Too many sign-in emails for now. Please try again later, or use Google.';

  @override
  String get providerNotEnabled =>
      'That sign-in method is not switched on yet.';

  @override
  String get emailOnlyNote =>
      'Email sign-in is limited while the project tests its mailer. Google has no limit.';

  @override
  String get codeInvalid =>
      'That code is not right. Check the six digits and try again.';

  @override
  String devCodeHint(String code) {
    return 'Sandbox mode: no email is sent. Enter $code.';
  }

  @override
  String get authTabSignIn => 'Sign in';

  @override
  String get authTabRegister => 'Create account';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle =>
      'One account for orders, wallet balance and delivery codes.';

  @override
  String get nameLabel => 'Full name';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String noAccountYet(String brand) {
    return 'New to $brand?';
  }

  @override
  String get haveAccountAlready => 'Already have an account?';

  @override
  String get orContinueWithEmail => 'or continue with email';

  @override
  String get signInWithCode => 'Email me a code instead';

  @override
  String get usePasswordInstead => 'Use a password instead';

  @override
  String get codeSignInTitle => 'Sign in with a code';

  @override
  String get codeSignInSubtitle => 'No password needed. We email six digits.';

  @override
  String get resendCode => 'Send a new code';

  @override
  String get confirmEmailTitle => 'Confirm your email';

  @override
  String confirmEmailBody(String email) {
    return 'We sent six digits to $email. Enter them to switch the account on.';
  }

  @override
  String get confirmAndContinue => 'Confirm and continue';

  @override
  String get resetTitle => 'Reset your password';

  @override
  String get resetSubtitle =>
      'We email six digits, then you choose a new password.';

  @override
  String get sendResetCode => 'Email me a code';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get savePassword => 'Save password and sign in';

  @override
  String passwordRuleTooShort(String min) {
    return 'Use at least $min characters.';
  }

  @override
  String get passwordRuleNeedsLower => 'Add a lowercase letter.';

  @override
  String get passwordRuleNeedsUpper => 'Add an uppercase letter.';

  @override
  String get passwordRuleNeedsDigit => 'Add a number.';

  @override
  String get passwordMismatch => 'The two passwords do not match.';

  @override
  String get passwordTooWeak =>
      'That password is too easy to guess. Make it longer.';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get referralToggle => 'Have a referral code?';

  @override
  String get referralCodeLabel => 'Referral code (optional)';

  @override
  String get referralHint => '8 letters or numbers';

  @override
  String get referralInvalid => 'A referral code is 8 characters.';

  @override
  String get referralFailed =>
      'Account created, but that referral code was not applied.';

  @override
  String get termsAgree =>
      'I agree to the Terms of Service and Privacy Policy.';

  @override
  String get termsRequired => 'Please accept the terms to continue.';

  @override
  String get nameRequired => 'Please enter your name.';

  @override
  String get passwordRequired => 'Please enter your password.';

  @override
  String get codeRequired => 'Enter the 6-digit code from the email.';

  @override
  String get emailInUse => 'That email already has an account. Try signing in.';

  @override
  String get wrongCredentials => 'Email or password is not right.';

  @override
  String get emailNotConfirmed =>
      'Confirm your email first — we sent you a code.';

  @override
  String get codeExpired => 'That code has expired. Ask for a new one.';

  @override
  String get paywayNotConfigured =>
      'KHQR payments are not switched on for this project yet. Please use another payment method.';

  @override
  String get paywayRejected =>
      'ABA did not accept that payment. Please try again, or use another method.';

  @override
  String get navHome => 'Home';

  @override
  String get navGames => 'Games';

  @override
  String get searchGames => 'Search games...';

  @override
  String get popularGames => 'Popular games';

  @override
  String get buyAgain => 'Buy again';

  @override
  String get trendingNow => 'Trending now';

  @override
  String get promotions => 'Promotions';

  @override
  String get promotionsSubtitle => 'Live discounts on selected packages';

  @override
  String get howItWorks => 'How it works';

  @override
  String get howStep1Title => 'Choose your game and package';

  @override
  String get howStep1Body => 'Pick the game, then the package you want.';

  @override
  String get howStep2Title => 'Enter your player ID';

  @override
  String get howStep2Body =>
      'Type the ID exactly as it shows in the game. Never your password.';

  @override
  String get howStep3Title => 'Pay and track your top-up';

  @override
  String get howStep3Body =>
      'Pay by ABA KHQR, then follow the order to delivery.';

  @override
  String get trustAndSupport => 'Trust and support';

  @override
  String get trustDeliveryTitle => 'Delivery';

  @override
  String get trustDeliveryBody =>
      'Codes and top-ups are delivered automatically once payment is confirmed. A supplier top-up can take a few minutes.';

  @override
  String get trustPaymentTitle => 'Payment';

  @override
  String get trustPaymentBody =>
      'ABA confirms your payment on the server. A screenshot is never treated as proof of payment.';

  @override
  String get trustRefundTitle => 'Refunds';

  @override
  String get trustRefundBody =>
      'If a top-up cannot be delivered, the amount is returned to your wallet. Refunds to a bank account are handled by support.';

  @override
  String get trustSupportTitle => 'Support';

  @override
  String get trustSupportBody =>
      'Send us your order number and we will take it from there.';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get qtyOnePerOrder =>
      'This top-up is delivered one at a time. Quantity set to 1 - tap buy again to continue.';

  @override
  String get tooManyLines =>
      'That is more than 20 items in one order. Please split it into two orders.';

  @override
  String get accountBlocked =>
      'Your account is on hold. Contact support and we will sort it out.';

  @override
  String get paymentUnreachable =>
      'Could not reach the payment service. Your order is saved, so try again or pay another way.';

  @override
  String get orderNotPayable =>
      'This order can no longer be paid. It may already be paid or expired - check its status below.';

  @override
  String get statusRefundPending => 'Refund pending';

  @override
  String get fieldHelpTooltip => 'How to find this';

  @override
  String get fieldHelpTitle => 'Where do I find this?';

  @override
  String get fieldHelpExample => 'Example';

  @override
  String get fieldHelpUserid =>
      'Open the game and tap your profile or avatar. Your ID is the number shown under your name. It does not change.';

  @override
  String get fieldHelpZone =>
      'Your server or zone is usually shown next to your in-game name, often in brackets, for example (2001).';

  @override
  String get fieldHelpGeneric =>
      'Open the game or service and look for this on your account or profile screen.';

  @override
  String get fieldHelpWarning =>
      'Check it before you pay. A top-up sent to the wrong ID usually cannot be reversed. If it fails, the amount returns to your wallet.';

  @override
  String get fieldRequired => 'Required';

  @override
  String get fieldWrongFormat => 'That is not the right format';

  @override
  String get close => 'Close';

  @override
  String get payByTransfer => 'Pay by bank transfer';

  @override
  String get transferIntro =>
      'Pay the exact amount below, then tell us. We check every transfer by hand against the bank, and your order stays open while we do.';

  @override
  String get transferTo => 'Transfer to';

  @override
  String get transferAccount => 'Account number';

  @override
  String get manualRateLimited =>
      'You have asked about a few orders already. Send us your order number and we will check it directly.';

  @override
  String get transferAmount => 'Amount';

  @override
  String get transferRemark => 'Put this as the remark';

  @override
  String get transferRemarkHint => 'so we can match your payment';

  @override
  String get iHavePaid => 'I have paid — check it';

  @override
  String get manualRequested =>
      'Thank you. Your payment is waiting to be checked by hand. You can close this page; the order will update when it is confirmed.';

  @override
  String get manualWaitingBody =>
      'If it has been a while, contact support with your order number.';

  @override
  String get adminManualPayments => 'Transfers to check';

  @override
  String get adminManualQueue =>
      'Orders where the buyer has asked to pay by bank transfer.';

  @override
  String get adminNoManualRequests =>
      'Nothing waiting. No buyer has asked to pay by transfer.';

  @override
  String get adminAmountReceived => 'Amount received';

  @override
  String get adminAmountReceivedHint => 'Type what the bank shows, in USD';

  @override
  String get adminAbaRef => 'ABA reference';

  @override
  String get adminAbaRefHint =>
      'From the bank app — each one can settle one order only';

  @override
  String get adminConfirmPayment => 'Confirm payment';

  @override
  String get adminDismissRequest => 'Dismiss request';

  @override
  String get adminDismissReason => 'Why is it being dismissed?';

  @override
  String get adminExpiresIn => 'Payable until';

  @override
  String get adminUnderpaid =>
      'That is less than the order total. Nothing was confirmed.';

  @override
  String get adminReferenceUsed =>
      'That ABA reference has already settled a different order.';

  @override
  String get adminExpired =>
      'This order expired. Handle the money as an external refund.';

  @override
  String get adminOnly => 'This page is for staff accounts.';

  @override
  String get orderNumber => 'Order number';

  @override
  String get adminTitle => 'Staff';

  @override
  String get adminOverview => 'Overview';

  @override
  String get adminOrdersTitle => 'Orders';

  @override
  String get adminRefundsTitle => 'Refunds';

  @override
  String get adminSupportTitle => 'Support';

  @override
  String get adminNeedsAttention => 'What needs doing';

  @override
  String get adminMoney => 'Money';

  @override
  String get adminPendingOrders => 'Pending orders';

  @override
  String get adminSupportOpen => 'Open tickets';

  @override
  String get adminManualWaiting => 'Lines awaiting manual delivery';

  @override
  String get adminReceivedToday => 'Received today';

  @override
  String get adminReceived7d => 'Received, last 7 days';

  @override
  String get adminReceived30d => 'Received, last 30 days';

  @override
  String get adminWalletSpent30d => 'Spent from wallets, last 30 days';

  @override
  String get adminRefunded30d => 'Refunded, last 30 days';

  @override
  String get adminReceivedNote =>
      'Money that reached the bank. Refunds are listed beside it, not taken off it, and wallet spend is not new money.';

  @override
  String get adminCountsNote => 'Counts of rows, not estimates.';

  @override
  String get adminSearchOrder => 'Order number';

  @override
  String get adminFilterAll => 'All';

  @override
  String get adminNoOrders => 'No orders match.';

  @override
  String get adminItemsTitle => 'Items';

  @override
  String get adminCustomerNote => 'Buyer\'s note';

  @override
  String get adminBuyerFields => 'Buyer fields';

  @override
  String get adminTimeline => 'History';

  @override
  String get adminPaymentsTitle => 'Payments';

  @override
  String get adminBuyerTitle => 'Buyer';

  @override
  String get adminKind => 'Type';

  @override
  String get adminKindPurchase => 'Purchase';

  @override
  String get adminKindWalletTopup => 'Wallet top-up';

  @override
  String get adminCreatedAt => 'Created';

  @override
  String get adminPaidAt => 'Paid';

  @override
  String get adminAgreeRefund => 'Agree a refund';

  @override
  String get adminRefundReason => 'Why is it being refunded?';

  @override
  String get adminMarkRefunded => 'Record the refund';

  @override
  String get adminRefundReference => 'Bank reference';

  @override
  String get adminRefundReferenceHint =>
      'Optional, but it is what makes the refund auditable';

  @override
  String get adminRefundRecorded =>
      'Recorded. This screen does not move money — the reversal is done in the bank.';

  @override
  String get adminRefundNote =>
      'Recording a refund here does not move money. Do the reversal in the bank first, then record what you did.';

  @override
  String get adminSummary => 'Summary';

  @override
  String get adminRefundsEmpty => 'No refunds are waiting.';

  @override
  String get adminResolveDelivered => 'Mark delivered';

  @override
  String get adminResolveFailed => 'Mark failed';

  @override
  String get adminTicketOpen => 'Open';

  @override
  String get adminTicketInProgress => 'In progress';

  @override
  String get adminTicketResolved => 'Resolved';

  @override
  String get adminTicketClosed => 'Closed';

  @override
  String get adminPriorityLow => 'Low';

  @override
  String get adminPriorityNormal => 'Normal';

  @override
  String get adminPriorityHigh => 'High';

  @override
  String get adminTicketContact => 'Contact';

  @override
  String get adminTicketNote => 'Internal note';

  @override
  String get adminTicketStart => 'Start';

  @override
  String get adminTicketResolve => 'Resolve';

  @override
  String get adminTicketClose => 'Close';

  @override
  String get adminTicketOpenOrder => 'Open the order';

  @override
  String get adminTicketsEmpty => 'No tickets.';

  @override
  String get adminCatalogueTitle => 'Catalogue';

  @override
  String get adminCatalogueNote =>
      'Hidden products do not show to customers. A price cannot go below the supplier cost.';

  @override
  String get adminCatalogueEmpty => 'No products yet.';

  @override
  String get adminProductShown => 'Shown to customers';

  @override
  String get adminProductHidden => 'Hidden';

  @override
  String get adminVariantPrice => 'Retail price (USD)';

  @override
  String get adminVariantPriceHint =>
      'Must be above zero and not below the supplier cost.';

  @override
  String get adminCostLabel => 'Cost';

  @override
  String get adminMarginLabel => 'Margin';

  @override
  String get adminPriceSaved => 'Price saved.';

  @override
  String get adminPriceInvalid => 'Enter a price above zero.';

  @override
  String get adminPriceBelowCost =>
      'The price is below the supplier cost. Not saved.';

  @override
  String get adminQueueTitle => 'Supplier queue';

  @override
  String get adminQueueNote =>
      'Lines the supplier could not finish. Retrying lines fix themselves; lines that need you are listed first.';

  @override
  String get adminQueueEmpty => 'No supplier lines are stuck.';

  @override
  String get adminQueueNeedsYou => 'Needs you';

  @override
  String get adminQueueRetrying => 'Retrying';

  @override
  String get adminQueueConfirmTitle => 'Mark this line delivered?';

  @override
  String get adminQueueConfirmBody =>
      'Only do this after you have delivered the top-up by hand. The buyer is not refunded.';

  @override
  String get adminQueueDelivered => 'Line marked delivered.';

  @override
  String get adminSavePrice => 'Save price';

  @override
  String get adminStaffTitle => 'Staff & roles';

  @override
  String get adminStaffNote =>
      'Only admins see this page. Staff run the admin screens; admins also manage roles.';

  @override
  String get adminStaffEmpty => 'No staff accounts yet.';

  @override
  String get adminFindByEmail => 'Find an account by email';

  @override
  String get adminEmailLabel => 'Email';

  @override
  String get adminFindButton => 'Find';

  @override
  String get adminRoleCustomer => 'Customer';

  @override
  String get adminRoleStaff => 'Staff';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminSetRole => 'Set role';

  @override
  String get adminRoleSaved => 'Role updated.';

  @override
  String get adminConsole => 'Staff console';

  @override
  String get adminExitToStore => 'Back to the store';

  @override
  String get adminCannotChangeOwn => 'You cannot change your own role.';

  @override
  String get adminUserNotFound =>
      'No account with that email. Ask them to sign up first.';

  @override
  String get adminConfirmPaymentNote =>
      'This marks the order paid and hands the line to the supplier. It cannot be undone from this screen.';

  @override
  String get adminDismissNote =>
      'This drops the buyer\'s claim. The order stays unpaid.';

  @override
  String get adminSetRoleTitle => 'Change this role?';

  @override
  String get adminSetRoleBody =>
      'The change takes effect immediately. Set another role to undo it.';

  @override
  String get adminResolveFailedTitle => 'Mark this line failed?';

  @override
  String get adminResolveFailedBody =>
      'The buyer is not refunded by this. A failed line needs a separate refund decision.';

  @override
  String get adminTicketCloseTitle => 'Close this ticket?';

  @override
  String get adminTicketCloseBody =>
      'It moves to Closed and drops out of the working list.';

  @override
  String adminShowingCount(int count) {
    return 'Showing the $count most recent.';
  }

  @override
  String get adminBannerTitle => 'Banner art';

  @override
  String get adminBannerUrlLabel => 'Image URL (blank searches IGDB)';

  @override
  String get adminBannerHint => 'A wide image works best: 16:9 or wider.';

  @override
  String get adminBannerFind => 'Find banner';

  @override
  String get adminBannerSaved => 'Banner saved.';

  @override
  String get adminBannerNone => 'No matching banner found.';

  @override
  String get adminBannerNotConfigured => 'The banner source is not configured.';

  @override
  String get adminBannerFailed => 'Could not load a banner.';
}
