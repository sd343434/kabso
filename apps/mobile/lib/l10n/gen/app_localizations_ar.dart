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
  String get goLiveModeMulti => 'بث متعدد';

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
  String get liveBgHostTitle => 'البث مستمر';

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
  String goLiveShareText(String title, String username) {
    return 'أنا مباشر الآن على Kabso Live: «$title» — تابعني @$username';
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
  String get liveToolFluent => 'السلاسة';

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
  String get liveToolNewcomers => 'الجدد';

  @override
  String get liveToolDataCenter => 'مركز البيانات';

  @override
  String get liveToolLiveTime => 'وقت البث';

  @override
  String get errorInsufficientCoins =>
      'تحتاج 15 عملة لإرسال رسالة عامة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.';

  @override
  String get liveBulletToggle => 'رسالة عامة';

  @override
  String liveBulletHint(String coins) {
    return 'رسالة عامة بـ 15 عملة · رصيدك $coins';
  }

  @override
  String get liveBulletHintNoBalance => 'رسالة عامة بـ 15 عملة';

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
  String get bagTakeOff => 'خلع';

  @override
  String get bagLocked => 'لم تمتلكه بعد';

  @override
  String get bagEmptyTitle => 'حقيبتك فارغة';

  @override
  String get bagEmptyMessage => 'ستظهر هنا العناصر التي تحصل عليها.';

  @override
  String get bagOwnedSection => 'عناصرك';

  @override
  String get bagLockedSection => 'عناصر أخرى';

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
  String get liveHubBrand => 'Kabso';

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
  String get liveVoiceRoomsToLive => 'البث المباشر';

  @override
  String get liveHubFilterLabel => 'عوامل التصفية';

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
  String get liveToolFlash => 'الفلاش';

  @override
  String get liveToolDual => 'كاميرتان';

  @override
  String get liveToolHd => 'جودة عالية';

  @override
  String get liveToolSticker => 'ملصقات';

  @override
  String get liveToolInfo => 'المعلومات';

  @override
  String get liveToolTrafficCard => 'بطاقة الزيارات';

  @override
  String get liveToolMagic => 'مؤثرات';

  @override
  String get liveToolFillLight => 'إضاءة';

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
  String get goLiveSummaryPoints => 'النقاط';

  @override
  String get goLiveSummaryTaps => 'من النقرات';

  @override
  String get goLiveSummaryGifts => 'من الهدايا';

  @override
  String get goLiveSummarySupporters => 'الداعمون';

  @override
  String get goLiveSummaryViewers => 'المشاهدون عند الانتهاء';

  @override
  String goLiveSummaryCharm(String level) {
    return 'مستوى الجاذبية $level';
  }

  @override
  String goLiveSummaryCharmNext(String points) {
    return '$points للمستوى التالي';
  }

  @override
  String get goLiveSummaryData => 'بيانات البث';

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
    return '×$multiplier';
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
    return 'ربحت $coins عملة، وأعلى مضاعف ×$multiplier';
  }

  @override
  String get liveLuckyNoWin => 'لا ربح هذه المرة';

  @override
  String liveLuckyBanner(String name, String multiplier, String coins) {
    return '$name ربح ×$multiplier: $coins عملة';
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
  String get liveWishNoteTitle => 'أمنيات';

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
}
