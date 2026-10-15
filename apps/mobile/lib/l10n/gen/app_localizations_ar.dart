// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'كابسو لايف';

  @override
  String get brandWordmarkPrimary => 'Kabso';

  @override
  String get brandWordmarkAccent => 'Live';

  @override
  String get brandSemanticLabel => 'كابسو لايف';

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
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'مرحبًا بعودتك! سجّل الدخول للمتابعة.';

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
  String get registerTitle => 'أنشئ حسابك';

  @override
  String get registerSubtitle => 'انضم إلى كابسو لايف خلال دقيقة.';

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
  String get registerPasswordLabel => 'كلمة المرور';

  @override
  String get registerPasswordHelper => 'من 8 إلى 128 حرفًا';

  @override
  String get registerSubmit => 'إنشاء الحساب';

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
  String get passwordShow => 'إظهار كلمة المرور';

  @override
  String get passwordHide => 'إخفاء كلمة المرور';

  @override
  String get forgotTitle => 'استعادة كلمة المرور';

  @override
  String get forgotSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل لك تعليمات إعادة التعيين.';

  @override
  String get forgotEmailLabel => 'البريد الإلكتروني';

  @override
  String get forgotSubmit => 'إرسال التعليمات';

  @override
  String get forgotConfirmationTitle => 'تحقّق من بريدك';

  @override
  String forgotConfirmationBody(String email) {
    return 'إذا كان هناك حساب مرتبط بـ $email فقد أرسلنا إليه تعليمات إعادة تعيين كلمة المرور.';
  }

  @override
  String get forgotBackToLogin => 'العودة إلى تسجيل الدخول';

  @override
  String get verifyTitle => 'أكّد بريدك الإلكتروني';

  @override
  String verifyBody(String email) {
    return 'أرسلنا رابط تأكيد إلى $email. افتح الرابط لتأكيد حسابك.';
  }

  @override
  String get verifyResend => 'إعادة إرسال الرسالة';

  @override
  String get verifyResent => 'تم إرسال رسالة التأكيد';

  @override
  String get verifyContinue => 'المتابعة إلى التطبيق';

  @override
  String get validationRequired => 'هذا الحقل مطلوب';

  @override
  String get validationEmailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String validationTooShort(int min) {
    return 'يجب ألا يقل عن $min أحرف';
  }

  @override
  String validationTooLong(int max) {
    return 'يجب ألا يزيد عن $max حرفًا';
  }

  @override
  String get validationUsernameFormat =>
      'استخدم أحرفًا إنجليزية صغيرة وأرقامًا و . و _ فقط، ولا تبدأ أو تنتهي بـ . أو _';

  @override
  String get validationInvalid => 'القيمة غير صالحة';

  @override
  String get sessionEndedBanner => 'انتهت جلستك. سجّل الدخول مرة أخرى.';

  @override
  String get accountSuspendedBanner => 'تم إيقاف هذا الحساب.';

  @override
  String get splashRestoreFailed => 'تعذّرت استعادة جلستك.';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDiscover => 'استكشف';

  @override
  String get navCreate => 'إنشاء';

  @override
  String get navLive => 'مباشر';

  @override
  String get navProfile => 'حسابي';

  @override
  String get homeComingTitle => 'خلاصتك في الطريق';

  @override
  String get discoverComingTitle => 'الاستكشاف قادم';

  @override
  String get createComingTitle => 'الإنشاء قادم';

  @override
  String get createComingBody =>
      'منشورات الصور تصل في المرحلة 3، والفيديوهات القصيرة في المرحلة 5.';

  @override
  String get liveComingTitle => 'البث المباشر قادم';

  @override
  String get profileTitle => 'حسابي';

  @override
  String get profileEmailVerified => 'البريد الإلكتروني مؤكَّد';

  @override
  String get profileEmailNotVerified => 'البريد الإلكتروني غير مؤكَّد';

  @override
  String get profileResendVerification => 'إعادة إرسال رسالة التأكيد';

  @override
  String profileUsername(String username) {
    return '‎@$username‎';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSessions => 'الجلسات النشطة';

  @override
  String get sessionsCurrent => 'هذا الجهاز';

  @override
  String get sessionUnknownDevice => 'جهاز غير معروف';

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
  String get logoutConfirmTitle => 'تسجيل الخروج من كابسو لايف؟';

  @override
  String get logoutConfirmBody =>
      'ستحتاج إلى تسجيل الدخول مرة أخرى على هذا الجهاز.';

  @override
  String get errorValidationFailed =>
      'بعض المعلومات غير صحيحة. راجعها وحاول مجددًا.';

  @override
  String get errorAuthUnauthenticated => 'يلزم تسجيل الدخول للمتابعة.';

  @override
  String get errorAuthInvalidCredentials =>
      'البريد الإلكتروني أو اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get errorAuthRefreshInvalid => 'انتهت جلستك. سجّل الدخول مرة أخرى.';

  @override
  String get errorAuthForbidden => 'ليس لديك صلاحية للقيام بذلك.';

  @override
  String get errorAccountSuspended => 'تم إيقاف هذا الحساب.';

  @override
  String get errorNotFound => 'لم نعثر على ما تبحث عنه.';

  @override
  String get errorUsernameTaken => 'اسم المستخدم هذا غير متاح.';

  @override
  String get errorIdempotencyConflict =>
      'تم إرسال هذا الطلب من قبل ببيانات مختلفة.';

  @override
  String get errorTokenExpired =>
      'انتهت صلاحية هذا الرابط أو تم استخدامه بالفعل.';

  @override
  String get errorTokenInvalid => 'هذا الرابط غير صالح.';

  @override
  String get errorInternal => 'حدث خطأ في الخادم. حاول مرة أخرى لاحقًا.';

  @override
  String get errorServiceUnavailable =>
      'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد قليل.';

  @override
  String get errorNetworkOffline =>
      'لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مجددًا.';

  @override
  String get errorNetworkTimeout =>
      'استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get errorEmailTaken =>
      'لا يمكن استخدام هذا البريد الإلكتروني لإنشاء حساب جديد. جرّب تسجيل الدخول أو إعادة تعيين كلمة المرور.';

  @override
  String get errorRateLimited =>
      'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String errorRateLimitedRetryIn(String wait) {
    return 'محاولات كثيرة. حاول مرة أخرى بعد $wait.';
  }

  @override
  String errorServiceBusyRetryIn(String wait) {
    return 'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد $wait.';
  }

  @override
  String errorIdLabel(String requestId) {
    return 'رمز الخطأ: $requestId';
  }

  @override
  String get homeComingBody =>
      'ستتوفر متابعة الأشخاص وخلاصتك الرئيسية في المرحلة 2، والمنشورات في المرحلة 3.';

  @override
  String get discoverComingBody =>
      'يتوفر البحث عن الأشخاص في المرحلة 2، والبثوث والفيديوهات وصنّاع المحتوى الرائجون في المرحلة 9.';

  @override
  String get liveComingBody =>
      'تتوفر مشاهدة البث المباشر واستضافته في المرحلة 6، ومعارك PK والهدايا في المرحلة 7.';

  @override
  String get profileContentComingTitle => 'ستظهر منشوراتك هنا';

  @override
  String get profileContentComingBody =>
      'يتوفر تعديل الملف الشخصي والمتابعون في المرحلة 2، والمنشورات في المرحلة 3، والقصص واللقطات المميزة في المرحلة 4.';

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
  String get sessionsRevoked => 'تم إنهاء الجلسة';

  @override
  String get sessionsAlreadyEnded => 'كانت هذه الجلسة منتهية بالفعل';

  @override
  String get sessionsNoOthers => 'حسابك مسجَّل الدخول على هذا الجهاز فقط.';
}
