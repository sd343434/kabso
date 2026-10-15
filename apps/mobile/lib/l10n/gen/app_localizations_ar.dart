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
  String get homeComingTitle => 'خلاصتك في الطريق';

  @override
  String get homeComingBody =>
      'ستتوفر متابعة الأشخاص وخلاصتك الرئيسية في المرحلة 2، والمنشورات في المرحلة 3.';

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
  String get liveComingTitle => 'غرف البث المباشر قادمة';

  @override
  String get liveComingBody =>
      'تتوفر مشاهدة البث المباشر واستضافته في المرحلة 6، ومعارك PK والهدايا في المرحلة 7.';

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
  String errorIdLabel(String requestId) {
    return 'رمز الخطأ: $requestId';
  }
}
