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
  String get loginIdentifierLabel => 'البريد الإلكتروني أو اسم المستخدم';

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
  String get kabiEmojiHi => 'هلا';

  @override
  String get kabiEmojiLove => 'حب';

  @override
  String get kabiEmojiLol => 'ضحك';

  @override
  String get kabiEmojiWow => 'واو';

  @override
  String get kabiEmojiSad => 'حزين';

  @override
  String get kabiEmojiAngry => 'معصّب';

  @override
  String get kabiEmojiWink => 'غمزة';

  @override
  String get kabiEmojiLive => 'لايف';

  @override
  String get kabiEmojiCool => 'كشخة';

  @override
  String get kabiEmojiDizzy => 'دايخ';

  @override
  String get kabiEmojiSleepy => 'نعسان';

  @override
  String get kabiEmojiSilly => 'مهبول';

  @override
  String get kabiEmojiShy => 'مستحي';

  @override
  String get kabiEmojiThink => 'يفكر';

  @override
  String get kabiEmojiParty => 'احتفال';

  @override
  String get kabiEmojiDead => 'مت ضحك';

  @override
  String get kabiEmojiMelt => 'ذايب';

  @override
  String get kabiEmojiKiss => 'بوسة';

  @override
  String get kabiEmojiPickerTitle => 'إيموجي كابي';

  @override
  String get kabiEmojiButton => 'إيموجي';

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
  String get chatVoiceSoon => 'الرسائل الصوتية قريباً';

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
  String get levelsIntro =>
      'تزيد نقاطك من الهدايا والإنفاق في الألعاب بعد تأكيدها. لكل مستوى نقاطه الخاصة.';

  @override
  String get levelsPreparing =>
      'المستويات قيد التجهيز. ستظهر نقاطك هنا عند تفعيل الهدايا والألعاب.';

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
  String levelsToNext(String points) {
    return '$points للمستوى التالي';
  }

  @override
  String levelsToNamed(String points, String level) {
    return '$points نقطة للوصول إلى $level';
  }

  @override
  String get levelsMax => 'أعلى مستوى';

  @override
  String get levelsLadder => 'كل المستويات';

  @override
  String get levelsCurrent => 'مستواك';

  @override
  String get levelsLoadError => 'تعذّر تحميل المستويات';

  @override
  String get navPosts => 'المنشورات';

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
}
