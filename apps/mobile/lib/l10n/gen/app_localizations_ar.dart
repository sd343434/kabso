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
  String get navReels => 'ريلز';

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
      'تصل المنشورات في المرحلة 3 والريلز في المرحلة 5. أما تعديل الملف الشخصي والقصص واللقطات المميزة فلاحقًا.';

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
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n دقيقة',
      many: 'منذ $n دقيقة',
      few: 'منذ $n دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n ساعة',
      many: 'منذ $n ساعة',
      few: 'منذ $n ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n يوم',
      many: 'منذ $n يومًا',
      few: 'منذ $n أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
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
  String get feedPreviewTestData => 'بيانات اختبار';

  @override
  String get feedOpenLive => 'البث المباشر';

  @override
  String get feedActionLike => 'إعجاب';

  @override
  String get feedActionComment => 'تعليقات';

  @override
  String get feedActionSave => 'حفظ';

  @override
  String livePreviewJoined(String name) {
    return '$name انضم';
  }

  @override
  String get livePreviewMinimize => 'تصغير';

  @override
  String get livePreviewBalance => 'الرصيد';

  @override
  String get livePreviewMore => 'المزيد';

  @override
  String get livePreviewEmoji => 'رموز تعبيرية';

  @override
  String livePreviewRank(int rank) {
    return 'الترتيب الأسبوعي #$rank';
  }

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

  @override
  String get shareSheetTitle => 'مشاركة إلى';

  @override
  String get shareRepost => 'إعادة نشر';

  @override
  String get shareCopyLink => 'نسخ الرابط';

  @override
  String get shareSend => 'إرسال';

  @override
  String get shareSaveVideo => 'حفظ الفيديو';

  @override
  String get shareReport => 'إبلاغ';

  @override
  String get messagesPreviewHint => 'اكتب رسالة…';

  @override
  String get messagesPreviewSend => 'إرسال';

  @override
  String get messagesPreviewPlay => 'تشغيل الفيديو';

  @override
  String messagesPreviewReaction(String emoji) {
    return 'تفاعل $emoji';
  }

  @override
  String commentsSheetTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعليق',
      many: '$count تعليقًا',
      few: '$count تعليقات',
      two: 'تعليقان',
      one: 'تعليق واحد',
      zero: 'لا تعليقات',
    );
    return '$_temp0';
  }

  @override
  String get commentsCreator => 'صاحب المنشور';

  @override
  String get commentsReply => 'رد';

  @override
  String commentsViewReplies(int count) {
    return 'عرض الردود ($count)';
  }

  @override
  String get commentsHideReplies => 'إخفاء الردود';

  @override
  String get commentsHint => 'أضف تعليقًا…';

  @override
  String get commentsPost => 'نشر';

  @override
  String commentsLike(String count) {
    return 'إعجاب، $count';
  }

  @override
  String get commentsVerified => 'موثّق';

  @override
  String get previewsHubTitle => 'معاينات التصميم';

  @override
  String get previewsHubNote => 'بيانات اختبار فقط. لا شيء هنا متصل بالخادم.';

  @override
  String get previewsHubFeed => 'المنشورات';

  @override
  String get previewsHubLive => 'غرفة البث';

  @override
  String get previewsHubMessages => 'الرسائل';

  @override
  String get previewsHubComponents => 'المكوّنات';

  @override
  String get commentsYou => 'أنت';

  @override
  String get conversationsTitle => 'الرسائل الخاصة';

  @override
  String get conversationsSharedVideo => 'شارك فيديو';

  @override
  String conversationsSayHi(String name) {
    return 'ألقِ التحية على $name';
  }

  @override
  String conversationsUnread(String name) {
    return '$name، غير مقروءة';
  }

  @override
  String get conversationsEmptyTitle => 'لا رسائل بعد';

  @override
  String get conversationsEmptyBody => 'عندما تراسل أحدًا، تظهر المحادثة هنا.';

  @override
  String get conversationsUnavailableTitle => 'الرسائل غير متاحة بعد';

  @override
  String get conversationsUnavailableBody =>
      'ستُفتح الرسائل الخاصة هنا عندما تصبح جاهزة.';

  @override
  String get previewStateLabel => 'حالة المعاينة';

  @override
  String get previewStateLoading => 'تحميل';

  @override
  String get previewStateError => 'خطأ';

  @override
  String get previewStateUnavailable => 'غير متاح';

  @override
  String get previewStateEmpty => 'فارغ';

  @override
  String get previewStatePopulated => 'مع بيانات';

  @override
  String get messagesGreetingHi => 'مرحبًا';

  @override
  String get messagesGreetingHello => 'أهلًا وسهلًا';

  @override
  String get messagesGreetingHowAreYou => 'كيف حالك؟';

  @override
  String get previewsHubConversations => 'المحادثات';

  @override
  String get discoverTrendingHashtag => 'وسم رائج';

  @override
  String discoverHashtagVideos(String name, String count) {
    return '$name، $count فيديو';
  }

  @override
  String discoverBanner(int index, int total) {
    return 'مميّز $index من $total';
  }

  @override
  String get discoverNoResultsTitle => 'لا نتائج';

  @override
  String discoverNoResultsBody(String query) {
    return 'لا شيء في بيانات الاختبار يطابق $query.';
  }

  @override
  String get discoverClearSearch => 'مسح البحث';

  @override
  String discoverOpenVideo(int index, String name) {
    return 'فتح الفيديو $index من $name';
  }

  @override
  String get reelsModeLabel => 'عرض الريلز أو المنشورات';

  @override
  String get reelsModeReels => 'ريلز';

  @override
  String get reelsModePosts => 'منشورات';

  @override
  String get reelsTabForYou => 'لك';

  @override
  String get reelsTabFriends => 'الأصدقاء';

  @override
  String reelsCoins(String count) {
    return 'رصيد العملات، $count';
  }

  @override
  String get reelsSave => 'حفظ';

  @override
  String get reelsSaved => 'محفوظ';

  @override
  String get reelsNotInterested => 'غير مهتم';

  @override
  String get reelsProgress => 'موضع التشغيل';

  @override
  String postsLikes(String count) {
    return '$count إعجاب';
  }

  @override
  String postsViewComments(String count) {
    return 'عرض كل التعليقات ($count)';
  }

  @override
  String get previewsHubReels => 'الريلز والمنشورات';

  @override
  String get previewsHubReelsTab => 'تبويب الريلز (المنشورات)';

  @override
  String get homeTabPosts => 'المنشورات';

  @override
  String get homeTabReels => 'الريلز';

  @override
  String get homeReelsUnavailableTitle => 'الريلز قادمة قريبًا';

  @override
  String get homeReelsUnavailableBody =>
      'ستظهر هنا مقاطع الفيديو القصيرة عند إطلاق الريلز. حاليًا، شاهد البث المباشر.';

  @override
  String get homeReelsEmptyTitle => 'لا توجد ريلز بعد';

  @override
  String get homeReelsErrorTitle => 'تعذّر تحميل الريلز';

  @override
  String homeReelBy(String name) {
    return 'ريل من $name';
  }

  @override
  String get liveHubJoin => 'ادخل البث';

  @override
  String get liveHubLoadingMore => 'جارٍ تحميل المزيد من البثوث';

  @override
  String get homeShowReels => 'عرض الريلز';

  @override
  String get homeShowPosts => 'عرض المنشورات';

  @override
  String get feedSeeMore => 'عرض المزيد';

  @override
  String get feedPostVideo => 'فيديو';

  @override
  String feedPostCounts(String likes, String comments, String shares) {
    return '$likes إعجاب، $comments تعليق، $shares مشاركة';
  }

  @override
  String get homeFeedTrending => 'رائج';

  @override
  String homeFollowAuthor(String name) {
    return 'متابعة $name';
  }

  @override
  String homeFollowingAuthor(String name) {
    return 'تتابع $name';
  }

  @override
  String get homeReelsFollowingUnavailableTitle => 'ريلز ممن تتابعهم';

  @override
  String get homeReelsFollowingUnavailableBody =>
      'ستظهر هنا ريلز من تتابعهم عند إطلاق الريلز. وحتى ذلك الحين، شاهد البث المباشر.';

  @override
  String get homeReelsFollowingEmptyTitle => 'لا توجد ريلز ممن تتابعهم بعد';

  @override
  String get feedPostMore => 'خيارات أخرى';

  @override
  String homeUnfollowAuthor(String name) {
    return 'إلغاء متابعة $name';
  }

  @override
  String get profileFollowers => 'المتابِعون';

  @override
  String get profileFollowingCount => 'يتابع';

  @override
  String get profileNoPosts => 'لا توجد منشورات بعد';

  @override
  String get profileNoReels => 'لا توجد ريلز بعد';

  @override
  String get profileGridEmptyBody => 'عندما تنشر شيئًا سيظهر هنا.';

  @override
  String get profileEditTitle => 'تعديل الملف الشخصي';

  @override
  String get profileEditSave => 'حفظ';

  @override
  String get profileEditName => 'الاسم';

  @override
  String get profileEditUsername => 'اسم المستخدم';

  @override
  String get profileEditBio => 'النبذة';

  @override
  String get profileEditUnavailable =>
      'تغيير الاسم والنبذة والصورة يحتاج تحديثًا في الخادم غير متاح بعد.';

  @override
  String get profileEditPhoto => 'تغيير الصورة';

  @override
  String get profileEditLinks => 'الروابط';

  @override
  String get profileEditGender => 'الجنس';

  @override
  String get profileEditCategory => 'فئة الحساب';

  @override
  String get profileEditReorderGrid => 'ترتيب الشبكة';

  @override
  String get profileEditPrivacy => 'خصوصية الحساب';

  @override
  String get profilePrivacyPublic => 'عام';

  @override
  String get profilePrivacyPrivate => 'خاص';

  @override
  String get profileEditSoon => 'قريبًا';

  @override
  String get profileSaved => 'المحفوظات';

  @override
  String get profileNoSaved => 'لا توجد محفوظات بعد';

  @override
  String get profileSavedEmptyBody =>
      'احفظ المنشورات والريلز لتجدها هنا. لا يرى محفوظاتك أحد غيرك.';

  @override
  String get profileSavedComingTitle => 'منشوراتك وريلز المحفوظة';

  @override
  String get profileSavedComingBody =>
      'يصل الحفظ مع المنشورات والريلز. لن يرى محفوظاتك أحد غيرك.';

  @override
  String get profileWatchLive => 'شاهد البث';

  @override
  String get profileOtherComingTitle => 'المنشورات والريلز قادمة';

  @override
  String get profileOtherComingBody =>
      'تصل المنشورات في المرحلة 3 والريلز في المرحلة 5.';

  @override
  String get profileOtherEmptyBody => 'لم يُنشر شيء بعد.';

  @override
  String get profilePrivateTitle => 'هذا الحساب خاص';

  @override
  String get profilePrivateBody => 'منشوراته وريلزه يراها متابعوه فقط.';

  @override
  String get profileNotFoundTitle => 'هذا الحساب غير متاح';

  @override
  String get profileNotFoundBody => 'قد يكون الرابط غير صحيح، أو أُزيل الحساب.';

  @override
  String profileUnfollowConfirm(String name) {
    return 'إلغاء متابعة $name؟';
  }

  @override
  String get previewsHubUserProfile => 'الملف العام';

  @override
  String get profileMessage => 'مراسلة';

  @override
  String get chatUnavailable =>
      'الرسائل الخاصة غير متاحة بعد. عند توفرها ستظهر محادثتكما هنا.';

  @override
  String get profileCopyUsername => 'نسخ اسم المستخدم';

  @override
  String get profileCopyLink => 'نسخ رابط الصفحة';

  @override
  String get profileReport => 'تبليغ';

  @override
  String get profileCopied => 'تم النسخ';
}
