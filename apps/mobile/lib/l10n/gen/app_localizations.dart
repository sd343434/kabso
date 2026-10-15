import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name shown by the OS task switcher.
  ///
  /// In ar, this message translates to:
  /// **'كابسو لايف'**
  String get appTitle;

  /// First word of the text wordmark placeholder (brand name, not translated).
  ///
  /// In ar, this message translates to:
  /// **'Kabso'**
  String get brandWordmarkPrimary;

  /// Accent word of the text wordmark placeholder (brand name, not translated).
  ///
  /// In ar, this message translates to:
  /// **'Live'**
  String get brandWordmarkAccent;

  /// Screen reader label for the wordmark.
  ///
  /// In ar, this message translates to:
  /// **'كابسو لايف'**
  String get brandSemanticLabel;

  /// No description provided for @actionRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// No description provided for @actionContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get actionContinue;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل…'**
  String get loading;

  /// No description provided for @errorTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما'**
  String get errorTitle;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا بعودتك! سجّل الدخول للمتابعة.'**
  String get loginSubtitle;

  /// No description provided for @loginIdentifierLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو اسم المستخدم'**
  String get loginIdentifierLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get loginPasswordLabel;

  /// No description provided for @loginSubmit.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginSubmit;

  /// No description provided for @loginForgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get loginForgotPassword;

  /// No description provided for @loginNoAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get loginNoAccount;

  /// No description provided for @loginCreateAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get loginCreateAccount;

  /// No description provided for @registerTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حسابك'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى كابسو لايف خلال دقيقة.'**
  String get registerSubtitle;

  /// No description provided for @registerEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get registerEmailLabel;

  /// No description provided for @registerUsernameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get registerUsernameLabel;

  /// No description provided for @registerUsernameHelper.
  ///
  /// In ar, this message translates to:
  /// **'من 3 إلى 30 حرفًا: أحرف إنجليزية صغيرة وأرقام و . و _'**
  String get registerUsernameHelper;

  /// No description provided for @registerDisplayNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الظاهر'**
  String get registerDisplayNameLabel;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordHelper.
  ///
  /// In ar, this message translates to:
  /// **'من 8 إلى 128 حرفًا'**
  String get registerPasswordHelper;

  /// No description provided for @registerSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get registerSubmit;

  /// No description provided for @registerHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟'**
  String get registerHaveAccount;

  /// No description provided for @registerSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get registerSignIn;

  /// No description provided for @usernameChecking.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من توفر الاسم…'**
  String get usernameChecking;

  /// No description provided for @usernameAvailable.
  ///
  /// In ar, this message translates to:
  /// **'‎@{username}‎ متاح'**
  String usernameAvailable(String username);

  /// No description provided for @usernameTaken.
  ///
  /// In ar, this message translates to:
  /// **'‎@{username}‎ مستخدم بالفعل'**
  String usernameTaken(String username);

  /// No description provided for @usernameCheckFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من توفر الاسم الآن'**
  String get usernameCheckFailed;

  /// No description provided for @passwordShow.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get passwordHide;

  /// No description provided for @forgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة كلمة المرور'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني وسنرسل لك تعليمات إعادة التعيين.'**
  String get forgotSubtitle;

  /// No description provided for @forgotEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get forgotEmailLabel;

  /// No description provided for @forgotSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التعليمات'**
  String get forgotSubmit;

  /// No description provided for @forgotConfirmationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من بريدك'**
  String get forgotConfirmationTitle;

  /// No description provided for @forgotConfirmationBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان هناك حساب مرتبط بـ {email} فقد أرسلنا إليه تعليمات إعادة تعيين كلمة المرور.'**
  String forgotConfirmationBody(String email);

  /// No description provided for @forgotBackToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى تسجيل الدخول'**
  String get forgotBackToLogin;

  /// No description provided for @verifyTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكّد بريدك الإلكتروني'**
  String get verifyTitle;

  /// No description provided for @verifyBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رابط تأكيد إلى {email}. افتح الرابط لتأكيد حسابك.'**
  String verifyBody(String email);

  /// No description provided for @verifyResend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرسالة'**
  String get verifyResend;

  /// No description provided for @verifyResent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رسالة التأكيد'**
  String get verifyResent;

  /// No description provided for @verifyContinue.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة إلى التطبيق'**
  String get verifyContinue;

  /// No description provided for @validationRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get validationRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدًا إلكترونيًا صحيحًا'**
  String get validationEmailInvalid;

  /// No description provided for @validationTooShort.
  ///
  /// In ar, this message translates to:
  /// **'يجب ألا يقل عن {min} أحرف'**
  String validationTooShort(int min);

  /// No description provided for @validationTooLong.
  ///
  /// In ar, this message translates to:
  /// **'يجب ألا يزيد عن {max} حرفًا'**
  String validationTooLong(int max);

  /// No description provided for @validationUsernameFormat.
  ///
  /// In ar, this message translates to:
  /// **'استخدم أحرفًا إنجليزية صغيرة وأرقامًا و . و _ فقط، ولا تبدأ أو تنتهي بـ . أو _'**
  String get validationUsernameFormat;

  /// No description provided for @validationInvalid.
  ///
  /// In ar, this message translates to:
  /// **'القيمة غير صالحة'**
  String get validationInvalid;

  /// No description provided for @sessionEndedBanner.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. سجّل الدخول مرة أخرى.'**
  String get sessionEndedBanner;

  /// No description provided for @accountSuspendedBanner.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف هذا الحساب.'**
  String get accountSuspendedBanner;

  /// No description provided for @splashRestoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت استعادة جلستك.'**
  String get splashRestoreFailed;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navDiscover.
  ///
  /// In ar, this message translates to:
  /// **'استكشف'**
  String get navDiscover;

  /// No description provided for @navCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get navCreate;

  /// No description provided for @navLive.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get navLive;

  /// No description provided for @navProfile.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navProfile;

  /// No description provided for @homeComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'خلاصتك في الطريق'**
  String get homeComingTitle;

  /// No description provided for @homeComingBody.
  ///
  /// In ar, this message translates to:
  /// **'منشورات وقصص من تتابعهم تصل في المرحلة 2.'**
  String get homeComingBody;

  /// No description provided for @discoverComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاستكشاف قادم'**
  String get discoverComingTitle;

  /// No description provided for @discoverComingBody.
  ///
  /// In ar, this message translates to:
  /// **'البحث وصنّاع المحتوى الرائجون يصلون في المرحلة 9.'**
  String get discoverComingBody;

  /// No description provided for @createComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإنشاء قادم'**
  String get createComingTitle;

  /// No description provided for @createComingBody.
  ///
  /// In ar, this message translates to:
  /// **'منشورات الصور تصل في المرحلة 3، والفيديوهات القصيرة في المرحلة 5.'**
  String get createComingBody;

  /// No description provided for @liveComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر قادم'**
  String get liveComingTitle;

  /// No description provided for @liveComingBody.
  ///
  /// In ar, this message translates to:
  /// **'بدء البث ومشاهدة البثوث تصل في المرحلة 6.'**
  String get liveComingBody;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get profileTitle;

  /// No description provided for @profileEmailVerified.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني مؤكَّد'**
  String get profileEmailVerified;

  /// No description provided for @profileEmailNotVerified.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير مؤكَّد'**
  String get profileEmailNotVerified;

  /// No description provided for @profileResendVerification.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال رسالة التأكيد'**
  String get profileResendVerification;

  /// No description provided for @profileContentComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملفك الشخصي قيد البناء'**
  String get profileContentComingTitle;

  /// No description provided for @profileContentComingBody.
  ///
  /// In ar, this message translates to:
  /// **'منشوراتك ومتابعوك ومقتطفاتك تصل في المرحلة 2.'**
  String get profileContentComingBody;

  /// No description provided for @profileUsername.
  ///
  /// In ar, this message translates to:
  /// **'‎@{username}‎'**
  String profileUsername(String username);

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'النظام'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsSessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات النشطة'**
  String get settingsSessions;

  /// No description provided for @sessionsCurrent.
  ///
  /// In ar, this message translates to:
  /// **'هذا الجهاز'**
  String get sessionsCurrent;

  /// No description provided for @sessionsLastActive.
  ///
  /// In ar, this message translates to:
  /// **'آخر نشاط: {date}'**
  String sessionsLastActive(String date);

  /// No description provided for @sessionsRevoke.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get sessionsRevoke;

  /// No description provided for @sessionsRevokeConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج من هذا الجهاز؟'**
  String get sessionsRevokeConfirmTitle;

  /// No description provided for @sessionsRevokeConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُطلب من هذا الجهاز تسجيل الدخول من جديد.'**
  String get sessionsRevokeConfirmBody;

  /// No description provided for @sessionsRevoked.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل خروج الجهاز'**
  String get sessionsRevoked;

  /// No description provided for @sessionsNoOthers.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات نشطة أخرى'**
  String get sessionsNoOthers;

  /// No description provided for @sessionUnknownDevice.
  ///
  /// In ar, this message translates to:
  /// **'جهاز غير معروف'**
  String get sessionUnknownDevice;

  /// No description provided for @platformAndroid.
  ///
  /// In ar, this message translates to:
  /// **'أندرويد'**
  String get platformAndroid;

  /// No description provided for @platformIos.
  ///
  /// In ar, this message translates to:
  /// **'iOS'**
  String get platformIos;

  /// No description provided for @platformWeb.
  ///
  /// In ar, this message translates to:
  /// **'الويب'**
  String get platformWeb;

  /// No description provided for @platformOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get platformOther;

  /// No description provided for @settingsAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get settingsAccount;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج من كابسو لايف؟'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى تسجيل الدخول مرة أخرى على هذا الجهاز.'**
  String get logoutConfirmBody;

  /// No description provided for @errorValidationFailed.
  ///
  /// In ar, this message translates to:
  /// **'بعض المعلومات غير صحيحة. راجعها وحاول مجددًا.'**
  String get errorValidationFailed;

  /// No description provided for @errorAuthUnauthenticated.
  ///
  /// In ar, this message translates to:
  /// **'يلزم تسجيل الدخول للمتابعة.'**
  String get errorAuthUnauthenticated;

  /// No description provided for @errorAuthInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو اسم المستخدم أو كلمة المرور غير صحيحة.'**
  String get errorAuthInvalidCredentials;

  /// No description provided for @errorAuthRefreshInvalid.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. سجّل الدخول مرة أخرى.'**
  String get errorAuthRefreshInvalid;

  /// No description provided for @errorAuthForbidden.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية للقيام بذلك.'**
  String get errorAuthForbidden;

  /// No description provided for @errorAccountSuspended.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف هذا الحساب.'**
  String get errorAccountSuspended;

  /// No description provided for @errorNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نعثر على ما تبحث عنه.'**
  String get errorNotFound;

  /// No description provided for @errorEmailTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد الإلكتروني مسجّل بالفعل.'**
  String get errorEmailTaken;

  /// No description provided for @errorUsernameTaken.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم هذا غير متاح.'**
  String get errorUsernameTaken;

  /// No description provided for @errorIdempotencyConflict.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال هذا الطلب من قبل ببيانات مختلفة.'**
  String get errorIdempotencyConflict;

  /// No description provided for @errorTokenExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية هذا الرابط أو تم استخدامه بالفعل.'**
  String get errorTokenExpired;

  /// No description provided for @errorTokenInvalid.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط غير صالح.'**
  String get errorTokenInvalid;

  /// No description provided for @errorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة جدًا. انتظر قليلًا ثم حاول مجددًا.'**
  String get errorRateLimited;

  /// No description provided for @errorInternal.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الخادم. حاول مرة أخرى لاحقًا.'**
  String get errorInternal;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد قليل.'**
  String get errorServiceUnavailable;

  /// 503 with Retry-After; wait is durationSeconds or durationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد {wait}.'**
  String errorServiceBusyRetryIn(String wait);

  /// 429 with Retry-After; wait is durationSeconds or durationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة جدًا. حاول مرة أخرى بعد {wait}.'**
  String errorRateLimitedRetryIn(String wait);

  /// No description provided for @durationSeconds.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ثانية واحدة} =2{ثانيتين} few{{count} ثوانٍ} many{{count} ثانية} other{{count} ثانية}}'**
  String durationSeconds(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة واحدة} =2{دقيقتين} few{{count} دقائق} many{{count} دقيقة} other{{count} دقيقة}}'**
  String durationMinutes(int count);

  /// No description provided for @errorNetworkOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت. تحقّق من اتصالك وحاول مجددًا.'**
  String get errorNetworkOffline;

  /// No description provided for @errorNetworkTimeout.
  ///
  /// In ar, this message translates to:
  /// **'استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.'**
  String get errorNetworkTimeout;

  /// No description provided for @errorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. حاول مرة أخرى.'**
  String get errorUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
