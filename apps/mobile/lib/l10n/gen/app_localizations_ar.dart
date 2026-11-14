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
  String get loginSubtitle => 'سجّل دخولك وكمّل من حيث وقفت';

  @override
  String get loginIdentifierLabel => 'البريد أو اسم المستخدم أو ايدي الموظف';

  @override
  String get loginPasswordLabel => 'كلمة المرور';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginNoAccount => 'ما عندك حساب؟';

  @override
  String get loginCreateAccount => 'أنشئ حساباً';

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
  String get usernameTooShort => 'استخدم 6 أحرف على الأقل';

  @override
  String get usernameTooLong => 'استخدم 30 حرفًا أو أقل';

  @override
  String get usernameBadChars => 'استخدم فقط a–z و0–9 والشرطة السفلية (_)';

  @override
  String get usernameBadEdges => 'لا يمكن أن يبدأ أو ينتهي بشرطة سفلية';

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
  String get splashSkip => 'تخطي';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDiscover => 'استكشاف';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navReels => 'ريلز';

  @override
  String get navLive => 'البث';

  @override
  String get navProfile => 'أنا';

  @override
  String get discoverComingTitle => 'الاستكشاف قادم';

  @override
  String get discoverComingBody =>
      'يتوفر البحث عن الأشخاص في المرحلة 2، والبثوث والفيديوهات وصنّاع المحتوى الرائجون في المرحلة 9.';

  @override
  String profileUsername(String username) {
    return '‎@$username‎';
  }

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
  String get settingsSoundEffects => 'المؤثرات الصوتية';

  @override
  String get settingsSoundEffectsHint => 'ماكس والهدايا المحظوظة والإشعارات';

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
  String get settingsDarkMode => 'الوضع الداكن';

  @override
  String get settingsThemeFollowsDevice => 'يتبع إعداد الجهاز';

  @override
  String get settingsThemeFollowDevice => 'اتباع الجهاز';

  @override
  String settingsLanguageCurrent(String language) {
    return 'اللغة: $language';
  }

  @override
  String settingsLanguageSwitchTo(String language) {
    return 'التبديل إلى $language';
  }

  @override
  String sessionsShowAll(int count) {
    return 'عرض الكل ($count)';
  }

  @override
  String get sessionsRevokeOthers => 'تسجيل الخروج من كل الأجهزة الأخرى';

  @override
  String get sessionsRevokeOthersTitle => 'تسجيل الخروج من كل الأجهزة الأخرى؟';

  @override
  String sessionsRevokeOthersBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'سيتم تسجيل الخروج من $n جهاز آخر على الفور.',
      many: 'سيتم تسجيل الخروج من $n جهازًا آخر على الفور.',
      few: 'سيتم تسجيل الخروج من $n أجهزة أخرى على الفور.',
      two: 'سيتم تسجيل الخروج من جهازين آخرين على الفور.',
      one: 'سيتم تسجيل الخروج من جهاز آخر على الفور.',
    );
    return '$_temp0';
  }

  @override
  String get sessionsRevokeOthersPasswordHint => 'أدخل كلمة المرور للتأكيد.';

  @override
  String get sessionsRevokeOthersConfirm => 'تسجيل الخروج';

  @override
  String sessionsRevokedOthers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'تم تسجيل الخروج من $n جهاز آخر',
      many: 'تم تسجيل الخروج من $n جهازًا آخر',
      few: 'تم تسجيل الخروج من $n أجهزة أخرى',
      two: 'تم تسجيل الخروج من جهازين آخرين',
      one: 'تم تسجيل الخروج من جهاز آخر',
      zero: 'لا توجد أجهزة أخرى مسجَّلة الدخول',
    );
    return '$_temp0';
  }

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
    return 'أرسل $name $gift ⁦×$count⁩';
  }

  @override
  String get giftPanelTitle => 'أرسل هدية';

  @override
  String get giftSend => 'إرسال';

  @override
  String get giftSendComingSoon => 'لا يمكن إرسال الهدايا بعد.';

  @override
  String giftCombo(int count) {
    return '⁦×$count⁩';
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
  String get livePreviewMinimize => 'تصغير';

  @override
  String get livePreviewBalance => 'الرصيد';

  @override
  String get livePreviewMore => 'المزيد';

  @override
  String get livePreviewEmoji => 'رموز تعبيرية';

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
  String get liveStatusEnded => 'انتهى البث';

  @override
  String get liveStatusConnectionLost => 'انقطع الاتصال';

  @override
  String get liveStatusHostAway => 'المضيف بعيد';

  @override
  String get liveStatusCantConnect => 'تعذّر الاتصال';

  @override
  String get liveStatusOffline => 'غير متصل';

  @override
  String get liveStatusUnavailable => 'غير متاح';

  @override
  String get liveStatusRemoved => 'تمت إزالتك';

  @override
  String get liveRoomEndedTitle => 'انتهى هذا البث';

  @override
  String get liveRoomEndedByHost => 'أنهى المضيف هذا البث.';

  @override
  String get liveRoomEndedTimeout => 'توقف البث بعد انقطاع اتصال المضيف.';

  @override
  String get liveRoomEndedHostAway =>
      'انتهى البث لأن المضيف غاب أكثر من 5 دقائق.';

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
  String get liveRoomReconnectingBody => 'لحظات ويعود البث من حيث توقف.';

  @override
  String get liveRoomJoinFailedTitle => 'تعذّر تشغيل البث';

  @override
  String get liveHostAwayBody => 'ابقَ هنا، سيُستأنف البث فور عودته.';

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
  String get commentsYou => 'أنت';

  @override
  String get conversationsTitle => 'الرسائل';

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
  String get profileEditShort => 'تعديل الملف';

  @override
  String get profileEditSave => 'حفظ';

  @override
  String get profileEditName => 'الاسم';

  @override
  String get profileEditUsername => 'اسم المستخدم';

  @override
  String get profileEditBio => 'النبذة';

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
  String get profileOtherEmptyBody => 'لم يُنشر شيء بعد.';

  @override
  String get profilePrivateTitle => 'هذا الحساب خاص';

  @override
  String get profilePrivateBody => 'منشوراته وريلزه وقصصه يراها متابعوه فقط.';

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
  String get profileBondsShow => 'إظهار العائلة والعلاقة والميداليات';

  @override
  String get profileBondsHide => 'إخفاء العائلة والعلاقة والميداليات';

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

  @override
  String get welcomeBody =>
      'بث مباشر، ريلز، بودكاست، وهدايا لصنّاعك المفضلين. ادخل وخلّي صوتك يوصل.';

  @override
  String get authProviderGoogle => 'Google';

  @override
  String get authProviderApple => 'Apple';

  @override
  String get authSocialSoon => 'قريبًا';

  @override
  String authSocialSoonLabel(String provider) {
    return 'المتابعة باستخدام $provider، قريبًا';
  }

  @override
  String get welcomeLiveChip => 'البث شغّال الآن';

  @override
  String get welcomeHeadline1 => 'العالم';

  @override
  String get welcomeHeadline2 => 'كله';

  @override
  String get welcomeHeadline3 => 'على الهواء.';

  @override
  String get welcomeStart => 'يلا نبدأ';

  @override
  String get welcomeHaveAccount => 'عندي حساب · ';

  @override
  String get welcomeComment1 => 'نورت يا كابي 🔥';

  @override
  String get welcomeComment2 => 'أول مرة هنا 😍';

  @override
  String get welcomeComment3 => 'كاب كاب 🎧';

  @override
  String get joinTitleLead => 'خلّي صوتك';

  @override
  String get joinTitleAccent => 'يوصل للعالم';

  @override
  String get joinBody =>
      'بث مباشر، ريلز وبودكاست في مكان واحد.\nأهلًا بك في Kabso Live.';

  @override
  String get joinCreate => 'إنشاء حساب';

  @override
  String get loginTitleLead => 'جاهز تبدأ ';

  @override
  String get loginTitleAccent => 'البث؟';

  @override
  String get kabiEmojiPickerTitle => 'الإيموجي';

  @override
  String get kabiEmojiButton => 'إيموجي';

  @override
  String get emojiPackKabi => 'كابي';

  @override
  String get emojiPackKiki => 'كيكي';

  @override
  String get emojiPackBoo => 'بو';

  @override
  String get emojiPackPipo => 'بيبو';

  @override
  String get emojiPackDubi => 'دوبي';

  @override
  String get emojiPackGogo => 'جوجو';

  @override
  String get emojiPackLulu => 'لولو';

  @override
  String get emojiPackNeno => 'نينو';

  @override
  String get emojiPackFlags => 'أعلام';

  @override
  String get emojiKabiHi => 'هلا';

  @override
  String get emojiKabiLove => 'حب';

  @override
  String get emojiKabiLol => 'ضحك';

  @override
  String get emojiKabiWow => 'واو';

  @override
  String get emojiKabiSad => 'حزين';

  @override
  String get emojiKabiAngry => 'معصّب';

  @override
  String get emojiKabiWink => 'غمزة';

  @override
  String get emojiKabiLive => 'لايف';

  @override
  String get emojiKabiCool => 'كشخة';

  @override
  String get emojiKabiDizzy => 'دايخ';

  @override
  String get emojiKabiSleepy => 'نعسان';

  @override
  String get emojiKabiSilly => 'مهبول';

  @override
  String get emojiKabiShy => 'مستحي';

  @override
  String get emojiKabiThink => 'يفكر';

  @override
  String get emojiKabiParty => 'احتفال';

  @override
  String get emojiKabiDead => 'مت ضحك';

  @override
  String get emojiKabiMelt => 'ذايب';

  @override
  String get emojiKabiKiss => 'بوسة';

  @override
  String get emojiKabiGift => 'هدية';

  @override
  String get emojiKabiFire => 'نار';

  @override
  String get emojiKabiCrown => 'VIP';

  @override
  String get emojiKabiMoney => 'فلوس';

  @override
  String get emojiKabiSing => 'يغني';

  @override
  String get emojiKabiStar => 'منبهر';

  @override
  String get emojiKikiHi => 'هلا';

  @override
  String get emojiKikiLove => 'حب';

  @override
  String get emojiKikiLol => 'ضحك';

  @override
  String get emojiKikiWow => 'واو';

  @override
  String get emojiKikiSad => 'حزين';

  @override
  String get emojiKikiAngry => 'معصّب';

  @override
  String get emojiKikiCool => 'كشخة';

  @override
  String get emojiKikiSleepy => 'نعسان';

  @override
  String get emojiKikiWink => 'غمزة';

  @override
  String get emojiKikiKiss => 'بوسة';

  @override
  String get emojiKikiSing => 'يغني';

  @override
  String get emojiKikiShy => 'مستحية';

  @override
  String get emojiKikiThink => 'تفكر';

  @override
  String get emojiKikiParty => 'احتفال';

  @override
  String get emojiKikiClap => 'تصفيق';

  @override
  String get emojiKikiFire => 'نار';

  @override
  String get emojiKikiOk => 'تمام';

  @override
  String get emojiKikiDizzy => 'دايخة';

  @override
  String get emojiBooBoo => 'بخ';

  @override
  String get emojiBooScared => 'خايف';

  @override
  String get emojiBooFade => 'اختفى';

  @override
  String get emojiBooPeek => 'يطل';

  @override
  String get emojiBooSpin => 'يرقص';

  @override
  String get emojiBooLaugh => 'ضحك';

  @override
  String get emojiBooLove => 'حب';

  @override
  String get emojiBooCry => 'يبكي';

  @override
  String get emojiBooSneaky => 'خبيث';

  @override
  String get emojiBooSleep => 'نايم';

  @override
  String get emojiBooShock => 'مصدوم';

  @override
  String get emojiBooParty => 'احتفال';

  @override
  String get emojiPipoHi => 'هلا';

  @override
  String get emojiPipoChirp => 'يغرّد';

  @override
  String get emojiPipoHungry => 'جوعان';

  @override
  String get emojiPipoCold => 'بردان';

  @override
  String get emojiPipoFly => 'يطير';

  @override
  String get emojiPipoLove => 'حب';

  @override
  String get emojiPipoCry => 'يبكي';

  @override
  String get emojiPipoAngry => 'معصّب';

  @override
  String get emojiPipoSleepy => 'نعسان';

  @override
  String get emojiPipoYay => 'ياي';

  @override
  String get emojiPipoShy => 'مستحي';

  @override
  String get emojiPipoWow => 'واو';

  @override
  String get emojiDubiHug => 'حضن';

  @override
  String get emojiDubiThanks => 'شكرًا';

  @override
  String get emojiDubiStrong => 'قوي';

  @override
  String get emojiDubiHoney => 'عسل';

  @override
  String get emojiDubiSleep => 'نايم';

  @override
  String get emojiDubiGrr => 'غاضب';

  @override
  String get emojiDubiLol => 'ضحك';

  @override
  String get emojiDubiLove => 'حب';

  @override
  String get emojiDubiCool => 'كشخة';

  @override
  String get emojiDubiOk => 'تمام';

  @override
  String get emojiDubiSad => 'حزين';

  @override
  String get emojiDubiClap => 'تصفيق';

  @override
  String get emojiGogoHi => 'هلا';

  @override
  String get emojiGogoRoar => 'زئير';

  @override
  String get emojiGogoStomp => 'يدبدب';

  @override
  String get emojiGogoHatch => 'يفقس';

  @override
  String get emojiGogoMunch => 'ياكل';

  @override
  String get emojiGogoDance => 'يرقص';

  @override
  String get emojiGogoSneeze => 'عطسة';

  @override
  String get emojiGogoCool => 'كشخة';

  @override
  String get emojiGogoLove => 'حب';

  @override
  String get emojiGogoLol => 'ضحك';

  @override
  String get emojiGogoCry => 'يبكي';

  @override
  String get emojiGogoWow => 'واو';

  @override
  String get emojiLuluHi => 'هلا';

  @override
  String get emojiLuluSun => 'مشمس';

  @override
  String get emojiLuluRain => 'ممطر';

  @override
  String get emojiLuluThunder => 'رعد';

  @override
  String get emojiLuluRainbow => 'قوس قزح';

  @override
  String get emojiLuluSnow => 'ثلج';

  @override
  String get emojiLuluWind => 'هواء';

  @override
  String get emojiLuluSleep => 'نايمة';

  @override
  String get emojiLuluLove => 'حب';

  @override
  String get emojiLuluWow => 'واو';

  @override
  String get emojiLuluLol => 'ضحك';

  @override
  String get emojiLuluShy => 'مستحية';

  @override
  String get emojiNenoHi => 'هلا';

  @override
  String get emojiNenoLove => 'حب';

  @override
  String get emojiNenoLol => 'ضحك';

  @override
  String get emojiNenoWow => 'واو';

  @override
  String get emojiNenoCry => 'يبكي';

  @override
  String get emojiNenoAngry => 'معصّب';

  @override
  String get emojiNenoCool => 'كشخة';

  @override
  String get emojiNenoThink => 'يفكر';

  @override
  String get emojiNenoWink => 'غمزة';

  @override
  String get emojiNenoSleepy => 'نعسان';

  @override
  String get emojiNenoMoney => 'بزنس';

  @override
  String get emojiNenoOk => 'تمام';

  @override
  String get emojiNenoClap => 'تصفيق';

  @override
  String get emojiNenoParty => 'احتفال';

  @override
  String get emojiNenoKiss => 'بوسة';

  @override
  String get emojiNenoBlush => 'مستحي';

  @override
  String get emojiNenoRose => 'وردة';

  @override
  String get emojiNenoHeartbeat => 'قلبي يدق';

  @override
  String get emojiNenoFlirt => 'غزل';

  @override
  String get emojiNenoMelt => 'ذايب';

  @override
  String get emojiNenoIloveu => 'أحبك';

  @override
  String get emojiNenoSerenade => 'يغني لها';

  @override
  String get emojiFlagsJo => 'الأردن';

  @override
  String get emojiFlagsPs => 'فلسطين';

  @override
  String get emojiFlagsSa => 'السعودية';

  @override
  String get emojiFlagsEg => 'مصر';

  @override
  String get emojiFlagsIq => 'العراق';

  @override
  String get emojiFlagsSy => 'سوريا';

  @override
  String get emojiFlagsYe => 'اليمن';

  @override
  String get emojiFlagsAe => 'الإمارات';

  @override
  String get emojiFlagsKw => 'الكويت';

  @override
  String get emojiFlagsQa => 'قطر';

  @override
  String get emojiFlagsBh => 'البحرين';

  @override
  String get emojiFlagsOm => 'عُمان';

  @override
  String get emojiFlagsLb => 'لبنان';

  @override
  String get emojiFlagsMa => 'المغرب';

  @override
  String get emojiFlagsDz => 'الجزائر';

  @override
  String get emojiFlagsTn => 'تونس';

  @override
  String get emojiFlagsLy => 'ليبيا';

  @override
  String get emojiFlagsSd => 'السودان';

  @override
  String get attachButton => 'إرفاق صورة أو فيديو';

  @override
  String get attachGallery => 'صورة أو فيديو من المعرض';

  @override
  String get attachTakePhoto => 'التقاط صورة';

  @override
  String get attachRecordVideo => 'تسجيل فيديو';

  @override
  String get attachFailed =>
      'تعذّر فتح الصور أو الكاميرا. تحقّق من صلاحيات التطبيق في الإعدادات.';

  @override
  String get attachPhotoLabel => 'صورة';

  @override
  String get attachPlayVideo => 'تشغيل الفيديو';

  @override
  String get attachPause => 'إيقاف الفيديو مؤقتًا';

  @override
  String get chatOnline => 'متصل الآن';

  @override
  String get chatToday => 'اليوم';

  @override
  String get chatStatusSent => 'أُرسلت';

  @override
  String get chatStatusDelivered => 'وصلت';

  @override
  String get chatStatusRead => 'قُرئت';

  @override
  String chatTyping(String name) {
    return '$name يكتب الآن';
  }

  @override
  String get conversationsSearch => 'ابحث في المحادثات';

  @override
  String get conversationsActiveNow => 'نشطون الآن';

  @override
  String get conversationsFilterAll => 'الكل';

  @override
  String get conversationsFilterUnread => 'غير المقروءة';

  @override
  String get conversationsFilterGroups => 'المجموعات';

  @override
  String get conversationsFilterFavorites => 'المفضلة';

  @override
  String get conversationsNoMatch => 'لا توجد محادثات مطابقة';

  @override
  String get conversationsMuted => 'مكتومة';

  @override
  String conversationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة غير مقروءة',
      few: '$count رسائل غير مقروءة',
      two: 'رسالتان غير مقروءتين',
      one: 'رسالة واحدة غير مقروءة',
    );
    return '$_temp0';
  }

  @override
  String get conversationsNewMessage => 'رسالة جديدة';

  @override
  String get conversationsSearchPeople => 'ابحث عن شخص';

  @override
  String get chatGiftButton => 'أرسل هدية';

  @override
  String chatGiftTitle(String name) {
    return 'أرسل هدية إلى $name';
  }

  @override
  String get chatGiftQuantity => 'الكمية';

  @override
  String get chatGiftPick => 'اختر هدية';

  @override
  String chatGiftSendNamed(String gift) {
    return 'أرسل $gift';
  }

  @override
  String chatGiftYours(String gift) {
    return 'هديتك: $gift';
  }

  @override
  String chatGiftFrom(String name, String gift) {
    return 'هدية من $name: $gift';
  }

  @override
  String get chatGiftYoursCaption => 'هديتك';

  @override
  String chatGiftFromCaption(String name) {
    return 'هدية من $name';
  }

  @override
  String pkFinalRound(String time) {
    return 'الجولة الأخيرة $time';
  }

  @override
  String get livePreviewMuted => 'الصوت مكتوم';

  @override
  String livePreviewGiftSent(String name, String gift) {
    return '$gift من $name';
  }

  @override
  String get livePreviewGallery => 'المعرض';

  @override
  String livePreviewGalleryProgress(String have, String total) {
    return 'معرض الهدايا $have من $total';
  }

  @override
  String get livePreviewGuests => 'دعوة ضيوف';

  @override
  String get previewsHubLivePk2 => 'تحدّي PK فردي';

  @override
  String get previewsHubLivePk4 => 'تحدّي PK ثنائي';

  @override
  String get pkBattleStart => 'ابدأ المعركة';

  @override
  String get livePreviewPlayBattle => 'تشغيل حركة المعركة (تجربة)';

  @override
  String get livePreviewSimulateRound => 'محاكاة جولة كاملة';

  @override
  String get livePreviewJoinedLine => 'انضم إلى البث';

  @override
  String get livePreviewHostSettings => 'إعدادات المضيف';

  @override
  String get livePreviewChatTextSize => 'حجم خط الدردشة';

  @override
  String get livePreviewTextSmall => 'صغير';

  @override
  String get livePreviewTextMedium => 'متوسط';

  @override
  String get livePreviewTextLarge => 'كبير';

  @override
  String liveViewersTab(String count) {
    return 'المشاهدون $count';
  }

  @override
  String get liveRankingTab => 'ترتيب المساهمة';

  @override
  String get livePeriodDaily => 'يومية';

  @override
  String get livePeriodWeekly => 'أسبوعية';

  @override
  String get livePeriodMonthly => 'شهرية';

  @override
  String get liveRankingHelp => 'كيف يُحسب الترتيب؟';

  @override
  String get liveRankingHelpBody =>
      'يُرتَّب المستخدمون حسب النقاط التي جمعوها في الفترة المختارة. هدايا الجاذبية تحسب الهدايا التي استلموها (الجاذبية)، وهدايا الساحر تحسب هدايا الحظ التي أرسلوها (الساحر)، ولا يُخلط النظامان. ويبيّن العد التنازلي متى تنتهي الجولة الحالية.';

  @override
  String get liveRankingEmpty => 'أرسل الهدايا لتصبح من كبار الداعمين';

  @override
  String get liveRankingYou => 'أنت';

  @override
  String get liveGetRanked => 'ادخل الترتيب';

  @override
  String get livePeriodHourly => 'في الساعة';

  @override
  String get livePeriodPrevious => 'الفترة السابقة';

  @override
  String get livePeriodNext => 'الفترة التالية';

  @override
  String get liveCountdown => 'العد التنازلي';

  @override
  String get liveGiftFilter => 'فلتر الهدايا';

  @override
  String get liveGiftsAttraction => 'هدايا الجاذبية';

  @override
  String get liveGiftsWizard => 'هدايا الساحر';

  @override
  String get liveRankingList => 'قائمة الترتيب';

  @override
  String get livePeriodOverall => 'الكلي';

  @override
  String get liveRankingAllTime => 'الترتيب الكلي';

  @override
  String get liveHostRankingPlace => 'ترتيب هذا المضيف';

  @override
  String get liveHostRankingHelpBody =>
      'يُرتَّب المضيفون فيما بينهم حسب الهدايا التي استلموها في الفترة المختارة: هذه الساعة أو اليوم أو هذا الشهر أو الترتيب الكلي. ويبيّن العد التنازلي متى تنتهي الجولة الحالية.';

  @override
  String get levelsTitle => 'مستوياتي';

  @override
  String get levelsPreparing =>
      'المستويات قيد التجهيز. ستظهر نقاطك هنا عند تفعيل الهدايا والألعاب.';

  @override
  String get levelsFounderTitle => 'المؤسس ليس له مستوى';

  @override
  String get levelsFounderBody =>
      'حساب مؤسس Kabso Live لا يحمل مستوى، ولا يظهر له مستوى في أي مكان: الملف الشخصي والبث والدردشة والقوائم.';

  @override
  String get levelsUnavailable => 'غير مفعّل بعد';

  @override
  String get levelsUnavailableBody =>
      'هذا المستوى غير مفعّل بعد. ستظهر نقاطك ومستواك هنا عند تفعيله.';

  @override
  String get levelsNoLevel => 'لا يوجد مستوى بعد';

  @override
  String levelsLevelNumber(int number) {
    return 'المستوى $number';
  }

  @override
  String levelsPoints(String points) {
    return '$points نقطة';
  }

  @override
  String get levelsMax => 'أعلى مستوى';

  @override
  String get levelsCurrent => 'مستواك';

  @override
  String get levelsLoadError => 'تعذّر تحميل المستويات';

  @override
  String levelsLv(int number) {
    return 'Lv.$number';
  }

  @override
  String levelsNeedXp(String points) {
    return 'تحتاج $points خبرة للوصول إلى المستوى التالي';
  }

  @override
  String get levelsCategories => 'تصنيفات المستوى';

  @override
  String get levelsHowItGrows => 'كيف يرتفع';

  @override
  String get levelsTiers => 'الشارات والمستويات';

  @override
  String levelsTierRange(int from, int to) {
    return 'Lv.$from–$to';
  }

  @override
  String get levelsTierFrame => 'مع إطار الصورة';

  @override
  String get levelsTierCurrent => 'الحالي';

  @override
  String get levelsTierOpen => 'مفتوح';

  @override
  String get levelsTierLocked => 'مقفل';

  @override
  String get levelsTierUnlocked => 'تم الفتح';

  @override
  String levelsTierToUnlock(String points) {
    return 'تحتاج $points نقطة للفتح';
  }

  @override
  String levelsTierFrom(String points) {
    return 'من $points نقطة';
  }

  @override
  String get levelsTabAttractiveness => 'الجاذبية';

  @override
  String get levelsTabSupport => 'الدعم';

  @override
  String get levelsTabWizard => 'الساحر';

  @override
  String get levelsTabGaming => 'اللعب';

  @override
  String get navMoments => 'اللحظات';

  @override
  String get navMessages => 'الرسائل';

  @override
  String get demoDataTitle => 'بيانات تجريبية';

  @override
  String get demoDataBody =>
      'لنسخ التجربة فقط: تعرض الشاشات المصمَّمة ببيانات تجريبية معلَّمة حيث لا توجد خدمة بعد. إيقافها يخرج من الحساب التجريبي.';

  @override
  String get demoDataTry => 'جرّب ببيانات تجريبية';

  @override
  String get feedPostsLoadMoreFailed => 'تعذّر تحميل المزيد من المنشورات';

  @override
  String get feedPostLike => 'إعجاب';

  @override
  String get feedPostUnlike => 'إلغاء الإعجاب';

  @override
  String get feedPostSave => 'حفظ';

  @override
  String get feedPostUnsave => 'إلغاء الحفظ';

  @override
  String feedPostCommentCount(String count) {
    return '$count تعليق';
  }

  @override
  String feedPostShareCount(String count) {
    return '$count مشاركة';
  }

  @override
  String feedPostRepostedBy(String name) {
    return 'أعاد $name نشره';
  }

  @override
  String get feedPostPending => 'قيد المراجعة — يظهر لك وحدك حتى تتم مراجعته';

  @override
  String get feedPostHide => 'إخفاء هذا المنشور';

  @override
  String get feedPostHidden => 'أُخفي المنشور من خلاصتك';

  @override
  String get feedPostReport => 'الإبلاغ عن المنشور';

  @override
  String get feedPostReportTitle => 'لماذا تبلّغ عن هذا المنشور؟';

  @override
  String get feedPostReported => 'شكراً، وصلنا بلاغك';

  @override
  String get feedPostDelete => 'حذف المنشور';

  @override
  String get feedPostDeleteConfirm => 'حذف هذا المنشور نهائياً؟';

  @override
  String get feedPostDeleted => 'حُذف المنشور';

  @override
  String get reportReasonSpam => 'رسائل مزعجة';

  @override
  String get reportReasonNudity => 'عُري أو محتوى جنسي';

  @override
  String get reportReasonViolence => 'عنف';

  @override
  String get reportReasonHate => 'خطاب كراهية';

  @override
  String get reportReasonHarassment => 'تحرّش أو تنمّر';

  @override
  String get reportReasonIllegal => 'محتوى غير قانوني';

  @override
  String get reportReasonOther => 'سبب آخر';

  @override
  String get errorMediaUploadsUnavailable => 'رفع الصور غير متاح حالياً.';

  @override
  String get errorMediaInvalid => 'تعذّرت قراءة الصورة. جرّب صورة أخرى.';

  @override
  String get errorPinLimitReached => 'يمكنك تثبيت 3 منشورات فقط.';

  @override
  String get errorReportAlreadyResolved => 'تمت معالجة هذا البلاغ من قبل.';

  @override
  String get createTitle => 'منشور جديد';

  @override
  String get createShare => 'نشر';

  @override
  String get createTextHint => 'اكتب وصف المنشور…';

  @override
  String get createLocationHint => 'أضف موقعاً (اختياري)';

  @override
  String get createAddPhotos => 'إضافة صور';

  @override
  String get createRemovePhoto => 'إزالة الصورة';

  @override
  String createPhotoNumber(int index) {
    return '$index';
  }

  @override
  String createPhotoLabel(int index, int total) {
    return 'صورة $index من $total';
  }

  @override
  String createUploading(int current, int total) {
    return 'جارٍ رفع الصور ($current من $total)…';
  }

  @override
  String get createPublishing => 'جارٍ النشر…';

  @override
  String get createPosted => 'تم نشر منشورك';

  @override
  String get createPostedInReview => 'تم النشر. سيظهر للآخرين بعد مراجعة الصور';

  @override
  String get createPhotosReviewNote =>
      'المنشورات التي فيها صور تظهر للآخرين بعد مراجعتها.';

  @override
  String get createPhotoUnsupported =>
      'صيغة هذه الصورة غير مدعومة. استخدم JPEG أو PNG أو WebP.';

  @override
  String get createPhotoTooLarge => 'الصورة أكبر من 15 ميغابايت.';

  @override
  String createPhotoTooMany(int max) {
    return 'يمكنك إضافة $max صور كحدّ أقصى.';
  }

  @override
  String get createPhotoAccessDenied =>
      'لا يمكن الوصول إلى الصور. اسمح بالوصول من الإعدادات.';

  @override
  String get createUploadsUnavailable =>
      'رفع الصور غير متاح حالياً. أزل الصور لتنشر نصاً فقط، أو حاول لاحقاً.';

  @override
  String get createPhotoInvalid =>
      'تعذّرت معالجة إحدى الصور. أزلها وحاول مجدداً.';

  @override
  String get createSubtitle => 'شارك لحظاتك مع متابعيك';

  @override
  String get createClose => 'إغلاق';

  @override
  String get createDiscardTitle => 'تجاهل المنشور؟';

  @override
  String get createDiscardBody => 'سيُحذف النص والصور التي أضفتها.';

  @override
  String get createDiscard => 'تجاهل';

  @override
  String get createKeepEditing => 'متابعة التعديل';

  @override
  String get createAddMore => 'إضافة المزيد';

  @override
  String createUpTo(int max) {
    return 'حتى $max صور';
  }

  @override
  String get createEmoji => 'إضافة رمز تعبيري';

  @override
  String get createAddHashtag => 'إضافة وسم';

  @override
  String get createTypePhotos => 'صور';

  @override
  String get createSoon => 'قريباً';

  @override
  String get createPlaceTitle => 'الموقع';

  @override
  String get createPlaceSubtitle => 'إضافة موقع';

  @override
  String get createPlaceSave => 'حفظ';

  @override
  String get createAudienceTitle => 'من يمكنه مشاهدة المنشور؟';

  @override
  String get createAudiencePublic => 'عام - متاح للجميع';

  @override
  String get createAudiencePrivate => 'خاص - متابعوك فقط';

  @override
  String get createAudienceExplain =>
      'من يرى منشوراتك يتبع خصوصية حسابك. غيّرها من الإعدادات.';

  @override
  String get createAudienceSettings => 'فتح الإعدادات';

  @override
  String get createMentionTitle => 'إشارة إلى أشخاص';

  @override
  String get createMentionSubtitle => 'إضافة أشخاص';

  @override
  String get createMentionSome => 'أشرت إلى أشخاص في النص';

  @override
  String get createMentionSearchHint => 'ابحث باسم المستخدم أو الاسم';

  @override
  String get createMentionStart => 'اكتب لتبحث عن أشخاص';

  @override
  String get createMentionNone => 'لا نتائج';

  @override
  String get createMentionFailed => 'تعذّر البحث. حاول مرة أخرى.';

  @override
  String get createHashtagsTitle => 'إضافة وسوم';

  @override
  String get createAdvancedTitle => 'مزيد من الخيارات';

  @override
  String get createAdvancedSubtitle => 'التعليقات وعدد الإعجابات';

  @override
  String get createCommentsOn => 'السماح بالتعليقات';

  @override
  String get createWhoEveryone => 'الجميع يمكنهم التعليق';

  @override
  String get createWhoFollowers => 'متابعوك فقط';

  @override
  String get createWhoNobody => 'لا أحد';

  @override
  String get createHideLikes => 'إخفاء عدد الإعجابات';

  @override
  String get createMediaSubtitle => 'اختر صورة أو أكثر';

  @override
  String get createNext => 'التالي';

  @override
  String get createBack => 'رجوع';

  @override
  String get createTabAll => 'الكل';

  @override
  String get createTabVideo => 'فيديو';

  @override
  String get createSelected => 'تم تحديدها';

  @override
  String createSelectUpTo(int max) {
    return 'يمكنك تحديد حتى $max صور';
  }

  @override
  String get createStepMedia => 'الوسائط';

  @override
  String get createStepDetails => 'التفاصيل';

  @override
  String createStepOf(int step, int total, String label) {
    return 'الخطوة $step من $total: $label';
  }

  @override
  String get createLongPressReorder => 'اضغط مطولاً واسحب لترتيب الصور';

  @override
  String get createAiCaption => 'اقتراح وصف بالذكاء الاصطناعي';

  @override
  String get createHashtagsExample => 'مثل #البتراء #سفر #أردن';

  @override
  String get createLibraryUnsupported =>
      'معرض الصور غير متاح هنا. اختر الصور من جهازك.';

  @override
  String get createLibraryDenied =>
      'اسمح لكبسو بالوصول إلى صورك لتختار منها هنا، أو اختر من جهازك.';

  @override
  String get createLibraryFailed => 'تعذّر فتح معرض الصور.';

  @override
  String get createLibraryEmpty => 'لا توجد صور على هذا الجهاز.';

  @override
  String get createLibraryLimited => 'يرى كبسو بعض صورك فقط.';

  @override
  String get createLibraryManage => 'تعديل';

  @override
  String get createLibraryAllow => 'السماح بالوصول';

  @override
  String get createPickFromDevice => 'اختيار من الجهاز';

  @override
  String get createLibraryPhoto => 'صورة من المعرض';

  @override
  String get commentsEmpty => 'لا توجد تعليقات بعد';

  @override
  String get commentsEmptyHint => 'كن أول من يعلّق.';

  @override
  String get commentsFailed => 'تعذّر تحميل التعليقات.';

  @override
  String get commentsMoreFailed => 'تعذّر تحميل المزيد.';

  @override
  String commentsReplyingTo(String name) {
    return 'الرد على $name';
  }

  @override
  String get commentsCancelReply => 'إلغاء الرد';

  @override
  String get commentsClosed => 'التعليقات مغلقة على هذا المنشور.';

  @override
  String get commentsNotAllowed => 'لا يمكنك التعليق على هذا المنشور.';

  @override
  String get commentsPinned => 'مثبّت';

  @override
  String get commentsPin => 'تثبيت التعليق';

  @override
  String get commentsUnpin => 'إلغاء التثبيت';

  @override
  String get commentsDelete => 'حذف التعليق';

  @override
  String get commentsDeleteTitle => 'حذف التعليق؟';

  @override
  String get commentsDeleteWithReplies => 'ستُحذف الردود عليه أيضاً.';

  @override
  String get commentsDeleted => 'حُذف التعليق';

  @override
  String get commentsReport => 'الإبلاغ عن التعليق';

  @override
  String get commentsReportTitle => 'لماذا تبلّغ عن هذا التعليق؟';

  @override
  String get commentsMore => 'خيارات التعليق';

  @override
  String commentsMoreReplies(int count) {
    return 'عرض ردود أخرى ($count)';
  }

  @override
  String get commentsSortRelevant => 'الأكثر صلة';

  @override
  String get commentsSortNewest => 'الأحدث';

  @override
  String get commentsSortMenu => 'ترتيب التعليقات';

  @override
  String get commentsDislike => 'عدم إعجاب';

  @override
  String get commentsOpen => 'عرض التعليقات';

  @override
  String get postTitle => 'منشور';

  @override
  String get postUnavailableTitle => 'هذا المنشور غير متاح';

  @override
  String get postUnavailableBody => 'ربما حُذف، أو أن صاحبه لا يتيحه لك.';

  @override
  String get profileGridPinned => 'مثبّت';

  @override
  String get profileGridOpenPost => 'فتح المنشور';

  @override
  String get searchHint => 'ابحث عن أشخاص أو وسوم أو منشورات';

  @override
  String get searchClear => 'مسح';

  @override
  String get searchTabUsers => 'الحسابات';

  @override
  String get searchTabHashtags => 'الوسوم';

  @override
  String get searchTabPosts => 'المنشورات';

  @override
  String get searchPromptTitle => 'ابحث في كبسو';

  @override
  String get searchPromptBody => 'اكتب اسماً أو وسماً أو كلمة من منشور.';

  @override
  String searchNoResults(String query) {
    return 'لا نتائج لـ «$query»';
  }

  @override
  String hashtagPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منشور',
      many: '$count منشورًا',
      few: '$count منشورات',
      two: 'منشوران',
      one: 'منشور واحد',
      zero: 'لا منشورات',
    );
    return '$_temp0';
  }

  @override
  String get hashtagRecent => 'الأحدث';

  @override
  String get hashtagTop => 'الأكثر تفاعلاً';

  @override
  String get hashtagNotFoundTitle => 'لا منشورات بهذا الوسم';

  @override
  String get hashtagNotFoundBody => 'لم يُستخدم هذا الوسم في منشور ظاهر بعد.';

  @override
  String get hashtagEmpty => 'لا منشورات هنا بعد';

  @override
  String hashtagLabel(String tag) {
    return '#$tag';
  }

  @override
  String get safetyBlock => 'حظر';

  @override
  String safetyBlockUser(String name) {
    return 'حظر $name';
  }

  @override
  String safetyBlockTitle(String name) {
    return 'حظر $name؟';
  }

  @override
  String get safetyBlockBody =>
      'لن يرى أحدكما منشورات الآخر أو تعليقاته أو ملفه، وتُلغى المتابعة بينكما. يمكنك إلغاء الحظر من الإعدادات.';

  @override
  String safetyBlocked(String name) {
    return 'تم حظر $name';
  }

  @override
  String get safetyUnblock => 'إلغاء الحظر';

  @override
  String safetyUnblocked(String name) {
    return 'أُلغي حظر $name';
  }

  @override
  String safetyMuteUser(String name) {
    return 'كتم $name';
  }

  @override
  String safetyMuted(String name) {
    return 'تم كتم $name: لن تظهر منشوراته في خلاصتك';
  }

  @override
  String get safetyUndo => 'تراجع';

  @override
  String get safetyReportUser => 'الإبلاغ عن الحساب';

  @override
  String get safetyReportTitle => 'لماذا تبلّغ عن هذا الحساب؟';

  @override
  String get safetySection => 'الخصوصية والأمان';

  @override
  String get safetyPrivacy => 'الخصوصية';

  @override
  String get safetyBlockedAccounts => 'الحسابات المحظورة';

  @override
  String get safetyNoBlocked => 'لم تحظر أحداً';

  @override
  String get safetyNoBlockedBody =>
      'من تحظره يظهر هنا، ويمكنك إلغاء حظره متى شئت.';

  @override
  String get privacyMentionTitle => 'من يمكنه الإشارة إليك';

  @override
  String get privacyMentionEveryone => 'الجميع';

  @override
  String get privacyMentionFollowing => 'من تتابعهم فقط';

  @override
  String get privacyMentionNobody => 'لا أحد';

  @override
  String get privacyCommentTitle => 'من يمكنه التعليق على منشوراتك الجديدة';

  @override
  String get privacyCommentHint =>
      'يمكنك تغيير ذلك لكل منشور من «مزيد من الخيارات».';

  @override
  String get privacySaved => 'تم الحفظ';

  @override
  String get safetyMutedAccounts => 'الحسابات المكتومة';

  @override
  String get safetyNoMuted => 'لم تكتم أحداً';

  @override
  String get safetyNoMutedBody =>
      'من تكتمه يظهر هنا، ويمكنك إلغاء كتمه متى شئت. لا يعرف أحد أنك كتمته.';

  @override
  String get safetyUnmute => 'إلغاء الكتم';

  @override
  String safetyUnmuteUser(String name) {
    return 'إلغاء كتم $name';
  }

  @override
  String safetyUnmuted(String name) {
    return 'أُلغي كتم $name';
  }

  @override
  String get likersTitle => 'الإعجابات';

  @override
  String get likersOpen => 'عرض من أعجبه المنشور';

  @override
  String get likersEmpty => 'لا إعجابات بعد';

  @override
  String get likersEmptyBody => 'عندما يعجب أحد بهذا المنشور سيظهر هنا.';

  @override
  String get likersHiddenTitle => 'الإعجابات مخفية';

  @override
  String get likersHiddenBody =>
      'أخفى صاحب المنشور عدد الإعجابات، فلا يرى القائمة غيره.';

  @override
  String get feedPostRepost => 'إعادة النشر';

  @override
  String get feedPostUnrepost => 'إلغاء إعادة النشر';

  @override
  String get feedPostReposted => 'أُعيد نشره لمتابعيك';

  @override
  String get feedPostUnreposted => 'أُلغيت إعادة النشر';

  @override
  String get feedPostRepostRefused => 'لا يمكن إعادة نشر هذا المنشور';

  @override
  String get profileReposts => 'إعادات النشر';

  @override
  String get profileNoReposts => 'لا إعادات نشر بعد';

  @override
  String get profileRepostsEmptyBody => 'المنشورات التي تُعاد نشرها تظهر هنا.';

  @override
  String get feedPostPin => 'تثبيت في الملف الشخصي';

  @override
  String get feedPostUnpin => 'إلغاء التثبيت';

  @override
  String get feedPostPinned => 'ثُبّت في ملفك الشخصي';

  @override
  String get feedPostUnpinned => 'أُلغي التثبيت';

  @override
  String get feedPostEdit => 'تعديل';

  @override
  String feedPostTimeEdited(String time) {
    return '$time · معدّل';
  }

  @override
  String get editPostTitle => 'تعديل المنشور';

  @override
  String get editPostSave => 'حفظ';

  @override
  String get editPostSaved => 'حُفظت التعديلات';

  @override
  String get editPostPhotosFixed => 'لا يمكن تغيير الصور بعد النشر.';

  @override
  String get editPostTextRequired => 'المنشور النصي يحتاج إلى نص.';

  @override
  String get editPostDiscardTitle => 'تجاهل التعديلات؟';

  @override
  String get editPostKeep => 'متابعة التعديل';

  @override
  String get editPostDiscard => 'تجاهل';

  @override
  String get editPostNoPlace => 'بلا موقع';

  @override
  String get editPostRemovePlace => 'إزالة الموقع';

  @override
  String get createScheduleTitle => 'وقت النشر';

  @override
  String get createScheduleNow => 'الآن';

  @override
  String createScheduleAt(String date, String time) {
    return '$date، $time';
  }

  @override
  String get createScheduleAction => 'جدولة';

  @override
  String get createScheduleClear => 'النشر الآن';

  @override
  String get createScheduleWindow =>
      'اختر وقتاً بعد 5 دقائق على الأقل وخلال 30 يوماً.';

  @override
  String createScheduled(String when) {
    return 'سيُنشر في $when';
  }

  @override
  String get createSaveDraft => 'حفظ كمسودة';

  @override
  String get createDiscardOrDraftBody =>
      'احفظه كمسودة لتكمله لاحقاً، أو تجاهله.';

  @override
  String get createDraftSaved => 'حُفظت المسودة';

  @override
  String get draftsTitle => 'المسودات والمجدولة';

  @override
  String get draftsTabDrafts => 'المسودات';

  @override
  String get draftsTabScheduled => 'المجدولة';

  @override
  String get draftsEmpty => 'لا مسودات';

  @override
  String get draftsEmptyBody => 'عند إغلاق منشور يمكنك حفظه كمسودة.';

  @override
  String get scheduledEmpty => 'لا منشورات مجدولة';

  @override
  String get scheduledEmptyBody => 'اختر «وقت النشر» عند إنشاء منشور لجدولته.';

  @override
  String draftsSavedOn(String when) {
    return 'حُفظت $when';
  }

  @override
  String draftsPublishesOn(String when) {
    return 'يُنشر $when';
  }

  @override
  String get draftsNoText => 'بلا نص';

  @override
  String get draftsDeleteConfirm => 'حذف هذه المسودة؟';

  @override
  String get draftsDeleted => 'حُذفت';

  @override
  String get editPostPublishNow => 'انشر الآن';

  @override
  String get editPostSchedule => 'جدولة';

  @override
  String get editPostReschedule => 'تغيير الموعد';

  @override
  String get editPostToDrafts => 'نقل إلى المسودات';

  @override
  String get editPostPublished => 'نُشر المنشور';

  @override
  String get editPostMovedToDrafts => 'نُقل إلى المسودات';

  @override
  String get editPostDraftBadge => 'مسودة';

  @override
  String editPostScheduledBadge(String when) {
    return 'مجدول: $when';
  }

  @override
  String get storyYourStory => 'قصتك';

  @override
  String get storyAdd => 'أضف قصة';

  @override
  String storyOpen(String name) {
    return 'عرض قصة $name';
  }

  @override
  String get storyMore => 'خيارات القصة';

  @override
  String get storyClose => 'إغلاق';

  @override
  String get storyDelete => 'حذف القصة';

  @override
  String get storyDeleteConfirm => 'حذف هذه القصة؟';

  @override
  String get storyDeleted => 'حُذفت القصة';

  @override
  String get storyReport => 'الإبلاغ عن القصة';

  @override
  String get storyReportTitle => 'لماذا تبلّغ عن هذه القصة؟';

  @override
  String get storyReported => 'شكراً، وصلنا البلاغ';

  @override
  String storyPeopleOf(String name) {
    return 'قصص $name';
  }

  @override
  String storyPhotoOf(String name) {
    return 'قصة $name';
  }

  @override
  String storyViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشاهدة',
      many: '$count مشاهدة',
      few: '$count مشاهدات',
      two: 'مشاهدتان',
      one: 'مشاهدة واحدة',
      zero: 'لا مشاهدات',
    );
    return '$_temp0';
  }

  @override
  String get storyNoViewers => 'لم يشاهدها أحد بعد';

  @override
  String get storyNoViewersBody =>
      'يظهر هنا من يشاهد قصتك خلال 48 ساعة من نشرها.';

  @override
  String get storyNewTitle => 'قصة جديدة';

  @override
  String get storyNewBody => 'صورة واحدة تبقى 24 ساعة، ويمكنك إضافة نص قصير.';

  @override
  String get storyPickPhoto => 'اختر صورة';

  @override
  String get storyChangePhoto => 'تغيير الصورة';

  @override
  String get storyShare => 'شارك';

  @override
  String get storyShared => 'نُشرت قصتك';

  @override
  String get storyTextHint => 'أضف نصاً (اختياري)';

  @override
  String get storyPreview => 'معاينة القصة';

  @override
  String get storyArchiveTitle => 'أرشيف القصص';

  @override
  String get storyArchiveEmpty => 'لا قصص بعد';

  @override
  String get storyArchiveEmptyBody =>
      'تُحفظ قصصك هنا بعد انتهائها، ولا يراها غيرك.';

  @override
  String storyArchiveCell(String date) {
    return 'قصة $date';
  }

  @override
  String get storyOpenOwn => 'عرض قصتك';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String notificationsBell(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الإشعارات، $count إشعار غير مقروء',
      many: 'الإشعارات، $count إشعارًا غير مقروء',
      few: 'الإشعارات، $count إشعارات غير مقروءة',
      two: 'الإشعارات، إشعاران غير مقروءين',
      one: 'الإشعارات، إشعار واحد غير مقروء',
      zero: 'الإشعارات، لا جديد',
    );
    return '$_temp0';
  }

  @override
  String notifActors(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name و$count شخص آخر',
      many: '$name و$count شخصًا آخر',
      few: '$name و$count أشخاص آخرين',
      two: '$name وشخصان آخران',
      one: '$name وشخص آخر',
      zero: '$name',
    );
    return '$_temp0';
  }

  @override
  String notifLikePost(String who) {
    return 'أعجب $who بمنشورك';
  }

  @override
  String notifLikeComment(String who) {
    return 'أعجب $who بتعليقك';
  }

  @override
  String notifComment(String who) {
    return 'علّق $who على منشورك';
  }

  @override
  String notifReply(String who) {
    return 'ردّ $who على تعليقك';
  }

  @override
  String notifMentionPost(String who) {
    return 'أشار إليك $who في منشور';
  }

  @override
  String notifMentionComment(String who) {
    return 'أشار إليك $who في تعليق';
  }

  @override
  String notifMentionStory(String who) {
    return 'أشار إليك $who في قصة';
  }

  @override
  String notifFollow(String who) {
    return 'بدأ $who بمتابعتك';
  }

  @override
  String notifRepost(String who) {
    return 'أعاد $who نشر منشورك';
  }

  @override
  String get notifPostPublished => 'نُشر منشورك المجدول';

  @override
  String get notifRemovedPost => 'أُزيل منشورك لمخالفته إرشادات المجتمع';

  @override
  String get notifRemovedComment => 'أُزيل تعليقك لمخالفته إرشادات المجتمع';

  @override
  String get notifRemovedStory => 'أُزيلت قصتك لمخالفتها إرشادات المجتمع';

  @override
  String get notifSectionToday => 'اليوم';

  @override
  String get notifSectionWeek => 'هذا الأسبوع';

  @override
  String get notifSectionEarlier => 'سابقًا';

  @override
  String get notifUnread => 'غير مقروء';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notificationsEmptyBody =>
      'ستظهر هنا الإعجابات والتعليقات والإشارات والمتابعون الجدد.';

  @override
  String get notificationsMarkAllRead => 'تعيين الكل كمقروء';

  @override
  String get notificationsSettings => 'إعدادات الإشعارات';

  @override
  String get notifSettingLikes => 'الإعجابات';

  @override
  String get notifSettingLikesBody => 'على منشوراتك وتعليقاتك';

  @override
  String get notifSettingComments => 'التعليقات والردود';

  @override
  String get notifSettingMentions => 'الإشارات';

  @override
  String get notifSettingFollows => 'المتابعون الجدد';

  @override
  String get notifSettingReposts => 'إعادات النشر';

  @override
  String get notifSettingsHint =>
      'تظهر الإشعارات داخل التطبيق. يصلك دائمًا إشعار عند نشر منشور مجدول أو إزالة محتوى لك.';

  @override
  String get notifSettingsSaved => 'حُفظ';

  @override
  String get errorLiveHostingNotAllowed => 'لا يمكن لحسابك البث المباشر بعد.';

  @override
  String get errorLiveGuestsNotAllowed =>
      'يسمح المضيف بمشاهدة هذا البث للمسجّلين فقط.';

  @override
  String get createModePost => 'منشور';

  @override
  String get createModeStory => 'قصة';

  @override
  String get createModeLive => 'بث مباشر';

  @override
  String get goLiveTitleHint => 'أضف عنواناً للبث';

  @override
  String get goLiveTitleRequired => 'أضف عنواناً لبثك أولاً.';

  @override
  String get goLiveFlip => 'قلب';

  @override
  String get goLiveMic => 'الميكروفون';

  @override
  String get goLiveMicOff => 'مكتوم';

  @override
  String get goLiveGuests => 'الزوار';

  @override
  String get goLiveGuestsOnHint => 'يمكن لمن لا يملك حساباً المشاهدة';

  @override
  String get goLiveGuestsOffHint => 'المشاهدة للمسجّلين فقط';

  @override
  String get goLiveGuestsOn => 'سُمح للزوار بالمشاهدة';

  @override
  String get goLiveGuestsOff => 'أُخرج الزوار وأصبحت المشاهدة للمسجّلين فقط';

  @override
  String get goLiveNoCategory => 'بلا فئة';

  @override
  String get goLiveStart => 'ابدأ البث';

  @override
  String get goLiveStarting => 'جارٍ بدء البث…';

  @override
  String get goLiveEnd => 'إنهاء';

  @override
  String get goLiveEndConfirmTitle => 'إنهاء البث؟';

  @override
  String get goLiveEndConfirmBody => 'سيرى المشاهدون أن البث انتهى.';

  @override
  String get goLiveEndConfirm => 'إنهاء البث';

  @override
  String get goLiveKeepGoing => 'متابعة البث';

  @override
  String goLiveElapsed(String duration) {
    return 'مباشر منذ $duration';
  }

  @override
  String get goLiveEndedTitle => 'انتهى بثك';

  @override
  String goLiveEndedDuration(String duration) {
    return 'المدة $duration';
  }

  @override
  String get goLiveDone => 'تم';

  @override
  String get goLiveCameraDeniedTitle => 'اسمح بالكاميرا والميكروفون';

  @override
  String get goLiveCameraDeniedBody =>
      'يحتاجهما Kabso Live ليعرضك مباشرة. اسمح بالوصول من الإعدادات ثم حاول مجدداً.';

  @override
  String get goLiveCameraUnavailableTitle => 'الكاميرا غير متاحة';

  @override
  String get goLiveCameraUnavailableBody =>
      'لم يُعثر على كاميرا أو ميكروفون، أو يستخدمهما تطبيق آخر.';

  @override
  String get goLiveNotAllowedTitle => 'البث يحتاج حساب مضيف';

  @override
  String get goLiveNotAllowedBody =>
      'يبث المضيفون عبر وكالة مضيفين في Kabso Live أو بعد توثيق هويتهم. التسجيل قريباً.';

  @override
  String get goLiveUnavailableTitle => 'البث المباشر غير متاح بعد';

  @override
  String get goLiveModeSolo => 'بث مباشر';

  @override
  String get goLiveModeAudio => 'بث صوتي';

  @override
  String goLiveSeat(int number) {
    return 'مقعد $number';
  }

  @override
  String get goLiveHostTag => 'المضيف';

  @override
  String goLiveSeatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقعد',
      many: '$count مقعدًا',
      few: '$count مقاعد',
      two: 'مقعدان',
      one: 'مقعد واحد',
    );
    return '$_temp0';
  }

  @override
  String get goLiveBeauty => 'تجميل';

  @override
  String get goLiveBeautyTitle => 'التجميل';

  @override
  String get goLiveBeautySwitch => 'تشغيل التجميل';

  @override
  String get goLiveBeautySmooth => 'تنعيم البشرة';

  @override
  String get goLiveBeautyBrighten => 'إضاءة';

  @override
  String get goLiveBeautyUnsupported => 'التجميل غير متاح على هذا الجهاز بعد.';

  @override
  String get goLiveTheme => 'الثيم';

  @override
  String get goLiveThemeTitle => 'ثيم الغرفة';

  @override
  String get liveThemeClassic => 'كلاسيكي';

  @override
  String get liveThemeIcePalace => 'قصر الجليد';

  @override
  String get liveThemeDesertNight => 'ليل الصحراء';

  @override
  String get liveThemeRoseGarden => 'حديقة الورد';

  @override
  String get liveThemeSunsetSky => 'سماء الغروب';

  @override
  String get liveThemeMoonPalace => 'قصر القمر';

  @override
  String get liveThemeOceanDepths => 'أعماق المحيط';

  @override
  String get liveThemeGoldenHall => 'القاعة الذهبية';

  @override
  String get liveThemeGameArena => 'ساحة الألعاب';

  @override
  String get liveThemeHeartGarden => 'حديقة القلوب';

  @override
  String get liveThemeGalaxy => 'المجرة';

  @override
  String get goLiveGuestsAllowedChip => 'الزوار مسموح';

  @override
  String get goLiveGuestsOffChip => 'للمسجّلين فقط';

  @override
  String get liveSeatRequest => 'اطلب مقعداً';

  @override
  String get liveSeatRequested => 'تم الطلب · إلغاء';

  @override
  String get liveSeatLeave => 'مغادرة المقعد';

  @override
  String get liveSeatInviteTitle => 'دعوة للصعود';

  @override
  String liveSeatInviteBody(String name) {
    return 'يدعوك $name للصعود إلى مقعد.';
  }

  @override
  String get liveSeatInviteAccept => 'صعود';

  @override
  String get liveSeatInviteDecline => 'لاحقاً';

  @override
  String get liveHostAway => 'سيعود المضيف قريباً';

  @override
  String get liveSeatMutedByHost => 'كتمك المضيف';

  @override
  String get liveSeatCaptureFailed => 'تعذّر تشغيل الكاميرا أو الميكروفون.';

  @override
  String get liveSeatMute => 'كتم';

  @override
  String get liveSeatUnmute => 'إلغاء الكتم';

  @override
  String get liveSeatRemove => 'إنزال من المقعد';

  @override
  String get liveSeatLock => 'قفل المايك';

  @override
  String get liveSeatUnlock => 'فتح المايك';

  @override
  String get liveSeatInvite => 'دعوة مشاهد';

  @override
  String get liveSeatMakeModerator => 'تعيين مشرفاً';

  @override
  String get liveSeatRemoveModerator => 'إلغاء الإشراف';

  @override
  String get liveSeatModeratorTag => 'مشرف';

  @override
  String get liveSeatRequests => 'الطلبات';

  @override
  String get liveSeatRequestsTitle => 'طلبات الصعود';

  @override
  String get liveSeatRequestsEmpty => 'لا توجد طلبات الآن.';

  @override
  String get liveSeatAccept => 'قبول';

  @override
  String get liveSeatDecline => 'رفض';

  @override
  String get liveSeatInviteSheetTitle => 'دعوة إلى مقعد';

  @override
  String get liveSeatInviteEmpty => 'لا يوجد مشاهدون مسجّلون الآن.';

  @override
  String get liveSeatInviteSend => 'دعوة';

  @override
  String get liveSeatInvited => 'أُرسلت الدعوة';

  @override
  String get liveSeats => 'المقاعد';

  @override
  String get liveSeatsTitle => 'عدد المقاعد';

  @override
  String liveSeatGuestNumber(int number) {
    return 'زائر $number';
  }

  @override
  String get goLiveAudioHeadline => 'ابدأ البث الصوتي';

  @override
  String get goLiveAudioSubtitle => 'شارك صوتك وتواصل مع جمهورك';

  @override
  String get goLiveChooseCategory => 'اختر الفئة';

  @override
  String get goLiveWhoCanWatch => 'من يمكنه المشاهدة؟';

  @override
  String get goLiveWatchEveryone => 'الجميع';

  @override
  String get goLiveWatchEveryoneHint => 'حتى من لا يملك حساباً';

  @override
  String get goLiveWatchSignedIn => 'المسجّلون فقط';

  @override
  String get goLiveWatchSignedInHint => 'أصحاب الحسابات فقط';

  @override
  String get goLiveVoiceSettings => 'إعدادات الصوت';

  @override
  String get goLiveMicrophone => 'الميكروفون';

  @override
  String get goLiveMicrophoneHint => 'يمكنك كتمه في أي وقت';

  @override
  String get goLiveNoiseReduction => 'تقليل الضوضاء';

  @override
  String get goLiveNoiseReductionHint => 'صوت أنقى في الأماكن المزدحمة';

  @override
  String get goLiveVoiceEnhance => 'تحسين الصوت';

  @override
  String get goLiveVoiceEnhanceHint => 'مستوى متوازن بلا صدى';

  @override
  String get goLiveStartAudio => 'ابدأ البث الصوتي';

  @override
  String get goLiveChangeTheme => 'تغيير الثيم';

  @override
  String get goLiveSeatsSection => 'عدد المقاعد';

  @override
  String get goLiveMinimize => 'تصغير البث';

  @override
  String get liveBgChannel => 'البث المباشر';

  @override
  String get liveBgHostTitle => 'Kabso: أنت في بث مباشر';

  @override
  String get liveBgGuestTitle => 'أنت على مقعد في البث';

  @override
  String get liveBgListenerTitle => 'تستمع إلى بث مباشر';

  @override
  String get liveBgBody => 'اضغط للعودة إلى الغرفة';

  @override
  String get liveBgEnd => 'إنهاء البث';

  @override
  String get liveBgLeave => 'مغادرة';

  @override
  String get goLiveBackToLive => 'العودة إلى البث';

  @override
  String get goLiveAllCategories => 'عرض الكل';

  @override
  String goLiveRoomLook(String name) {
    return 'مظهر الغرفة: $name';
  }

  @override
  String get goLiveLiveType => 'نوع البث';

  @override
  String get goLiveMuteMic => 'كتم الصوت';

  @override
  String get goLiveUnmuteMic => 'تشغيل الصوت';

  @override
  String get goLiveChat => 'الدردشة';

  @override
  String get goLivePk => 'تحدي PK';

  @override
  String get goLivePkSoon => 'تحديات PK غير متاحة بعد.';

  @override
  String get goLiveChatHint => 'اكتب رسالة…';

  @override
  String get goLiveChatSend => 'إرسال';

  @override
  String get goLiveChatPill => 'دردشة…';

  @override
  String get goLiveShare => 'مشاركة';

  @override
  String goLiveShareText(String title, String handle) {
    return 'أنا مباشر الآن على Kabso Live: «$title» — تابعني $handle';
  }

  @override
  String get goLiveShareCopied => 'نُسخت دعوة البث، الصقها لمن تريد';

  @override
  String liveScore(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted نقطة',
      many: '$formatted نقطة',
      few: '$formatted نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا نقاط',
    );
    return '$_temp0';
  }

  @override
  String get liveScoreTitle => 'نقاط البث';

  @override
  String get liveScoreTaps => 'التكبيس';

  @override
  String get liveScoreSupport => 'الدعم';

  @override
  String get liveScoreHint =>
      'كل تكبيسة نقطة، وكل كوينزة دعم 100 نقطة. الدعم يبدأ مع الهدايا.';

  @override
  String get liveTapHint => 'اضغط على البث لتشجيع المضيف';

  @override
  String get errorLiveChatNotInRoom =>
      'أنت لست داخل هذا البث الآن. افتح البث من جديد.';

  @override
  String get errorLiveChatMuted =>
      'كتمك المضيف أو أحد المشرفين في دردشة هذا البث.';

  @override
  String get errorLiveChatClosed => 'أوقف المضيف الدردشة.';

  @override
  String get liveChatOff => 'الدردشة متوقفة';

  @override
  String get liveChatMutedPill => 'أنت مكتوم في دردشة هذا البث';

  @override
  String get liveChatSignIn => 'سجّل الدخول للمشاركة في الدردشة';

  @override
  String get liveChatFailed => 'لم تُرسل. اضغط لإعادة المحاولة';

  @override
  String get liveChatNewMessages => 'رسائل جديدة ↓';

  @override
  String get liveChatRetry => 'إعادة الإرسال';

  @override
  String get liveChatDiscard => 'حذف';

  @override
  String get liveChatHostBadge => 'المضيف';

  @override
  String get liveChatModeratorBadge => 'مشرف';

  @override
  String get liveChatViewProfile => 'عرض الملف الشخصي';

  @override
  String get liveChatDelete => 'حذف الرسالة';

  @override
  String get liveChatDeleted => 'حُذفت الرسالة';

  @override
  String liveChatMuteUser(String name) {
    return 'كتم $name في الدردشة';
  }

  @override
  String liveChatUnmuteUser(String name) {
    return 'إلغاء كتم $name';
  }

  @override
  String liveChatUserMuted(String name) {
    return 'كُتم $name في دردشة هذا البث';
  }

  @override
  String liveChatUserUnmuted(String name) {
    return 'أُلغي كتم $name';
  }

  @override
  String liveSeatMuteUser(String name) {
    return 'كتم مايك $name';
  }

  @override
  String liveSeatUnmuteUser(String name) {
    return 'إلغاء كتم مايك $name';
  }

  @override
  String liveSeatUserMuted(String name) {
    return 'كُتم مايك $name';
  }

  @override
  String liveSeatUserUnmuted(String name) {
    return 'أُلغي كتم مايك $name';
  }

  @override
  String get liveChatReport => 'الإبلاغ عن الرسالة';

  @override
  String get liveChatReportTitle => 'لماذا تبلغ عن هذه الرسالة؟';

  @override
  String get liveChatTurnedOff => 'أوقفت الدردشة. لا يستطيع المشاهدون الكتابة.';

  @override
  String get liveChatTurnedOn => 'الدردشة تعمل';

  @override
  String liveChatLineLabel(String name, String text) {
    return '$name: $text';
  }

  @override
  String liveChatCharmLabel(int level) {
    return 'مستوى الجاذبية $level';
  }

  @override
  String liveChatSupportLabel(int level) {
    return 'مستوى الدعم $level';
  }

  @override
  String liveChatFamilyLabel(String name, int level) {
    return 'العائلة $name، المستوى $level';
  }

  @override
  String liveChatMedalsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ميدالية',
      few: '$count ميداليات',
      two: 'ميداليتان',
      one: 'ميدالية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get liveChatTool => 'الدردشة';

  @override
  String get liveToolsRoom => 'أدوات الغرفة';

  @override
  String get liveToolsOther => 'أدوات أخرى';

  @override
  String get liveToolOn => 'يعمل';

  @override
  String get liveToolOff => 'متوقف';

  @override
  String get liveToolsVoice => 'الصوت';

  @override
  String get liveToolsViewers => 'المشاهدون';

  @override
  String get liveSeatGuestsTab => 'الضيوف';

  @override
  String get liveSeatGuestsEmpty => 'لا أحد على المقاعد الآن';

  @override
  String get liveSeatInviteFriends => 'ادعُ أصدقاءك';

  @override
  String get liveUserManage => 'إدارة';

  @override
  String get liveUserViewProfile => 'عرض الملف';

  @override
  String get liveUserFamily => 'العائلة';

  @override
  String get liveUserGiftWall => 'حائط الهدايا';

  @override
  String get liveUserMedals => 'الميداليات';

  @override
  String get liveUserSoon => 'قريباً';

  @override
  String liveUserBoxSoon(String box) {
    return '$box: قريباً';
  }

  @override
  String liveSeatNumberLabel(int number) {
    return 'المقعد $number';
  }

  @override
  String get liveEditRoom => 'تعديل الغرفة';

  @override
  String get liveEditRoomName => 'اسم الغرفة';

  @override
  String get liveEditRoomCategory => 'الفئة';

  @override
  String get liveEditRoomTopic => 'الموضوع';

  @override
  String get liveEditRoomTopicHint => 'عمّ تتحدثون الآن؟';

  @override
  String get liveEditRoomSave => 'حفظ';

  @override
  String get liveEditRoomSaved => 'حُفظت الغرفة';

  @override
  String liveRoomTopic(String topic) {
    return 'الموضوع: $topic';
  }

  @override
  String get liveContributionTab => 'قائمة المساهمة';

  @override
  String get liveContributionEmpty =>
      'لا مساهمات بعد. النقرات على البث تُحسب هنا.';

  @override
  String liveContributionRow(int rank, String name, String points) {
    return 'المرتبة $rank، $name، $points';
  }

  @override
  String get liveCoverEdit => 'تعديل';

  @override
  String get liveCoverEditLabel => 'تعديل صورة غلاف البث';

  @override
  String get liveCoverSheetTitle => 'صورة غلاف البث';

  @override
  String get liveCoverSheetBody => 'تظهر في بطاقة بثك وفي الغرفة، في كل بث.';

  @override
  String get liveCoverChoose => 'اختيار صورة';

  @override
  String get liveCoverRemove => 'إزالة الغلاف واستخدام صورتي';

  @override
  String get liveCoverUpdated => 'تم تحديث غلاف البث.';

  @override
  String get liveCoverRemoved => 'أُزيل الغلاف؛ ستظهر صورتك.';

  @override
  String get liveCoverUploading => 'جارٍ رفع الغلاف…';

  @override
  String get liveSettingsShare => 'مشاركة';

  @override
  String get liveSettingsBlockedWords => 'الكلمات المحظورة';

  @override
  String get liveSettingsSchedule => 'جدول البث';

  @override
  String get liveSettingsEventCenter => 'مركز الفعاليات';

  @override
  String get liveSettingsCreatorCenter => 'مركز صنّاع المحتوى';

  @override
  String get liveSoon => 'قريباً';

  @override
  String get liveRoomInfoChange => 'تغيير';

  @override
  String get liveRoomLevel => 'مستوى الغرفة';

  @override
  String get liveRoomSettings => 'إعدادات الغرفة';

  @override
  String get liveRoomTag => 'الوسم';

  @override
  String get liveRoomNoTag => 'بلا وسم';

  @override
  String get liveRoomAnnouncement => 'الإعلان';

  @override
  String get liveRoomBoost => 'تعزيز غرفتي';

  @override
  String get liveBlockedWordsHint =>
      'تُخفى هذه الكلمات بنجوم (***) في دردشة كل بثوثك.';

  @override
  String get liveBlockedWordsAddHint => 'أضف كلمة أو عبارة قصيرة';

  @override
  String get liveBlockedWordsAdd => 'إضافة';

  @override
  String get liveBlockedWordsFull => 'وصلت إلى 100 كلمة';

  @override
  String get liveBlockedWordsEmpty => 'لا كلمات محظورة بعد.';

  @override
  String liveBlockedWordsRemove(String word) {
    return 'إزالة $word';
  }

  @override
  String get liveRankTitle => 'ترتيب الشعبية';

  @override
  String get liveRankRich => 'الأغنى';

  @override
  String get liveRankHour => 'هذه الساعة';

  @override
  String get liveRankDay => 'اليوم';

  @override
  String get liveRankWeek => 'هذا الأسبوع';

  @override
  String get liveRankEmpty => 'لا نقاط بعد في هذه الفترة.';

  @override
  String get liveRankLive => 'مباشر';

  @override
  String get liveRankChip => 'ترتيب الغرف';

  @override
  String liveRankCountdown(String days, String hours, String minutes) {
    return 'ينتهي خلال: $daysي $hoursس $minutesد';
  }

  @override
  String liveRankRow(int rank, String name, String points) {
    return 'المرتبة $rank، $name، $points';
  }

  @override
  String notifLiveScheduled(String who, String time) {
    return 'يبدأ $who بثًا مباشرًا الساعة $time';
  }

  @override
  String get notifSettingLives => 'البثوث المجدولة';

  @override
  String get notifSettingLivesBody => 'عندما يقترب موعد بث لمضيف تتابعه';

  @override
  String get errorLiveScheduleFull => 'يمكنك جدولة 10 بثوث كحد أقصى.';

  @override
  String get liveScheduleHint =>
      'يصل لمتابعيك تذكير قبل الموعد بـ15 دقيقة. البث نفسه تبدؤه أنت.';

  @override
  String get liveScheduleEmpty => 'لا بثوث مجدولة.';

  @override
  String get liveScheduleAdd => 'جدولة بث';

  @override
  String get liveScheduleTitleHint => 'عنوان البث';

  @override
  String get liveSchedulePickTime => 'اختر التاريخ والوقت';

  @override
  String get liveScheduleSave => 'حفظ';

  @override
  String get liveScheduleTooSoon => 'اختر وقتًا بعد 15 دقيقة على الأقل.';

  @override
  String get liveScheduleTooFar => 'اختر وقتًا خلال 30 يومًا.';

  @override
  String liveScheduleRemove(String title) {
    return 'إلغاء $title';
  }

  @override
  String liveScheduleWhen(String date, String time) {
    return '$date، $time';
  }

  @override
  String liveRoomNumber(String number) {
    return 'المعرّف: $number';
  }

  @override
  String liveRoomLevelBadge(int level) {
    return 'مستوى الغرفة $level';
  }

  @override
  String get liveToolMusic => 'موسيقى';

  @override
  String get liveToolSounds => 'المؤثرات';

  @override
  String get liveToolProgramList => 'قائمة البرامج';

  @override
  String get liveToolShareScreen => 'مشاركة الشاشة';

  @override
  String get liveToolYoutube => 'يوتيوب';

  @override
  String get liveToolSinging => 'غناء';

  @override
  String get liveToolTopic => 'الموضوع';

  @override
  String get liveToolManagement => 'الإدارة';

  @override
  String get liveToolAssistance => 'مساعد البث';

  @override
  String get liveToolRecorder => 'التسجيل';

  @override
  String get liveToolsFailed => 'تعذّر ذلك الآن. حاول مرة أخرى.';

  @override
  String get liveToolsCancel => 'إلغاء';

  @override
  String get liveToolsClose => 'إغلاق';

  @override
  String get liveCam2JoinTile => 'كاميرا ثانية';

  @override
  String get liveSecondCameraJoin => 'الانضمام ككاميرا ثانية';

  @override
  String get liveCam2Intro =>
      'بُثّ من جهازين: هذا الهاتف، وكاميرا ثانية على هاتف أو جهاز لوحي آخر بالحساب نفسه.';

  @override
  String get liveCam2Steps =>
      'على الجهاز الثاني: سجّل الدخول بالحساب نفسه، افتح «بث مباشر» ثم «الانضمام ككاميرا ثانية»، وأدخل الرمز.';

  @override
  String get liveCam2Layout =>
      'يرى المشاهدون صورة كبيرة وصورة صغيرة يمكن سحبها، ويبدّلون بينهما بلمسة.';

  @override
  String get liveCam2CreateCode => 'إنشاء رمز الاقتران';

  @override
  String get liveCam2CodeLabel => 'رمز الاقتران';

  @override
  String liveCam2CodeExpires(String time) {
    return 'ينتهي خلال $time';
  }

  @override
  String get liveCam2CodeOnce => 'يُستخدم مرة واحدة، وبحسابك فقط.';

  @override
  String get liveCam2CodeExpired => 'انتهت صلاحية الرمز. أنشئ رمزاً جديداً.';

  @override
  String get liveCam2NewCode => 'رمز جديد';

  @override
  String get liveCam2Cancel => 'إلغاء الرمز';

  @override
  String get liveCam2Waiting => 'في انتظار اتصال الجهاز الثاني…';

  @override
  String get liveCam2Connected => 'الكاميرا الثانية متصلة';

  @override
  String get liveCam2MainLabel => 'الصورة الكبيرة للمشاهدين';

  @override
  String get liveCam2MainHost => 'هذا الهاتف';

  @override
  String get liveCam2MainSecond => 'الكاميرا الثانية';

  @override
  String get liveCam2MainNote =>
      'يستطيع كل مشاهد التبديل بين الصورتين على شاشته.';

  @override
  String get liveCam2End => 'فصل الكاميرا الثانية';

  @override
  String get liveCam2NotLive => 'ابدأ البث أولاً، ثم وصّل جهازك الثاني.';

  @override
  String get liveCam2InPk =>
      'الكاميرا الثانية غير متاحة أثناء PK. وصّلها من جديد بعد انتهاء PK.';

  @override
  String get liveCam2NotSolo =>
      'الكاميرا الثانية متاحة في البث الفردي بالفيديو فقط.';

  @override
  String get liveCam2Busy => 'لهذا البث كاميرا ثانية بالفعل.';

  @override
  String get liveCam2Unavailable =>
      'لا يمكن إضافة كاميرا ثانية لهذا البث الآن: انتهى البث أو هو في PK.';

  @override
  String get liveCam2Swap => 'تبديل الكاميرتين';

  @override
  String get liveCam2JoinIntro =>
      'سجّل الدخول بالحساب نفسه الذي تبثّ منه، ثم أدخل الرمز الظاهر في «كاميرتان» على جهازك الرئيسي.';

  @override
  String get liveCam2JoinPermissions =>
      'سيطلب Kabso Live إذن الكاميرا والميكروفون. يبدأ الميكروفون مكتوماً، ولا تظهر الدردشة على هذا الجهاز.';

  @override
  String get liveCam2JoinButton => 'انضمام';

  @override
  String get liveCam2CodeInvalid =>
      'الرمز غير صحيح أو انتهت صلاحيته. أنشئ رمزاً جديداً على جهازك الرئيسي.';

  @override
  String get liveCam2TooMany => 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.';

  @override
  String get liveCam2Failed => 'تعذّر الاتصال. حاول مرة أخرى.';

  @override
  String get liveCam2PermissionDenied =>
      'اسمح لتطبيق Kabso Live باستخدام الكاميرا والميكروفون من إعدادات الجهاز.';

  @override
  String get liveCam2OnAir => 'كاميرا ثانية · مباشر';

  @override
  String get liveCam2Connecting => 'جارٍ الاتصال…';

  @override
  String get liveCam2Flip => 'قلب';

  @override
  String get liveCam2MicOn => 'تشغيل الصوت';

  @override
  String get liveCam2MicOff => 'كتم الصوت';

  @override
  String get liveCam2Leave => 'مغادرة';

  @override
  String get liveCam2KeepOpen =>
      'أبقِ هذه الشاشة مفتوحة، فهي تبقى مضاءة أثناء البث. إذا خرجت من التطبيق تتوقف هذه الكاميرا مؤقتاً حتى تعود.';

  @override
  String get liveCam2CopyLog => 'نسخ سجل التشخيص';

  @override
  String get liveCam2LogCopied => 'تم نسخ سجل التشخيص. الصقه في رسالة للدعم.';

  @override
  String get liveCam2AwakeFailed =>
      'تعذّر إبقاء الشاشة مضاءة تلقائياً. المس الشاشة من حين لآخر كي لا تنطفئ.';

  @override
  String get liveCam2BackgroundFailed =>
      'تعذّر تشغيل خدمة البث في الخلفية. أبقِ التطبيق مفتوحاً على هذه الشاشة.';

  @override
  String get liveCam2CameraSlow =>
      'الكاميرا لا تستجيب الآن. إن بقيت الصورة متوقفة فاضغط «قلب» أو غادر وانضم من جديد.';

  @override
  String get liveCam2FilterFailed =>
      'تعذّر تطبيق الفلتر على هذا الجهاز، فبقيت الصورة بدون فلتر.';

  @override
  String get liveCam2Ended =>
      'انتهت الكاميرا الثانية: انتهى البث أو فُصلت من الجهاز الرئيسي.';

  @override
  String get liveMusicRightsTitle => 'حقوق الموسيقى';

  @override
  String get liveMusicRightsBody =>
      'تأكد أنك تملك حقوق تشغيل الموسيقى. يُمنع تشغيل موسيقى محمية بحقوق النشر بدون ترخيص.';

  @override
  String get liveMusicRightsAccept => 'أؤكد ذلك';

  @override
  String get liveMusicAdd => 'إضافة ملفات صوتية';

  @override
  String get liveMusicPickerNote =>
      'يفتح منتقي الملفات في جهازك؛ لا يرى Kabso Live إلا الملفات التي تختارها، ولا تُرفع إلى الخادم.';

  @override
  String get liveMusicMixNote =>
      'تُمزج الموسيقى تحت صوتك في بثك، وتنخفض حين تتكلم. لا تسمعها أنت من سماعة هاتفك، وكتم الميكروفون يكتمها أيضاً.';

  @override
  String get liveMusicEmpty =>
      'لا توجد موسيقى بعد. لن يُشغَّل شيء حتى تختار ملفاً وتضغط تشغيل.';

  @override
  String get liveMusicNothing => 'لا شيء يُشغَّل';

  @override
  String get liveMusicPlay => 'تشغيل';

  @override
  String get liveMusicPause => 'إيقاف مؤقت';

  @override
  String get liveMusicNext => 'التالي';

  @override
  String get liveMusicRemove => 'إزالة';

  @override
  String get liveMusicVolume => 'مستوى الموسيقى';

  @override
  String get liveMusicDucking => 'خفض الموسيقى حين أتكلم';

  @override
  String liveMusicQueueFull(int max) {
    return 'القائمة ممتلئة (حتى $max ملفاً).';
  }

  @override
  String get liveMusicUnreadable => 'تعذّر تشغيل هذا الملف.';

  @override
  String get liveMusicNotReady =>
      'الموسيقى تُمزج في ميكروفون البث: افتح الميكروفون وانتظر بدء البث ثم شغّلها.';

  @override
  String get liveMusicUnsupportedFormat =>
      'هاتفك لا يدعم صيغة هذا الملف. جرّب ملف MP3 أو M4A.';

  @override
  String get liveMusicMicOff => 'الميكروفون مكتوم: لن يسمع المشاهدون الموسيقى.';

  @override
  String get liveMusicUnsupportedIos =>
      'الموسيقى غير متاحة على iOS في هذا الإصدار: مزج الملف داخل ميكروفون البث يحتاج وحدة صوت خاصة بـ iOS لم تُبنَ بعد.';

  @override
  String get liveMusicUnsupportedWeb =>
      'الموسيقى غير متاحة في نسخة الويب. استخدم تطبيق أندرويد.';

  @override
  String get liveClipTitle => 'تسجيل مقطع';

  @override
  String get liveClipIntro =>
      'سجّل حتى ٦٠ ثانية من بثك كما يراه المشاهدون: كاميرتك وصوتك. يمكنك الإيقاف قبل ذلك.';

  @override
  String get liveClipTransparency =>
      'يرى المشاهدون «يتم التسجيل» أثناء التسجيل.';

  @override
  String get liveClipLimits =>
      'لا يتضمّن المقطع الكاميرا الثانية ولا الموسيقى ولا التعليقات والهدايا على الشاشة.';

  @override
  String get liveClipStart => 'ابدأ التسجيل';

  @override
  String get liveClipStop => 'إيقاف التسجيل';

  @override
  String get liveClipRec => 'تسجيل';

  @override
  String liveClipRecSemantics(int seconds) {
    return 'يتم التسجيل، بقي $seconds ثانية';
  }

  @override
  String get liveClipViewerBadge => 'يتم التسجيل';

  @override
  String get liveClipPreviewTitle => 'مقطعك';

  @override
  String get liveClipCaption => 'وصف (اختياري)';

  @override
  String get liveClipSave => 'حفظ في الجهاز';

  @override
  String get liveClipSavedShort => 'محفوظ';

  @override
  String get liveClipSaved => 'حُفظ المقطع في معرض الصور.';

  @override
  String get liveClipSaveFailed =>
      'تعذّر الحفظ. اسمح لتطبيق Kabso Live بإضافة الصور والفيديو من الإعدادات.';

  @override
  String get liveClipPostReel => 'نشر كريلز';

  @override
  String get liveClipPostFailed => 'تعذّر النشر. المقطع باقٍ، حاول مجدداً.';

  @override
  String get liveClipDiscard => 'تجاهل';

  @override
  String get liveClipFailed => 'تعذّر بدء التسجيل على هذا الجهاز.';

  @override
  String get liveClipTooShort => 'المقطع أقصر من ثانية؛ سجّل مقطعاً أطول.';

  @override
  String get liveClipUnreadable => 'تعذّرت قراءة المقطع.';

  @override
  String get liveClipUnsupportedIos =>
      'تسجيل المقاطع غير متاح على iOS في هذا الإصدار: مسجّل WebRTC هناك لا يلتقط صوت البث.';

  @override
  String get liveClipUnsupportedWeb => 'تسجيل المقاطع غير متاح في نسخة الويب.';

  @override
  String get liveClipNoCamera => 'شغّل الكاميرا لتسجيل مقطع.';

  @override
  String get liveToolNewcomers => 'الجدد';

  @override
  String get liveToolDataCenter => 'مركز البيانات';

  @override
  String get liveToolLiveTime => 'وقت البث';

  @override
  String get errorInsufficientCoins =>
      'تحتاج 10,000 عملة لإرسال رسالة عامة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.';

  @override
  String get liveBulletToggle => 'رسالة عامة';

  @override
  String liveBulletHint(String price, String coins) {
    return 'رسالة عامة بـ $price عملة · رصيدك $coins';
  }

  @override
  String liveBulletHintNoBalance(String price) {
    return 'رسالة عامة بـ $price عملة';
  }

  @override
  String get liveBulletSent => 'أُرسلت رسالتك العامة إلى كل البثوث';

  @override
  String liveBulletLabel(String name, String text) {
    return 'رسالة عامة من $name: $text';
  }

  @override
  String get liveVoiceRecord => 'مقطع صوتي';

  @override
  String get liveVoiceSend => 'إرسال المقطع الصوتي';

  @override
  String get liveVoiceCancel => 'إلغاء التسجيل';

  @override
  String liveVoiceRecording(String time) {
    return 'جارٍ التسجيل $time من 0:30';
  }

  @override
  String get liveVoiceDenied =>
      'اسمح باستخدام الميكروفون من الإعدادات لإرسال مقاطع صوتية.';

  @override
  String get liveVoiceUnavailable => 'الميكروفون غير متاح الآن.';

  @override
  String get liveVoiceUploadsUnavailable =>
      'إرسال الرسائل الصوتية غير متاح حالياً.';

  @override
  String get liveRoomRulesNotice =>
      'مرحباً بك في Kabso Live. يُمنع نشر أي محتوى مسيء أو مخالف لإرشادات المجتمع، وفريق الإشراف يتابع البث على مدار الساعة.';

  @override
  String get liveRoomRulesLabel => 'تنبيه من Kabso Live';

  @override
  String get liveVoiceTooLarge => 'المقطع الصوتي كبير جداً. سجّل مقطعاً أقصر.';

  @override
  String get liveVoiceLiveMicPaused => 'مايك البث متوقف مؤقتاً أثناء التسجيل';

  @override
  String get liveVoiceLiveMicBusy =>
      'تعذّر إيقاف مايك البث مؤقتاً، لذلك لا يمكن تسجيل مقطع صوتي الآن.';

  @override
  String get liveVoicePlayFailed => 'تعذّر تشغيل هذا المقطع الصوتي.';

  @override
  String get liveVoiceSilent =>
      'لم يُلتقط أي صوت في هذا المقطع، لذلك لم يُرسل. حاول مرة أخرى.';

  @override
  String get liveChatPrivateMessages => 'الرسائل الخاصة';

  @override
  String get liveChatPicture => 'صورة';

  @override
  String get liveChatSending => 'جارٍ الإرسال…';

  @override
  String liveChatVoiceLine(String name, String duration) {
    return '$name: مقطع صوتي، $duration';
  }

  @override
  String liveChatPictureLine(String name) {
    return '$name: صورة';
  }

  @override
  String get liveChatPlay => 'تشغيل';

  @override
  String get liveChatPause => 'إيقاف مؤقت';

  @override
  String get errorLiveKicked =>
      'تم إخراجك من هذا البث. يمكنك مشاهدة البث التالي للمضيف.';

  @override
  String get liveKickedTitle => 'تم إخراجك من هذا البث';

  @override
  String get liveKickedBody =>
      'أخرجك المضيف أو أحد المشرفين، ولا يمكنك العودة إليه حتى ينتهي. يمكنك مشاهدة البث التالي للمضيف.';

  @override
  String get liveUserPoints => 'النقاط في هذا البث';

  @override
  String liveUserRank(String rank) {
    return 'المركز $rank في هذا البث';
  }

  @override
  String get liveUserNoPoints => 'لا نقاط في هذا البث بعد';

  @override
  String get liveUserKick => 'إخراج من البث';

  @override
  String liveUserKickTitle(String name) {
    return 'إخراج $name من هذا البث؟';
  }

  @override
  String get liveUserKickBody =>
      'سيخرج من البث الآن ولن يستطيع العودة حتى ينتهي.';

  @override
  String get liveUserKickConfirm => 'إخراج';

  @override
  String liveUserKicked(String name) {
    return 'تم إخراج $name من هذا البث';
  }

  @override
  String liveUserModeratorAdded(String name) {
    return '$name أصبح مشرفاً';
  }

  @override
  String liveUserModeratorRemoved(String name) {
    return '$name لم يعد مشرفاً';
  }

  @override
  String get liveUserMore => 'المزيد';

  @override
  String get liveUserCp => 'العلاقة';

  @override
  String get liveUserNone => 'لا يوجد';

  @override
  String get liveUserFamilyNone => 'ليس في عائلة بعد';

  @override
  String get liveUserFamilyNoneSelf => 'لست في عائلة بعد';

  @override
  String get liveUserFamilyHint => 'انضم لعائلة أو أنشئ عائلتك';

  @override
  String get liveUserCpNone => 'لا يوجد شريك بعد';

  @override
  String get liveUserCpBar =>
      'هدايا CP قريباً: أرسلها لشخص مميّز لتصبحا ثنائياً';

  @override
  String get liveUserCpPartner => 'مكان الشريك فارغ';

  @override
  String get liveBulletTag => 'رسالة عامة';

  @override
  String get errorAlreadyInFamily =>
      'أنت في عائلة بالفعل. يمكنك أن تكون في عائلة واحدة فقط.';

  @override
  String get errorFamilyFull => 'هذه العائلة ممتلئة ولا تقبل أعضاء جدداً.';

  @override
  String get errorFamilyNameTaken =>
      'هذا الاسم مستخدم لعائلة أخرى. لم تُخصم أي عملات.';

  @override
  String get errorFamilyRequestPending =>
      'لديك طلب انضمام معلّق لعائلة أخرى. ألغِه أولاً.';

  @override
  String get errorFamilyRequestNotPending =>
      'تمت معالجة هذا الطلب أو أُلغي أو انتهت صلاحيته.';

  @override
  String get errorFamilyNotEmpty =>
      'يمكنك حلّ العائلة فقط عندما تكون العضو الوحيد فيها.';

  @override
  String get errorFamilyLeaderCannotLeave =>
      'القائد لا يغادر العائلة: سلّمها لعضو آخر أو حلّها.';

  @override
  String get errorCpAlreadyPaired =>
      'أنت أو هذا الشخص لديه شريك بالفعل. لم تُخصم أي عملات.';

  @override
  String get errorCpRequestPending =>
      'لديك طلب علاقة معلّق. ألغِه من صفحة العلاقة أولاً.';

  @override
  String get errorCpRequestNotPending =>
      'تمت معالجة طلب العلاقة هذا أو أُلغي أو انتهت صلاحيته.';

  @override
  String get errorCpNotPaired => 'ليس لديك شريك الآن. لم تُخصم أي عملات.';

  @override
  String get errorMedalNotUnlocked => 'اختر فقط الميداليات التي حصلت عليها.';

  @override
  String bondsCoins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملة',
      many: '$count عملة',
      few: '$count عملات',
      two: 'عملتان',
      one: 'عملة واحدة',
    );
    return '$_temp0';
  }

  @override
  String bondsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String bondsBalance(String coins) {
    return 'رصيدك: $coins';
  }

  @override
  String get bondsConfirm => 'تأكيد';

  @override
  String get bondsCancel => 'إلغاء';

  @override
  String get familiesTitle => 'العائلات';

  @override
  String get familiesSearchHint => 'ابحث بالاسم أو الرقم';

  @override
  String get familiesMine => 'عائلتي';

  @override
  String get familiesCreate => 'أنشئ عائلة';

  @override
  String get familiesTop => 'أفضل العائلات';

  @override
  String get familiesResults => 'نتائج البحث';

  @override
  String get familiesEmpty => 'لا توجد عائلات بعد';

  @override
  String get familiesEmptyBody => 'كن أول من ينشئ عائلة.';

  @override
  String get familiesNoMatch => 'لا توجد عائلة مطابقة';

  @override
  String get familiesNoMatchBody =>
      'جرّب اسماً آخر أو رقم العائلة المكوّن من 8 أرقام.';

  @override
  String get familiesLoadError => 'تعذّر تحميل العائلات';

  @override
  String get familiesNumberNotFound => 'لا توجد عائلة بهذا الرقم';

  @override
  String familyNumber(String number) {
    return 'رقم العائلة $number';
  }

  @override
  String familyLevel(int level) {
    return 'مستوى $level';
  }

  @override
  String familyMembersCount(int count, int capacity) {
    return 'الأعضاء $count / $capacity';
  }

  @override
  String familyPendingRequest(String name) {
    return 'طلبك للانضمام إلى $name قيد الانتظار';
  }

  @override
  String get familyCancelRequest => 'إلغاء الطلب';

  @override
  String get familyRequestCancelled => 'تم إلغاء طلب الانضمام';

  @override
  String get familyNotFoundTitle => 'العائلة غير موجودة';

  @override
  String get familyNotFoundBody => 'ربما تم حلّ هذه العائلة.';

  @override
  String get familyLoadError => 'تعذّر تحميل العائلة';

  @override
  String familyPoints(String points) {
    return 'النقاط: $points';
  }

  @override
  String familyProgress(String points, String next, int level) {
    return '$points / $next للوصول إلى المستوى $level';
  }

  @override
  String get familyTopLevel => 'وصلت العائلة إلى أعلى مستوى';

  @override
  String familyLeader(String name) {
    return 'القائد: $name';
  }

  @override
  String get familyJoin => 'اطلب الانضمام';

  @override
  String get familyJoinSent =>
      'تم إرسال طلب الانضمام. يرد عليه القائد أو النواب.';

  @override
  String get familyRequested => 'تم إرسال الطلب';

  @override
  String get familyFullLabel => 'العائلة ممتلئة';

  @override
  String get familyInOther => 'أنت عضو في عائلة أخرى';

  @override
  String get familyLeave => 'مغادرة العائلة';

  @override
  String familyLeaveTitle(String name) {
    return 'مغادرة $name؟';
  }

  @override
  String get familyLeaveBody => 'تبقى النقاط التي قدّمتها مع العائلة.';

  @override
  String get familyLeft => 'غادرت العائلة';

  @override
  String get familyManage => 'إدارة العائلة';

  @override
  String get familyChangeEmblem => 'تغيير الشعار';

  @override
  String get familyRemoveEmblem => 'إزالة الشعار';

  @override
  String get familyEmblemUpdated => 'تم تحديث الشعار';

  @override
  String get familyEmblemRemoved => 'تمت إزالة الشعار';

  @override
  String get familyDisband => 'حلّ العائلة';

  @override
  String familyDisbandTitle(String name) {
    return 'حلّ $name؟';
  }

  @override
  String get familyDisbandBody => 'يصبح الاسم متاحاً لغيرك ولا تُسترد العملات.';

  @override
  String get familyDisbanded => 'تم حلّ العائلة';

  @override
  String get familyDisbandOnlyAlone => 'يمكنك الحلّ عندما تكون العضو الوحيد';

  @override
  String get familyRequestsTitle => 'طلبات الانضمام';

  @override
  String get familyRequestsEmpty => 'لا توجد طلبات حالياً';

  @override
  String get familyAccept => 'قبول';

  @override
  String get familyDecline => 'رفض';

  @override
  String familyAccepted(String name) {
    return 'انضم $name إلى العائلة';
  }

  @override
  String get familyDeclined => 'تم رفض الطلب';

  @override
  String get familyMembersTitle => 'الأعضاء';

  @override
  String get familyRoleLeader => 'القائد';

  @override
  String get familyRoleDeputy => 'نائب';

  @override
  String get familyRoleMember => 'عضو';

  @override
  String get familyMakeDeputy => 'تعيين نائباً';

  @override
  String get familyMakeMember => 'إعادة إلى عضو';

  @override
  String get familyTransfer => 'تسليم القيادة';

  @override
  String familyTransferTitle(String name) {
    return 'تسليم القيادة إلى $name؟';
  }

  @override
  String familyTransferBody(String name) {
    return 'يصبح $name القائد وتصبح أنت نائباً.';
  }

  @override
  String familyTransferred(String name) {
    return 'أصبح $name القائد';
  }

  @override
  String get familyRemove => 'إزالة من العائلة';

  @override
  String familyRemoveTitle(String name) {
    return 'إزالة $name من العائلة؟';
  }

  @override
  String familyRemoved(String name) {
    return 'تمت إزالة $name';
  }

  @override
  String familyRoleChanged(String name) {
    return 'تم تغيير دور $name';
  }

  @override
  String get familyMemberActions => 'خيارات العضو';

  @override
  String get familyCreateTitle => 'عائلة جديدة';

  @override
  String get familyNameLabel => 'اسم العائلة';

  @override
  String get familyNameHelp => 'من 2 إلى 20 حرفاً، ولا يتكرر بين العائلات.';

  @override
  String get familyNameInvalid =>
      'استخدم من 2 إلى 20 حرفاً بدون رموز غير مسموحة.';

  @override
  String get familyEmblemLabel => 'الشعار (اختياري)';

  @override
  String get familyEmblemChoose => 'اختر صورة للشعار';

  @override
  String familyCreateCost(String coins) {
    return 'إنشاء العائلة يكلّف $coins';
  }

  @override
  String familyCreateSubmit(String coins) {
    return 'أنشئ مقابل $coins';
  }

  @override
  String familyCreateNotEnough(String coins) {
    return 'تحتاج $coins لإنشاء عائلة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.';
  }

  @override
  String familyCreated(String name) {
    return 'تم إنشاء $name';
  }

  @override
  String get cpTitle => 'العلاقة';

  @override
  String cpDay(int days) {
    return 'اليوم $days معاً';
  }

  @override
  String cpPoints(String points) {
    return 'نقاط العلاقة: $points';
  }

  @override
  String cpToNext(String points, String name) {
    return 'باقي $points للوصول إلى $name';
  }

  @override
  String get cpTopTier => 'وصلتما إلى أعلى مستوى';

  @override
  String cpSince(String date) {
    return 'منذ $date';
  }

  @override
  String get cpGiftTitle => 'أرسل هدية علاقة';

  @override
  String get cpGiftBody =>
      'تضيف الهدية نقاطاً لعلاقتكما، ولا يحصل شريكك على عملات.';

  @override
  String cpGiftConfirmTitle(String coins) {
    return 'إرسال $coins كهدية علاقة؟';
  }

  @override
  String cpGiftSent(String points) {
    return 'تم إرسال الهدية: +$points نقطة';
  }

  @override
  String get cpGiftNotEnough =>
      'ليس لديك عملات كافية لهذه الهدية. يضيف الفريق العملات حالياً.';

  @override
  String get cpEnd => 'إنهاء العلاقة';

  @override
  String cpEndTitle(String name) {
    return 'إنهاء العلاقة مع $name؟';
  }

  @override
  String get cpEndBody => 'لا تُسترد أي عملات.';

  @override
  String get cpEnded => 'انتهت العلاقة';

  @override
  String get cpNoneTitle => 'لا يوجد شريك بعد';

  @override
  String get cpNoneBody =>
      'أرسل طلب علاقة من الملف الشخصي لشخص ما أو من بطاقته في البث.';

  @override
  String get cpRequestsTitle => 'طلبات العلاقة';

  @override
  String get cpIncoming => 'الواردة';

  @override
  String get cpOutgoing => 'المرسلة';

  @override
  String get cpIncomingEmpty => 'لا توجد طلبات واردة';

  @override
  String get cpOutgoingEmpty => 'لا توجد طلبات مرسلة';

  @override
  String cpRequestFrom(String name) {
    return '$name يريد أن تكونا ثنائياً';
  }

  @override
  String cpRequestTo(String name) {
    return 'بانتظار رد $name';
  }

  @override
  String cpExpires(String date) {
    return 'ينتهي في $date';
  }

  @override
  String get cpAccept => 'قبول';

  @override
  String get cpDecline => 'رفض';

  @override
  String get cpCancel => 'إلغاء الطلب';

  @override
  String cpAccepted(String name) {
    return 'أنت و$name ثنائي الآن';
  }

  @override
  String get cpDeclined => 'تم رفض الطلب';

  @override
  String get cpCancelled => 'تم إلغاء الطلب وأُعيدت العملات';

  @override
  String get cpSendRequest => 'أرسل طلب علاقة';

  @override
  String get cpSendShort => 'أرسل طلباً';

  @override
  String cpSendTitle(String name) {
    return 'إرسال طلب علاقة إلى $name؟';
  }

  @override
  String cpSendBody(String coins, String days) {
    return 'يكلّف الطلب $coins. تعود إليك العملات إذا رُفض أو أُلغي أو لم يُرد عليه خلال $days.';
  }

  @override
  String cpSent(String name) {
    return 'تم إرسال طلب العلاقة إلى $name';
  }

  @override
  String cpSendNotEnough(String coins) {
    return 'تحتاج $coins لإرسال طلب علاقة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.';
  }

  @override
  String get cpLoadError => 'تعذّر تحميل العلاقة';

  @override
  String cpBoxValue(String name, String tier) {
    return '$name · $tier';
  }

  @override
  String familyBoxValue(String name, int level) {
    return '$name · مستوى $level';
  }

  @override
  String get medalsTitle => 'الميداليات';

  @override
  String medalsOwned(int owned, int total) {
    return '$owned من $total';
  }

  @override
  String get medalsChoose => 'اختر الميداليات المعروضة';

  @override
  String get medalsLocked => 'مقفلة';

  @override
  String medalsEarnedOn(String date) {
    return 'حصلت عليها في $date';
  }

  @override
  String get medalsEmptyTitle => 'لا توجد ميداليات بعد';

  @override
  String get medalsEmptyBody =>
      'تُمنح الميداليات تلقائياً عند البث ومستويات الجاذبية والعائلات والعلاقات.';

  @override
  String get medalsLoadError => 'تعذّر تحميل الميداليات';

  @override
  String get medalsShowcaseTitle => 'ميداليات ملفك';

  @override
  String medalsShowcaseHint(int max) {
    return 'اختر حتى $max ميداليات بالترتيب الذي تريده.';
  }

  @override
  String medalsShowcaseCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String medalsShowcaseLimit(int max) {
    return 'يمكنك عرض $max ميداليات كحد أقصى';
  }

  @override
  String get medalsShowcaseSave => 'حفظ';

  @override
  String get medalsShowcaseSaved => 'تم حفظ ميداليات ملفك';

  @override
  String get medalsShowcaseEmptyPreview =>
      'لا شيء معروض. اختر ميداليات من الأسفل.';

  @override
  String get medalsShowcaseNoneEarned =>
      'لم تحصل على ميداليات بعد، لذا لا يوجد ما تعرضه.';

  @override
  String medalsRowLabel(String names) {
    return 'الميداليات: $names';
  }

  @override
  String medalsPosition(String name, int position) {
    return '$name، الترتيب $position';
  }

  @override
  String get medalsDiscard => 'تجاهل التغييرات؟';

  @override
  String get medalsDiscardConfirm => 'تجاهل';

  @override
  String notifCpRequest(String who) {
    return '$who أرسل لك طلب علاقة';
  }

  @override
  String notifCpAccepted(String who) {
    return '$who قبل طلب العلاقة، أصبحتما ثنائياً';
  }

  @override
  String notifFamilyJoinAccepted(String family) {
    return 'تم قبولك في عائلة $family';
  }

  @override
  String notifFamilyJoinDeclined(String family) {
    return 'تم رفض طلبك للانضمام إلى $family';
  }

  @override
  String notifMedalAwarded(String name) {
    return 'حصلت على ميدالية جديدة: $name';
  }

  @override
  String get notifMedalAwardedUnnamed => 'حصلت على ميدالية جديدة';

  @override
  String get errorBagItemNotOwned => 'هذا العنصر ليس في حقيبتك.';

  @override
  String get bagTitle => 'الحقيبة';

  @override
  String get bagTileValue => 'زيّن بطاقتك';

  @override
  String get bagCategoryProfileCard => 'بطاقة الملف الشخصي';

  @override
  String get bagLoadError => 'تعذّر تحميل الحقيبة';

  @override
  String get bagWorn => 'قيد الارتداء';

  @override
  String get bagWear => 'ارتداء';

  @override
  String get bagTakeOff => 'إزالة';

  @override
  String get bagEmptyTitle => 'حقيبتك فارغة';

  @override
  String get bagEmptyMessage => 'ستظهر هنا العناصر التي تحصل عليها.';

  @override
  String get bagOwnedSection => 'عناصرك';

  @override
  String get errorGiftUnavailable => 'هذه الهدية لم تعد متاحة.';

  @override
  String get errorGiftBagInsufficient =>
      'لا يوجد في حقيبتك ما يكفي من هذه الهدية.';

  @override
  String get errorLiveGiftRecipientUnavailable =>
      'أحد المستلمين لم يعد على المايك.';

  @override
  String get liveGiftTabPopular => 'شائعة';

  @override
  String get liveGiftTabEvent => 'مناسبات';

  @override
  String get liveGiftTabFun => 'مرح';

  @override
  String get liveGiftTabBag => 'الحقيبة';

  @override
  String get liveGiftHost => 'المضيف';

  @override
  String get liveGiftAllOnMic => 'الكل';

  @override
  String get liveGiftAllOnMicSemantics => 'الإهداء لكل من على المايك';

  @override
  String get liveGiftEmptyTitle => 'لا توجد هدايا بعد';

  @override
  String get liveGiftEmptyMessage =>
      'ستظهر الهدايا هنا عندما يضيفها فريق Kabso Live.';

  @override
  String get liveGiftBagEmptyTitle => 'حقيبة الهدايا فارغة';

  @override
  String get liveGiftBagEmptyMessage =>
      'الهدايا التي تحصل عليها تظهر هنا، وترسلها دون عملات.';

  @override
  String get liveGiftLoadError => 'تعذّر تحميل الهدايا';

  @override
  String get liveGiftPickGift => 'اختر هدية';

  @override
  String get liveGiftPickRecipient => 'اختر من سيستلم الهدية';

  @override
  String get liveGiftNoRecipients => 'لا يوجد أحد على المايك لإهدائه';

  @override
  String get liveGiftSignIn => 'سجّل الدخول لإرسال الهدايا';

  @override
  String get liveGiftNotEnoughCoins => 'رصيدك من العملات لا يكفي لهذه الهدية.';

  @override
  String liveGiftBalance(String coins) {
    return 'رصيدك: $coins';
  }

  @override
  String liveGiftQuantity(String count) {
    return 'الكمية $count';
  }

  @override
  String get liveGiftBadgeNew => 'جديد';

  @override
  String get liveGiftBadgeEvent => 'مناسبة';

  @override
  String liveGiftBannerSent(String gift, String recipients) {
    return 'أهدى $gift إلى $recipients';
  }

  @override
  String liveGiftRecipientsTwo(String first, String second) {
    return '$first و$second';
  }

  @override
  String liveGiftRecipientsMore(String name, int count) {
    return '$name +$count';
  }

  @override
  String get liveGiftGeneric => 'هدية';

  @override
  String liveGiftNotOnMic(String name) {
    return '$name ليس على المايك. تُرسل الهدايا للمضيف ولمن على المايك.';
  }

  @override
  String liveGiftBagCount(String count) {
    return 'لديك $count';
  }

  @override
  String get liveGiftTagAll => 'الكل';

  @override
  String get liveGiftTagsSemantics => 'تصنيفات الهدايا';

  @override
  String get cpSpaceTitle => 'مساحة الثنائي';

  @override
  String get cpSpaceOpen => 'فتح مساحة الثنائي';

  @override
  String get cpSpaceHelpTitle => 'كيف تعمل مساحة الثنائي';

  @override
  String cpSpaceHelpBody(String zone) {
    return 'القرب هو نقاط علاقتكما: تزيده هدايا الثنائي ومكافآت المهام اليومية، وكل مستوى أعلى يفتح امتيازات أكثر. تبدأ المهام اليومية من جديد كل يوم عند 00:00 ($zone).';
  }

  @override
  String cpSpaceDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get cpSpaceActionTasks => 'المهام اليومية';

  @override
  String get cpSpaceActionPrivileges => 'امتيازات الثنائي';

  @override
  String get cpSpaceActionGifts => 'هدايا الثنائي';

  @override
  String get cpSpaceActionRanking => 'الترتيب';

  @override
  String get cpSpaceLevelTitle => 'مستوى الثنائي';

  @override
  String cpSpaceLevel(int level) {
    return 'Lv.$level';
  }

  @override
  String cpSpaceProgress(String points, String target) {
    return '$points / $target';
  }

  @override
  String cpSpaceIntimacy(String points) {
    return 'القرب $points';
  }

  @override
  String cpSpaceToNext(String points, String name) {
    return '$points قرب إضافي للوصول إلى $name';
  }

  @override
  String cpSpaceTasksResets(String time) {
    return 'تبدأ من جديد عند $time';
  }

  @override
  String cpSpaceTaskReward(String points) {
    return '+$points';
  }

  @override
  String cpSpaceTaskProgress(int progress, int target) {
    return '$progress/$target';
  }

  @override
  String get cpSpaceClaim => 'استلام';

  @override
  String get cpSpaceClaimed => 'تم الاستلام';

  @override
  String get cpSpaceNotDone => 'لم تكتمل';

  @override
  String cpSpaceClaimedToast(String points) {
    return '+$points قرب';
  }

  @override
  String get cpSpaceClaimedBefore => 'تم استلامها اليوم';

  @override
  String get cpSpaceTasksError => 'تعذّر تحميل مهام اليوم';

  @override
  String get cpPrivSpecialFrame => 'إطار مميز';

  @override
  String get cpPrivChatBubble => 'فقاعة حصرية';

  @override
  String get cpPrivMicEffect => 'تأثير مايك الثنائي';

  @override
  String get cpPrivEntranceEffect => 'تأثير الدخول';

  @override
  String get cpPrivGiftWall => 'جدار هدايا الثنائي';

  @override
  String get cpPrivSpecialFrameAbout => 'إطار على شكل قلب حول صورتيكما.';

  @override
  String get cpPrivChatBubbleAbout =>
      'تظهر رسائلكما في دردشة البث داخل فقاعة الثنائي.';

  @override
  String get cpPrivMicEffectAbout =>
      'تأثير الثنائي على مقعديكما عندما تكونان على المايك.';

  @override
  String get cpPrivEntranceEffectAbout =>
      'عندما تدخل بثًا، ترى الغرفة دخولك كثنائي.';

  @override
  String get cpPrivGiftWallAbout => 'يرى الجميع هدايا الثنائي التي تبادلتماها.';

  @override
  String cpSpaceUnlocksAt(int level) {
    return 'يُفتح عند Lv.$level';
  }

  @override
  String get cpSpaceUnlocked => 'مفتوح';

  @override
  String get cpSpaceLocked => 'مقفل';

  @override
  String get cpSpaceGiftWall => 'جدار الهدايا';

  @override
  String cpSpaceGiftWallTotals(String gifts, String coins) {
    return 'الهدايا $gifts · العملات $coins';
  }

  @override
  String cpSpaceGiftWallEntry(String from, String to) {
    return 'من $from إلى $to';
  }

  @override
  String get cpSpaceGiftWallEmpty => 'لا توجد هدايا ثنائي بعد';

  @override
  String cpSpaceGiftWallLocked(int level) {
    return 'يُفتح جدار هدايا هذا الثنائي عند Lv.$level.';
  }

  @override
  String get cpSpaceGiftWallError => 'تعذّر تحميل جدار الهدايا';

  @override
  String cpSpaceGiftConfirm(String gift, String coins) {
    return 'إرسال $gift مقابل $coins؟';
  }

  @override
  String get cpSpaceConfessionsTitle => 'جدار الاعترافات';

  @override
  String get cpSpaceConfessionsEmpty => 'كن أول من يترك اعترافًا لشريكك';

  @override
  String get cpSpaceConfessionsEmptyPublic => 'لا توجد اعترافات بعد';

  @override
  String cpSpaceConfessionHint(String name) {
    return 'اكتب إلى $name';
  }

  @override
  String get cpSpaceConfessionSend => 'إرسال';

  @override
  String get cpSpaceConfessionSent => 'تم ترك الاعتراف';

  @override
  String cpSpaceConfessionTo(String from, String to) {
    return 'من $from إلى $to';
  }

  @override
  String get cpSpaceConfessionMenu => 'خيارات الاعتراف';

  @override
  String get cpSpaceConfessionDelete => 'حذف';

  @override
  String get cpSpaceConfessionDeleteTitle => 'حذف هذا الاعتراف؟';

  @override
  String get cpSpaceConfessionDeleted => 'تم حذف الاعتراف';

  @override
  String get cpSpaceConfessionReport => 'إبلاغ';

  @override
  String get cpSpaceConfessionReportTitle => 'لماذا تبلّغ عن هذا الاعتراف؟';

  @override
  String get cpSpaceConfessionsError => 'تعذّر تحميل الاعترافات';

  @override
  String get cpSpaceRankingTitle => 'ترتيب الثنائيات';

  @override
  String get cpSpaceRankingWeek => 'هذا الأسبوع';

  @override
  String get cpSpaceRankingAll => 'كل الأوقات';

  @override
  String get cpSpaceRankingEmpty => 'لا توجد ثنائيات هنا بعد';

  @override
  String get cpSpaceRankingError => 'تعذّر تحميل الترتيب';

  @override
  String cpSpaceRankingMe(String rank) {
    return 'ثنائيكما: #$rank';
  }

  @override
  String get cpSpaceRankingMeUnranked => 'ثنائيكما غير مرتّب بعد';

  @override
  String cpSpacePair(String first, String second) {
    return '$first و$second';
  }

  @override
  String get cpSpaceLoadError => 'تعذّر تحميل مساحة الثنائي';

  @override
  String get cpSpaceGoneTitle => 'مساحة هذا الثنائي غير متاحة';

  @override
  String get cpSpaceGoneBody => 'ربما انتهت العلاقة، أو لا يمكن عرضها لك.';

  @override
  String get errorCpTaskNotCompleted => 'لم تكتمل هذه المهمة اليوم بعد.';

  @override
  String get errorCpPrivilegeLocked => 'لم يفتح هذا الثنائي هذه الميزة بعد.';

  @override
  String liveCpEntranceCouple(String name, String partner) {
    return '$name و$partner';
  }

  @override
  String liveCpEntranceLevel(String level) {
    return 'دخول الثنائي · $level';
  }

  @override
  String get errorFamilyChatMuted => 'تم كتمك في دردشة العائلة.';

  @override
  String get familiesListTitle => 'قائمة العائلات';

  @override
  String get familiesSearchShort => 'ابحث عن عائلة';

  @override
  String get familiesTabPrestige => 'هيبة العائلة';

  @override
  String get familiesTabBattle => 'ترتيب القتال';

  @override
  String get familiesTabActive => 'الأكثر نشاطاً';

  @override
  String familiesSoonLabel(String feature) {
    return '$feature، قريباً';
  }

  @override
  String get familiesBoardEmpty => 'لا توجد عائلات في الترتيب بعد';

  @override
  String get familiesBoardEmptyPrestige =>
      'تظهر هنا العائلات التي جمعت نقاطاً هذا الشهر.';

  @override
  String get familiesBoardEmptyActive =>
      'تظهر هنا العائلات التي نشط أعضاؤها هذا الأسبوع.';

  @override
  String familiesScoreMonth(String points) {
    return 'نقاط هذا الشهر: $points';
  }

  @override
  String familiesScoreActive(String count) {
    return 'نشطون هذا الأسبوع: $count';
  }

  @override
  String familiesPodiumLabel(int place, String name) {
    return 'المركز $place: $name';
  }

  @override
  String get familiesMyRankNone => 'لم تدخل عائلتك الترتيب بعد';

  @override
  String get familyJoinShort => 'انضمام';

  @override
  String familyJoinNamed(String name) {
    return 'انضمام إلى $name';
  }

  @override
  String familyLevelLong(int level) {
    return 'المستوى $level';
  }

  @override
  String get familyActiveJustNow => 'نشط الآن';

  @override
  String get familyOnlineNow => 'متصل الآن';

  @override
  String get familySoon => 'قريباً';

  @override
  String get familyPageTitle => 'العائلة';

  @override
  String get familyShare => 'مشاركة العائلة';

  @override
  String get familyInvite => 'دعوة أعضاء';

  @override
  String get familyInviteCopied => 'تم نسخ الدعوة. أرسلها لمن تريد.';

  @override
  String familyInviteText(String name, String number) {
    return 'انضم إلى عائلتي «$name» على Kabso Live. رقم العائلة: $number';
  }

  @override
  String get familyNumberLabel => 'رقم العائلة';

  @override
  String familyNumberCopy(String number) {
    return 'رقم العائلة $number، انسخ';
  }

  @override
  String get familyCopyNumber => 'نسخ رقم العائلة';

  @override
  String get familyMemberWord => 'عضو';

  @override
  String familyMembersShort(String count) {
    return '$count عضو';
  }

  @override
  String get familyMembersSearchHint => 'ابحث في الأعضاء';

  @override
  String get familyMembersNoMatch => 'لا يوجد عضو بهذا الاسم';

  @override
  String familyToReach(int level) {
    return 'للوصول إلى المستوى $level';
  }

  @override
  String get familyToolManage => 'إدارة العائلة';

  @override
  String get familyToolCompetitions => 'المسابقات';

  @override
  String get familyToolShop => 'متجر العائلة';

  @override
  String get familyToolTasks => 'المهام';

  @override
  String get familyTabMembers => 'الأعضاء';

  @override
  String get familyTabEvents => 'الفعاليات';

  @override
  String get familyTabContributions => 'المساهمات';

  @override
  String get familyTabRanking => 'الترتيب';

  @override
  String get familyContributionsThisMonth => 'مساهمات الأعضاء هذا الشهر';

  @override
  String get familyContributionsEmpty => 'لا مساهمات هذا الشهر بعد';

  @override
  String get familyContributionsEmptyBody =>
      'كل عملة ينفقها الأعضاء في التطبيق تُحتسب للعائلة.';

  @override
  String get familyRankNone => '—';

  @override
  String get familyRankingNote =>
      'الترتيب بين كل العائلات: هيبة العائلة لهذا الشهر، والنشاط لهذا الأسبوع.';

  @override
  String get familyChangeCover => 'تغيير الغلاف';

  @override
  String get familyRemoveCover => 'إزالة الغلاف';

  @override
  String get familyCoverUpdated => 'تم تحديث الغلاف';

  @override
  String get familyCoverRemoved => 'تمت إزالة الغلاف';

  @override
  String get familyTaglineTitle => 'وصف العائلة';

  @override
  String get familyTaglineHint => 'مثال: عائلة عالمية · ترفيه · بث مباشر';

  @override
  String get familySave => 'حفظ';

  @override
  String get familySaved => 'تم الحفظ';

  @override
  String get familyViewProfile => 'عرض الملف الشخصي';

  @override
  String get familyChatOpen => 'مراسلة العائلة';

  @override
  String get familyChatTitle => 'دردشة العائلة';

  @override
  String get familyChatHint => 'اكتب رسالة للعائلة';

  @override
  String get familyChatSend => 'إرسال';

  @override
  String get familyChatEmpty => 'ابدأوا الحديث';

  @override
  String get familyChatEmptyBody => 'الرسائل هنا يراها أعضاء العائلة فقط.';

  @override
  String get familyChatLoadError => 'تعذّر تحميل الدردشة';

  @override
  String get familyChatMembersOnly => 'الدردشة لأعضاء العائلة فقط';

  @override
  String get familyChatMembersOnlyBody => 'انضم إلى العائلة لتشارك في الدردشة.';

  @override
  String get familyChatDelete => 'حذف الرسالة';

  @override
  String get familyChatDeleted => 'تم حذف الرسالة';

  @override
  String get familyChatReport => 'الإبلاغ عن الرسالة';

  @override
  String get familyChatReported => 'شكراً، تم إرسال البلاغ';

  @override
  String get familyChatMute => 'كتم في الدردشة';

  @override
  String get familyChatUnmute => 'إلغاء الكتم في الدردشة';

  @override
  String familyChatMutedName(String name) {
    return 'تم كتم $name في الدردشة';
  }

  @override
  String familyChatUnmutedName(String name) {
    return 'تم إلغاء كتم $name';
  }

  @override
  String get privacyActivityTitle => 'حالة النشاط';

  @override
  String get privacyActivityLabel => 'إظهار حالة النشاط';

  @override
  String get privacyActivityHint =>
      'يرى أعضاء عائلتك إن كنت متصلاً الآن أو متى كنت نشطاً آخر مرة.';

  @override
  String get followListsFollowBack => 'رد المتابعة';

  @override
  String get followListsFollowersEmpty => 'لا يوجد متابِعون بعد';

  @override
  String get followListsFollowersEmptyBody =>
      'عندما يتابع أحدٌ هذا الحساب سيظهر هنا.';

  @override
  String get followListsFollowingEmpty => 'لا يتابع أحدًا بعد';

  @override
  String get followListsFollowingEmptyBody =>
      'ستظهر هنا الحسابات التي يتابعها هذا الحساب.';

  @override
  String get followListsPrivateBody =>
      'لا يرى متابِعي هذا الحساب ومن يتابعهم إلا متابِعوه.';

  @override
  String followListsTabFollowers(String count) {
    return '$count المتابِعون';
  }

  @override
  String followListsTabFollowing(String count) {
    return '$count يتابع';
  }

  @override
  String get followListsAddPeople => 'اكتشف أشخاصاً';

  @override
  String get followListsSearchHint => 'بحث';

  @override
  String get followListsSortBy => 'الترتيب:';

  @override
  String get followListsSortDefault => 'الافتراضي';

  @override
  String get followListsSortOldest => 'الأقدم أولاً';

  @override
  String get followListsSortToggle => 'تغيير الترتيب';

  @override
  String followListsRowMore(String name) {
    return 'خيارات $name';
  }

  @override
  String get followListsRemoveFollower => 'إزالة المتابِع';

  @override
  String followListsRemoveFollowerTitle(String name) {
    return 'إزالة $name من متابِعيك؟';
  }

  @override
  String get followListsRemoveFollowerBody =>
      'لن يُبلَّغ بذلك، ويستطيع متابعتك مجدداً ما لم يكن حسابك خاصاً.';

  @override
  String get followListsRemoveFollowerConfirm => 'إزالة';

  @override
  String followListsFollowerRemoved(String name) {
    return 'أُزيل $name من متابِعيك';
  }

  @override
  String get followListsNoMatch => 'لا نتائج';

  @override
  String followListsNoMatchBody(String query) {
    return 'لا أحد في هذه القائمة يبدأ اسمه بـ «$query».';
  }

  @override
  String get profileOpenFollowers => 'عرض المتابِعين';

  @override
  String get profileOpenFollowing => 'عرض من يتابعهم';

  @override
  String get liveHubBrand => 'كابسو لايف';

  @override
  String get liveGridAudio => 'صوتي';

  @override
  String get liveGridVideo => 'فيديو';

  @override
  String homeBannerSemantics(int index, int count) {
    return 'إعلان $index من $count';
  }

  @override
  String homeBannerTitledSemantics(String title, int index, int count) {
    return '$title، إعلان $index من $count';
  }

  @override
  String get familiesActivitiesTitle => 'أنشطة العائلات';

  @override
  String get familiesActivityMonthly => 'التصنيف الشهري\nهيبة العائلة';

  @override
  String familiesRowMembers(int count, int capacity) {
    return 'الأعضاء: $count/$capacity';
  }

  @override
  String get familiesMonthPointsLabel => 'نقاط هذا الشهر:';

  @override
  String get familiesActiveLabel => 'نشطون هذا الأسبوع:';

  @override
  String navMessagesUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة غير مقروءة',
      many: '$count رسالة غير مقروءة',
      few: '$count رسائل غير مقروءة',
      two: 'رسالتان غير مقروءتين',
      one: 'رسالة واحدة غير مقروءة',
    );
    return '$_temp0';
  }

  @override
  String get navMessagesUnreadMany => 'أكثر من 99 رسالة غير مقروءة';

  @override
  String get navMomentsNew => 'قصص جديدة';

  @override
  String get liveVoiceRoomsTitle => 'الغرف الصوتية';

  @override
  String get liveHubFilterLabel => 'عوامل التصفية';

  @override
  String get liveHubFilterFollowing => 'المتابَعين';

  @override
  String get livePartyTabFollowing => 'المتابَعة';

  @override
  String get liveCardPopular => 'رائج';

  @override
  String get liveHubFilterNearby => 'القريبة';

  @override
  String get liveHubFilterPopular => 'الرائج';

  @override
  String get liveHubFilterFeatured => 'المميزة';

  @override
  String get liveHubFilterExplore => 'استكشاف';

  @override
  String get liveHubPopularMenuHint => 'يفتح قائمة: المتابَعون أو الفئات';

  @override
  String get liveNearbyNoCountryTitle => 'حدّد بلدك لترى البثوث القريبة';

  @override
  String get liveNearbyNoCountryBody =>
      'تعرض «القريبة» بثوث المضيفين من بلدك. بلدك لا يظهر في ملفك العام.';

  @override
  String get liveNearbySetCountry => 'حدّد بلدك';

  @override
  String get liveNearbyChangeCountry => 'تغيير البلد';

  @override
  String liveNearbyEmptyTitle(String country) {
    return 'لا بثوث من $country الآن';
  }

  @override
  String get liveNearbyEmptyBody => 'عد لاحقًا أو جرّب «الرائج».';

  @override
  String get liveFeaturedEmptyTitle => 'لا بثوث مميزة الآن';

  @override
  String get liveFeaturedEmptyBody =>
      'تظهر هنا بثوث المضيفين الذين يختارهم فريق Kabso Live.';

  @override
  String get liveVoiceTabFollow => 'المتابَعون';

  @override
  String get liveVoiceTabHot => 'الرائجة';

  @override
  String get liveVoiceTabNew => 'الجديدة';

  @override
  String get liveVoiceRecommended => 'المقترحة';

  @override
  String get liveVoiceSection => 'الغرف';

  @override
  String get liveVoiceListView => 'عرض كقائمة';

  @override
  String get liveVoiceGridView => 'عرض كشبكة';

  @override
  String liveVoiceSeats(int taken, int total) {
    return '$taken/$total';
  }

  @override
  String get liveVoiceEmptyTitle => 'لا غرف صوتية الآن';

  @override
  String get liveVoiceEmptyBody => 'عد لاحقًا أو جرّب فئة أخرى.';

  @override
  String get countryPickerTitle => 'بلدك';

  @override
  String get countryPickerBody =>
      'يحدّد بثوث «القريبة». لا يظهر في ملفك العام.';

  @override
  String get countryPickerSearch => 'ابحث عن بلد';

  @override
  String get countryPickerClear => 'إزالة البلد';

  @override
  String get settingsCountry => 'البلد';

  @override
  String get settingsCountryNotSet => 'غير محدّد';

  @override
  String get liveGiftRecipientRefused =>
      'لا يمكن إرسال الهدية إلى هذا المستلم هنا الآن.';

  @override
  String get liveLeaveTitle => 'أعجبك البث؟ تابِع المضيف قبل أن تغادر';

  @override
  String get liveLeaveFollow => 'تابِع واخرج';

  @override
  String get liveLeaveExit => 'الخروج من البث';

  @override
  String liveHostPillPoints(String points) {
    return 'نقاط هذا البث $points';
  }

  @override
  String liveHostPillCherries(String cherries) {
    return 'كرز هذا البث $cherries';
  }

  @override
  String liveHostPillTaps(String taps) {
    return 'نقرات هذا البث $taps';
  }

  @override
  String get liveChatSayHi => 'قل مرحبًا…';

  @override
  String get liveQuickHello => 'مرحبًا 😊';

  @override
  String get liveQuickFire => '🔥🔥🔥';

  @override
  String get liveQuickNiceMood => 'أجواء جميلة~';

  @override
  String get liveQuickGotMe => 'أسرتني';

  @override
  String liveQuickReplyLabel(String text) {
    return 'إرسال: $text';
  }

  @override
  String get liveToolDual => 'كاميرتان';

  @override
  String get liveToolSticker => 'ملصقات';

  @override
  String get liveToolInfo => 'المعلومات';

  @override
  String get liveToolTrafficCard => 'صواريخ الزيارات';

  @override
  String get liveToolMagic => 'الفلاتر';

  @override
  String get liveToolFillLight => 'إضاءة';

  @override
  String get liveFillLightNoTorch => 'هذه الكاميرا بلا كشاف.';

  @override
  String get liveFillLightTitle => 'الإضاءة';

  @override
  String get liveFillLightOff => 'إيقاف';

  @override
  String get liveFillLightLow => 'خفيفة';

  @override
  String get liveFillLightMedium => 'متوسطة';

  @override
  String get liveFillLightHigh => 'قوية';

  @override
  String get liveFillLightOnPicture =>
      'تُفتّح الإضاءة الصورة نفسها بلطف، فيراها مشاهدوك كما تراها.';

  @override
  String get liveFillLightScreenOnly =>
      'على هذا الجهاز تضيء الشاشة وجهك بتوهّج خفيف عند الحواف؛ صورة البث لا تتغير.';

  @override
  String get liveFilterTitle => 'فلاتر الألوان';

  @override
  String get liveFilterUnsupported =>
      'فلاتر الألوان غير متاحة على هذا الجهاز بعد، فيجب أن يراها مشاهدوك لا شاشتك وحدها.';

  @override
  String get liveFilterNatural => 'طبيعي';

  @override
  String get liveFilterWarm => 'دافئ';

  @override
  String get liveFilterCool => 'بارد';

  @override
  String get liveFilterMono => 'أبيض وأسود';

  @override
  String get liveFilterCinematic => 'سينمائي';

  @override
  String get liveFilterVivid => 'زاهٍ';

  @override
  String get liveFilterSoft => 'ناعم';

  @override
  String get liveEffectsTitle => 'المؤثرات (تجريبي)';

  @override
  String get liveEffectNone => 'بلا';

  @override
  String get liveEffectBackgroundBlur => 'تمويه الخلفية';

  @override
  String get liveEffectsUnavailable => 'المؤثرات غير متاحة في هذا الإصدار بعد.';

  @override
  String get liveManageAddModerator => 'إضافة مشرف';

  @override
  String get liveToolMixer => 'الصوت';

  @override
  String get liveBeautyToolsTitle => 'أدوات التجميل';

  @override
  String get liveHostGuests => 'اتصال الضيوف';

  @override
  String get liveHostGuestsSoon =>
      'يمكن للضيوف الانضمام في البث متعدد الضيوف. في البث الفردي ستتوفر لاحقاً.';

  @override
  String get liveHostTools => 'الأدوات';

  @override
  String get liveManageTitle => 'إدارة المستخدمين';

  @override
  String get liveManageMuted => 'المكتومون في الدردشة';

  @override
  String get liveManageKicked => 'المطرودون من البث';

  @override
  String get liveManageModerators => 'المشرفون';

  @override
  String get liveManageModeratorsHint => 'افتح بطاقة الشخص لتعيينه مشرفاً.';

  @override
  String get liveManageSignedInOnly => 'للمسجلين فقط';

  @override
  String get liveManageSignedInOnlyBody =>
      'لا يستطيع من ليس لديه حساب المشاهدة.';

  @override
  String get liveManageEmpty => 'لا أحد بعد';

  @override
  String get liveManageUnmute => 'إلغاء الكتم';

  @override
  String get liveManageLetBack => 'السماح بالعودة';

  @override
  String get liveManageRemove => 'إزالة';

  @override
  String get goLiveSummaryTime => 'مدة البث';

  @override
  String get goLiveSummaryTaps => 'من النقرات';

  @override
  String get goLiveSummaryGifts => 'من الهدايا';

  @override
  String get goLiveSummarySupporters => 'الداعمون';

  @override
  String goLiveSummaryCharm(String level) {
    return 'مستوى الجاذبية $level';
  }

  @override
  String goLiveSummaryCharmNext(String points) {
    return '$points للمستوى التالي';
  }

  @override
  String get liveGiftTabRecent => 'الأخيرة';

  @override
  String get liveGiftTabLucky => 'الحظ';

  @override
  String get liveGiftRecentEmptyTitle => 'لا هدايا حديثة';

  @override
  String get liveGiftRecentEmptyMessage =>
      'تظهر هنا الهدايا التي ترسلها من هذا الهاتف.';

  @override
  String get liveGiftPriceSort => 'السعر';

  @override
  String get liveGiftPriceSortOff => 'الترتيب حسب السعر';

  @override
  String get liveGiftPriceSortUp => 'السعر من الأقل إلى الأعلى';

  @override
  String get liveGiftPriceSortDown => 'السعر من الأعلى إلى الأقل';

  @override
  String liveGiftWealthLevel(String level) {
    return 'مستوى الثروة $level';
  }

  @override
  String liveGiftWealthToNext(String points) {
    return '$points للمستوى التالي';
  }

  @override
  String get liveLuckyOdds => 'احتمالات الربح';

  @override
  String get liveLuckyOddsTitle => 'احتمالات الربح في هدايا الحظ';

  @override
  String get liveLuckyOddsIntro =>
      'كل هدية ترسلها سحبة واحدة. الربح يساوي المضاعف مضروباً في سعر الهدية بالعملات.';

  @override
  String liveLuckyOddsRow(String multiplier) {
    return '⁦×$multiplier⁩';
  }

  @override
  String get liveLuckyOddsNoWin => 'بلا ربح';

  @override
  String liveLuckyOddsReturn(String percent) {
    return 'العائد المتوقع: $percent من العملات المنفقة';
  }

  @override
  String liveLuckyOddsHostShare(String percent) {
    return 'يُحتسب $percent من قيمة الهدية للمضيف.';
  }

  @override
  String get liveLuckyOddsProtection =>
      'لا تتجاوز أرباح اليوم العائد المتوقع من هدايا الحظ في ذلك اليوم؛ والربح الذي يتجاوزه يُدفع أقل أو لا يُدفع.';

  @override
  String get liveLuckyOddsAge => 'لمن هم في سن 18 عاماً أو أكثر فقط.';

  @override
  String get liveLuckyAgeTitle => 'هل عمرك 18 عاماً أو أكثر؟';

  @override
  String get liveLuckyAgeBody =>
      'هدايا الحظ لعبة حظ تُلعب بالعملات. أكّد أن عمرك 18 عاماً أو أكثر لإرسالها.';

  @override
  String get liveLuckyAgeConfirm => 'عمري 18 عاماً أو أكثر';

  @override
  String get liveLuckyRegion => 'هدايا الحظ غير متاحة في بلدك.';

  @override
  String get liveLuckyOff => 'هدايا الحظ متوقفة حالياً.';

  @override
  String liveLuckyWon(String coins, String multiplier) {
    return 'ربحت $coins عملة، وأعلى مضاعف ⁦×$multiplier⁩';
  }

  @override
  String get liveLuckyNoWin => 'لا ربح هذه المرة';

  @override
  String liveLuckyBanner(String name, String multiplier, String coins) {
    return '$name ربح ⁦×$multiplier⁩: $coins عملة';
  }

  @override
  String get errorLuckyGiftAgeUnconfirmed =>
      'أكّد أن عمرك 18 عاماً أو أكثر لإرسال هدايا الحظ.';

  @override
  String get errorLuckyGiftRegionUnavailable => 'هدايا الحظ غير متاحة في بلدك.';

  @override
  String get liveEmojiPanel => 'الرموز التعبيرية';

  @override
  String get liveEmojiKeyboard => 'لوحة المفاتيح';

  @override
  String get liveEmojiSmileys => 'الوجوه';

  @override
  String get liveEmojiPeople => 'الأيدي والأشخاص';

  @override
  String get liveEmojiLove => 'الحب';

  @override
  String get liveEmojiAnimals => 'الحيوانات والطبيعة';

  @override
  String get liveEmojiFood => 'الطعام والشراب';

  @override
  String get liveEmojiActivities => 'الأنشطة';

  @override
  String get liveEmojiTravel => 'السفر والأماكن';

  @override
  String get liveEmojiObjects => 'الأشياء';

  @override
  String get liveEmojiSymbols => 'الرموز';

  @override
  String get goLiveToolsMore => 'المزيد';

  @override
  String get goLiveToolsLess => 'أقل';

  @override
  String get goLiveCategoriesAll => 'كل المواضيع';

  @override
  String get liveUserMention => 'منشن';

  @override
  String get liveQuickHostWelcome => 'أهلاً بكم في البث 👋';

  @override
  String get liveQuickHostThanks => 'شكراً على الدعم 🌹';

  @override
  String get liveQuickHostFollow => 'تابعوني ❤️';

  @override
  String get liveQuickHostShare => 'شاركوا البث 🔥';

  @override
  String get liveRoomIdCopyHint => 'انقر للنسخ';

  @override
  String get liveWishTitle => 'قائمة الأمنيات';

  @override
  String get liveWishHint =>
      'اختر حتى ٤ هدايا تتمنّاها، يراها المشاهدون في البث.';

  @override
  String get liveWishSave => 'حفظ';

  @override
  String get liveWishFull => '٤ هدايا كحد أقصى';

  @override
  String liveWishRemove(String name) {
    return 'إزالة $name';
  }

  @override
  String liveWishMoveEarlier(String name) {
    return 'تقديم $name';
  }

  @override
  String liveWishRowLabel(String name, String count) {
    return '$name، استلمت $count';
  }

  @override
  String get liveWishCardLabel => 'قائمة أمنيات المضيف';

  @override
  String get liveWishEditLabel => 'تعديل قائمة الأمنيات';

  @override
  String get liveToolWish => 'الأمنيات';

  @override
  String get livePromoClose => 'إخفاء الإعلان';

  @override
  String get liveSeatEmoji => 'إيموجي على مقعدي';

  @override
  String get liveSeatEmojiHint => 'يظهر على مقعدك مرة واحدة ويراه الجميع';

  @override
  String liveWishChosenCount(int count) {
    return 'تم اختيار $count من 4';
  }

  @override
  String get liveUsernameCopied => 'تم النسخ';

  @override
  String get liveChatTooFast => 'أُرسلت بسرعة كبيرة. اضغط لإعادة المحاولة';

  @override
  String liveBulletTime(String time) {
    return 'أُرسلت $time';
  }

  @override
  String get liveGames => 'الألعاب';

  @override
  String get liveGamesSoon => 'الألعاب قريباً';

  @override
  String get liveGamesSoonBody =>
      'نعمل على إضافة ألعاب تلعبها داخل البث، وهي غير متاحة بعد.';

  @override
  String liveChatGiftLine(
    String sender,
    String gift,
    int count,
    String recipient,
  ) {
    return '$sender أرسل $gift ×$count إلى $recipient';
  }

  @override
  String liveChatGiftRecipients(String name, int more) {
    return '$name و$more آخرين';
  }

  @override
  String liveChatLuckyLine(String sender, String multiplier, String coins) {
    return '$sender ربح ×$multiplier = $coins عملة من هدية الحظ';
  }

  @override
  String liveStripGift(String sender, String receiver, String gift) {
    return 'أرسل $sender إلى $receiver هدية $gift';
  }

  @override
  String liveStripGameWin(String winner, String amount) {
    return 'فاز $winner بجائزة قيمتها $amount تذكرة';
  }

  @override
  String get liveStripShowGifts => 'إظهار شريط الهدايا';

  @override
  String get liveStripShowGames => 'إظهار شريط الألعاب';

  @override
  String get liveStripSwitchHint => 'في جميع البثوث وعلى كل أجهزتك';

  @override
  String get liveStripHideWins => 'إخفاء أشرطة الفوز';

  @override
  String get liveStripHideWinsHint =>
      'مكاسب الحظ الكبيرة من اللايفات الأخرى لا تظهر؛ شريط المكسب في هذا البث يبقى';

  @override
  String get liveViewerMenu => 'المزيد';

  @override
  String get liveToolsModerator => 'أدوات المشرف';

  @override
  String get liveToolReportHost => 'الإبلاغ عن المضيف';

  @override
  String get liveToolViewers => 'المشاهدون';

  @override
  String get liveToolContributions => 'المساهمات';

  @override
  String get liveToolGiftSounds => 'أصوات الهدايا';

  @override
  String get liveToolGiftEffects => 'مؤثرات الهدايا';

  @override
  String get liveToolClearScreen => 'شاشة نظيفة';

  @override
  String get liveBroadcastSettings => 'إعدادات البث';

  @override
  String get liveSettingsSound => 'الصوت';

  @override
  String get liveSettingsCamera => 'الكاميرا';

  @override
  String get liveSettingsCameraHint => 'عند إيقافها يرى الآخرون صورتك';

  @override
  String get liveSettingsFlip => 'قلب الكاميرا';

  @override
  String get liveSettingsQuality => 'الجودة';

  @override
  String get liveSettingsSeatCount => 'عدد المقاعد';

  @override
  String get liveSettingsQuestions => 'الأسئلة';

  @override
  String get liveSettingsRoom => 'الغرفة';

  @override
  String get liveSettingsGeneral => 'عام';

  @override
  String get liveSettingsGuestsHint => 'المشاهدة دون حساب';

  @override
  String get liveMuteAll => 'كتم الجميع';

  @override
  String get liveMuteAllHint => 'يكتم مايك كل من على المقاعد';

  @override
  String get liveMuteAllDone => 'تم كتم كل من على المقاعد';

  @override
  String get liveMuteAllNone => 'لا أحد على المقاعد لكتمه';

  @override
  String get liveCameraOff => 'تم إيقاف الكاميرا';

  @override
  String get liveViewerSettings => 'إعدادات المشاهدة';

  @override
  String get liveViewerThisLive => 'هذا البث';

  @override
  String get liveViewerEffects => 'الهدايا والتأثيرات';

  @override
  String get liveViewerDisplay => 'العرض';

  @override
  String get liveViewerMuteLive => 'كتم صوت البث عندي';

  @override
  String get liveViewerMuteLiveHint => 'لهذا البث فقط، ولا يتغيّر شيء عند غيرك';

  @override
  String get liveViewerVolume => 'مستوى الصوت';

  @override
  String get liveViewerGiftSounds => 'كتم أصوات الهدايا';

  @override
  String get liveViewerGiftEffects => 'إخفاء مؤثرات الهدايا';

  @override
  String get liveViewerGiftEffectsHint => 'يبقى شريط الهدية في الدردشة';

  @override
  String get liveViewerQuipSounds => 'كتم أصوات الإفيهات';

  @override
  String get liveViewerEntrances => 'إخفاء تأثيرات الدخول';

  @override
  String get liveViewerCleanHint =>
      'يخفي الدردشة والبطاقات، اضغط «إظهار الكل» للعودة';

  @override
  String get liveViewerCleanRestore => 'إظهار الكل';

  @override
  String get liveViewerChatText => 'حجم خط الدردشة';

  @override
  String get liveViewerChatSmall => 'صغير';

  @override
  String get liveViewerChatNormal => 'عادي';

  @override
  String get liveViewerChatLarge => 'كبير';

  @override
  String get liveViewerDataSaver => 'توفير البيانات';

  @override
  String get liveViewerDataSaverHint => 'الصوت فقط، دون فيديو';

  @override
  String get liveViewerDataSaverOn => 'توفير البيانات: الصوت فقط';

  @override
  String get liveToolSeatRequests => 'طلبات المقاعد';

  @override
  String liveCinemaMoved(int seat) {
    return 'وضع السينما يتسع لـ 10 مقاعد: تم نقلك إلى المقعد $seat.';
  }

  @override
  String get liveCinemaOffSeat =>
      'تم إنزالك من المقعد لأن وضع السينما يتسع لـ 10 مقاعد فقط.';

  @override
  String get liveGuestJoin => 'انضم كضيف';

  @override
  String get liveGuestsFull =>
      'مقاعد الضيوف الثلاثة في هذا البث ممتلئة. حاول مجدداً عندما يفرغ مقعد.';

  @override
  String get liveStatsCherries => 'كرز هذا البث';

  @override
  String liveStatsIncludesYours(String points) {
    return 'منها $points من نقراتك وهداياك أنت';
  }

  @override
  String get liveStatsViewers => 'المشاهدون';

  @override
  String get liveStatsPeak => 'ذروة المشاهدة';

  @override
  String get liveStatsAverageWatch => 'متوسط مدة المشاهدة';

  @override
  String get liveStatsNewFollowers => 'متابعون جدد';

  @override
  String get liveStatsChatMessages => 'رسائل الدردشة';

  @override
  String get liveStatsGiftsSent => 'الهدايا المُرسلة';

  @override
  String get liveStatsCountriesTitle => 'من أين جاء مشاهدوك';

  @override
  String get liveStatsCountryOther => 'دول أخرى';

  @override
  String get liveStatsCountryUnknown => 'غير محدد';

  @override
  String liveStatsCountriesNote(String count) {
    return 'النسب من إجمالي المشاهدين ($count)، مقرّبة إلى منزلة عشرية واحدة';
  }

  @override
  String liveStatsCountryRow(String country, String percent, String count) {
    return '$country: $percent من المشاهدين ($count)';
  }

  @override
  String get liveStatsNoViewers =>
      'لم يشاهد أحد هذه المرة. بثك القادم فرصة جديدة.';

  @override
  String get liveStatsTopSupporters => 'أبرز الداعمين';

  @override
  String get liveStatsNoSupporters =>
      'لا داعمين هذه المرة. ستظهر هنا هدايا ونقرات مشاهديك.';

  @override
  String liveStatsSupporterRank(int rank, String name, String points) {
    return 'المركز $rank: $name، $points كرزة';
  }

  @override
  String get liveStatsLoadFailed => 'تعذّر تحميل بيانات البث';

  @override
  String get liveStatsLoadFailedBody => 'تحقّق من اتصالك ثم حاول مجدداً.';

  @override
  String get liveComboLabel => 'ماكس';

  @override
  String get liveMaxXJackpot => 'جاكبوت';

  @override
  String get liveMaxXSuperJackpot => 'سوبر جاكبوت';

  @override
  String liveComboSemantics(String gift, int count) {
    return 'ماكس إكس: أرسل $gift مجدداً ⁦×$count⁩';
  }

  @override
  String liveComboBalance(String coins) {
    return 'رصيدك $coins عملة';
  }

  @override
  String get usernameLettersAndDigits =>
      'استخدم أحرفاً وأرقاماً معاً (مثل sara22)';

  @override
  String get usernamePremium =>
      'هذا يوزر مميز، واليوزرات المميزة تُستأجر من متجر اليوزرات المميزة.';

  @override
  String get errorPremiumUsernameUnavailable =>
      'لا يمكن استئجار هذا اليوزر الآن.';

  @override
  String get errorPremiumUsernamePriceChanged =>
      'تغيّر السعر للتو. راجع السعر الجديد وحاول مجدداً.';

  @override
  String get errorPremiumUsernameActive =>
      'لديك يوزر مميز بالفعل. أعِده أولاً.';

  @override
  String get premiumTitle => 'اليوزرات المميزة';

  @override
  String get premiumTileValue => 'استأجر @يوزر مميز';

  @override
  String get premiumSearchHint => 'ابحث عن يوزر، مثل 777';

  @override
  String get premiumSearchHelp => 'اكتب اسماً لترى إن كان متاحاً للاستئجار.';

  @override
  String get premiumLoadError => 'تعذّر تحميل المتجر';

  @override
  String get premiumTierAll => 'الكل';

  @override
  String get premiumTierLegend => 'أسطوري';

  @override
  String get premiumTierRuby => 'ياقوتي';

  @override
  String get premiumTierGold => 'ذهبي';

  @override
  String get premiumTierSilver => 'فضي';

  @override
  String get premiumTierLegendRule => 'من 1 إلى 3 أحرف';

  @override
  String get premiumTierRubyRule => 'حرف أو رقم مكرر (7777)';

  @override
  String get premiumTierGoldRule => '4–5 أحرف أو نمط (1221، 1212، 123456)';

  @override
  String get premiumTierSilverRule => '6 أو أكثر: أحرف فقط أو أرقام فقط';

  @override
  String get premiumTierNotOnSale => 'غير متاح للبيع بعد';

  @override
  String premiumPricePerPeriod(String coins, int days) {
    return '$coins عملة / $days يوماً';
  }

  @override
  String premiumCoins(String coins) {
    return '$coins عملة';
  }

  @override
  String get premiumSuggestions => 'متاحة الآن';

  @override
  String get premiumNotOnSaleTitle => 'اليوزرات المميزة غير متاحة للبيع بعد';

  @override
  String get premiumNotOnSaleMessage => 'لم تُحدَّد الأسعار بعد. عُد قريباً.';

  @override
  String get premiumNoSuggestionsTitle => 'لا يوجد يوزر متاح هنا الآن';

  @override
  String get premiumNoSuggestionsMessage =>
      'ابحث عن اسم في الأعلى أو جرّب فئة أخرى.';

  @override
  String premiumRules(int days, int grace) {
    return 'كل استئجار مدته $days يوماً ويمكنك التجديد في أي وقت. عند انتهائه تعود إلى يوزرك العادي، ويُحجز الاسم لك $grace أيام.';
  }

  @override
  String get premiumStateAvailable => 'متاح للاستئجار';

  @override
  String get premiumStateNotForSale => 'غير متاح للبيع بعد';

  @override
  String get premiumStateTaken => 'هذا اليوزر مستخدم من شخص آخر';

  @override
  String get premiumStateHeld => 'محجوز لمستأجره السابق لبضعة أيام';

  @override
  String get premiumStateYours => 'هذا يوزرك، ويمكنك تجديده.';

  @override
  String get premiumStateYoursGrace => 'انتهى استئجارك. جدّد الآن لاستعادته.';

  @override
  String get premiumStateReserved => 'هذا اليوزر محجوز';

  @override
  String get premiumStateRegular =>
      'ليس يوزراً مميزاً: يمكنك أخذه مجاناً من الإعدادات › اسم المستخدم إن كان متاحاً.';

  @override
  String get premiumStateInvalid => 'ليس اسم مستخدم صالحاً';

  @override
  String premiumHeldUntil(String date) {
    return 'يصبح متاحاً بعد $date';
  }

  @override
  String get premiumRent => 'استئجار';

  @override
  String get premiumRenew => 'تجديد';

  @override
  String premiumRentFor(String coins) {
    return 'استئجار · $coins عملة';
  }

  @override
  String premiumRenewFor(String coins) {
    return 'تجديد · $coins عملة';
  }

  @override
  String get premiumRentTitle => 'استئجار هذا اليوزر';

  @override
  String get premiumRenewTitle => 'تجديد يوزرك';

  @override
  String get premiumSheetPrice => 'السعر';

  @override
  String get premiumSheetBalance => 'رصيدك';

  @override
  String get premiumSheetUntil => 'لك حتى';

  @override
  String premiumSheetAfter(String username) {
    return 'بعد ذلك تعود إلى ‎@$username ما لم تجدّد.';
  }

  @override
  String get premiumNotEnoughCoins => 'رصيدك من العملات لا يكفي.';

  @override
  String premiumRented(String username) {
    return 'أصبحت الآن ⁦$username⁩';
  }

  @override
  String premiumRenewed(String username) {
    return 'تم تجديد ⁦$username⁩';
  }

  @override
  String get premiumMineTitle => 'يوزرك المميز';

  @override
  String get premiumMineGraceTitle => 'انتهى يوزرك المميز';

  @override
  String premiumMineLeft(String left) {
    return 'متبقٍ $left';
  }

  @override
  String get premiumMineNoEnd => 'بلا تاريخ انتهاء';

  @override
  String get premiumMineGranted => 'مُهدى من فريق Kabso';

  @override
  String premiumMineGrace(String username, String left) {
    return 'عدت إلى ‎@$username، والاسم محجوز لك لمدة $left.';
  }

  @override
  String get premiumRelease => 'إعادة اليوزر';

  @override
  String get premiumReleaseTitle => 'إعادة يوزرك المميز؟';

  @override
  String premiumReleaseBody(String premium, String regular) {
    return 'سيعود ⁦$premium⁩ إلى المتجر الآن وتعود إلى ‎@$regular. لا تُسترد العملات.';
  }

  @override
  String premiumReleased(String username) {
    return 'عدت إلى ‎@$username';
  }

  @override
  String get premiumLeftUnderMinute => 'أقل من دقيقة';

  @override
  String premiumLeftMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String premiumLeftHours(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ساعة',
      many: '$hours ساعة',
      few: '$hours ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
    );
    return '$_temp0 و$minutes د';
  }

  @override
  String premiumLeftDays(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يوماً',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0 و$hours س';
  }

  @override
  String premiumBadgeLabel(String tier, String username) {
    return 'يوزر مميز $tier ⁦$username⁩';
  }

  @override
  String get settingsUsername => 'اسم المستخدم';

  @override
  String get changeUsernameTitle => 'تغيير اسم المستخدم';

  @override
  String get changeUsernameCurrent => 'اسم المستخدم الحالي';

  @override
  String get changeUsernameNew => 'اسم المستخدم الجديد';

  @override
  String get changeUsernameRule =>
      'من 6 إلى 30: أحرف وأرقام (a–z و0–9)، ويُسمح بـ _';

  @override
  String get changeUsernameSave => 'حفظ';

  @override
  String changeUsernameDone(String username) {
    return 'أصبحت الآن ‎@$username';
  }

  @override
  String get changeUsernameNote => 'يصبح اسمك القديم متاحاً للآخرين فوراً.';

  @override
  String changeUsernameRentInstead(String username) {
    return 'استأجر ⁦$username⁩ كيوزر مميز';
  }

  @override
  String changeUsernamePremiumActive(String premium, String regular) {
    return 'أنت تستخدم اليوزر المميز ⁦$premium⁩. لتغيير يوزرك العادي (‎@$regular) أعِد اليوزر المميز أولاً.';
  }

  @override
  String notificationPremiumExpiring(String username, String left) {
    return 'ينتهي يوزرك المميز ⁦$username⁩ خلال $left. جدّده لتحتفظ به.';
  }

  @override
  String notificationPremiumExpired(String username) {
    return 'انتهى يوزرك المميز ⁦$username⁩، وهو محجوز لك لبضعة أيام.';
  }

  @override
  String searchTryHint(String term) {
    return 'جرّب البحث: $term';
  }

  @override
  String get searchCancel => 'إلغاء';

  @override
  String get searchRecentTitle => 'عمليات البحث الأخيرة';

  @override
  String get searchRecentClear => 'مسح الكل';

  @override
  String searchRecentRemove(String term) {
    return 'إزالة «$term» من عمليات البحث الأخيرة';
  }

  @override
  String get searchHotTitle => 'الأكثر بحثاً';

  @override
  String searchHotSemantics(int rank, String term) {
    return 'بحث رائج $rank: $term';
  }

  @override
  String get searchTagTrending => 'رائج';

  @override
  String get searchTagNew => 'جديد';

  @override
  String get searchHotTakeTitle => 'وسوم رائجة';

  @override
  String get searchMore => 'المزيد';

  @override
  String get searchMayLikeTitle => 'قد يعجبك';

  @override
  String get trendingHashtagsTitle => 'الوسوم الرائجة';

  @override
  String get trendingHashtagsEmpty => 'لا توجد وسوم رائجة هذا الأسبوع';

  @override
  String trendingHashtagWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منشور هذا الأسبوع',
      many: '$count منشورًا هذا الأسبوع',
      few: '$count منشورات هذا الأسبوع',
      two: 'منشوران هذا الأسبوع',
      one: 'منشور واحد هذا الأسبوع',
      zero: 'لا منشورات هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String get liveEffectStarting => 'جارٍ تشغيل المؤثر…';

  @override
  String get liveEffectUnavailableStopped =>
      'المؤثر غير متاح الآن: توقّف عن إعطاء صورة جديدة، فعادت الكاميرا من دونه. جرّبه مرة أخرى بعد قليل.';

  @override
  String get liveEffectUnavailableLicence =>
      'المؤثر غير متاح الآن: لم يُقبل ترخيص المؤثرات في هذا الإصدار.';

  @override
  String get liveEffectUnavailableFailed =>
      'المؤثر غير متاح الآن: لم يبدأ على هذا الجهاز. جرّبه مرة أخرى بعد قليل.';

  @override
  String get liveEffectUnavailableBlack =>
      'المؤثر غير متاح الآن: خرجت صورته سوداء، فعادت الكاميرا من دونه قبل أن يراها المشاهدون. جرّبه مرة أخرى لاحقاً.';

  @override
  String get liveEffectUnavailableSlow =>
      'المؤثر غير متاح الآن: كان أبطأ من أن يواكب الكاميرا على هذا الجهاز، فعادت الكاميرا من دونه.';

  @override
  String get liveEffectsEngineFree =>
      'المحرك: المجاني، على الجهاز (⁦ML Kit + MediaPipe⁩)';

  @override
  String get liveFreeBeautyTitle => 'التجميل';

  @override
  String get liveFreeBeautyOn => 'تجميل الوجه';

  @override
  String get liveFreeBeautyNote =>
      'يُنزَّل نموذج الوجه (3.6 ميغابايت) مرة واحدة عند أول استخدام، ثم يعمل كل شيء على الجهاز.';

  @override
  String get liveFreeBeautyUnavailable =>
      'التجميل غير متاح الآن: تعذّر تحميل نموذج الوجه. تحقّق من الاتصال وجرّب مرة أخرى.';

  @override
  String get liveFreeBeautySmooth => 'تنعيم البشرة';

  @override
  String get liveFreeBeautyBrighten => 'تفتيح';

  @override
  String get liveFreeBeautySlim => 'نحت الوجه';

  @override
  String get liveFreeBeautyEyes => 'تكبير العينين';

  @override
  String get liveLuckyBigWin => 'فوز كبير';

  @override
  String get livePermissionTitleVideo => 'الكاميرا والميكروفون لبثّك';

  @override
  String get livePermissionTitleAudio => 'الميكروفون للغرفة الصوتية';

  @override
  String get livePermissionBodyVideo =>
      'يستخدم Kabso Live الكاميرا والميكروفون فقط أثناء بثّك أو جلوسك على مقعد، ليراك الحاضرون ويسمعوك. سيسألك الجهاز مرة واحدة.';

  @override
  String get livePermissionBodyAudio =>
      'يستخدم Kabso Live الميكروفون فقط أثناء وجودك في الغرفة الصوتية ليسمعك الحاضرون، ولا يحتاج الكاميرا هنا. سيسألك الجهاز مرة واحدة.';

  @override
  String get livePermissionContinue => 'متابعة';

  @override
  String get livePermissionNotNow => 'ليس الآن';

  @override
  String get livePermissionOpenSettings => 'فتح الإعدادات';

  @override
  String get livePermissionBlockedVideo =>
      'رفضتَ الوصول من قبل ولن يسألك الجهاز مجدداً. افتح الإعدادات ثم الأذونات، واسمح بالكاميرا والميكروفون.';

  @override
  String get livePermissionBlockedAudio =>
      'رفضتَ الوصول من قبل ولن يسألك الجهاز مجدداً. افتح الإعدادات ثم الأذونات، واسمح بالميكروفون.';

  @override
  String get goLiveMicDeniedTitle => 'اسمح بالميكروفون';

  @override
  String get goLiveMicDeniedBody =>
      'تحتاجه الغرفة الصوتية ليسمعك الحاضرون. اضغط «إعادة المحاولة» ليسألك الجهاز مرة أخرى.';

  @override
  String get livePermissionSeatRefused =>
      'لا يمكن الجلوس على المقعد دون السماح بالوصول.';

  @override
  String get pushPermissionTitle => 'فعّل الإشعارات';

  @override
  String get pushPermissionBody =>
      'ليصلك إشعار بصوت Kabso Live عند وصول رسالة في محادثة عائلتك، وعند المتابعات والإعجابات والتعليقات. يمكنك تغيير ذلك في أي وقت من الإعدادات.';

  @override
  String get pushPermissionAllow => 'السماح بالإشعارات';

  @override
  String get pushPermissionNotNow => 'ليس الآن';

  @override
  String get pushOffTitle => 'الإشعارات متوقفة على هذا الهاتف';

  @override
  String get pushOffBody =>
      'فعّلها ليصلك إشعار بالرسائل الجديدة والتفاعلات حتى والتطبيق مغلق.';

  @override
  String get pushOffBlockedBody =>
      'أوقفتَ الإشعارات من قبل ولن يسألك الجهاز مجدداً. افتح الإعدادات وفعّل الإشعارات لتطبيق Kabso Live.';

  @override
  String get pushTurnOn => 'تفعيل';

  @override
  String get pushOpenSettings => 'فتح الإعدادات';

  @override
  String get notifSettingMessages => 'الرسائل';

  @override
  String get notifSettingMessagesBody =>
      'إشعار على الهاتف عند وصول رسائل جديدة في محادثة عائلتك ورسائلك الخاصة';

  @override
  String get liveMaxXGuaranteed => 'ضمان';

  @override
  String liveLuckyOddsPity(String multiplier, String after) {
    return '×$multiplier مضمون بعد $after محاولة بدون ربح';
  }

  @override
  String liveLuckyTicker(String name, String multiplier, String room) {
    return '$name ربح ×$multiplier في غرفة $room';
  }

  @override
  String liveLuckyGlobalIn(String room) {
    return 'في $room';
  }

  @override
  String liveLuckyGlobalLeaveSeat(String room) {
    return 'ستترك مقعدك وتنتقل إلى $room. هل تريد المتابعة؟';
  }

  @override
  String get liveLuckyGlobalGo => 'انتقال';

  @override
  String get dmTabChats => 'الدردشات';

  @override
  String get dmTabRequests => 'طلبات المراسلة';

  @override
  String dmTabRequestsCount(String count) {
    return 'طلبات المراسلة ($count)';
  }

  @override
  String get dmRequestsEmptyTitle => 'لا توجد طلبات مراسلة';

  @override
  String get dmRequestsHint =>
      'رسائل الأشخاص الذين لا تتابعهم تنتظر هنا. لن يعرفوا أنك رأيتها حتى تقبل.';

  @override
  String get dmRetentionNotice =>
      'الرسائل تُحذف تلقائياً بعد 24 ساعة من إرسالها.';

  @override
  String get dmNoRecentMessages => 'لا توجد رسائل خلال آخر 24 ساعة.';

  @override
  String get dmLastPhoto => '📷 صورة';

  @override
  String get dmPreviewVoice => '🎤 رسالة صوتية';

  @override
  String get dmPreviewSticker => 'ملصق';

  @override
  String dmPreviewGift(String count) {
    return '🎁 هدية ×$count';
  }

  @override
  String get dmPreviewExpired => 'انتهت صلاحية الرسائل';

  @override
  String dmPreviewYou(String text) {
    return 'أنت: $text';
  }

  @override
  String get dmPreviewUnsupported => 'رسالة لا يعرضها هذا الإصدار';

  @override
  String dmRequestBanner(String name) {
    return '$name يريد مراسلتك. اقبل لنقل المحادثة إلى رسائلك.';
  }

  @override
  String get dmAccept => 'قبول';

  @override
  String get dmDecline => 'حذف';

  @override
  String dmRequestLeft(String name, String count) {
    return 'حتى يرد $name يمكنك إرسال $count رسائل أخرى';
  }

  @override
  String dmRequestLimit(String name) {
    return 'انتظر رد $name قبل إرسال المزيد.';
  }

  @override
  String dmNotAllowed(String name) {
    return '$name لا يستقبل رسائل منك.';
  }

  @override
  String get dmUnavailable => 'هذه المحادثة غير متاحة.';

  @override
  String get dmMenu => 'خيارات المحادثة';

  @override
  String get dmMute => 'كتم';

  @override
  String get dmUnmute => 'إلغاء الكتم';

  @override
  String get dmMuted => 'تم كتم المحادثة';

  @override
  String get dmUnmuted => 'تم إلغاء كتم المحادثة';

  @override
  String get dmDeleteConversation => 'حذف المحادثة';

  @override
  String get dmDeleteConversationTitle => 'حذف هذه المحادثة؟';

  @override
  String get dmDeleteConversationBody =>
      'تُحذف من عندك فقط. ستعود إذا وصلت رسالة جديدة.';

  @override
  String get dmReportPerson => 'إبلاغ';

  @override
  String get dmDeleteForMe => 'حذف لدي';

  @override
  String get dmDeleteForEveryone => 'حذف لدى الجميع';

  @override
  String get dmReportMessage => 'الإبلاغ عن الرسالة';

  @override
  String get dmReported => 'شكراً. سنراجع البلاغ.';

  @override
  String get dmVideoNotSupported =>
      'لا يمكن إرسال الفيديو في الرسائل. أرسل صورة بدلاً منه.';

  @override
  String get dmPhotoUnsupported =>
      'لا يمكن إرسال هذا النوع من الصور. اختر صورة JPEG أو PNG أو WebP.';

  @override
  String get dmSending => 'جارٍ الإرسال…';

  @override
  String get dmGiftRequestTitle => 'إرسال هدية كطلب مراسلة؟';

  @override
  String dmGiftRequestBody(String name) {
    return 'لم يقبل $name رسائلك بعد. تُدفع الهدية الآن وتُحسب من رسائل طلبك حتى لو لم يقبل.';
  }

  @override
  String get dmGiftContinue => 'متابعة';

  @override
  String dmGiftMine(String count) {
    return 'هديتك ×$count';
  }

  @override
  String dmGiftTheirs(String name, String count) {
    return 'هدية من $name ×$count';
  }

  @override
  String dmLuckyWon(String coins, String multiplier) {
    return 'ربح $coins كوينز (×$multiplier)';
  }

  @override
  String get dmLuckyNoWin => 'لا ربح هذه المرة';

  @override
  String dmVoiceNote(String length) {
    return 'رسالة صوتية، $length';
  }

  @override
  String get dmPhoto => 'صورة';

  @override
  String get dmStartConversation => 'أرسل رسالة لبدء المحادثة.';

  @override
  String get privacyMessageTitle => 'من يستطيع مراسلتك';

  @override
  String get privacyMessageHint =>
      'من لا تتابعهم يرسلون طلبات مراسلة. الرسائل تُحذف بعد 24 ساعة من إرسالها.';

  @override
  String get errorDmNotAllowed => 'هذا الشخص لا يستقبل رسائل منك.';

  @override
  String get errorDmRequestLimit => 'انتظر الرد قبل إرسال المزيد من الرسائل.';

  @override
  String get errorDmRequestTextOnly =>
      'يمكن إرسال النصوص والملصقات والهدايا فقط حتى يُقبل طلبك.';

  @override
  String get errorDmDeleteWindowPassed =>
      'لم يعد بالإمكان حذف هذه الرسالة لدى الجميع.';

  @override
  String get liveGiftTabQuips => 'إفيهات';

  @override
  String get liveQuipFree => 'مجاني';

  @override
  String get liveQuipSoundboardFree => '∞ مجاني';

  @override
  String get liveQuipFreeOnce => 'إفيه مجاني واحد لك في كل بث.';

  @override
  String get liveQuipSoundboardHint =>
      'مجانية لك وللمشرفين — صوت كل ثانيتين، يسمعه الجميع.';

  @override
  String get liveQuipSoundEffectsOff =>
      'المؤثرات الصوتية مطفأة في الإعدادات: لن تسمعها أنت، لكن الغرفة تسمعها.';

  @override
  String get liveQuipSoundboardTitle => 'المؤثرات الصوتية';

  @override
  String get liveQuipSoundboardEmpty => 'لا توجد مؤثرات مجانية بعد.';

  @override
  String get liveQuipMute => 'كتم الإفيهات';

  @override
  String get liveQuipUnmute => 'تشغيل صوت الإفيهات';

  @override
  String liveQuipQueued(int seconds) {
    return 'في الدور — يبدأ بعد $seconds ث';
  }

  @override
  String liveQuipBannerSent(String words) {
    return 'أرسل إفيه: $words';
  }

  @override
  String liveChatQuipLine(String sender, String words) {
    return '$sender أرسل إفيه: $words';
  }

  @override
  String get errorQuipFreeUsed => 'استخدمت إفيهك المجاني في هذا البث.';

  @override
  String get errorQuipQueueFull => 'إفيهات كثيرة بانتظار دورها، جرّب بعد قليل.';

  @override
  String get liveBoostTitle => 'صواريخ الزيارات';

  @override
  String liveBoostHint(int slots) {
    return 'اختر صاروخاً: يظهر بثك في أعلى قائمة البث مع علامة «مميز» وإطار متحرك. $slots أماكن فقط؛ إن امتلأت ينتظر دوره.';
  }

  @override
  String liveBoostGiftHint(String name) {
    return 'هدية لـ $name: صاروخ يرفع بثه إلى أعلى القائمة مع علامة «مميز». المضيف لا يربح منها عملات.';
  }

  @override
  String liveBoostMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String liveBoostPrice(String coins) {
    return '$coins عملة';
  }

  @override
  String liveBoostSave(int percent) {
    return 'وفّر $percent%';
  }

  @override
  String liveBoostHeld(int count) {
    return 'لديك $count';
  }

  @override
  String get liveBoostStartsNow => 'يبدأ فوراً.';

  @override
  String liveBoostStartsIn(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
    );
    return 'الأماكن ممتلئة: يبدأ خلال $_temp0 على الأكثر.';
  }

  @override
  String liveBoostUseCard(int count) {
    return 'استخدم بطاقة (لديك $count)';
  }

  @override
  String get liveBoostUseCardAction => 'استخدم البطاقة';

  @override
  String liveBoostBuy(String coins) {
    return 'اشترِ بـ $coins عملة';
  }

  @override
  String get liveBoostConfirmTitle => 'صواريخ الزيارات';

  @override
  String liveBoostConfirmCoins(int minutes, String coins) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0 في الأماكن المميزة مقابل $coins عملة؟';
  }

  @override
  String liveBoostConfirmCard(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return 'استخدام بطاقة $_temp0؟';
  }

  @override
  String get liveBoostConfirmAction => 'تأكيد';

  @override
  String get liveBoostDoneNow =>
      'انطلق الصاروخ: البث مميز الآن في أعلى القائمة.';

  @override
  String liveBoostDoneWaiting(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
    );
    return 'في الدور: يبدأ خلال $_temp0 على الأكثر.';
  }

  @override
  String liveBoostRunning(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
    );
    return 'مميز الآن — ينتهي خلال $_temp0.';
  }

  @override
  String liveBoostWaiting(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتين',
      one: 'دقيقة واحدة',
    );
    return 'صاروخ في الدور — يبدأ خلال $_temp0 على الأكثر.';
  }

  @override
  String get liveBoostLoadError => 'تعذّر تحميل صواريخ الزيارات';

  @override
  String get liveBoostFeatured => 'مميز';

  @override
  String get liveBoostGiftAction => 'صاروخ زيارات';

  @override
  String liveRocketStage(int stage) {
    return 'صاروخ $stage';
  }

  @override
  String get errorBoostQueueFull =>
      'الأماكن المميزة محجوزة لوقت طويل؛ جرّب بطاقة أقصر أو لاحقاً.';

  @override
  String get errorBoostCardInsufficient => 'ليس لديك بطاقة بهذه المدة.';

  @override
  String get errorBoostRoomBusy => 'لهذا البث صاروخ زيارات يعمل أو في الدور.';

  @override
  String get liveNewcomerBadge => 'جديد 🌱';

  @override
  String liveNewcomersHint(int days) {
    return 'حسابات عمرها أقل من $days يوماً، موجودة في البث الآن.';
  }

  @override
  String get liveNewcomersEmpty => 'لا يوجد جدد في البث الآن.';

  @override
  String get liveNewcomersLoadError => 'تعذّر تحميل الجدد';

  @override
  String get liveNewcomerWelcome => 'رحّب';

  @override
  String get liveNewcomerWelcomed => 'تم الترحيب ✓';

  @override
  String liveNewcomerWelcomeText(String username) {
    return 'أهلاً @$username 🌱 نوّرت البث';
  }

  @override
  String get liveStatsGiftCoins => 'قيمة الهدايا';

  @override
  String get liveStatsEarnings => 'أرباحك (عرض فقط)';

  @override
  String liveDataDuration(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String get liveDataLoadError => 'تعذّر تحميل مركز البيانات';

  @override
  String get liveDataLives => 'البثوث';

  @override
  String get liveDataLiveTime => 'مدة البث';

  @override
  String get liveDataNewFollowers => 'متابعون جدد';

  @override
  String get liveDataViewers => 'المشاهدون';

  @override
  String get liveDataChartTitle => 'مدة البث عبر الوقت';

  @override
  String get liveDataEmpty => 'لا توجد بثوث منتهية في هذه الفترة.';

  @override
  String get liveDataBestHours => 'أفضل الأوقات';

  @override
  String liveDataBestHourSemantics(String day, int hour) {
    return 'أفضل وقت: $day الساعة $hour';
  }

  @override
  String get liveDataPeriodDay => 'يوم';

  @override
  String get liveDataPeriodWeek => 'أسبوع';

  @override
  String get liveDataPeriodMonth => 'شهر';

  @override
  String get liveDataPeriodYear => 'سنة';

  @override
  String get liveDataHint =>
      'بثوثك المنتهية فقط؛ البث الجاري يُحسب عند انتهائه.';

  @override
  String get liveDataMon => 'إثنين';

  @override
  String get liveDataTue => 'ثلاثاء';

  @override
  String get liveDataWed => 'أربعاء';

  @override
  String get liveDataThu => 'خميس';

  @override
  String get liveDataFri => 'جمعة';

  @override
  String get liveDataSat => 'سبت';

  @override
  String get liveDataSun => 'أحد';

  @override
  String get liveProgramTitle => 'قائمة البرامج';

  @override
  String get liveProgramNow => 'الآن';

  @override
  String liveProgramNext(String time) {
    return 'التالي $time';
  }

  @override
  String get liveProgramStarted => 'بدأت الفقرة';

  @override
  String get liveProgramOpenHint => 'عرض قائمة البرامج';

  @override
  String get liveProgramEmpty => 'لا توجد فقرات بعد';

  @override
  String get liveProgramEditorHint =>
      'حتى 10 فقرات. يراها الجميع في الغرفة ويُعلَن عن كل فقرة عند بدايتها.';

  @override
  String get liveProgramTitleHint => 'عنوان الفقرة';

  @override
  String liveProgramTimeLabel(String time) {
    return 'وقت البداية $time، غيّره';
  }

  @override
  String get liveProgramAdd => 'أضف فقرة';

  @override
  String get liveProgramRemove => 'احذف الفقرة';

  @override
  String get liveProgramSave => 'حفظ القائمة';

  @override
  String get liveProgramOrderError => 'رتّب الفقرات حسب وقت بدايتها';

  @override
  String liveAssistantWelcomeOne(String name) {
    return 'رحّب بـ $name، انضم للتو';
  }

  @override
  String liveAssistantWelcomeMany(String name, int count) {
    return 'رحّب بـ $name و$count آخرين انضموا للتو';
  }

  @override
  String liveAssistantThank(String name, String coins) {
    return 'اشكر $name على هدية بقيمة $coins عملة';
  }

  @override
  String liveAssistantSilence(int minutes) {
    return 'لم تتكلم منذ $minutes دقائق، قل شيئاً للحضور';
  }

  @override
  String liveAssistantRising(int before, int now) {
    return 'الحضور يزداد: من $before إلى $now. استمر';
  }

  @override
  String liveAssistantFalling(int before, int now) {
    return 'الحضور يقل: من $before إلى $now. جرّب فقرة جديدة أو سؤالاً';
  }

  @override
  String liveAssistantRest(int hours) {
    return 'أنت على الهواء منذ $hours ساعات، خذ استراحة قصيرة';
  }

  @override
  String get liveAssistantQuestion => 'الدردشة هادئة، اطرح سؤالاً على الحضور';

  @override
  String get liveAssistantDismiss => 'إخفاء';

  @override
  String get liveAssistantAbout =>
      'تلميحات خفيفة تظهر لك وحدك أثناء البث، من أحداث الغرفة فقط. لا يُرسل شيء.';

  @override
  String get liveAssistantOn => 'تشغيل المساعد';

  @override
  String get liveAssistantKindWelcome => 'الترحيب بالقادمين';

  @override
  String get liveAssistantKindThank => 'الشكر على الهدايا الكبيرة';

  @override
  String get liveAssistantKindSilence => 'تنبيه عند الصمت';

  @override
  String get liveAssistantKindAudience => 'زيادة أو نقص الحضور';

  @override
  String get liveAssistantKindRest => 'استراحة في البث الطويل';

  @override
  String get liveAssistantKindQuestion => 'اقتراح سؤال عند هدوء الدردشة';

  @override
  String get liveToolQuality => 'الجودة';

  @override
  String get liveQualitySmooth => 'سلس';

  @override
  String get liveQualitySmoothDetail => '480p، أخف على الاتصال الضعيف';

  @override
  String get liveQualityNormal => 'عادي';

  @override
  String get liveQualityNormalDetail => '720p، الجودة الافتراضية';

  @override
  String get liveQualityConnExcellent => 'الاتصال ممتاز';

  @override
  String get liveQualityConnGood => 'الاتصال جيد';

  @override
  String get liveQualityConnPoor => 'الاتصال ضعيف';

  @override
  String get liveQualityConnLost => 'انقطع الاتصال، جارٍ إعادة المحاولة';

  @override
  String get liveQualityConnUnknown => 'جارٍ قياس الاتصال';

  @override
  String get liveQualityFailed => 'تعذّر تغيير الجودة، بقيت كما كانت';

  @override
  String get liveQualitySuggest => 'اتصالك ضعيف، فعّل السلاسة؟';

  @override
  String get liveQualitySuggestAction => 'فعّل';

  @override
  String get liveQualityHigh => 'عالي 1080p';

  @override
  String get liveQualityHighDetail =>
      '1080p بـ 30 إطاراً، يعود إلى 720p تلقائياً إذا ضعف الاتصال';

  @override
  String get liveQualityHighSlowUplink =>
      'سرعة الرفع الآن أقل من المطلوب لـ 1080p';

  @override
  String get liveQualityHighUnsupported =>
      'هذه الكاميرا لا تلتقط 1080p، بقيت الجودة كما كانت';

  @override
  String get liveQualityHighFallback => 'تم خفض الجودة لضعف الاتصال';

  @override
  String get liveQualitySmoothOn => 'تم تفعيل السلاسة';

  @override
  String get liveStickersHint =>
      'حتى 3 ملصقات يراها الجميع. اسحب الملصق على البث لتحريكه، وبإصبعين لتكبيره وتدويره.';

  @override
  String liveStickersOnLive(int count, int max) {
    return 'على البث ($count من $max)';
  }

  @override
  String get liveStickersNone => 'لا ملصقات بعد';

  @override
  String get liveStickersFull => '3 ملصقات كحد أقصى، احذف واحداً لإضافة غيره';

  @override
  String get liveStickersRemove => 'احذف الملصق';

  @override
  String get liveStickersTextHint => 'اكتب ملصقاً نصياً';

  @override
  String get liveStickersAddText => 'أضف';

  @override
  String get errorYoutubeVideoUnavailable =>
      'لا يمكن تشغيل هذا الفيديو هنا، قد يكون خاصاً أو ممنوعاً من التشغيل خارج يوتيوب.';

  @override
  String get errorYoutubeSearchUnavailable =>
      'البحث في يوتيوب غير مفعّل بعد، الصق رابط الفيديو.';

  @override
  String get liveWatchTitle => 'يوتيوب';

  @override
  String get liveWatchLinkHint => 'الصق رابط فيديو يوتيوب';

  @override
  String get liveWatchPlay => 'شاهدوا معاً';

  @override
  String get liveWatchSearchHint => 'ابحث في يوتيوب';

  @override
  String get liveWatchSearchOff => 'البحث غير مفعّل بعد، الصق رابطاً';

  @override
  String get liveWatchNowPlaying => 'يُعرض الآن';

  @override
  String get liveWatchStop => 'إيقاف العرض';

  @override
  String liveWatchSuggestions(int count) {
    return 'اقتراحات المشاهدين ($count)';
  }

  @override
  String get liveWatchNoSuggestions => 'لا اقتراحات الآن';

  @override
  String get liveWatchApprove => 'اعرضه';

  @override
  String get liveWatchReject => 'تجاهل';

  @override
  String liveWatchSuggestedBy(String name) {
    return 'اقترحه $name';
  }

  @override
  String get liveWatchSuggest => 'اقترح فيديو';

  @override
  String get liveWatchSuggestSend => 'أرسل الاقتراح';

  @override
  String get liveWatchSuggestSent => 'وصل اقتراحك للمضيف';

  @override
  String get liveWatchBadLink => 'هذا ليس رابط فيديو يوتيوب';

  @override
  String get liveWatchHide => 'إخفاء الفيديو';

  @override
  String get liveWatchShow => 'عرض الفيديو';

  @override
  String get liveWatchDrag => 'اسحب لنقل نافذة الفيديو';

  @override
  String get liveWatchPlayerError => 'تعذّر تشغيل الفيديو على هذا الهاتف';

  @override
  String liveWatchNewSuggestion(String title) {
    return 'اقتراح جديد: $title';
  }

  @override
  String get liveWinTierWin => 'فوز';

  @override
  String get liveWinTierHuge => 'فوز ضخم';

  @override
  String liveWinBannerSemantics(
    String label,
    String name,
    String multiplier,
    String coins,
  ) {
    return '$label: $name ربح ⁦×$multiplier⁩، $coins عملة';
  }

  @override
  String liveWinBannerSent(String name, String gift) {
    return '$name أرسل $gift';
  }

  @override
  String liveWinBannerWon(String multiplier, String coins) {
    return 'ربح $multiplier وحصل على $coins';
  }

  @override
  String get meHubOpenProfile => 'افتح ملفك الشخصي';

  @override
  String get meHubFans => 'المعجبون';

  @override
  String get meHubLevels => 'المستويات';

  @override
  String get meHubVip => 'شراء VIP';

  @override
  String get meHubEarn => 'اربح المال';

  @override
  String get meHubCreatorCenter => 'مركز صنّاع المحتوى';

  @override
  String get meHubEventCenter => 'مركز الفعاليات';

  @override
  String get meHubWallet => 'المحفظة';

  @override
  String get meHubItemBag => 'الحقيبة';

  @override
  String get meHubMyProfile => 'ملفي الشخصي';

  @override
  String get meHubSvip => 'SVIP';

  @override
  String get meHubTaskCenter => 'مركز المهام';

  @override
  String get meHubRanking => 'التصنيف';

  @override
  String meHubSoonItem(String item) {
    return '$item، قريباً';
  }

  @override
  String meHubCoins(String coins) {
    return '$coins كوينز';
  }

  @override
  String get createMenuTitle => 'إنشاء';

  @override
  String get createMenuPost => 'منشور';

  @override
  String get createMenuPostHint => 'صور أو فيديو أو نص';

  @override
  String get createMenuReel => 'ريلز';

  @override
  String get createMenuReelHint => 'فيديو عمودي قصير يظهر في لحظات';

  @override
  String get createMenuStory => 'ستوري';

  @override
  String get createMenuStoryHint => 'صورة تبقى ٢٤ ساعة';

  @override
  String get createMenuLive => 'بث مباشر';

  @override
  String get createMenuLiveHint => 'فيديو أو صوت، الآن';

  @override
  String get createVideoUpTo => 'فيديو واحد حتى ٩٠ ثانية';

  @override
  String get createLibraryVideo => 'فيديو';

  @override
  String get createLibraryNoVideos => 'لا توجد فيديوهات على هذا الجهاز.';

  @override
  String get createPickVideo => 'اختيار فيديو';

  @override
  String get createRemoveVideo => 'إزالة الفيديو';

  @override
  String createVideoLabel(String length) {
    return 'فيديو، $length';
  }

  @override
  String get createVideoOrPhotos =>
      'يضم المنشور صوراً أو فيديو واحداً، وليس الاثنين معاً.';

  @override
  String get createVideoTooLong =>
      'يمكن أن تصل مدة فيديو المنشور إلى ٩٠ ثانية.';

  @override
  String get createVideoTooLarge => 'حجم هذا الفيديو أكبر من ٢٠٠ ميغابايت.';

  @override
  String get createVideoTooShort => 'اختر فيديو مدته ثانية واحدة على الأقل.';

  @override
  String get createVideoUnsupported =>
      'صيغة هذا الفيديو غير مدعومة. استخدم MP4 أو MOV.';

  @override
  String get createVideoUnreadable =>
      'تعذّرت قراءة هذا الفيديو على هذا الجهاز.';

  @override
  String get createVideoInvalid => 'تعذّرت معالجة الفيديو. جرّب فيديو آخر.';

  @override
  String get createVideoUploadsUnavailable =>
      'رفع الفيديو غير متاح حالياً. حاول مرة أخرى لاحقاً.';

  @override
  String createUploadingVideo(int percent) {
    return 'جارٍ رفع الفيديو… $percent٪';
  }

  @override
  String get createPostedVideoInReview =>
      'تم النشر. سيظهر للآخرين بعد مراجعة الفيديو';

  @override
  String get reelNewTitle => 'ريلز جديد';

  @override
  String get reelNewBody => 'فيديو عمودي حتى ٦٠ ثانية، يظهر في لحظات.';

  @override
  String get reelPickVideo => 'اختيار فيديو';

  @override
  String get reelChangeVideo => 'تغيير الفيديو';

  @override
  String get reelCaptionHint => 'اكتب وصفاً… #وسوم @إشارات';

  @override
  String get reelShare => 'نشر';

  @override
  String get reelShared => 'تم نشر الريلز';

  @override
  String get reelSharedInReview => 'تم النشر. سيظهر الريلز للآخرين بعد مراجعته';

  @override
  String get reelTooLong => 'يمكن أن تصل مدة الريلز إلى ٦٠ ثانية.';

  @override
  String get reelTooLarge => 'حجم هذا الفيديو أكبر من ١٠٠ ميغابايت.';

  @override
  String get reelVertical =>
      'تبدو الريلز أفضل عمودية؛ سيظهر هذا الفيديو بأشرطة.';

  @override
  String get reelPreview => 'أول لقطة من الريلز';

  @override
  String get videoPlay => 'تشغيل الفيديو';

  @override
  String get videoPause => 'إيقاف الفيديو مؤقتاً';

  @override
  String get videoMute => 'كتم الصوت';

  @override
  String get videoUnmute => 'تشغيل الصوت';

  @override
  String get videoCannotPlay => 'لا يمكن تشغيل هذا الفيديو الآن';

  @override
  String get liveGuestCamera => 'الكاميرا';

  @override
  String get liveGuestCameraOff => 'الكاميرا مطفأة';

  @override
  String get liveMiniOpen => 'العودة إلى البث';

  @override
  String get liveMiniLeave => 'مغادرة البث';

  @override
  String get walletBalanceLabel => 'رصيد الكوينز';

  @override
  String get walletRecharge => 'شحن';

  @override
  String get walletRechargeSoon => 'الشحن قريباً — لم تُحدَّد طريقة الدفع بعد.';

  @override
  String get walletHistoryTitle => 'سجل المعاملات';

  @override
  String get walletHistoryEmpty => 'لا معاملات بعد';

  @override
  String get walletHistoryEmptyBody => 'ستظهر هنا كل عملية تغيّر رصيدك.';

  @override
  String get walletLoadError => 'تعذّر تحميل المحفظة';

  @override
  String walletBalanceAfter(String coins) {
    return 'الرصيد بعدها $coins';
  }

  @override
  String get walletReasonAdminGrant => 'منحة من الفريق';

  @override
  String get walletReasonAdminRevoke => 'سحب من الفريق';

  @override
  String get walletReasonBulletMessage => 'رسالة عامة';

  @override
  String get walletReasonFamilyCreate => 'إنشاء عائلة';

  @override
  String get walletReasonCpRequest => 'طلب CP';

  @override
  String get walletReasonCpRefund => 'استرداد طلب CP';

  @override
  String get walletReasonCpGift => 'هدية CP';

  @override
  String get walletReasonLiveGift => 'هدية في بث';

  @override
  String get walletReasonLuckyGift => 'هدية الحظ';

  @override
  String get walletReasonLuckyGiftWin => 'ربح من هدية الحظ';

  @override
  String get walletReasonPremiumRent => 'استئجار اسم مميز';

  @override
  String get walletReasonPremiumRenew => 'تجديد اسم مميز';

  @override
  String get walletReasonDmGift => 'هدية في محادثة';

  @override
  String get walletReasonLiveBoost => 'صاروخ زيارات';

  @override
  String get walletReasonLiveBoostRefund => 'استرداد صاروخ زيارات';

  @override
  String get walletReasonOther => 'تغيير في الرصيد';

  @override
  String get earnTotal => 'إجمالي أرباحك';

  @override
  String get earnLast7Days => 'آخر 7 أيام';

  @override
  String get earnLast30Days => 'آخر 30 يوماً';

  @override
  String get earnDisplayOnly =>
      'الأرباح للعرض فقط: هي حصتك من الهدايا التي تصلك في البث والمحادثات، ولا تُضاف إلى رصيد الكوينز.';

  @override
  String get earnWithdraw => 'سحب الأرباح';

  @override
  String get earnWithdrawSoon => 'السحب قريباً — لم تُحدَّد طريقة الدفع بعد.';

  @override
  String get earnHistoryTitle => 'سجل الأرباح';

  @override
  String get earnEmpty => 'لا أرباح بعد';

  @override
  String get earnEmptyBody =>
      'عندما تصلك هدايا في البث أو المحادثات تظهر حصتك منها هنا.';

  @override
  String get earnLoadError => 'تعذّر تحميل الأرباح';

  @override
  String earnGiftLine(String gift, int quantity) {
    return '$gift × $quantity';
  }

  @override
  String earnFrom(String name) {
    return 'من $name';
  }

  @override
  String get earnFromHidden => 'من حساب غير متاح';

  @override
  String get earnContextLive => 'في بث';

  @override
  String get earnContextDm => 'في محادثة';

  @override
  String earnShare(String percent, String coins) {
    return 'حصتك $percent٪ من $coins';
  }

  @override
  String get creatorPeriod7 => '7 أيام';

  @override
  String get creatorPeriod30 => '30 يوماً';

  @override
  String get creatorPeriodAll => 'كل الوقت';

  @override
  String get creatorFollowers => 'المتابعون';

  @override
  String get creatorFollowersTotal => 'كل المتابعين';

  @override
  String get creatorFollowersNew => 'تابعوك في هذه الفترة';

  @override
  String get creatorPosts => 'المنشورات';

  @override
  String get creatorReels => 'الريلز';

  @override
  String get creatorPublished => 'منشورة';

  @override
  String get creatorViews => 'المشاهدات';

  @override
  String get creatorLikes => 'الإعجابات';

  @override
  String get creatorComments => 'التعليقات';

  @override
  String get creatorShares => 'المشاركات';

  @override
  String get creatorContentHint => 'ما نُشر في هذه الفترة، بأرقامه حتى الآن.';

  @override
  String get creatorNoPosts => 'لم تنشر شيئاً في هذه الفترة.';

  @override
  String get creatorLive => 'البث المباشر';

  @override
  String get creatorLiveHint => 'البثوث التي بدأت في هذه الفترة وانتهت.';

  @override
  String get creatorNoLives => 'لا بثوث منتهية في هذه الفترة.';

  @override
  String get creatorPeakViewers => 'أعلى مشاهدة';

  @override
  String get creatorOpenProfile => 'منشوراتي وريلزي';

  @override
  String get creatorTabLive => 'البث';

  @override
  String get creatorTabAgency => 'الوكالة';

  @override
  String creatorMonthData(String month) {
    return 'بيانات $month';
  }

  @override
  String get creatorLiveData => 'بيانات البث';

  @override
  String get creatorLiveMinutes => 'دقائق البث';

  @override
  String get creatorNewFans => 'متابعون جدد';

  @override
  String get creatorNewEarnings => 'أرباح جديدة';

  @override
  String get creatorServices => 'خدمات البث';

  @override
  String get creatorSvcPreview => 'معاينة البث';

  @override
  String get creatorSvcCover => 'تعديل الغلاف';

  @override
  String get creatorSvcEvents => 'فعالياتي';

  @override
  String get creatorSvcHostLevel => 'مستوى المضيف';

  @override
  String get creatorSvcViolations => 'مخالفات الحساب';

  @override
  String get creatorSvcAcademy => 'أكاديمية المضيف';

  @override
  String get creatorSvcSupport => 'خدمة العملاء';

  @override
  String get creatorSvcIdentity => 'توثيق الهوية';

  @override
  String get creatorSvcFans => 'نمو المتابعين';

  @override
  String get creatorTrafficHint =>
      'تشتري صاروخ الزيارات من «أدوات الغرفة» أثناء بثك.';

  @override
  String get creatorGoLive => 'ابدأ البث';

  @override
  String get creatorLoadError => 'تعذّر تحميل الإحصاءات';

  @override
  String get dmSearch => 'بحث في المحادثات';

  @override
  String get dmSearchHint => 'ابحث بالاسم أو اسم المستخدم';

  @override
  String get dmSearchClose => 'إغلاق البحث';

  @override
  String dmSearchEmpty(String query) {
    return 'لا توجد محادثة تطابق «$query»';
  }

  @override
  String get dmNewMessageHint => 'اكتب اسم الشخص أو اسم المستخدم';

  @override
  String get dmNewMessageEmpty => 'لم نجد أحداً بهذا الاسم';

  @override
  String get dmNewMessageStart => 'ابحث عن شخص لتبدأ محادثة معه';

  @override
  String get dmConversationActions => 'خيارات المحادثة';

  @override
  String get dmMarkRead => 'تعليم كمقروءة';

  @override
  String get dmMarkUnread => 'تعليم كغير مقروءة';

  @override
  String get dmMarkedUnread => 'معلّمة كغير مقروءة';

  @override
  String get dmCopy => 'نسخ';

  @override
  String get dmCopied => 'تم نسخ الرسالة';

  @override
  String get dmViewProfile => 'عرض الملف الشخصي';

  @override
  String get chatVoiceUnavailable => 'الرسائل الصوتية غير متاحة على هذا الجهاز';

  @override
  String get profileEditPhotoSheetTitle => 'صورة الملف الشخصي';

  @override
  String get profileEditPhotoLibrary => 'اختيار من الصور';

  @override
  String get profileEditPhotoCamera => 'التقاط صورة';

  @override
  String get profileEditPhotoRemove => 'إزالة الصورة';

  @override
  String get profileEditPhotoUpdated => 'تم تحديث صورتك';

  @override
  String get profileEditPhotoRemoved => 'تمت إزالة صورتك';

  @override
  String get profileEditPhotoUploading => 'جارٍ رفع الصورة…';

  @override
  String get profileEditCropTitle => 'قص الصورة';

  @override
  String get profileEditCropHint => 'اسحب الصورة وكبّرها لتملأ المربع';

  @override
  String get profileEditCropDone => 'تم';

  @override
  String get profileEditSaved => 'تم الحفظ';

  @override
  String get profileEditBioPlaceholder => 'أضف نبذة عنك';

  @override
  String profileEditBioTooLong(int max, int lines) {
    return 'يمكن أن تصل النبذة إلى $max حرف و$lines أسطر.';
  }

  @override
  String get profileEditBioInvalid => 'تحتوي النبذة على رموز غير مسموح بها.';

  @override
  String get profileEditNameHelp =>
      'يظهر اسمك في ملفك وفي البث والرسائل. يمكن أن يتكرر بين الحسابات.';

  @override
  String get profileEditBioHelp => 'تظهر النبذة للجميع في ملفك الشخصي.';

  @override
  String createLibraryVideoTooLong(String length, int seconds) {
    return 'فيديو، $length، أطول من $seconds ثانية، لا يمكن استخدامه';
  }

  @override
  String get tasksLoadError => 'تعذّر تحميل المهام';

  @override
  String get tasksCheckInCalendar => 'التقويم';

  @override
  String tasksCheckInMoreDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'سجّل $days يوماً إضافياً لتحصل على مكافأة إضافية',
      few: 'سجّل $days أيام إضافية لتحصل على مكافأة إضافية',
      two: 'سجّل يومين إضافيين لتحصل على مكافأة إضافية',
      one: 'سجّل يوماً إضافياً لتحصل على مكافأة إضافية',
    );
    return '$_temp0';
  }

  @override
  String get tasksCalendarTitle => 'تقويم تسجيل الدخول';

  @override
  String tasksCalendarBody(String coins) {
    return 'سجّل الدخول كل يوم: اليوم السابع على التوالي يمنحك $coins عملة إضافية، ويوم فائت يعيد العدّ.';
  }

  @override
  String tasksDayCoins(String coins) {
    return '$coins عملة';
  }

  @override
  String get eventsTitle => 'الفعاليات';

  @override
  String get tasksCheckInTitle => 'مكافآت تسجيل الدخول';

  @override
  String tasksCheckInBonusToday(String coins) {
    return 'اليوم يوم المكافأة: $coins عملة إضافية';
  }

  @override
  String get tasksCheckInAction => 'تسجيل';

  @override
  String tasksStreak(String days) {
    return '$days أيام متتالية';
  }

  @override
  String get tasksToday => 'اليوم';

  @override
  String tasksDailyCap(String earned, String cap) {
    return 'مكافآت اليوم: $earned من $cap كرزة';
  }

  @override
  String tasksMonthlyCap(String earned, String cap) {
    return 'مكافآت الشهر: $earned من $cap كرزة';
  }

  @override
  String get tasksRewardsTitle => 'مكافآت المهام';

  @override
  String get tasksWeeklyTitle => 'مهام المضيف الأسبوعية';

  @override
  String get tasksWeeklyHint => 'تتجدد كل يوم إثنين.';

  @override
  String get tasksCreatorTitle => 'مهام صانع المحتوى';

  @override
  String get tasksCreatorHint => 'ضمن مكافآت اليوم.';

  @override
  String get tasksCreatorWeeklyTitle => 'مهام صانع المحتوى الأسبوعية';

  @override
  String get tasksEmpty => 'لا مهام الآن';

  @override
  String get tasksEmptyBody => 'ستظهر هنا المهام عندما يضيفها فريق كبسو.';

  @override
  String get tasksActionGo => 'اذهب';

  @override
  String get tasksActionClaim => 'استلم';

  @override
  String get tasksActionDone => 'تم';

  @override
  String tasksRewardReceived(String coins) {
    return 'حصلت على $coins عملة';
  }

  @override
  String get tasksNoCoinsCap => 'تم التسجيل — بلغت حدّ مكافآت اليوم';

  @override
  String tasksRewardReceivedCherries(String cherries) {
    return 'حصلت على $cherries كرزة';
  }

  @override
  String get tasksCapReached => 'بلغت حدّ مكافآت المهام لهذا اليوم';

  @override
  String get tasksMonthlyCapReached => 'بلغت حدّ مكافآت المهام لهذا الشهر';

  @override
  String get eventsTabCalendar => 'تقويم الفعاليات';

  @override
  String get eventsTabPermanent => 'الفعاليات الدائمة';

  @override
  String get eventsTabRegional => 'الإقليمية';

  @override
  String get eventsIntroTitle => 'تقويم الفعاليات';

  @override
  String get eventsIntroBody =>
      'أبرز فعاليات كبسو الرسمية كل شهر — اعرف المكافآت وطريقة المشاركة مبكراً. اضغط أي فعالية لتفاصيلها.';

  @override
  String eventsCalendarMonth(String month) {
    return 'تقويم فعاليات $month';
  }

  @override
  String get eventsPreviousMonth => 'الشهر السابق';

  @override
  String get eventsNextMonth => 'الشهر التالي';

  @override
  String eventsMore(String count) {
    return 'و$count أخرى';
  }

  @override
  String get eventsEmptyMonth => 'لا فعاليات هذا الشهر';

  @override
  String get eventsEmpty => 'لا فعاليات الآن';

  @override
  String get eventsEmptyBody => 'عندما يعلن فريق كبسو عن فعالية ستظهر هنا.';

  @override
  String get eventsNoCountry => 'حدّد بلدك لترى فعاليات منطقتك';

  @override
  String get eventsNoCountryBody => 'يمكنك اختيار بلدك من تعديل الملف الشخصي.';

  @override
  String get eventsLoadError => 'تعذّر تحميل الفعاليات';

  @override
  String get eventsEnded => 'انتهت';

  @override
  String get eventsFeatured => 'رائج';

  @override
  String get eventsUpcoming => 'قريباً';

  @override
  String get eventsRunning => 'جارية';

  @override
  String eventsDates(String start, String end) {
    return 'من $start إلى $end';
  }

  @override
  String eventsSince(String start) {
    return 'منذ $start';
  }

  @override
  String get eventsDetailTitle => 'تفاصيل الفعالية';

  @override
  String get eventsForHosts => 'للمضيفين فقط';

  @override
  String get eventsRules => 'القواعد';

  @override
  String get eventsNoRules => 'لا قواعد إضافية.';

  @override
  String get eventsPrizes => 'الجوائز';

  @override
  String get eventsNoPrizes => 'لا جوائز لهذه الفعالية.';

  @override
  String get eventsPrizesReview =>
      'تُصرف الجوائز تلقائياً بعد 24 ساعة من انتهاء الفعالية.';

  @override
  String get eventsPrizesPaid => 'صُرفت الجوائز.';

  @override
  String eventsRank(String rank) {
    return 'المركز $rank';
  }

  @override
  String eventsRanks(String from, String to) {
    return 'المراكز $from–$to';
  }

  @override
  String get eventsBoard => 'لوحة الصدارة';

  @override
  String get eventsBoardLive => 'مباشر';

  @override
  String get eventsBoardFinal => 'النتائج النهائية';

  @override
  String get eventsBoardEmpty => 'لا أحد في اللوحة بعد.';

  @override
  String eventsMeRank(String rank) {
    return 'ترتيبك: $rank';
  }

  @override
  String get eventsMeNotRanked => 'لم تدخل اللوحة بعد';

  @override
  String get eventsMetricGiftsReceived => 'قيمة الهدايا المستلمة';

  @override
  String get eventsMetricGiftsSent => 'قيمة الهدايا المرسلة';

  @override
  String get eventsMetricLiveMinutes => 'دقائق البث';

  @override
  String get eventsMetricTaps => 'النقرات المستلمة';

  @override
  String get eventsMetricFollowers => 'المتابعون الجدد';

  @override
  String get eventsMetricOther => 'النقاط';

  @override
  String get svipLoadError => 'تعذّر تحميل SVIP';

  @override
  String get svipRules => 'قواعد SVIP';

  @override
  String svipRulesBody(String days) {
    return 'تحصل على SVIP بإرسال الهدايا: أنفق العملات على الهدايا خلال $days يوماً لتصل إلى المستوى، ويبقى معك 30 يوماً من آخر مرة بلغته. لا يُشترى SVIP بالمال.';
  }

  @override
  String get svipNotYet => 'لست SVIP بعد';

  @override
  String svipTier(String tier) {
    return 'SVIP $tier';
  }

  @override
  String svipUntil(String tier, String date) {
    return '$tier حتى $date';
  }

  @override
  String svipTrack(String tier, String count) {
    return 'المستوى $tier من $count';
  }

  @override
  String get svipLocked => 'مقفل';

  @override
  String get svipUnlocked => 'مفتوح';

  @override
  String svipSpendToUpgrade(String coins, String days) {
    return 'أنفق $coins عملة على الهدايا خلال $days يوماً للترقية';
  }

  @override
  String svipSpent(String coins, String days) {
    return 'أنفقت $coins عملة في آخر $days يوماً';
  }

  @override
  String get svipTop => 'وصلت إلى أعلى مستوى SVIP';

  @override
  String get svipPerksTitle => 'امتيازات SVIP';

  @override
  String get svipPerksSoon => 'الامتيازات قيد الإعداد وستُفعَّل تباعاً.';

  @override
  String svipSpendMore(String coins, String tier) {
    return 'أنفق $coins عملة أخرى للوصول إلى $tier';
  }

  @override
  String get svipCta => 'أرسل هدية';

  @override
  String get walletTabCoins => 'العملات';

  @override
  String get walletRechargeTitle => 'شحن العملات';

  @override
  String walletBonus(String coins) {
    return '$coins إضافية';
  }

  @override
  String get walletOffer => 'عرض كبير';

  @override
  String walletGetCoins(String coins, String total) {
    return 'احصل على $coins عملة · المجموع $total';
  }

  @override
  String get walletPackagesEmpty => 'لا باقات شحن الآن';

  @override
  String get walletPackagesError => 'تعذّر تحميل باقات الشحن';

  @override
  String get walletReasonTaskReward => 'مكافأة مهمة';

  @override
  String get walletReasonCheckIn => 'مكافأة تسجيل الدخول';

  @override
  String get walletReasonEventPrize => 'جائزة فعالية';

  @override
  String get registerGenderLabel => 'الجنس';

  @override
  String get registerGenderHelper =>
      'لا يظهر في ملفك الشخصي إلا إذا اخترت ذلك لاحقاً.';

  @override
  String get registerGenderRequired => 'اختر خياراً';

  @override
  String get genderMale => 'ذكر';

  @override
  String get genderFemale => 'أنثى';

  @override
  String get genderUndisclosed => 'أفضّل عدم الذكر';

  @override
  String get categorySinger => 'مغنٍّ';

  @override
  String get categoryMusician => 'موسيقي';

  @override
  String get categoryPoet => 'شاعر';

  @override
  String get categoryPresenter => 'مقدّم برامج';

  @override
  String get categoryGamer => 'لاعب ألعاب';

  @override
  String get categoryContentCreator => 'صانع محتوى';

  @override
  String get categoryAthlete => 'رياضي';

  @override
  String get categoryArtist => 'فنان';

  @override
  String get categoryBlogger => 'مدوّن';

  @override
  String get categoryPublicFigure => 'شخصية عامة';

  @override
  String get categoryOther => 'أخرى';

  @override
  String get profileEditNotSet => 'غير محدد';

  @override
  String get profileEditGenderShow => 'إظهار الجنس في ملفي';

  @override
  String get profileEditGenderShowHint =>
      'مخفي افتراضياً. «أفضّل عدم الذكر» لا يظهر أبداً.';

  @override
  String profileEditGenderHidden(String gender) {
    return '$gender · مخفي';
  }

  @override
  String get profileEditCategoryNone => 'بدون فئة';

  @override
  String get profileEditCategoryHint => 'تظهر تحت اسمك في ملفك الشخصي.';

  @override
  String profileEditLinksValue(int count) {
    return '$count من 3';
  }

  @override
  String get profileEditLinksHint =>
      'حتى 3 روابط تبدأ بـ https://‎. روابط إنستغرام وتيك توك ويوتيوب وفيسبوك وإكس تُفتح مباشرة، وأي رابط آخر بعد تنبيه.';

  @override
  String get profileEditLinkUrl => 'الرابط';

  @override
  String get profileEditLinkLabel => 'الاسم (اختياري)';

  @override
  String get profileEditLinkAdd => 'إضافة رابط';

  @override
  String get profileEditLinkRemove => 'حذف الرابط';

  @override
  String get profileEditLinkInvalid =>
      'رابط غير صالح: يجب أن يبدأ بـ https://‎ ويكون اسم موقع، بلا كلمة مرور أو منفذ أو عنوان IP.';

  @override
  String get profileEditLinkTooLong => 'الرابط طويل جداً.';

  @override
  String profileEditLinkLabelTooLong(int max) {
    return 'الاسم حتى $max حرفاً في سطر واحد.';
  }

  @override
  String get profileEditLinkDuplicate => 'هذا الرابط مضاف مسبقاً.';

  @override
  String get profileEditPinHint =>
      'ثبّت حتى 3 منشورات لتظهر أولاً في ملفك، من قائمة «…» في المنشور.';

  @override
  String get privacyPrivateTitle => 'الحساب الخاص';

  @override
  String get privacyPrivateLabel => 'حساب خاص';

  @override
  String get privacyPrivateHint =>
      'متابعوك فقط يرون منشوراتك وريلزك وقصصك. من يريد متابعتك يرسل طلباً تقبله أو ترفضه. البث المباشر يبقى عاماً.';

  @override
  String get privacyMakePublicTitle => 'جعل الحساب عاماً؟';

  @override
  String get privacyMakePublicBody =>
      'سيرى الجميع منشوراتك وريلزك وقصصك، وستُقبل كل طلبات المتابعة المعلّقة.';

  @override
  String get privacyMakePublicConfirm => 'جعله عاماً';

  @override
  String get followRequestsTitle => 'طلبات المتابعة';

  @override
  String get followRequestsEmptyTitle => 'لا توجد طلبات';

  @override
  String get followRequestsEmptyBody =>
      'عندما يطلب أحد متابعة حسابك الخاص يظهر هنا.';

  @override
  String get followRequestAccept => 'قبول';

  @override
  String get followRequestDecline => 'رفض';

  @override
  String followRequestAccepted(String name) {
    return '$name يتابعك الآن';
  }

  @override
  String get followRequestDeclined => 'تم رفض الطلب';

  @override
  String get followRequested => 'تم الطلب';

  @override
  String profileCancelRequestConfirm(String name) {
    return 'إلغاء طلب متابعة $name؟';
  }

  @override
  String get profileCancelRequest => 'إلغاء الطلب';

  @override
  String get profileRequestSent => 'أُرسل طلب المتابعة';

  @override
  String get linkLeavingTitle => 'أنت تغادر Kabso';

  @override
  String get linkLeavingBody =>
      'هذا الرابط يفتح موقعاً خارج Kabso. تأكّد أنك تثق به قبل المتابعة.';

  @override
  String get linkLeavingOpen => 'فتح الرابط';

  @override
  String get linkReport => 'الإبلاغ عن الرابط';

  @override
  String get linkReportTitle => 'لماذا تبلّغ عن هذا الرابط؟';

  @override
  String get linkCopy => 'نسخ الرابط';

  @override
  String get linkCopied => 'تم نسخ الرابط';

  @override
  String get linkOpenFailed => 'تعذّر فتح الرابط';

  @override
  String linkSemantics(String name) {
    return 'رابط: $name';
  }

  @override
  String notifFollowRequest(String who) {
    return '$who طلب متابعتك';
  }

  @override
  String notifFollowRequestAccepted(String who) {
    return '$who قبل طلب متابعتك';
  }

  @override
  String get notifAvatarRemoved =>
      'أزال فريق الإشراف صورة ملفك الشخصي لمخالفتها الإرشادات';

  @override
  String bagDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يوماً',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String bagHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ساعة',
      many: '$hours ساعة',
      few: '$hours ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String bagMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String bagDurationPair(String first, String second) {
    return '$first $second';
  }

  @override
  String bagRemaining(String duration) {
    return 'متبقٍ $duration';
  }

  @override
  String get bagEndsToday => 'ينتهي اليوم';

  @override
  String get bagPermanent => 'دائم';

  @override
  String get bagFromKabso => 'هدية من Kabso';

  @override
  String bagFromUser(String name) {
    return 'هدية من $name';
  }

  @override
  String get bagFromSomeone => 'هدية';

  @override
  String get bagFromLevel => 'مكافأة مستوى';

  @override
  String get bagFromPurchase => 'تم الشراء';

  @override
  String get bagSend => 'إرسال';

  @override
  String get bagNoSendFree => 'العناصر المجانية لا تُرسل';

  @override
  String get bagNoSendLevel => 'مكافآت المستوى لا تُرسل، فهي مرتبطة بمستواك';

  @override
  String get bagNoSendOther => 'لا يمكن إرسال هذا العنصر';

  @override
  String get bagCategoryOther => 'عناصر أخرى';

  @override
  String bagSendTitle(String item) {
    return 'إرسال $item';
  }

  @override
  String bagSendYouHave(String left) {
    return 'لديك: $left';
  }

  @override
  String get bagSendAmount => 'كم تريد أن ترسل؟';

  @override
  String get bagSendAll => 'الكل';

  @override
  String get bagSendPermanentNote =>
      'العنصر الدائم يُرسل كاملاً ويخرج من حقيبتك.';

  @override
  String get bagSendWholeNote => 'سيخرج العنصر من حقيبتك مع كل مدته المتبقية.';

  @override
  String bagSendPartNote(String left) {
    return 'يبقى لديك بعد الإرسال: $left';
  }

  @override
  String get bagSendTo => 'إلى';

  @override
  String get bagSendSearchHint => 'ابحث بالاسم أو اسم المستخدم';

  @override
  String get bagSendSearchStart => 'اختر من سترسل إليه العنصر.';

  @override
  String get bagSendSearchEmpty => 'لا يوجد أحد بهذا الاسم.';

  @override
  String get bagSendChange => 'تغيير';

  @override
  String get bagSendConfirmTitle => 'تأكيد الإرسال';

  @override
  String bagSendConfirmBody(String item, String amount, String user) {
    return 'إرسال $item ($amount) إلى $user؟';
  }

  @override
  String bagSendDone(String user) {
    return 'تم الإرسال إلى $user';
  }

  @override
  String get errorBagItemNotTransferable => 'لا يمكن إرسال هذا العنصر.';

  @override
  String get errorBagSendPermanentWholeOnly =>
      'العنصر الدائم يُرسل كاملاً فقط.';

  @override
  String get errorBagSendExceedsRemaining => 'هذه مدة أطول مما تبقى في العنصر.';

  @override
  String get errorBagRecipientHasPermanent =>
      'يملك هذا العنصر بشكل دائم بالفعل.';

  @override
  String notifBagItemReceived(String who, String item) {
    return 'أرسل لك $who $item';
  }

  @override
  String get notifBagItemProfileCard => 'بطاقة ملف شخصي';

  @override
  String get notifBagItemGeneric => 'عنصراً لحقيبتك';

  @override
  String get bagTabTools => 'الأدوات';

  @override
  String get bagTabItems => 'الحقيبة';

  @override
  String get bagInUse => 'قيد الاستخدام';

  @override
  String get bagAllTools => 'كل الأدوات';

  @override
  String get bagUse => 'استخدام';

  @override
  String get bagNothingWorn => 'لا شيء';

  @override
  String get walletTabGold => 'العملات الذهبية';

  @override
  String get walletTabCherries => 'الكرز';

  @override
  String get walletGoldBalance => 'رصيدي من العملات';

  @override
  String get walletCherryBalance => 'رصيدي من الكرز';

  @override
  String walletCherries(String cherries) {
    return '$cherries كرزة';
  }

  @override
  String get walletRewards => 'المكافآت';

  @override
  String get walletRewardsBase => 'العملات';

  @override
  String get walletRewardsBonus => 'المكافأة';

  @override
  String get walletRewardsTotal => 'المجموع';

  @override
  String get walletGet => 'احصل على';

  @override
  String walletTotal(String total) {
    return 'المجموع: $total';
  }

  @override
  String get walletPayUnavailable => 'الدفع غير متاح بعد';

  @override
  String get walletWithdraw => 'سحب';

  @override
  String cherryValue(Object amount) {
    return '≈ $amount';
  }

  @override
  String cherryHeld(Object cherries) {
    return 'محجوز للسحب: $cherries';
  }

  @override
  String get cherryUnitShort => 'عملة واحدة من حصتك في الهدية = 10 كرزات.';

  @override
  String cherryUnit(Object amount, Object cherries, Object min) {
    return 'عملة واحدة من حصتك في الهدية = 10 كرزات. $cherries كرزة = $amount. السحب من $min. ليست نقاط الكرز في البث.';
  }

  @override
  String get cherryHistoryTitle => 'سجل الكرز';

  @override
  String get cherryReasonGift => 'هدية مستلمة';

  @override
  String get cherryReasonAgency => 'عمولة الوكالة';

  @override
  String get cherryReasonParent => 'عمولة أدمن الوكالات';

  @override
  String get cherryReasonGiftReversal => 'ألغى الفريق هدية';

  @override
  String get cherryReasonCommissionReversal => 'إلغاء عمولة';

  @override
  String get cherryReasonWithdrawal => 'طلب سحب (محجوز)';

  @override
  String get cherryReasonRefund => 'رُفض السحب: أُعيدت الكرزات';

  @override
  String get cherryReasonTask => 'مكافأة مهمة';

  @override
  String cherryTaskLocked(String cherries) {
    return '$cherries كرزة من المهام مقفلة — تُفتح للسحب بعد تحقيق شرط الأرباح';
  }

  @override
  String get cherryReasonOther => 'تغيير في الكرز';

  @override
  String get cherryWithdrawalsTitle => 'طلبات السحب';

  @override
  String get cherryWithdrawalPending => 'قيد الانتظار';

  @override
  String get cherryWithdrawalPaid => 'دُفع';

  @override
  String get cherryWithdrawalRejected => 'مرفوض';

  @override
  String cherryWithdrawalLine(Object cherries) {
    return '$cherries كرزة';
  }

  @override
  String cherryPendingNote(Object amount, Object days) {
    return 'طلبك بقيمة $amount قيد الانتظار: يدفعه فريق كبسو يدوياً خلال $days أيام.';
  }

  @override
  String get withdrawTitle => 'سحب الكرز';

  @override
  String withdrawBalance(Object amount, Object cherries) {
    return 'المتاح: $cherries كرزة ≈ $amount';
  }

  @override
  String withdrawRate(Object amount, Object cherries, Object min) {
    return '$cherries كرزة = $amount · الحد الأدنى $min';
  }

  @override
  String withdrawAmountLabel(Object currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String withdrawAmountHelper(Object cherries) {
    return '= $cherries كرزة';
  }

  @override
  String withdrawAmountMin(Object amount) {
    return 'الحد الأدنى $amount';
  }

  @override
  String withdrawAmountShort(Object amount) {
    return 'كرزاتك تكفي حتى $amount';
  }

  @override
  String get withdrawAmountInvalid => 'اكتب مبلغاً مثل 10 أو 12.50';

  @override
  String get withdrawDetailsLabel => 'أين ندفع لك؟';

  @override
  String get withdrawDetailsHint => 'اسم البنك والآيبان، أو اسم المحفظة ورقمها';

  @override
  String withdrawManualNote(Object days) {
    return 'لا يوجد دفع تلقائي بعد: يراجع فريق كبسو طلبك ويدفعه يدوياً خلال $days أيام. تُحجز الكرزات الآن وتعود إليك إن رُفض الطلب.';
  }

  @override
  String get withdrawSubmit => 'إرسال الطلب';

  @override
  String withdrawSubmitAmount(Object amount) {
    return 'طلب سحب $amount';
  }

  @override
  String get withdrawSent => 'أُرسل طلب السحب';

  @override
  String get errorAgencyAlreadyMember => 'أنت مضيف في وكالة أخرى.';

  @override
  String get errorAgencyJoinNotAllowed =>
      'لا يمكن لوكيل وكالة الانضمام إلى وكالة كمضيف.';

  @override
  String get errorAgencyLeaveWindowClosed =>
      'انتهت مدة المغادرة. أرسل شكوى إلى الإدارة.';

  @override
  String get errorInsufficientCherries => 'كرزاتك لا تكفي لهذا المبلغ.';

  @override
  String get errorWithdrawalPending => 'لديك طلب سحب ينتظر الدفع.';

  @override
  String get meHubAgency => 'الوكالة';

  @override
  String get agencyTitle => 'الوكالة';

  @override
  String get agencyLoadError => 'تعذّر تحميل الوكالة';

  @override
  String get agencyJoinTitle => 'انضم إلى وكالة';

  @override
  String get agencyJoinBody =>
      'اكتب رمز الدعوة من وكيلك، تحقّق من الوكالة، ثم اقبل.';

  @override
  String get agencyCodeLabel => 'رمز الدعوة';

  @override
  String get agencyFind => 'عرض الوكالة';

  @override
  String get agencyNotFound => 'لا توجد وكالة بهذا الرمز.';

  @override
  String agencyPreviewOwner(Object name) {
    return 'الوكيل: $name';
  }

  @override
  String agencyHostCount(Object count) {
    return 'المضيفون: $count';
  }

  @override
  String get agencyAccept => 'قبول والانضمام';

  @override
  String agencyLeaveRule(Object days) {
    return 'يمكنك المغادرة خلال $days يوماً من الانضمام؛ بعدها عبر شكوى إلى الإدارة فقط.';
  }

  @override
  String get agencyJoined => 'انضممت إلى الوكالة';

  @override
  String get agencyMyAgency => 'وكالتي';

  @override
  String agencyJoinedAt(Object date) {
    return 'انضممت في $date';
  }

  @override
  String agencyLeaveUntil(Object date) {
    return 'يمكنك المغادرة حتى $date';
  }

  @override
  String agencyLeaveClosed(Object days) {
    return 'انتهت مدة المغادرة ($days يوماً). للمغادرة أرسل شكوى إلى الإدارة.';
  }

  @override
  String get agencyLeave => 'مغادرة الوكالة';

  @override
  String get agencyLeaveConfirm =>
      'تتوقف عمولة الوكالة على هداياك. يمكنك الانضمام إلى وكالة أخرى برمزها.';

  @override
  String get agencyLeft => 'غادرت الوكالة';

  @override
  String get agencyComplain => 'شكوى إلى الإدارة';

  @override
  String get agencyComplaintHint => 'ما المشكلة؟';

  @override
  String get agencyComplaintSend => 'إرسال الشكوى';

  @override
  String get agencyComplaintSent => 'أُرسلت الشكوى إلى الإدارة';

  @override
  String agencyComplaintOpen(Object date) {
    return 'شكواك لدى الإدارة (أُرسلت في $date).';
  }

  @override
  String get agencyComplaintDone => 'ردّت الإدارة على شكواك.';

  @override
  String get agencyInviteCode => 'رمز الدعوة الخاص بك';

  @override
  String get agencyCopy => 'نسخ الرمز';

  @override
  String get agencyCopied => 'تم نسخ الرمز';

  @override
  String get agencyInviteHint =>
      'يكتب المضيفون هذا الرمز في «الوكالة» ثم يقبلون.';

  @override
  String get agencyRankTitle => 'الرتبة';

  @override
  String get agencyRankNew => 'جديدة (فترة سماح)';

  @override
  String get agencyRankAgent => 'وكيل مضيفين';

  @override
  String get agencyRankAdmin => 'أدمن وكالات';

  @override
  String get agencyRankLapsed => 'غير مؤهلة هذا الشهر';

  @override
  String agencyRate(Object percent) {
    return 'عمولتك هذا الشهر: $percent%';
  }

  @override
  String agencyRateNote(Object tier) {
    return 'تدفعها كبسو فوق كرزات مضيفيك ولا تُخصم منهم. 16% في الشهر التالي لشهر يحقق فيه مضيفوك $tier كرزة.';
  }

  @override
  String agencyParent(Object name) {
    return 'أدمن الوكالات: $name';
  }

  @override
  String get agencyProgressTitle => 'التقدّم';

  @override
  String agencyActiveHosts(Object count, Object required) {
    return 'المضيفون النشطون: $count / $required';
  }

  @override
  String agencyActiveRule(Object days, Object hours, Object window) {
    return 'النشط = بثّ في $days أيام ولمدة $hours ساعات خلال آخر $window يوماً.';
  }

  @override
  String agencyMonthCherries(Object cherries) {
    return 'كرز مضيفيك هذا الشهر: $cherries';
  }

  @override
  String agencyException(Object cherries, Object hosts) {
    return 'أو $cherries كرزة في الشهر مع أقل من $hosts مضيفين نشطين.';
  }

  @override
  String agencySubProgress(Object count, Object required) {
    return 'الوكالات الفرعية المؤهلة: $count / $required';
  }

  @override
  String get agencyQualifiesNow => 'أنت مؤهل الآن.';

  @override
  String get agencyNotQualifiedNow => 'لست مؤهلاً بعد.';

  @override
  String get agencyEvaluationNote =>
      'تُراجع الرتب في بداية كل شهر وتبقى حتى نهايته.';

  @override
  String get agencyCommissionTitle => 'العمولات (كرز)';

  @override
  String get agencyThisMonth => 'هذا الشهر';

  @override
  String get agencyLastMonth => 'الشهر الماضي';

  @override
  String get agencyTotal => 'الإجمالي';

  @override
  String get agencyParentCommissionTitle => 'عمولة أدمن الوكالات (3%)';

  @override
  String get agencySubAgenciesTitle => 'الوكالات الفرعية';

  @override
  String agencySubLine(Object active, Object cherries) {
    return '$active نشطون · $cherries كرزة هذا الشهر';
  }

  @override
  String get agencyQualified => 'مؤهلة';

  @override
  String get agencyNotQualified => 'غير مؤهلة';

  @override
  String agencyHostsTitle(Object count) {
    return 'المضيفون ($count)';
  }

  @override
  String get agencyHostsEmpty => 'لا مضيفين بعد';

  @override
  String get agencyHostsEmptyBody => 'شارك رمز الدعوة مع المضيفين.';

  @override
  String get agencyHostActive => 'نشط';

  @override
  String get agencyHostInactive => 'غير نشط';

  @override
  String agencyHostLine(Object cherries, Object days, Object hours) {
    return '$days أيام · $hours ساعة بث (30 يوماً) · $cherries كرزة هذا الشهر';
  }

  @override
  String get agencyHostNoCommission => 'انضم والوكالة غير مؤهلة: بلا عمولة';

  @override
  String rechargeBadgeLabel(int tier) {
    return 'شارة الشحن اليومي، المستوى $tier';
  }

  @override
  String rechargeAgentBadgeLabel(String code) {
    return 'وكيل شحن $code';
  }

  @override
  String rechargeAgentFrameLabel(String name, String code) {
    return '$name، وكيل شحن $code';
  }

  @override
  String rechargeEntranceJoined(String name) {
    return 'دخل وكيل الشحن $name البث';
  }

  @override
  String agentEntranceJoined(String name) {
    return 'دخل $name البث';
  }

  @override
  String rechargeAgentIdLine(String code) {
    return 'وكيل شحن · $code';
  }

  @override
  String rechargeIdLine(String code) {
    return 'وكيل شحن · $code';
  }

  @override
  String get rechargeTitle => 'وكيل الشحن';

  @override
  String get rechargeDirectoryTitle => 'وكلاء الشحن';

  @override
  String get rechargeDirectoryHint =>
      'اشترِ العملات من وكيل في بلدك وادفع له مباشرة';

  @override
  String get rechargeBuyViaAgent => 'الشحن عبر وكيل';

  @override
  String get rechargeBecome => 'كن وكيل شحن';

  @override
  String get rechargeIntroTitle => 'بِع عملات Kabso في بلدك';

  @override
  String get rechargeIntroBody =>
      'يشتري الوكيل العملات بالجملة من Kabso ويبيعها لمستخدمي Kabso، ويدفع له المشتري خارج التطبيق. يحصل الوكيل على إطار وشارة ودخول خاص في الغرف.';

  @override
  String rechargeIntroActivation(String coins) {
    return 'يُفعَّل الوكيل بعد أول شحن لا يقل عن $coins عملة.';
  }

  @override
  String get rechargePendingTitle => 'طلبك قيد المراجعة';

  @override
  String get rechargePendingBody =>
      'سيتواصل معك فريق Kabso على واتساب. بيانات طلبك خاصة ولا يراها إلا الفريق.';

  @override
  String get rechargeRejectedTitle => 'لم يُقبل طلبك السابق.';

  @override
  String rechargeRejectedReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get rechargeApplyAgain => 'قدّم طلباً جديداً';

  @override
  String get rechargeApprovedTitle => 'تمت الموافقة — بانتظار أول شحن';

  @override
  String rechargeApprovedBody(String coins) {
    return 'فعّل وكالتك بشحن أول لا يقل عن $coins عملة عبر فريق Kabso. يظهر رمزك وإطارك بعد التفعيل.';
  }

  @override
  String get rechargeSuspendedTitle => 'الوكالة موقوفة';

  @override
  String get rechargeSuspendedBody =>
      'لا يمكنك البيع الآن ولا تظهر في دليل الوكلاء، وأُزيل الإطار والشارة والدخول. تواصل مع فريق Kabso.';

  @override
  String get rechargeStock => 'مخزون العملات';

  @override
  String rechargeStockLabel(String coins) {
    return 'مخزون العملات: $coins';
  }

  @override
  String get rechargeSell => 'بيع عملات';

  @override
  String get rechargeManage => 'إدارة الوكالة';

  @override
  String get rechargeSalesTitle => 'المبيعات';

  @override
  String rechargeSalesTotals(int count, String coins) {
    return '$count عملية\n$coins عملة';
  }

  @override
  String get rechargeToday => 'اليوم';

  @override
  String get rechargeLast7 => '٧ أيام';

  @override
  String get rechargeLast30 => '٣٠ يوماً';

  @override
  String rechargeCherryToday(String today, String cap) {
    return 'كرز المضيفين اليوم: $today من $cap';
  }

  @override
  String get rechargeEmployeesTitle => 'الموظفون';

  @override
  String get rechargeEmployeesHint =>
      'أضف موظفين يبيعون من مخزونك في ساعات عملهم';

  @override
  String get rechargeAvailabilityTitle => 'أوقات التواصل وطرق الدفع';

  @override
  String get rechargeAvailabilityEmpty =>
      'لم تحدد أوقاتاً بعد؛ لن يظهر زر التواصل في الدليل';

  @override
  String rechargeSlotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وقتاً',
      few: '$count أوقات',
      two: 'وقتان',
      one: 'وقت واحد',
    );
    return '$_temp0';
  }

  @override
  String get rechargeAvailabilityNote =>
      'يظهر رقم واتساب وطريقة الدفع للوقت الحالي في دليل الوكلاء لكل المستخدمين.';

  @override
  String get rechargeCherryBuyTitle => 'شراء كرز المضيفين';

  @override
  String get rechargeCherrySellTitle => 'بيع الكرز لوكيل';

  @override
  String rechargeCherryRate(String cherries, String coins) {
    return '$cherries كرزة = $coins عملة في مخزون الوكيل';
  }

  @override
  String rechargeEmployeeOf(String name) {
    return 'موظف لدى $name';
  }

  @override
  String get rechargeOnShift => 'في الدوام';

  @override
  String get rechargeOffShift => 'خارج الدوام';

  @override
  String get rechargeSellTitle => 'بيع عملات من المخزون';

  @override
  String rechargeStockLeft(String coins) {
    return 'في المخزون: $coins عملة';
  }

  @override
  String get rechargeBuyer => 'المشتري';

  @override
  String get rechargeBuyerHint => 'اسم المستخدم أو المعرّف';

  @override
  String get rechargeCoins => 'عدد العملات';

  @override
  String get rechargeSellInvalid => 'اكتب المشتري وعدد العملات';

  @override
  String rechargeSold(String coins, String buyer) {
    return 'أُرسلت $coins عملة إلى $buyer';
  }

  @override
  String get rechargeSellNote =>
      'يدفع لك المشتري خارج التطبيق. تأكد من استلام المبلغ قبل البيع.';

  @override
  String get rechargeApplyTitle => 'طلب وكيل شحن';

  @override
  String get rechargePrivacyNote =>
      'بيانات الطلب خاصة: لا يراها إلا فريق Kabso، وتُحذف بعد ٩٠ يوماً إذا لم يُقبل الطلب.';

  @override
  String get rechargeFullName => 'الاسم الرباعي';

  @override
  String get rechargeFullNameHint => 'كما في الهوية';

  @override
  String get rechargeFullNameError =>
      'اكتب الاسم الرباعي (أربعة أسماء على الأقل)';

  @override
  String get rechargePhone => 'رقم الهاتف (واتساب)';

  @override
  String get rechargePhoneHint => 'بالصيغة الدولية، مثل ‎+201001234567';

  @override
  String get rechargePhoneError =>
      'اكتب رقماً دولياً يبدأ بـ + (مثل ‎+201001234567)';

  @override
  String get rechargePhoto => 'صورتك';

  @override
  String get rechargePhotoHint => 'صورة واضحة لك';

  @override
  String get rechargeSelfie => 'سيلفي للتحقق';

  @override
  String get rechargeSelfieHint => 'بالكاميرا الأمامية الآن؛ يراجعها الفريق';

  @override
  String get rechargeLocations => 'أماكن البيع';

  @override
  String get rechargeCountry => 'الدولة';

  @override
  String get rechargeCities => 'المدن (افصل بفاصلة)';

  @override
  String get rechargeAddLocation => 'إضافة دولة';

  @override
  String get rechargeLocationError =>
      'اكتب رمز الدولة من حرفين (مثل EG) ومدينة واحدة على الأقل';

  @override
  String get rechargePaymentMethods => 'طرق الدفع المتاحة في كل دولة';

  @override
  String get rechargePaymentType => 'النوع';

  @override
  String get rechargePaymentDetails => 'التفاصيل (مثل فودافون كاش، إنستاباي)';

  @override
  String get rechargeAddPayment => 'إضافة طريقة دفع';

  @override
  String get rechargePaymentError =>
      'لكل طريقة دفع: دولة من أماكن البيع وتفاصيل';

  @override
  String get rechargeMissingPhotos =>
      'أضف صورتك وصورة السيلفي (JPEG أو PNG أو WebP)';

  @override
  String get rechargeSubmit => 'إرسال الطلب';

  @override
  String get rechargeSubmitted => 'أُرسل طلبك';

  @override
  String get rechargePayBank => 'تحويل بنكي';

  @override
  String get rechargePayWallet => 'محفظة إلكترونية';

  @override
  String get rechargePayCash => 'نقداً';

  @override
  String get rechargePayCard => 'بطاقة';

  @override
  String get rechargePayCrypto => 'عملات رقمية';

  @override
  String get rechargePayOther => 'أخرى';

  @override
  String get rechargeRemove => 'إزالة';

  @override
  String get rechargeAddEmployee => 'إضافة موظف';

  @override
  String get rechargeEmployeeUsername => 'اسم المستخدم';

  @override
  String get rechargeEmployeesEmpty => 'لا يوجد موظفون بعد';

  @override
  String rechargeRemoveEmployeeConfirm(String name) {
    return 'إزالة $name من الموظفين؟ يتوقف عن البيع فوراً.';
  }

  @override
  String get rechargeHours => 'ساعات العمل';

  @override
  String get rechargeTimeZone => 'المنطقة الزمنية';

  @override
  String get rechargeFrom => 'من';

  @override
  String get rechargeTo => 'إلى';

  @override
  String get rechargeAddSlot => 'إضافة وقت';

  @override
  String get rechargeWhatsapp => 'رقم واتساب';

  @override
  String get rechargePaymentNow => 'طريقة الدفع في هذا الوقت';

  @override
  String get rechargeSave => 'حفظ';

  @override
  String get rechargeSaved => 'تم الحفظ';

  @override
  String get rechargeDay1 => 'الإثنين';

  @override
  String get rechargeDay2 => 'الثلاثاء';

  @override
  String get rechargeDay3 => 'الأربعاء';

  @override
  String get rechargeDay4 => 'الخميس';

  @override
  String get rechargeDay5 => 'الجمعة';

  @override
  String get rechargeDay6 => 'السبت';

  @override
  String get rechargeDay7 => 'الأحد';

  @override
  String get rechargeDirectoryNote =>
      'تدفع للوكيل خارج التطبيق، ثم يرسل العملات إلى حسابك مباشرة.';

  @override
  String get rechargeDirectoryEmpty => 'لا يوجد وكلاء في هذه الدولة بعد';

  @override
  String get rechargeDirectoryEmptyBody => 'جرّب دولة أخرى أو عُد لاحقاً.';

  @override
  String rechargeAvailableNowLine(String method) {
    return 'متاح الآن · الدفع: $method';
  }

  @override
  String get rechargeNotAvailableNow => 'غير متاح الآن';

  @override
  String get rechargeContact => 'تواصل';

  @override
  String get rechargeCherryOffer => 'بيع كرز لوكيل';

  @override
  String get rechargeCherryAsk => 'طلب كرز من مضيف';

  @override
  String get rechargeAgentCodeField => 'رمز الوكيل (مثل coin0001)';

  @override
  String get rechargeHostField => 'اسم مستخدم المضيف';

  @override
  String get rechargeCherryAmount => 'عدد الكرز';

  @override
  String rechargeCherryRules(String min, String step) {
    return 'الحد الأدنى $min كرزة، وبمضاعفات $step';
  }

  @override
  String get rechargeCherryLockedNote => 'كرز المهام المقفل لا يُباع.';

  @override
  String rechargeCherryPreview(String coins, String money) {
    return 'يحصل الوكيل على $coins عملة، ويدفع للمضيف $money نقداً';
  }

  @override
  String get rechargeCherrySend => 'إرسال الطلب';

  @override
  String get rechargeCherrySent => 'أُرسل الطلب؛ بانتظار تأكيد الطرف الآخر';

  @override
  String get rechargeCherryEmpty => 'لا توجد طلبات';

  @override
  String get rechargeCherryConfirmHint =>
      'أكّد فقط بعد أن يُدفع المبلغ نقداً. ينتهي الطلب بعد ٣٠ دقيقة.';

  @override
  String get rechargeCherryWaiting => 'بانتظار تأكيد الطرف الآخر';

  @override
  String get rechargeCherryCancel => 'إلغاء الطلب';

  @override
  String get rechargeConfirm => 'تأكيد';

  @override
  String get rechargeDecline => 'رفض';

  @override
  String get rechargeCherryPending => 'بانتظار التأكيد';

  @override
  String get rechargeCherryConfirmed => 'مؤكَّد';

  @override
  String get rechargeCherryDeclined => 'مرفوض';

  @override
  String get rechargeCherryCancelled => 'ملغى';

  @override
  String get rechargeCherryExpired => 'منتهٍ';

  @override
  String rechargeCherryLine(String cherries, String coins) {
    return '$cherries كرزة ← $coins عملة';
  }

  @override
  String rechargeMoney(String amount) {
    return 'المبلغ النقدي: $amount';
  }

  @override
  String notifRechargeCoins(String name, String coins) {
    return '$name شحن لك $coins عملة';
  }

  @override
  String notifRechargeCherry(String name) {
    return '$name يطلب تأكيد بيع كرز';
  }

  @override
  String get errorRechargeApplicationNotAllowed =>
      'لا يمكنك تقديم طلب وكيل شحن الآن.';

  @override
  String get errorRechargeAgentNotActive => 'هذا الوكيل غير مفعّل.';

  @override
  String get errorRechargeOffShift => 'يمكنك البيع في ساعات عملك فقط.';

  @override
  String get errorRechargeStockInsufficient => 'مخزون العملات لا يكفي.';

  @override
  String get errorRechargeEmployeeNotAllowed =>
      'لا يمكن إضافة هذا الشخص موظفاً.';

  @override
  String get errorRechargeCherryRequestPending =>
      'يوجد طلب مفتوح بينكما بالفعل.';

  @override
  String get errorRechargeCherryRequestClosed => 'هذا الطلب لم يعد مفتوحاً.';

  @override
  String get errorRechargeCherryCapReached =>
      'بلغ الوكيل حدّه اليومي من الكرز.';

  @override
  String get errorUsernameLocked =>
      'اسم المستخدم مقفل ما دام اليوزر المميز فعّالاً.';

  @override
  String get settingsUsernameLocked => 'مقفل';

  @override
  String settingsBaseUsername(String username) {
    return 'اسمك الأساسي: $username';
  }

  @override
  String changeUsernameSpecialLocked(String special, String base) {
    return '$special يوزر مميز مقفل، ولا يمكن تغييره ما دام فعّالاً. يراه الجميع وحده؛ اسمك الأساسي $base لا يراه غيرك، ويمكنك تسجيل الدخول به.';
  }

  @override
  String changeUsernameSpecialEnds(String date) {
    return 'ينتهي في $date، ثم يعود اسمك الأساسي.';
  }

  @override
  String hostAgentBadgeLabel(String code) {
    return 'وكيل مضيفين $code';
  }

  @override
  String hostAgentFrameLabel(String name) {
    return '$name، وكيل مضيفين';
  }

  @override
  String hostAgentEntranceJoined(String name) {
    return 'دخل وكيل المضيفين $name البث';
  }

  @override
  String hostAgentIdLine(String code) {
    return 'وكيل مضيفين · $code';
  }

  @override
  String get hostAgentCardTitle => 'وكيل مضيفين';

  @override
  String get hostAgentCodeLabel => 'رمز وكيل المضيفين';

  @override
  String get hostAgentPerksNote =>
      'إطارك وشارتك ودخولك المميز في البث ظاهرة ما دامت وكالتك قائمة.';

  @override
  String hostAgentReservedNote(String code, String shown) {
    return 'الرمز $code محجوز لك. يظهر اسم المستخدم $shown لأنه فُعّل أولاً.';
  }

  @override
  String hostAgentSuspendedNote(String code) {
    return 'مزايا وكيل المضيفين موقوفة. يبقى الرمز $code محجوزاً لك.';
  }

  @override
  String get hostAgentPendingNote => 'يُمنح رمز وكيل المضيفين قريباً.';

  @override
  String get bagCategoryAvatarFrame => 'إطارات الصورة';

  @override
  String get bagFromHostActive => 'مكافأة المضيف النشط';

  @override
  String get bagNoSendHostActive => 'إطار المضيف لا يُرسل';

  @override
  String get hostFrameChooseTitle => 'اختر لون إطار المضيف';

  @override
  String get hostFrameChooseBody =>
      'أنت مضيف نشط: اختر الإطار الذي يناسبك، ويمكنك تغييره لاحقاً.';

  @override
  String get hostFrameChoose => 'اختيار';

  @override
  String get hostFrameChangeColour => 'تغيير اللون';

  @override
  String get hostFrameBlue => 'أزرق';

  @override
  String get hostFramePink => 'وردي';

  @override
  String get hostFrameSaved => 'تم اختيار إطار المضيف';

  @override
  String get errorHostFrameStyleFromGender =>
      'لون إطار المضيف يتبع الجنس في ملفك.';

  @override
  String get rechargeStatusActive => 'نشط';

  @override
  String get rechargeStatusSuspended => 'موقوف';

  @override
  String rechargeCherryTodayNoCap(String today) {
    return 'كرز المضيفين اليوم: $today';
  }

  @override
  String rechargeSalesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملية',
      many: '$count عملية',
      few: '$count عمليات',
      two: 'عمليتان',
      one: 'عملية واحدة',
      zero: '$count عملية',
    );
    return '$_temp0';
  }

  @override
  String get rechargeMore => 'المزيد';

  @override
  String get rechargeBuyerNotFound => 'لا يوجد مستخدم بهذا الاسم';

  @override
  String get rechargeBuyerChecking => 'جارٍ التحقق من المشتري…';

  @override
  String get rechargeSellOverStock => 'أكثر من المخزون المتاح';

  @override
  String rechargeStockAfter(String coins) {
    return 'المخزون بعد البيع: $coins';
  }

  @override
  String get rechargeSellConfirmTitle => 'تأكيد البيع';

  @override
  String get rechargeSellIrreversible => 'لا يمكن التراجع عن البيع بعد تأكيده.';

  @override
  String get rechargeApplyStepPersonal => 'بياناتك';

  @override
  String get rechargeApplyStepPhotos => 'الصور';

  @override
  String get rechargePhotoAdded => 'تمت الإضافة';

  @override
  String get rechargePhotoRequired => 'مطلوبة';

  @override
  String get rechargeApplyStepPrivacy => 'الخصوصية';

  @override
  String get rechargeChooseCountry => 'اختر الدولة';

  @override
  String get rechargeStockAfterLabel => 'المخزون بعد البيع';

  @override
  String get walletTopupWebsite => 'الشحن من الموقع';

  @override
  String get walletTopupWebsiteHint =>
      'اشحن بالبطاقة على موقع Kabso Live الرسمي';

  @override
  String get settingsDeleteAccount => 'حذف الحساب';

  @override
  String get settingsDeleteAccountHint => 'يُحذف نهائياً بعد 30 يوماً من الطلب';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String deleteAccountStep(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get deleteAccountIntroTitle => 'قبل أن تحذف حسابك';

  @override
  String get deleteAccountWhatGoes => 'ما سيُحذف';

  @override
  String get deleteAccountWhatGoesBody =>
      'ملفك الشخصي واسمك وصورتك، منشوراتك ومقاطعك وقصصك، رسائلك، من تتابعهم ومن يتابعونك، وبريدك الإلكتروني.';

  @override
  String get deleteAccountForfeit => 'ما ستخسره';

  @override
  String get deleteAccountForfeitBody =>
      'رصيد العملات والكرزات وما في حقيبتك ووقت اسم المستخدم المميز. لا تُسترد ولا تُحوَّل.';

  @override
  String get deleteAccountKept => 'ما نحتفظ به';

  @override
  String get deleteAccountKeptBody =>
      'سجلات المدفوعات والهدايا التي يطلبها القانون والمحاسبة ومكافحة الاحتيال، دون أي بيانات تعرّف بك. سيرى الآخرون «مستخدم محذوف» مكان اسمك.';

  @override
  String deleteAccountGrace(int days) {
    return 'لديك $days يوماً لتغيير رأيك: سجّل الدخول خلالها واختر «إلغاء الحذف». بعدها يُحذف الحساب نهائياً.';
  }

  @override
  String get deleteAccountBlockedTitle => 'يجب تسوية هذا أولاً';

  @override
  String get deleteAccountBlockerRechargeAgent =>
      'أنت وكيل شحن: تواصل مع الفريق لتسوية المخزون وإيقاف الوكالة.';

  @override
  String get deleteAccountBlockerHostAgency =>
      'أنت مالك وكالة مضيفين: تواصل مع الفريق لنقل المضيفين وإيقاف الوكالة.';

  @override
  String get deleteAccountBlockerPendingWithdrawal =>
      'لديك طلب سحب كرزات قيد التنفيذ: انتظر حتى يُدفع.';

  @override
  String get deleteAccountBlockerPendingCherrySale =>
      'لديك طلب بيع كرزات لوكيل شحن لم يُغلق بعد: أكمله أو ألغِه.';

  @override
  String get deleteAccountBlockerNegativeBalance =>
      'رصيدك سالب: تواصل مع الفريق لتسويته.';

  @override
  String get deleteAccountBlockerOther =>
      'هناك أمر يجب تسويته أولاً: تواصل مع الفريق.';

  @override
  String deleteAccountContact(String email) {
    return 'للمساعدة راسلنا على $email';
  }

  @override
  String get deleteAccountPasswordTitle => 'أكّد أنه أنت';

  @override
  String get deleteAccountPasswordBody => 'أدخل كلمة مرور حسابك للمتابعة.';

  @override
  String get deleteAccountConfirmTitle => 'تأكيد أخير';

  @override
  String deleteAccountConfirmBody(String word) {
    return 'اكتب «$word» لتأكيد حذف حسابك.';
  }

  @override
  String get deleteAccountConfirmWord => 'حذف';

  @override
  String get deleteAccountConfirmLabel => 'كلمة التأكيد';

  @override
  String get deleteAccountConfirmMismatch => 'اكتب الكلمة كما هي.';

  @override
  String get deleteAccountSubmit => 'احذف حسابي';

  @override
  String get deleteAccountDoneBanner =>
      'استلمنا طلب حذف حسابك وسجّلنا خروجك من كل الأجهزة. يمكنك إلغاء الحذف بتسجيل الدخول خلال 30 يوماً.';

  @override
  String get deletionPendingTitle => 'طلب حذف قيد التنفيذ';

  @override
  String get deletionPendingQuestion => 'إلغاء الحذف؟';

  @override
  String deletionPendingBody(String date) {
    return 'سيُحذف هذا الحساب نهائياً في $date. ألغِ الحذف ليعود حسابك كما كان.';
  }

  @override
  String get deletionPendingBodyNoDate =>
      'سيُحذف هذا الحساب نهائياً قريباً. ألغِ الحذف ليعود حسابك كما كان.';

  @override
  String get deletionPendingCancel => 'إلغاء الحذف';

  @override
  String get deletionPendingKeep => 'متابعة الحذف';

  @override
  String get deletionPendingRestored => 'أُلغي الحذف. مرحباً بعودتك.';

  @override
  String get deletedUser => 'مستخدم محذوف';

  @override
  String get errorReauthFailed => 'كلمة المرور غير صحيحة.';

  @override
  String get errorAccountDeletionBlocked =>
      'يجب تسوية بعض الأمور قبل حذف الحساب.';

  @override
  String get errorAccountDeletionPending => 'هذا الحساب في انتظار الحذف.';

  @override
  String get privacyDataTitle => 'بياناتك';

  @override
  String get dataExportTitle => 'تنزيل بياناتي';

  @override
  String get dataExportTileHint => 'نسخة من بياناتك بصيغة يمكنك نقلها';

  @override
  String get dataExportIntro =>
      'نجهّز لك ملف ZIP فيه بياناتك بصيغة JSON مع ملف توضيحي بالعربية والإنجليزية: ملفك وإعداداتك، منشوراتك وريلزك وقصصك، تعليقاتك، رسائلك، متابعاتك والحظر، سجلات العملات والكرز والمستويات، الهدايا، السحوبات، طلب وكيل الشحن، موافقاتك، وسجل الأجهزة وتسجيل الدخول.';

  @override
  String get dataExportRules =>
      'يمكنك طلب نسخة واحدة كل 24 ساعة. عندما تجهز نرسل لك إشعاراً ورسالة بريد، والتنزيل يعمل مرة واحدة خلال 7 أيام.';

  @override
  String get dataExportNoSecrets =>
      'لا يحوي الملف كلمة مرورك ولا بيانات خاصة لأشخاص آخرين.';

  @override
  String get dataExportRequest => 'طلب نسخة من بياناتي';

  @override
  String get dataExportPasswordTitle => 'تأكيد هويتك';

  @override
  String get dataExportPasswordBody =>
      'أدخل كلمة مرور حسابك لطلب نسخة من بياناتك.';

  @override
  String get dataExportPasswordLabel => 'كلمة المرور';

  @override
  String get dataExportContinue => 'متابعة';

  @override
  String get dataExportRequested =>
      'استلمنا طلبك. سنرسل لك إشعاراً عندما تجهز بياناتك.';

  @override
  String get dataExportPreparing =>
      'نجهّز بياناتك… سنرسل لك إشعاراً عندما تجهز.';

  @override
  String dataExportReady(String date) {
    return 'بياناتك جاهزة. التنزيل متاح مرة واحدة حتى $date.';
  }

  @override
  String get dataExportDownload => 'تنزيل الملف';

  @override
  String dataExportSaved(String path) {
    return 'حُفظ الملف في: $path';
  }

  @override
  String dataExportDownloaded(String date) {
    return 'نزّلت هذه النسخة في $date.';
  }

  @override
  String get dataExportExpired => 'انتهت صلاحية آخر نسخة قبل تنزيلها.';

  @override
  String get dataExportFailed => 'تعذّر تجهيز آخر نسخة. يمكنك طلب نسخة جديدة.';

  @override
  String dataExportNextAt(String date) {
    return 'يمكنك طلب نسخة جديدة بعد $date.';
  }

  @override
  String get dataExportRefresh => 'تحديث';

  @override
  String get consentTitle => 'حدّثنا الشروط وسياسة الخصوصية';

  @override
  String get consentBody =>
      'اقرأ ملخص التغييرات، ثم وافق لتتابع استخدام Kabso Live.';

  @override
  String get consentTermsName => 'شروط الاستخدام';

  @override
  String get consentPrivacyName => 'سياسة الخصوصية';

  @override
  String consentVersion(String version, String date) {
    return 'الإصدار $version · ساري من $date';
  }

  @override
  String get consentReadFull => 'قراءة النص الكامل';

  @override
  String get consentAccept => 'أوافق وأتابع';

  @override
  String get consentNotNow =>
      'لا توافق؟ يمكنك تنزيل بياناتك أو حذف حسابك أو تسجيل الخروج.';

  @override
  String get consentLogout => 'تسجيل الخروج';

  @override
  String get consentAccepted => 'شكراً، سُجّلت موافقتك.';

  @override
  String get registerLegalAccept =>
      'عمري 18 عاماً أو أكثر، وأوافق على شروط الاستخدام وسياسة الخصوصية.';

  @override
  String get registerLegalRequired => 'أكّد عمرك ووافق على الشروط للمتابعة.';

  @override
  String get notifDataExportReady => 'نسخة بياناتك جاهزة للتنزيل';

  @override
  String get errorConsentRequired =>
      'راجع الشروط وسياسة الخصوصية المحدّثة ووافق عليها للمتابعة.';

  @override
  String get errorConsentVersionMismatch =>
      'صدر إصدار أحدث للتو. راجعه من جديد.';

  @override
  String get errorDataExportLimit =>
      'يمكنك طلب نسخة واحدة من بياناتك كل 24 ساعة.';

  @override
  String get errorDataExportLinkInvalid => 'رابط التنزيل لم يعد صالحاً.';

  @override
  String get liveGiftTabPk => 'PK';

  @override
  String get pkSheetTitle => 'تحدي PK';

  @override
  String get pkTabInvite => 'دعوة مضيف';

  @override
  String get pkTabRandom => 'مطابقة عشوائية';

  @override
  String get pkSearchHint => 'ابحث عن مضيف مباشر';

  @override
  String get pkLiveNow => 'مضيفون مباشرون الآن';

  @override
  String get pkNoCandidates => 'لا يوجد مضيفون متاحون الآن';

  @override
  String get pkInvite => 'دعوة';

  @override
  String pkInviteSent(String name) {
    return 'أُرسلت الدعوة إلى $name';
  }

  @override
  String pkWaitingFor(String name, String seconds) {
    return 'بانتظار رد $name… $seconds';
  }

  @override
  String get pkCancel => 'إلغاء';

  @override
  String get pkRandomStart => 'ابدأ المطابقة';

  @override
  String pkRandomSearching(String time) {
    return 'جارٍ البحث عن خصم… $time';
  }

  @override
  String get pkRandomStop => 'إيقاف البحث';

  @override
  String get pkRandomHint => 'نطابقك مع مضيف مباشر يبحث عن تحدٍ الآن.';

  @override
  String get pkInvitesSwitch => 'استقبال دعوات PK';

  @override
  String get pkIncomingTitle => 'دعوة PK';

  @override
  String pkIncomingBody(String name) {
    return '$name يدعوك إلى تحدي PK';
  }

  @override
  String get pkAccept => 'قبول';

  @override
  String get pkDecline => 'رفض';

  @override
  String get pkNoticeDeclined => 'رُفضت دعوتك';

  @override
  String get pkNoticeExpired => 'انتهت مهلة الدعوة';

  @override
  String get pkNoticeQueueExpired => 'لم نجد خصماً، حاول مجدداً';

  @override
  String get pkEnd => 'إنهاء التحدي';

  @override
  String get pkEndConfirmTitle => 'إنهاء التحدي الآن؟';

  @override
  String get pkEndConfirmBody =>
      'إنهاء التحدي قبل وقته يُحتسب انسحاباً ويفوز الخصم.';

  @override
  String get pkMuteOpponent => 'كتم الخصم';

  @override
  String get pkUnmuteOpponent => 'إلغاء كتم الخصم';

  @override
  String get pkBoosterDouble => 'دبل';

  @override
  String get pkBoosterDoubleTurbo => 'دبل تيربو';

  @override
  String get pkBoosterTriple => 'تربل';

  @override
  String get pkBoosterTripleTurbo => 'تربل تيربو';

  @override
  String pkBoostChip(String multiplier, String time) {
    return '×$multiplier $time';
  }

  @override
  String pkRoundTimer(String time) {
    return 'PK $time';
  }

  @override
  String get pkResultWin => 'فوز';

  @override
  String get pkResultLose => 'خسارة';

  @override
  String get pkResultDraw => 'تعادل';

  @override
  String pkEndedForfeit(String name) {
    return 'انسحب $name';
  }

  @override
  String pkEndedDisconnect(String name) {
    return 'انقطع اتصال $name';
  }

  @override
  String pkEndedAway(String name) {
    return 'غاب $name عن التحدي';
  }

  @override
  String get pkEndedAdmin => 'أنهى المشرف التحدي';

  @override
  String get pkBoosterNoMatch => 'المعززات تعمل أثناء التحدي فقط';

  @override
  String pkBoosterTooEarly(String minutes) {
    return 'متاح في آخر $minutes من التحدي';
  }

  @override
  String get pkBoosterLastMinute => 'دقيقة';

  @override
  String get pkBoosterLastTwoMinutes => 'دقيقتين';

  @override
  String get pkBoosterLimit => 'استُخدم الحد الأقصى لهذا المعزز في هذا التحدي';

  @override
  String get pkBoosterActiveHigher => 'معزز مساوٍ أو أقوى فعّال الآن';

  @override
  String get pkErrorBusy => 'المضيف مشغول بتحدٍ أو دعوة أخرى';

  @override
  String get pkErrorInvitesOff => 'هذا المضيف لا يستقبل دعوات PK';

  @override
  String get pkErrorCooldown => 'انتظر قليلاً قبل دعوة أخرى';

  @override
  String get pkErrorUnavailable => 'لا يمكن بدء تحدٍ الآن';

  @override
  String get pkErrorInviteClosed => 'الدعوة لم تعد متاحة';

  @override
  String pkRecord(String wins, String losses, String draws) {
    return 'PK: $wins فوز · $losses خسارة · $draws تعادل';
  }

  @override
  String pkOpponentPane(String name) {
    return 'الخصم $name';
  }

  @override
  String pkOwnPane(String name) {
    return 'المضيف $name';
  }

  @override
  String pkGuestSemantics(String name) {
    return 'ضيف $name';
  }

  @override
  String get pkModeOneVsOne => 'PK ثنائي';

  @override
  String get pkModeTeam => 'PK رباعي';

  @override
  String get pkModeMulti => 'PK متعدد';

  @override
  String pkModeSoon(String mode) {
    return '$mode قريباً — لم يُبنَ بعد';
  }

  @override
  String get pkFriendsTab => 'الأصدقاء';

  @override
  String get pkNoFriends => 'لا يوجد أصدقاء لدعوتهم حالياً';

  @override
  String get pkFriendsHelp =>
      'الأصدقاء: مضيفون تتابعهم ويتابعونك، وفي بث فيديو مباشر الآن. ابحث عن أي مضيف آخر بالاسم، أو جرّب المطابقة العشوائية.';

  @override
  String get pkHelpTitle => 'ما هو PK؟';

  @override
  String get pkHelpBody =>
      'تحدٍّ بين مضيفَين: هدايا مشاهدي كل غرفة أثناء الجولة تصير نقاط PK (قيمة الهدية × المضاعِف). الأعلى نقاطاً يفوز. المعزِّزات ×2 / ×3 / ×5 / ×10 تضاعف النقاط فقط، لا المال.';

  @override
  String get pkHistoryTitle => 'سجل PK';

  @override
  String get pkHistoryEmpty => 'لا توجد مباريات PK بعد';

  @override
  String get pkHistoryNotCounted => 'غير محتسبة';

  @override
  String get pkHistoryVoid => 'ملغاة';

  @override
  String pkHistoryRounds(String own, String other) {
    return 'الجولات $own–$other';
  }

  @override
  String pkHistoryVs(String name) {
    return 'ضد $name';
  }

  @override
  String get pkHistoryLoadError => 'تعذّر تحميل سجل PK';

  @override
  String get pkSettingsTitle => 'إعدادات PK';

  @override
  String get pkSettingsLoadError => 'تعذّر تحميل إعدادات PK';

  @override
  String get pkSettingMode => 'وضع PK';

  @override
  String get pkSettingModeHelp =>
      'جولة واحدة: جولة واحدة تحسم النتيجة. الأفضل من ثلاث: حتى 3 جولات بالمدة المختارة، ومن يفوز بجولتين يفوز. لكل جولة نقاطها ومعزِّزاتها.';

  @override
  String get pkModeSingle => 'جولة واحدة';

  @override
  String get pkModeBestOfThree => 'الأفضل من ثلاث';

  @override
  String get pkSettingTime => 'المدة';

  @override
  String pkMinutes(String minutes) {
    return '$minutes د';
  }

  @override
  String pkMinutesLong(String minutes) {
    return '$minutes دقائق';
  }

  @override
  String get pkSettingAutoStart => 'بدء PK مباشرة بعد الاتصال';

  @override
  String get pkSettingGender => 'تفضيل الجنس في المطابقة العشوائية';

  @override
  String get pkGenderBoth => 'الكل';

  @override
  String get pkGenderMale => 'ذكور';

  @override
  String get pkGenderFemale => 'إناث';

  @override
  String get pkSettingRegion => 'تفضيل المنطقة في المطابقة العشوائية';

  @override
  String get pkRegionGlobal => 'عالمي';

  @override
  String get pkRegionSame => 'بلدي فقط';

  @override
  String get pkSettingAutoMatch => 'مطابقة تلقائية';

  @override
  String get pkSettingAutoMatchHelp =>
      'وأنت في بث فيديو ولست في PK، تدخل المطابقة العشوائية تلقائياً.';

  @override
  String get pkSettingRecommend => 'السماح باقتراحي على المضيفين الآخرين';

  @override
  String pkSettingsNoteEffective(String points) {
    return '1. PK فعّال: مجموع نقاط PK للطرفين ≥ $points (يُحتسب في سجلك).';
  }

  @override
  String get pkSettingsNoteRandom =>
      '2. إذا اختلفت إعدادات المضيفَين، يُختار إعداد أحدهما عشوائياً.';

  @override
  String get pkSettingsSoonTab => 'هذا الوضع قريباً — لا إعدادات له بعد';

  @override
  String get pkSettingSaveError => 'تعذّر حفظ الإعداد';

  @override
  String get pkStart => 'ابدأ PK';

  @override
  String get pkConnectedHint =>
      'تم الاتصال — يبدأ PK حين يضغط أحدكما «ابدأ PK»';

  @override
  String pkRoundLabel(String round) {
    return 'الجولة $round/3';
  }

  @override
  String pkSettingsFromOther(String name) {
    return 'طُبِّقت إعدادات $name (اختيار عشوائي)';
  }

  @override
  String pkBoostActivated(String host, String booster) {
    return 'فعّل فريق $host $booster';
  }

  @override
  String pkBoostGain(String points, String multiplier) {
    return '+$points ×$multiplier';
  }

  @override
  String pkBoostChipSemantics(
    String booster,
    String multiplier,
    String seconds,
  ) {
    return '$booster ×$multiplier، يتبقى $seconds ث';
  }

  @override
  String get liveDataPageTitle => 'بيانات البث';

  @override
  String get liveDataNowLiveTime => 'وقت البث';

  @override
  String get liveDataNowViewers => 'مشاهدون فريدون';

  @override
  String liveDataNowViewersHint(String peak) {
    return 'الذروة $peak';
  }

  @override
  String get liveDataNowCherries => 'كرز جديد';

  @override
  String get liveDataNowGivers => 'داعمو الهدايا';

  @override
  String get liveDataNowFans => 'متابعون جدد';

  @override
  String get liveDataCreatorCenter => 'مركز المبدعين';

  @override
  String liveDataLevel(String level) {
    return 'Lv.$level';
  }

  @override
  String get liveDataLevelHelp =>
      'مستوى الجاذبية: يرتفع بقيمة الهدايا التي تصلك.';

  @override
  String get liveDataHistory => 'إحصاءات الفترات السابقة';

  @override
  String get liveDataNotLive => 'تظهر بيانات البث أثناء بثّك المباشر.';

  @override
  String get liveToolHd => 'HD';

  @override
  String get liveToolFlash => 'فلاش';

  @override
  String get liveHostBox => 'الألعاب';

  @override
  String get liveTargetChip => 'تارجت';

  @override
  String liveTargetCherriesSemantics(String received) {
    return 'هدف الهدايا اليوم: $received كرز';
  }

  @override
  String liveTargetLuckySemantics(String received) {
    return 'هدف هدايا الحظ اليوم: $received كرز';
  }

  @override
  String get liveTargetReached => 'تم بلوغ الهدف';

  @override
  String get liveTargetPeriodDay => 'يومي';

  @override
  String get liveTargetPeriodWeek => 'أسبوعي';

  @override
  String get liveTargetPeriodMonth => 'شهري';

  @override
  String get liveTargetPeriodAll => 'الكل';

  @override
  String get liveTargetCherriesSection => 'الهدايا';

  @override
  String get liveTargetLuckySection => 'هدايا الحظ';

  @override
  String get liveTargetTopSupporters => 'أفضل الداعمين';

  @override
  String get liveTargetNoSupporters => 'لا يوجد داعمون بعد';

  @override
  String get liveTargetToday => 'أهداف اليوم';

  @override
  String get liveTargetCherriesGoal => 'هدف الهدايا';

  @override
  String get liveTargetLuckyGoal => 'هدف هدايا الحظ';

  @override
  String get liveTargetNoTarget => 'لا هدف اليوم';

  @override
  String liveTargetConversion(int band) {
    return 'هدف الهدايا هو هدف مهمة «هدف الهدايا» لفئتك ($band)، بالكرز.';
  }

  @override
  String get liveTargetTaskCenter => 'مركز المهام';

  @override
  String get liveTargetLoadError => 'تعذّر تحميل الإحصاءات';

  @override
  String get liveTargetZoneHint => 'الفترات حسب توقيت الرياض.';

  @override
  String get reelsChipStories => 'القصص';

  @override
  String get reelsChipRooms => 'الغرف';

  @override
  String get reelsOpenStories => 'فتح القصص';

  @override
  String get reelsOpenRooms => 'فتح الغرف الصوتية';

  @override
  String get reelsStoriesEmpty =>
      'لا توجد قصص الآن. أضف قصتك أو تابع أشخاصاً لترى قصصهم.';

  @override
  String reelsShareLabel(String count) {
    return 'مشاركة، $count';
  }

  @override
  String reelsCommentsLabel(String count) {
    return 'التعليقات، $count';
  }

  @override
  String reelsShareText(String author, String caption) {
    return '$author على Kabso Live: $caption';
  }

  @override
  String reelsShareTextNoCaption(String author) {
    return 'شاهد ريل $author على Kabso Live';
  }

  @override
  String reelsOriginalSound(String name) {
    return 'صوت أصلي · $name';
  }

  @override
  String get reelsMore => 'المزيد';

  @override
  String reelsRequestFollow(String name) {
    return 'طلب متابعة $name';
  }

  @override
  String reelsFollowRequested(String name) {
    return 'طلبت متابعة $name';
  }

  @override
  String liveTargetCountdownHours(String hours, String minutes) {
    return 'العد التنازلي $hoursس $minutesد';
  }

  @override
  String liveTargetCountdownDays(String days, String hours) {
    return 'العد التنازلي $daysي $hoursس';
  }

  @override
  String get liveTargetRangeToday => 'اليوم';

  @override
  String get liveTargetRangeWeek => 'هذا الأسبوع';

  @override
  String get liveTargetRangeMonth => 'هذا الشهر';

  @override
  String get liveTargetRangeAll => 'كل الوقت';

  @override
  String get liveTargetHelpTitle => 'ما هو التارجت؟';

  @override
  String get liveTargetHelp =>
      'للمضيف هدفان كل يوم، كلاهما بالكرز الذي يصله فعلاً: هدف الهدايا (من كل الهدايا غير هدايا الحظ التي يرسلها الآخرون) وهدف هدايا الحظ (من هدايا الحظ، ومنها ما يرسله المضيف لنفسه). يبدأ العد من جديد عند منتصف الليل بتوقيت الرياض. القائمة ترتّب الداعمين في الفترة المختارة: بالكرز في «الهدايا» وبالعملات في «هدايا الحظ».';

  @override
  String get liveTargetSupport => 'ادعم';

  @override
  String liveTargetMyPlace(String rank, String amount) {
    return 'ترتيبك $rank: $amount';
  }

  @override
  String get liveTargetClose => 'إغلاق';

  @override
  String goLiveFailureDetails(String code) {
    return 'تفاصيل: $code';
  }

  @override
  String get goLiveToolsDegraded =>
      'بعض أدوات البث لم تعمل وأُوقفت. البث مستمر.';

  @override
  String get rechargeOrdersTitle => 'طلبات الشحن';

  @override
  String get rechargeOrdersHint => 'طلباتك من الوكلاء ومحادثة كل طلب';

  @override
  String get rechargeOrdersMine => 'مشترياتي';

  @override
  String get rechargeOrdersIncoming => 'الطلبات الواردة';

  @override
  String rechargeOrdersIncomingHint(String count, String coins) {
    return '$count طلب ينتظرك · $coins عملة مجمّدة';
  }

  @override
  String get rechargeOrdersEmpty => 'لا توجد طلبات بعد';

  @override
  String get rechargeOrdersEmptyBody =>
      'اختر وكيلاً من «وكلاء الشحن» ثم «اطلب شحن».';

  @override
  String get rechargeOrderNew => 'اطلب شحن';

  @override
  String get rechargeOrderNewTitle => 'طلب شحن جديد';

  @override
  String get rechargeOrderCoins => 'عدد العملات';

  @override
  String rechargeOrderCoinsRange(String min, String max) {
    return 'من $min إلى $max عملة';
  }

  @override
  String get rechargeOrderPrice => 'السعر';

  @override
  String rechargeOrderUsd(String amount) {
    return '$amount دولار';
  }

  @override
  String rechargeOrderLocal(String amount, String currency, String rate) {
    return '≈ $amount $currency (1 دولار = $rate)';
  }

  @override
  String get rechargeOrderUsdOnly =>
      'لا يوجد سعر صرف لهذا البلد: السعر بالدولار فقط.';

  @override
  String get rechargeOrderPriceNote =>
      'السعر يحسبه Kabso حسب السعر الموحد للعملات.';

  @override
  String get rechargeOrderPaymentMethod => 'طريقة الدفع';

  @override
  String get rechargeOrderSubmit => 'إرسال الطلب';

  @override
  String get rechargeOrderOutsideNote =>
      'تدفع للوكيل خارج التطبيق. عند إرسال معلومات الدفع تُجمَّد العملات من رصيد الوكيل حتى يؤكد استلام المبلغ.';

  @override
  String get rechargeOrderTitle => 'طلب شحن';

  @override
  String get rechargeOrderStatusRequested => 'بانتظار معلومات الدفع من الوكيل';

  @override
  String get rechargeOrderStatusAwaiting => 'بانتظار التحويل';

  @override
  String get rechargeOrderStatusPaid => 'تم الإرسال — بانتظار تأكيد الوكيل';

  @override
  String get rechargeOrderStatusDisputed => 'نزاع — الإدارة تراجع الطلب';

  @override
  String get rechargeOrderStatusCompleted => 'مكتمل — أُضيفت العملات';

  @override
  String get rechargeOrderStatusByAdmin => 'أُضيفت العملات بقرار الإدارة';

  @override
  String get rechargeOrderStatusRefunded =>
      'أُعيدت العملات إلى الوكيل بقرار الإدارة';

  @override
  String get rechargeOrderStatusCancelled => 'ملغى';

  @override
  String get rechargeOrderStatusExpired => 'انتهت مهلة الطلب';

  @override
  String get rechargeOrderStatusUnknown => 'طلب شحن';

  @override
  String rechargeOrderFrozen(String coins) {
    return '$coins عملة مجمّدة لهذا الطلب';
  }

  @override
  String rechargeOrderCoinsLine(String coins) {
    return '$coins عملة';
  }

  @override
  String get rechargeOrderNoticeTitle => 'تعليمات الحماية';

  @override
  String get rechargeOrderNotice =>
      'يرجى أخذ لقطة شاشة وتسجيل فيديو للشاشة منذ لحظة مغادرة المحادثة وحتى وصول الحوالة إلى المعلومات التي قدّمها الوكيل، لحمايتكم من أي خطأ أو احتيال. عند التحويل أرسل لقطة شاشة للحوالة واحتفظ بفيديو الشاشة حتى تصلك العملات.';

  @override
  String get rechargeOrderNoticeAck => 'قرأت وفهمت';

  @override
  String get rechargeOrderSent => 'قمت بالإرسال';

  @override
  String get rechargeOrderSentTitle => 'أرفق لقطة شاشة الحوالة';

  @override
  String get rechargeOrderSentBody =>
      'اختر لقطة شاشة التحويل؛ تُرسل في المحادثة كإثبات. احتفظ بفيديو الشاشة حتى تصلك العملات.';

  @override
  String get rechargeOrderPickScreenshot => 'اختيار لقطة الشاشة';

  @override
  String get rechargeOrderBadImage => 'اختر صورة JPEG أو PNG أو WebP.';

  @override
  String rechargeOrderCountdown(String time) {
    return 'يمكنك فتح نزاع بعد $time';
  }

  @override
  String rechargeOrderCountdownAgent(String time) {
    return 'تحقّق من وصول الحوالة · $time قبل أن يستطيع المشتري فتح نزاع';
  }

  @override
  String get rechargeOrderWaitOver =>
      'انتهت مدة الانتظار. إن لم تصلك العملات افتح نزاعاً.';

  @override
  String get rechargeOrderWaitOverAgent =>
      'انتهت مدة الانتظار: يمكن للمشتري فتح نزاع الآن.';

  @override
  String get rechargeOrderDispute => 'نزاع';

  @override
  String get rechargeOrderDisputeTitle => 'فتح نزاع';

  @override
  String get rechargeOrderDisputeBody =>
      'تبقى العملات مجمّدة، وتدخل الإدارة المحادثة لمراجعة الإثباتات وتقرّر.';

  @override
  String get rechargeOrderDisputeReason => 'ماذا حدث؟ (اختياري)';

  @override
  String get rechargeOrderReceived => 'استلمت';

  @override
  String get rechargeOrderReceivedTitle => 'تأكيد الاستلام';

  @override
  String rechargeOrderReceivedBody(String coins) {
    return 'تأكد أن المبلغ وصل فعلاً إلى حسابك. بعد التأكيد تُضاف $coins عملة إلى المشتري ولا يمكن التراجع.';
  }

  @override
  String get rechargeOrderSendDetails => 'إرسال معلومات الدفع';

  @override
  String get rechargeOrderDetailsLabel => 'معلومات التحويل';

  @override
  String get rechargeOrderDetailsHint => 'رقم المحفظة أو الحساب واسم المستلم';

  @override
  String rechargeOrderDetailsBody(String coins) {
    return 'عند الإرسال تُجمَّد $coins عملة من رصيدك لهذا الطلب حتى تؤكد الاستلام.';
  }

  @override
  String get rechargeOrderCancel => 'إلغاء الطلب';

  @override
  String get rechargeOrderCancelBody =>
      'هل تريد إلغاء الطلب؟ تعود أي عملات مجمّدة إلى رصيد الوكيل.';

  @override
  String get rechargeOrderKeep => 'تراجع';

  @override
  String get rechargeOrderChatHint => 'اكتب رسالة…';

  @override
  String get rechargeOrderChatClosed => 'المحادثة مغلقة';

  @override
  String get rechargeOrderRoleAdmin => 'الإدارة';

  @override
  String rechargeOrderPaymentDetails(String method) {
    return 'معلومات الدفع · $method';
  }

  @override
  String get rechargeOrderProof => 'لقطة شاشة الحوالة';

  @override
  String get rechargeOrderCopied => 'تم نسخ معلومات الدفع';

  @override
  String get rechargeOrderEventCreated => 'أُنشئ الطلب';

  @override
  String get rechargeOrderEventDetails =>
      'أرسل الوكيل معلومات الدفع وجُمّدت العملات';

  @override
  String get rechargeOrderEventNotice => 'أقرّ المشتري بتعليمات الحماية';

  @override
  String get rechargeOrderEventPaid => 'ضغط المشتري «قمت بالإرسال»';

  @override
  String get rechargeOrderEventCompleted =>
      'أكّد الوكيل الاستلام وأُضيفت العملات';

  @override
  String get rechargeOrderEventDisputedBuyer => 'فتح المشتري نزاعاً';

  @override
  String get rechargeOrderEventDisputedAgent => 'فتح الوكيل نزاعاً';

  @override
  String get rechargeOrderEventCancelledBuyer => 'ألغى المشتري الطلب';

  @override
  String get rechargeOrderEventCancelledAgent => 'ألغى الوكيل الطلب';

  @override
  String get rechargeOrderEventExpired => 'انتهت مهلة الطلب';

  @override
  String get rechargeOrderEventForBuyer => 'قرار الإدارة: العملات للمشتري';

  @override
  String get rechargeOrderEventForAgent => 'قرار الإدارة: العملات تعود للوكيل';

  @override
  String get rechargeOrderEventOther => 'تحديث على الطلب';

  @override
  String notifRechargeOrderCreated(String coins) {
    return 'طلب شحن جديد ينتظر معلومات الدفع ($coins عملة)';
  }

  @override
  String get notifRechargeOrderDetails =>
      'أرسل الوكيل معلومات الدفع لطلب الشحن';

  @override
  String get notifRechargeOrderPaid =>
      'أكّد المشتري إرسال المبلغ: تحقّق من وصول الحوالة';

  @override
  String notifRechargeOrderCompleted(String coins) {
    return 'أُضيفت $coins عملة من طلب الشحن';
  }

  @override
  String get notifRechargeOrderDisputed => 'فُتح نزاع على طلب الشحن';

  @override
  String get notifRechargeOrderRefunded =>
      'أُغلق النزاع وأُعيدت العملات إلى الوكيل';

  @override
  String get notifRechargeOrderCancelled => 'أُلغي طلب الشحن';

  @override
  String get notifRechargeOrderExpired => 'انتهت مهلة طلب الشحن';

  @override
  String get notifRechargeOrderAdmin => 'رسالة من الإدارة في طلب الشحن';

  @override
  String get notifRechargeOrderMessage => 'رسالة جديدة في طلب الشحن';

  @override
  String get errorRechargeOrdersUnavailable => 'طلبات الشحن غير متاحة حالياً.';

  @override
  String get errorRechargeOrderOpenExists => 'لديك طلب مفتوح مع هذا الوكيل.';

  @override
  String get errorRechargeOrderStateChanged =>
      'تغيّرت حالة الطلب. حدّث الصفحة.';

  @override
  String get errorRechargeOrderNoticeRequired =>
      'اقرأ تعليمات الحماية وأقرّ بها أولاً.';

  @override
  String get errorRechargeOrderDisputeTooEarly =>
      'يمكنك فتح نزاع بعد انتهاء مدة الانتظار.';

  @override
  String agencyDaysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String agencyHostsCount(int hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      hosts,
      locale: localeName,
      other: '$hosts مضيف',
      many: '$hosts مضيفًا',
      few: '$hosts مضيفين',
      two: 'مضيفَين',
      one: 'مضيف واحد',
    );
    return '$_temp0';
  }

  @override
  String agencyHoursCount(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ساعة',
      many: '$hours ساعة',
      few: '$hours ساعات',
      two: 'ساعتين',
      one: 'ساعة واحدة',
      zero: 'أقل من ساعة',
    );
    return '$_temp0';
  }

  @override
  String get agencyOpenButton => 'افتح وكالة';

  @override
  String get agencyOpenButtonHint => 'مجانًا — تُنشأ وكالتك فورًا';

  @override
  String get agencyOpenTitle => 'افتح وكالة';

  @override
  String get agencyOpenFree => 'فتح الوكالة مجاني';

  @override
  String agencyOpenRule(String days, String hosts) {
    return 'تُنشأ وكالتك فورًا بعد الإرسال. خلال $days يجب أن تفعّل $hosts على الأقل: ينضم المضيف إلى وكالتك ثم يفتح بثًا ويستلم هدايا. إن لم يتحقق ذلك تُغلق الوكالة تلقائيًا ويصلك إشعار بالسبب.';
  }

  @override
  String get agencyOpenStepInfo => 'بيانات الوكالة';

  @override
  String get agencyOpenName => 'اسم الوكالة';

  @override
  String get agencyOpenNameError => 'اكتب اسمًا من حرفين إلى 40 حرفًا';

  @override
  String get agencyOpenCountry => 'البلد';

  @override
  String get agencyOpenCountryError => 'اختر البلد';

  @override
  String get agencyOpenContactType => 'وسيلة التواصل';

  @override
  String get agencyOpenContactValue => 'رقم أو معرّف التواصل';

  @override
  String get agencyOpenContactError => 'اكتب 3 أحرف على الأقل';

  @override
  String get agencyContactWhatsapp => 'واتساب';

  @override
  String get agencyContactTelegram => 'تيليجرام';

  @override
  String get agencyContactPhone => 'هاتف';

  @override
  String get agencyContactEmail => 'بريد إلكتروني';

  @override
  String get agencyContactOther => 'أخرى';

  @override
  String get agencyOpenExpected => 'عدد المضيفين المتوقع';

  @override
  String get agencyOpenExpectedError => 'من 1 إلى 10000';

  @override
  String get agencyOpenBio => 'نبذة قصيرة';

  @override
  String get agencyOpenBioHint => 'اختياري، حتى 300 حرف';

  @override
  String get agencyOpenStepId => 'التحقق من الهوية (إلزامي)';

  @override
  String get agencyOpenIdCard => 'صورة الهوية';

  @override
  String get agencyOpenIdCardHint => 'صورة واضحة لبطاقة الهوية أو جواز السفر';

  @override
  String get agencyOpenIdMissing => 'أضف صورة الهوية والسيلفي';

  @override
  String get agencyOpenPrivacy =>
      'صور الهوية خاصة: لا يراها إلا فريق Kabso Live، وكل عرض لها يُسجَّل.';

  @override
  String get agencyOpenSubmit => 'افتح الوكالة مجانًا';

  @override
  String get agencyOpenDone => 'فُتحت وكالتك. فعّل مضيفيك خلال فترة التجربة';

  @override
  String get agencyOpenOwns => 'لديك وكالة بالفعل';

  @override
  String get agencyOpenIsHost => 'أنت مضيف في وكالة. غادرها أولًا لتفتح وكالة';

  @override
  String get agencyOpenNotActive => 'حسابك غير نشط';

  @override
  String agencyOpenCooldown(String date) {
    return 'يمكنك فتح وكالة جديدة من $date';
  }

  @override
  String get agencyProbationTitle => 'فترة التجربة';

  @override
  String agencyProbationLeft(String days, String hours) {
    return 'متبقٍ: $days و$hours';
  }

  @override
  String agencyProbationLeftHours(String hours) {
    return 'متبقٍ: $hours';
  }

  @override
  String get agencyProbationEnding => 'انتهت المدة، يجري التحقق الآن';

  @override
  String agencyProbationActivated(String count, String required) {
    return 'المضيفون المفعّلون: $count / $required';
  }

  @override
  String agencyProbationRuleShort(String hosts, String days) {
    return 'فعّل $hosts خلال $days: ينضم المضيف ثم يبثّ ويستلم هدايا.';
  }

  @override
  String get agencyProbationJoined => 'انضم';

  @override
  String get agencyProbationLive => 'بثّ';

  @override
  String get agencyProbationGifts => 'استلم هدايا';

  @override
  String get agencyProbationNoHosts =>
      'لا مضيفين بعد. شارك رمز الدعوة ليبدأ المضيفون.';

  @override
  String get agencyProbationPassed => 'اجتازت وكالتك فترة التجربة';

  @override
  String get agencyShare => 'مشاركة';

  @override
  String agencyShareText(String code) {
    return 'انضم إلى وكالتي على Kabso Live برمز الدعوة: $code';
  }

  @override
  String get agencyClosedTitle => 'أُغلقت الوكالة';

  @override
  String agencyClosedProbation(String hosts, String count) {
    return 'لم تفعّل $hosts (بثّ واستلام هدايا) خلال فترة التجربة. المفعّلون: $count';
  }

  @override
  String get agencyClosedAdmin => 'أغلقها فريق Kabso Live';

  @override
  String agencyClosedOn(String date) {
    return 'تاريخ الإغلاق: $date';
  }

  @override
  String get agencyReopenNow => 'يمكنك فتح وكالة جديدة الآن';

  @override
  String get notifAgencyOpened => 'فُتحت وكالتك. فعّل مضيفيك خلال فترة التجربة';

  @override
  String notifAgencyReminder(String count, String required) {
    return 'بقي أقل من يوم على نهاية فترة التجربة: المفعّلون $count / $required';
  }

  @override
  String get notifAgencyPassed => 'اجتازت وكالتك فترة التجربة';

  @override
  String notifAgencyClosedProbation(String hosts, String count) {
    return 'أُغلقت وكالتك لأنها لم تفعّل $hosts (بثّ واستلام هدايا) خلال فترة التجربة. المفعّلون: $count';
  }

  @override
  String get notifAgencyClosedAdmin => 'أُغلقت وكالتك من قِبل فريق Kabso Live';

  @override
  String get notifAgencyHostReleased =>
      'أُغلقت الوكالة التي كنت فيها، وأصبحت حرًا للانضمام إلى وكالة أخرى';

  @override
  String get errorAgencyOpenNotAllowed => 'لا يمكنك فتح وكالة الآن';

  @override
  String get errorAccountLocked => 'حسابك مقفل مؤقتاً من فريق Kabso.';

  @override
  String errorAccountLockedUntil(String date, String reason) {
    return 'حسابك مقفل مؤقتاً حتى $date. السبب: $reason';
  }

  @override
  String get errorAccountRestricted => 'هذه الميزة موقوفة لحسابك مؤقتاً.';

  @override
  String errorAccountRestrictedUntil(String what, String date) {
    return '$what موقوف لحسابك حتى $date.';
  }

  @override
  String get restrictionChatMute => 'إرسال الرسائل والتعليقات';

  @override
  String get restrictionNoLive => 'البث المباشر';

  @override
  String get restrictionNoGifts => 'إرسال الهدايا';

  @override
  String get restrictionNoPosting => 'النشر';

  @override
  String get errorPasswordChangeRequired => 'اختر كلمة مرور جديدة للمتابعة.';

  @override
  String get passwordChangeTitle => 'كلمة مرور جديدة';

  @override
  String get passwordChangeBody =>
      'طلب فريق Kabso تغيير كلمة مرور حسابك. اختر كلمة مرور جديدة لتسجيل الدخول؛ ستنتهي جلساتك الأخرى.';

  @override
  String get passwordChangeNew => 'كلمة المرور الجديدة';

  @override
  String get passwordChangeConfirm => 'تأكيد كلمة المرور';

  @override
  String get passwordChangeMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get passwordChangeSame => 'اختر كلمة مرور مختلفة عن الحالية.';

  @override
  String get passwordChangeTooShort => '٨ أحرف على الأقل.';

  @override
  String get passwordChangeSubmit => 'حفظ وتسجيل الدخول';

  @override
  String get hostApplyTitle => 'كن مضيفاً مع الإدارة';

  @override
  String get hostApplyIntro =>
      'تبثّ مباشرة مع فريق Kabso Live، بلا وكالة وبلا عمولة وكالة. نراجع طلبك ونبلغك بالنتيجة.';

  @override
  String get hostApplyButton => 'قدّم الطلب';

  @override
  String get hostApplyPendingTitle => 'طلبك قيد المراجعة';

  @override
  String hostApplyPendingBody(String date) {
    return 'أرسلت طلبك في $date. سنبلغك عند القرار.';
  }

  @override
  String get hostApplyCancel => 'إلغاء الطلب';

  @override
  String get hostApplyCancelConfirmTitle => 'إلغاء طلبك؟';

  @override
  String get hostApplyCancelConfirmBody => 'يمكنك التقديم مرة أخرى في أي وقت.';

  @override
  String get hostApplyCancelKeep => 'إبقاء الطلب';

  @override
  String get hostApplyCancelled => 'أُلغي طلبك';

  @override
  String get hostApplyApprovedTitle => 'أنت مضيف مع الإدارة ✓';

  @override
  String get hostApplyApprovedBody =>
      'يمكنك البث الآن مباشرة مع فريق Kabso Live، بلا وكالة.';

  @override
  String get hostApplyGoLive => 'ابدأ البث';

  @override
  String get hostApplyHostAgencyTitle => 'لديك صلاحية البث';

  @override
  String get hostApplyRejectedTitle => 'لم تتم الموافقة على طلبك';

  @override
  String hostApplyRejectedReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String hostApplyReapplyOn(String date) {
    return 'يمكنك التقديم مجدداً من $date';
  }

  @override
  String get hostApplyReapplyNow => 'يمكنك التقديم مجدداً الآن';

  @override
  String get hostApplyNotActive => 'حسابك غير نشط الآن، فلا يمكنك التقديم';

  @override
  String get hostApplyFormTitle => 'مضيف مع الإدارة';

  @override
  String get hostApplyStepInfo => 'بياناتك';

  @override
  String get hostApplyName => 'الاسم الظاهر في البث';

  @override
  String get hostApplyNameHint => 'تأكد أنه الاسم الذي تريد أن يراه المشاهدون';

  @override
  String get hostApplyNameError => 'اكتب الاسم الظاهر';

  @override
  String get hostApplyCountry => 'البلد';

  @override
  String get hostApplyCountryError => 'اختر بلدك';

  @override
  String get hostApplyBirth => 'تاريخ الميلاد';

  @override
  String get hostApplyBirthPick => 'اختر التاريخ';

  @override
  String get hostApplyBirthError => 'اختر تاريخ ميلادك';

  @override
  String hostApplyMinAge(String age) {
    return 'البث مع الإدارة للبالغين فقط ($age+)';
  }

  @override
  String get hostApplyContactType => 'وسيلة التواصل';

  @override
  String get hostApplyContactValue => 'رقمك أو معرّفك';

  @override
  String get hostApplyContactError => 'اكتب وسيلة تواصل نصل بها إليك';

  @override
  String get hostApplyBio => 'نبذة: ماذا ستبث؟';

  @override
  String get hostApplyBioHint => 'مثال: طبخ، ألعاب، دردشة، موسيقى';

  @override
  String get hostApplyBioError => 'اكتب نبذة قصيرة عمّا ستبثه';

  @override
  String get hostApplyLinks => 'حساباتك في منصات البث (اختياري)';

  @override
  String get hostApplyAddLink => 'إضافة رابط';

  @override
  String get hostApplyLinkError => 'رابط يبدأ بـ https://';

  @override
  String get hostApplyStepId => 'تحقق الهوية (إلزامي)';

  @override
  String get hostApplyStepRules => 'قواعد المضيفين';

  @override
  String get hostApplyRulesText =>
      '• احترم المشاهدين، ولا تبث محتوى مسيئاً أو للبالغين.\n• لا تطلب الهدايا بالإكراه أو الخداع، ولا تبث محتوى غيرك دون حق.\n• حافظ على خصوصيتك وخصوصية الآخرين.\n• يسحب الفريق صلاحية البث عند مخالفة القواعد.';

  @override
  String get hostApplyRulesAccept => 'قرأت قواعد المضيفين وأوافق عليها';

  @override
  String get hostApplyRulesError => 'وافق على القواعد للمتابعة';

  @override
  String get hostApplyPrivacy =>
      'صورك وبياناتك خاصة: يراها فريق المراجعة فقط، ولا تظهر لأي أحد.';

  @override
  String get hostApplySubmit => 'أرسل الطلب';

  @override
  String get hostApplySent => 'أُرسل طلبك. سنبلغك بالنتيجة';

  @override
  String get hostApplyRefusedPending => 'لديك طلب قيد المراجعة بالفعل';

  @override
  String get hostApplyRefusedHost => 'لديك صلاحية البث بالفعل';

  @override
  String get hostApplyRefusedAgency =>
      'أنت في وكالة: البث مع الإدارة لمن ليس في وكالة';

  @override
  String get hostApplyRefusedCooldown => 'لا يمكنك التقديم مجدداً الآن';

  @override
  String get notifHostApproved =>
      'تمت الموافقة على طلبك: أنت الآن مضيف مع إدارة Kabso Live ويمكنك بدء البث';

  @override
  String get notifHostRejected =>
      'لم تتم الموافقة على طلبك لتكون مضيفاً مع الإدارة. افتح «الوكالة» لمعرفة السبب';

  @override
  String get errorHostApplicationNotAllowed => 'لا يمكنك التقديم الآن';

  @override
  String get liveCategoryRowLabel => 'تصنيفات البث';

  @override
  String get liveCategoryAll => 'الكل';

  @override
  String get liveCategoryLive => 'بث مباشر';

  @override
  String get liveCategoryAudio => 'بث صوتي';

  @override
  String get liveCategoryPodcast => 'بث بودكاست';

  @override
  String get liveCategoryStreamer => 'بث ستريمر';

  @override
  String get liveStreamerSoonTitle => 'بث الستريمر قريباً';

  @override
  String get liveStreamerSoonBody => 'قريباً تبث شاشة هاتفك مباشرة لمتابعيك.';

  @override
  String get livePodcastEmptyTitle => 'لا بودكاست مباشر الآن';

  @override
  String get livePodcastEmptyBody => 'ابدأ حلقتك أو عُد لاحقاً.';

  @override
  String get podcastUpcoming => 'حلقات قادمة';

  @override
  String get podcastRemindMe => 'ذكّرني';

  @override
  String get podcastReminderOn => 'سنذكّرك';

  @override
  String podcastStartsAt(String time) {
    return '$time';
  }

  @override
  String podcastListeners(String count) {
    return 'المستمعون · $count';
  }

  @override
  String get podcastSeeAll => 'عرض الكل ‹';

  @override
  String podcastEpisode(int number) {
    return 'الحلقة $number';
  }

  @override
  String get podcastLiveTag => 'مباشر';

  @override
  String get podcastTopicBusiness => 'ريادة أعمال';

  @override
  String get podcastTopicTech => 'تقنية';

  @override
  String get podcastTopicSports => 'رياضة';

  @override
  String get podcastTopicReligion => 'دين';

  @override
  String get podcastTopicSociety => 'مجتمع';

  @override
  String get podcastTopicEntertainment => 'ترفيه';

  @override
  String get podcastTopicOther => 'أخرى';

  @override
  String get podcastRaiseHand => 'ارفع يدك';

  @override
  String get podcastLowerHand => 'أنزل يدك';

  @override
  String get podcastHandUp => 'يدك مرفوعة. اضغط لإنزالها.';

  @override
  String get podcastLeaveStage => 'عُد إلى المستمعين';

  @override
  String get podcastAskTitle => 'ارفع يدك';

  @override
  String get podcastAskHint => 'سؤالك باختصار (اختياري)';

  @override
  String get podcastAskSend => 'ارفع يدي';

  @override
  String get podcastHandsTitle => 'رفع الأيدي ✋';

  @override
  String podcastHandsRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب',
      many: '$count طلباً',
      few: '$count طلبات',
      two: 'طلبان',
      one: 'طلب واحد',
      zero: 'لا طلبات',
    );
    return '$_temp0';
  }

  @override
  String podcastHandsSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقاعد متاحة',
      two: 'مقعدان متاحان',
      one: 'مقعد واحد متاح',
      zero: 'لا مقعد متاح',
    );
    return '$_temp0';
  }

  @override
  String get podcastLater => 'لاحقاً';

  @override
  String get podcastBringUp => 'اصعد';

  @override
  String get podcastNoHands => 'لا أيدي مرفوعة الآن.';

  @override
  String podcastHandsBadge(int count) {
    return '$count أيدٍ مرفوعة';
  }

  @override
  String get podcastQuestionTime => 'مدة السؤال';

  @override
  String podcastMinutes(int count) {
    return '$count د';
  }

  @override
  String get podcastNoLimit => 'بدون حد';

  @override
  String get podcastQuestionsOpen => 'استقبال الأسئلة';

  @override
  String podcastQuestionPill(String time) {
    return 'سؤال · $time';
  }

  @override
  String get podcastQuestionsClosed => 'المضيف لا يستقبل أسئلة الآن.';

  @override
  String get podcastSeatsFull => 'المقاعد الثلاثة ممتلئة. أنزل متحدثاً أولاً.';

  @override
  String get podcastDeferred => 'لاحقاً';

  @override
  String get podcastSpeakerDown => 'إنزال إلى المستمعين';

  @override
  String get podcastSetupTopic => 'موضوع الحلقة';

  @override
  String get podcastSetupTitleHint => 'عنوان الحلقة';

  @override
  String get podcastSetupTitleRequired => 'اكتب عنوان الحلقة أولاً.';

  @override
  String get podcastSetupGuests => 'الضيوف (حتى 3)';

  @override
  String get podcastSetupAddGuest => 'إضافة ضيف';

  @override
  String get podcastSetupGuestsNote => 'نرسل الدعوة لكل ضيف عند دخوله البث.';

  @override
  String get podcastSetupGuestSearch => 'ابحث باسم المستخدم';

  @override
  String get podcastSetupQuestions => 'أسئلة المستمعين';

  @override
  String get podcastSetupOpen => 'مفتوحة';

  @override
  String get podcastSetupClosed => 'مغلقة';

  @override
  String get podcastSetupWhen => 'الموعد';

  @override
  String get podcastSetupNow => 'الآن';

  @override
  String get podcastSetupSchedule => 'جدولة';

  @override
  String get podcastSetupScheduled =>
      'جُدولت الحلقة. نذكّر متابعيك قبلها بـ 15 دقيقة.';

  @override
  String get podcastSetupScheduleAction => 'جدولة الحلقة';

  @override
  String get goLiveModePodcast => 'بث بودكاست';

  @override
  String get goLiveModeStreamer => 'بث ستريمر';

  @override
  String get liveCardTagStreamer => 'ستريمر';

  @override
  String get goLiveStreamerSoonIos => 'قريباً على آيفون';

  @override
  String get goLiveStreamerIosSnack => 'بث ستريمر قريباً على آيفون';

  @override
  String get streamerSetupBody =>
      'يرى المشاهدون شاشة هاتفك، لعبة أو تطبيق، مع فقاعة صغيرة من كاميرتك الأمامية.';

  @override
  String get streamerCameraBubble => 'فقاعة الكاميرا';

  @override
  String get streamerCameraCorner => 'مكان الفقاعة';

  @override
  String get streamerCornerTopLeft => 'أعلى اليسار';

  @override
  String get streamerCornerTopRight => 'أعلى اليمين';

  @override
  String get streamerCornerBottomLeft => 'أسفل اليسار';

  @override
  String get streamerCornerBottomRight => 'أسفل اليمين';

  @override
  String get streamerMic => 'الميكروفون';

  @override
  String get streamerGameAudio => 'صوت اللعبة';

  @override
  String get streamerGameAudioNote => 'بعض الألعاب تمنع التقاط صوتها';

  @override
  String get streamerHeadphonesTip =>
      'استخدم سماعات حتى لا يُسمع صوت اللعبة مرتين';

  @override
  String get streamerGameAudioOld =>
      'صوت اللعبة يحتاج أندرويد 10 أو أحدث، سيُبث صوت الميكروفون فقط';

  @override
  String get streamerPrivacyNote =>
      'لا يرى المشاهدون شاشتك وأنت داخل Kabso Live';

  @override
  String get streamerConsentRefused =>
      'لم تسمح بتصوير الشاشة، لذلك لم يبدأ البث';

  @override
  String streamerConsentFailed(String code) {
    return 'تعذّر طلب إذن تصوير الشاشة ($code)';
  }

  @override
  String get streamerConsentHint =>
      'اضغط \"بدء\" في نافذة أندرويد لمشاركة شاشتك';

  @override
  String get streamerShareAgainFailed =>
      'تعذّر تشغيل مشاركة الشاشة، حاول مرة أخرى';

  @override
  String get streamerFailServiceDenied =>
      'لم يسمح أندرويد بتشغيل خدمة البث، فلا يمكن تصوير الشاشة. افتح Kabso Live من جديد وحاول مرة أخرى';

  @override
  String get streamerFailSecurity =>
      'رفض أندرويد تصوير الشاشة لأسباب أمان. اضغط «ابدأ البث» من جديد واختر «بدء» في نافذة أندرويد';

  @override
  String get streamerFailStoppedBySystem =>
      'أوقف أندرويد تصوير الشاشة لأن خدمة البث توقفت';

  @override
  String get streamerFailUnsupportedOs =>
      'إصدار أندرويد على هذا الهاتف لا يدعم مشاركة الشاشة';

  @override
  String streamerFailCapture(String code) {
    return 'تعذّر بدء تصوير الشاشة ($code)';
  }

  @override
  String streamerFailPublish(String code) {
    return 'تعذّر إرسال الشاشة إلى البث ($code)';
  }

  @override
  String get streamerCopyReport => 'نسخ تقرير المشكلة';

  @override
  String get streamerReportCopied => 'نُسخ التقرير، أرسله لنا';

  @override
  String get streamerReportTitle => 'لم تبدأ مشاركة الشاشة';

  @override
  String get streamerOnAir => 'شاشتك على الهواء';

  @override
  String get streamerPausedInApp => 'الشاشة متوقفة مؤقتاً وأنت داخل Kabso Live';

  @override
  String get streamerPausedCall => 'الشاشة متوقفة أثناء المكالمة';

  @override
  String get streamerPausedScreenOff => 'الشاشة متوقفة والهاتف مقفل';

  @override
  String get streamerGoToGame => 'اذهب إلى اللعبة';

  @override
  String get streamerStoppedTitle => 'توقفت مشاركة الشاشة';

  @override
  String get streamerShareAgain => 'شارك الشاشة من جديد';

  @override
  String get streamerGameLive => 'صوت اللعبة يُبث';

  @override
  String get streamerGameMuted => 'صوت اللعبة مكتوم';

  @override
  String get streamerGameUnavailable =>
      'صوت اللعبة غير متاح على هذا الهاتف، يُبث الميكروفون فقط';

  @override
  String get streamerShowCamera => 'إظهار الكاميرا';

  @override
  String get streamerHideCamera => 'إخفاء الكاميرا';

  @override
  String get streamerMuteGame => 'كتم صوت اللعبة';

  @override
  String get streamerUnmuteGame => 'تشغيل صوت اللعبة';

  @override
  String get streamerNotifMicOff => 'كتم المايك';

  @override
  String get streamerNotifMicOn => 'تشغيل المايك';

  @override
  String get streamerDragHint => 'اسحب الفقاعة إلى أي زاوية';

  @override
  String get streamerPausedViewer =>
      'الشاشة متوقفة مؤقتاً، سيعود البث بعد قليل';

  @override
  String get streamerWaiting => 'بانتظار شاشة المضيف…';

  @override
  String get streamerWaitingCamera => 'بانتظار صورة المضيف…';

  @override
  String get streamerFullscreen => 'ملء الشاشة';

  @override
  String get streamerExitFullscreen => 'الخروج من ملء الشاشة';

  @override
  String streamerScreenSemantics(String name) {
    return 'شاشة $name';
  }

  @override
  String chatJoinedMale(String name) {
    return '$name دخل البث';
  }

  @override
  String chatJoinedFemale(String name) {
    return '$name دخلت البث';
  }

  @override
  String get liveThemePodcastStudio => 'استوديو البودكاست';

  @override
  String get liveThemePodcastMajlis => 'مجلس الخيمة';

  @override
  String get liveThemePodcastLibrary => 'مكتبة الزمرد';

  @override
  String get errorLiveQuestionsClosed => 'المضيف لا يستقبل أسئلة الآن.';

  @override
  String get podcastSpeaking => 'يتحدث';

  @override
  String get podcastMuted => 'الميكروفون مغلق';

  @override
  String get inviteTitle => 'دعوة صديق';

  @override
  String get inviteRulesTooltip => 'القواعد';

  @override
  String get inviteHeroLine => 'ادعُ أصدقاءك واربح حتى';

  @override
  String inviteMoneyHint(String money) {
    return '≈ $money';
  }

  @override
  String inviteTickerLine(String name, String amount) {
    return '$name ربح $amount كرزة، مبروك';
  }

  @override
  String get inviteCardTitle => 'ادعُ أصدقاء جدداً للانضمام إلى Kabso';

  @override
  String inviteStepSignup(String amount) {
    return 'يسجّل صديقك بكودك: تحصل على $amount كرزة.';
  }

  @override
  String inviteStepRecharge(String percent) {
    return 'أول شحن لصديقك: تحصل على $percent من قيمته بالكرز.';
  }

  @override
  String inviteStepHold(String hours) {
    return 'تُضاف المكافآت إلى رصيد الكرز القابل للسحب بعد التحقق ($hours ساعة).';
  }

  @override
  String inviteYouGet(String you, String friend) {
    return 'تحصل أنت على $you، ويحصل صديقك على $friend';
  }

  @override
  String inviteYouGetOnly(String you) {
    return 'تحصل أنت على $you عن كل صديق';
  }

  @override
  String inviteCherries(String amount) {
    return '$amount كرزة';
  }

  @override
  String get inviteNow => 'ادعُ الآن';

  @override
  String get inviteMyCode => 'كود دعوتي:';

  @override
  String get inviteCopy => 'نسخ';

  @override
  String get inviteCodeCopied => 'تم نسخ كود الدعوة';

  @override
  String get inviteLinkCopied => 'تم نسخ رابط الدعوة';

  @override
  String get inviteMilestonesTitle => 'ادعُ أصدقاء جدداً واربح حتى';

  @override
  String inviteInvitedCount(String count) {
    return '$count مدعو';
  }

  @override
  String inviteMilestoneFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صديق',
      many: '$count صديقاً',
      few: '$count أصدقاء',
      two: 'صديقان',
      one: 'صديق واحد',
    );
    return '$_temp0';
  }

  @override
  String get inviteMilestoneLocked => 'مقفلة';

  @override
  String get inviteMilestoneUnlocked => 'تحققت، قيد المراجعة';

  @override
  String get inviteMilestoneClaimed => 'أُضيفت';

  @override
  String inviteMilestoneSemantics(String friends, String amount, String state) {
    return 'مرحلة $friends: $amount كرزة، $state';
  }

  @override
  String inviteRewardsPending(String amount) {
    return 'محجوز: $amount';
  }

  @override
  String inviteRewardsCredited(String amount) {
    return 'أُضيف: $amount';
  }

  @override
  String get inviteFriendsTitle => 'أصدقاؤك';

  @override
  String get inviteStatusPending => 'قيد التحقق';

  @override
  String get inviteStatusQualified => 'مؤهل';

  @override
  String get inviteStatusRejected => 'غير مؤهل';

  @override
  String get inviteStatusVoid => 'ملغى';

  @override
  String get inviteRecharged => 'شحن';

  @override
  String get inviteNoFriends => 'لم تدعُ أحداً بعد. شارك كودك مع أصدقائك.';

  @override
  String get inviteErrorTitle => 'تعذّر تحميل صفحة الدعوة';

  @override
  String inviteShareText(String code, String link) {
    return 'انضم إليّ في Kabso Live. استخدم كود دعوتي $code عند التسجيل: $link';
  }

  @override
  String get inviteShareWhatsapp => 'واتساب';

  @override
  String get inviteShareMore => 'مشاركة';

  @override
  String get inviteShareCopyLink => 'نسخ الرابط';

  @override
  String get inviteShareFailed => 'تعذّر فتح التطبيق؛ نُسخ الرابط بدلاً من ذلك';

  @override
  String get inviteRulesTitle => 'قواعد الدعوة';

  @override
  String inviteRuleSignup(String amount) {
    return 'عندما يسجّل صديق جديد بكود دعوتك تحصل على $amount كرزة.';
  }

  @override
  String inviteRuleInvitee(String amount) {
    return 'ويحصل صديقك على $amount كرزة.';
  }

  @override
  String inviteRuleRecharge(String percent) {
    return 'عند أول شحن لصديقك (من الموقع أو وكيل شحن أو طلب شحن) تحصل على $percent من قيمته بالكرز.';
  }

  @override
  String inviteRuleHold(String hours) {
    return 'تُحجز كل مكافأة $hours ساعة ثم تُضاف إلى رصيد الكرز القابل للسحب. تُلغى إذا حُظر حساب صديقك أو حُذف أو قُيّد.';
  }

  @override
  String get inviteRuleFair =>
      'مكافأة واحدة لكل جهاز ولكل بريد، ولا تُحتسب دعوة نفسك أو حساباتك الأخرى.';

  @override
  String inviteRuleCap(String count) {
    return 'يُكافأ حتى $count تسجيلاً في اليوم.';
  }

  @override
  String inviteRuleLater(String days) {
    return 'يمكن لصديقك إدخال كودك من الإعدادات خلال $days يوم من تسجيله، مرة واحدة.';
  }

  @override
  String inviteRuleMilestones(String list) {
    return 'مكافآت المراحل، مرة واحدة لكل مرحلة، حسب عدد أصدقائك المؤهلين:\n$list';
  }

  @override
  String get inviteRuleWithdraw =>
      'الكرز يخضع لقواعد السحب المعتادة في محفظة الكرز.';

  @override
  String get referralApplyRow => 'كود الدعوة';

  @override
  String get referralApplyTitle => 'أدخل كود الدعوة';

  @override
  String get referralApplyLabel => 'كود صديقك أو رابط الدعوة';

  @override
  String referralApplyBody(String date) {
    return 'يمكنك إدخاله مرة واحدة حتى $date.';
  }

  @override
  String get referralApplySubmit => 'تأكيد';

  @override
  String get referralApplied => 'تم ربط حسابك بكود صديقك';

  @override
  String get referralAppliedNotEligible =>
      'حُفظ الكود، لكن هذه الدعوة لا تستوفي الشروط';

  @override
  String get errorReferralUnavailable => 'الدعوات غير متاحة الآن';

  @override
  String get errorReferralCodeInvalid => 'كود الدعوة غير صحيح';

  @override
  String get errorReferralNotAllowed => 'لا يمكنك إدخال كود دعوة الآن';

  @override
  String get errorDeviceAccountLimit =>
      'لا يمكن إنشاء أكثر من حسابين من نفس الجهاز. يمكنك تسجيل الدخول إلى حساباتك الحالية.';

  @override
  String errorDeviceAccountLimitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لا يمكن إنشاء أكثر من $count حساب من نفس الجهاز.',
      many: 'لا يمكن إنشاء أكثر من $count حسابًا من نفس الجهاز.',
      few: 'لا يمكن إنشاء أكثر من $count حسابات من نفس الجهاز.',
      two: 'لا يمكن إنشاء أكثر من حسابين من نفس الجهاز.',
      one: 'لا يمكن إنشاء أكثر من حساب واحد من نفس الجهاز.',
    );
    return '$_temp0 يمكنك تسجيل الدخول إلى حساباتك الحالية.';
  }

  @override
  String get registerReferralLabel => 'كود الدعوة (اختياري)';

  @override
  String get registerReferralHelper =>
      'إن دعاك صديق، اكتب كوده أو الصق رابط الدعوة';

  @override
  String get cherryReasonReferral => 'مكافأة دعوة';

  @override
  String inviteStepMilestones(String list) {
    return 'مكافآت إضافية حسب عدد أصدقائك المؤهلين:\n$list';
  }

  @override
  String inviteMilestoneItem(String friends, String amount) {
    return '$friends: $amount كرزة';
  }

  @override
  String get inviteRuleClawback =>
      'إذا ألغى فريق Kabso دعوة غير صالحة يُسترجع الكرز الذي أُضيف بسببها، وإن لم يكفِ رصيدك يصبح سالباً ولا يمكن السحب حتى يُسدَّد.';

  @override
  String get cherryReasonReferralReversal => 'استرجاع مكافأة دعوة';

  @override
  String get notifReferralReversed =>
      'ألغى فريق Kabso دعوة غير صالحة واسترجع كرز مكافأتها. افتح محفظة الكرز للتفاصيل';

  @override
  String get feedSuggested => 'مقترح لك';

  @override
  String get feedPostSeeMore => 'المزيد';

  @override
  String feedPostViewCount(String count) {
    return '$count مشاهدة';
  }

  @override
  String storyWatchLive(String name) {
    return 'شاهد بث $name المباشر';
  }

  @override
  String get storyReplyHint => 'اكتب رسالة…';

  @override
  String get storyReplySend => 'إرسال';

  @override
  String get storyReplySent => 'أُرسلت إلى الرسائل';

  @override
  String storyReact(String name) {
    return 'أعجبتني قصة $name';
  }

  @override
  String get notifCoverRemoved =>
      'أزال فريق الإشراف صورة غلاف ملفك لمخالفتها الإرشادات';

  @override
  String get profileEditCover => 'صورة الغلاف';

  @override
  String get profileEditCoverSet => 'مضبوطة';

  @override
  String get profileEditCoverRemove => 'حذف صورة الغلاف';

  @override
  String get profileEditCoverUpdated => 'تم تحديث صورة الغلاف';

  @override
  String get profileEditCoverRemoved => 'حُذفت صورة الغلاف';

  @override
  String profileCoverOf(String name) {
    return 'صورة غلاف $name';
  }

  @override
  String get profileTabPostsWord => 'منشورات';

  @override
  String get profileTabReelsWord => 'ريلز';

  @override
  String get profileTabRepostsWord => 'إعادات';

  @override
  String get profileFollowerWord => 'متابِع';

  @override
  String get profileFollowingWord => 'متابَع';

  @override
  String profileJoined(String date) {
    return 'انضم في $date';
  }

  @override
  String get profileBlockedTitle => 'حظرت هذا الحساب';

  @override
  String get profileBlockedBody =>
      'لن ترى منشوراته ولن يتمكن من مراسلتك. ألغِ الحظر لتراها.';

  @override
  String get profileTabSavedWord => 'محفوظات';

  @override
  String get profileBondFamily => 'العائلة';

  @override
  String get profileBondCouple => 'العلاقة';

  @override
  String get profileBondMedals => 'الميداليات';

  @override
  String liveCardId(String id) {
    return 'ID: $id';
  }

  @override
  String get liveCardReport => 'إبلاغ';

  @override
  String get liveCardFollowers => 'المتابِعون';

  @override
  String get liveCardFollowing => 'المتابَعون';

  @override
  String get liveCardCherries => 'الكرز المستلم';

  @override
  String get liveCardCoinsSent => 'الكوينز المرسلة';

  @override
  String get liveCardFollow => 'متابعة';

  @override
  String get liveCardUnfollow => 'إلغاء المتابعة';

  @override
  String get liveCardChat => 'دردشة';

  @override
  String get liveCardSendGift => 'إرسال هدية';

  @override
  String get liveCardEditProfile => 'تعديل الملف';

  @override
  String get liveCardFamilyNone => 'بلا عائلة';

  @override
  String get privacyCardStatsTitle => 'الأرقام في بطاقتك';

  @override
  String get privacyHideCherries => 'إخفاء الكرز المستلم';

  @override
  String get privacyHideCoins => 'إخفاء الكوينز المرسلة';

  @override
  String get privacyCardStatsHint =>
      'الرقم المخفي لا يظهر لغيرك في بطاقتك داخل البث ولا في ملفك. أنت وفريق Kabso تستطيعون رؤيته.';

  @override
  String get kycStepTitle => 'تأكيد الهوية';

  @override
  String get kycStepIntro =>
      'نتأكد من هويتك عبر Didit: صورة وثيقتك ثم صورة لوجهك. لا حاجة لرفع صورة الهوية والسيلفي يدوياً.';

  @override
  String get kycStatusNotStarted => 'لم تبدأ التحقق بعد';

  @override
  String get kycStatusNotStartedHint =>
      'صوّر وثيقة هويتك (بطاقة أو جواز أو رخصة) ثم وجهك. يستغرق نحو دقيقتين.';

  @override
  String get kycStatusInProgress => 'التحقق لم يكتمل';

  @override
  String get kycStatusInProgressHint =>
      'تابع من حيث توقفت؛ ستظهر النتيجة هنا عند الانتهاء.';

  @override
  String get kycStatusInReview => 'التحقق قيد المراجعة';

  @override
  String get kycStatusInReviewHint =>
      'تتم مراجعة التحقق، وسنخبرك بالنتيجة بإشعار.';

  @override
  String get kycStatusApproved => 'تم تأكيد هويتك';

  @override
  String get kycStatusApprovedHint => 'هويتك مؤكدة ويمكنك إرسال الطلب.';

  @override
  String get kycStatusDeclined => 'لم يتم تأكيد هويتك';

  @override
  String get kycStatusDeclinedHint =>
      'يمكنك المحاولة مرة أخرى بعد مراعاة السبب:';

  @override
  String get kycStatusExpired => 'انتهت جلسة التحقق';

  @override
  String get kycStatusExpiredHint => 'انتهت الجلسة قبل اكتمالها. ابدأ من جديد.';

  @override
  String get kycStart => 'ابدأ التحقق';

  @override
  String get kycContinue => 'متابعة التحقق';

  @override
  String get kycRetry => 'إعادة المحاولة';

  @override
  String kycWhatHappens(String provider) {
    return 'يُفتح التحقق داخل التطبيق لدى $provider. لا نحفظ صور وثيقتك أو وجهك.';
  }

  @override
  String get kycRefusedDailyLimit =>
      'وصلت إلى الحد اليومي لمحاولات التحقق. حاول غداً.';

  @override
  String get kycUnavailable => 'التحقق من الهوية غير متاح الآن. حاول لاحقاً.';

  @override
  String get kycRequiredToSubmit => 'أكمل «تأكيد الهوية» أولاً.';

  @override
  String get kycRequiredApproved => 'يلزم تأكيد هويتك (مقبول) قبل فتح الوكالة.';

  @override
  String get kycReasonUnderAge => 'العمر في الوثيقة أقل من ١٨ سنة.';

  @override
  String get kycReasonNoBirthDate =>
      'تعذّرت قراءة تاريخ الميلاد في الوثيقة. صوّرها بوضوح.';

  @override
  String get kycReasonDocumentExpired =>
      'الوثيقة منتهية الصلاحية. استخدم وثيقة سارية.';

  @override
  String get kycReasonNoFace => 'لم يظهر وجهك بوضوح. صوّر في مكان مضاء.';

  @override
  String get kycReasonLiveness =>
      'لم ينجح فحص الحيوية. صوّر وجهك مباشرة دون صورة أو شاشة.';

  @override
  String get kycReasonFaceMatch => 'وجهك لا يطابق صورة الوثيقة.';

  @override
  String get kycReasonOther => 'لم تجتز إحدى خطوات التحقق.';

  @override
  String get kycClose => 'إغلاق';

  @override
  String get kycOpenInBrowser => 'فتح في المتصفح';

  @override
  String get notifKycApproved => 'تم تأكيد هويتك بنجاح';

  @override
  String get notifKycDeclined =>
      'لم يتم تأكيد هويتك. افتح الطلب لمعرفة السبب والمحاولة مرة أخرى';

  @override
  String get notifKycInReview =>
      'التحقق من هويتك قيد المراجعة، سنخبرك بالنتيجة';

  @override
  String get errorKycNotAllowed => 'لا يمكن بدء التحقق الآن';

  @override
  String get agencyOpenRefusedKyc =>
      'يلزم تأكيد هويتك أولاً (خطوة «تأكيد الهوية»).';

  @override
  String pkFollowHost(String name) {
    return 'متابعة $name';
  }

  @override
  String get pkTypeNormal => 'PK عادي';

  @override
  String get pkTypeDares => 'PK أحكام';

  @override
  String get pkTypeDaresHint => 'الخاسر ينفذ حكماً تسحبه القرعة';

  @override
  String get pkTypeLabel => 'نوع PK';

  @override
  String get pkRandomDares => 'عشوائي أحكام';

  @override
  String pkInviteSentDares(String name) {
    return 'أُرسلت دعوة PK أحكام إلى $name';
  }

  @override
  String get pkDareDrawTitle => 'قرعة الحكم';

  @override
  String get pkDareLevelEasy => 'سهل';

  @override
  String get pkDareLevelMedium => 'متوسط';

  @override
  String get pkDareLevelHard => 'صعب';

  @override
  String pkDareLoserDeciding(String name) {
    return 'بانتظار قرار $name';
  }

  @override
  String get pkDareYourDare => 'حكمك';

  @override
  String get pkDareAccept => 'قبول';

  @override
  String get pkDareRefuse => 'رفض';

  @override
  String get pkDareRefuseTitle => 'رفض الحكم؟';

  @override
  String pkDareRefuseBody(String points) {
    return 'يُحتسب الرفض في نقاط PK: $points';
  }

  @override
  String get pkDareDone => 'نُفّذ ✅';

  @override
  String get pkDareNotDone => 'لم يُنفّذ ❌';

  @override
  String get pkDareJudge => 'هل نُفّذ الحكم؟';

  @override
  String get pkDareOutcomeDone => 'نُفّذ الحكم 🎉';

  @override
  String get pkDareOutcomeRefused => 'رفض الحكم';

  @override
  String get pkDareOutcomeNotDone => 'لم يُنفّذ الحكم';

  @override
  String get pkDareReport => 'إبلاغ عن الحكم';

  @override
  String get pkDareReported => 'شكراً، وصل البلاغ';

  @override
  String pkDareSemantics(String text, String time) {
    return 'الحكم: $text. الوقت المتبقي $time';
  }

  @override
  String get pkDareDrawSemantics => 'قرعة الحكم بين ثلاثة: سهل ومتوسط وصعب';

  @override
  String pkRecordPoints(String points) {
    return 'نقاط PK: $points';
  }

  @override
  String pkRecordDares(String done, String refused) {
    return 'أحكام نُفّذت: $done · رُفضت: $refused';
  }

  @override
  String get pkFailureDareClosed => 'لم يعد بالإمكان الرد على هذا الحكم';

  @override
  String get liveCountryPickerTitle => 'بلد «القريبة»';

  @override
  String get liveCountryPickerBody =>
      'اختر بلداً لترى بثوثه في «القريبة». لا يغيّر ملفك.';

  @override
  String liveNearbyCountryRow(String country) {
    return 'بلد «القريبة»: $country. تغيير';
  }

  @override
  String get liveNearbyChooseCountry => 'اختر بلداً';

  @override
  String get pkRematch => 'جولة أخرى';

  @override
  String pkRematchAsk(String name) {
    return 'العب جولة أخرى مع $name؟';
  }

  @override
  String pkRematchWaiting(String name) {
    return 'بانتظار $name…';
  }

  @override
  String pkRematchOffered(String name) {
    return '$name يريد جولة أخرى';
  }

  @override
  String get pkRematchBanner => 'جولة أخرى تبدأ';

  @override
  String get pkRematchDeclined => 'رفض المضيف الآخر الجولة الأخرى';

  @override
  String get pkRematchExpired => 'لم يردّ المضيف الآخر على الجولة الأخرى';

  @override
  String pkRematchSeconds(String seconds) {
    return '$seconds ث';
  }

  @override
  String get pkPointsLabel => 'نقاط PK';

  @override
  String pkPointsSemantics(String name, String points) {
    return 'نقاط PK لـ$name: $points';
  }

  @override
  String get pkRematchAfterDare => 'جولة أخرى بعد انتهاء الحكم';

  @override
  String pkEndForfeitPoints(String points) {
    return 'الانسحاب يخصم $points نقاط PK';
  }

  @override
  String get liveToolReportLive => 'الإبلاغ عن البث';

  @override
  String get liveReportTitle => 'لماذا تبلّغ عن هذا البث؟';

  @override
  String get liveReportNoteLabel => 'ملاحظة (اختياري)';

  @override
  String get liveReportNoteHint => 'صف ما حدث في البث';

  @override
  String get liveReportSend => 'إرسال البلاغ';

  @override
  String get liveReportSent => 'وصل بلاغك، سيراجع فريق Kabso البث.';

  @override
  String get errorDeviceBanned => 'تم حظر هذا الجهاز من فريق Kabso.';

  @override
  String errorDeviceBannedUntil(String date, String reason) {
    return 'تم حظر هذا الجهاز من فريق Kabso حتى $date. السبب: $reason';
  }

  @override
  String errorDeviceBannedPermanent(String reason) {
    return 'تم حظر هذا الجهاز من فريق Kabso نهائياً. السبب: $reason';
  }

  @override
  String errorAccountRestrictedUntilReason(
    String what,
    String date,
    String reason,
  ) {
    return '$what موقوف لحسابك حتى $date. السبب: $reason';
  }

  @override
  String get notifLiveModeratedEnd => 'أنهى فريق Kabso بثك.';

  @override
  String notifLiveModeratedNoLive(String date) {
    return 'أنهى فريق Kabso بثك ومنعك من البث حتى $date.';
  }

  @override
  String notifLiveModeratedSuspend(String date) {
    return 'أنهى فريق Kabso بثك وعلّق حسابك حتى $date.';
  }

  @override
  String notifLiveModeratedDevice(String date) {
    return 'أنهى فريق Kabso بثك وحظر جهازك حتى $date.';
  }

  @override
  String get notifLiveModeratedDevicePermanent =>
      'أنهى فريق Kabso بثك وحظر جهازك نهائياً.';

  @override
  String notifLiveModeratedReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get liveHostTasksTitle => 'مهام المضيف';

  @override
  String get liveHostTasksHide => 'إخفاء مهام المضيف';

  @override
  String liveHostTasksLevel(int level) {
    return 'Lv$level';
  }

  @override
  String liveHostTasksDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String liveHostTasksLabel(
    String task,
    String progress,
    String target,
    int days,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بقي $days يوم',
      few: 'بقيت $days أيام',
      two: 'بقي يومان',
      one: 'بقي يوم واحد',
    );
    return 'مهام المضيف: $task، $progress من $target، $_temp0';
  }

  @override
  String get liveToolQuickReplies => 'الردود السريعة';

  @override
  String get liveToolRoomRank => 'ترتيب الغرف';

  @override
  String get livePerformanceTitle => 'حالة الأداء';

  @override
  String get livePerformanceRealtime => 'بيانات لحظية';

  @override
  String get livePerformancePeak => 'ذروة المشاهدين';

  @override
  String get livePerformanceHelpLabel => 'عن هذه الأرقام';

  @override
  String get livePerformanceHelp =>
      'أرقام هذا البث، تتحدّث كل 15 ثانية: وقت البث، والمشاهدون الفريدون وأكبر عدد في وقت واحد، والمتابعون الجدد، والكرز المستلم، ومن أرسلوا الهدايا. يعرض الرسم القراءات المأخوذة أثناء فتح هذه البطاقة.';

  @override
  String liveLevelTicker(String name, int level, String host) {
    return 'تهانينا لـ $name على الترقية إلى المستوى $level في غرفة البث المباشر الخاصة بـ $host';
  }

  @override
  String get liveLevelTickerSupport => 'مستوى الدعم';

  @override
  String get liveLevelTickerCharm => 'مستوى الجاذبية';

  @override
  String get vipLoadError => 'تعذّر تحميل VIP';

  @override
  String get vipEmpty => 'لا توجد مستويات VIP معروضة الآن.';

  @override
  String get vipNotYet => 'لست VIP بعد';

  @override
  String vipUntil(String tier, String date) {
    return '$tier حتى $date';
  }

  @override
  String vipDaysLeft(String days) {
    return 'متبقٍ $days يوماً';
  }

  @override
  String vipOffSale(String tier) {
    return 'لم يعد $tier معروضاً للبيع؛ يبقى معك حتى نهايته ولا يُجدَّد.';
  }

  @override
  String get vipCurrent => 'مستواك الحالي';

  @override
  String vipForDays(String days) {
    return 'لمدة $days يوماً';
  }

  @override
  String vipPriceSemantics(String coins, String days) {
    return '$coins عملة لمدة $days يوماً';
  }

  @override
  String vipPerksTitle(String tier) {
    return 'امتيازات $tier';
  }

  @override
  String get vipPerksSoon => 'الميزات المعلّمة «قريباً» تُفعَّل عند إطلاقها.';

  @override
  String get vipPerksEmpty => 'لا توجد ميزات لهذا المستوى بعد.';

  @override
  String get vipPerkActive => 'مفعّلة';

  @override
  String vipPerkWith(String tier) {
    return 'مع $tier';
  }

  @override
  String get vipBuy => 'اشترِ الآن';

  @override
  String get vipRenew => 'جدّد';

  @override
  String get vipUpgrade => 'ترقية';

  @override
  String get vipLowerTier => 'أقل من مستواك';

  @override
  String get vipRenewLimit => 'وصلت إلى حد التجديد';

  @override
  String vipConfirmBuy(String tier) {
    return 'شراء $tier';
  }

  @override
  String vipConfirmRenew(String tier) {
    return 'تجديد $tier';
  }

  @override
  String vipConfirmUpgrade(String tier) {
    return 'الترقية إلى $tier';
  }

  @override
  String get vipConfirmPrice => 'السعر';

  @override
  String get vipConfirmBalance => 'رصيدك';

  @override
  String get vipConfirmUntil => 'ينتهي في';

  @override
  String vipUpgradeNote(String tier) {
    return 'يبدأ المستوى الجديد الآن؛ الأيام المتبقية من $tier لا تُحتسب ولا تُسترد.';
  }

  @override
  String get vipManualRenew => 'التجديد يدوي: لا يُخصم شيء تلقائياً.';

  @override
  String get vipShort => 'رصيدك من العملات لا يكفي.';

  @override
  String get vipRecharge => 'اشحن العملات';

  @override
  String vipPay(String coins) {
    return 'ادفع $coins';
  }

  @override
  String vipDone(String tier, String date) {
    return 'أصبحت $tier حتى $date';
  }

  @override
  String get vipRules => 'قواعد VIP';

  @override
  String vipRulesBody(String days) {
    return 'تشتري VIP بالعملات من رصيدك لمدة المستوى. التجديد يدوي ويضيف المدة إلى نهاية اشتراكك (حتى $days يوماً مقدماً). الترقية إلى مستوى أعلى تبدأ فوراً بسعره الكامل، ولا تُحتسب الأيام المتبقية من مستواك السابق. لا يمكن شراء مستوى أقل قبل انتهاء مستواك. لا يُخصم شيء تلقائياً.';
  }

  @override
  String get vipErrorDowngrade =>
      'لا يمكن شراء مستوى أقل من مستواك قبل انتهائه.';

  @override
  String get vipErrorRenewLimit => 'وصلت إلى أقصى مدة يمكن تجديدها مقدماً.';

  @override
  String get vipErrorTierOff => 'هذا المستوى لم يعد معروضاً للبيع.';

  @override
  String get errorVipUnavailable => 'لا يمكن شراء هذا المستوى الآن.';

  @override
  String get errorVipPriceChanged =>
      'تغيّر سعر هذا المستوى. راجع السعر الجديد.';

  @override
  String get walletReasonVipPurchase => 'شراء VIP';

  @override
  String vipCurrently(String status) {
    return 'حالياً: $status';
  }

  @override
  String get vipStatusNone => 'بدون VIP';

  @override
  String vipUpgradeTo(String tier) {
    return 'الترقية: $tier';
  }

  @override
  String get vipMaxTier => 'أعلى مستوى';

  @override
  String get vipBalanceLabel => 'رصيدك';

  @override
  String get vipStore => 'متجر VIP';

  @override
  String get vipStoreSoon => 'متجر هدايا VIP — قريباً.';

  @override
  String vipPerksSection(String tier) {
    return 'امتيازات $tier';
  }

  @override
  String get vipSectionIdentity => 'التعريف';

  @override
  String get vipSectionPrivilege => 'امتياز حصري';

  @override
  String vipPrivilegeTitle(String tier, String count, String total) {
    return 'الامتياز الحصري $tier $count/$total';
  }

  @override
  String get vipMine => 'الخاص بي VIP';

  @override
  String get vipPageTitle => 'في آي بي';

  @override
  String get vipPrivilegesHeader => 'امتيازات VIP';

  @override
  String get vipPayCoins => 'ادفع بالعملات الذهبية';

  @override
  String get liveDailyRankTitle => 'الترتيب اليومي';

  @override
  String get liveDailyRankHide => 'إخفاء الترتيب اليومي';

  @override
  String liveDailyRankGap(String gap) {
    return '$gap عن السابق';
  }

  @override
  String liveDailyRankLabel(String name, String rank, String points) {
    return '$name: الترتيب اليوم $rank، $points نقطة';
  }

  @override
  String get liveToolRecharge => 'الشحن';

  @override
  String get walletReasonVipDailyCoins => 'كوينز VIP اليومية';

  @override
  String liveBulletSentFree(String count) {
    return 'أُرسلت رسالة عامة مجانية · متبقي $count اليوم';
  }

  @override
  String vipEntranceJoined(String name) {
    return '$name دخل الغرفة';
  }

  @override
  String get vipVisitorsTitle => 'من زار ملفي';

  @override
  String get vipVisitorsEntry => 'من زار ملفي';

  @override
  String vipVisitorsTotal(String count) {
    return '$count زائر في آخر 30 يوماً';
  }

  @override
  String vipVisitorsVisits(String count) {
    return '$count زيارات';
  }

  @override
  String get vipVisitorsEmptyTitle => 'لا زوار بعد';

  @override
  String get vipVisitorsEmptyMessage => 'من يفتح ملفك يظهر هنا.';

  @override
  String get vipVisitorsNoPerkTitle => 'ميزة لأعضاء VIP';

  @override
  String get vipVisitorsNoPerkMessage => 'اعرف من زار ملفك مع VIP.';

  @override
  String get vipVisitorsNoPerkAction => 'شراء VIP';

  @override
  String get vipIdentity => 'التعريف';

  @override
  String get vipPreviewName => 'اسمك';

  @override
  String vipPerkPerDay(String value) {
    return '$value يومياً';
  }

  @override
  String get vipPerkSoonTag => 'قريباً';

  @override
  String vipPricePer(String days) {
    return 'كوينز / $days يوماً';
  }

  @override
  String vipSpeedupLine(String percent) {
    return '+$percent٪ تسريع المستوى';
  }

  @override
  String vipRenewalDiscountLine(String percent) {
    return 'خصم $percent٪ عند التجديد';
  }

  @override
  String get liveKabsoTeam => 'فريق كابسو';

  @override
  String get liveKabsoTeamInfoTitle => 'فريق كابسو';

  @override
  String get liveKabsoTeamInfo =>
      'هذا عضو في فريق كابسو يتابع البث للحفاظ على سلامة المجتمع. لا يُحتسب ضمن المشاهدين ولا الداعمين.';

  @override
  String liveKabsoTeamWatching(String name) {
    return '$name من فريق كابسو';
  }

  @override
  String get liveKabsoTeamHere => 'فريق كابسو يتابع هذا البث';

  @override
  String get bagCategoryChatBubble => 'إطارات الرسائل';

  @override
  String get bagCategoryEntryBanner => 'لافتات الدخول';

  @override
  String get bagCategoryEntryEffect => 'مؤثرات الدخول';

  @override
  String get bagCategoryMicWave => 'موجات المايك';

  @override
  String bagFromVip(String tier) {
    return 'من عضوية $tier';
  }

  @override
  String get bagNoSendVip => 'عناصر VIP تابعة لعضويتك ولا تُرسل';

  @override
  String get bagNoSendPermanent => 'العناصر الدائمة لا تُرسل';

  @override
  String get meHubStore => 'المتجر';

  @override
  String get storeTitle => 'المتجر';

  @override
  String get storeKindAvatarFrame => 'إطارات الصور';

  @override
  String get storeKindProfileCard => 'بطاقات تعريفية';

  @override
  String get storeKindChatBubble => 'فقاعات الرسائل';

  @override
  String get storeKindEntryBanner => 'لافتات الدخول';

  @override
  String get storeKindEntryEffect => 'سيارات الدخول';

  @override
  String get storeNew => 'جديد';

  @override
  String get storeOwned => 'تملكه';

  @override
  String storeOwnedUntil(String date) {
    return 'تملكه حتى $date — الشراء يضيف المدة إليه';
  }

  @override
  String get storeCoins => 'عملات';

  @override
  String get storeCherries => 'كرز';

  @override
  String get storeDuration => 'المدة';

  @override
  String get storePayWith => 'الدفع بـ';

  @override
  String get storePrice => 'السعر';

  @override
  String get storeBalance => 'رصيدك';

  @override
  String get storeBuy => 'شراء';

  @override
  String get storeGift => 'إهداء';

  @override
  String get storeRecharge => 'شحن';

  @override
  String get storeShortCoins => 'رصيد العملات لا يكفي لهذا العنصر.';

  @override
  String get storeShortCherries =>
      'رصيد الكرز لا يكفي. الكرز يُكسب من الهدايا التي تصلك في البث ولا يُشحن.';

  @override
  String storeBuyConfirm(String name, String days, String price) {
    return 'شراء «$name» لمدة $days مقابل $price؟';
  }

  @override
  String storeGiftConfirm(String name, String days, String user, String price) {
    return 'إهداء «$name» لمدة $days إلى $user مقابل $price؟';
  }

  @override
  String storeBought(String name, String date) {
    return 'تم الشراء. «$name» في حقيبتك حتى $date.';
  }

  @override
  String storeGiftSent(String user) {
    return 'أُرسلت الهدية إلى $user.';
  }

  @override
  String get storeWearNow => 'ارتدِ الآن';

  @override
  String get storeWorn => 'ترتديه الآن';

  @override
  String get storeGiftTitle => 'إهداء إلى…';

  @override
  String get storeGiftSearch => 'اسم المستخدم';

  @override
  String get storeGiftFollowing => 'من تتابعهم';

  @override
  String get storeGiftNone => 'لا يوجد أحد هنا بعد.';

  @override
  String get storeEmpty => 'لا توجد عناصر في المتجر بعد. عُد قريباً.';

  @override
  String get storePreviewSample => 'مرحباً بالجميع 👋';

  @override
  String storeTotal(String price, String days) {
    return '$price · $days';
  }

  @override
  String get errorStoreUnavailable => 'لا يمكن شراء هذا العنصر الآن.';

  @override
  String get errorStorePriceChanged =>
      'تغيّر سعر هذا العنصر. راجع السعر الجديد.';

  @override
  String get walletReasonStorePurchase => 'شراء من المتجر';

  @override
  String storeLockedCherries(String amount) {
    return 'كرز المهام المقفل لا يُصرف في المتجر ($amount مقفل).';
  }

  @override
  String get staffToolsTitle => 'أدوات فريق كابسو';

  @override
  String get staffMeIntro => 'الإشراف على البثوث من هاتفك';

  @override
  String get staffRoleOwner => 'مالك';

  @override
  String get staffRoleModeration => 'مشرف';

  @override
  String get staffRoleSupport => 'دعم';

  @override
  String get staffRoleFinance => 'مالية';

  @override
  String get staffShift => 'في المناوبة';

  @override
  String get staffShiftAutoHint =>
      'يعمل تلقائياً عند دخولك بثاً أو استخدام أدوات الفريق أو فتح «بثوثي»؛ تُوزَّع عليك البثوث وتصلك بلاغاتها، وتوقفه أنت';

  @override
  String get staffShiftOff => 'خارج المناوبة';

  @override
  String get staffMyLives => 'بثوثي';

  @override
  String get staffMyLivesEmpty => 'لا بثوث موكلة إليك الآن';

  @override
  String get staffMyLivesOffShift => 'شغّل «في المناوبة» لتصلك البثوث';

  @override
  String get staffAnyLive => 'يمكنك دخول أي بث كفريق كابسو من القائمة الرئيسية';

  @override
  String staffReportsCount(String count) {
    return 'بلاغات: $count';
  }

  @override
  String staffViewersCount(String count) {
    return '$count مشاهد';
  }

  @override
  String get staffEnterTitle => 'كيف تدخل البث؟';

  @override
  String get staffEnterVisible => 'دخول ظاهر (فريق كابسو)';

  @override
  String get staffEnterVisibleHint =>
      'تظهر في المشاهدين بشارة فريق كابسو ولا تُحتسب';

  @override
  String get staffEnterHidden => 'مراقبة خفية';

  @override
  String get staffEnterHiddenHint => 'لا يراك أحد ولا تكتب في الدردشة';

  @override
  String staffModeNow(String mode) {
    return 'أنت الآن: $mode';
  }

  @override
  String get staffModeSwitch => 'تبديل';

  @override
  String get staffReports => 'البلاغات';

  @override
  String get staffReportsEmpty => 'لا بلاغات على هذا البث';

  @override
  String get staffReportOnLive => 'على البث';

  @override
  String staffReportOnUser(String name) {
    return 'على $name';
  }

  @override
  String staffReportOnMessage(String name) {
    return 'رسالة من $name';
  }

  @override
  String staffReportBy(String name) {
    return 'أبلغ: $name';
  }

  @override
  String get staffReportClosed => 'تمت معالجته';

  @override
  String get staffActions => 'الإجراءات';

  @override
  String get staffActionWarn => 'تنبيه المضيف';

  @override
  String get staffActionEnd => 'إنهاء البث';

  @override
  String get staffActionNoLive => 'منع من البث';

  @override
  String get staffActionSuspend => 'تعليق الحساب';

  @override
  String get staffActionDismiss => 'تمت المراجعة — لا مخالفة';

  @override
  String get staffActionKick => 'إخراج من البث';

  @override
  String get staffActionMute => 'كتم في الدردشة';

  @override
  String get staffActionRemoveMessage => 'حذف الرسالة';

  @override
  String get staffPersonActions => 'إجراء على شخص';

  @override
  String get staffPersonField => 'اسم المستخدم';

  @override
  String get staffReason => 'السبب (يُسجَّل)';

  @override
  String get staffReasonHostHint =>
      'يصل السبب إلى المضيف من «فريق Kabso» دون اسمك.';

  @override
  String get staffDuration => 'المدة';

  @override
  String get staffDuration1h => 'ساعة';

  @override
  String get staffDuration24h => '24 ساعة';

  @override
  String get staffDuration3d => '3 أيام';

  @override
  String get staffDuration7d => '7 أيام';

  @override
  String get staffDuration30d => '30 يوماً';

  @override
  String get staffApply => 'تنفيذ';

  @override
  String get staffDone => 'تم';

  @override
  String get staffReadOnly => 'دورك: الاطلاع على البلاغات فقط';

  @override
  String get staffNoEconomy => 'فريق كابسو لا يرسل هدايا ولا ينقر في البث';

  @override
  String notifLiveStaffReport(String host) {
    return 'بلاغ جديد على بث $host';
  }

  @override
  String get errorStaffProtected => 'لا يمكن اتخاذ إجراء ضد فريق كابسو';

  @override
  String get errorLiveStaffRefused => 'فريق كابسو لا يفعل هذا في البث';

  @override
  String get errorStaffStepUpRequired =>
      'أدخل رمز المصادقة لاستخدام أدوات الفريق';

  @override
  String get errorStaffTotpNotEnrolled =>
      'فعّل تطبيق المصادقة من لوحة الإدارة أولاً';

  @override
  String get errorAdminTotpInvalid => 'رمز المصادقة غير صحيح';

  @override
  String get errorAdminLocked => 'محاولات خاطئة كثيرة. حاول لاحقاً';

  @override
  String get errorAdminActionRefused => 'رُفض الإجراء';

  @override
  String get profileLiveNowTitle => 'في بث الآن';

  @override
  String get profileLiveNowSelfTitle => 'أنت في بث الآن';

  @override
  String profileLiveFor(String duration) {
    return 'مباشر منذ $duration';
  }

  @override
  String profileLiveHoursMinutes(int hours, int minutes) {
    return '$hoursس $minutesد';
  }

  @override
  String profileLiveMinutes(int minutes) {
    return '$minutesد';
  }

  @override
  String profileLiveCardSemantics(
    String title,
    String duration,
    String details,
  ) {
    return '$title، $duration، $details';
  }

  @override
  String profileTagsMore(int count) {
    return '$count منشنات أخرى';
  }

  @override
  String get profileEditTags => 'المنشنات';

  @override
  String profileEditTagsValue(int count) {
    return '$count من 10';
  }

  @override
  String get profileEditTagsHint =>
      'حتى 10 منشنات قصيرة تظهر على غلاف ملفك، حتى 24 حرفاً لكل منها.';

  @override
  String get profileEditTagField => 'منشن جديد';

  @override
  String get profileEditTagAdd => 'إضافة';

  @override
  String profileEditTagRemove(String tag) {
    return 'حذف $tag';
  }

  @override
  String profileEditTagTooLong(int max) {
    return '$max حرفاً على الأكثر.';
  }

  @override
  String get profileEditTagDuplicate => 'هذا المنشن مضاف بالفعل.';

  @override
  String get profileEditTagInvalid => 'يحتوي على رموز غير مسموح بها.';

  @override
  String get profileEditTagsFull => 'وصلت إلى 10 منشنات.';

  @override
  String get profileTagIconDefault => 'بدون أيقونة';

  @override
  String get profileTagIconCrown => 'تاج';

  @override
  String get profileTagIconFlag => 'علم دولة';

  @override
  String get profileTagIconFire => 'نار';

  @override
  String get profileTagIconTrophy => 'كأس';

  @override
  String get profileTagIconGamepad => 'ألعاب';

  @override
  String get profileTagIconMusic => 'موسيقى';

  @override
  String get profileTagIconMic => 'ميكروفون';

  @override
  String get profileTagIconMoon => 'هلال';

  @override
  String get profileTagIconHeart => 'قلب';

  @override
  String get profileTagIconStar => 'نجمة';

  @override
  String get profileTagIconGem => 'جوهرة';

  @override
  String get profileTagIconCamera => 'كاميرا';

  @override
  String get profileTagIconBook => 'كتاب';

  @override
  String get profileTagIconSport => 'رياضة';

  @override
  String get profileTagIconPalette => 'فن';

  @override
  String get profileTagIconGlobe => 'العالم';

  @override
  String profileTagIconFlagOf(String country) {
    return 'علم $country';
  }

  @override
  String get profileTagIconPick => 'أيقونة الوسم';

  @override
  String profileTagIconChange(String tag) {
    return 'تغيير أيقونة $tag';
  }

  @override
  String profileTagIconNew(String icon) {
    return 'أيقونة الوسم الجديد: $icon';
  }

  @override
  String get profileEditTagsIconHint => 'اضغط على أي منشن لاختيار أيقونته.';

  @override
  String get liveTargetLevelEasy => 'سهل';

  @override
  String get liveTargetLevelMedium => 'متوسط';

  @override
  String get liveTargetLevelHard => 'صعب';

  @override
  String liveTargetRewardLocked(String amount) {
    return '+$amount كرز مقفل';
  }

  @override
  String liveTargetRewardPaid(String amount) {
    return 'تم · +$amount كرز مقفل';
  }

  @override
  String get liveTargetRewardHint =>
      'المكافأة نسبة من ربح المنصة الفعلي، تُصرف كرزاً مقفلاً مثل المهام عند إكمال الهدف.';

  @override
  String liveTargetDailySemantics(
    String level,
    String title,
    String progress,
    String amount,
    String reward,
  ) {
    return '$level: $title، $progress من $amount، المكافأة $reward كرز';
  }

  @override
  String tasksWindowLabel(String from, String to) {
    return 'بين $from و$to';
  }

  @override
  String get cherryReasonHostTarget => 'مكافأة هدف يومي';

  @override
  String get staffRegionArabWorld => 'الوطن العربي';

  @override
  String get staffRegionGreaterChina => 'الصين الكبرى';

  @override
  String get staffRegionTurkey => 'تركيا';

  @override
  String get staffRegionIran => 'إيران';

  @override
  String get staffRegionSouthAsia => 'جنوب آسيا';

  @override
  String get staffRegionSoutheastAsia => 'جنوب شرق آسيا';

  @override
  String get staffRegionEastAsia => 'شرق آسيا';

  @override
  String get staffRegionEurope => 'أوروبا';

  @override
  String get staffRegionNorthAmerica => 'أمريكا الشمالية';

  @override
  String get staffRegionLatinAmerica => 'أمريكا اللاتينية';

  @override
  String get staffRegionSubSaharanAfrica => 'أفريقيا جنوب الصحراء';

  @override
  String get staffRegionRussiaCentralAsia => 'روسيا وآسيا الوسطى';

  @override
  String get staffRegionOceania => 'أوقيانوسيا';

  @override
  String staffRegionsTwo(String first, String second) {
    return '$first و$second';
  }

  @override
  String staffRegionsMore(String first, String second) {
    return '$first و$second وأكثر';
  }

  @override
  String staffLineModeration(String regions) {
    return 'مشرف — $regions';
  }

  @override
  String staffLineSupport(String regions) {
    return 'دعم — $regions';
  }

  @override
  String get staffLineFinance => 'المالية';

  @override
  String get postAnnouncementLabel => 'إعلان رسمي — فريق كابسو';

  @override
  String get postComposerAnnouncementOnly =>
      'حسابات فريق كابسو تنشر إعلانات رسمية فقط.';

  @override
  String get meStaffAnnouncement => 'نشر إعلان';

  @override
  String get meStaffAnnouncementReel => 'نشر ريلز إعلان';

  @override
  String get staffFeatureUnavailable => 'غير متاح لحسابات فريق كابسو.';

  @override
  String get staffPictureLocked => 'صورة فريق كابسو ثابتة ولا يمكن تغييرها.';

  @override
  String get staffCoverLocked => 'غلاف فريق كابسو ثابت ولا يمكن تغييره.';

  @override
  String get staffOfficialBioTitle => 'الحساب الرسمي';

  @override
  String get staffOfficialBio =>
      'الحساب الرسمي لفريق إدارة Kabso Live. نعمل على مدار الساعة لتبقى تجربتك آمنة وممتعة للجميع. للدعم أو للإبلاغ عن أي مخالفة، راسلنا مباشرة.';

  @override
  String get staffBioLocked => 'نبذة رسمية ثابتة لا يمكن تعديلها';

  @override
  String get staffFrameLocked => 'إطار فريق كابسو مثبّت ولا يمكن تغييره.';

  @override
  String get staffTeamPicture => 'صورة فريق كابسو';

  @override
  String profileStaffId(String id) {
    return 'ID: $id';
  }

  @override
  String get profileStaffIdHint => 'رقم موظف رسمي في فريق كابسو';

  @override
  String get staffRoleBd => 'تطوير الأعمال';

  @override
  String staffLineBd(String regions) {
    return 'تطوير الأعمال — $regions';
  }

  @override
  String get recruiterFieldLabel => 'إن كنت تابعاً لمشرف، ضع معرّفه هنا';

  @override
  String get recruiterFieldHint =>
      'اختياري — ID الموظف مثل Kabso01 أو اسم المستخدم';

  @override
  String get recruiterChecking => 'جارٍ التحقق…';

  @override
  String get recruiterNotFound => 'غير موجود';

  @override
  String get recruiterFixError => 'صحّح معرّف المشرف أو اتركه فارغاً';

  @override
  String recruiterFoundSemantics(String name) {
    return 'المستقطِب: $name';
  }

  @override
  String get staffMyRecruits => 'استقطاباتي';

  @override
  String get staffMyEarnings => 'أرباحي';

  @override
  String get staffRecruitsIntro =>
      'من سجّلوا عن طريقك. تحصل تلقائياً على نسبة من ربح المنصة من كل واحد منهم، تُحسب يومياً.';

  @override
  String get staffRecruitsEmpty =>
      'لا يوجد مستقطَبون بعد. شارك معرّفك ليكتبه المتقدمون في طلباتهم.';

  @override
  String get recruitTypeAll => 'الكل';

  @override
  String get recruitTypeHost => 'مضيف';

  @override
  String get recruitTypeAgency => 'وكالة';

  @override
  String get recruitTypeRechargeAgent => 'وكيل شحن';

  @override
  String get recruitTypeCreator => 'صانع محتوى';

  @override
  String get recruitStatusActive => 'نشط';

  @override
  String get recruitStatusInactive => 'غير نشط';

  @override
  String recruitSince(String date) {
    return 'منذ $date';
  }

  @override
  String recruitCherries(String cherries) {
    return '$cherries كرز';
  }

  @override
  String get staffEarningsBalance => 'رصيد الكرز';

  @override
  String staffEarningsWithdrawable(String cherries, String amount) {
    return 'قابل للسحب: $cherries ≈ $amount';
  }

  @override
  String get staffEarningsTotal => 'مجموع العمولات';

  @override
  String get staffEarnings30 => 'آخر 30 يوماً';

  @override
  String get staffEarningsWithdraw => 'سحب الأرباح';

  @override
  String get staffEarningsPending => 'طلب سحب قيد الدفع';

  @override
  String get staffEarningsByRecruit => 'حسب المستقطَب';

  @override
  String get staffEarningsHistory => 'السجل اليومي';

  @override
  String get staffEarningsEmpty =>
      'لا عمولات بعد — تُحسب كل يوم من ربح المنصة الفعلي.';

  @override
  String staffEarningsShares(
    String host,
    String creator,
    String agency,
    String recharge,
  ) {
    return 'نسبتك: $host مضيفون · $creator صناع محتوى · $agency وكالات · $recharge وكلاء شحن';
  }

  @override
  String staffEarningsDayLine(String profit, String pct) {
    return 'ربح المنصة $profit × $pct';
  }

  @override
  String get creatorProgrammeEntry => 'برنامج صناع المحتوى';

  @override
  String get creatorProgrammeTitle => 'انضم كصانع محتوى';

  @override
  String get creatorProgrammeIntro =>
      'قدّم طلبك ليراجعه فريق كابسو. بعد الموافقة تصبح صانع محتوى في Kabso Live.';

  @override
  String get creatorProgrammeCountry => 'الدولة';

  @override
  String get creatorProgrammeCategory => 'نوع المحتوى';

  @override
  String get creatorProgrammeLinks => 'روابط أعمالك (1 إلى 5)';

  @override
  String get creatorProgrammeLinkError => 'رابط يبدأ بـ https://';

  @override
  String get creatorProgrammeAddLink => 'إضافة رابط';

  @override
  String get creatorProgrammeBio => 'نبذة (اختياري)';

  @override
  String get creatorProgrammeSubmit => 'إرسال الطلب';

  @override
  String get creatorProgrammeSent => 'تم إرسال طلبك';

  @override
  String get creatorProgrammePending => 'طلبك قيد المراجعة';

  @override
  String get creatorProgrammeMember => 'أنت صانع محتوى في Kabso Live';

  @override
  String creatorProgrammeRejected(String reason) {
    return 'رُفض طلبك: $reason';
  }

  @override
  String get creatorProgrammeCancel => 'سحب الطلب';

  @override
  String get creatorProgrammeStaff =>
      'حسابات فريق كابسو لا تتقدم لبرنامج صناع المحتوى.';

  @override
  String get creatorCatVideo => 'فيديو';

  @override
  String get creatorCatPhoto => 'صور';

  @override
  String get creatorCatMusic => 'موسيقى';

  @override
  String get creatorCatGaming => 'ألعاب';

  @override
  String get creatorCatComedy => 'كوميديا';

  @override
  String get creatorCatEducation => 'تعليم';

  @override
  String get creatorCatLifestyle => 'أسلوب حياة';

  @override
  String get creatorCatOther => 'أخرى';

  @override
  String get rechargeCherryBuyForAgentTitle => 'شراء كرز للوكيل';

  @override
  String rechargeWorksFor(String name) {
    return 'يعمل لصالح $name';
  }

  @override
  String rechargeCherryForAgentNote(String name) {
    return 'تشتري لحساب $name: العملات تُضاف إلى مخزون الوكيل والدفع للمضيف من الوكيل.';
  }

  @override
  String get rechargeBlockOffShift => 'خارج ساعات عملك: يمكنك الاطلاع فقط.';

  @override
  String get rechargeBlockNotPermitted => 'لم يسمح لك الوكيل بهذا.';

  @override
  String get rechargeOrderClaimedByOther => 'تم استلامه بواسطة موظف آخر';

  @override
  String get rechargeOrderClaimedByAgent => 'يتولاه الوكيل';

  @override
  String rechargeOrderClaimedBy(String name) {
    return 'يتولاه $name';
  }

  @override
  String get rechargeOrderClaimedByYou => 'أنت تتولى هذا الطلب';

  @override
  String rechargeActedBy(String name) {
    return 'بواسطة $name';
  }

  @override
  String get rechargePermBuyCherries => 'يمكنه شراء الكرز';

  @override
  String get rechargePermBuyCherriesHint =>
      'يشتري كرز المضيفين لحسابك أثناء دوامه';

  @override
  String get rechargePermReceivesOrders => 'يستقبل طلبات الشراء';

  @override
  String get rechargePermReceivesOrdersHint =>
      'تصله طلبات المشترين ويتولاها أثناء دوامه';

  @override
  String rechargeEmployeeActsToday(int cherries, int orders) {
    return 'اليوم: $cherries شراء كرز · $orders طلب منجز';
  }

  @override
  String get errorRechargeEmployeeNotPermitted =>
      'لم يسمح لك الوكيل بهذا الإجراء.';

  @override
  String get errorRechargeOrderClaimed =>
      'تم استلام هذا الطلب بواسطة موظف آخر.';

  @override
  String rechargeOrdersForAgentHint(String name) {
    return 'طلبات المشترين لـ $name، أول من يتولى الطلب يملكه';
  }

  @override
  String get rechargeBlockStaff =>
      'أنت الآن ضمن فريق كابسو: لا يمكنك العمل كموظف شحن، يمكنك الاطلاع فقط.';

  @override
  String get rechargeEmployeeIsStaffNote =>
      'ضمن فريق كابسو الآن: لا يمكنه العمل لصالحك. يمكنك إزالته.';

  @override
  String get errorRechargeEmployeeIsStaff =>
      'هذا الحساب من فريق كابسو، ولا يمكن إضافته موظفاً للشحن.';

  @override
  String get errorStaffAccountLimited =>
      'حسابات فريق كابسو لا يمكنها القيام بهذا.';

  @override
  String get staffSharedReports => 'بلاغات';

  @override
  String get staffSharedReportsTitle => 'البلاغات';

  @override
  String staffSharedReportsBadge(int count) {
    return '$count بلاغ غير محلول';
  }

  @override
  String get staffSharedReportsHint =>
      'البلاغات مشتركة بين المشرفين والدعم: من يحل البلاغ يضغط «تم حله».';

  @override
  String get staffSharedTabOpen => 'غير محلولة';

  @override
  String get staffSharedTabResolved => 'تم حلها';

  @override
  String get staffSharedEmptyOpen => 'لا بلاغات بانتظار الحل';

  @override
  String get staffSharedEmptyResolved => 'لا بلاغات محلولة بعد';

  @override
  String get staffSharedResolve => 'تم حله';

  @override
  String get staffSharedResolveTitle => 'تم حل البلاغ';

  @override
  String get staffSharedResolveIntro =>
      'يصبح البلاغ محلولاً لكل فريق الإشراف والدعم، ويظهر اسمك ووقت الحل.';

  @override
  String get staffSharedResolveNote => 'ملاحظة (اختيارية)';

  @override
  String staffSharedResolvedBy(String name, String when) {
    return 'حلّه $name · $when';
  }

  @override
  String staffSharedResolvedAt(String when) {
    return 'تم الحل · $when';
  }

  @override
  String staffSharedResolutionNote(String note) {
    return 'ملاحظة الحل: $note';
  }

  @override
  String get staffSharedAlreadyResolved => 'تم حله بالفعل من عضو آخر في الفريق';

  @override
  String get staffSharedDone => 'تم حل البلاغ';

  @override
  String staffSharedReportedBy(String name) {
    return 'أبلغ: $name';
  }

  @override
  String staffSharedAuthor(String name) {
    return 'صاحب المحتوى: $name';
  }

  @override
  String staffSharedReporterNote(String note) {
    return 'ملاحظة المبلّغ: $note';
  }

  @override
  String get staffSharedGone => 'المحتوى محذوف أو مخفي';

  @override
  String get staffSharedOutcomeDismissed => 'مرفوض';

  @override
  String get staffReportTypePost => 'منشور';

  @override
  String get staffReportTypeComment => 'تعليق';

  @override
  String get staffReportTypeStory => 'قصة';

  @override
  String get staffReportTypeUser => 'حساب';

  @override
  String get staffReportTypeLive => 'بث';

  @override
  String get staffReportTypeLiveChat => 'رسالة في بث';

  @override
  String get staffReportTypeConfession => 'اعتراف CP';

  @override
  String get staffReportTypeFamilyChat => 'رسالة عائلة';

  @override
  String get staffReportTypeDm => 'رسالة خاصة';

  @override
  String get staffReportTypeLink => 'رابط في الملف';

  @override
  String get notifStaffReportNew => 'بلاغ جديد بانتظار الحل';

  @override
  String get itemBadgeLimited => 'لفترة محدودة';

  @override
  String get itemBadgeNew => 'جديد';

  @override
  String get itemBadgeSeasonal => 'موسمي';

  @override
  String get itemBadgeExclusive => 'حصري';

  @override
  String get itemBadgeMostWanted => 'الأكثر طلباً';

  @override
  String get itemBadgeFeatured => 'مميز';

  @override
  String get itemBadgeFullscreen => 'شاشة كاملة';

  @override
  String get itemBadgeSound => 'بمؤثرات صوتية';

  @override
  String get itemBadgeNoSound => 'بدون مؤثرات صوتية';

  @override
  String itemBadgeDaysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'باقٍ $n يوم',
      many: 'باقٍ $n يوماً',
      few: 'باقٍ $n أيام',
      two: 'باقٍ يومان',
      one: 'باقٍ يوم',
    );
    return '$_temp0';
  }

  @override
  String get itemBadgeEndsToday => 'ينتهي اليوم';

  @override
  String get itemBadgesTitle => 'الشارات';

  @override
  String get giftDetailsHint => 'اضغط مطولاً لعرض التفاصيل';

  @override
  String get giftDetailsLucky => 'هدية حظ';

  @override
  String get lrTitle => 'طلبات رفع الليفيل';

  @override
  String get lrMeRow => 'طلب رفع ليفيل';

  @override
  String get lrIntro =>
      'داعم جديد من تطبيق آخر؟ أرسل طلباً للإدارة مع فيديو لحسابه هناك، وتقترح الإدارة ليفيل الدعم المناسب.';

  @override
  String get lrNew => 'طلب جديد';

  @override
  String get lrEmpty => 'لم ترسل أي طلب بعد.';

  @override
  String get lrStatusPending => 'قيد المراجعة';

  @override
  String get lrStatusApproved => 'تمت الموافقة';

  @override
  String get lrStatusRejected => 'مرفوض';

  @override
  String lrApprovedLevel(String level) {
    return 'رُفع إلى المستوى $level';
  }

  @override
  String lrRejectReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String lrSourceLine(String app, String level, String id) {
    return '$app · المستوى $level · ID $id';
  }

  @override
  String get lrFormTitle => 'طلب رفع ليفيل';

  @override
  String get lrUsername => 'اسم المستخدم في Kabso';

  @override
  String get lrCheck => 'تحقّق';

  @override
  String get lrNotFound => 'لا يوجد حساب بهذا الاسم';

  @override
  String get lrStaffAccount => 'حساب في فريق كابسو: لا ليفيلات له';

  @override
  String get lrOpenExists => 'لدى هذا الداعم طلب قيد المراجعة';

  @override
  String lrTotalRecharge(String coins) {
    return 'إجمالي الشحن: $coins';
  }

  @override
  String lrFirstDaysRecharge(String days, String coins) {
    return 'شحن أول $days أيام: $coins';
  }

  @override
  String lrLevels(String support, String charm) {
    return 'ليفيل الدعم $support · الجاذبية $charm';
  }

  @override
  String lrNotEligible(String min) {
    return 'يمكنك الإرسال الآن، لكن لا تتم الموافقة قبل شحن $min عملة';
  }

  @override
  String get lrEligible => 'الشحن كافٍ للموافقة';

  @override
  String get lrSourceApp => 'التطبيق';

  @override
  String get lrConfirmed => 'مؤكد';

  @override
  String get lrEstimate => 'تقدير';

  @override
  String get lrOtherName => 'اسم التطبيق';

  @override
  String get lrAccountId => 'الآيدي في التطبيق';

  @override
  String get lrSourceLevel => 'المستوى في التطبيق';

  @override
  String get lrVideo => 'فيديو الحساب';

  @override
  String get lrVideoHint =>
      'سجّل فيديو لصفحة الحساب في التطبيق يظهر فيه المستوى والآيدي (حتى 90 ثانية).';

  @override
  String get lrVideoPick => 'اختر الفيديو';

  @override
  String lrVideoChosen(String seconds) {
    return 'فيديو $seconds ث';
  }

  @override
  String lrVideoUploading(String percent) {
    return 'جارٍ الرفع… $percent%';
  }

  @override
  String get lrNote => 'ملاحظة (اختياري)';

  @override
  String get lrSend => 'إرسال الطلب';

  @override
  String get lrSent => 'أُرسل الطلب إلى الإدارة';

  @override
  String get lrRequired => 'مطلوب';

  @override
  String get lrLevelRange => 'من 1 إلى 999';

  @override
  String notifLevelRaiseApproved(String user, String level) {
    return 'تمت الموافقة على طلب رفع ليفيل $user إلى المستوى $level';
  }

  @override
  String notifLevelRaiseRejected(String user) {
    return 'لم تتم الموافقة على طلب رفع ليفيل $user';
  }

  @override
  String notifLevelRaised(String level) {
    return 'تم رفع ليفيل الدعم الخاص بك إلى المستوى $level';
  }

  @override
  String lrDidYouMean(String name) {
    return 'هل تقصد: $name؟';
  }

  @override
  String lrDuplicate(String status, String date, String name) {
    return 'يوجد طلب لنفس الحساب في نفس التطبيق ($status) منذ $date، أرسله $name';
  }

  @override
  String get lrDuplicateShort => 'يوجد طلب لنفس الحساب في نفس التطبيق';

  @override
  String get lrPreviouslyRejected => 'سبق رفض طلب بنفس الحساب';

  @override
  String get medalsStageTitle => 'الميداليات التي أرتديها';

  @override
  String get medalsNotWorn => 'غير مرتدية';

  @override
  String get medalsNoneWorn => 'لا ترتدي أي ميدالية';

  @override
  String medalsWornCount(int count, int max) {
    return 'ترتدي $count من $max';
  }

  @override
  String get medalsTabAchievements => 'الإنجازات';

  @override
  String get medalsTabActivity => 'النشاط';

  @override
  String get medalsTabEmpty => 'لا توجد ميداليات في هذا التبويب';

  @override
  String get medalsNotObtained => 'لم تُحصَّل';

  @override
  String medalsLevel(int level) {
    return 'المستوى $level';
  }

  @override
  String get medalsWorn => 'مرتدية';

  @override
  String get medalsTopLevel => 'أعلى مستوى';

  @override
  String medalsProgress(String value, String next) {
    return '$value / $next';
  }

  @override
  String get medalsLevelsTitle => 'المستويات';

  @override
  String get medalsWear => 'ارتداء';

  @override
  String get medalsTakeOff => 'خلع';

  @override
  String get medalsWearSaved => 'تم تحديث ميدالياتك المرتدية';

  @override
  String medalsThresholdLives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بث',
      many: '$count بثاً',
      few: '$count بثوث',
      two: 'بثّان',
      one: 'بث واحد',
    );
    return '$_temp0';
  }

  @override
  String medalsThresholdHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة بث',
      many: '$count ساعة بث',
      few: '$count ساعات بث',
      two: 'ساعتا بث',
      one: 'ساعة بث واحدة',
    );
    return '$_temp0';
  }

  @override
  String medalsThresholdCharm(int count) {
    return 'مستوى الجاذبية $count';
  }

  @override
  String medalsThresholdBullets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة عامة',
      many: '$count رسالة عامة',
      few: '$count رسائل عامة',
      two: 'رسالتان عامتان',
      one: 'رسالة عامة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get medalsThresholdOnce => 'مرة واحدة';

  @override
  String medalsLevelReachedLabel(String level) {
    return '$level، تم بلوغه';
  }

  @override
  String medalsCardLabel(String name, String status) {
    return '$name، $status';
  }

  @override
  String notifMedalLevelUp(String name, int level) {
    return 'ارتقت ميداليتك $name إلى المستوى $level';
  }

  @override
  String notifMedalLevelUpUnnamed(int level) {
    return 'ارتقت ميداليتك إلى المستوى $level';
  }

  @override
  String medalsProfileWornCount(int count, int max) {
    return 'على ملفك: $count من $max';
  }

  @override
  String medalsThresholdGiftCoins(String amount) {
    return '$amount كوينز من الهدايا';
  }

  @override
  String medalsThresholdLuckyCoins(String amount) {
    return '$amount كوينز من هدايا الحظ';
  }

  @override
  String get staffReportViewTitle => 'البلاغ';

  @override
  String get staffReportBanner => 'محتوى مُبلّغ عنه';

  @override
  String get staffReportBannerHint =>
      'تراه كفريق كابسو مهما كانت حالته — لا يظهر للآخرين إلا إذا كان ظاهراً.';

  @override
  String get staffReportStateVisible => 'ظاهر';

  @override
  String get staffReportStateHidden => 'مخفي بالإشراف';

  @override
  String get staffReportStateDeleted => 'محذوف';

  @override
  String get staffReportStateExpired => 'منتهي';

  @override
  String get staffReportStateLive => 'على الهواء';

  @override
  String get staffReportStateEnded => 'انتهى البث';

  @override
  String get staffReportStateGone => 'غير موجود';

  @override
  String get staffReportContentDeleted => 'المحتوى محذوف';

  @override
  String get staffReportSnapshotShown => 'يُعرض ما حفظه البلاغ وقت الإبلاغ.';

  @override
  String get staffReportReelMark => 'ريلز';

  @override
  String get staffReportVideoMark => 'فيديو';

  @override
  String get staffReportOnPost => 'التعليق على هذا المنشور';

  @override
  String get staffReportReportedComment => 'التعليق المُبلّغ عنه';

  @override
  String get staffReportOpenProfile => 'فتح الملف الشخصي';

  @override
  String get staffReportEnterLive => 'دخول البث كفريق كابسو';

  @override
  String get staffReportLiveEnded => 'البث منتهٍ — هذا ملخصه.';

  @override
  String get staffReportDmTitle => 'محادثة — للقراءة فقط';

  @override
  String staffReportDmBetween(String sender, String recipient) {
    return 'من $sender إلى $recipient';
  }

  @override
  String get staffReportDmPrivacy =>
      'لقطة محفوظة من البلاغ: الرسالة المُبلّغ عنها فقط، لا باقي المحادثة. كل فتح يُسجَّل.';

  @override
  String get staffReportDmExpired =>
      'انتهت الرسالة الأصلية بعد ٢٤ ساعة؛ اللقطة باقية.';

  @override
  String get staffReportDmPurged => 'مُسح محتوى اللقطة بعد انتهاء مدة الحفظ.';

  @override
  String get staffReportDmImage => 'صورة';

  @override
  String get staffReportDmVoice => 'رسالة صوتية';

  @override
  String staffReportDmGift(String code, String quantity) {
    return 'هدية $code ×$quantity';
  }

  @override
  String get staffReportActionsTitle => 'إجراءات';

  @override
  String get staffReportActionWarn => 'تحذير';

  @override
  String get staffReportActionRestrict => 'تقييد';

  @override
  String get staffReportActionSuspend => 'تعليق مؤقت';

  @override
  String get staffReportActionBan => 'حظر دائم';

  @override
  String get staffReportActionRemove => 'إخفاء المحتوى';

  @override
  String get staffReportActionEndLive => 'إنهاء البث';

  @override
  String get staffReportRestrictNoPosting => 'منع النشر';

  @override
  String get staffReportRestrictNoLive => 'منع البث';

  @override
  String get staffReportRestrictChat => 'منع الرسائل';

  @override
  String staffReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get staffReportDuration => 'المدة';

  @override
  String get staffReportReason => 'السبب (يُحفظ في السجل)';

  @override
  String get staffReportReasonRequired => 'اكتب السبب';

  @override
  String get staffReportAutoResolve => 'يُحلّ البلاغ تلقائياً بعد الإجراء.';

  @override
  String staffReportConfirmWarn(String name) {
    return 'تحذير $name؟';
  }

  @override
  String staffReportConfirmRestrict(String name) {
    return 'تقييد $name؟';
  }

  @override
  String staffReportConfirmSuspend(String name) {
    return 'تعليق حساب $name مؤقتاً؟';
  }

  @override
  String staffReportConfirmBan(String name) {
    return 'حظر $name نهائياً؟';
  }

  @override
  String get staffReportConfirmRemove => 'إخفاء هذا المحتوى عن الجميع؟';

  @override
  String get staffReportConfirmBanHint =>
      'يُعلَّق الحساب ولا يستطيع الدخول. يمكن للإدارة رفعه من اللوحة.';

  @override
  String get staffReportConfirmSuspendHint =>
      'لا يستطيع الدخول حتى تنتهي المدة.';

  @override
  String get staffReportApply => 'تنفيذ';

  @override
  String get staffReportActionDone => 'تم الإجراء وحُلّ البلاغ';

  @override
  String staffReportResolvedByAction(String action) {
    return 'حُلّ بإجراء: $action';
  }

  @override
  String get staffReportNoActions => 'لا إجراءات متاحة لدورك على هذا البلاغ.';

  @override
  String get staffReportOpen => 'فتح';

  @override
  String get staffReportThreadTitle => 'المحادثة كاملة — للقراءة فقط';

  @override
  String get staffReportThreadPrivacy =>
      'نسخة محفوظة عند الإبلاغ: كل رسائل المحادثة التي كانت موجودة حينها، ولا تُضاف رسائل لاحقة. كل فتح يُسجَّل.';

  @override
  String staffReportThreadCaptured(String when) {
    return 'حُفظت $when';
  }

  @override
  String staffReportThreadTruncated(String count) {
    return 'حُفظت آخر $count رسالة فقط.';
  }

  @override
  String get staffReportThreadReported => 'الرسالة المُبلّغ عنها';

  @override
  String get staffReportThreadMediaMissing => 'ملف لم يُحفظ';

  @override
  String get staffReportThreadEmpty => 'لم تكن في المحادثة رسائل عند الإبلاغ.';

  @override
  String get staffReportActionDeleteContent => 'حذف نهائي';

  @override
  String get staffReportActionDeleteAccount => 'حذف الحساب';

  @override
  String get staffReportConfirmDeleteContent => 'حذف هذا المحتوى نهائياً؟';

  @override
  String staffReportConfirmDeleteAccount(String name) {
    return 'حذف حساب $name؟';
  }

  @override
  String get staffReportConfirmDeleteContentHint =>
      'لا يمكن التراجع عن الحذف النهائي، ويُبلَّغ صاحب المحتوى.';

  @override
  String get staffReportConfirmDeleteAccountHint =>
      'يبدأ حذف الحساب بمهلته (يمكن إلغاؤه من اللوحة خلالها)، ويُسجَّل خروجه من كل الأجهزة.';

  @override
  String get staffReportConfirmWord => 'حذف';

  @override
  String staffReportTypeToConfirm(String word) {
    return 'اكتب «$word» للتأكيد';
  }

  @override
  String get staffReportConfirmMismatch => 'اكتب الكلمة كما هي';

  @override
  String get staffReportThreadOpen => 'اضغط لفتح المحادثة';

  @override
  String staffReportThreadCount(String count) {
    return 'الرسائل المحفوظة: $count';
  }

  @override
  String get staffReportThreadOnlyReported =>
      'بلاغ قديم: الرسالة المُبلّغ عنها فقط';

  @override
  String get liveCreatorBadge => 'صانع محتوى';

  @override
  String get hostApplyRefusedCreator =>
      'أنت صانع محتوى: تبث من برنامج صناع المحتوى، ولا يمكن أن تكون مضيفاً أيضاً';

  @override
  String get creatorProgrammeHost =>
      'أنت مضيف: لا يمكن أن تكون صانع محتوى أيضاً.';

  @override
  String get agencyOpenBanned => 'حُظرت وكالتك ولا يمكن فتحها من جديد';

  @override
  String get agencyClosedBanned => 'حُظرت الوكالة لتفعيل صانع محتوى وهمي';

  @override
  String get errorAgencyActivationNotAllowed =>
      'لا يمكن تفعيل هذا العضو بهذه الطريقة';

  @override
  String get agencyActivate => 'تفعيل';

  @override
  String agencyActivateTitle(String name) {
    return 'تفعيل $name';
  }

  @override
  String get agencyActivateIntro => 'اختر كيف يبث هذا العضو:';

  @override
  String get agencyActivateAsHost => 'مضيف';

  @override
  String get agencyActivateAsHostBody =>
      'يبث ضمن وكالتك بنسبة المضيف المعتادة.';

  @override
  String get agencyActivateAsCreator => 'صانع محتوى';

  @override
  String get agencyActivateAsCreatorBody =>
      'لمن يصنع محتوى على منصات أخرى. تحتاج معلوماته وروابط أعماله.';

  @override
  String get agencyCreatorShareNote => 'نسبة صانع المحتوى 70%';

  @override
  String get agencyCreatorWarning =>
      'إن قمت بتفعيل شخص على أنه صانع محتوى ولم يكن كذلك، سيتم حظر الوكالة وخسارة أرباحك.';

  @override
  String get agencyCreatorConfirm =>
      'قرأت التحذير وأؤكد أن هذا الشخص صانع محتوى';

  @override
  String get agencyCreatorConfirmError => 'ضع علامة التأكيد للمتابعة';

  @override
  String get agencyActivateHostButton => 'تفعيل كمضيف';

  @override
  String get agencyActivateCreatorButton => 'تفعيل كصانع محتوى';

  @override
  String agencyActivatedHost(String name) {
    return 'أصبح $name مضيفاً';
  }

  @override
  String agencyActivatedCreator(String name) {
    return 'أصبح $name صانع محتوى';
  }

  @override
  String get agencyActivationRefusedHost =>
      'هذا العضو مضيف: لا يمكن تفعيله صانع محتوى';

  @override
  String get agencyActivationRefusedCreator =>
      'هذا العضو صانع محتوى: لا يمكن تفعيله مضيفاً';

  @override
  String get agencyActivationRefusedSuspended => 'وكالتك موقوفة من الفريق';

  @override
  String get verificationBadgeOwner => 'مالك التطبيق';

  @override
  String get verificationBadgeStaff => 'فريق كابسو';

  @override
  String get verificationBadgeRechargeAgent => 'وكيل شحن';

  @override
  String get verificationBadgeHostAgent => 'وكيل مضيفين';

  @override
  String get verificationBadgeCreator => 'صانع محتوى';

  @override
  String get verificationBadgeVerifiedHost => 'مضيف موثّق الهوية';

  @override
  String verificationBadgeLabel(String kind) {
    return 'موثّق: $kind';
  }

  @override
  String get verificationBadgeAbout => 'شارة تُمنح تلقائياً حسب الشروط';

  @override
  String get medalsReqFollowers => 'المتابعون';

  @override
  String get medalsReqLikes => 'الإعجابات';

  @override
  String get medalsReqViews => 'المشاهدات';

  @override
  String get medalsReqAllTogether => 'الشروط الثلاثة معاً للمستوى التالي';

  @override
  String get medalsCreatorsOnly => 'لصنّاع المحتوى فقط';

  @override
  String get medalsCreatorsOnlyBody =>
      'تُحسب المتابعات والإعجابات والمشاهدات لصنّاع المحتوى فقط. المستوى الذي وصلت إليه يبقى لك.';

  @override
  String medalsThresholdPkPoints(String points) {
    return '$points نقطة PK';
  }

  @override
  String get ownerFollow => 'متابعة المؤسس';

  @override
  String get ownerFollowing => 'تتابع المؤسس';

  @override
  String get ownerFeedbackButton => 'اقترح ميزة / أبلغ';

  @override
  String get founderBadgeLabel => 'مؤسس Kabso Live';

  @override
  String get founderSocialInstagram => 'إنستغرام';

  @override
  String get founderSocialFacebook => 'فيسبوك';

  @override
  String get founderSocialWhatsApp => 'واتساب';

  @override
  String get founderSocialSnapchat => 'سناب شات';

  @override
  String get founderFeedbackStat => 'الاقتراحات والشكاوى';

  @override
  String get ownerPrivate => 'خاص';

  @override
  String get ownerEdit => 'تعديل';

  @override
  String get ownerDelete => 'حذف';

  @override
  String get ownerSave => 'حفظ';

  @override
  String get ownerSeeAll => 'عرض الكل';

  @override
  String get ownerMoveUp => 'تحريك لأعلى';

  @override
  String get ownerMoveDown => 'تحريك لأسفل';

  @override
  String get ownerFieldRequired => 'مطلوب';

  @override
  String get ownerDashboardTitle => 'لوحة المؤسس';

  @override
  String get ownerDashboardOnline => 'مستخدم الآن';

  @override
  String ownerDashboardOnlineLong(int minutes) {
    return 'المستخدمون النشطون آخر $minutes دقائق';
  }

  @override
  String get ownerDashboardLives => 'بث الآن';

  @override
  String get ownerDashboardIncome => 'دخل اليوم';

  @override
  String get ownerDashboardIncomeHidden => 'مخفي، اضغط للإظهار';

  @override
  String get ownerDashboardIncomeWebsite => 'شحن الموقع (بطاقات)';

  @override
  String get ownerDashboardIncomeAgents => 'شحن الوكلاء';

  @override
  String ownerDashboardUpdated(String time) {
    return 'آخر تحديث $time · يُحدَّث كل دقيقة';
  }

  @override
  String get ownerDashboardFailed =>
      'تعذّر تحميل الأرقام — اضغط لإعادة المحاولة';

  @override
  String get ownerOfficialTitle => 'إعلانات رسمية';

  @override
  String get ownerOfficialLabel => 'رسمي';

  @override
  String get ownerOfficialMark => 'تعيين كإعلان رسمي';

  @override
  String get ownerOfficialUnmark => 'إزالة من الإعلانات الرسمية';

  @override
  String get ownerOfficialMarked => 'أصبح إعلاناً رسمياً في ملفك';

  @override
  String get ownerOfficialUnmarked => 'أُزيل من الإعلانات الرسمية';

  @override
  String get ownerOfficialEmptyOwn =>
      'لا إعلانات رسمية بعد. اختر «تعيين كإعلان رسمي» من قائمة أي منشور لك.';

  @override
  String get ownerOfficialUntitled => 'إعلان';

  @override
  String get ownerJourneyTitle => 'رحلة Kabso';

  @override
  String get ownerJourneySubtitle => 'قصة المؤسس والمنصة';

  @override
  String get ownerJourneyLatest => 'الأحدث';

  @override
  String get ownerJourneyAdd => 'إضافة محطة';

  @override
  String get ownerJourneyAddFirst => 'أضف أول محطة في رحلة Kabso';

  @override
  String get ownerJourneyEditOne => 'تعديل المحطة';

  @override
  String get ownerJourneyEditorTitle => 'تعديل رحلة Kabso';

  @override
  String ownerJourneyEditorHint(int max) {
    return 'اسحب للترتيب أو استخدم الأسهم · حتى $max محطة';
  }

  @override
  String get ownerJourneyEmptyOwn => 'لا محطات بعد — أضف الأولى.';

  @override
  String get ownerJourneyDeleteConfirm => 'حذف هذه المحطة؟';

  @override
  String get ownerMilestoneTitleAr => 'العنوان (بالعربية)';

  @override
  String get ownerMilestoneTitleEn => 'العنوان (بالإنجليزية)';

  @override
  String get ownerMilestoneLineAr => 'سطر قصير (بالعربية)';

  @override
  String get ownerMilestoneLineEn => 'سطر قصير (بالإنجليزية)';

  @override
  String get ownerMilestoneMonth => 'الشهر';

  @override
  String get ownerMilestoneYear => 'السنة';

  @override
  String get ownerMilestoneIcon => 'الأيقونة';

  @override
  String get ownerMilestoneLatestHint => 'تظهر عليها «الأحدث» (محطة واحدة فقط)';

  @override
  String get ownerCoverVideoTitle => 'فيديو الغلاف';

  @override
  String get ownerCoverVideoHint =>
      'فيديو قصير يتكرر بدل صورة الغلاف (حتى 60 ثانية). من لغة تطبيقه العربية يرى الفيديو العربي، والباقون الإنجليزي؛ إن وُجد واحد فقط يراه الجميع.';

  @override
  String get ownerCoverVideoArabic => 'الفيديو العربي';

  @override
  String get ownerCoverVideoEnglish => 'الفيديو الإنجليزي';

  @override
  String get ownerCoverVideoNone => 'لا يوجد';

  @override
  String ownerCoverVideoSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String ownerCoverVideoUploading(int percent) {
    return 'جارٍ الرفع… $percent%';
  }

  @override
  String get ownerCoverVideoChoose => 'اختيار فيديو';

  @override
  String get ownerCoverVideoReplace => 'استبدال';

  @override
  String get ownerCoverVideoRemove => 'إزالة الفيديو';

  @override
  String get ownerCoverVideoSaved => 'تم حفظ فيديو الغلاف';

  @override
  String get ownerCoverVideoRemoved => 'أُزيل فيديو الغلاف';

  @override
  String get ownerBioDefault =>
      'مؤسس Kabso Live. بنيتُ هذه المنصة لتجمعنا في البث والمحتوى ومجتمع واحد. اقتراحاتكم تصلني مباشرة، فشاركوني أفكاركم.';

  @override
  String get ownerBioTitle => 'بايو المؤسس';

  @override
  String get ownerBioHint =>
      'يظهر لكل زائر بلغة تطبيقه. اترك الحقل فارغاً ليظهر النص الافتراضي.';

  @override
  String get ownerBioArabic => 'بالعربية';

  @override
  String get ownerBioEnglish => 'بالإنجليزية';

  @override
  String get ownerBioSaved => 'تم حفظ البايو';

  @override
  String get ownerCoverVideoPlay => 'تشغيل فيديو الغلاف';

  @override
  String get ownerCoverVideoPause => 'إيقاف فيديو الغلاف مؤقتاً';

  @override
  String get ownerCoverVideoMute => 'كتم الصوت';

  @override
  String get ownerCoverVideoUnmute => 'تشغيل الصوت';

  @override
  String get ownerFeedbackTitle => 'اقترح ميزة أو أبلغ عن موظف';

  @override
  String get ownerFeedbackSubtitle => 'يصل مباشرة إلى صندوق المؤسس.';

  @override
  String get ownerFeedbackFeature => 'اقتراح ميزة';

  @override
  String get ownerFeedbackReport => 'الإبلاغ عن موظف';

  @override
  String get ownerFeedbackFeatureHint => 'ما الميزة التي تريدها؟';

  @override
  String get ownerFeedbackReportHint => 'ماذا حدث؟ اذكر التفاصيل';

  @override
  String get ownerFeedbackStaff => 'الموظف';

  @override
  String get ownerFeedbackStaffHint => '@اسم المستخدم أو آيدي الموظف';

  @override
  String get ownerFeedbackStaffNone => 'لا يوجد موظف بهذا الاسم';

  @override
  String get ownerFeedbackCategory => 'السبب';

  @override
  String get ownerFeedbackImage => 'إضافة صورة';

  @override
  String ownerFeedbackEvidence(int count) {
    return 'صور الإثبات (حتى $count)';
  }

  @override
  String get ownerFeedbackImageInvalid => 'هذه الصورة غير مدعومة أو كبيرة جداً';

  @override
  String get ownerFeedbackConfidential =>
      'بلاغك سري: لا يصل إلى الموظف ولا إلى المشرفين، تقرؤه الإدارة العليا فقط.';

  @override
  String get ownerFeedbackSend => 'إرسال';

  @override
  String get ownerFeedbackSent => 'وصل إلى صندوق المؤسس. شكراً لك.';

  @override
  String get ownerCategoryRudeness => 'إساءة أو تعامل سيئ';

  @override
  String get ownerCategoryAbuseOfPower => 'إساءة استخدام الصلاحيات';

  @override
  String get ownerCategoryUnfairAction => 'إجراء غير عادل';

  @override
  String get ownerCategoryNoResponse => 'تجاهل أو عدم الرد';

  @override
  String get ownerCategoryCorruption => 'رشوة أو فساد';

  @override
  String get ownerCategoryOther => 'سبب آخر';

  @override
  String get errorOwnerOnly => 'هذا متاح لصاحب البرنامج فقط.';

  @override
  String get errorOwnerJourneyLimit =>
      'وصلت رحلة Kabso إلى الحد الأقصى من المحطات.';

  @override
  String get notifOwnerFeedbackFeature => 'اقتراح ميزة جديد في صندوق المؤسس';

  @override
  String get notifOwnerFeedbackReport => 'بلاغ جديد عن موظف في صندوق المؤسس';

  @override
  String get ownerAnnouncementNew => 'إعلان رسمي جديد';

  @override
  String get ownerAnnouncementEdit => 'تعديل الإعلان';

  @override
  String get ownerAnnouncementTextAr => 'النص بالعربية';

  @override
  String get ownerAnnouncementTextEn => 'النص بالإنجليزية';

  @override
  String get ownerAnnouncementHint =>
      'من لغة تطبيقه العربية يرى النص العربي، والباقون الإنجليزي. يظهر أول منشور عند الجميع حتى تنشر إعلاناً أحدث، ويصلهم إشعار مرة واحدة.';

  @override
  String get ownerAnnouncementEditHint => 'التعديل لا يرسل إشعاراً جديداً.';

  @override
  String get ownerAnnouncementPhotos => 'صور (اختياري)';

  @override
  String get ownerAnnouncementPublish => 'نشر للجميع';

  @override
  String get ownerAnnouncementPublished =>
      'نُشر الإعلان، ويصل الإشعار للجميع خلال دقائق.';

  @override
  String get ownerAnnouncementSaved => 'حُفظ الإعلان دون إشعار جديد.';

  @override
  String get ownerDashboardIncomeNote =>
      'ما يدخل Kabso فقط: شحن المتجر بالبطاقات بعد الاسترداد، وما يدفعه الوكلاء لـ Kabso لشراء رصيدهم. لا يُحسب ما يبيعه الوكيل للمستخدمين.';

  @override
  String ownerDashboardIncomeOther(String currency) {
    return 'بعملة أخرى ($currency)';
  }

  @override
  String notifOwnerAnnouncement(String text) {
    return 'إعلان رسمي من المؤسس: $text';
  }

  @override
  String get ownerSearchRole => 'مؤسس Kabso Live';

  @override
  String get ownerSearchFollow => 'متابعة';

  @override
  String get ownerSearchFollowing => 'متابَع';

  @override
  String get ownerProfitTitle => 'الربح';

  @override
  String get ownerProfitToday => 'ربح اليوم';

  @override
  String get ownerProfitBeforeShort => 'قبل';

  @override
  String get ownerProfitAfterShort => 'بعد';

  @override
  String get ownerProfitBefore => 'الدخل قبل';

  @override
  String get ownerProfitAfter => 'الربح النهائي بعد';

  @override
  String get ownerProfitDay => 'اليوم';

  @override
  String get ownerProfitMonth => 'الشهر';

  @override
  String get ownerProfitPickDay => 'اختيار يوم';

  @override
  String get ownerProfitCardCharged => 'شحن المتجر بالبطاقات';

  @override
  String get ownerProfitRefunds => 'المبالغ المستردة';

  @override
  String get ownerProfitChargebacks => 'الاعتراضات البنكية';

  @override
  String get ownerProfitAgents => 'شراء الوكلاء من Kabso';

  @override
  String get ownerProfitDeductions => 'الخصومات';

  @override
  String get ownerProfitGifts => 'نصيب المضيفين وصنّاع المحتوى من الهدايا';

  @override
  String get ownerProfitAgencies => 'عمولات الوكالات';

  @override
  String get ownerProfitReferrals => 'مكافآت الدعوات';

  @override
  String get ownerProfitTasks => 'جوائز المهام والأهداف';

  @override
  String get ownerProfitStaff => 'عمولات الموظفين على التجنيد';

  @override
  String get ownerProfitTeam => 'تعديلات الفريق';

  @override
  String get ownerProfitCardFees => 'رسوم البطاقات (تقديرية)';

  @override
  String ownerProfitCherries(String count, String rate) {
    return 'الكرز: $count، بسعر السحب $rate لكل مليون';
  }

  @override
  String ownerProfitFees(String count, String percent, String fixed) {
    return 'الطلبات: $count، بنسبة $percent و$fixed للطلب';
  }

  @override
  String get ownerProfitFixed => 'تكاليف ثابتة';

  @override
  String ownerProfitFixedShare(String days, String monthly) {
    return 'أيام: $days من $monthly شهرياً';
  }

  @override
  String get ownerProfitFixedNone => 'لا تكاليف ثابتة في هذه الفترة';

  @override
  String get ownerProfitPartial =>
      'حتى اليوم: الحصة المنقضية من التكاليف الثابتة';

  @override
  String ownerProfitOther(String currency, String before, String after) {
    return '$currency: قبل $before، بعد $after';
  }

  @override
  String get ownerProfitFailed => 'تعذّر حساب الربح';

  @override
  String get ownerProfitRetry => 'إعادة المحاولة';

  @override
  String get ownerCostsManage => 'إدارة التكاليف الثابتة';

  @override
  String get ownerCostsHint => 'مبلغ شهري بالدولار يُقسَّم على أيام الشهر';

  @override
  String get ownerCostsEmpty => 'لا تكاليف ثابتة بعد';

  @override
  String get ownerCostsAdd => 'إضافة تكلفة';

  @override
  String get ownerCostsEdit => 'تعديل التكلفة';

  @override
  String get ownerCostsName => 'الاسم';

  @override
  String get ownerCostsNameHint => 'مثلاً: Claude أو LiveKit أو الخوادم';

  @override
  String get ownerCostsMonthly => 'المبلغ الشهري (USD)';

  @override
  String get ownerCostsFrom => 'من';

  @override
  String get ownerCostsTo => 'إلى (اختياري)';

  @override
  String get ownerCostsOngoing => 'مستمرة';

  @override
  String ownerCostsPerMonth(String amount) {
    return '$amount شهرياً';
  }

  @override
  String get ownerCostsEnded => 'انتهت';

  @override
  String get ownerCostsInvalid => 'أدخل اسماً ومبلغاً أكبر من صفر';

  @override
  String get ownerCostsDelete => 'حذف';

  @override
  String ownerCostsDeleteConfirm(String name) {
    return 'حذف $name؟ لن تُحسب في الربح بعد الآن.';
  }

  @override
  String get ownerCostsCancel => 'إلغاء';

  @override
  String get ownerCostsSaved => 'حُفظت التكلفة';

  @override
  String get ownerProfitCoins => 'عملات مُنحت مجاناً (جوائز ومكافآت)';

  @override
  String ownerProfitCoinsDetail(String count, String rate) {
    return 'العملات: $count، بأقل سعر للوكيل $rate لكل مليون';
  }

  @override
  String get eventsGifts => 'هدايا الفعالية';

  @override
  String eventsGiftPoints(String points) {
    return '$points نقطة';
  }

  @override
  String get eventsGiftPointsHint =>
      'كل عملة تُرسل بهدية من هدايا الفعالية تعطي نقاطاً';

  @override
  String get eventsRuleOnlyGifts =>
      'تُحتسب النقاط فقط من إرسال هدايا الفعالية خلال مدتها.';

  @override
  String get eventsRuleMinimum =>
      'يجب الوصول إلى الحد الأدنى من النقاط للتأهل للجوائز.';

  @override
  String get eventsRuleAutoPayout =>
      'تُرسل الجوائز تلقائياً بعد انتهاء الفعالية.';

  @override
  String get eventsLocalTime => 'التواريخ بتوقيتك المحلي';

  @override
  String get eventsBoardSenders => 'ترتيب الداعمين';

  @override
  String get eventsBoardReceivers => 'ترتيب المضيفين';

  @override
  String get eventsBoardCreators => 'صناع المحتوى';

  @override
  String get eventsBoardAgencies => 'الوكالات';

  @override
  String get eventsBoardCp => 'الثنائيات CP';

  @override
  String eventsMinPoints(String points) {
    return 'الحد الأدنى للتأهل: $points نقطة';
  }

  @override
  String eventsPointsToQualify(String points) {
    return 'باقي $points نقطة للتأهل';
  }

  @override
  String get eventsQualified => 'مؤهّل للجائزة';

  @override
  String get eventsNotQualified => 'لم يتأهل';

  @override
  String eventsPrizeCherries(String amount) {
    return '$amount كرز';
  }

  @override
  String eventsPrizeDays(String name, String days) {
    return '$name · $days يوم';
  }

  @override
  String get eventsPrizeVip => 'بطاقة VIP';

  @override
  String get eventsPrizeItem => 'عنصر';

  @override
  String eventsAgencyOwner(String name) {
    return 'الوكيل: $name';
  }

  @override
  String eventsCpPair(String a, String b) {
    return '$a و$b';
  }

  @override
  String get eventsBoardsTitle => 'الترتيب والجوائز';

  @override
  String eventsPrizeCpMoney(String cherries, String coins) {
    return '$cherries كرز للمضيف / $coins كوينز لغيره';
  }

  @override
  String eventsPrizePermanent(String name) {
    return '$name · دائم';
  }

  @override
  String eventsPrizeMedalLevel(String name, String level) {
    return '$name (المستوى $level)';
  }

  @override
  String eventsCountdownStarts(String time) {
    return 'تبدأ بعد $time';
  }

  @override
  String eventsCountdownEnds(String time) {
    return 'تنتهي بعد $time';
  }

  @override
  String get eventsCountdownEnded => 'انتهت الفعالية';

  @override
  String eventsMyBar(String rank, String points) {
    return 'مركزي: $rank · $points نقطة';
  }

  @override
  String eventsMyBarNone(String points) {
    return 'لم تدخل الترتيب بعد · $points نقطة';
  }

  @override
  String eventsToNextRank(String points, String rank) {
    return 'باقي $points نقطة للمركز $rank';
  }

  @override
  String eventsSendGiftTitle(String name) {
    return 'أرسل $name داخل بث';
  }

  @override
  String get eventsSendGiftBody =>
      'تُرسل هدايا الفعالية من لوحة الهدايا داخل أي بث مباشر، وتُحسب نقاطها فوراً.';

  @override
  String get eventsGoLive => 'اذهب إلى البث';

  @override
  String get eventsPrizePreview => 'معاينة الجائزة';

  @override
  String get notifEventPrizeWon => 'مبروك، وصلتك جائزة فعالية';

  @override
  String get founderActionsTitle => 'إجراءات المؤسس';

  @override
  String founderActionsFor(String name) {
    return 'إجراءات المؤسس · $name';
  }

  @override
  String get founderActionWarn => 'تحذير';

  @override
  String get founderActionSuspend => 'حظر مؤقت';

  @override
  String get founderActionBan => 'حظر دائم';

  @override
  String get founderActionDelete => 'حذف الحساب';

  @override
  String get founderActionWarnHint =>
      'يصل للشخص إشعار تحذير، ويبقى حسابه كما هو.';

  @override
  String get founderActionSuspendHint =>
      'لا يستطيع الدخول حتى تنتهي المدة، ويُنهى بثه إن كان مباشراً.';

  @override
  String get founderActionBanHint =>
      'يُحظر الحساب حتى يُفك الحظر من لوحة التحكم.';

  @override
  String get founderActionDeleteHint =>
      'يدخل الحساب مهلة الحذف ويمكن استرجاعه خلالها عند تسجيل الدخول، ثم يُحذف نهائياً.';

  @override
  String get founderActionReason => 'السبب';

  @override
  String get founderActionReasonHint => 'مطلوب — يُحفظ في سجل التدقيق';

  @override
  String get founderActionDuration => 'المدة';

  @override
  String founderActionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String founderActionConfirmTitle(String action, String name) {
    return '$action — $name';
  }

  @override
  String get founderActionConfirm => 'تأكيد';

  @override
  String founderActionDone(String action) {
    return 'تم: $action';
  }

  @override
  String get founderActionNotActive =>
      'رُفض: الحساب غير نشط أو عليه إجراء قائم.';

  @override
  String get founderActionSelfOrOwner =>
      'لا يمكن تنفيذ هذا الإجراء على هذا الحساب.';

  @override
  String giftOwnerBy(String name) {
    return 'هدية $name';
  }

  @override
  String giftOwnerSemantics(String name) {
    return 'هدية مخصصة لصاحبها $name';
  }

  @override
  String get liveRankMonth => 'هذا الشهر';

  @override
  String get liveRankYear => 'هذه السنة';

  @override
  String get liveRankGames => 'مجنون اللعب';

  @override
  String get liveRankGamesEmpty =>
      'لا تذاكر مُنفقة في الألعاب بعد في هذه الفترة.';

  @override
  String liveRankTickets(String formatted) {
    return '$formatted تذكرة';
  }

  @override
  String liveRankCoins(String formatted) {
    return '$formatted كوينز';
  }

  @override
  String get liveRankRichEmpty => 'لم يُرسل أحد هدايا بعد في هذه الفترة.';

  @override
  String get navParty => 'الحفلة';

  @override
  String get liveHubGoLive => 'ابدأ بثاً';

  @override
  String get feedCreate => 'إنشاء';

  @override
  String get photoEditTitle => 'تعديل الصورة';

  @override
  String get photoEditDone => 'تم';

  @override
  String get photoEditCancel => 'إلغاء';

  @override
  String get photoEditPreview => 'الصورة بعد التعديل';

  @override
  String get photoEditRotate => 'تدوير';

  @override
  String get photoEditFailed => 'تعذّر تعديل هذه الصورة';

  @override
  String get photoToolCrop => 'قص';

  @override
  String get photoToolFilters => 'فلاتر';

  @override
  String get photoToolAdjust => 'ضبط';

  @override
  String get photoAspectOriginal => 'الأصلي';

  @override
  String get photoFilterNormal => 'عادي';

  @override
  String get photoFilterVivid => 'زاهٍ';

  @override
  String get photoFilterWarm => 'دافئ';

  @override
  String get photoFilterCool => 'بارد';

  @override
  String get photoFilterMono => 'أحادي';

  @override
  String get photoFilterFade => 'باهت';

  @override
  String get photoAdjustBrightness => 'السطوع';

  @override
  String get photoAdjustContrast => 'التباين';

  @override
  String get createKindPost => 'منشور';

  @override
  String get createKindReel => 'ريلز';

  @override
  String get createKindStory => 'ستوري';

  @override
  String get createEditPhoto => 'تعديل';

  @override
  String get createSuggestions => 'اقتراحات';

  @override
  String get uploadRetrying => 'انقطع الاتصال — نعيد المحاولة…';

  @override
  String get uploadView => 'عرض';

  @override
  String createSuggestionPosts(String count) {
    return '$count منشور';
  }

  @override
  String relativeShortMinutes(int n) {
    return '$nد';
  }

  @override
  String relativeShortHours(int n) {
    return '$nس';
  }

  @override
  String relativeShortDays(int n) {
    return '$nي';
  }

  @override
  String get dmBoxes => 'صناديق الرسائل';

  @override
  String get dmTabArchived => 'المؤرشفة';

  @override
  String get dmArchive => 'أرشفة';

  @override
  String get dmUnarchive => 'إلغاء الأرشفة';

  @override
  String get dmArchivedDone => 'تمت الأرشفة';

  @override
  String get dmUnarchivedDone => 'أُعيدت إلى الدردشات';

  @override
  String get dmArchivedEmptyTitle => 'لا توجد دردشات مؤرشفة';

  @override
  String get dmArchivedHint =>
      'الدردشات التي تؤرشفها تظهر هنا فقط لك، وتعود إلى الدردشات عندما يصلك رد جديد.';

  @override
  String get dmNewGroup => 'مجموعة جديدة';

  @override
  String get dmGroupNameLabel => 'اسم المجموعة';

  @override
  String get dmGroupNameHint => 'مثال: أصدقاء الجامعة';

  @override
  String get dmGroupNameRequired => 'اكتب اسمًا للمجموعة';

  @override
  String get dmGroupAddPhoto => 'إضافة صورة';

  @override
  String get dmGroupChangePhoto => 'تغيير الصورة';

  @override
  String get dmGroupRemovePhoto => 'إزالة الصورة';

  @override
  String get dmGroupPhoto => 'صورة المجموعة';

  @override
  String get dmGroupPickMembers => 'اختر الأعضاء';

  @override
  String get dmGroupPickHint => 'يمكنك إضافة من تتابعهم ويتابعونك.';

  @override
  String get dmGroupPickAtLeastOne => 'اختر شخصًا واحدًا على الأقل';

  @override
  String dmGroupSelected(String count) {
    return 'المختارون: $count';
  }

  @override
  String get dmGroupSearchPeople => 'ابحث عن شخص';

  @override
  String get dmGroupCreate => 'إنشاء';

  @override
  String get dmGroupCandidatesEmpty => 'لا يوجد أحد لإضافته بعد';

  @override
  String get dmGroupCandidatesEmptyBody =>
      'تابِع أشخاصًا يتابعونك لتضيفهم إلى مجموعة.';

  @override
  String dmGroupMembersCount(String count) {
    return 'الأعضاء: $count';
  }

  @override
  String get dmGroupInfo => 'معلومات المجموعة';

  @override
  String get dmGroupMembers => 'الأعضاء';

  @override
  String get dmGroupAddMembers => 'إضافة أعضاء';

  @override
  String get dmGroupMembersAdded => 'أُضيف الأعضاء';

  @override
  String get dmGroupAdmin => 'مشرف';

  @override
  String get dmGroupCreator => 'المنشئ';

  @override
  String get dmGroupYou => 'أنت';

  @override
  String get dmGroupMakeAdmin => 'تعيين مشرفًا';

  @override
  String get dmGroupRemoveAdmin => 'إزالة الإشراف';

  @override
  String get dmGroupRemoveMember => 'إزالة من المجموعة';

  @override
  String get dmGroupRename => 'تغيير الاسم';

  @override
  String get dmGroupSave => 'حفظ';

  @override
  String get dmGroupLeave => 'مغادرة المجموعة';

  @override
  String get dmGroupLeaveTitle => 'مغادرة المجموعة؟';

  @override
  String get dmGroupLeaveBody =>
      'لن تصلك رسائلها بعد الآن، ويمكن لمشرف إضافتك من جديد.';

  @override
  String get dmGroupReport => 'الإبلاغ عن المجموعة';

  @override
  String get dmGroupUnavailable => 'هذه المجموعة لم تعد متاحة';

  @override
  String get dmGroupUnknownSender => 'حساب غير متاح';

  @override
  String dmPreviewSender(String name, String text) {
    return '$name: $text';
  }

  @override
  String get dmGroupNoGifts => 'لا تُرسل الهدايا في المجموعات';

  @override
  String get errorDmNotArchivable =>
      'لا يمكن أرشفة طلب مراسلة. اقبله أو احذفه.';

  @override
  String get errorDmGroupFull => 'وصلت المجموعة إلى الحد الأقصى من الأعضاء.';

  @override
  String get errorDmGroupMemberNotAllowed =>
      'لا يمكنك إضافة بعض هؤلاء الأشخاص إلى مجموعة.';

  @override
  String eventsFinalRank(String rank) {
    return 'مركزك النهائي: $rank';
  }

  @override
  String get eventsNotParticipated => 'لم تشارك';

  @override
  String eventsNotQualifiedFinal(String points) {
    return 'لم تتأهل — الحد الأدنى $points نقطة';
  }

  @override
  String get eventsYouWon => 'فزت بـ:';

  @override
  String eventsYouWonShort(String prize) {
    return 'فزت بـ $prize';
  }

  @override
  String eventsYouWonMore(String prize, String count) {
    return 'فزت بـ $prize +$count';
  }

  @override
  String get eventsPrizePending => 'تُسلَّم الجائزة بعد المراجعة';

  @override
  String get eventsResultsPending => 'النتائج النهائية قيد الاعتماد';

  @override
  String eventsMyBarFinal(String rank, String points) {
    return 'مركزك النهائي: $rank · $points نقطة';
  }

  @override
  String get eventsMyBarNotRanked => 'لم تدخل الترتيب بعد';

  @override
  String get eventsAnnounceStarted => 'بدأت فعالية جديدة';

  @override
  String get eventsAnnounceJoin => 'شارك الآن';

  @override
  String get eventsAnnounceLater => 'لاحقاً';

  @override
  String get eventsAnnounceTopPrize => 'الجائزة الكبرى';

  @override
  String get eventsAnnounceWinTitle => 'مبروك';

  @override
  String eventsAnnounceWinBody(String rank, String event) {
    return 'حصلت على المركز $rank في $event';
  }

  @override
  String get eventsAnnounceYourPrize => 'جائزتك';

  @override
  String get eventsAnnounceResults => 'عرض النتائج';

  @override
  String get eventsAnnounceClose => 'إغلاق الإعلان';

  @override
  String get eventsNotQualifiedYou => 'لم تتأهل';

  @override
  String get livePartyEmptyTitle => 'لا غرف في الحفلة الآن';

  @override
  String get livePartyEmptyBody => 'عد لاحقًا أو جرّب تبويبًا آخر.';

  @override
  String get signupCodeToggle => 'لديك رمز دعوة؟';

  @override
  String get signupCodeLabel => 'رمز الدعوة أو رمز المشرف (اختياري)';

  @override
  String get signupCodeHelper =>
      'رمز صديق دعاك، أو رمز المشرف الذي استقطبك. لا يمكن تغييره بعد التسجيل.';

  @override
  String get signupCodePaste => 'لصق الرمز';

  @override
  String get signupCodeRemove => 'إزالة الرمز';

  @override
  String get signupCodeFromLink =>
      'أُضيف تلقائياً من رابط الدعوة. يمكنك إزالته.';

  @override
  String get signupCodeChecking => 'جارٍ التحقق من الرمز…';

  @override
  String get signupCodeInviteOk => 'رمز دعوة من صديق';

  @override
  String signupCodeSupervisorOk(String code) {
    return 'رمز المشرف $code';
  }

  @override
  String get signupCodeNotFound => 'الرمز غير صحيح. تأكد منه أو اتركه فارغاً.';

  @override
  String get signupCodeClipboardEmpty => 'لا يوجد رمز في الحافظة';

  @override
  String get staffSignupLinkTitle => 'رابطك الشخصي';

  @override
  String staffSignupLinkBody(String code) {
    return 'أرسله لمن تستقطبه: يحمّل التطبيق ويُضاف رمزك $code عند إنشاء حسابه.';
  }

  @override
  String get staffSignupLinkCopy => 'نسخ الرابط';

  @override
  String get staffSignupLinkShare => 'مشاركة';

  @override
  String get staffSignupLinkCopied => 'تم نسخ الرابط';

  @override
  String staffSignupCounts(int granted, int withheld) {
    return 'سجّلوا برمزك: $granted · لم يُحتسبوا: $withheld';
  }

  @override
  String get staffSignupWithheldNote =>
      'لا يُحتسب من كان له حساب على الجهاز نفسه أو سجّل بالبريد نفسه من قبل.';

  @override
  String get storeIapTitle => 'الشراء من المتجر';

  @override
  String storeIapVia(String store) {
    return 'الدفع عبر $store';
  }

  @override
  String storeIapCoins(String coins) {
    return '$coins عملة';
  }

  @override
  String storeIapBuyLabel(String coins, String price) {
    return 'شراء $coins عملة بسعر $price';
  }

  @override
  String get storeIapConsentTitle => 'قبل الشراء';

  @override
  String get storeIapConsentDelivery =>
      'تُسلَّم العملات فوراً إلى رصيدك وتُستهلك عند استخدامها، ولا تُسترد بعد الشراء.';

  @override
  String get storeIapConsentFraud =>
      'طلب استرداد عبر المتجر يُعدّ احتيالاً: تُسحب العملات (وقد يصبح رصيدك سالباً) ويُحظر الحساب وكل أجهزته.';

  @override
  String storeIapConsentShare(String store) {
    return 'عند طلب استرداد، يرسل Kabso إلى $store مقدار ما استُهلك من هذه العملات ليقرّر الطلب.';
  }

  @override
  String get storeIapConsentCheck =>
      'أوافق على سياسة عدم الاسترداد وعلى مشاركة بيانات الاستخدام عند طلب استرداد';

  @override
  String storeIapConsentContinue(String store) {
    return 'متابعة إلى $store';
  }

  @override
  String storeIapConsentPrice(String coins, String price) {
    return '$coins عملة — $price';
  }

  @override
  String get storeIapConsentTerms =>
      'التفاصيل في شروط الاستخدام: «مشتريات المتاجر وسياسة عدم الاسترداد».';

  @override
  String get storeIapVerifying => 'جارٍ تأكيد الشراء مع المتجر…';

  @override
  String get storeIapPending =>
      'الدفع قيد المعالجة لدى المتجر. تُضاف العملات عند اكتماله.';

  @override
  String storeIapSuccess(String coins) {
    return 'أُضيفت $coins عملة إلى رصيدك.';
  }

  @override
  String get storeIapRejected =>
      'لم تُضف العملات: الشراء من المتجر مرة واحدة لكل حساب وجهاز. يعيد المتجر المبلغ تلقائياً.';

  @override
  String get storeIapStoreError => 'لم يكتمل الشراء في المتجر.';

  @override
  String get storeIapDeviceBanned =>
      'الشراء من المتجر غير متاح على هذا الجهاز لأنه محظور.';

  @override
  String get storeIapLimitReached =>
      'اشتريت من المتجر من قبل على هذا الحساب أو الجهاز. الشراء من المتجر مرة واحدة فقط.';

  @override
  String get storeIapDismiss => 'حسناً';

  @override
  String get errorStoreIapUnavailable => 'الشراء من المتجر غير متاح حالياً.';

  @override
  String get errorStoreIapVerificationFailed =>
      'لم يؤكد المتجر هذا الشراء، ولم تُضف عملات.';

  @override
  String get errorStoreIapPurchaseConflict => 'هذا الشراء مرتبط بحساب آخر.';

  @override
  String get errorStoreIapPending => 'الدفع قيد المعالجة لدى المتجر.';

  @override
  String get walletReasonStoreIap => 'شراء من المتجر';

  @override
  String get walletReasonStoreIapReversal =>
      'استرداد عبر المتجر (سُحبت العملات)';

  @override
  String get errorLiveCapacityFull => 'البث مزدحم الآن، حاول بعد قليل';

  @override
  String get liveCapacityTitle => 'البث مزدحم';

  @override
  String get liveCapacityHint =>
      'إعداداتك محفوظة، يمكنك المحاولة مجددًا بعد انتهاء العدّ.';

  @override
  String get liveCapacityRetry => 'حاول مجددًا';

  @override
  String liveCapacityRetryIn(String wait) {
    return 'حاول مجددًا بعد $wait';
  }

  @override
  String get liveCapacityClose => 'لاحقًا';

  @override
  String get waRow => 'واتساب';

  @override
  String waRowBadge(int count) {
    return '$count محادثة بانتظار الرد';
  }

  @override
  String get waTitle => 'واتساب';

  @override
  String get waTabUnassigned => 'غير مسندة';

  @override
  String get waTabMine => 'محادثاتي';

  @override
  String get waTabAll => 'الكل';

  @override
  String get waTabClosed => 'مغلقة';

  @override
  String get waSearch => 'ابحث بالاسم أو الرقم';

  @override
  String get waEmpty => 'لا توجد محادثات هنا';

  @override
  String get waEmptyHint => 'تظهر هنا رسائل العملاء إلى رقم Kabso الرسمي.';

  @override
  String get waOff => 'واتساب غير مفعّل بعد';

  @override
  String get waOffHint => 'يضبطه المالك بعد إنشاء حساب Meta للأعمال.';

  @override
  String waUnreadCount(int count) {
    return '$count غير مقروءة';
  }

  @override
  String get waAssignedToMe => 'معي';

  @override
  String waAssignedTo(String name) {
    return 'مع $name';
  }

  @override
  String get waUnassigned => 'غير مسندة';

  @override
  String get waClosed => 'مغلقة';

  @override
  String get waClaim => 'استلام';

  @override
  String get waRelease => 'إرجاع للقائمة';

  @override
  String get waTransfer => 'تحويل';

  @override
  String get waTransferTo => 'تحويل إلى';

  @override
  String get waClose => 'إغلاق';

  @override
  String get waReopen => 'إعادة فتح';

  @override
  String waWindowOpen(String time) {
    return 'نافذة الرد مفتوحة حتى $time';
  }

  @override
  String get waWindowClosed =>
      'مرّت 24 ساعة على آخر رسالة من العميل: يمكنك فقط إرسال قالب معتمد.';

  @override
  String get waWindowNever =>
      'لم يرسل العميل رسالة بعد: يمكنك فقط إرسال قالب معتمد.';

  @override
  String get waComposerHint => 'اكتب ردك…';

  @override
  String get waSend => 'إرسال';

  @override
  String get waSendTemplate => 'إرسال قالب';

  @override
  String waTemplateParam(int n) {
    return 'المتغيّر $n';
  }

  @override
  String get waNoTemplates => 'لا توجد قوالب معتمدة بعد.';

  @override
  String get waAttach => 'إرفاق';

  @override
  String get waQuickReplies => 'ردود سريعة';

  @override
  String get waNoQuickReplies => 'لا توجد ردود سريعة.';

  @override
  String get waVoice => 'رسالة صوتية';

  @override
  String get waPlay => 'تشغيل';

  @override
  String get waPause => 'إيقاف';

  @override
  String get waOpenFile => 'فتح الملف';

  @override
  String get waMediaTooLarge => 'الملف أكبر من الحد المسموح ولم يُحفظ.';

  @override
  String get waMediaRefused => 'نوع الملف غير مسموح ولم يُحفظ.';

  @override
  String get waMediaFailed => 'تعذّر جلب الملف من واتساب.';

  @override
  String get waLocation => 'موقع';

  @override
  String get waUnsupported => 'رسالة من نوع غير مدعوم بعد.';

  @override
  String waTemplateTag(String name) {
    return 'قالب: $name';
  }

  @override
  String get waStatusSent => 'أُرسلت';

  @override
  String get waStatusDelivered => 'وصلت';

  @override
  String get waStatusRead => 'قُرئت';

  @override
  String get waStatusFailed => 'فشل الإرسال';

  @override
  String waSentBy(String name) {
    return 'أرسلها $name';
  }

  @override
  String get waCustomer => 'العميل';

  @override
  String get waAccount => 'حساب Kabso';

  @override
  String get waNoAccount =>
      'غير مربوط بحساب. اطلب من العميل اسم المستخدم ثم اربطه.';

  @override
  String get waLink => 'ربط بحساب';

  @override
  String get waUnlink => 'إلغاء الربط';

  @override
  String get waUsername => 'اسم المستخدم';

  @override
  String get waNotes => 'ملاحظات داخلية';

  @override
  String get waNotesHint => 'لا تُرسل إلى العميل أبداً.';

  @override
  String get waAddNote => 'إضافة ملاحظة';

  @override
  String get waNoNotes => 'لا توجد ملاحظات.';

  @override
  String get waHistory => 'سجل الإسناد';

  @override
  String get waSomeone => 'موظف';

  @override
  String get waMute => 'كتم إشعارات واتساب';

  @override
  String get waErrWindow => 'انتهت نافذة الـ24 ساعة: أرسل قالباً معتمداً.';

  @override
  String get waErrAssigned => 'المحادثة مع موظف آخر.';

  @override
  String get waErrClosed => 'المحادثة مغلقة. أعد فتحها أولاً.';

  @override
  String get waErrSend => 'لم يقبل واتساب الرسالة.';

  @override
  String get waErrOff => 'واتساب غير مفعّل على الخادم.';

  @override
  String get waDetails => 'تفاصيل العميل';

  @override
  String get waViewOnly => 'مشاهدة فقط';

  @override
  String get waViewOnlyHint =>
      'مستواك في واتساب «مشاهدة فقط»: تقرأ المحادثة وتفاصيل العميل، ولا يمكنك الرد أو اتخاذ إجراء.';

  @override
  String eventsUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يوم',
      many: 'يومًا',
      few: 'أيام',
      two: 'يومان',
      one: 'يوم',
      zero: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String eventsUnitHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ساعة',
      many: 'ساعة',
      few: 'ساعات',
      two: 'ساعتان',
      one: 'ساعة',
      zero: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String eventsUnitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دقيقة',
      many: 'دقيقة',
      few: 'دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
      zero: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String eventsUnitSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ثانية',
      many: 'ثانية',
      few: 'ثوانٍ',
      two: 'ثانيتان',
      one: 'ثانية',
      zero: 'ثانية',
    );
    return '$_temp0';
  }

  @override
  String get eventsTabRanking => 'الترتيب';

  @override
  String get eventsTabRewards => 'الجوائز';

  @override
  String get eventsRewardPermanent => 'دائم';

  @override
  String get eventsRewardPreview => 'معاينة';

  @override
  String get eventsRewardFeatured => 'الجائزة الكبرى';

  @override
  String get eventsSeatOpen => 'المركز متاح';

  @override
  String eventsToPrevRank(String points, String rank) {
    return 'باقي $points للمركز $rank';
  }

  @override
  String get eventsLastHour => 'الساعة الأخيرة';

  @override
  String eventsRewardDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يوماً',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String eventsDaysShort(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم',
      zero: '0 يوم',
    );
    return '$_temp0';
  }

  @override
  String get eventsNoEnd => 'بلا نهاية';

  @override
  String get eventsMilestonesTitle => 'المراحل';

  @override
  String eventsMilestoneAt(String points) {
    return 'عند $points نقطة';
  }

  @override
  String get eventPreviewSampleLabel => 'معاينة · بيانات المتصدرين تجريبية';

  @override
  String get liveTypeTagVoice => 'Voice';

  @override
  String get liveTypeTagCam => 'Live Cam';

  @override
  String get liveTypeTagPodcast => 'Podcast';

  @override
  String get liveTypeTagStreamer => 'Streamer';

  @override
  String get podcastFormat => 'نوع الحلقة';

  @override
  String get podcastFormatAudio => 'صوت';

  @override
  String get podcastFormatVideo => 'فيديو';

  @override
  String get podcastVideoBadge => 'فيديو';

  @override
  String get podcastShotSpeaker => 'لقطة المتحدث';

  @override
  String get podcastShotSplit => 'نقاش';

  @override
  String get podcastShotGrid => 'نقاش جماعي';

  @override
  String get podcastShotHotSeat => 'الكرسي الساخن';

  @override
  String get podcastBackToDirector => 'رجوع للمخرج';

  @override
  String podcastGuestLowerThird(String name, String title) {
    return 'الضيف: $name — $title';
  }

  @override
  String podcastGuestLowerThirdName(String name) {
    return 'الضيف: $name';
  }

  @override
  String get podcastGuestTitleHint => 'لقب الضيف (اختياري)';

  @override
  String get podcastQuestionsTitle => 'أسئلة المستمعين';

  @override
  String get podcastVote => 'صوّت للسؤال';

  @override
  String get podcastUnvote => 'ألغِ التصويت';

  @override
  String podcastVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صوت',
      many: '$count صوتاً',
      few: '$count أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات',
    );
    return '$_temp0';
  }

  @override
  String get podcastNoQuestions => 'لا أسئلة بعد.';

  @override
  String get podcastDirector => 'المخرج';

  @override
  String get podcastDirectorAuto => 'تلقائي';

  @override
  String podcastDirectorPinned(String name) {
    return 'ثبّت اللقطة على $name';
  }

  @override
  String podcastHotSeatFrom(String name) {
    return 'سؤال من $name';
  }

  @override
  String get podcastBackstage => 'خلف الكواليس';

  @override
  String get podcastBringOnAir => 'على الهواء';

  @override
  String get podcastBackstageCheckTitle => 'أنت خلف الكواليس';

  @override
  String get podcastBackstageCheckBody =>
      'المضيف وحده يراك ويسمعك الآن. تأكد من الكاميرا والميكروفون، وسيُدخلك على الهواء.';

  @override
  String get podcastBackstageMicOk => 'الميكروفون يعمل';

  @override
  String get podcastBackstageMicQuiet => 'تكلّم لاختبار الميكروفون';

  @override
  String get podcastBackstageCameraOff => 'الكاميرا مغلقة';

  @override
  String get podcastBackstageLeave => 'مغادرة الكواليس';

  @override
  String podcastControlPinned(String name) {
    return 'مثبّت: $name';
  }

  @override
  String podcastControlLayout(String layout) {
    return 'تخطيط ثابت: $layout';
  }

  @override
  String get podcastDirectorLayout => 'التخطيط';

  @override
  String get podcastDirectorPeople => 'تثبيت شخص';

  @override
  String get podcastSegments => 'فقرات الحلقة';

  @override
  String podcastSegmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فقرة',
      many: '$count فقرة',
      few: '$count فقرات',
      two: 'فقرتان',
      one: 'فقرة واحدة',
      zero: 'لا فقرات',
    );
    return '$_temp0';
  }

  @override
  String podcastSegmentOf(int current, int total) {
    return 'الفقرة $current من $total';
  }

  @override
  String get podcastSegmentNext => 'الفقرة التالية';

  @override
  String get podcastSegmentStart => 'ابدأ الفقرات';

  @override
  String get podcastSegmentAdd => 'إضافة فقرة';

  @override
  String get podcastSegmentRemove => 'حذف الفقرة';

  @override
  String get podcastSegmentTitleHint => 'عنوان الفقرة';

  @override
  String get podcastSegmentMinutesHint => 'دقائق';

  @override
  String get podcastSegmentsSave => 'حفظ الفقرات';

  @override
  String get podcastClosingTitle => 'نهاية الحلقة';

  @override
  String get podcastClosingBody => 'شكراً لمتابعتكم';

  @override
  String get podcastShowOnScreen => 'اعرض على الشاشة';

  @override
  String get podcastOnScreenTag => 'سؤال الجمهور';

  @override
  String get podcastOnScreenHide => 'إخفاء السؤال';

  @override
  String get waFailed => 'تعذّر الإرسال';

  @override
  String get waFailDetails => 'سبب التعذّر';

  @override
  String get waFailUndeliverable =>
      'لم يصل إلى الرقم: قد لا يستخدم واتساب أو لم يوافق على شروطه.';

  @override
  String get waFailRate => 'أُرسلت رسائل كثيرة في وقت قصير: حاول بعد قليل.';

  @override
  String get waFailUnsupported =>
      'واتساب لا يقبل هذا النوع من الرسائل لهذا الرقم.';

  @override
  String get waRetry => 'إعادة الإرسال';

  @override
  String get waYesterday => 'أمس';

  @override
  String waWindowLeftHours(int hours) {
    return 'نافذة الرد: $hours س متبقية';
  }

  @override
  String waWindowLeftMinutes(int minutes) {
    return 'نافذة الرد: $minutes د متبقية';
  }

  @override
  String get waWindowClosedChip => 'مغلقة — قالب فقط';

  @override
  String get waMenu => 'إجراءات المحادثة';

  @override
  String get waAttachPhoto => 'صورة';

  @override
  String get waDeptPAYMENTS => 'الشحن والمدفوعات';

  @override
  String get waDeptAGENCIES => 'الوكالات والمضيفون';

  @override
  String get waDeptTECHNICAL => 'المشاكل التقنية';

  @override
  String get waDeptREPORTS => 'البلاغات والحظر';

  @override
  String get waDeptGENERAL => 'عام';

  @override
  String get waDeptAll => 'كل الأقسام';

  @override
  String waDeptLabel(String department) {
    return 'القسم: $department';
  }

  @override
  String get waTransferTitle => 'تحويل المحادثة';

  @override
  String get waTransferDepartment => 'القسم';

  @override
  String get waTransferWho => 'إلى من';

  @override
  String get waTransferFirst => 'أول متاح في القسم';

  @override
  String get waTransferFirstHint =>
      'أقل موظف مناوب انشغالاً، أو قائمة القسم إن لم يكن أحد مناوباً';

  @override
  String get waTransferNoAgents => 'لا يوجد موظفون في هذا القسم بعد.';

  @override
  String get waTransferNote => 'ملاحظة داخلية (اختياري)';

  @override
  String get waTransferNoteHint => 'تُحفظ مع التحويل ولا تُرسل للعميل أبداً';

  @override
  String get waTransferConfirm => 'تحويل';

  @override
  String waTransferDoneTo(String name) {
    return 'حُوّلت المحادثة إلى $name';
  }

  @override
  String waTransferDoneQueue(String department) {
    return 'حُوّلت المحادثة إلى قائمة $department';
  }

  @override
  String waAgentOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محادثة مفتوحة',
      many: '$count محادثة مفتوحة',
      few: '$count محادثات مفتوحة',
      two: 'محادثتان مفتوحتان',
      one: 'محادثة مفتوحة',
      zero: 'لا محادثات مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get waOnShift => 'مناوب';

  @override
  String get waOffShift => 'خارج المناوبة';

  @override
  String waQueueOf(String department) {
    return 'قائمة $department';
  }

  @override
  String get vipPayPoints => 'استبدل بالنقاط';

  @override
  String get vipPayWith => 'طريقة الدفع';

  @override
  String vipPoints(String points) {
    return '$points نقطة';
  }

  @override
  String vipPointsBalance(String points) {
    return 'رصيدك: $points نقطة';
  }

  @override
  String get vipPointsShort => 'نقاط غير كافية';

  @override
  String get vipPointsHint => 'كل عملة تشحنها = نقطة شحن';

  @override
  String get vipConfirmPoints => 'نقاطك';

  @override
  String vipRedeem(String points) {
    return 'استبدل $points نقطة';
  }

  @override
  String get vipErrorNoPointsPrice => 'هذا المستوى لا يُستبدل بالنقاط.';

  @override
  String vipRedeemDone(String tier, String date) {
    return 'تم استبدال النقاط: $tier حتى $date';
  }

  @override
  String get errorInsufficientRechargePoints =>
      'نقاط الشحن لا تكفي لهذا المستوى.';

  @override
  String get rechargePointsTitle => 'نقاط الشحن';

  @override
  String rechargePointsRowHint(String points) {
    return '$points نقطة · استبدلها بـ VIP';
  }

  @override
  String get rechargePointsBalanceLabel => 'رصيد النقاط';

  @override
  String get rechargePointsHowTo =>
      'كل عملة تشحنها من الموقع أو المتجر أو من وكيل شحن = نقطة واحدة. النقاط لا تنتهي وتُستبدل بـ VIP.';

  @override
  String get rechargePointsEmpty => 'لا نقاط بعد';

  @override
  String get rechargePointsEmptyBody => 'اشحن العملات لتجمع النقاط.';

  @override
  String get rechargePointsLoadError => 'تعذّر تحميل نقاط الشحن';

  @override
  String rechargePointsAfter(String points) {
    return 'الرصيد بعدها: $points';
  }

  @override
  String get rechargePointsReasonWeb => 'شحن من الموقع';

  @override
  String get rechargePointsReasonStore => 'شحن من المتجر';

  @override
  String get rechargePointsReasonAgent => 'شحن من وكيل';

  @override
  String get rechargePointsReasonVip => 'استبدال VIP';

  @override
  String get rechargePointsReasonReversal => 'استرجاع شحن';

  @override
  String get rechargePointsReasonAdmin => 'تعديل من الإدارة';

  @override
  String get rechargePointsReasonOther => 'تغيير في النقاط';

  @override
  String vipPointsPer(String days) {
    return 'نقطة / $days يوماً';
  }

  @override
  String get contentGiftButton => 'هدية الدعم';

  @override
  String commentsGiftSent(String sender, String gift, String count) {
    return '$sender أرسل $gift $count';
  }

  @override
  String contentGiftCherriesLabel(String amount) {
    return 'كرز الهدايا: $amount';
  }

  @override
  String notifContentGiftReceived(String who) {
    return 'أرسل لك $who هدية';
  }

  @override
  String get walletReasonContentGift => 'هدية على منشور';

  @override
  String get earnContextContent => 'على منشور';

  @override
  String get errorContentGiftRecipientUnavailable =>
      'لا يمكن إرسال هدية على هذا المنشور.';

  @override
  String get statusTitle => 'الحالة';

  @override
  String get statusNone => 'بدون حالة';

  @override
  String get statusPickerHint => 'اختر رمزاً يظهر فوق صورتك مثل الفقاعات';

  @override
  String get statusSave => 'حفظ';

  @override
  String get statusSaved => 'تم حفظ الحالة';

  @override
  String get statusCleared => 'أُزيلت الحالة';

  @override
  String get statusPackGeneral => 'عام';

  @override
  String get statusPackPremium => 'المميزة';

  @override
  String get statusLockedHint =>
      'معاينة فقط: افتح المتجر لاستخدام رموز المميزة';

  @override
  String get statusLockedLabel => 'مقفلة';

  @override
  String get statusOpenStore => 'افتح المتجر';

  @override
  String get statusNotOwned =>
      'هذه الحالة من حزمة المميزة. افتح المتجر لشرائها';

  @override
  String get statusStoreTitle => 'الحالة المميزة';

  @override
  String statusStoreCount(String count) {
    return '$count رمزاً متحركاً تظهر فوق صورتك مثل الفقاعات';
  }

  @override
  String statusStoreActive(String date) {
    return 'الحزمة مفعّلة حتى $date';
  }

  @override
  String statusStoreDays(String days) {
    return '$days يوماً';
  }

  @override
  String statusStorePrice(String price) {
    return '$price عملة';
  }

  @override
  String statusStoreBuy(String price) {
    return 'شراء · $price';
  }

  @override
  String statusStoreRenew(String price) {
    return 'تجديد · $price';
  }

  @override
  String statusStoreConfirmBuy(String days, String price) {
    return 'شراء الحزمة المميزة: $days مقابل $price؟';
  }

  @override
  String statusStoreConfirmRenew(String days, String price) {
    return 'تجديد الحزمة المميزة: $days مقابل $price؟ تُضاف المدة إلى المدة المتبقية.';
  }

  @override
  String get statusStoreConfirm => 'تأكيد';

  @override
  String get statusStoreBought => 'تم تفعيل الحزمة المميزة';

  @override
  String get statusStoreRenewed => 'تم تجديد الحزمة';

  @override
  String get statusStoreShort => 'رصيدك غير كافٍ لهذه الحزمة.';

  @override
  String get statusStoreRecharge => 'شحن العملات';

  @override
  String statusStoreBalance(String coins) {
    return 'رصيدك: $coins';
  }

  @override
  String get statusStoreLoadError => 'تعذّر تحميل المتجر';

  @override
  String get statusStoreNotSold => 'الحزمة غير متاحة للشراء الآن';

  @override
  String get statusStoreUse => 'استخدم الحالة';

  @override
  String statusSemantics(String name) {
    return 'الحالة: $name';
  }

  @override
  String get walletReasonStatusPack => 'شراء حزمة الحالة';

  @override
  String get settingsLicenses => 'التراخيص';

  @override
  String get settingsNotoAttribution =>
      'الرموز المتحركة من Google ‏(Noto Emoji)، بترخيص CC BY 4.0';

  @override
  String get statusEmojiNotoHappy => 'سعيد';

  @override
  String get statusEmojiNotoLaugh => 'ضحك';

  @override
  String get statusEmojiNotoLove => 'حب';

  @override
  String get statusEmojiNotoHeartEyes => 'معجب';

  @override
  String get statusEmojiNotoCool => 'رايق';

  @override
  String get statusEmojiNotoStarStruck => 'منبهر';

  @override
  String get statusEmojiNotoParty => 'احتفال';

  @override
  String get statusEmojiNotoInnocent => 'بريء';

  @override
  String get statusEmojiNotoWinkTongue => 'مشاكس';

  @override
  String get statusEmojiNotoHug => 'حضن';

  @override
  String get statusEmojiNotoKiss => 'بوسة';

  @override
  String get statusEmojiNotoThinking => 'أفكر';

  @override
  String get statusEmojiNotoSleepy => 'نعسان';

  @override
  String get statusEmojiNotoEyeRoll => 'ملل';

  @override
  String get statusEmojiNotoSad => 'حزين';

  @override
  String get statusEmojiNotoCrying => 'بكاء';

  @override
  String get statusEmojiNotoAngry => 'غاضب';

  @override
  String get statusEmojiNotoShocked => 'مصدوم';

  @override
  String get statusEmojiNotoHeart => 'قلب';

  @override
  String get statusEmojiNotoFire => 'نار';

  @override
  String get statusEmojiNotoHundred => '١٠٠';

  @override
  String get statusEmojiNotoThumbsUp => 'تمام';

  @override
  String get statusEmojiNotoCongrats => 'مبروك';

  @override
  String get statusEmojiNotoThanks => 'شكراً';

  @override
  String get statusEmojiPremiumBird => 'عصفور';

  @override
  String get statusEmojiPremiumDove => 'حمامة';

  @override
  String get statusEmojiPremiumEagle => 'نسر';

  @override
  String get statusEmojiPremiumOwl => 'بومة';

  @override
  String get statusEmojiPremiumFlamingo => 'فلامنجو';

  @override
  String get statusEmojiPremiumPeacock => 'طاووس';

  @override
  String get statusEmojiPremiumPenguin => 'بطريق';

  @override
  String get statusEmojiPremiumChick => 'صوص';

  @override
  String get statusEmojiPremiumHatching => 'فقس';

  @override
  String get statusEmojiPremiumCrown => 'تاج';

  @override
  String get statusEmojiPremiumDiamond => 'ألماس';

  @override
  String get statusEmojiPremiumRocket => 'صاروخ';

  @override
  String get statusEmojiPremiumLion => 'أسد';

  @override
  String get statusEmojiPremiumRich => 'غني';

  @override
  String get statusEmojiPremiumTrophy => 'كأس';

  @override
  String get statusEmojiPremiumGlowStar => 'نجمة';

  @override
  String get statusEmojiPremiumSparkles => 'بريق';

  @override
  String get statusEmojiPremiumUnicorn => 'يونيكورن';

  @override
  String get statusEmojiPremiumDragon => 'تنين';

  @override
  String get statusEmojiPremiumRose => 'وردة';

  @override
  String get statusEmojiPremiumGift => 'هدية';

  @override
  String get statusEmojiPremiumFireworks => 'ألعاب نارية';

  @override
  String get statusEmojiPremiumRainbow => 'قوس قزح';

  @override
  String get statusEmojiPremiumSparklingHeart => 'قلب لامع';

  @override
  String get statusEmojiPremiumChampagne => 'شمبانيا';

  @override
  String get statusEmojiPremiumCheers => 'نخب';

  @override
  String get statusEmojiPremiumDevil => 'شقي';

  @override
  String get vipIdentityEntry => 'هويتي المميزة';

  @override
  String get vipIdentityTitle => 'هويتي المميزة';

  @override
  String get vipIdentityNoneTitle => 'لا توجد ميزات هوية في مستواك';

  @override
  String get vipIdentityNoneMessage =>
      'التوقيع والآيدي الذهبي واليوزر المميز تأتي مع مستويات VIP التي تشملها.';

  @override
  String get vipIdentityNotHeld => 'هذه الميزة ليست ضمن عضويتك الآن.';

  @override
  String get vipIdentityNotYourClass => 'هذا خارج فئة مستواك.';

  @override
  String get vipIdentitySave => 'حفظ';

  @override
  String get vipIdentitySaved => 'تم الحفظ';

  @override
  String get vipSignatureTitle => 'التوقيع المتحرك';

  @override
  String vipSignatureSubtitle(int max) {
    return 'يظهر تحت منشوراتك ورسائلك العامة، حتى $max حرفاً.';
  }

  @override
  String get vipSignatureHint => 'اكتب توقيعك';

  @override
  String get vipSignatureClear => 'إزالة';

  @override
  String get vipSignatureCleared => 'أزيل التوقيع';

  @override
  String get vipSignatureBlocked => 'التوقيع يحتوي كلمة غير مسموحة.';

  @override
  String vipSignatureTooLong(int max) {
    return 'التوقيع أطول من $max حرفاً.';
  }

  @override
  String get vipSignatureTooShort => 'اكتب التوقيع أولاً.';

  @override
  String get vipSignatureInvalid => 'التوقيع سطر واحد بلا رموز مخفية.';

  @override
  String vipSignatureSemantics(String text) {
    return 'توقيع: $text';
  }

  @override
  String get vipGoldenIdTitle => 'الآيدي الذهبي';

  @override
  String vipGoldenIdSubtitle(String cls) {
    return 'اختر رقماً متاحاً من فئة: $cls';
  }

  @override
  String get vipGoldenIdNoClass => 'لم تُحدَّد فئة لهذه الميزة بعد.';

  @override
  String get vipGoldenIdNoneFree => 'لا توجد أرقام متاحة الآن من فئتك.';

  @override
  String vipGoldenIdPick(String number) {
    return 'اختيار $number';
  }

  @override
  String get vipGoldenIdTaken => 'هذا الرقم مأخوذ.';

  @override
  String vipGoldenIdTaken2(String number) {
    return 'أصبح $number آيديك الذهبي';
  }

  @override
  String get vipGoldenIdRelease => 'إرجاع';

  @override
  String get vipGoldenIdReleased => 'أُرجع الرقم';

  @override
  String get vipGoldenIdGrace =>
      'محفوظ لك بعد انتهاء العضوية؛ جدّد VIP لاستعادته قبل أن يعود للمخزون.';

  @override
  String get vipGoldenIdHint => 'آيدي ذهبي';

  @override
  String get vipGoldenClassRepeated => 'رقم مكرر';

  @override
  String vipGoldenClassDigits(int n) {
    return '$n أرقام';
  }

  @override
  String get vipPremiumTitle => 'يوزر مميز مجاني';

  @override
  String get vipPremiumSubtitle =>
      'اختر يوزراً مميزاً من فئة مستواك أو أقل؛ يبقى لك طوال العضوية.';

  @override
  String get vipPremiumNone => 'لا توجد أسماء متاحة الآن.';

  @override
  String vipPremiumClaim(String username) {
    return 'أخذ $username مجاناً';
  }

  @override
  String vipPremiumClaimed(String username) {
    return 'أصبح $username يوزرك';
  }

  @override
  String get errorLiveVipOnly => 'هذه الغرفة لأعضاء VIP من مستواها فما فوق';

  @override
  String get errorLivePinBusy => 'هناك رسالة مثبتة الآن، حاول بعد قليل';

  @override
  String get liveVipPinAction => 'تثبيت';

  @override
  String get liveVipPinRemove => 'إزالة';

  @override
  String liveVipPinnedBy(String name) {
    return 'مثبتة · $name';
  }

  @override
  String get liveVipPinUsedUp => 'استخدمت تثبيتات اليوم';

  @override
  String liveVipGreetingTitle(String level) {
    return 'VIP $level دخل البث';
  }

  @override
  String get liveVipGreetingAction => 'رحّب';

  @override
  String liveVipGreetingLine(String name) {
    return 'أهلاً وسهلاً بـ @$name 👑';
  }

  @override
  String get liveVipLockTitle => 'غرفة VIP خاصة';

  @override
  String liveVipLockBody(String tier) {
    return 'هذه الغرفة لأعضاء $tier فما فوق';
  }

  @override
  String get liveVipLockGetVip => 'اشترك في VIP';

  @override
  String get liveVipLockClose => 'حسناً';

  @override
  String get liveVipRoomToggle => 'غرفة VIP';

  @override
  String get liveVipRoomHint =>
      'يدخلها أعضاء VIP من المستوى الذي تختاره فما فوق';

  @override
  String get liveVipReserveAction => 'احجز لصديق';

  @override
  String get liveVipReserveTitle => 'قفل المقعد لصديق';

  @override
  String get liveVipReserveHint => 'اسم المستخدم';

  @override
  String get liveVipReserveConfirm => 'احجز';

  @override
  String liveVipReservedFor(String name) {
    return 'محجوز لـ $name';
  }

  @override
  String get liveVipReleaseAction => 'إلغاء الحجز';

  @override
  String get privacyVipTitle => 'امتيازات VIP';

  @override
  String get privacyVipHiddenVisit => 'زيارة خفية';

  @override
  String get privacyVipHiddenVisitHint =>
      'زياراتك للملفات لا تظهر في «من زار ملفي».';

  @override
  String get privacyVipRankingAnonymous => 'اسم مخفي في التصنيفات';

  @override
  String get privacyVipRankingAnonymousHint =>
      'تظهر «مجهول» في قوائم الترتيب والداعمين.';

  @override
  String get privacyVipKickMuteShield => 'حماية من طرد وكتم المشرف العادي';

  @override
  String get privacyVipKickMuteShieldHint =>
      'لا يطردك أو يكتمك مشرف الغرفة؛ يبقى المضيف وفريق كابسو قادرين.';

  @override
  String get errorVipProtected =>
      'هذا العضو محمي بامتياز VIP؛ يستطيع المضيف أو فريق كابسو فقط.';

  @override
  String get vipAnonymousName => 'مجهول';

  @override
  String get liveGiftAnonymousToggle => 'إهداء مجهول';

  @override
  String get liveGiftAnonymousOn => 'إهداء مجهول: يظهر اسمك «مجهول»';

  @override
  String get liveGiftAnonymousFrom => 'هدية من «مجهول»';

  @override
  String get liveGiftAnonymousHint =>
      'لن يُكشف لك المرسل؛ يبقى اسمه في سجل الفريق.';

  @override
  String get liveGiftAnonymousReport => 'إبلاغ عن المرسل';

  @override
  String get liveGiftAnonymousRefuse => 'رفض الهدايا المجهولة من هذا المرسل';

  @override
  String get liveGiftAnonymousRefused => 'لن تصلك هدايا مجهولة من هذا المرسل.';

  @override
  String get liveGiftReported => 'تم الإبلاغ، شكراً لك.';

  @override
  String get liveGiftTabVip => 'VIP';

  @override
  String get vipNowTitle => 'ما تمنحك ميزاتك الآن';

  @override
  String vipNowRockets(String count, String minutes) {
    return 'صواريخ هذا الشهر: $count × $minutes دقيقة';
  }

  @override
  String vipNowRocketsNext(String date) {
    return 'الدفعة التالية $date';
  }

  @override
  String vipNowFreeCp(String left, String perMonth) {
    return 'طلبات CP مجانية: $left من $perMonth متبقية هذا الشهر';
  }

  @override
  String vipNowMaxQuantity(String count) {
    return 'أرسل حتى $count هدية دفعة واحدة';
  }

  @override
  String vipNowVoice(String seconds) {
    return 'رسائل صوتية حتى $seconds ثانية';
  }

  @override
  String vipNowExclusive(String count) {
    return '$count هدايا حصرية في تبويب VIP';
  }

  @override
  String get vipNowPriority => 'دعم بأولوية — بلاغاتك ومحادثات الدعم أولاً';

  @override
  String get vipScheduledEntry => 'هدية مؤجلة';

  @override
  String vipScheduledEntrySub(String pending, String max) {
    return '$pending من $max بانتظار الإرسال';
  }

  @override
  String get vipScheduledEmptyTitle => 'لا هدايا مؤجلة';

  @override
  String get vipScheduledEmptyBody =>
      'اختر هدية وموعداً، وتصل في وقتها إلى المحادثة.';

  @override
  String get vipScheduledNew => 'جدولة هدية';

  @override
  String get vipScheduledTo => 'إلى (اسم المستخدم)';

  @override
  String get vipScheduledGift => 'الهدية';

  @override
  String get vipScheduledQuantity => 'الكمية';

  @override
  String get vipScheduledWhen => 'الموعد';

  @override
  String vipScheduledHold(String coins) {
    return 'تُحجز $coins الآن وتُرجع إن أُلغيت أو تعذّر الإرسال.';
  }

  @override
  String get vipScheduledSubmit => 'جدولة';

  @override
  String get vipScheduledDone => 'جُدولت الهدية';

  @override
  String get vipScheduledCancel => 'إلغاء الهدية';

  @override
  String get vipScheduledCancelled => 'أُلغيت الهدية وأُرجعت العملات';

  @override
  String get vipScheduledStatusPending => 'بانتظار الإرسال';

  @override
  String get vipScheduledStatusDelivered => 'أُرسلت';

  @override
  String get vipScheduledStatusCancelled => 'أُلغيت';

  @override
  String get vipScheduledStatusFailed => 'تعذّر الإرسال — أُرجعت العملات';

  @override
  String vipScheduledLine(String quantity, String gift, String name) {
    return '$quantity × $gift إلى $name';
  }

  @override
  String vipScheduledAt(String date) {
    return '$date';
  }

  @override
  String get vipScheduledNoPerkTitle => 'الهدية المؤجلة من ميزات VIP';

  @override
  String get vipScheduledTooMany => 'وصلت إلى الحد الأقصى من الهدايا المنتظرة';

  @override
  String get vipScheduledBadTime =>
      'اختر موعداً بعد 5 دقائق على الأقل وخلال سنة';

  @override
  String cpSendBodyFree(String left) {
    return 'مجاني بميزة VIP — $left طلبات مجانية متبقية هذا الشهر. لا تُرجع العملات لأنه لا يُخصم شيء.';
  }

  @override
  String get walletReasonVipScheduledGift => 'هدية مؤجلة (محجوزة)';

  @override
  String get walletReasonVipScheduledGiftRelease => 'هدية مؤجلة (أُرجعت)';

  @override
  String vipScheduledMeta(String when, String status) {
    return '$when · $status';
  }

  @override
  String vipScheduledGiftOption(String name, String coins) {
    return '$name · $coins';
  }

  @override
  String get vipAnimatedAvatarEntry => 'صورة متحركة';

  @override
  String get vipAnimatedAvatarIntro =>
      'سجّل 3 ثوانٍ لوجهك أو اختر مقطعاً من المعرض: نزيل الخلفية على هاتفك، وتظهر صورتك متحركة فوق اسمك في بطاقتك داخل الغرف.';

  @override
  String get vipAnimatedAvatarEmpty => 'لا توجد صورة متحركة بعد';

  @override
  String get vipAnimatedAvatarRecord => 'تسجيل';

  @override
  String get vipAnimatedAvatarRerecord => 'إعادة التسجيل';

  @override
  String get vipAnimatedAvatarSave => 'حفظ';

  @override
  String get vipAnimatedAvatarRemove => 'إزالة';

  @override
  String get vipAnimatedAvatarLook => 'انظر إلى الكاميرا وابتسم';

  @override
  String get vipAnimatedAvatarRecording => 'جارٍ التسجيل…';

  @override
  String get vipAnimatedAvatarProcessing => 'جارٍ إزالة الخلفية…';

  @override
  String get vipAnimatedAvatarPreview => 'هكذا ستظهر في بطاقتك';

  @override
  String get vipAnimatedAvatarNoPerson =>
      'لم نجد وجهك في المقطع. سجّل مجدداً في إضاءة جيدة وانظر إلى الكاميرا.';

  @override
  String get vipAnimatedAvatarCameraError =>
      'تعذّر فتح الكاميرا. اسمح للتطبيق باستخدام الكاميرا ثم حاول مجدداً.';

  @override
  String get vipAnimatedAvatarTooLarge => 'المقطع كبير جداً. سجّل مقطعاً أقصر.';

  @override
  String get vipAnimatedAvatarSaved => 'حُفظت صورتك المتحركة';

  @override
  String get vipAnimatedAvatarRemoved => 'أُزيلت صورتك المتحركة';

  @override
  String get notifAnimatedAvatarRemoved =>
      'أزال فريق الإشراف صورتك المتحركة لمخالفتها الإرشادات';

  @override
  String get vipAnimatedAvatarPick => 'اختيار من المعرض';

  @override
  String get vipAnimatedAvatarPickError =>
      'تعذّر قراءة هذا المقطع. اختر مقطعاً آخر.';

  @override
  String get vipAnimatedAvatarTrimTitle => 'اختر 3 ثوانٍ من المقطع';

  @override
  String get vipAnimatedAvatarTrimHint => 'حرّك الشريط لاختيار بداية الجزء';

  @override
  String get vipAnimatedAvatarTrimWhole =>
      'المقطع 3 ثوانٍ أو أقل: سيُستخدم كاملاً';

  @override
  String get vipAnimatedAvatarTrimUse => 'استخدام هذا الجزء';

  @override
  String get vipAnimatedAvatarTrimCancel => 'إلغاء';

  @override
  String get supportChatName => 'دعم كابسو';

  @override
  String get supportChatSubtitle => 'فريق كابسو يرد عليك هنا';

  @override
  String supportUnread(int count) {
    return 'دعم كابسو، ردود غير مقروءة: $count';
  }

  @override
  String get supportIntro =>
      'اكتب لنا ما تحتاجه: الشحن، الوكالات، مشكلة تقنية أو بلاغ. اختر الموضوع ثم أرسل رسالتك، وسيرد عليك فريق كابسو هنا.';

  @override
  String get supportPickTopic => 'اختر موضوع رسالتك';

  @override
  String get supportNewTicket => 'أُغلق طلبك السابق — اختر موضوع طلبك الجديد';

  @override
  String get supportPickTopicFirst => 'اختر الموضوع أولاً';

  @override
  String supportTopicOf(String topic) {
    return 'الموضوع: $topic';
  }

  @override
  String get supportComposerHint => 'اكتب رسالتك لفريق كابسو';

  @override
  String get supportReceiptReceived => 'تم الاستلام';

  @override
  String get supportReceiptRead => 'تمت القراءة';

  @override
  String get dmPin => 'تثبيت في الأعلى';

  @override
  String get dmUnpin => 'إلغاء التثبيت';

  @override
  String get dmPinnedDone => 'ثُبّتت المحادثة في الأعلى';

  @override
  String get dmUnpinned => 'أُلغي التثبيت';

  @override
  String dmPinLimit(int max) {
    return 'يمكنك تثبيت $max محادثات فقط. ألغِ تثبيت واحدة أولاً.';
  }

  @override
  String get dmPinOnline => 'متصل الآن';

  @override
  String get dmPinnedLabel => 'مثبّتة';

  @override
  String get dmPinActions => 'خيارات التثبيت';

  @override
  String get errorDmPinLimit =>
      'يمكنك تثبيت ٥ محادثات فقط. ألغِ تثبيت واحدة أولاً.';

  @override
  String get waInApp => 'داخل التطبيق';

  @override
  String get waInAppHint =>
      'محادثة «دعم كابسو» من داخل التطبيق — بلا نافذة ٢٤ ساعة وبلا قوالب؛ الرد نص أو صورة.';

  @override
  String get categoryQuranReciter => 'قارئ قرآن';

  @override
  String get categoryStoryteller => 'راوٍ';

  @override
  String get categoryWriter => 'كاتب';

  @override
  String get categoryJournalist => 'صحفي';

  @override
  String get categoryPhotographer => 'مصوّر';

  @override
  String get categoryActor => 'ممثل';

  @override
  String get categoryComedian => 'كوميدي';

  @override
  String get categoryCalligrapher => 'خطّاط';

  @override
  String get categoryDesigner => 'مصمّم';

  @override
  String get categoryChef => 'طاهٍ';

  @override
  String get categoryTeacher => 'معلّم / مدرّب';

  @override
  String get categoryDj => 'دي جي';

  @override
  String get categoryTraveler => 'رحّالة';

  @override
  String get categoryFamilyMusic => 'الموسيقى';

  @override
  String get categoryFamilyReciter => 'التلاوة والرواية';

  @override
  String get categoryFamilyWord => 'الكلمة';

  @override
  String get categoryFamilyVisual => 'الفنون البصرية';

  @override
  String get categoryFamilyPerformer => 'الأداء والمحتوى';

  @override
  String get categoryFamilySportsGames => 'الرياضة والألعاب';

  @override
  String get categoryFamilyLifestyle => 'أسلوب الحياة';

  @override
  String get categoryFamilyPublic => 'عام';

  @override
  String get featuredWorks => 'أعمالي';

  @override
  String get featuredRecitations => 'تلاواتي';

  @override
  String get featuredStories => 'حكاياتي';

  @override
  String get featuredPoems => 'قصائدي';

  @override
  String get featuredArticles => 'مقالاتي';

  @override
  String get featuredReports => 'تقاريري';

  @override
  String get featuredProgram => 'برنامجي';

  @override
  String get featuredGames => 'ألعابي';

  @override
  String get featuredAchievements => 'إنجازاتي';

  @override
  String get featuredGallery => 'معرضي';

  @override
  String get featuredMostViewed => 'الأكثر مشاهدة';

  @override
  String get featuredHighlights => 'المميز';

  @override
  String featuredPinIn(String section) {
    return 'تثبيت في «$section»';
  }

  @override
  String featuredUnpinFrom(String section) {
    return 'إلغاء التثبيت من «$section»';
  }

  @override
  String featuredPinned(String section) {
    return 'ثُبّت في «$section»';
  }

  @override
  String get featuredUnpinned => 'أُلغي التثبيت';

  @override
  String get featuredReorder => 'ترتيب';

  @override
  String get featuredReorderHint => 'اسحب لتغيير الترتيب. حتى ٦ منشورات.';

  @override
  String get featuredReorderSave => 'حفظ الترتيب';

  @override
  String get featuredEmptyOwn =>
      'ثبّت حتى ٦ من منشوراتك هنا من قائمة «⋯» في المنشور.';

  @override
  String get featuredAutoNote => 'أحدث منشوراتك — ثبّت ما تريد إظهاره هنا';

  @override
  String get featuredUpcoming => 'قادم';

  @override
  String get featuredPodcast => 'بودكاست';

  @override
  String featuredViews(String count) {
    return '$count مشاهدة';
  }

  @override
  String get featuredPlay => 'تشغيل';

  @override
  String get featuredReadMore => 'اقرأ المزيد';

  @override
  String categoryBadgeVerified(String category) {
    return 'فئة موثّقة: $category';
  }

  @override
  String get categoryVerifyRequest => 'طلب توثيق الفئة';

  @override
  String get categoryVerifyHint =>
      'بعد أن يوثّق فريق كابسو فئتك تأخذ صفحتك شكلها الخاص: لون وشارة وقسم مميّز في الأعلى.';

  @override
  String get categoryVerifyPending => 'طلب التوثيق قيد المراجعة';

  @override
  String get categoryVerifyCancel => 'إلغاء الطلب';

  @override
  String get categoryVerifyVerified => 'فئتك موثّقة';

  @override
  String categoryVerifyRejected(String reason) {
    return 'لم يُقبل طلبك: $reason';
  }

  @override
  String get categoryVerifySent => 'أُرسل طلب التوثيق إلى فريق كابسو';

  @override
  String get categoryVerifyChangeWarning => 'تغيير الفئة يزيل التوثيق.';

  @override
  String get categoryLockedNote =>
      'قفل فريق كابسو فئة حسابك، فلا يمكن تغييرها الآن.';

  @override
  String get errorFeaturedPinLimit =>
      'يمكنك تثبيت ٦ منشورات فقط هنا. ألغِ تثبيت واحد أولاً.';

  @override
  String get errorCategoryVerificationPending => 'لديك طلب توثيق قيد المراجعة.';

  @override
  String get errorAccountCategoryLocked => 'قفل فريق كابسو فئة حسابك.';

  @override
  String get notifCategoryVerified =>
      'وثّق فريق كابسو فئة حسابك — صفحتك الآن بشكلها الخاص';

  @override
  String get notifCategoryReviewed =>
      'راجع فريق كابسو فئة حسابك. افتح «تعديل الملف» لمعرفة التفاصيل';

  @override
  String get staffRoleTrustSafety => 'مراقبة المحتوى والأمان';

  @override
  String get staffRoleLiveOps => 'مدير عمليات البث';

  @override
  String get staffRoleTalent => 'مدير الوكالات والمواهب';

  @override
  String get staffRoleVipCare => 'دعم كبار الداعمين';

  @override
  String get staffRoleCommunity => 'المجتمع والفعاليات';

  @override
  String get staffOnShiftNow => 'في المناوبة الآن';

  @override
  String get staffScheduledHint => 'حسب جدول المناوبات في لوحة الإدارة.';

  @override
  String get staffMyRoles => 'أدواري';

  @override
  String get staffRolesAndShift => 'أدواري والمناوبة';

  @override
  String get staffOpsPanelHint => 'أدوات دورك في لوحة الإدارة.';

  @override
  String get settingsFollowUs => 'تابعنا';

  @override
  String get socialPlatformInstagram => 'إنستغرام';

  @override
  String get socialPlatformTiktok => 'تيك توك';

  @override
  String get socialPlatformX => 'إكس';

  @override
  String get socialPlatformFacebook => 'فيسبوك';

  @override
  String get socialPlatformYoutube => 'يوتيوب';

  @override
  String get socialPlatformSnapchat => 'سناب شات';

  @override
  String get socialPlatformTelegram => 'تيليجرام';

  @override
  String get socialPlatformWhatsapp => 'واتساب';

  @override
  String get socialPlatformThreads => 'ثريدز';

  @override
  String get socialPlatformLinkedin => 'لينكدإن';

  @override
  String get socialPlatformDiscord => 'ديسكورد';

  @override
  String get socialPlatformOther => 'موقع آخر';

  @override
  String get giftStaffRefused => 'حسابات فريق كابسو لا ترسل الهدايا.';

  @override
  String get errorStaffGiftRefused => 'حسابات فريق كابسو لا ترسل الهدايا.';

  @override
  String get staffCherriesCompanyOnly =>
      'حساب فريق كابسو يسحب الكرز عن طريق Kabso Live فقط: اطلب السحب من محفظة الكرز، ولا يمكن بيعه لوكيل.';

  @override
  String get errorStaffWithdrawalCompanyOnly =>
      'حساب فريق كابسو يسحب الكرز عن طريق Kabso Live فقط.';

  @override
  String get ownerProfitCompensations => 'تعويضات دعم كبار الداعمين (عملات)';

  @override
  String get badgeExplainKabsoTeam =>
      'شارة فريق كابسو — هذا الحساب من فريق عمل كابسو الرسمي';

  @override
  String badgeExplainWealthLevel(int level) {
    return 'مستوى الثروة $level';
  }

  @override
  String badgeExplainCharmLevel(int level) {
    return 'مستوى الجاذبية $level';
  }

  @override
  String badgeExplainWizardLevel(int level) {
    return 'مستوى الساحر $level';
  }

  @override
  String badgeExplainGamingLevel(int level) {
    return 'مستوى اللعب $level';
  }

  @override
  String badgeExplainRoomLevel(int level) {
    return 'مستوى الغرفة $level — مستوى جاذبية المضيف';
  }

  @override
  String badgeExplainVip(int tier) {
    return 'عضوية VIP $tier';
  }

  @override
  String badgeExplainGoldenId(String id) {
    return 'آيدي ذهبي $id — من مزايا عضوية VIP';
  }

  @override
  String badgeExplainVerification(String kind) {
    return 'شارة التوثيق: $kind — تُمنح تلقائياً عند تحقق الشروط';
  }

  @override
  String badgeExplainCategory(String category) {
    return 'فئة موثّقة: $category — وثّقها فريق كابسو';
  }

  @override
  String get badgeExplainFounder => 'شارة المؤسس — مؤسس Kabso Live';

  @override
  String badgeExplainRechargeTier(int tier) {
    return 'شارة الشحن اليومي — المستوى $tier، تظهر 24 ساعة بعد الشحن';
  }

  @override
  String badgeExplainRechargeAgent(String code) {
    return 'وكيل شحن معتمد في Kabso Live — $code';
  }

  @override
  String badgeExplainHostAgent(String code) {
    return 'وكيل مضيفين في Kabso Live — $code';
  }

  @override
  String badgeExplainItem(String name) {
    return 'شارة العنصر: $name';
  }

  @override
  String get badgeExplainCreatorLive =>
      'صانع محتوى — المضيف صانع محتوى في Kabso Live';

  @override
  String get badgeExplainHostTargetGifts => 'هدف الهدايا اليومي للمضيف';

  @override
  String get badgeExplainHostTargetLucky => 'هدف هدايا الحظ اليومي للمضيف';

  @override
  String get badgeExplainHost => 'المضيف — صاحب هذا البث';

  @override
  String get badgeExplainModerator => 'مشرف — يساعد المضيف في إدارة هذا البث';

  @override
  String get badgeExplainNewcomer => 'جديد — انضم إلى Kabso Live مؤخراً';

  @override
  String badgeExplainFamily(String name, int level) {
    return 'عائلة $name — المستوى $level';
  }

  @override
  String get waLangAR => 'عربي';

  @override
  String get waLangEN => 'English';

  @override
  String waLangLabel(String language) {
    return 'لغة العميل: $language';
  }

  @override
  String get ambProgrammeTitle => 'برنامج سفراء Kabso';

  @override
  String get ambProgrammeEntry => 'كن سفيراً لـ Kabso';

  @override
  String get ambProgrammeEntryHint =>
      'مثّل Kabso في منطقتك واربح عمولة على شحن أصدقائك النشطين';

  @override
  String get ambHeroTitle =>
      'سفير Kabso ليس مجرد ناشر إعلانات، بل ممثل Kabso في منطقته';

  @override
  String get ambWhatYouDo => 'ماذا يفعل السفير';

  @override
  String get ambDo1 => 'يجلب مستخدمين جدداً عبر رمزه ورابطه الشخصي';

  @override
  String get ambDo2 => 'ينشر محتوى ترويجياً على وسائل التواصل';

  @override
  String get ambDo3 => 'يعرّف بـ Kabso في بلده';

  @override
  String get ambDo4 => 'ينظّم حملات وفعاليات ومسابقات بالتنسيق مع الإدارة';

  @override
  String get ambWhatYouGet => 'ماذا يحصل عليه';

  @override
  String get ambGet1 => 'عمولة على الشحن المؤهل لأصدقائه النشطين';

  @override
  String get ambGet2 =>
      'مكافآت شهرية عند تحقيق الأهداف: كوينز أو أيام VIP أو عناصر';

  @override
  String get ambGet3 => 'شارة السفير الحصرية';

  @override
  String get ambGet4 => 'مستويات بمكافآت متصاعدة';

  @override
  String get ambLevelsTitle => 'المستويات';

  @override
  String ambLevelName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'BRONZE': 'برونزي',
      'SILVER': 'فضي',
      'GOLD': 'ذهبي',
      'DIAMOND': 'ماسي',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String ambLevelRequirement(String active, String coins) {
    return 'إحالات نشطة: $active · شحن: $coins كوينز شهرياً';
  }

  @override
  String ambLevelCommission(String pct) {
    return 'عمولة $pct';
  }

  @override
  String get ambRewardNone => 'بلا مكافأة شهرية';

  @override
  String ambRewardCoins(String amount) {
    return 'مكافأة: $amount كوينز';
  }

  @override
  String ambRewardVip(String tier, String days) {
    return 'مكافأة: $tier · أيام: $days';
  }

  @override
  String ambRewardItem(String days) {
    return 'مكافأة: عنصر حقيبة · أيام: $days';
  }

  @override
  String get ambRulesTitle => 'القواعد';

  @override
  String ambRuleWindow(String days) {
    return 'نافذة الإسناد بعد تسجيل الصديق (أيام): $days';
  }

  @override
  String ambRuleHold(String days) {
    return 'مدة الحجز قبل الدفع (أيام): $days';
  }

  @override
  String ambRuleActive(String days, String coins) {
    return 'الصديق النشط — عمر الحساب بالأيام: $days · الشحن بالكوينز: $coins';
  }

  @override
  String get ambRuleFraud =>
      'الإحالات الوهمية والدفع من حسابك والاسترجاع تلغي العمولة';

  @override
  String get ambRuleTrack =>
      'صديق يسجّل برمزك يُحتسب في برنامج السفراء بدلاً من مكافأة «دعوة الأصدقاء»';

  @override
  String get ambFormTitle => 'طلب الانضمام';

  @override
  String get ambCountry => 'البلد';

  @override
  String get ambCountryError => 'اختر بلدك';

  @override
  String get ambLinks => 'روابط حساباتك على التواصل الاجتماعي';

  @override
  String get ambAddLink => 'إضافة رابط';

  @override
  String get ambLinkError => 'أدخل رابطاً يبدأ بـ https://';

  @override
  String get ambAudience => 'حجم جمهورك (عدد المتابعين)';

  @override
  String get ambAudienceError => 'أدخل رقماً';

  @override
  String get ambMotivation => 'لماذا تريد أن تكون سفيراً؟';

  @override
  String get ambMotivationError => 'اكتب سبباً قصيراً';

  @override
  String get ambSubmit => 'إرسال الطلب';

  @override
  String get ambSent => 'تم إرسال طلبك';

  @override
  String get ambStatusPending => 'طلبك قيد المراجعة من الإدارة';

  @override
  String ambStatusRejected(String reason) {
    return 'لم تتم الموافقة على طلبك: $reason. يمكنك التقديم مرة أخرى.';
  }

  @override
  String get ambStatusStaff =>
      'حسابات فريق كابسو لا يمكنها الانضمام إلى برنامج السفراء';

  @override
  String get ambStatusNotActive => 'حسابك غير متاح للتقديم حالياً';

  @override
  String get ambSoon => 'البرنامج قريباً — ستتمكن من التقديم عند إطلاقه';

  @override
  String get ambYouAreAmbassador => 'أنت سفير Kabso';

  @override
  String get ambOpenDashboard => 'لوحة السفير';

  @override
  String get ambDashTitle => 'لوحة السفير';

  @override
  String get ambYourCode => 'رمزك ورابطك';

  @override
  String get ambCopy => 'نسخ';

  @override
  String get ambCopied => 'تم النسخ';

  @override
  String get ambShare => 'مشاركة';

  @override
  String ambShareText(String code, String link) {
    return 'انضم إلى Kabso Live برمزي $code: $link';
  }

  @override
  String ambCommissionRate(String pct) {
    return 'عمولتك $pct من الشحن المؤهل';
  }

  @override
  String ambNextLevel(String level) {
    return 'للوصول إلى $level هذا الشهر';
  }

  @override
  String ambNeedActive(String n) {
    return 'إحالات نشطة متبقية: $n';
  }

  @override
  String ambNeedCoins(String n) {
    return 'شحن متبقٍ بالكوينز: $n';
  }

  @override
  String get ambTopLevel => 'أنت في أعلى مستوى';

  @override
  String get ambThisMonth => 'أهداف هذا الشهر';

  @override
  String get ambActiveReferrals => 'إحالات نشطة';

  @override
  String get ambQualifiedTopups => 'شحن مؤهل (كوينز)';

  @override
  String get ambReferrals => 'إحالاتك';

  @override
  String get ambTotal => 'الكل';

  @override
  String get ambActive => 'نشطة';

  @override
  String get ambPendingRefs => 'بانتظار النشاط';

  @override
  String get ambCommissions => 'العمولات (كرز)';

  @override
  String get ambPending => 'قيد الحجز';

  @override
  String get ambHeld => 'معلّقة';

  @override
  String get ambPaid => 'مدفوعة';

  @override
  String get ambReversed => 'مسترجعة';

  @override
  String get ambPayoutsHeld => 'مدفوعاتك معلّقة مؤقتاً لمراجعة الإدارة';

  @override
  String get ambOff => 'البرنامج متوقف مؤقتاً — تُحفظ عمولاتك حتى يعود';

  @override
  String get ambHistory => 'السجل الشهري';

  @override
  String get ambRecent => 'آخر العمولات';

  @override
  String get ambNoHistory => 'لا شيء بعد';

  @override
  String ambCommissionStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'PENDING': 'قيد الحجز',
      'CREDITED': 'مدفوعة',
      'VOID': 'ملغاة',
      'REVERSED': 'مسترجعة',
      'other': '$status',
    });
    return '$_temp0';
  }

  @override
  String ambRewardStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'GRANTED': 'مُنحت المكافأة',
      'HELD': 'المكافأة معلّقة',
      'other': 'بلا مكافأة',
    });
    return '$_temp0';
  }

  @override
  String ambBadgeLabel(String level) {
    return 'سفير Kabso · $level';
  }

  @override
  String get meHubAmbassadors => 'سفراء Kabso';

  @override
  String get notifAmbassadorApproved =>
      'تمت الموافقة على طلبك: أصبحت سفيراً لـ Kabso Live';

  @override
  String get notifAmbassadorRejected =>
      'لم تتم الموافقة على طلبك في برنامج سفراء Kabso. افتح البرنامج لمعرفة السبب';

  @override
  String get notifAmbassadorLevelUp => 'ارتفع مستواك في برنامج سفراء Kabso';

  @override
  String get notifAmbassadorReward =>
      'حققت أهداف الشهر وحصلت على مكافأة السفير';

  @override
  String get errorAmbassadorApplicationNotAllowed =>
      'لا يمكنك التقديم إلى برنامج السفراء الآن';

  @override
  String ambBadgeExplainer(String level) {
    return 'سفير Kabso — المستوى $level';
  }

  @override
  String get ambStatusEnded =>
      'انتهت عضويتك في برنامج السفراء. لا يمكنك التقديم مجدداً إلا إذا أعادت الإدارة تعيينك.';

  @override
  String get notifAmbassadorEnded => 'انتهت عضويتك في برنامج سفراء Kabso';

  @override
  String get ownerProfitAmbassadorCommissions => 'عمولات السفراء';

  @override
  String get ownerProfitAmbassadorRewards => 'مكافآت السفراء (عملات)';

  @override
  String get pk4Title => 'PK رباعي';

  @override
  String get pk4Subtitle => '٢ ضد ٢ — فريقان من مضيفَين';

  @override
  String get pk4LobbyHint =>
      'ادعُ زميلاً ومنافسَين. تبدأ المعركة حين يقبل الأربعة.';

  @override
  String get pk4OpenLobby => 'افتح PK رباعي';

  @override
  String pk4LobbyEndsIn(String time) {
    return 'يُغلق خلال $time';
  }

  @override
  String get pk4SeatOrganiser => 'المنظِّم';

  @override
  String get pk4SeatTeammate => 'زميلك';

  @override
  String get pk4SeatOpponent => 'منافس';

  @override
  String get pk4SeatInvite => 'ادعُ مضيفاً';

  @override
  String pk4SeatWaiting(String seconds) {
    return 'بانتظار… $seconds';
  }

  @override
  String get pk4SeatReady => 'جاهز';

  @override
  String pk4InviteTo(String place) {
    return 'ادعُ إلى مكان: $place';
  }

  @override
  String get pk4PickPlace => 'اختر مكاناً فارغاً لتدعو إليه';

  @override
  String get pk4CancelLobby => 'إلغاء PK الرباعي';

  @override
  String get pk4LeaveLobby => 'مغادرة';

  @override
  String get pk4CancelInvite => 'سحب الدعوة';

  @override
  String get pk4IncomingTitle => 'دعوة PK رباعي';

  @override
  String pk4IncomingBody(String name, String place) {
    return '$name يدعوك إلى PK رباعي — $place';
  }

  @override
  String get pk4NoticeExpired => 'لم يكتمل العدد';

  @override
  String get pk4NoticeCancelled => 'ألغى المنظِّم PK الرباعي';

  @override
  String get pk4NoticeDeclined => 'اعتذر المضيف — ادعُ غيره';

  @override
  String get pk4NoticeInviteExpired => 'لم يرد المضيف — ادعُ غيره';

  @override
  String get pk4NoticeLeft => 'غادر مضيف مكانه';

  @override
  String get pk4Out => 'غادر';

  @override
  String pk4MuteHost(String name) {
    return 'كتم صوت $name';
  }

  @override
  String pk4UnmuteHost(String name) {
    return 'إلغاء كتم $name';
  }

  @override
  String get pk4ResultWin => 'فاز فريقكم';

  @override
  String get pk4ResultLoss => 'خسر فريقكم';

  @override
  String pk4ScoreSemantics(String own, String other) {
    return 'فريقكم $own، المنافسون $other';
  }

  @override
  String pk4PaneSemantics(String name, String score) {
    return '$name، $score نقطة';
  }

  @override
  String get pk4ConnectedHint =>
      'تم ربط المضيفين الأربعة — تبدأ المعركة حين يضغط أحدهم ابدأ';

  @override
  String get pk4EndConfirmBody =>
      'ستغادر المعركة ويكمل زميلك وحده؛ تبقى نقاطك لفريقك.';

  @override
  String get pk4ErrorLobbyClosed => 'لم تعد غرفة PK الرباعي مفتوحة';

  @override
  String get pk4ErrorSeatTaken => 'هذا المكان فيه دعوة بالفعل';

  @override
  String get bannerAmbassadorsStaff =>
      'برنامج سفراء Kabso غير متاح لحسابات فريق Kabso';
}
