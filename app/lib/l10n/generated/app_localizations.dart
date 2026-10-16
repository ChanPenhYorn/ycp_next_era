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
  /// **'Chanpenh'**
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
  String soldCount(String count);

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

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
  /// **'Automatic delivery'**
  String get trustInstant;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Top up your games in seconds'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Game top-ups and gift cards. Pay with ABA KHQR and get your order delivered automatically.'**
  String get heroSubtitle;

  /// No description provided for @heroCta.
  ///
  /// In en, this message translates to:
  /// **'Browse games'**
  String get heroCta;

  /// No description provided for @trustPayment.
  ///
  /// In en, this message translates to:
  /// **'Pay with ABA KHQR'**
  String get trustPayment;

  /// No description provided for @trustSupport.
  ///
  /// In en, this message translates to:
  /// **'Support on Telegram'**
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

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

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

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

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
  /// **'Waiting for us to check your transfer'**
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
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google, or your email and password.'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

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
  /// **'Email sign-in is limited while the project tests its mailer. Google has no limit.'**
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

  /// No description provided for @authTabSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authTabSignIn;

  /// No description provided for @authTabRegister.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authTabRegister;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One account for orders, wallet balance and delivery codes.'**
  String get registerSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get nameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'New to {brand}?'**
  String noAccountYet(String brand);

  /// No description provided for @haveAccountAlready.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountAlready;

  /// No description provided for @orContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or continue with email'**
  String get orContinueWithEmail;

  /// No description provided for @signInWithCode.
  ///
  /// In en, this message translates to:
  /// **'Email me a code instead'**
  String get signInWithCode;

  /// No description provided for @usePasswordInstead.
  ///
  /// In en, this message translates to:
  /// **'Use a password instead'**
  String get usePasswordInstead;

  /// No description provided for @codeSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a code'**
  String get codeSignInTitle;

  /// No description provided for @codeSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No password needed. We email six digits.'**
  String get codeSignInSubtitle;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get resendCode;

  /// No description provided for @confirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmEmailTitle;

  /// No description provided for @confirmEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent six digits to {email}. Enter them to switch the account on.'**
  String confirmEmailBody(String email);

  /// No description provided for @confirmAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Confirm and continue'**
  String get confirmAndContinue;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We email six digits, then you choose a new password.'**
  String get resetSubtitle;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Email me a code'**
  String get sendResetCode;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @savePassword.
  ///
  /// In en, this message translates to:
  /// **'Save password and sign in'**
  String get savePassword;

  /// No description provided for @passwordRuleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String passwordRuleTooShort(String min);

  /// No description provided for @passwordRuleNeedsLower.
  ///
  /// In en, this message translates to:
  /// **'Add a lowercase letter.'**
  String get passwordRuleNeedsLower;

  /// No description provided for @passwordRuleNeedsUpper.
  ///
  /// In en, this message translates to:
  /// **'Add an uppercase letter.'**
  String get passwordRuleNeedsUpper;

  /// No description provided for @passwordRuleNeedsDigit.
  ///
  /// In en, this message translates to:
  /// **'Add a number.'**
  String get passwordRuleNeedsDigit;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @passwordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'That password is too easy to guess. Make it longer.'**
  String get passwordTooWeak;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @referralToggle.
  ///
  /// In en, this message translates to:
  /// **'Have a referral code?'**
  String get referralToggle;

  /// No description provided for @referralCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeLabel;

  /// No description provided for @referralHint.
  ///
  /// In en, this message translates to:
  /// **'8 letters or numbers'**
  String get referralHint;

  /// No description provided for @referralInvalid.
  ///
  /// In en, this message translates to:
  /// **'A referral code is 8 characters.'**
  String get referralInvalid;

  /// No description provided for @referralFailed.
  ///
  /// In en, this message translates to:
  /// **'Account created, but that referral code was not applied.'**
  String get referralFailed;

  /// No description provided for @termsAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy.'**
  String get termsAgree;

  /// No description provided for @termsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms to continue.'**
  String get termsRequired;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get nameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get passwordRequired;

  /// No description provided for @codeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the email.'**
  String get codeRequired;

  /// No description provided for @emailInUse.
  ///
  /// In en, this message translates to:
  /// **'That email already has an account. Try signing in.'**
  String get emailInUse;

  /// No description provided for @wrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is not right.'**
  String get wrongCredentials;

  /// No description provided for @emailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email first — we sent you a code.'**
  String get emailNotConfirmed;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Ask for a new one.'**
  String get codeExpired;

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

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get navGames;

  /// No description provided for @searchGames.
  ///
  /// In en, this message translates to:
  /// **'Search games...'**
  String get searchGames;

  /// No description provided for @popularGames.
  ///
  /// In en, this message translates to:
  /// **'Popular games'**
  String get popularGames;

  /// No description provided for @promotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get promotions;

  /// No description provided for @promotionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live discounts on selected packages'**
  String get promotionsSubtitle;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorks;

  /// No description provided for @howStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Choose your game and package'**
  String get howStep1Title;

  /// No description provided for @howStep1Body.
  ///
  /// In en, this message translates to:
  /// **'Pick the game, then the package you want.'**
  String get howStep1Body;

  /// No description provided for @howStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Enter your player ID'**
  String get howStep2Title;

  /// No description provided for @howStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Type the ID exactly as it shows in the game. Never your password.'**
  String get howStep2Body;

  /// No description provided for @howStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Pay and track your top-up'**
  String get howStep3Title;

  /// No description provided for @howStep3Body.
  ///
  /// In en, this message translates to:
  /// **'Pay by ABA KHQR, then follow the order to delivery.'**
  String get howStep3Body;

  /// No description provided for @trustAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Trust and support'**
  String get trustAndSupport;

  /// No description provided for @trustDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get trustDeliveryTitle;

  /// No description provided for @trustDeliveryBody.
  ///
  /// In en, this message translates to:
  /// **'Codes and top-ups are delivered automatically once payment is confirmed. A supplier top-up can take a few minutes.'**
  String get trustDeliveryBody;

  /// No description provided for @trustPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get trustPaymentTitle;

  /// No description provided for @trustPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'ABA confirms your payment on the server. A screenshot is never treated as proof of payment.'**
  String get trustPaymentBody;

  /// No description provided for @trustRefundTitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get trustRefundTitle;

  /// No description provided for @trustRefundBody.
  ///
  /// In en, this message translates to:
  /// **'If a top-up cannot be delivered, the amount is returned to your wallet. Refunds to a bank account are handled by support.'**
  String get trustRefundBody;

  /// No description provided for @trustSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get trustSupportTitle;

  /// No description provided for @trustSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Send us your order number and we will take it from there.'**
  String get trustSupportBody;

  /// No description provided for @partnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Supply partner'**
  String get partnerTitle;

  /// No description provided for @partnerBody.
  ///
  /// In en, this message translates to:
  /// **'Many top-ups are fulfilled automatically through our supply partner Bay2Game.'**
  String get partnerBody;

  /// No description provided for @partnerBadge.
  ///
  /// In en, this message translates to:
  /// **'Automatic fulfilment'**
  String get partnerBadge;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @statusRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund pending'**
  String get statusRefundPending;

  /// No description provided for @fieldHelpTooltip.
  ///
  /// In en, this message translates to:
  /// **'How to find this'**
  String get fieldHelpTooltip;

  /// No description provided for @fieldHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do I find this?'**
  String get fieldHelpTitle;

  /// No description provided for @fieldHelpExample.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get fieldHelpExample;

  /// No description provided for @fieldHelpUserid.
  ///
  /// In en, this message translates to:
  /// **'Open the game and tap your profile or avatar. Your ID is the number shown under your name. It does not change.'**
  String get fieldHelpUserid;

  /// No description provided for @fieldHelpZone.
  ///
  /// In en, this message translates to:
  /// **'Your server or zone is usually shown next to your in-game name, often in brackets, for example (2001).'**
  String get fieldHelpZone;

  /// No description provided for @fieldHelpGeneric.
  ///
  /// In en, this message translates to:
  /// **'Open the game or service and look for this on your account or profile screen.'**
  String get fieldHelpGeneric;

  /// No description provided for @fieldHelpWarning.
  ///
  /// In en, this message translates to:
  /// **'Check it before you pay. A top-up sent to the wrong ID usually cannot be reversed. If it fails, the amount returns to your wallet.'**
  String get fieldHelpWarning;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @fieldWrongFormat.
  ///
  /// In en, this message translates to:
  /// **'That is not the right format'**
  String get fieldWrongFormat;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @payByTransfer.
  ///
  /// In en, this message translates to:
  /// **'Pay by bank transfer'**
  String get payByTransfer;

  /// No description provided for @transferIntro.
  ///
  /// In en, this message translates to:
  /// **'Pay the exact amount below, then tell us. We check every transfer by hand against the bank, and your order stays open while we do.'**
  String get transferIntro;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer to'**
  String get transferTo;

  /// No description provided for @transferAccount.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get transferAccount;

  /// No description provided for @manualRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You have asked about a few orders already. Send us your order number and we will check it directly.'**
  String get manualRateLimited;

  /// No description provided for @transferAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get transferAmount;

  /// No description provided for @transferRemark.
  ///
  /// In en, this message translates to:
  /// **'Put this as the remark'**
  String get transferRemark;

  /// No description provided for @transferRemarkHint.
  ///
  /// In en, this message translates to:
  /// **'so we can match your payment'**
  String get transferRemarkHint;

  /// No description provided for @iHavePaid.
  ///
  /// In en, this message translates to:
  /// **'I have paid — check it'**
  String get iHavePaid;

  /// No description provided for @manualRequested.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your payment is waiting to be checked by hand. You can close this page; the order will update when it is confirmed.'**
  String get manualRequested;

  /// No description provided for @manualWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'If it has been a while, contact support with your order number.'**
  String get manualWaitingBody;

  /// No description provided for @adminManualPayments.
  ///
  /// In en, this message translates to:
  /// **'Transfers to check'**
  String get adminManualPayments;

  /// No description provided for @adminManualQueue.
  ///
  /// In en, this message translates to:
  /// **'Orders where the buyer has asked to pay by bank transfer.'**
  String get adminManualQueue;

  /// No description provided for @adminNoManualRequests.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting. No buyer has asked to pay by transfer.'**
  String get adminNoManualRequests;

  /// No description provided for @adminAmountReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get adminAmountReceived;

  /// No description provided for @adminAmountReceivedHint.
  ///
  /// In en, this message translates to:
  /// **'Type what the bank shows, in USD'**
  String get adminAmountReceivedHint;

  /// No description provided for @adminAbaRef.
  ///
  /// In en, this message translates to:
  /// **'ABA reference'**
  String get adminAbaRef;

  /// No description provided for @adminAbaRefHint.
  ///
  /// In en, this message translates to:
  /// **'From the bank app — each one can settle one order only'**
  String get adminAbaRefHint;

  /// No description provided for @adminConfirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get adminConfirmPayment;

  /// No description provided for @adminDismissRequest.
  ///
  /// In en, this message translates to:
  /// **'Dismiss request'**
  String get adminDismissRequest;

  /// No description provided for @adminDismissReason.
  ///
  /// In en, this message translates to:
  /// **'Why is it being dismissed?'**
  String get adminDismissReason;

  /// No description provided for @adminExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Payable until'**
  String get adminExpiresIn;

  /// No description provided for @adminUnderpaid.
  ///
  /// In en, this message translates to:
  /// **'That is less than the order total. Nothing was confirmed.'**
  String get adminUnderpaid;

  /// No description provided for @adminReferenceUsed.
  ///
  /// In en, this message translates to:
  /// **'That ABA reference has already settled a different order.'**
  String get adminReferenceUsed;

  /// No description provided for @adminExpired.
  ///
  /// In en, this message translates to:
  /// **'This order expired. Handle the money as an external refund.'**
  String get adminExpired;

  /// No description provided for @adminOnly.
  ///
  /// In en, this message translates to:
  /// **'This page is for staff accounts.'**
  String get adminOnly;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderNumber;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get adminTitle;

  /// No description provided for @adminOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get adminOverview;

  /// No description provided for @adminOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get adminOrdersTitle;

  /// No description provided for @adminRefundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get adminRefundsTitle;

  /// No description provided for @adminSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get adminSupportTitle;

  /// No description provided for @adminNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'What needs doing'**
  String get adminNeedsAttention;

  /// No description provided for @adminMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get adminMoney;

  /// No description provided for @adminPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending orders'**
  String get adminPendingOrders;

  /// No description provided for @adminSupportOpen.
  ///
  /// In en, this message translates to:
  /// **'Open tickets'**
  String get adminSupportOpen;

  /// No description provided for @adminManualWaiting.
  ///
  /// In en, this message translates to:
  /// **'Lines awaiting manual delivery'**
  String get adminManualWaiting;

  /// No description provided for @adminReceivedToday.
  ///
  /// In en, this message translates to:
  /// **'Received today'**
  String get adminReceivedToday;

  /// No description provided for @adminReceived7d.
  ///
  /// In en, this message translates to:
  /// **'Received, last 7 days'**
  String get adminReceived7d;

  /// No description provided for @adminReceived30d.
  ///
  /// In en, this message translates to:
  /// **'Received, last 30 days'**
  String get adminReceived30d;

  /// No description provided for @adminWalletSpent30d.
  ///
  /// In en, this message translates to:
  /// **'Spent from wallets, last 30 days'**
  String get adminWalletSpent30d;

  /// No description provided for @adminRefunded30d.
  ///
  /// In en, this message translates to:
  /// **'Refunded, last 30 days'**
  String get adminRefunded30d;

  /// No description provided for @adminReceivedNote.
  ///
  /// In en, this message translates to:
  /// **'Money that reached the bank. Refunds are listed beside it, not taken off it, and wallet spend is not new money.'**
  String get adminReceivedNote;

  /// No description provided for @adminCountsNote.
  ///
  /// In en, this message translates to:
  /// **'Counts of rows, not estimates.'**
  String get adminCountsNote;

  /// No description provided for @adminSearchOrder.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get adminSearchOrder;

  /// No description provided for @adminFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminFilterAll;

  /// No description provided for @adminNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders match.'**
  String get adminNoOrders;

  /// No description provided for @adminItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get adminItemsTitle;

  /// No description provided for @adminCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Buyer\'s note'**
  String get adminCustomerNote;

  /// No description provided for @adminBuyerFields.
  ///
  /// In en, this message translates to:
  /// **'Buyer fields'**
  String get adminBuyerFields;

  /// No description provided for @adminTimeline.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get adminTimeline;

  /// No description provided for @adminPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get adminPaymentsTitle;

  /// No description provided for @adminBuyerTitle.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get adminBuyerTitle;

  /// No description provided for @adminKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminKind;

  /// No description provided for @adminKindPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get adminKindPurchase;

  /// No description provided for @adminKindWalletTopup.
  ///
  /// In en, this message translates to:
  /// **'Wallet top-up'**
  String get adminKindWalletTopup;

  /// No description provided for @adminCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get adminCreatedAt;

  /// No description provided for @adminPaidAt.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get adminPaidAt;

  /// No description provided for @adminAgreeRefund.
  ///
  /// In en, this message translates to:
  /// **'Agree a refund'**
  String get adminAgreeRefund;

  /// No description provided for @adminRefundReason.
  ///
  /// In en, this message translates to:
  /// **'Why is it being refunded?'**
  String get adminRefundReason;

  /// No description provided for @adminMarkRefunded.
  ///
  /// In en, this message translates to:
  /// **'Record the refund'**
  String get adminMarkRefunded;

  /// No description provided for @adminRefundReference.
  ///
  /// In en, this message translates to:
  /// **'Bank reference'**
  String get adminRefundReference;

  /// No description provided for @adminRefundReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, but it is what makes the refund auditable'**
  String get adminRefundReferenceHint;

  /// No description provided for @adminRefundRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded. This screen does not move money — the reversal is done in the bank.'**
  String get adminRefundRecorded;

  /// No description provided for @adminRefundNote.
  ///
  /// In en, this message translates to:
  /// **'Recording a refund here does not move money. Do the reversal in the bank first, then record what you did.'**
  String get adminRefundNote;

  /// No description provided for @adminSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get adminSummary;

  /// No description provided for @adminRefundsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No refunds are waiting.'**
  String get adminRefundsEmpty;

  /// No description provided for @adminResolveDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get adminResolveDelivered;

  /// No description provided for @adminResolveFailed.
  ///
  /// In en, this message translates to:
  /// **'Mark failed'**
  String get adminResolveFailed;

  /// No description provided for @adminTicketOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminTicketOpen;

  /// No description provided for @adminTicketInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get adminTicketInProgress;

  /// No description provided for @adminTicketResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get adminTicketResolved;

  /// No description provided for @adminTicketClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get adminTicketClosed;

  /// No description provided for @adminPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get adminPriorityLow;

  /// No description provided for @adminPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get adminPriorityNormal;

  /// No description provided for @adminPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get adminPriorityHigh;

  /// No description provided for @adminTicketContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get adminTicketContact;

  /// No description provided for @adminTicketNote.
  ///
  /// In en, this message translates to:
  /// **'Internal note'**
  String get adminTicketNote;

  /// No description provided for @adminTicketStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get adminTicketStart;

  /// No description provided for @adminTicketResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get adminTicketResolve;

  /// No description provided for @adminTicketClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminTicketClose;

  /// No description provided for @adminTicketOpenOrder.
  ///
  /// In en, this message translates to:
  /// **'Open the order'**
  String get adminTicketOpenOrder;

  /// No description provided for @adminTicketsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tickets.'**
  String get adminTicketsEmpty;

  /// No description provided for @adminCatalogueTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalogue'**
  String get adminCatalogueTitle;

  /// No description provided for @adminCatalogueNote.
  ///
  /// In en, this message translates to:
  /// **'Hidden products do not show to customers. A price cannot go below the supplier cost.'**
  String get adminCatalogueNote;

  /// No description provided for @adminCatalogueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products yet.'**
  String get adminCatalogueEmpty;

  /// No description provided for @adminProductShown.
  ///
  /// In en, this message translates to:
  /// **'Shown to customers'**
  String get adminProductShown;

  /// No description provided for @adminProductHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get adminProductHidden;

  /// No description provided for @adminVariantPrice.
  ///
  /// In en, this message translates to:
  /// **'Retail price (USD)'**
  String get adminVariantPrice;

  /// No description provided for @adminVariantPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Must be above zero and not below the supplier cost.'**
  String get adminVariantPriceHint;

  /// No description provided for @adminCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get adminCostLabel;

  /// No description provided for @adminMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get adminMarginLabel;

  /// No description provided for @adminPriceSaved.
  ///
  /// In en, this message translates to:
  /// **'Price saved.'**
  String get adminPriceSaved;

  /// No description provided for @adminPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a price above zero.'**
  String get adminPriceInvalid;

  /// No description provided for @adminPriceBelowCost.
  ///
  /// In en, this message translates to:
  /// **'The price is below the supplier cost. Not saved.'**
  String get adminPriceBelowCost;

  /// No description provided for @adminQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplier queue'**
  String get adminQueueTitle;

  /// No description provided for @adminQueueNote.
  ///
  /// In en, this message translates to:
  /// **'Lines the supplier could not finish. Retrying lines fix themselves; lines that need you are listed first.'**
  String get adminQueueNote;

  /// No description provided for @adminQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No supplier lines are stuck.'**
  String get adminQueueEmpty;

  /// No description provided for @adminQueueNeedsYou.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get adminQueueNeedsYou;

  /// No description provided for @adminQueueRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get adminQueueRetrying;

  /// No description provided for @adminQueueConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark this line delivered?'**
  String get adminQueueConfirmTitle;

  /// No description provided for @adminQueueConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Only do this after you have delivered the top-up by hand. The buyer is not refunded.'**
  String get adminQueueConfirmBody;

  /// No description provided for @adminQueueDelivered.
  ///
  /// In en, this message translates to:
  /// **'Line marked delivered.'**
  String get adminQueueDelivered;

  /// No description provided for @adminSavePrice.
  ///
  /// In en, this message translates to:
  /// **'Save price'**
  String get adminSavePrice;

  /// No description provided for @adminStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff & roles'**
  String get adminStaffTitle;

  /// No description provided for @adminStaffNote.
  ///
  /// In en, this message translates to:
  /// **'Only admins see this page. Staff run the admin screens; admins also manage roles.'**
  String get adminStaffNote;

  /// No description provided for @adminStaffEmpty.
  ///
  /// In en, this message translates to:
  /// **'No staff accounts yet.'**
  String get adminStaffEmpty;

  /// No description provided for @adminFindByEmail.
  ///
  /// In en, this message translates to:
  /// **'Find an account by email'**
  String get adminFindByEmail;

  /// No description provided for @adminEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminEmailLabel;

  /// No description provided for @adminFindButton.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get adminFindButton;

  /// No description provided for @adminRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get adminRoleCustomer;

  /// No description provided for @adminRoleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get adminRoleStaff;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminSetRole.
  ///
  /// In en, this message translates to:
  /// **'Set role'**
  String get adminSetRole;

  /// No description provided for @adminRoleSaved.
  ///
  /// In en, this message translates to:
  /// **'Role updated.'**
  String get adminRoleSaved;

  /// No description provided for @adminCannotChangeOwn.
  ///
  /// In en, this message translates to:
  /// **'You cannot change your own role.'**
  String get adminCannotChangeOwn;

  /// No description provided for @adminUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account with that email. Ask them to sign up first.'**
  String get adminUserNotFound;
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
