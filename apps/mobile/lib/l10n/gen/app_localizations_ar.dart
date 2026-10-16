// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Kabso Live';

  @override
  String get brandWordmarkPrimary => 'Kabso';

  @override
  String get brandWordmarkAccent => 'Live';

  @override
  String get brandSemanticLabel => 'Kabso Live';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSwitchHint => 'يغيّر لغة التطبيق';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'مرحبًا بعودتك. سجّل الدخول للمتابعة.';

  @override
  String get loginIdentifierLabel => 'البريد الإلكتروني أو اسم المستخدم';

  @override
  String get loginPasswordLabel => 'كلمة المرور';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginNoAccount => 'ليس لديك حساب؟';

  @override
  String get loginCreateAccount => 'إنشاء حساب';

  @override
  String get passwordShow => 'إظهار كلمة المرور';

  @override
  String get passwordHide => 'إخفاء كلمة المرور';

  @override
  String get registerTitle => 'أنشئ حسابك';

  @override
  String get registerSubtitle => 'انضم إلى Kabso Live خلال دقيقة.';

  @override
  String get registerEmailLabel => 'البريد الإلكتروني';

  @override
  String get registerUsernameLabel => 'اسم المستخدم';

  @override
  String get registerUsernameHelper =>
      'من 3 إلى 30 حرفًا: أحرف إنجليزية صغيرة وأرقام و . و _';

  @override
  String get registerDisplayNameLabel => 'الاسم الظاهر';

  @override
  String get registerDisplayNameHelper =>
      'اسمك كما يراه الآخرون. حتى 50 حرفًا، ويمكنك استخدام الرموز التعبيرية.';

  @override
  String displayNameCounter(int count) {
    return '$count/50';
  }

  @override
  String get displayNameTooLong =>
      'هذا الاسم طويل جدًا. استخدم 50 حرفًا كحدّ أقصى (بعض الرموز التعبيرية تُحتسب أكثر من حرف).';

  @override
  String get displayNameInvalid =>
      'يحتوي هذا الاسم على أحرف لا يمكن استخدامها. استخدم الحروف والأرقام والمسافات والرموز التعبيرية.';

  @override
  String get displayNameReserved =>
      'لا يمكن استخدام هذا الاسم. اختر اسمًا آخر.';

  @override
  String get registerPasswordLabel => 'كلمة المرور';

  @override
  String get registerPasswordHelper => '8 أحرف على الأقل';

  @override
  String get registerSubmit => 'إنشاء الحساب';

  @override
  String get registerCodeNotice =>
      'سنرسل إلى بريدك الإلكتروني رمزًا من 8 أرقام لتأكيد عنوانك.';

  @override
  String get registerTerms =>
      'بإنشائك حسابًا، فإنك توافق على الشروط وسياسة الخصوصية.';

  @override
  String get registerHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get registerSignIn => 'تسجيل الدخول';

  @override
  String get usernameChecking => 'جارٍ التحقق من توفر الاسم…';

  @override
  String usernameAvailable(String username) {
    return '‎@$username‎ متاح';
  }

  @override
  String usernameTaken(String username) {
    return '‎@$username‎ غير متاح. جرّب اسمًا آخر.';
  }

  @override
  String get usernameCheckFailed =>
      'تعذّر التحقق الآن. يمكنك المتابعة على أي حال.';

  @override
  String get usernameTooShort => 'استخدم 3 أحرف على الأقل';

  @override
  String get usernameTooLong => 'استخدم 30 حرفًا أو أقل';

  @override
  String get usernameBadChars =>
      'استخدم فقط a–z و0–9 والنقطة (.) والشرطة السفلية (_)';

  @override
  String get usernameBadEdges => 'لا يمكن أن يبدأ أو ينتهي بنقطة أو شرطة سفلية';

  @override
  String get codeTitle => 'تحقّق من بريدك الإلكتروني';

  @override
  String codeBody(String email) {
    return 'إذا كان من الممكن استخدام $email لإنشاء حساب جديد، فقد أرسلنا إليه رمزًا من 8 أرقام. أدخل الرمز أدناه.';
  }

  @override
  String get codeChangeEmail => 'تغيير البريد الإلكتروني';

  @override
  String get codeFieldLabel => 'الرمز المكوّن من 8 أرقام';

  @override
  String get codeFieldHint => 'أدخل الرمز الوارد في البريد أو الصقه';

  @override
  String get codeExpiryHint =>
      'تنتهي صلاحية الرمز خلال 30 دقيقة. تحقّق من مجلد الرسائل غير المرغوب فيها إن لم تجده.';

  @override
  String get codeMaybeExpired =>
      'ربما انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get codePasteInvalid =>
      'يتكوّن الرمز من 8 أرقام. تحقّق منه وحاول مرة أخرى.';

  @override
  String get codeSubmit => 'تأكيد';

  @override
  String get codeResend => 'إرسال رمز جديد';

  @override
  String codeResendIn(String time) {
    return 'إرسال رمز جديد بعد $time';
  }

  @override
  String get codeResent =>
      'إذا كان من الممكن استخدام هذا البريد، فسيصلك رمز جديد قريبًا. لم تعد الرموز السابقة صالحة.';

  @override
  String get codeHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get codeLogIn => 'سجّل الدخول';

  @override
  String get codeWelcome => 'مرحبًا بك في Kabso Live';

  @override
  String get errCodeInvalid => 'هذا الرمز غير صحيح أو انتهت صلاحيته.';

  @override
  String get errCodeInvalidRepeated =>
      'ما زال لا يعمل؟ اطلب رمزًا جديدًا واستخدم أحدث رسالة.';

  @override
  String get errUsernameTakenDuringVerify =>
      'حجز شخص آخر اسم المستخدم هذا قبل أن تُكمل. اختر اسمًا آخر وسنرسل إليك رمزًا جديدًا.';

  @override
  String get forgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotSubtitle =>
      'أدخل البريد الإلكتروني الذي سجّلت به وسنرسل إليك رابطًا لإعادة التعيين.';

  @override
  String get forgotEmailLabel => 'البريد الإلكتروني';

  @override
  String get forgotSubmit => 'إرسال الرابط';

  @override
  String get forgotConfirmationTitle => 'تحقّق من بريدك الإلكتروني';

  @override
  String forgotConfirmationBody(String email) {
    return 'إذا كان هناك حساب مرتبط بـ $email، فقد أرسلنا إليه رابطًا لإعادة تعيين كلمة المرور. تنتهي صلاحية الرابط خلال ساعة واحدة.';
  }

  @override
  String get forgotBackToLogin => 'العودة إلى تسجيل الدخول';

  @override
  String get validationRequired => 'هذا الحقل مطلوب';

  @override
  String get validationEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String validationTooShort(int min) {
    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'حرف',
      many: 'حرفًا',
      few: 'أحرف',
    );
    return 'استخدم $min $_temp0 على الأقل';
  }

  @override
  String validationTooLong(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'حرف',
      many: 'حرفًا',
      few: 'أحرف',
    );
    return 'استخدم $max $_temp0 أو أقل';
  }

  @override
  String get validationInvalid => 'القيمة غير صالحة';

  @override
  String get sessionEndedBanner => 'انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى.';

  @override
  String get accountSuspendedBanner =>
      'تم إيقاف هذا الحساب. إذا كنت تعتقد أن هذا خطأ، فتواصل مع الدعم.';

  @override
  String get splashRestoreFailed => 'تعذّرت استعادة جلستك.';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDiscover => 'استكشاف';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navLive => 'مباشر';

  @override
  String get navProfile => 'حسابي';

  @override
  String get discoverComingTitle => 'الاستكشاف قادم';

  @override
  String get discoverComingBody =>
      'يتوفر البحث عن الأشخاص في المرحلة 2، والبثوث والفيديوهات وصنّاع المحتوى الرائجون في المرحلة 9.';

  @override
  String get createComingTitle => 'الإنشاء قادم';

  @override
  String get createComingBody =>
      'تتوفر المنشورات في المرحلة 3، والقصص في المرحلة 4، والفيديوهات القصيرة في المرحلة 5، والبث المباشر في المرحلة 6.';

  @override
  String profileUsername(String username) {
    return '‎@$username‎';
  }

  @override
  String get profileContentComingTitle => 'ستظهر منشوراتك هنا';

  @override
  String get profileContentComingBody =>
      'يتوفر تعديل الملف الشخصي والمتابعون في المرحلة 2، والمنشورات في المرحلة 3، والقصص واللقطات المميزة في المرحلة 4.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get themeSystem => 'حسب إعدادات الجهاز';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsSessions => 'الجلسات النشطة';

  @override
  String get sessionsCurrent => 'هذا الجهاز';

  @override
  String get sessionUnknownDevice => 'جهاز غير معروف';

  @override
  String sessionsLastActive(String relativeTime) {
    return 'نشط $relativeTime';
  }

  @override
  String get sessionsActiveNow => 'نشط الآن';

  @override
  String sessionsSignedIn(String date) {
    return 'تسجيل الدخول في $date';
  }

  @override
  String relativeMinutesAgo(int n) {
    return 'منذ $n د';
  }

  @override
  String relativeHoursAgo(int n) {
    return 'منذ $n س';
  }

  @override
  String relativeDaysAgo(int n) {
    return 'منذ $n ي';
  }

  @override
  String get sessionsRevoke => 'إنهاء';

  @override
  String get sessionsRevokeConfirmTitle => 'إنهاء هذه الجلسة؟';

  @override
  String sessionsRevokeConfirmBody(String device) {
    return 'سيتم تسجيل خروج $device على الفور.';
  }

  @override
  String get sessionsRevokeConfirm => 'إنهاء الجلسة';

  @override
  String get sessionsRevoked => 'تم إنهاء الجلسة';

  @override
  String get sessionsAlreadyEnded => 'كانت هذه الجلسة منتهية بالفعل';

  @override
  String get sessionsNoOthers => 'حسابك مسجَّل الدخول على هذا الجهاز فقط.';

  @override
  String get platformAndroid => 'أندرويد';

  @override
  String get platformIos => 'iOS';

  @override
  String get platformWeb => 'الويب';

  @override
  String get platformOther => 'أخرى';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج من Kabso Live؟';

  @override
  String get logoutConfirmBody =>
      'ستحتاج إلى كلمة المرور لتسجيل الدخول مجددًا على هذا الجهاز.';

  @override
  String get logoutDone => 'تم تسجيل خروجك';

  @override
  String get errorValidationFailed =>
      'بعض البيانات تحتاج إلى تصحيح. راجع الحقول المحدَّدة.';

  @override
  String get errorAuthUnauthenticated =>
      'انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errorAuthInvalidCredentials =>
      'البريد الإلكتروني أو اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get errorAuthRefreshInvalid =>
      'انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errorAuthForbidden => 'ليس لديك صلاحية للقيام بذلك.';

  @override
  String get errorAccountSuspended =>
      'تم إيقاف هذا الحساب. إذا كنت تعتقد أن هذا خطأ، فتواصل مع الدعم.';

  @override
  String get errorNotFound => 'هذا المحتوى غير متاح. ربما تمت إزالته.';

  @override
  String get errorUsernameTaken => 'اسم المستخدم هذا غير متاح. جرّب اسمًا آخر.';

  @override
  String get errorIdempotencyConflict =>
      'تم إرسال هذا الطلب من قبل ببيانات مختلفة. حدّث الصفحة وحاول مرة أخرى.';

  @override
  String get errorTokenExpired =>
      'انتهت صلاحية هذا الرابط أو سبق استخدامه. اطلب رابطًا جديدًا.';

  @override
  String get errorTokenInvalid => 'هذا الرابط غير صالح. اطلب رابطًا جديدًا.';

  @override
  String get errorRateLimited =>
      'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String errorRateLimitedRetryIn(String wait) {
    return 'محاولات كثيرة. حاول مرة أخرى بعد $wait.';
  }

  @override
  String get errorInternal => 'حدث خطأ من جهتنا. يُرجى المحاولة مرة أخرى.';

  @override
  String get errorServiceUnavailable =>
      'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد قليل.';

  @override
  String errorServiceBusyRetryIn(String wait) {
    return 'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد $wait.';
  }

  @override
  String get errorNetworkOffline =>
      'لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مجددًا.';

  @override
  String get errorNetworkTimeout =>
      'استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get errorLiveHostingUnavailable => 'البث المباشر غير متاح بعد.';

  @override
  String get errorLiveRoomAlreadyActive =>
      'لديك بث مباشر قائم بالفعل. تابعه أو أنهِه أولًا.';

  @override
  String get errorLiveRoomEnded => 'انتهى هذا البث.';

  @override
  String errorIdLabel(String requestId) {
    return 'رمز الخطأ: $requestId';
  }

  @override
  String get liveBadge => 'مباشر';

  @override
  String get pkBadge => 'PK';

  @override
  String liveViewers(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted مشاهد',
      many: '$formatted مشاهدًا',
      few: '$formatted مشاهدين',
      two: 'مشاهدان',
      one: 'مشاهد واحد',
      zero: 'لا مشاهدين',
    );
    return '$_temp0';
  }

  @override
  String liveCardSemantics(String host, String viewers, String title) {
    return '$host، مباشر، $viewers، $title';
  }

  @override
  String get avatarLiveNow => 'يبث مباشرة الآن';

  @override
  String get avatarStoryUnseen => 'لديه قصة جديدة';

  @override
  String get avatarStorySeen => 'تمت مشاهدة القصة';

  @override
  String get liveFollow => 'متابعة';

  @override
  String get liveFollowing => 'تتابعه';

  @override
  String get liveClose => 'إغلاق';

  @override
  String get liveCommentHint => 'قل شيئًا…';

  @override
  String get liveGifts => 'الهدايا';

  @override
  String get liveShare => 'مشاركة';

  @override
  String get liveVideoPlaceholder => 'فيديو البث';

  @override
  String chatJoined(String name) {
    return 'انضم $name';
  }

  @override
  String chatGiftSent(String name, String gift, int count) {
    return 'أرسل $name $gift ×$count';
  }

  @override
  String get giftPanelTitle => 'أرسل هدية';

  @override
  String get giftSend => 'إرسال';

  @override
  String get giftSendComingSoon => 'لا يمكن إرسال الهدايا بعد.';

  @override
  String giftCombo(int count) {
    return '×$count';
  }

  @override
  String giftCellSemantics(String gift, String price) {
    return '$gift، السعر $price';
  }

  @override
  String pkTimeLeft(String time) {
    return 'متبقٍ $time';
  }

  @override
  String pkScoreSemantics(String left, String right) {
    return 'النتيجة $left مقابل $right';
  }

  @override
  String get pkWin => 'فوز';

  @override
  String get pkLose => 'خسارة';

  @override
  String get pkDraw => 'تعادل';

  @override
  String compactThousand(String value) {
    return '$value ألف';
  }

  @override
  String compactMillion(String value) {
    return '$value مليون';
  }

  @override
  String compactBillion(String value) {
    return '$value مليار';
  }

  @override
  String get debugComponentGallery => 'معرض المكونات';

  @override
  String get registerUsernameReservedHint =>
      'إذا كنت قد بدأت التسجيل بهذا البريد واسم المستخدم، فقد يظل رمزك صالحًا. اطلب رمزًا جديدًا للمتابعة، أو اختر اسم مستخدم آخر.';

  @override
  String get registerResendCode => 'أعد إرسال الرمز';

  @override
  String get registerChooseAnotherUsername => 'اختر اسم مستخدم آخر';

  @override
  String get feedTabFollowing => 'متابَعون';

  @override
  String get feedTabPopular => 'رائج';

  @override
  String get feedTabNew => 'جديد';

  @override
  String get feedSearch => 'بحث';

  @override
  String get feedSeePopular => 'عرض الرائج';

  @override
  String get feedPullToRefresh => 'اسحب للأسفل للتحديث.';

  @override
  String get homeFollowingUnavailableTitle => 'ابقَ قريبًا ممن تتابعهم';

  @override
  String get homeFollowingUnavailableBody =>
      'ستظهر هنا قريبًا منشورات من تتابعهم. وحتى ذلك الحين، شاهد من يبث منهم مباشرة الآن.';

  @override
  String get homePopularUnavailableTitle => 'المنشورات في الطريق';

  @override
  String get homePopularUnavailableBody =>
      'قريبًا ستظهر هنا المنشورات التي يتحدث عنها الجميع. وحتى ذلك الحين، انضم إلى بث مباشر.';

  @override
  String get homeNewUnavailableTitle => 'منشورات جديدة قريبًا';

  @override
  String get homeNewUnavailableBody =>
      'ستصل هنا أحدث منشورات المجتمع أولًا بأول. والآن، اكتشف من بدأ البث للتو.';

  @override
  String get homeEmptyTitle => 'لا توجد منشورات بعد';

  @override
  String get homeFollowingEmptyTitle => 'لا توجد منشورات ممن تتابعهم بعد';

  @override
  String get homeErrorTitle => 'تعذّر تحميل المنشورات';

  @override
  String get liveHubChipAll => 'الكل';

  @override
  String get liveHubFollowingUnavailableTitle => 'بثوث من تتابعهم';

  @override
  String get liveHubFollowingUnavailableBody =>
      'البث المباشر غير متاح بعد. عند إتاحته سترى هنا من يبث ممن تتابعهم.';

  @override
  String get liveHubPopularUnavailableTitle => 'البث المباشر غير متاح بعد';

  @override
  String get liveHubPopularUnavailableBody =>
      'نعمل على تجهيزه. عند إتاحته ستظهر هنا البثوث الأكثر مشاهدة.';

  @override
  String get liveHubNewUnavailableTitle => 'هنا تبدأ البثوث الجديدة';

  @override
  String get liveHubNewUnavailableBody =>
      'البث المباشر غير متاح بعد. عند إتاحته ستظهر هنا البثوث التي بدأت للتو أولًا.';

  @override
  String get liveHubEmptyTitle => 'لا توجد بثوث مباشرة الآن';

  @override
  String get liveHubFollowingEmptyTitle => 'لا أحد ممن تتابعهم يبث الآن';

  @override
  String get liveHubErrorTitle => 'تعذّر تحميل البثوث المباشرة';

  @override
  String get liveHubLoadMoreFailed => 'تعذّر تحميل المزيد';

  @override
  String get liveHubListEnd => 'اسحب للأسفل لعرض بثوث جديدة';

  @override
  String get liveCardNew => 'جديد';

  @override
  String liveMultiGuest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ضيف',
      many: '$count ضيفًا',
      few: '$count ضيوف',
      two: 'ضيفان',
      one: 'ضيف واحد',
    );
    return '$_temp0';
  }

  @override
  String liveCardSemanticsMode(String card, String mode) {
    return '$card، $mode';
  }

  @override
  String get feedPostJustNow => 'الآن';

  @override
  String get feedOfflineTitle => 'أنت غير متصل بالإنترنت';

  @override
  String get feedOfflineBody => 'تحقّق من اتصالك ثم أعد المحاولة.';

  @override
  String get homeWatchLive => 'شاهد البث المباشر';

  @override
  String get homeSeeWhoIsLive => 'شاهد من يبث الآن';

  @override
  String get liveHubEmptyBody =>
      'تفقّد البثوث الجديدة أو حاول مرة أخرى لاحقًا.';

  @override
  String get liveHubSeeNew => 'عرض البثوث الجديدة';

  @override
  String get liveHubFollowingEmptyBody =>
      'عندما يبدأ من تتابعهم البث، ستجدهم هنا.';

  @override
  String liveCardSemanticsCategory(String card, String category) {
    return '$card، $category';
  }

  @override
  String get liveRoomVideoUnavailableTitle => 'فيديو البث غير متاح بعد';

  @override
  String get liveRoomVideoUnavailableBody =>
      'لا يمكن تشغيل الفيديو في التطبيق بعد. تفاصيل الغرفة هنا مباشرة.';

  @override
  String get liveRoomChatUnavailable =>
      'الدردشة غير متاحة بعد. ستظهر الرسائل هنا.';

  @override
  String liveRoomFollowers(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted متابع',
      many: '$formatted متابعًا',
      few: '$formatted متابعين',
      two: 'متابعان',
      one: 'متابع واحد',
      zero: 'لا متابعين',
    );
    return '$_temp0';
  }

  @override
  String liveRoomHostSemantics(String host) {
    return '$host، ملف المضيف';
  }

  @override
  String liveRoomUsername(String username) {
    return '@$username';
  }

  @override
  String liveRoomCategory(String category) {
    return 'الفئة: $category';
  }

  @override
  String get liveRoomEndedTitle => 'انتهى هذا البث';

  @override
  String get liveRoomEndedByHost => 'أنهى المضيف هذا البث.';

  @override
  String get liveRoomEndedTimeout => 'توقف البث بعد انقطاع اتصال المضيف.';

  @override
  String get liveRoomEndedOther => 'لم يعد هذا البث متاحًا.';

  @override
  String get liveRoomBackToLive => 'العودة إلى البثوث';

  @override
  String get liveRoomNotFoundTitle => 'هذا البث غير متاح';

  @override
  String get liveRoomNotFoundBody => 'ربما انتهى أو تمت إزالته.';

  @override
  String get liveRoomErrorTitle => 'تعذّر فتح هذا البث';

  @override
  String get liveRoomLoading => 'جارٍ فتح البث';

  @override
  String get liveRoomWeakConnection => 'اتصال ضعيف';

  @override
  String get liveRoomReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get liveRoomCameraOff => 'الكاميرا متوقفة';

  @override
  String get giftNameHeart => 'قلب';

  @override
  String get giftNameStar => 'نجمة';

  @override
  String get giftNameDiamond => 'ماسة';

  @override
  String get giftNameCrown => 'تاج';

  @override
  String get pkVersus => 'VS';

  @override
  String pkSupporters(String names) {
    return 'أبرز الداعمين: $names';
  }

  @override
  String get multiGuestOpenSeat => 'مقعد شاغر';

  @override
  String multiGuestMicOff(String name) {
    return '$name، الميكروفون مغلق';
  }

  @override
  String get multiGuestHost => 'المضيف';
}
