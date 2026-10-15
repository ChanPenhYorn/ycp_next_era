// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppL10nKm extends AppL10n {
  AppL10nKm([String locale = 'km']) : super(locale);

  @override
  String get appTitle => 'សេឡា';

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
  String get noProducts => 'មិនទាន់មានផលិតផល';

  @override
  String get trustInstant => 'ដឹកជញ្ជូនស្វ័យប្រវត្តិ';

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
  String get quantity => 'ចំនួន';

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
  String get scanQr => 'ស្កេនដោយកម្មវិធីធនាគារណាមួយ';

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
  String get loginTitle => 'ចូលប្រើគណនីរបស់អ្នក';

  @override
  String get loginSubtitle =>
      'យើងផ្ញើកូដតែម្ដងទៅអ៊ីមែលរបស់អ្នក។ មិនត្រូវការពាក្យសម្ងាត់ទេ។';

  @override
  String get emailLabel => 'អាសយដ្ឋានអ៊ីមែល';

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
      'ការចូលតាមអ៊ីមែលមានកំណត់ក្នុងការសាកល្បង។ Google គ្មានកំណត់ទេ។';

  @override
  String get codeInvalid =>
      'កូដនេះមិនត្រឹមត្រូវ។ សូមពិនិត្យលេខ ៦ ខ្ទង់ ហើយព្យាយាមម្ដងទៀត។';

  @override
  String devCodeHint(String code) {
    return 'របៀបសាកល្បង: គ្មានអ៊ីមែលត្រូវបានផ្ញើទេ។ សូមបញ្ចូល $code។';
  }

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
}
