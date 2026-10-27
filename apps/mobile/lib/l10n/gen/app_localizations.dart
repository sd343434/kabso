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

  /// App name (T2: Latin script in Arabic until B8).
  ///
  /// In ar, this message translates to:
  /// **'Kabso Live'**
  String get appTitle;

  /// Wordmark first word (brand, not translated).
  ///
  /// In ar, this message translates to:
  /// **'Kabso'**
  String get brandWordmarkPrimary;

  /// Wordmark accent word (brand, not translated).
  ///
  /// In ar, this message translates to:
  /// **'Live'**
  String get brandWordmarkAccent;

  /// Screen reader label for the wordmark.
  ///
  /// In ar, this message translates to:
  /// **'Kabso Live'**
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

  /// Arabic in its own script.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// English in its own script.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSwitchHint.
  ///
  /// In ar, this message translates to:
  /// **'يغيّر لغة التطبيق'**
  String get languageSwitchHint;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك وكمّل من حيث وقفت'**
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
  /// **'ما عندك حساب؟'**
  String get loginNoAccount;

  /// No description provided for @loginCreateAccount.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حساباً'**
  String get loginCreateAccount;

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

  /// No description provided for @registerTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حسابك'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى Kabso Live خلال دقيقة.'**
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

  /// No description provided for @registerDisplayNameHelper.
  ///
  /// In ar, this message translates to:
  /// **'اسمك كما يراه الآخرون. حتى 50 حرفًا، ويمكنك استخدام الرموز التعبيرية.'**
  String get registerDisplayNameHelper;

  /// Grapheme counter (Latin digits).
  ///
  /// In ar, this message translates to:
  /// **'{count}/50'**
  String displayNameCounter(int count);

  /// No description provided for @displayNameTooLong.
  ///
  /// In ar, this message translates to:
  /// **'هذا الاسم طويل جدًا. استخدم 50 حرفًا كحدّ أقصى (بعض الرموز التعبيرية تُحتسب أكثر من حرف).'**
  String get displayNameTooLong;

  /// No description provided for @displayNameInvalid.
  ///
  /// In ar, this message translates to:
  /// **'يحتوي هذا الاسم على أحرف لا يمكن استخدامها. استخدم الحروف والأرقام والمسافات والرموز التعبيرية.'**
  String get displayNameInvalid;

  /// reserved_term; never hints at the reserved list.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن استخدام هذا الاسم. اختر اسمًا آخر.'**
  String get displayNameReserved;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordHelper.
  ///
  /// In ar, this message translates to:
  /// **'8 أحرف على الأقل'**
  String get registerPasswordHelper;

  /// No description provided for @registerSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get registerSubmit;

  /// No description provided for @registerCodeNotice.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل إلى بريدك الإلكتروني رمزًا من 8 أرقام لتأكيد عنوانك.'**
  String get registerCodeNotice;

  /// Links added once B7 URLs exist.
  ///
  /// In ar, this message translates to:
  /// **'بإنشائك حسابًا، فإنك توافق على الشروط وسياسة الخصوصية.'**
  String get registerTerms;

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
  /// **'‎@{username}‎ غير متاح. جرّب اسمًا آخر.'**
  String usernameTaken(String username);

  /// No description provided for @usernameCheckFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق الآن. يمكنك المتابعة على أي حال.'**
  String get usernameCheckFailed;

  /// No description provided for @usernameTooShort.
  ///
  /// In ar, this message translates to:
  /// **'استخدم 3 أحرف على الأقل'**
  String get usernameTooShort;

  /// No description provided for @usernameTooLong.
  ///
  /// In ar, this message translates to:
  /// **'استخدم 30 حرفًا أو أقل'**
  String get usernameTooLong;

  /// No description provided for @usernameBadChars.
  ///
  /// In ar, this message translates to:
  /// **'استخدم فقط a–z و0–9 والنقطة (.) والشرطة السفلية (_)'**
  String get usernameBadChars;

  /// No description provided for @usernameBadEdges.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن أن يبدأ أو ينتهي بنقطة أو شرطة سفلية'**
  String get usernameBadEdges;

  /// No description provided for @codeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من بريدك الإلكتروني'**
  String get codeTitle;

  /// Never implies whether the address has an account.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان من الممكن استخدام {email} لإنشاء حساب جديد، فقد أرسلنا إليه رمزًا من 8 أرقام. أدخل الرمز أدناه.'**
  String codeBody(String email);

  /// No description provided for @codeChangeEmail.
  ///
  /// In ar, this message translates to:
  /// **'تغيير البريد الإلكتروني'**
  String get codeChangeEmail;

  /// No description provided for @codeFieldLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرمز المكوّن من 8 أرقام'**
  String get codeFieldLabel;

  /// No description provided for @codeFieldHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز الوارد في البريد أو الصقه'**
  String get codeFieldHint;

  /// No description provided for @codeExpiryHint.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي صلاحية الرمز خلال 30 دقيقة. تحقّق من مجلد الرسائل غير المرغوب فيها إن لم تجده.'**
  String get codeExpiryHint;

  /// No description provided for @codeMaybeExpired.
  ///
  /// In ar, this message translates to:
  /// **'ربما انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.'**
  String get codeMaybeExpired;

  /// No description provided for @codePasteInvalid.
  ///
  /// In ar, this message translates to:
  /// **'يتكوّن الرمز من 8 أرقام. تحقّق منه وحاول مرة أخرى.'**
  String get codePasteInvalid;

  /// No description provided for @codeSubmit.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get codeSubmit;

  /// No description provided for @codeResend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز جديد'**
  String get codeResend;

  /// {time} = m:ss, Latin digits.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز جديد بعد {time}'**
  String codeResendIn(String time);

  /// No description provided for @codeResent.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان من الممكن استخدام هذا البريد، فسيصلك رمز جديد قريبًا. لم تعد الرموز السابقة صالحة.'**
  String get codeResent;

  /// No description provided for @codeHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟'**
  String get codeHaveAccount;

  /// No description provided for @codeLogIn.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول'**
  String get codeLogIn;

  /// No description provided for @codeWelcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا بك في Kabso Live'**
  String get codeWelcome;

  /// No description provided for @errCodeInvalid.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرمز غير صحيح أو انتهت صلاحيته.'**
  String get errCodeInvalid;

  /// No description provided for @errCodeInvalidRepeated.
  ///
  /// In ar, this message translates to:
  /// **'ما زال لا يعمل؟ اطلب رمزًا جديدًا واستخدم أحدث رسالة.'**
  String get errCodeInvalidRepeated;

  /// No description provided for @errUsernameTakenDuringVerify.
  ///
  /// In ar, this message translates to:
  /// **'حجز شخص آخر اسم المستخدم هذا قبل أن تُكمل. اختر اسمًا آخر وسنرسل إليك رمزًا جديدًا.'**
  String get errUsernameTakenDuringVerify;

  /// No description provided for @forgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين كلمة المرور'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البريد الإلكتروني الذي سجّلت به وسنرسل إليك رابطًا لإعادة التعيين.'**
  String get forgotSubtitle;

  /// No description provided for @forgotEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get forgotEmailLabel;

  /// No description provided for @forgotSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرابط'**
  String get forgotSubmit;

  /// No description provided for @forgotConfirmationTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من بريدك الإلكتروني'**
  String get forgotConfirmationTitle;

  /// No description provided for @forgotConfirmationBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا كان هناك حساب مرتبط بـ {email}، فقد أرسلنا إليه رابطًا لإعادة تعيين كلمة المرور. تنتهي صلاحية الرابط خلال ساعة واحدة.'**
  String forgotConfirmationBody(String email);

  /// No description provided for @forgotBackToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى تسجيل الدخول'**
  String get forgotBackToLogin;

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

  /// T4: Arabic plural via ICU.
  ///
  /// In ar, this message translates to:
  /// **'استخدم {min} {min, plural, few{أحرف} many{حرفًا} other{حرف}} على الأقل'**
  String validationTooShort(int min);

  /// T4: Arabic plural via ICU.
  ///
  /// In ar, this message translates to:
  /// **'استخدم {max} {max, plural, few{أحرف} many{حرفًا} other{حرف}} أو أقل'**
  String validationTooLong(int max);

  /// No description provided for @validationInvalid.
  ///
  /// In ar, this message translates to:
  /// **'القيمة غير صالحة'**
  String get validationInvalid;

  /// No description provided for @sessionEndedBanner.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى.'**
  String get sessionEndedBanner;

  /// No support button until B7 provides a channel.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف هذا الحساب. إذا كنت تعتقد أن هذا خطأ، فتواصل مع الدعم.'**
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
  /// **'استكشاف'**
  String get navDiscover;

  /// No description provided for @navCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get navCreate;

  /// D48: fourth bottom tab, For you · Posts · Reels.
  ///
  /// In ar, this message translates to:
  /// **'ريلز'**
  String get navReels;

  /// No description provided for @navLive.
  ///
  /// In ar, this message translates to:
  /// **'البث'**
  String get navLive;

  /// No description provided for @navProfile.
  ///
  /// In ar, this message translates to:
  /// **'أنا'**
  String get navProfile;

  /// No description provided for @discoverComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاستكشاف قادم'**
  String get discoverComingTitle;

  /// No description provided for @discoverComingBody.
  ///
  /// In ar, this message translates to:
  /// **'يتوفر البحث عن الأشخاص في المرحلة 2، والبثوث والفيديوهات وصنّاع المحتوى الرائجون في المرحلة 9.'**
  String get discoverComingBody;

  /// Profile TopBar title.
  ///
  /// In ar, this message translates to:
  /// **'‎@{username}‎'**
  String profileUsername(String username);

  /// No description provided for @profileContentComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر منشوراتك هنا'**
  String get profileContentComingTitle;

  /// No description provided for @profileContentComingBody.
  ///
  /// In ar, this message translates to:
  /// **'تصل المنشورات في المرحلة 3 والريلز في المرحلة 5. أما تعديل الملف الشخصي والقصص واللقطات المميزة فلاحقًا.'**
  String get profileContentComingBody;

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
  /// **'حسب إعدادات الجهاز'**
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

  /// No description provided for @sessionUnknownDevice.
  ///
  /// In ar, this message translates to:
  /// **'جهاز غير معروف'**
  String get sessionUnknownDevice;

  /// No description provided for @sessionsLastActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط {relativeTime}'**
  String sessionsLastActive(String relativeTime);

  /// No description provided for @sessionsActiveNow.
  ///
  /// In ar, this message translates to:
  /// **'نشط الآن'**
  String get sessionsActiveNow;

  /// No description provided for @sessionsSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول في {date}'**
  String sessionsSignedIn(String date);

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{منذ دقيقة} =2{منذ دقيقتين} few{منذ {n} دقائق} many{منذ {n} دقيقة} other{منذ {n} دقيقة}}'**
  String relativeMinutesAgo(int n);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{منذ ساعة} =2{منذ ساعتين} few{منذ {n} ساعات} many{منذ {n} ساعة} other{منذ {n} ساعة}}'**
  String relativeHoursAgo(int n);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{منذ يوم} =2{منذ يومين} few{منذ {n} أيام} many{منذ {n} يومًا} other{منذ {n} يوم}}'**
  String relativeDaysAgo(int n);

  /// No description provided for @sessionsRevoke.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء'**
  String get sessionsRevoke;

  /// No description provided for @sessionsRevokeConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء هذه الجلسة؟'**
  String get sessionsRevokeConfirmTitle;

  /// No description provided for @sessionsRevokeConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم تسجيل خروج {device} على الفور.'**
  String sessionsRevokeConfirmBody(String device);

  /// No description provided for @sessionsRevokeConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الجلسة'**
  String get sessionsRevokeConfirm;

  /// No description provided for @sessionsRevoked.
  ///
  /// In ar, this message translates to:
  /// **'تم إنهاء الجلسة'**
  String get sessionsRevoked;

  /// No description provided for @sessionsAlreadyEnded.
  ///
  /// In ar, this message translates to:
  /// **'كانت هذه الجلسة منتهية بالفعل'**
  String get sessionsAlreadyEnded;

  /// No description provided for @sessionsNoOthers.
  ///
  /// In ar, this message translates to:
  /// **'حسابك مسجَّل الدخول على هذا الجهاز فقط.'**
  String get sessionsNoOthers;

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
  /// **'تسجيل الخروج من Kabso Live؟'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى كلمة المرور لتسجيل الدخول مجددًا على هذا الجهاز.'**
  String get logoutConfirmBody;

  /// No description provided for @logoutDone.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل خروجك'**
  String get logoutDone;

  /// No description provided for @errorValidationFailed.
  ///
  /// In ar, this message translates to:
  /// **'بعض البيانات تحتاج إلى تصحيح. راجع الحقول المحدَّدة.'**
  String get errorValidationFailed;

  /// No description provided for @errorAuthUnauthenticated.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى.'**
  String get errorAuthUnauthenticated;

  /// No description provided for @errorAuthInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو اسم المستخدم أو كلمة المرور غير صحيحة.'**
  String get errorAuthInvalidCredentials;

  /// No description provided for @errorAuthRefreshInvalid.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك. يُرجى تسجيل الدخول مرة أخرى.'**
  String get errorAuthRefreshInvalid;

  /// No description provided for @errorAuthForbidden.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك صلاحية للقيام بذلك.'**
  String get errorAuthForbidden;

  /// No description provided for @errorAccountSuspended.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف هذا الحساب. إذا كنت تعتقد أن هذا خطأ، فتواصل مع الدعم.'**
  String get errorAccountSuspended;

  /// No description provided for @errorNotFound.
  ///
  /// In ar, this message translates to:
  /// **'هذا المحتوى غير متاح. ربما تمت إزالته.'**
  String get errorNotFound;

  /// No description provided for @errorUsernameTaken.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم هذا غير متاح. جرّب اسمًا آخر.'**
  String get errorUsernameTaken;

  /// No description provided for @errorIdempotencyConflict.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال هذا الطلب من قبل ببيانات مختلفة. حدّث الصفحة وحاول مرة أخرى.'**
  String get errorIdempotencyConflict;

  /// No description provided for @errorTokenExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية هذا الرابط أو سبق استخدامه. اطلب رابطًا جديدًا.'**
  String get errorTokenExpired;

  /// No description provided for @errorTokenInvalid.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط غير صالح. اطلب رابطًا جديدًا.'**
  String get errorTokenInvalid;

  /// No description provided for @errorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.'**
  String get errorRateLimited;

  /// {wait} = m:ss, Latin digits.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. حاول مرة أخرى بعد {wait}.'**
  String errorRateLimitedRetryIn(String wait);

  /// No description provided for @errorInternal.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ من جهتنا. يُرجى المحاولة مرة أخرى.'**
  String get errorInternal;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد قليل.'**
  String get errorServiceUnavailable;

  /// {wait} = m:ss, Latin digits.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة مشغولة حاليًا. حاول مرة أخرى بعد {wait}.'**
  String errorServiceBusyRetryIn(String wait);

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

  /// LIVE_HOSTING_UNAVAILABLE (503, v1.3): going live is switched off by server config. Not transient.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر غير متاح بعد.'**
  String get errorLiveHostingUnavailable;

  /// LIVE_ROOM_ALREADY_ACTIVE (409, v1.3): go-live refused because the caller already has a live room.
  ///
  /// In ar, this message translates to:
  /// **'لديك بث مباشر قائم بالفعل. تابعه أو أنهِه أولًا.'**
  String get errorLiveRoomAlreadyActive;

  /// LIVE_ROOM_ENDED (409, v1.3): the room is no longer live.
  ///
  /// In ar, this message translates to:
  /// **'انتهى هذا البث.'**
  String get errorLiveRoomEnded;

  /// No description provided for @errorIdLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز الخطأ: {requestId}'**
  String errorIdLabel(String requestId);

  /// LIVE marker on cards and avatars (KL-022).
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get liveBadge;

  /// PK marker (same in both locales).
  ///
  /// In ar, this message translates to:
  /// **'PK'**
  String get pkBadge;

  /// Semantics: full viewer count; {formatted} is the exact grouped number (Latin digits).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مشاهدين} =1{مشاهد واحد} =2{مشاهدان} few{{formatted} مشاهدين} many{{formatted} مشاهدًا} other{{formatted} مشاهد}}'**
  String liveViewers(int count, String formatted);

  /// No description provided for @liveCardSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{host}، مباشر، {viewers}، {title}'**
  String liveCardSemantics(String host, String viewers, String title);

  /// Avatar ring semantics suffix.
  ///
  /// In ar, this message translates to:
  /// **'يبث مباشرة الآن'**
  String get avatarLiveNow;

  /// No description provided for @avatarStoryUnseen.
  ///
  /// In ar, this message translates to:
  /// **'لديه قصة جديدة'**
  String get avatarStoryUnseen;

  /// No description provided for @avatarStorySeen.
  ///
  /// In ar, this message translates to:
  /// **'تمت مشاهدة القصة'**
  String get avatarStorySeen;

  /// No description provided for @liveFollow.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get liveFollow;

  /// No description provided for @liveFollowing.
  ///
  /// In ar, this message translates to:
  /// **'تتابعه'**
  String get liveFollowing;

  /// No description provided for @liveClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get liveClose;

  /// No description provided for @liveCommentHint.
  ///
  /// In ar, this message translates to:
  /// **'قل شيئًا…'**
  String get liveCommentHint;

  /// No description provided for @liveGifts.
  ///
  /// In ar, this message translates to:
  /// **'الهدايا'**
  String get liveGifts;

  /// The audio room bar's toolbox button (owner pack): opens the room tools.
  ///
  /// In ar, this message translates to:
  /// **'صندوق الأدوات'**
  String get liveToolbox;

  /// No description provided for @liveShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get liveShare;

  /// Placeholder slot until streams exist (B1).
  ///
  /// In ar, this message translates to:
  /// **'فيديو البث'**
  String get liveVideoPlaceholder;

  /// No description provided for @chatJoined.
  ///
  /// In ar, this message translates to:
  /// **'انضم {name}'**
  String chatJoined(String name);

  /// No description provided for @chatGiftSent.
  ///
  /// In ar, this message translates to:
  /// **'أرسل {name} {gift} ×{count}'**
  String chatGiftSent(String name, String gift, int count);

  /// No description provided for @giftPanelTitle.
  ///
  /// In ar, this message translates to:
  /// **'أرسل هدية'**
  String get giftPanelTitle;

  /// No description provided for @giftSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get giftSend;

  /// Purchases are blocked on B5.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال الهدايا بعد.'**
  String get giftSendComingSoon;

  /// No description provided for @giftCombo.
  ///
  /// In ar, this message translates to:
  /// **'⁦×{count}⁩'**
  String giftCombo(int count);

  /// No description provided for @giftCellSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{gift}، السعر {price}'**
  String giftCellSemantics(String gift, String price);

  /// No description provided for @pkTimeLeft.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ {time}'**
  String pkTimeLeft(String time);

  /// No description provided for @pkScoreSemantics.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة {left} مقابل {right}'**
  String pkScoreSemantics(String left, String right);

  /// No description provided for @pkWin.
  ///
  /// In ar, this message translates to:
  /// **'فوز'**
  String get pkWin;

  /// No description provided for @pkLose.
  ///
  /// In ar, this message translates to:
  /// **'خسارة'**
  String get pkLose;

  /// No description provided for @pkDraw.
  ///
  /// In ar, this message translates to:
  /// **'تعادل'**
  String get pkDraw;

  /// DESIGN_SYSTEM §3.3 compact counts (NBSP before Arabic suffix).
  ///
  /// In ar, this message translates to:
  /// **'{value} ألف'**
  String compactThousand(String value);

  /// No description provided for @compactMillion.
  ///
  /// In ar, this message translates to:
  /// **'{value} مليون'**
  String compactMillion(String value);

  /// No description provided for @compactBillion.
  ///
  /// In ar, this message translates to:
  /// **'{value} مليار'**
  String compactBillion(String value);

  /// Debug builds only.
  ///
  /// In ar, this message translates to:
  /// **'معرض المكونات'**
  String get debugComponentGallery;

  /// v1.2.3 SEC-025: 409 USERNAME_TAKEN for the username the user reserved in this flow.
  ///
  /// In ar, this message translates to:
  /// **'إذا كنت قد بدأت التسجيل بهذا البريد واسم المستخدم، فقد يظل رمزك صالحًا. اطلب رمزًا جديدًا للمتابعة، أو اختر اسم مستخدم آخر.'**
  String get registerUsernameReservedHint;

  /// No description provided for @registerResendCode.
  ///
  /// In ar, this message translates to:
  /// **'أعد إرسال الرمز'**
  String get registerResendCode;

  /// No description provided for @registerChooseAnotherUsername.
  ///
  /// In ar, this message translates to:
  /// **'اختر اسم مستخدم آخر'**
  String get registerChooseAnotherUsername;

  /// KL-033 primary tab (Home feed and Live hub).
  ///
  /// In ar, this message translates to:
  /// **'متابَعون'**
  String get feedTabFollowing;

  /// KL-033 primary tab; the default tab.
  ///
  /// In ar, this message translates to:
  /// **'رائج'**
  String get feedTabPopular;

  /// KL-033 primary tab: most recent first.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get feedTabNew;

  /// No description provided for @feedPreviewTestData.
  ///
  /// In ar, this message translates to:
  /// **'بيانات اختبار'**
  String get feedPreviewTestData;

  /// No description provided for @feedOpenLive.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر'**
  String get feedOpenLive;

  /// No description provided for @feedActionLike.
  ///
  /// In ar, this message translates to:
  /// **'إعجاب'**
  String get feedActionLike;

  /// No description provided for @feedActionComment.
  ///
  /// In ar, this message translates to:
  /// **'تعليقات'**
  String get feedActionComment;

  /// No description provided for @feedActionSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get feedActionSave;

  /// No description provided for @livePreviewMinimize.
  ///
  /// In ar, this message translates to:
  /// **'تصغير'**
  String get livePreviewMinimize;

  /// No description provided for @livePreviewBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get livePreviewBalance;

  /// No description provided for @livePreviewMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get livePreviewMore;

  /// No description provided for @livePreviewEmoji.
  ///
  /// In ar, this message translates to:
  /// **'رموز تعبيرية'**
  String get livePreviewEmoji;

  /// Semantics/tooltip of the header search button; opens Discover.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get feedSearch;

  /// Empty Following tab: switches to the Popular tab.
  ///
  /// In ar, this message translates to:
  /// **'عرض الرائج'**
  String get feedSeePopular;

  /// No description provided for @feedPullToRefresh.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للأسفل للتحديث.'**
  String get feedPullToRefresh;

  /// Home Following tab while there is no posts API. Warm, honest, product copy. No phase numbers or roadmap talk (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'ابقَ قريبًا ممن تتابعهم'**
  String get homeFollowingUnavailableTitle;

  /// No description provided for @homeFollowingUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا قريبًا منشورات من تتابعهم. وحتى ذلك الحين، شاهد من يبث منهم مباشرة الآن.'**
  String get homeFollowingUnavailableBody;

  /// Home Popular tab while there is no posts API. No phase numbers or roadmap talk (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'المنشورات في الطريق'**
  String get homePopularUnavailableTitle;

  /// No description provided for @homePopularUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا ستظهر هنا المنشورات التي يتحدث عنها الجميع. وحتى ذلك الحين، انضم إلى بث مباشر.'**
  String get homePopularUnavailableBody;

  /// Home New tab while there is no posts API. No phase numbers or roadmap talk (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'منشورات جديدة قريبًا'**
  String get homeNewUnavailableTitle;

  /// No description provided for @homeNewUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'ستصل هنا أحدث منشورات المجتمع أولًا بأول. والآن، اكتشف من بدأ البث للتو.'**
  String get homeNewUnavailableBody;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منشورات بعد'**
  String get homeEmptyTitle;

  /// No description provided for @homeFollowingEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منشورات ممن تتابعهم بعد'**
  String get homeFollowingEmptyTitle;

  /// No description provided for @homeErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المنشورات'**
  String get homeErrorTitle;

  /// The only category chip until categories come from the server (D36).
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get liveHubChipAll;

  /// Live hub Following tab while GET /live/config reports hostingEnabled = false. Followed by Try again (re-checks the config). No phase numbers or roadmap talk (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'بثوث من تتابعهم'**
  String get liveHubFollowingUnavailableTitle;

  /// No description provided for @liveHubFollowingUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر غير متاح بعد. عند إتاحته سترى هنا من يبث ممن تتابعهم.'**
  String get liveHubFollowingUnavailableBody;

  /// Live hub Popular tab while GET /live/config reports hostingEnabled = false. Followed by Try again (re-checks the config). No phase numbers or roadmap talk (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر غير متاح بعد'**
  String get liveHubPopularUnavailableTitle;

  /// No description provided for @liveHubPopularUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'نعمل على تجهيزه. عند إتاحته ستظهر هنا البثوث الأكثر مشاهدة.'**
  String get liveHubPopularUnavailableBody;

  /// Live hub New tab while GET /live/config reports hostingEnabled = false. Followed by Try again (re-checks the config). No phase numbers or roadmap talk (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'هنا تبدأ البثوث الجديدة'**
  String get liveHubNewUnavailableTitle;

  /// No description provided for @liveHubNewUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر غير متاح بعد. عند إتاحته ستظهر هنا البثوث التي بدأت للتو أولًا.'**
  String get liveHubNewUnavailableBody;

  /// KL-047 owner copy: Popular/New, successful response with zero rooms.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بثوث مباشرة الآن'**
  String get liveHubEmptyTitle;

  /// No description provided for @liveHubFollowingEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد ممن تتابعهم يبث الآن'**
  String get liveHubFollowingEmptyTitle;

  /// No description provided for @liveHubErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل البثوث المباشرة'**
  String get liveHubErrorTitle;

  /// HL-H5 inline footer error when the next page of live rooms fails; followed by a Retry button.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المزيد'**
  String get liveHubLoadMoreFailed;

  /// HL-H5 end-of-list caption of a live room list (no 'all caught up').
  ///
  /// In ar, this message translates to:
  /// **'اسحب للأسفل لعرض بثوث جديدة'**
  String get liveHubListEnd;

  /// Cover card chip shown instead of a viewer count below 1 viewer (VG-11).
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get liveCardNew;

  /// Semantics of the multi-guest tag on a cover card.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ضيف واحد} =2{ضيفان} few{{count} ضيوف} many{{count} ضيفًا} other{{count} ضيف}}'**
  String liveMultiGuest(int count);

  /// Cover card semantics with the room mode (PK or guests) appended.
  ///
  /// In ar, this message translates to:
  /// **'{card}، {mode}'**
  String liveCardSemanticsMode(String card, String mode);

  /// Feed item time under one minute.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get feedPostJustNow;

  /// KL-047 / QA-003: Home and Live region when a load failed with the client-only NETWORK_OFFLINE; followed by Try again.
  ///
  /// In ar, this message translates to:
  /// **'أنت غير متصل بالإنترنت'**
  String get feedOfflineTitle;

  /// No description provided for @feedOfflineBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من اتصالك ثم أعد المحاولة.'**
  String get feedOfflineBody;

  /// KL-047 primary action on Home Popular/New: opens the Live tab (same Popular/New tab).
  ///
  /// In ar, this message translates to:
  /// **'شاهد البث المباشر'**
  String get homeWatchLive;

  /// KL-047 primary action on Home Following: opens the Live tab on Following.
  ///
  /// In ar, this message translates to:
  /// **'شاهد من يبث الآن'**
  String get homeSeeWhoIsLive;

  /// KL-047 owner copy, under liveHubEmptyTitle; followed by Try again (re-requests the list).
  ///
  /// In ar, this message translates to:
  /// **'تفقّد البثوث الجديدة أو حاول مرة أخرى لاحقًا.'**
  String get liveHubEmptyBody;

  /// KL-047 secondary action on the empty Popular tab: switches to the New tab.
  ///
  /// In ar, this message translates to:
  /// **'عرض البثوث الجديدة'**
  String get liveHubSeeNew;

  /// Under liveHubFollowingEmptyTitle; followed by See popular.
  ///
  /// In ar, this message translates to:
  /// **'عندما يبدأ من تتابعهم البث، ستجدهم هنا.'**
  String get liveHubFollowingEmptyBody;

  /// Cover card semantics with the room category name appended (KL-047).
  ///
  /// In ar, this message translates to:
  /// **'{card}، {category}'**
  String liveCardSemanticsCategory(String card, String category);

  /// Room stage while no video can play (no media provider).
  ///
  /// In ar, this message translates to:
  /// **'فيديو البث غير متاح بعد'**
  String get liveRoomVideoUnavailableTitle;

  /// No description provided for @liveRoomVideoUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تشغيل الفيديو في التطبيق بعد. تفاصيل الغرفة هنا مباشرة.'**
  String get liveRoomVideoUnavailableBody;

  /// Honest empty chat: there is no chat API yet.
  ///
  /// In ar, this message translates to:
  /// **'الدردشة غير متاحة بعد. ستظهر الرسائل هنا.'**
  String get liveRoomChatUnavailable;

  /// Host follower count from the public profile; {formatted} is compact (Latin digits).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا متابعين} =1{متابع واحد} =2{متابعان} few{{formatted} متابعين} many{{formatted} متابعًا} other{{formatted} متابع}}'**
  String liveRoomFollowers(int count, String formatted);

  /// No description provided for @liveRoomHostSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{host}، ملف المضيف'**
  String liveRoomHostSemantics(String host);

  /// No description provided for @liveRoomUsername.
  ///
  /// In ar, this message translates to:
  /// **'@{username}'**
  String liveRoomUsername(String username);

  /// No description provided for @liveRoomCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة: {category}'**
  String liveRoomCategory(String category);

  /// No description provided for @liveRoomEndedTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهى هذا البث'**
  String get liveRoomEndedTitle;

  /// No description provided for @liveRoomEndedByHost.
  ///
  /// In ar, this message translates to:
  /// **'أنهى المضيف هذا البث.'**
  String get liveRoomEndedByHost;

  /// No description provided for @liveRoomEndedTimeout.
  ///
  /// In ar, this message translates to:
  /// **'توقف البث بعد انقطاع اتصال المضيف.'**
  String get liveRoomEndedTimeout;

  /// No description provided for @liveRoomEndedOther.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا البث متاحًا.'**
  String get liveRoomEndedOther;

  /// No description provided for @liveRoomBackToLive.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى البثوث'**
  String get liveRoomBackToLive;

  /// No description provided for @liveRoomNotFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا البث غير متاح'**
  String get liveRoomNotFoundTitle;

  /// No description provided for @liveRoomNotFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'ربما انتهى أو تمت إزالته.'**
  String get liveRoomNotFoundBody;

  /// No description provided for @liveRoomErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح هذا البث'**
  String get liveRoomErrorTitle;

  /// Semantics while the room loads.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ فتح البث'**
  String get liveRoomLoading;

  /// No description provided for @liveRoomWeakConnection.
  ///
  /// In ar, this message translates to:
  /// **'اتصال ضعيف'**
  String get liveRoomWeakConnection;

  /// No description provided for @liveRoomReconnecting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إعادة الاتصال…'**
  String get liveRoomReconnecting;

  /// No description provided for @liveRoomCameraOff.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا متوقفة'**
  String get liveRoomCameraOff;

  /// No description provided for @giftNameHeart.
  ///
  /// In ar, this message translates to:
  /// **'قلب'**
  String get giftNameHeart;

  /// No description provided for @giftNameStar.
  ///
  /// In ar, this message translates to:
  /// **'نجمة'**
  String get giftNameStar;

  /// No description provided for @giftNameDiamond.
  ///
  /// In ar, this message translates to:
  /// **'ماسة'**
  String get giftNameDiamond;

  /// No description provided for @giftNameCrown.
  ///
  /// In ar, this message translates to:
  /// **'تاج'**
  String get giftNameCrown;

  /// Kabso PK mark on the seam between the panes.
  ///
  /// In ar, this message translates to:
  /// **'VS'**
  String get pkVersus;

  /// No description provided for @pkSupporters.
  ///
  /// In ar, this message translates to:
  /// **'أبرز الداعمين: {names}'**
  String pkSupporters(String names);

  /// No description provided for @multiGuestOpenSeat.
  ///
  /// In ar, this message translates to:
  /// **'مقعد شاغر'**
  String get multiGuestOpenSeat;

  /// No description provided for @multiGuestMicOff.
  ///
  /// In ar, this message translates to:
  /// **'{name}، الميكروفون مغلق'**
  String multiGuestMicOff(String name);

  /// No description provided for @multiGuestHost.
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get multiGuestHost;

  /// KL-056 preview share sheet title.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة إلى'**
  String get shareSheetTitle;

  /// No description provided for @shareRepost.
  ///
  /// In ar, this message translates to:
  /// **'إعادة نشر'**
  String get shareRepost;

  /// No description provided for @shareCopyLink.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get shareCopyLink;

  /// No description provided for @shareSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get shareSend;

  /// No description provided for @shareSaveVideo.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الفيديو'**
  String get shareSaveVideo;

  /// No description provided for @shareReport.
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ'**
  String get shareReport;

  /// KL-056 messages preview composer hint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة…'**
  String get messagesPreviewHint;

  /// No description provided for @messagesPreviewSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get messagesPreviewSend;

  /// No description provided for @messagesPreviewPlay.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الفيديو'**
  String get messagesPreviewPlay;

  /// No description provided for @messagesPreviewReaction.
  ///
  /// In ar, this message translates to:
  /// **'تفاعل {emoji}'**
  String messagesPreviewReaction(String emoji);

  /// KL-056 comments sheet header.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تعليقات} =1{تعليق واحد} =2{تعليقان} few{{count} تعليقات} many{{count} تعليقًا} other{{count} تعليق}}'**
  String commentsSheetTitle(int count);

  /// No description provided for @commentsCreator.
  ///
  /// In ar, this message translates to:
  /// **'صاحب المنشور'**
  String get commentsCreator;

  /// No description provided for @commentsReply.
  ///
  /// In ar, this message translates to:
  /// **'رد'**
  String get commentsReply;

  /// No description provided for @commentsViewReplies.
  ///
  /// In ar, this message translates to:
  /// **'عرض الردود ({count})'**
  String commentsViewReplies(int count);

  /// No description provided for @commentsHideReplies.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الردود'**
  String get commentsHideReplies;

  /// No description provided for @commentsHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف تعليقًا…'**
  String get commentsHint;

  /// No description provided for @commentsPost.
  ///
  /// In ar, this message translates to:
  /// **'نشر'**
  String get commentsPost;

  /// No description provided for @commentsLike.
  ///
  /// In ar, this message translates to:
  /// **'إعجاب، {count}'**
  String commentsLike(String count);

  /// No description provided for @commentsVerified.
  ///
  /// In ar, this message translates to:
  /// **'موثّق'**
  String get commentsVerified;

  /// KL-056 debug-only hub listing the design previews.
  ///
  /// In ar, this message translates to:
  /// **'معاينات التصميم'**
  String get previewsHubTitle;

  /// No description provided for @previewsHubNote.
  ///
  /// In ar, this message translates to:
  /// **'بيانات اختبار فقط. لا شيء هنا متصل بالخادم.'**
  String get previewsHubNote;

  /// No description provided for @previewsHubFeed.
  ///
  /// In ar, this message translates to:
  /// **'المنشورات'**
  String get previewsHubFeed;

  /// No description provided for @previewsHubLive.
  ///
  /// In ar, this message translates to:
  /// **'غرفة البث'**
  String get previewsHubLive;

  /// No description provided for @previewsHubMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get previewsHubMessages;

  /// No description provided for @previewsHubComponents.
  ///
  /// In ar, this message translates to:
  /// **'المكوّنات'**
  String get previewsHubComponents;

  /// Author name shown on the viewer's own new comment and composer avatar.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get commentsYou;

  /// KL-056 conversation list preview title.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get conversationsTitle;

  /// No description provided for @conversationsSharedVideo.
  ///
  /// In ar, this message translates to:
  /// **'شارك فيديو'**
  String get conversationsSharedVideo;

  /// No description provided for @conversationsSayHi.
  ///
  /// In ar, this message translates to:
  /// **'ألقِ التحية على {name}'**
  String conversationsSayHi(String name);

  /// No description provided for @conversationsUnread.
  ///
  /// In ar, this message translates to:
  /// **'{name}، غير مقروءة'**
  String conversationsUnread(String name);

  /// No description provided for @conversationsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا رسائل بعد'**
  String get conversationsEmptyTitle;

  /// No description provided for @conversationsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'عندما تراسل أحدًا، تظهر المحادثة هنا.'**
  String get conversationsEmptyBody;

  /// No description provided for @conversationsUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل غير متاحة بعد'**
  String get conversationsUnavailableTitle;

  /// No description provided for @conversationsUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُفتح الرسائل الخاصة هنا عندما تصبح جاهزة.'**
  String get conversationsUnavailableBody;

  /// No description provided for @previewStateLabel.
  ///
  /// In ar, this message translates to:
  /// **'حالة المعاينة'**
  String get previewStateLabel;

  /// No description provided for @previewStateLoading.
  ///
  /// In ar, this message translates to:
  /// **'تحميل'**
  String get previewStateLoading;

  /// No description provided for @previewStateError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get previewStateError;

  /// No description provided for @previewStateUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get previewStateUnavailable;

  /// No description provided for @previewStateEmpty.
  ///
  /// In ar, this message translates to:
  /// **'فارغ'**
  String get previewStateEmpty;

  /// No description provided for @previewStatePopulated.
  ///
  /// In ar, this message translates to:
  /// **'مع بيانات'**
  String get previewStatePopulated;

  /// No description provided for @messagesGreetingHi.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا'**
  String get messagesGreetingHi;

  /// No description provided for @messagesGreetingHello.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا وسهلًا'**
  String get messagesGreetingHello;

  /// No description provided for @messagesGreetingHowAreYou.
  ///
  /// In ar, this message translates to:
  /// **'كيف حالك؟'**
  String get messagesGreetingHowAreYou;

  /// No description provided for @previewsHubConversations.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات'**
  String get previewsHubConversations;

  /// KL-056 Discover preview hashtag subtitle.
  ///
  /// In ar, this message translates to:
  /// **'وسم رائج'**
  String get discoverTrendingHashtag;

  /// No description provided for @discoverHashtagVideos.
  ///
  /// In ar, this message translates to:
  /// **'{name}، {count} فيديو'**
  String discoverHashtagVideos(String name, String count);

  /// No description provided for @discoverBanner.
  ///
  /// In ar, this message translates to:
  /// **'مميّز {index} من {total}'**
  String discoverBanner(int index, int total);

  /// No description provided for @discoverNoResultsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج'**
  String get discoverNoResultsTitle;

  /// No description provided for @discoverNoResultsBody.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء في بيانات الاختبار يطابق {query}.'**
  String discoverNoResultsBody(String query);

  /// No description provided for @discoverClearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get discoverClearSearch;

  /// No description provided for @discoverOpenVideo.
  ///
  /// In ar, this message translates to:
  /// **'فتح الفيديو {index} من {name}'**
  String discoverOpenVideo(int index, String name);

  /// No description provided for @reelsModeLabel.
  ///
  /// In ar, this message translates to:
  /// **'عرض الريلز أو المنشورات'**
  String get reelsModeLabel;

  /// No description provided for @reelsModeReels.
  ///
  /// In ar, this message translates to:
  /// **'ريلز'**
  String get reelsModeReels;

  /// No description provided for @reelsModePosts.
  ///
  /// In ar, this message translates to:
  /// **'منشورات'**
  String get reelsModePosts;

  /// No description provided for @reelsTabForYou.
  ///
  /// In ar, this message translates to:
  /// **'لك'**
  String get reelsTabForYou;

  /// No description provided for @reelsTabFriends.
  ///
  /// In ar, this message translates to:
  /// **'الأصدقاء'**
  String get reelsTabFriends;

  /// No description provided for @reelsCoins.
  ///
  /// In ar, this message translates to:
  /// **'رصيد العملات، {count}'**
  String reelsCoins(String count);

  /// No description provided for @reelsSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get reelsSave;

  /// No description provided for @reelsSaved.
  ///
  /// In ar, this message translates to:
  /// **'محفوظ'**
  String get reelsSaved;

  /// No description provided for @reelsNotInterested.
  ///
  /// In ar, this message translates to:
  /// **'غير مهتم'**
  String get reelsNotInterested;

  /// No description provided for @reelsProgress.
  ///
  /// In ar, this message translates to:
  /// **'موضع التشغيل'**
  String get reelsProgress;

  /// No description provided for @postsLikes.
  ///
  /// In ar, this message translates to:
  /// **'{count} إعجاب'**
  String postsLikes(String count);

  /// No description provided for @postsViewComments.
  ///
  /// In ar, this message translates to:
  /// **'عرض كل التعليقات ({count})'**
  String postsViewComments(String count);

  /// No description provided for @previewsHubReels.
  ///
  /// In ar, this message translates to:
  /// **'الريلز والمنشورات'**
  String get previewsHubReels;

  /// D52: debug hub entry for the real Reels tab with test data.
  ///
  /// In ar, this message translates to:
  /// **'تبويب الريلز (المنشورات)'**
  String get previewsHubReelsTab;

  /// No description provided for @homeTabPosts.
  ///
  /// In ar, this message translates to:
  /// **'المنشورات'**
  String get homeTabPosts;

  /// No description provided for @homeTabReels.
  ///
  /// In ar, this message translates to:
  /// **'الريلز'**
  String get homeTabReels;

  /// No description provided for @homeReelsUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'الريلز قادمة قريبًا'**
  String get homeReelsUnavailableTitle;

  /// No description provided for @homeReelsUnavailableBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا مقاطع الفيديو القصيرة عند إطلاق الريلز. حاليًا، شاهد البث المباشر.'**
  String get homeReelsUnavailableBody;

  /// No description provided for @homeReelsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ريلز بعد'**
  String get homeReelsEmptyTitle;

  /// No description provided for @homeReelsErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الريلز'**
  String get homeReelsErrorTitle;

  /// No description provided for @homeReelBy.
  ///
  /// In ar, this message translates to:
  /// **'ريل من {name}'**
  String homeReelBy(String name);

  /// No description provided for @liveHubJoin.
  ///
  /// In ar, this message translates to:
  /// **'ادخل البث'**
  String get liveHubJoin;

  /// No description provided for @liveHubLoadingMore.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل المزيد من البثوث'**
  String get liveHubLoadingMore;

  /// D52: header switch, Posts → Reels.
  ///
  /// In ar, this message translates to:
  /// **'عرض الريلز'**
  String get homeShowReels;

  /// D52: header switch, Reels → Posts.
  ///
  /// In ar, this message translates to:
  /// **'عرض المنشورات'**
  String get homeShowPosts;

  /// D52: expands a post's collapsed text.
  ///
  /// In ar, this message translates to:
  /// **'عرض المزيد'**
  String get feedSeeMore;

  /// D52: semantics of the video mark on a post.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get feedPostVideo;

  /// D52: semantics of a post's display-only counts.
  ///
  /// In ar, this message translates to:
  /// **'{likes} إعجاب، {comments} تعليق، {shares} مشاركة'**
  String feedPostCounts(String likes, String comments, String shares);

  /// D53: header tab, the trending feed (default).
  ///
  /// In ar, this message translates to:
  /// **'رائج'**
  String get homeFeedTrending;

  /// D53: follow badge on a reel's rail photo.
  ///
  /// In ar, this message translates to:
  /// **'متابعة {name}'**
  String homeFollowAuthor(String name);

  /// D53: the badge after following.
  ///
  /// In ar, this message translates to:
  /// **'تتابع {name}'**
  String homeFollowingAuthor(String name);

  /// D53: Reels · Following unavailable state.
  ///
  /// In ar, this message translates to:
  /// **'ريلز ممن تتابعهم'**
  String get homeReelsFollowingUnavailableTitle;

  /// D53: Reels · Following unavailable state.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا ريلز من تتابعهم عند إطلاق الريلز. وحتى ذلك الحين، شاهد البث المباشر.'**
  String get homeReelsFollowingUnavailableBody;

  /// D53: Reels · Following empty state.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ريلز ممن تتابعهم بعد'**
  String get homeReelsFollowingEmptyTitle;

  /// D54: the three dots on a post.
  ///
  /// In ar, this message translates to:
  /// **'خيارات أخرى'**
  String get feedPostMore;

  /// D54: post menu action.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء متابعة {name}'**
  String homeUnfollowAuthor(String name);

  /// D57: own profile.
  ///
  /// In ar, this message translates to:
  /// **'المتابِعون'**
  String get profileFollowers;

  /// D57: own profile.
  ///
  /// In ar, this message translates to:
  /// **'يتابع'**
  String get profileFollowingCount;

  /// D57: own profile.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منشورات بعد'**
  String get profileNoPosts;

  /// D57: own profile.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ريلز بعد'**
  String get profileNoReels;

  /// D57: own profile.
  ///
  /// In ar, this message translates to:
  /// **'عندما تنشر شيئًا سيظهر هنا.'**
  String get profileGridEmptyBody;

  /// D58: edit profile (read-only until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get profileEditTitle;

  /// D58: edit profile (read-only until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get profileEditSave;

  /// D58: edit profile (read-only until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get profileEditName;

  /// D58: edit profile (read-only until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get profileEditUsername;

  /// D58: edit profile (read-only until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'النبذة'**
  String get profileEditBio;

  /// D58: edit profile (read-only until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'تغيير الاسم والنبذة والصورة يحتاج تحديثًا في الخادم غير متاح بعد.'**
  String get profileEditUnavailable;

  /// D58: under the photo (disabled until upload exists).
  ///
  /// In ar, this message translates to:
  /// **'تغيير الصورة'**
  String get profileEditPhoto;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'الروابط'**
  String get profileEditLinks;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get profileEditGender;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'فئة الحساب'**
  String get profileEditCategory;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'ترتيب الشبكة'**
  String get profileEditReorderGrid;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'خصوصية الحساب'**
  String get profileEditPrivacy;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get profilePrivacyPublic;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'خاص'**
  String get profilePrivacyPrivate;

  /// D58: edit profile rows (coming soon until CP-001).
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get profileEditSoon;

  /// D59: own profile, saved tab.
  ///
  /// In ar, this message translates to:
  /// **'المحفوظات'**
  String get profileSaved;

  /// D59: own profile, saved tab.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محفوظات بعد'**
  String get profileNoSaved;

  /// D59: own profile, saved tab.
  ///
  /// In ar, this message translates to:
  /// **'احفظ المنشورات والريلز لتجدها هنا. لا يرى محفوظاتك أحد غيرك.'**
  String get profileSavedEmptyBody;

  /// D59: own profile, saved tab.
  ///
  /// In ar, this message translates to:
  /// **'منشوراتك وريلز المحفوظة'**
  String get profileSavedComingTitle;

  /// D59: own profile, saved tab.
  ///
  /// In ar, this message translates to:
  /// **'يصل الحفظ مع المنشورات والريلز. لن يرى محفوظاتك أحد غيرك.'**
  String get profileSavedComingBody;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'شاهد البث'**
  String get profileWatchLive;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'المنشورات والريلز قادمة'**
  String get profileOtherComingTitle;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'تصل المنشورات في المرحلة 3 والريلز في المرحلة 5.'**
  String get profileOtherComingBody;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنشر شيء بعد.'**
  String get profileOtherEmptyBody;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب خاص'**
  String get profilePrivateTitle;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'منشوراته وريلزه يراها متابعوه فقط.'**
  String get profilePrivateBody;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب غير متاح'**
  String get profileNotFoundTitle;

  /// D60: public profile.
  ///
  /// In ar, this message translates to:
  /// **'قد يكون الرابط غير صحيح، أو أُزيل الحساب.'**
  String get profileNotFoundBody;

  /// D60: unfollow sheet.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء متابعة {name}؟'**
  String profileUnfollowConfirm(String name);

  /// D60: debug hub entry.
  ///
  /// In ar, this message translates to:
  /// **'الملف العام'**
  String get previewsHubUserProfile;

  /// D61: Message button / not-connected chat.
  ///
  /// In ar, this message translates to:
  /// **'مراسلة'**
  String get profileMessage;

  /// D61: Message button / not-connected chat.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل الخاصة غير متاحة بعد. عند توفرها ستظهر محادثتكما هنا.'**
  String get chatUnavailable;

  /// D62: public profile three-dots menu.
  ///
  /// In ar, this message translates to:
  /// **'نسخ اسم المستخدم'**
  String get profileCopyUsername;

  /// D62: public profile three-dots menu.
  ///
  /// In ar, this message translates to:
  /// **'نسخ رابط الصفحة'**
  String get profileCopyLink;

  /// D62: public profile three-dots menu.
  ///
  /// In ar, this message translates to:
  /// **'تبليغ'**
  String get profileReport;

  /// D62: public profile three-dots menu.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get profileCopied;

  /// D64 welcome: one paragraph under the headline.
  ///
  /// In ar, this message translates to:
  /// **'بث مباشر، ريلز، بودكاست، وهدايا لصنّاعك المفضلين. ادخل وخلّي صوتك يوصل.'**
  String get welcomeBody;

  /// D64: brand name, not translated.
  ///
  /// In ar, this message translates to:
  /// **'Google'**
  String get authProviderGoogle;

  /// D64: brand name, not translated.
  ///
  /// In ar, this message translates to:
  /// **'Apple'**
  String get authProviderApple;

  /// D64: badge on social sign-in buttons that do not work yet (CP-002).
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get authSocialSoon;

  /// D64: screen-reader label of a social sign-in button that does not work yet.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة باستخدام {provider}، قريبًا'**
  String authSocialSoonLabel(String provider);

  /// D64 welcome: pill next to the wordmark, with a pulsing dot.
  ///
  /// In ar, this message translates to:
  /// **'البث شغّال الآن'**
  String get welcomeLiveChip;

  /// D64 welcome headline, first word (animated separately).
  ///
  /// In ar, this message translates to:
  /// **'العالم'**
  String get welcomeHeadline1;

  /// D64 welcome headline, second word.
  ///
  /// In ar, this message translates to:
  /// **'كله'**
  String get welcomeHeadline2;

  /// D64 welcome headline, second line (red marker under it).
  ///
  /// In ar, this message translates to:
  /// **'على الهواء.'**
  String get welcomeHeadline3;

  /// D64 welcome: main button, opens registration.
  ///
  /// In ar, this message translates to:
  /// **'يلا نبدأ'**
  String get welcomeStart;

  /// D64 welcome: text before the red "Log in" (loginSubmit); keep the trailing separator and space.
  ///
  /// In ar, this message translates to:
  /// **'عندي حساب · '**
  String get welcomeHaveAccount;

  /// D64 welcome: illustrative comment bubble floating by Kabi (decorative, not read by screen readers).
  ///
  /// In ar, this message translates to:
  /// **'نورت يا كابي 🔥'**
  String get welcomeComment1;

  /// D64 welcome: illustrative comment bubble.
  ///
  /// In ar, this message translates to:
  /// **'أول مرة هنا 😍'**
  String get welcomeComment2;

  /// D64 welcome: illustrative comment bubble (Kabi's "kab kab").
  ///
  /// In ar, this message translates to:
  /// **'كاب كاب 🎧'**
  String get welcomeComment3;

  /// D65 join screen: first line of the title.
  ///
  /// In ar, this message translates to:
  /// **'خلّي صوتك'**
  String get joinTitleLead;

  /// D65 join screen: second line of the title, in red.
  ///
  /// In ar, this message translates to:
  /// **'يوصل للعالم'**
  String get joinTitleAccent;

  /// D65 join screen: two lines under the title.
  ///
  /// In ar, this message translates to:
  /// **'بث مباشر، ريلز وبودكاست في مكان واحد.\nأهلًا بك في Kabso Live.'**
  String get joinBody;

  /// D65 join screen: filled button, opens registration.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get joinCreate;

  /// D65 login: title before the red part; keep the trailing space.
  ///
  /// In ar, this message translates to:
  /// **'جاهز تبدأ '**
  String get loginTitleLead;

  /// D65 login: red end of the title.
  ///
  /// In ar, this message translates to:
  /// **'البث؟'**
  String get loginTitleAccent;

  /// D66: title of the emoji picker sheet.
  ///
  /// In ar, this message translates to:
  /// **'الإيموجي'**
  String get kabiEmojiPickerTitle;

  /// D66: tooltip of the emoji button in a composer.
  ///
  /// In ar, this message translates to:
  /// **'إيموجي'**
  String get kabiEmojiButton;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'كابي'**
  String get emojiPackKabi;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'كيكي'**
  String get emojiPackKiki;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'بو'**
  String get emojiPackBoo;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'بيبو'**
  String get emojiPackPipo;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'دوبي'**
  String get emojiPackDubi;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'جوجو'**
  String get emojiPackGogo;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'لولو'**
  String get emojiPackLulu;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'نينو'**
  String get emojiPackNeno;

  /// An emoji category (pack) tab in the picker (D102).
  ///
  /// In ar, this message translates to:
  /// **'أعلام'**
  String get emojiPackFlags;

  /// Name of the Kabi emoji "hi" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هلا'**
  String get emojiKabiHi;

  /// Name of the Kabi emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiKabiLove;

  /// Name of the Kabi emoji "lol" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiKabiLol;

  /// Name of the Kabi emoji "wow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'واو'**
  String get emojiKabiWow;

  /// Name of the Kabi emoji "sad" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حزين'**
  String get emojiKabiSad;

  /// Name of the Kabi emoji "angry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'معصّب'**
  String get emojiKabiAngry;

  /// Name of the Kabi emoji "wink" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'غمزة'**
  String get emojiKabiWink;

  /// Name of the Kabi emoji "live" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'لايف'**
  String get emojiKabiLive;

  /// Name of the Kabi emoji "cool" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'كشخة'**
  String get emojiKabiCool;

  /// Name of the Kabi emoji "dizzy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'دايخ'**
  String get emojiKabiDizzy;

  /// Name of the Kabi emoji "sleepy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نعسان'**
  String get emojiKabiSleepy;

  /// Name of the Kabi emoji "silly" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مهبول'**
  String get emojiKabiSilly;

  /// Name of the Kabi emoji "shy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مستحي'**
  String get emojiKabiShy;

  /// Name of the Kabi emoji "think" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يفكر'**
  String get emojiKabiThink;

  /// Name of the Kabi emoji "party" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'احتفال'**
  String get emojiKabiParty;

  /// Name of the Kabi emoji "dead" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مت ضحك'**
  String get emojiKabiDead;

  /// Name of the Kabi emoji "melt" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ذايب'**
  String get emojiKabiMelt;

  /// Name of the Kabi emoji "kiss" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'بوسة'**
  String get emojiKabiKiss;

  /// Name of the Kabi emoji "gift" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get emojiKabiGift;

  /// Name of the Kabi emoji "fire" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نار'**
  String get emojiKabiFire;

  /// Name of the Kabi emoji "crown" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'VIP'**
  String get emojiKabiCrown;

  /// Name of the Kabi emoji "money" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'فلوس'**
  String get emojiKabiMoney;

  /// Name of the Kabi emoji "sing" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يغني'**
  String get emojiKabiSing;

  /// Name of the Kabi emoji "star" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'منبهر'**
  String get emojiKabiStar;

  /// Name of the Kiki emoji "hi" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هلا'**
  String get emojiKikiHi;

  /// Name of the Kiki emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiKikiLove;

  /// Name of the Kiki emoji "lol" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiKikiLol;

  /// Name of the Kiki emoji "wow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'واو'**
  String get emojiKikiWow;

  /// Name of the Kiki emoji "sad" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حزين'**
  String get emojiKikiSad;

  /// Name of the Kiki emoji "angry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'معصّب'**
  String get emojiKikiAngry;

  /// Name of the Kiki emoji "cool" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'كشخة'**
  String get emojiKikiCool;

  /// Name of the Kiki emoji "sleepy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نعسان'**
  String get emojiKikiSleepy;

  /// Name of the Kiki emoji "wink" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'غمزة'**
  String get emojiKikiWink;

  /// Name of the Kiki emoji "kiss" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'بوسة'**
  String get emojiKikiKiss;

  /// Name of the Kiki emoji "sing" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يغني'**
  String get emojiKikiSing;

  /// Name of the Kiki emoji "shy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مستحية'**
  String get emojiKikiShy;

  /// Name of the Kiki emoji "think" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تفكر'**
  String get emojiKikiThink;

  /// Name of the Kiki emoji "party" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'احتفال'**
  String get emojiKikiParty;

  /// Name of the Kiki emoji "clap" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تصفيق'**
  String get emojiKikiClap;

  /// Name of the Kiki emoji "fire" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نار'**
  String get emojiKikiFire;

  /// Name of the Kiki emoji "ok" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get emojiKikiOk;

  /// Name of the Kiki emoji "dizzy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'دايخة'**
  String get emojiKikiDizzy;

  /// Name of the Boo emoji "boo" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'بخ'**
  String get emojiBooBoo;

  /// Name of the Boo emoji "scared" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'خايف'**
  String get emojiBooScared;

  /// Name of the Boo emoji "fade" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'اختفى'**
  String get emojiBooFade;

  /// Name of the Boo emoji "peek" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يطل'**
  String get emojiBooPeek;

  /// Name of the Boo emoji "spin" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يرقص'**
  String get emojiBooSpin;

  /// Name of the Boo emoji "laugh" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiBooLaugh;

  /// Name of the Boo emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiBooLove;

  /// Name of the Boo emoji "cry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يبكي'**
  String get emojiBooCry;

  /// Name of the Boo emoji "sneaky" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'خبيث'**
  String get emojiBooSneaky;

  /// Name of the Boo emoji "sleep" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نايم'**
  String get emojiBooSleep;

  /// Name of the Boo emoji "shock" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مصدوم'**
  String get emojiBooShock;

  /// Name of the Boo emoji "party" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'احتفال'**
  String get emojiBooParty;

  /// Name of the Pipo emoji "hi" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هلا'**
  String get emojiPipoHi;

  /// Name of the Pipo emoji "chirp" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يغرّد'**
  String get emojiPipoChirp;

  /// Name of the Pipo emoji "hungry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'جوعان'**
  String get emojiPipoHungry;

  /// Name of the Pipo emoji "cold" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'بردان'**
  String get emojiPipoCold;

  /// Name of the Pipo emoji "fly" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يطير'**
  String get emojiPipoFly;

  /// Name of the Pipo emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiPipoLove;

  /// Name of the Pipo emoji "cry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يبكي'**
  String get emojiPipoCry;

  /// Name of the Pipo emoji "angry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'معصّب'**
  String get emojiPipoAngry;

  /// Name of the Pipo emoji "sleepy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نعسان'**
  String get emojiPipoSleepy;

  /// Name of the Pipo emoji "yay" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ياي'**
  String get emojiPipoYay;

  /// Name of the Pipo emoji "shy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مستحي'**
  String get emojiPipoShy;

  /// Name of the Pipo emoji "wow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'واو'**
  String get emojiPipoWow;

  /// Name of the Dubi emoji "hug" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حضن'**
  String get emojiDubiHug;

  /// Name of the Dubi emoji "thanks" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'شكرًا'**
  String get emojiDubiThanks;

  /// Name of the Dubi emoji "strong" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'قوي'**
  String get emojiDubiStrong;

  /// Name of the Dubi emoji "honey" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'عسل'**
  String get emojiDubiHoney;

  /// Name of the Dubi emoji "sleep" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نايم'**
  String get emojiDubiSleep;

  /// Name of the Dubi emoji "grr" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'غاضب'**
  String get emojiDubiGrr;

  /// Name of the Dubi emoji "lol" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiDubiLol;

  /// Name of the Dubi emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiDubiLove;

  /// Name of the Dubi emoji "cool" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'كشخة'**
  String get emojiDubiCool;

  /// Name of the Dubi emoji "ok" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get emojiDubiOk;

  /// Name of the Dubi emoji "sad" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حزين'**
  String get emojiDubiSad;

  /// Name of the Dubi emoji "clap" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تصفيق'**
  String get emojiDubiClap;

  /// Name of the Gogo emoji "hi" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هلا'**
  String get emojiGogoHi;

  /// Name of the Gogo emoji "roar" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'زئير'**
  String get emojiGogoRoar;

  /// Name of the Gogo emoji "stomp" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يدبدب'**
  String get emojiGogoStomp;

  /// Name of the Gogo emoji "hatch" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يفقس'**
  String get emojiGogoHatch;

  /// Name of the Gogo emoji "munch" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ياكل'**
  String get emojiGogoMunch;

  /// Name of the Gogo emoji "dance" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يرقص'**
  String get emojiGogoDance;

  /// Name of the Gogo emoji "sneeze" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'عطسة'**
  String get emojiGogoSneeze;

  /// Name of the Gogo emoji "cool" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'كشخة'**
  String get emojiGogoCool;

  /// Name of the Gogo emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiGogoLove;

  /// Name of the Gogo emoji "lol" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiGogoLol;

  /// Name of the Gogo emoji "cry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يبكي'**
  String get emojiGogoCry;

  /// Name of the Gogo emoji "wow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'واو'**
  String get emojiGogoWow;

  /// Name of the Lulu emoji "hi" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هلا'**
  String get emojiLuluHi;

  /// Name of the Lulu emoji "sun" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مشمس'**
  String get emojiLuluSun;

  /// Name of the Lulu emoji "rain" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ممطر'**
  String get emojiLuluRain;

  /// Name of the Lulu emoji "thunder" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'رعد'**
  String get emojiLuluThunder;

  /// Name of the Lulu emoji "rainbow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'قوس قزح'**
  String get emojiLuluRainbow;

  /// Name of the Lulu emoji "snow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ثلج'**
  String get emojiLuluSnow;

  /// Name of the Lulu emoji "wind" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هواء'**
  String get emojiLuluWind;

  /// Name of the Lulu emoji "sleep" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نايمة'**
  String get emojiLuluSleep;

  /// Name of the Lulu emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiLuluLove;

  /// Name of the Lulu emoji "wow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'واو'**
  String get emojiLuluWow;

  /// Name of the Lulu emoji "lol" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiLuluLol;

  /// Name of the Lulu emoji "shy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مستحية'**
  String get emojiLuluShy;

  /// Name of the Neno emoji "hi" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'هلا'**
  String get emojiNenoHi;

  /// Name of the Neno emoji "love" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get emojiNenoLove;

  /// Name of the Neno emoji "lol" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get emojiNenoLol;

  /// Name of the Neno emoji "wow" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'واو'**
  String get emojiNenoWow;

  /// Name of the Neno emoji "cry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يبكي'**
  String get emojiNenoCry;

  /// Name of the Neno emoji "angry" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'معصّب'**
  String get emojiNenoAngry;

  /// Name of the Neno emoji "cool" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'كشخة'**
  String get emojiNenoCool;

  /// Name of the Neno emoji "think" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يفكر'**
  String get emojiNenoThink;

  /// Name of the Neno emoji "wink" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'غمزة'**
  String get emojiNenoWink;

  /// Name of the Neno emoji "sleepy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'نعسان'**
  String get emojiNenoSleepy;

  /// Name of the Neno emoji "money" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'بزنس'**
  String get emojiNenoMoney;

  /// Name of the Neno emoji "ok" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get emojiNenoOk;

  /// Name of the Neno emoji "clap" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تصفيق'**
  String get emojiNenoClap;

  /// Name of the Neno emoji "party" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'احتفال'**
  String get emojiNenoParty;

  /// Name of the Neno emoji "kiss" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'بوسة'**
  String get emojiNenoKiss;

  /// Name of the Neno emoji "blush" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مستحي'**
  String get emojiNenoBlush;

  /// Name of the Neno emoji "rose" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'وردة'**
  String get emojiNenoRose;

  /// Name of the Neno emoji "heartbeat" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'قلبي يدق'**
  String get emojiNenoHeartbeat;

  /// Name of the Neno emoji "flirt" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'غزل'**
  String get emojiNenoFlirt;

  /// Name of the Neno emoji "melt" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ذايب'**
  String get emojiNenoMelt;

  /// Name of the Neno emoji "iloveu" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'أحبك'**
  String get emojiNenoIloveu;

  /// Name of the Neno emoji "serenade" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'يغني لها'**
  String get emojiNenoSerenade;

  /// Name of the Flags emoji "jo" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'الأردن'**
  String get emojiFlagsJo;

  /// Name of the Flags emoji "ps" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'فلسطين'**
  String get emojiFlagsPs;

  /// Name of the Flags emoji "sa" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'السعودية'**
  String get emojiFlagsSa;

  /// Name of the Flags emoji "eg" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'مصر'**
  String get emojiFlagsEg;

  /// Name of the Flags emoji "iq" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'العراق'**
  String get emojiFlagsIq;

  /// Name of the Flags emoji "sy" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'سوريا'**
  String get emojiFlagsSy;

  /// Name of the Flags emoji "ye" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'اليمن'**
  String get emojiFlagsYe;

  /// Name of the Flags emoji "ae" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'الإمارات'**
  String get emojiFlagsAe;

  /// Name of the Flags emoji "kw" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'الكويت'**
  String get emojiFlagsKw;

  /// Name of the Flags emoji "qa" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'قطر'**
  String get emojiFlagsQa;

  /// Name of the Flags emoji "bh" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'البحرين'**
  String get emojiFlagsBh;

  /// Name of the Flags emoji "om" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'عُمان'**
  String get emojiFlagsOm;

  /// Name of the Flags emoji "lb" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'لبنان'**
  String get emojiFlagsLb;

  /// Name of the Flags emoji "ma" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'المغرب'**
  String get emojiFlagsMa;

  /// Name of the Flags emoji "dz" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'الجزائر'**
  String get emojiFlagsDz;

  /// Name of the Flags emoji "tn" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'تونس'**
  String get emojiFlagsTn;

  /// Name of the Flags emoji "ly" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'ليبيا'**
  String get emojiFlagsLy;

  /// Name of the Flags emoji "sd" (screen readers, picker; D66/D102).
  ///
  /// In ar, this message translates to:
  /// **'السودان'**
  String get emojiFlagsSd;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق صورة أو فيديو'**
  String get attachButton;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'صورة أو فيديو من المعرض'**
  String get attachGallery;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة'**
  String get attachTakePhoto;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل فيديو'**
  String get attachRecordVideo;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الصور أو الكاميرا. تحقّق من صلاحيات التطبيق في الإعدادات.'**
  String get attachFailed;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get attachPhotoLabel;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الفيديو'**
  String get attachPlayVideo;

  /// D67: attaching a photo or video in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الفيديو مؤقتًا'**
  String get attachPause;

  /// Tooltip of the disabled microphone in the chat composer: voice messages need an API (D68, CP-004).
  ///
  /// In ar, this message translates to:
  /// **'الرسائل الصوتية قريباً'**
  String get chatVoiceSoon;

  /// Peer status in a conversation header (D68).
  ///
  /// In ar, this message translates to:
  /// **'متصل الآن'**
  String get chatOnline;

  /// Day separator chip in a conversation (D68).
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get chatToday;

  /// Screen-reader label of one tick on a sent message.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت'**
  String get chatStatusSent;

  /// Screen-reader label of two grey ticks.
  ///
  /// In ar, this message translates to:
  /// **'وصلت'**
  String get chatStatusDelivered;

  /// Screen-reader label of two ticks once read.
  ///
  /// In ar, this message translates to:
  /// **'قُرئت'**
  String get chatStatusRead;

  /// Typing indicator, read by screen readers.
  ///
  /// In ar, this message translates to:
  /// **'{name} يكتب الآن'**
  String chatTyping(String name);

  /// Search field hint above the conversation list (D68).
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المحادثات'**
  String get conversationsSearch;

  /// Title of the row of people online now (D68).
  ///
  /// In ar, this message translates to:
  /// **'نشطون الآن'**
  String get conversationsActiveNow;

  /// Filter chip: every conversation.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get conversationsFilterAll;

  /// Filter chip: unread conversations.
  ///
  /// In ar, this message translates to:
  /// **'غير المقروءة'**
  String get conversationsFilterUnread;

  /// Filter chip: group conversations.
  ///
  /// In ar, this message translates to:
  /// **'المجموعات'**
  String get conversationsFilterGroups;

  /// Filter chip: favourite conversations.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get conversationsFilterFavorites;

  /// Shown when the search or filter matches nothing.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محادثات مطابقة'**
  String get conversationsNoMatch;

  /// Screen-reader note on a muted conversation.
  ///
  /// In ar, this message translates to:
  /// **'مكتومة'**
  String get conversationsMuted;

  /// Screen-reader count of unread messages in a conversation.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{رسالة واحدة غير مقروءة} =2{رسالتان غير مقروءتين} few{{count} رسائل غير مقروءة} other{{count} رسالة غير مقروءة}}'**
  String conversationsUnreadCount(int count);

  /// Title and button of the new-message sheet in the conversation list (D68).
  ///
  /// In ar, this message translates to:
  /// **'رسالة جديدة'**
  String get conversationsNewMessage;

  /// Search hint in the new-message sheet (D68).
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن شخص'**
  String get conversationsSearchPeople;

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'أرسل هدية'**
  String get chatGiftButton;

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'أرسل هدية إلى {name}'**
  String chatGiftTitle(String name);

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get chatGiftQuantity;

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'اختر هدية'**
  String get chatGiftPick;

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'أرسل {gift}'**
  String chatGiftSendNamed(String gift);

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'هديتك: {gift}'**
  String chatGiftYours(String gift);

  /// Gift box in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'هدية من {name}: {gift}'**
  String chatGiftFrom(String name, String gift);

  /// Caption under a gift in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'هديتك'**
  String get chatGiftYoursCaption;

  /// Caption under a gift in a conversation (D69).
  ///
  /// In ar, this message translates to:
  /// **'هدية من {name}'**
  String chatGiftFromCaption(String name);

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'الجولة الأخيرة {time}'**
  String pkFinalRound(String time);

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'الصوت مكتوم'**
  String get livePreviewMuted;

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'{gift} من {name}'**
  String livePreviewGiftSent(String name, String gift);

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get livePreviewGallery;

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'معرض الهدايا {have} من {total}'**
  String livePreviewGalleryProgress(String have, String total);

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'دعوة ضيوف'**
  String get livePreviewGuests;

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'تحدّي PK فردي'**
  String get previewsHubLivePk2;

  /// Live preview, solo and PK layouts (D71).
  ///
  /// In ar, this message translates to:
  /// **'تحدّي PK ثنائي'**
  String get previewsHubLivePk4;

  /// PK battle animations (D71).
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المعركة'**
  String get pkBattleStart;

  /// PK battle animations (D71).
  ///
  /// In ar, this message translates to:
  /// **'تشغيل حركة المعركة (تجربة)'**
  String get livePreviewPlayBattle;

  /// D73: debug live preview, plays a whole PK round on the score bar.
  ///
  /// In ar, this message translates to:
  /// **'محاكاة جولة كاملة'**
  String get livePreviewSimulateRound;

  /// D76: the line under a newcomer's name and level badges in the live chat.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى البث'**
  String get livePreviewJoinedLine;

  /// D79: live preview Host settings (chat text size).
  ///
  /// In ar, this message translates to:
  /// **'إعدادات المضيف'**
  String get livePreviewHostSettings;

  /// D79: live preview Host settings (chat text size).
  ///
  /// In ar, this message translates to:
  /// **'حجم خط الدردشة'**
  String get livePreviewChatTextSize;

  /// D79: live preview Host settings (chat text size).
  ///
  /// In ar, this message translates to:
  /// **'صغير'**
  String get livePreviewTextSmall;

  /// D79: live preview Host settings (chat text size).
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get livePreviewTextMedium;

  /// D79: live preview Host settings (chat text size).
  ///
  /// In ar, this message translates to:
  /// **'كبير'**
  String get livePreviewTextLarge;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'المشاهدون {count}'**
  String liveViewersTab(String count);

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب المساهمة'**
  String get liveRankingTab;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'يومية'**
  String get livePeriodDaily;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعية'**
  String get livePeriodWeekly;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'شهرية'**
  String get livePeriodMonthly;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'كيف يُحسب الترتيب؟'**
  String get liveRankingHelp;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'يُرتَّب المستخدمون حسب النقاط التي جمعوها في الفترة المختارة. هدايا الجاذبية تحسب الهدايا التي استلموها (الجاذبية)، وهدايا الساحر تحسب هدايا الحظ التي أرسلوها (الساحر)، ولا يُخلط النظامان. ويبيّن العد التنازلي متى تنتهي الجولة الحالية.'**
  String get liveRankingHelpBody;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'أرسل الهدايا لتصبح من كبار الداعمين'**
  String get liveRankingEmpty;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get liveRankingYou;

  /// D82: live viewers box / contribution ranking.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الترتيب'**
  String get liveGetRanked;

  /// No description provided for @livePeriodHourly.
  ///
  /// In ar, this message translates to:
  /// **'في الساعة'**
  String get livePeriodHourly;

  /// No description provided for @livePeriodPrevious.
  ///
  /// In ar, this message translates to:
  /// **'الفترة السابقة'**
  String get livePeriodPrevious;

  /// No description provided for @livePeriodNext.
  ///
  /// In ar, this message translates to:
  /// **'الفترة التالية'**
  String get livePeriodNext;

  /// No description provided for @liveCountdown.
  ///
  /// In ar, this message translates to:
  /// **'العد التنازلي'**
  String get liveCountdown;

  /// No description provided for @liveGiftFilter.
  ///
  /// In ar, this message translates to:
  /// **'فلتر الهدايا'**
  String get liveGiftFilter;

  /// No description provided for @liveGiftsAttraction.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الجاذبية'**
  String get liveGiftsAttraction;

  /// No description provided for @liveGiftsWizard.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الساحر'**
  String get liveGiftsWizard;

  /// No description provided for @liveRankingList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الترتيب'**
  String get liveRankingList;

  /// No description provided for @livePeriodOverall.
  ///
  /// In ar, this message translates to:
  /// **'الكلي'**
  String get livePeriodOverall;

  /// No description provided for @liveRankingAllTime.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب الكلي'**
  String get liveRankingAllTime;

  /// No description provided for @liveHostRankingPlace.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب هذا المضيف'**
  String get liveHostRankingPlace;

  /// No description provided for @liveHostRankingHelpBody.
  ///
  /// In ar, this message translates to:
  /// **'يُرتَّب المضيفون فيما بينهم حسب الهدايا التي استلموها في الفترة المختارة: هذه الساعة أو اليوم أو هذا الشهر أو الترتيب الكلي. ويبيّن العد التنازلي متى تنتهي الجولة الحالية.'**
  String get liveHostRankingHelpBody;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'مستوياتي'**
  String get levelsTitle;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'تزيد نقاطك من الهدايا والإنفاق في الألعاب بعد تأكيدها. لكل مستوى نقاطه الخاصة.'**
  String get levelsIntro;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'المستويات قيد التجهيز. ستظهر نقاطك هنا عند تفعيل الهدايا والألعاب.'**
  String get levelsPreparing;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'غير مفعّل بعد'**
  String get levelsUnavailable;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'هذا المستوى غير مفعّل بعد. ستظهر نقاطك ومستواك هنا عند تفعيله.'**
  String get levelsUnavailableBody;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مستوى بعد'**
  String get levelsNoLevel;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'المستوى {number}'**
  String levelsLevelNumber(int number);

  /// D72: levels (CP-005). Points are pre-formatted with Latin digits and separators.
  ///
  /// In ar, this message translates to:
  /// **'{points} نقطة'**
  String levelsPoints(String points);

  /// D72: levels (CP-005). Points are pre-formatted with Latin digits and separators.
  ///
  /// In ar, this message translates to:
  /// **'{points} للمستوى التالي'**
  String levelsToNext(String points);

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'{points} نقطة للوصول إلى {level}'**
  String levelsToNamed(String points, String level);

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'أعلى مستوى'**
  String get levelsMax;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'كل المستويات'**
  String get levelsLadder;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'مستواك'**
  String get levelsCurrent;

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المستويات'**
  String get levelsLoadError;

  /// No description provided for @navMoments.
  ///
  /// In ar, this message translates to:
  /// **'اللحظات'**
  String get navMoments;

  /// No description provided for @navMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get navMessages;

  /// No description provided for @demoDataTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات تجريبية'**
  String get demoDataTitle;

  /// No description provided for @demoDataBody.
  ///
  /// In ar, this message translates to:
  /// **'لنسخ التجربة فقط: تعرض الشاشات المصمَّمة ببيانات تجريبية معلَّمة حيث لا توجد خدمة بعد. إيقافها يخرج من الحساب التجريبي.'**
  String get demoDataBody;

  /// No description provided for @demoDataTry.
  ///
  /// In ar, this message translates to:
  /// **'جرّب ببيانات تجريبية'**
  String get demoDataTry;

  /// KL-060: footer error of the posts feed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المزيد من المنشورات'**
  String get feedPostsLoadMoreFailed;

  /// KL-060: like button of a post.
  ///
  /// In ar, this message translates to:
  /// **'إعجاب'**
  String get feedPostLike;

  /// KL-060: like button of a liked post.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإعجاب'**
  String get feedPostUnlike;

  /// KL-060: save button of a post.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get feedPostSave;

  /// KL-060: save button of a saved post.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحفظ'**
  String get feedPostUnsave;

  /// KL-060: semantics of a post's comment count.
  ///
  /// In ar, this message translates to:
  /// **'{count} تعليق'**
  String feedPostCommentCount(String count);

  /// KL-060: semantics of a post's share count.
  ///
  /// In ar, this message translates to:
  /// **'{count} مشاركة'**
  String feedPostShareCount(String count);

  /// KL-060: line above a repost in the Following feed.
  ///
  /// In ar, this message translates to:
  /// **'أعاد {name} نشره'**
  String feedPostRepostedBy(String name);

  /// KL-060: a post with photos waiting for moderation (author only).
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة — يظهر لك وحدك حتى تتم مراجعته'**
  String get feedPostPending;

  /// KL-060: more sheet.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء هذا المنشور'**
  String get feedPostHide;

  /// KL-060: after hiding.
  ///
  /// In ar, this message translates to:
  /// **'أُخفي المنشور من خلاصتك'**
  String get feedPostHidden;

  /// KL-060: more sheet.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن المنشور'**
  String get feedPostReport;

  /// KL-060: title of the reason sheet.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذا المنشور؟'**
  String get feedPostReportTitle;

  /// KL-060: after a report.
  ///
  /// In ar, this message translates to:
  /// **'شكراً، وصلنا بلاغك'**
  String get feedPostReported;

  /// KL-060: more sheet (own post).
  ///
  /// In ar, this message translates to:
  /// **'حذف المنشور'**
  String get feedPostDelete;

  /// KL-060: confirm dialog.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا المنشور نهائياً؟'**
  String get feedPostDeleteConfirm;

  /// KL-060: after delete.
  ///
  /// In ar, this message translates to:
  /// **'حُذف المنشور'**
  String get feedPostDeleted;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'رسائل مزعجة'**
  String get reportReasonSpam;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'عُري أو محتوى جنسي'**
  String get reportReasonNudity;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'عنف'**
  String get reportReasonViolence;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'خطاب كراهية'**
  String get reportReasonHate;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'تحرّش أو تنمّر'**
  String get reportReasonHarassment;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'محتوى غير قانوني'**
  String get reportReasonIllegal;

  /// KL-060 report reason.
  ///
  /// In ar, this message translates to:
  /// **'سبب آخر'**
  String get reportReasonOther;

  /// v1.5-social MEDIA_UPLOADS_UNAVAILABLE.
  ///
  /// In ar, this message translates to:
  /// **'رفع الصور غير متاح حالياً.'**
  String get errorMediaUploadsUnavailable;

  /// v1.5-social MEDIA_INVALID.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الصورة. جرّب صورة أخرى.'**
  String get errorMediaInvalid;

  /// v1.5-social PIN_LIMIT_REACHED.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تثبيت 3 منشورات فقط.'**
  String get errorPinLimitReached;

  /// v1.5-social REPORT_ALREADY_RESOLVED.
  ///
  /// In ar, this message translates to:
  /// **'تمت معالجة هذا البلاغ من قبل.'**
  String get errorReportAlreadyResolved;

  /// KL-060 Create screen title.
  ///
  /// In ar, this message translates to:
  /// **'منشور جديد'**
  String get createTitle;

  /// KL-060 publish button.
  ///
  /// In ar, this message translates to:
  /// **'نشر'**
  String get createShare;

  /// KL-060 caption hint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب وصف المنشور…'**
  String get createTextHint;

  /// KL-060 location hint.
  ///
  /// In ar, this message translates to:
  /// **'أضف موقعاً (اختياري)'**
  String get createLocationHint;

  /// KL-060 add photos tile.
  ///
  /// In ar, this message translates to:
  /// **'إضافة صور'**
  String get createAddPhotos;

  /// KL-060 remove one photo.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الصورة'**
  String get createRemovePhoto;

  /// KL-060 the order badge on a draft photo (1 = first in the post).
  ///
  /// In ar, this message translates to:
  /// **'{index}'**
  String createPhotoNumber(int index);

  /// KL-060 photo semantics.
  ///
  /// In ar, this message translates to:
  /// **'صورة {index} من {total}'**
  String createPhotoLabel(int index, int total);

  /// KL-060 upload progress.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ رفع الصور ({current} من {total})…'**
  String createUploading(int current, int total);

  /// KL-060 creating the post.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ النشر…'**
  String get createPublishing;

  /// KL-060 after a text post.
  ///
  /// In ar, this message translates to:
  /// **'تم نشر منشورك'**
  String get createPosted;

  /// KL-060 after a photo post (moderation PENDING).
  ///
  /// In ar, this message translates to:
  /// **'تم النشر. سيظهر للآخرين بعد مراجعة الصور'**
  String get createPostedInReview;

  /// KL-060 note under the form (CP-006 Q2).
  ///
  /// In ar, this message translates to:
  /// **'المنشورات التي فيها صور تظهر للآخرين بعد مراجعتها.'**
  String get createPhotosReviewNote;

  /// KL-060 picked photo refused (type from bytes).
  ///
  /// In ar, this message translates to:
  /// **'صيغة هذه الصورة غير مدعومة. استخدم JPEG أو PNG أو WebP.'**
  String get createPhotoUnsupported;

  /// KL-060 picked photo too big.
  ///
  /// In ar, this message translates to:
  /// **'الصورة أكبر من 15 ميغابايت.'**
  String get createPhotoTooLarge;

  /// KL-060 photo limit.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إضافة {max} صور كحدّ أقصى.'**
  String createPhotoTooMany(int max);

  /// KL-060 picker refused.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الوصول إلى الصور. اسمح بالوصول من الإعدادات.'**
  String get createPhotoAccessDenied;

  /// KL-060 MEDIA_UPLOADS_UNAVAILABLE on Create.
  ///
  /// In ar, this message translates to:
  /// **'رفع الصور غير متاح حالياً. أزل الصور لتنشر نصاً فقط، أو حاول لاحقاً.'**
  String get createUploadsUnavailable;

  /// KL-060 MEDIA_INVALID on Create.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت معالجة إحدى الصور. أزلها وحاول مجدداً.'**
  String get createPhotoInvalid;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'شارك لحظاتك مع متابعيك'**
  String get createSubtitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get createClose;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'تجاهل المنشور؟'**
  String get createDiscardTitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف النص والصور التي أضفتها.'**
  String get createDiscardBody;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get createDiscard;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'متابعة التعديل'**
  String get createKeepEditing;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إضافة المزيد'**
  String get createAddMore;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'حتى {max} صور'**
  String createUpTo(int max);

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إضافة رمز تعبيري'**
  String get createEmoji;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إضافة وسم'**
  String get createAddHashtag;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'صور'**
  String get createTypePhotos;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get createSoon;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get createPlaceTitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إضافة موقع'**
  String get createPlaceSubtitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get createPlaceSave;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'من يمكنه مشاهدة المنشور؟'**
  String get createAudienceTitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'عام - متاح للجميع'**
  String get createAudiencePublic;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'خاص - متابعوك فقط'**
  String get createAudiencePrivate;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'من يرى منشوراتك يتبع خصوصية حسابك. غيّرها من الإعدادات.'**
  String get createAudienceExplain;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get createAudienceSettings;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إشارة إلى أشخاص'**
  String get createMentionTitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إضافة أشخاص'**
  String get createMentionSubtitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'أشرت إلى أشخاص في النص'**
  String get createMentionSome;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم المستخدم أو الاسم'**
  String get createMentionSearchHint;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'اكتب لتبحث عن أشخاص'**
  String get createMentionStart;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج'**
  String get createMentionNone;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر البحث. حاول مرة أخرى.'**
  String get createMentionFailed;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إضافة وسوم'**
  String get createHashtagsTitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'مزيد من الخيارات'**
  String get createAdvancedTitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'التعليقات وعدد الإعجابات'**
  String get createAdvancedSubtitle;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'السماح بالتعليقات'**
  String get createCommentsOn;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'الجميع يمكنهم التعليق'**
  String get createWhoEveryone;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'متابعوك فقط'**
  String get createWhoFollowers;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'لا أحد'**
  String get createWhoNobody;

  /// KL-060 Create screen (owner reference).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء عدد الإعجابات'**
  String get createHideLikes;

  /// KL-060 media step subtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر صورة أو أكثر'**
  String get createMediaSubtitle;

  /// KL-060 media step: go to details.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get createNext;

  /// KL-060 details step: back to media.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get createBack;

  /// KL-060 media filter.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get createTabAll;

  /// KL-060 media filter (no video before M2).
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get createTabVideo;

  /// KL-060 under the selected count.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديدها'**
  String get createSelected;

  /// KL-060 media step note.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تحديد حتى {max} صور'**
  String createSelectUpTo(int max);

  /// KL-060 step 1 label.
  ///
  /// In ar, this message translates to:
  /// **'الوسائط'**
  String get createStepMedia;

  /// KL-060 step 2 label.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get createStepDetails;

  /// KL-060 step semantics.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {step} من {total}: {label}'**
  String createStepOf(int step, int total, String label);

  /// KL-060 hint under the strip.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولاً واسحب لترتيب الصور'**
  String get createLongPressReorder;

  /// KL-060 AI caption tool (no API yet).
  ///
  /// In ar, this message translates to:
  /// **'اقتراح وصف بالذكاء الاصطناعي'**
  String get createAiCaption;

  /// KL-060 hashtags row example.
  ///
  /// In ar, this message translates to:
  /// **'مثل #البتراء #سفر #أردن'**
  String get createHashtagsExample;

  /// KL-060 no library (web).
  ///
  /// In ar, this message translates to:
  /// **'معرض الصور غير متاح هنا. اختر الصور من جهازك.'**
  String get createLibraryUnsupported;

  /// KL-060 library access refused.
  ///
  /// In ar, this message translates to:
  /// **'اسمح لكبسو بالوصول إلى صورك لتختار منها هنا، أو اختر من جهازك.'**
  String get createLibraryDenied;

  /// KL-060 library error.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح معرض الصور.'**
  String get createLibraryFailed;

  /// KL-060 empty library.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صور على هذا الجهاز.'**
  String get createLibraryEmpty;

  /// KL-060 limited access.
  ///
  /// In ar, this message translates to:
  /// **'يرى كبسو بعض صورك فقط.'**
  String get createLibraryLimited;

  /// KL-060 change limited selection.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get createLibraryManage;

  /// KL-060 open settings for access.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالوصول'**
  String get createLibraryAllow;

  /// KL-060 system picker.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من الجهاز'**
  String get createPickFromDevice;

  /// KL-060 library tile semantics.
  ///
  /// In ar, this message translates to:
  /// **'صورة من المعرض'**
  String get createLibraryPhoto;

  /// KL-060 comments: none.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تعليقات بعد'**
  String get commentsEmpty;

  /// KL-060 comments: none.
  ///
  /// In ar, this message translates to:
  /// **'كن أول من يعلّق.'**
  String get commentsEmptyHint;

  /// KL-060 comments: load error.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل التعليقات.'**
  String get commentsFailed;

  /// KL-060 comments: next page error.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المزيد.'**
  String get commentsMoreFailed;

  /// KL-060 reply banner.
  ///
  /// In ar, this message translates to:
  /// **'الرد على {name}'**
  String commentsReplyingTo(String name);

  /// KL-060 reply banner close.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرد'**
  String get commentsCancelReply;

  /// KL-060 commentsEnabled false or NOBODY.
  ///
  /// In ar, this message translates to:
  /// **'التعليقات مغلقة على هذا المنشور.'**
  String get commentsClosed;

  /// KL-060 comment 403.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك التعليق على هذا المنشور.'**
  String get commentsNotAllowed;

  /// KL-060 pinned label.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت'**
  String get commentsPinned;

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت التعليق'**
  String get commentsPin;

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get commentsUnpin;

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'حذف التعليق'**
  String get commentsDelete;

  /// KL-060 confirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف التعليق؟'**
  String get commentsDeleteTitle;

  /// KL-060 confirm body (top level).
  ///
  /// In ar, this message translates to:
  /// **'ستُحذف الردود عليه أيضاً.'**
  String get commentsDeleteWithReplies;

  /// KL-060 snack.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التعليق'**
  String get commentsDeleted;

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن التعليق'**
  String get commentsReport;

  /// KL-060 report sheet.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذا التعليق؟'**
  String get commentsReportTitle;

  /// KL-060 menu semantics.
  ///
  /// In ar, this message translates to:
  /// **'خيارات التعليق'**
  String get commentsMore;

  /// KL-060 next replies page.
  ///
  /// In ar, this message translates to:
  /// **'عرض ردود أخرى ({count})'**
  String commentsMoreReplies(int count);

  /// KL-060 comment button semantics.
  ///
  /// In ar, this message translates to:
  /// **'عرض التعليقات'**
  String get commentsOpen;

  /// KL-060 post screen title.
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get postTitle;

  /// KL-060 post 404.
  ///
  /// In ar, this message translates to:
  /// **'هذا المنشور غير متاح'**
  String get postUnavailableTitle;

  /// KL-060 post 404.
  ///
  /// In ar, this message translates to:
  /// **'ربما حُذف، أو أن صاحبه لا يتيحه لك.'**
  String get postUnavailableBody;

  /// KL-060 grid cell semantics.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت'**
  String get profileGridPinned;

  /// KL-060 grid cell semantics.
  ///
  /// In ar, this message translates to:
  /// **'فتح المنشور'**
  String get profileGridOpenPost;

  /// KL-060 search field.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن أشخاص أو وسوم أو منشورات'**
  String get searchHint;

  /// KL-060 search clear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get searchClear;

  /// KL-060 search type.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get searchTabUsers;

  /// KL-060 search type.
  ///
  /// In ar, this message translates to:
  /// **'الوسوم'**
  String get searchTabHashtags;

  /// KL-060 search type.
  ///
  /// In ar, this message translates to:
  /// **'المنشورات'**
  String get searchTabPosts;

  /// KL-060 search empty query.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في كبسو'**
  String get searchPromptTitle;

  /// KL-060 search empty query.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسماً أو وسماً أو كلمة من منشور.'**
  String get searchPromptBody;

  /// KL-060 search empty.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج لـ «{query}»'**
  String searchNoResults(String query);

  /// KL-060 hashtag count.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا منشورات} =1{منشور واحد} =2{منشوران} few{{count} منشورات} many{{count} منشورًا} other{{count} منشور}}'**
  String hashtagPostCount(int count);

  /// KL-060 hashtag sort.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get hashtagRecent;

  /// KL-060 hashtag sort.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر تفاعلاً'**
  String get hashtagTop;

  /// KL-060 hashtag 404.
  ///
  /// In ar, this message translates to:
  /// **'لا منشورات بهذا الوسم'**
  String get hashtagNotFoundTitle;

  /// KL-060 hashtag 404.
  ///
  /// In ar, this message translates to:
  /// **'لم يُستخدم هذا الوسم في منشور ظاهر بعد.'**
  String get hashtagNotFoundBody;

  /// KL-060 hashtag empty.
  ///
  /// In ar, this message translates to:
  /// **'لا منشورات هنا بعد'**
  String get hashtagEmpty;

  /// KL-060 a hashtag as shown.
  ///
  /// In ar, this message translates to:
  /// **'#{tag}'**
  String hashtagLabel(String tag);

  /// KL-060 block action.
  ///
  /// In ar, this message translates to:
  /// **'حظر'**
  String get safetyBlock;

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'حظر {name}'**
  String safetyBlockUser(String name);

  /// KL-060 confirm.
  ///
  /// In ar, this message translates to:
  /// **'حظر {name}؟'**
  String safetyBlockTitle(String name);

  /// KL-060 confirm.
  ///
  /// In ar, this message translates to:
  /// **'لن يرى أحدكما منشورات الآخر أو تعليقاته أو ملفه، وتُلغى المتابعة بينكما. يمكنك إلغاء الحظر من الإعدادات.'**
  String get safetyBlockBody;

  /// KL-060 snack.
  ///
  /// In ar, this message translates to:
  /// **'تم حظر {name}'**
  String safetyBlocked(String name);

  /// KL-060 blocked list.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get safetyUnblock;

  /// KL-060 snack.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي حظر {name}'**
  String safetyUnblocked(String name);

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'كتم {name}'**
  String safetyMuteUser(String name);

  /// KL-060 snack.
  ///
  /// In ar, this message translates to:
  /// **'تم كتم {name}: لن تظهر منشوراته في خلاصتك'**
  String safetyMuted(String name);

  /// KL-060 snack action.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get safetyUndo;

  /// KL-060 menu.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن الحساب'**
  String get safetyReportUser;

  /// KL-060 report sheet.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذا الحساب؟'**
  String get safetyReportTitle;

  /// KL-060 settings section.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية والأمان'**
  String get safetySection;

  /// KL-060 settings.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get safetyPrivacy;

  /// KL-060 settings.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات المحظورة'**
  String get safetyBlockedAccounts;

  /// KL-060 blocked empty.
  ///
  /// In ar, this message translates to:
  /// **'لم تحظر أحداً'**
  String get safetyNoBlocked;

  /// KL-060 blocked empty.
  ///
  /// In ar, this message translates to:
  /// **'من تحظره يظهر هنا، ويمكنك إلغاء حظره متى شئت.'**
  String get safetyNoBlockedBody;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'من يمكنه الإشارة إليك'**
  String get privacyMentionTitle;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'الجميع'**
  String get privacyMentionEveryone;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'من تتابعهم فقط'**
  String get privacyMentionFollowing;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد'**
  String get privacyMentionNobody;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'من يمكنه التعليق على منشوراتك الجديدة'**
  String get privacyCommentTitle;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تغيير ذلك لكل منشور من «مزيد من الخيارات».'**
  String get privacyCommentHint;

  /// KL-060 privacy.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get privacySaved;

  /// CP-007 settings.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات المكتومة'**
  String get safetyMutedAccounts;

  /// CP-007 empty.
  ///
  /// In ar, this message translates to:
  /// **'لم تكتم أحداً'**
  String get safetyNoMuted;

  /// CP-007 empty.
  ///
  /// In ar, this message translates to:
  /// **'من تكتمه يظهر هنا، ويمكنك إلغاء كتمه متى شئت. لا يعرف أحد أنك كتمته.'**
  String get safetyNoMutedBody;

  /// CP-007 action.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get safetyUnmute;

  /// CP-007 menu.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء كتم {name}'**
  String safetyUnmuteUser(String name);

  /// CP-007 snack.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي كتم {name}'**
  String safetyUnmuted(String name);

  /// Title of the screen listing who liked a post
  ///
  /// In ar, this message translates to:
  /// **'الإعجابات'**
  String get likersTitle;

  /// Accessibility label of a post's like count, which opens the likers
  ///
  /// In ar, this message translates to:
  /// **'عرض من أعجبه المنشور'**
  String get likersOpen;

  /// Likers list empty title
  ///
  /// In ar, this message translates to:
  /// **'لا إعجابات بعد'**
  String get likersEmpty;

  /// Likers list empty body
  ///
  /// In ar, this message translates to:
  /// **'عندما يعجب أحد بهذا المنشور سيظهر هنا.'**
  String get likersEmptyBody;

  /// Likers list when the author hides like counts
  ///
  /// In ar, this message translates to:
  /// **'الإعجابات مخفية'**
  String get likersHiddenTitle;

  /// Likers list hidden body
  ///
  /// In ar, this message translates to:
  /// **'أخفى صاحب المنشور عدد الإعجابات، فلا يرى القائمة غيره.'**
  String get likersHiddenBody;

  /// Repost button label
  ///
  /// In ar, this message translates to:
  /// **'إعادة النشر'**
  String get feedPostRepost;

  /// Repost button label when already reposted
  ///
  /// In ar, this message translates to:
  /// **'إلغاء إعادة النشر'**
  String get feedPostUnrepost;

  /// Message after reposting
  ///
  /// In ar, this message translates to:
  /// **'أُعيد نشره لمتابعيك'**
  String get feedPostReposted;

  /// Message after undoing a repost
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت إعادة النشر'**
  String get feedPostUnreposted;

  /// Repost refused (own post or a private account)
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إعادة نشر هذا المنشور'**
  String get feedPostRepostRefused;

  /// Profile Reposts tab label
  ///
  /// In ar, this message translates to:
  /// **'إعادات النشر'**
  String get profileReposts;

  /// Profile Reposts tab empty title
  ///
  /// In ar, this message translates to:
  /// **'لا إعادات نشر بعد'**
  String get profileNoReposts;

  /// Profile Reposts tab empty body
  ///
  /// In ar, this message translates to:
  /// **'المنشورات التي تُعاد نشرها تظهر هنا.'**
  String get profileRepostsEmptyBody;

  /// Own post menu: pin it on the profile
  ///
  /// In ar, this message translates to:
  /// **'تثبيت في الملف الشخصي'**
  String get feedPostPin;

  /// Own post menu: unpin it
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get feedPostUnpin;

  /// Message after pinning
  ///
  /// In ar, this message translates to:
  /// **'ثُبّت في ملفك الشخصي'**
  String get feedPostPinned;

  /// Message after unpinning
  ///
  /// In ar, this message translates to:
  /// **'أُلغي التثبيت'**
  String get feedPostUnpinned;

  /// Own post menu: edit
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get feedPostEdit;

  /// Post time with the edited mark
  ///
  /// In ar, this message translates to:
  /// **'{time} · معدّل'**
  String feedPostTimeEdited(String time);

  /// Edit post screen title
  ///
  /// In ar, this message translates to:
  /// **'تعديل المنشور'**
  String get editPostTitle;

  /// Edit post save action
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get editPostSave;

  /// Message after saving an edit
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات'**
  String get editPostSaved;

  /// Edit post: note under the photos
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تغيير الصور بعد النشر.'**
  String get editPostPhotosFixed;

  /// Edit post: a text-only post cannot be emptied
  ///
  /// In ar, this message translates to:
  /// **'المنشور النصي يحتاج إلى نص.'**
  String get editPostTextRequired;

  /// Edit post: leaving with unsaved changes
  ///
  /// In ar, this message translates to:
  /// **'تجاهل التعديلات؟'**
  String get editPostDiscardTitle;

  /// Edit post: stay
  ///
  /// In ar, this message translates to:
  /// **'متابعة التعديل'**
  String get editPostKeep;

  /// Edit post: leave without saving
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get editPostDiscard;

  /// Edit post: no place set
  ///
  /// In ar, this message translates to:
  /// **'بلا موقع'**
  String get editPostNoPlace;

  /// Edit post: clear the place
  ///
  /// In ar, this message translates to:
  /// **'إزالة الموقع'**
  String get editPostRemovePlace;

  /// Create: schedule row title
  ///
  /// In ar, this message translates to:
  /// **'وقت النشر'**
  String get createScheduleTitle;

  /// Create: schedule row when publishing now
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get createScheduleNow;

  /// A scheduled date and time
  ///
  /// In ar, this message translates to:
  /// **'{date}، {time}'**
  String createScheduleAt(String date, String time);

  /// Create: the action pill when a time is set
  ///
  /// In ar, this message translates to:
  /// **'جدولة'**
  String get createScheduleAction;

  /// Create: clear the scheduled time
  ///
  /// In ar, this message translates to:
  /// **'النشر الآن'**
  String get createScheduleClear;

  /// Schedule time out of range
  ///
  /// In ar, this message translates to:
  /// **'اختر وقتاً بعد 5 دقائق على الأقل وخلال 30 يوماً.'**
  String get createScheduleWindow;

  /// Message after scheduling
  ///
  /// In ar, this message translates to:
  /// **'سيُنشر في {when}'**
  String createScheduled(String when);

  /// Create close dialog: save as draft
  ///
  /// In ar, this message translates to:
  /// **'حفظ كمسودة'**
  String get createSaveDraft;

  /// Create close dialog body when a draft can be saved
  ///
  /// In ar, this message translates to:
  /// **'احفظه كمسودة لتكمله لاحقاً، أو تجاهله.'**
  String get createDiscardOrDraftBody;

  /// Message after saving a draft
  ///
  /// In ar, this message translates to:
  /// **'حُفظت المسودة'**
  String get createDraftSaved;

  /// Drafts screen title and profile button tooltip
  ///
  /// In ar, this message translates to:
  /// **'المسودات والمجدولة'**
  String get draftsTitle;

  /// Drafts screen: drafts tab
  ///
  /// In ar, this message translates to:
  /// **'المسودات'**
  String get draftsTabDrafts;

  /// Drafts screen: scheduled tab
  ///
  /// In ar, this message translates to:
  /// **'المجدولة'**
  String get draftsTabScheduled;

  /// Drafts empty title
  ///
  /// In ar, this message translates to:
  /// **'لا مسودات'**
  String get draftsEmpty;

  /// Drafts empty body
  ///
  /// In ar, this message translates to:
  /// **'عند إغلاق منشور يمكنك حفظه كمسودة.'**
  String get draftsEmptyBody;

  /// Scheduled empty title
  ///
  /// In ar, this message translates to:
  /// **'لا منشورات مجدولة'**
  String get scheduledEmpty;

  /// Scheduled empty body
  ///
  /// In ar, this message translates to:
  /// **'اختر «وقت النشر» عند إنشاء منشور لجدولته.'**
  String get scheduledEmptyBody;

  /// Draft row: when it was saved
  ///
  /// In ar, this message translates to:
  /// **'حُفظت {when}'**
  String draftsSavedOn(String when);

  /// Scheduled row: when it publishes
  ///
  /// In ar, this message translates to:
  /// **'يُنشر {when}'**
  String draftsPublishesOn(String when);

  /// Draft row with photos only
  ///
  /// In ar, this message translates to:
  /// **'بلا نص'**
  String get draftsNoText;

  /// Confirm deleting a draft or scheduled post
  ///
  /// In ar, this message translates to:
  /// **'حذف هذه المسودة؟'**
  String get draftsDeleteConfirm;

  /// Message after deleting a draft
  ///
  /// In ar, this message translates to:
  /// **'حُذفت'**
  String get draftsDeleted;

  /// Edit a draft: publish it
  ///
  /// In ar, this message translates to:
  /// **'انشر الآن'**
  String get editPostPublishNow;

  /// Edit a draft: schedule it
  ///
  /// In ar, this message translates to:
  /// **'جدولة'**
  String get editPostSchedule;

  /// Edit a scheduled post: new time
  ///
  /// In ar, this message translates to:
  /// **'تغيير الموعد'**
  String get editPostReschedule;

  /// Edit a scheduled post: back to drafts
  ///
  /// In ar, this message translates to:
  /// **'نقل إلى المسودات'**
  String get editPostToDrafts;

  /// Message after publishing a draft
  ///
  /// In ar, this message translates to:
  /// **'نُشر المنشور'**
  String get editPostPublished;

  /// Message after unscheduling
  ///
  /// In ar, this message translates to:
  /// **'نُقل إلى المسودات'**
  String get editPostMovedToDrafts;

  /// Edit screen: status of a draft
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get editPostDraftBadge;

  /// Edit screen: status of a scheduled post
  ///
  /// In ar, this message translates to:
  /// **'مجدول: {when}'**
  String editPostScheduledBadge(String when);

  /// Stories tray: the caller's own entry
  ///
  /// In ar, this message translates to:
  /// **'قصتك'**
  String get storyYourStory;

  /// Stories tray: add a story (accessibility)
  ///
  /// In ar, this message translates to:
  /// **'أضف قصة'**
  String get storyAdd;

  /// Stories tray: open an account's stories (accessibility)
  ///
  /// In ar, this message translates to:
  /// **'عرض قصة {name}'**
  String storyOpen(String name);

  /// Story viewer: more button
  ///
  /// In ar, this message translates to:
  /// **'خيارات القصة'**
  String get storyMore;

  /// Story viewer/new story: close
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get storyClose;

  /// Story viewer: delete own story
  ///
  /// In ar, this message translates to:
  /// **'حذف القصة'**
  String get storyDelete;

  /// Confirm deleting a story
  ///
  /// In ar, this message translates to:
  /// **'حذف هذه القصة؟'**
  String get storyDeleteConfirm;

  /// Message after deleting a story
  ///
  /// In ar, this message translates to:
  /// **'حُذفت القصة'**
  String get storyDeleted;

  /// Story viewer: report
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن القصة'**
  String get storyReport;

  /// Report reason sheet title for a story
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذه القصة؟'**
  String get storyReportTitle;

  /// Message after reporting a story
  ///
  /// In ar, this message translates to:
  /// **'شكراً، وصلنا البلاغ'**
  String get storyReported;

  /// Story photo accessibility label
  ///
  /// In ar, this message translates to:
  /// **'قصة {name}'**
  String storyPhotoOf(String name);

  /// Who saw a story: count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مشاهدات} =1{مشاهدة واحدة} =2{مشاهدتان} few{{count} مشاهدات} many{{count} مشاهدة} other{{count} مشاهدة}}'**
  String storyViewCount(int count);

  /// Story viewers empty title
  ///
  /// In ar, this message translates to:
  /// **'لم يشاهدها أحد بعد'**
  String get storyNoViewers;

  /// Story viewers empty body
  ///
  /// In ar, this message translates to:
  /// **'يظهر هنا من يشاهد قصتك خلال 48 ساعة من نشرها.'**
  String get storyNoViewersBody;

  /// New story screen title
  ///
  /// In ar, this message translates to:
  /// **'قصة جديدة'**
  String get storyNewTitle;

  /// New story screen explanation
  ///
  /// In ar, this message translates to:
  /// **'صورة واحدة تبقى 24 ساعة، ويمكنك إضافة نص قصير.'**
  String get storyNewBody;

  /// New story: pick a photo
  ///
  /// In ar, this message translates to:
  /// **'اختر صورة'**
  String get storyPickPhoto;

  /// New story: change the photo
  ///
  /// In ar, this message translates to:
  /// **'تغيير الصورة'**
  String get storyChangePhoto;

  /// New story: share action
  ///
  /// In ar, this message translates to:
  /// **'شارك'**
  String get storyShare;

  /// Message after posting a story
  ///
  /// In ar, this message translates to:
  /// **'نُشرت قصتك'**
  String get storyShared;

  /// New story: text hint
  ///
  /// In ar, this message translates to:
  /// **'أضف نصاً (اختياري)'**
  String get storyTextHint;

  /// New story: preview accessibility
  ///
  /// In ar, this message translates to:
  /// **'معاينة القصة'**
  String get storyPreview;

  /// Story archive screen and settings tile
  ///
  /// In ar, this message translates to:
  /// **'أرشيف القصص'**
  String get storyArchiveTitle;

  /// Story archive empty title
  ///
  /// In ar, this message translates to:
  /// **'لا قصص بعد'**
  String get storyArchiveEmpty;

  /// Story archive empty body
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ قصصك هنا بعد انتهائها، ولا يراها غيرك.'**
  String get storyArchiveEmptyBody;

  /// Story archive cell accessibility
  ///
  /// In ar, this message translates to:
  /// **'قصة {date}'**
  String storyArchiveCell(String date);

  /// Stories tray: open your own stories (accessibility)
  ///
  /// In ar, this message translates to:
  /// **'عرض قصتك'**
  String get storyOpenOwn;

  /// Notifications screen title (CP-009)
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// Bell on the Posts header: accessible label with the unread count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{الإشعارات، لا جديد} =1{الإشعارات، إشعار واحد غير مقروء} =2{الإشعارات، إشعاران غير مقروءين} few{الإشعارات، {count} إشعارات غير مقروءة} many{الإشعارات، {count} إشعارًا غير مقروء} other{الإشعارات، {count} إشعار غير مقروء}}'**
  String notificationsBell(int count);

  /// Who did it: the latest actor and how many others
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{name}} =1{{name} وشخص آخر} =2{{name} وشخصان آخران} few{{name} و{count} أشخاص آخرين} many{{name} و{count} شخصًا آخر} other{{name} و{count} شخص آخر}}'**
  String notifActors(String name, int count);

  /// Notification: post liked
  ///
  /// In ar, this message translates to:
  /// **'أعجب {who} بمنشورك'**
  String notifLikePost(String who);

  /// Notification: comment liked
  ///
  /// In ar, this message translates to:
  /// **'أعجب {who} بتعليقك'**
  String notifLikeComment(String who);

  /// Notification: comment on your post
  ///
  /// In ar, this message translates to:
  /// **'علّق {who} على منشورك'**
  String notifComment(String who);

  /// Notification: reply to your comment
  ///
  /// In ar, this message translates to:
  /// **'ردّ {who} على تعليقك'**
  String notifReply(String who);

  /// Notification: mention in a post
  ///
  /// In ar, this message translates to:
  /// **'أشار إليك {who} في منشور'**
  String notifMentionPost(String who);

  /// Notification: mention in a comment
  ///
  /// In ar, this message translates to:
  /// **'أشار إليك {who} في تعليق'**
  String notifMentionComment(String who);

  /// Notification: mention in a story
  ///
  /// In ar, this message translates to:
  /// **'أشار إليك {who} في قصة'**
  String notifMentionStory(String who);

  /// Notification: new follower
  ///
  /// In ar, this message translates to:
  /// **'بدأ {who} بمتابعتك'**
  String notifFollow(String who);

  /// Notification: repost
  ///
  /// In ar, this message translates to:
  /// **'أعاد {who} نشر منشورك'**
  String notifRepost(String who);

  /// Notification: scheduled post published
  ///
  /// In ar, this message translates to:
  /// **'نُشر منشورك المجدول'**
  String get notifPostPublished;

  /// Notification: post removed by moderation
  ///
  /// In ar, this message translates to:
  /// **'أُزيل منشورك لمخالفته إرشادات المجتمع'**
  String get notifRemovedPost;

  /// Notification: comment removed by moderation
  ///
  /// In ar, this message translates to:
  /// **'أُزيل تعليقك لمخالفته إرشادات المجتمع'**
  String get notifRemovedComment;

  /// Notification: story removed by moderation
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت قصتك لمخالفتها إرشادات المجتمع'**
  String get notifRemovedStory;

  /// Notifications section
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get notifSectionToday;

  /// Notifications section
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get notifSectionWeek;

  /// Notifications section
  ///
  /// In ar, this message translates to:
  /// **'سابقًا'**
  String get notifSectionEarlier;

  /// Accessibility: an unread notification
  ///
  /// In ar, this message translates to:
  /// **'غير مقروء'**
  String get notifUnread;

  /// Empty notifications
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات بعد'**
  String get notificationsEmpty;

  /// Empty notifications body
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا الإعجابات والتعليقات والإشارات والمتابعون الجدد.'**
  String get notificationsEmptyBody;

  /// Notifications action
  ///
  /// In ar, this message translates to:
  /// **'تعيين الكل كمقروء'**
  String get notificationsMarkAllRead;

  /// Notifications: open settings
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get notificationsSettings;

  /// Notification setting
  ///
  /// In ar, this message translates to:
  /// **'الإعجابات'**
  String get notifSettingLikes;

  /// Notification setting detail
  ///
  /// In ar, this message translates to:
  /// **'على منشوراتك وتعليقاتك'**
  String get notifSettingLikesBody;

  /// Notification setting
  ///
  /// In ar, this message translates to:
  /// **'التعليقات والردود'**
  String get notifSettingComments;

  /// Notification setting
  ///
  /// In ar, this message translates to:
  /// **'الإشارات'**
  String get notifSettingMentions;

  /// Notification setting
  ///
  /// In ar, this message translates to:
  /// **'المتابعون الجدد'**
  String get notifSettingFollows;

  /// Notification setting
  ///
  /// In ar, this message translates to:
  /// **'إعادات النشر'**
  String get notifSettingReposts;

  /// Notification settings footnote
  ///
  /// In ar, this message translates to:
  /// **'تظهر الإشعارات داخل التطبيق. يصلك دائمًا إشعار عند نشر منشور مجدول أو إزالة محتوى لك.'**
  String get notifSettingsHint;

  /// Notification setting saved
  ///
  /// In ar, this message translates to:
  /// **'حُفظ'**
  String get notifSettingsSaved;

  /// LIVE_HOSTING_NOT_ALLOWED (403, CP-010).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن لحسابك البث المباشر بعد.'**
  String get errorLiveHostingNotAllowed;

  /// LIVE_GUESTS_NOT_ALLOWED (403, CP-010).
  ///
  /// In ar, this message translates to:
  /// **'يسمح المضيف بمشاهدة هذا البث للمسجّلين فقط.'**
  String get errorLiveGuestsNotAllowed;

  /// Create mode bar: post
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get createModePost;

  /// Create mode bar: story
  ///
  /// In ar, this message translates to:
  /// **'قصة'**
  String get createModeStory;

  /// Create mode bar: go live
  ///
  /// In ar, this message translates to:
  /// **'بث مباشر'**
  String get createModeLive;

  /// Go-live title field hint
  ///
  /// In ar, this message translates to:
  /// **'أضف عنواناً للبث'**
  String get goLiveTitleHint;

  /// Snack when Go live is tapped without a title
  ///
  /// In ar, this message translates to:
  /// **'أضف عنواناً لبثك أولاً.'**
  String get goLiveTitleRequired;

  /// Flip camera
  ///
  /// In ar, this message translates to:
  /// **'قلب'**
  String get goLiveFlip;

  /// Microphone toggle (on)
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون'**
  String get goLiveMic;

  /// Microphone toggle (off)
  ///
  /// In ar, this message translates to:
  /// **'مكتوم'**
  String get goLiveMicOff;

  /// Guests switch label
  ///
  /// In ar, this message translates to:
  /// **'الزوار'**
  String get goLiveGuests;

  /// Guests switch on (semantics)
  ///
  /// In ar, this message translates to:
  /// **'يمكن لمن لا يملك حساباً المشاهدة'**
  String get goLiveGuestsOnHint;

  /// Guests switch off (semantics)
  ///
  /// In ar, this message translates to:
  /// **'المشاهدة للمسجّلين فقط'**
  String get goLiveGuestsOffHint;

  /// Snack after allowing guests while live
  ///
  /// In ar, this message translates to:
  /// **'سُمح للزوار بالمشاهدة'**
  String get goLiveGuestsOn;

  /// Snack after turning guests off while live
  ///
  /// In ar, this message translates to:
  /// **'أُخرج الزوار وأصبحت المشاهدة للمسجّلين فقط'**
  String get goLiveGuestsOff;

  /// Category chip: none
  ///
  /// In ar, this message translates to:
  /// **'بلا فئة'**
  String get goLiveNoCategory;

  /// Big start button
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البث'**
  String get goLiveStart;

  /// Starting state
  ///
  /// In ar, this message translates to:
  /// **'جارٍ بدء البث…'**
  String get goLiveStarting;

  /// End button while live
  ///
  /// In ar, this message translates to:
  /// **'إنهاء'**
  String get goLiveEnd;

  /// End confirmation title
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البث؟'**
  String get goLiveEndConfirmTitle;

  /// End confirmation body
  ///
  /// In ar, this message translates to:
  /// **'سيرى المشاهدون أن البث انتهى.'**
  String get goLiveEndConfirmBody;

  /// End confirmation action
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البث'**
  String get goLiveEndConfirm;

  /// End confirmation cancel
  ///
  /// In ar, this message translates to:
  /// **'متابعة البث'**
  String get goLiveKeepGoing;

  /// Elapsed time (semantics)
  ///
  /// In ar, this message translates to:
  /// **'مباشر منذ {duration}'**
  String goLiveElapsed(String duration);

  /// Ended summary title
  ///
  /// In ar, this message translates to:
  /// **'انتهى بثك'**
  String get goLiveEndedTitle;

  /// Ended summary duration
  ///
  /// In ar, this message translates to:
  /// **'المدة {duration}'**
  String goLiveEndedDuration(String duration);

  /// Ended summary button
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get goLiveDone;

  /// Capture denied title
  ///
  /// In ar, this message translates to:
  /// **'اسمح بالكاميرا والميكروفون'**
  String get goLiveCameraDeniedTitle;

  /// Capture denied body
  ///
  /// In ar, this message translates to:
  /// **'يحتاجهما Kabso Live ليعرضك مباشرة. اسمح بالوصول من الإعدادات ثم حاول مجدداً.'**
  String get goLiveCameraDeniedBody;

  /// Capture unavailable title
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا غير متاحة'**
  String get goLiveCameraUnavailableTitle;

  /// Capture unavailable body
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على كاميرا أو ميكروفون، أو يستخدمهما تطبيق آخر.'**
  String get goLiveCameraUnavailableBody;

  /// canHost false title
  ///
  /// In ar, this message translates to:
  /// **'البث يحتاج حساب مضيف'**
  String get goLiveNotAllowedTitle;

  /// canHost false body
  ///
  /// In ar, this message translates to:
  /// **'يبث المضيفون عبر وكالة مضيفين في Kabso Live أو بعد توثيق هويتهم. التسجيل قريباً.'**
  String get goLiveNotAllowedBody;

  /// hostingEnabled false title
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر غير متاح بعد'**
  String get goLiveUnavailableTitle;

  /// Go-live mode: multi-guest video (CP-011)
  ///
  /// In ar, this message translates to:
  /// **'بث متعدد'**
  String get goLiveModeMulti;

  /// Go-live mode: one host on camera
  ///
  /// In ar, this message translates to:
  /// **'بث مباشر'**
  String get goLiveModeSolo;

  /// Go-live mode: voice room
  ///
  /// In ar, this message translates to:
  /// **'بث صوتي'**
  String get goLiveModeAudio;

  /// An empty seat tile
  ///
  /// In ar, this message translates to:
  /// **'مقعد {number}'**
  String goLiveSeat(int number);

  /// Tag on the host's tile
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get goLiveHostTag;

  /// Seat count option (semantics)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مقعد واحد} =2{مقعدان} few{{count} مقاعد} many{{count} مقعدًا} other{{count} مقعد}}'**
  String goLiveSeatCount(int count);

  /// Beauty tool
  ///
  /// In ar, this message translates to:
  /// **'تجميل'**
  String get goLiveBeauty;

  /// Beauty sheet title
  ///
  /// In ar, this message translates to:
  /// **'التجميل'**
  String get goLiveBeautyTitle;

  /// Beauty on/off switch
  ///
  /// In ar, this message translates to:
  /// **'تشغيل التجميل'**
  String get goLiveBeautySwitch;

  /// Beauty: smoothing slider
  ///
  /// In ar, this message translates to:
  /// **'تنعيم البشرة'**
  String get goLiveBeautySmooth;

  /// Beauty: brightening slider
  ///
  /// In ar, this message translates to:
  /// **'إضاءة'**
  String get goLiveBeautyBrighten;

  /// Beauty unsupported on this platform
  ///
  /// In ar, this message translates to:
  /// **'التجميل غير متاح على هذا الجهاز بعد.'**
  String get goLiveBeautyUnsupported;

  /// Theme tool
  ///
  /// In ar, this message translates to:
  /// **'الثيم'**
  String get goLiveTheme;

  /// Theme sheet title
  ///
  /// In ar, this message translates to:
  /// **'ثيم الغرفة'**
  String get goLiveThemeTitle;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'كلاسيكي'**
  String get liveThemeClassic;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'قصر الجليد'**
  String get liveThemeIcePalace;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'ليل الصحراء'**
  String get liveThemeDesertNight;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'حديقة الورد'**
  String get liveThemeRoseGarden;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'سماء الغروب'**
  String get liveThemeSunsetSky;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'قصر القمر'**
  String get liveThemeMoonPalace;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'أعماق المحيط'**
  String get liveThemeOceanDepths;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'القاعة الذهبية'**
  String get liveThemeGoldenHall;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'ساحة الألعاب'**
  String get liveThemeGameArena;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'حديقة القلوب'**
  String get liveThemeHeartGarden;

  /// Theme name
  ///
  /// In ar, this message translates to:
  /// **'المجرة'**
  String get liveThemeGalaxy;

  /// Guests chip on
  ///
  /// In ar, this message translates to:
  /// **'الزوار مسموح'**
  String get goLiveGuestsAllowedChip;

  /// Guests chip off
  ///
  /// In ar, this message translates to:
  /// **'للمسجّلين فقط'**
  String get goLiveGuestsOffChip;

  /// Viewer: ask for a seat
  ///
  /// In ar, this message translates to:
  /// **'اطلب مقعداً'**
  String get liveSeatRequest;

  /// Viewer: pending request (tap cancels)
  ///
  /// In ar, this message translates to:
  /// **'تم الطلب · إلغاء'**
  String get liveSeatRequested;

  /// Seated: leave
  ///
  /// In ar, this message translates to:
  /// **'مغادرة المقعد'**
  String get liveSeatLeave;

  /// Invite dialog title
  ///
  /// In ar, this message translates to:
  /// **'دعوة للصعود'**
  String get liveSeatInviteTitle;

  /// Invite dialog body
  ///
  /// In ar, this message translates to:
  /// **'يدعوك {name} للصعود إلى مقعد.'**
  String liveSeatInviteBody(String name);

  /// Accept invitation
  ///
  /// In ar, this message translates to:
  /// **'صعود'**
  String get liveSeatInviteAccept;

  /// Decline invitation
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get liveSeatInviteDecline;

  /// Host disconnected but the room is live
  ///
  /// In ar, this message translates to:
  /// **'سيعود المضيف قريباً'**
  String get liveHostAway;

  /// Seated guest muted by the host
  ///
  /// In ar, this message translates to:
  /// **'كتمك المضيف'**
  String get liveSeatMutedByHost;

  /// Seated: capture failed
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الكاميرا أو الميكروفون.'**
  String get liveSeatCaptureFailed;

  /// Seat action
  ///
  /// In ar, this message translates to:
  /// **'كتم'**
  String get liveSeatMute;

  /// Seat action
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get liveSeatUnmute;

  /// Seat action
  ///
  /// In ar, this message translates to:
  /// **'إنزال من المقعد'**
  String get liveSeatRemove;

  /// Seat action
  ///
  /// In ar, this message translates to:
  /// **'قفل المايك'**
  String get liveSeatLock;

  /// Seat action
  ///
  /// In ar, this message translates to:
  /// **'فتح المايك'**
  String get liveSeatUnlock;

  /// Seat action
  ///
  /// In ar, this message translates to:
  /// **'دعوة مشاهد'**
  String get liveSeatInvite;

  /// Seat/viewer action
  ///
  /// In ar, this message translates to:
  /// **'تعيين مشرفاً'**
  String get liveSeatMakeModerator;

  /// Seat/viewer action
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإشراف'**
  String get liveSeatRemoveModerator;

  /// Moderator tag
  ///
  /// In ar, this message translates to:
  /// **'مشرف'**
  String get liveSeatModeratorTag;

  /// Tool: seat requests
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get liveSeatRequests;

  /// Requests sheet title
  ///
  /// In ar, this message translates to:
  /// **'طلبات الصعود'**
  String get liveSeatRequestsTitle;

  /// Requests sheet empty
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات الآن.'**
  String get liveSeatRequestsEmpty;

  /// Accept a request
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get liveSeatAccept;

  /// Decline a request
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get liveSeatDecline;

  /// Invite sheet title
  ///
  /// In ar, this message translates to:
  /// **'دعوة إلى مقعد'**
  String get liveSeatInviteSheetTitle;

  /// Invite sheet empty
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مشاهدون مسجّلون الآن.'**
  String get liveSeatInviteEmpty;

  /// Invite button
  ///
  /// In ar, this message translates to:
  /// **'دعوة'**
  String get liveSeatInviteSend;

  /// Snack after inviting
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت الدعوة'**
  String get liveSeatInvited;

  /// Tool: seat count while live
  ///
  /// In ar, this message translates to:
  /// **'المقاعد'**
  String get liveSeats;

  /// Seat count sheet title
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get liveSeatsTitle;

  /// A guest viewer
  ///
  /// In ar, this message translates to:
  /// **'زائر {number}'**
  String liveSeatGuestNumber(int number);

  /// Audio go-live headline
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البث الصوتي'**
  String get goLiveAudioHeadline;

  /// Audio go-live subtitle
  ///
  /// In ar, this message translates to:
  /// **'شارك صوتك وتواصل مع جمهورك'**
  String get goLiveAudioSubtitle;

  /// Category section
  ///
  /// In ar, this message translates to:
  /// **'اختر الفئة'**
  String get goLiveChooseCategory;

  /// Guests section
  ///
  /// In ar, this message translates to:
  /// **'من يمكنه المشاهدة؟'**
  String get goLiveWhoCanWatch;

  /// Guests allowed option
  ///
  /// In ar, this message translates to:
  /// **'الجميع'**
  String get goLiveWatchEveryone;

  /// Guests allowed hint
  ///
  /// In ar, this message translates to:
  /// **'حتى من لا يملك حساباً'**
  String get goLiveWatchEveryoneHint;

  /// Guests off option
  ///
  /// In ar, this message translates to:
  /// **'المسجّلون فقط'**
  String get goLiveWatchSignedIn;

  /// Guests off hint
  ///
  /// In ar, this message translates to:
  /// **'أصحاب الحسابات فقط'**
  String get goLiveWatchSignedInHint;

  /// Voice section
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الصوت'**
  String get goLiveVoiceSettings;

  /// Mic row
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون'**
  String get goLiveMicrophone;

  /// Mic row hint
  ///
  /// In ar, this message translates to:
  /// **'يمكنك كتمه في أي وقت'**
  String get goLiveMicrophoneHint;

  /// Voice option
  ///
  /// In ar, this message translates to:
  /// **'تقليل الضوضاء'**
  String get goLiveNoiseReduction;

  /// Voice option hint
  ///
  /// In ar, this message translates to:
  /// **'صوت أنقى في الأماكن المزدحمة'**
  String get goLiveNoiseReductionHint;

  /// Voice option
  ///
  /// In ar, this message translates to:
  /// **'تحسين الصوت'**
  String get goLiveVoiceEnhance;

  /// Voice option hint
  ///
  /// In ar, this message translates to:
  /// **'مستوى متوازن بلا صدى'**
  String get goLiveVoiceEnhanceHint;

  /// Audio start button
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البث الصوتي'**
  String get goLiveStartAudio;

  /// Theme thumbnail action
  ///
  /// In ar, this message translates to:
  /// **'تغيير الثيم'**
  String get goLiveChangeTheme;

  /// Seats section
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get goLiveSeatsSection;

  /// Minimize the live into a floating window
  ///
  /// In ar, this message translates to:
  /// **'تصغير البث'**
  String get goLiveMinimize;

  /// Android notification channel name for the ongoing live notification (D123)
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر'**
  String get liveBgChannel;

  /// Ongoing notification title while the host's live runs in the background
  ///
  /// In ar, this message translates to:
  /// **'البث مستمر'**
  String get liveBgHostTitle;

  /// Ongoing notification title for a seated guest
  ///
  /// In ar, this message translates to:
  /// **'أنت على مقعد في البث'**
  String get liveBgGuestTitle;

  /// Ongoing notification title for a listener of an audio room
  ///
  /// In ar, this message translates to:
  /// **'تستمع إلى بث مباشر'**
  String get liveBgListenerTitle;

  /// Ongoing notification text
  ///
  /// In ar, this message translates to:
  /// **'اضغط للعودة إلى الغرفة'**
  String get liveBgBody;

  /// Ongoing notification action: end the live
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البث'**
  String get liveBgEnd;

  /// Ongoing notification action: leave the seat or the room
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get liveBgLeave;

  /// Floating window: open the live full screen
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى البث'**
  String get goLiveBackToLive;

  /// Categories: open the full list
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get goLiveAllCategories;

  /// Audio setup: the room theme card
  ///
  /// In ar, this message translates to:
  /// **'مظهر الغرفة: {name}'**
  String goLiveRoomLook(String name);

  /// Sheet title: choose multi / LIVE / audio
  ///
  /// In ar, this message translates to:
  /// **'نوع البث'**
  String get goLiveLiveType;

  /// Audio room: the big centre mic button while the mic is on
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get goLiveMuteMic;

  /// Audio room: the big centre mic button while muted
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الصوت'**
  String get goLiveUnmuteMic;

  /// Audio room bottom bar: the chat button
  ///
  /// In ar, this message translates to:
  /// **'الدردشة'**
  String get goLiveChat;

  /// Audio room bar: the PK (versus) button
  ///
  /// In ar, this message translates to:
  /// **'تحدي PK'**
  String get goLivePk;

  /// PK is not in the contract yet
  ///
  /// In ar, this message translates to:
  /// **'تحديات PK غير متاحة بعد.'**
  String get goLivePkSoon;

  /// Audio room: the chat box placeholder
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة…'**
  String get goLiveChatHint;

  /// Audio room: send a chat message
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get goLiveChatSend;

  /// Audio room bar: the short chat pill (opens the chat box)
  ///
  /// In ar, this message translates to:
  /// **'دردشة…'**
  String get goLiveChatPill;

  /// Audio room top bar: share the live
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get goLiveShare;

  /// The invite copied by Share
  ///
  /// In ar, this message translates to:
  /// **'أنا مباشر الآن على Kabso Live: «{title}» — تابعني @{username}'**
  String goLiveShareText(String title, String username);

  /// After Share copied the invite
  ///
  /// In ar, this message translates to:
  /// **'نُسخت دعوة البث، الصقها لمن تريد'**
  String get goLiveShareCopied;

  /// Room score for screen readers
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نقاط} =1{نقطة واحدة} =2{نقطتان} few{{formatted} نقاط} many{{formatted} نقطة} other{{formatted} نقطة}}'**
  String liveScore(int count, String formatted);

  /// Score sheet title
  ///
  /// In ar, this message translates to:
  /// **'نقاط البث'**
  String get liveScoreTitle;

  /// Score sheet: tap points
  ///
  /// In ar, this message translates to:
  /// **'التكبيس'**
  String get liveScoreTaps;

  /// Score sheet: support points
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get liveScoreSupport;

  /// Score sheet footnote
  ///
  /// In ar, this message translates to:
  /// **'كل تكبيسة نقطة، وكل كوينزة دعم 100 نقطة. الدعم يبدأ مع الهدايا.'**
  String get liveScoreHint;

  /// Viewer: tap the live to cheer
  ///
  /// In ar, this message translates to:
  /// **'اضغط على البث لتشجيع المضيف'**
  String get liveTapHint;

  /// LIVE_CHAT_NOT_IN_ROOM (403, CP-013).
  ///
  /// In ar, this message translates to:
  /// **'أنت لست داخل هذا البث الآن. افتح البث من جديد.'**
  String get errorLiveChatNotInRoom;

  /// LIVE_CHAT_MUTED (403, CP-013).
  ///
  /// In ar, this message translates to:
  /// **'كتمك المضيف أو أحد المشرفين في دردشة هذا البث.'**
  String get errorLiveChatMuted;

  /// LIVE_CHAT_CLOSED (409, CP-013).
  ///
  /// In ar, this message translates to:
  /// **'أوقف المضيف الدردشة.'**
  String get errorLiveChatClosed;

  /// Chat pill when the host turned the chat off (CP-013).
  ///
  /// In ar, this message translates to:
  /// **'الدردشة متوقفة'**
  String get liveChatOff;

  /// Chat pill when the viewer is muted (CP-013).
  ///
  /// In ar, this message translates to:
  /// **'أنت مكتوم في دردشة هذا البث'**
  String get liveChatMutedPill;

  /// Chat pill for guests without an account (CP-013).
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول للمشاركة في الدردشة'**
  String get liveChatSignIn;

  /// A chat line that failed to send (CP-013).
  ///
  /// In ar, this message translates to:
  /// **'لم تُرسل. اضغط لإعادة المحاولة'**
  String get liveChatFailed;

  /// Action on a failed chat line.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get liveChatRetry;

  /// Action on a failed chat line: drop it.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get liveChatDiscard;

  /// Badge before the host's chat messages.
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get liveChatHostBadge;

  /// Badge before a moderator's chat messages.
  ///
  /// In ar, this message translates to:
  /// **'مشرف'**
  String get liveChatModeratorBadge;

  /// Chat line action.
  ///
  /// In ar, this message translates to:
  /// **'عرض الملف الشخصي'**
  String get liveChatViewProfile;

  /// Chat line action (author, host, moderator).
  ///
  /// In ar, this message translates to:
  /// **'حذف الرسالة'**
  String get liveChatDelete;

  /// Snack after deleting a chat message.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الرسالة'**
  String get liveChatDeleted;

  /// Chat line action (host, moderator).
  ///
  /// In ar, this message translates to:
  /// **'كتم {name} في الدردشة'**
  String liveChatMuteUser(String name);

  /// Chat line action (host, moderator).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء كتم {name}'**
  String liveChatUnmuteUser(String name);

  /// Snack after muting someone in chat.
  ///
  /// In ar, this message translates to:
  /// **'كُتم {name} في دردشة هذا البث'**
  String liveChatUserMuted(String name);

  /// Snack after unmuting someone in chat.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي كتم {name}'**
  String liveChatUserUnmuted(String name);

  /// Person card: mute this seated person's or guest's microphone.
  ///
  /// In ar, this message translates to:
  /// **'كتم مايك {name}'**
  String liveSeatMuteUser(String name);

  /// Person card: unmute this seated person's or guest's microphone.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء كتم مايك {name}'**
  String liveSeatUnmuteUser(String name);

  /// Snack after muting someone's seat microphone.
  ///
  /// In ar, this message translates to:
  /// **'كُتم مايك {name}'**
  String liveSeatUserMuted(String name);

  /// Snack after unmuting someone's seat microphone.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي كتم مايك {name}'**
  String liveSeatUserUnmuted(String name);

  /// Chat line action.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن الرسالة'**
  String get liveChatReport;

  /// Title of the reasons sheet for a chat message.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلغ عن هذه الرسالة؟'**
  String get liveChatReportTitle;

  /// Snack for the host.
  ///
  /// In ar, this message translates to:
  /// **'أوقفت الدردشة. لا يستطيع المشاهدون الكتابة.'**
  String get liveChatTurnedOff;

  /// Snack for the host.
  ///
  /// In ar, this message translates to:
  /// **'الدردشة تعمل'**
  String get liveChatTurnedOn;

  /// Screen reader label of a chat line.
  ///
  /// In ar, this message translates to:
  /// **'{name}: {text}'**
  String liveChatLineLabel(String name, String text);

  /// D119: screen reader label of the charm level badge under a chat author's name.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الجاذبية {level}'**
  String liveChatCharmLabel(int level);

  /// D119: screen reader label of the support level badge under a chat author's name.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الدعم {level}'**
  String liveChatSupportLabel(int level);

  /// D119: screen reader label of the family chip under a chat author's name.
  ///
  /// In ar, this message translates to:
  /// **'العائلة {name}، المستوى {level}'**
  String liveChatFamilyLabel(String name, int level);

  /// Host tool: the room chat on/off switch (CP-013); its state is shown by the button.
  ///
  /// In ar, this message translates to:
  /// **'الدردشة'**
  String get liveChatTool;

  /// Host tools sheet: section title.
  ///
  /// In ar, this message translates to:
  /// **'أدوات الغرفة'**
  String get liveToolsRoom;

  /// Host tools sheet: section title.
  ///
  /// In ar, this message translates to:
  /// **'أدوات أخرى'**
  String get liveToolsOther;

  /// Under an on/off tool that is on.
  ///
  /// In ar, this message translates to:
  /// **'يعمل'**
  String get liveToolOn;

  /// Under an on/off tool that is off.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get liveToolOff;

  /// Host tool: voice settings while live.
  ///
  /// In ar, this message translates to:
  /// **'الصوت'**
  String get liveToolsVoice;

  /// Host tool: who is watching.
  ///
  /// In ar, this message translates to:
  /// **'المشاهدون'**
  String get liveToolsViewers;

  /// Viewers sheet tab: people on a seat.
  ///
  /// In ar, this message translates to:
  /// **'الضيوف'**
  String get liveSeatGuestsTab;

  /// Viewers sheet, Guests tab empty.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد على المقاعد الآن'**
  String get liveSeatGuestsEmpty;

  /// Guests tab with nobody on a seat: opens the Viewers tab to invite people onto a seat.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ أصدقاءك'**
  String get liveSeatInviteFriends;

  /// Person card in a live (host): opens the moderator choice.
  ///
  /// In ar, this message translates to:
  /// **'إدارة'**
  String get liveUserManage;

  /// Person card in a live: opens their full profile.
  ///
  /// In ar, this message translates to:
  /// **'عرض الملف'**
  String get liveUserViewProfile;

  /// Person card in a live: the family box (no families yet: says soon).
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get liveUserFamily;

  /// Person card in a live: the gifts they received (no gifts API yet: says soon).
  ///
  /// In ar, this message translates to:
  /// **'حائط الهدايا'**
  String get liveUserGiftWall;

  /// Person card in a live: their medals (no medals yet: says soon).
  ///
  /// In ar, this message translates to:
  /// **'الميداليات'**
  String get liveUserMedals;

  /// Tag on a person-card box whose feature is not built yet.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get liveUserSoon;

  /// Snack when a not-yet-built person-card box is tapped.
  ///
  /// In ar, this message translates to:
  /// **'{box}: قريباً'**
  String liveUserBoxSoon(String box);

  /// Viewers sheet, Guests tab: the person's seat.
  ///
  /// In ar, this message translates to:
  /// **'المقعد {number}'**
  String liveSeatNumberLabel(int number);

  /// Room tools: edit the room's name, category and topic (CP-014).
  ///
  /// In ar, this message translates to:
  /// **'تعديل الغرفة'**
  String get liveEditRoom;

  /// Edit room sheet: name field label.
  ///
  /// In ar, this message translates to:
  /// **'اسم الغرفة'**
  String get liveEditRoomName;

  /// Edit room sheet: category chips label.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get liveEditRoomCategory;

  /// Edit room sheet: topic field label.
  ///
  /// In ar, this message translates to:
  /// **'الموضوع'**
  String get liveEditRoomTopic;

  /// Edit room sheet: topic hint.
  ///
  /// In ar, this message translates to:
  /// **'عمّ تتحدثون الآن؟'**
  String get liveEditRoomTopicHint;

  /// Edit room sheet: save button.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get liveEditRoomSave;

  /// Snack after the room was edited.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت الغرفة'**
  String get liveEditRoomSaved;

  /// Screen-reader label of the topic chip and card line.
  ///
  /// In ar, this message translates to:
  /// **'الموضوع: {topic}'**
  String liveRoomTopic(String topic);

  /// Viewers sheet tab and sheet title: who gave this live the most points (CP-014).
  ///
  /// In ar, this message translates to:
  /// **'قائمة المساهمة'**
  String get liveContributionTab;

  /// Contribution list empty.
  ///
  /// In ar, this message translates to:
  /// **'لا مساهمات بعد. النقرات على البث تُحسب هنا.'**
  String get liveContributionEmpty;

  /// Contribution row for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'المرتبة {rank}، {name}، {points}'**
  String liveContributionRow(int rank, String name, String points);

  /// Label on the live cover picture (go-live screen), opens the cover options
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get liveCoverEdit;

  /// Semantics label of the live cover picture
  ///
  /// In ar, this message translates to:
  /// **'تعديل صورة غلاف البث'**
  String get liveCoverEditLabel;

  /// Title of the cover options sheet
  ///
  /// In ar, this message translates to:
  /// **'صورة غلاف البث'**
  String get liveCoverSheetTitle;

  /// Explains where the cover shows
  ///
  /// In ar, this message translates to:
  /// **'تظهر في بطاقة بثك وفي الغرفة، في كل بث.'**
  String get liveCoverSheetBody;

  /// Cover sheet action: pick a photo from the gallery
  ///
  /// In ar, this message translates to:
  /// **'اختيار صورة'**
  String get liveCoverChoose;

  /// Cover sheet action: remove the cover (the avatar is used)
  ///
  /// In ar, this message translates to:
  /// **'إزالة الغلاف واستخدام صورتي'**
  String get liveCoverRemove;

  /// Snack after the cover changed
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث غلاف البث.'**
  String get liveCoverUpdated;

  /// Snack after the cover was removed
  ///
  /// In ar, this message translates to:
  /// **'أُزيل الغلاف؛ ستظهر صورتك.'**
  String get liveCoverRemoved;

  /// Semantics while the cover uploads
  ///
  /// In ar, this message translates to:
  /// **'جارٍ رفع الغلاف…'**
  String get liveCoverUploading;

  /// Live settings sheet (owner ref 71)
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get liveSettingsShare;

  /// Live settings sheet (owner ref 71)
  ///
  /// In ar, this message translates to:
  /// **'الكلمات المحظورة'**
  String get liveSettingsBlockedWords;

  /// Live settings sheet (owner ref 71)
  ///
  /// In ar, this message translates to:
  /// **'جدول البث'**
  String get liveSettingsSchedule;

  /// Live settings sheet (owner ref 71)
  ///
  /// In ar, this message translates to:
  /// **'مركز الفعاليات'**
  String get liveSettingsEventCenter;

  /// Live settings sheet (owner ref 71)
  ///
  /// In ar, this message translates to:
  /// **'مركز صنّاع المحتوى'**
  String get liveSettingsCreatorCenter;

  /// Live settings sheet (owner ref 71)
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get liveSoon;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get liveRoomInfoChange;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'مستوى الغرفة'**
  String get liveRoomLevel;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الغرفة'**
  String get liveRoomSettings;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'الوسم'**
  String get liveRoomTag;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'بلا وسم'**
  String get liveRoomNoTag;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'الإعلان'**
  String get liveRoomAnnouncement;

  /// Room info sheet (owner ref 73)
  ///
  /// In ar, this message translates to:
  /// **'تعزيز غرفتي'**
  String get liveRoomBoost;

  /// Blocked words sheet (CP-016 B)
  ///
  /// In ar, this message translates to:
  /// **'تُخفى هذه الكلمات بنجوم (***) في دردشة كل بثوثك.'**
  String get liveBlockedWordsHint;

  /// Blocked words sheet (CP-016 B)
  ///
  /// In ar, this message translates to:
  /// **'أضف كلمة أو عبارة قصيرة'**
  String get liveBlockedWordsAddHint;

  /// Blocked words sheet (CP-016 B)
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get liveBlockedWordsAdd;

  /// Blocked words sheet (CP-016 B)
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى 100 كلمة'**
  String get liveBlockedWordsFull;

  /// Blocked words sheet (CP-016 B)
  ///
  /// In ar, this message translates to:
  /// **'لا كلمات محظورة بعد.'**
  String get liveBlockedWordsEmpty;

  /// Tooltip of a blocked word chip delete button
  ///
  /// In ar, this message translates to:
  /// **'إزالة {word}'**
  String liveBlockedWordsRemove(String word);

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'ترتيب الشعبية'**
  String get liveRankTitle;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'الأغنى'**
  String get liveRankRich;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'هذه الساعة'**
  String get liveRankHour;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get liveRankDay;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get liveRankWeek;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'لا نقاط بعد في هذه الفترة.'**
  String get liveRankEmpty;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get liveRankLive;

  /// Popularity board (CP-016 A, ref 74)
  ///
  /// In ar, this message translates to:
  /// **'ترتيب الغرف'**
  String get liveRankChip;

  /// Time left in the board window
  ///
  /// In ar, this message translates to:
  /// **'ينتهي خلال: {days}ي {hours}س {minutes}د'**
  String liveRankCountdown(String days, String hours, String minutes);

  /// Screen reader label of a board row
  ///
  /// In ar, this message translates to:
  /// **'المرتبة {rank}، {name}، {points}'**
  String liveRankRow(int rank, String name, String points);

  /// Notification: a host you follow goes live soon (CP-016 C)
  ///
  /// In ar, this message translates to:
  /// **'يبدأ {who} بثًا مباشرًا الساعة {time}'**
  String notifLiveScheduled(String who, String time);

  /// Notification setting (CP-016 C)
  ///
  /// In ar, this message translates to:
  /// **'البثوث المجدولة'**
  String get notifSettingLives;

  /// Notification setting subtitle (CP-016 C)
  ///
  /// In ar, this message translates to:
  /// **'عندما يقترب موعد بث لمضيف تتابعه'**
  String get notifSettingLivesBody;

  /// Error LIVE_SCHEDULE_FULL
  ///
  /// In ar, this message translates to:
  /// **'يمكنك جدولة 10 بثوث كحد أقصى.'**
  String get errorLiveScheduleFull;

  /// Live schedule sheet hint (CP-016 C)
  ///
  /// In ar, this message translates to:
  /// **'يصل لمتابعيك تذكير قبل الموعد بـ15 دقيقة. البث نفسه تبدؤه أنت.'**
  String get liveScheduleHint;

  /// Live schedule sheet: empty
  ///
  /// In ar, this message translates to:
  /// **'لا بثوث مجدولة.'**
  String get liveScheduleEmpty;

  /// Live schedule sheet: add button
  ///
  /// In ar, this message translates to:
  /// **'جدولة بث'**
  String get liveScheduleAdd;

  /// Live schedule form: title field
  ///
  /// In ar, this message translates to:
  /// **'عنوان البث'**
  String get liveScheduleTitleHint;

  /// Live schedule form: date and time button
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ والوقت'**
  String get liveSchedulePickTime;

  /// Live schedule form: save
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get liveScheduleSave;

  /// Live schedule form: too soon
  ///
  /// In ar, this message translates to:
  /// **'اختر وقتًا بعد 15 دقيقة على الأقل.'**
  String get liveScheduleTooSoon;

  /// Live schedule form: too far
  ///
  /// In ar, this message translates to:
  /// **'اختر وقتًا خلال 30 يومًا.'**
  String get liveScheduleTooFar;

  /// Live schedule: remove button tooltip
  ///
  /// In ar, this message translates to:
  /// **'إلغاء {title}'**
  String liveScheduleRemove(String title);

  /// Live schedule: a slot's date and time
  ///
  /// In ar, this message translates to:
  /// **'{date}، {time}'**
  String liveScheduleWhen(String date, String time);

  /// The room bar's second line: the host's public room number (CP-016 G)
  ///
  /// In ar, this message translates to:
  /// **'المعرّف: {number}'**
  String liveRoomNumber(String number);

  /// Screen reader label of the room level badge next to the room name: the host's charm level (CP-016 D, D101)
  ///
  /// In ar, this message translates to:
  /// **'مستوى الغرفة {level}'**
  String liveRoomLevelBadge(int level);

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'موسيقى'**
  String get liveToolMusic;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات'**
  String get liveToolSounds;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'السلاسة'**
  String get liveToolFluent;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'قائمة البرامج'**
  String get liveToolProgramList;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الشاشة'**
  String get liveToolShareScreen;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'يوتيوب'**
  String get liveToolYoutube;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'غناء'**
  String get liveToolSinging;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'الموضوع'**
  String get liveToolTopic;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'الإدارة'**
  String get liveToolManagement;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'مساعد البث'**
  String get liveToolAssistance;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'التسجيل'**
  String get liveToolRecorder;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'الجدد'**
  String get liveToolNewcomers;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'مركز البيانات'**
  String get liveToolDataCenter;

  /// Room tools sheet tile (owner ref 84)
  ///
  /// In ar, this message translates to:
  /// **'وقت البث'**
  String get liveToolLiveTime;

  /// INSUFFICIENT_COINS (409, CP-017): a bullet costs 15 coins; no purchase flow exists yet.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج 15 عملة لإرسال رسالة عامة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.'**
  String get errorInsufficientCoins;

  /// Live chat tool: bullet mode on/off (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة'**
  String get liveBulletToggle;

  /// Chat field hint while bullet mode is on, with the coin balance (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة بـ 15 عملة · رصيدك {coins}'**
  String liveBulletHint(String coins);

  /// Chat field hint in bullet mode before the balance is known (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة بـ 15 عملة'**
  String get liveBulletHintNoBalance;

  /// Snack after a bullet was sent (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت رسالتك العامة إلى كل البثوث'**
  String get liveBulletSent;

  /// Screen reader label of a flying bullet (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة من {name}: {text}'**
  String liveBulletLabel(String name, String text);

  /// Live chat tool: record a voice clip (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'مقطع صوتي'**
  String get liveVoiceRecord;

  /// Stops recording and sends the voice clip (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'إرسال المقطع الصوتي'**
  String get liveVoiceSend;

  /// Throws the voice clip away (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التسجيل'**
  String get liveVoiceCancel;

  /// Recording timer in the chat box (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التسجيل {time} من 0:30'**
  String liveVoiceRecording(String time);

  /// Microphone permission refused (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'اسمح باستخدام الميكروفون من الإعدادات لإرسال مقاطع صوتية.'**
  String get liveVoiceDenied;

  /// The microphone could not start (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون غير متاح الآن.'**
  String get liveVoiceUnavailable;

  /// Live chat: a voice clip could not be sent because uploads are off on the server (503 MEDIA_UPLOADS_UNAVAILABLE). D118.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرسائل الصوتية غير متاح حالياً.'**
  String get liveVoiceUploadsUnavailable;

  /// The red system line with the room's rules, shown once when a live opens (host and viewers); local, never sent. D118.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في Kabso Live. يُمنع نشر أي محتوى مسيء أو مخالف لإرشادات المجتمع، وفريق الإشراف يتابع البث على مدار الساعة.'**
  String get liveRoomRulesNotice;

  /// Screen-reader name of the red system line in the live chat. D118.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه من Kabso Live'**
  String get liveRoomRulesLabel;

  /// A voice clip over 1 MiB (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'المقطع الصوتي كبير جداً. سجّل مقطعاً أقصر.'**
  String get liveVoiceTooLarge;

  /// Live chat: while a voice clip records, the person's own live microphone (host or seated guest) is paused; shown next to the chat tools (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'مايك البث متوقف مؤقتاً أثناء التسجيل'**
  String get liveVoiceLiveMicPaused;

  /// Live chat: the live microphone could not be paused for a voice clip, so nothing is recorded (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إيقاف مايك البث مؤقتاً، لذلك لا يمكن تسجيل مقطع صوتي الآن.'**
  String get liveVoiceLiveMicBusy;

  /// Live chat: a voice clip could not be played (the player failed to load or start it) (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل هذا المقطع الصوتي.'**
  String get liveVoicePlayFailed;

  /// Live chat: the recorded voice clip was silent (the microphone delivered nothing), so it was not sent (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'لم يُلتقط أي صوت في هذا المقطع، لذلك لم يُرسل. حاول مرة أخرى.'**
  String get liveVoiceSilent;

  /// Live chat tool: opens the Messages tab (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'الرسائل الخاصة'**
  String get liveChatPrivateMessages;

  /// Live chat tool: send a picture (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get liveChatPicture;

  /// The chat box while a clip or picture uploads (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإرسال…'**
  String get liveChatSending;

  /// Screen reader label of a voice clip line (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'{name}: مقطع صوتي، {duration}'**
  String liveChatVoiceLine(String name, String duration);

  /// Screen reader label of a picture line (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'{name}: صورة'**
  String liveChatPictureLine(String name);

  /// Plays a voice clip in the live chat (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get liveChatPlay;

  /// Pauses a voice clip in the live chat (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get liveChatPause;

  /// LIVE_KICKED (403, v1.20-live, D105): the host or a moderator kicked the caller out of this live.
  ///
  /// In ar, this message translates to:
  /// **'تم إخراجك من هذا البث. يمكنك مشاهدة البث التالي للمضيف.'**
  String get errorLiveKicked;

  /// Shown instead of the room when the host or a moderator kicked this person out (D105).
  ///
  /// In ar, this message translates to:
  /// **'تم إخراجك من هذا البث'**
  String get liveKickedTitle;

  /// Body of the removed-from-live message (D105).
  ///
  /// In ar, this message translates to:
  /// **'أخرجك المضيف أو أحد المشرفين، ولا يمكنك العودة إليه حتى ينتهي. يمكنك مشاهدة البث التالي للمضيف.'**
  String get liveKickedBody;

  /// Person card in a live: the points button (tooltip) and the title of the points popover (D105).
  ///
  /// In ar, this message translates to:
  /// **'النقاط في هذا البث'**
  String get liveUserPoints;

  /// Points popover: the person's place in this live's Contribution list.
  ///
  /// In ar, this message translates to:
  /// **'المركز {rank} في هذا البث'**
  String liveUserRank(String rank);

  /// Points popover: the person gave this live no points.
  ///
  /// In ar, this message translates to:
  /// **'لا نقاط في هذا البث بعد'**
  String get liveUserNoPoints;

  /// Person card (host, moderators): kicks the person out of this live (D105).
  ///
  /// In ar, this message translates to:
  /// **'إخراج من البث'**
  String get liveUserKick;

  /// Confirm dialog title before kicking someone out of a live.
  ///
  /// In ar, this message translates to:
  /// **'إخراج {name} من هذا البث؟'**
  String liveUserKickTitle(String name);

  /// Confirm dialog body before kicking someone out of a live.
  ///
  /// In ar, this message translates to:
  /// **'سيخرج من البث الآن ولن يستطيع العودة حتى ينتهي.'**
  String get liveUserKickBody;

  /// Confirm button: kick someone out of a live.
  ///
  /// In ar, this message translates to:
  /// **'إخراج'**
  String get liveUserKickConfirm;

  /// Snack after kicking someone out of a live.
  ///
  /// In ar, this message translates to:
  /// **'تم إخراج {name} من هذا البث'**
  String liveUserKicked(String name);

  /// Snack after the host makes someone a moderator from their card.
  ///
  /// In ar, this message translates to:
  /// **'{name} أصبح مشرفاً'**
  String liveUserModeratorAdded(String name);

  /// Snack after the host removes a moderator from their card.
  ///
  /// In ar, this message translates to:
  /// **'{name} لم يعد مشرفاً'**
  String liveUserModeratorRemoved(String name);

  /// Person card in a live: the more button (report, block).
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get liveUserMore;

  /// Person card in a live: the relationship (CP) box (not built yet).
  ///
  /// In ar, this message translates to:
  /// **'العلاقة'**
  String get liveUserCp;

  /// Person card in a live: a small box with nothing in it yet (family, CP).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد'**
  String get liveUserNone;

  /// Family box on someone else's card: families do not exist yet, so nobody is in one.
  ///
  /// In ar, this message translates to:
  /// **'ليس في عائلة بعد'**
  String get liveUserFamilyNone;

  /// Family box on your own card (owner's copy): families do not exist yet.
  ///
  /// In ar, this message translates to:
  /// **'لست في عائلة بعد'**
  String get liveUserFamilyNoneSelf;

  /// Family box: second line (owner's copy); joining is not built yet.
  ///
  /// In ar, this message translates to:
  /// **'انضم لعائلة أو أنشئ عائلتك'**
  String get liveUserFamilyHint;

  /// Relationship box: nobody is linked (CP does not exist yet).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد شريك بعد'**
  String get liveUserCpNone;

  /// Relationship box: the bottom bar; CP gifts are not built yet.
  ///
  /// In ar, this message translates to:
  /// **'هدايا CP قريباً: أرسلها لشخص مميّز لتصبحا ثنائياً'**
  String get liveUserCpBar;

  /// Screen reader label of the empty partner slot in the relationship box.
  ///
  /// In ar, this message translates to:
  /// **'مكان الشريك فارغ'**
  String get liveUserCpPartner;

  /// Tag on a public message (bullet, CP-017) shown as a box in the room chat (owner, 2026-10-26).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة'**
  String get liveBulletTag;

  /// ALREADY_IN_FAMILY (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'أنت في عائلة بالفعل. يمكنك أن تكون في عائلة واحدة فقط.'**
  String get errorAlreadyInFamily;

  /// FAMILY_FULL (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'هذه العائلة ممتلئة ولا تقبل أعضاء جدداً.'**
  String get errorFamilyFull;

  /// FAMILY_NAME_TAKEN (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'هذا الاسم مستخدم لعائلة أخرى. لم تُخصم أي عملات.'**
  String get errorFamilyNameTaken;

  /// FAMILY_REQUEST_PENDING (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب انضمام معلّق لعائلة أخرى. ألغِه أولاً.'**
  String get errorFamilyRequestPending;

  /// FAMILY_REQUEST_NOT_PENDING (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'تمت معالجة هذا الطلب أو أُلغي أو انتهت صلاحيته.'**
  String get errorFamilyRequestNotPending;

  /// FAMILY_NOT_EMPTY (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك حلّ العائلة فقط عندما تكون العضو الوحيد فيها.'**
  String get errorFamilyNotEmpty;

  /// FAMILY_LEADER_CANNOT_LEAVE (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'القائد لا يغادر العائلة: سلّمها لعضو آخر أو حلّها.'**
  String get errorFamilyLeaderCannotLeave;

  /// CP_ALREADY_PAIRED (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'أنت أو هذا الشخص لديه شريك بالفعل. لم تُخصم أي عملات.'**
  String get errorCpAlreadyPaired;

  /// CP_REQUEST_PENDING (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب علاقة معلّق. ألغِه من صفحة العلاقة أولاً.'**
  String get errorCpRequestPending;

  /// CP_REQUEST_NOT_PENDING (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'تمت معالجة طلب العلاقة هذا أو أُلغي أو انتهت صلاحيته.'**
  String get errorCpRequestNotPending;

  /// CP_NOT_PAIRED (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك شريك الآن. لم تُخصم أي عملات.'**
  String get errorCpNotPaired;

  /// MEDAL_NOT_UNLOCKED (409, CP-018).
  ///
  /// In ar, this message translates to:
  /// **'اختر فقط الميداليات التي حصلت عليها.'**
  String get errorMedalNotUnlocked;

  /// An amount of coins (CP-018 prices and balances).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{عملة واحدة} =2{عملتان} few{{count} عملات} many{{count} عملة} other{{count} عملة}}'**
  String bondsCoins(int count);

  /// A number of days (CP-018 request lifetime).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومين} few{{count} أيام} many{{count} يوماً} other{{count} يوم}}'**
  String bondsDays(int count);

  /// The coin balance on a spending screen (CP-018); coins is bondsCoins.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك: {coins}'**
  String bondsBalance(String coins);

  /// Confirm button of a CP-018 dialog.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get bondsConfirm;

  /// Cancel button of a CP-018 dialog.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get bondsCancel;

  /// Families screen title (CP-018).
  ///
  /// In ar, this message translates to:
  /// **'العائلات'**
  String get familiesTitle;

  /// Families search field hint. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الرقم'**
  String get familiesSearchHint;

  /// Families screen: your family section. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'عائلتي'**
  String get familiesMine;

  /// Button: create a family (costs coins). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أنشئ عائلة'**
  String get familiesCreate;

  /// Families list header without a search. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أفضل العائلات'**
  String get familiesTop;

  /// Families list header with a search. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'نتائج البحث'**
  String get familiesResults;

  /// Families list is empty. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عائلات بعد'**
  String get familiesEmpty;

  /// Families list is empty: hint. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'كن أول من ينشئ عائلة.'**
  String get familiesEmptyBody;

  /// Families search found nothing. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عائلة مطابقة'**
  String get familiesNoMatch;

  /// Families search found nothing: hint. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'جرّب اسماً آخر أو رقم العائلة المكوّن من 8 أرقام.'**
  String get familiesNoMatchBody;

  /// Families list failed to load. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل العائلات'**
  String get familiesLoadError;

  /// Search by an 8-digit number found nothing (404). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عائلة بهذا الرقم'**
  String get familiesNumberNotFound;

  /// A family number (8 digits). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'رقم العائلة {number}'**
  String familyNumber(String number);

  /// A family level badge. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'مستوى {level}'**
  String familyLevel(int level);

  /// Member count of a family. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء {count} / {capacity}'**
  String familyMembersCount(int count, int capacity);

  /// Banner: your pending join request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'طلبك للانضمام إلى {name} قيد الانتظار'**
  String familyPendingRequest(String name);

  /// Cancel your join request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get familyCancelRequest;

  /// Snack: join request cancelled. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء طلب الانضمام'**
  String get familyRequestCancelled;

  /// Family page: 404. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'العائلة غير موجودة'**
  String get familyNotFoundTitle;

  /// Family page: 404 body. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'ربما تم حلّ هذه العائلة.'**
  String get familyNotFoundBody;

  /// Family page failed to load. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل العائلة'**
  String get familyLoadError;

  /// Family or member points (pre-formatted digits). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'النقاط: {points}'**
  String familyPoints(String points);

  /// Family progress to the next level (pre-formatted numbers). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{points} / {next} للوصول إلى المستوى {level}'**
  String familyProgress(String points, String next, int level);

  /// Family at the top level. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'وصلت العائلة إلى أعلى مستوى'**
  String get familyTopLevel;

  /// The family leader. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'القائد: {name}'**
  String familyLeader(String name);

  /// Button: ask to join a family. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'اطلب الانضمام'**
  String get familyJoin;

  /// Snack: join request sent. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب الانضمام. يرد عليه القائد أو النواب.'**
  String get familyJoinSent;

  /// Family page: your request is pending. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الطلب'**
  String get familyRequested;

  /// Family page: full, cannot ask to join. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'العائلة ممتلئة'**
  String get familyFullLabel;

  /// Family page: you are in another family. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أنت عضو في عائلة أخرى'**
  String get familyInOther;

  /// Button: leave the family. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'مغادرة العائلة'**
  String get familyLeave;

  /// Leave confirm title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'مغادرة {name}؟'**
  String familyLeaveTitle(String name);

  /// Leave confirm body. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تبقى النقاط التي قدّمتها مع العائلة.'**
  String get familyLeaveBody;

  /// Snack: left the family. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'غادرت العائلة'**
  String get familyLeft;

  /// Leader menu tooltip. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إدارة العائلة'**
  String get familyManage;

  /// Leader: change the emblem. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تغيير الشعار'**
  String get familyChangeEmblem;

  /// Leader: remove the emblem. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إزالة الشعار'**
  String get familyRemoveEmblem;

  /// Snack: emblem updated. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الشعار'**
  String get familyEmblemUpdated;

  /// Snack: emblem removed. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تمت إزالة الشعار'**
  String get familyEmblemRemoved;

  /// Leader: disband (only when alone). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'حلّ العائلة'**
  String get familyDisband;

  /// Disband confirm title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'حلّ {name}؟'**
  String familyDisbandTitle(String name);

  /// Disband confirm body. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'يصبح الاسم متاحاً لغيرك ولا تُسترد العملات.'**
  String get familyDisbandBody;

  /// Snack: disbanded. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم حلّ العائلة'**
  String get familyDisbanded;

  /// Disband is unavailable: other members. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الحلّ عندما تكون العضو الوحيد'**
  String get familyDisbandOnlyAlone;

  /// Family page: pending join requests (leader, deputies). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'طلبات الانضمام'**
  String get familyRequestsTitle;

  /// No pending join requests. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات حالياً'**
  String get familyRequestsEmpty;

  /// Accept a join request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get familyAccept;

  /// Decline a join request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get familyDecline;

  /// Snack: join request accepted. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'انضم {name} إلى العائلة'**
  String familyAccepted(String name);

  /// Snack: join request declined. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get familyDeclined;

  /// Family page: members section. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء'**
  String get familyMembersTitle;

  /// Family role. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'القائد'**
  String get familyRoleLeader;

  /// Family role. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'نائب'**
  String get familyRoleDeputy;

  /// Family role. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'عضو'**
  String get familyRoleMember;

  /// Leader: make a member a deputy. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تعيين نائباً'**
  String get familyMakeDeputy;

  /// Leader: make a deputy a member. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إعادة إلى عضو'**
  String get familyMakeMember;

  /// Leader: transfer leadership. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تسليم القيادة'**
  String get familyTransfer;

  /// Transfer confirm title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تسليم القيادة إلى {name}؟'**
  String familyTransferTitle(String name);

  /// Transfer confirm body. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'يصبح {name} القائد وتصبح أنت نائباً.'**
  String familyTransferBody(String name);

  /// Snack: transferred. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أصبح {name} القائد'**
  String familyTransferred(String name);

  /// Leader: remove a member. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إزالة من العائلة'**
  String get familyRemove;

  /// Remove confirm title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name} من العائلة؟'**
  String familyRemoveTitle(String name);

  /// Snack: member removed. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تمت إزالة {name}'**
  String familyRemoved(String name);

  /// Snack: role changed. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير دور {name}'**
  String familyRoleChanged(String name);

  /// Leader: member menu tooltip. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'خيارات العضو'**
  String get familyMemberActions;

  /// Create family screen title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'عائلة جديدة'**
  String get familyCreateTitle;

  /// Create family: name field. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'اسم العائلة'**
  String get familyNameLabel;

  /// Create family: name help. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'من 2 إلى 20 حرفاً، ولا يتكرر بين العائلات.'**
  String get familyNameHelp;

  /// Create family: invalid name (VALIDATION_FAILED on name). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'استخدم من 2 إلى 20 حرفاً بدون رموز غير مسموحة.'**
  String get familyNameInvalid;

  /// Create family: emblem picker. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'الشعار (اختياري)'**
  String get familyEmblemLabel;

  /// Create family: emblem picker button. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'اختر صورة للشعار'**
  String get familyEmblemChoose;

  /// Create family: price (coins is bondsCoins). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إنشاء العائلة يكلّف {coins}'**
  String familyCreateCost(String coins);

  /// Create family: submit (coins is bondsCoins). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أنشئ مقابل {coins}'**
  String familyCreateSubmit(String coins);

  /// Create family: INSUFFICIENT_COINS. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تحتاج {coins} لإنشاء عائلة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.'**
  String familyCreateNotEnough(String coins);

  /// Snack: family created. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء {name}'**
  String familyCreated(String name);

  /// CP page title (CP-018).
  ///
  /// In ar, this message translates to:
  /// **'العلاقة'**
  String get cpTitle;

  /// CP: days together (the first day is day 1). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'اليوم {days} معاً'**
  String cpDay(int days);

  /// CP points (pre-formatted). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'نقاط العلاقة: {points}'**
  String cpPoints(String points);

  /// CP: points to the next tier. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'باقي {points} للوصول إلى {name}'**
  String cpToNext(String points, String name);

  /// CP at the top tier. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'وصلتما إلى أعلى مستوى'**
  String get cpTopTier;

  /// CP: formed on. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'منذ {date}'**
  String cpSince(String date);

  /// CP: gift section title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أرسل هدية علاقة'**
  String get cpGiftTitle;

  /// CP: gift section explanation. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تضيف الهدية نقاطاً لعلاقتكما، ولا يحصل شريكك على عملات.'**
  String get cpGiftBody;

  /// CP gift confirm (coins is bondsCoins). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إرسال {coins} كهدية علاقة؟'**
  String cpGiftConfirmTitle(String coins);

  /// Snack: CP gift sent. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الهدية: +{points} نقطة'**
  String cpGiftSent(String points);

  /// CP gift: INSUFFICIENT_COINS. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك عملات كافية لهذه الهدية. يضيف الفريق العملات حالياً.'**
  String get cpGiftNotEnough;

  /// CP: end the couple. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إنهاء العلاقة'**
  String get cpEnd;

  /// End confirm title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إنهاء العلاقة مع {name}؟'**
  String cpEndTitle(String name);

  /// End confirm body. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا تُسترد أي عملات.'**
  String get cpEndBody;

  /// Snack: ended. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'انتهت العلاقة'**
  String get cpEnded;

  /// CP page: no couple. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد شريك بعد'**
  String get cpNoneTitle;

  /// CP page: no couple, hint. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أرسل طلب علاقة من الملف الشخصي لشخص ما أو من بطاقته في البث.'**
  String get cpNoneBody;

  /// CP page: requests section. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'طلبات العلاقة'**
  String get cpRequestsTitle;

  /// CP requests: incoming tab. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'الواردة'**
  String get cpIncoming;

  /// CP requests: outgoing tab. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'المرسلة'**
  String get cpOutgoing;

  /// CP: no incoming requests. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات واردة'**
  String get cpIncomingEmpty;

  /// CP: no outgoing requests. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات مرسلة'**
  String get cpOutgoingEmpty;

  /// Incoming CP request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{name} يريد أن تكونا ثنائياً'**
  String cpRequestFrom(String name);

  /// Outgoing CP request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'بانتظار رد {name}'**
  String cpRequestTo(String name);

  /// CP request expiry. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في {date}'**
  String cpExpires(String date);

  /// Accept a CP request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get cpAccept;

  /// Decline a CP request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get cpDecline;

  /// Cancel your CP request (coins come back). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cpCancel;

  /// Snack: CP request accepted. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أنت و{name} ثنائي الآن'**
  String cpAccepted(String name);

  /// Snack: CP request declined. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get cpDeclined;

  /// Snack: CP request cancelled (refunded). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب وأُعيدت العملات'**
  String get cpCancelled;

  /// Button: send a CP request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أرسل طلب علاقة'**
  String get cpSendRequest;

  /// CP box on someone else's card when you can send a request. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'أرسل طلباً'**
  String get cpSendShort;

  /// CP request confirm title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب علاقة إلى {name}؟'**
  String cpSendTitle(String name);

  /// CP request confirm body (coins bondsCoins, days bondsDays). (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'يكلّف الطلب {coins}. تعود إليك العملات إذا رُفض أو أُلغي أو لم يُرد عليه خلال {days}.'**
  String cpSendBody(String coins, String days);

  /// Snack: CP request sent. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب العلاقة إلى {name}'**
  String cpSent(String name);

  /// CP request: INSUFFICIENT_COINS. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تحتاج {coins} لإرسال طلب علاقة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.'**
  String cpSendNotEnough(String coins);

  /// CP page failed to load. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل العلاقة'**
  String get cpLoadError;

  /// CP box value: partner and tier name. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{name} · {tier}'**
  String cpBoxValue(String name, String tier);

  /// Family box value: name and level. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{name} · مستوى {level}'**
  String familyBoxValue(String name, int level);

  /// Medals screen title (CP-018).
  ///
  /// In ar, this message translates to:
  /// **'الميداليات'**
  String get medalsTitle;

  /// Medals owned of the catalogue. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{owned} من {total}'**
  String medalsOwned(int owned, int total);

  /// Button: open the showcase picker. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'اختر الميداليات المعروضة'**
  String get medalsChoose;

  /// A medal not earned yet. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'مقفلة'**
  String get medalsLocked;

  /// When a medal was earned. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'حصلت عليها في {date}'**
  String medalsEarnedOn(String date);

  /// No medals earned. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ميداليات بعد'**
  String get medalsEmptyTitle;

  /// Explains how medals are earned. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تُمنح الميداليات تلقائياً عند البث ومستويات الجاذبية والعائلات والعلاقات.'**
  String get medalsEmptyBody;

  /// Medals failed to load. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الميداليات'**
  String get medalsLoadError;

  /// Showcase picker title. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'ميداليات ملفك'**
  String get medalsShowcaseTitle;

  /// Showcase picker hint. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'اختر حتى {max} ميداليات بالترتيب الذي تريده.'**
  String medalsShowcaseHint(int max);

  /// Showcase picker: chosen of the maximum. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{count} / {max}'**
  String medalsShowcaseCount(int count, int max);

  /// Snack: showcase full. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'يمكنك عرض {max} ميداليات كحد أقصى'**
  String medalsShowcaseLimit(int max);

  /// Showcase picker: save. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get medalsShowcaseSave;

  /// Snack: showcase saved. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ ميداليات ملفك'**
  String get medalsShowcaseSaved;

  /// Showcase picker: nothing chosen. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لا شيء معروض. اختر ميداليات من الأسفل.'**
  String get medalsShowcaseEmptyPreview;

  /// Showcase picker: nothing unlocked. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'لم تحصل على ميداليات بعد، لذا لا يوجد ما تعرضه.'**
  String get medalsShowcaseNoneEarned;

  /// Screen reader label of the medal row on a profile or card. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'الميداليات: {names}'**
  String medalsRowLabel(String names);

  /// Screen reader: a chosen medal and its place. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{name}، الترتيب {position}'**
  String medalsPosition(String name, int position);

  /// Showcase picker: leaving with unsaved changes. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تجاهل التغييرات؟'**
  String get medalsDiscard;

  /// Showcase picker: discard. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get medalsDiscardConfirm;

  /// Notification CP_REQUEST. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{who} أرسل لك طلب علاقة'**
  String notifCpRequest(String who);

  /// Notification CP_ACCEPTED. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'{who} قبل طلب العلاقة، أصبحتما ثنائياً'**
  String notifCpAccepted(String who);

  /// Notification FAMILY_JOIN_ACCEPTED. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم قبولك في عائلة {family}'**
  String notifFamilyJoinAccepted(String family);

  /// Notification FAMILY_JOIN_DECLINED. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'تم رفض طلبك للانضمام إلى {family}'**
  String notifFamilyJoinDeclined(String family);

  /// Notification MEDAL_AWARDED with the name from GET /medals. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'حصلت على ميدالية جديدة: {name}'**
  String notifMedalAwarded(String name);

  /// Notification MEDAL_AWARDED before the name is known. (CP-018 (D106))
  ///
  /// In ar, this message translates to:
  /// **'حصلت على ميدالية جديدة'**
  String get notifMedalAwardedUnnamed;

  /// BAG_ITEM_NOT_OWNED (409, CP-019).
  ///
  /// In ar, this message translates to:
  /// **'هذا العنصر ليس في حقيبتك.'**
  String get errorBagItemNotOwned;

  /// The bag screen title and the Me tab tile. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'الحقيبة'**
  String get bagTitle;

  /// The bag tile's line on your own profile. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'زيّن بطاقتك'**
  String get bagTileValue;

  /// Bag category PROFILE_CARD (tab). (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'بطاقة الملف الشخصي'**
  String get bagCategoryProfileCard;

  /// Bag screen error title. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الحقيبة'**
  String get bagLoadError;

  /// Badge on the item worn now. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'قيد الارتداء'**
  String get bagWorn;

  /// Button: wear this item. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'ارتداء'**
  String get bagWear;

  /// Button: stop wearing this item. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'خلع'**
  String get bagTakeOff;

  /// A catalogue item the user does not own (no store yet). (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'لم تمتلكه بعد'**
  String get bagLocked;

  /// Bag empty state title. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'حقيبتك فارغة'**
  String get bagEmptyTitle;

  /// Bag empty state message. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا العناصر التي تحصل عليها.'**
  String get bagEmptyMessage;

  /// Bag section: items the user owns. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'عناصرك'**
  String get bagOwnedSection;

  /// Bag section: catalogue items not owned. (CP-019 (D107))
  ///
  /// In ar, this message translates to:
  /// **'عناصر أخرى'**
  String get bagLockedSection;

  /// Error GIFT_UNAVAILABLE. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'هذه الهدية لم تعد متاحة.'**
  String get errorGiftUnavailable;

  /// Error GIFT_BAG_INSUFFICIENT. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد في حقيبتك ما يكفي من هذه الهدية.'**
  String get errorGiftBagInsufficient;

  /// Error LIVE_GIFT_RECIPIENT_UNAVAILABLE. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'أحد المستلمين لم يعد على المايك.'**
  String get errorLiveGiftRecipientUnavailable;

  /// Gift panel tab POPULAR. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'شائعة'**
  String get liveGiftTabPopular;

  /// Gift panel tab EVENT. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'مناسبات'**
  String get liveGiftTabEvent;

  /// Gift panel tab FUN. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'مرح'**
  String get liveGiftTabFun;

  /// Gift panel tab: the caller's gift bag. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'الحقيبة'**
  String get liveGiftTabBag;

  /// Chip on the host's picture in the gift recipients row. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get liveGiftHost;

  /// Toggle: send to the host and everyone on the mic. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get liveGiftAllOnMic;

  /// Screen reader label of the All toggle. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'الإهداء لكل من على المايك'**
  String get liveGiftAllOnMicSemantics;

  /// Gift panel: the catalogue is empty. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد هدايا بعد'**
  String get liveGiftEmptyTitle;

  /// Gift panel empty catalogue message. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'ستظهر الهدايا هنا عندما يضيفها فريق Kabso Live.'**
  String get liveGiftEmptyMessage;

  /// Gift panel bag tab empty title. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'حقيبة الهدايا فارغة'**
  String get liveGiftBagEmptyTitle;

  /// Gift panel bag tab empty message. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'الهدايا التي تحصل عليها تظهر هنا، وترسلها دون عملات.'**
  String get liveGiftBagEmptyMessage;

  /// Gift panel error title. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الهدايا'**
  String get liveGiftLoadError;

  /// Why Send is disabled: no gift selected. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'اختر هدية'**
  String get liveGiftPickGift;

  /// Why Send is disabled: no recipient. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'اختر من سيستلم الهدية'**
  String get liveGiftPickRecipient;

  /// Host's panel: no seated people. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أحد على المايك لإهدائه'**
  String get liveGiftNoRecipients;

  /// Gift panel for guests. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لإرسال الهدايا'**
  String get liveGiftSignIn;

  /// INSUFFICIENT_COINS on a gift send. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'رصيدك من العملات لا يكفي لهذه الهدية.'**
  String get liveGiftNotEnoughCoins;

  /// Screen reader label of the coin balance. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'رصيدك: {coins}'**
  String liveGiftBalance(String coins);

  /// Screen reader label of the quantity selector. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'الكمية {count}'**
  String liveGiftQuantity(String count);

  /// Gift badge NEW. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get liveGiftBadgeNew;

  /// Gift badge EVENT. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'مناسبة'**
  String get liveGiftBadgeEvent;

  /// Gift banner line under the sender's name. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'أهدى {gift} إلى {recipients}'**
  String liveGiftBannerSent(String gift, String recipients);

  /// Two recipients in a gift banner. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String liveGiftRecipientsTwo(String first, String second);

  /// More than two recipients: the first and how many more. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'{name} +{count}'**
  String liveGiftRecipientsMore(String name, int count);

  /// A gift whose name the app does not have. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get liveGiftGeneric;

  /// Gift panel opened from a person who cannot receive gifts. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'{name} ليس على المايك. تُرسل الهدايا للمضيف ولمن على المايك.'**
  String liveGiftNotOnMic(String name);

  /// Screen reader: how many of a bag gift the caller holds. (CP-020 (D108))
  ///
  /// In ar, this message translates to:
  /// **'لديك {count}'**
  String liveGiftBagCount(String count);

  /// Gift panel: the first sub-category chip, every gift of the open tab. (D117)
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get liveGiftTagAll;

  /// Screen reader label of the gift panel's sub-category chip row. (D117)
  ///
  /// In ar, this message translates to:
  /// **'تصنيفات الهدايا'**
  String get liveGiftTagsSemantics;

  /// CP space: page title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'مساحة الثنائي'**
  String get cpSpaceTitle;

  /// CP: button to the CP space. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'فتح مساحة الثنائي'**
  String get cpSpaceOpen;

  /// CP space: help sheet title and button tooltip. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'كيف تعمل مساحة الثنائي'**
  String get cpSpaceHelpTitle;

  /// CP space: help text; zone = the CP day's time zone. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'القرب هو نقاط علاقتكما: تزيده هدايا الثنائي ومكافآت المهام اليومية، وكل مستوى أعلى يفتح امتيازات أكثر. تبدأ المهام اليومية من جديد كل يوم عند 00:00 ({zone}).'**
  String cpSpaceHelpBody(String zone);

  /// CP space: days together on the ribbon. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} many{{days} يومًا} other{{days} يوم}}'**
  String cpSpaceDays(int days);

  /// CP space: quick action and section title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'المهام اليومية'**
  String get cpSpaceActionTasks;

  /// CP space: quick action and section title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'امتيازات الثنائي'**
  String get cpSpaceActionPrivileges;

  /// CP space: quick action and section title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'هدايا الثنائي'**
  String get cpSpaceActionGifts;

  /// CP space: quick action. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get cpSpaceActionRanking;

  /// CP space: section title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'مستوى الثنائي'**
  String get cpSpaceLevelTitle;

  /// CP space: the CP level, large. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'Lv.{level}'**
  String cpSpaceLevel(int level);

  /// CP space: points of the couple / points of the next level. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'{points} / {target}'**
  String cpSpaceProgress(String points, String target);

  /// CP space: the couple's CP points. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'القرب {points}'**
  String cpSpaceIntimacy(String points);

  /// CP space: points left to the next tier. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'{points} قرب إضافي للوصول إلى {name}'**
  String cpSpaceToNext(String points, String name);

  /// CP space: when today's tasks reset. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تبدأ من جديد عند {time}'**
  String cpSpaceTasksResets(String time);

  /// CP space: a task's reward in intimacy. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'+{points}'**
  String cpSpaceTaskReward(String points);

  /// CP space: task progress. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'{progress}/{target}'**
  String cpSpaceTaskProgress(int progress, int target);

  /// CP space: claim a task reward. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'استلام'**
  String get cpSpaceClaim;

  /// CP space: a claimed task. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تم الاستلام'**
  String get cpSpaceClaimed;

  /// CP space: a task not done today. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لم تكتمل'**
  String get cpSpaceNotDone;

  /// CP space: a claim added intimacy. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'+{points} قرب'**
  String cpSpaceClaimedToast(String points);

  /// CP space: the partner claimed it already. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تم استلامها اليوم'**
  String get cpSpaceClaimedBefore;

  /// CP space: tasks failed to load. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل مهام اليوم'**
  String get cpSpaceTasksError;

  /// CP privilege name. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'إطار مميز'**
  String get cpPrivSpecialFrame;

  /// CP privilege name. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'فقاعة حصرية'**
  String get cpPrivChatBubble;

  /// CP privilege name. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تأثير مايك الثنائي'**
  String get cpPrivMicEffect;

  /// CP privilege name. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تأثير الدخول'**
  String get cpPrivEntranceEffect;

  /// CP privilege name. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'جدار هدايا الثنائي'**
  String get cpPrivGiftWall;

  /// CP privilege description. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'إطار على شكل قلب حول صورتيكما.'**
  String get cpPrivSpecialFrameAbout;

  /// CP privilege description. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تظهر رسائلكما في دردشة البث داخل فقاعة الثنائي.'**
  String get cpPrivChatBubbleAbout;

  /// CP privilege description. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تأثير الثنائي على مقعديكما عندما تكونان على المايك.'**
  String get cpPrivMicEffectAbout;

  /// CP privilege description. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'عندما تدخل بثًا، ترى الغرفة دخولك كثنائي.'**
  String get cpPrivEntranceEffectAbout;

  /// CP privilege description. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'يرى الجميع هدايا الثنائي التي تبادلتماها.'**
  String get cpPrivGiftWallAbout;

  /// CP space: the level that unlocks a privilege. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'يُفتح عند Lv.{level}'**
  String cpSpaceUnlocksAt(int level);

  /// CP space: an unlocked privilege. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get cpSpaceUnlocked;

  /// CP space: a locked privilege. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get cpSpaceLocked;

  /// CP space: open the gift wall. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'جدار الهدايا'**
  String get cpSpaceGiftWall;

  /// CP space: gift wall totals. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'الهدايا {gifts} · العملات {coins}'**
  String cpSpaceGiftWallTotals(String gifts, String coins);

  /// CP space: who sent a gift to whom. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'من {from} إلى {to}'**
  String cpSpaceGiftWallEntry(String from, String to);

  /// CP space: empty gift wall. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد هدايا ثنائي بعد'**
  String get cpSpaceGiftWallEmpty;

  /// CP space: another couple's wall before it is unlocked. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'يُفتح جدار هدايا هذا الثنائي عند Lv.{level}.'**
  String cpSpaceGiftWallLocked(int level);

  /// CP space: gift wall failed. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل جدار الهدايا'**
  String get cpSpaceGiftWallError;

  /// CP space: confirm a named CP gift. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'إرسال {gift} مقابل {coins}؟'**
  String cpSpaceGiftConfirm(String gift, String coins);

  /// CP space: section title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'جدار الاعترافات'**
  String get cpSpaceConfessionsTitle;

  /// CP space: empty confession wall (own couple). (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'كن أول من يترك اعترافًا لشريكك'**
  String get cpSpaceConfessionsEmpty;

  /// CP space: empty confession wall (another couple). (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد اعترافات بعد'**
  String get cpSpaceConfessionsEmptyPublic;

  /// CP space: confession field hint. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'اكتب إلى {name}'**
  String cpSpaceConfessionHint(String name);

  /// CP space: send a confession. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get cpSpaceConfessionSend;

  /// CP space: confession written. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تم ترك الاعتراف'**
  String get cpSpaceConfessionSent;

  /// CP space: a confession's author and recipient. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'من {from} إلى {to}'**
  String cpSpaceConfessionTo(String from, String to);

  /// CP space: confession menu tooltip. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'خيارات الاعتراف'**
  String get cpSpaceConfessionMenu;

  /// CP space: delete a confession. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get cpSpaceConfessionDelete;

  /// CP space: confirm delete. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا الاعتراف؟'**
  String get cpSpaceConfessionDeleteTitle;

  /// CP space: deleted. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الاعتراف'**
  String get cpSpaceConfessionDeleted;

  /// CP space: report a confession. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ'**
  String get cpSpaceConfessionReport;

  /// CP space: report reasons title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذا الاعتراف؟'**
  String get cpSpaceConfessionReportTitle;

  /// CP space: confessions failed. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الاعترافات'**
  String get cpSpaceConfessionsError;

  /// CP space: ranking sheet title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'ترتيب الثنائيات'**
  String get cpSpaceRankingTitle;

  /// CP space: ranking tab. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get cpSpaceRankingWeek;

  /// CP space: ranking tab. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'كل الأوقات'**
  String get cpSpaceRankingAll;

  /// CP space: empty ranking. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ثنائيات هنا بعد'**
  String get cpSpaceRankingEmpty;

  /// CP space: ranking failed. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الترتيب'**
  String get cpSpaceRankingError;

  /// CP space: the caller's rank. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'ثنائيكما: #{rank}'**
  String cpSpaceRankingMe(String rank);

  /// CP space: the caller has no points in the period. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'ثنائيكما غير مرتّب بعد'**
  String get cpSpaceRankingMeUnranked;

  /// CP space: two partners' names. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String cpSpacePair(String first, String second);

  /// CP space: failed to load. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل مساحة الثنائي'**
  String get cpSpaceLoadError;

  /// CP space: 404 title. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'مساحة هذا الثنائي غير متاحة'**
  String get cpSpaceGoneTitle;

  /// CP space: 404 body. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'ربما انتهت العلاقة، أو لا يمكن عرضها لك.'**
  String get cpSpaceGoneBody;

  /// Error CP_TASK_NOT_COMPLETED (CP-021). (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لم تكتمل هذه المهمة اليوم بعد.'**
  String get errorCpTaskNotCompleted;

  /// Error CP_PRIVILEGE_LOCKED (CP-021). (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'لم يفتح هذا الثنائي هذه الميزة بعد.'**
  String get errorCpPrivilegeLocked;

  /// CP Entrance Effect banner in a live: the joiner and their CP partner. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'{name} و{partner}'**
  String liveCpEntranceCouple(String name, String partner);

  /// CP Entrance Effect banner: second line with the CP level name. (CP-021 (D112))
  ///
  /// In ar, this message translates to:
  /// **'دخول الثنائي · {level}'**
  String liveCpEntranceLevel(String level);

  /// Error FAMILY_CHAT_MUTED. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم كتمك في دردشة العائلة.'**
  String get errorFamilyChatMuted;

  /// Families screen: section title above the search and boards. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'قائمة العائلات'**
  String get familiesListTitle;

  /// Families screen: search field hint (name or number). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن عائلة'**
  String get familiesSearchShort;

  /// Board tab: families by points gained this month. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'هيبة العائلة'**
  String get familiesTabPrestige;

  /// Board tab shown as Soon: family battles are not built. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'ترتيب القتال'**
  String get familiesTabBattle;

  /// Board tab: families by members active this week. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الأكثر نشاطاً'**
  String get familiesTabActive;

  /// Screen-reader label of a feature that is not built yet. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'{feature}، قريباً'**
  String familiesSoonLabel(String feature);

  /// Board empty state title. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عائلات في الترتيب بعد'**
  String get familiesBoardEmpty;

  /// Prestige board empty state body. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا العائلات التي جمعت نقاطاً هذا الشهر.'**
  String get familiesBoardEmptyPrestige;

  /// Active board empty state body. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا العائلات التي نشط أعضاؤها هذا الأسبوع.'**
  String get familiesBoardEmptyActive;

  /// Board row: points gained this month (compact). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'نقاط هذا الشهر: {points}'**
  String familiesScoreMonth(String points);

  /// Board row: members active this week (compact). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'نشطون هذا الأسبوع: {count}'**
  String familiesScoreActive(String count);

  /// Screen-reader label of a podium card. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'المركز {place}: {name}'**
  String familiesPodiumLabel(int place, String name);

  /// Pinned bar: the caller's family has no score on this board. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'لم تدخل عائلتك الترتيب بعد'**
  String get familiesMyRankNone;

  /// Gold Join pill on a family row. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'انضمام'**
  String get familyJoinShort;

  /// Screen-reader label of the podium + button. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'انضمام إلى {name}'**
  String familyJoinNamed(String name);

  /// A family level (podium, rows, hero chip, progress). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'المستوى {level}'**
  String familyLevelLong(int level);

  /// Presence: last active under a minute ago but not counted online. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'نشط الآن'**
  String get familyActiveJustNow;

  /// Presence: active in the last 5 minutes. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'متصل الآن'**
  String get familyOnlineNow;

  /// Small tag on a feature that is not built yet (D62 convention). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get familySoon;

  /// Family page title in the hero. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get familyPageTitle;

  /// Hero share button tooltip (copies the invite). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'مشاركة العائلة'**
  String get familyShare;

  /// Family page bottom bar: copies the invite text. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'دعوة أعضاء'**
  String get familyInvite;

  /// Snack after copying the invite. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الدعوة. أرسلها لمن تريد.'**
  String get familyInviteCopied;

  /// The copied invite (no public link yet, B7). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى عائلتي «{name}» على Kabso Live. رقم العائلة: {number}'**
  String familyInviteText(String name, String number);

  /// Hero box label above the number. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'رقم العائلة'**
  String get familyNumberLabel;

  /// Screen-reader label of the number box. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'رقم العائلة {number}، انسخ'**
  String familyNumberCopy(String number);

  /// Hero menu item. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'نسخ رقم العائلة'**
  String get familyCopyNumber;

  /// Under the member count in the header. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'عضو'**
  String get familyMemberWord;

  /// Member count (compact) next to the member search. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'{count} عضو'**
  String familyMembersShort(String count);

  /// Members tab search hint. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'ابحث في الأعضاء'**
  String get familyMembersSearchHint;

  /// Members tab: empty search. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عضو بهذا الاسم'**
  String get familyMembersNoMatch;

  /// Under the level progress numbers. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'للوصول إلى المستوى {level}'**
  String familyToReach(int level);

  /// Tool tile (leader). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'إدارة العائلة'**
  String get familyToolManage;

  /// Tool tile shown as Soon. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'المسابقات'**
  String get familyToolCompetitions;

  /// Tool tile shown as Soon. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'متجر العائلة'**
  String get familyToolShop;

  /// Tool tile shown as Soon. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get familyToolTasks;

  /// Family page tab. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء'**
  String get familyTabMembers;

  /// Family page tab shown as Soon. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الفعاليات'**
  String get familyTabEvents;

  /// Family page tab: this month's contributions. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'المساهمات'**
  String get familyTabContributions;

  /// Family page tab: the family on both boards. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get familyTabRanking;

  /// Contributions tab header. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'مساهمات الأعضاء هذا الشهر'**
  String get familyContributionsThisMonth;

  /// Contributions tab empty title. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'لا مساهمات هذا الشهر بعد'**
  String get familyContributionsEmpty;

  /// Contributions tab empty body. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'كل عملة ينفقها الأعضاء في التطبيق تُحتسب للعائلة.'**
  String get familyContributionsEmptyBody;

  /// Ranking tab: not ranked (score 0). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'—'**
  String get familyRankNone;

  /// Ranking tab footnote. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الترتيب بين كل العائلات: هيبة العائلة لهذا الشهر، والنشاط لهذا الأسبوع.'**
  String get familyRankingNote;

  /// Leader menu item. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تغيير الغلاف'**
  String get familyChangeCover;

  /// Leader menu item. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'إزالة الغلاف'**
  String get familyRemoveCover;

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الغلاف'**
  String get familyCoverUpdated;

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تمت إزالة الغلاف'**
  String get familyCoverRemoved;

  /// Dialog title and menu item (the line under the name). (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'وصف العائلة'**
  String get familyTaglineTitle;

  /// Tagline field hint. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'مثال: عائلة عالمية · ترفيه · بث مباشر'**
  String get familyTaglineHint;

  /// Dialog save button. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get familySave;

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get familySaved;

  /// Member menu item. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'عرض الملف الشخصي'**
  String get familyViewProfile;

  /// Family page bottom bar: opens the family chat. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'مراسلة العائلة'**
  String get familyChatOpen;

  /// Family chat title while the family loads. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'دردشة العائلة'**
  String get familyChatTitle;

  /// Family chat input hint. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة للعائلة'**
  String get familyChatHint;

  /// Family chat send button tooltip. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get familyChatSend;

  /// Family chat empty title. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'ابدأوا الحديث'**
  String get familyChatEmpty;

  /// Family chat empty body. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الرسائل هنا يراها أعضاء العائلة فقط.'**
  String get familyChatEmptyBody;

  /// Family chat load error. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الدردشة'**
  String get familyChatLoadError;

  /// Family chat: the caller is not a member. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الدردشة لأعضاء العائلة فقط'**
  String get familyChatMembersOnly;

  /// Family chat: not a member body. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى العائلة لتشارك في الدردشة.'**
  String get familyChatMembersOnlyBody;

  /// Family chat long-press action. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'حذف الرسالة'**
  String get familyChatDelete;

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الرسالة'**
  String get familyChatDeleted;

  /// Family chat long-press action and report sheet title. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن الرسالة'**
  String get familyChatReport;

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'شكراً، تم إرسال البلاغ'**
  String get familyChatReported;

  /// Member menu: leader or deputy mutes the member in the family chat. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'كتم في الدردشة'**
  String get familyChatMute;

  /// Member menu. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم في الدردشة'**
  String get familyChatUnmute;

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم كتم {name} في الدردشة'**
  String familyChatMutedName(String name);

  /// Snack. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء كتم {name}'**
  String familyChatUnmutedName(String name);

  /// Privacy section title. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'حالة النشاط'**
  String get privacyActivityTitle;

  /// Privacy switch. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'إظهار حالة النشاط'**
  String get privacyActivityLabel;

  /// Privacy switch subtitle. (CP-022 (D116))
  ///
  /// In ar, this message translates to:
  /// **'يرى أعضاء عائلتك إن كنت متصلاً الآن أو متى كنت نشطاً آخر مرة.'**
  String get privacyActivityHint;

  /// D121: follow-list row button when that person follows you and you do not follow them.
  ///
  /// In ar, this message translates to:
  /// **'رد المتابعة'**
  String get followListsFollowBack;

  /// D121: empty Followers tab.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد متابِعون بعد'**
  String get followListsFollowersEmpty;

  /// D121: under followListsFollowersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'عندما يتابع أحدٌ هذا الحساب سيظهر هنا.'**
  String get followListsFollowersEmptyBody;

  /// D121: empty Following tab.
  ///
  /// In ar, this message translates to:
  /// **'لا يتابع أحدًا بعد'**
  String get followListsFollowingEmpty;

  /// D121: under followListsFollowingEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا الحسابات التي يتابعها هذا الحساب.'**
  String get followListsFollowingEmptyBody;

  /// D121: a private account's lists for someone who does not follow it (403); under profilePrivateTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يرى متابِعي هذا الحساب ومن يتابعهم إلا متابِعوه.'**
  String get followListsPrivateBody;

  /// D125: Followers tab with the profile's count (compact, Latin digits).
  ///
  /// In ar, this message translates to:
  /// **'{count} المتابِعون'**
  String followListsTabFollowers(String count);

  /// D125: Following tab with the profile's count (compact, Latin digits).
  ///
  /// In ar, this message translates to:
  /// **'{count} يتابع'**
  String followListsTabFollowing(String count);

  /// D125: header add-person button (opens Discover / search).
  ///
  /// In ar, this message translates to:
  /// **'اكتشف أشخاصاً'**
  String get followListsAddPeople;

  /// D125: search field hint (searches within the list by name or @username).
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get followListsSearchHint;

  /// D125: sort row label, followed by the current order in bold.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب:'**
  String get followListsSortBy;

  /// D125: sort order: newest follow first (the default).
  ///
  /// In ar, this message translates to:
  /// **'الافتراضي'**
  String get followListsSortDefault;

  /// D125: sort order: oldest follow first.
  ///
  /// In ar, this message translates to:
  /// **'الأقدم أولاً'**
  String get followListsSortOldest;

  /// D125: tooltip of the sort toggle (default / oldest first).
  ///
  /// In ar, this message translates to:
  /// **'تغيير الترتيب'**
  String get followListsSortToggle;

  /// D125: tooltip / screen-reader label of a row's ⋯ menu.
  ///
  /// In ar, this message translates to:
  /// **'خيارات {name}'**
  String followListsRowMore(String name);

  /// D125: ⋯ menu item on your own Followers tab.
  ///
  /// In ar, this message translates to:
  /// **'إزالة المتابِع'**
  String get followListsRemoveFollower;

  /// D125: confirm title before removing a follower.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name} من متابِعيك؟'**
  String followListsRemoveFollowerTitle(String name);

  /// D125: confirm body before removing a follower.
  ///
  /// In ar, this message translates to:
  /// **'لن يُبلَّغ بذلك، ويستطيع متابعتك مجدداً ما لم يكن حسابك خاصاً.'**
  String get followListsRemoveFollowerBody;

  /// D125: confirm button of removing a follower.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get followListsRemoveFollowerConfirm;

  /// D125: snack after removing a follower.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل {name} من متابِعيك'**
  String followListsFollowerRemoved(String name);

  /// D125: the list has no one matching the search.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج'**
  String get followListsNoMatch;

  /// D125: under followListsNoMatch.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد في هذه القائمة يبدأ اسمه بـ «{query}».'**
  String followListsNoMatchBody(String query);

  /// D121: screen-reader hint of the Followers count on a profile (opens the list).
  ///
  /// In ar, this message translates to:
  /// **'عرض المتابِعين'**
  String get profileOpenFollowers;

  /// D121: screen-reader hint of the Following count on a profile (opens the list).
  ///
  /// In ar, this message translates to:
  /// **'عرض من يتابعهم'**
  String get profileOpenFollowing;

  /// No description provided for @liveHubBrand.
  ///
  /// In ar, this message translates to:
  /// **'Kabso'**
  String get liveHubBrand;

  /// No description provided for @liveGridAudio.
  ///
  /// In ar, this message translates to:
  /// **'صوتي'**
  String get liveGridAudio;

  /// No description provided for @liveGridVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get liveGridVideo;

  /// No description provided for @homeBannerSemantics.
  ///
  /// In ar, this message translates to:
  /// **'إعلان {index} من {count}'**
  String homeBannerSemantics(int index, int count);

  /// No description provided for @homeBannerTitledSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{title}، إعلان {index} من {count}'**
  String homeBannerTitledSemantics(String title, int index, int count);

  /// D127: the families list section above the activity cards.
  ///
  /// In ar, this message translates to:
  /// **'أنشطة العائلات'**
  String get familiesActivitiesTitle;

  /// D127: the activity card that opens the monthly prestige board (two lines).
  ///
  /// In ar, this message translates to:
  /// **'التصنيف الشهري\nهيبة العائلة'**
  String get familiesActivityMonthly;

  /// D127: a list row, members of capacity.
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء: {count}/{capacity}'**
  String familiesRowMembers(int count, int capacity);

  /// D127: a list row, before the points gained this calendar month.
  ///
  /// In ar, this message translates to:
  /// **'نقاط هذا الشهر:'**
  String get familiesMonthPointsLabel;

  /// D127: a list row, before the members active this week.
  ///
  /// In ar, this message translates to:
  /// **'نشطون هذا الأسبوع:'**
  String get familiesActiveLabel;

  /// D130: the Messages tab's badge, read by screen readers after the tab's name.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{رسالة واحدة غير مقروءة} =2{رسالتان غير مقروءتين} few{{count} رسائل غير مقروءة} many{{count} رسالة غير مقروءة} other{{count} رسالة غير مقروءة}}'**
  String navMessagesUnread(int count);

  /// D130: the Messages tab's badge above 99 (shown as 99+).
  ///
  /// In ar, this message translates to:
  /// **'أكثر من 99 رسالة غير مقروءة'**
  String get navMessagesUnreadMany;

  /// D130: the Moments tab's dot (unseen stories from followed accounts), read by screen readers.
  ///
  /// In ar, this message translates to:
  /// **'قصص جديدة'**
  String get navMomentsNew;

  /// D131: the Voice rooms screen title and the Live hub party button's name (it opens the voice rooms).
  ///
  /// In ar, this message translates to:
  /// **'الغرف الصوتية'**
  String get liveVoiceRoomsTitle;

  /// D131: the Live hub filter row, announced as a group.
  ///
  /// In ar, this message translates to:
  /// **'عوامل التصفية'**
  String get liveHubFilterLabel;

  /// D131: hub filter, lives from hosts in the person's own country (D133 scope=nearby).
  ///
  /// In ar, this message translates to:
  /// **'القريبة'**
  String get liveHubFilterNearby;

  /// D131: hub filter in popular order; its menu picks Following or a category.
  ///
  /// In ar, this message translates to:
  /// **'الرائج'**
  String get liveHubFilterPopular;

  /// D131: hub filter, hosts featured from admin (D133 featured=true).
  ///
  /// In ar, this message translates to:
  /// **'المميزة'**
  String get liveHubFilterFeatured;

  /// D131: hub filter, the newest lives (tab=new).
  ///
  /// In ar, this message translates to:
  /// **'استكشاف'**
  String get liveHubFilterExplore;

  /// D131: screen-reader hint of the selected Popular filter pill.
  ///
  /// In ar, this message translates to:
  /// **'يفتح قائمة: المتابَعون أو الفئات'**
  String get liveHubPopularMenuHint;

  /// D133: Nearby when the person has no country (COUNTRY_NOT_SET).
  ///
  /// In ar, this message translates to:
  /// **'حدّد بلدك لترى البثوث القريبة'**
  String get liveNearbyNoCountryTitle;

  /// D133: body of the no-country state.
  ///
  /// In ar, this message translates to:
  /// **'تعرض «القريبة» بثوث المضيفين من بلدك. بلدك لا يظهر في ملفك العام.'**
  String get liveNearbyNoCountryBody;

  /// D133: button opening the country list.
  ///
  /// In ar, this message translates to:
  /// **'حدّد بلدك'**
  String get liveNearbySetCountry;

  /// D133: secondary action on an empty Nearby list.
  ///
  /// In ar, this message translates to:
  /// **'تغيير البلد'**
  String get liveNearbyChangeCountry;

  /// D133: Nearby with a country but no rooms.
  ///
  /// In ar, this message translates to:
  /// **'لا بثوث من {country} الآن'**
  String liveNearbyEmptyTitle(String country);

  /// D133: body of an empty Nearby list.
  ///
  /// In ar, this message translates to:
  /// **'عد لاحقًا أو جرّب «الرائج».'**
  String get liveNearbyEmptyBody;

  /// D133: Featured with no rooms.
  ///
  /// In ar, this message translates to:
  /// **'لا بثوث مميزة الآن'**
  String get liveFeaturedEmptyTitle;

  /// D133: body of an empty Featured list.
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا بثوث المضيفين الذين يختارهم فريق Kabso Live.'**
  String get liveFeaturedEmptyBody;

  /// D131: Voice rooms top tab, rooms of followed hosts (tab=following).
  ///
  /// In ar, this message translates to:
  /// **'المتابَعون'**
  String get liveVoiceTabFollow;

  /// D131: Voice rooms top tab, popular order (tab=popular).
  ///
  /// In ar, this message translates to:
  /// **'الرائجة'**
  String get liveVoiceTabHot;

  /// D131: Voice rooms top tab, newest (tab=new).
  ///
  /// In ar, this message translates to:
  /// **'الجديدة'**
  String get liveVoiceTabNew;

  /// D131: Voice rooms second row, every voice room (the default).
  ///
  /// In ar, this message translates to:
  /// **'المقترحة'**
  String get liveVoiceRecommended;

  /// D131: Voice rooms section title above the list.
  ///
  /// In ar, this message translates to:
  /// **'الغرف'**
  String get liveVoiceSection;

  /// D131: switch to the list layout.
  ///
  /// In ar, this message translates to:
  /// **'عرض كقائمة'**
  String get liveVoiceListView;

  /// D131: switch to the grid layout.
  ///
  /// In ar, this message translates to:
  /// **'عرض كشبكة'**
  String get liveVoiceGridView;

  /// D131: a voice room row's seats taken over seats (CP-011).
  ///
  /// In ar, this message translates to:
  /// **'{taken}/{total}'**
  String liveVoiceSeats(int taken, int total);

  /// D131: an empty voice room list.
  ///
  /// In ar, this message translates to:
  /// **'لا غرف صوتية الآن'**
  String get liveVoiceEmptyTitle;

  /// D131: body of an empty voice room list.
  ///
  /// In ar, this message translates to:
  /// **'عد لاحقًا أو جرّب فئة أخرى.'**
  String get liveVoiceEmptyBody;

  /// D133: the country list sheet title.
  ///
  /// In ar, this message translates to:
  /// **'بلدك'**
  String get countryPickerTitle;

  /// D133: the country list sheet explanation.
  ///
  /// In ar, this message translates to:
  /// **'يحدّد بثوث «القريبة». لا يظهر في ملفك العام.'**
  String get countryPickerBody;

  /// D133: the country list search hint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن بلد'**
  String get countryPickerSearch;

  /// D133: clears the person's country.
  ///
  /// In ar, this message translates to:
  /// **'إزالة البلد'**
  String get countryPickerClear;

  /// D133: settings row for the person's own country.
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get settingsCountry;

  /// D133: settings row value without a country.
  ///
  /// In ar, this message translates to:
  /// **'غير محدّد'**
  String get settingsCountryNotSet;

  /// D131: the server refused the recipients (400 VALIDATION_FAILED, field recipients), e.g. a server without D128 refusing a host's gift to themself.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال الهدية إلى هذا المستلم هنا الآن.'**
  String get liveGiftRecipientRefused;

  /// D131: the leave prompt's question (ref 160), when the viewer can follow and does not.
  ///
  /// In ar, this message translates to:
  /// **'أعجبك البث؟ تابِع المضيف قبل أن تغادر'**
  String get liveLeaveTitle;

  /// D131: leave prompt primary: follow the host, then leave.
  ///
  /// In ar, this message translates to:
  /// **'تابِع واخرج'**
  String get liveLeaveFollow;

  /// D131: leave prompt secondary: leave without following.
  ///
  /// In ar, this message translates to:
  /// **'الخروج من البث'**
  String get liveLeaveExit;

  /// D131: screen-reader text of the host pill's points line (cherry).
  ///
  /// In ar, this message translates to:
  /// **'نقاط هذا البث {points}'**
  String liveHostPillPoints(String points);

  /// D131: screen-reader text of the host pill's taps line (heart).
  ///
  /// In ar, this message translates to:
  /// **'نقرات هذا البث {taps}'**
  String liveHostPillTaps(String taps);

  /// D131: the video live's chat pill hint (ref 158).
  ///
  /// In ar, this message translates to:
  /// **'قل مرحبًا…'**
  String get liveChatSayHi;

  /// D131: a quick reply sent as a chat message (ref 158).
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا 😊'**
  String get liveQuickHello;

  /// D131: a quick reply sent as a chat message.
  ///
  /// In ar, this message translates to:
  /// **'🔥🔥🔥'**
  String get liveQuickFire;

  /// D131: a quick reply sent as a chat message.
  ///
  /// In ar, this message translates to:
  /// **'أجواء جميلة~'**
  String get liveQuickNiceMood;

  /// D131: a quick reply sent as a chat message (no exclamation mark, T3).
  ///
  /// In ar, this message translates to:
  /// **'أسرتني'**
  String get liveQuickGotMe;

  /// D131: screen-reader label of a quick reply chip.
  ///
  /// In ar, this message translates to:
  /// **'إرسال: {text}'**
  String liveQuickReplyLabel(String text);

  /// Room tools: the camera flash (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'الفلاش'**
  String get liveToolFlash;

  /// Room tools: both cameras at once (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'كاميرتان'**
  String get liveToolDual;

  /// Room tools: high-definition video (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'جودة عالية'**
  String get liveToolHd;

  /// Room tools: stickers on the video (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'ملصقات'**
  String get liveToolSticker;

  /// Room tools: the live's info and topic.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات'**
  String get liveToolInfo;

  /// Room tools: a paid boost (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'بطاقة الزيارات'**
  String get liveToolTrafficCard;

  /// Beautification tools: face effects (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'مؤثرات'**
  String get liveToolMagic;

  /// Beautification tools: a screen light (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'إضاءة'**
  String get liveToolFillLight;

  /// Beautification tools: opens the voice settings.
  ///
  /// In ar, this message translates to:
  /// **'الصوت'**
  String get liveToolMixer;

  /// Title of the host's beautification sheet.
  ///
  /// In ar, this message translates to:
  /// **'أدوات التجميل'**
  String get liveBeautyToolsTitle;

  /// Host bar: invite viewers to join on a seat.
  ///
  /// In ar, this message translates to:
  /// **'اتصال الضيوف'**
  String get liveHostGuests;

  /// Host bar: guest connection in a SOLO live.
  ///
  /// In ar, this message translates to:
  /// **'يمكن للضيوف الانضمام في البث متعدد الضيوف. في البث الفردي ستتوفر لاحقاً.'**
  String get liveHostGuestsSoon;

  /// Host bar: opens the room tools.
  ///
  /// In ar, this message translates to:
  /// **'الأدوات'**
  String get liveHostTools;

  /// Title of the host's user management sheet.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المستخدمين'**
  String get liveManageTitle;

  /// User management: people muted in this live's chat.
  ///
  /// In ar, this message translates to:
  /// **'المكتومون في الدردشة'**
  String get liveManageMuted;

  /// User management: people removed from this live.
  ///
  /// In ar, this message translates to:
  /// **'المطرودون من البث'**
  String get liveManageKicked;

  /// User management: this live's moderators.
  ///
  /// In ar, this message translates to:
  /// **'المشرفون'**
  String get liveManageModerators;

  /// User management: how to add a moderator.
  ///
  /// In ar, this message translates to:
  /// **'افتح بطاقة الشخص لتعيينه مشرفاً.'**
  String get liveManageModeratorsHint;

  /// User management: switch that stops people without an account from watching.
  ///
  /// In ar, this message translates to:
  /// **'للمسجلين فقط'**
  String get liveManageSignedInOnly;

  /// User management: the switch's explanation.
  ///
  /// In ar, this message translates to:
  /// **'لا يستطيع من ليس لديه حساب المشاهدة.'**
  String get liveManageSignedInOnlyBody;

  /// User management: an empty list.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد بعد'**
  String get liveManageEmpty;

  /// User management: unmute someone in the chat.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get liveManageUnmute;

  /// User management: let a removed person come back.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالعودة'**
  String get liveManageLetBack;

  /// User management: remove a moderator.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get liveManageRemove;

  /// End-of-live summary: duration.
  ///
  /// In ar, this message translates to:
  /// **'مدة البث'**
  String get goLiveSummaryTime;

  /// End-of-live summary: this live's points (cherries).
  ///
  /// In ar, this message translates to:
  /// **'النقاط'**
  String get goLiveSummaryPoints;

  /// End-of-live summary: points from taps.
  ///
  /// In ar, this message translates to:
  /// **'من النقرات'**
  String get goLiveSummaryTaps;

  /// End-of-live summary: points from gifts.
  ///
  /// In ar, this message translates to:
  /// **'من الهدايا'**
  String get goLiveSummaryGifts;

  /// End-of-live summary: people who gave this live points.
  ///
  /// In ar, this message translates to:
  /// **'الداعمون'**
  String get goLiveSummarySupporters;

  /// End-of-live summary: the viewer count when the live ended.
  ///
  /// In ar, this message translates to:
  /// **'المشاهدون عند الانتهاء'**
  String get goLiveSummaryViewers;

  /// End-of-live summary: the host's charm level.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الجاذبية {level}'**
  String goLiveSummaryCharm(String level);

  /// End-of-live summary: points to the next charm level.
  ///
  /// In ar, this message translates to:
  /// **'{points} للمستوى التالي'**
  String goLiveSummaryCharmNext(String points);

  /// End-of-live summary: the section title.
  ///
  /// In ar, this message translates to:
  /// **'بيانات البث'**
  String get goLiveSummaryData;

  /// Gift panel tab: gifts sent recently from this phone.
  ///
  /// In ar, this message translates to:
  /// **'الأخيرة'**
  String get liveGiftTabRecent;

  /// Gift panel tab: lucky gifts (D132).
  ///
  /// In ar, this message translates to:
  /// **'الحظ'**
  String get liveGiftTabLucky;

  /// Gift panel, Recent tab empty.
  ///
  /// In ar, this message translates to:
  /// **'لا هدايا حديثة'**
  String get liveGiftRecentEmptyTitle;

  /// Gift panel, Recent tab empty.
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا الهدايا التي ترسلها من هذا الهاتف.'**
  String get liveGiftRecentEmptyMessage;

  /// Gift panel: sort the gifts by price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get liveGiftPriceSort;

  /// Gift panel: price sorting off (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'الترتيب حسب السعر'**
  String get liveGiftPriceSortOff;

  /// Gift panel: ascending price (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'السعر من الأقل إلى الأعلى'**
  String get liveGiftPriceSortUp;

  /// Gift panel: descending price (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'السعر من الأعلى إلى الأقل'**
  String get liveGiftPriceSortDown;

  /// Gift panel: the sender's SUPPORT level.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الثروة {level}'**
  String liveGiftWealthLevel(String level);

  /// Gift panel: wealth points to the next level.
  ///
  /// In ar, this message translates to:
  /// **'{points} للمستوى التالي'**
  String liveGiftWealthToNext(String points);

  /// Gift panel, Lucky tab: opens the published odds.
  ///
  /// In ar, this message translates to:
  /// **'احتمالات الربح'**
  String get liveLuckyOdds;

  /// Title of the odds sheet.
  ///
  /// In ar, this message translates to:
  /// **'احتمالات الربح في هدايا الحظ'**
  String get liveLuckyOddsTitle;

  /// Odds sheet: how a draw works.
  ///
  /// In ar, this message translates to:
  /// **'كل هدية ترسلها سحبة واحدة. الربح يساوي المضاعف مضروباً في سعر الهدية بالعملات.'**
  String get liveLuckyOddsIntro;

  /// Odds sheet: one multiplier.
  ///
  /// In ar, this message translates to:
  /// **'×{multiplier}'**
  String liveLuckyOddsRow(String multiplier);

  /// Odds sheet: the chance of no win.
  ///
  /// In ar, this message translates to:
  /// **'بلا ربح'**
  String get liveLuckyOddsNoWin;

  /// Odds sheet: the return percentage.
  ///
  /// In ar, this message translates to:
  /// **'العائد المتوقع: {percent} من العملات المنفقة'**
  String liveLuckyOddsReturn(String percent);

  /// Odds sheet: the host share.
  ///
  /// In ar, this message translates to:
  /// **'يُحتسب {percent} من قيمة الهدية للمضيف.'**
  String liveLuckyOddsHostShare(String percent);

  /// Odds sheet: the daily protection.
  ///
  /// In ar, this message translates to:
  /// **'لا تتجاوز أرباح اليوم العائد المتوقع من هدايا الحظ في ذلك اليوم؛ والربح الذي يتجاوزه يُدفع أقل أو لا يُدفع.'**
  String get liveLuckyOddsProtection;

  /// Odds sheet: the age limit.
  ///
  /// In ar, this message translates to:
  /// **'لمن هم في سن 18 عاماً أو أكثر فقط.'**
  String get liveLuckyOddsAge;

  /// 18+ confirmation dialog title.
  ///
  /// In ar, this message translates to:
  /// **'هل عمرك 18 عاماً أو أكثر؟'**
  String get liveLuckyAgeTitle;

  /// 18+ confirmation dialog body.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الحظ لعبة حظ تُلعب بالعملات. أكّد أن عمرك 18 عاماً أو أكثر لإرسالها.'**
  String get liveLuckyAgeBody;

  /// 18+ confirmation button.
  ///
  /// In ar, this message translates to:
  /// **'عمري 18 عاماً أو أكثر'**
  String get liveLuckyAgeConfirm;

  /// Lucky tab: region unavailable.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الحظ غير متاحة في بلدك.'**
  String get liveLuckyRegion;

  /// Lucky tab: disabled.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الحظ متوقفة حالياً.'**
  String get liveLuckyOff;

  /// Lucky send result.
  ///
  /// In ar, this message translates to:
  /// **'ربحت {coins} عملة، وأعلى مضاعف ×{multiplier}'**
  String liveLuckyWon(String coins, String multiplier);

  /// Lucky send result: nothing won.
  ///
  /// In ar, this message translates to:
  /// **'لا ربح هذه المرة'**
  String get liveLuckyNoWin;

  /// Room banner for a big lucky win.
  ///
  /// In ar, this message translates to:
  /// **'{name} ربح ×{multiplier}: {coins} عملة'**
  String liveLuckyBanner(String name, String multiplier, String coins);

  /// Error LUCKY_GIFT_AGE_UNCONFIRMED.
  ///
  /// In ar, this message translates to:
  /// **'أكّد أن عمرك 18 عاماً أو أكثر لإرسال هدايا الحظ.'**
  String get errorLuckyGiftAgeUnconfirmed;

  /// Error LUCKY_GIFT_REGION_UNAVAILABLE.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الحظ غير متاحة في بلدك.'**
  String get errorLuckyGiftRegionUnavailable;

  /// Live composer: show the emoji panel.
  ///
  /// In ar, this message translates to:
  /// **'الرموز التعبيرية'**
  String get liveEmojiPanel;

  /// Live composer: show the keyboard instead of the emoji panel.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المفاتيح'**
  String get liveEmojiKeyboard;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الوجوه'**
  String get liveEmojiSmileys;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الأيدي والأشخاص'**
  String get liveEmojiPeople;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الحب'**
  String get liveEmojiLove;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الحيوانات والطبيعة'**
  String get liveEmojiAnimals;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الطعام والشراب'**
  String get liveEmojiFood;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الأنشطة'**
  String get liveEmojiActivities;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'السفر والأماكن'**
  String get liveEmojiTravel;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الأشياء'**
  String get liveEmojiObjects;

  /// Emoji group.
  ///
  /// In ar, this message translates to:
  /// **'الرموز'**
  String get liveEmojiSymbols;

  /// Go-live setup: show the second row of tools.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get goLiveToolsMore;

  /// Go-live setup: fold the second row of tools.
  ///
  /// In ar, this message translates to:
  /// **'أقل'**
  String get goLiveToolsLess;

  /// Go-live setup: open every live category.
  ///
  /// In ar, this message translates to:
  /// **'كل المواضيع'**
  String get goLiveCategoriesAll;

  /// D135: the person card's Mention action (puts @username into the live chat box).
  ///
  /// In ar, this message translates to:
  /// **'منشن'**
  String get liveUserMention;

  /// D135: a host quick reply on their own live (sent as a chat message).
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بكم في البث 👋'**
  String get liveQuickHostWelcome;

  /// D135: a host quick reply on their own live (sent as a chat message).
  ///
  /// In ar, this message translates to:
  /// **'شكراً على الدعم 🌹'**
  String get liveQuickHostThanks;

  /// D135: a host quick reply on their own live (sent as a chat message).
  ///
  /// In ar, this message translates to:
  /// **'تابعوني ❤️'**
  String get liveQuickHostFollow;

  /// D135: a host quick reply on their own live (sent as a chat message).
  ///
  /// In ar, this message translates to:
  /// **'شاركوا البث 🔥'**
  String get liveQuickHostShare;

  /// D135: the room ID beside the host's name (copy).
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ معرّف الغرفة'**
  String get liveRoomIdCopied;

  /// D135: the room ID beside the host's name (copy).
  ///
  /// In ar, this message translates to:
  /// **'انقر للنسخ'**
  String get liveRoomIdCopyHint;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الأمنيات'**
  String get liveWishTitle;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'اختر حتى ٤ هدايا تتمنّاها، يراها المشاهدون في البث.'**
  String get liveWishHint;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get liveWishSave;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'٤ هدايا كحد أقصى'**
  String get liveWishFull;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name}'**
  String liveWishRemove(String name);

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'تقديم {name}'**
  String liveWishMoveEarlier(String name);

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'{name}، استلمت {count}'**
  String liveWishRowLabel(String name, String count);

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'قائمة أمنيات المضيف'**
  String get liveWishCardLabel;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'تعديل قائمة الأمنيات'**
  String get liveWishEditLabel;

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'الأمنيات'**
  String get liveToolWish;
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
