// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppL10nKm extends AppL10n {
  AppL10nKm([String locale = 'km']) : super(locale);

  @override
  String get appTitle => 'ចាន់ពេញ';

  @override
  String get searchHint => 'ស្វែងរកផលិតផល';

  @override
  String get all => 'ទាំងអស់';

  @override
  String get inStock => 'មានទំនិញ';

  @override
  String get outOfStock => 'អស់ទំនិញ';

  @override
  String get buyNow => 'ទិញឥឡូវ';

  @override
  String get signIn => 'ចូលប្រើ';

  @override
  String get signOut => 'ចាកចេញ';

  @override
  String get signUp => 'បង្កើតគណនី';

  @override
  String get account => 'គណនី';

  @override
  String get orders => 'ការបញ្ជាទិញ';

  @override
  String get wallet => 'កាបូបលុយ';

  @override
  String get loading => 'កំពុងផ្ទុក...';

  @override
  String get retry => 'ព្យាយាមម្ដងទៀត';

  @override
  String get instant => 'ដឹកភ្លាមៗ';

  @override
  String soldCount(String count) {
    return 'លក់បាន $count';
  }

  @override
  String get from => 'ចាប់ផ្ដើមពី';

  @override
  String get featured => 'ពេញនិយម';

  @override
  String get categories => 'ប្រភេទផលិតផល';

  @override
  String get allProducts => 'ផលិតផលទាំងអស់';

  @override
  String get searchNoResults =>
      'គ្មានហ្គេមត្រូវនឹងការស្វែងរកនេះទេ។ សាកឈ្មោះផ្សេង។';

  @override
  String get clearSearch => 'លុបការស្វែងរក';

  @override
  String searchActive(String term) {
    return 'ការស្វែងរក៖ $term';
  }

  @override
  String get noProducts => 'មិនទាន់មានផលិតផល';

  @override
  String get trustInstant => 'ដឹកជញ្ជូនស្វ័យប្រវត្តិ';

  @override
  String get heroTitle => 'បញ្ចូលទឹកប្រាក់ហ្គេមក្នុងរយៈពេលពីរបីវិនាទី';

  @override
  String get heroSubtitle =>
      'បញ្ចូលទឹកប្រាក់ហ្គេម និងកាតកាដូ។ បង់ប្រាក់តាម ABA KHQR ហើយទទួលការបញ្ជាទិញដោយស្វ័យប្រវត្តិ។';

  @override
  String get heroCta => 'មើលហ្គេម';

  @override
  String get trustPayment => 'បង់ប្រាក់តាម ABA KHQR';

  @override
  String get trustSupport => 'ជំនួយតាម Telegram';

  @override
  String get description => 'បរិយាយ';

  @override
  String get deliveryTime => 'ពេលដឹកជញ្ជូន';

  @override
  String get deliveryInstant => 'ភ្លាមៗ';

  @override
  String get deliveryManual => 'ដោយដៃ ក្នុងរយៈពេល ១៥ នាទី';

  @override
  String get showMore => 'បង្ហាញបន្ថែម';

  @override
  String get showLess => 'បង្ហាញតិច';

  @override
  String get quantity => 'ចំនួន';

  @override
  String get remove => 'លុប';

  @override
  String get cancel => 'បោះបង់';

  @override
  String get addToCart => 'ដាក់ក្នុងកន្ត្រក';

  @override
  String get requiredInfo => 'ព័ត៌មានត្រូវការ';

  @override
  String get reviews => 'មតិយោបល់';

  @override
  String get noReviews => 'មិនទាន់មានមតិយោបល់';

  @override
  String get checkout => 'ទូទាត់ប្រាក់';

  @override
  String get cart => 'កន្ត្រក';

  @override
  String get cartEmpty => 'កន្ត្រករបស់អ្នកទទេ';

  @override
  String get contactEmail => 'អ៊ីមែល';

  @override
  String get contactTelegram => 'Telegram';

  @override
  String get note => 'កំណត់សម្គាល់';

  @override
  String get orderSummary => 'សេចក្ដីសង្ខេប';

  @override
  String get subtotal => 'សរុបរង';

  @override
  String get discount => 'បញ្ចុះតម្លៃ';

  @override
  String get total => 'សរុប';

  @override
  String get coupon => 'កូដបញ្ចុះតម្លៃ';

  @override
  String get apply => 'អនុវត្ត';

  @override
  String get couponInvalid => 'កូដបញ្ចុះតម្លៃមិនត្រឹមត្រូវ';

  @override
  String get payWithKhqr => 'បង់តាម ABA KHQR';

  @override
  String get payWithWallet => 'បង់ដោយកាបូបលុយ';

  @override
  String get paymentMethod => 'វិធីបង់ប្រាក់';

  @override
  String get scanQr => 'ស្កេនដោយកម្មវិធីធនាគារណាមួយ';

  @override
  String get payByCard => 'បង់ដោយកាត';

  @override
  String get payByCardSubtitle => 'Visa, Mastercard · Dodo';

  @override
  String get cardSheetTitle => 'ការបង់ប្រាក់ដោយកាត';

  @override
  String get cardSheetIntro =>
      'បញ្ចប់នៅទំព័រទូទាត់សុវត្ថិភាពរបស់ Dodo។ សូមទុកផ្ទាំងនេះបើកទុក វានឹងធ្វើបច្ចុប្បន្នភាពដោយខ្លួនឯងពេលការទូទាត់ចូល។';

  @override
  String get cardOpenCheckout => 'បើកទំព័រទូទាត់សុវត្ថិភាព';

  @override
  String get cardWaiting => 'កំពុងរង់ចាំការទូទាត់…';

  @override
  String get cardPaid => 'បានទទួលប្រាក់ហើយ។ កំពុងបើកការបញ្ជាទិញរបស់អ្នក…';

  @override
  String get cardDeclined =>
      'ការទូទាត់ដោយកាតមិនបានជោគជ័យទេ។ សូមព្យាយាមម្ដងទៀត ឬជ្រើសវិធីផ្សេង។';

  @override
  String get cardExpired =>
      'ការទូទាត់នេះផុតកំណត់ហើយ។ សូមចាប់ផ្ដើមការបញ្ជាទិញថ្មី។';

  @override
  String get cardNotConfigured =>
      'ការបង់ប្រាក់ដោយកាតមិនទាន់បើកនៅឡើយទេ។ សូមប្រើវិធីផ្សេង។';

  @override
  String get cardOpenFailed =>
      'មិនអាចបើកទំព័រទូទាត់បានទេ។ សូមពិនិត្យកម្មវិធីទប់ស្កាត់ផ្ទាំងលេចឡើងរបស់កម្មវិធីរុករក ហើយព្យាយាមម្ដងទៀត។';

  @override
  String get openAbaMobile => 'បើក ABA Mobile';

  @override
  String get waitingPayment => 'កំពុងរង់ចាំការទូទាត់...';

  @override
  String get khqrExpired => 'QR នេះផុតកំណត់ហើយ';

  @override
  String get newQr => 'បង្កើត QR ថ្មី';

  @override
  String get insufficientBalance => 'សមតុល្យកាបូបលុយមិនគ្រប់គ្រាន់';

  @override
  String get orderNo => 'លេខការបញ្ជាទិញ';

  @override
  String get status => 'ស្ថានភាព';

  @override
  String get statusPending => 'រង់ចាំទូទាត់';

  @override
  String get statusPaid => 'បានទូទាត់';

  @override
  String get statusDelivering => 'កំពុងដឹកជញ្ជូន';

  @override
  String get statusDelivered => 'បានដឹកជញ្ជូន';

  @override
  String get statusFailed => 'បរាជ័យ';

  @override
  String get statusRefunded => 'បានសងវិញ';

  @override
  String get statusExpired => 'ផុតកំណត់';

  @override
  String get yourCodes => 'កូដរបស់អ្នក';

  @override
  String get manualWaiting => 'កំពុងរង់ចាំយើងពិនិត្យការផ្ទេរប្រាក់';

  @override
  String get orderEmpty => 'មិនទាន់មានការបញ្ជាទិញ';

  @override
  String get orderPaidSuccess => 'ទទួលប្រាក់រួចរាល់';

  @override
  String get about => 'អំពីយើង';

  @override
  String get aboutText =>
      'ផ្តល់សេវាកម្មផលិតផលឌីជីថល និងកាតហ្គេម ក្នុងតម្លៃសមរម្យ ដឹកភ្លាមៗ។';

  @override
  String get quickLinks => 'តំណរហ័ស';

  @override
  String get help => 'ជំនួយ';

  @override
  String get contact => 'ទំនាក់ទំនង';

  @override
  String get weAccept => 'យើងទទួល';

  @override
  String get rights => 'រក្សាសិទ្ធិគ្រប់បែបយ៉ាង';

  @override
  String get loginTitle => 'សូមស្វាគមន៍ត្រឡប់មកវិញ';

  @override
  String get loginSubtitle =>
      'ចូលប្រើដោយ Google ឬអ៊ីមែល និងពាក្យសម្ងាត់របស់អ្នក។';

  @override
  String get emailLabel => 'អាសយដ្ឋានអ៊ីមែល';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get sendCode => 'ផ្ញើកូដ';

  @override
  String get otpLabel => 'កូដ ៦ ខ្ទង់';

  @override
  String get verify => 'ផ្ទៀងផ្ទាត់ និងបន្ត';

  @override
  String codeSent(String email) {
    return 'បានផ្ញើកូដទៅ $email';
  }

  @override
  String get somethingWentWrong => 'មានបញ្ហា។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String get itemUnavailable =>
      'ទំនិញមួយចំនួនលែងមានលក់ទៀតទេ។ យើងបានដកវាចេញពីកន្ត្រករបស់អ្នក។';

  @override
  String get guestMustSignIn => 'សូមចូលប្រើជាមុនសិន';

  @override
  String get walletTitle => 'កាបូបលុយ';

  @override
  String get walletBalance => 'សមតុល្យ';

  @override
  String get walletTopup => 'បញ្ចូលលុយ';

  @override
  String get walletAmount => 'ចំនួនទឹកប្រាក់';

  @override
  String get walletHistory => 'ប្រតិបត្តិការ';

  @override
  String get walletEmpty => 'មិនទាន់មានប្រតិបត្តិការ';

  @override
  String get walletTopupNote => 'លុយចូលភ្លាមៗ បន្ទាប់ពីទូទាត់ KHQR ជោគជ័យ។';

  @override
  String get walletCredited => 'បញ្ចូលលុយរួចរាល់';

  @override
  String get walletTopupFailed => 'ការបញ្ចូលលុយមិនបានសម្រេច';

  @override
  String walletLimits(String min, String max) {
    return 'ចន្លោះពី $min ដល់ $max';
  }

  @override
  String walletSpent(Object orderNo) {
    return 'ការបញ្ជាទិញ $orderNo';
  }

  @override
  String get writeReview => 'សរសេរមតិយោបល់';

  @override
  String get reviewRating => 'ពិន្ទុរបស់អ្នក';

  @override
  String get reviewBody => 'ប្រាប់អ្នកទិញផ្សេងទៀតពីបទពិសោធន៍របស់អ្នក';

  @override
  String get reviewSubmit => 'ផ្ញើមតិយោបល់';

  @override
  String get reviewPending =>
      'អរគុណ។ មតិយោបល់នឹងបង្ហាញបន្ទាប់ពីបុគ្គលិកអនុម័ត។';

  @override
  String get reviewThanks => 'អរគុណសម្រាប់មតិយោបល់';

  @override
  String get reviewFailed => 'មិនអាចផ្ញើមតិយោបល់បានទេ';

  @override
  String get notDeliveredYet => 'មិនទាន់ដឹកជញ្ជូន';

  @override
  String get accountTitle => 'គណនី';

  @override
  String get accountEmail => 'ចូលប្រើជា';

  @override
  String get coins => 'កាក់';

  @override
  String get connectTelegram => 'ភ្ជាប់ Telegram';

  @override
  String get telegramConnected => 'បានភ្ជាប់ Telegram';

  @override
  String get telegramHint =>
      'ទទួលសារភ្លាមៗ នៅពេលការបញ្ជាទិញរួចរាល់ និងមើលកូដក្នុង Telegram។';

  @override
  String get telegramUnlinkHint =>
      'ដើម្បីផ្តាច់ សូមផ្ញើ /unlink ក្នុងការសន្ទនា។';

  @override
  String get telegramCodeHint => 'ផ្ញើកូដនេះទៅ bot ដើម្បីភ្ជាប់គណនី';

  @override
  String get telegramWait => 'កំពុងរង់ចាំការផ្ញើកូដ...';

  @override
  String get copyCode => 'ចម្លងកូដ';

  @override
  String get copied => 'បានចម្លង';

  @override
  String get openTelegram => 'បើក Telegram';

  @override
  String get telegramRefresh => 'ខ្ញុំបានផ្ញើរួច';

  @override
  String get telegramDisconnect => 'ផ្ដាច់';

  @override
  String get telegramLinkFailed =>
      'មិនអាចចាប់ផ្ដើមភ្ជាប់បានទេ។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String get invalidEmail =>
      'អ៊ីមែលនេះមិនត្រឹមត្រូវទេ។ សូមពិនិត្យមើលថាមានសញ្ញា @ ឬអត់។';

  @override
  String get continueWithGoogle => 'បន្តដោយ Google';

  @override
  String get orDivider => 'ឬ';

  @override
  String otpSentTo(Object email) {
    return 'យើងបានផ្ញើកូដ ៦ ខ្ទង់ទៅ $email';
  }

  @override
  String get useDifferentEmail => 'ប្រើអ៊ីមែលផ្សេង';

  @override
  String get emailRateLimited =>
      'ផ្ញើអ៊ីមែលច្រើនពេក។ សូមព្យាយាមម្ដងទៀត ឬប្រើ Google។';

  @override
  String get providerNotEnabled => 'វិធីចូលនេះមិនទាន់បើកនៅឡើយទេ។';

  @override
  String get emailOnlyNote =>
      'ការចូលតាមអ៊ីមែលមានកំណត់ក្នុងពេលសាកល្បង mailer។ Google គ្មានកំណត់ទេ។';

  @override
  String get codeInvalid =>
      'កូដនេះមិនត្រឹមត្រូវ។ សូមពិនិត្យលេខ ៦ ខ្ទង់ ហើយព្យាយាមម្ដងទៀត។';

  @override
  String devCodeHint(String code) {
    return 'របៀបសាកល្បង: គ្មានអ៊ីមែលត្រូវបានផ្ញើទេ។ សូមបញ្ចូល $code។';
  }

  @override
  String get authTabSignIn => 'ចូលប្រើ';

  @override
  String get authTabRegister => 'បង្កើតគណនី';

  @override
  String get registerTitle => 'បង្កើតគណនីរបស់អ្នក';

  @override
  String get registerSubtitle =>
      'គណនីតែមួយសម្រាប់ការបញ្ជាទិញ សមតុល្យកាបូប និងកូដផ្តល់ជូន។';

  @override
  String get nameLabel => 'ឈ្មោះពេញ';

  @override
  String get passwordLabel => 'ពាក្យសម្ងាត់';

  @override
  String get confirmPasswordLabel => 'បញ្ជាក់ពាក្យសម្ងាត់';

  @override
  String get forgotPassword => 'ភ្លេចពាក្យសម្ងាត់?';

  @override
  String noAccountYet(String brand) {
    return 'ថ្មីនៅ $brand?';
  }

  @override
  String get haveAccountAlready => 'មានគណនីរួចហើយ?';

  @override
  String get orContinueWithEmail => 'ឬបន្តដោយអ៊ីមែល';

  @override
  String get signInWithCode => 'ផ្ញើកូដឲ្យខ្ញុំជំនួសវិញ';

  @override
  String get usePasswordInstead => 'ប្រើពាក្យសម្ងាត់ជំនួសវិញ';

  @override
  String get codeSignInTitle => 'ចូលប្រើដោយកូដ';

  @override
  String get codeSignInSubtitle =>
      'មិនត្រូវការពាក្យសម្ងាត់ទេ។ យើងផ្ញើលេខ ៦ ខ្ទង់តាមអ៊ីមែល។';

  @override
  String get resendCode => 'ផ្ញើកូដថ្មី';

  @override
  String get confirmEmailTitle => 'បញ្ជាក់អ៊ីមែលរបស់អ្នក';

  @override
  String confirmEmailBody(String email) {
    return 'យើងបានផ្ញើលេខ ៦ ខ្ទង់ទៅ $email។ សូមបញ្ចូលដើម្បីបើកគណនី។';
  }

  @override
  String get confirmAndContinue => 'បញ្ជាក់ និងបន្ត';

  @override
  String get resetTitle => 'កំណត់ពាក្យសម្ងាត់ឡើងវិញ';

  @override
  String get resetSubtitle =>
      'យើងផ្ញើលេខ ៦ ខ្ទង់ បន្ទាប់មកអ្នកជ្រើសរើសពាក្យសម្ងាត់ថ្មី។';

  @override
  String get sendResetCode => 'ផ្ញើកូដឲ្យខ្ញុំ';

  @override
  String get newPasswordLabel => 'ពាក្យសម្ងាត់ថ្មី';

  @override
  String get savePassword => 'រក្សាទុក និងចូលប្រើ';

  @override
  String passwordRuleTooShort(String min) {
    return 'ប្រើយ៉ាងតិច $min តួអក្សរ។';
  }

  @override
  String get passwordRuleNeedsLower => 'បន្ថែមអក្សរតូច។';

  @override
  String get passwordRuleNeedsUpper => 'បន្ថែមអក្សរធំ។';

  @override
  String get passwordRuleNeedsDigit => 'បន្ថែមលេខ។';

  @override
  String get passwordMismatch => 'ពាក្យសម្ងាត់ទាំងពីរមិនដូចគ្នាទេ។';

  @override
  String get passwordTooWeak => 'ពាក្យសម្ងាត់នេះខ្សោយពេក។ សូមធ្វើឲ្យវែងជាងនេះ។';

  @override
  String get passwordStrengthWeak => 'ខ្សោយ';

  @override
  String get passwordStrengthFair => 'មធ្យម';

  @override
  String get passwordStrengthStrong => 'ខ្លាំង';

  @override
  String get referralToggle => 'មានកូដណែនាំ?';

  @override
  String get referralCodeLabel => 'កូដណែនាំ (មិនចាំបាច់)';

  @override
  String get referralHint => '៨ តួអក្សរ ឬលេខ';

  @override
  String get referralInvalid => 'កូដណែនាំមាន ៨ តួអក្សរ។';

  @override
  String get referralFailed =>
      'បង្កើតគណនីរួចរាល់ ប៉ុន្តែកូដណែនាំមិនត្រូវបានប្រើទេ។';

  @override
  String get termsAgree =>
      'ខ្ញុំយល់ព្រមនឹងលក្ខខណ្ឌប្រើប្រាស់ និងគោលការណ៍ឯកជនភាព។';

  @override
  String get termsRequired => 'សូមយល់ព្រមនឹងលក្ខខណ្ឌជាមុន។';

  @override
  String get nameRequired => 'សូមបញ្ចូលឈ្មោះរបស់អ្នក។';

  @override
  String get passwordRequired => 'សូមបញ្ចូលពាក្យសម្ងាត់របស់អ្នក។';

  @override
  String get codeRequired => 'សូមបញ្ចូលកូដ ៦ ខ្ទង់ពីអ៊ីមែល។';

  @override
  String get emailInUse => 'អ៊ីមែលនេះមានគណនីរួចហើយ។ សូមព្យាយាមចូលប្រើវិញ។';

  @override
  String get wrongCredentials => 'អ៊ីមែល ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវទេ។';

  @override
  String get emailNotConfirmed =>
      'សូមបញ្ជាក់អ៊ីមែលជាមុន — យើងបានផ្ញើកូដទៅអ្នក។';

  @override
  String get codeExpired => 'កូដនេះផុតកំណត់ហើយ។ សូមសុំកូដថ្មី។';

  @override
  String get paywayNotConfigured =>
      'ការទូទាត់ KHQR មិនទាន់បើកសម្រាប់គម្រោងនេះនៅឡើយទេ។ សូមប្រើវិធីផ្សេង។';

  @override
  String get paywayRejected =>
      'ABA មិនទទួលយកការទូទាត់នេះទេ។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String get navHome => 'ទំព័រដើម';

  @override
  String get navGames => 'ហ្គេម';

  @override
  String get searchGames => 'ស្វែងរកហ្គេម...';

  @override
  String get popularGames => 'ហ្គេមពេញនិយម';

  @override
  String get buyAgain => 'ទិញម្តងទៀត';

  @override
  String get trendingNow => 'កំពុងពេញនិយម';

  @override
  String get promotions => 'ប្រូម៉ូសិន';

  @override
  String get promotionsSubtitle => 'ការបញ្ចុះតម្លៃពិតលើកញ្ចប់មួយចំនួន';

  @override
  String get howItWorks => 'របៀបទិញ';

  @override
  String get howStep1Title => 'ជ្រើសរើសហ្គេម និងកញ្ចប់';

  @override
  String get howStep1Body => 'រើសហ្គេម បន្ទាប់មករើសកញ្ចប់ដែលអ្នកចង់បាន។';

  @override
  String get howStep2Title => 'បញ្ចូល Player ID';

  @override
  String get howStep2Body =>
      'បញ្ចូល ID ឲ្យដូចដែលបង្ហាញក្នុងហ្គេម។ មិនត្រូវបញ្ចូលពាក្យសម្ងាត់ទេ។';

  @override
  String get howStep3Title => 'ទូទាត់ និងតាមដានការបញ្ចូល';

  @override
  String get howStep3Body =>
      'ទូទាត់តាម ABA KHQR រួចតាមដានការបញ្ជាទិញរហូតដល់ទទួលបាន។';

  @override
  String get trustAndSupport => 'ទំនុកចិត្ត និងជំនួយ';

  @override
  String get trustDeliveryTitle => 'ការផ្តល់ជូន';

  @override
  String get trustDeliveryBody =>
      'កូដ និងការបញ្ចូលពេជ្រ ផ្តល់ជូនដោយស្វ័យប្រវត្តិ បន្ទាប់ពីទូទាត់ប្រាក់រួច។ ការបញ្ចូលតាមអ្នកផ្គត់ផ្គង់អាចចំណាយពេលពីរបីនាទី។';

  @override
  String get trustPaymentTitle => 'ការទូទាត់';

  @override
  String get trustPaymentBody =>
      'ABA ផ្ទៀងផ្ទាត់ការទូទាត់នៅលើម៉ាស៊ីនមេ។ រូបថតអេក្រង់មិនត្រូវបានចាត់ទុកជាភស្តុតាងនៃការទូទាត់ទេ។';

  @override
  String get trustRefundTitle => 'ការសងប្រាក់វិញ';

  @override
  String get trustRefundBody =>
      'បើមិនអាចផ្តល់ជូនបាន ទឹកប្រាក់នឹងត្រឡប់ទៅកាបូបលុយរបស់អ្នកវិញ។ ការសងប្រាក់ទៅគណនីធនាគារ ត្រូវទាក់ទងជំនួយ។';

  @override
  String get trustSupportTitle => 'ជំនួយ';

  @override
  String get trustSupportBody => 'ផ្ញើលេខការបញ្ជាទិញមកយើង យើងនឹងបន្តជួយ។';

  @override
  String get contactSupport => 'ទាក់ទងជំនួយ';

  @override
  String get qtyOnePerOrder =>
      'ការបញ្ចូលនេះផ្តល់ជូនម្ដងមួយ។ ចំនួនត្រូវបានកែត្រឡប់ទៅ ១ វិញ សូមចុចទិញម្ដងទៀត។';

  @override
  String get tooManyLines =>
      'ការបញ្ជាទិញនេះលើសពី ២០ មុខទំនិញ។ សូមបំបែកជាការបញ្ជាទិញពីរ។';

  @override
  String get accountBlocked =>
      'គណនីរបស់អ្នកត្រូវបានផ្អាកជាបណ្ដោះអាសន្ន។ សូមទាក់ទងជំនួយ យើងនឹងដោះស្រាយជូន។';

  @override
  String get paymentUnreachable =>
      'មិនអាចភ្ជាប់ទៅសេវាទូទាត់បានទេ។ ការបញ្ជាទិញរបស់អ្នកត្រូវបានរក្សាទុក សូមព្យាយាមម្ដងទៀត ឬបង់តាមមធ្យោបាយផ្សេង។';

  @override
  String get orderNotPayable =>
      'ការបញ្ជាទិញនេះមិនអាចទូទាត់បានទៀតទេ។ វាប្រហែលជាបានបង់រួច ឬផុតកំណត់ - សូមពិនិត្យស្ថានភាពខាងក្រោម។';

  @override
  String get statusRefundPending => 'កំពុងរង់ចាំការសងប្រាក់វិញ';

  @override
  String get fieldHelpTooltip => 'របៀបរកវា';

  @override
  String get fieldHelpTitle => 'រកវានៅឯណា?';

  @override
  String get fieldHelpExample => 'ឧទាហរណ៍';

  @override
  String get fieldHelpUserid =>
      'បើកហ្គេម រួចចុចលើឈ្មោះ ឬរូបរបស់អ្នក។ លេខ ID គឺលេខដែលនៅក្រោមឈ្មោះរបស់អ្នក ហើយវាមិនផ្លាស់ប្តូរទេ។';

  @override
  String get fieldHelpZone =>
      'Server ឬ Zone ជាធម្មតាបង្ហាញនៅជិតឈ្មោះក្នុងហ្គេម ដូចជាក្នុងវង់ក្រចក (2001)។';

  @override
  String get fieldHelpGeneric =>
      'បើកហ្គេម ឬសេវានោះ រួចរកព័ត៌មាននេះនៅក្នុងទំព័រគណនី ឬប្រវត្តិរូបរបស់អ្នក។';

  @override
  String get fieldHelpWarning =>
      'សូមពិនិត្យឲ្យបានត្រឹមត្រូវមុនពេលបង់ប្រាក់។ ការបញ្ចូលទៅ ID ខុស ជាធម្មតាមិនអាចដកវិញបានទេ។ បើមិនជោគជ័យ ទឹកប្រាក់ត្រឡប់ទៅកាបូបលុយរបស់អ្នកវិញ។';

  @override
  String get fieldRequired => 'ត្រូវបំពេញ';

  @override
  String get fieldWrongFormat => 'ទម្រង់មិនត្រឹមត្រូវ';

  @override
  String get close => 'បិទ';

  @override
  String get payByTransfer => 'បង់តាមធនាគារ';

  @override
  String get transferIntro =>
      'សូមបង់ចំនួនឲ្យត្រូវខាងក្រោម រួចប្រាប់យើង។ យើងពិនិត្យការផ្ទេរប្រាក់នីមួយៗដោយដៃ ហើយការបញ្ជាទិញរបស់អ្នកនៅបន្តរហូតដល់ផ្ទៀងផ្ទាត់រួច។';

  @override
  String get transferTo => 'ផ្ទេរទៅ';

  @override
  String get transferAccount => 'លេខគណនី';

  @override
  String get manualRateLimited =>
      'អ្នកបានសួរច្រើនដងហើយ។ សូមផ្ញើលេខការបញ្ជាទិញមកយើង យើងនឹងពិនិត្យផ្ទាល់។';

  @override
  String get transferAmount => 'ចំនួនទឹកប្រាក់';

  @override
  String get transferRemark => 'សរសេរនេះក្នុងចំណាំ';

  @override
  String get transferRemarkHint => 'ដើម្បីយើងអាចផ្គូផ្គងការទូទាត់របស់អ្នក';

  @override
  String get iHavePaid => 'ខ្ញុំបានបង់រួច — សូមពិនិត្យ';

  @override
  String get manualRequested =>
      'សូមអរគុណ។ ការទូទាត់របស់អ្នកកំពុងរង់ចាំការពិនិត្យដោយដៃ។ អ្នកអាចបិទទំព័រនេះបាន ការបញ្ជាទិញនឹងផ្លាស់ប្ដូរពេលផ្ទៀងផ្ទាត់រួច។';

  @override
  String get manualWaitingBody =>
      'បើយូរពេក សូមទាក់ទងជំនួយ ដោយប្រាប់លេខការបញ្ជាទិញរបស់អ្នក។';

  @override
  String get adminManualPayments => 'ការផ្ទេរប្រាក់ត្រូវពិនិត្យ';

  @override
  String get adminManualQueue => 'ការបញ្ជាទិញដែលអ្នកទិញបានស្នើបង់តាមធនាគារ។';

  @override
  String get adminNoManualRequests =>
      'គ្មានអ្វីរង់ចាំទេ។ គ្មានអ្នកទិញណាបានស្នើបង់តាមការផ្ទេរប្រាក់។';

  @override
  String get adminAmountReceived => 'ទឹកប្រាក់ទទួលបាន';

  @override
  String get adminAmountReceivedHint => 'សរសេរតាមដែលធនាគារបង្ហាញ ជាដុល្លារ';

  @override
  String get adminAbaRef => 'លេខយោង ABA';

  @override
  String get adminAbaRefHint =>
      'ពីកម្មវិធីធនាគារ — លេខមួយប្រើសម្រាប់ការបញ្ជាទិញតែមួយ';

  @override
  String get adminConfirmPayment => 'បញ្ជាក់ការទូទាត់';

  @override
  String get adminDismissRequest => 'បោះបង់សំណើ';

  @override
  String get adminDismissReason => 'ហេតុអ្វីបោះបង់?';

  @override
  String get adminExpiresIn => 'អាចបង់បានដល់';

  @override
  String get adminUnderpaid =>
      'ចំនួននេះតិចជាងតម្លៃការបញ្ជាទិញ។ គ្មានអ្វីត្រូវបានបញ្ជាក់ទេ។';

  @override
  String get adminReferenceUsed =>
      'លេខយោង ABA នេះបានបញ្ជាក់ការបញ្ជាទិញផ្សេងរួចហើយ។';

  @override
  String get adminExpired =>
      'ការបញ្ជាទិញនេះផុតកំណត់ហើយ។ សូមដោះស្រាយទឹកប្រាក់ជាការសងប្រាក់វិញក្រៅប្រព័ន្ធ។';

  @override
  String get adminOnly => 'ទំព័រនេះសម្រាប់គណនីបុគ្គលិកប៉ុណ្ណោះ។';

  @override
  String get orderNumber => 'លេខការបញ្ជាទិញ';

  @override
  String get adminTitle => 'បុគ្គលិក';

  @override
  String get adminOverview => 'ទូទៅ';

  @override
  String get adminOrdersTitle => 'ការបញ្ជាទិញ';

  @override
  String get adminRefundsTitle => 'ការសងប្រាក់វិញ';

  @override
  String get adminSupportTitle => 'ជំនួយ';

  @override
  String get adminNeedsAttention => 'អ្វីដែលត្រូវធ្វើ';

  @override
  String get adminMoney => 'ទឹកប្រាក់';

  @override
  String get adminPendingOrders => 'ការបញ្ជាទិញរង់ចាំ';

  @override
  String get adminSupportOpen => 'សំបុត្រដែលបើក';

  @override
  String get adminManualWaiting => 'បន្ទាត់រង់ចាំបញ្ជូនដោយដៃ';

  @override
  String get adminReceivedToday => 'ទទួលថ្ងៃនេះ';

  @override
  String get adminReceived7d => 'ទទួល ៧ ថ្ងៃចុងក្រោយ';

  @override
  String get adminReceived30d => 'ទទួល ៣០ ថ្ងៃចុងក្រោយ';

  @override
  String get adminWalletSpent30d => 'ចំណាយពីកាបូប ៣០ ថ្ងៃចុងក្រោយ';

  @override
  String get adminRefunded30d => 'សងវិញ ៣០ ថ្ងៃចុងក្រោយ';

  @override
  String get adminReceivedNote =>
      'ទឹកប្រាក់ដែលបានចូលធនាគារ។ ការសងវិញបង្ហាញក្បែរវា មិនកាត់ចេញទេ ហើយការចំណាយពីកាបូបមិនមែនជាទឹកប្រាក់ថ្មីទេ។';

  @override
  String get adminCountsNote => 'ជាចំនួនជួរពិត មិនមែនការប៉ាន់ស្មានទេ។';

  @override
  String get adminSearchOrder => 'លេខការបញ្ជាទិញ';

  @override
  String get adminFilterAll => 'ទាំងអស់';

  @override
  String get adminNoOrders => 'គ្មានការបញ្ជាទិញត្រូវគ្នាទេ។';

  @override
  String get adminItemsTitle => 'ទំនិញ';

  @override
  String get adminCustomerNote => 'កំណត់សម្គាល់អ្នកទិញ';

  @override
  String get adminBuyerFields => 'ព័ត៌មានអ្នកទិញ';

  @override
  String get adminTimeline => 'ប្រវត្តិ';

  @override
  String get adminPaymentsTitle => 'ការទូទាត់';

  @override
  String get adminBuyerTitle => 'អ្នកទិញ';

  @override
  String get adminKind => 'ប្រភេទ';

  @override
  String get adminKindPurchase => 'ការទិញ';

  @override
  String get adminKindWalletTopup => 'បញ្ចូលកាបូប';

  @override
  String get adminCreatedAt => 'បង្កើត';

  @override
  String get adminPaidAt => 'បានបង់';

  @override
  String get adminAgreeRefund => 'យល់ព្រមសងប្រាក់វិញ';

  @override
  String get adminRefundReason => 'ហេតុអ្វីសងប្រាក់វិញ?';

  @override
  String get adminMarkRefunded => 'កត់ត្រាការសងប្រាក់វិញ';

  @override
  String get adminRefundReference => 'លេខយោងធនាគារ';

  @override
  String get adminRefundReferenceHint =>
      'ស្រេចចិត្ត ប៉ុន្តែវាជាអ្វីដែលធ្វើឲ្យការសងប្រាក់វិញអាចផ្ទៀងផ្ទាត់បាន';

  @override
  String get adminRefundRecorded =>
      'បានកត់ត្រា។ ទំព័រនេះមិនផ្លាស់ប្ដូរទឹកប្រាក់ទេ — ការផ្ទេរត្រូវធ្វើនៅធនាគារ។';

  @override
  String get adminRefundNote =>
      'ការកត់ត្រាសងប្រាក់វិញនៅទីនេះមិនផ្លាស់ប្ដូរទឹកប្រាក់ទេ។ សូមផ្ទេរនៅធនាគារជាមុន រួចទើបកត់ត្រា។';

  @override
  String get adminSummary => 'សេចក្ដីសង្ខេប';

  @override
  String get adminRefundsEmpty => 'គ្មានការសងប្រាក់វិញរង់ចាំទេ។';

  @override
  String get adminResolveDelivered => 'សម្គាល់ថាបានបញ្ជូន';

  @override
  String get adminResolveFailed => 'សម្គាល់ថាបរាជ័យ';

  @override
  String get adminTicketOpen => 'បើក';

  @override
  String get adminTicketInProgress => 'កំពុងដោះស្រាយ';

  @override
  String get adminTicketResolved => 'បានដោះស្រាយ';

  @override
  String get adminTicketClosed => 'បានបិទ';

  @override
  String get adminPriorityLow => 'ទាប';

  @override
  String get adminPriorityNormal => 'ធម្មតា';

  @override
  String get adminPriorityHigh => 'ខ្ពស់';

  @override
  String get adminTicketContact => 'ទំនាក់ទំនង';

  @override
  String get adminTicketNote => 'កំណត់សម្គាល់ផ្ទៃក្នុង';

  @override
  String get adminTicketStart => 'ចាប់ផ្ដើម';

  @override
  String get adminTicketResolve => 'ដោះស្រាយ';

  @override
  String get adminTicketClose => 'បិទ';

  @override
  String get adminTicketOpenOrder => 'បើកការបញ្ជាទិញ';

  @override
  String get adminTicketsEmpty => 'គ្មានសំបុត្រទេ។';

  @override
  String get adminCatalogueTitle => 'បញ្ជីទំនិញ';

  @override
  String get adminCatalogueNote =>
      'ទំនិញដែលលាក់មិនបង្ហាញដល់អតិថិជនទេ។ តម្លៃមិនអាចទាបជាងតម្លៃដើមពីអ្នកផ្គត់ផ្គង់បានទេ។';

  @override
  String get adminCatalogueEmpty => 'មិនទាន់មានទំនិញទេ។';

  @override
  String get adminProductShown => 'បង្ហាញដល់អតិថិជន';

  @override
  String get adminProductHidden => 'បានលាក់';

  @override
  String get adminVariantPrice => 'តម្លៃលក់ (USD)';

  @override
  String get adminVariantPriceHint =>
      'ត្រូវធំជាងសូន្យ និងមិនទាបជាងតម្លៃដើមពីអ្នកផ្គត់ផ្គង់។';

  @override
  String get adminCostLabel => 'តម្លៃដើម';

  @override
  String get adminMarginLabel => 'ចំណេញ';

  @override
  String get adminPriceSaved => 'បានរក្សាទុកតម្លៃ។';

  @override
  String get adminPriceInvalid => 'បញ្ចូលតម្លៃធំជាងសូន្យ។';

  @override
  String get adminPriceBelowCost =>
      'តម្លៃទាបជាងតម្លៃដើមពីអ្នកផ្គត់ផ្គង់។ មិនបានរក្សាទុក។';

  @override
  String get adminQueueTitle => 'ជួរអ្នកផ្គត់ផ្គង់';

  @override
  String get adminQueueNote =>
      'បន្ទាត់ដែលអ្នកផ្គត់ផ្គង់មិនអាចបញ្ចប់បាន។ បន្ទាត់កំពុងព្យាយាមម្តងទៀតនឹងដោះស្រាយខ្លួនឯង; បន្ទាត់ដែលត្រូវការអ្នកបង្ហាញមុន។';

  @override
  String get adminQueueEmpty => 'គ្មានបន្ទាត់អ្នកផ្គត់ផ្គង់ណាជាប់ទេ។';

  @override
  String get adminQueueNeedsYou => 'ត្រូវការអ្នក';

  @override
  String get adminQueueRetrying => 'កំពុងព្យាយាមម្តងទៀត';

  @override
  String get adminQueueConfirmTitle => 'សម្គាល់បន្ទាត់នេះថាបានបញ្ជូន?';

  @override
  String get adminQueueConfirmBody =>
      'ធ្វើតែបន្ទាប់ពីអ្នកបានបញ្ជូនការបញ្ចូលដោយដៃប៉ុណ្ណោះ។ អតិថិជនមិនត្រូវបានសងប្រាក់វិញទេ។';

  @override
  String get adminQueueDelivered => 'បានសម្គាល់បន្ទាត់ថាបានបញ្ជូន។';

  @override
  String get adminSavePrice => 'រក្សាទុកតម្លៃ';

  @override
  String get adminStaffTitle => 'បុគ្គលិក និងតួនាទី';

  @override
  String get adminStaffNote =>
      'មានតែអ្នកគ្រប់គ្រងប៉ុណ្ណោះដែលឃើញទំព័រនេះ។ បុគ្គលិកប្រើអេក្រង់គ្រប់គ្រង; អ្នកគ្រប់គ្រងកំណត់តួនាទីផងដែរ។';

  @override
  String get adminStaffEmpty => 'គ្មានគណនីបុគ្គលិកទេ។';

  @override
  String get adminFindByEmail => 'ស្វែងរកគណនីតាមអ៊ីមែល';

  @override
  String get adminEmailLabel => 'អ៊ីមែល';

  @override
  String get adminFindButton => 'ស្វែងរក';

  @override
  String get adminRoleCustomer => 'អតិថិជន';

  @override
  String get adminRoleStaff => 'បុគ្គលិក';

  @override
  String get adminRoleAdmin => 'អ្នកគ្រប់គ្រង';

  @override
  String get adminSetRole => 'កំណត់តួនាទី';

  @override
  String get adminRoleSaved => 'បានធ្វើបច្ចុប្បន្នភាពតួនាទី។';

  @override
  String get adminConsole => 'កុងសូលបុគ្គលិក';

  @override
  String get adminExitToStore => 'ត្រឡប់ទៅហាង';

  @override
  String get adminCannotChangeOwn =>
      'អ្នកមិនអាចផ្លាស់ប្តូរតួនាទីរបស់ខ្លួនឯងបានទេ។';

  @override
  String get adminUserNotFound =>
      'គ្មានគណនីដែលមានអ៊ីមែលនេះទេ។ សូមស្នើឱ្យពួកគេចុះឈ្មោះជាមុន។';

  @override
  String get adminConfirmPaymentNote =>
      'ការនេះសម្គាល់ការបញ្ជាទិញថាបានទូទាត់ ហើយបញ្ជូនបន្ទាត់ទៅអ្នកផ្គត់ផ្គង់។ មិនអាចត្រឡប់វិញពីទំព័រនេះទេ។';

  @override
  String get adminDismissNote =>
      'ការនេះបោះបង់ការទាមទាររបស់អតិថិជន។ ការបញ្ជាទិញនៅតែមិនទាន់ទូទាត់។';

  @override
  String get adminSetRoleTitle => 'ប្ដូរតួនាទីនេះ?';

  @override
  String get adminSetRoleBody =>
      'ការផ្លាស់ប្ដូរមានប្រសិទ្ធភាពភ្លាមៗ។ កំណត់តួនាទីផ្សេងដើម្បីត្រឡប់វិញ។';

  @override
  String get adminResolveFailedTitle => 'សម្គាល់បន្ទាត់នេះថាបរាជ័យ?';

  @override
  String get adminResolveFailedBody =>
      'អតិថិជនមិនត្រូវបានសងប្រាក់វិញដោយការនេះទេ។ បន្ទាត់ដែលបរាជ័យត្រូវការការសម្រេចចិត្តសងប្រាក់ដោយឡែក។';

  @override
  String get adminTicketCloseTitle => 'បិទសំណើនេះ?';

  @override
  String get adminTicketCloseBody =>
      'វានឹងផ្លាស់ទៅស្ថានភាពបិទ ហើយចេញពីបញ្ជីការងារ។';

  @override
  String adminShowingCount(int count) {
    return 'បង្ហាញ $count ចុងក្រោយបំផុត។';
  }

  @override
  String get adminBannerTitle => 'រូបភាពបដា';

  @override
  String get adminBannerUrlLabel => 'តំណរូបភាព (ទទេ = ស្វែងរកតាម IGDB)';

  @override
  String get adminBannerHint => 'រូបភាពទទឹងល្អបំផុត៖ 16:9 ឬធំជាង។';

  @override
  String get adminBannerFind => 'ស្វែងរកបដា';

  @override
  String get adminBannerSaved => 'បានរក្សាទុកបដា។';

  @override
  String get adminBannerNone => 'រកមិនឃើញបដាដែលត្រូវគ្នាទេ។';

  @override
  String get adminBannerNotConfigured => 'ប្រភពរូបភាពបដាមិនបានកំណត់ទេ។';

  @override
  String get adminBannerFailed => 'មិនអាចផ្ទុកបដាបានទេ។';
}
