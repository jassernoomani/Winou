// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get tagline => 'ابحث عن الحيوانات الضائعة وساعد حيوانات الشارع';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get displayName => 'اسمك';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get noAccount => 'ليس لديك حساب؟ أنشئ حسابًا';

  @override
  String get haveAccount => 'لديك حساب؟ سجّل الدخول';

  @override
  String get required => 'مطلوب';

  @override
  String get invalidEmail => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get passwordTooShort => '8 أحرف على الأقل';

  @override
  String get errorNetwork => 'تعذّر الوصول إلى الخادم. تحقّق من اتصالك.';

  @override
  String get errorRateLimited => 'لقد نشرت كثيرًا مؤخرًا. حاول لاحقًا.';

  @override
  String get errorInvalidImage =>
      'تعذّرت قراءة هذه الصورة. استخدم صورة JPEG أو PNG أو WebP أو HEIC.';

  @override
  String get errorImageTooLarge => 'هذه الصورة كبيرة جدًا.';

  @override
  String get errorEmailTaken => 'هذا البريد الإلكتروني مسجّل بالفعل.';

  @override
  String get errorWrongCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorUnexpected => 'حدث خطأ ما.';

  @override
  String get retry => 'حاول مجددًا';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get change => 'تغيير';

  @override
  String get choose => 'اختيار';

  @override
  String get apply => 'تطبيق';

  @override
  String get speciesCat => 'قطّ';

  @override
  String get speciesDog => 'كلب';

  @override
  String get speciesOther => 'آخر';

  @override
  String get conditionHealthy => 'بصحة جيدة';

  @override
  String get conditionInjured => 'مصاب';

  @override
  String get conditionNeedsHelp => 'يحتاج إلى مساعدة';

  @override
  String get statusOpen => 'لا يزال ضائعًا';

  @override
  String get statusFound => 'عُثر عليه';

  @override
  String get statusClosed => 'مغلق';

  @override
  String get typeLost => 'حيوانات ضائعة';

  @override
  String get typeSighting => 'مشاهدة';

  @override
  String get typeStray => 'حيوان شارع';

  @override
  String get filters => 'التصفية';

  @override
  String get filterShow => 'عرض';

  @override
  String get filterSpecies => 'النوع';

  @override
  String get filterCondition => 'الحالة (المشاهدات)';

  @override
  String get filterPeriod => 'الفترة';

  @override
  String get periodAny => 'في أي وقت';

  @override
  String periodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get myActivity => 'نشاطي';

  @override
  String get myLocation => 'موقعي';

  @override
  String get reportLostPet => 'الإبلاغ عن حيوان ضائع';

  @override
  String get iSawAnAnimal => 'رأيت حيوانًا';

  @override
  String lostNamed(String name) {
    return '$name ضائع';
  }

  @override
  String sightingOf(String species) {
    return 'مشاهدة $species';
  }

  @override
  String strayOf(String species) {
    return '$species شارع';
  }

  @override
  String get photoHint =>
      'اقترب وأظهر الوجه: هذا يساعدنا على التعرّف على الحيوان.';

  @override
  String get condition => 'الحالة';

  @override
  String get isStray => 'هذا حيوان شارع';

  @override
  String get isStrayHelp => 'يعيش في الخارج وليس له مالك';

  @override
  String get noteOptional => 'ملاحظة (اختياري)';

  @override
  String get locating => 'جارٍ تحديد موقعك…';

  @override
  String get locationMissing => 'لا يوجد موقع بعد: اختره على الخريطة';

  @override
  String locationFromGps(int meters) {
    return 'موقعك الحالي (±$meters م)';
  }

  @override
  String get locationPicked => 'موقع مختار على الخريطة';

  @override
  String get postSighting => 'إرسال المشاهدة';

  @override
  String uploading(String progress) {
    return 'جارٍ رفع الصور $progress';
  }

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String get noAnimalTitle => 'لم يُعثر على حيوان';

  @override
  String get noAnimalBody =>
      'لم نجد قطًّا أو كلبًا في هذه الصورة. الأفضل صورة قريبة للرأس.';

  @override
  String get keepPhoto => 'الاحتفاظ بها';

  @override
  String get retakePhoto => 'إعادة التصوير';

  @override
  String get lostPhotosHint =>
      'أضف من 1 إلى 5 صور واضحة، ويُفضَّل أن تكون للوجه من زوايا مختلفة.';

  @override
  String get petName => 'اسم الحيوان';

  @override
  String get descriptionOptional => 'الوصف (اختياري)';

  @override
  String get descriptionHint => 'الطوق، العلامات، الطباع…';

  @override
  String get lastSeenAt => 'آخر مرة شوهد فيها';

  @override
  String get lastSeenWhere => 'أين شوهد آخر مرة؟';

  @override
  String get locationPrivacyNote =>
      'لا يرى الآخرون سوى منطقة بقطر 300 م تقريبًا حوله';

  @override
  String get publishReport => 'نشر البلاغ';

  @override
  String get pickLocationTitle => 'اختر المكان';

  @override
  String get pickLocationHint => 'انقر على الخريطة حيث كان الحيوان.';

  @override
  String get confirmLocation => 'استخدام هذا المكان';

  @override
  String get markFound => 'تمّ العثور عليه';

  @override
  String get closeReport => 'إغلاق البلاغ';

  @override
  String get reopenReport => 'إعادة الفتح (لا يزال ضائعًا)';

  @override
  String get deleteReportQuestion => 'حذف هذا البلاغ وصوره؟';

  @override
  String get deleteSightingQuestion => 'حذف هذه المشاهدة وصورها؟';

  @override
  String lastSeenOn(String date) {
    return 'آخر مشاهدة: $date';
  }

  @override
  String seenOn(String date) {
    return 'شوهد: $date';
  }

  @override
  String get approximateArea => 'منطقة تقريبية لحماية خصوصية المالك.';

  @override
  String get photoProcessing => 'جارٍ الفحص…';

  @override
  String get photoNoAnimal => 'لم يُعثر على حيوان';

  @override
  String get photoNotMatched => 'غير مستخدمة في المطابقة';

  @override
  String get photoFailed => 'فشلت المعالجة';

  @override
  String get tabMatches => 'التطابقات';

  @override
  String get tabMyLostPets => 'حيواناتي الضائعة';

  @override
  String get tabMySightings => 'مشاهداتي';

  @override
  String get noMatches =>
      'لا توجد تطابقات محتملة بعد. نفحص كل مشاهدة جديدة قريبة.';

  @override
  String get noLostReports => 'لم تبلّغ عن أي حيوان ضائع.';

  @override
  String get noSightings => 'لم تنشر أي مشاهدة.';

  @override
  String get possibleMatch => 'تطابق محتمل';

  @override
  String possibleMatchFor(String name) {
    return 'هل يمكن أن يكون $name؟';
  }

  @override
  String similarity(int percent) {
    return 'تشابه بنسبة $percent%';
  }

  @override
  String get yourPhoto => 'صورتك';

  @override
  String get sightingPhoto => 'المشاهدة';

  @override
  String get matchExplanation =>
      'وجد نموذجنا أن هذه الصور متشابهة. انظر جيدًا إلى العلامات والملامح قبل التواصل مع من رآه.';

  @override
  String get matchNotFound => 'هذا التطابق لم يعد موجودًا.';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get chooseFromGallery => 'من المعرض';

  @override
  String get timeNow => 'شوهد الآن';

  @override
  String timeFromPhoto(String date) {
    return 'شوهد $date (من الصورة)';
  }

  @override
  String get timeMissing => 'متى رأيته؟ حدّد الوقت';

  @override
  String get locationFromPhoto => 'الموقع من الصورة';

  @override
  String get locationNeeded => 'أين رأيته؟ اختر على الخريطة';

  @override
  String get missingPets => 'الحيوانات الضائعة';

  @override
  String get map => 'الخريطة';

  @override
  String get nearMe => 'بالقرب مني';

  @override
  String get everywhere => 'في كل مكان';

  @override
  String get allSpecies => 'الكل';

  @override
  String get noMissingPets => 'لا توجد حيوانات ضائعة مُبلَّغ عنها. خبر سار!';

  @override
  String get noMissingPetsNearby =>
      'لا توجد حيوانات ضائعة بالقرب منك. جرّب «في كل مكان».';

  @override
  String kmAway(String km) {
    return 'على بعد $km كم';
  }

  @override
  String get locationOffForNearby =>
      'فعّل تحديد الموقع لرؤية الحيوانات القريبة منك.';

  @override
  String matchNotification(String name) {
    return 'ربما رأى أحدهم $name.';
  }

  @override
  String get view => 'عرض';

  @override
  String get thatsMyPet => 'هذا حيواني';

  @override
  String get notMyPet => 'ليس حيواني';

  @override
  String get matchHidden => 'أُخفيت. لن تُقترح هذه المشاهدة مجددًا.';

  @override
  String get undo => 'تراجع';

  @override
  String matchConfirmedInfo(String name) {
    return 'تعرّفت على $name. تمّ إبلاغ الشخص الذي رآه.';
  }

  @override
  String get messageFinder => 'راسل من رآه';

  @override
  String get openConversation => 'فتح المحادثة';

  @override
  String gotPetBack(String name) {
    return 'استعدت $name';
  }

  @override
  String gotPetBackQuestion(String name) {
    return 'هل عاد $name إلى البيت؟ سيُغلق هذا الملف: لا مزيد من التطابقات، ويختفي البلاغ من الخريطة. يمكنك إعادة فتحه لاحقًا.';
  }

  @override
  String get closeCase => 'إغلاق الملف';

  @override
  String petBackHome(String name) {
    return 'عاد $name إلى البيت. أُغلق الملف.';
  }

  @override
  String get matchStatusConfirmed => 'مؤكَّد';

  @override
  String get messages => 'الرسائل';

  @override
  String get noConversations =>
      'لا توجد رسائل بعد. عندما تراسل شخصًا رأى حيوانك، أو يتعرّف مالك على حيوان رأيته، تظهر المحادثة هنا.';

  @override
  String aboutPet(String name) {
    return 'بخصوص $name';
  }

  @override
  String youSaid(String text) {
    return 'أنت: $text';
  }

  @override
  String get writeMessage => 'اكتب رسالة';

  @override
  String get send => 'إرسال';

  @override
  String get noMessagesYet =>
      'لا توجد رسائل بعد. ألقِ التحية واشرح كيف يمكنك المساعدة.';

  @override
  String get chatPrivacy =>
      'لا يظهر إلا اسمك. لا تشارك عنوانك أبدًا قبل أن تتأكد.';

  @override
  String caseClosedChat(String name) {
    return 'عاد $name إلى البيت. أُغلق هذا الملف، لكن لا يزال بإمكانك الكتابة.';
  }

  @override
  String messageNotification(String name) {
    return 'رسالة جديدة من $name';
  }

  @override
  String confirmedNotification(String name) {
    return 'تعرّف مالك $name على الحيوان الذي رأيته.';
  }

  @override
  String foundNotification(String name) {
    return 'عاد $name إلى البيت. شكرًا على مساعدتك!';
  }

  @override
  String get helpBringThemHome => 'ساعدنا في إعادتهم إلى البيت';

  @override
  String missingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حيوانًا ضائعًا',
      few: '$count حيوانات ضائعة',
      two: 'حيوانان ضائعان',
      one: 'حيوان واحد ضائع',
      zero: 'لا يوجد حيوان ضائع هنا',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n دقيقة',
      few: 'منذ $n دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n ساعة',
      few: 'منذ $n ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n يومًا',
      few: 'منذ $n أيام',
      two: 'منذ يومين',
      one: 'أمس',
    );
    return '$_temp0';
  }

  @override
  String seenAgo(String when) {
    return 'شوهد $when';
  }

  @override
  String missingCountMore(int count) {
    return 'أكثر من $count حيوانًا ضائعًا';
  }

  @override
  String get possibleVisualMatch => 'تشابه بصري محتمل';

  @override
  String get notConfirmedIdentity => 'تشابه، وليس هوية مؤكَّدة.';

  @override
  String get addClearPhoto => 'أضف صورة واضحة';

  @override
  String get addClearPhotoHelp => 'الكاميرا أو المعرض';

  @override
  String get emailHint => 'بريدك الإلكتروني';

  @override
  String get speciesTitle => 'النوع';

  @override
  String get adjust => 'تعديل';

  @override
  String get tapToAdjust => 'انقر على «تعديل» لتحريكه';

  @override
  String get retake => 'إعادة التصوير';

  @override
  String get thanksTitle => 'شكرًا لك!';

  @override
  String get thanksBody =>
      'مشاهدتك على الخريطة. إذا كانت تشبه حيوانًا ضائعًا، سنُبلغ مالكه فورًا.';

  @override
  String get backToMissingPets => 'العودة إلى الحيوانات الضائعة';

  @override
  String get typeLostOne => 'حيوان ضائع';

  @override
  String get strayStatusTitle => 'ماذا حلّ به؟';

  @override
  String get strayAround => 'لا يزال هنا';

  @override
  String get strayHelped => 'تمّت مساعدته';

  @override
  String get strayGone => 'لم يعد يُرى';

  @override
  String get strayAroundHelp =>
      'رأيته مجددًا؟ انقر على «لا يزال هنا»: هذا يُبقي الحيوان على الخريطة.';

  @override
  String get strayUpdated => 'شكرًا على التحديث!';

  @override
  String helpedBy(String name) {
    return 'ساعدته $name';
  }

  @override
  String get injuredBanner =>
      'هذا الحيوان مصاب. إذا كنت قريبًا، انظر إن كان بإمكانك المساعدة.';

  @override
  String get needsHelpBanner =>
      'هذا الحيوان يحتاج إلى مساعدة. إذا كنت قريبًا، انظر إن كان بإمكانك المساعدة.';

  @override
  String get report => 'إبلاغ';

  @override
  String get reportWhy => 'لماذا تبلّغ عنه؟';

  @override
  String get reasonSpam => 'رسائل مزعجة أو إعلان';

  @override
  String get reasonInappropriate => 'غير لائق أو مسيء';

  @override
  String get reasonFake => 'مزيّف أو مضلّل';

  @override
  String get reasonDangerous => 'خطير أو احتيال';

  @override
  String get reasonOther => 'سبب آخر';

  @override
  String get reportNoteHint => 'هل تريد إضافة شيء؟ (اختياري)';

  @override
  String get sendReport => 'إرسال البلاغ';

  @override
  String get reportThanks => 'شكرًا. سننظر في الأمر.';

  @override
  String get reportHiddenNow => 'شكرًا. أُخفي إلى حين مراجعته.';

  @override
  String get hiddenNotice =>
      'أبلغ عنه بعض الأشخاص، لذا لا يراه الآخرون حتى نراجعه.';

  @override
  String get messageHidden => 'أُخفيت بعد إبلاغ';

  @override
  String get becomeAssociation => 'سجّل كجمعية';

  @override
  String get associationIntro =>
      'تحصل الملاجئ والمنقذون والأطباء البيطريون على شارة موثَّقة وتنبيهات بالحيوانات المصابة القريبة منهم. نراجع كل طلب يدويًا.';

  @override
  String get organisation => 'اسم المنظمة';

  @override
  String get city => 'المدينة';

  @override
  String get contact => 'الهاتف أو الموقع أو صفحة التواصل الاجتماعي';

  @override
  String get contactHelp => 'لنتحقق من هويتك. لا يظهر للآخرين أبدًا.';

  @override
  String get associationNote => 'هل من شيء آخر؟ (اختياري)';

  @override
  String get alertArea => 'أين نرسل لك التنبيهات؟';

  @override
  String get alertAreaHelp => 'الحيوانات المصابة في نطاق 10 كم من هذا المكان';

  @override
  String get sendRequest => 'إرسال الطلب';

  @override
  String requestPending(String name) {
    return 'طلبك باسم $name قيد المراجعة. سنُعلمك بالنتيجة.';
  }

  @override
  String requestApproved(String name) {
    return '$name جمعية موثَّقة. ستصلك تنبيهات بالحيوانات المصابة القريبة منك.';
  }

  @override
  String get requestRejected =>
      'لم نتمكن من التحقق من طلبك الأخير. يمكنك إرسال طلب جديد بمزيد من التفاصيل.';

  @override
  String get verifiedAssociation => 'جمعية موثَّقة';

  @override
  String get admin => 'الإدارة';

  @override
  String get adminRequests => 'الطلبات';

  @override
  String get adminHidden => 'المخفيّ';

  @override
  String get noPendingRequests => 'لا توجد طلبات في الانتظار.';

  @override
  String get noHiddenContent => 'لا يوجد شيء مخفيّ.';

  @override
  String get approve => 'قبول';

  @override
  String get reject => 'رفض';

  @override
  String get restore => 'استعادة';

  @override
  String reportsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بلاغًا',
      few: '$count بلاغات',
      two: 'بلاغان',
      one: 'بلاغ واحد',
    );
    return '$_temp0';
  }

  @override
  String messageFrom(String name) {
    return 'رسالة من $name';
  }

  @override
  String get deleteForGood => 'حذفه نهائيًا؟';

  @override
  String get more => 'المزيد';

  @override
  String get helpNotification => 'حيوان يحتاج إلى مساعدة بالقرب منك';

  @override
  String get associationNotification => 'تمّ الرد على طلب الجمعية';

  @override
  String get serverAddress => 'عنوان الخادم';

  @override
  String get serverHelp =>
      'الحاسوب الذي يشغّل Winou. على نقطة اتصال هاتفك أو على نفس شبكة Wi-Fi: عنوانه، مثل 192.168.43.12. بكابل USB: ‎127.0.0.1.';

  @override
  String get testConnection => 'اختبار';

  @override
  String get serverOk => 'متصل';

  @override
  String get serverUnreachable =>
      'تعذّر الوصول إليه. هل أنتما على نفس الشبكة؟ هل جدار الحماية في الحاسوب مفتوح؟';

  @override
  String get save => 'حفظ';

  @override
  String get errorBanned => 'هذا الحساب موقوف.';

  @override
  String get suspendedTitle => 'الحساب موقوف';

  @override
  String suspendedUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get suspendedForGood => 'نهائيًا';

  @override
  String suspendedReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get suspendedHelp =>
      'حيواناتك الضائعة ومشاهداتك مخفية عن الآخرين خلال هذه المدة. إذا كنت تظن أن هذا خطأ، تواصل مع فريق Winou.';

  @override
  String get checkAgain => 'التحقق مجددًا';

  @override
  String get stillSuspended => 'لا يزال موقوفًا.';

  @override
  String get adminUsers => 'المستخدمون';

  @override
  String get searchUsers => 'الاسم أو البريد الإلكتروني';

  @override
  String get bannedOnly => 'الموقوفون فقط';

  @override
  String get noUsersFound => 'لم يُعثر على أحد.';

  @override
  String get noBannedUsers => 'لا يوجد أحد موقوف.';

  @override
  String get banned => 'موقوف';

  @override
  String get association => 'جمعية';

  @override
  String joinedOn(String date) {
    return 'انضمّ في $date';
  }

  @override
  String get statLostPets => 'ضائعة';

  @override
  String get statSightings => 'مشاهدات';

  @override
  String get statReports => 'بلاغات';

  @override
  String get suspend => 'إيقاف';

  @override
  String suspendWho(String name) {
    return 'إيقاف $name؟';
  }

  @override
  String get suspendExplain =>
      'لن يتمكن من تسجيل الدخول أو النشر، ويُخفى ما نشره عن الآخرين حتى نهاية الإيقاف. سيرى السبب.';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get forGood => 'نهائيًا';

  @override
  String get suspendReasonHint => 'السبب، سيُعرض عليه (اختياري)';

  @override
  String get liftSuspension => 'رفع الإيقاف';

  @override
  String liftSuspensionOf(String name) {
    return 'السماح لـ$name باستخدام Winou مجددًا؟';
  }

  @override
  String get revokeAssociation => 'سحب صفة الجمعية';

  @override
  String revokeAssociationQuestion(String name) {
    return 'سحب صفة الجمعية من $name؟ لن تبقى الشارة ولا تنبيهات الحيوانات المصابة. يمكنها التقدّم بطلب جديد.';
  }

  @override
  String get revoke => 'سحب';

  @override
  String userLostPets(int count) {
    return 'حيوانات ضائعة ($count)';
  }

  @override
  String userSightings(int count) {
    return 'مشاهدات ($count)';
  }

  @override
  String get hiddenLabel => 'مخفيّ';

  @override
  String get adminHistory => 'سجل الإدارة';

  @override
  String get noAdminHistory => 'لا توجد إجراءات إدارية بعد.';

  @override
  String get deletedAdmin => 'مشرف سابق';

  @override
  String get actionApprovedAssociation => 'قُبلت الجمعية';

  @override
  String get actionRejectedAssociation => 'رُفض طلب الجمعية';

  @override
  String get actionRevokedAssociation => 'سُحبت صفة الجمعية';

  @override
  String actionRestored(String what) {
    return 'استُعيد: $what';
  }

  @override
  String actionDeleted(String what) {
    return 'حُذف: $what';
  }

  @override
  String get actionBanned => 'أُوقف';

  @override
  String get actionUnbanned => 'رُفع الإيقاف';

  @override
  String get targetLostReport => 'بلاغ حيوان ضائع';

  @override
  String get targetSighting => 'مشاهدة';

  @override
  String get targetMessage => 'رسالة';

  @override
  String get adminReported => 'المُبلَّغ عنه';

  @override
  String get noReportedContent => 'لا توجد بلاغات في الانتظار.';

  @override
  String get dismissReports => 'تجاهل';

  @override
  String get hideNow => 'إخفاء الآن';

  @override
  String byAuthor(String name) {
    return 'بواسطة $name';
  }

  @override
  String get viewAuthor => 'من نشره';

  @override
  String get adminDelete => 'حذف (إدارة)';

  @override
  String get hiddenFromOthers => 'مخفيّ عن الجميع باستثناء صاحبه.';

  @override
  String get shownAgain => 'ظاهر من جديد.';

  @override
  String actionHidden(String what) {
    return 'أُخفي: $what';
  }

  @override
  String actionDismissed(String what) {
    return 'تمّ تجاهل البلاغات · $what';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get adminDashboard => 'لوحة المتابعة';

  @override
  String get adminActivity => 'النشاط';

  @override
  String aboutUser(String name) {
    return 'بخصوص $name';
  }

  @override
  String get statUsers => 'المستخدمون';

  @override
  String statNewThisWeek(int count) {
    return '+$count هذا الأسبوع';
  }

  @override
  String get statOpenLost => 'لا تزال ضائعة';

  @override
  String statOfTotal(int count) {
    return 'من أصل $count مُبلَّغ عنها';
  }

  @override
  String get statReunited => 'عادت إلى البيت';

  @override
  String statReunionRate(String rate) {
    return '$rate من الحيوانات الضائعة';
  }

  @override
  String get statMatchesConfirmed => 'تطابقات مؤكَّدة';

  @override
  String get statStraysOnMap => 'حيوانات الشارع على الخريطة';

  @override
  String get statAssociations => 'الجمعيات';

  @override
  String statStraysHelped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ساعدت $count حيوانًا',
      few: 'ساعدت $count حيوانات',
      two: 'ساعدت حيوانين',
      one: 'ساعدت حيوانًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String lastWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر $count أسبوعًا',
      few: 'آخر $count أسابيع',
      two: 'آخر أسبوعين',
      one: 'الأسبوع الأخير',
    );
    return '$_temp0';
  }

  @override
  String weekOf(String date) {
    return 'أسبوع $date';
  }

  @override
  String get seriesLost => 'ضائعة';

  @override
  String get seriesSightings => 'مشاهدات';

  @override
  String get seriesReunited => 'عادت';

  @override
  String get showTable => 'عرض كجدول';

  @override
  String get showChart => 'عرض كرسم بياني';

  @override
  String get weekColumn => 'الأسبوع';

  @override
  String get weeklyChartLabel =>
      'الحيوانات الضائعة والمشاهدات والحيوانات العائدة إلى البيت في كل أسبوع. المس واسحب لرؤية أرقام أسبوع.';

  @override
  String get errorTooManyAttempts =>
      'محاولات كثيرة جدًا. انتظر بضع دقائق ثم حاول مجددًا.';

  @override
  String get errorWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get errorSessionExpired => 'يُرجى تسجيل الدخول مجددًا.';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get nameHelp => 'يظهر للأشخاص الذين تتحدث معهم';

  @override
  String get account => 'الحساب';

  @override
  String get changeName => 'تغيير اسمك';

  @override
  String get nameChanged => 'تمّ تغيير الاسم.';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get changePasswordHelp => 'سيُسجَّل خروج هواتفك الأخرى.';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get passwordChanged =>
      'تمّ تغيير كلمة المرور. سُجّل خروج هواتفك الأخرى.';

  @override
  String get signOutEverywhere => 'تسجيل الخروج من كل الهواتف';

  @override
  String get signOutEverywhereHelp =>
      'إذا فقدت هاتفًا، أو استعملت هاتف شخص آخر';

  @override
  String get signOutEverywhereQuestion =>
      'تسجيل الخروج من Winou على كل الهواتف، بما فيها هذا الهاتف؟';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountHelp => 'حسابك وكل ما نشرته';

  @override
  String get deleteAccountQuestion => 'حذف حسابك؟';

  @override
  String get deleteAccountWarning =>
      'ستُحذف بلاغاتك عن الحيوانات الضائعة ومشاهداتك وصورك ومحادثاتك نهائيًا. لا يمكن التراجع عن ذلك.';

  @override
  String get deleteAccountForGood => 'حذف حسابي';

  @override
  String get accountDeleted => 'تمّ حذف حسابك.';

  @override
  String get or => 'أو';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get signedInWithGoogle => 'تسجيل الدخول عبر Google';

  @override
  String get setPassword => 'تعيين كلمة مرور';

  @override
  String get setPasswordHelp =>
      'لتتمكن من تسجيل الدخول ببريدك الإلكتروني أيضًا، وليس عبر Google فقط';

  @override
  String get errorGoogleDisabled =>
      'تسجيل الدخول عبر Google غير متاح على هذا الخادم.';

  @override
  String get errorGoogleNoEmail =>
      'لا يملك حساب Google هذا بريدًا إلكترونيًا موثَّقًا.';

  @override
  String get errorGoogleFailed =>
      'لم ينجح تسجيل الدخول عبر Google. حاول مجددًا.';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordTitle => 'اختر كلمة مرور جديدة';

  @override
  String get forgotPasswordHelp =>
      'أدخل بريدك الإلكتروني: سنرسل لك رمزًا من 6 أرقام.';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get sendNewCode => 'إرسال رمز جديد';

  @override
  String get codeSent =>
      'أُرسل الرمز. تفقّد بريدك الوارد والرسائل غير المرغوب فيها.';

  @override
  String get enterCodeTitle => 'تفقّد بريدك الإلكتروني';

  @override
  String enterCodeHelp(String email) {
    return 'أدخل الرمز المكوَّن من 6 أرقام الذي أرسلناه إلى $email. صالح لمدة 15 دقيقة.';
  }

  @override
  String get code => 'الرمز';

  @override
  String get codeSixDigits => '6 أرقام';

  @override
  String get setPasswordAndSignIn => 'حفظ وتسجيل الدخول';

  @override
  String get confirmEmail => 'تأكيد بريدك الإلكتروني';

  @override
  String get confirmEmailHelp =>
      'لتتمكن من الحصول على كلمة مرور جديدة إذا نسيتها';

  @override
  String get emailConfirmed => 'تمّ تأكيد البريد الإلكتروني.';

  @override
  String get emailConfirmedPill => 'البريد مؤكَّد';

  @override
  String get emailNotConfirmed => 'البريد غير مؤكَّد';

  @override
  String get errorWrongCode => 'هذا الرمز غير صحيح.';

  @override
  String get errorCodeExpired =>
      'انتهت صلاحية هذا الرمز أو جُرّب مرات كثيرة. اطلب رمزًا جديدًا.';

  @override
  String get errorTooManyCodes =>
      'أرسلنا بالفعل عدة رموز. تفقّد الرسائل غير المرغوب فيها، أو حاول بعد ساعة.';

  @override
  String get sharePosterButton => 'مشاركة ملصق';

  @override
  String get helpByShaRing => 'ساعد بالمشاركة';

  @override
  String sawThisPet(String name) {
    return 'رأيت $name';
  }

  @override
  String shareTitle(String name) {
    return 'مشاركة $name';
  }

  @override
  String get shareHelp =>
      'انشره في مجموعات الحي، أرسله على واتساب، أو اطبعه. رمز QR يفتح صفحة الحيوان.';

  @override
  String get sharePoster => 'مشاركة الملصق';

  @override
  String get shareLink => 'مشاركة';

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get linkCopied => 'تمّ نسخ الرابط.';

  @override
  String shareLostText(String name, String species, String link) {
    return 'هل رأيت $name؟ $species ضائع: شاهد الصور وأبلغ المالك عبر Winou. $link';
  }

  @override
  String get posterLostCat => 'قطّ ضائع';

  @override
  String get posterLostDog => 'كلب ضائع';

  @override
  String get posterLostPet => 'حيوان ضائع';

  @override
  String get posterSeenIt => 'هل رأيت هذا الحيوان؟';

  @override
  String get posterScan => 'امسح الرمز لرؤية الصور وإبلاغ المالك مجانًا.';

  @override
  String sightingAboutPet(String name) {
    return 'بخصوص $name: سيُبلَّغ المالك فورًا.';
  }

  @override
  String finderMatchTitle(String name) {
    return 'شخص يقول إنه رأى $name';
  }

  @override
  String get finderMatchBody =>
      'تعرّف على حيوانك من خلال بلاغك. قارن الصور، ثم راسله.';

  @override
  String get seenByFinder => 'رآه أحدهم';

  @override
  String get finderMatchTip =>
      'انظر جيدًا إلى العلامات والملامح قبل مراسلته: قد يخطئ الناس.';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabMe => 'أنا';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeSystem => 'تلقائي';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'لغة الهاتف';

  @override
  String get thisPhone => 'هذا الهاتف';

  @override
  String get permissions => 'الإشعارات والموقع';

  @override
  String get permissionsHelp => 'اسمح بها أو امنعها من إعدادات Android';

  @override
  String get about => 'حول Winou';

  @override
  String get skip => 'تخطٍّ';

  @override
  String get next => 'التالي';

  @override
  String get getStarted => 'لنبدأ';

  @override
  String get welcomeLostTitle => 'ابحث عن حيوان ضائع';

  @override
  String get welcomeLostBody =>
      'أبلغ عن حيوانك ببضع صور. يقارنها Winou بكل حيوان شوهد بالقرب منك، ويُعلمك عندما يشبهه أحدها.';

  @override
  String get welcomeSawTitle => 'رأيت حيوانًا؟';

  @override
  String get welcomeSawBody =>
      'صوّر قطًّا أو كلبًا تائهًا. إذا كان أحدهم يبحث عنه، يُبلَّغ فورًا، ويمكنكما التحدث دون مشاركة رقمك.';

  @override
  String get welcomeStraysTitle => 'ساعد حيوانات الشارع';

  @override
  String get welcomeStraysBody =>
      'ضع حيوانات الشارع على الخريطة، وأبلغ عن المصاب منها، فتُنبَّه الجمعيات القريبة.';

  @override
  String get welcomePermissionsTitle => 'أمران يساعدان';

  @override
  String get welcomePermissionsBody =>
      'يعمل Winou بدونهما، لكنه يعمل أفضل معهما.';

  @override
  String get permissionNotificationsTitle => 'الإشعارات';

  @override
  String get permissionNotificationsBody =>
      'اعرف فورًا عندما يكون أحدهم قد رأى حيوانك، أو عندما يراسلك.';

  @override
  String get permissionLocationTitle => 'الموقع';

  @override
  String get permissionLocationBody =>
      'لعرض الحيوانات الضائعة القريبة منك وتحديد مكان مشاهداتك. لا يُشارَك أبدًا: لا يرى الآخرون إلا منطقة تقريبية للحيوان الضائع.';

  @override
  String get permissionsLater => 'يمكنك تغيير ذلك لاحقًا في الإعدادات.';

  @override
  String get allow => 'السماح';

  @override
  String get allowed => 'مسموح';

  @override
  String get notAllowed => 'غير مسموح';

  @override
  String get offlineBanner => 'لا يوجد اتصال بالإنترنت';

  @override
  String get serverDownBanner => 'تعذّر الوصول إلى Winou حاليًا';

  @override
  String photosUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'جارٍ إرسال $count صورة…',
      few: 'جارٍ إرسال $count صور…',
      two: 'جارٍ إرسال صورتين…',
      one: 'جارٍ إرسال صورة واحدة…',
    );
    return '$_temp0';
  }

  @override
  String photosWaiting(int count) {
    return '$count في الانتظار';
  }

  @override
  String photosQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ستُرسل $count صورة عند عودة الاتصال.',
      few: 'ستُرسل $count صور عند عودة الاتصال.',
      two: 'ستُرسل صورتان عند عودة الاتصال.',
      one: 'ستُرسل صورة واحدة عند عودة الاتصال.',
    );
    return '$_temp0';
  }

  @override
  String reunionTitle(String name) {
    return 'مرحبًا بعودتك إلى البيت يا $name!';
  }

  @override
  String get reunionBody =>
      'شكرًا لأنك لم تستسلم. أُبلغ كل من ساعد بالخبر السار.';

  @override
  String reunionShareText(String name, String species) {
    return 'خبر سار: عاد $name إلى البيت! شكرًا لكل من شارك وبحث. عُثر عليه بفضل Winou.';
  }

  @override
  String get shareGoodNews => 'شارك الخبر السار';

  @override
  String get done => 'تم';

  @override
  String get viewCards => 'بطاقات';

  @override
  String get viewList => 'قائمة';

  @override
  String get viewGrid => 'شبكة';
}
