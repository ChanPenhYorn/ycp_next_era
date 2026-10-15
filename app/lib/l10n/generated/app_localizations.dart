import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sela'**
  String get appTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchHint;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get outOfStock;

  /// No description provided for @buyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get buyNow;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @instant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get instant;

  /// No description provided for @soldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String soldCount(int count);

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Game top-ups and digital cards, instantly'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with ABA KHQR, receive your code in seconds'**
  String get heroSubtitle;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get featured;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get allProducts;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get noProducts;

  /// No description provided for @trustInstant.
  ///
  /// In en, this message translates to:
  /// **'Automatic 24/7 delivery'**
  String get trustInstant;

  /// No description provided for @trustPayment.
  ///
  /// In en, this message translates to:
  /// **'Pay with ABA KHQR'**
  String get trustPayment;

  /// No description provided for @trustSupport.
  ///
  /// In en, this message translates to:
  /// **'24/7 support on Telegram'**
  String get trustSupport;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @deliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryTime;

  /// No description provided for @deliveryInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get deliveryInstant;

  /// No description provided for @deliveryManual.
  ///
  /// In en, this message translates to:
  /// **'Manual, within 15 minutes'**
  String get deliveryManual;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @requiredInfo.
  ///
  /// In en, this message translates to:
  /// **'Required information'**
  String get requiredInfo;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviews;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmail;

  /// No description provided for @contactTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get contactTelegram;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get orderSummary;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @coupon.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get coupon;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @couponInvalid.
  ///
  /// In en, this message translates to:
  /// **'That coupon code is not valid'**
  String get couponInvalid;

  /// No description provided for @payWithKhqr.
  ///
  /// In en, this message translates to:
  /// **'Pay with ABA KHQR'**
  String get payWithKhqr;

  /// No description provided for @payWithWallet.
  ///
  /// In en, this message translates to:
  /// **'Pay from wallet'**
  String get payWithWallet;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan with any banking app'**
  String get scanQr;

  /// No description provided for @openAbaMobile.
  ///
  /// In en, this message translates to:
  /// **'Open ABA Mobile'**
  String get openAbaMobile;

  /// No description provided for @waitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment...'**
  String get waitingPayment;

  /// No description provided for @khqrExpired.
  ///
  /// In en, this message translates to:
  /// **'This QR has expired'**
  String get khqrExpired;

  /// No description provided for @newQr.
  ///
  /// In en, this message translates to:
  /// **'Generate a new QR'**
  String get newQr;

  /// No description provided for @insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Not enough wallet balance'**
  String get insufficientBalance;

  /// No description provided for @orderNo.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderNo;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get statusPending;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get statusDelivering;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get statusRefunded;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @yourCodes.
  ///
  /// In en, this message translates to:
  /// **'Your codes'**
  String get yourCodes;

  /// No description provided for @manualWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for staff setup'**
  String get manualWaiting;

  /// No description provided for @orderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get orderEmpty;

  /// No description provided for @orderPaidSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get orderPaidSuccess;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get about;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'Digital goods and game cards at fair prices with instant delivery.'**
  String get aboutText;

  /// No description provided for @quickLinks.
  ///
  /// In en, this message translates to:
  /// **'Quick links'**
  String get quickLinks;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @weAccept.
  ///
  /// In en, this message translates to:
  /// **'We accept'**
  String get weAccept;

  /// No description provided for @rights.
  ///
  /// In en, this message translates to:
  /// **'All rights reserved'**
  String get rights;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We email you a one-time code. No password to remember.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpLabel;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get verify;

  /// No description provided for @codeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {email}'**
  String codeSent(String email);

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @guestMustSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get guestMustSignIn;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get walletBalance;

  /// No description provided for @walletTopup.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get walletTopup;

  /// No description provided for @walletAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get walletAmount;

  /// No description provided for @walletHistory.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get walletHistory;

  /// No description provided for @walletEmpty.
  ///
  /// In en, this message translates to:
  /// **'No wallet activity yet'**
  String get walletEmpty;

  /// No description provided for @walletTopupNote.
  ///
  /// In en, this message translates to:
  /// **'Top-ups are credited the moment the KHQR is paid.'**
  String get walletTopupNote;

  /// No description provided for @walletCredited.
  ///
  /// In en, this message translates to:
  /// **'Top-up complete'**
  String get walletCredited;

  /// No description provided for @walletTopupFailed.
  ///
  /// In en, this message translates to:
  /// **'Top-up was not completed'**
  String get walletTopupFailed;

  /// No description provided for @walletLimits.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max}'**
  String walletLimits(String min, String max);

  /// No description provided for @walletSpent.
  ///
  /// In en, this message translates to:
  /// **'Order {orderNo}'**
  String walletSpent(Object orderNo);

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get writeReview;

  /// No description provided for @reviewRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get reviewRating;

  /// No description provided for @reviewBody.
  ///
  /// In en, this message translates to:
  /// **'Tell other buyers how it went'**
  String get reviewBody;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get reviewSubmit;

  /// No description provided for @reviewPending.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your review appears once staff approve it.'**
  String get reviewPending;

  /// No description provided for @reviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the review'**
  String get reviewThanks;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the review'**
  String get reviewFailed;

  /// No description provided for @notDeliveredYet.
  ///
  /// In en, this message translates to:
  /// **'Not delivered yet'**
  String get notDeliveredYet;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get accountEmail;

  /// No description provided for @coins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coins;

  /// No description provided for @connectTelegram.
  ///
  /// In en, this message translates to:
  /// **'Connect Telegram'**
  String get connectTelegram;

  /// No description provided for @telegramConnected.
  ///
  /// In en, this message translates to:
  /// **'Telegram connected'**
  String get telegramConnected;

  /// No description provided for @telegramHint.
  ///
  /// In en, this message translates to:
  /// **'Get a message the moment your order is ready, and check your codes in chat.'**
  String get telegramHint;

  /// No description provided for @telegramCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Send this code to the bot to link your account'**
  String get telegramCodeHint;

  /// No description provided for @telegramWait.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you to send the code...'**
  String get telegramWait;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @openTelegram.
  ///
  /// In en, this message translates to:
  /// **'Open Telegram'**
  String get openTelegram;

  /// No description provided for @telegramRefresh.
  ///
  /// In en, this message translates to:
  /// **'I have sent it'**
  String get telegramRefresh;

  /// No description provided for @telegramDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get telegramDisconnect;

  /// No description provided for @telegramLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start linking. Please try again.'**
  String get telegramLinkFailed;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an email address. Check for a missing @.'**
  String get invalidEmail;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}'**
  String otpSentTo(Object email);

  /// No description provided for @useDifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useDifferentEmail;

  /// No description provided for @emailRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in emails for now. Please try again later, or use Google.'**
  String get emailRateLimited;

  /// No description provided for @providerNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'That sign-in method is not switched on yet.'**
  String get providerNotEnabled;

  /// No description provided for @emailOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is limited while testing. Google sign-in has no limit.'**
  String get emailOnlyNote;

  /// No description provided for @codeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is not right. Check the six digits and try again.'**
  String get codeInvalid;

  /// No description provided for @devCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Sandbox mode: no email is sent. Enter {code}.'**
  String devCodeHint(String code);

  /// No description provided for @paywayNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'KHQR payments are not switched on for this project yet. Please use another payment method.'**
  String get paywayNotConfigured;

  /// No description provided for @paywayRejected.
  ///
  /// In en, this message translates to:
  /// **'ABA did not accept that payment. Please try again, or use another method.'**
  String get paywayRejected;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'km':
      return AppL10nKm();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
