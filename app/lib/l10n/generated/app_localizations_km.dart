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
  String soldCount(int count) {
    return 'លក់បាន $count';
  }

  @override
  String get from => 'ចាប់ផ្ដើមពី';

  @override
  String get heroTitle => 'ទិញពេជ្រហ្គេម និងកាតឌីជីថល ភ្លាមៗ';

  @override
  String get heroSubtitle => 'បង់តាម ABA KHQR ទទួលកូដក្នុងរយៈពេលប៉ុន្មានវិនាទី';

  @override
  String get featured => 'ពេញនិយម';

  @override
  String get categories => 'ប្រភេទផលិតផល';

  @override
  String get allProducts => 'ផលិតផលទាំងអស់';

  @override
  String get noProducts => 'មិនទាន់មានផលិតផល';

  @override
  String get trustInstant => 'ដឹកជញ្ជូនស្វ័យប្រវត្តិ ២៤/៧';

  @override
  String get trustPayment => 'បង់ប្រាក់តាម ABA KHQR';

  @override
  String get trustSupport => 'ជំនួយការ ២៤/៧ តាម Telegram';

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
  String get manualWaiting => 'រង់ចាំបុគ្គលិកដំឡើង';

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
}
