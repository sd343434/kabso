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
  /// **'البريد أو اسم المستخدم أو ايدي الموظف'**
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
  /// **'استخدم 6 أحرف على الأقل'**
  String get usernameTooShort;

  /// No description provided for @usernameTooLong.
  ///
  /// In ar, this message translates to:
  /// **'استخدم 30 حرفًا أو أقل'**
  String get usernameTooLong;

  /// No description provided for @usernameBadChars.
  ///
  /// In ar, this message translates to:
  /// **'استخدم فقط a–z و0–9 والشرطة السفلية (_)'**
  String get usernameBadChars;

  /// No description provided for @usernameBadEdges.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن أن يبدأ أو ينتهي بشرطة سفلية'**
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

  /// D156: the button that skips the launch video.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get splashSkip;

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

  /// D145d: Settings switch for the app's sound effects (the MAX X taps and wins).
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات الصوتية'**
  String get settingsSoundEffects;

  /// D145d: the sound effects switch's subtitle.
  ///
  /// In ar, this message translates to:
  /// **'ماكس والهدايا المحظوظة والإشعارات'**
  String get settingsSoundEffectsHint;

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

  /// D226: the one Settings switch, light ↔ dark.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get settingsDarkMode;

  /// D226: the dark mode switch's subtitle while the app still follows the device (no explicit choice yet).
  ///
  /// In ar, this message translates to:
  /// **'يتبع إعداد الجهاز'**
  String get settingsThemeFollowsDevice;

  /// D226: the small link that drops the explicit choice and follows the device again.
  ///
  /// In ar, this message translates to:
  /// **'اتباع الجهاز'**
  String get settingsThemeFollowDevice;

  /// D226: the language switch's title with the current language (its own name, isolated).
  ///
  /// In ar, this message translates to:
  /// **'اللغة: {language}'**
  String settingsLanguageCurrent(String language);

  /// D226: the language switch's subtitle, the other language (its own name, isolated).
  ///
  /// In ar, this message translates to:
  /// **'التبديل إلى {language}'**
  String settingsLanguageSwitchTo(String language);

  /// D226: the row under the two most recent sessions that opens the full list; count = all active sessions.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل ({count})'**
  String sessionsShowAll(int count);

  /// D226: the red text button under the sessions (only while another session exists).
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج من كل الأجهزة الأخرى'**
  String get sessionsRevokeOthers;

  /// No description provided for @sessionsRevokeOthersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج من كل الأجهزة الأخرى؟'**
  String get sessionsRevokeOthersTitle;

  /// D226: the confirm dialog; n = the other sessions in the list.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{سيتم تسجيل الخروج من جهاز آخر على الفور.} =2{سيتم تسجيل الخروج من جهازين آخرين على الفور.} few{سيتم تسجيل الخروج من {n} أجهزة أخرى على الفور.} many{سيتم تسجيل الخروج من {n} جهازًا آخر على الفور.} other{سيتم تسجيل الخروج من {n} جهاز آخر على الفور.}}'**
  String sessionsRevokeOthersBody(int n);

  /// No description provided for @sessionsRevokeOthersPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور للتأكيد.'**
  String get sessionsRevokeOthersPasswordHint;

  /// No description provided for @sessionsRevokeOthersConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get sessionsRevokeOthersConfirm;

  /// D226: the snackbar after revokeOtherSessions; n = revoked.
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =0{لا توجد أجهزة أخرى مسجَّلة الدخول} =1{تم تسجيل الخروج من جهاز آخر} =2{تم تسجيل الخروج من جهازين آخرين} few{تم تسجيل الخروج من {n} أجهزة أخرى} many{تم تسجيل الخروج من {n} جهازًا آخر} other{تم تسجيل الخروج من {n} جهاز آخر}}'**
  String sessionsRevokedOthers(int n);

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
  /// **'أرسل {name} {gift} ⁦×{count}⁩'**
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

  /// D221: the red status pill on the interruption card of a live that ended.
  ///
  /// In ar, this message translates to:
  /// **'انتهى البث'**
  String get liveStatusEnded;

  /// D221: the status pill while the live reconnects.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال'**
  String get liveStatusConnectionLost;

  /// D221: the status pill while the host is away.
  ///
  /// In ar, this message translates to:
  /// **'المضيف بعيد'**
  String get liveStatusHostAway;

  /// D221: the status pill when the live's video could not connect or the room failed to open.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال'**
  String get liveStatusCantConnect;

  /// D221: the status pill when the viewer is offline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get liveStatusOffline;

  /// D221: the status pill when the live (or its video) is not available.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get liveStatusUnavailable;

  /// D221: the status pill when the viewer was removed from the live.
  ///
  /// In ar, this message translates to:
  /// **'تمت إزالتك'**
  String get liveStatusRemoved;

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

  /// D170: the video live ended because the host was away (app in the background, camera off) for 5 minutes.
  ///
  /// In ar, this message translates to:
  /// **'انتهى البث لأن المضيف غاب أكثر من 5 دقائق.'**
  String get liveRoomEndedHostAway;

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

  /// D216: under «Reconnecting…» on the interruption card.
  ///
  /// In ar, this message translates to:
  /// **'لحظات ويعود البث من حيث توقف.'**
  String get liveRoomReconnectingBody;

  /// D216: title of the card when the live's video could not connect (the reason follows).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل البث'**
  String get liveRoomJoinFailedTitle;

  /// D216: under «The host will be right back» on the interruption card.
  ///
  /// In ar, this message translates to:
  /// **'ابقَ هنا، سيُستأنف البث فور عودته.'**
  String get liveHostAwayBody;

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

  /// D278: the own profile's button over the cover (owner: «تعديل الملف»).
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف'**
  String get profileEditShort;

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
  /// **'منشوراته وريلزه وقصصه يراها متابعوه فقط.'**
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

  /// D335: the chevron beside «مراسلة» / «تعديل الملف» that opens the family, couple and medals tiles.
  ///
  /// In ar, this message translates to:
  /// **'إظهار العائلة والعلاقة والميداليات'**
  String get profileBondsShow;

  /// D335: the same chevron while the tiles are open (closes them).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء العائلة والعلاقة والميداليات'**
  String get profileBondsHide;

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
  /// **'المستويات قيد التجهيز. ستظهر نقاطك هنا عند تفعيل الهدايا والألعاب.'**
  String get levelsPreparing;

  /// D361 (§10.156; owner: «المؤسس ليس له ليفيل»): the founder's own levels page — the neutral state instead of his levels.
  ///
  /// In ar, this message translates to:
  /// **'المؤسس ليس له مستوى'**
  String get levelsFounderTitle;

  /// D361 (§10.156): the line under «المؤسس ليس له مستوى».
  ///
  /// In ar, this message translates to:
  /// **'حساب مؤسس Kabso Live لا يحمل مستوى، ولا يظهر له مستوى في أي مكان: الملف الشخصي والبث والدردشة والقوائم.'**
  String get levelsFounderBody;

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

  /// D72: levels (CP-005).
  ///
  /// In ar, this message translates to:
  /// **'أعلى مستوى'**
  String get levelsMax;

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

  /// D169: the big level on the level card; Latin in both languages, like the level badges.
  ///
  /// In ar, this message translates to:
  /// **'Lv.{number}'**
  String levelsLv(int number);

  /// D169: under the level card's progress bar; {points} is shown highlighted, pre-formatted with Latin digits and separators.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج {points} خبرة للوصول إلى المستوى التالي'**
  String levelsNeedXp(String points);

  /// D169: screen-reader label of the category filter above the level card.
  ///
  /// In ar, this message translates to:
  /// **'تصنيفات المستوى'**
  String get levelsCategories;

  /// D169: heading over the category's explanation on its page.
  ///
  /// In ar, this message translates to:
  /// **'كيف يرتفع'**
  String get levelsHowItGrows;

  /// D169: heading over every badge tier of a category with its levels.
  ///
  /// In ar, this message translates to:
  /// **'الشارات والمستويات'**
  String get levelsTiers;

  /// D169: the levels one badge tier covers; Latin, left to right in both languages.
  ///
  /// In ar, this message translates to:
  /// **'Lv.{from}–{to}'**
  String levelsTierRange(int from, int to);

  /// D169: screen-reader note on a support tier tile — reaching the tier gives its avatar frame.
  ///
  /// In ar, this message translates to:
  /// **'مع إطار الصورة'**
  String get levelsTierFrame;

  /// D169: the pill of the caller's current tier card.
  ///
  /// In ar, this message translates to:
  /// **'الحالي'**
  String get levelsTierCurrent;

  /// D169: the pill of a tier the caller has passed.
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get levelsTierOpen;

  /// D169: the pill (with a lock) of a tier not reached yet, or of an inactive category.
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get levelsTierLocked;

  /// D169: the grey line of a tier the caller has reached.
  ///
  /// In ar, this message translates to:
  /// **'تم الفتح'**
  String get levelsTierUnlocked;

  /// D169: the grey line of a locked tier; {points} is stressed, pre-formatted with Latin digits.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج {points} نقطة للفتح'**
  String levelsTierToUnlock(String points);

  /// D169: a tier card's caption — the points the tier starts at.
  ///
  /// In ar, this message translates to:
  /// **'من {points} نقطة'**
  String levelsTierFrom(String points);

  /// D169: the short name in the levels tab bar (no «مستوى», so the four fit side by side).
  ///
  /// In ar, this message translates to:
  /// **'الجاذبية'**
  String get levelsTabAttractiveness;

  /// D169: the short name in the levels tab bar (no «مستوى», so the four fit side by side).
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get levelsTabSupport;

  /// D169: the short name in the levels tab bar (no «مستوى», so the four fit side by side).
  ///
  /// In ar, this message translates to:
  /// **'الساحر'**
  String get levelsTabWizard;

  /// D169: the short name in the levels tab bar (no «مستوى», so the four fit side by side).
  ///
  /// In ar, this message translates to:
  /// **'اللعب'**
  String get levelsTabGaming;

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

  /// D364 comments sheet order menu: the pinned comment, then by likes, then newest (listComments sort=RELEVANT, the default).
  ///
  /// In ar, this message translates to:
  /// **'الأكثر صلة'**
  String get commentsSortRelevant;

  /// D364 comments sheet order menu: the pinned comment, then newest first (listComments sort=NEWEST).
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get commentsSortNewest;

  /// D364 tooltip / screen-reader name of the comments order menu button.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب التعليقات'**
  String get commentsSortMenu;

  /// D364 screen-reader name of a comment's dislike button (private: no count is shown).
  ///
  /// In ar, this message translates to:
  /// **'عدم إعجاب'**
  String get commentsDislike;

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

  /// D375 story viewer: a person in the people carousel at the bottom (accessibility; a tap opens their stories)
  ///
  /// In ar, this message translates to:
  /// **'قصص {name}'**
  String storyPeopleOf(String name);

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
  /// **'Kabso: أنت في بث مباشر'**
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
  /// **'أنا مباشر الآن على Kabso Live: «{title}» — تابعني {handle}'**
  String goLiveShareText(String title, String handle);

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

  /// D230: the pill over the live chat while scrolled up to older messages and new ones arrived; a tap jumps back to the newest.
  ///
  /// In ar, this message translates to:
  /// **'رسائل جديدة ↓'**
  String get liveChatNewMessages;

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

  /// D234: screen reader label of the medals row (up to 5 showcased medals) under a live chat author's badges.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ميدالية واحدة} =2{ميداليتان} few{{count} ميداليات} other{{count} ميدالية}}'**
  String liveChatMedalsLabel(int count);

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

  /// D201 live tools: a generic failure.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر ذلك الآن. حاول مرة أخرى.'**
  String get liveToolsFailed;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get liveToolsCancel;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get liveToolsClose;

  /// D201: the go-live setup tile that opens «الانضمام ككاميرا ثانية» (short).
  ///
  /// In ar, this message translates to:
  /// **'كاميرا ثانية'**
  String get liveCam2JoinTile;

  /// D201 live tools: entry on the go-live screen and the screen title (device B).
  ///
  /// In ar, this message translates to:
  /// **'الانضمام ككاميرا ثانية'**
  String get liveSecondCameraJoin;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'بُثّ من جهازين: هذا الهاتف، وكاميرا ثانية على هاتف أو جهاز لوحي آخر بالحساب نفسه.'**
  String get liveCam2Intro;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'على الجهاز الثاني: سجّل الدخول بالحساب نفسه، افتح «بث مباشر» ثم «الانضمام ككاميرا ثانية»، وأدخل الرمز.'**
  String get liveCam2Steps;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'يرى المشاهدون صورة كبيرة وصورة صغيرة يمكن سحبها، ويبدّلون بينهما بلمسة.'**
  String get liveCam2Layout;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رمز الاقتران'**
  String get liveCam2CreateCode;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'رمز الاقتران'**
  String get liveCam2CodeLabel;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'ينتهي خلال {time}'**
  String liveCam2CodeExpires(String time);

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'يُستخدم مرة واحدة، وبحسابك فقط.'**
  String get liveCam2CodeOnce;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الرمز. أنشئ رمزاً جديداً.'**
  String get liveCam2CodeExpired;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'رمز جديد'**
  String get liveCam2NewCode;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرمز'**
  String get liveCam2Cancel;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'في انتظار اتصال الجهاز الثاني…'**
  String get liveCam2Waiting;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا الثانية متصلة'**
  String get liveCam2Connected;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الصورة الكبيرة للمشاهدين'**
  String get liveCam2MainLabel;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'هذا الهاتف'**
  String get liveCam2MainHost;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا الثانية'**
  String get liveCam2MainSecond;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'يستطيع كل مشاهد التبديل بين الصورتين على شاشته.'**
  String get liveCam2MainNote;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'فصل الكاميرا الثانية'**
  String get liveCam2End;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البث أولاً، ثم وصّل جهازك الثاني.'**
  String get liveCam2NotLive;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا الثانية غير متاحة أثناء PK. وصّلها من جديد بعد انتهاء PK.'**
  String get liveCam2InPk;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا الثانية متاحة في البث الفردي بالفيديو فقط.'**
  String get liveCam2NotSolo;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'لهذا البث كاميرا ثانية بالفعل.'**
  String get liveCam2Busy;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إضافة كاميرا ثانية لهذا البث الآن: انتهى البث أو هو في PK.'**
  String get liveCam2Unavailable;

  /// D201 live tools: screen reader label of the small picture.
  ///
  /// In ar, this message translates to:
  /// **'تبديل الكاميرتين'**
  String get liveCam2Swap;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول بالحساب نفسه الذي تبثّ منه، ثم أدخل الرمز الظاهر في «كاميرتان» على جهازك الرئيسي.'**
  String get liveCam2JoinIntro;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'سيطلب Kabso Live إذن الكاميرا والميكروفون. يبدأ الميكروفون مكتوماً، ولا تظهر الدردشة على هذا الجهاز.'**
  String get liveCam2JoinPermissions;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'انضمام'**
  String get liveCam2JoinButton;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو انتهت صلاحيته. أنشئ رمزاً جديداً على جهازك الرئيسي.'**
  String get liveCam2CodeInvalid;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.'**
  String get liveCam2TooMany;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال. حاول مرة أخرى.'**
  String get liveCam2Failed;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'اسمح لتطبيق Kabso Live باستخدام الكاميرا والميكروفون من إعدادات الجهاز.'**
  String get liveCam2PermissionDenied;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'كاميرا ثانية · مباشر'**
  String get liveCam2OnAir;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الاتصال…'**
  String get liveCam2Connecting;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'قلب'**
  String get liveCam2Flip;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الصوت'**
  String get liveCam2MicOn;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get liveCam2MicOff;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get liveCam2Leave;

  /// D243 second camera device: the screen stays on; leaving the app pauses the camera.
  ///
  /// In ar, this message translates to:
  /// **'أبقِ هذه الشاشة مفتوحة، فهي تبقى مضاءة أثناء البث. إذا خرجت من التطبيق تتوقف هذه الكاميرا مؤقتاً حتى تعود.'**
  String get liveCam2KeepOpen;

  /// D251 second camera: copies a state log (no personal data) to share with support.
  ///
  /// In ar, this message translates to:
  /// **'نسخ سجل التشخيص'**
  String get liveCam2CopyLog;

  /// D251 second camera: after copying the log.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ سجل التشخيص. الصقه في رسالة للدعم.'**
  String get liveCam2LogCopied;

  /// D251 second camera: keep-screen-on failed or did not answer.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إبقاء الشاشة مضاءة تلقائياً. المس الشاشة من حين لآخر كي لا تنطفئ.'**
  String get liveCam2AwakeFailed;

  /// D251 second camera: the live foreground service failed or did not answer.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل خدمة البث في الخلفية. أبقِ التطبيق مفتوحاً على هذه الشاشة.'**
  String get liveCam2BackgroundFailed;

  /// D251 second camera: a camera call failed or did not answer in time.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا لا تستجيب الآن. إن بقيت الصورة متوقفة فاضغط «قلب» أو غادر وانضم من جديد.'**
  String get liveCam2CameraSlow;

  /// D251 second camera: the camera effects pipeline failed or did not answer.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تطبيق الفلتر على هذا الجهاز، فبقيت الصورة بدون فلتر.'**
  String get liveCam2FilterFailed;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'انتهت الكاميرا الثانية: انتهى البث أو فُصلت من الجهاز الرئيسي.'**
  String get liveCam2Ended;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'حقوق الموسيقى'**
  String get liveMusicRightsTitle;

  /// D201 live tools: the one-time notice (owner text, exact).
  ///
  /// In ar, this message translates to:
  /// **'تأكد أنك تملك حقوق تشغيل الموسيقى. يُمنع تشغيل موسيقى محمية بحقوق النشر بدون ترخيص.'**
  String get liveMusicRightsBody;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'أؤكد ذلك'**
  String get liveMusicRightsAccept;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملفات صوتية'**
  String get liveMusicAdd;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'يفتح منتقي الملفات في جهازك؛ لا يرى Kabso Live إلا الملفات التي تختارها، ولا تُرفع إلى الخادم.'**
  String get liveMusicPickerNote;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تُمزج الموسيقى تحت صوتك في بثك، وتنخفض حين تتكلم. لا تسمعها أنت من سماعة هاتفك، وكتم الميكروفون يكتمها أيضاً.'**
  String get liveMusicMixNote;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'لا توجد موسيقى بعد. لن يُشغَّل شيء حتى تختار ملفاً وتضغط تشغيل.'**
  String get liveMusicEmpty;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'لا شيء يُشغَّل'**
  String get liveMusicNothing;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get liveMusicPlay;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get liveMusicPause;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get liveMusicNext;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get liveMusicRemove;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'مستوى الموسيقى'**
  String get liveMusicVolume;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'خفض الموسيقى حين أتكلم'**
  String get liveMusicDucking;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'القائمة ممتلئة (حتى {max} ملفاً).'**
  String liveMusicQueueFull(int max);

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل هذا الملف.'**
  String get liveMusicUnreadable;

  /// D232: the mixer has no live microphone yet (the file is fine)
  ///
  /// In ar, this message translates to:
  /// **'الموسيقى تُمزج في ميكروفون البث: افتح الميكروفون وانتظر بدء البث ثم شغّلها.'**
  String get liveMusicNotReady;

  /// D232: no decoder for this file's format on the phone
  ///
  /// In ar, this message translates to:
  /// **'هاتفك لا يدعم صيغة هذا الملف. جرّب ملف MP3 أو M4A.'**
  String get liveMusicUnsupportedFormat;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون مكتوم: لن يسمع المشاهدون الموسيقى.'**
  String get liveMusicMicOff;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الموسيقى غير متاحة على iOS في هذا الإصدار: مزج الملف داخل ميكروفون البث يحتاج وحدة صوت خاصة بـ iOS لم تُبنَ بعد.'**
  String get liveMusicUnsupportedIos;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'الموسيقى غير متاحة في نسخة الويب. استخدم تطبيق أندرويد.'**
  String get liveMusicUnsupportedWeb;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تسجيل مقطع'**
  String get liveClipTitle;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'سجّل حتى ٦٠ ثانية من بثك كما يراه المشاهدون: كاميرتك وصوتك. يمكنك الإيقاف قبل ذلك.'**
  String get liveClipIntro;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'يرى المشاهدون «يتم التسجيل» أثناء التسجيل.'**
  String get liveClipTransparency;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'لا يتضمّن المقطع الكاميرا الثانية ولا الموسيقى ولا التعليقات والهدايا على الشاشة.'**
  String get liveClipLimits;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التسجيل'**
  String get liveClipStart;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'إيقاف التسجيل'**
  String get liveClipStop;

  /// D201 live tools: the recording badge.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل'**
  String get liveClipRec;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'يتم التسجيل، بقي {seconds} ثانية'**
  String liveClipRecSemantics(int seconds);

  /// D201 live tools: what viewers see while the host records.
  ///
  /// In ar, this message translates to:
  /// **'يتم التسجيل'**
  String get liveClipViewerBadge;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'مقطعك'**
  String get liveClipPreviewTitle;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'وصف (اختياري)'**
  String get liveClipCaption;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'حفظ في الجهاز'**
  String get liveClipSave;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'محفوظ'**
  String get liveClipSavedShort;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'حُفظ المقطع في معرض الصور.'**
  String get liveClipSaved;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ. اسمح لتطبيق Kabso Live بإضافة الصور والفيديو من الإعدادات.'**
  String get liveClipSaveFailed;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'نشر كريلز'**
  String get liveClipPostReel;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تعذّر النشر. المقطع باقٍ، حاول مجدداً.'**
  String get liveClipPostFailed;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get liveClipDiscard;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء التسجيل على هذا الجهاز.'**
  String get liveClipFailed;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'المقطع أقصر من ثانية؛ سجّل مقطعاً أطول.'**
  String get liveClipTooShort;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة المقطع.'**
  String get liveClipUnreadable;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تسجيل المقاطع غير متاح على iOS في هذا الإصدار: مسجّل WebRTC هناك لا يلتقط صوت البث.'**
  String get liveClipUnsupportedIos;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'تسجيل المقاطع غير متاح في نسخة الويب.'**
  String get liveClipUnsupportedWeb;

  /// D201 live tools
  ///
  /// In ar, this message translates to:
  /// **'شغّل الكاميرا لتسجيل مقطع.'**
  String get liveClipNoCamera;

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

  /// INSUFFICIENT_COINS (409, CP-017): a bullet costs 10,000 coins (D371, liveBulletCostCoins, grouped like KFormat.grouped); no purchase flow exists yet.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج 10,000 عملة لإرسال رسالة عامة. يضيف الفريق العملات حالياً، ولا يوجد شراء بعد.'**
  String get errorInsufficientCoins;

  /// Live chat tool: bullet mode on/off (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة'**
  String get liveBulletToggle;

  /// Chat field hint while bullet mode is on, with the price (D371: 10,000 coins, KFormat.grouped(liveBulletCostCoins)) and the coin balance (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة بـ {price} عملة · رصيدك {coins}'**
  String liveBulletHint(String price, String coins);

  /// Chat field hint in bullet mode before the balance is known, with the price (D371: KFormat.grouped(liveBulletCostCoins)) (CP-017).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة بـ {price} عملة'**
  String liveBulletHintNoBalance(String price);

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
  /// **'إزالة'**
  String get bagTakeOff;

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
  /// **'كابسو لايف'**
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

  /// D237: the Live hub's first filter tab — lives of the people you follow.
  ///
  /// In ar, this message translates to:
  /// **'المتابَعين'**
  String get liveHubFilterFollowing;

  /// D246: the party page's first big tab (owner: «متابعة»), lives of the people you follow (tab=following).
  ///
  /// In ar, this message translates to:
  /// **'المتابَعة'**
  String get livePartyTabFollowing;

  /// D246: the party card's grey pill for a live in the top of its kind in the popular order (LiveRoomSummary.popular).
  ///
  /// In ar, this message translates to:
  /// **'رائج'**
  String get liveCardPopular;

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

  /// D259: screen-reader text of the host pill's cherries line — the real cherries the host earned in this live.
  ///
  /// In ar, this message translates to:
  /// **'كرز هذا البث {cherries}'**
  String liveHostPillCherries(String cherries);

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

  /// Room tools: both cameras at once (not available yet).
  ///
  /// In ar, this message translates to:
  /// **'كاميرتان'**
  String get liveToolDual;

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
  /// **'صواريخ الزيارات'**
  String get liveToolTrafficCard;

  /// Beautification tools: Magic — the colour filters (D143).
  ///
  /// In ar, this message translates to:
  /// **'الفلاتر'**
  String get liveToolMagic;

  /// Fill light (D143/D157): a soft light on the picture with the front camera, the torch with the back camera.
  ///
  /// In ar, this message translates to:
  /// **'إضاءة'**
  String get liveToolFillLight;

  /// Fill light: the back camera has no torch, so the light stays off.
  ///
  /// In ar, this message translates to:
  /// **'هذه الكاميرا بلا كشاف.'**
  String get liveFillLightNoTorch;

  /// Fill light sheet (D157): its title.
  ///
  /// In ar, this message translates to:
  /// **'الإضاءة'**
  String get liveFillLightTitle;

  /// Fill light level: off.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get liveFillLightOff;

  /// Fill light level: low.
  ///
  /// In ar, this message translates to:
  /// **'خفيفة'**
  String get liveFillLightLow;

  /// Fill light level: medium.
  ///
  /// In ar, this message translates to:
  /// **'متوسطة'**
  String get liveFillLightMedium;

  /// Fill light level: high.
  ///
  /// In ar, this message translates to:
  /// **'قوية'**
  String get liveFillLightHigh;

  /// Fill light (D157): the light is on the published picture.
  ///
  /// In ar, this message translates to:
  /// **'تُفتّح الإضاءة الصورة نفسها بلطف، فيراها مشاهدوك كما تراها.'**
  String get liveFillLightOnPicture;

  /// Fill light (D157): no camera pipeline on this device, so only a thin glow on the screen lights the face.
  ///
  /// In ar, this message translates to:
  /// **'على هذا الجهاز تضيء الشاشة وجهك بتوهّج خفيف عند الحواف؛ صورة البث لا تتغير.'**
  String get liveFillLightScreenOnly;

  /// Magic: title of the colour-filter picker.
  ///
  /// In ar, this message translates to:
  /// **'فلاتر الألوان'**
  String get liveFilterTitle;

  /// Magic: why the filters are greyed on a device without a camera pipeline.
  ///
  /// In ar, this message translates to:
  /// **'فلاتر الألوان غير متاحة على هذا الجهاز بعد، فيجب أن يراها مشاهدوك لا شاشتك وحدها.'**
  String get liveFilterUnsupported;

  /// Colour filter: none.
  ///
  /// In ar, this message translates to:
  /// **'طبيعي'**
  String get liveFilterNatural;

  /// Colour filter: warmer tones.
  ///
  /// In ar, this message translates to:
  /// **'دافئ'**
  String get liveFilterWarm;

  /// Colour filter: cooler tones.
  ///
  /// In ar, this message translates to:
  /// **'بارد'**
  String get liveFilterCool;

  /// Colour filter: black and white.
  ///
  /// In ar, this message translates to:
  /// **'أبيض وأسود'**
  String get liveFilterMono;

  /// Colour filter: muted film look.
  ///
  /// In ar, this message translates to:
  /// **'سينمائي'**
  String get liveFilterCinematic;

  /// Colour filter: stronger colour.
  ///
  /// In ar, this message translates to:
  /// **'زاهٍ'**
  String get liveFilterVivid;

  /// Colour filter: low contrast.
  ///
  /// In ar, this message translates to:
  /// **'ناعم'**
  String get liveFilterSoft;

  /// D144 Magic: the AR effects section (DeepAR), marked beta.
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات (تجريبي)'**
  String get liveEffectsTitle;

  /// D144 Magic: no AR effect.
  ///
  /// In ar, this message translates to:
  /// **'بلا'**
  String get liveEffectNone;

  /// D144 Magic: DeepAR's background blur effect.
  ///
  /// In ar, this message translates to:
  /// **'تمويه الخلفية'**
  String get liveEffectBackgroundBlur;

  /// D144 Magic: why effects are greyed (no DeepAR licence in this build).
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات غير متاحة في هذا الإصدار بعد.'**
  String get liveEffectsUnavailable;

  /// User management: opens the viewers to make one a moderator.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مشرف'**
  String get liveManageAddModerator;

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
  /// **'⁦×{multiplier}⁩'**
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
  /// **'ربحت {coins} عملة، وأعلى مضاعف ⁦×{multiplier}⁩'**
  String liveLuckyWon(String coins, String multiplier);

  /// Lucky send result: nothing won.
  ///
  /// In ar, this message translates to:
  /// **'لا ربح هذه المرة'**
  String get liveLuckyNoWin;

  /// Room banner for a big lucky win.
  ///
  /// In ar, this message translates to:
  /// **'{name} ربح ⁦×{multiplier}⁩: {coins} عملة'**
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

  /// D136/D137: the wish list and the in-room promo box.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الإعلان'**
  String get livePromoClose;

  /// D138: an emoji played once on one's own seat in an audio room.
  ///
  /// In ar, this message translates to:
  /// **'إيموجي على مقعدي'**
  String get liveSeatEmoji;

  /// D138: an emoji played once on one's own seat in an audio room.
  ///
  /// In ar, this message translates to:
  /// **'يظهر على مقعدك مرة واحدة ويراه الجميع'**
  String get liveSeatEmojiHint;

  /// D141: the owner's device feedback on the live rooms.
  ///
  /// In ar, this message translates to:
  /// **'تم اختيار {count} من 4'**
  String liveWishChosenCount(int count);

  /// D141: the owner's device feedback on the live rooms.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get liveUsernameCopied;

  /// D141: the owner's device feedback on the live rooms.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت بسرعة كبيرة. اضغط لإعادة المحاولة'**
  String get liveChatTooFast;

  /// D141: the owner's device feedback on the live rooms.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت {time}'**
  String liveBulletTime(String time);

  /// D141: the owner's device feedback on the live rooms.
  ///
  /// In ar, this message translates to:
  /// **'الألعاب'**
  String get liveGames;

  /// D141: the owner's device feedback on the live rooms.
  ///
  /// In ar, this message translates to:
  /// **'الألعاب قريباً'**
  String get liveGamesSoon;

  /// D173: the games sheet of the live bars (no games yet).
  ///
  /// In ar, this message translates to:
  /// **'نعمل على إضافة ألعاب تلعبها داخل البث، وهي غير متاحة بعد.'**
  String get liveGamesSoonBody;

  /// D178: gifts, lucky wins and the global gift strip in the live.
  ///
  /// In ar, this message translates to:
  /// **'{sender} أرسل {gift} ×{count} إلى {recipient}'**
  String liveChatGiftLine(
    String sender,
    String gift,
    int count,
    String recipient,
  );

  /// D178: gifts, lucky wins and the global gift strip in the live.
  ///
  /// In ar, this message translates to:
  /// **'{name} و{more} آخرين'**
  String liveChatGiftRecipients(String name, int more);

  /// D178: gifts, lucky wins and the global gift strip in the live.
  ///
  /// In ar, this message translates to:
  /// **'{sender} ربح ×{multiplier} = {coins} عملة من هدية الحظ'**
  String liveChatLuckyLine(String sender, String multiplier, String coins);

  /// D305: the global gifts strip (a gift of ≥ 500 000 coins in any live). Names are bidi-isolated by the app.
  ///
  /// In ar, this message translates to:
  /// **'أرسل {sender} إلى {receiver} هدية {gift}'**
  String liveStripGift(String sender, String receiver, String gift);

  /// D305: the global games strip (a game prize of ≥ 1 000 000 tickets). amount is the grouped number; the ticket icon follows it.
  ///
  /// In ar, this message translates to:
  /// **'فاز {winner} بجائزة قيمتها {amount} تذكرة'**
  String liveStripGameWin(String winner, String amount);

  /// D305: per-account switch, every live's settings sheet and the notification settings.
  ///
  /// In ar, this message translates to:
  /// **'إظهار شريط الهدايا'**
  String get liveStripShowGifts;

  /// D305: per-account switch, every live's settings sheet and the notification settings.
  ///
  /// In ar, this message translates to:
  /// **'إظهار شريط الألعاب'**
  String get liveStripShowGames;

  /// D305: under the two strip switches.
  ///
  /// In ar, this message translates to:
  /// **'في جميع البثوث وعلى كل أجهزتك'**
  String get liveStripSwitchHint;

  /// D347: hides the global lucky banner (a ×250 / ×500 / ×1000 win in another live) in every live, on every device (the account's luckyStrip off).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء أشرطة الفوز'**
  String get liveStripHideWins;

  /// D347: under «إخفاء أشرطة الفوز».
  ///
  /// In ar, this message translates to:
  /// **'مكاسب الحظ الكبيرة من اللايفات الأخرى لا تظهر؛ شريط المكسب في هذا البث يبقى'**
  String get liveStripHideWinsHint;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get liveViewerMenu;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'أدوات المشرف'**
  String get liveToolsModerator;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن المضيف'**
  String get liveToolReportHost;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'المشاهدون'**
  String get liveToolViewers;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'المساهمات'**
  String get liveToolContributions;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'أصوات الهدايا'**
  String get liveToolGiftSounds;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'مؤثرات الهدايا'**
  String get liveToolGiftEffects;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'شاشة نظيفة'**
  String get liveToolClearScreen;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'إعدادات البث'**
  String get liveBroadcastSettings;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الصوت'**
  String get liveSettingsSound;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get liveSettingsCamera;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'عند إيقافها يرى الآخرون صورتك'**
  String get liveSettingsCameraHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'قلب الكاميرا'**
  String get liveSettingsFlip;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الجودة'**
  String get liveSettingsQuality;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get liveSettingsSeatCount;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الأسئلة'**
  String get liveSettingsQuestions;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الغرفة'**
  String get liveSettingsRoom;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get liveSettingsGeneral;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'المشاهدة دون حساب'**
  String get liveSettingsGuestsHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'كتم الجميع'**
  String get liveMuteAll;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'يكتم مايك كل من على المقاعد'**
  String get liveMuteAllHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'تم كتم كل من على المقاعد'**
  String get liveMuteAllDone;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'لا أحد على المقاعد لكتمه'**
  String get liveMuteAllNone;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف الكاميرا'**
  String get liveCameraOff;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'إعدادات المشاهدة'**
  String get liveViewerSettings;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'هذا البث'**
  String get liveViewerThisLive;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الهدايا والتأثيرات'**
  String get liveViewerEffects;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'العرض'**
  String get liveViewerDisplay;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'كتم صوت البث عندي'**
  String get liveViewerMuteLive;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'لهذا البث فقط، ولا يتغيّر شيء عند غيرك'**
  String get liveViewerMuteLiveHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'مستوى الصوت'**
  String get liveViewerVolume;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'كتم أصوات الهدايا'**
  String get liveViewerGiftSounds;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء مؤثرات الهدايا'**
  String get liveViewerGiftEffects;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'يبقى شريط الهدية في الدردشة'**
  String get liveViewerGiftEffectsHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'كتم أصوات الإفيهات'**
  String get liveViewerQuipSounds;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء تأثيرات الدخول'**
  String get liveViewerEntrances;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'يخفي الدردشة والبطاقات، اضغط «إظهار الكل» للعودة'**
  String get liveViewerCleanHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'إظهار الكل'**
  String get liveViewerCleanRestore;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'حجم خط الدردشة'**
  String get liveViewerChatText;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'صغير'**
  String get liveViewerChatSmall;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get liveViewerChatNormal;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'كبير'**
  String get liveViewerChatLarge;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'توفير البيانات'**
  String get liveViewerDataSaver;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'الصوت فقط، دون فيديو'**
  String get liveViewerDataSaverHint;

  /// D225: the live settings pages (host «إعدادات البث», viewer «إعدادات المشاهدة»).
  ///
  /// In ar, this message translates to:
  /// **'توفير البيانات: الصوت فقط'**
  String get liveViewerDataSaverOn;

  /// D173: the ≡ menu of the live bar for everyone (viewer and moderator items).
  ///
  /// In ar, this message translates to:
  /// **'طلبات المقاعد'**
  String get liveToolSeatRequests;

  /// D173: the audio room became a cinema (YouTube together) with 10 seats.
  ///
  /// In ar, this message translates to:
  /// **'وضع السينما يتسع لـ 10 مقاعد: تم نقلك إلى المقعد {seat}.'**
  String liveCinemaMoved(int seat);

  /// D173: the audio room became a cinema (YouTube together) with 10 seats.
  ///
  /// In ar, this message translates to:
  /// **'تم إنزالك من المقعد لأن وضع السينما يتسع لـ 10 مقاعد فقط.'**
  String get liveCinemaOffSeat;

  /// D173: the guest (∞) button of the viewer's video live bar.
  ///
  /// In ar, this message translates to:
  /// **'انضم كضيف'**
  String get liveGuestJoin;

  /// D174: a solo live's 3 guest seats are taken.
  ///
  /// In ar, this message translates to:
  /// **'مقاعد الضيوف الثلاثة في هذا البث ممتلئة. حاول مجدداً عندما يفرغ مقعد.'**
  String get liveGuestsFull;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'كرز هذا البث'**
  String get liveStatsCherries;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'منها {points} من نقراتك وهداياك أنت'**
  String liveStatsIncludesYours(String points);

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'المشاهدون'**
  String get liveStatsViewers;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'ذروة المشاهدة'**
  String get liveStatsPeak;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'متوسط مدة المشاهدة'**
  String get liveStatsAverageWatch;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'متابعون جدد'**
  String get liveStatsNewFollowers;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'رسائل الدردشة'**
  String get liveStatsChatMessages;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'الهدايا المُرسلة'**
  String get liveStatsGiftsSent;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'من أين جاء مشاهدوك'**
  String get liveStatsCountriesTitle;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'دول أخرى'**
  String get liveStatsCountryOther;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get liveStatsCountryUnknown;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'النسب من إجمالي المشاهدين ({count})، مقرّبة إلى منزلة عشرية واحدة'**
  String liveStatsCountriesNote(String count);

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'{country}: {percent} من المشاهدين ({count})'**
  String liveStatsCountryRow(String country, String percent, String count);

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'لم يشاهد أحد هذه المرة. بثك القادم فرصة جديدة.'**
  String get liveStatsNoViewers;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'أبرز الداعمين'**
  String get liveStatsTopSupporters;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'لا داعمين هذه المرة. ستظهر هنا هدايا ونقرات مشاهديك.'**
  String get liveStatsNoSupporters;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'المركز {rank}: {name}، {points} كرزة'**
  String liveStatsSupporterRank(int rank, String name, String points);

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات البث'**
  String get liveStatsLoadFailed;

  /// D140: the full-screen end-of-live summary (the live's statistics).
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من اتصالك ثم حاول مجدداً.'**
  String get liveStatsLoadFailedBody;

  /// D145/D145c/D145d: the word on the MAX X button before its counter — owner's MAX X design: «ماكس x12» in Arabic, «MAX x12» in English (screen readers say "Max X" / «ماكس إكس» through liveComboSemantics).
  ///
  /// In ar, this message translates to:
  /// **'ماكس'**
  String get liveComboLabel;

  /// D145d: the ×500 win celebration's title on the MAX X button (owner's file: جاكبوت / JACKPOT).
  ///
  /// In ar, this message translates to:
  /// **'جاكبوت'**
  String get liveMaxXJackpot;

  /// D145d: the ×1000 win celebration's title (owner's file: سوبر جاكبوت / SUPER JACKPOT).
  ///
  /// In ar, this message translates to:
  /// **'سوبر جاكبوت'**
  String get liveMaxXSuperJackpot;

  /// D145: the lucky combo button for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'ماكس إكس: أرسل {gift} مجدداً ⁦×{count}⁩'**
  String liveComboSemantics(String gift, int count);

  /// D145: the coin balance under the combo button.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك {coins} عملة'**
  String liveComboBalance(String coins);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'استخدم أحرفاً وأرقاماً معاً (مثل sara22)'**
  String get usernameLettersAndDigits;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'هذا يوزر مميز، واليوزرات المميزة تُستأجر من متجر اليوزرات المميزة.'**
  String get usernamePremium;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن استئجار هذا اليوزر الآن.'**
  String get errorPremiumUsernameUnavailable;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر السعر للتو. راجع السعر الجديد وحاول مجدداً.'**
  String get errorPremiumUsernamePriceChanged;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'لديك يوزر مميز بالفعل. أعِده أولاً.'**
  String get errorPremiumUsernameActive;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'اليوزرات المميزة'**
  String get premiumTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'استأجر @يوزر مميز'**
  String get premiumTileValue;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن يوزر، مثل 777'**
  String get premiumSearchHint;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسماً لترى إن كان متاحاً للاستئجار.'**
  String get premiumSearchHelp;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المتجر'**
  String get premiumLoadError;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get premiumTierAll;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'أسطوري'**
  String get premiumTierLegend;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ياقوتي'**
  String get premiumTierRuby;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ذهبي'**
  String get premiumTierGold;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'فضي'**
  String get premiumTierSilver;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'من 1 إلى 3 أحرف'**
  String get premiumTierLegendRule;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'حرف أو رقم مكرر (7777)'**
  String get premiumTierRubyRule;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'4–5 أحرف أو نمط (1221، 1212، 123456)'**
  String get premiumTierGoldRule;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'6 أو أكثر: أحرف فقط أو أرقام فقط'**
  String get premiumTierSilverRule;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح للبيع بعد'**
  String get premiumTierNotOnSale;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة / {days} يوماً'**
  String premiumPricePerPeriod(String coins, int days);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة'**
  String premiumCoins(String coins);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'متاحة الآن'**
  String get premiumSuggestions;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'اليوزرات المميزة غير متاحة للبيع بعد'**
  String get premiumNotOnSaleTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحدَّد الأسعار بعد. عُد قريباً.'**
  String get premiumNotOnSaleMessage;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد يوزر متاح هنا الآن'**
  String get premiumNoSuggestionsTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن اسم في الأعلى أو جرّب فئة أخرى.'**
  String get premiumNoSuggestionsMessage;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'كل استئجار مدته {days} يوماً ويمكنك التجديد في أي وقت. عند انتهائه تعود إلى يوزرك العادي، ويُحجز الاسم لك {grace} أيام.'**
  String premiumRules(int days, int grace);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'متاح للاستئجار'**
  String get premiumStateAvailable;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح للبيع بعد'**
  String get premiumStateNotForSale;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'هذا اليوزر مستخدم من شخص آخر'**
  String get premiumStateTaken;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'محجوز لمستأجره السابق لبضعة أيام'**
  String get premiumStateHeld;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'هذا يوزرك، ويمكنك تجديده.'**
  String get premiumStateYours;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'انتهى استئجارك. جدّد الآن لاستعادته.'**
  String get premiumStateYoursGrace;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'هذا اليوزر محجوز'**
  String get premiumStateReserved;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ليس يوزراً مميزاً: يمكنك أخذه مجاناً من الإعدادات › اسم المستخدم إن كان متاحاً.'**
  String get premiumStateRegular;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ليس اسم مستخدم صالحاً'**
  String get premiumStateInvalid;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'يصبح متاحاً بعد {date}'**
  String premiumHeldUntil(String date);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'استئجار'**
  String get premiumRent;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تجديد'**
  String get premiumRenew;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'استئجار · {coins} عملة'**
  String premiumRentFor(String coins);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تجديد · {coins} عملة'**
  String premiumRenewFor(String coins);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'استئجار هذا اليوزر'**
  String get premiumRentTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تجديد يوزرك'**
  String get premiumRenewTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get premiumSheetPrice;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك'**
  String get premiumSheetBalance;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'لك حتى'**
  String get premiumSheetUntil;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'بعد ذلك تعود إلى ‎@{username} ما لم تجدّد.'**
  String premiumSheetAfter(String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك من العملات لا يكفي.'**
  String get premiumNotEnoughCoins;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'أصبحت الآن ⁦{username}⁩'**
  String premiumRented(String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تم تجديد ⁦{username}⁩'**
  String premiumRenewed(String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'يوزرك المميز'**
  String get premiumMineTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'انتهى يوزرك المميز'**
  String get premiumMineGraceTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ {left}'**
  String premiumMineLeft(String left);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'بلا تاريخ انتهاء'**
  String get premiumMineNoEnd;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'مُهدى من فريق Kabso'**
  String get premiumMineGranted;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'عدت إلى ‎@{username}، والاسم محجوز لك لمدة {left}.'**
  String premiumMineGrace(String username, String left);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'إعادة اليوزر'**
  String get premiumRelease;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'إعادة يوزرك المميز؟'**
  String get premiumReleaseTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'سيعود ⁦{premium}⁩ إلى المتجر الآن وتعود إلى ‎@{regular}. لا تُسترد العملات.'**
  String premiumReleaseBody(String premium, String regular);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'عدت إلى ‎@{username}'**
  String premiumReleased(String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'أقل من دقيقة'**
  String get premiumLeftUnderMinute;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'{minutes, plural, =1{دقيقة واحدة} =2{دقيقتان} few{{minutes} دقائق} many{{minutes} دقيقة} other{{minutes} دقيقة}}'**
  String premiumLeftMinutes(int minutes);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'{hours, plural, =1{ساعة واحدة} =2{ساعتان} few{{hours} ساعات} many{{hours} ساعة} other{{hours} ساعة}} و{minutes} د'**
  String premiumLeftHours(int hours, int minutes);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} many{{days} يوماً} other{{days} يوم}} و{hours} س'**
  String premiumLeftDays(int days, int hours);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'يوزر مميز {tier} ⁦{username}⁩'**
  String premiumBadgeLabel(String tier, String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get settingsUsername;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'تغيير اسم المستخدم'**
  String get changeUsernameTitle;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم الحالي'**
  String get changeUsernameCurrent;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم الجديد'**
  String get changeUsernameNew;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'من 6 إلى 30: أحرف وأرقام (a–z و0–9)، ويُسمح بـ _'**
  String get changeUsernameRule;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get changeUsernameSave;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'أصبحت الآن ‎@{username}'**
  String changeUsernameDone(String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'يصبح اسمك القديم متاحاً للآخرين فوراً.'**
  String get changeUsernameNote;

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'استأجر ⁦{username}⁩ كيوزر مميز'**
  String changeUsernameRentInstead(String username);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'أنت تستخدم اليوزر المميز ⁦{premium}⁩. لتغيير يوزرك العادي (‎@{regular}) أعِد اليوزر المميز أولاً.'**
  String changeUsernamePremiumActive(String premium, String regular);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي يوزرك المميز ⁦{username}⁩ خلال {left}. جدّده لتحتفظ به.'**
  String notificationPremiumExpiring(String username, String left);

  /// D146: premium usernames (يوزر مميز) and the regular username rule.
  ///
  /// In ar, this message translates to:
  /// **'انتهى يوزرك المميز ⁦{username}⁩، وهو محجوز لك لبضعة أيام.'**
  String notificationPremiumExpired(String username);

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'جرّب البحث: {term}'**
  String searchTryHint(String term);

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get searchCancel;

  /// D157: the search home's local history of this device's searches.
  ///
  /// In ar, this message translates to:
  /// **'عمليات البحث الأخيرة'**
  String get searchRecentTitle;

  /// D157: clears the recent searches.
  ///
  /// In ar, this message translates to:
  /// **'مسح الكل'**
  String get searchRecentClear;

  /// D157: removes one recent search (the ✕ on its chip).
  ///
  /// In ar, this message translates to:
  /// **'إزالة «{term}» من عمليات البحث الأخيرة'**
  String searchRecentRemove(String term);

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'الأكثر بحثاً'**
  String get searchHotTitle;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'بحث رائج {rank}: {term}'**
  String searchHotSemantics(int rank, String term);

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'رائج'**
  String get searchTagTrending;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get searchTagNew;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'وسوم رائجة'**
  String get searchHotTakeTitle;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get searchMore;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'قد يعجبك'**
  String get searchMayLikeTitle;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'الوسوم الرائجة'**
  String get trendingHashtagsTitle;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وسوم رائجة هذا الأسبوع'**
  String get trendingHashtagsEmpty;

  /// D147: Bigo-style search home (trending searches, hot hashtags, lives).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا منشورات هذا الأسبوع} =1{منشور واحد هذا الأسبوع} =2{منشوران هذا الأسبوع} few{{count} منشورات هذا الأسبوع} many{{count} منشورًا هذا الأسبوع} other{{count} منشور هذا الأسبوع}}'**
  String trendingHashtagWeekCount(int count);

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تشغيل المؤثر…'**
  String get liveEffectStarting;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'المؤثر غير متاح الآن: توقّف عن إعطاء صورة جديدة، فعادت الكاميرا من دونه. جرّبه مرة أخرى بعد قليل.'**
  String get liveEffectUnavailableStopped;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'المؤثر غير متاح الآن: لم يُقبل ترخيص المؤثرات في هذا الإصدار.'**
  String get liveEffectUnavailableLicence;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'المؤثر غير متاح الآن: لم يبدأ على هذا الجهاز. جرّبه مرة أخرى بعد قليل.'**
  String get liveEffectUnavailableFailed;

  /// D145e: DeepAR's picture was black; the effect switched itself off.
  ///
  /// In ar, this message translates to:
  /// **'المؤثر غير متاح الآن: خرجت صورته سوداء، فعادت الكاميرا من دونه قبل أن يراها المشاهدون. جرّبه مرة أخرى لاحقاً.'**
  String get liveEffectUnavailableBlack;

  /// D228: the free effects engine kept missing its frame budget (too_slow) and switched itself off.
  ///
  /// In ar, this message translates to:
  /// **'المؤثر غير متاح الآن: كان أبطأ من أن يواكب الكاميرا على هذا الجهاز، فعادت الكاميرا من دونه.'**
  String get liveEffectUnavailableSlow;

  /// D228 Magic: the effects run on the free engine (Google ML Kit + MediaPipe, on the device). ML Kit and MediaPipe are product names: not translated; in Arabic they sit in a left-to-right isolate (U+2066 … U+2069) so the brackets stay in place.
  ///
  /// In ar, this message translates to:
  /// **'المحرك: المجاني، على الجهاز (⁦ML Kit + MediaPipe⁩)'**
  String get liveEffectsEngineFree;

  /// D228 Magic: the free engine's beauty section.
  ///
  /// In ar, this message translates to:
  /// **'التجميل'**
  String get liveFreeBeautyTitle;

  /// D228 Magic: turns the free engine's beauty on.
  ///
  /// In ar, this message translates to:
  /// **'تجميل الوجه'**
  String get liveFreeBeautyOn;

  /// D228 Magic: the face model downloads once on first use; then everything runs on the phone.
  ///
  /// In ar, this message translates to:
  /// **'يُنزَّل نموذج الوجه (3.6 ميغابايت) مرة واحدة عند أول استخدام، ثم يعمل كل شيء على الجهاز.'**
  String get liveFreeBeautyNote;

  /// D228 Magic: the face model could not be downloaded or loaded.
  ///
  /// In ar, this message translates to:
  /// **'التجميل غير متاح الآن: تعذّر تحميل نموذج الوجه. تحقّق من الاتصال وجرّب مرة أخرى.'**
  String get liveFreeBeautyUnavailable;

  /// D228 Magic: skin smoothing strength (0–100).
  ///
  /// In ar, this message translates to:
  /// **'تنعيم البشرة'**
  String get liveFreeBeautySmooth;

  /// D228 Magic: brighten/whiten strength (0–100).
  ///
  /// In ar, this message translates to:
  /// **'تفتيح'**
  String get liveFreeBeautyBrighten;

  /// D228 Magic: subtle face slimming strength (0–100).
  ///
  /// In ar, this message translates to:
  /// **'نحت الوجه'**
  String get liveFreeBeautySlim;

  /// D228 Magic: subtle eye enlargement strength (0–100).
  ///
  /// In ar, this message translates to:
  /// **'تكبير العينين'**
  String get liveFreeBeautyEyes;

  /// D159: the label of the ruby win banner (x50 to x100; D145e: the big win card).
  ///
  /// In ar, this message translates to:
  /// **'فوز كبير'**
  String get liveLuckyBigWin;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا والميكروفون لبثّك'**
  String get livePermissionTitleVideo;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون للغرفة الصوتية'**
  String get livePermissionTitleAudio;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'يستخدم Kabso Live الكاميرا والميكروفون فقط أثناء بثّك أو جلوسك على مقعد، ليراك الحاضرون ويسمعوك. سيسألك الجهاز مرة واحدة.'**
  String get livePermissionBodyVideo;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'يستخدم Kabso Live الميكروفون فقط أثناء وجودك في الغرفة الصوتية ليسمعك الحاضرون، ولا يحتاج الكاميرا هنا. سيسألك الجهاز مرة واحدة.'**
  String get livePermissionBodyAudio;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get livePermissionContinue;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get livePermissionNotNow;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get livePermissionOpenSettings;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'رفضتَ الوصول من قبل ولن يسألك الجهاز مجدداً. افتح الإعدادات ثم الأذونات، واسمح بالكاميرا والميكروفون.'**
  String get livePermissionBlockedVideo;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'رفضتَ الوصول من قبل ولن يسألك الجهاز مجدداً. افتح الإعدادات ثم الأذونات، واسمح بالميكروفون.'**
  String get livePermissionBlockedAudio;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'اسمح بالميكروفون'**
  String get goLiveMicDeniedTitle;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'تحتاجه الغرفة الصوتية ليسمعك الحاضرون. اضغط «إعادة المحاولة» ليسألك الجهاز مرة أخرى.'**
  String get goLiveMicDeniedBody;

  /// D144a: DeepAR status and camera/microphone permissions.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الجلوس على المقعد دون السماح بالوصول.'**
  String get livePermissionSeatRefused;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'فعّل الإشعارات'**
  String get pushPermissionTitle;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'ليصلك إشعار بصوت Kabso Live عند وصول رسالة في محادثة عائلتك، وعند المتابعات والإعجابات والتعليقات. يمكنك تغيير ذلك في أي وقت من الإعدادات.'**
  String get pushPermissionBody;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'السماح بالإشعارات'**
  String get pushPermissionAllow;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get pushPermissionNotNow;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات متوقفة على هذا الهاتف'**
  String get pushOffTitle;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'فعّلها ليصلك إشعار بالرسائل الجديدة والتفاعلات حتى والتطبيق مغلق.'**
  String get pushOffBody;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'أوقفتَ الإشعارات من قبل ولن يسألك الجهاز مجدداً. افتح الإعدادات وفعّل الإشعارات لتطبيق Kabso Live.'**
  String get pushOffBlockedBody;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get pushTurnOn;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get pushOpenSettings;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get notifSettingMessages;

  /// D152: push notifications (permission, settings).
  ///
  /// In ar, this message translates to:
  /// **'إشعار على الهاتف عند وصول رسائل جديدة في محادثة عائلتك ورسائلك الخاصة'**
  String get notifSettingMessagesBody;

  /// D148: the small label over a MAX X win the guarantee paid (×5 after 15 losing draws in a row).
  ///
  /// In ar, this message translates to:
  /// **'ضمان'**
  String get liveMaxXGuaranteed;

  /// D148: the odds sheet's line for the per-sender guarantee (owner's wording).
  ///
  /// In ar, this message translates to:
  /// **'×{multiplier} مضمون بعد {after} محاولة بدون ربح'**
  String liveLuckyOddsPity(String multiplier, String after);

  /// D148: the gold ticker of a big lucky win in another live («لحظة الحظ»); a tap opens that live.
  ///
  /// In ar, this message translates to:
  /// **'{name} ربح ×{multiplier} في غرفة {room}'**
  String liveLuckyTicker(String name, String multiplier, String room);

  /// D347: the tag under the global lucky banner (a ×250 / ×500 / ×1000 win in another live): the live it happened in; a tap opens it.
  ///
  /// In ar, this message translates to:
  /// **'في {room}'**
  String liveLuckyGlobalIn(String room);

  /// D347: a seated guest tapped the global lucky banner; going there leaves their seat.
  ///
  /// In ar, this message translates to:
  /// **'ستترك مقعدك وتنتقل إلى {room}. هل تريد المتابعة؟'**
  String liveLuckyGlobalLeaveSeat(String room);

  /// D347: confirms moving to the live of the global lucky banner.
  ///
  /// In ar, this message translates to:
  /// **'انتقال'**
  String get liveLuckyGlobalGo;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'الدردشات'**
  String get dmTabChats;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'طلبات المراسلة'**
  String get dmTabRequests;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'طلبات المراسلة ({count})'**
  String dmTabRequestsCount(String count);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات مراسلة'**
  String get dmRequestsEmptyTitle;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'رسائل الأشخاص الذين لا تتابعهم تنتظر هنا. لن يعرفوا أنك رأيتها حتى تقبل.'**
  String get dmRequestsHint;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'الرسائل تُحذف تلقائياً بعد 24 ساعة من إرسالها.'**
  String get dmRetentionNotice;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل خلال آخر 24 ساعة.'**
  String get dmNoRecentMessages;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'📷 صورة'**
  String get dmLastPhoto;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'🎤 رسالة صوتية'**
  String get dmPreviewVoice;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'ملصق'**
  String get dmPreviewSticker;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'🎁 هدية ×{count}'**
  String dmPreviewGift(String count);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الرسائل'**
  String get dmPreviewExpired;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'أنت: {text}'**
  String dmPreviewYou(String text);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'رسالة لا يعرضها هذا الإصدار'**
  String get dmPreviewUnsupported;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'{name} يريد مراسلتك. اقبل لنقل المحادثة إلى رسائلك.'**
  String dmRequestBanner(String name);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get dmAccept;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get dmDecline;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'حتى يرد {name} يمكنك إرسال {count} رسائل أخرى'**
  String dmRequestLeft(String name, String count);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'انتظر رد {name} قبل إرسال المزيد.'**
  String dmRequestLimit(String name);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'{name} لا يستقبل رسائل منك.'**
  String dmNotAllowed(String name);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'هذه المحادثة غير متاحة.'**
  String get dmUnavailable;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'خيارات المحادثة'**
  String get dmMenu;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'كتم'**
  String get dmMute;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get dmUnmute;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'تم كتم المحادثة'**
  String get dmMuted;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء كتم المحادثة'**
  String get dmUnmuted;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'حذف المحادثة'**
  String get dmDeleteConversation;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'حذف هذه المحادثة؟'**
  String get dmDeleteConversationTitle;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'تُحذف من عندك فقط. ستعود إذا وصلت رسالة جديدة.'**
  String get dmDeleteConversationBody;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ'**
  String get dmReportPerson;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'حذف لدي'**
  String get dmDeleteForMe;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'حذف لدى الجميع'**
  String get dmDeleteForEveryone;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن الرسالة'**
  String get dmReportMessage;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'شكراً. سنراجع البلاغ.'**
  String get dmReported;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال الفيديو في الرسائل. أرسل صورة بدلاً منه.'**
  String get dmVideoNotSupported;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال هذا النوع من الصور. اختر صورة JPEG أو PNG أو WebP.'**
  String get dmPhotoUnsupported;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإرسال…'**
  String get dmSending;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'إرسال هدية كطلب مراسلة؟'**
  String get dmGiftRequestTitle;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لم يقبل {name} رسائلك بعد. تُدفع الهدية الآن وتُحسب من رسائل طلبك حتى لو لم يقبل.'**
  String dmGiftRequestBody(String name);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get dmGiftContinue;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'هديتك ×{count}'**
  String dmGiftMine(String count);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'هدية من {name} ×{count}'**
  String dmGiftTheirs(String name, String count);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'ربح {coins} كوينز (×{multiplier})'**
  String dmLuckyWon(String coins, String multiplier);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لا ربح هذه المرة'**
  String get dmLuckyNoWin;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية، {length}'**
  String dmVoiceNote(String length);

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get dmPhoto;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'أرسل رسالة لبدء المحادثة.'**
  String get dmStartConversation;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'من يستطيع مراسلتك'**
  String get privacyMessageTitle;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'من لا تتابعهم يرسلون طلبات مراسلة. الرسائل تُحذف بعد 24 ساعة من إرسالها.'**
  String get privacyMessageHint;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'هذا الشخص لا يستقبل رسائل منك.'**
  String get errorDmNotAllowed;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'انتظر الرد قبل إرسال المزيد من الرسائل.'**
  String get errorDmRequestLimit;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'يمكن إرسال النصوص والملصقات والهدايا فقط حتى يُقبل طلبك.'**
  String get errorDmRequestTextOnly;

  /// D155: direct messages (CONVENTIONS §11.13).
  ///
  /// In ar, this message translates to:
  /// **'لم يعد بالإمكان حذف هذه الرسالة لدى الجميع.'**
  String get errorDmDeleteWindowPassed;

  /// D154: the gift panel tab of quips (sounds played to the room).
  ///
  /// In ar, this message translates to:
  /// **'إفيهات'**
  String get liveGiftTabQuips;

  /// D154: the price label of a free quip.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get liveQuipFree;

  /// D154: a free quip for the host or a moderator (their soundboard, no limit but one every 2 s).
  ///
  /// In ar, this message translates to:
  /// **'∞ مجاني'**
  String get liveQuipSoundboardFree;

  /// D154: the gift panel line under a selected free quip.
  ///
  /// In ar, this message translates to:
  /// **'إفيه مجاني واحد لك في كل بث.'**
  String get liveQuipFreeOnce;

  /// D154: the soundboard's explanation.
  ///
  /// In ar, this message translates to:
  /// **'مجانية لك وللمشرفين — صوت كل ثانيتين، يسمعه الجميع.'**
  String get liveQuipSoundboardHint;

  /// D154: the soundboard when the app's Sound effects setting is off.
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات الصوتية مطفأة في الإعدادات: لن تسمعها أنت، لكن الغرفة تسمعها.'**
  String get liveQuipSoundEffectsOff;

  /// D154: the host's soundboard sheet title.
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات الصوتية'**
  String get liveQuipSoundboardTitle;

  /// D154: the soundboard when the catalogue has no free quips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مؤثرات مجانية بعد.'**
  String get liveQuipSoundboardEmpty;

  /// D154: mute quips' sound on this phone.
  ///
  /// In ar, this message translates to:
  /// **'كتم الإفيهات'**
  String get liveQuipMute;

  /// D154: turn quips' sound back on on this phone.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل صوت الإفيهات'**
  String get liveQuipUnmute;

  /// D154: a quip waits for its turn in the room's queue.
  ///
  /// In ar, this message translates to:
  /// **'في الدور — يبدأ بعد {seconds} ث'**
  String liveQuipQueued(int seconds);

  /// D224: the line under the sender's name on a quip's gift strip.
  ///
  /// In ar, this message translates to:
  /// **'أرسل إفيه: {words}'**
  String liveQuipBannerSent(String words);

  /// D224: a quip's line in the live chat, like a gift's line.
  ///
  /// In ar, this message translates to:
  /// **'{sender} أرسل إفيه: {words}'**
  String liveChatQuipLine(String sender, String words);

  /// Error QUIP_FREE_USED.
  ///
  /// In ar, this message translates to:
  /// **'استخدمت إفيهك المجاني في هذا البث.'**
  String get errorQuipFreeUsed;

  /// Error QUIP_QUEUE_FULL.
  ///
  /// In ar, this message translates to:
  /// **'إفيهات كثيرة بانتظار دورها، جرّب بعد قليل.'**
  String get errorQuipQueueFull;

  /// D154b: the traffic card sheet title.
  ///
  /// In ar, this message translates to:
  /// **'صواريخ الزيارات'**
  String get liveBoostTitle;

  /// D154b: the host's explanation.
  ///
  /// In ar, this message translates to:
  /// **'اختر صاروخاً: يظهر بثك في أعلى قائمة البث مع علامة «مميز» وإطار متحرك. {slots} أماكن فقط؛ إن امتلأت ينتظر دوره.'**
  String liveBoostHint(int slots);

  /// D154b: a viewer gifting the host.
  ///
  /// In ar, this message translates to:
  /// **'هدية لـ {name}: صاروخ يرفع بثه إلى أعلى القائمة مع علامة «مميز». المضيف لا يربح منها عملات.'**
  String liveBoostGiftHint(String name);

  /// D154b: a card length.
  ///
  /// In ar, this message translates to:
  /// **'{minutes, plural, =1{دقيقة واحدة} =2{دقيقتان} few{{minutes} دقائق} other{{minutes} دقيقة}}'**
  String liveBoostMinutes(int minutes);

  /// D154b: a card price (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة'**
  String liveBoostPrice(String coins);

  /// D154b: what a longer card saves.
  ///
  /// In ar, this message translates to:
  /// **'وفّر {percent}%'**
  String liveBoostSave(int percent);

  /// D154b: reward cards held of a length.
  ///
  /// In ar, this message translates to:
  /// **'لديك {count}'**
  String liveBoostHeld(int count);

  /// D154b: a free slot now.
  ///
  /// In ar, this message translates to:
  /// **'يبدأ فوراً.'**
  String get liveBoostStartsNow;

  /// D154b: the honest wait.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن ممتلئة: يبدأ خلال {minutes, plural, =1{دقيقة واحدة} =2{دقيقتين} few{{minutes} دقائق} other{{minutes} دقيقة}} على الأكثر.'**
  String liveBoostStartsIn(int minutes);

  /// D154b: pay with a reward card.
  ///
  /// In ar, this message translates to:
  /// **'استخدم بطاقة (لديك {count})'**
  String liveBoostUseCard(int count);

  /// D154b: the button with a card.
  ///
  /// In ar, this message translates to:
  /// **'استخدم البطاقة'**
  String get liveBoostUseCardAction;

  /// D154b: the buy button.
  ///
  /// In ar, this message translates to:
  /// **'اشترِ بـ {coins} عملة'**
  String liveBoostBuy(String coins);

  /// D154b: confirm dialog title.
  ///
  /// In ar, this message translates to:
  /// **'صواريخ الزيارات'**
  String get liveBoostConfirmTitle;

  /// D154b: confirm with coins.
  ///
  /// In ar, this message translates to:
  /// **'{minutes, plural, =1{دقيقة واحدة} =2{دقيقتان} few{{minutes} دقائق} other{{minutes} دقيقة}} في الأماكن المميزة مقابل {coins} عملة؟'**
  String liveBoostConfirmCoins(int minutes, String coins);

  /// D154b: confirm with a card.
  ///
  /// In ar, this message translates to:
  /// **'استخدام بطاقة {minutes, plural, =1{دقيقة واحدة} =2{دقيقتان} few{{minutes} دقائق} other{{minutes} دقيقة}}؟'**
  String liveBoostConfirmCard(int minutes);

  /// D154b: confirm button.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get liveBoostConfirmAction;

  /// D154b: bought, running.
  ///
  /// In ar, this message translates to:
  /// **'انطلق الصاروخ: البث مميز الآن في أعلى القائمة.'**
  String get liveBoostDoneNow;

  /// D154b: bought, waiting.
  ///
  /// In ar, this message translates to:
  /// **'في الدور: يبدأ خلال {minutes, plural, =1{دقيقة واحدة} =2{دقيقتين} few{{minutes} دقائق} other{{minutes} دقيقة}} على الأكثر.'**
  String liveBoostDoneWaiting(int minutes);

  /// D154b: the live's card is running.
  ///
  /// In ar, this message translates to:
  /// **'مميز الآن — ينتهي خلال {minutes, plural, =1{دقيقة واحدة} =2{دقيقتين} few{{minutes} دقائق} other{{minutes} دقيقة}}.'**
  String liveBoostRunning(int minutes);

  /// D154b: the live's card is waiting.
  ///
  /// In ar, this message translates to:
  /// **'صاروخ في الدور — يبدأ خلال {minutes, plural, =1{دقيقة واحدة} =2{دقيقتين} few{{minutes} دقائق} other{{minutes} دقيقة}} على الأكثر.'**
  String liveBoostWaiting(int minutes);

  /// D154b: offers failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل صواريخ الزيارات'**
  String get liveBoostLoadError;

  /// D154b: the label of a boosted live on the hub.
  ///
  /// In ar, this message translates to:
  /// **'مميز'**
  String get liveBoostFeatured;

  /// D154b: the host card's button for viewers.
  ///
  /// In ar, this message translates to:
  /// **'صاروخ زيارات'**
  String get liveBoostGiftAction;

  /// D233: a rocket stage «صاروخ 1 · 2 · 3 · 4» (sheet card, hub badge label).
  ///
  /// In ar, this message translates to:
  /// **'صاروخ {stage}'**
  String liveRocketStage(int stage);

  /// Error BOOST_QUEUE_FULL.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن المميزة محجوزة لوقت طويل؛ جرّب بطاقة أقصر أو لاحقاً.'**
  String get errorBoostQueueFull;

  /// Error BOOST_CARD_INSUFFICIENT.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك بطاقة بهذه المدة.'**
  String get errorBoostCardInsufficient;

  /// Error BOOST_ROOM_BUSY.
  ///
  /// In ar, this message translates to:
  /// **'لهذا البث صاروخ زيارات يعمل أو في الدور.'**
  String get errorBoostRoomBusy;

  /// D154c: the newcomer badge in chat and the newcomers list.
  ///
  /// In ar, this message translates to:
  /// **'جديد 🌱'**
  String get liveNewcomerBadge;

  /// D154c: the newcomers sheet explanation.
  ///
  /// In ar, this message translates to:
  /// **'حسابات عمرها أقل من {days} يوماً، موجودة في البث الآن.'**
  String liveNewcomersHint(int days);

  /// D154c: empty newcomers list.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد جدد في البث الآن.'**
  String get liveNewcomersEmpty;

  /// D154c: newcomers failed to load.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الجدد'**
  String get liveNewcomersLoadError;

  /// D154c: send the ready welcome line.
  ///
  /// In ar, this message translates to:
  /// **'رحّب'**
  String get liveNewcomerWelcome;

  /// D154c: already welcomed.
  ///
  /// In ar, this message translates to:
  /// **'تم الترحيب ✓'**
  String get liveNewcomerWelcomed;

  /// D154c: the ready welcome chat line.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً @{username} 🌱 نوّرت البث'**
  String liveNewcomerWelcomeText(String username);

  /// D154d: the gifts' value in coins.
  ///
  /// In ar, this message translates to:
  /// **'قيمة الهدايا'**
  String get liveStatsGiftCoins;

  /// D154d: the host's share of the gifts (display only).
  ///
  /// In ar, this message translates to:
  /// **'أرباحك (عرض فقط)'**
  String get liveStatsEarnings;

  /// D154d: a live time.
  ///
  /// In ar, this message translates to:
  /// **'{hours} س {minutes} د'**
  String liveDataDuration(int hours, int minutes);

  /// D154d: load failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل مركز البيانات'**
  String get liveDataLoadError;

  /// D154d: number of lives.
  ///
  /// In ar, this message translates to:
  /// **'البثوث'**
  String get liveDataLives;

  /// D154d: total live time.
  ///
  /// In ar, this message translates to:
  /// **'مدة البث'**
  String get liveDataLiveTime;

  /// D154d: follower growth.
  ///
  /// In ar, this message translates to:
  /// **'متابعون جدد'**
  String get liveDataNewFollowers;

  /// D154d: unique viewers summed over lives.
  ///
  /// In ar, this message translates to:
  /// **'المشاهدون'**
  String get liveDataViewers;

  /// D154d: the bar chart title.
  ///
  /// In ar, this message translates to:
  /// **'مدة البث عبر الوقت'**
  String get liveDataChartTitle;

  /// D154d: empty period.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بثوث منتهية في هذه الفترة.'**
  String get liveDataEmpty;

  /// D154d: the heatmap title.
  ///
  /// In ar, this message translates to:
  /// **'أفضل الأوقات'**
  String get liveDataBestHours;

  /// D154d: heatmap for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'أفضل وقت: {day} الساعة {hour}'**
  String liveDataBestHourSemantics(String day, int hour);

  /// D154d: period.
  ///
  /// In ar, this message translates to:
  /// **'يوم'**
  String get liveDataPeriodDay;

  /// D154d: period.
  ///
  /// In ar, this message translates to:
  /// **'أسبوع'**
  String get liveDataPeriodWeek;

  /// D154d: period.
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get liveDataPeriodMonth;

  /// D154d: period.
  ///
  /// In ar, this message translates to:
  /// **'سنة'**
  String get liveDataPeriodYear;

  /// D154d: the data center's scope.
  ///
  /// In ar, this message translates to:
  /// **'بثوثك المنتهية فقط؛ البث الجاري يُحسب عند انتهائه.'**
  String get liveDataHint;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'إثنين'**
  String get liveDataMon;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'ثلاثاء'**
  String get liveDataTue;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'أربعاء'**
  String get liveDataWed;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'خميس'**
  String get liveDataThu;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'جمعة'**
  String get liveDataFri;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'سبت'**
  String get liveDataSat;

  /// D154d: weekday.
  ///
  /// In ar, this message translates to:
  /// **'أحد'**
  String get liveDataSun;

  /// D154e: the live's program (card, list and editor title).
  ///
  /// In ar, this message translates to:
  /// **'قائمة البرامج'**
  String get liveProgramTitle;

  /// D154e: the label of the segment on now.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get liveProgramNow;

  /// D154e: the label of the next segment before the first one starts.
  ///
  /// In ar, this message translates to:
  /// **'التالي {time}'**
  String liveProgramNext(String time);

  /// D154e: shown on the card for a few seconds when a segment begins.
  ///
  /// In ar, this message translates to:
  /// **'بدأت الفقرة'**
  String get liveProgramStarted;

  /// D154e: the card's tap hint for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'عرض قائمة البرامج'**
  String get liveProgramOpenHint;

  /// D154e: the list when the host set none.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فقرات بعد'**
  String get liveProgramEmpty;

  /// D154e: the editor's explanation.
  ///
  /// In ar, this message translates to:
  /// **'حتى 10 فقرات. يراها الجميع في الغرفة ويُعلَن عن كل فقرة عند بدايتها.'**
  String get liveProgramEditorHint;

  /// D154e: the title field's hint.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الفقرة'**
  String get liveProgramTitleHint;

  /// D154e: the start time button for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'وقت البداية {time}، غيّره'**
  String liveProgramTimeLabel(String time);

  /// D154e: adds a row to the program.
  ///
  /// In ar, this message translates to:
  /// **'أضف فقرة'**
  String get liveProgramAdd;

  /// D154e: removes a row.
  ///
  /// In ar, this message translates to:
  /// **'احذف الفقرة'**
  String get liveProgramRemove;

  /// D154e: saves the whole program.
  ///
  /// In ar, this message translates to:
  /// **'حفظ القائمة'**
  String get liveProgramSave;

  /// D154e: the starts are not ascending.
  ///
  /// In ar, this message translates to:
  /// **'رتّب الفقرات حسب وقت بدايتها'**
  String get liveProgramOrderError;

  /// D154f assistant hint: one person joined.
  ///
  /// In ar, this message translates to:
  /// **'رحّب بـ {name}، انضم للتو'**
  String liveAssistantWelcomeOne(String name);

  /// D154f assistant hint: several joined.
  ///
  /// In ar, this message translates to:
  /// **'رحّب بـ {name} و{count} آخرين انضموا للتو'**
  String liveAssistantWelcomeMany(String name, int count);

  /// D154f assistant hint: a big gift.
  ///
  /// In ar, this message translates to:
  /// **'اشكر {name} على هدية بقيمة {coins} عملة'**
  String liveAssistantThank(String name, String coins);

  /// D154f assistant hint: the host is quiet (microphone on).
  ///
  /// In ar, this message translates to:
  /// **'لم تتكلم منذ {minutes} دقائق، قل شيئاً للحضور'**
  String liveAssistantSilence(int minutes);

  /// D154f assistant hint: viewers rising.
  ///
  /// In ar, this message translates to:
  /// **'الحضور يزداد: من {before} إلى {now}. استمر'**
  String liveAssistantRising(int before, int now);

  /// D154f assistant hint: viewers falling.
  ///
  /// In ar, this message translates to:
  /// **'الحضور يقل: من {before} إلى {now}. جرّب فقرة جديدة أو سؤالاً'**
  String liveAssistantFalling(int before, int now);

  /// D154f assistant hint: a long live.
  ///
  /// In ar, this message translates to:
  /// **'أنت على الهواء منذ {hours} ساعات، خذ استراحة قصيرة'**
  String liveAssistantRest(int hours);

  /// D154f assistant hint: few chat messages.
  ///
  /// In ar, this message translates to:
  /// **'الدردشة هادئة، اطرح سؤالاً على الحضور'**
  String get liveAssistantQuestion;

  /// D154f: the hint's tap hint for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get liveAssistantDismiss;

  /// D154f: the settings' explanation.
  ///
  /// In ar, this message translates to:
  /// **'تلميحات خفيفة تظهر لك وحدك أثناء البث، من أحداث الغرفة فقط. لا يُرسل شيء.'**
  String get liveAssistantAbout;

  /// D154f: the master switch.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل المساعد'**
  String get liveAssistantOn;

  /// D154f: a hint kind.
  ///
  /// In ar, this message translates to:
  /// **'الترحيب بالقادمين'**
  String get liveAssistantKindWelcome;

  /// D154f: a hint kind.
  ///
  /// In ar, this message translates to:
  /// **'الشكر على الهدايا الكبيرة'**
  String get liveAssistantKindThank;

  /// D154f: a hint kind.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه عند الصمت'**
  String get liveAssistantKindSilence;

  /// D154f: a hint kind.
  ///
  /// In ar, this message translates to:
  /// **'زيادة أو نقص الحضور'**
  String get liveAssistantKindAudience;

  /// D154f: a hint kind.
  ///
  /// In ar, this message translates to:
  /// **'استراحة في البث الطويل'**
  String get liveAssistantKindRest;

  /// D154f: a hint kind.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح سؤال عند هدوء الدردشة'**
  String get liveAssistantKindQuestion;

  /// D154g Room Tools: the picture quality and the connection (replaces HD and Fluent).
  ///
  /// In ar, this message translates to:
  /// **'الجودة'**
  String get liveToolQuality;

  /// D154g: 480p at 15 fps.
  ///
  /// In ar, this message translates to:
  /// **'سلس'**
  String get liveQualitySmooth;

  /// D154g: smooth option detail.
  ///
  /// In ar, this message translates to:
  /// **'480p، أخف على الاتصال الضعيف'**
  String get liveQualitySmoothDetail;

  /// D154g: 720p (default).
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get liveQualityNormal;

  /// D154g: normal option detail.
  ///
  /// In ar, this message translates to:
  /// **'720p، الجودة الافتراضية'**
  String get liveQualityNormalDetail;

  /// D154g: connection indicator.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال ممتاز'**
  String get liveQualityConnExcellent;

  /// D154g: connection indicator.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال جيد'**
  String get liveQualityConnGood;

  /// D154g: connection indicator.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال ضعيف'**
  String get liveQualityConnPoor;

  /// D154g: connection indicator.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال، جارٍ إعادة المحاولة'**
  String get liveQualityConnLost;

  /// D154g: connection indicator before LiveKit rates it.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ قياس الاتصال'**
  String get liveQualityConnUnknown;

  /// D154g: the camera could not restart.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تغيير الجودة، بقيت كما كانت'**
  String get liveQualityFailed;

  /// D154g: suggestion after a weak connection for a while.
  ///
  /// In ar, this message translates to:
  /// **'اتصالك ضعيف، فعّل السلاسة؟'**
  String get liveQualitySuggest;

  /// D154g: the suggestion's action.
  ///
  /// In ar, this message translates to:
  /// **'فعّل'**
  String get liveQualitySuggestAction;

  /// D160: 1080p at 30 fps (only where the camera captures it).
  ///
  /// In ar, this message translates to:
  /// **'عالي 1080p'**
  String get liveQualityHigh;

  /// D160: high option detail.
  ///
  /// In ar, this message translates to:
  /// **'1080p بـ 30 إطاراً، يعود إلى 720p تلقائياً إذا ضعف الاتصال'**
  String get liveQualityHighDetail;

  /// D160: high option disabled: the measured uplink is below ~4 Mbps.
  ///
  /// In ar, this message translates to:
  /// **'سرعة الرفع الآن أقل من المطلوب لـ 1080p'**
  String get liveQualityHighSlowUplink;

  /// D160: the camera delivered less than 1080p after switching.
  ///
  /// In ar, this message translates to:
  /// **'هذه الكاميرا لا تلتقط 1080p، بقيت الجودة كما كانت'**
  String get liveQualityHighUnsupported;

  /// D160: 1080p fell back to 720p after a weak connection.
  ///
  /// In ar, this message translates to:
  /// **'تم خفض الجودة لضعف الاتصال'**
  String get liveQualityHighFallback;

  /// D154g: after switching from the suggestion.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل السلاسة'**
  String get liveQualitySmoothOn;

  /// D154h: the sticker sheet's explanation.
  ///
  /// In ar, this message translates to:
  /// **'حتى 3 ملصقات يراها الجميع. اسحب الملصق على البث لتحريكه، وبإصبعين لتكبيره وتدويره.'**
  String get liveStickersHint;

  /// D154h: the stickers placed now.
  ///
  /// In ar, this message translates to:
  /// **'على البث ({count} من {max})'**
  String liveStickersOnLive(int count, int max);

  /// D154h: none placed.
  ///
  /// In ar, this message translates to:
  /// **'لا ملصقات بعد'**
  String get liveStickersNone;

  /// D154h: the limit is reached.
  ///
  /// In ar, this message translates to:
  /// **'3 ملصقات كحد أقصى، احذف واحداً لإضافة غيره'**
  String get liveStickersFull;

  /// D154h: removes one sticker.
  ///
  /// In ar, this message translates to:
  /// **'احذف الملصق'**
  String get liveStickersRemove;

  /// D154h: the text sticker field.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ملصقاً نصياً'**
  String get liveStickersTextHint;

  /// D154h: adds the text sticker.
  ///
  /// In ar, this message translates to:
  /// **'أضف'**
  String get liveStickersAddText;

  /// Error YOUTUBE_VIDEO_UNAVAILABLE.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تشغيل هذا الفيديو هنا، قد يكون خاصاً أو ممنوعاً من التشغيل خارج يوتيوب.'**
  String get errorYoutubeVideoUnavailable;

  /// Error YOUTUBE_SEARCH_UNAVAILABLE.
  ///
  /// In ar, this message translates to:
  /// **'البحث في يوتيوب غير مفعّل بعد، الصق رابط الفيديو.'**
  String get errorYoutubeSearchUnavailable;

  /// D154i: the watch-together sheet title.
  ///
  /// In ar, this message translates to:
  /// **'يوتيوب'**
  String get liveWatchTitle;

  /// D154i: the link field.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط فيديو يوتيوب'**
  String get liveWatchLinkHint;

  /// D154i: the host starts the pasted video.
  ///
  /// In ar, this message translates to:
  /// **'شاهدوا معاً'**
  String get liveWatchPlay;

  /// D154i: the search field.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في يوتيوب'**
  String get liveWatchSearchHint;

  /// D154i: no server key.
  ///
  /// In ar, this message translates to:
  /// **'البحث غير مفعّل بعد، الصق رابطاً'**
  String get liveWatchSearchOff;

  /// D154i: the current video label.
  ///
  /// In ar, this message translates to:
  /// **'يُعرض الآن'**
  String get liveWatchNowPlaying;

  /// D154i: the host stops watch-together.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف العرض'**
  String get liveWatchStop;

  /// D154i: the host's list.
  ///
  /// In ar, this message translates to:
  /// **'اقتراحات المشاهدين ({count})'**
  String liveWatchSuggestions(int count);

  /// D154i: none waiting.
  ///
  /// In ar, this message translates to:
  /// **'لا اقتراحات الآن'**
  String get liveWatchNoSuggestions;

  /// D154i: plays a suggestion.
  ///
  /// In ar, this message translates to:
  /// **'اعرضه'**
  String get liveWatchApprove;

  /// D154i: turns a suggestion down.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get liveWatchReject;

  /// D154i: who suggested.
  ///
  /// In ar, this message translates to:
  /// **'اقترحه {name}'**
  String liveWatchSuggestedBy(String name);

  /// D154i: a viewer's button on the player.
  ///
  /// In ar, this message translates to:
  /// **'اقترح فيديو'**
  String get liveWatchSuggest;

  /// D154i: sends a viewer's suggestion.
  ///
  /// In ar, this message translates to:
  /// **'أرسل الاقتراح'**
  String get liveWatchSuggestSend;

  /// D154i: after a suggestion.
  ///
  /// In ar, this message translates to:
  /// **'وصل اقتراحك للمضيف'**
  String get liveWatchSuggestSent;

  /// D154i: a link that is not YouTube.
  ///
  /// In ar, this message translates to:
  /// **'هذا ليس رابط فيديو يوتيوب'**
  String get liveWatchBadLink;

  /// D154i: a viewer hides the player on their phone.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الفيديو'**
  String get liveWatchHide;

  /// D154i: shows the hidden player.
  ///
  /// In ar, this message translates to:
  /// **'عرض الفيديو'**
  String get liveWatchShow;

  /// D160: the watch window's drag handle (video lives).
  ///
  /// In ar, this message translates to:
  /// **'اسحب لنقل نافذة الفيديو'**
  String get liveWatchDrag;

  /// D154i: the embedded player failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الفيديو على هذا الهاتف'**
  String get liveWatchPlayerError;

  /// D154i: the host is told of a suggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح جديد: {title}'**
  String liveWatchNewSuggestion(String title);

  /// D159: the label of the sapphire win banner (x5 to x25).
  ///
  /// In ar, this message translates to:
  /// **'فوز'**
  String get liveWinTierWin;

  /// D159: the label of the amethyst win banner (x250).
  ///
  /// In ar, this message translates to:
  /// **'فوز ضخم'**
  String get liveWinTierHuge;

  /// D159: what screen readers hear for a win banner; coins is pre-formatted and isolated.
  ///
  /// In ar, this message translates to:
  /// **'{label}: {name} ربح ⁦×{multiplier}⁩، {coins} عملة'**
  String liveWinBannerSemantics(
    String label,
    String name,
    String multiplier,
    String coins,
  );

  /// D159 rev 2: the win banner's first line (the owner's «Oz Nabulsi أرسل عملة الحظ»); name and gift are drawn as separate pieces.
  ///
  /// In ar, this message translates to:
  /// **'{name} أرسل {gift}'**
  String liveWinBannerSent(String name, String gift);

  /// D159 rev 2: the win banner's second line (the owner's «ربح x100 وحصل على 17,500 🪙»); multiplier (×N) and coins are drawn as separate gold pieces, the coin icon follows.
  ///
  /// In ar, this message translates to:
  /// **'ربح {multiplier} وحصل على {coins}'**
  String liveWinBannerWon(String multiplier, String coins);

  /// D163: the Me hub (owner ref, Bigo-style layout). the avatar and name open the profile page
  ///
  /// In ar, this message translates to:
  /// **'افتح ملفك الشخصي'**
  String get meHubOpenProfile;

  /// D163: the Me hub (owner ref, Bigo-style layout). the followers count on the hub
  ///
  /// In ar, this message translates to:
  /// **'المعجبون'**
  String get meHubFans;

  /// D163: the Me hub (owner ref, Bigo-style layout). the levels card
  ///
  /// In ar, this message translates to:
  /// **'المستويات'**
  String get meHubLevels;

  /// D163: the Me hub (owner ref, Bigo-style layout). the VIP card (not built: Soon)
  ///
  /// In ar, this message translates to:
  /// **'شراء VIP'**
  String get meHubVip;

  /// D163: the Me hub (owner ref, Bigo-style layout). the host earnings card (not built: Soon)
  ///
  /// In ar, this message translates to:
  /// **'اربح المال'**
  String get meHubEarn;

  /// D163: the Me hub (owner ref, Bigo-style layout). row (not built: Soon)
  ///
  /// In ar, this message translates to:
  /// **'مركز صنّاع المحتوى'**
  String get meHubCreatorCenter;

  /// D163: the Me hub (owner ref, Bigo-style layout). row (not built: Soon)
  ///
  /// In ar, this message translates to:
  /// **'مركز الفعاليات'**
  String get meHubEventCenter;

  /// D163: the Me hub (owner ref, Bigo-style layout). row: the coin balance; no wallet screen yet (Soon)
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get meHubWallet;

  /// D163: the Me hub (owner ref, Bigo-style layout). row: opens the bag
  ///
  /// In ar, this message translates to:
  /// **'الحقيبة'**
  String get meHubItemBag;

  /// D168: the Me hub's top icon beside Settings (tooltip and screen-reader label); opens the profile page with posts, reels, reposts and saved
  ///
  /// In ar, this message translates to:
  /// **'ملفي الشخصي'**
  String get meHubMyProfile;

  /// D163: the Me hub (owner ref, Bigo-style layout). row (not built: Soon)
  ///
  /// In ar, this message translates to:
  /// **'SVIP'**
  String get meHubSvip;

  /// D163: the Me hub (owner ref, Bigo-style layout). row (not built: Soon)
  ///
  /// In ar, this message translates to:
  /// **'مركز المهام'**
  String get meHubTaskCenter;

  /// D163: the Me hub (owner ref, Bigo-style layout). row: opens the popularity board (CP-016 A)
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get meHubRanking;

  /// D163: the Me hub (owner ref, Bigo-style layout). screen readers: a button whose feature is not built yet
  ///
  /// In ar, this message translates to:
  /// **'{item}، قريباً'**
  String meHubSoonItem(String item);

  /// D163: the Me hub (owner ref, Bigo-style layout). screen readers: the wallet balance
  ///
  /// In ar, this message translates to:
  /// **'{coins} كوينز'**
  String meHubCoins(String coins);

  /// D162: the ➕ menu's title.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get createMenuTitle;

  /// D162: ➕ menu choice.
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get createMenuPost;

  /// D162: ➕ menu choice hint.
  ///
  /// In ar, this message translates to:
  /// **'صور أو فيديو أو نص'**
  String get createMenuPostHint;

  /// D162: ➕ menu choice.
  ///
  /// In ar, this message translates to:
  /// **'ريلز'**
  String get createMenuReel;

  /// D162: ➕ menu choice hint.
  ///
  /// In ar, this message translates to:
  /// **'فيديو عمودي قصير يظهر في لحظات'**
  String get createMenuReelHint;

  /// D162: ➕ menu choice.
  ///
  /// In ar, this message translates to:
  /// **'ستوري'**
  String get createMenuStory;

  /// D162: ➕ menu choice hint.
  ///
  /// In ar, this message translates to:
  /// **'صورة تبقى ٢٤ ساعة'**
  String get createMenuStoryHint;

  /// D162: ➕ menu choice.
  ///
  /// In ar, this message translates to:
  /// **'بث مباشر'**
  String get createMenuLive;

  /// D162: ➕ menu choice hint.
  ///
  /// In ar, this message translates to:
  /// **'فيديو أو صوت، الآن'**
  String get createMenuLiveHint;

  /// D162: the media step's note on the Video tab.
  ///
  /// In ar, this message translates to:
  /// **'فيديو واحد حتى ٩٠ ثانية'**
  String get createVideoUpTo;

  /// D162: a library video tile (semantics).
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get createLibraryVideo;

  /// D162: empty video grid.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فيديوهات على هذا الجهاز.'**
  String get createLibraryNoVideos;

  /// D162: the system video picker.
  ///
  /// In ar, this message translates to:
  /// **'اختيار فيديو'**
  String get createPickVideo;

  /// D162: removes the draft's video.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الفيديو'**
  String get createRemoveVideo;

  /// D162: the selected video and its length.
  ///
  /// In ar, this message translates to:
  /// **'فيديو، {length}'**
  String createVideoLabel(String length);

  /// D162: mixing photos and a video.
  ///
  /// In ar, this message translates to:
  /// **'يضم المنشور صوراً أو فيديو واحداً، وليس الاثنين معاً.'**
  String get createVideoOrPhotos;

  /// D162: post video limit (D168: 90 seconds, owner).
  ///
  /// In ar, this message translates to:
  /// **'يمكن أن تصل مدة فيديو المنشور إلى ٩٠ ثانية.'**
  String get createVideoTooLong;

  /// D162: post video size limit.
  ///
  /// In ar, this message translates to:
  /// **'حجم هذا الفيديو أكبر من ٢٠٠ ميغابايت.'**
  String get createVideoTooLarge;

  /// D162: minimum length.
  ///
  /// In ar, this message translates to:
  /// **'اختر فيديو مدته ثانية واحدة على الأقل.'**
  String get createVideoTooShort;

  /// D162: not MP4 / QuickTime.
  ///
  /// In ar, this message translates to:
  /// **'صيغة هذا الفيديو غير مدعومة. استخدم MP4 أو MOV.'**
  String get createVideoUnsupported;

  /// D162: the library could not open the file.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة هذا الفيديو على هذا الجهاز.'**
  String get createVideoUnreadable;

  /// D162: the server refused the video (MEDIA_INVALID).
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت معالجة الفيديو. جرّب فيديو آخر.'**
  String get createVideoInvalid;

  /// D162: MEDIA_UPLOADS_UNAVAILABLE for a video.
  ///
  /// In ar, this message translates to:
  /// **'رفع الفيديو غير متاح حالياً. حاول مرة أخرى لاحقاً.'**
  String get createVideoUploadsUnavailable;

  /// D162: video upload progress.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ رفع الفيديو… {percent}٪'**
  String createUploadingVideo(int percent);

  /// D162: a video post waits for moderation.
  ///
  /// In ar, this message translates to:
  /// **'تم النشر. سيظهر للآخرين بعد مراجعة الفيديو'**
  String get createPostedVideoInReview;

  /// D162: the reel screen.
  ///
  /// In ar, this message translates to:
  /// **'ريلز جديد'**
  String get reelNewTitle;

  /// D162: the reel screen.
  ///
  /// In ar, this message translates to:
  /// **'فيديو عمودي حتى ٦٠ ثانية، يظهر في لحظات.'**
  String get reelNewBody;

  /// D162: picks the reel's video.
  ///
  /// In ar, this message translates to:
  /// **'اختيار فيديو'**
  String get reelPickVideo;

  /// D162: picks another video.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الفيديو'**
  String get reelChangeVideo;

  /// D162: the reel caption.
  ///
  /// In ar, this message translates to:
  /// **'اكتب وصفاً… #وسوم @إشارات'**
  String get reelCaptionHint;

  /// D162: shares the reel.
  ///
  /// In ar, this message translates to:
  /// **'نشر'**
  String get reelShare;

  /// D162: the reel was created.
  ///
  /// In ar, this message translates to:
  /// **'تم نشر الريلز'**
  String get reelShared;

  /// D162: a reel waits for moderation.
  ///
  /// In ar, this message translates to:
  /// **'تم النشر. سيظهر الريلز للآخرين بعد مراجعته'**
  String get reelSharedInReview;

  /// D162: reel length limit.
  ///
  /// In ar, this message translates to:
  /// **'يمكن أن تصل مدة الريلز إلى ٦٠ ثانية.'**
  String get reelTooLong;

  /// D162: reel size limit.
  ///
  /// In ar, this message translates to:
  /// **'حجم هذا الفيديو أكبر من ١٠٠ ميغابايت.'**
  String get reelTooLarge;

  /// D162: a landscape reel.
  ///
  /// In ar, this message translates to:
  /// **'تبدو الريلز أفضل عمودية؛ سيظهر هذا الفيديو بأشرطة.'**
  String get reelVertical;

  /// D162: the preview (semantics).
  ///
  /// In ar, this message translates to:
  /// **'أول لقطة من الريلز'**
  String get reelPreview;

  /// D162: the inline player.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الفيديو'**
  String get videoPlay;

  /// D162: the inline player.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الفيديو مؤقتاً'**
  String get videoPause;

  /// D162: the inline player.
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get videoMute;

  /// D162: the inline player.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الصوت'**
  String get videoUnmute;

  /// D162: the inline player failed.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تشغيل هذا الفيديو الآن'**
  String get videoCannotPlay;

  /// D174a: a seated guest's own camera toggle on the viewer bar (camera on).
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get liveGuestCamera;

  /// D174a: the same toggle while the guest's camera is off (the others see their picture).
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا مطفأة'**
  String get liveGuestCameraOff;

  /// D181: a viewer's floating window of a minimized live (tap: open it again).
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى البث'**
  String get liveMiniOpen;

  /// D181: ✕ on a viewer's floating window: leaves the live.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة البث'**
  String get liveMiniLeave;

  /// D164: the wallet's balance card.
  ///
  /// In ar, this message translates to:
  /// **'رصيد الكوينز'**
  String get walletBalanceLabel;

  /// D164: the recharge button (disabled, Soon).
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get walletRecharge;

  /// D164: why recharge is not available.
  ///
  /// In ar, this message translates to:
  /// **'الشحن قريباً — لم تُحدَّد طريقة الدفع بعد.'**
  String get walletRechargeSoon;

  /// D164: the ledger section.
  ///
  /// In ar, this message translates to:
  /// **'سجل المعاملات'**
  String get walletHistoryTitle;

  /// D164: empty ledger title.
  ///
  /// In ar, this message translates to:
  /// **'لا معاملات بعد'**
  String get walletHistoryEmpty;

  /// D164: empty ledger message.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا كل عملية تغيّر رصيدك.'**
  String get walletHistoryEmptyBody;

  /// D164: ledger load failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المحفظة'**
  String get walletLoadError;

  /// D164: the balance after one change.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعدها {coins}'**
  String walletBalanceAfter(String coins);

  /// D164: ledger reason ADMIN_GRANT.
  ///
  /// In ar, this message translates to:
  /// **'منحة من الفريق'**
  String get walletReasonAdminGrant;

  /// D164: ledger reason ADMIN_REVOKE.
  ///
  /// In ar, this message translates to:
  /// **'سحب من الفريق'**
  String get walletReasonAdminRevoke;

  /// D164: ledger reason BULLET_MESSAGE.
  ///
  /// In ar, this message translates to:
  /// **'رسالة عامة'**
  String get walletReasonBulletMessage;

  /// D164: ledger reason FAMILY_CREATE.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء عائلة'**
  String get walletReasonFamilyCreate;

  /// D164: ledger reason CP_REQUEST.
  ///
  /// In ar, this message translates to:
  /// **'طلب CP'**
  String get walletReasonCpRequest;

  /// D164: ledger reason CP_REFUND.
  ///
  /// In ar, this message translates to:
  /// **'استرداد طلب CP'**
  String get walletReasonCpRefund;

  /// D164: ledger reason CP_GIFT.
  ///
  /// In ar, this message translates to:
  /// **'هدية CP'**
  String get walletReasonCpGift;

  /// D164: ledger reason LIVE_GIFT.
  ///
  /// In ar, this message translates to:
  /// **'هدية في بث'**
  String get walletReasonLiveGift;

  /// D164: ledger reason LUCKY_GIFT.
  ///
  /// In ar, this message translates to:
  /// **'هدية الحظ'**
  String get walletReasonLuckyGift;

  /// D164: ledger reason LUCKY_GIFT_WIN.
  ///
  /// In ar, this message translates to:
  /// **'ربح من هدية الحظ'**
  String get walletReasonLuckyGiftWin;

  /// D164: ledger reason PREMIUM_USERNAME_RENT.
  ///
  /// In ar, this message translates to:
  /// **'استئجار اسم مميز'**
  String get walletReasonPremiumRent;

  /// D164: ledger reason PREMIUM_USERNAME_RENEW.
  ///
  /// In ar, this message translates to:
  /// **'تجديد اسم مميز'**
  String get walletReasonPremiumRenew;

  /// D164: ledger reason DM_GIFT.
  ///
  /// In ar, this message translates to:
  /// **'هدية في محادثة'**
  String get walletReasonDmGift;

  /// D164: ledger reason LIVE_BOOST.
  ///
  /// In ar, this message translates to:
  /// **'صاروخ زيارات'**
  String get walletReasonLiveBoost;

  /// D164: ledger reason LIVE_BOOST_REFUND.
  ///
  /// In ar, this message translates to:
  /// **'استرداد صاروخ زيارات'**
  String get walletReasonLiveBoostRefund;

  /// D164: a ledger reason this app does not know.
  ///
  /// In ar, this message translates to:
  /// **'تغيير في الرصيد'**
  String get walletReasonOther;

  /// D164: earnings total card.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي أرباحك'**
  String get earnTotal;

  /// D164: earnings of the last 7 days.
  ///
  /// In ar, this message translates to:
  /// **'آخر 7 أيام'**
  String get earnLast7Days;

  /// D164: earnings of the last 30 days.
  ///
  /// In ar, this message translates to:
  /// **'آخر 30 يوماً'**
  String get earnLast30Days;

  /// D164: what earnings are.
  ///
  /// In ar, this message translates to:
  /// **'الأرباح للعرض فقط: هي حصتك من الهدايا التي تصلك في البث والمحادثات، ولا تُضاف إلى رصيد الكوينز.'**
  String get earnDisplayOnly;

  /// D164: the withdraw button (disabled, Soon).
  ///
  /// In ar, this message translates to:
  /// **'سحب الأرباح'**
  String get earnWithdraw;

  /// D164: why withdrawal is not available (D149).
  ///
  /// In ar, this message translates to:
  /// **'السحب قريباً — لم تُحدَّد طريقة الدفع بعد.'**
  String get earnWithdrawSoon;

  /// D164: the earnings history section.
  ///
  /// In ar, this message translates to:
  /// **'سجل الأرباح'**
  String get earnHistoryTitle;

  /// D164: no earnings title.
  ///
  /// In ar, this message translates to:
  /// **'لا أرباح بعد'**
  String get earnEmpty;

  /// D164: no earnings message.
  ///
  /// In ar, this message translates to:
  /// **'عندما تصلك هدايا في البث أو المحادثات تظهر حصتك منها هنا.'**
  String get earnEmptyBody;

  /// D164: earnings load failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الأرباح'**
  String get earnLoadError;

  /// D164: one earning's gift and quantity.
  ///
  /// In ar, this message translates to:
  /// **'{gift} × {quantity}'**
  String earnGiftLine(String gift, int quantity);

  /// D164: who sent the gift.
  ///
  /// In ar, this message translates to:
  /// **'من {name}'**
  String earnFrom(String name);

  /// D164: the sender is hidden (inactive or blocked).
  ///
  /// In ar, this message translates to:
  /// **'من حساب غير متاح'**
  String get earnFromHidden;

  /// D164: the gift was sent in a live.
  ///
  /// In ar, this message translates to:
  /// **'في بث'**
  String get earnContextLive;

  /// D164: the gift was sent in a chat.
  ///
  /// In ar, this message translates to:
  /// **'في محادثة'**
  String get earnContextDm;

  /// D164: the share of one send.
  ///
  /// In ar, this message translates to:
  /// **'حصتك {percent}٪ من {coins}'**
  String earnShare(String percent, String coins);

  /// D164: creator center period.
  ///
  /// In ar, this message translates to:
  /// **'7 أيام'**
  String get creatorPeriod7;

  /// D164: creator center period.
  ///
  /// In ar, this message translates to:
  /// **'30 يوماً'**
  String get creatorPeriod30;

  /// D164: creator center period.
  ///
  /// In ar, this message translates to:
  /// **'كل الوقت'**
  String get creatorPeriodAll;

  /// D164: creator center section.
  ///
  /// In ar, this message translates to:
  /// **'المتابعون'**
  String get creatorFollowers;

  /// D164: followers now.
  ///
  /// In ar, this message translates to:
  /// **'كل المتابعين'**
  String get creatorFollowersTotal;

  /// D164: follows made in the period that still stand.
  ///
  /// In ar, this message translates to:
  /// **'تابعوك في هذه الفترة'**
  String get creatorFollowersNew;

  /// D164: creator center section.
  ///
  /// In ar, this message translates to:
  /// **'المنشورات'**
  String get creatorPosts;

  /// D164: creator center section.
  ///
  /// In ar, this message translates to:
  /// **'الريلز'**
  String get creatorReels;

  /// D164: published in the period.
  ///
  /// In ar, this message translates to:
  /// **'منشورة'**
  String get creatorPublished;

  /// D164: views.
  ///
  /// In ar, this message translates to:
  /// **'المشاهدات'**
  String get creatorViews;

  /// D164: likes.
  ///
  /// In ar, this message translates to:
  /// **'الإعجابات'**
  String get creatorLikes;

  /// D164: comments.
  ///
  /// In ar, this message translates to:
  /// **'التعليقات'**
  String get creatorComments;

  /// D164: shares.
  ///
  /// In ar, this message translates to:
  /// **'المشاركات'**
  String get creatorShares;

  /// D164: how post numbers are counted.
  ///
  /// In ar, this message translates to:
  /// **'ما نُشر في هذه الفترة، بأرقامه حتى الآن.'**
  String get creatorContentHint;

  /// D164: empty content section.
  ///
  /// In ar, this message translates to:
  /// **'لم تنشر شيئاً في هذه الفترة.'**
  String get creatorNoPosts;

  /// D164: creator center section.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر'**
  String get creatorLive;

  /// D164: how lives are counted.
  ///
  /// In ar, this message translates to:
  /// **'البثوث التي بدأت في هذه الفترة وانتهت.'**
  String get creatorLiveHint;

  /// D164: empty live section.
  ///
  /// In ar, this message translates to:
  /// **'لا بثوث منتهية في هذه الفترة.'**
  String get creatorNoLives;

  /// D164: the most viewers at once.
  ///
  /// In ar, this message translates to:
  /// **'أعلى مشاهدة'**
  String get creatorPeakViewers;

  /// D164: link to the own profile grid.
  ///
  /// In ar, this message translates to:
  /// **'منشوراتي وريلزي'**
  String get creatorOpenProfile;

  /// D172: Creator Center tab.
  ///
  /// In ar, this message translates to:
  /// **'البث'**
  String get creatorTabLive;

  /// D172: Creator Center tab (host agencies; not built).
  ///
  /// In ar, this message translates to:
  /// **'الوكالة'**
  String get creatorTabAgency;

  /// D172: the stats card's title; month is the month's name (this month so far).
  ///
  /// In ar, this message translates to:
  /// **'بيانات {month}'**
  String creatorMonthData(String month);

  /// D172: link to (and title of) the detailed statistics.
  ///
  /// In ar, this message translates to:
  /// **'بيانات البث'**
  String get creatorLiveData;

  /// D172: minutes live this month.
  ///
  /// In ar, this message translates to:
  /// **'دقائق البث'**
  String get creatorLiveMinutes;

  /// D172: follows made this month that still stand.
  ///
  /// In ar, this message translates to:
  /// **'متابعون جدد'**
  String get creatorNewFans;

  /// D172: the host's share of gifts in this month's lives (display only).
  ///
  /// In ar, this message translates to:
  /// **'أرباح جديدة'**
  String get creatorNewEarnings;

  /// D172: the services grid's title.
  ///
  /// In ar, this message translates to:
  /// **'خدمات البث'**
  String get creatorServices;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'معاينة البث'**
  String get creatorSvcPreview;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الغلاف'**
  String get creatorSvcCover;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'فعالياتي'**
  String get creatorSvcEvents;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'مستوى المضيف'**
  String get creatorSvcHostLevel;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'مخالفات الحساب'**
  String get creatorSvcViolations;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'أكاديمية المضيف'**
  String get creatorSvcAcademy;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'خدمة العملاء'**
  String get creatorSvcSupport;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'توثيق الهوية'**
  String get creatorSvcIdentity;

  /// D172: service tile.
  ///
  /// In ar, this message translates to:
  /// **'نمو المتابعين'**
  String get creatorSvcFans;

  /// D172: where the traffic card is bought.
  ///
  /// In ar, this message translates to:
  /// **'تشتري صاروخ الزيارات من «أدوات الغرفة» أثناء بثك.'**
  String get creatorTrafficHint;

  /// D172: the floating button.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البث'**
  String get creatorGoLive;

  /// D164: creator stats load failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الإحصاءات'**
  String get creatorLoadError;

  /// D165: the search button of the conversation list.
  ///
  /// In ar, this message translates to:
  /// **'بحث في المحادثات'**
  String get dmSearch;

  /// D165: the hint of the conversation search field.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو اسم المستخدم'**
  String get dmSearchHint;

  /// D165: closes the conversation search.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق البحث'**
  String get dmSearchClose;

  /// D165: no conversation matches the search.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محادثة تطابق «{query}»'**
  String dmSearchEmpty(String query);

  /// D165: the hint of the new-message person search.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الشخص أو اسم المستخدم'**
  String get dmNewMessageHint;

  /// D165: the new-message search found nobody.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد أحداً بهذا الاسم'**
  String get dmNewMessageEmpty;

  /// D165: the new-message sheet before a search.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن شخص لتبدأ محادثة معه'**
  String get dmNewMessageStart;

  /// D165: the long-press menu of a conversation row (semantics hint).
  ///
  /// In ar, this message translates to:
  /// **'خيارات المحادثة'**
  String get dmConversationActions;

  /// D165: marks a conversation read from the list.
  ///
  /// In ar, this message translates to:
  /// **'تعليم كمقروءة'**
  String get dmMarkRead;

  /// D165: marks a conversation unread (markDmUnread).
  ///
  /// In ar, this message translates to:
  /// **'تعليم كغير مقروءة'**
  String get dmMarkUnread;

  /// D165: semantics of a row marked unread.
  ///
  /// In ar, this message translates to:
  /// **'معلّمة كغير مقروءة'**
  String get dmMarkedUnread;

  /// D165: copies a text message (long press).
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get dmCopy;

  /// D165: a text message was copied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الرسالة'**
  String get dmCopied;

  /// D165: the chat header opens the person's profile.
  ///
  /// In ar, this message translates to:
  /// **'عرض الملف الشخصي'**
  String get dmViewProfile;

  /// D165: the microphone of a composer that cannot record here (replaces «قريباً»).
  ///
  /// In ar, this message translates to:
  /// **'الرسائل الصوتية غير متاحة على هذا الجهاز'**
  String get chatVoiceUnavailable;

  /// D168: the sheet title of «تغيير الصورة» in edit profile.
  ///
  /// In ar, this message translates to:
  /// **'صورة الملف الشخصي'**
  String get profileEditPhotoSheetTitle;

  /// D168: photo sheet choice: the system photo picker.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من الصور'**
  String get profileEditPhotoLibrary;

  /// D168: photo sheet choice: the camera.
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة'**
  String get profileEditPhotoCamera;

  /// D168: photo sheet choice: back to the initial.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الصورة'**
  String get profileEditPhotoRemove;

  /// D168: snack after the profile photo changed.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث صورتك'**
  String get profileEditPhotoUpdated;

  /// D168: snack after the profile photo was removed.
  ///
  /// In ar, this message translates to:
  /// **'تمت إزالة صورتك'**
  String get profileEditPhotoRemoved;

  /// D168: under the photo (and its screen-reader label) while it uploads.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ رفع الصورة…'**
  String get profileEditPhotoUploading;

  /// D168: the square crop screen's title.
  ///
  /// In ar, this message translates to:
  /// **'قص الصورة'**
  String get profileEditCropTitle;

  /// D168: the crop screen's hint (and the photo's screen-reader label).
  ///
  /// In ar, this message translates to:
  /// **'اسحب الصورة وكبّرها لتملأ المربع'**
  String get profileEditCropHint;

  /// D168: the crop screen's confirm button.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get profileEditCropDone;

  /// D168: snack after the name or bio was saved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get profileEditSaved;

  /// D168: the empty bio row and the bio field's hint.
  ///
  /// In ar, this message translates to:
  /// **'أضف نبذة عنك'**
  String get profileEditBioPlaceholder;

  /// D168: the bio is too long (characters or lines).
  ///
  /// In ar, this message translates to:
  /// **'يمكن أن تصل النبذة إلى {max} حرف و{lines} أسطر.'**
  String profileEditBioTooLong(int max, int lines);

  /// D168: the server refused a character in the bio.
  ///
  /// In ar, this message translates to:
  /// **'تحتوي النبذة على رموز غير مسموح بها.'**
  String get profileEditBioInvalid;

  /// D168: under the name field.
  ///
  /// In ar, this message translates to:
  /// **'يظهر اسمك في ملفك وفي البث والرسائل. يمكن أن يتكرر بين الحسابات.'**
  String get profileEditNameHelp;

  /// D168: under the bio field.
  ///
  /// In ar, this message translates to:
  /// **'تظهر النبذة للجميع في ملفك الشخصي.'**
  String get profileEditBioHelp;

  /// D168: screen-reader label of a library video longer than the limit (90 s for posts, 60 s for reels).
  ///
  /// In ar, this message translates to:
  /// **'فيديو، {length}، أطول من {seconds} ثانية، لا يمكن استخدامه'**
  String createLibraryVideoTooLong(String length, int seconds);

  /// D166: tasks failed to load.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المهام'**
  String get tasksLoadError;

  /// D176: the sign-in card's link to the 7-day calendar sheet.
  ///
  /// In ar, this message translates to:
  /// **'التقويم'**
  String get tasksCheckInCalendar;

  /// D176: sign-ins still needed for the 7th-day bonus (computed by the server's cycle).
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{سجّل يوماً إضافياً لتحصل على مكافأة إضافية} =2{سجّل يومين إضافيين لتحصل على مكافأة إضافية} few{سجّل {days} أيام إضافية لتحصل على مكافأة إضافية} other{سجّل {days} يوماً إضافياً لتحصل على مكافأة إضافية}}'**
  String tasksCheckInMoreDays(int days);

  /// D176: the 7-day sign-in calendar sheet.
  ///
  /// In ar, this message translates to:
  /// **'تقويم تسجيل الدخول'**
  String get tasksCalendarTitle;

  /// D176: the sign-in calendar sheet's rule line.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول كل يوم: اليوم السابع على التوالي يمنحك {coins} عملة إضافية، ويوم فائت يعيد العدّ.'**
  String tasksCalendarBody(String coins);

  /// D176: a day's coins in the sign-in calendar sheet.
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة'**
  String tasksDayCoins(String coins);

  /// D176: the Event Center page title (the reference's «Activities»).
  ///
  /// In ar, this message translates to:
  /// **'الفعاليات'**
  String get eventsTitle;

  /// D166: the check-in section.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت تسجيل الدخول'**
  String get tasksCheckInTitle;

  /// D166: the 7th day of the streak is today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم يوم المكافأة: {coins} عملة إضافية'**
  String tasksCheckInBonusToday(String coins);

  /// D166: the check-in button.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل'**
  String get tasksCheckInAction;

  /// D166: the check-in streak.
  ///
  /// In ar, this message translates to:
  /// **'{days} أيام متتالية'**
  String tasksStreak(String days);

  /// D166: today's slot of the check-in strip.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get tasksToday;

  /// D166; D184: the daily cap of task cherries (task rewards are cherries).
  ///
  /// In ar, this message translates to:
  /// **'مكافآت اليوم: {earned} من {cap} كرزة'**
  String tasksDailyCap(String earned, String cap);

  /// D188: the calendar month's cap of task cherries (daily and weekly tasks), under the daily line.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت الشهر: {earned} من {cap} كرزة'**
  String tasksMonthlyCap(String earned, String cap);

  /// D166: the daily task list.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت المهام'**
  String get tasksRewardsTitle;

  /// D166: the weekly task list.
  ///
  /// In ar, this message translates to:
  /// **'مهام المضيف الأسبوعية'**
  String get tasksWeeklyTitle;

  /// D166: when weekly tasks reset.
  ///
  /// In ar, this message translates to:
  /// **'تتجدد كل يوم إثنين.'**
  String get tasksWeeklyHint;

  /// D297: the creator tasks of today (creator-programme members only).
  ///
  /// In ar, this message translates to:
  /// **'مهام صانع المحتوى'**
  String get tasksCreatorTitle;

  /// D297: the creator tasks count toward the daily cap like every daily task.
  ///
  /// In ar, this message translates to:
  /// **'ضمن مكافآت اليوم.'**
  String get tasksCreatorHint;

  /// D297: the weekly creator tasks.
  ///
  /// In ar, this message translates to:
  /// **'مهام صانع المحتوى الأسبوعية'**
  String get tasksCreatorWeeklyTitle;

  /// D166: no task is configured.
  ///
  /// In ar, this message translates to:
  /// **'لا مهام الآن'**
  String get tasksEmpty;

  /// D166: no task is configured (message).
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا المهام عندما يضيفها فريق كبسو.'**
  String get tasksEmptyBody;

  /// D166: a task not done yet: go where it is done.
  ///
  /// In ar, this message translates to:
  /// **'اذهب'**
  String get tasksActionGo;

  /// D166: a done task: claim its coins.
  ///
  /// In ar, this message translates to:
  /// **'استلم'**
  String get tasksActionClaim;

  /// D166: a claimed task / today's check-in done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get tasksActionDone;

  /// D166: a claim or check-in paid coins.
  ///
  /// In ar, this message translates to:
  /// **'حصلت على {coins} عملة'**
  String tasksRewardReceived(String coins);

  /// D166: a check-in after the daily cap (no coins).
  ///
  /// In ar, this message translates to:
  /// **'تم التسجيل — بلغت حدّ مكافآت اليوم'**
  String get tasksNoCoinsCap;

  /// D184: a task claim paid cherries.
  ///
  /// In ar, this message translates to:
  /// **'حصلت على {cherries} كرزة'**
  String tasksRewardReceivedCherries(String cherries);

  /// D166: TASK_DAILY_CAP_REACHED.
  ///
  /// In ar, this message translates to:
  /// **'بلغت حدّ مكافآت المهام لهذا اليوم'**
  String get tasksCapReached;

  /// D188: TASK_MONTHLY_CAP_REACHED.
  ///
  /// In ar, this message translates to:
  /// **'بلغت حدّ مكافآت المهام لهذا الشهر'**
  String get tasksMonthlyCapReached;

  /// D166: Event Center tab.
  ///
  /// In ar, this message translates to:
  /// **'تقويم الفعاليات'**
  String get eventsTabCalendar;

  /// D166: Event Center tab.
  ///
  /// In ar, this message translates to:
  /// **'الفعاليات الدائمة'**
  String get eventsTabPermanent;

  /// D166: Event Center tab.
  ///
  /// In ar, this message translates to:
  /// **'الإقليمية'**
  String get eventsTabRegional;

  /// D166: the intro card title.
  ///
  /// In ar, this message translates to:
  /// **'تقويم الفعاليات'**
  String get eventsIntroTitle;

  /// D166: the intro card text.
  ///
  /// In ar, this message translates to:
  /// **'أبرز فعاليات كبسو الرسمية كل شهر — اعرف المكافآت وطريقة المشاركة مبكراً. اضغط أي فعالية لتفاصيلها.'**
  String get eventsIntroBody;

  /// D166: the calendar's month title.
  ///
  /// In ar, this message translates to:
  /// **'تقويم فعاليات {month}'**
  String eventsCalendarMonth(String month);

  /// D166: calendar navigation.
  ///
  /// In ar, this message translates to:
  /// **'الشهر السابق'**
  String get eventsPreviousMonth;

  /// D166: calendar navigation.
  ///
  /// In ar, this message translates to:
  /// **'الشهر التالي'**
  String get eventsNextMonth;

  /// D166: more event bars than fit in a week.
  ///
  /// In ar, this message translates to:
  /// **'و{count} أخرى'**
  String eventsMore(String count);

  /// D166: empty calendar month.
  ///
  /// In ar, this message translates to:
  /// **'لا فعاليات هذا الشهر'**
  String get eventsEmptyMonth;

  /// D166: empty event list.
  ///
  /// In ar, this message translates to:
  /// **'لا فعاليات الآن'**
  String get eventsEmpty;

  /// D166: empty event list (message).
  ///
  /// In ar, this message translates to:
  /// **'عندما يعلن فريق كبسو عن فعالية ستظهر هنا.'**
  String get eventsEmptyBody;

  /// D166: regional tab without a country.
  ///
  /// In ar, this message translates to:
  /// **'حدّد بلدك لترى فعاليات منطقتك'**
  String get eventsNoCountry;

  /// D166: regional tab without a country (message).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك اختيار بلدك من تعديل الملف الشخصي.'**
  String get eventsNoCountryBody;

  /// D166: events failed to load.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الفعاليات'**
  String get eventsLoadError;

  /// D166: an ended event's tag.
  ///
  /// In ar, this message translates to:
  /// **'انتهت'**
  String get eventsEnded;

  /// D166: a featured event's tag.
  ///
  /// In ar, this message translates to:
  /// **'رائج'**
  String get eventsFeatured;

  /// D166: an event that has not started.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get eventsUpcoming;

  /// D166: a running event.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get eventsRunning;

  /// D166: an event's dates.
  ///
  /// In ar, this message translates to:
  /// **'من {start} إلى {end}'**
  String eventsDates(String start, String end);

  /// D166: a permanent event without an end.
  ///
  /// In ar, this message translates to:
  /// **'منذ {start}'**
  String eventsSince(String start);

  /// D166: the event screen's title.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الفعالية'**
  String get eventsDetailTitle;

  /// D166: an event for hosts.
  ///
  /// In ar, this message translates to:
  /// **'للمضيفين فقط'**
  String get eventsForHosts;

  /// D166: the event rules section.
  ///
  /// In ar, this message translates to:
  /// **'القواعد'**
  String get eventsRules;

  /// D166: an event without rules text.
  ///
  /// In ar, this message translates to:
  /// **'لا قواعد إضافية.'**
  String get eventsNoRules;

  /// D166: the event prizes section.
  ///
  /// In ar, this message translates to:
  /// **'الجوائز'**
  String get eventsPrizes;

  /// D166: an event without prizes.
  ///
  /// In ar, this message translates to:
  /// **'لا جوائز لهذه الفعالية.'**
  String get eventsNoPrizes;

  /// D166: the review window before payout.
  ///
  /// In ar, this message translates to:
  /// **'تُصرف الجوائز تلقائياً بعد 24 ساعة من انتهاء الفعالية.'**
  String get eventsPrizesReview;

  /// D166: prizes paid.
  ///
  /// In ar, this message translates to:
  /// **'صُرفت الجوائز.'**
  String get eventsPrizesPaid;

  /// D166: one rank.
  ///
  /// In ar, this message translates to:
  /// **'المركز {rank}'**
  String eventsRank(String rank);

  /// D166: a range of ranks (each gets the prize).
  ///
  /// In ar, this message translates to:
  /// **'المراكز {from}–{to}'**
  String eventsRanks(String from, String to);

  /// D166: the leaderboard section.
  ///
  /// In ar, this message translates to:
  /// **'لوحة الصدارة'**
  String get eventsBoard;

  /// D166: the board is still counting.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get eventsBoardLive;

  /// D166: the frozen board.
  ///
  /// In ar, this message translates to:
  /// **'النتائج النهائية'**
  String get eventsBoardFinal;

  /// D166: an empty leaderboard.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد في اللوحة بعد.'**
  String get eventsBoardEmpty;

  /// D166: the caller's own rank.
  ///
  /// In ar, this message translates to:
  /// **'ترتيبك: {rank}'**
  String eventsMeRank(String rank);

  /// D166: the caller has no rank.
  ///
  /// In ar, this message translates to:
  /// **'لم تدخل اللوحة بعد'**
  String get eventsMeNotRanked;

  /// D166: what the event counts.
  ///
  /// In ar, this message translates to:
  /// **'قيمة الهدايا المستلمة'**
  String get eventsMetricGiftsReceived;

  /// D166: what the event counts.
  ///
  /// In ar, this message translates to:
  /// **'قيمة الهدايا المرسلة'**
  String get eventsMetricGiftsSent;

  /// D166: what the event counts.
  ///
  /// In ar, this message translates to:
  /// **'دقائق البث'**
  String get eventsMetricLiveMinutes;

  /// D166: what the event counts.
  ///
  /// In ar, this message translates to:
  /// **'النقرات المستلمة'**
  String get eventsMetricTaps;

  /// D166: what the event counts.
  ///
  /// In ar, this message translates to:
  /// **'المتابعون الجدد'**
  String get eventsMetricFollowers;

  /// D166: an unknown metric.
  ///
  /// In ar, this message translates to:
  /// **'النقاط'**
  String get eventsMetricOther;

  /// D166: SVIP failed to load.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل SVIP'**
  String get svipLoadError;

  /// D166: the rules button and sheet.
  ///
  /// In ar, this message translates to:
  /// **'قواعد SVIP'**
  String get svipRules;

  /// D166: how SVIP is earned.
  ///
  /// In ar, this message translates to:
  /// **'تحصل على SVIP بإرسال الهدايا: أنفق العملات على الهدايا خلال {days} يوماً لتصل إلى المستوى، ويبقى معك 30 يوماً من آخر مرة بلغته. لا يُشترى SVIP بالمال.'**
  String svipRulesBody(String days);

  /// D166: status line without SVIP.
  ///
  /// In ar, this message translates to:
  /// **'لست SVIP بعد'**
  String get svipNotYet;

  /// D166: a tier name.
  ///
  /// In ar, this message translates to:
  /// **'SVIP {tier}'**
  String svipTier(String tier);

  /// D166: status line with SVIP.
  ///
  /// In ar, this message translates to:
  /// **'{tier} حتى {date}'**
  String svipUntil(String tier, String date);

  /// D166: the tier track (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'المستوى {tier} من {count}'**
  String svipTrack(String tier, String count);

  /// D166: a locked tier or perk.
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get svipLocked;

  /// D166: an unlocked perk.
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get svipUnlocked;

  /// D166: what the next tier needs.
  ///
  /// In ar, this message translates to:
  /// **'أنفق {coins} عملة على الهدايا خلال {days} يوماً للترقية'**
  String svipSpendToUpgrade(String coins, String days);

  /// D166: the rolling spending.
  ///
  /// In ar, this message translates to:
  /// **'أنفقت {coins} عملة في آخر {days} يوماً'**
  String svipSpent(String coins, String days);

  /// D166: at the top tier.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى أعلى مستوى SVIP'**
  String get svipTop;

  /// D166: the perks section.
  ///
  /// In ar, this message translates to:
  /// **'امتيازات SVIP'**
  String get svipPerksTitle;

  /// D166: no perk is built yet.
  ///
  /// In ar, this message translates to:
  /// **'الامتيازات قيد الإعداد وستُفعَّل تباعاً.'**
  String get svipPerksSoon;

  /// D166: the sticky bar.
  ///
  /// In ar, this message translates to:
  /// **'أنفق {coins} عملة أخرى للوصول إلى {tier}'**
  String svipSpendMore(String coins, String tier);

  /// D166: the gold button (opens the lives).
  ///
  /// In ar, this message translates to:
  /// **'أرسل هدية'**
  String get svipCta;

  /// D166: wallet tab.
  ///
  /// In ar, this message translates to:
  /// **'العملات'**
  String get walletTabCoins;

  /// D166: the packages section.
  ///
  /// In ar, this message translates to:
  /// **'شحن العملات'**
  String get walletRechargeTitle;

  /// D166: a package's bonus coins (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'{coins} إضافية'**
  String walletBonus(String coins);

  /// D166: the discount ribbon.
  ///
  /// In ar, this message translates to:
  /// **'عرض كبير'**
  String get walletOffer;

  /// D166: the recharge button (disabled until payments exist, B5).
  ///
  /// In ar, this message translates to:
  /// **'احصل على {coins} عملة · المجموع {total}'**
  String walletGetCoins(String coins, String total);

  /// D166: no package configured.
  ///
  /// In ar, this message translates to:
  /// **'لا باقات شحن الآن'**
  String get walletPackagesEmpty;

  /// D166: packages failed to load.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل باقات الشحن'**
  String get walletPackagesError;

  /// D166: ledger reason TASK_REWARD.
  ///
  /// In ar, this message translates to:
  /// **'مكافأة مهمة'**
  String get walletReasonTaskReward;

  /// D166: ledger reason CHECK_IN_REWARD.
  ///
  /// In ar, this message translates to:
  /// **'مكافأة تسجيل الدخول'**
  String get walletReasonCheckIn;

  /// D166: ledger reason EVENT_PRIZE.
  ///
  /// In ar, this message translates to:
  /// **'جائزة فعالية'**
  String get walletReasonEventPrize;

  /// D175: the required gender choice on Register.
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get registerGenderLabel;

  /// D175: under the gender choice on Register (private by default).
  ///
  /// In ar, this message translates to:
  /// **'لا يظهر في ملفك الشخصي إلا إذا اخترت ذلك لاحقاً.'**
  String get registerGenderHelper;

  /// D175: Register submitted without a gender.
  ///
  /// In ar, this message translates to:
  /// **'اختر خياراً'**
  String get registerGenderRequired;

  /// D175: Gender MALE.
  ///
  /// In ar, this message translates to:
  /// **'ذكر'**
  String get genderMale;

  /// D175: Gender FEMALE.
  ///
  /// In ar, this message translates to:
  /// **'أنثى'**
  String get genderFemale;

  /// D175: Gender UNDISCLOSED.
  ///
  /// In ar, this message translates to:
  /// **'أفضّل عدم الذكر'**
  String get genderUndisclosed;

  /// D175: AccountCategory SINGER.
  ///
  /// In ar, this message translates to:
  /// **'مغنٍّ'**
  String get categorySinger;

  /// D175: AccountCategory MUSICIAN.
  ///
  /// In ar, this message translates to:
  /// **'موسيقي'**
  String get categoryMusician;

  /// D175: AccountCategory POET.
  ///
  /// In ar, this message translates to:
  /// **'شاعر'**
  String get categoryPoet;

  /// D175: AccountCategory PRESENTER.
  ///
  /// In ar, this message translates to:
  /// **'مقدّم برامج'**
  String get categoryPresenter;

  /// D175: AccountCategory GAMER.
  ///
  /// In ar, this message translates to:
  /// **'لاعب ألعاب'**
  String get categoryGamer;

  /// D175: AccountCategory CONTENT_CREATOR.
  ///
  /// In ar, this message translates to:
  /// **'صانع محتوى'**
  String get categoryContentCreator;

  /// D175: AccountCategory ATHLETE.
  ///
  /// In ar, this message translates to:
  /// **'رياضي'**
  String get categoryAthlete;

  /// D175: AccountCategory ARTIST.
  ///
  /// In ar, this message translates to:
  /// **'فنان'**
  String get categoryArtist;

  /// D175: AccountCategory BLOGGER.
  ///
  /// In ar, this message translates to:
  /// **'مدوّن'**
  String get categoryBlogger;

  /// D175: AccountCategory PUBLIC_FIGURE.
  ///
  /// In ar, this message translates to:
  /// **'شخصية عامة'**
  String get categoryPublicFigure;

  /// D175: AccountCategory OTHER.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get categoryOther;

  /// D175: an Edit profile row without a value (gender, category).
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get profileEditNotSet;

  /// D175: switch in the gender sheet (off by default).
  ///
  /// In ar, this message translates to:
  /// **'إظهار الجنس في ملفي'**
  String get profileEditGenderShow;

  /// D175: under the show-gender switch.
  ///
  /// In ar, this message translates to:
  /// **'مخفي افتراضياً. «أفضّل عدم الذكر» لا يظهر أبداً.'**
  String get profileEditGenderShowHint;

  /// D175: the gender row value while it is not shown on the profile.
  ///
  /// In ar, this message translates to:
  /// **'{gender} · مخفي'**
  String profileEditGenderHidden(String gender);

  /// D175: clears the account category.
  ///
  /// In ar, this message translates to:
  /// **'بدون فئة'**
  String get profileEditCategoryNone;

  /// D175: the category sheet subtitle.
  ///
  /// In ar, this message translates to:
  /// **'تظهر تحت اسمك في ملفك الشخصي.'**
  String get profileEditCategoryHint;

  /// D175: the links row value (how many links are set).
  ///
  /// In ar, this message translates to:
  /// **'{count} من 3'**
  String profileEditLinksValue(int count);

  /// D175: the links editor explanation.
  ///
  /// In ar, this message translates to:
  /// **'حتى 3 روابط تبدأ بـ https://‎. روابط إنستغرام وتيك توك ويوتيوب وفيسبوك وإكس تُفتح مباشرة، وأي رابط آخر بعد تنبيه.'**
  String get profileEditLinksHint;

  /// D175: the URL field of a link.
  ///
  /// In ar, this message translates to:
  /// **'الرابط'**
  String get profileEditLinkUrl;

  /// D175: the label field of a link.
  ///
  /// In ar, this message translates to:
  /// **'الاسم (اختياري)'**
  String get profileEditLinkLabel;

  /// D175: adds a link field (up to 3).
  ///
  /// In ar, this message translates to:
  /// **'إضافة رابط'**
  String get profileEditLinkAdd;

  /// D175: removes one link field (button tooltip).
  ///
  /// In ar, this message translates to:
  /// **'حذف الرابط'**
  String get profileEditLinkRemove;

  /// D175: link refused (invalid_format).
  ///
  /// In ar, this message translates to:
  /// **'رابط غير صالح: يجب أن يبدأ بـ https://‎ ويكون اسم موقع، بلا كلمة مرور أو منفذ أو عنوان IP.'**
  String get profileEditLinkInvalid;

  /// D175: link refused (too_long).
  ///
  /// In ar, this message translates to:
  /// **'الرابط طويل جداً.'**
  String get profileEditLinkTooLong;

  /// D175: label refused.
  ///
  /// In ar, this message translates to:
  /// **'الاسم حتى {max} حرفاً في سطر واحد.'**
  String profileEditLinkLabelTooLong(int max);

  /// D175: the same link twice.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط مضاف مسبقاً.'**
  String get profileEditLinkDuplicate;

  /// D175 (owner: pinning 3 is enough): replaces the grid-order “Coming soon” row.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت حتى 3 منشورات لتظهر أولاً في ملفك، من قائمة «…» في المنشور.'**
  String get profileEditPinHint;

  /// D175: privacy section header.
  ///
  /// In ar, this message translates to:
  /// **'الحساب الخاص'**
  String get privacyPrivateTitle;

  /// D175: the private-account switch.
  ///
  /// In ar, this message translates to:
  /// **'حساب خاص'**
  String get privacyPrivateLabel;

  /// D175: under the private-account switch.
  ///
  /// In ar, this message translates to:
  /// **'متابعوك فقط يرون منشوراتك وريلزك وقصصك. من يريد متابعتك يرسل طلباً تقبله أو ترفضه. البث المباشر يبقى عاماً.'**
  String get privacyPrivateHint;

  /// D175: confirm before switching private → public.
  ///
  /// In ar, this message translates to:
  /// **'جعل الحساب عاماً؟'**
  String get privacyMakePublicTitle;

  /// D175: confirm body.
  ///
  /// In ar, this message translates to:
  /// **'سيرى الجميع منشوراتك وريلزك وقصصك، وستُقبل كل طلبات المتابعة المعلّقة.'**
  String get privacyMakePublicBody;

  /// D175: confirm button.
  ///
  /// In ar, this message translates to:
  /// **'جعله عاماً'**
  String get privacyMakePublicConfirm;

  /// D175: the follow-requests screen and its row in privacy settings.
  ///
  /// In ar, this message translates to:
  /// **'طلبات المتابعة'**
  String get followRequestsTitle;

  /// D175: empty follow-requests list.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات'**
  String get followRequestsEmptyTitle;

  /// D175: empty follow-requests list body.
  ///
  /// In ar, this message translates to:
  /// **'عندما يطلب أحد متابعة حسابك الخاص يظهر هنا.'**
  String get followRequestsEmptyBody;

  /// D175: accept a follow request.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get followRequestAccept;

  /// D175: decline a follow request.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get followRequestDecline;

  /// D175: snack after accepting.
  ///
  /// In ar, this message translates to:
  /// **'{name} يتابعك الآن'**
  String followRequestAccepted(String name);

  /// D175: snack after declining.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get followRequestDeclined;

  /// D175: the follow button while a request is pending.
  ///
  /// In ar, this message translates to:
  /// **'تم الطلب'**
  String get followRequested;

  /// D175: confirm sheet title.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء طلب متابعة {name}؟'**
  String profileCancelRequestConfirm(String name);

  /// D175: cancels a pending follow request.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get profileCancelRequest;

  /// D175: snack after following a private account.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل طلب المتابعة'**
  String get profileRequestSent;

  /// D175 (owner): the warning before opening a link that is not a known platform.
  ///
  /// In ar, this message translates to:
  /// **'أنت تغادر Kabso'**
  String get linkLeavingTitle;

  /// D175: the warning body (the full URL is shown under it).
  ///
  /// In ar, this message translates to:
  /// **'هذا الرابط يفتح موقعاً خارج Kabso. تأكّد أنك تثق به قبل المتابعة.'**
  String get linkLeavingBody;

  /// D175: opens the link after the warning.
  ///
  /// In ar, this message translates to:
  /// **'فتح الرابط'**
  String get linkLeavingOpen;

  /// D175: reports a profile link.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن الرابط'**
  String get linkReport;

  /// D175: report reason sheet title.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذا الرابط؟'**
  String get linkReportTitle;

  /// D175: copies a profile link.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get linkCopy;

  /// D175: snack after copying a link.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الرابط'**
  String get linkCopied;

  /// D175: the system could not open the link.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرابط'**
  String get linkOpenFailed;

  /// D175: screen-reader label of a profile link.
  ///
  /// In ar, this message translates to:
  /// **'رابط: {name}'**
  String linkSemantics(String name);

  /// D175: FOLLOW_REQUEST notification.
  ///
  /// In ar, this message translates to:
  /// **'{who} طلب متابعتك'**
  String notifFollowRequest(String who);

  /// D175: FOLLOW_REQUEST_ACCEPTED notification.
  ///
  /// In ar, this message translates to:
  /// **'{who} قبل طلب متابعتك'**
  String notifFollowRequestAccepted(String who);

  /// D175: AVATAR_REMOVED notification (system).
  ///
  /// In ar, this message translates to:
  /// **'أزال فريق الإشراف صورة ملفك الشخصي لمخالفتها الإرشادات'**
  String get notifAvatarRemoved;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} many{{days} يوماً} other{{days} يوم}}'**
  String bagDays(int days);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'{hours, plural, =1{ساعة واحدة} =2{ساعتان} few{{hours} ساعات} many{{hours} ساعة} other{{hours} ساعة}}'**
  String bagHours(int hours);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'{minutes, plural, =1{دقيقة واحدة} =2{دقيقتان} few{{minutes} دقائق} many{{minutes} دقيقة} other{{minutes} دقيقة}}'**
  String bagMinutes(int minutes);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'{first} {second}'**
  String bagDurationPair(String first, String second);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ {duration}'**
  String bagRemaining(String duration);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'ينتهي اليوم'**
  String get bagEndsToday;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'دائم'**
  String get bagPermanent;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'هدية من Kabso'**
  String get bagFromKabso;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'هدية من {name}'**
  String bagFromUser(String name);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get bagFromSomeone;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة مستوى'**
  String get bagFromLevel;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'تم الشراء'**
  String get bagFromPurchase;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get bagSend;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'العناصر المجانية لا تُرسل'**
  String get bagNoSendFree;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'مكافآت المستوى لا تُرسل، فهي مرتبطة بمستواك'**
  String get bagNoSendLevel;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال هذا العنصر'**
  String get bagNoSendOther;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'عناصر أخرى'**
  String get bagCategoryOther;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'إرسال {item}'**
  String bagSendTitle(String item);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'لديك: {left}'**
  String bagSendYouHave(String left);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'كم تريد أن ترسل؟'**
  String get bagSendAmount;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get bagSendAll;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'العنصر الدائم يُرسل كاملاً ويخرج من حقيبتك.'**
  String get bagSendPermanentNote;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'سيخرج العنصر من حقيبتك مع كل مدته المتبقية.'**
  String get bagSendWholeNote;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'يبقى لديك بعد الإرسال: {left}'**
  String bagSendPartNote(String left);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get bagSendTo;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو اسم المستخدم'**
  String get bagSendSearchHint;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'اختر من سترسل إليه العنصر.'**
  String get bagSendSearchStart;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أحد بهذا الاسم.'**
  String get bagSendSearchEmpty;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get bagSendChange;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الإرسال'**
  String get bagSendConfirmTitle;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'إرسال {item} ({amount}) إلى {user}؟'**
  String bagSendConfirmBody(String item, String amount, String user);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'تم الإرسال إلى {user}'**
  String bagSendDone(String user);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال هذا العنصر.'**
  String get errorBagItemNotTransferable;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'العنصر الدائم يُرسل كاملاً فقط.'**
  String get errorBagSendPermanentWholeOnly;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'هذه مدة أطول مما تبقى في العنصر.'**
  String get errorBagSendExceedsRemaining;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'يملك هذا العنصر بشكل دائم بالفعل.'**
  String get errorBagRecipientHasPermanent;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'أرسل لك {who} {item}'**
  String notifBagItemReceived(String who, String item);

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'بطاقة ملف شخصي'**
  String get notifBagItemProfileCard;

  /// D171: the bag v2 (expiry, gifts, send).
  ///
  /// In ar, this message translates to:
  /// **'عنصراً لحقيبتك'**
  String get notifBagItemGeneric;

  /// D180: the bag in the layout of the owner reference.
  ///
  /// In ar, this message translates to:
  /// **'الأدوات'**
  String get bagTabTools;

  /// D180: the bag in the layout of the owner reference.
  ///
  /// In ar, this message translates to:
  /// **'الحقيبة'**
  String get bagTabItems;

  /// D180: the bag in the layout of the owner reference.
  ///
  /// In ar, this message translates to:
  /// **'قيد الاستخدام'**
  String get bagInUse;

  /// D180: the bag in the layout of the owner reference.
  ///
  /// In ar, this message translates to:
  /// **'كل الأدوات'**
  String get bagAllTools;

  /// D180: the bag in the layout of the owner reference.
  ///
  /// In ar, this message translates to:
  /// **'استخدام'**
  String get bagUse;

  /// D180: the bag in the layout of the owner reference.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء'**
  String get bagNothingWorn;

  /// D177: wallet tab, the spending currency (Kabi gold coin, D161).
  ///
  /// In ar, this message translates to:
  /// **'العملات الذهبية'**
  String get walletTabGold;

  /// D177: wallet tab, the host currency (Kab Cherry, D134).
  ///
  /// In ar, this message translates to:
  /// **'الكرز'**
  String get walletTabCherries;

  /// D177: under the gold balance.
  ///
  /// In ar, this message translates to:
  /// **'رصيدي من العملات'**
  String get walletGoldBalance;

  /// D177: under the cherry total.
  ///
  /// In ar, this message translates to:
  /// **'رصيدي من الكرز'**
  String get walletCherryBalance;

  /// D177: a cherry amount for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرزة'**
  String walletCherries(String cherries);

  /// D177: the selected package's bonus row and sheet title.
  ///
  /// In ar, this message translates to:
  /// **'المكافآت'**
  String get walletRewards;

  /// D177: rewards sheet line.
  ///
  /// In ar, this message translates to:
  /// **'العملات'**
  String get walletRewardsBase;

  /// D177: rewards sheet line.
  ///
  /// In ar, this message translates to:
  /// **'المكافأة'**
  String get walletRewardsBonus;

  /// D177: rewards sheet line.
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get walletRewardsTotal;

  /// D177: the recharge pill's first line, before the coin icon and amount.
  ///
  /// In ar, this message translates to:
  /// **'احصل على'**
  String get walletGet;

  /// D177: the recharge pill's second line.
  ///
  /// In ar, this message translates to:
  /// **'المجموع: {total}'**
  String walletTotal(String total);

  /// D177: the recharge pill is disabled (B5: no payment method chosen).
  ///
  /// In ar, this message translates to:
  /// **'الدفع غير متاح بعد'**
  String get walletPayUnavailable;

  /// D177: the cherry tab's withdraw pill (disabled, D149).
  ///
  /// In ar, this message translates to:
  /// **'سحب'**
  String get walletWithdraw;

  /// No description provided for @cherryValue.
  ///
  /// In ar, this message translates to:
  /// **'≈ {amount}'**
  String cherryValue(Object amount);

  /// No description provided for @cherryHeld.
  ///
  /// In ar, this message translates to:
  /// **'محجوز للسحب: {cherries}'**
  String cherryHeld(Object cherries);

  /// No description provided for @cherryUnitShort.
  ///
  /// In ar, this message translates to:
  /// **'عملة واحدة من حصتك في الهدية = 10 كرزات.'**
  String get cherryUnitShort;

  /// No description provided for @cherryUnit.
  ///
  /// In ar, this message translates to:
  /// **'عملة واحدة من حصتك في الهدية = 10 كرزات. {cherries} كرزة = {amount}. السحب من {min}. ليست نقاط الكرز في البث.'**
  String cherryUnit(Object amount, Object cherries, Object min);

  /// No description provided for @cherryHistoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل الكرز'**
  String get cherryHistoryTitle;

  /// No description provided for @cherryReasonGift.
  ///
  /// In ar, this message translates to:
  /// **'هدية مستلمة'**
  String get cherryReasonGift;

  /// No description provided for @cherryReasonAgency.
  ///
  /// In ar, this message translates to:
  /// **'عمولة الوكالة'**
  String get cherryReasonAgency;

  /// No description provided for @cherryReasonParent.
  ///
  /// In ar, this message translates to:
  /// **'عمولة أدمن الوكالات'**
  String get cherryReasonParent;

  /// No description provided for @cherryReasonGiftReversal.
  ///
  /// In ar, this message translates to:
  /// **'ألغى الفريق هدية'**
  String get cherryReasonGiftReversal;

  /// No description provided for @cherryReasonCommissionReversal.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء عمولة'**
  String get cherryReasonCommissionReversal;

  /// No description provided for @cherryReasonWithdrawal.
  ///
  /// In ar, this message translates to:
  /// **'طلب سحب (محجوز)'**
  String get cherryReasonWithdrawal;

  /// No description provided for @cherryReasonRefund.
  ///
  /// In ar, this message translates to:
  /// **'رُفض السحب: أُعيدت الكرزات'**
  String get cherryReasonRefund;

  /// D184: a TASK_REWARD row of the cherry history (a Task Center reward).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة مهمة'**
  String get cherryReasonTask;

  /// D184: task cherries not withdrawable yet (the owner's earnings condition, wording may change).
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرزة من المهام مقفلة — تُفتح للسحب بعد تحقيق شرط الأرباح'**
  String cherryTaskLocked(String cherries);

  /// No description provided for @cherryReasonOther.
  ///
  /// In ar, this message translates to:
  /// **'تغيير في الكرز'**
  String get cherryReasonOther;

  /// No description provided for @cherryWithdrawalsTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبات السحب'**
  String get cherryWithdrawalsTitle;

  /// No description provided for @cherryWithdrawalPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get cherryWithdrawalPending;

  /// No description provided for @cherryWithdrawalPaid.
  ///
  /// In ar, this message translates to:
  /// **'دُفع'**
  String get cherryWithdrawalPaid;

  /// No description provided for @cherryWithdrawalRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get cherryWithdrawalRejected;

  /// No description provided for @cherryWithdrawalLine.
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرزة'**
  String cherryWithdrawalLine(Object cherries);

  /// No description provided for @cherryPendingNote.
  ///
  /// In ar, this message translates to:
  /// **'طلبك بقيمة {amount} قيد الانتظار: يدفعه فريق كبسو يدوياً خلال {days} أيام.'**
  String cherryPendingNote(Object amount, Object days);

  /// No description provided for @withdrawTitle.
  ///
  /// In ar, this message translates to:
  /// **'سحب الكرز'**
  String get withdrawTitle;

  /// No description provided for @withdrawBalance.
  ///
  /// In ar, this message translates to:
  /// **'المتاح: {cherries} كرزة ≈ {amount}'**
  String withdrawBalance(Object amount, Object cherries);

  /// No description provided for @withdrawRate.
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرزة = {amount} · الحد الأدنى {min}'**
  String withdrawRate(Object amount, Object cherries, Object min);

  /// No description provided for @withdrawAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ ({currency})'**
  String withdrawAmountLabel(Object currency);

  /// No description provided for @withdrawAmountHelper.
  ///
  /// In ar, this message translates to:
  /// **'= {cherries} كرزة'**
  String withdrawAmountHelper(Object cherries);

  /// No description provided for @withdrawAmountMin.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى {amount}'**
  String withdrawAmountMin(Object amount);

  /// No description provided for @withdrawAmountShort.
  ///
  /// In ar, this message translates to:
  /// **'كرزاتك تكفي حتى {amount}'**
  String withdrawAmountShort(Object amount);

  /// No description provided for @withdrawAmountInvalid.
  ///
  /// In ar, this message translates to:
  /// **'اكتب مبلغاً مثل 10 أو 12.50'**
  String get withdrawAmountInvalid;

  /// No description provided for @withdrawDetailsLabel.
  ///
  /// In ar, this message translates to:
  /// **'أين ندفع لك؟'**
  String get withdrawDetailsLabel;

  /// No description provided for @withdrawDetailsHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم البنك والآيبان، أو اسم المحفظة ورقمها'**
  String get withdrawDetailsHint;

  /// No description provided for @withdrawManualNote.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد دفع تلقائي بعد: يراجع فريق كبسو طلبك ويدفعه يدوياً خلال {days} أيام. تُحجز الكرزات الآن وتعود إليك إن رُفض الطلب.'**
  String withdrawManualNote(Object days);

  /// No description provided for @withdrawSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get withdrawSubmit;

  /// No description provided for @withdrawSubmitAmount.
  ///
  /// In ar, this message translates to:
  /// **'طلب سحب {amount}'**
  String withdrawSubmitAmount(Object amount);

  /// No description provided for @withdrawSent.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل طلب السحب'**
  String get withdrawSent;

  /// No description provided for @errorAgencyAlreadyMember.
  ///
  /// In ar, this message translates to:
  /// **'أنت مضيف في وكالة أخرى.'**
  String get errorAgencyAlreadyMember;

  /// No description provided for @errorAgencyJoinNotAllowed.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن لوكيل وكالة الانضمام إلى وكالة كمضيف.'**
  String get errorAgencyJoinNotAllowed;

  /// No description provided for @errorAgencyLeaveWindowClosed.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة المغادرة. أرسل شكوى إلى الإدارة.'**
  String get errorAgencyLeaveWindowClosed;

  /// No description provided for @errorInsufficientCherries.
  ///
  /// In ar, this message translates to:
  /// **'كرزاتك لا تكفي لهذا المبلغ.'**
  String get errorInsufficientCherries;

  /// No description provided for @errorWithdrawalPending.
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب سحب ينتظر الدفع.'**
  String get errorWithdrawalPending;

  /// No description provided for @meHubAgency.
  ///
  /// In ar, this message translates to:
  /// **'الوكالة'**
  String get meHubAgency;

  /// No description provided for @agencyTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوكالة'**
  String get agencyTitle;

  /// No description provided for @agencyLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الوكالة'**
  String get agencyLoadError;

  /// No description provided for @agencyJoinTitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى وكالة'**
  String get agencyJoinTitle;

  /// No description provided for @agencyJoinBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رمز الدعوة من وكيلك، تحقّق من الوكالة، ثم اقبل.'**
  String get agencyJoinBody;

  /// No description provided for @agencyCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز الدعوة'**
  String get agencyCodeLabel;

  /// No description provided for @agencyFind.
  ///
  /// In ar, this message translates to:
  /// **'عرض الوكالة'**
  String get agencyFind;

  /// No description provided for @agencyNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد وكالة بهذا الرمز.'**
  String get agencyNotFound;

  /// No description provided for @agencyPreviewOwner.
  ///
  /// In ar, this message translates to:
  /// **'الوكيل: {name}'**
  String agencyPreviewOwner(Object name);

  /// No description provided for @agencyHostCount.
  ///
  /// In ar, this message translates to:
  /// **'المضيفون: {count}'**
  String agencyHostCount(Object count);

  /// No description provided for @agencyAccept.
  ///
  /// In ar, this message translates to:
  /// **'قبول والانضمام'**
  String get agencyAccept;

  /// No description provided for @agencyLeaveRule.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك المغادرة خلال {days} يوماً من الانضمام؛ بعدها عبر شكوى إلى الإدارة فقط.'**
  String agencyLeaveRule(Object days);

  /// No description provided for @agencyJoined.
  ///
  /// In ar, this message translates to:
  /// **'انضممت إلى الوكالة'**
  String get agencyJoined;

  /// No description provided for @agencyMyAgency.
  ///
  /// In ar, this message translates to:
  /// **'وكالتي'**
  String get agencyMyAgency;

  /// No description provided for @agencyJoinedAt.
  ///
  /// In ar, this message translates to:
  /// **'انضممت في {date}'**
  String agencyJoinedAt(Object date);

  /// No description provided for @agencyLeaveUntil.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك المغادرة حتى {date}'**
  String agencyLeaveUntil(Object date);

  /// No description provided for @agencyLeaveClosed.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة المغادرة ({days} يوماً). للمغادرة أرسل شكوى إلى الإدارة.'**
  String agencyLeaveClosed(Object days);

  /// No description provided for @agencyLeave.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الوكالة'**
  String get agencyLeave;

  /// No description provided for @agencyLeaveConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تتوقف عمولة الوكالة على هداياك. يمكنك الانضمام إلى وكالة أخرى برمزها.'**
  String get agencyLeaveConfirm;

  /// No description provided for @agencyLeft.
  ///
  /// In ar, this message translates to:
  /// **'غادرت الوكالة'**
  String get agencyLeft;

  /// No description provided for @agencyComplain.
  ///
  /// In ar, this message translates to:
  /// **'شكوى إلى الإدارة'**
  String get agencyComplain;

  /// No description provided for @agencyComplaintHint.
  ///
  /// In ar, this message translates to:
  /// **'ما المشكلة؟'**
  String get agencyComplaintHint;

  /// No description provided for @agencyComplaintSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الشكوى'**
  String get agencyComplaintSend;

  /// No description provided for @agencyComplaintSent.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت الشكوى إلى الإدارة'**
  String get agencyComplaintSent;

  /// No description provided for @agencyComplaintOpen.
  ///
  /// In ar, this message translates to:
  /// **'شكواك لدى الإدارة (أُرسلت في {date}).'**
  String agencyComplaintOpen(Object date);

  /// No description provided for @agencyComplaintDone.
  ///
  /// In ar, this message translates to:
  /// **'ردّت الإدارة على شكواك.'**
  String get agencyComplaintDone;

  /// No description provided for @agencyInviteCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الدعوة الخاص بك'**
  String get agencyInviteCode;

  /// No description provided for @agencyCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرمز'**
  String get agencyCopy;

  /// No description provided for @agencyCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الرمز'**
  String get agencyCopied;

  /// No description provided for @agencyInviteHint.
  ///
  /// In ar, this message translates to:
  /// **'يكتب المضيفون هذا الرمز في «الوكالة» ثم يقبلون.'**
  String get agencyInviteHint;

  /// No description provided for @agencyRankTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرتبة'**
  String get agencyRankTitle;

  /// No description provided for @agencyRankNew.
  ///
  /// In ar, this message translates to:
  /// **'جديدة (فترة سماح)'**
  String get agencyRankNew;

  /// No description provided for @agencyRankAgent.
  ///
  /// In ar, this message translates to:
  /// **'وكيل مضيفين'**
  String get agencyRankAgent;

  /// No description provided for @agencyRankAdmin.
  ///
  /// In ar, this message translates to:
  /// **'أدمن وكالات'**
  String get agencyRankAdmin;

  /// No description provided for @agencyRankLapsed.
  ///
  /// In ar, this message translates to:
  /// **'غير مؤهلة هذا الشهر'**
  String get agencyRankLapsed;

  /// No description provided for @agencyRate.
  ///
  /// In ar, this message translates to:
  /// **'عمولتك هذا الشهر: {percent}%'**
  String agencyRate(Object percent);

  /// No description provided for @agencyRateNote.
  ///
  /// In ar, this message translates to:
  /// **'تدفعها كبسو فوق كرزات مضيفيك ولا تُخصم منهم. 16% في الشهر التالي لشهر يحقق فيه مضيفوك {tier} كرزة.'**
  String agencyRateNote(Object tier);

  /// No description provided for @agencyParent.
  ///
  /// In ar, this message translates to:
  /// **'أدمن الوكالات: {name}'**
  String agencyParent(Object name);

  /// No description provided for @agencyProgressTitle.
  ///
  /// In ar, this message translates to:
  /// **'التقدّم'**
  String get agencyProgressTitle;

  /// No description provided for @agencyActiveHosts.
  ///
  /// In ar, this message translates to:
  /// **'المضيفون النشطون: {count} / {required}'**
  String agencyActiveHosts(Object count, Object required);

  /// No description provided for @agencyActiveRule.
  ///
  /// In ar, this message translates to:
  /// **'النشط = بثّ في {days} أيام ولمدة {hours} ساعات خلال آخر {window} يوماً.'**
  String agencyActiveRule(Object days, Object hours, Object window);

  /// No description provided for @agencyMonthCherries.
  ///
  /// In ar, this message translates to:
  /// **'كرز مضيفيك هذا الشهر: {cherries}'**
  String agencyMonthCherries(Object cherries);

  /// No description provided for @agencyException.
  ///
  /// In ar, this message translates to:
  /// **'أو {cherries} كرزة في الشهر مع أقل من {hosts} مضيفين نشطين.'**
  String agencyException(Object cherries, Object hosts);

  /// No description provided for @agencySubProgress.
  ///
  /// In ar, this message translates to:
  /// **'الوكالات الفرعية المؤهلة: {count} / {required}'**
  String agencySubProgress(Object count, Object required);

  /// No description provided for @agencyQualifiesNow.
  ///
  /// In ar, this message translates to:
  /// **'أنت مؤهل الآن.'**
  String get agencyQualifiesNow;

  /// No description provided for @agencyNotQualifiedNow.
  ///
  /// In ar, this message translates to:
  /// **'لست مؤهلاً بعد.'**
  String get agencyNotQualifiedNow;

  /// No description provided for @agencyEvaluationNote.
  ///
  /// In ar, this message translates to:
  /// **'تُراجع الرتب في بداية كل شهر وتبقى حتى نهايته.'**
  String get agencyEvaluationNote;

  /// No description provided for @agencyCommissionTitle.
  ///
  /// In ar, this message translates to:
  /// **'العمولات (كرز)'**
  String get agencyCommissionTitle;

  /// No description provided for @agencyThisMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get agencyThisMonth;

  /// No description provided for @agencyLastMonth.
  ///
  /// In ar, this message translates to:
  /// **'الشهر الماضي'**
  String get agencyLastMonth;

  /// No description provided for @agencyTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get agencyTotal;

  /// No description provided for @agencyParentCommissionTitle.
  ///
  /// In ar, this message translates to:
  /// **'عمولة أدمن الوكالات (3%)'**
  String get agencyParentCommissionTitle;

  /// No description provided for @agencySubAgenciesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوكالات الفرعية'**
  String get agencySubAgenciesTitle;

  /// No description provided for @agencySubLine.
  ///
  /// In ar, this message translates to:
  /// **'{active} نشطون · {cherries} كرزة هذا الشهر'**
  String agencySubLine(Object active, Object cherries);

  /// No description provided for @agencyQualified.
  ///
  /// In ar, this message translates to:
  /// **'مؤهلة'**
  String get agencyQualified;

  /// No description provided for @agencyNotQualified.
  ///
  /// In ar, this message translates to:
  /// **'غير مؤهلة'**
  String get agencyNotQualified;

  /// No description provided for @agencyHostsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المضيفون ({count})'**
  String agencyHostsTitle(Object count);

  /// No description provided for @agencyHostsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مضيفين بعد'**
  String get agencyHostsEmpty;

  /// No description provided for @agencyHostsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'شارك رمز الدعوة مع المضيفين.'**
  String get agencyHostsEmptyBody;

  /// No description provided for @agencyHostActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get agencyHostActive;

  /// No description provided for @agencyHostInactive.
  ///
  /// In ar, this message translates to:
  /// **'غير نشط'**
  String get agencyHostInactive;

  /// No description provided for @agencyHostLine.
  ///
  /// In ar, this message translates to:
  /// **'{days} أيام · {hours} ساعة بث (30 يوماً) · {cherries} كرزة هذا الشهر'**
  String agencyHostLine(Object cherries, Object days, Object hours);

  /// No description provided for @agencyHostNoCommission.
  ///
  /// In ar, this message translates to:
  /// **'انضم والوكالة غير مؤهلة: بلا عمولة'**
  String get agencyHostNoCommission;

  /// D187 daily recharge badge (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'شارة الشحن اليومي، المستوى {tier}'**
  String rechargeBadgeLabel(int tier);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل شحن {code}'**
  String rechargeAgentBadgeLabel(String code);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{name}، وكيل شحن {code}'**
  String rechargeAgentFrameLabel(String name, String code);

  /// D185 recharge agents: the entrance bar's screen-reader label (the display name)
  ///
  /// In ar, this message translates to:
  /// **'دخل وكيل الشحن {name} البث'**
  String rechargeEntranceJoined(String name);

  /// D185/D189 the text in both entrance bars (the display name)
  ///
  /// In ar, this message translates to:
  /// **'دخل {name} البث'**
  String agentEntranceJoined(String name);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل شحن · {code}'**
  String rechargeAgentIdLine(String code);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل شحن · {code}'**
  String rechargeIdLine(String code);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل الشحن'**
  String get rechargeTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'وكلاء الشحن'**
  String get rechargeDirectoryTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اشترِ العملات من وكيل في بلدك وادفع له مباشرة'**
  String get rechargeDirectoryHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الشحن عبر وكيل'**
  String get rechargeBuyViaAgent;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'كن وكيل شحن'**
  String get rechargeBecome;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بِع عملات Kabso في بلدك'**
  String get rechargeIntroTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يشتري الوكيل العملات بالجملة من Kabso ويبيعها لمستخدمي Kabso، ويدفع له المشتري خارج التطبيق. يحصل الوكيل على إطار وشارة ودخول خاص في الغرف.'**
  String get rechargeIntroBody;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يُفعَّل الوكيل بعد أول شحن لا يقل عن {coins} عملة.'**
  String rechargeIntroActivation(String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة'**
  String get rechargePendingTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'سيتواصل معك فريق Kabso على واتساب. بيانات طلبك خاصة ولا يراها إلا الفريق.'**
  String get rechargePendingBody;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لم يُقبل طلبك السابق.'**
  String get rechargeRejectedTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String rechargeRejectedReason(String reason);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'قدّم طلباً جديداً'**
  String get rechargeApplyAgain;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة — بانتظار أول شحن'**
  String get rechargeApprovedTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'فعّل وكالتك بشحن أول لا يقل عن {coins} عملة عبر فريق Kabso. يظهر رمزك وإطارك بعد التفعيل.'**
  String rechargeApprovedBody(String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الوكالة موقوفة'**
  String get rechargeSuspendedTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك البيع الآن ولا تظهر في دليل الوكلاء، وأُزيل الإطار والشارة والدخول. تواصل مع فريق Kabso.'**
  String get rechargeSuspendedBody;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'مخزون العملات'**
  String get rechargeStock;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'مخزون العملات: {coins}'**
  String rechargeStockLabel(String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بيع عملات'**
  String get rechargeSell;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إدارة الوكالة'**
  String get rechargeManage;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'المبيعات'**
  String get rechargeSalesTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{count} عملية\n{coins} عملة'**
  String rechargeSalesTotals(int count, String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get rechargeToday;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'٧ أيام'**
  String get rechargeLast7;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'٣٠ يوماً'**
  String get rechargeLast30;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'كرز المضيفين اليوم: {today} من {cap}'**
  String rechargeCherryToday(String today, String cap);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الموظفون'**
  String get rechargeEmployeesTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أضف موظفين يبيعون من مخزونك في ساعات عملهم'**
  String get rechargeEmployeesHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أوقات التواصل وطرق الدفع'**
  String get rechargeAvailabilityTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لم تحدد أوقاتاً بعد؛ لن يظهر زر التواصل في الدليل'**
  String get rechargeAvailabilityEmpty;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وقت واحد} =2{وقتان} few{{count} أوقات} other{{count} وقتاً}}'**
  String rechargeSlotCount(int count);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يظهر رقم واتساب وطريقة الدفع للوقت الحالي في دليل الوكلاء لكل المستخدمين.'**
  String get rechargeAvailabilityNote;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'شراء كرز المضيفين'**
  String get rechargeCherryBuyTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بيع الكرز لوكيل'**
  String get rechargeCherrySellTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرزة = {coins} عملة في مخزون الوكيل'**
  String rechargeCherryRate(String cherries, String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'موظف لدى {name}'**
  String rechargeEmployeeOf(String name);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'في الدوام'**
  String get rechargeOnShift;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'خارج الدوام'**
  String get rechargeOffShift;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بيع عملات من المخزون'**
  String get rechargeSellTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'في المخزون: {coins} عملة'**
  String rechargeStockLeft(String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'المشتري'**
  String get rechargeBuyer;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم أو المعرّف'**
  String get rechargeBuyerHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'عدد العملات'**
  String get rechargeCoins;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اكتب المشتري وعدد العملات'**
  String get rechargeSellInvalid;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت {coins} عملة إلى {buyer}'**
  String rechargeSold(String coins, String buyer);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يدفع لك المشتري خارج التطبيق. تأكد من استلام المبلغ قبل البيع.'**
  String get rechargeSellNote;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'طلب وكيل شحن'**
  String get rechargeApplyTitle;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بيانات الطلب خاصة: لا يراها إلا فريق Kabso، وتُحذف بعد ٩٠ يوماً إذا لم يُقبل الطلب.'**
  String get rechargePrivacyNote;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الاسم الرباعي'**
  String get rechargeFullName;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'كما في الهوية'**
  String get rechargeFullNameHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اكتب الاسم الرباعي (أربعة أسماء على الأقل)'**
  String get rechargeFullNameError;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف (واتساب)'**
  String get rechargePhone;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بالصيغة الدولية، مثل ‎+201001234567'**
  String get rechargePhoneHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقماً دولياً يبدأ بـ + (مثل ‎+201001234567)'**
  String get rechargePhoneError;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'صورتك'**
  String get rechargePhoto;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'صورة واضحة لك'**
  String get rechargePhotoHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'سيلفي للتحقق'**
  String get rechargeSelfie;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بالكاميرا الأمامية الآن؛ يراجعها الفريق'**
  String get rechargeSelfieHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أماكن البيع'**
  String get rechargeLocations;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الدولة'**
  String get rechargeCountry;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'المدن (افصل بفاصلة)'**
  String get rechargeCities;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إضافة دولة'**
  String get rechargeAddLocation;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اكتب رمز الدولة من حرفين (مثل EG) ومدينة واحدة على الأقل'**
  String get rechargeLocationError;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'طرق الدفع المتاحة في كل دولة'**
  String get rechargePaymentMethods;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get rechargePaymentType;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل (مثل فودافون كاش، إنستاباي)'**
  String get rechargePaymentDetails;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إضافة طريقة دفع'**
  String get rechargeAddPayment;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لكل طريقة دفع: دولة من أماكن البيع وتفاصيل'**
  String get rechargePaymentError;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أضف صورتك وصورة السيلفي (JPEG أو PNG أو WebP)'**
  String get rechargeMissingPhotos;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get rechargeSubmit;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أُرسل طلبك'**
  String get rechargeSubmitted;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'تحويل بنكي'**
  String get rechargePayBank;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'محفظة إلكترونية'**
  String get rechargePayWallet;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'نقداً'**
  String get rechargePayCash;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بطاقة'**
  String get rechargePayCard;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'عملات رقمية'**
  String get rechargePayCrypto;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get rechargePayOther;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get rechargeRemove;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إضافة موظف'**
  String get rechargeAddEmployee;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get rechargeEmployeeUsername;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موظفون بعد'**
  String get rechargeEmployeesEmpty;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name} من الموظفين؟ يتوقف عن البيع فوراً.'**
  String rechargeRemoveEmployeeConfirm(String name);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'ساعات العمل'**
  String get rechargeHours;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'المنطقة الزمنية'**
  String get rechargeTimeZone;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get rechargeFrom;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get rechargeTo;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إضافة وقت'**
  String get rechargeAddSlot;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'رقم واتساب'**
  String get rechargeWhatsapp;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع في هذا الوقت'**
  String get rechargePaymentNow;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get rechargeSave;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get rechargeSaved;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الإثنين'**
  String get rechargeDay1;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get rechargeDay2;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get rechargeDay3;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get rechargeDay4;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get rechargeDay5;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get rechargeDay6;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get rechargeDay7;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'تدفع للوكيل خارج التطبيق، ثم يرسل العملات إلى حسابك مباشرة.'**
  String get rechargeDirectoryNote;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد وكلاء في هذه الدولة بعد'**
  String get rechargeDirectoryEmpty;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'جرّب دولة أخرى أو عُد لاحقاً.'**
  String get rechargeDirectoryEmptyBody;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'متاح الآن · الدفع: {method}'**
  String rechargeAvailableNowLine(String method);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'غير متاح الآن'**
  String get rechargeNotAvailableNow;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'تواصل'**
  String get rechargeContact;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بيع كرز لوكيل'**
  String get rechargeCherryOffer;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'طلب كرز من مضيف'**
  String get rechargeCherryAsk;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'رمز الوكيل (مثل coin0001)'**
  String get rechargeAgentCodeField;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'اسم مستخدم المضيف'**
  String get rechargeHostField;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'عدد الكرز'**
  String get rechargeCherryAmount;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى {min} كرزة، وبمضاعفات {step}'**
  String rechargeCherryRules(String min, String step);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'كرز المهام المقفل لا يُباع.'**
  String get rechargeCherryLockedNote;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يحصل الوكيل على {coins} عملة، ويدفع للمضيف {money} نقداً'**
  String rechargeCherryPreview(String coins, String money);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get rechargeCherrySend;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أُرسل الطلب؛ بانتظار تأكيد الطرف الآخر'**
  String get rechargeCherrySent;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات'**
  String get rechargeCherryEmpty;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'أكّد فقط بعد أن يُدفع المبلغ نقداً. ينتهي الطلب بعد ٣٠ دقيقة.'**
  String get rechargeCherryConfirmHint;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بانتظار تأكيد الطرف الآخر'**
  String get rechargeCherryWaiting;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get rechargeCherryCancel;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get rechargeConfirm;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get rechargeDecline;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التأكيد'**
  String get rechargeCherryPending;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'مؤكَّد'**
  String get rechargeCherryConfirmed;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get rechargeCherryDeclined;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get rechargeCherryCancelled;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'منتهٍ'**
  String get rechargeCherryExpired;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرزة ← {coins} عملة'**
  String rechargeCherryLine(String cherries, String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'المبلغ النقدي: {amount}'**
  String rechargeMoney(String amount);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{name} شحن لك {coins} عملة'**
  String notifRechargeCoins(String name, String coins);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'{name} يطلب تأكيد بيع كرز'**
  String notifRechargeCherry(String name);

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك تقديم طلب وكيل شحن الآن.'**
  String get errorRechargeApplicationNotAllowed;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'هذا الوكيل غير مفعّل.'**
  String get errorRechargeAgentNotActive;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يمكنك البيع في ساعات عملك فقط.'**
  String get errorRechargeOffShift;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'مخزون العملات لا يكفي.'**
  String get errorRechargeStockInsufficient;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إضافة هذا الشخص موظفاً.'**
  String get errorRechargeEmployeeNotAllowed;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'يوجد طلب مفتوح بينكما بالفعل.'**
  String get errorRechargeCherryRequestPending;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'هذا الطلب لم يعد مفتوحاً.'**
  String get errorRechargeCherryRequestClosed;

  /// D185 recharge agents
  ///
  /// In ar, this message translates to:
  /// **'بلغ الوكيل حدّه اليومي من الكرز.'**
  String get errorRechargeCherryCapReached;

  /// D185 special usernames
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم مقفل ما دام اليوزر المميز فعّالاً.'**
  String get errorUsernameLocked;

  /// D185 special usernames
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get settingsUsernameLocked;

  /// D185 special usernames
  ///
  /// In ar, this message translates to:
  /// **'اسمك الأساسي: {username}'**
  String settingsBaseUsername(String username);

  /// D185 special usernames
  ///
  /// In ar, this message translates to:
  /// **'{special} يوزر مميز مقفل، ولا يمكن تغييره ما دام فعّالاً. يراه الجميع وحده؛ اسمك الأساسي {base} لا يراه غيرك، ويمكنك تسجيل الدخول به.'**
  String changeUsernameSpecialLocked(String special, String base);

  /// D185 special usernames
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في {date}، ثم يعود اسمك الأساسي.'**
  String changeUsernameSpecialEnds(String date);

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل مضيفين {code}'**
  String hostAgentBadgeLabel(String code);

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'{name}، وكيل مضيفين'**
  String hostAgentFrameLabel(String name);

  /// D189 host agents (the display name)
  ///
  /// In ar, this message translates to:
  /// **'دخل وكيل المضيفين {name} البث'**
  String hostAgentEntranceJoined(String name);

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل مضيفين · {code}'**
  String hostAgentIdLine(String code);

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'وكيل مضيفين'**
  String get hostAgentCardTitle;

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'رمز وكيل المضيفين'**
  String get hostAgentCodeLabel;

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'إطارك وشارتك ودخولك المميز في البث ظاهرة ما دامت وكالتك قائمة.'**
  String get hostAgentPerksNote;

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'الرمز {code} محجوز لك. يظهر اسم المستخدم {shown} لأنه فُعّل أولاً.'**
  String hostAgentReservedNote(String code, String shown);

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'مزايا وكيل المضيفين موقوفة. يبقى الرمز {code} محجوزاً لك.'**
  String hostAgentSuspendedNote(String code);

  /// D189 host agents
  ///
  /// In ar, this message translates to:
  /// **'يُمنح رمز وكيل المضيفين قريباً.'**
  String get hostAgentPendingNote;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'إطارات الصورة'**
  String get bagCategoryAvatarFrame;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'مكافأة المضيف النشط'**
  String get bagFromHostActive;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'إطار المضيف لا يُرسل'**
  String get bagNoSendHostActive;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'اختر لون إطار المضيف'**
  String get hostFrameChooseTitle;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'أنت مضيف نشط: اختر الإطار الذي يناسبك، ويمكنك تغييره لاحقاً.'**
  String get hostFrameChooseBody;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'اختيار'**
  String get hostFrameChoose;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'تغيير اللون'**
  String get hostFrameChangeColour;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'أزرق'**
  String get hostFrameBlue;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'وردي'**
  String get hostFramePink;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'تم اختيار إطار المضيف'**
  String get hostFrameSaved;

  /// D186 active-host frames
  ///
  /// In ar, this message translates to:
  /// **'لون إطار المضيف يتبع الجنس في ملفك.'**
  String get errorHostFrameStyleFromGender;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get rechargeStatusActive;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get rechargeStatusSuspended;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'كرز المضيفين اليوم: {today}'**
  String rechargeCherryTodayNoCap(String today);

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} عملية} =1{عملية واحدة} =2{عمليتان} few{{count} عمليات} many{{count} عملية} other{{count} عملية}}'**
  String rechargeSalesCount(int count);

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get rechargeMore;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مستخدم بهذا الاسم'**
  String get rechargeBuyerNotFound;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من المشتري…'**
  String get rechargeBuyerChecking;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'أكثر من المخزون المتاح'**
  String get rechargeSellOverStock;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'المخزون بعد البيع: {coins}'**
  String rechargeStockAfter(String coins);

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البيع'**
  String get rechargeSellConfirmTitle;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن التراجع عن البيع بعد تأكيده.'**
  String get rechargeSellIrreversible;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'بياناتك'**
  String get rechargeApplyStepPersonal;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'الصور'**
  String get rechargeApplyStepPhotos;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'تمت الإضافة'**
  String get rechargePhotoAdded;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'مطلوبة'**
  String get rechargePhotoRequired;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get rechargeApplyStepPrivacy;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'اختر الدولة'**
  String get rechargeChooseCountry;

  /// D185 recharge screens (owner polish)
  ///
  /// In ar, this message translates to:
  /// **'المخزون بعد البيع'**
  String get rechargeStockAfterLabel;

  /// D190 the website top-up link (server flag, off by default)
  ///
  /// In ar, this message translates to:
  /// **'الشحن من الموقع'**
  String get walletTopupWebsite;

  /// D190 the website top-up link
  ///
  /// In ar, this message translates to:
  /// **'اشحن بالبطاقة على موقع Kabso Live الرسمي'**
  String get walletTopupWebsiteHint;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get settingsDeleteAccount;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'يُحذف نهائياً بعد 30 يوماً من الطلب'**
  String get settingsDeleteAccountHint;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get deleteAccountTitle;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {step} من {total}'**
  String deleteAccountStep(int step, int total);

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'قبل أن تحذف حسابك'**
  String get deleteAccountIntroTitle;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'ما سيُحذف'**
  String get deleteAccountWhatGoes;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'ملفك الشخصي واسمك وصورتك، منشوراتك ومقاطعك وقصصك، رسائلك، من تتابعهم ومن يتابعونك، وبريدك الإلكتروني.'**
  String get deleteAccountWhatGoesBody;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'ما ستخسره'**
  String get deleteAccountForfeit;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'رصيد العملات والكرزات وما في حقيبتك ووقت اسم المستخدم المميز. لا تُسترد ولا تُحوَّل.'**
  String get deleteAccountForfeitBody;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'ما نحتفظ به'**
  String get deleteAccountKept;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'سجلات المدفوعات والهدايا التي يطلبها القانون والمحاسبة ومكافحة الاحتيال، دون أي بيانات تعرّف بك. سيرى الآخرون «مستخدم محذوف» مكان اسمك.'**
  String get deleteAccountKeptBody;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'لديك {days} يوماً لتغيير رأيك: سجّل الدخول خلالها واختر «إلغاء الحذف». بعدها يُحذف الحساب نهائياً.'**
  String deleteAccountGrace(int days);

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'يجب تسوية هذا أولاً'**
  String get deleteAccountBlockedTitle;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'أنت وكيل شحن: تواصل مع الفريق لتسوية المخزون وإيقاف الوكالة.'**
  String get deleteAccountBlockerRechargeAgent;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'أنت مالك وكالة مضيفين: تواصل مع الفريق لنقل المضيفين وإيقاف الوكالة.'**
  String get deleteAccountBlockerHostAgency;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب سحب كرزات قيد التنفيذ: انتظر حتى يُدفع.'**
  String get deleteAccountBlockerPendingWithdrawal;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب بيع كرزات لوكيل شحن لم يُغلق بعد: أكمله أو ألغِه.'**
  String get deleteAccountBlockerPendingCherrySale;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'رصيدك سالب: تواصل مع الفريق لتسويته.'**
  String get deleteAccountBlockerNegativeBalance;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'هناك أمر يجب تسويته أولاً: تواصل مع الفريق.'**
  String get deleteAccountBlockerOther;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'للمساعدة راسلنا على {email}'**
  String deleteAccountContact(String email);

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'أكّد أنه أنت'**
  String get deleteAccountPasswordTitle;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة مرور حسابك للمتابعة.'**
  String get deleteAccountPasswordBody;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'تأكيد أخير'**
  String get deleteAccountConfirmTitle;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'اكتب «{word}» لتأكيد حذف حسابك.'**
  String deleteAccountConfirmBody(String word);

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get deleteAccountConfirmWord;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'كلمة التأكيد'**
  String get deleteAccountConfirmLabel;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'اكتب الكلمة كما هي.'**
  String get deleteAccountConfirmMismatch;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'احذف حسابي'**
  String get deleteAccountSubmit;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'استلمنا طلب حذف حسابك وسجّلنا خروجك من كل الأجهزة. يمكنك إلغاء الحذف بتسجيل الدخول خلال 30 يوماً.'**
  String get deleteAccountDoneBanner;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'طلب حذف قيد التنفيذ'**
  String get deletionPendingTitle;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحذف؟'**
  String get deletionPendingQuestion;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف هذا الحساب نهائياً في {date}. ألغِ الحذف ليعود حسابك كما كان.'**
  String deletionPendingBody(String date);

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف هذا الحساب نهائياً قريباً. ألغِ الحذف ليعود حسابك كما كان.'**
  String get deletionPendingBodyNoDate;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحذف'**
  String get deletionPendingCancel;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'متابعة الحذف'**
  String get deletionPendingKeep;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الحذف. مرحباً بعودتك.'**
  String get deletionPendingRestored;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'مستخدم محذوف'**
  String get deletedUser;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور غير صحيحة.'**
  String get errorReauthFailed;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'يجب تسوية بعض الأمور قبل حذف الحساب.'**
  String get errorAccountDeletionBlocked;

  /// D193 account deletion
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب في انتظار الحذف.'**
  String get errorAccountDeletionPending;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'بياناتك'**
  String get privacyDataTitle;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'تنزيل بياناتي'**
  String get dataExportTitle;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'نسخة من بياناتك بصيغة يمكنك نقلها'**
  String get dataExportTileHint;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'نجهّز لك ملف ZIP فيه بياناتك بصيغة JSON مع ملف توضيحي بالعربية والإنجليزية: ملفك وإعداداتك، منشوراتك وريلزك وقصصك، تعليقاتك، رسائلك، متابعاتك والحظر، سجلات العملات والكرز والمستويات، الهدايا، السحوبات، طلب وكيل الشحن، موافقاتك، وسجل الأجهزة وتسجيل الدخول.'**
  String get dataExportIntro;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'يمكنك طلب نسخة واحدة كل 24 ساعة. عندما تجهز نرسل لك إشعاراً ورسالة بريد، والتنزيل يعمل مرة واحدة خلال 7 أيام.'**
  String get dataExportRules;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'لا يحوي الملف كلمة مرورك ولا بيانات خاصة لأشخاص آخرين.'**
  String get dataExportNoSecrets;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'طلب نسخة من بياناتي'**
  String get dataExportRequest;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'تأكيد هويتك'**
  String get dataExportPasswordTitle;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة مرور حسابك لطلب نسخة من بياناتك.'**
  String get dataExportPasswordBody;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get dataExportPasswordLabel;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get dataExportContinue;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'استلمنا طلبك. سنرسل لك إشعاراً عندما تجهز بياناتك.'**
  String get dataExportRequested;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'نجهّز بياناتك… سنرسل لك إشعاراً عندما تجهز.'**
  String get dataExportPreparing;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'بياناتك جاهزة. التنزيل متاح مرة واحدة حتى {date}.'**
  String dataExportReady(String date);

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'تنزيل الملف'**
  String get dataExportDownload;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'حُفظ الملف في: {path}'**
  String dataExportSaved(String path);

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'نزّلت هذه النسخة في {date}.'**
  String dataExportDownloaded(String date);

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية آخر نسخة قبل تنزيلها.'**
  String get dataExportExpired;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز آخر نسخة. يمكنك طلب نسخة جديدة.'**
  String get dataExportFailed;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'يمكنك طلب نسخة جديدة بعد {date}.'**
  String dataExportNextAt(String date);

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get dataExportRefresh;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'حدّثنا الشروط وسياسة الخصوصية'**
  String get consentTitle;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'اقرأ ملخص التغييرات، ثم وافق لتتابع استخدام Kabso Live.'**
  String get consentBody;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get consentTermsName;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get consentPrivacyName;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version} · ساري من {date}'**
  String consentVersion(String version, String date);

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'قراءة النص الكامل'**
  String get consentReadFull;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'أوافق وأتابع'**
  String get consentAccept;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'لا توافق؟ يمكنك تنزيل بياناتك أو حذف حسابك أو تسجيل الخروج.'**
  String get consentNotNow;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get consentLogout;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'شكراً، سُجّلت موافقتك.'**
  String get consentAccepted;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'عمري 18 عاماً أو أكثر، وأوافق على شروط الاستخدام وسياسة الخصوصية.'**
  String get registerLegalAccept;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'أكّد عمرك ووافق على الشروط للمتابعة.'**
  String get registerLegalRequired;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'نسخة بياناتك جاهزة للتنزيل'**
  String get notifDataExportReady;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'راجع الشروط وسياسة الخصوصية المحدّثة ووافق عليها للمتابعة.'**
  String get errorConsentRequired;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'صدر إصدار أحدث للتو. راجعه من جديد.'**
  String get errorConsentVersionMismatch;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'يمكنك طلب نسخة واحدة من بياناتك كل 24 ساعة.'**
  String get errorDataExportLimit;

  /// D198 privacy
  ///
  /// In ar, this message translates to:
  /// **'رابط التنزيل لم يعد صالحاً.'**
  String get errorDataExportLinkInvalid;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'PK'**
  String get liveGiftTabPk;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'تحدي PK'**
  String get pkSheetTitle;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دعوة مضيف'**
  String get pkTabInvite;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'مطابقة عشوائية'**
  String get pkTabRandom;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مضيف مباشر'**
  String get pkSearchHint;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'مضيفون مباشرون الآن'**
  String get pkLiveNow;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مضيفون متاحون الآن'**
  String get pkNoCandidates;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دعوة'**
  String get pkInvite;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت الدعوة إلى {name}'**
  String pkInviteSent(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار رد {name}… {seconds}'**
  String pkWaitingFor(String name, String seconds);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get pkCancel;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المطابقة'**
  String get pkRandomStart;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البحث عن خصم… {time}'**
  String pkRandomSearching(String time);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف البحث'**
  String get pkRandomStop;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'نطابقك مع مضيف مباشر يبحث عن تحدٍ الآن.'**
  String get pkRandomHint;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'استقبال دعوات PK'**
  String get pkInvitesSwitch;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دعوة PK'**
  String get pkIncomingTitle;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'{name} يدعوك إلى تحدي PK'**
  String pkIncomingBody(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get pkAccept;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get pkDecline;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'رُفضت دعوتك'**
  String get pkNoticeDeclined;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الدعوة'**
  String get pkNoticeExpired;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد خصماً، حاول مجدداً'**
  String get pkNoticeQueueExpired;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء التحدي'**
  String get pkEnd;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء التحدي الآن؟'**
  String get pkEndConfirmTitle;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء التحدي قبل وقته يُحتسب انسحاباً ويفوز الخصم.'**
  String get pkEndConfirmBody;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'كتم الخصم'**
  String get pkMuteOpponent;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء كتم الخصم'**
  String get pkUnmuteOpponent;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دبل'**
  String get pkBoosterDouble;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دبل تيربو'**
  String get pkBoosterDoubleTurbo;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'تربل'**
  String get pkBoosterTriple;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'تربل تيربو'**
  String get pkBoosterTripleTurbo;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'×{multiplier} {time}'**
  String pkBoostChip(String multiplier, String time);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'PK {time}'**
  String pkRoundTimer(String time);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'فوز'**
  String get pkResultWin;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'خسارة'**
  String get pkResultLose;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'تعادل'**
  String get pkResultDraw;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'انسحب {name}'**
  String pkEndedForfeit(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'انقطع اتصال {name}'**
  String pkEndedDisconnect(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'غاب {name} عن التحدي'**
  String pkEndedAway(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'أنهى المشرف التحدي'**
  String get pkEndedAdmin;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'المعززات تعمل أثناء التحدي فقط'**
  String get pkBoosterNoMatch;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'متاح في آخر {minutes} من التحدي'**
  String pkBoosterTooEarly(String minutes);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get pkBoosterLastMinute;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'دقيقتين'**
  String get pkBoosterLastTwoMinutes;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'استُخدم الحد الأقصى لهذا المعزز في هذا التحدي'**
  String get pkBoosterLimit;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'معزز مساوٍ أو أقوى فعّال الآن'**
  String get pkBoosterActiveHigher;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'المضيف مشغول بتحدٍ أو دعوة أخرى'**
  String get pkErrorBusy;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'هذا المضيف لا يستقبل دعوات PK'**
  String get pkErrorInvitesOff;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'انتظر قليلاً قبل دعوة أخرى'**
  String get pkErrorCooldown;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن بدء تحدٍ الآن'**
  String get pkErrorUnavailable;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'الدعوة لم تعد متاحة'**
  String get pkErrorInviteClosed;

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'PK: {wins} فوز · {losses} خسارة · {draws} تعادل'**
  String pkRecord(String wins, String losses, String draws);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'الخصم {name}'**
  String pkOpponentPane(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'المضيف {name}'**
  String pkOwnPane(String name);

  /// v1.43-live (D195): PK 1 v 1.
  ///
  /// In ar, this message translates to:
  /// **'ضيف {name}'**
  String pkGuestSemantics(String name);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'PK ثنائي'**
  String get pkModeOneVsOne;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'PK رباعي'**
  String get pkModeTeam;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'PK متعدد'**
  String get pkModeMulti;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'{mode} قريباً — لم يُبنَ بعد'**
  String pkModeSoon(String mode);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الأصدقاء'**
  String get pkFriendsTab;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أصدقاء لدعوتهم حالياً'**
  String get pkNoFriends;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الأصدقاء: مضيفون تتابعهم ويتابعونك، وفي بث فيديو مباشر الآن. ابحث عن أي مضيف آخر بالاسم، أو جرّب المطابقة العشوائية.'**
  String get pkFriendsHelp;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'ما هو PK؟'**
  String get pkHelpTitle;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تحدٍّ بين مضيفَين: هدايا مشاهدي كل غرفة أثناء الجولة تصير نقاط PK (قيمة الهدية × المضاعِف). الأعلى نقاطاً يفوز. المعزِّزات ×2 / ×3 / ×5 / ×10 تضاعف النقاط فقط، لا المال.'**
  String get pkHelpBody;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'سجل PK'**
  String get pkHistoryTitle;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مباريات PK بعد'**
  String get pkHistoryEmpty;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'غير محتسبة'**
  String get pkHistoryNotCounted;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get pkHistoryVoid;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الجولات {own}–{other}'**
  String pkHistoryRounds(String own, String other);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'ضد {name}'**
  String pkHistoryVs(String name);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل سجل PK'**
  String get pkHistoryLoadError;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'إعدادات PK'**
  String get pkSettingsTitle;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل إعدادات PK'**
  String get pkSettingsLoadError;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'وضع PK'**
  String get pkSettingMode;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'جولة واحدة: جولة واحدة تحسم النتيجة. الأفضل من ثلاث: حتى 3 جولات بالمدة المختارة، ومن يفوز بجولتين يفوز. لكل جولة نقاطها ومعزِّزاتها.'**
  String get pkSettingModeHelp;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'جولة واحدة'**
  String get pkModeSingle;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الأفضل من ثلاث'**
  String get pkModeBestOfThree;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get pkSettingTime;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'{minutes} د'**
  String pkMinutes(String minutes);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'{minutes} دقائق'**
  String pkMinutesLong(String minutes);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'بدء PK مباشرة بعد الاتصال'**
  String get pkSettingAutoStart;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تفضيل الجنس في المطابقة العشوائية'**
  String get pkSettingGender;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get pkGenderBoth;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'ذكور'**
  String get pkGenderMale;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'إناث'**
  String get pkGenderFemale;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تفضيل المنطقة في المطابقة العشوائية'**
  String get pkSettingRegion;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'عالمي'**
  String get pkRegionGlobal;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'بلدي فقط'**
  String get pkRegionSame;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'مطابقة تلقائية'**
  String get pkSettingAutoMatch;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'وأنت في بث فيديو ولست في PK، تدخل المطابقة العشوائية تلقائياً.'**
  String get pkSettingAutoMatchHelp;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'السماح باقتراحي على المضيفين الآخرين'**
  String get pkSettingRecommend;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'1. PK فعّال: مجموع نقاط PK للطرفين ≥ {points} (يُحتسب في سجلك).'**
  String pkSettingsNoteEffective(String points);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'2. إذا اختلفت إعدادات المضيفَين، يُختار إعداد أحدهما عشوائياً.'**
  String get pkSettingsNoteRandom;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'هذا الوضع قريباً — لا إعدادات له بعد'**
  String get pkSettingsSoonTab;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ الإعداد'**
  String get pkSettingSaveError;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'ابدأ PK'**
  String get pkStart;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تم الاتصال — يبدأ PK حين يضغط أحدكما «ابدأ PK»'**
  String get pkConnectedHint;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الجولة {round}/3'**
  String pkRoundLabel(String round);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'طُبِّقت إعدادات {name} (اختيار عشوائي)'**
  String pkSettingsFromOther(String name);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'فعّل فريق {host} {booster}'**
  String pkBoostActivated(String host, String booster);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'+{points} ×{multiplier}'**
  String pkBoostGain(String points, String multiplier);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'{booster} ×{multiplier}، يتبقى {seconds} ث'**
  String pkBoostChipSemantics(
    String booster,
    String multiplier,
    String seconds,
  );

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'بيانات البث'**
  String get liveDataPageTitle;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'وقت البث'**
  String get liveDataNowLiveTime;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'مشاهدون فريدون'**
  String get liveDataNowViewers;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الذروة {peak}'**
  String liveDataNowViewersHint(String peak);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'كرز جديد'**
  String get liveDataNowCherries;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'داعمو الهدايا'**
  String get liveDataNowGivers;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'متابعون جدد'**
  String get liveDataNowFans;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'مركز المبدعين'**
  String get liveDataCreatorCenter;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'Lv.{level}'**
  String liveDataLevel(String level);

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'مستوى الجاذبية: يرتفع بقيمة الهدايا التي تصلك.'**
  String get liveDataLevelHelp;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'إحصاءات الفترات السابقة'**
  String get liveDataHistory;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'تظهر بيانات البث أثناء بثّك المباشر.'**
  String get liveDataNotLive;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'HD'**
  String get liveToolHd;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'فلاش'**
  String get liveToolFlash;

  /// v1.44-live (D199): the host's live tools, PK sheet and PK Setting (owner «طبق تصميم 100%»).
  ///
  /// In ar, this message translates to:
  /// **'الألعاب'**
  String get liveHostBox;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'تارجت'**
  String get liveTargetChip;

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'هدف الهدايا اليوم: {received} كرز'**
  String liveTargetCherriesSemantics(String received);

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'هدف هدايا الحظ اليوم: {received} كرز'**
  String liveTargetLuckySemantics(String received);

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'تم بلوغ الهدف'**
  String get liveTargetReached;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'يومي'**
  String get liveTargetPeriodDay;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get liveTargetPeriodWeek;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get liveTargetPeriodMonth;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get liveTargetPeriodAll;

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'الهدايا'**
  String get liveTargetCherriesSection;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الحظ'**
  String get liveTargetLuckySection;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'أفضل الداعمين'**
  String get liveTargetTopSupporters;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد داعمون بعد'**
  String get liveTargetNoSupporters;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'أهداف اليوم'**
  String get liveTargetToday;

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'هدف الهدايا'**
  String get liveTargetCherriesGoal;

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'هدف هدايا الحظ'**
  String get liveTargetLuckyGoal;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'لا هدف اليوم'**
  String get liveTargetNoTarget;

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'هدف الهدايا هو هدف مهمة «هدف الهدايا» لفئتك ({band})، بالكرز.'**
  String liveTargetConversion(int band);

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'مركز المهام'**
  String get liveTargetTaskCenter;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الإحصاءات'**
  String get liveTargetLoadError;

  /// v1.44-live (D199): the «تارجت» chip and the host gift stats sheet.
  ///
  /// In ar, this message translates to:
  /// **'الفترات حسب توقيت الرياض.'**
  String get liveTargetZoneHint;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'القصص'**
  String get reelsChipStories;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'الغرف'**
  String get reelsChipRooms;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'فتح القصص'**
  String get reelsOpenStories;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'فتح الغرف الصوتية'**
  String get reelsOpenRooms;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قصص الآن. أضف قصتك أو تابع أشخاصاً لترى قصصهم.'**
  String get reelsStoriesEmpty;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'مشاركة، {count}'**
  String reelsShareLabel(String count);

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'التعليقات، {count}'**
  String reelsCommentsLabel(String count);

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'{author} على Kabso Live: {caption}'**
  String reelsShareText(String author, String caption);

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'شاهد ريل {author} على Kabso Live'**
  String reelsShareTextNoCaption(String author);

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'صوت أصلي · {name}'**
  String reelsOriginalSound(String name);

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get reelsMore;

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'طلب متابعة {name}'**
  String reelsRequestFollow(String name);

  /// D202 the reels page
  ///
  /// In ar, this message translates to:
  /// **'طلبت متابعة {name}'**
  String reelsFollowRequested(String name);

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'العد التنازلي {hours}س {minutes}د'**
  String liveTargetCountdownHours(String hours, String minutes);

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'العد التنازلي {days}ي {hours}س'**
  String liveTargetCountdownDays(String days, String hours);

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get liveTargetRangeToday;

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get liveTargetRangeWeek;

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get liveTargetRangeMonth;

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'كل الوقت'**
  String get liveTargetRangeAll;

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'ما هو التارجت؟'**
  String get liveTargetHelpTitle;

  /// v1.69-live (D277): «هدف الهدايا» / «هدف هدايا الحظ», both in cherries (the key keeps its D199 name).
  ///
  /// In ar, this message translates to:
  /// **'للمضيف هدفان كل يوم، كلاهما بالكرز الذي يصله فعلاً: هدف الهدايا (من كل الهدايا غير هدايا الحظ التي يرسلها الآخرون) وهدف هدايا الحظ (من هدايا الحظ، ومنها ما يرسله المضيف لنفسه). يبدأ العد من جديد عند منتصف الليل بتوقيت الرياض. القائمة ترتّب الداعمين في الفترة المختارة: بالكرز في «الهدايا» وبالعملات في «هدايا الحظ».'**
  String get liveTargetHelp;

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'ادعم'**
  String get liveTargetSupport;

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'ترتيبك {rank}: {amount}'**
  String liveTargetMyPlace(String rank, String amount);

  /// v1.44-live (D199b): the «تارجت» ranking sheet.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get liveTargetClose;

  /// D210: under a failed go-live, the step and error type that failed (technical code, shown as is) so a device report names it
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل: {code}'**
  String goLiveFailureDetails(String code);

  /// D210: an optional live tool (PK, music, targets…) failed to start and was switched off; the live goes on
  ///
  /// In ar, this message translates to:
  /// **'بعض أدوات البث لم تعمل وأُوقفت. البث مستمر.'**
  String get goLiveToolsDegraded;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلبات الشحن'**
  String get rechargeOrdersTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلباتك من الوكلاء ومحادثة كل طلب'**
  String get rechargeOrdersHint;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'مشترياتي'**
  String get rechargeOrdersMine;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'الطلبات الواردة'**
  String get rechargeOrdersIncoming;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'{count} طلب ينتظرك · {coins} عملة مجمّدة'**
  String rechargeOrdersIncomingHint(String count, String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد'**
  String get rechargeOrdersEmpty;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اختر وكيلاً من «وكلاء الشحن» ثم «اطلب شحن».'**
  String get rechargeOrdersEmptyBody;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اطلب شحن'**
  String get rechargeOrderNew;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلب شحن جديد'**
  String get rechargeOrderNewTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'عدد العملات'**
  String get rechargeOrderCoins;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'من {min} إلى {max} عملة'**
  String rechargeOrderCoinsRange(String min, String max);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get rechargeOrderPrice;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'{amount} دولار'**
  String rechargeOrderUsd(String amount);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'≈ {amount} {currency} (1 دولار = {rate})'**
  String rechargeOrderLocal(String amount, String currency, String rate);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سعر صرف لهذا البلد: السعر بالدولار فقط.'**
  String get rechargeOrderUsdOnly;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'السعر يحسبه Kabso حسب السعر الموحد للعملات.'**
  String get rechargeOrderPriceNote;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get rechargeOrderPaymentMethod;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get rechargeOrderSubmit;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تدفع للوكيل خارج التطبيق. عند إرسال معلومات الدفع تُجمَّد العملات من رصيد الوكيل حتى يؤكد استلام المبلغ.'**
  String get rechargeOrderOutsideNote;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلب شحن'**
  String get rechargeOrderTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'بانتظار معلومات الدفع من الوكيل'**
  String get rechargeOrderStatusRequested;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التحويل'**
  String get rechargeOrderStatusAwaiting;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تم الإرسال — بانتظار تأكيد الوكيل'**
  String get rechargeOrderStatusPaid;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'نزاع — الإدارة تراجع الطلب'**
  String get rechargeOrderStatusDisputed;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'مكتمل — أُضيفت العملات'**
  String get rechargeOrderStatusCompleted;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت العملات بقرار الإدارة'**
  String get rechargeOrderStatusByAdmin;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت العملات إلى الوكيل بقرار الإدارة'**
  String get rechargeOrderStatusRefunded;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get rechargeOrderStatusCancelled;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الطلب'**
  String get rechargeOrderStatusExpired;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلب شحن'**
  String get rechargeOrderStatusUnknown;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة مجمّدة لهذا الطلب'**
  String rechargeOrderFrozen(String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة'**
  String rechargeOrderCoinsLine(String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تعليمات الحماية'**
  String get rechargeOrderNoticeTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'يرجى أخذ لقطة شاشة وتسجيل فيديو للشاشة منذ لحظة مغادرة المحادثة وحتى وصول الحوالة إلى المعلومات التي قدّمها الوكيل، لحمايتكم من أي خطأ أو احتيال. عند التحويل أرسل لقطة شاشة للحوالة واحتفظ بفيديو الشاشة حتى تصلك العملات.'**
  String get rechargeOrderNotice;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'قرأت وفهمت'**
  String get rechargeOrderNoticeAck;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'قمت بالإرسال'**
  String get rechargeOrderSent;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أرفق لقطة شاشة الحوالة'**
  String get rechargeOrderSentTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اختر لقطة شاشة التحويل؛ تُرسل في المحادثة كإثبات. احتفظ بفيديو الشاشة حتى تصلك العملات.'**
  String get rechargeOrderSentBody;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اختيار لقطة الشاشة'**
  String get rechargeOrderPickScreenshot;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اختر صورة JPEG أو PNG أو WebP.'**
  String get rechargeOrderBadImage;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'يمكنك فتح نزاع بعد {time}'**
  String rechargeOrderCountdown(String time);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من وصول الحوالة · {time} قبل أن يستطيع المشتري فتح نزاع'**
  String rechargeOrderCountdownAgent(String time);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة الانتظار. إن لم تصلك العملات افتح نزاعاً.'**
  String get rechargeOrderWaitOver;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'انتهت مدة الانتظار: يمكن للمشتري فتح نزاع الآن.'**
  String get rechargeOrderWaitOverAgent;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'نزاع'**
  String get rechargeOrderDispute;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'فتح نزاع'**
  String get rechargeOrderDisputeTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تبقى العملات مجمّدة، وتدخل الإدارة المحادثة لمراجعة الإثباتات وتقرّر.'**
  String get rechargeOrderDisputeBody;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'ماذا حدث؟ (اختياري)'**
  String get rechargeOrderDisputeReason;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'استلمت'**
  String get rechargeOrderReceived;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الاستلام'**
  String get rechargeOrderReceivedTitle;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تأكد أن المبلغ وصل فعلاً إلى حسابك. بعد التأكيد تُضاف {coins} عملة إلى المشتري ولا يمكن التراجع.'**
  String rechargeOrderReceivedBody(String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'إرسال معلومات الدفع'**
  String get rechargeOrderSendDetails;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'معلومات التحويل'**
  String get rechargeOrderDetailsLabel;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'رقم المحفظة أو الحساب واسم المستلم'**
  String get rechargeOrderDetailsHint;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'عند الإرسال تُجمَّد {coins} عملة من رصيدك لهذا الطلب حتى تؤكد الاستلام.'**
  String rechargeOrderDetailsBody(String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get rechargeOrderCancel;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء الطلب؟ تعود أي عملات مجمّدة إلى رصيد الوكيل.'**
  String get rechargeOrderCancelBody;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get rechargeOrderKeep;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة…'**
  String get rechargeOrderChatHint;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'المحادثة مغلقة'**
  String get rechargeOrderChatClosed;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'الإدارة'**
  String get rechargeOrderRoleAdmin;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'معلومات الدفع · {method}'**
  String rechargeOrderPaymentDetails(String method);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'لقطة شاشة الحوالة'**
  String get rechargeOrderProof;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ معلومات الدفع'**
  String get rechargeOrderCopied;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أُنشئ الطلب'**
  String get rechargeOrderEventCreated;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أرسل الوكيل معلومات الدفع وجُمّدت العملات'**
  String get rechargeOrderEventDetails;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أقرّ المشتري بتعليمات الحماية'**
  String get rechargeOrderEventNotice;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'ضغط المشتري «قمت بالإرسال»'**
  String get rechargeOrderEventPaid;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أكّد الوكيل الاستلام وأُضيفت العملات'**
  String get rechargeOrderEventCompleted;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'فتح المشتري نزاعاً'**
  String get rechargeOrderEventDisputedBuyer;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'فتح الوكيل نزاعاً'**
  String get rechargeOrderEventDisputedAgent;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'ألغى المشتري الطلب'**
  String get rechargeOrderEventCancelledBuyer;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'ألغى الوكيل الطلب'**
  String get rechargeOrderEventCancelledAgent;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الطلب'**
  String get rechargeOrderEventExpired;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'قرار الإدارة: العملات للمشتري'**
  String get rechargeOrderEventForBuyer;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'قرار الإدارة: العملات تعود للوكيل'**
  String get rechargeOrderEventForAgent;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تحديث على الطلب'**
  String get rechargeOrderEventOther;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلب شحن جديد ينتظر معلومات الدفع ({coins} عملة)'**
  String notifRechargeOrderCreated(String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أرسل الوكيل معلومات الدفع لطلب الشحن'**
  String get notifRechargeOrderDetails;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أكّد المشتري إرسال المبلغ: تحقّق من وصول الحوالة'**
  String get notifRechargeOrderPaid;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت {coins} عملة من طلب الشحن'**
  String notifRechargeOrderCompleted(String coins);

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'فُتح نزاع على طلب الشحن'**
  String get notifRechargeOrderDisputed;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أُغلق النزاع وأُعيدت العملات إلى الوكيل'**
  String get notifRechargeOrderRefunded;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'أُلغي طلب الشحن'**
  String get notifRechargeOrderCancelled;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة طلب الشحن'**
  String get notifRechargeOrderExpired;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'رسالة من الإدارة في طلب الشحن'**
  String get notifRechargeOrderAdmin;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'رسالة جديدة في طلب الشحن'**
  String get notifRechargeOrderMessage;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'طلبات الشحن غير متاحة حالياً.'**
  String get errorRechargeOrdersUnavailable;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب مفتوح مع هذا الوكيل.'**
  String get errorRechargeOrderOpenExists;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'تغيّرت حالة الطلب. حدّث الصفحة.'**
  String get errorRechargeOrderStateChanged;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'اقرأ تعليمات الحماية وأقرّ بها أولاً.'**
  String get errorRechargeOrderNoticeRequired;

  /// D204 recharge orders
  ///
  /// In ar, this message translates to:
  /// **'يمكنك فتح نزاع بعد انتهاء مدة الانتظار.'**
  String get errorRechargeOrderDisputeTooEarly;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يوم واحد} =2{يومين} few{{days} أيام} many{{days} يومًا} other{{days} يوم}}'**
  String agencyDaysCount(int days);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'{hosts, plural, =1{مضيف واحد} =2{مضيفَين} few{{hosts} مضيفين} many{{hosts} مضيفًا} other{{hosts} مضيف}}'**
  String agencyHostsCount(int hosts);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'{hours, plural, =0{أقل من ساعة} =1{ساعة واحدة} =2{ساعتين} few{{hours} ساعات} many{{hours} ساعة} other{{hours} ساعة}}'**
  String agencyHoursCount(int hours);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'افتح وكالة'**
  String get agencyOpenButton;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'مجانًا — تُنشأ وكالتك فورًا'**
  String get agencyOpenButtonHint;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'افتح وكالة'**
  String get agencyOpenTitle;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'فتح الوكالة مجاني'**
  String get agencyOpenFree;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'تُنشأ وكالتك فورًا بعد الإرسال. خلال {days} يجب أن تفعّل {hosts} على الأقل: ينضم المضيف إلى وكالتك ثم يفتح بثًا ويستلم هدايا. إن لم يتحقق ذلك تُغلق الوكالة تلقائيًا ويصلك إشعار بالسبب.'**
  String agencyOpenRule(String days, String hosts);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'بيانات الوكالة'**
  String get agencyOpenStepInfo;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اسم الوكالة'**
  String get agencyOpenName;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا من حرفين إلى 40 حرفًا'**
  String get agencyOpenNameError;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get agencyOpenCountry;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اختر البلد'**
  String get agencyOpenCountryError;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'وسيلة التواصل'**
  String get agencyOpenContactType;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'رقم أو معرّف التواصل'**
  String get agencyOpenContactValue;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اكتب 3 أحرف على الأقل'**
  String get agencyOpenContactError;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get agencyContactWhatsapp;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'تيليجرام'**
  String get agencyContactTelegram;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'هاتف'**
  String get agencyContactPhone;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'بريد إلكتروني'**
  String get agencyContactEmail;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get agencyContactOther;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'عدد المضيفين المتوقع'**
  String get agencyOpenExpected;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'من 1 إلى 10000'**
  String get agencyOpenExpectedError;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'نبذة قصيرة'**
  String get agencyOpenBio;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اختياري، حتى 300 حرف'**
  String get agencyOpenBioHint;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الهوية (إلزامي)'**
  String get agencyOpenStepId;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'صورة الهوية'**
  String get agencyOpenIdCard;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'صورة واضحة لبطاقة الهوية أو جواز السفر'**
  String get agencyOpenIdCardHint;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أضف صورة الهوية والسيلفي'**
  String get agencyOpenIdMissing;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'صور الهوية خاصة: لا يراها إلا فريق Kabso Live، وكل عرض لها يُسجَّل.'**
  String get agencyOpenPrivacy;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'افتح الوكالة مجانًا'**
  String get agencyOpenSubmit;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'فُتحت وكالتك. فعّل مضيفيك خلال فترة التجربة'**
  String get agencyOpenDone;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'لديك وكالة بالفعل'**
  String get agencyOpenOwns;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أنت مضيف في وكالة. غادرها أولًا لتفتح وكالة'**
  String get agencyOpenIsHost;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'حسابك غير نشط'**
  String get agencyOpenNotActive;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك فتح وكالة جديدة من {date}'**
  String agencyOpenCooldown(String date);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'فترة التجربة'**
  String get agencyProbationTitle;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ: {days} و{hours}'**
  String agencyProbationLeft(String days, String hours);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ: {hours}'**
  String agencyProbationLeftHours(String hours);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'انتهت المدة، يجري التحقق الآن'**
  String get agencyProbationEnding;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'المضيفون المفعّلون: {count} / {required}'**
  String agencyProbationActivated(String count, String required);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'فعّل {hosts} خلال {days}: ينضم المضيف ثم يبثّ ويستلم هدايا.'**
  String agencyProbationRuleShort(String hosts, String days);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'انضم'**
  String get agencyProbationJoined;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'بثّ'**
  String get agencyProbationLive;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'استلم هدايا'**
  String get agencyProbationGifts;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'لا مضيفين بعد. شارك رمز الدعوة ليبدأ المضيفون.'**
  String get agencyProbationNoHosts;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اجتازت وكالتك فترة التجربة'**
  String get agencyProbationPassed;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get agencyShare;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى وكالتي على Kabso Live برمز الدعوة: {code}'**
  String agencyShareText(String code);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت الوكالة'**
  String get agencyClosedTitle;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'لم تفعّل {hosts} (بثّ واستلام هدايا) خلال فترة التجربة. المفعّلون: {count}'**
  String agencyClosedProbation(String hosts, String count);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أغلقها فريق Kabso Live'**
  String get agencyClosedAdmin;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإغلاق: {date}'**
  String agencyClosedOn(String date);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك فتح وكالة جديدة الآن'**
  String get agencyReopenNow;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'فُتحت وكالتك. فعّل مضيفيك خلال فترة التجربة'**
  String get notifAgencyOpened;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'بقي أقل من يوم على نهاية فترة التجربة: المفعّلون {count} / {required}'**
  String notifAgencyReminder(String count, String required);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'اجتازت وكالتك فترة التجربة'**
  String get notifAgencyPassed;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت وكالتك لأنها لم تفعّل {hosts} (بثّ واستلام هدايا) خلال فترة التجربة. المفعّلون: {count}'**
  String notifAgencyClosedProbation(String hosts, String count);

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت وكالتك من قِبل فريق Kabso Live'**
  String get notifAgencyClosedAdmin;

  /// v1.70-social (D206): «افتح وكالة».
  ///
  /// In ar, this message translates to:
  /// **'أُغلقت الوكالة التي كنت فيها، وأصبحت حرًا للانضمام إلى وكالة أخرى'**
  String get notifAgencyHostReleased;

  /// v1.70-social (D206): AGENCY_OPEN_NOT_ALLOWED.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك فتح وكالة الآن'**
  String get errorAgencyOpenNotAllowed;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'حسابك مقفل مؤقتاً من فريق Kabso.'**
  String get errorAccountLocked;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'حسابك مقفل مؤقتاً حتى {date}. السبب: {reason}'**
  String errorAccountLockedUntil(String date, String reason);

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة موقوفة لحسابك مؤقتاً.'**
  String get errorAccountRestricted;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'{what} موقوف لحسابك حتى {date}.'**
  String errorAccountRestrictedUntil(String what, String date);

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرسائل والتعليقات'**
  String get restrictionChatMute;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'البث المباشر'**
  String get restrictionNoLive;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الهدايا'**
  String get restrictionNoGifts;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'النشر'**
  String get restrictionNoPosting;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'اختر كلمة مرور جديدة للمتابعة.'**
  String get errorPasswordChangeRequired;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور جديدة'**
  String get passwordChangeTitle;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'طلب فريق Kabso تغيير كلمة مرور حسابك. اختر كلمة مرور جديدة لتسجيل الدخول؛ ستنتهي جلساتك الأخرى.'**
  String get passwordChangeBody;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get passwordChangeNew;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get passwordChangeConfirm;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين.'**
  String get passwordChangeMismatch;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'اختر كلمة مرور مختلفة عن الحالية.'**
  String get passwordChangeSame;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'٨ أحرف على الأقل.'**
  String get passwordChangeTooShort;

  /// v1.72-social (D208): the team's account controls.
  ///
  /// In ar, this message translates to:
  /// **'حفظ وتسجيل الدخول'**
  String get passwordChangeSubmit;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'كن مضيفاً مع الإدارة'**
  String get hostApplyTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'تبثّ مباشرة مع فريق Kabso Live، بلا وكالة وبلا عمولة وكالة. نراجع طلبك ونبلغك بالنتيجة.'**
  String get hostApplyIntro;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'قدّم الطلب'**
  String get hostApplyButton;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة'**
  String get hostApplyPendingTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'أرسلت طلبك في {date}. سنبلغك عند القرار.'**
  String hostApplyPendingBody(String date);

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get hostApplyCancel;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'إلغاء طلبك؟'**
  String get hostApplyCancelConfirmTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك التقديم مرة أخرى في أي وقت.'**
  String get hostApplyCancelConfirmBody;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'إبقاء الطلب'**
  String get hostApplyCancelKeep;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'أُلغي طلبك'**
  String get hostApplyCancelled;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'أنت مضيف مع الإدارة ✓'**
  String get hostApplyApprovedTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك البث الآن مباشرة مع فريق Kabso Live، بلا وكالة.'**
  String get hostApplyApprovedBody;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البث'**
  String get hostApplyGoLive;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لديك صلاحية البث'**
  String get hostApplyHostAgencyTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لم تتم الموافقة على طلبك'**
  String get hostApplyRejectedTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String hostApplyRejectedReason(String reason);

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك التقديم مجدداً من {date}'**
  String hostApplyReapplyOn(String date);

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك التقديم مجدداً الآن'**
  String get hostApplyReapplyNow;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'حسابك غير نشط الآن، فلا يمكنك التقديم'**
  String get hostApplyNotActive;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'مضيف مع الإدارة'**
  String get hostApplyFormTitle;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'بياناتك'**
  String get hostApplyStepInfo;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'الاسم الظاهر في البث'**
  String get hostApplyName;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'تأكد أنه الاسم الذي تريد أن يراه المشاهدون'**
  String get hostApplyNameHint;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'اكتب الاسم الظاهر'**
  String get hostApplyNameError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get hostApplyCountry;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'اختر بلدك'**
  String get hostApplyCountryError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الميلاد'**
  String get hostApplyBirth;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ'**
  String get hostApplyBirthPick;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخ ميلادك'**
  String get hostApplyBirthError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'البث مع الإدارة للبالغين فقط ({age}+)'**
  String hostApplyMinAge(String age);

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'وسيلة التواصل'**
  String get hostApplyContactType;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'رقمك أو معرّفك'**
  String get hostApplyContactValue;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'اكتب وسيلة تواصل نصل بها إليك'**
  String get hostApplyContactError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'نبذة: ماذا ستبث؟'**
  String get hostApplyBio;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'مثال: طبخ، ألعاب، دردشة، موسيقى'**
  String get hostApplyBioHint;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'اكتب نبذة قصيرة عمّا ستبثه'**
  String get hostApplyBioError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'حساباتك في منصات البث (اختياري)'**
  String get hostApplyLinks;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'إضافة رابط'**
  String get hostApplyAddLink;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'رابط يبدأ بـ https://'**
  String get hostApplyLinkError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'تحقق الهوية (إلزامي)'**
  String get hostApplyStepId;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'قواعد المضيفين'**
  String get hostApplyStepRules;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'• احترم المشاهدين، ولا تبث محتوى مسيئاً أو للبالغين.\n• لا تطلب الهدايا بالإكراه أو الخداع، ولا تبث محتوى غيرك دون حق.\n• حافظ على خصوصيتك وخصوصية الآخرين.\n• يسحب الفريق صلاحية البث عند مخالفة القواعد.'**
  String get hostApplyRulesText;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'قرأت قواعد المضيفين وأوافق عليها'**
  String get hostApplyRulesAccept;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'وافق على القواعد للمتابعة'**
  String get hostApplyRulesError;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'صورك وبياناتك خاصة: يراها فريق المراجعة فقط، ولا تظهر لأي أحد.'**
  String get hostApplyPrivacy;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'أرسل الطلب'**
  String get hostApplySubmit;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'أُرسل طلبك. سنبلغك بالنتيجة'**
  String get hostApplySent;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب قيد المراجعة بالفعل'**
  String get hostApplyRefusedPending;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لديك صلاحية البث بالفعل'**
  String get hostApplyRefusedHost;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'أنت في وكالة: البث مع الإدارة لمن ليس في وكالة'**
  String get hostApplyRefusedAgency;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك التقديم مجدداً الآن'**
  String get hostApplyRefusedCooldown;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة على طلبك: أنت الآن مضيف مع إدارة Kabso Live ويمكنك بدء البث'**
  String get notifHostApproved;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لم تتم الموافقة على طلبك لتكون مضيفاً مع الإدارة. افتح «الوكالة» لمعرفة السبب'**
  String get notifHostRejected;

  /// v1.73-social (D209): «كن مضيفاً مع الإدارة».
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك التقديم الآن'**
  String get errorHostApplicationNotAllowed;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'تصنيفات البث'**
  String get liveCategoryRowLabel;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get liveCategoryAll;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث مباشر'**
  String get liveCategoryLive;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث صوتي'**
  String get liveCategoryAudio;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث بودكاست'**
  String get liveCategoryPodcast;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث ستريمر'**
  String get liveCategoryStreamer;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث الستريمر قريباً'**
  String get liveStreamerSoonTitle;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'قريباً تبث شاشة هاتفك مباشرة لمتابعيك.'**
  String get liveStreamerSoonBody;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'لا بودكاست مباشر الآن'**
  String get livePodcastEmptyTitle;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ابدأ حلقتك أو عُد لاحقاً.'**
  String get livePodcastEmptyBody;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'حلقات قادمة'**
  String get podcastUpcoming;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني'**
  String get podcastRemindMe;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'سنذكّرك'**
  String get podcastReminderOn;

  /// D212: when an announced episode starts (already formatted).
  ///
  /// In ar, this message translates to:
  /// **'{time}'**
  String podcastStartsAt(String time);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'المستمعون · {count}'**
  String podcastListeners(String count);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل ‹'**
  String get podcastSeeAll;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'الحلقة {number}'**
  String podcastEpisode(int number);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get podcastLiveTag;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ريادة أعمال'**
  String get podcastTopicBusiness;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'تقنية'**
  String get podcastTopicTech;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'رياضة'**
  String get podcastTopicSports;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'دين'**
  String get podcastTopicReligion;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مجتمع'**
  String get podcastTopicSociety;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ترفيه'**
  String get podcastTopicEntertainment;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get podcastTopicOther;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ارفع يدك'**
  String get podcastRaiseHand;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'أنزل يدك'**
  String get podcastLowerHand;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'يدك مرفوعة. اضغط لإنزالها.'**
  String get podcastHandUp;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'عُد إلى المستمعين'**
  String get podcastLeaveStage;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ارفع يدك'**
  String get podcastAskTitle;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'سؤالك باختصار (اختياري)'**
  String get podcastAskHint;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ارفع يدي'**
  String get podcastAskSend;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'رفع الأيدي ✋'**
  String get podcastHandsTitle;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا طلبات} =1{طلب واحد} =2{طلبان} few{{count} طلبات} many{{count} طلباً} other{{count} طلب}}'**
  String podcastHandsRequests(int count);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مقعد متاح} =1{مقعد واحد متاح} =2{مقعدان متاحان} other{{count} مقاعد متاحة}}'**
  String podcastHandsSeats(int count);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get podcastLater;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'اصعد'**
  String get podcastBringUp;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'لا أيدي مرفوعة الآن.'**
  String get podcastNoHands;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'{count} أيدٍ مرفوعة'**
  String podcastHandsBadge(int count);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مدة السؤال'**
  String get podcastQuestionTime;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'{count} د'**
  String podcastMinutes(int count);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بدون حد'**
  String get podcastNoLimit;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'استقبال الأسئلة'**
  String get podcastQuestionsOpen;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'سؤال · {time}'**
  String podcastQuestionPill(String time);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'المضيف لا يستقبل أسئلة الآن.'**
  String get podcastQuestionsClosed;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'المقاعد الثلاثة ممتلئة. أنزل متحدثاً أولاً.'**
  String get podcastSeatsFull;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get podcastDeferred;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'إنزال إلى المستمعين'**
  String get podcastSpeakerDown;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'موضوع الحلقة'**
  String get podcastSetupTopic;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'عنوان الحلقة'**
  String get podcastSetupTitleHint;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'اكتب عنوان الحلقة أولاً.'**
  String get podcastSetupTitleRequired;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'الضيوف (حتى 3)'**
  String get podcastSetupGuests;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'إضافة ضيف'**
  String get podcastSetupAddGuest;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'نرسل الدعوة لكل ضيف عند دخوله البث.'**
  String get podcastSetupGuestsNote;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم المستخدم'**
  String get podcastSetupGuestSearch;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'أسئلة المستمعين'**
  String get podcastSetupQuestions;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مفتوحة'**
  String get podcastSetupOpen;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مغلقة'**
  String get podcastSetupClosed;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get podcastSetupWhen;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get podcastSetupNow;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'جدولة'**
  String get podcastSetupSchedule;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'جُدولت الحلقة. نذكّر متابعيك قبلها بـ 15 دقيقة.'**
  String get podcastSetupScheduled;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'جدولة الحلقة'**
  String get podcastSetupScheduleAction;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث بودكاست'**
  String get goLiveModePodcast;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'بث ستريمر'**
  String get goLiveModeStreamer;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'ستريمر'**
  String get liveCardTagStreamer;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'قريباً على آيفون'**
  String get goLiveStreamerSoonIos;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'بث ستريمر قريباً على آيفون'**
  String get goLiveStreamerIosSnack;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'يرى المشاهدون شاشة هاتفك، لعبة أو تطبيق، مع فقاعة صغيرة من كاميرتك الأمامية.'**
  String get streamerSetupBody;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'فقاعة الكاميرا'**
  String get streamerCameraBubble;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'مكان الفقاعة'**
  String get streamerCameraCorner;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'أعلى اليسار'**
  String get streamerCornerTopLeft;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'أعلى اليمين'**
  String get streamerCornerTopRight;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'أسفل اليسار'**
  String get streamerCornerBottomLeft;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'أسفل اليمين'**
  String get streamerCornerBottomRight;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون'**
  String get streamerMic;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'صوت اللعبة'**
  String get streamerGameAudio;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'بعض الألعاب تمنع التقاط صوتها'**
  String get streamerGameAudioNote;

  /// D213 (the streamer live): the setup's and the on-air tip while the game sound is on and no headset is connected (the speaker's game sound would reach the microphone too).
  ///
  /// In ar, this message translates to:
  /// **'استخدم سماعات حتى لا يُسمع صوت اللعبة مرتين'**
  String get streamerHeadphonesTip;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'صوت اللعبة يحتاج أندرويد 10 أو أحدث، سيُبث صوت الميكروفون فقط'**
  String get streamerGameAudioOld;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'لا يرى المشاهدون شاشتك وأنت داخل Kabso Live'**
  String get streamerPrivacyNote;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'لم تسمح بتصوير الشاشة، لذلك لم يبدأ البث'**
  String get streamerConsentRefused;

  /// D262: the system's screen-capture consent could not be asked or never showed; code is a short technical reason (e.g. instant_cancel).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر طلب إذن تصوير الشاشة ({code})'**
  String streamerConsentFailed(String code);

  /// D262b: the go-live streamer panel's one-line hint before Android's screen-capture dialog (whole screen).
  ///
  /// In ar, this message translates to:
  /// **'اضغط \"بدء\" في نافذة أندرويد لمشاركة شاشتك'**
  String get streamerConsentHint;

  /// D262: allowed, but the screen could not start again («شارك الشاشة من جديد»).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل مشاركة الشاشة، حاول مرة أخرى'**
  String get streamerShareAgainFailed;

  /// D346: the live's foreground service (type mediaProjection) could not start or was not running when the screen capture started.
  ///
  /// In ar, this message translates to:
  /// **'لم يسمح أندرويد بتشغيل خدمة البث، فلا يمكن تصوير الشاشة. افتح Kabso Live من جديد وحاول مرة أخرى'**
  String get streamerFailServiceDenied;

  /// D346: Android threw a SecurityException for the screen capture (e.g. a spent consent).
  ///
  /// In ar, this message translates to:
  /// **'رفض أندرويد تصوير الشاشة لأسباب أمان. اضغط «ابدأ البث» من جديد واختر «بدء» في نافذة أندرويد'**
  String get streamerFailSecurity;

  /// D346: the system stopped the MediaProjection because the live's foreground service was gone.
  ///
  /// In ar, this message translates to:
  /// **'أوقف أندرويد تصوير الشاشة لأن خدمة البث توقفت'**
  String get streamerFailStoppedBySystem;

  /// D346: the Android version cannot capture the screen.
  ///
  /// In ar, this message translates to:
  /// **'إصدار أندرويد على هذا الهاتف لا يدعم مشاركة الشاشة'**
  String get streamerFailUnsupportedOs;

  /// D346: the screen capture could not start; code is a short technical reason.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء تصوير الشاشة ({code})'**
  String streamerFailCapture(String code);

  /// D346: the screen track could not be published; code is a short technical reason.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال الشاشة إلى البث ({code})'**
  String streamerFailPublish(String code);

  /// D346 (owner): the button that copies the short streamer problem report (no personal data).
  ///
  /// In ar, this message translates to:
  /// **'نسخ تقرير المشكلة'**
  String get streamerCopyReport;

  /// D346: snack after the report was copied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ التقرير، أرسله لنا'**
  String get streamerReportCopied;

  /// D346: the title of the streamer problem card.
  ///
  /// In ar, this message translates to:
  /// **'لم تبدأ مشاركة الشاشة'**
  String get streamerReportTitle;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'شاشتك على الهواء'**
  String get streamerOnAir;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'الشاشة متوقفة مؤقتاً وأنت داخل Kabso Live'**
  String get streamerPausedInApp;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'الشاشة متوقفة أثناء المكالمة'**
  String get streamerPausedCall;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'الشاشة متوقفة والهاتف مقفل'**
  String get streamerPausedScreenOff;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى اللعبة'**
  String get streamerGoToGame;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'توقفت مشاركة الشاشة'**
  String get streamerStoppedTitle;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'شارك الشاشة من جديد'**
  String get streamerShareAgain;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'صوت اللعبة يُبث'**
  String get streamerGameLive;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'صوت اللعبة مكتوم'**
  String get streamerGameMuted;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'صوت اللعبة غير متاح على هذا الهاتف، يُبث الميكروفون فقط'**
  String get streamerGameUnavailable;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'إظهار الكاميرا'**
  String get streamerShowCamera;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الكاميرا'**
  String get streamerHideCamera;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'كتم صوت اللعبة'**
  String get streamerMuteGame;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'تشغيل صوت اللعبة'**
  String get streamerUnmuteGame;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'كتم المايك'**
  String get streamerNotifMicOff;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'تشغيل المايك'**
  String get streamerNotifMicOn;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'اسحب الفقاعة إلى أي زاوية'**
  String get streamerDragHint;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'الشاشة متوقفة مؤقتاً، سيعود البث بعد قليل'**
  String get streamerPausedViewer;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'بانتظار شاشة المضيف…'**
  String get streamerWaiting;

  /// D247 (v1.57-live): a STREAMER whose main picture is the camera (the web studio, OBS Virtual Camera) before it arrives.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار صورة المضيف…'**
  String get streamerWaitingCamera;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'ملء الشاشة'**
  String get streamerFullscreen;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'الخروج من ملء الشاشة'**
  String get streamerExitFullscreen;

  /// D213 (the streamer live «بث ستريمر»).
  ///
  /// In ar, this message translates to:
  /// **'شاشة {name}'**
  String streamerScreenSemantics(String name);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'{name} دخل البث'**
  String chatJoinedMale(String name);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'{name} دخلت البث'**
  String chatJoinedFemale(String name);

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'استوديو البودكاست'**
  String get liveThemePodcastStudio;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مجلس الخيمة'**
  String get liveThemePodcastMajlis;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'مكتبة الزمرد'**
  String get liveThemePodcastLibrary;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'المضيف لا يستقبل أسئلة الآن.'**
  String get errorLiveQuestionsClosed;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'يتحدث'**
  String get podcastSpeaking;

  /// D212 (live categories and the podcast live).
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون مغلق'**
  String get podcastMuted;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'دعوة صديق'**
  String get inviteTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'القواعد'**
  String get inviteRulesTooltip;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ادعُ أصدقاءك واربح حتى'**
  String get inviteHeroLine;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'≈ {money}'**
  String inviteMoneyHint(String money);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'{name} ربح {amount} كرزة، مبروك'**
  String inviteTickerLine(String name, String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ادعُ أصدقاء جدداً للانضمام إلى Kabso'**
  String get inviteCardTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'يسجّل صديقك بكودك: تحصل على {amount} كرزة.'**
  String inviteStepSignup(String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'أول شحن لصديقك: تحصل على {percent} من قيمته بالكرز.'**
  String inviteStepRecharge(String percent);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تُضاف المكافآت إلى رصيد الكرز القابل للسحب بعد التحقق ({hours} ساعة).'**
  String inviteStepHold(String hours);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تحصل أنت على {you}، ويحصل صديقك على {friend}'**
  String inviteYouGet(String you, String friend);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تحصل أنت على {you} عن كل صديق'**
  String inviteYouGetOnly(String you);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'{amount} كرزة'**
  String inviteCherries(String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ادعُ الآن'**
  String get inviteNow;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'كود دعوتي:'**
  String get inviteMyCode;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get inviteCopy;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ كود الدعوة'**
  String get inviteCodeCopied;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ رابط الدعوة'**
  String get inviteLinkCopied;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ادعُ أصدقاء جدداً واربح حتى'**
  String get inviteMilestonesTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'{count} مدعو'**
  String inviteInvitedCount(String count);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{صديق واحد} =2{صديقان} few{{count} أصدقاء} many{{count} صديقاً} other{{count} صديق}}'**
  String inviteMilestoneFriends(int count);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مقفلة'**
  String get inviteMilestoneLocked;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تحققت، قيد المراجعة'**
  String get inviteMilestoneUnlocked;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت'**
  String get inviteMilestoneClaimed;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مرحلة {friends}: {amount} كرزة، {state}'**
  String inviteMilestoneSemantics(String friends, String amount, String state);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'محجوز: {amount}'**
  String inviteRewardsPending(String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'أُضيف: {amount}'**
  String inviteRewardsCredited(String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'أصدقاؤك'**
  String get inviteFriendsTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'قيد التحقق'**
  String get inviteStatusPending;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مؤهل'**
  String get inviteStatusQualified;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'غير مؤهل'**
  String get inviteStatusRejected;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get inviteStatusVoid;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get inviteRecharged;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'لم تدعُ أحداً بعد. شارك كودك مع أصدقائك.'**
  String get inviteNoFriends;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل صفحة الدعوة'**
  String get inviteErrorTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'انضم إليّ في Kabso Live. استخدم كود دعوتي {code} عند التسجيل: {link}'**
  String inviteShareText(String code, String link);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get inviteShareWhatsapp;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get inviteShareMore;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get inviteShareCopyLink;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح التطبيق؛ نُسخ الرابط بدلاً من ذلك'**
  String get inviteShareFailed;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'قواعد الدعوة'**
  String get inviteRulesTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'عندما يسجّل صديق جديد بكود دعوتك تحصل على {amount} كرزة.'**
  String inviteRuleSignup(String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ويحصل صديقك على {amount} كرزة.'**
  String inviteRuleInvitee(String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'عند أول شحن لصديقك (من الموقع أو وكيل شحن أو طلب شحن) تحصل على {percent} من قيمته بالكرز.'**
  String inviteRuleRecharge(String percent);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تُحجز كل مكافأة {hours} ساعة ثم تُضاف إلى رصيد الكرز القابل للسحب. تُلغى إذا حُظر حساب صديقك أو حُذف أو قُيّد.'**
  String inviteRuleHold(String hours);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة واحدة لكل جهاز ولكل بريد، ولا تُحتسب دعوة نفسك أو حساباتك الأخرى.'**
  String get inviteRuleFair;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'يُكافأ حتى {count} تسجيلاً في اليوم.'**
  String inviteRuleCap(String count);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'يمكن لصديقك إدخال كودك من الإعدادات خلال {days} يوم من تسجيله، مرة واحدة.'**
  String inviteRuleLater(String days);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مكافآت المراحل، مرة واحدة لكل مرحلة، حسب عدد أصدقائك المؤهلين:\n{list}'**
  String inviteRuleMilestones(String list);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'الكرز يخضع لقواعد السحب المعتادة في محفظة الكرز.'**
  String get inviteRuleWithdraw;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'كود الدعوة'**
  String get referralApplyRow;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'أدخل كود الدعوة'**
  String get referralApplyTitle;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'كود صديقك أو رابط الدعوة'**
  String get referralApplyLabel;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إدخاله مرة واحدة حتى {date}.'**
  String referralApplyBody(String date);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get referralApplySubmit;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'تم ربط حسابك بكود صديقك'**
  String get referralApplied;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'حُفظ الكود، لكن هذه الدعوة لا تستوفي الشروط'**
  String get referralAppliedNotEligible;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'الدعوات غير متاحة الآن'**
  String get errorReferralUnavailable;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'كود الدعوة غير صحيح'**
  String get errorReferralCodeInvalid;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك إدخال كود دعوة الآن'**
  String get errorReferralNotAllowed;

  /// D223 (owner copy): DEVICE_ACCOUNT_LIMIT — this device already created its 2 accounts; signing in is still possible.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إنشاء أكثر من حسابين من نفس الجهاز. يمكنك تسجيل الدخول إلى حساباتك الحالية.'**
  String get errorDeviceAccountLimit;

  /// D223: DEVICE_ACCOUNT_LIMIT with the device's own limit (details[0].issue; an OWNER exception may differ from 2). T4: Arabic plural via ICU.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{لا يمكن إنشاء أكثر من حساب واحد من نفس الجهاز.} =2{لا يمكن إنشاء أكثر من حسابين من نفس الجهاز.} few{لا يمكن إنشاء أكثر من {count} حسابات من نفس الجهاز.} many{لا يمكن إنشاء أكثر من {count} حسابًا من نفس الجهاز.} other{لا يمكن إنشاء أكثر من {count} حساب من نفس الجهاز.}} يمكنك تسجيل الدخول إلى حساباتك الحالية.'**
  String errorDeviceAccountLimitCount(int count);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'كود الدعوة (اختياري)'**
  String get registerReferralLabel;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'إن دعاك صديق، اكتب كوده أو الصق رابط الدعوة'**
  String get registerReferralHelper;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة دعوة'**
  String get cherryReasonReferral;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'مكافآت إضافية حسب عدد أصدقائك المؤهلين:\n{list}'**
  String inviteStepMilestones(String list);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'{friends}: {amount} كرزة'**
  String inviteMilestoneItem(String friends, String amount);

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'إذا ألغى فريق Kabso دعوة غير صالحة يُسترجع الكرز الذي أُضيف بسببها، وإن لم يكفِ رصيدك يصبح سالباً ولا يمكن السحب حتى يُسدَّد.'**
  String get inviteRuleClawback;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'استرجاع مكافأة دعوة'**
  String get cherryReasonReferralReversal;

  /// D217 (invite friends «دعوة الأصدقاء»).
  ///
  /// In ar, this message translates to:
  /// **'ألغى فريق Kabso دعوة غير صالحة واسترجع كرز مكافأتها. افتح محفظة الكرز للتفاصيل'**
  String get notifReferralReversed;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'مقترح لك'**
  String get feedSuggested;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get feedPostSeeMore;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'{count} مشاهدة'**
  String feedPostViewCount(String count);

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'شاهد بث {name} المباشر'**
  String storyWatchLive(String name);

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة…'**
  String get storyReplyHint;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get storyReplySend;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت إلى الرسائل'**
  String get storyReplySent;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'أعجبتني قصة {name}'**
  String storyReact(String name);

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'أزال فريق الإشراف صورة غلاف ملفك لمخالفتها الإرشادات'**
  String get notifCoverRemoved;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'صورة الغلاف'**
  String get profileEditCover;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'مضبوطة'**
  String get profileEditCoverSet;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'حذف صورة الغلاف'**
  String get profileEditCoverRemove;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث صورة الغلاف'**
  String get profileEditCoverUpdated;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'حُذفت صورة الغلاف'**
  String get profileEditCoverRemoved;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'صورة غلاف {name}'**
  String profileCoverOf(String name);

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'منشورات'**
  String get profileTabPostsWord;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'ريلز'**
  String get profileTabReelsWord;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'إعادات'**
  String get profileTabRepostsWord;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73). After the follower count: «1.2K متابِع».
  ///
  /// In ar, this message translates to:
  /// **'متابِع'**
  String get profileFollowerWord;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'متابَع'**
  String get profileFollowingWord;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'انضم في {date}'**
  String profileJoined(String date);

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'حظرت هذا الحساب'**
  String get profileBlockedTitle;

  /// D218 (the owner's social redesign, CONVENTIONS §10.73).
  ///
  /// In ar, this message translates to:
  /// **'لن ترى منشوراته ولن يتمكن من مراسلتك. ألغِ الحظر لتراها.'**
  String get profileBlockedBody;

  /// D218 (owner: «وحدهما»): the own profile's Saved tab in the text tabs.
  ///
  /// In ar, this message translates to:
  /// **'محفوظات'**
  String get profileTabSavedWord;

  /// D218: the profile's bond card title (short: it never truncates).
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get profileBondFamily;

  /// D218: the profile's bond card title (short: it never truncates).
  ///
  /// In ar, this message translates to:
  /// **'العلاقة'**
  String get profileBondCouple;

  /// D218: the profile's bond card title (short: it never truncates).
  ///
  /// In ar, this message translates to:
  /// **'الميداليات'**
  String get profileBondMedals;

  /// D220: the ID line under the name on a person's card in a live (the username).
  ///
  /// In ar, this message translates to:
  /// **'ID: {id}'**
  String liveCardId(String id);

  /// D220: the report button at the start of the card's top row.
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ'**
  String get liveCardReport;

  /// D220: the card's first number.
  ///
  /// In ar, this message translates to:
  /// **'المتابِعون'**
  String get liveCardFollowers;

  /// D220: the card's second number (accounts they follow).
  ///
  /// In ar, this message translates to:
  /// **'المتابَعون'**
  String get liveCardFollowing;

  /// D220: the card's third number (lifetime cherries received from gifts).
  ///
  /// In ar, this message translates to:
  /// **'الكرز المستلم'**
  String get liveCardCherries;

  /// D220: the card's fourth number (lifetime coins sent on gifts).
  ///
  /// In ar, this message translates to:
  /// **'الكوينز المرسلة'**
  String get liveCardCoinsSent;

  /// D220: the wide follow button (with a plus).
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get liveCardFollow;

  /// D220 (owner): the follow button once followed — a neutral «Unfollow» that asks first.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المتابعة'**
  String get liveCardUnfollow;

  /// D220: the outline button that opens a direct conversation.
  ///
  /// In ar, this message translates to:
  /// **'دردشة'**
  String get liveCardChat;

  /// D220: the round gift button's label for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'إرسال هدية'**
  String get liveCardSendGift;

  /// D220: the button on your own card.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف'**
  String get liveCardEditProfile;

  /// D220: the family part of the card's gradient pill when the person has no family.
  ///
  /// In ar, this message translates to:
  /// **'بلا عائلة'**
  String get liveCardFamilyNone;

  /// D220: the privacy section with the two switches.
  ///
  /// In ar, this message translates to:
  /// **'الأرقام في بطاقتك'**
  String get privacyCardStatsTitle;

  /// D220: privacy switch.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الكرز المستلم'**
  String get privacyHideCherries;

  /// D220: privacy switch.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الكوينز المرسلة'**
  String get privacyHideCoins;

  /// D220: under the two switches.
  ///
  /// In ar, this message translates to:
  /// **'الرقم المخفي لا يظهر لغيرك في بطاقتك داخل البث ولا في ملفك. أنت وفريق Kabso تستطيعون رؤيته.'**
  String get privacyCardStatsHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الهوية'**
  String get kycStepTitle;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'نتأكد من هويتك عبر Didit: صورة وثيقتك ثم صورة لوجهك. لا حاجة لرفع صورة الهوية والسيلفي يدوياً.'**
  String get kycStepIntro;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لم تبدأ التحقق بعد'**
  String get kycStatusNotStarted;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'صوّر وثيقة هويتك (بطاقة أو جواز أو رخصة) ثم وجهك. يستغرق نحو دقيقتين.'**
  String get kycStatusNotStartedHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'التحقق لم يكتمل'**
  String get kycStatusInProgress;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'تابع من حيث توقفت؛ ستظهر النتيجة هنا عند الانتهاء.'**
  String get kycStatusInProgressHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'التحقق قيد المراجعة'**
  String get kycStatusInReview;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'تتم مراجعة التحقق، وسنخبرك بالنتيجة بإشعار.'**
  String get kycStatusInReviewHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد هويتك'**
  String get kycStatusApproved;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'هويتك مؤكدة ويمكنك إرسال الطلب.'**
  String get kycStatusApprovedHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تأكيد هويتك'**
  String get kycStatusDeclined;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك المحاولة مرة أخرى بعد مراعاة السبب:'**
  String get kycStatusDeclinedHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلسة التحقق'**
  String get kycStatusExpired;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة قبل اكتمالها. ابدأ من جديد.'**
  String get kycStatusExpiredHint;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التحقق'**
  String get kycStart;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'متابعة التحقق'**
  String get kycContinue;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get kycRetry;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'يُفتح التحقق داخل التطبيق لدى {provider}. لا نحفظ صور وثيقتك أو وجهك.'**
  String kycWhatHappens(String provider);

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى الحد اليومي لمحاولات التحقق. حاول غداً.'**
  String get kycRefusedDailyLimit;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الهوية غير متاح الآن. حاول لاحقاً.'**
  String get kycUnavailable;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'أكمل «تأكيد الهوية» أولاً.'**
  String get kycRequiredToSubmit;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'يلزم تأكيد هويتك (مقبول) قبل فتح الوكالة.'**
  String get kycRequiredApproved;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'العمر في الوثيقة أقل من ١٨ سنة.'**
  String get kycReasonUnderAge;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة تاريخ الميلاد في الوثيقة. صوّرها بوضوح.'**
  String get kycReasonNoBirthDate;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'الوثيقة منتهية الصلاحية. استخدم وثيقة سارية.'**
  String get kycReasonDocumentExpired;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لم يظهر وجهك بوضوح. صوّر في مكان مضاء.'**
  String get kycReasonNoFace;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لم ينجح فحص الحيوية. صوّر وجهك مباشرة دون صورة أو شاشة.'**
  String get kycReasonLiveness;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'وجهك لا يطابق صورة الوثيقة.'**
  String get kycReasonFaceMatch;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لم تجتز إحدى خطوات التحقق.'**
  String get kycReasonOther;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get kycClose;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'فتح في المتصفح'**
  String get kycOpenInBrowser;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد هويتك بنجاح'**
  String get notifKycApproved;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تأكيد هويتك. افتح الطلب لمعرفة السبب والمحاولة مرة أخرى'**
  String get notifKycDeclined;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'التحقق من هويتك قيد المراجعة، سنخبرك بالنتيجة'**
  String get notifKycInReview;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن بدء التحقق الآن'**
  String get errorKycNotAllowed;

  /// v1.80-kyc (D227): «تأكيد الهوية» (Didit).
  ///
  /// In ar, this message translates to:
  /// **'يلزم تأكيد هويتك أولاً (خطوة «تأكيد الهوية»).'**
  String get agencyOpenRefusedKyc;

  /// D231: the + on the other PK host's chip at the bottom of their half (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'متابعة {name}'**
  String pkFollowHost(String name);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'PK عادي'**
  String get pkTypeNormal;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'PK أحكام'**
  String get pkTypeDares;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'الخاسر ينفذ حكماً تسحبه القرعة'**
  String get pkTypeDaresHint;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'نوع PK'**
  String get pkTypeLabel;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'عشوائي أحكام'**
  String get pkRandomDares;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت دعوة PK أحكام إلى {name}'**
  String pkInviteSentDares(String name);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'قرعة الحكم'**
  String get pkDareDrawTitle;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'سهل'**
  String get pkDareLevelEasy;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get pkDareLevelMedium;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'صعب'**
  String get pkDareLevelHard;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'بانتظار قرار {name}'**
  String pkDareLoserDeciding(String name);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'حكمك'**
  String get pkDareYourDare;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get pkDareAccept;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get pkDareRefuse;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'رفض الحكم؟'**
  String get pkDareRefuseTitle;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'يُحتسب الرفض في نقاط PK: {points}'**
  String pkDareRefuseBody(String points);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'نُفّذ ✅'**
  String get pkDareDone;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'لم يُنفّذ ❌'**
  String get pkDareNotDone;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'هل نُفّذ الحكم؟'**
  String get pkDareJudge;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'نُفّذ الحكم 🎉'**
  String get pkDareOutcomeDone;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'رفض الحكم'**
  String get pkDareOutcomeRefused;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'لم يُنفّذ الحكم'**
  String get pkDareOutcomeNotDone;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ عن الحكم'**
  String get pkDareReport;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'شكراً، وصل البلاغ'**
  String get pkDareReported;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'الحكم: {text}. الوقت المتبقي {time}'**
  String pkDareSemantics(String text, String time);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'قرعة الحكم بين ثلاثة: سهل ومتوسط وصعب'**
  String get pkDareDrawSemantics;

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'نقاط PK: {points}'**
  String pkRecordPoints(String points);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'أحكام نُفّذت: {done} · رُفضت: {refused}'**
  String pkRecordDares(String done, String refused);

  /// v1.50-live (D229): «PK أحكام».
  ///
  /// In ar, this message translates to:
  /// **'لم يعد بالإمكان الرد على هذا الحكم'**
  String get pkFailureDareClosed;

  /// D240: the title of the «القريبة» country picker (a local choice).
  ///
  /// In ar, this message translates to:
  /// **'بلد «القريبة»'**
  String get liveCountryPickerTitle;

  /// D240: the picker's line.
  ///
  /// In ar, this message translates to:
  /// **'اختر بلداً لترى بثوثه في «القريبة». لا يغيّر ملفك.'**
  String get liveCountryPickerBody;

  /// D240: the country row under the filters, for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'بلد «القريبة»: {country}. تغيير'**
  String liveNearbyCountryRow(String country);

  /// D240: the country row with no country yet.
  ///
  /// In ar, this message translates to:
  /// **'اختر بلداً'**
  String get liveNearbyChooseCountry;

  /// D242: the rematch button.
  ///
  /// In ar, this message translates to:
  /// **'جولة أخرى'**
  String get pkRematch;

  /// D242: the result card asks.
  ///
  /// In ar, this message translates to:
  /// **'العب جولة أخرى مع {name}؟'**
  String pkRematchAsk(String name);

  /// D242: the asking host waits.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار {name}…'**
  String pkRematchWaiting(String name);

  /// D242: the other host is asked.
  ///
  /// In ar, this message translates to:
  /// **'{name} يريد جولة أخرى'**
  String pkRematchOffered(String name);

  /// D242: everyone, when the new battle starts.
  ///
  /// In ar, this message translates to:
  /// **'جولة أخرى تبدأ'**
  String get pkRematchBanner;

  /// D242: the asking host is told.
  ///
  /// In ar, this message translates to:
  /// **'رفض المضيف الآخر الجولة الأخرى'**
  String get pkRematchDeclined;

  /// D242: the offer lapsed.
  ///
  /// In ar, this message translates to:
  /// **'لم يردّ المضيف الآخر على الجولة الأخرى'**
  String get pkRematchExpired;

  /// D242: the answer countdown for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث'**
  String pkRematchSeconds(String seconds);

  /// D276: each host's PK points (PkHostRecord.points) on their half of the PK stage.
  ///
  /// In ar, this message translates to:
  /// **'نقاط PK'**
  String get pkPointsLabel;

  /// D276: the PK points chip for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'نقاط PK لـ{name}: {points}'**
  String pkPointsSemantics(String name, String points);

  /// D276: the host's PK sheet in the result while the dare still runs.
  ///
  /// In ar, this message translates to:
  /// **'جولة أخرى بعد انتهاء الحكم'**
  String get pkRematchAfterDare;

  /// D276 (owner: «انسحاب = −٣»): the «إنهاء التحدي» confirm during the battle; points is the deduction without its sign.
  ///
  /// In ar, this message translates to:
  /// **'الانسحاب يخصم {points} نقاط PK'**
  String pkEndForfeitPoints(String points);

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن البث'**
  String get liveToolReportLive;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ عن هذا البث؟'**
  String get liveReportTitle;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get liveReportNoteLabel;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'صف ما حدث في البث'**
  String get liveReportNoteHint;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'إرسال البلاغ'**
  String get liveReportSend;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'وصل بلاغك، سيراجع فريق Kabso البث.'**
  String get liveReportSent;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'تم حظر هذا الجهاز من فريق Kabso.'**
  String get errorDeviceBanned;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'تم حظر هذا الجهاز من فريق Kabso حتى {date}. السبب: {reason}'**
  String errorDeviceBannedUntil(String date, String reason);

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'تم حظر هذا الجهاز من فريق Kabso نهائياً. السبب: {reason}'**
  String errorDeviceBannedPermanent(String reason);

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'{what} موقوف لحسابك حتى {date}. السبب: {reason}'**
  String errorAccountRestrictedUntilReason(
    String what,
    String date,
    String reason,
  );

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'أنهى فريق Kabso بثك.'**
  String get notifLiveModeratedEnd;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'أنهى فريق Kabso بثك ومنعك من البث حتى {date}.'**
  String notifLiveModeratedNoLive(String date);

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'أنهى فريق Kabso بثك وعلّق حسابك حتى {date}.'**
  String notifLiveModeratedSuspend(String date);

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'أنهى فريق Kabso بثك وحظر جهازك حتى {date}.'**
  String notifLiveModeratedDevice(String date);

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'أنهى فريق Kabso بثك وحظر جهازك نهائياً.'**
  String get notifLiveModeratedDevicePermanent;

  /// v1.60-live (D250): live moderation — «الإبلاغ عن البث», the device ban and the restriction reason, the LIVE_MODERATED notification.
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String notifLiveModeratedReason(String reason);

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'مهام المضيف'**
  String get liveHostTasksTitle;

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء مهام المضيف'**
  String get liveHostTasksHide;

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'Lv{level}'**
  String liveHostTasksLevel(int level);

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{count} أيام} other{{count} يوم}}'**
  String liveHostTasksDays(int count);

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'مهام المضيف: {task}، {progress} من {target}، {days, plural, =1{بقي يوم واحد} =2{بقي يومان} few{بقيت {days} أيام} other{بقي {days} يوم}}'**
  String liveHostTasksLabel(
    String task,
    String progress,
    String target,
    int days,
  );

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'الردود السريعة'**
  String get liveToolQuickReplies;

  /// D253: the host's screen as the owner's reference (2026-11-03).
  ///
  /// In ar, this message translates to:
  /// **'ترتيب الغرف'**
  String get liveToolRoomRank;

  /// D253b: the host performance card.
  ///
  /// In ar, this message translates to:
  /// **'حالة الأداء'**
  String get livePerformanceTitle;

  /// D253b: the host performance card.
  ///
  /// In ar, this message translates to:
  /// **'بيانات لحظية'**
  String get livePerformanceRealtime;

  /// D253b: the host performance card.
  ///
  /// In ar, this message translates to:
  /// **'ذروة المشاهدين'**
  String get livePerformancePeak;

  /// D253b: the host performance card.
  ///
  /// In ar, this message translates to:
  /// **'عن هذه الأرقام'**
  String get livePerformanceHelpLabel;

  /// D253b: the host performance card.
  ///
  /// In ar, this message translates to:
  /// **'أرقام هذا البث، تتحدّث كل 15 ثانية: وقت البث، والمشاهدون الفريدون وأكبر عدد في وقت واحد، والمتابعون الجدد، والكرز المستلم، ومن أرسلوا الهدايا. يعرض الرسم القراءات المأخوذة أثناء فتح هذه البطاقة.'**
  String get livePerformanceHelp;

  /// D254: the level-up banner in every live.
  ///
  /// In ar, this message translates to:
  /// **'تهانينا لـ {name} على الترقية إلى المستوى {level} في غرفة البث المباشر الخاصة بـ {host}'**
  String liveLevelTicker(String name, int level, String host);

  /// D254: the level-up banner in every live.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الدعم'**
  String get liveLevelTickerSupport;

  /// D254: the level-up banner in every live.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الجاذبية'**
  String get liveLevelTickerCharm;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل VIP'**
  String get vipLoadError;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مستويات VIP معروضة الآن.'**
  String get vipEmpty;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لست VIP بعد'**
  String get vipNotYet;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'{tier} حتى {date}'**
  String vipUntil(String tier, String date);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ {days} يوماً'**
  String vipDaysLeft(String days);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لم يعد {tier} معروضاً للبيع؛ يبقى معك حتى نهايته ولا يُجدَّد.'**
  String vipOffSale(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'مستواك الحالي'**
  String get vipCurrent;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لمدة {days} يوماً'**
  String vipForDays(String days);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة لمدة {days} يوماً'**
  String vipPriceSemantics(String coins, String days);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'امتيازات {tier}'**
  String vipPerksTitle(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'الميزات المعلّمة «قريباً» تُفعَّل عند إطلاقها.'**
  String get vipPerksSoon;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ميزات لهذا المستوى بعد.'**
  String get vipPerksEmpty;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'مفعّلة'**
  String get vipPerkActive;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'مع {tier}'**
  String vipPerkWith(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'اشترِ الآن'**
  String get vipBuy;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'جدّد'**
  String get vipRenew;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'ترقية'**
  String get vipUpgrade;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'أقل من مستواك'**
  String get vipLowerTier;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى حد التجديد'**
  String get vipRenewLimit;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'شراء {tier}'**
  String vipConfirmBuy(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'تجديد {tier}'**
  String vipConfirmRenew(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'الترقية إلى {tier}'**
  String vipConfirmUpgrade(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get vipConfirmPrice;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'رصيدك'**
  String get vipConfirmBalance;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في'**
  String get vipConfirmUntil;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'يبدأ المستوى الجديد الآن؛ الأيام المتبقية من {tier} لا تُحتسب ولا تُسترد.'**
  String vipUpgradeNote(String tier);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'التجديد يدوي: لا يُخصم شيء تلقائياً.'**
  String get vipManualRenew;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'رصيدك من العملات لا يكفي.'**
  String get vipShort;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'اشحن العملات'**
  String get vipRecharge;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'ادفع {coins}'**
  String vipPay(String coins);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'أصبحت {tier} حتى {date}'**
  String vipDone(String tier, String date);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'قواعد VIP'**
  String get vipRules;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'تشتري VIP بالعملات من رصيدك لمدة المستوى. التجديد يدوي ويضيف المدة إلى نهاية اشتراكك (حتى {days} يوماً مقدماً). الترقية إلى مستوى أعلى تبدأ فوراً بسعره الكامل، ولا تُحتسب الأيام المتبقية من مستواك السابق. لا يمكن شراء مستوى أقل قبل انتهاء مستواك. لا يُخصم شيء تلقائياً.'**
  String vipRulesBody(String days);

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن شراء مستوى أقل من مستواك قبل انتهائه.'**
  String get vipErrorDowngrade;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى أقصى مدة يمكن تجديدها مقدماً.'**
  String get vipErrorRenewLimit;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'هذا المستوى لم يعد معروضاً للبيع.'**
  String get vipErrorTierOff;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن شراء هذا المستوى الآن.'**
  String get errorVipUnavailable;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'تغيّر سعر هذا المستوى. راجع السعر الجديد.'**
  String get errorVipPriceChanged;

  /// D252: «شراء VIP».
  ///
  /// In ar, this message translates to:
  /// **'شراء VIP'**
  String get walletReasonVipPurchase;

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'حالياً: {status}'**
  String vipCurrently(String status);

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'بدون VIP'**
  String get vipStatusNone;

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'الترقية: {tier}'**
  String vipUpgradeTo(String tier);

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'أعلى مستوى'**
  String get vipMaxTier;

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'رصيدك'**
  String get vipBalanceLabel;

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'متجر VIP'**
  String get vipStore;

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'متجر هدايا VIP — قريباً.'**
  String get vipStoreSoon;

  /// D252: «شراء VIP» — reference layout (D252b).
  ///
  /// In ar, this message translates to:
  /// **'امتيازات {tier}'**
  String vipPerksSection(String tier);

  /// D252b v2: «شراء VIP» — the appearance perks category header.
  ///
  /// In ar, this message translates to:
  /// **'التعريف'**
  String get vipSectionIdentity;

  /// D252b v2: «شراء VIP» — the privileges perks category header.
  ///
  /// In ar, this message translates to:
  /// **'امتياز حصري'**
  String get vipSectionPrivilege;

  /// D252c: «شراء VIP» in the owner's new reference.
  ///
  /// In ar, this message translates to:
  /// **'الامتياز الحصري {tier} {count}/{total}'**
  String vipPrivilegeTitle(String tier, String count, String total);

  /// D252c: «شراء VIP» in the owner's new reference.
  ///
  /// In ar, this message translates to:
  /// **'الخاص بي VIP'**
  String get vipMine;

  /// D304: the VIP purchase page's top bar title.
  ///
  /// In ar, this message translates to:
  /// **'في آي بي'**
  String get vipPageTitle;

  /// D304: the header over the tier's perks (the owner's reference layout).
  ///
  /// In ar, this message translates to:
  /// **'امتيازات VIP'**
  String get vipPrivilegesHeader;

  /// D252c: «شراء VIP» in the owner's new reference.
  ///
  /// In ar, this message translates to:
  /// **'ادفع بالعملات الذهبية'**
  String get vipPayCoins;

  /// D257: the viewer's screen as the owner's reference.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب اليومي'**
  String get liveDailyRankTitle;

  /// D257: the viewer's screen as the owner's reference.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الترتيب اليومي'**
  String get liveDailyRankHide;

  /// D257: the viewer's screen as the owner's reference.
  ///
  /// In ar, this message translates to:
  /// **'{gap} عن السابق'**
  String liveDailyRankGap(String gap);

  /// D257: the viewer's screen as the owner's reference.
  ///
  /// In ar, this message translates to:
  /// **'{name}: الترتيب اليوم {rank}، {points} نقطة'**
  String liveDailyRankLabel(String name, String rank, String points);

  /// D257: the viewer's screen as the owner's reference.
  ///
  /// In ar, this message translates to:
  /// **'الشحن'**
  String get liveToolRecharge;

  /// D258: the VIP daily coins credit.
  ///
  /// In ar, this message translates to:
  /// **'كوينز VIP اليومية'**
  String get walletReasonVipDailyCoins;

  /// D258: a VIP's free public message (DAILY_BULLET).
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت رسالة عامة مجانية · متبقي {count} اليوم'**
  String liveBulletSentFree(String count);

  /// D258: the VIP entry banner (owner reference): the name, then «دخل الغرفة».
  ///
  /// In ar, this message translates to:
  /// **'{name} دخل الغرفة'**
  String vipEntranceJoined(String name);

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'من زار ملفي'**
  String get vipVisitorsTitle;

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'من زار ملفي'**
  String get vipVisitorsEntry;

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'{count} زائر في آخر 30 يوماً'**
  String vipVisitorsTotal(String count);

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'{count} زيارات'**
  String vipVisitorsVisits(String count);

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'لا زوار بعد'**
  String get vipVisitorsEmptyTitle;

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'من يفتح ملفك يظهر هنا.'**
  String get vipVisitorsEmptyMessage;

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'ميزة لأعضاء VIP'**
  String get vipVisitorsNoPerkTitle;

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'اعرف من زار ملفك مع VIP.'**
  String get vipVisitorsNoPerkMessage;

  /// D258: «من زار ملفي» (PROFILE_VISITORS).
  ///
  /// In ar, this message translates to:
  /// **'شراء VIP'**
  String get vipVisitorsNoPerkAction;

  /// D258: the VIP page (owner reference 38).
  ///
  /// In ar, this message translates to:
  /// **'التعريف'**
  String get vipIdentity;

  /// D258: the VIP page (owner reference 38).
  ///
  /// In ar, this message translates to:
  /// **'اسمك'**
  String get vipPreviewName;

  /// D258: the VIP page (owner reference 38).
  ///
  /// In ar, this message translates to:
  /// **'{value} يومياً'**
  String vipPerkPerDay(String value);

  /// v1.129-social (D374): under a VIP perk the app does not do yet (the catalogue's not-built perks).
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get vipPerkSoonTag;

  /// D258: the VIP page's purchase panel (owner reference 40).
  ///
  /// In ar, this message translates to:
  /// **'كوينز / {days} يوماً'**
  String vipPricePer(String days);

  /// D258: the VIP page's purchase panel (owner reference 40).
  ///
  /// In ar, this message translates to:
  /// **'+{percent}٪ تسريع المستوى'**
  String vipSpeedupLine(String percent);

  /// D258: the VIP page's purchase panel (owner reference 40).
  ///
  /// In ar, this message translates to:
  /// **'خصم {percent}٪ عند التجديد'**
  String vipRenewalDiscountLine(String percent);

  /// D260: the badge of a Kabso staff member watching a live (viewer list and top viewers).
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو'**
  String get liveKabsoTeam;

  /// D260: the dialog a staff entry opens.
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو'**
  String get liveKabsoTeamInfoTitle;

  /// D260: the dialog a staff entry opens.
  ///
  /// In ar, this message translates to:
  /// **'هذا عضو في فريق كابسو يتابع البث للحفاظ على سلامة المجتمع. لا يُحتسب ضمن المشاهدين ولا الداعمين.'**
  String get liveKabsoTeamInfo;

  /// D260: a screen reader's label of a staff row.
  ///
  /// In ar, this message translates to:
  /// **'{name} من فريق كابسو'**
  String liveKabsoTeamWatching(String name);

  /// D260: a screen reader's label of the team shield by the top viewers.
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو يتابع هذا البث'**
  String get liveKabsoTeamHere;

  /// D264: a VIP member's tier items in the bag (§10.97).
  ///
  /// In ar, this message translates to:
  /// **'إطارات الرسائل'**
  String get bagCategoryChatBubble;

  /// D264: a VIP member's tier items in the bag (§10.97).
  ///
  /// In ar, this message translates to:
  /// **'لافتات الدخول'**
  String get bagCategoryEntryBanner;

  /// D264: a VIP member's tier items in the bag (§10.97).
  ///
  /// In ar, this message translates to:
  /// **'مؤثرات الدخول'**
  String get bagCategoryEntryEffect;

  /// D264: a VIP member's tier items in the bag (§10.97).
  ///
  /// In ar, this message translates to:
  /// **'موجات المايك'**
  String get bagCategoryMicWave;

  /// D264: a VIP member's tier items in the bag (§10.97).
  ///
  /// In ar, this message translates to:
  /// **'من عضوية {tier}'**
  String bagFromVip(String tier);

  /// D264: a VIP member's tier items in the bag (§10.97).
  ///
  /// In ar, this message translates to:
  /// **'عناصر VIP تابعة لعضويتك ولا تُرسل'**
  String get bagNoSendVip;

  /// D266: permanent bag items are never sent.
  ///
  /// In ar, this message translates to:
  /// **'العناصر الدائمة لا تُرسل'**
  String get bagNoSendPermanent;

  /// D267: the Me tab's store card (D270: opens the store).
  ///
  /// In ar, this message translates to:
  /// **'المتجر'**
  String get meHubStore;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'المتجر'**
  String get storeTitle;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'إطارات الصور'**
  String get storeKindAvatarFrame;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'بطاقات تعريفية'**
  String get storeKindProfileCard;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'فقاعات الرسائل'**
  String get storeKindChatBubble;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'لافتات الدخول'**
  String get storeKindEntryBanner;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'سيارات الدخول'**
  String get storeKindEntryEffect;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get storeNew;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'تملكه'**
  String get storeOwned;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'تملكه حتى {date} — الشراء يضيف المدة إليه'**
  String storeOwnedUntil(String date);

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'عملات'**
  String get storeCoins;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'كرز'**
  String get storeCherries;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get storeDuration;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'الدفع بـ'**
  String get storePayWith;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get storePrice;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'رصيدك'**
  String get storeBalance;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'شراء'**
  String get storeBuy;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'إهداء'**
  String get storeGift;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get storeRecharge;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'رصيد العملات لا يكفي لهذا العنصر.'**
  String get storeShortCoins;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'رصيد الكرز لا يكفي. الكرز يُكسب من الهدايا التي تصلك في البث ولا يُشحن.'**
  String get storeShortCherries;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'شراء «{name}» لمدة {days} مقابل {price}؟'**
  String storeBuyConfirm(String name, String days, String price);

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'إهداء «{name}» لمدة {days} إلى {user} مقابل {price}؟'**
  String storeGiftConfirm(String name, String days, String user, String price);

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'تم الشراء. «{name}» في حقيبتك حتى {date}.'**
  String storeBought(String name, String date);

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت الهدية إلى {user}.'**
  String storeGiftSent(String user);

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'ارتدِ الآن'**
  String get storeWearNow;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'ترتديه الآن'**
  String get storeWorn;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'إهداء إلى…'**
  String get storeGiftTitle;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get storeGiftSearch;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'من تتابعهم'**
  String get storeGiftFollowing;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أحد هنا بعد.'**
  String get storeGiftNone;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر في المتجر بعد. عُد قريباً.'**
  String get storeEmpty;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بالجميع 👋'**
  String get storePreviewSample;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'{price} · {days}'**
  String storeTotal(String price, String days);

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن شراء هذا العنصر الآن.'**
  String get errorStoreUnavailable;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'تغيّر سعر هذا العنصر. راجع السعر الجديد.'**
  String get errorStorePriceChanged;

  /// D270: «المتجر» (the store).
  ///
  /// In ar, this message translates to:
  /// **'شراء من المتجر'**
  String get walletReasonStorePurchase;

  /// D270: locked task cherries are not spendable in the store (owner).
  ///
  /// In ar, this message translates to:
  /// **'كرز المهام المقفل لا يُصرف في المتجر ({amount} مقفل).'**
  String storeLockedCherries(String amount);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'أدوات فريق كابسو'**
  String get staffToolsTitle;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'الإشراف على البثوث من هاتفك'**
  String get staffMeIntro;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'مالك'**
  String get staffRoleOwner;

  /// D283: the line of a moderator with no region.
  ///
  /// In ar, this message translates to:
  /// **'مشرف'**
  String get staffRoleModeration;

  /// D283: the line of a support staff member with no region.
  ///
  /// In ar, this message translates to:
  /// **'دعم'**
  String get staffRoleSupport;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'مالية'**
  String get staffRoleFinance;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'في المناوبة'**
  String get staffShift;

  /// D286: the shift switch — on by itself with staff work, off by hand.
  ///
  /// In ar, this message translates to:
  /// **'يعمل تلقائياً عند دخولك بثاً أو استخدام أدوات الفريق أو فتح «بثوثي»؛ تُوزَّع عليك البثوث وتصلك بلاغاتها، وتوقفه أنت'**
  String get staffShiftAutoHint;

  /// D286: the tools sheet shows the shift as it is now (off).
  ///
  /// In ar, this message translates to:
  /// **'خارج المناوبة'**
  String get staffShiftOff;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'بثوثي'**
  String get staffMyLives;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'لا بثوث موكلة إليك الآن'**
  String get staffMyLivesEmpty;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'شغّل «في المناوبة» لتصلك البثوث'**
  String get staffMyLivesOffShift;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك دخول أي بث كفريق كابسو من القائمة الرئيسية'**
  String get staffAnyLive;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'بلاغات: {count}'**
  String staffReportsCount(String count);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'{count} مشاهد'**
  String staffViewersCount(String count);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'كيف تدخل البث؟'**
  String get staffEnterTitle;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'دخول ظاهر (فريق كابسو)'**
  String get staffEnterVisible;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تظهر في المشاهدين بشارة فريق كابسو ولا تُحتسب'**
  String get staffEnterVisibleHint;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'مراقبة خفية'**
  String get staffEnterHidden;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'لا يراك أحد ولا تكتب في الدردشة'**
  String get staffEnterHiddenHint;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'أنت الآن: {mode}'**
  String staffModeNow(String mode);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تبديل'**
  String get staffModeSwitch;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'البلاغات'**
  String get staffReports;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'لا بلاغات على هذا البث'**
  String get staffReportsEmpty;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'على البث'**
  String get staffReportOnLive;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'على {name}'**
  String staffReportOnUser(String name);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'رسالة من {name}'**
  String staffReportOnMessage(String name);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'أبلغ: {name}'**
  String staffReportBy(String name);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تمت معالجته'**
  String get staffReportClosed;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'الإجراءات'**
  String get staffActions;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تنبيه المضيف'**
  String get staffActionWarn;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البث'**
  String get staffActionEnd;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'منع من البث'**
  String get staffActionNoLive;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تعليق الحساب'**
  String get staffActionSuspend;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تمت المراجعة — لا مخالفة'**
  String get staffActionDismiss;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'إخراج من البث'**
  String get staffActionKick;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'كتم في الدردشة'**
  String get staffActionMute;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'حذف الرسالة'**
  String get staffActionRemoveMessage;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'إجراء على شخص'**
  String get staffPersonActions;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get staffPersonField;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'السبب (يُسجَّل)'**
  String get staffReason;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'يصل السبب إلى المضيف من «فريق Kabso» دون اسمك.'**
  String get staffReasonHostHint;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get staffDuration;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get staffDuration1h;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'24 ساعة'**
  String get staffDuration24h;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'3 أيام'**
  String get staffDuration3d;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'7 أيام'**
  String get staffDuration7d;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'30 يوماً'**
  String get staffDuration30d;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تنفيذ'**
  String get staffApply;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get staffDone;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'دورك: الاطلاع على البلاغات فقط'**
  String get staffReadOnly;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو لا يرسل هدايا ولا ينقر في البث'**
  String get staffNoEconomy;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'بلاغ جديد على بث {host}'**
  String notifLiveStaffReport(String host);

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن اتخاذ إجراء ضد فريق كابسو'**
  String get errorStaffProtected;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو لا يفعل هذا في البث'**
  String get errorLiveStaffRefused;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز المصادقة لاستخدام أدوات الفريق'**
  String get errorStaffStepUpRequired;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'فعّل تطبيق المصادقة من لوحة الإدارة أولاً'**
  String get errorStaffTotpNotEnrolled;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'رمز المصادقة غير صحيح'**
  String get errorAdminTotpInvalid;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'محاولات خاطئة كثيرة. حاول لاحقاً'**
  String get errorAdminLocked;

  /// D273: «فريق كابسو» from the app (staff tools, step-up, shift, «بثوثي»).
  ///
  /// In ar, this message translates to:
  /// **'رُفض الإجراء'**
  String get errorAdminActionRefused;

  /// D279: the profile's «في بث الآن» card under the cover.
  ///
  /// In ar, this message translates to:
  /// **'في بث الآن'**
  String get profileLiveNowTitle;

  /// D279: the profile's «في بث الآن» card under the cover.
  ///
  /// In ar, this message translates to:
  /// **'أنت في بث الآن'**
  String get profileLiveNowSelfTitle;

  /// D279: the profile's «في بث الآن» card under the cover.
  ///
  /// In ar, this message translates to:
  /// **'مباشر منذ {duration}'**
  String profileLiveFor(String duration);

  /// D279: the profile's «في بث الآن» card under the cover.
  ///
  /// In ar, this message translates to:
  /// **'{hours}س {minutes}د'**
  String profileLiveHoursMinutes(int hours, int minutes);

  /// D279: the profile's «في بث الآن» card under the cover.
  ///
  /// In ar, this message translates to:
  /// **'{minutes}د'**
  String profileLiveMinutes(int minutes);

  /// D279: the profile's «في بث الآن» card under the cover.
  ///
  /// In ar, this message translates to:
  /// **'{title}، {duration}، {details}'**
  String profileLiveCardSemantics(
    String title,
    String duration,
    String details,
  );

  /// D278b: the «+n» chip after the profile tags that do not fit two lines (screen reader).
  ///
  /// In ar, this message translates to:
  /// **'{count} منشنات أخرى'**
  String profileTagsMore(int count);

  /// D278b: the edit profile row and screen title for the profile tags «منشنات».
  ///
  /// In ar, this message translates to:
  /// **'المنشنات'**
  String get profileEditTags;

  /// D278b: the tags row value (how many tags are set).
  ///
  /// In ar, this message translates to:
  /// **'{count} من 10'**
  String profileEditTagsValue(int count);

  /// D278b: the tags editor explanation.
  ///
  /// In ar, this message translates to:
  /// **'حتى 10 منشنات قصيرة تظهر على غلاف ملفك، حتى 24 حرفاً لكل منها.'**
  String get profileEditTagsHint;

  /// D278b: the tags editor's text field.
  ///
  /// In ar, this message translates to:
  /// **'منشن جديد'**
  String get profileEditTagField;

  /// D278b: adds the typed tag.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get profileEditTagAdd;

  /// D278b: removes one tag (chip delete button).
  ///
  /// In ar, this message translates to:
  /// **'حذف {tag}'**
  String profileEditTagRemove(String tag);

  /// D278b: a tag is too long.
  ///
  /// In ar, this message translates to:
  /// **'{max} حرفاً على الأكثر.'**
  String profileEditTagTooLong(int max);

  /// D278b: the same tag twice (ignoring case).
  ///
  /// In ar, this message translates to:
  /// **'هذا المنشن مضاف بالفعل.'**
  String get profileEditTagDuplicate;

  /// D278b: a tag refused (invalid_format).
  ///
  /// In ar, this message translates to:
  /// **'يحتوي على رموز غير مسموح بها.'**
  String get profileEditTagInvalid;

  /// D278b: no more tags can be added.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى 10 منشنات.'**
  String get profileEditTagsFull;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'بدون أيقونة'**
  String get profileTagIconDefault;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'تاج'**
  String get profileTagIconCrown;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'علم دولة'**
  String get profileTagIconFlag;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'نار'**
  String get profileTagIconFire;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'كأس'**
  String get profileTagIconTrophy;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'ألعاب'**
  String get profileTagIconGamepad;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'موسيقى'**
  String get profileTagIconMusic;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'ميكروفون'**
  String get profileTagIconMic;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'هلال'**
  String get profileTagIconMoon;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'قلب'**
  String get profileTagIconHeart;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'نجمة'**
  String get profileTagIconStar;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'جوهرة'**
  String get profileTagIconGem;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'كاميرا'**
  String get profileTagIconCamera;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'كتاب'**
  String get profileTagIconBook;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'رياضة'**
  String get profileTagIconSport;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'فن'**
  String get profileTagIconPalette;

  /// D292 (§10.106): a profile tag icon's name (the icon picker and screen readers).
  ///
  /// In ar, this message translates to:
  /// **'العالم'**
  String get profileTagIconGlobe;

  /// D292: a tag's flag icon with its country (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'علم {country}'**
  String profileTagIconFlagOf(String country);

  /// D292: the icon picker sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'أيقونة الوسم'**
  String get profileTagIconPick;

  /// D292: a tag chip in the editor opens the icon picker (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'تغيير أيقونة {tag}'**
  String profileTagIconChange(String tag);

  /// D292: the button beside the new-tag field that picks its icon.
  ///
  /// In ar, this message translates to:
  /// **'أيقونة الوسم الجديد: {icon}'**
  String profileTagIconNew(String icon);

  /// D292: the tags editor's hint about icons.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أي منشن لاختيار أيقونته.'**
  String get profileEditTagsIconHint;

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'سهل'**
  String get liveTargetLevelEasy;

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get liveTargetLevelMedium;

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'صعب'**
  String get liveTargetLevelHard;

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'+{amount} كرز مقفل'**
  String liveTargetRewardLocked(String amount);

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'تم · +{amount} كرز مقفل'**
  String liveTargetRewardPaid(String amount);

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'المكافأة نسبة من ربح المنصة الفعلي، تُصرف كرزاً مقفلاً مثل المهام عند إكمال الهدف.'**
  String get liveTargetRewardHint;

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'{level}: {title}، {progress} من {amount}، المكافأة {reward} كرز'**
  String liveTargetDailySemantics(
    String level,
    String title,
    String progress,
    String amount,
    String reward,
  );

  /// D281: the smart targets «الأهداف الذكية» (chip, sheet) and the generated Task Center.
  ///
  /// In ar, this message translates to:
  /// **'بين {from} و{to}'**
  String tasksWindowLabel(String from, String to);

  /// D281: a HOST_TARGET_REWARD row of the cherry history (a smart daily target reward, locked like task rewards).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة هدف يومي'**
  String get cherryReasonHostTarget;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'الوطن العربي'**
  String get staffRegionArabWorld;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'الصين الكبرى'**
  String get staffRegionGreaterChina;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'تركيا'**
  String get staffRegionTurkey;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'إيران'**
  String get staffRegionIran;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'جنوب آسيا'**
  String get staffRegionSouthAsia;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'جنوب شرق آسيا'**
  String get staffRegionSoutheastAsia;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'شرق آسيا'**
  String get staffRegionEastAsia;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'أوروبا'**
  String get staffRegionEurope;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'أمريكا الشمالية'**
  String get staffRegionNorthAmerica;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'أمريكا اللاتينية'**
  String get staffRegionLatinAmerica;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'أفريقيا جنوب الصحراء'**
  String get staffRegionSubSaharanAfrica;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'روسيا وآسيا الوسطى'**
  String get staffRegionRussiaCentralAsia;

  /// D283: a staff region.
  ///
  /// In ar, this message translates to:
  /// **'أوقيانوسيا'**
  String get staffRegionOceania;

  /// D283: two regions on the profile line.
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second}'**
  String staffRegionsTwo(String first, String second);

  /// D283: three or more regions on the profile line.
  ///
  /// In ar, this message translates to:
  /// **'{first} و{second} وأكثر'**
  String staffRegionsMore(String first, String second);

  /// D283: a moderator's profile line (Arabic is built as «مشرف للوطن العربي» in code).
  ///
  /// In ar, this message translates to:
  /// **'مشرف — {regions}'**
  String staffLineModeration(String regions);

  /// D283: a support staff member's profile line.
  ///
  /// In ar, this message translates to:
  /// **'دعم — {regions}'**
  String staffLineSupport(String regions);

  /// D283: the line of a finance staff member.
  ///
  /// In ar, this message translates to:
  /// **'المالية'**
  String get staffLineFinance;

  /// D283: the label of an announcement post or reel in the feeds.
  ///
  /// In ar, this message translates to:
  /// **'إعلان رسمي — فريق كابسو'**
  String get postAnnouncementLabel;

  /// D283: the composer note for a staff account.
  ///
  /// In ar, this message translates to:
  /// **'حسابات فريق كابسو تنشر إعلانات رسمية فقط.'**
  String get postComposerAnnouncementOnly;

  /// D283: the staff Me tab entry to the announcement composer.
  ///
  /// In ar, this message translates to:
  /// **'نشر إعلان'**
  String get meStaffAnnouncement;

  /// D283: the staff Me tab entry to the announcement reel composer.
  ///
  /// In ar, this message translates to:
  /// **'نشر ريلز إعلان'**
  String get meStaffAnnouncementReel;

  /// D283: a page a staff account cannot use.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح لحسابات فريق كابسو.'**
  String get staffFeatureUnavailable;

  /// D283: edit profile, instead of «تغيير الصورة».
  ///
  /// In ar, this message translates to:
  /// **'صورة فريق كابسو ثابتة ولا يمكن تغييرها.'**
  String get staffPictureLocked;

  /// D283: edit profile / the cover, instead of «تغيير الغلاف».
  ///
  /// In ar, this message translates to:
  /// **'غلاف فريق كابسو ثابت ولا يمكن تغييره.'**
  String get staffCoverLocked;

  /// D283b: the title of the official bio card on a staff profile (owner: «اجعل بايو ملفت واجمل لانه هذه شركة بالعربي والانجليزي»).
  ///
  /// In ar, this message translates to:
  /// **'الحساب الرسمي'**
  String get staffOfficialBioTitle;

  /// D283b: the fixed official bio of every Kabso Team account, in place of the typed bio.
  ///
  /// In ar, this message translates to:
  /// **'الحساب الرسمي لفريق إدارة Kabso Live. نعمل على مدار الساعة لتبقى تجربتك آمنة وممتعة للجميع. للدعم أو للإبلاغ عن أي مخالفة، راسلنا مباشرة.'**
  String get staffOfficialBio;

  /// D283b: edit profile, the bio row of a staff account (locked).
  ///
  /// In ar, this message translates to:
  /// **'نبذة رسمية ثابتة لا يمكن تعديلها'**
  String get staffBioLocked;

  /// D283: the bag's frames for a staff account.
  ///
  /// In ar, this message translates to:
  /// **'إطار فريق كابسو مثبّت ولا يمكن تغييره.'**
  String get staffFrameLocked;

  /// D283: the screen reader label of the team picture.
  ///
  /// In ar, this message translates to:
  /// **'صورة فريق كابسو'**
  String get staffTeamPicture;

  /// D283c: a staff account's official staff ID «Kabso01» where the @username is shown (profile, person card, Me tab). Reads left to right in both languages.
  ///
  /// In ar, this message translates to:
  /// **'ID: {id}'**
  String profileStaffId(String id);

  /// D283c: the screen reader hint of the staff ID line.
  ///
  /// In ar, this message translates to:
  /// **'رقم موظف رسمي في فريق كابسو'**
  String get profileStaffIdHint;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'تطوير الأعمال'**
  String get staffRoleBd;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'تطوير الأعمال — {regions}'**
  String staffLineBd(String regions);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'إن كنت تابعاً لمشرف، ضع معرّفه هنا'**
  String get recruiterFieldLabel;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'اختياري — ID الموظف مثل Kabso01 أو اسم المستخدم'**
  String get recruiterFieldHint;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق…'**
  String get recruiterChecking;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'غير موجود'**
  String get recruiterNotFound;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'صحّح معرّف المشرف أو اتركه فارغاً'**
  String get recruiterFixError;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'المستقطِب: {name}'**
  String recruiterFoundSemantics(String name);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'استقطاباتي'**
  String get staffMyRecruits;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'أرباحي'**
  String get staffMyEarnings;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'من سجّلوا عن طريقك. تحصل تلقائياً على نسبة من ربح المنصة من كل واحد منهم، تُحسب يومياً.'**
  String get staffRecruitsIntro;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مستقطَبون بعد. شارك معرّفك ليكتبه المتقدمون في طلباتهم.'**
  String get staffRecruitsEmpty;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get recruitTypeAll;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'مضيف'**
  String get recruitTypeHost;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'وكالة'**
  String get recruitTypeAgency;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'وكيل شحن'**
  String get recruitTypeRechargeAgent;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'صانع محتوى'**
  String get recruitTypeCreator;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get recruitStatusActive;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'غير نشط'**
  String get recruitStatusInactive;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'منذ {date}'**
  String recruitSince(String date);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرز'**
  String recruitCherries(String cherries);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'رصيد الكرز'**
  String get staffEarningsBalance;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'قابل للسحب: {cherries} ≈ {amount}'**
  String staffEarningsWithdrawable(String cherries, String amount);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'مجموع العمولات'**
  String get staffEarningsTotal;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'آخر 30 يوماً'**
  String get staffEarnings30;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'سحب الأرباح'**
  String get staffEarningsWithdraw;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'طلب سحب قيد الدفع'**
  String get staffEarningsPending;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'حسب المستقطَب'**
  String get staffEarningsByRecruit;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'السجل اليومي'**
  String get staffEarningsHistory;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'لا عمولات بعد — تُحسب كل يوم من ربح المنصة الفعلي.'**
  String get staffEarningsEmpty;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'نسبتك: {host} مضيفون · {creator} صناع محتوى · {agency} وكالات · {recharge} وكلاء شحن'**
  String staffEarningsShares(
    String host,
    String creator,
    String agency,
    String recharge,
  );

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'ربح المنصة {profit} × {pct}'**
  String staffEarningsDayLine(String profit, String pct);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'برنامج صناع المحتوى'**
  String get creatorProgrammeEntry;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'انضم كصانع محتوى'**
  String get creatorProgrammeTitle;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'قدّم طلبك ليراجعه فريق كابسو. بعد الموافقة تصبح صانع محتوى في Kabso Live.'**
  String get creatorProgrammeIntro;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'الدولة'**
  String get creatorProgrammeCountry;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'نوع المحتوى'**
  String get creatorProgrammeCategory;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'روابط أعمالك (1 إلى 5)'**
  String get creatorProgrammeLinks;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'رابط يبدأ بـ https://'**
  String get creatorProgrammeLinkError;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'إضافة رابط'**
  String get creatorProgrammeAddLink;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'نبذة (اختياري)'**
  String get creatorProgrammeBio;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get creatorProgrammeSubmit;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك'**
  String get creatorProgrammeSent;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة'**
  String get creatorProgrammePending;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'أنت صانع محتوى في Kabso Live'**
  String get creatorProgrammeMember;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'رُفض طلبك: {reason}'**
  String creatorProgrammeRejected(String reason);

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'سحب الطلب'**
  String get creatorProgrammeCancel;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'حسابات فريق كابسو لا تتقدم لبرنامج صناع المحتوى.'**
  String get creatorProgrammeStaff;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get creatorCatVideo;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'صور'**
  String get creatorCatPhoto;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'موسيقى'**
  String get creatorCatMusic;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'ألعاب'**
  String get creatorCatGaming;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'كوميديا'**
  String get creatorCatComedy;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'تعليم'**
  String get creatorCatEducation;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'أسلوب حياة'**
  String get creatorCatLifestyle;

  /// D285: recruitment by staff «الاستقطاب».
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get creatorCatOther;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'شراء كرز للوكيل'**
  String get rechargeCherryBuyForAgentTitle;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'يعمل لصالح {name}'**
  String rechargeWorksFor(String name);

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'تشتري لحساب {name}: العملات تُضاف إلى مخزون الوكيل والدفع للمضيف من الوكيل.'**
  String rechargeCherryForAgentNote(String name);

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'خارج ساعات عملك: يمكنك الاطلاع فقط.'**
  String get rechargeBlockOffShift;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'لم يسمح لك الوكيل بهذا.'**
  String get rechargeBlockNotPermitted;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'تم استلامه بواسطة موظف آخر'**
  String get rechargeOrderClaimedByOther;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'يتولاه الوكيل'**
  String get rechargeOrderClaimedByAgent;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'يتولاه {name}'**
  String rechargeOrderClaimedBy(String name);

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'أنت تتولى هذا الطلب'**
  String get rechargeOrderClaimedByYou;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'بواسطة {name}'**
  String rechargeActedBy(String name);

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'يمكنه شراء الكرز'**
  String get rechargePermBuyCherries;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'يشتري كرز المضيفين لحسابك أثناء دوامه'**
  String get rechargePermBuyCherriesHint;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'يستقبل طلبات الشراء'**
  String get rechargePermReceivesOrders;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'تصله طلبات المشترين ويتولاها أثناء دوامه'**
  String get rechargePermReceivesOrdersHint;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'اليوم: {cherries} شراء كرز · {orders} طلب منجز'**
  String rechargeEmployeeActsToday(int cherries, int orders);

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'لم يسمح لك الوكيل بهذا الإجراء.'**
  String get errorRechargeEmployeeNotPermitted;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'تم استلام هذا الطلب بواسطة موظف آخر.'**
  String get errorRechargeOrderClaimed;

  /// D287 recharge employees act for the agent
  ///
  /// In ar, this message translates to:
  /// **'طلبات المشترين لـ {name}، أول من يتولى الطلب يملكه'**
  String rechargeOrdersForAgentHint(String name);

  /// D287 recharge employees act for the agent (owner: never a Kabso Team account)
  ///
  /// In ar, this message translates to:
  /// **'أنت الآن ضمن فريق كابسو: لا يمكنك العمل كموظف شحن، يمكنك الاطلاع فقط.'**
  String get rechargeBlockStaff;

  /// D287 recharge employees act for the agent (owner: never a Kabso Team account)
  ///
  /// In ar, this message translates to:
  /// **'ضمن فريق كابسو الآن: لا يمكنه العمل لصالحك. يمكنك إزالته.'**
  String get rechargeEmployeeIsStaffNote;

  /// D287 recharge employees act for the agent (owner: never a Kabso Team account)
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب من فريق كابسو، ولا يمكن إضافته موظفاً للشحن.'**
  String get errorRechargeEmployeeIsStaff;

  /// D287 recharge employees act for the agent (owner: never a Kabso Team account)
  ///
  /// In ar, this message translates to:
  /// **'حسابات فريق كابسو لا يمكنها القيام بهذا.'**
  String get errorStaffAccountLimited;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'بلاغات'**
  String get staffSharedReports;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'البلاغات'**
  String get staffSharedReportsTitle;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'{count} بلاغ غير محلول'**
  String staffSharedReportsBadge(int count);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'البلاغات مشتركة بين المشرفين والدعم: من يحل البلاغ يضغط «تم حله».'**
  String get staffSharedReportsHint;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'غير محلولة'**
  String get staffSharedTabOpen;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تم حلها'**
  String get staffSharedTabResolved;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'لا بلاغات بانتظار الحل'**
  String get staffSharedEmptyOpen;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'لا بلاغات محلولة بعد'**
  String get staffSharedEmptyResolved;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تم حله'**
  String get staffSharedResolve;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تم حل البلاغ'**
  String get staffSharedResolveTitle;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'يصبح البلاغ محلولاً لكل فريق الإشراف والدعم، ويظهر اسمك ووقت الحل.'**
  String get staffSharedResolveIntro;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختيارية)'**
  String get staffSharedResolveNote;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'حلّه {name} · {when}'**
  String staffSharedResolvedBy(String name, String when);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تم الحل · {when}'**
  String staffSharedResolvedAt(String when);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة الحل: {note}'**
  String staffSharedResolutionNote(String note);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تم حله بالفعل من عضو آخر في الفريق'**
  String get staffSharedAlreadyResolved;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تم حل البلاغ'**
  String get staffSharedDone;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'أبلغ: {name}'**
  String staffSharedReportedBy(String name);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'صاحب المحتوى: {name}'**
  String staffSharedAuthor(String name);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة المبلّغ: {note}'**
  String staffSharedReporterNote(String note);

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'المحتوى محذوف أو مخفي'**
  String get staffSharedGone;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get staffSharedOutcomeDismissed;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get staffReportTypePost;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'تعليق'**
  String get staffReportTypeComment;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'قصة'**
  String get staffReportTypeStory;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'حساب'**
  String get staffReportTypeUser;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'بث'**
  String get staffReportTypeLive;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'رسالة في بث'**
  String get staffReportTypeLiveChat;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'اعتراف CP'**
  String get staffReportTypeConfession;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'رسالة عائلة'**
  String get staffReportTypeFamilyChat;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'رسالة خاصة'**
  String get staffReportTypeDm;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'رابط في الملف'**
  String get staffReportTypeLink;

  /// D288: «بلاغات» — the shared report queue (§10.101).
  ///
  /// In ar, this message translates to:
  /// **'بلاغ جديد بانتظار الحل'**
  String get notifStaffReportNew;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'لفترة محدودة'**
  String get itemBadgeLimited;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get itemBadgeNew;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'موسمي'**
  String get itemBadgeSeasonal;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'حصري'**
  String get itemBadgeExclusive;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'الأكثر طلباً'**
  String get itemBadgeMostWanted;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'مميز'**
  String get itemBadgeFeatured;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'شاشة كاملة'**
  String get itemBadgeFullscreen;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'بمؤثرات صوتية'**
  String get itemBadgeSound;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'بدون مؤثرات صوتية'**
  String get itemBadgeNoSound;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'{n, plural, =1{باقٍ يوم} =2{باقٍ يومان} few{باقٍ {n} أيام} many{باقٍ {n} يوماً} other{باقٍ {n} يوم}}'**
  String itemBadgeDaysLeft(int n);

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'ينتهي اليوم'**
  String get itemBadgeEndsToday;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'الشارات'**
  String get itemBadgesTitle;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولاً لعرض التفاصيل'**
  String get giftDetailsHint;

  /// D289: gift and store badges «شارات الهدايا والمتجر» (CONVENTIONS §10.102).
  ///
  /// In ar, this message translates to:
  /// **'هدية حظ'**
  String get giftDetailsLucky;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'طلبات رفع الليفيل'**
  String get lrTitle;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'طلب رفع ليفيل'**
  String get lrMeRow;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'داعم جديد من تطبيق آخر؟ أرسل طلباً للإدارة مع فيديو لحسابه هناك، وتقترح الإدارة ليفيل الدعم المناسب.'**
  String get lrIntro;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get lrNew;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'لم ترسل أي طلب بعد.'**
  String get lrEmpty;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get lrStatusPending;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة'**
  String get lrStatusApproved;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get lrStatusRejected;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'رُفع إلى المستوى {level}'**
  String lrApprovedLevel(String level);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String lrRejectReason(String reason);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'{app} · المستوى {level} · ID {id}'**
  String lrSourceLine(String app, String level, String id);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'طلب رفع ليفيل'**
  String get lrFormTitle;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم في Kabso'**
  String get lrUsername;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'تحقّق'**
  String get lrCheck;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب بهذا الاسم'**
  String get lrNotFound;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'حساب في فريق كابسو: لا ليفيلات له'**
  String get lrStaffAccount;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'لدى هذا الداعم طلب قيد المراجعة'**
  String get lrOpenExists;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الشحن: {coins}'**
  String lrTotalRecharge(String coins);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'شحن أول {days} أيام: {coins}'**
  String lrFirstDaysRecharge(String days, String coins);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'ليفيل الدعم {support} · الجاذبية {charm}'**
  String lrLevels(String support, String charm);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الإرسال الآن، لكن لا تتم الموافقة قبل شحن {min} عملة'**
  String lrNotEligible(String min);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'الشحن كافٍ للموافقة'**
  String get lrEligible;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'التطبيق'**
  String get lrSourceApp;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get lrConfirmed;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'تقدير'**
  String get lrEstimate;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'اسم التطبيق'**
  String get lrOtherName;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'الآيدي في التطبيق'**
  String get lrAccountId;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'المستوى في التطبيق'**
  String get lrSourceLevel;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'فيديو الحساب'**
  String get lrVideo;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'سجّل فيديو لصفحة الحساب في التطبيق يظهر فيه المستوى والآيدي (حتى 90 ثانية).'**
  String get lrVideoHint;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'اختر الفيديو'**
  String get lrVideoPick;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'فيديو {seconds} ث'**
  String lrVideoChosen(String seconds);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الرفع… {percent}%'**
  String lrVideoUploading(String percent);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get lrNote;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get lrSend;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'أُرسل الطلب إلى الإدارة'**
  String get lrSent;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get lrRequired;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'من 1 إلى 999'**
  String get lrLevelRange;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة على طلب رفع ليفيل {user} إلى المستوى {level}'**
  String notifLevelRaiseApproved(String user, String level);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'لم تتم الموافقة على طلب رفع ليفيل {user}'**
  String notifLevelRaiseRejected(String user);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'تم رفع ليفيل الدعم الخاص بك إلى المستوى {level}'**
  String notifLevelRaised(String level);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'هل تقصد: {name}؟'**
  String lrDidYouMean(String name);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'يوجد طلب لنفس الحساب في نفس التطبيق ({status}) منذ {date}، أرسله {name}'**
  String lrDuplicate(String status, String date, String name);

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'يوجد طلب لنفس الحساب في نفس التطبيق'**
  String get lrDuplicateShort;

  /// D290: level-raise requests «طلب رفع ليفيل».
  ///
  /// In ar, this message translates to:
  /// **'سبق رفض طلب بنفس الحساب'**
  String get lrPreviouslyRejected;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'الميداليات التي أرتديها'**
  String get medalsStageTitle;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'غير مرتدية'**
  String get medalsNotWorn;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'لا ترتدي أي ميدالية'**
  String get medalsNoneWorn;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'ترتدي {count} من {max}'**
  String medalsWornCount(int count, int max);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'الإنجازات'**
  String get medalsTabAchievements;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'النشاط'**
  String get medalsTabActivity;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ميداليات في هذا التبويب'**
  String get medalsTabEmpty;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحصَّل'**
  String get medalsNotObtained;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'المستوى {level}'**
  String medalsLevel(int level);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'مرتدية'**
  String get medalsWorn;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'أعلى مستوى'**
  String get medalsTopLevel;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'{value} / {next}'**
  String medalsProgress(String value, String next);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'المستويات'**
  String get medalsLevelsTitle;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'ارتداء'**
  String get medalsWear;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'خلع'**
  String get medalsTakeOff;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث ميدالياتك المرتدية'**
  String get medalsWearSaved;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بث واحد} =2{بثّان} few{{count} بثوث} many{{count} بثاً} other{{count} بث}}'**
  String medalsThresholdLives(int count);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ساعة بث واحدة} =2{ساعتا بث} few{{count} ساعات بث} many{{count} ساعة بث} other{{count} ساعة بث}}'**
  String medalsThresholdHours(int count);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الجاذبية {count}'**
  String medalsThresholdCharm(int count);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{رسالة عامة واحدة} =2{رسالتان عامتان} few{{count} رسائل عامة} many{{count} رسالة عامة} other{{count} رسالة عامة}}'**
  String medalsThresholdBullets(int count);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'مرة واحدة'**
  String get medalsThresholdOnce;

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'{level}، تم بلوغه'**
  String medalsLevelReachedLabel(String level);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'{name}، {status}'**
  String medalsCardLabel(String name, String status);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'ارتقت ميداليتك {name} إلى المستوى {level}'**
  String notifMedalLevelUp(String name, int level);

  /// D291: medal levels and the medals page.
  ///
  /// In ar, this message translates to:
  /// **'ارتقت ميداليتك إلى المستوى {level}'**
  String notifMedalLevelUpUnnamed(int level);

  /// D291: the medals the profile shows, under the one-medal stage.
  ///
  /// In ar, this message translates to:
  /// **'على ملفك: {count} من {max}'**
  String medalsProfileWornCount(int count, int max);

  /// D291: a Wealth Kings level threshold (coins of gifts sent, lucky excluded).
  ///
  /// In ar, this message translates to:
  /// **'{amount} كوينز من الهدايا'**
  String medalsThresholdGiftCoins(String amount);

  /// D291: a Lucky Master level threshold (coins of lucky gifts sent).
  ///
  /// In ar, this message translates to:
  /// **'{amount} كوينز من هدايا الحظ'**
  String medalsThresholdLuckyCoins(String amount);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'البلاغ'**
  String get staffReportViewTitle;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'محتوى مُبلّغ عنه'**
  String get staffReportBanner;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تراه كفريق كابسو مهما كانت حالته — لا يظهر للآخرين إلا إذا كان ظاهراً.'**
  String get staffReportBannerHint;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'ظاهر'**
  String get staffReportStateVisible;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'مخفي بالإشراف'**
  String get staffReportStateHidden;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'محذوف'**
  String get staffReportStateDeleted;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get staffReportStateExpired;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'على الهواء'**
  String get staffReportStateLive;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'انتهى البث'**
  String get staffReportStateEnded;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'غير موجود'**
  String get staffReportStateGone;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'المحتوى محذوف'**
  String get staffReportContentDeleted;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'يُعرض ما حفظه البلاغ وقت الإبلاغ.'**
  String get staffReportSnapshotShown;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'ريلز'**
  String get staffReportReelMark;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get staffReportVideoMark;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'التعليق على هذا المنشور'**
  String get staffReportOnPost;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'التعليق المُبلّغ عنه'**
  String get staffReportReportedComment;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'فتح الملف الشخصي'**
  String get staffReportOpenProfile;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'دخول البث كفريق كابسو'**
  String get staffReportEnterLive;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'البث منتهٍ — هذا ملخصه.'**
  String get staffReportLiveEnded;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'محادثة — للقراءة فقط'**
  String get staffReportDmTitle;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'من {sender} إلى {recipient}'**
  String staffReportDmBetween(String sender, String recipient);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'لقطة محفوظة من البلاغ: الرسالة المُبلّغ عنها فقط، لا باقي المحادثة. كل فتح يُسجَّل.'**
  String get staffReportDmPrivacy;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرسالة الأصلية بعد ٢٤ ساعة؛ اللقطة باقية.'**
  String get staffReportDmExpired;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'مُسح محتوى اللقطة بعد انتهاء مدة الحفظ.'**
  String get staffReportDmPurged;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get staffReportDmImage;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get staffReportDmVoice;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'هدية {code} ×{quantity}'**
  String staffReportDmGift(String code, String quantity);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'إجراءات'**
  String get staffReportActionsTitle;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تحذير'**
  String get staffReportActionWarn;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تقييد'**
  String get staffReportActionRestrict;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تعليق مؤقت'**
  String get staffReportActionSuspend;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حظر دائم'**
  String get staffReportActionBan;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المحتوى'**
  String get staffReportActionRemove;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البث'**
  String get staffReportActionEndLive;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'منع النشر'**
  String get staffReportRestrictNoPosting;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'منع البث'**
  String get staffReportRestrictNoLive;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'منع الرسائل'**
  String get staffReportRestrictChat;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يوماً} other{{count} يوم}}'**
  String staffReportDays(int count);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get staffReportDuration;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'السبب (يُحفظ في السجل)'**
  String get staffReportReason;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'اكتب السبب'**
  String get staffReportReasonRequired;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'يُحلّ البلاغ تلقائياً بعد الإجراء.'**
  String get staffReportAutoResolve;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تحذير {name}؟'**
  String staffReportConfirmWarn(String name);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تقييد {name}؟'**
  String staffReportConfirmRestrict(String name);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تعليق حساب {name} مؤقتاً؟'**
  String staffReportConfirmSuspend(String name);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حظر {name} نهائياً؟'**
  String staffReportConfirmBan(String name);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'إخفاء هذا المحتوى عن الجميع؟'**
  String get staffReportConfirmRemove;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'يُعلَّق الحساب ولا يستطيع الدخول. يمكن للإدارة رفعه من اللوحة.'**
  String get staffReportConfirmBanHint;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'لا يستطيع الدخول حتى تنتهي المدة.'**
  String get staffReportConfirmSuspendHint;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تنفيذ'**
  String get staffReportApply;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'تم الإجراء وحُلّ البلاغ'**
  String get staffReportActionDone;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حُلّ بإجراء: {action}'**
  String staffReportResolvedByAction(String action);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'لا إجراءات متاحة لدورك على هذا البلاغ.'**
  String get staffReportNoActions;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get staffReportOpen;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'المحادثة كاملة — للقراءة فقط'**
  String get staffReportThreadTitle;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'نسخة محفوظة عند الإبلاغ: كل رسائل المحادثة التي كانت موجودة حينها، ولا تُضاف رسائل لاحقة. كل فتح يُسجَّل.'**
  String get staffReportThreadPrivacy;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حُفظت {when}'**
  String staffReportThreadCaptured(String when);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حُفظت آخر {count} رسالة فقط.'**
  String staffReportThreadTruncated(String count);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'الرسالة المُبلّغ عنها'**
  String get staffReportThreadReported;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'ملف لم يُحفظ'**
  String get staffReportThreadMediaMissing;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'لم تكن في المحادثة رسائل عند الإبلاغ.'**
  String get staffReportThreadEmpty;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get staffReportActionDeleteContent;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get staffReportActionDeleteAccount;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا المحتوى نهائياً؟'**
  String get staffReportConfirmDeleteContent;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حذف حساب {name}؟'**
  String staffReportConfirmDeleteAccount(String name);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن التراجع عن الحذف النهائي، ويُبلَّغ صاحب المحتوى.'**
  String get staffReportConfirmDeleteContentHint;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'يبدأ حذف الحساب بمهلته (يمكن إلغاؤه من اللوحة خلالها)، ويُسجَّل خروجه من كل الأجهزة.'**
  String get staffReportConfirmDeleteAccountHint;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get staffReportConfirmWord;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'اكتب «{word}» للتأكيد'**
  String staffReportTypeToConfirm(String word);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'اكتب الكلمة كما هي'**
  String get staffReportConfirmMismatch;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'اضغط لفتح المحادثة'**
  String get staffReportThreadOpen;

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'الرسائل المحفوظة: {count}'**
  String staffReportThreadCount(String count);

  /// D296: a report opened by the staff (§10.109).
  ///
  /// In ar, this message translates to:
  /// **'بلاغ قديم: الرسالة المُبلّغ عنها فقط'**
  String get staffReportThreadOnlyReported;

  /// D295: the purple badge on a creator's live card and next to the host's name in the room.
  ///
  /// In ar, this message translates to:
  /// **'صانع محتوى'**
  String get liveCreatorBadge;

  /// D295: HOST_APPLICATION_NOT_ALLOWED CREATOR.
  ///
  /// In ar, this message translates to:
  /// **'أنت صانع محتوى: تبث من برنامج صناع المحتوى، ولا يمكن أن تكون مضيفاً أيضاً'**
  String get hostApplyRefusedCreator;

  /// D295: CREATOR_APPLICATION_NOT_ALLOWED HOST.
  ///
  /// In ar, this message translates to:
  /// **'أنت مضيف: لا يمكن أن تكون صانع محتوى أيضاً.'**
  String get creatorProgrammeHost;

  /// D295: AGENCY_OPEN_NOT_ALLOWED BANNED.
  ///
  /// In ar, this message translates to:
  /// **'حُظرت وكالتك ولا يمكن فتحها من جديد'**
  String get agencyOpenBanned;

  /// D295: the closed agency card, reason BANNED.
  ///
  /// In ar, this message translates to:
  /// **'حُظرت الوكالة لتفعيل صانع محتوى وهمي'**
  String get agencyClosedBanned;

  /// D295: AGENCY_ACTIVATION_NOT_ALLOWED.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تفعيل هذا العضو بهذه الطريقة'**
  String get errorAgencyActivationNotAllowed;

  /// D295: the button on an agency member's row.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get agencyActivate;

  /// D295: the activation sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل {name}'**
  String agencyActivateTitle(String name);

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'اختر كيف يبث هذا العضو:'**
  String get agencyActivateIntro;

  /// D295: the first choice; also the member's tag.
  ///
  /// In ar, this message translates to:
  /// **'مضيف'**
  String get agencyActivateAsHost;

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'يبث ضمن وكالتك بنسبة المضيف المعتادة.'**
  String get agencyActivateAsHostBody;

  /// D295: the second choice.
  ///
  /// In ar, this message translates to:
  /// **'صانع محتوى'**
  String get agencyActivateAsCreator;

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'لمن يصنع محتوى على منصات أخرى. تحتاج معلوماته وروابط أعماله.'**
  String get agencyActivateAsCreatorBody;

  /// D295: the note on the creator choice (owner's wording).
  ///
  /// In ar, this message translates to:
  /// **'نسبة صانع المحتوى 70%'**
  String get agencyCreatorShareNote;

  /// D295: the warning before activating a creator (owner's wording).
  ///
  /// In ar, this message translates to:
  /// **'إن قمت بتفعيل شخص على أنه صانع محتوى ولم يكن كذلك، سيتم حظر الوكالة وخسارة أرباحك.'**
  String get agencyCreatorWarning;

  /// D295: the tick the agent must give.
  ///
  /// In ar, this message translates to:
  /// **'قرأت التحذير وأؤكد أن هذا الشخص صانع محتوى'**
  String get agencyCreatorConfirm;

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'ضع علامة التأكيد للمتابعة'**
  String get agencyCreatorConfirmError;

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل كمضيف'**
  String get agencyActivateHostButton;

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل كصانع محتوى'**
  String get agencyActivateCreatorButton;

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'أصبح {name} مضيفاً'**
  String agencyActivatedHost(String name);

  /// D295: content creators go live.
  ///
  /// In ar, this message translates to:
  /// **'أصبح {name} صانع محتوى'**
  String agencyActivatedCreator(String name);

  /// D295: AGENCY_ACTIVATION_NOT_ALLOWED HOST.
  ///
  /// In ar, this message translates to:
  /// **'هذا العضو مضيف: لا يمكن تفعيله صانع محتوى'**
  String get agencyActivationRefusedHost;

  /// D295: AGENCY_ACTIVATION_NOT_ALLOWED CREATOR.
  ///
  /// In ar, this message translates to:
  /// **'هذا العضو صانع محتوى: لا يمكن تفعيله مضيفاً'**
  String get agencyActivationRefusedCreator;

  /// D295: AGENCY_ACTIVATION_NOT_ALLOWED AGENCY_SUSPENDED.
  ///
  /// In ar, this message translates to:
  /// **'وكالتك موقوفة من الفريق'**
  String get agencyActivationRefusedSuspended;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The badge kind inside «موثّق: …».
  ///
  /// In ar, this message translates to:
  /// **'مالك التطبيق'**
  String get verificationBadgeOwner;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The badge kind inside «موثّق: …».
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو'**
  String get verificationBadgeStaff;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The badge kind inside «موثّق: …».
  ///
  /// In ar, this message translates to:
  /// **'وكيل شحن'**
  String get verificationBadgeRechargeAgent;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The badge kind inside «موثّق: …».
  ///
  /// In ar, this message translates to:
  /// **'وكيل مضيفين'**
  String get verificationBadgeHostAgent;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The badge kind inside «موثّق: …».
  ///
  /// In ar, this message translates to:
  /// **'صانع محتوى'**
  String get verificationBadgeCreator;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The badge kind inside «موثّق: …».
  ///
  /// In ar, this message translates to:
  /// **'مضيف موثّق الهوية'**
  String get verificationBadgeVerifiedHost;

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The spoken label and the tooltip title.
  ///
  /// In ar, this message translates to:
  /// **'موثّق: {kind}'**
  String verificationBadgeLabel(String kind);

  /// D293: the automatic verification badge «شارة التوثيق» beside the name (profile header, Me tab). The tooltip's second line.
  ///
  /// In ar, this message translates to:
  /// **'شارة تُمنح تلقائياً حسب الشروط'**
  String get verificationBadgeAbout;

  /// D300: «مدرسة المحتوى» requirement — followers (ACTIVE accounts, as the profile counts them).
  ///
  /// In ar, this message translates to:
  /// **'المتابعون'**
  String get medalsReqFollowers;

  /// D300: «مدرسة المحتوى» requirement — likes from other ACTIVE accounts on posts and reels.
  ///
  /// In ar, this message translates to:
  /// **'الإعجابات'**
  String get medalsReqLikes;

  /// D300: «مدرسة المحتوى» requirement — views from other ACTIVE accounts of posts and reels.
  ///
  /// In ar, this message translates to:
  /// **'المشاهدات'**
  String get medalsReqViews;

  /// D300: the heading above the three requirement bars in the medal sheet.
  ///
  /// In ar, this message translates to:
  /// **'الشروط الثلاثة معاً للمستوى التالي'**
  String get medalsReqAllTogether;

  /// D300: a creators-only medal for a person who is not a content creator now (card pill and sheet).
  ///
  /// In ar, this message translates to:
  /// **'لصنّاع المحتوى فقط'**
  String get medalsCreatorsOnly;

  /// D300: the sheet's note for a person who is not a content creator now.
  ///
  /// In ar, this message translates to:
  /// **'تُحسب المتابعات والإعجابات والمشاهدات لصنّاع المحتوى فقط. المستوى الذي وصلت إليه يبقى لك.'**
  String get medalsCreatorsOnlyBody;

  /// D300: a «لاعب الأحكام» level threshold (PK points).
  ///
  /// In ar, this message translates to:
  /// **'{points} نقطة PK'**
  String medalsThresholdPkPoints(String points);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The visitor's follow button on the owner's page.
  ///
  /// In ar, this message translates to:
  /// **'متابعة المؤسس'**
  String get ownerFollow;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The follow button once following (a tap asks before unfollowing).
  ///
  /// In ar, this message translates to:
  /// **'تتابع المؤسس'**
  String get ownerFollowing;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The visitor's button that opens «اقترح ميزة / أبلغ عن موظف».
  ///
  /// In ar, this message translates to:
  /// **'اقترح ميزة / أبلغ'**
  String get ownerFeedbackButton;

  /// D357 (§10.153): the founder's badge (the D293 seal in Kabso red with a white play triangle) at the bottom centre of his photo — its spoken label and tooltip.
  ///
  /// In ar, this message translates to:
  /// **'مؤسس Kabso Live'**
  String get founderBadgeLabel;

  /// D357 (§10.153): the spoken label and tooltip of the Instagram button in the founder page's social row.
  ///
  /// In ar, this message translates to:
  /// **'إنستغرام'**
  String get founderSocialInstagram;

  /// D357: the Facebook button of the founder page's social row.
  ///
  /// In ar, this message translates to:
  /// **'فيسبوك'**
  String get founderSocialFacebook;

  /// D357: the WhatsApp button of the founder page's social row.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get founderSocialWhatsApp;

  /// D357: the Snapchat button of the founder page's social row.
  ///
  /// In ar, this message translates to:
  /// **'سناب شات'**
  String get founderSocialSnapchat;

  /// D357 (§10.153): the founder's page, the second of its two numbers — how many «اقترح ميزة / أبلغ» submissions (suggestions and complaints together) he has received.
  ///
  /// In ar, this message translates to:
  /// **'الاقتراحات والشكاوى'**
  String get founderFeedbackStat;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The chip on what only the owner sees.
  ///
  /// In ar, this message translates to:
  /// **'خاص'**
  String get ownerPrivate;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The edit button of a section.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get ownerEdit;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Delete a milestone.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get ownerDelete;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Save a milestone.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get ownerSave;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Opens every official announcement.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get ownerSeeAll;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Reorder a milestone.
  ///
  /// In ar, this message translates to:
  /// **'تحريك لأعلى'**
  String get ownerMoveUp;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Reorder a milestone.
  ///
  /// In ar, this message translates to:
  /// **'تحريك لأسفل'**
  String get ownerMoveDown;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). A required form field.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get ownerFieldRequired;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The owner's private dashboard card.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المؤسس'**
  String get ownerDashboardTitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard tile: users online now.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم الآن'**
  String get ownerDashboardOnline;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard details: online users.
  ///
  /// In ar, this message translates to:
  /// **'المستخدمون النشطون آخر {minutes} دقائق'**
  String ownerDashboardOnlineLong(int minutes);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard tile: live rooms now.
  ///
  /// In ar, this message translates to:
  /// **'بث الآن'**
  String get ownerDashboardLives;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard tile: money received today.
  ///
  /// In ar, this message translates to:
  /// **'دخل اليوم'**
  String get ownerDashboardIncome;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Spoken when the income is blurred.
  ///
  /// In ar, this message translates to:
  /// **'مخفي، اضغط للإظهار'**
  String get ownerDashboardIncomeHidden;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard details: card top-ups.
  ///
  /// In ar, this message translates to:
  /// **'شحن الموقع (بطاقات)'**
  String get ownerDashboardIncomeWebsite;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard details: agents' paid top-ups.
  ///
  /// In ar, this message translates to:
  /// **'شحن الوكلاء'**
  String get ownerDashboardIncomeAgents;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard details: when the numbers were computed.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث {time} · يُحدَّث كل دقيقة'**
  String ownerDashboardUpdated(String time);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Dashboard load failure.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الأرقام — اضغط لإعادة المحاولة'**
  String get ownerDashboardFailed;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The owner's official announcements section.
  ///
  /// In ar, this message translates to:
  /// **'إعلانات رسمية'**
  String get ownerOfficialTitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The label on the owner's official post.
  ///
  /// In ar, this message translates to:
  /// **'رسمي'**
  String get ownerOfficialLabel;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Post menu (owner only).
  ///
  /// In ar, this message translates to:
  /// **'تعيين كإعلان رسمي'**
  String get ownerOfficialMark;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Post menu (owner only).
  ///
  /// In ar, this message translates to:
  /// **'إزالة من الإعلانات الرسمية'**
  String get ownerOfficialUnmark;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Snack after marking.
  ///
  /// In ar, this message translates to:
  /// **'أصبح إعلاناً رسمياً في ملفك'**
  String get ownerOfficialMarked;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Snack after unmarking.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من الإعلانات الرسمية'**
  String get ownerOfficialUnmarked;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The owner's empty section.
  ///
  /// In ar, this message translates to:
  /// **'لا إعلانات رسمية بعد. اختر «تعيين كإعلان رسمي» من قائمة أي منشور لك.'**
  String get ownerOfficialEmptyOwn;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). An announcement without text.
  ///
  /// In ar, this message translates to:
  /// **'إعلان'**
  String get ownerOfficialUntitled;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The owner's timeline section.
  ///
  /// In ar, this message translates to:
  /// **'رحلة Kabso'**
  String get ownerJourneyTitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Under the timeline title.
  ///
  /// In ar, this message translates to:
  /// **'قصة المؤسس والمنصة'**
  String get ownerJourneySubtitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The latest milestone's mark.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get ownerJourneyLatest;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Add a milestone.
  ///
  /// In ar, this message translates to:
  /// **'إضافة محطة'**
  String get ownerJourneyAdd;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The owner's empty timeline.
  ///
  /// In ar, this message translates to:
  /// **'أضف أول محطة في رحلة Kabso'**
  String get ownerJourneyAddFirst;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The form's title when editing.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المحطة'**
  String get ownerJourneyEditOne;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The editor sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'تعديل رحلة Kabso'**
  String get ownerJourneyEditorTitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The editor's hint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للترتيب أو استخدم الأسهم · حتى {max} محطة'**
  String ownerJourneyEditorHint(int max);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The editor's empty state.
  ///
  /// In ar, this message translates to:
  /// **'لا محطات بعد — أضف الأولى.'**
  String get ownerJourneyEmptyOwn;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Confirm a delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذه المحطة؟'**
  String get ownerJourneyDeleteConfirm;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'العنوان (بالعربية)'**
  String get ownerMilestoneTitleAr;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'العنوان (بالإنجليزية)'**
  String get ownerMilestoneTitleEn;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'سطر قصير (بالعربية)'**
  String get ownerMilestoneLineAr;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'سطر قصير (بالإنجليزية)'**
  String get ownerMilestoneLineEn;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'الشهر'**
  String get ownerMilestoneMonth;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'السنة'**
  String get ownerMilestoneYear;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Form field.
  ///
  /// In ar, this message translates to:
  /// **'الأيقونة'**
  String get ownerMilestoneIcon;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The latest switch's hint.
  ///
  /// In ar, this message translates to:
  /// **'تظهر عليها «الأحدث» (محطة واحدة فقط)'**
  String get ownerMilestoneLatestHint;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Edit profile section (owner only).
  ///
  /// In ar, this message translates to:
  /// **'فيديو الغلاف'**
  String get ownerCoverVideoTitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The section's hint.
  ///
  /// In ar, this message translates to:
  /// **'فيديو قصير يتكرر بدل صورة الغلاف (حتى 60 ثانية). من لغة تطبيقه العربية يرى الفيديو العربي، والباقون الإنجليزي؛ إن وُجد واحد فقط يراه الجميع.'**
  String get ownerCoverVideoHint;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Row label.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو العربي'**
  String get ownerCoverVideoArabic;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Row label.
  ///
  /// In ar, this message translates to:
  /// **'الفيديو الإنجليزي'**
  String get ownerCoverVideoEnglish;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). No video for this language.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد'**
  String get ownerCoverVideoNone;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The video's length.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث'**
  String ownerCoverVideoSeconds(int seconds);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Upload progress.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الرفع… {percent}%'**
  String ownerCoverVideoUploading(int percent);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Pick a video.
  ///
  /// In ar, this message translates to:
  /// **'اختيار فيديو'**
  String get ownerCoverVideoChoose;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Replace the video.
  ///
  /// In ar, this message translates to:
  /// **'استبدال'**
  String get ownerCoverVideoReplace;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Remove the video.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الفيديو'**
  String get ownerCoverVideoRemove;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Snack.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ فيديو الغلاف'**
  String get ownerCoverVideoSaved;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Snack.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل فيديو الغلاف'**
  String get ownerCoverVideoRemoved;

  /// D307: the founder's page (§10.112.11). The founder's default bio when he has set none for this language.
  ///
  /// In ar, this message translates to:
  /// **'مؤسس Kabso Live. بنيتُ هذه المنصة لتجمعنا في البث والمحتوى ومجتمع واحد. اقتراحاتكم تصلني مباشرة، فشاركوني أفكاركم.'**
  String get ownerBioDefault;

  /// D307: the founder's page (§10.112.11). The bio editor's title and its button in «لوحة المؤسس».
  ///
  /// In ar, this message translates to:
  /// **'بايو المؤسس'**
  String get ownerBioTitle;

  /// D307: the founder's page (§10.112.11). The bio editor's hint.
  ///
  /// In ar, this message translates to:
  /// **'يظهر لكل زائر بلغة تطبيقه. اترك الحقل فارغاً ليظهر النص الافتراضي.'**
  String get ownerBioHint;

  /// D307: the founder's page (§10.112.11). The Arabic field's label.
  ///
  /// In ar, this message translates to:
  /// **'بالعربية'**
  String get ownerBioArabic;

  /// D307: the founder's page (§10.112.11). The English field's label.
  ///
  /// In ar, this message translates to:
  /// **'بالإنجليزية'**
  String get ownerBioEnglish;

  /// D307: the founder's page (§10.112.11). Snack.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ البايو'**
  String get ownerBioSaved;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Spoken label.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل فيديو الغلاف'**
  String get ownerCoverVideoPlay;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Spoken label.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف فيديو الغلاف مؤقتاً'**
  String get ownerCoverVideoPause;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Spoken label.
  ///
  /// In ar, this message translates to:
  /// **'كتم الصوت'**
  String get ownerCoverVideoMute;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Spoken label.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الصوت'**
  String get ownerCoverVideoUnmute;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'اقترح ميزة أو أبلغ عن موظف'**
  String get ownerFeedbackTitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Under the sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'يصل مباشرة إلى صندوق المؤسس.'**
  String get ownerFeedbackSubtitle;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Choice 1.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح ميزة'**
  String get ownerFeedbackFeature;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Choice 2.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن موظف'**
  String get ownerFeedbackReport;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The suggestion's text hint.
  ///
  /// In ar, this message translates to:
  /// **'ما الميزة التي تريدها؟'**
  String get ownerFeedbackFeatureHint;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). The report's text hint.
  ///
  /// In ar, this message translates to:
  /// **'ماذا حدث؟ اذكر التفاصيل'**
  String get ownerFeedbackReportHint;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Label.
  ///
  /// In ar, this message translates to:
  /// **'الموظف'**
  String get ownerFeedbackStaff;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Search hint.
  ///
  /// In ar, this message translates to:
  /// **'@اسم المستخدم أو آيدي الموظف'**
  String get ownerFeedbackStaffHint;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). No search result.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موظف بهذا الاسم'**
  String get ownerFeedbackStaffNone;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Label.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get ownerFeedbackCategory;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Suggestion picture.
  ///
  /// In ar, this message translates to:
  /// **'إضافة صورة'**
  String get ownerFeedbackImage;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report pictures.
  ///
  /// In ar, this message translates to:
  /// **'صور الإثبات (حتى {count})'**
  String ownerFeedbackEvidence(int count);

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Bad picture.
  ///
  /// In ar, this message translates to:
  /// **'هذه الصورة غير مدعومة أو كبيرة جداً'**
  String get ownerFeedbackImageInvalid;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Confidentiality note.
  ///
  /// In ar, this message translates to:
  /// **'بلاغك سري: لا يصل إلى الموظف ولا إلى المشرفين، تقرؤه الإدارة العليا فقط.'**
  String get ownerFeedbackConfidential;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Send button.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get ownerFeedbackSend;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Snack.
  ///
  /// In ar, this message translates to:
  /// **'وصل إلى صندوق المؤسس. شكراً لك.'**
  String get ownerFeedbackSent;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report reason.
  ///
  /// In ar, this message translates to:
  /// **'إساءة أو تعامل سيئ'**
  String get ownerCategoryRudeness;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report reason.
  ///
  /// In ar, this message translates to:
  /// **'إساءة استخدام الصلاحيات'**
  String get ownerCategoryAbuseOfPower;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report reason.
  ///
  /// In ar, this message translates to:
  /// **'إجراء غير عادل'**
  String get ownerCategoryUnfairAction;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report reason.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل أو عدم الرد'**
  String get ownerCategoryNoResponse;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report reason.
  ///
  /// In ar, this message translates to:
  /// **'رشوة أو فساد'**
  String get ownerCategoryCorruption;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Report reason.
  ///
  /// In ar, this message translates to:
  /// **'سبب آخر'**
  String get ownerCategoryOther;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Error OWNER_ONLY.
  ///
  /// In ar, this message translates to:
  /// **'هذا متاح لصاحب البرنامج فقط.'**
  String get errorOwnerOnly;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Error OWNER_JOURNEY_LIMIT.
  ///
  /// In ar, this message translates to:
  /// **'وصلت رحلة Kabso إلى الحد الأقصى من المحطات.'**
  String get errorOwnerJourneyLimit;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Notification OWNER_FEEDBACK_NEW (FEATURE).
  ///
  /// In ar, this message translates to:
  /// **'اقتراح ميزة جديد في صندوق المؤسس'**
  String get notifOwnerFeedbackFeature;

  /// D301: the app owner's profile «صفحة صاحب البرنامج» (§10.112). Notification OWNER_FEEDBACK_NEW (STAFF_REPORT).
  ///
  /// In ar, this message translates to:
  /// **'بلاغ جديد عن موظف في صندوق المؤسس'**
  String get notifOwnerFeedbackReport;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The composer's title and the profile button.
  ///
  /// In ar, this message translates to:
  /// **'إعلان رسمي جديد'**
  String get ownerAnnouncementNew;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The composer's title when editing.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الإعلان'**
  String get ownerAnnouncementEdit;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The Arabic caption field.
  ///
  /// In ar, this message translates to:
  /// **'النص بالعربية'**
  String get ownerAnnouncementTextAr;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The English caption field.
  ///
  /// In ar, this message translates to:
  /// **'النص بالإنجليزية'**
  String get ownerAnnouncementTextEn;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The composer's explanation.
  ///
  /// In ar, this message translates to:
  /// **'من لغة تطبيقه العربية يرى النص العربي، والباقون الإنجليزي. يظهر أول منشور عند الجميع حتى تنشر إعلاناً أحدث، ويصلهم إشعار مرة واحدة.'**
  String get ownerAnnouncementHint;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The composer's note when editing.
  ///
  /// In ar, this message translates to:
  /// **'التعديل لا يرسل إشعاراً جديداً.'**
  String get ownerAnnouncementEditHint;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The photos button.
  ///
  /// In ar, this message translates to:
  /// **'صور (اختياري)'**
  String get ownerAnnouncementPhotos;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). Publish button.
  ///
  /// In ar, this message translates to:
  /// **'نشر للجميع'**
  String get ownerAnnouncementPublish;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). Snack.
  ///
  /// In ar, this message translates to:
  /// **'نُشر الإعلان، ويصل الإشعار للجميع خلال دقائق.'**
  String get ownerAnnouncementPublished;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). Snack.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ الإعلان دون إشعار جديد.'**
  String get ownerAnnouncementSaved;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). The dashboard's income definition.
  ///
  /// In ar, this message translates to:
  /// **'ما يدخل Kabso فقط: شحن المتجر بالبطاقات بعد الاسترداد، وما يدفعه الوكلاء لـ Kabso لشراء رصيدهم. لا يُحسب ما يبيعه الوكيل للمستخدمين.'**
  String get ownerDashboardIncomeNote;

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). A line of money received in another currency.
  ///
  /// In ar, this message translates to:
  /// **'بعملة أخرى ({currency})'**
  String ownerDashboardIncomeOther(String currency);

  /// D301 follow-up: the owner's bilingual announcements and the owner's answers (§10.112.7–8). Notification OWNER_ANNOUNCEMENT.
  ///
  /// In ar, this message translates to:
  /// **'إعلان رسمي من المؤسس: {text}'**
  String notifOwnerAnnouncement(String text);

  /// D301 (§10.112.9): the founder pinned in search — the line under his name.
  ///
  /// In ar, this message translates to:
  /// **'مؤسس Kabso Live'**
  String get ownerSearchRole;

  /// D301 (§10.112.9): the founder pinned in search — the short follow button (the name stays readable).
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get ownerSearchFollow;

  /// D301 (§10.112.9): the founder pinned in search — the button once he is followed.
  ///
  /// In ar, this message translates to:
  /// **'متابَع'**
  String get ownerSearchFollowing;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the section title.
  ///
  /// In ar, this message translates to:
  /// **'الربح'**
  String get ownerProfitTitle;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the card's strip.
  ///
  /// In ar, this message translates to:
  /// **'ربح اليوم'**
  String get ownerProfitToday;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the card: before every share.
  ///
  /// In ar, this message translates to:
  /// **'قبل'**
  String get ownerProfitBeforeShort;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the card: after every share and the fixed costs.
  ///
  /// In ar, this message translates to:
  /// **'بعد'**
  String get ownerProfitAfterShort;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the money Kabso received.
  ///
  /// In ar, this message translates to:
  /// **'الدخل قبل'**
  String get ownerProfitBefore;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — what is left.
  ///
  /// In ar, this message translates to:
  /// **'الربح النهائي بعد'**
  String get ownerProfitAfter;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the day tab.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get ownerProfitDay;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the month tab.
  ///
  /// In ar, this message translates to:
  /// **'الشهر'**
  String get ownerProfitMonth;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the day picker button.
  ///
  /// In ar, this message translates to:
  /// **'اختيار يوم'**
  String get ownerProfitPickDay;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a part of «قبل».
  ///
  /// In ar, this message translates to:
  /// **'شحن المتجر بالبطاقات'**
  String get ownerProfitCardCharged;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a part of «قبل».
  ///
  /// In ar, this message translates to:
  /// **'المبالغ المستردة'**
  String get ownerProfitRefunds;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a part of «قبل».
  ///
  /// In ar, this message translates to:
  /// **'الاعتراضات البنكية'**
  String get ownerProfitChargebacks;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a part of «قبل».
  ///
  /// In ar, this message translates to:
  /// **'شراء الوكلاء من Kabso'**
  String get ownerProfitAgents;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the deductions heading.
  ///
  /// In ar, this message translates to:
  /// **'الخصومات'**
  String get ownerProfitDeductions;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction GIFTS.
  ///
  /// In ar, this message translates to:
  /// **'نصيب المضيفين وصنّاع المحتوى من الهدايا'**
  String get ownerProfitGifts;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction AGENCY_COMMISSIONS.
  ///
  /// In ar, this message translates to:
  /// **'عمولات الوكالات'**
  String get ownerProfitAgencies;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction REFERRAL_REWARDS.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت الدعوات'**
  String get ownerProfitReferrals;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction TASK_REWARDS.
  ///
  /// In ar, this message translates to:
  /// **'جوائز المهام والأهداف'**
  String get ownerProfitTasks;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction STAFF_COMMISSIONS.
  ///
  /// In ar, this message translates to:
  /// **'عمولات الموظفين على التجنيد'**
  String get ownerProfitStaff;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction TEAM_ADJUSTMENTS.
  ///
  /// In ar, this message translates to:
  /// **'تعديلات الفريق'**
  String get ownerProfitTeam;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction CARD_FEES.
  ///
  /// In ar, this message translates to:
  /// **'رسوم البطاقات (تقديرية)'**
  String get ownerProfitCardFees;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a cherry line's detail.
  ///
  /// In ar, this message translates to:
  /// **'الكرز: {count}، بسعر السحب {rate} لكل مليون'**
  String ownerProfitCherries(String count, String rate);

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the card fees' detail.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات: {count}، بنسبة {percent} و{fixed} للطلب'**
  String ownerProfitFees(String count, String percent, String fixed);

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the fixed costs line and the editor's title.
  ///
  /// In ar, this message translates to:
  /// **'تكاليف ثابتة'**
  String get ownerProfitFixed;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a fixed cost's share.
  ///
  /// In ar, this message translates to:
  /// **'أيام: {days} من {monthly} شهرياً'**
  String ownerProfitFixedShare(String days, String monthly);

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — no fixed cost.
  ///
  /// In ar, this message translates to:
  /// **'لا تكاليف ثابتة في هذه الفترة'**
  String get ownerProfitFixedNone;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the current month's note.
  ///
  /// In ar, this message translates to:
  /// **'حتى اليوم: الحصة المنقضية من التكاليف الثابتة'**
  String get ownerProfitPartial;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — another currency's line, never converted.
  ///
  /// In ar, this message translates to:
  /// **'{currency}: قبل {before}، بعد {after}'**
  String ownerProfitOther(String currency, String before, String after);

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the error.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حساب الربح'**
  String get ownerProfitFailed;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get ownerProfitRetry;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the editor button.
  ///
  /// In ar, this message translates to:
  /// **'إدارة التكاليف الثابتة'**
  String get ownerCostsManage;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the editor's explanation.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ شهري بالدولار يُقسَّم على أيام الشهر'**
  String get ownerCostsHint;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the empty list.
  ///
  /// In ar, this message translates to:
  /// **'لا تكاليف ثابتة بعد'**
  String get ownerCostsEmpty;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the add button.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تكلفة'**
  String get ownerCostsAdd;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the form's title when editing.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التكلفة'**
  String get ownerCostsEdit;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the name field.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get ownerCostsName;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the name hint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: Claude أو LiveKit أو الخوادم'**
  String get ownerCostsNameHint;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the amount field.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الشهري (USD)'**
  String get ownerCostsMonthly;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the start day.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get ownerCostsFrom;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the end day.
  ///
  /// In ar, this message translates to:
  /// **'إلى (اختياري)'**
  String get ownerCostsTo;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — no end day.
  ///
  /// In ar, this message translates to:
  /// **'مستمرة'**
  String get ownerCostsOngoing;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a cost's amount.
  ///
  /// In ar, this message translates to:
  /// **'{amount} شهرياً'**
  String ownerCostsPerMonth(String amount);

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — a cost no longer active.
  ///
  /// In ar, this message translates to:
  /// **'انتهت'**
  String get ownerCostsEnded;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the form's error.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسماً ومبلغاً أكبر من صفر'**
  String get ownerCostsInvalid;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get ownerCostsDelete;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the delete confirmation.
  ///
  /// In ar, this message translates to:
  /// **'حذف {name}؟ لن تُحسب في الربح بعد الآن.'**
  String ownerCostsDeleteConfirm(String name);

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get ownerCostsCancel;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — snack.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التكلفة'**
  String get ownerCostsSaved;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — deduction COIN_REWARDS.
  ///
  /// In ar, this message translates to:
  /// **'عملات مُنحت مجاناً (جوائز ومكافآت)'**
  String get ownerProfitCoins;

  /// D301 follow-up (§10.112.10): «الربح» before and after every share, and the fixed costs — the coin rewards' detail.
  ///
  /// In ar, this message translates to:
  /// **'العملات: {count}، بأقل سعر للوكيل {rate} لكل مليون'**
  String ownerProfitCoinsDetail(String count, String rate);

  /// D303: the gift event's gifts section.
  ///
  /// In ar, this message translates to:
  /// **'هدايا الفعالية'**
  String get eventsGifts;

  /// D303: the points one event gift earns (per recipient).
  ///
  /// In ar, this message translates to:
  /// **'{points} نقطة'**
  String eventsGiftPoints(String points);

  /// D303: under the event gifts.
  ///
  /// In ar, this message translates to:
  /// **'كل عملة تُرسل بهدية من هدايا الفعالية تعطي نقاطاً'**
  String get eventsGiftPointsHint;

  /// D303: the gift event's built-in rule 1.
  ///
  /// In ar, this message translates to:
  /// **'تُحتسب النقاط فقط من إرسال هدايا الفعالية خلال مدتها.'**
  String get eventsRuleOnlyGifts;

  /// D303: rule 2.
  ///
  /// In ar, this message translates to:
  /// **'يجب الوصول إلى الحد الأدنى من النقاط للتأهل للجوائز.'**
  String get eventsRuleMinimum;

  /// D303: rule 3.
  ///
  /// In ar, this message translates to:
  /// **'تُرسل الجوائز تلقائياً بعد انتهاء الفعالية.'**
  String get eventsRuleAutoPayout;

  /// D303: under the gift event's dates.
  ///
  /// In ar, this message translates to:
  /// **'التواريخ بتوقيتك المحلي'**
  String get eventsLocalTime;

  /// D303: the SENDERS board tab.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب الداعمين'**
  String get eventsBoardSenders;

  /// D303: the RECEIVERS board tab.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب المضيفين'**
  String get eventsBoardReceivers;

  /// D303: the CREATORS board tab.
  ///
  /// In ar, this message translates to:
  /// **'صناع المحتوى'**
  String get eventsBoardCreators;

  /// D303: the AGENCIES board tab.
  ///
  /// In ar, this message translates to:
  /// **'الوكالات'**
  String get eventsBoardAgencies;

  /// D303: the CP board tab.
  ///
  /// In ar, this message translates to:
  /// **'الثنائيات CP'**
  String get eventsBoardCp;

  /// D303: a board's qualification minimum.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى للتأهل: {points} نقطة'**
  String eventsMinPoints(String points);

  /// D303: the caller's missing points.
  ///
  /// In ar, this message translates to:
  /// **'باقي {points} نقطة للتأهل'**
  String eventsPointsToQualify(String points);

  /// D303: the caller reached the minimum.
  ///
  /// In ar, this message translates to:
  /// **'مؤهّل للجائزة'**
  String get eventsQualified;

  /// D303: a board row below the minimum.
  ///
  /// In ar, this message translates to:
  /// **'لم يتأهل'**
  String get eventsNotQualified;

  /// D303: a cherries prize.
  ///
  /// In ar, this message translates to:
  /// **'{amount} كرز'**
  String eventsPrizeCherries(String amount);

  /// D303: a bag item or VIP prize for some days.
  ///
  /// In ar, this message translates to:
  /// **'{name} · {days} يوم'**
  String eventsPrizeDays(String name, String days);

  /// D303: a VIP prize without a tier name.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة VIP'**
  String get eventsPrizeVip;

  /// D303: a bag item prize without a name.
  ///
  /// In ar, this message translates to:
  /// **'عنصر'**
  String get eventsPrizeItem;

  /// D303: an agency row's owner.
  ///
  /// In ar, this message translates to:
  /// **'الوكيل: {name}'**
  String eventsAgencyOwner(String name);

  /// D303: a CP row's two partners.
  ///
  /// In ar, this message translates to:
  /// **'{a} و{b}'**
  String eventsCpPair(String a, String b);

  /// D303: the board tabs section.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب والجوائز'**
  String get eventsBoardsTitle;

  /// D303: the CP couple amount.
  ///
  /// In ar, this message translates to:
  /// **'{cherries} كرز للمضيف / {coins} كوينز لغيره'**
  String eventsPrizeCpMoney(String cherries, String coins);

  /// D303: a permanent prize.
  ///
  /// In ar, this message translates to:
  /// **'{name} · دائم'**
  String eventsPrizePermanent(String name);

  /// D303: an event medal level.
  ///
  /// In ar, this message translates to:
  /// **'{name} (المستوى {level})'**
  String eventsPrizeMedalLevel(String name, String level);

  /// D303: countdown to the start.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ بعد {time}'**
  String eventsCountdownStarts(String time);

  /// D303: countdown to the end.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي بعد {time}'**
  String eventsCountdownEnds(String time);

  /// D303: after the end.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الفعالية'**
  String get eventsCountdownEnded;

  /// D303: the sticky my-rank bar.
  ///
  /// In ar, this message translates to:
  /// **'مركزي: {rank} · {points} نقطة'**
  String eventsMyBar(String rank, String points);

  /// D303: the sticky bar when not ranked.
  ///
  /// In ar, this message translates to:
  /// **'لم تدخل الترتيب بعد · {points} نقطة'**
  String eventsMyBarNone(String points);

  /// D303: points to the next rank.
  ///
  /// In ar, this message translates to:
  /// **'باقي {points} نقطة للمركز {rank}'**
  String eventsToNextRank(String points, String rank);

  /// D303: tapping an event gift.
  ///
  /// In ar, this message translates to:
  /// **'أرسل {name} داخل بث'**
  String eventsSendGiftTitle(String name);

  /// D303: tapping an event gift outside a live.
  ///
  /// In ar, this message translates to:
  /// **'تُرسل هدايا الفعالية من لوحة الهدايا داخل أي بث مباشر، وتُحسب نقاطها فوراً.'**
  String get eventsSendGiftBody;

  /// D303: the button to the Live hub.
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى البث'**
  String get eventsGoLive;

  /// D303: the prize preview sheet.
  ///
  /// In ar, this message translates to:
  /// **'معاينة الجائزة'**
  String get eventsPrizePreview;

  /// D303: the EVENT_PRIZE_WON notification.
  ///
  /// In ar, this message translates to:
  /// **'مبروك، وصلتك جائزة فعالية'**
  String get notifEventPrizeWon;

  /// D311: the founder's moderation menu on a profile or a person card.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات المؤسس'**
  String get founderActionsTitle;

  /// D311: the sheet's title with the person's name.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات المؤسس · {name}'**
  String founderActionsFor(String name);

  /// D311: warn the person.
  ///
  /// In ar, this message translates to:
  /// **'تحذير'**
  String get founderActionWarn;

  /// D311: a timed ban.
  ///
  /// In ar, this message translates to:
  /// **'حظر مؤقت'**
  String get founderActionSuspend;

  /// D311: a permanent ban.
  ///
  /// In ar, this message translates to:
  /// **'حظر دائم'**
  String get founderActionBan;

  /// D311: delete the account (with its grace period).
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get founderActionDelete;

  /// D311: what WARN does.
  ///
  /// In ar, this message translates to:
  /// **'يصل للشخص إشعار تحذير، ويبقى حسابه كما هو.'**
  String get founderActionWarnHint;

  /// D311: what SUSPEND does.
  ///
  /// In ar, this message translates to:
  /// **'لا يستطيع الدخول حتى تنتهي المدة، ويُنهى بثه إن كان مباشراً.'**
  String get founderActionSuspendHint;

  /// D311: what BAN does.
  ///
  /// In ar, this message translates to:
  /// **'يُحظر الحساب حتى يُفك الحظر من لوحة التحكم.'**
  String get founderActionBanHint;

  /// D311: what DELETE_ACCOUNT does.
  ///
  /// In ar, this message translates to:
  /// **'يدخل الحساب مهلة الحذف ويمكن استرجاعه خلالها عند تسجيل الدخول، ثم يُحذف نهائياً.'**
  String get founderActionDeleteHint;

  /// D311: the reason field.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get founderActionReason;

  /// D311: the reason field's hint.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب — يُحفظ في سجل التدقيق'**
  String get founderActionReasonHint;

  /// D311: the timed ban's duration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get founderActionDuration;

  /// D311: a duration in days.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يوماً} other{{count} يوم}}'**
  String founderActionDays(int count);

  /// D311: the confirmation dialog's title.
  ///
  /// In ar, this message translates to:
  /// **'{action} — {name}'**
  String founderActionConfirmTitle(String action, String name);

  /// D311: the confirm button.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get founderActionConfirm;

  /// D311: the success message.
  ///
  /// In ar, this message translates to:
  /// **'تم: {action}'**
  String founderActionDone(String action);

  /// D311: ADMIN_ACTION_REFUSED (not ACTIVE / already pending).
  ///
  /// In ar, this message translates to:
  /// **'رُفض: الحساب غير نشط أو عليه إجراء قائم.'**
  String get founderActionNotActive;

  /// D311: refused on yourself or another owner.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تنفيذ هذا الإجراء على هذا الحساب.'**
  String get founderActionSelfOrOwner;

  /// D312: a custom gift's owner on the gift tile.
  ///
  /// In ar, this message translates to:
  /// **'هدية {name}'**
  String giftOwnerBy(String name);

  /// D312: the custom gift's owner for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'هدية مخصصة لصاحبها {name}'**
  String giftOwnerSemantics(String name);

  /// D314: the ranking page's month period.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get liveRankMonth;

  /// D314: the ranking page's year period.
  ///
  /// In ar, this message translates to:
  /// **'هذه السنة'**
  String get liveRankYear;

  /// D315: the ranking page's tab of players by game tickets spent.
  ///
  /// In ar, this message translates to:
  /// **'مجنون اللعب'**
  String get liveRankGames;

  /// D315: an empty «مجنون اللعب» board.
  ///
  /// In ar, this message translates to:
  /// **'لا تذاكر مُنفقة في الألعاب بعد في هذه الفترة.'**
  String get liveRankGamesEmpty;

  /// D315: tickets spent, for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'{formatted} تذكرة'**
  String liveRankTickets(String formatted);

  /// D320: coins sent as gifts on «الأغنى», for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'{formatted} كوينز'**
  String liveRankCoins(String formatted);

  /// D320: an empty «الأغنى» board.
  ///
  /// In ar, this message translates to:
  /// **'لم يُرسل أحد هدايا بعد في هذه الفترة.'**
  String get liveRankRichEmpty;

  /// D322: the owner's bottom bar, second tab — the party page (the voice rooms).
  ///
  /// In ar, this message translates to:
  /// **'الحفلة'**
  String get navParty;

  /// D322: the Live hub top bar's «+» (opens go-live); tooltip and screen-reader name.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بثاً'**
  String get liveHubGoLive;

  /// D322: the Moments top bar's «+» (opens the create menu: post, reel, story, live); tooltip and screen-reader name.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get feedCreate;

  /// D333: the photo editor's title.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصورة'**
  String get photoEditTitle;

  /// D333: apply the photo edit.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get photoEditDone;

  /// D333: leave the photo editor without changes.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get photoEditCancel;

  /// D333: the editor's preview, for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'الصورة بعد التعديل'**
  String get photoEditPreview;

  /// D333: turn the photo a quarter clockwise.
  ///
  /// In ar, this message translates to:
  /// **'تدوير'**
  String get photoEditRotate;

  /// D333: the edit could not be applied.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تعديل هذه الصورة'**
  String get photoEditFailed;

  /// D333: the crop tool.
  ///
  /// In ar, this message translates to:
  /// **'قص'**
  String get photoToolCrop;

  /// D333: the looks.
  ///
  /// In ar, this message translates to:
  /// **'فلاتر'**
  String get photoToolFilters;

  /// D333: brightness and contrast.
  ///
  /// In ar, this message translates to:
  /// **'ضبط'**
  String get photoToolAdjust;

  /// D333: keep the photo's own shape.
  ///
  /// In ar, this message translates to:
  /// **'الأصلي'**
  String get photoAspectOriginal;

  /// D333: no look.
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get photoFilterNormal;

  /// D333: more colour.
  ///
  /// In ar, this message translates to:
  /// **'زاهٍ'**
  String get photoFilterVivid;

  /// D333: warmer.
  ///
  /// In ar, this message translates to:
  /// **'دافئ'**
  String get photoFilterWarm;

  /// D333: cooler.
  ///
  /// In ar, this message translates to:
  /// **'بارد'**
  String get photoFilterCool;

  /// D333: black and white.
  ///
  /// In ar, this message translates to:
  /// **'أحادي'**
  String get photoFilterMono;

  /// D333: soft, lifted blacks.
  ///
  /// In ar, this message translates to:
  /// **'باهت'**
  String get photoFilterFade;

  /// D333: the brightness slider.
  ///
  /// In ar, this message translates to:
  /// **'السطوع'**
  String get photoAdjustBrightness;

  /// D333: the contrast slider.
  ///
  /// In ar, this message translates to:
  /// **'التباين'**
  String get photoAdjustContrast;

  /// D333: Create's top tab — a post.
  ///
  /// In ar, this message translates to:
  /// **'منشور'**
  String get createKindPost;

  /// D333: Create's top tab — a reel.
  ///
  /// In ar, this message translates to:
  /// **'ريلز'**
  String get createKindReel;

  /// D333: Create's top tab — a story.
  ///
  /// In ar, this message translates to:
  /// **'ستوري'**
  String get createKindStory;

  /// D333: open the photo editor on the big preview.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get createEditPhoto;

  /// D333: the hashtag and people suggestions under the caption, for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'اقتراحات'**
  String get createSuggestions;

  /// D333: the upload waits to retry by itself.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال — نعيد المحاولة…'**
  String get uploadRetrying;

  /// D333: open the new post.
  ///
  /// In ar, this message translates to:
  /// **'عرض'**
  String get uploadView;

  /// D333: a suggested hashtag's post count (already compact).
  ///
  /// In ar, this message translates to:
  /// **'{count} منشور'**
  String createSuggestionPosts(String count);

  /// D336: compact time since, in minutes (the Messages tab's rows and story cards).
  ///
  /// In ar, this message translates to:
  /// **'{n}د'**
  String relativeShortMinutes(int n);

  /// D336: compact time since, in hours.
  ///
  /// In ar, this message translates to:
  /// **'{n}س'**
  String relativeShortHours(int n);

  /// D336: compact time since, in days.
  ///
  /// In ar, this message translates to:
  /// **'{n}ي'**
  String relativeShortDays(int n);

  /// D336: the button beside search that opens the Messages boxes (chats, requests).
  ///
  /// In ar, this message translates to:
  /// **'صناديق الرسائل'**
  String get dmBoxes;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'المؤرشفة'**
  String get dmTabArchived;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get dmArchive;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الأرشفة'**
  String get dmUnarchive;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'تمت الأرشفة'**
  String get dmArchivedDone;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت إلى الدردشات'**
  String get dmUnarchivedDone;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دردشات مؤرشفة'**
  String get dmArchivedEmptyTitle;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'الدردشات التي تؤرشفها تظهر هنا فقط لك، وتعود إلى الدردشات عندما يصلك رد جديد.'**
  String get dmArchivedHint;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'مجموعة جديدة'**
  String get dmNewGroup;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'اسم المجموعة'**
  String get dmGroupNameLabel;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'مثال: أصدقاء الجامعة'**
  String get dmGroupNameHint;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا للمجموعة'**
  String get dmGroupNameRequired;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إضافة صورة'**
  String get dmGroupAddPhoto;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'تغيير الصورة'**
  String get dmGroupChangePhoto;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إزالة الصورة'**
  String get dmGroupRemovePhoto;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'صورة المجموعة'**
  String get dmGroupPhoto;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'اختر الأعضاء'**
  String get dmGroupPickMembers;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إضافة من تتابعهم ويتابعونك.'**
  String get dmGroupPickHint;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'اختر شخصًا واحدًا على الأقل'**
  String get dmGroupPickAtLeastOne;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'المختارون: {count}'**
  String dmGroupSelected(String count);

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن شخص'**
  String get dmGroupSearchPeople;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get dmGroupCreate;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أحد لإضافته بعد'**
  String get dmGroupCandidatesEmpty;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'تابِع أشخاصًا يتابعونك لتضيفهم إلى مجموعة.'**
  String get dmGroupCandidatesEmptyBody;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء: {count}'**
  String dmGroupMembersCount(String count);

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'معلومات المجموعة'**
  String get dmGroupInfo;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء'**
  String get dmGroupMembers;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إضافة أعضاء'**
  String get dmGroupAddMembers;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'أُضيف الأعضاء'**
  String get dmGroupMembersAdded;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'مشرف'**
  String get dmGroupAdmin;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'المنشئ'**
  String get dmGroupCreator;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get dmGroupYou;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'تعيين مشرفًا'**
  String get dmGroupMakeAdmin;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إزالة الإشراف'**
  String get dmGroupRemoveAdmin;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'إزالة من المجموعة'**
  String get dmGroupRemoveMember;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'تغيير الاسم'**
  String get dmGroupRename;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get dmGroupSave;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'مغادرة المجموعة'**
  String get dmGroupLeave;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'مغادرة المجموعة؟'**
  String get dmGroupLeaveTitle;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'لن تصلك رسائلها بعد الآن، ويمكن لمشرف إضافتك من جديد.'**
  String get dmGroupLeaveBody;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن المجموعة'**
  String get dmGroupReport;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'هذه المجموعة لم تعد متاحة'**
  String get dmGroupUnavailable;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'حساب غير متاح'**
  String get dmGroupUnknownSender;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'{name}: {text}'**
  String dmPreviewSender(String name, String text);

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'لا تُرسل الهدايا في المجموعات'**
  String get dmGroupNoGifts;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن أرشفة طلب مراسلة. اقبله أو احذفه.'**
  String get errorDmNotArchivable;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'وصلت المجموعة إلى الحد الأقصى من الأعضاء.'**
  String get errorDmGroupFull;

  /// D339: archived chats and group messages (CONVENTIONS §10.132, §10.133).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك إضافة بعض هؤلاء الأشخاص إلى مجموعة.'**
  String get errorDmGroupMemberNotAllowed;

  /// D340: the caller's final place on an ended event's board.
  ///
  /// In ar, this message translates to:
  /// **'مركزك النهائي: {rank}'**
  String eventsFinalRank(String rank);

  /// D340: an ended event the caller scored nothing in.
  ///
  /// In ar, this message translates to:
  /// **'لم تشارك'**
  String get eventsNotParticipated;

  /// D340: an ended board's place below the minimum.
  ///
  /// In ar, this message translates to:
  /// **'لم تتأهل — الحد الأدنى {points} نقطة'**
  String eventsNotQualifiedFinal(String points);

  /// D340: before the prize chips of an ended board.
  ///
  /// In ar, this message translates to:
  /// **'فزت بـ:'**
  String get eventsYouWon;

  /// D340: the sticky bar's prize line.
  ///
  /// In ar, this message translates to:
  /// **'فزت بـ {prize}'**
  String eventsYouWonShort(String prize);

  /// D340: the sticky bar's prize line when the bundle has more items.
  ///
  /// In ar, this message translates to:
  /// **'فزت بـ {prize} +{count}'**
  String eventsYouWonMore(String prize, String count);

  /// D340: a won prize held for review.
  ///
  /// In ar, this message translates to:
  /// **'تُسلَّم الجائزة بعد المراجعة'**
  String get eventsPrizePending;

  /// D340: ended, the board not frozen yet.
  ///
  /// In ar, this message translates to:
  /// **'النتائج النهائية قيد الاعتماد'**
  String get eventsResultsPending;

  /// D340: the sticky bar after the end.
  ///
  /// In ar, this message translates to:
  /// **'مركزك النهائي: {rank} · {points} نقطة'**
  String eventsMyBarFinal(String rank, String points);

  /// D340: the sticky bar when not ranked (no «· 0 نقطة»).
  ///
  /// In ar, this message translates to:
  /// **'لم تدخل الترتيب بعد'**
  String get eventsMyBarNotRanked;

  /// D340: the full-screen start announcement's badge.
  ///
  /// In ar, this message translates to:
  /// **'بدأت فعالية جديدة'**
  String get eventsAnnounceStarted;

  /// D340: the start announcement's button (opens the event).
  ///
  /// In ar, this message translates to:
  /// **'شارك الآن'**
  String get eventsAnnounceJoin;

  /// D340: closes a full-screen announcement.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get eventsAnnounceLater;

  /// D340: the start announcement's key prize.
  ///
  /// In ar, this message translates to:
  /// **'الجائزة الكبرى'**
  String get eventsAnnounceTopPrize;

  /// D340: the winner's full-screen announcement.
  ///
  /// In ar, this message translates to:
  /// **'مبروك'**
  String get eventsAnnounceWinTitle;

  /// D340: the winner's place and event.
  ///
  /// In ar, this message translates to:
  /// **'حصلت على المركز {rank} في {event}'**
  String eventsAnnounceWinBody(String rank, String event);

  /// D340: the winner's bundle.
  ///
  /// In ar, this message translates to:
  /// **'جائزتك'**
  String get eventsAnnounceYourPrize;

  /// D340: the winner's announcement button (opens the event).
  ///
  /// In ar, this message translates to:
  /// **'عرض النتائج'**
  String get eventsAnnounceResults;

  /// D340: the announcement's close button (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الإعلان'**
  String get eventsAnnounceClose;

  /// D340: the sticky bar after the end, below the minimum.
  ///
  /// In ar, this message translates to:
  /// **'لم تتأهل'**
  String get eventsNotQualifiedYou;

  /// D342: the party page's one mixed list (audio, podcast, multi) is empty.
  ///
  /// In ar, this message translates to:
  /// **'لا غرف في الحفلة الآن'**
  String get livePartyEmptyTitle;

  /// D342: under livePartyEmptyTitle (the other tabs are Following, Popular, Explore, Nearby).
  ///
  /// In ar, this message translates to:
  /// **'عد لاحقًا أو جرّب تبويبًا آخر.'**
  String get livePartyEmptyBody;

  /// D343: the sign-up's collapsed code field.
  ///
  /// In ar, this message translates to:
  /// **'لديك رمز دعوة؟'**
  String get signupCodeToggle;

  /// D343: the sign-up code field's label.
  ///
  /// In ar, this message translates to:
  /// **'رمز الدعوة أو رمز المشرف (اختياري)'**
  String get signupCodeLabel;

  /// D343: the sign-up code field's helper.
  ///
  /// In ar, this message translates to:
  /// **'رمز صديق دعاك، أو رمز المشرف الذي استقطبك. لا يمكن تغييره بعد التسجيل.'**
  String get signupCodeHelper;

  /// D343: the button that reads the clipboard (on tap only).
  ///
  /// In ar, this message translates to:
  /// **'لصق الرمز'**
  String get signupCodePaste;

  /// D343: clears a pre-filled code.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الرمز'**
  String get signupCodeRemove;

  /// D343: the code came from the Play install referrer.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف تلقائياً من رابط الدعوة. يمكنك إزالته.'**
  String get signupCodeFromLink;

  /// D343: the live check is running.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الرمز…'**
  String get signupCodeChecking;

  /// D343: the live check found an invite code.
  ///
  /// In ar, this message translates to:
  /// **'رمز دعوة من صديق'**
  String get signupCodeInviteOk;

  /// D343: the live check found a supervisor's staff ID.
  ///
  /// In ar, this message translates to:
  /// **'رمز المشرف {code}'**
  String signupCodeSupervisorOk(String code);

  /// D343: unknown code (live check or the 400 at sign-up).
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح. تأكد منه أو اتركه فارغاً.'**
  String get signupCodeNotFound;

  /// D343: paste found no code.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رمز في الحافظة'**
  String get signupCodeClipboardEmpty;

  /// D343: the supervisor's share link card.
  ///
  /// In ar, this message translates to:
  /// **'رابطك الشخصي'**
  String get staffSignupLinkTitle;

  /// D343: the supervisor's share link card.
  ///
  /// In ar, this message translates to:
  /// **'أرسله لمن تستقطبه: يحمّل التطبيق ويُضاف رمزك {code} عند إنشاء حسابه.'**
  String staffSignupLinkBody(String code);

  /// D343.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرابط'**
  String get staffSignupLinkCopy;

  /// D343.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get staffSignupLinkShare;

  /// D343.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الرابط'**
  String get staffSignupLinkCopied;

  /// D343: accounts created with the supervisor's code.
  ///
  /// In ar, this message translates to:
  /// **'سجّلوا برمزك: {granted} · لم يُحتسبوا: {withheld}'**
  String staffSignupCounts(int granted, int withheld);

  /// D343.
  ///
  /// In ar, this message translates to:
  /// **'لا يُحتسب من كان له حساب على الجهاز نفسه أو سجّل بالبريد نفسه من قبل.'**
  String get staffSignupWithheldNote;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'الشراء من المتجر'**
  String get storeIapTitle;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'الدفع عبر {store}'**
  String storeIapVia(String store);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة'**
  String storeIapCoins(String coins);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'شراء {coins} عملة بسعر {price}'**
  String storeIapBuyLabel(String coins, String price);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'قبل الشراء'**
  String get storeIapConsentTitle;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'تُسلَّم العملات فوراً إلى رصيدك وتُستهلك عند استخدامها، ولا تُسترد بعد الشراء.'**
  String get storeIapConsentDelivery;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'طلب استرداد عبر المتجر يُعدّ احتيالاً: تُسحب العملات (وقد يصبح رصيدك سالباً) ويُحظر الحساب وكل أجهزته.'**
  String get storeIapConsentFraud;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'عند طلب استرداد، يرسل Kabso إلى {store} مقدار ما استُهلك من هذه العملات ليقرّر الطلب.'**
  String storeIapConsentShare(String store);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على سياسة عدم الاسترداد وعلى مشاركة بيانات الاستخدام عند طلب استرداد'**
  String get storeIapConsentCheck;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'متابعة إلى {store}'**
  String storeIapConsentContinue(String store);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'{coins} عملة — {price}'**
  String storeIapConsentPrice(String coins, String price);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل في شروط الاستخدام: «مشتريات المتاجر وسياسة عدم الاسترداد».'**
  String get storeIapConsentTerms;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تأكيد الشراء مع المتجر…'**
  String get storeIapVerifying;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'الدفع قيد المعالجة لدى المتجر. تُضاف العملات عند اكتماله.'**
  String get storeIapPending;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت {coins} عملة إلى رصيدك.'**
  String storeIapSuccess(String coins);

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'لم تُضف العملات: الشراء من المتجر مرة واحدة لكل حساب وجهاز. يعيد المتجر المبلغ تلقائياً.'**
  String get storeIapRejected;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل الشراء في المتجر.'**
  String get storeIapStoreError;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'الشراء من المتجر غير متاح على هذا الجهاز لأنه محظور.'**
  String get storeIapDeviceBanned;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'اشتريت من المتجر من قبل على هذا الحساب أو الجهاز. الشراء من المتجر مرة واحدة فقط.'**
  String get storeIapLimitReached;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get storeIapDismiss;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'الشراء من المتجر غير متاح حالياً.'**
  String get errorStoreIapUnavailable;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'لم يؤكد المتجر هذا الشراء، ولم تُضف عملات.'**
  String get errorStoreIapVerificationFailed;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشراء مرتبط بحساب آخر.'**
  String get errorStoreIapPurchaseConflict;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'الدفع قيد المعالجة لدى المتجر.'**
  String get errorStoreIapPending;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'شراء من المتجر'**
  String get walletReasonStoreIap;

  /// D345: coins from the stores (Google Play / App Store), the no-refund consent and the states.
  ///
  /// In ar, this message translates to:
  /// **'استرداد عبر المتجر (سُحبت العملات)'**
  String get walletReasonStoreIapReversal;

  /// LIVE_CAPACITY_FULL (503, v1.113-live, D351): a new live does not fit on the servers now; the owner's words. Transient (Retry-After).
  ///
  /// In ar, this message translates to:
  /// **'البث مزدحم الآن، حاول بعد قليل'**
  String get errorLiveCapacityFull;

  /// D351: the live capacity guard «حد الامتلاء» (LIVE_CAPACITY_FULL, CONVENTIONS §10.148) — the sheet after a refused go-live.
  ///
  /// In ar, this message translates to:
  /// **'البث مزدحم'**
  String get liveCapacityTitle;

  /// D351: the live capacity guard «حد الامتلاء» (LIVE_CAPACITY_FULL, CONVENTIONS §10.148) — the sheet after a refused go-live.
  ///
  /// In ar, this message translates to:
  /// **'إعداداتك محفوظة، يمكنك المحاولة مجددًا بعد انتهاء العدّ.'**
  String get liveCapacityHint;

  /// D351: the live capacity guard «حد الامتلاء» (LIVE_CAPACITY_FULL, CONVENTIONS §10.148) — the sheet after a refused go-live.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجددًا'**
  String get liveCapacityRetry;

  /// D351: the live capacity guard «حد الامتلاء» (LIVE_CAPACITY_FULL, CONVENTIONS §10.148) — the sheet after a refused go-live. {wait}: m:ss until Retry-After has passed.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجددًا بعد {wait}'**
  String liveCapacityRetryIn(String wait);

  /// D351: the live capacity guard «حد الامتلاء» (LIVE_CAPACITY_FULL, CONVENTIONS §10.148) — the sheet after a refused go-live.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get liveCapacityClose;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get waRow;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'{count} محادثة بانتظار الرد'**
  String waRowBadge(int count);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get waTitle;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'غير مسندة'**
  String get waTabUnassigned;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'محادثاتي'**
  String get waTabMine;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get waTabAll;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'مغلقة'**
  String get waTabClosed;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الرقم'**
  String get waSearch;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد محادثات هنا'**
  String get waEmpty;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا رسائل العملاء إلى رقم Kabso الرسمي.'**
  String get waEmptyHint;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'واتساب غير مفعّل بعد'**
  String get waOff;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'يضبطه المالك بعد إنشاء حساب Meta للأعمال.'**
  String get waOffHint;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'{count} غير مقروءة'**
  String waUnreadCount(int count);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'معي'**
  String get waAssignedToMe;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'مع {name}'**
  String waAssignedTo(String name);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'غير مسندة'**
  String get waUnassigned;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'مغلقة'**
  String get waClosed;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'استلام'**
  String get waClaim;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إرجاع للقائمة'**
  String get waRelease;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get waTransfer;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'تحويل إلى'**
  String get waTransferTo;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get waClose;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح'**
  String get waReopen;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'نافذة الرد مفتوحة حتى {time}'**
  String waWindowOpen(String time);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'مرّت 24 ساعة على آخر رسالة من العميل: يمكنك فقط إرسال قالب معتمد.'**
  String get waWindowClosed;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لم يرسل العميل رسالة بعد: يمكنك فقط إرسال قالب معتمد.'**
  String get waWindowNever;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'اكتب ردك…'**
  String get waComposerHint;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get waSend;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إرسال قالب'**
  String get waSendTemplate;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'المتغيّر {n}'**
  String waTemplateParam(int n);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قوالب معتمدة بعد.'**
  String get waNoTemplates;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إرفاق'**
  String get waAttach;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'ردود سريعة'**
  String get waQuickReplies;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ردود سريعة.'**
  String get waNoQuickReplies;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get waVoice;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get waPlay;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get waPause;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'فتح الملف'**
  String get waOpenFile;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'الملف أكبر من الحد المسموح ولم يُحفظ.'**
  String get waMediaTooLarge;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'نوع الملف غير مسموح ولم يُحفظ.'**
  String get waMediaRefused;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر جلب الملف من واتساب.'**
  String get waMediaFailed;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'موقع'**
  String get waLocation;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'رسالة من نوع غير مدعوم بعد.'**
  String get waUnsupported;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'قالب: {name}'**
  String waTemplateTag(String name);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت'**
  String get waStatusSent;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'وصلت'**
  String get waStatusDelivered;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'قُرئت'**
  String get waStatusRead;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'فشل الإرسال'**
  String get waStatusFailed;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'أرسلها {name}'**
  String waSentBy(String name);

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'العميل'**
  String get waCustomer;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'حساب Kabso'**
  String get waAccount;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'غير مربوط بحساب. اطلب من العميل اسم المستخدم ثم اربطه.'**
  String get waNoAccount;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'ربط بحساب'**
  String get waLink;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الربط'**
  String get waUnlink;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get waUsername;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات داخلية'**
  String get waNotes;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لا تُرسل إلى العميل أبداً.'**
  String get waNotesHint;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'إضافة ملاحظة'**
  String get waAddNote;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ملاحظات.'**
  String get waNoNotes;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'سجل الإسناد'**
  String get waHistory;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'موظف'**
  String get waSomeone;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'كتم إشعارات واتساب'**
  String get waMute;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'انتهت نافذة الـ24 ساعة: أرسل قالباً معتمداً.'**
  String get waErrWindow;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'المحادثة مع موظف آخر.'**
  String get waErrAssigned;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'المحادثة مغلقة. أعد فتحها أولاً.'**
  String get waErrClosed;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'لم يقبل واتساب الرسالة.'**
  String get waErrSend;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'واتساب غير مفعّل على الخادم.'**
  String get waErrOff;

  /// D355: «واتساب» — the official Kabso WhatsApp number (§10.151).
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل العميل'**
  String get waDetails;

  /// D360 (§10.155): the label of a staff member whose WhatsApp level is VIEW — reads, never replies or acts.
  ///
  /// In ar, this message translates to:
  /// **'مشاهدة فقط'**
  String get waViewOnly;

  /// D360 (§10.155): the note in place of the composer for the WhatsApp level VIEW.
  ///
  /// In ar, this message translates to:
  /// **'مستواك في واتساب «مشاهدة فقط»: تقرأ المحادثة وتفاصيل العميل، ولا يمكنك الرد أو اتخاذ إجراء.'**
  String get waViewOnlyHint;

  /// D354 (§10.150): a hero countdown's unit under its number, agreeing with it.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{يوم} =1{يوم} =2{يومان} few{أيام} many{يومًا} other{يوم}}'**
  String eventsUnitDays(int count);

  /// D354 (§10.150): a hero countdown's unit under its number, agreeing with it.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{ساعة} =1{ساعة} =2{ساعتان} few{ساعات} many{ساعة} other{ساعة}}'**
  String eventsUnitHours(int count);

  /// D354 (§10.150): a hero countdown's unit under its number, agreeing with it.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{دقيقة} =1{دقيقة} =2{دقيقتان} few{دقائق} many{دقيقة} other{دقيقة}}'**
  String eventsUnitMinutes(int count);

  /// D354 (§10.150): a hero countdown's unit under its number, agreeing with it.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{ثانية} =1{ثانية} =2{ثانيتان} few{ثوانٍ} many{ثانية} other{ثانية}}'**
  String eventsUnitSeconds(int count);

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get eventsTabRanking;

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'الجوائز'**
  String get eventsTabRewards;

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'دائم'**
  String get eventsRewardPermanent;

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'معاينة'**
  String get eventsRewardPreview;

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'الجائزة الكبرى'**
  String get eventsRewardFeatured;

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'المركز متاح'**
  String get eventsSeatOpen;

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'باقي {points} للمركز {rank}'**
  String eventsToPrevRank(String points, String rank);

  /// D354 (§10.150): the designed event page.
  ///
  /// In ar, this message translates to:
  /// **'الساعة الأخيرة'**
  String get eventsLastHour;

  /// D354 (§10.150): a reward's duration.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} many{{days} يوماً} other{{days} يوم}}'**
  String eventsRewardDays(int days);

  /// D354 (§10.150): the days left in the stage layout's small countdown.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =0{0 يوم} =1{يوم} =2{يومان} few{{days} أيام} many{{days} يومًا} other{{days} يوم}}'**
  String eventsDaysShort(int days);

  /// D354 (§10.150): a permanent event's small countdown.
  ///
  /// In ar, this message translates to:
  /// **'بلا نهاية'**
  String get eventsNoEnd;

  /// D354 (§10.150): the milestones section «المراحل» (D325).
  ///
  /// In ar, this message translates to:
  /// **'المراحل'**
  String get eventsMilestonesTitle;

  /// D354 (§10.150): a milestone's points threshold.
  ///
  /// In ar, this message translates to:
  /// **'عند {points} نقطة'**
  String eventsMilestoneAt(String points);

  /// D356 (§10.152): the label on the panel's live preview of the event page (Flutter web only, never in the app): the leaderboard rows are sample data.
  ///
  /// In ar, this message translates to:
  /// **'معاينة · بيانات المتصدرين تجريبية'**
  String get eventPreviewSampleLabel;

  /// D362: the tiny type tag beside the animated glyph on a live card: an AUDIO room. The owner's short English tag, deliberately the same in Arabic and English (his file: short English tag next to the small icon); screen readers hear the full Arabic type name instead.
  ///
  /// In ar, this message translates to:
  /// **'Voice'**
  String get liveTypeTagVoice;

  /// D362: the tiny type tag beside the animated glyph on a live card: a SOLO camera live. The owner's short English tag, deliberately the same in Arabic and English (his file: short English tag next to the small icon); screen readers hear the full Arabic type name instead.
  ///
  /// In ar, this message translates to:
  /// **'Live Cam'**
  String get liveTypeTagCam;

  /// D362: the tiny type tag beside the animated glyph on a live card: a PODCAST. The owner's short English tag, deliberately the same in Arabic and English (his file: short English tag next to the small icon); screen readers hear the full Arabic type name instead.
  ///
  /// In ar, this message translates to:
  /// **'Podcast'**
  String get liveTypeTagPodcast;

  /// D362: the tiny type tag beside the animated glyph on a live card: a STREAMER live. The owner's short English tag, deliberately the same in Arabic and English (his file: short English tag next to the small icon); screen readers hear the full Arabic type name instead.
  ///
  /// In ar, this message translates to:
  /// **'Streamer'**
  String get liveTypeTagStreamer;

  /// D363: the podcast setup's «صوت / فيديو» row label.
  ///
  /// In ar, this message translates to:
  /// **'نوع الحلقة'**
  String get podcastFormat;

  /// D363: the audio choice of the podcast format (today's podcast, the default).
  ///
  /// In ar, this message translates to:
  /// **'صوت'**
  String get podcastFormatAudio;

  /// D363: the video choice of the podcast format (host and guests on camera, the automatic director).
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get podcastFormatVideo;

  /// D363: the small badge on a video podcast's hub card and announced-episode card.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get podcastVideoBadge;

  /// D363: the shot chip — the current speaker full screen.
  ///
  /// In ar, this message translates to:
  /// **'لقطة المتحدث'**
  String get podcastShotSpeaker;

  /// D363: the shot chip — two people alternating, top / bottom.
  ///
  /// In ar, this message translates to:
  /// **'نقاش'**
  String get podcastShotSplit;

  /// D363: the shot chip — three or more speaking at once (everyone).
  ///
  /// In ar, this message translates to:
  /// **'نقاش جماعي'**
  String get podcastShotGrid;

  /// D363: the hot seat — the shot chip, the host's button on a question and the question card's tag.
  ///
  /// In ar, this message translates to:
  /// **'الكرسي الساخن'**
  String get podcastShotHotSeat;

  /// D363: the chip a viewer taps to leave their own pick and follow the automatic director again.
  ///
  /// In ar, this message translates to:
  /// **'رجوع للمخرج'**
  String get podcastBackToDirector;

  /// D363: the lower third when a guest appears; title = the short title the host gave.
  ///
  /// In ar, this message translates to:
  /// **'الضيف: {name} — {title}'**
  String podcastGuestLowerThird(String name, String title);

  /// D363: the lower third of a guest without a title.
  ///
  /// In ar, this message translates to:
  /// **'الضيف: {name}'**
  String podcastGuestLowerThirdName(String name);

  /// D363: the field for the guest's short title when the host invites in a video podcast.
  ///
  /// In ar, this message translates to:
  /// **'لقب الضيف (اختياري)'**
  String get podcastGuestTitleHint;

  /// D363: the questions list of a video podcast, most votes first.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة المستمعين'**
  String get podcastQuestionsTitle;

  /// D363: a listener's upvote button on a question (screen-reader label).
  ///
  /// In ar, this message translates to:
  /// **'صوّت للسؤال'**
  String get podcastVote;

  /// D363: taking back an upvote (screen-reader label).
  ///
  /// In ar, this message translates to:
  /// **'ألغِ التصويت'**
  String get podcastUnvote;

  /// D363: a question's upvotes (screen readers; the card shows the digits).
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أصوات} =1{صوت واحد} =2{صوتان} few{{count} أصوات} many{{count} صوتاً} other{{count} صوت}}'**
  String podcastVotes(int count);

  /// D363: the questions list is empty.
  ///
  /// In ar, this message translates to:
  /// **'لا أسئلة بعد.'**
  String get podcastNoQuestions;

  /// D363: the host's controls row for the automatic director.
  ///
  /// In ar, this message translates to:
  /// **'المخرج'**
  String get podcastDirector;

  /// D363: the director chooses the shot (no pinned guest).
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get podcastDirectorAuto;

  /// D363: the host pins the shot on one person.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت اللقطة على {name}'**
  String podcastDirectorPinned(String name);

  /// D363: the hot seat card's asker line.
  ///
  /// In ar, this message translates to:
  /// **'سؤال من {name}'**
  String podcastHotSeatFrom(String name);

  /// D363 scope extension: the host's strip of accepted guests waiting backstage (seen by the host only).
  ///
  /// In ar, this message translates to:
  /// **'خلف الكواليس'**
  String get podcastBackstage;

  /// D363 scope extension: the host's button that brings a backstage guest on air.
  ///
  /// In ar, this message translates to:
  /// **'على الهواء'**
  String get podcastBringOnAir;

  /// D363 scope extension: the guest's self-check screen title.
  ///
  /// In ar, this message translates to:
  /// **'أنت خلف الكواليس'**
  String get podcastBackstageCheckTitle;

  /// D363 scope extension: the guest's self-check explanation.
  ///
  /// In ar, this message translates to:
  /// **'المضيف وحده يراك ويسمعك الآن. تأكد من الكاميرا والميكروفون، وسيُدخلك على الهواء.'**
  String get podcastBackstageCheckBody;

  /// D363 scope extension: the self-check while the guest's voice is heard.
  ///
  /// In ar, this message translates to:
  /// **'الميكروفون يعمل'**
  String get podcastBackstageMicOk;

  /// D363 scope extension: the self-check while the guest is silent.
  ///
  /// In ar, this message translates to:
  /// **'تكلّم لاختبار الميكروفون'**
  String get podcastBackstageMicQuiet;

  /// D363 scope extension: the self-check when the guest's camera is off.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا مغلقة'**
  String get podcastBackstageCameraOff;

  /// D363 scope extension: the guest leaves backstage without going on air (back to the audience).
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الكواليس'**
  String get podcastBackstageLeave;

  /// D363 scope extension: the chip while the host keeps the shot on one person.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت: {name}'**
  String podcastControlPinned(String name);

  /// D363 scope extension: the chip while the host keeps a layout; layout = the shot's name.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط ثابت: {layout}'**
  String podcastControlLayout(String layout);

  /// D363 scope extension: the director sheet's layout section (keep a layout).
  ///
  /// In ar, this message translates to:
  /// **'التخطيط'**
  String get podcastDirectorLayout;

  /// D363 scope extension: the director sheet's people section.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت شخص'**
  String get podcastDirectorPeople;

  /// D363 scope extension: the episode's agenda — the setup row, the host's tool and the editor's title.
  ///
  /// In ar, this message translates to:
  /// **'فقرات الحلقة'**
  String get podcastSegments;

  /// D363 scope extension: how many segments are prepared.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا فقرات} =1{فقرة واحدة} =2{فقرتان} few{{count} فقرات} many{{count} فقرة} other{{count} فقرة}}'**
  String podcastSegmentsCount(int count);

  /// D363 scope extension: the segment card and the progress bar's label.
  ///
  /// In ar, this message translates to:
  /// **'الفقرة {current} من {total}'**
  String podcastSegmentOf(int current, int total);

  /// D363 scope extension: the host's control that moves to the next segment (after the last: the closing card).
  ///
  /// In ar, this message translates to:
  /// **'الفقرة التالية'**
  String get podcastSegmentNext;

  /// D363 scope extension: the host's control before the first segment.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الفقرات'**
  String get podcastSegmentStart;

  /// D363 scope extension: the editor's add button.
  ///
  /// In ar, this message translates to:
  /// **'إضافة فقرة'**
  String get podcastSegmentAdd;

  /// D363 scope extension: the editor's remove button (screen readers).
  ///
  /// In ar, this message translates to:
  /// **'حذف الفقرة'**
  String get podcastSegmentRemove;

  /// D363 scope extension: the editor's title field (1–40 characters).
  ///
  /// In ar, this message translates to:
  /// **'عنوان الفقرة'**
  String get podcastSegmentTitleHint;

  /// D363 scope extension: the editor's optional planned minutes field.
  ///
  /// In ar, this message translates to:
  /// **'دقائق'**
  String get podcastSegmentMinutesHint;

  /// D363 scope extension: the editor's save button.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الفقرات'**
  String get podcastSegmentsSave;

  /// D363 scope extension: the closing card after the last segment.
  ///
  /// In ar, this message translates to:
  /// **'نهاية الحلقة'**
  String get podcastClosingTitle;

  /// D363 scope extension: the closing card's line.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لمتابعتكم'**
  String get podcastClosingBody;

  /// D363 scope extension: the host's button on a hand's question (the question card over the video).
  ///
  /// In ar, this message translates to:
  /// **'اعرض على الشاشة'**
  String get podcastShowOnScreen;

  /// D363 scope extension: the question card's tag over the video.
  ///
  /// In ar, this message translates to:
  /// **'سؤال الجمهور'**
  String get podcastOnScreenTag;

  /// D363 scope extension: the host's dismiss button on the question card.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء السؤال'**
  String get podcastOnScreenHide;

  /// D365: under a staff message WhatsApp did not deliver (never Meta's English text).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الإرسال'**
  String get waFailed;

  /// D365: the tooltip of the failed-send line (tap to read the reason).
  ///
  /// In ar, this message translates to:
  /// **'سبب التعذّر'**
  String get waFailDetails;

  /// D365: Meta 131026, in words.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل إلى الرقم: قد لا يستخدم واتساب أو لم يوافق على شروطه.'**
  String get waFailUndeliverable;

  /// D365: Meta's rate limits (130429, 131056, 80007, 4), in words.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت رسائل كثيرة في وقت قصير: حاول بعد قليل.'**
  String get waFailRate;

  /// D365: Meta 131051, in words.
  ///
  /// In ar, this message translates to:
  /// **'واتساب لا يقبل هذا النوع من الرسائل لهذا الرقم.'**
  String get waFailUnsupported;

  /// D365: sends a failed text again (a new message).
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get waRetry;

  /// D365: the chat's day separator for yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get waYesterday;

  /// D365: the chat's window chip, more than an hour left.
  ///
  /// In ar, this message translates to:
  /// **'نافذة الرد: {hours} س متبقية'**
  String waWindowLeftHours(int hours);

  /// D365: the chat's window chip, under an hour left.
  ///
  /// In ar, this message translates to:
  /// **'نافذة الرد: {minutes} د متبقية'**
  String waWindowLeftMinutes(int minutes);

  /// D365: the chat's window chip outside the 24-hour window.
  ///
  /// In ar, this message translates to:
  /// **'مغلقة — قالب فقط'**
  String get waWindowClosedChip;

  /// D365: the tooltip of the chat's actions menu.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات المحادثة'**
  String get waMenu;

  /// D365: the attach sheet's photo item.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get waAttachPhoto;

  /// D366: the WhatsApp department PAYMENTS.
  ///
  /// In ar, this message translates to:
  /// **'الشحن والمدفوعات'**
  String get waDeptPAYMENTS;

  /// D366: the WhatsApp department AGENCIES.
  ///
  /// In ar, this message translates to:
  /// **'الوكالات والمضيفون'**
  String get waDeptAGENCIES;

  /// D366: the WhatsApp department TECHNICAL.
  ///
  /// In ar, this message translates to:
  /// **'المشاكل التقنية'**
  String get waDeptTECHNICAL;

  /// D366: the WhatsApp department REPORTS.
  ///
  /// In ar, this message translates to:
  /// **'البلاغات والحظر'**
  String get waDeptREPORTS;

  /// D366: the WhatsApp department GENERAL (the default).
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get waDeptGENERAL;

  /// D366: the inbox's department filter, no department chosen.
  ///
  /// In ar, this message translates to:
  /// **'كل الأقسام'**
  String get waDeptAll;

  /// D366: the semantics of a department chip.
  ///
  /// In ar, this message translates to:
  /// **'القسم: {department}'**
  String waDeptLabel(String department);

  /// D366: the transfer sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'تحويل المحادثة'**
  String get waTransferTitle;

  /// D366: the transfer sheet's department section.
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get waTransferDepartment;

  /// D366: the transfer sheet's target section.
  ///
  /// In ar, this message translates to:
  /// **'إلى من'**
  String get waTransferWho;

  /// D366: route to the department's first available agent.
  ///
  /// In ar, this message translates to:
  /// **'أول متاح في القسم'**
  String get waTransferFirst;

  /// D366: what «أول متاح في القسم» does.
  ///
  /// In ar, this message translates to:
  /// **'أقل موظف مناوب انشغالاً، أو قائمة القسم إن لم يكن أحد مناوباً'**
  String get waTransferFirstHint;

  /// D366: a department with no agent.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موظفون في هذا القسم بعد.'**
  String get waTransferNoAgents;

  /// D366: the transfer sheet's note field.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة داخلية (اختياري)'**
  String get waTransferNote;

  /// D366: the note field's helper text.
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ مع التحويل ولا تُرسل للعميل أبداً'**
  String get waTransferNoteHint;

  /// D366: the transfer sheet's confirm button.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get waTransferConfirm;

  /// D366: the toast after a transfer to a person.
  ///
  /// In ar, this message translates to:
  /// **'حُوّلت المحادثة إلى {name}'**
  String waTransferDoneTo(String name);

  /// D366: the toast after a transfer to the department queue.
  ///
  /// In ar, this message translates to:
  /// **'حُوّلت المحادثة إلى قائمة {department}'**
  String waTransferDoneQueue(String department);

  /// D366: an agent's open assigned conversations.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا محادثات مفتوحة} =1{محادثة مفتوحة} =2{محادثتان مفتوحتان} few{{count} محادثات مفتوحة} many{{count} محادثة مفتوحة} other{{count} محادثة مفتوحة}}'**
  String waAgentOpen(int count);

  /// D366: the on-shift dot's label.
  ///
  /// In ar, this message translates to:
  /// **'مناوب'**
  String get waOnShift;

  /// D366: the off-shift dot's label.
  ///
  /// In ar, this message translates to:
  /// **'خارج المناوبة'**
  String get waOffShift;

  /// D366: the chat strip when the conversation waits in a department queue.
  ///
  /// In ar, this message translates to:
  /// **'قائمة {department}'**
  String waQueueOf(String department);

  /// D370 «نقاط الشحن»: the VIP page's second way to pay (recharge points).
  ///
  /// In ar, this message translates to:
  /// **'استبدل بالنقاط'**
  String get vipPayPoints;

  /// D370 «نقاط الشحن»: the VIP purchase panel's pay-method switch (semantics label).
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get vipPayWith;

  /// D370 «نقاط الشحن»: a points amount (grouped Western digits).
  ///
  /// In ar, this message translates to:
  /// **'{points} نقطة'**
  String vipPoints(String points);

  /// D370 «نقاط الشحن»: the VIP purchase panel's points balance line.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك: {points} نقطة'**
  String vipPointsBalance(String points);

  /// D370 «نقاط الشحن»: the VIP button when the points do not cover the price.
  ///
  /// In ar, this message translates to:
  /// **'نقاط غير كافية'**
  String get vipPointsShort;

  /// D370 «نقاط الشحن»: the VIP purchase panel's hint under the points balance.
  ///
  /// In ar, this message translates to:
  /// **'كل عملة تشحنها = نقطة شحن'**
  String get vipPointsHint;

  /// D370 «نقاط الشحن»: the VIP confirm card's points balance line.
  ///
  /// In ar, this message translates to:
  /// **'نقاطك'**
  String get vipConfirmPoints;

  /// D370 «نقاط الشحن»: the VIP confirm card's primary button (points).
  ///
  /// In ar, this message translates to:
  /// **'استبدل {points} نقطة'**
  String vipRedeem(String points);

  /// D370 «نقاط الشحن»: VIP_UNAVAILABLE no_points_price.
  ///
  /// In ar, this message translates to:
  /// **'هذا المستوى لا يُستبدل بالنقاط.'**
  String get vipErrorNoPointsPrice;

  /// D370 «نقاط الشحن»: the snack after a points purchase.
  ///
  /// In ar, this message translates to:
  /// **'تم استبدال النقاط: {tier} حتى {date}'**
  String vipRedeemDone(String tier, String date);

  /// D370 «نقاط الشحن»: INSUFFICIENT_RECHARGE_POINTS.
  ///
  /// In ar, this message translates to:
  /// **'نقاط الشحن لا تكفي لهذا المستوى.'**
  String get errorInsufficientRechargePoints;

  /// D370 «نقاط الشحن»: the wallet row and the history page title.
  ///
  /// In ar, this message translates to:
  /// **'نقاط الشحن'**
  String get rechargePointsTitle;

  /// D370 «نقاط الشحن»: the wallet row's subtitle.
  ///
  /// In ar, this message translates to:
  /// **'{points} نقطة · استبدلها بـ VIP'**
  String rechargePointsRowHint(String points);

  /// D370 «نقاط الشحن»: the history page's balance card.
  ///
  /// In ar, this message translates to:
  /// **'رصيد النقاط'**
  String get rechargePointsBalanceLabel;

  /// D370 «نقاط الشحن»: the history page's explanation.
  ///
  /// In ar, this message translates to:
  /// **'كل عملة تشحنها من الموقع أو المتجر أو من وكيل شحن = نقطة واحدة. النقاط لا تنتهي وتُستبدل بـ VIP.'**
  String get rechargePointsHowTo;

  /// D370 «نقاط الشحن»: the history page's empty state.
  ///
  /// In ar, this message translates to:
  /// **'لا نقاط بعد'**
  String get rechargePointsEmpty;

  /// D370 «نقاط الشحن»: the history page's empty state body.
  ///
  /// In ar, this message translates to:
  /// **'اشحن العملات لتجمع النقاط.'**
  String get rechargePointsEmptyBody;

  /// D370 «نقاط الشحن»: the history page's error.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل نقاط الشحن'**
  String get rechargePointsLoadError;

  /// D370 «نقاط الشحن»: a history row's balance after.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعدها: {points}'**
  String rechargePointsAfter(String points);

  /// D370 «نقاط الشحن»: a points history reason.
  ///
  /// In ar, this message translates to:
  /// **'شحن من الموقع'**
  String get rechargePointsReasonWeb;

  /// D370 «نقاط الشحن»: a points history reason.
  ///
  /// In ar, this message translates to:
  /// **'شحن من المتجر'**
  String get rechargePointsReasonStore;

  /// D370 «نقاط الشحن»: a points history reason.
  ///
  /// In ar, this message translates to:
  /// **'شحن من وكيل'**
  String get rechargePointsReasonAgent;

  /// D370 «نقاط الشحن»: a points history reason.
  ///
  /// In ar, this message translates to:
  /// **'استبدال VIP'**
  String get rechargePointsReasonVip;

  /// D370 «نقاط الشحن»: a points history reason.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع شحن'**
  String get rechargePointsReasonReversal;

  /// D370 «نقاط الشحن»: a points history reason.
  ///
  /// In ar, this message translates to:
  /// **'تعديل من الإدارة'**
  String get rechargePointsReasonAdmin;

  /// D370 «نقاط الشحن»: a points history reason (unknown).
  ///
  /// In ar, this message translates to:
  /// **'تغيير في النقاط'**
  String get rechargePointsReasonOther;

  /// D370 «نقاط الشحن»: the VIP purchase panel's unit and length (points).
  ///
  /// In ar, this message translates to:
  /// **'نقطة / {days} يوماً'**
  String vipPointsPer(String days);

  /// D372 «هدية الدعم»: the comment composer's gift box button (tooltip).
  ///
  /// In ar, this message translates to:
  /// **'هدية الدعم'**
  String get contentGiftButton;

  /// D372: a gift line in the comments (gold), e.g. «سارة أرسل وردة ×10»; {count} is «×10», isolated left to right.
  ///
  /// In ar, this message translates to:
  /// **'{sender} أرسل {gift} {count}'**
  String commentsGiftSent(String sender, String gift, String count);

  /// D372: screen-reader label of the gift counter on a post or reel (the cherries the author earned from gifts on it).
  ///
  /// In ar, this message translates to:
  /// **'كرز الهدايا: {amount}'**
  String contentGiftCherriesLabel(String amount);

  /// D372: CONTENT_GIFT_RECEIVED — someone sent a gift on your post or reel.
  ///
  /// In ar, this message translates to:
  /// **'أرسل لك {who} هدية'**
  String notifContentGiftReceived(String who);

  /// D372: ledger reason CONTENT_GIFT.
  ///
  /// In ar, this message translates to:
  /// **'هدية على منشور'**
  String get walletReasonContentGift;

  /// D372: an earning gift sent on a post or reel.
  ///
  /// In ar, this message translates to:
  /// **'على منشور'**
  String get earnContextContent;

  /// D372: CONTENT_GIFT_RECIPIENT_UNAVAILABLE.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إرسال هدية على هذا المنشور.'**
  String get errorContentGiftRecipientUnavailable;

  /// D376 «الحالة»: the Edit profile row and the picker title.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get statusTitle;

  /// D376: clears the status (picker button and the Edit profile value).
  ///
  /// In ar, this message translates to:
  /// **'بدون حالة'**
  String get statusNone;

  /// D376: the picker subtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر رمزاً يظهر فوق صورتك مثل الفقاعات'**
  String get statusPickerHint;

  /// D376: the picker save button.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get statusSave;

  /// D376: after saving.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الحالة'**
  String get statusSaved;

  /// D376: after «بدون حالة» was saved.
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت الحالة'**
  String get statusCleared;

  /// D376: the Google Noto pack tab.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get statusPackGeneral;

  /// D376: the store pack tab.
  ///
  /// In ar, this message translates to:
  /// **'المميزة'**
  String get statusPackPremium;

  /// D376: under the preview when a locked emoji is selected.
  ///
  /// In ar, this message translates to:
  /// **'معاينة فقط: افتح المتجر لاستخدام رموز المميزة'**
  String get statusLockedHint;

  /// D376: screen reader suffix of a locked emoji.
  ///
  /// In ar, this message translates to:
  /// **'مقفلة'**
  String get statusLockedLabel;

  /// D376: opens «متجر الحالة».
  ///
  /// In ar, this message translates to:
  /// **'افتح المتجر'**
  String get statusOpenStore;

  /// D376: 409 pack_not_owned.
  ///
  /// In ar, this message translates to:
  /// **'هذه الحالة من حزمة المميزة. افتح المتجر لشرائها'**
  String get statusNotOwned;

  /// D376: «متجر الحالة» title.
  ///
  /// In ar, this message translates to:
  /// **'الحالة المميزة'**
  String get statusStoreTitle;

  /// D376: under the store preview.
  ///
  /// In ar, this message translates to:
  /// **'{count} رمزاً متحركاً تظهر فوق صورتك مثل الفقاعات'**
  String statusStoreCount(String count);

  /// D376: the store banner while held.
  ///
  /// In ar, this message translates to:
  /// **'الحزمة مفعّلة حتى {date}'**
  String statusStoreActive(String date);

  /// D376: a price option duration.
  ///
  /// In ar, this message translates to:
  /// **'{days} يوماً'**
  String statusStoreDays(String days);

  /// D376: a price.
  ///
  /// In ar, this message translates to:
  /// **'{price} عملة'**
  String statusStorePrice(String price);

  /// D376: the buy button.
  ///
  /// In ar, this message translates to:
  /// **'شراء · {price}'**
  String statusStoreBuy(String price);

  /// D376: the renew button.
  ///
  /// In ar, this message translates to:
  /// **'تجديد · {price}'**
  String statusStoreRenew(String price);

  /// D376: buy confirmation.
  ///
  /// In ar, this message translates to:
  /// **'شراء الحزمة المميزة: {days} مقابل {price}؟'**
  String statusStoreConfirmBuy(String days, String price);

  /// D376: renew confirmation.
  ///
  /// In ar, this message translates to:
  /// **'تجديد الحزمة المميزة: {days} مقابل {price}؟ تُضاف المدة إلى المدة المتبقية.'**
  String statusStoreConfirmRenew(String days, String price);

  /// D376: the confirm button.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get statusStoreConfirm;

  /// D376: after buying.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل الحزمة المميزة'**
  String get statusStoreBought;

  /// D376: after renewing.
  ///
  /// In ar, this message translates to:
  /// **'تم تجديد الحزمة'**
  String get statusStoreRenewed;

  /// D376: insufficient coins.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك غير كافٍ لهذه الحزمة.'**
  String get statusStoreShort;

  /// D376: opens the wallet.
  ///
  /// In ar, this message translates to:
  /// **'شحن العملات'**
  String get statusStoreRecharge;

  /// D376: the coin balance in the store.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك: {coins}'**
  String statusStoreBalance(String coins);

  /// D376: the store failed to load.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المتجر'**
  String get statusStoreLoadError;

  /// D376: no price.
  ///
  /// In ar, this message translates to:
  /// **'الحزمة غير متاحة للشراء الآن'**
  String get statusStoreNotSold;

  /// D376: after buying, sets the previewed emoji as the status.
  ///
  /// In ar, this message translates to:
  /// **'استخدم الحالة'**
  String get statusStoreUse;

  /// D376: what a screen reader says for a status over a picture.
  ///
  /// In ar, this message translates to:
  /// **'الحالة: {name}'**
  String statusSemantics(String name);

  /// D376: wallet history reason STATUS_PACK_PURCHASE.
  ///
  /// In ar, this message translates to:
  /// **'شراء حزمة الحالة'**
  String get walletReasonStatusPack;

  /// D376: the settings row opening the licenses page.
  ///
  /// In ar, this message translates to:
  /// **'التراخيص'**
  String get settingsLicenses;

  /// D376: the CC BY 4.0 attribution of the Noto animated emoji (required by the licence).
  ///
  /// In ar, this message translates to:
  /// **'الرموز المتحركة من Google ‏(Noto Emoji)، بترخيص CC BY 4.0'**
  String get settingsNotoAttribution;

  /// D376 «الحالة»: the name of the status emoji `noto.happy`.
  ///
  /// In ar, this message translates to:
  /// **'سعيد'**
  String get statusEmojiNotoHappy;

  /// D376 «الحالة»: the name of the status emoji `noto.laugh`.
  ///
  /// In ar, this message translates to:
  /// **'ضحك'**
  String get statusEmojiNotoLaugh;

  /// D376 «الحالة»: the name of the status emoji `noto.love`.
  ///
  /// In ar, this message translates to:
  /// **'حب'**
  String get statusEmojiNotoLove;

  /// D376 «الحالة»: the name of the status emoji `noto.heart_eyes`.
  ///
  /// In ar, this message translates to:
  /// **'معجب'**
  String get statusEmojiNotoHeartEyes;

  /// D376 «الحالة»: the name of the status emoji `noto.cool`.
  ///
  /// In ar, this message translates to:
  /// **'رايق'**
  String get statusEmojiNotoCool;

  /// D376 «الحالة»: the name of the status emoji `noto.star_struck`.
  ///
  /// In ar, this message translates to:
  /// **'منبهر'**
  String get statusEmojiNotoStarStruck;

  /// D376 «الحالة»: the name of the status emoji `noto.party`.
  ///
  /// In ar, this message translates to:
  /// **'احتفال'**
  String get statusEmojiNotoParty;

  /// D376 «الحالة»: the name of the status emoji `noto.innocent`.
  ///
  /// In ar, this message translates to:
  /// **'بريء'**
  String get statusEmojiNotoInnocent;

  /// D376 «الحالة»: the name of the status emoji `noto.wink_tongue`.
  ///
  /// In ar, this message translates to:
  /// **'مشاكس'**
  String get statusEmojiNotoWinkTongue;

  /// D376 «الحالة»: the name of the status emoji `noto.hug`.
  ///
  /// In ar, this message translates to:
  /// **'حضن'**
  String get statusEmojiNotoHug;

  /// D376 «الحالة»: the name of the status emoji `noto.kiss`.
  ///
  /// In ar, this message translates to:
  /// **'بوسة'**
  String get statusEmojiNotoKiss;

  /// D376 «الحالة»: the name of the status emoji `noto.thinking`.
  ///
  /// In ar, this message translates to:
  /// **'أفكر'**
  String get statusEmojiNotoThinking;

  /// D376 «الحالة»: the name of the status emoji `noto.sleepy`.
  ///
  /// In ar, this message translates to:
  /// **'نعسان'**
  String get statusEmojiNotoSleepy;

  /// D376 «الحالة»: the name of the status emoji `noto.eye_roll`.
  ///
  /// In ar, this message translates to:
  /// **'ملل'**
  String get statusEmojiNotoEyeRoll;

  /// D376 «الحالة»: the name of the status emoji `noto.sad`.
  ///
  /// In ar, this message translates to:
  /// **'حزين'**
  String get statusEmojiNotoSad;

  /// D376 «الحالة»: the name of the status emoji `noto.crying`.
  ///
  /// In ar, this message translates to:
  /// **'بكاء'**
  String get statusEmojiNotoCrying;

  /// D376 «الحالة»: the name of the status emoji `noto.angry`.
  ///
  /// In ar, this message translates to:
  /// **'غاضب'**
  String get statusEmojiNotoAngry;

  /// D376 «الحالة»: the name of the status emoji `noto.shocked`.
  ///
  /// In ar, this message translates to:
  /// **'مصدوم'**
  String get statusEmojiNotoShocked;

  /// D376 «الحالة»: the name of the status emoji `noto.heart`.
  ///
  /// In ar, this message translates to:
  /// **'قلب'**
  String get statusEmojiNotoHeart;

  /// D376 «الحالة»: the name of the status emoji `noto.fire`.
  ///
  /// In ar, this message translates to:
  /// **'نار'**
  String get statusEmojiNotoFire;

  /// D376 «الحالة»: the name of the status emoji `noto.hundred`.
  ///
  /// In ar, this message translates to:
  /// **'١٠٠'**
  String get statusEmojiNotoHundred;

  /// D376 «الحالة»: the name of the status emoji `noto.thumbs_up`.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get statusEmojiNotoThumbsUp;

  /// D376 «الحالة»: the name of the status emoji `noto.congrats`.
  ///
  /// In ar, this message translates to:
  /// **'مبروك'**
  String get statusEmojiNotoCongrats;

  /// D376 «الحالة»: the name of the status emoji `noto.thanks`.
  ///
  /// In ar, this message translates to:
  /// **'شكراً'**
  String get statusEmojiNotoThanks;

  /// D376 «الحالة»: the name of the status emoji `premium.bird`.
  ///
  /// In ar, this message translates to:
  /// **'عصفور'**
  String get statusEmojiPremiumBird;

  /// D376 «الحالة»: the name of the status emoji `premium.dove`.
  ///
  /// In ar, this message translates to:
  /// **'حمامة'**
  String get statusEmojiPremiumDove;

  /// D376 «الحالة»: the name of the status emoji `premium.eagle`.
  ///
  /// In ar, this message translates to:
  /// **'نسر'**
  String get statusEmojiPremiumEagle;

  /// D376 «الحالة»: the name of the status emoji `premium.owl`.
  ///
  /// In ar, this message translates to:
  /// **'بومة'**
  String get statusEmojiPremiumOwl;

  /// D376 «الحالة»: the name of the status emoji `premium.flamingo`.
  ///
  /// In ar, this message translates to:
  /// **'فلامنجو'**
  String get statusEmojiPremiumFlamingo;

  /// D376 «الحالة»: the name of the status emoji `premium.peacock`.
  ///
  /// In ar, this message translates to:
  /// **'طاووس'**
  String get statusEmojiPremiumPeacock;

  /// D376 «الحالة»: the name of the status emoji `premium.penguin`.
  ///
  /// In ar, this message translates to:
  /// **'بطريق'**
  String get statusEmojiPremiumPenguin;

  /// D376 «الحالة»: the name of the status emoji `premium.chick`.
  ///
  /// In ar, this message translates to:
  /// **'صوص'**
  String get statusEmojiPremiumChick;

  /// D376 «الحالة»: the name of the status emoji `premium.hatching`.
  ///
  /// In ar, this message translates to:
  /// **'فقس'**
  String get statusEmojiPremiumHatching;

  /// D376 «الحالة»: the name of the status emoji `premium.crown`.
  ///
  /// In ar, this message translates to:
  /// **'تاج'**
  String get statusEmojiPremiumCrown;

  /// D376 «الحالة»: the name of the status emoji `premium.diamond`.
  ///
  /// In ar, this message translates to:
  /// **'ألماس'**
  String get statusEmojiPremiumDiamond;

  /// D376 «الحالة»: the name of the status emoji `premium.rocket`.
  ///
  /// In ar, this message translates to:
  /// **'صاروخ'**
  String get statusEmojiPremiumRocket;

  /// D376 «الحالة»: the name of the status emoji `premium.lion`.
  ///
  /// In ar, this message translates to:
  /// **'أسد'**
  String get statusEmojiPremiumLion;

  /// D376 «الحالة»: the name of the status emoji `premium.rich`.
  ///
  /// In ar, this message translates to:
  /// **'غني'**
  String get statusEmojiPremiumRich;

  /// D376 «الحالة»: the name of the status emoji `premium.trophy`.
  ///
  /// In ar, this message translates to:
  /// **'كأس'**
  String get statusEmojiPremiumTrophy;

  /// D376 «الحالة»: the name of the status emoji `premium.glow_star`.
  ///
  /// In ar, this message translates to:
  /// **'نجمة'**
  String get statusEmojiPremiumGlowStar;

  /// D376 «الحالة»: the name of the status emoji `premium.sparkles`.
  ///
  /// In ar, this message translates to:
  /// **'بريق'**
  String get statusEmojiPremiumSparkles;

  /// D376 «الحالة»: the name of the status emoji `premium.unicorn`.
  ///
  /// In ar, this message translates to:
  /// **'يونيكورن'**
  String get statusEmojiPremiumUnicorn;

  /// D376 «الحالة»: the name of the status emoji `premium.dragon`.
  ///
  /// In ar, this message translates to:
  /// **'تنين'**
  String get statusEmojiPremiumDragon;

  /// D376 «الحالة»: the name of the status emoji `premium.rose`.
  ///
  /// In ar, this message translates to:
  /// **'وردة'**
  String get statusEmojiPremiumRose;

  /// D376 «الحالة»: the name of the status emoji `premium.gift`.
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get statusEmojiPremiumGift;

  /// D376 «الحالة»: the name of the status emoji `premium.fireworks`.
  ///
  /// In ar, this message translates to:
  /// **'ألعاب نارية'**
  String get statusEmojiPremiumFireworks;

  /// D376 «الحالة»: the name of the status emoji `premium.rainbow`.
  ///
  /// In ar, this message translates to:
  /// **'قوس قزح'**
  String get statusEmojiPremiumRainbow;

  /// D376 «الحالة»: the name of the status emoji `premium.sparkling_heart`.
  ///
  /// In ar, this message translates to:
  /// **'قلب لامع'**
  String get statusEmojiPremiumSparklingHeart;

  /// D376 «الحالة»: the name of the status emoji `premium.champagne`.
  ///
  /// In ar, this message translates to:
  /// **'شمبانيا'**
  String get statusEmojiPremiumChampagne;

  /// D376 «الحالة»: the name of the status emoji `premium.cheers`.
  ///
  /// In ar, this message translates to:
  /// **'نخب'**
  String get statusEmojiPremiumCheers;

  /// D376 «الحالة»: the name of the status emoji `premium.devil`.
  ///
  /// In ar, this message translates to:
  /// **'شقي'**
  String get statusEmojiPremiumDevil;

  /// D378 VIP identity perks: vipIdentityEntry
  ///
  /// In ar, this message translates to:
  /// **'هويتي المميزة'**
  String get vipIdentityEntry;

  /// D378 VIP identity perks: vipIdentityTitle
  ///
  /// In ar, this message translates to:
  /// **'هويتي المميزة'**
  String get vipIdentityTitle;

  /// D378 VIP identity perks: vipIdentityNoneTitle
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ميزات هوية في مستواك'**
  String get vipIdentityNoneTitle;

  /// D378 VIP identity perks: vipIdentityNoneMessage
  ///
  /// In ar, this message translates to:
  /// **'التوقيع والآيدي الذهبي واليوزر المميز تأتي مع مستويات VIP التي تشملها.'**
  String get vipIdentityNoneMessage;

  /// D378 VIP identity perks: vipIdentityNotHeld
  ///
  /// In ar, this message translates to:
  /// **'هذه الميزة ليست ضمن عضويتك الآن.'**
  String get vipIdentityNotHeld;

  /// D378 VIP identity perks: vipIdentityNotYourClass
  ///
  /// In ar, this message translates to:
  /// **'هذا خارج فئة مستواك.'**
  String get vipIdentityNotYourClass;

  /// D378 VIP identity perks: vipIdentitySave
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get vipIdentitySave;

  /// D378 VIP identity perks: vipIdentitySaved
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get vipIdentitySaved;

  /// D378 VIP identity perks: vipSignatureTitle
  ///
  /// In ar, this message translates to:
  /// **'التوقيع المتحرك'**
  String get vipSignatureTitle;

  /// D378 VIP identity perks: vipSignatureSubtitle
  ///
  /// In ar, this message translates to:
  /// **'يظهر تحت منشوراتك ورسائلك العامة، حتى {max} حرفاً.'**
  String vipSignatureSubtitle(int max);

  /// D378 VIP identity perks: vipSignatureHint
  ///
  /// In ar, this message translates to:
  /// **'اكتب توقيعك'**
  String get vipSignatureHint;

  /// D378 VIP identity perks: vipSignatureClear
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get vipSignatureClear;

  /// D378 VIP identity perks: vipSignatureCleared
  ///
  /// In ar, this message translates to:
  /// **'أزيل التوقيع'**
  String get vipSignatureCleared;

  /// D378 VIP identity perks: vipSignatureBlocked
  ///
  /// In ar, this message translates to:
  /// **'التوقيع يحتوي كلمة غير مسموحة.'**
  String get vipSignatureBlocked;

  /// D378 VIP identity perks: vipSignatureTooLong
  ///
  /// In ar, this message translates to:
  /// **'التوقيع أطول من {max} حرفاً.'**
  String vipSignatureTooLong(int max);

  /// D378 VIP identity perks: vipSignatureTooShort
  ///
  /// In ar, this message translates to:
  /// **'اكتب التوقيع أولاً.'**
  String get vipSignatureTooShort;

  /// D378 VIP identity perks: vipSignatureInvalid
  ///
  /// In ar, this message translates to:
  /// **'التوقيع سطر واحد بلا رموز مخفية.'**
  String get vipSignatureInvalid;

  /// D378 VIP identity perks: vipSignatureSemantics
  ///
  /// In ar, this message translates to:
  /// **'توقيع: {text}'**
  String vipSignatureSemantics(String text);

  /// D378 VIP identity perks: vipGoldenIdTitle
  ///
  /// In ar, this message translates to:
  /// **'الآيدي الذهبي'**
  String get vipGoldenIdTitle;

  /// D378 VIP identity perks: vipGoldenIdSubtitle
  ///
  /// In ar, this message translates to:
  /// **'اختر رقماً متاحاً من فئة: {cls}'**
  String vipGoldenIdSubtitle(String cls);

  /// D378 VIP identity perks: vipGoldenIdNoClass
  ///
  /// In ar, this message translates to:
  /// **'لم تُحدَّد فئة لهذه الميزة بعد.'**
  String get vipGoldenIdNoClass;

  /// D378 VIP identity perks: vipGoldenIdNoneFree
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أرقام متاحة الآن من فئتك.'**
  String get vipGoldenIdNoneFree;

  /// D378 VIP identity perks: vipGoldenIdPick
  ///
  /// In ar, this message translates to:
  /// **'اختيار {number}'**
  String vipGoldenIdPick(String number);

  /// D378 VIP identity perks: vipGoldenIdTaken
  ///
  /// In ar, this message translates to:
  /// **'هذا الرقم مأخوذ.'**
  String get vipGoldenIdTaken;

  /// D378 VIP identity perks: vipGoldenIdTaken2
  ///
  /// In ar, this message translates to:
  /// **'أصبح {number} آيديك الذهبي'**
  String vipGoldenIdTaken2(String number);

  /// D378 VIP identity perks: vipGoldenIdRelease
  ///
  /// In ar, this message translates to:
  /// **'إرجاع'**
  String get vipGoldenIdRelease;

  /// D378 VIP identity perks: vipGoldenIdReleased
  ///
  /// In ar, this message translates to:
  /// **'أُرجع الرقم'**
  String get vipGoldenIdReleased;

  /// D378 VIP identity perks: vipGoldenIdGrace
  ///
  /// In ar, this message translates to:
  /// **'محفوظ لك بعد انتهاء العضوية؛ جدّد VIP لاستعادته قبل أن يعود للمخزون.'**
  String get vipGoldenIdGrace;

  /// D378 VIP identity perks: vipGoldenIdHint
  ///
  /// In ar, this message translates to:
  /// **'آيدي ذهبي'**
  String get vipGoldenIdHint;

  /// D378 VIP identity perks: vipGoldenClassRepeated
  ///
  /// In ar, this message translates to:
  /// **'رقم مكرر'**
  String get vipGoldenClassRepeated;

  /// D378 VIP identity perks: vipGoldenClassDigits
  ///
  /// In ar, this message translates to:
  /// **'{n} أرقام'**
  String vipGoldenClassDigits(int n);

  /// D378 VIP identity perks: vipPremiumTitle
  ///
  /// In ar, this message translates to:
  /// **'يوزر مميز مجاني'**
  String get vipPremiumTitle;

  /// D378 VIP identity perks: vipPremiumSubtitle
  ///
  /// In ar, this message translates to:
  /// **'اختر يوزراً مميزاً من فئة مستواك أو أقل؛ يبقى لك طوال العضوية.'**
  String get vipPremiumSubtitle;

  /// D378 VIP identity perks: vipPremiumNone
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أسماء متاحة الآن.'**
  String get vipPremiumNone;

  /// D378 VIP identity perks: vipPremiumClaim
  ///
  /// In ar, this message translates to:
  /// **'أخذ {username} مجاناً'**
  String vipPremiumClaim(String username);

  /// D378 VIP identity perks: vipPremiumClaimed
  ///
  /// In ar, this message translates to:
  /// **'أصبح {username} يوزرك'**
  String vipPremiumClaimed(String username);

  /// LIVE_VIP_ONLY (403, v1.132-social, D379): a VIP room «غرفة VIP خاصة».
  ///
  /// In ar, this message translates to:
  /// **'هذه الغرفة لأعضاء VIP من مستواها فما فوق'**
  String get errorLiveVipOnly;

  /// LIVE_PIN_BUSY (409, v1.132-social, D379): one pinned message per room at a time.
  ///
  /// In ar, this message translates to:
  /// **'هناك رسالة مثبتة الآن، حاول بعد قليل'**
  String get errorLivePinBusy;

  /// D379 PINNED_MESSAGE: the long-press action on one's own chat message (VIP holders only).
  ///
  /// In ar, this message translates to:
  /// **'تثبيت'**
  String get liveVipPinAction;

  /// D379 PINNED_MESSAGE: takes the pinned message down (its author, the host, a moderator).
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get liveVipPinRemove;

  /// D379 PINNED_MESSAGE: the pin bar's label above the pinned text. {name}: the author.
  ///
  /// In ar, this message translates to:
  /// **'مثبتة · {name}'**
  String liveVipPinnedBy(String name);

  /// D379 PINNED_MESSAGE: VIP_UNAVAILABLE used_up.
  ///
  /// In ar, this message translates to:
  /// **'استخدمت تثبيتات اليوم'**
  String get liveVipPinUsedUp;

  /// D379 HOST_GREETING: the host-only card when a holder joins. {level}: the VIP level number.
  ///
  /// In ar, this message translates to:
  /// **'VIP {level} دخل البث'**
  String liveVipGreetingTitle(String level);

  /// D379 HOST_GREETING: the one-tap greeting button.
  ///
  /// In ar, this message translates to:
  /// **'رحّب'**
  String get liveVipGreetingAction;

  /// D379 HOST_GREETING: the chat line the host sends with one tap. {name}: the joiner's username.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً وسهلاً بـ @{name} 👑'**
  String liveVipGreetingLine(String name);

  /// D379 VIP_ROOM: the lock sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'غرفة VIP خاصة'**
  String get liveVipLockTitle;

  /// D379 VIP_ROOM: the lock sheet (LIVE_VIP_ONLY). {tier}: the tier's name.
  ///
  /// In ar, this message translates to:
  /// **'هذه الغرفة لأعضاء {tier} فما فوق'**
  String liveVipLockBody(String tier);

  /// D379 VIP_ROOM: the lock sheet's button to the VIP page.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في VIP'**
  String get liveVipLockGetVip;

  /// D379 VIP_ROOM: closes the lock sheet.
  ///
  /// In ar, this message translates to:
  /// **'حسناً'**
  String get liveVipLockClose;

  /// D379 VIP_ROOM: the audio go-live setup switch (holders only).
  ///
  /// In ar, this message translates to:
  /// **'غرفة VIP'**
  String get liveVipRoomToggle;

  /// D379 VIP_ROOM: the go-live setup hint under the switch.
  ///
  /// In ar, this message translates to:
  /// **'يدخلها أعضاء VIP من المستوى الذي تختاره فما فوق'**
  String get liveVipRoomHint;

  /// D379 SEAT_RESERVE: the host's empty-seat action (holders, audio rooms).
  ///
  /// In ar, this message translates to:
  /// **'احجز لصديق'**
  String get liveVipReserveAction;

  /// D379 SEAT_RESERVE: the sheet's title.
  ///
  /// In ar, this message translates to:
  /// **'قفل المقعد لصديق'**
  String get liveVipReserveTitle;

  /// D379 SEAT_RESERVE: the username field.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get liveVipReserveHint;

  /// D379 SEAT_RESERVE: confirms.
  ///
  /// In ar, this message translates to:
  /// **'احجز'**
  String get liveVipReserveConfirm;

  /// D379 SEAT_RESERVE: the kept seat's label. {name}: the person.
  ///
  /// In ar, this message translates to:
  /// **'محجوز لـ {name}'**
  String liveVipReservedFor(String name);

  /// D379 SEAT_RESERVE: the host frees the kept seat.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحجز'**
  String get liveVipReleaseAction;

  /// D380 VIP privacy: the privacy screen's section of the VIP privacy switches
  ///
  /// In ar, this message translates to:
  /// **'امتيازات VIP'**
  String get privacyVipTitle;

  /// D380 VIP privacy: HIDDEN_VISIT switch
  ///
  /// In ar, this message translates to:
  /// **'زيارة خفية'**
  String get privacyVipHiddenVisit;

  /// D380 VIP privacy: HIDDEN_VISIT hint
  ///
  /// In ar, this message translates to:
  /// **'زياراتك للملفات لا تظهر في «من زار ملفي».'**
  String get privacyVipHiddenVisitHint;

  /// D380 VIP privacy: RANKING_ANONYMOUS switch
  ///
  /// In ar, this message translates to:
  /// **'اسم مخفي في التصنيفات'**
  String get privacyVipRankingAnonymous;

  /// D380 VIP privacy: RANKING_ANONYMOUS hint
  ///
  /// In ar, this message translates to:
  /// **'تظهر «مجهول» في قوائم الترتيب والداعمين.'**
  String get privacyVipRankingAnonymousHint;

  /// D380 VIP privacy: KICK_MUTE_SHIELD switch
  ///
  /// In ar, this message translates to:
  /// **'حماية من طرد وكتم المشرف العادي'**
  String get privacyVipKickMuteShield;

  /// D380 VIP privacy: KICK_MUTE_SHIELD hint
  ///
  /// In ar, this message translates to:
  /// **'لا يطردك أو يكتمك مشرف الغرفة؛ يبقى المضيف وفريق كابسو قادرين.'**
  String get privacyVipKickMuteShieldHint;

  /// D380 VIP privacy: VIP_PROTECTED
  ///
  /// In ar, this message translates to:
  /// **'هذا العضو محمي بامتياز VIP؛ يستطيع المضيف أو فريق كابسو فقط.'**
  String get errorVipProtected;

  /// D380 VIP privacy: the stand-in name of an anonymous VIP member
  ///
  /// In ar, this message translates to:
  /// **'مجهول'**
  String get vipAnonymousName;

  /// D380 VIP privacy: the gift panel's ANONYMOUS_GIFT switch
  ///
  /// In ar, this message translates to:
  /// **'إهداء مجهول'**
  String get liveGiftAnonymousToggle;

  /// D380 VIP privacy: the gift panel's ANONYMOUS_GIFT switch while on
  ///
  /// In ar, this message translates to:
  /// **'إهداء مجهول: يظهر اسمك «مجهول»'**
  String get liveGiftAnonymousOn;

  /// D380 VIP privacy: the recipient's anonymous gift sheet title
  ///
  /// In ar, this message translates to:
  /// **'هدية من «مجهول»'**
  String get liveGiftAnonymousFrom;

  /// D380 VIP privacy: the recipient's anonymous gift sheet hint
  ///
  /// In ar, this message translates to:
  /// **'لن يُكشف لك المرسل؛ يبقى اسمه في سجل الفريق.'**
  String get liveGiftAnonymousHint;

  /// D380 VIP privacy: report an anonymous gift's sender
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ عن المرسل'**
  String get liveGiftAnonymousReport;

  /// D380 VIP privacy: refuse the sender's anonymous gifts
  ///
  /// In ar, this message translates to:
  /// **'رفض الهدايا المجهولة من هذا المرسل'**
  String get liveGiftAnonymousRefuse;

  /// D380 VIP privacy: after refusing
  ///
  /// In ar, this message translates to:
  /// **'لن تصلك هدايا مجهولة من هذا المرسل.'**
  String get liveGiftAnonymousRefused;

  /// D380 VIP privacy: after reporting a gift's sender
  ///
  /// In ar, this message translates to:
  /// **'تم الإبلاغ، شكراً لك.'**
  String get liveGiftReported;

  /// D381 EXCLUSIVE_GIFTS: the gift sheet's tab of the exclusive gifts the caller's VIP may send.
  ///
  /// In ar, this message translates to:
  /// **'VIP'**
  String get liveGiftTabVip;

  /// D381 «الخاص بي VIP»: the heading of the perks' current state.
  ///
  /// In ar, this message translates to:
  /// **'ما تمنحك ميزاتك الآن'**
  String get vipNowTitle;

  /// D381 MONTHLY_ROCKETS: the traffic cards granted this month.
  ///
  /// In ar, this message translates to:
  /// **'صواريخ هذا الشهر: {count} × {minutes} دقيقة'**
  String vipNowRockets(String count, String minutes);

  /// D381 MONTHLY_ROCKETS: when the next month's cards come.
  ///
  /// In ar, this message translates to:
  /// **'الدفعة التالية {date}'**
  String vipNowRocketsNext(String date);

  /// D381 FREE_CP_REQUEST.
  ///
  /// In ar, this message translates to:
  /// **'طلبات CP مجانية: {left} من {perMonth} متبقية هذا الشهر'**
  String vipNowFreeCp(String left, String perMonth);

  /// D381 HIGHER_GIFT_QUANTITY.
  ///
  /// In ar, this message translates to:
  /// **'أرسل حتى {count} هدية دفعة واحدة'**
  String vipNowMaxQuantity(String count);

  /// D381 LONGER_VOICE.
  ///
  /// In ar, this message translates to:
  /// **'رسائل صوتية حتى {seconds} ثانية'**
  String vipNowVoice(String seconds);

  /// D381 EXCLUSIVE_GIFTS.
  ///
  /// In ar, this message translates to:
  /// **'{count} هدايا حصرية في تبويب VIP'**
  String vipNowExclusive(String count);

  /// D381 PRIORITY_SUPPORT.
  ///
  /// In ar, this message translates to:
  /// **'دعم بأولوية — بلاغاتك ومحادثات الدعم أولاً'**
  String get vipNowPriority;

  /// D381 SCHEDULED_GIFT: the «الخاص بي VIP» row and the page title.
  ///
  /// In ar, this message translates to:
  /// **'هدية مؤجلة'**
  String get vipScheduledEntry;

  /// D381 SCHEDULED_GIFT: pending count.
  ///
  /// In ar, this message translates to:
  /// **'{pending} من {max} بانتظار الإرسال'**
  String vipScheduledEntrySub(String pending, String max);

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'لا هدايا مؤجلة'**
  String get vipScheduledEmptyTitle;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'اختر هدية وموعداً، وتصل في وقتها إلى المحادثة.'**
  String get vipScheduledEmptyBody;

  /// D381: the new scheduled gift button and sheet title.
  ///
  /// In ar, this message translates to:
  /// **'جدولة هدية'**
  String get vipScheduledNew;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'إلى (اسم المستخدم)'**
  String get vipScheduledTo;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'الهدية'**
  String get vipScheduledGift;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get vipScheduledQuantity;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get vipScheduledWhen;

  /// D381: the hold notice.
  ///
  /// In ar, this message translates to:
  /// **'تُحجز {coins} الآن وتُرجع إن أُلغيت أو تعذّر الإرسال.'**
  String vipScheduledHold(String coins);

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'جدولة'**
  String get vipScheduledSubmit;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'جُدولت الهدية'**
  String get vipScheduledDone;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الهدية'**
  String get vipScheduledCancel;

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت الهدية وأُرجعت العملات'**
  String get vipScheduledCancelled;

  /// D381 status.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الإرسال'**
  String get vipScheduledStatusPending;

  /// D381 status.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت'**
  String get vipScheduledStatusDelivered;

  /// D381 status.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت'**
  String get vipScheduledStatusCancelled;

  /// D381 status.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الإرسال — أُرجعت العملات'**
  String get vipScheduledStatusFailed;

  /// D381: a scheduled gift row.
  ///
  /// In ar, this message translates to:
  /// **'{quantity} × {gift} إلى {name}'**
  String vipScheduledLine(String quantity, String gift, String name);

  /// D381: the delivery time.
  ///
  /// In ar, this message translates to:
  /// **'{date}'**
  String vipScheduledAt(String date);

  /// D381.
  ///
  /// In ar, this message translates to:
  /// **'الهدية المؤجلة من ميزات VIP'**
  String get vipScheduledNoPerkTitle;

  /// D381: 409 too_many.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى الحد الأقصى من الهدايا المنتظرة'**
  String get vipScheduledTooMany;

  /// D381: 400 deliverAt.
  ///
  /// In ar, this message translates to:
  /// **'اختر موعداً بعد 5 دقائق على الأقل وخلال سنة'**
  String get vipScheduledBadTime;

  /// D381 FREE_CP_REQUEST: the confirmation body of a free request.
  ///
  /// In ar, this message translates to:
  /// **'مجاني بميزة VIP — {left} طلبات مجانية متبقية هذا الشهر. لا تُرجع العملات لأنه لا يُخصم شيء.'**
  String cpSendBodyFree(String left);

  /// D381 ledger VIP_SCHEDULED_GIFT.
  ///
  /// In ar, this message translates to:
  /// **'هدية مؤجلة (محجوزة)'**
  String get walletReasonVipScheduledGift;

  /// D381 ledger VIP_SCHEDULED_GIFT_RELEASE.
  ///
  /// In ar, this message translates to:
  /// **'هدية مؤجلة (أُرجعت)'**
  String get walletReasonVipScheduledGiftRelease;

  /// D381: a scheduled gift's time and status.
  ///
  /// In ar, this message translates to:
  /// **'{when} · {status}'**
  String vipScheduledMeta(String when, String status);

  /// D381: a gift in the form's list with its price.
  ///
  /// In ar, this message translates to:
  /// **'{name} · {coins}'**
  String vipScheduledGiftOption(String name, String coins);

  /// D384 «صورة متحركة» (the VIP animated picture): the entry in «الخاص بي VIP» and the screen title.
  ///
  /// In ar, this message translates to:
  /// **'صورة متحركة'**
  String get vipAnimatedAvatarEntry;

  /// D384 «صورة متحركة» (the VIP animated picture): the screen's explanation.
  ///
  /// In ar, this message translates to:
  /// **'سجّل 3 ثوانٍ لوجهك أو اختر مقطعاً من المعرض: نزيل الخلفية على هاتفك، وتظهر صورتك متحركة فوق اسمك في بطاقتك داخل الغرف.'**
  String get vipAnimatedAvatarIntro;

  /// D384 «صورة متحركة» (the VIP animated picture): the stage with no clip.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صورة متحركة بعد'**
  String get vipAnimatedAvatarEmpty;

  /// D384 «صورة متحركة» (the VIP animated picture): the record button.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل'**
  String get vipAnimatedAvatarRecord;

  /// D384 «صورة متحركة» (the VIP animated picture): record again after a preview.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسجيل'**
  String get vipAnimatedAvatarRerecord;

  /// D384 «صورة متحركة» (the VIP animated picture): save the previewed cut-out.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get vipAnimatedAvatarSave;

  /// D384 «صورة متحركة» (the VIP animated picture): remove the saved clip.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get vipAnimatedAvatarRemove;

  /// D384 «صورة متحركة» (the VIP animated picture): shown over the camera while recording.
  ///
  /// In ar, this message translates to:
  /// **'انظر إلى الكاميرا وابتسم'**
  String get vipAnimatedAvatarLook;

  /// D384 «صورة متحركة» (the VIP animated picture): while recording.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التسجيل…'**
  String get vipAnimatedAvatarRecording;

  /// D384 «صورة متحركة» (the VIP animated picture): while the phone removes the background.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إزالة الخلفية…'**
  String get vipAnimatedAvatarProcessing;

  /// D384 «صورة متحركة» (the VIP animated picture): above the previewed cut-out.
  ///
  /// In ar, this message translates to:
  /// **'هكذا ستظهر في بطاقتك'**
  String get vipAnimatedAvatarPreview;

  /// D384 «صورة متحركة» (the VIP animated picture): no person found in most frames.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد وجهك في المقطع. سجّل مجدداً في إضاءة جيدة وانظر إلى الكاميرا.'**
  String get vipAnimatedAvatarNoPerson;

  /// D384 «صورة متحركة» (the VIP animated picture): the camera is unavailable or not allowed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الكاميرا. اسمح للتطبيق باستخدام الكاميرا ثم حاول مجدداً.'**
  String get vipAnimatedAvatarCameraError;

  /// D384 «صورة متحركة» (the VIP animated picture): the strip is over the upload limit.
  ///
  /// In ar, this message translates to:
  /// **'المقطع كبير جداً. سجّل مقطعاً أقصر.'**
  String get vipAnimatedAvatarTooLarge;

  /// D384 «صورة متحركة» (the VIP animated picture): after saving.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت صورتك المتحركة'**
  String get vipAnimatedAvatarSaved;

  /// D384 «صورة متحركة» (the VIP animated picture): after removing.
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت صورتك المتحركة'**
  String get vipAnimatedAvatarRemoved;

  /// D384 «صورة متحركة» (the VIP animated picture): the ANIMATED_AVATAR_REMOVED notification.
  ///
  /// In ar, this message translates to:
  /// **'أزال فريق الإشراف صورتك المتحركة لمخالفتها الإرشادات'**
  String get notifAnimatedAvatarRemoved;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: pick a video from the gallery.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من المعرض'**
  String get vipAnimatedAvatarPick;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: the picked video cannot be read.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قراءة هذا المقطع. اختر مقطعاً آخر.'**
  String get vipAnimatedAvatarPickError;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: above the trim slider.
  ///
  /// In ar, this message translates to:
  /// **'اختر 3 ثوانٍ من المقطع'**
  String get vipAnimatedAvatarTrimTitle;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: under the trim range.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الشريط لاختيار بداية الجزء'**
  String get vipAnimatedAvatarTrimHint;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: a short video is kept whole.
  ///
  /// In ar, this message translates to:
  /// **'المقطع 3 ثوانٍ أو أقل: سيُستخدم كاملاً'**
  String get vipAnimatedAvatarTrimWhole;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: use the chosen 3 seconds.
  ///
  /// In ar, this message translates to:
  /// **'استخدام هذا الجزء'**
  String get vipAnimatedAvatarTrimUse;

  /// D384 «صورة متحركة» (the VIP animated picture), gallery picking: leave the trim without using it.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get vipAnimatedAvatarTrimCancel;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'دعم كابسو'**
  String get supportChatName;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'فريق كابسو يرد عليك هنا'**
  String get supportChatSubtitle;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'دعم كابسو، ردود غير مقروءة: {count}'**
  String supportUnread(int count);

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'اكتب لنا ما تحتاجه: الشحن، الوكالات، مشكلة تقنية أو بلاغ. اختر الموضوع ثم أرسل رسالتك، وسيرد عليك فريق كابسو هنا.'**
  String get supportIntro;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'اختر موضوع رسالتك'**
  String get supportPickTopic;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'أُغلق طلبك السابق — اختر موضوع طلبك الجديد'**
  String get supportNewTicket;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'اختر الموضوع أولاً'**
  String get supportPickTopicFirst;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'الموضوع: {topic}'**
  String supportTopicOf(String topic);

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك لفريق كابسو'**
  String get supportComposerHint;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'تم الاستلام'**
  String get supportReceiptReceived;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'تمت القراءة'**
  String get supportReceiptRead;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'تثبيت في الأعلى'**
  String get dmPin;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get dmUnpin;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'ثُبّتت المحادثة في الأعلى'**
  String get dmPinnedDone;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'أُلغي التثبيت'**
  String get dmUnpinned;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تثبيت {max} محادثات فقط. ألغِ تثبيت واحدة أولاً.'**
  String dmPinLimit(int max);

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'متصل الآن'**
  String get dmPinOnline;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'مثبّتة'**
  String get dmPinnedLabel;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'خيارات التثبيت'**
  String get dmPinActions;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تثبيت ٥ محادثات فقط. ألغِ تثبيت واحدة أولاً.'**
  String get errorDmPinLimit;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'داخل التطبيق'**
  String get waInApp;

  /// D385: «دعم كابسو» (the in-app support chat) and the pinned chats at the top of «الرسائل» (CONVENTIONS §10.174).
  ///
  /// In ar, this message translates to:
  /// **'محادثة «دعم كابسو» من داخل التطبيق — بلا نافذة ٢٤ ساعة وبلا قوالب؛ الرد نص أو صورة.'**
  String get waInAppHint;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'قارئ قرآن'**
  String get categoryQuranReciter;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'راوٍ'**
  String get categoryStoryteller;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'كاتب'**
  String get categoryWriter;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'صحفي'**
  String get categoryJournalist;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'مصوّر'**
  String get categoryPhotographer;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'ممثل'**
  String get categoryActor;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'كوميدي'**
  String get categoryComedian;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'خطّاط'**
  String get categoryCalligrapher;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'مصمّم'**
  String get categoryDesigner;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'طاهٍ'**
  String get categoryChef;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'معلّم / مدرّب'**
  String get categoryTeacher;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'دي جي'**
  String get categoryDj;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'رحّالة'**
  String get categoryTraveler;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'الموسيقى'**
  String get categoryFamilyMusic;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'التلاوة والرواية'**
  String get categoryFamilyReciter;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'الكلمة'**
  String get categoryFamilyWord;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'الفنون البصرية'**
  String get categoryFamilyVisual;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'الأداء والمحتوى'**
  String get categoryFamilyPerformer;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'الرياضة والألعاب'**
  String get categoryFamilySportsGames;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'أسلوب الحياة'**
  String get categoryFamilyLifestyle;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get categoryFamilyPublic;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'أعمالي'**
  String get featuredWorks;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'تلاواتي'**
  String get featuredRecitations;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'حكاياتي'**
  String get featuredStories;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'قصائدي'**
  String get featuredPoems;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'مقالاتي'**
  String get featuredArticles;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'تقاريري'**
  String get featuredReports;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'برنامجي'**
  String get featuredProgram;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'ألعابي'**
  String get featuredGames;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'إنجازاتي'**
  String get featuredAchievements;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'معرضي'**
  String get featuredGallery;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'الأكثر مشاهدة'**
  String get featuredMostViewed;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'المميز'**
  String get featuredHighlights;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'تثبيت في «{section}»'**
  String featuredPinIn(String section);

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت من «{section}»'**
  String featuredUnpinFrom(String section);

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'ثُبّت في «{section}»'**
  String featuredPinned(String section);

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'أُلغي التثبيت'**
  String get featuredUnpinned;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'ترتيب'**
  String get featuredReorder;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'اسحب لتغيير الترتيب. حتى ٦ منشورات.'**
  String get featuredReorderHint;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'حفظ الترتيب'**
  String get featuredReorderSave;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'ثبّت حتى ٦ من منشوراتك هنا من قائمة «⋯» في المنشور.'**
  String get featuredEmptyOwn;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'أحدث منشوراتك — ثبّت ما تريد إظهاره هنا'**
  String get featuredAutoNote;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'قادم'**
  String get featuredUpcoming;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'بودكاست'**
  String get featuredPodcast;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'{count} مشاهدة'**
  String featuredViews(String count);

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get featuredPlay;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'اقرأ المزيد'**
  String get featuredReadMore;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'فئة موثّقة: {category}'**
  String categoryBadgeVerified(String category);

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'طلب توثيق الفئة'**
  String get categoryVerifyRequest;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'بعد أن يوثّق فريق كابسو فئتك تأخذ صفحتك شكلها الخاص: لون وشارة وقسم مميّز في الأعلى.'**
  String get categoryVerifyHint;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'طلب التوثيق قيد المراجعة'**
  String get categoryVerifyPending;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get categoryVerifyCancel;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'فئتك موثّقة'**
  String get categoryVerifyVerified;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'لم يُقبل طلبك: {reason}'**
  String categoryVerifyRejected(String reason);

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'أُرسل طلب التوثيق إلى فريق كابسو'**
  String get categoryVerifySent;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'تغيير الفئة يزيل التوثيق.'**
  String get categoryVerifyChangeWarning;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'قفل فريق كابسو فئة حسابك، فلا يمكن تغييرها الآن.'**
  String get categoryLockedNote;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تثبيت ٦ منشورات فقط هنا. ألغِ تثبيت واحد أولاً.'**
  String get errorFeaturedPinLimit;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'لديك طلب توثيق قيد المراجعة.'**
  String get errorCategoryVerificationPending;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'قفل فريق كابسو فئة حسابك.'**
  String get errorAccountCategoryLocked;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'وثّق فريق كابسو فئة حسابك — صفحتك الآن بشكلها الخاص'**
  String get notifCategoryVerified;

  /// D386: a profile page per account category (CONVENTIONS §10.175).
  ///
  /// In ar, this message translates to:
  /// **'راجع فريق كابسو فئة حسابك. افتح «تعديل الملف» لمعرفة التفاصيل'**
  String get notifCategoryReviewed;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'مراقبة المحتوى والأمان'**
  String get staffRoleTrustSafety;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'مدير عمليات البث'**
  String get staffRoleLiveOps;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'مدير الوكالات والمواهب'**
  String get staffRoleTalent;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'دعم كبار الداعمين'**
  String get staffRoleVipCare;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'المجتمع والفعاليات'**
  String get staffRoleCommunity;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'في المناوبة الآن'**
  String get staffOnShiftNow;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'حسب جدول المناوبات في لوحة الإدارة.'**
  String get staffScheduledHint;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'أدواري'**
  String get staffMyRoles;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'أدواري والمناوبة'**
  String get staffRolesAndShift;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'أدوات دورك في لوحة الإدارة.'**
  String get staffOpsPanelHint;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'تابعنا'**
  String get settingsFollowUs;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'إنستغرام'**
  String get socialPlatformInstagram;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'تيك توك'**
  String get socialPlatformTiktok;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'إكس'**
  String get socialPlatformX;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'فيسبوك'**
  String get socialPlatformFacebook;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'يوتيوب'**
  String get socialPlatformYoutube;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'سناب شات'**
  String get socialPlatformSnapchat;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'تيليجرام'**
  String get socialPlatformTelegram;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get socialPlatformWhatsapp;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'ثريدز'**
  String get socialPlatformThreads;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'لينكدإن'**
  String get socialPlatformLinkedin;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'ديسكورد'**
  String get socialPlatformDiscord;

  /// D387: the operations staff roles, the on-shift badge «في المناوبة الآن» and the app's official accounts «تابعنا» (CONVENTIONS §10.176).
  ///
  /// In ar, this message translates to:
  /// **'موقع آخر'**
  String get socialPlatformOther;

  /// D387: staff accounts send no gift and withdraw cherries only through Kabso (CONVENTIONS §10.176.8–9).
  ///
  /// In ar, this message translates to:
  /// **'حسابات فريق كابسو لا ترسل الهدايا.'**
  String get giftStaffRefused;

  /// D387: staff accounts send no gift and withdraw cherries only through Kabso (CONVENTIONS §10.176.8–9).
  ///
  /// In ar, this message translates to:
  /// **'حسابات فريق كابسو لا ترسل الهدايا.'**
  String get errorStaffGiftRefused;

  /// D387: staff accounts send no gift and withdraw cherries only through Kabso (CONVENTIONS §10.176.8–9).
  ///
  /// In ar, this message translates to:
  /// **'حساب فريق كابسو يسحب الكرز عن طريق Kabso Live فقط: اطلب السحب من محفظة الكرز، ولا يمكن بيعه لوكيل.'**
  String get staffCherriesCompanyOnly;

  /// D387: staff accounts send no gift and withdraw cherries only through Kabso (CONVENTIONS §10.176.8–9).
  ///
  /// In ar, this message translates to:
  /// **'حساب فريق كابسو يسحب الكرز عن طريق Kabso Live فقط.'**
  String get errorStaffWithdrawalCompanyOnly;

  /// D387 (§10.176.4): «الربح» — the coins given as VIP care compensations.
  ///
  /// In ar, this message translates to:
  /// **'تعويضات دعم كبار الداعمين (عملات)'**
  String get ownerProfitCompensations;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'شارة فريق كابسو — هذا الحساب من فريق عمل كابسو الرسمي'**
  String get badgeExplainKabsoTeam;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'مستوى الثروة {level}'**
  String badgeExplainWealthLevel(int level);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'مستوى الجاذبية {level}'**
  String badgeExplainCharmLevel(int level);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'مستوى الساحر {level}'**
  String badgeExplainWizardLevel(int level);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'مستوى اللعب {level}'**
  String badgeExplainGamingLevel(int level);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'مستوى الغرفة {level} — مستوى جاذبية المضيف'**
  String badgeExplainRoomLevel(int level);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'عضوية VIP {tier}'**
  String badgeExplainVip(int tier);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'آيدي ذهبي {id} — من مزايا عضوية VIP'**
  String badgeExplainGoldenId(String id);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'شارة التوثيق: {kind} — تُمنح تلقائياً عند تحقق الشروط'**
  String badgeExplainVerification(String kind);

  /// D389 (§10.178) for D386 (§10.175): the explainer of a verified category's badge beside the name
  ///
  /// In ar, this message translates to:
  /// **'فئة موثّقة: {category} — وثّقها فريق كابسو'**
  String badgeExplainCategory(String category);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'شارة المؤسس — مؤسس Kabso Live'**
  String get badgeExplainFounder;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'شارة الشحن اليومي — المستوى {tier}، تظهر 24 ساعة بعد الشحن'**
  String badgeExplainRechargeTier(int tier);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'وكيل شحن معتمد في Kabso Live — {code}'**
  String badgeExplainRechargeAgent(String code);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'وكيل مضيفين في Kabso Live — {code}'**
  String badgeExplainHostAgent(String code);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'شارة العنصر: {name}'**
  String badgeExplainItem(String name);

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'صانع محتوى — المضيف صانع محتوى في Kabso Live'**
  String get badgeExplainCreatorLive;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'هدف الهدايا اليومي للمضيف'**
  String get badgeExplainHostTargetGifts;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'هدف هدايا الحظ اليومي للمضيف'**
  String get badgeExplainHostTargetLucky;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'المضيف — صاحب هذا البث'**
  String get badgeExplainHost;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'مشرف — يساعد المضيف في إدارة هذا البث'**
  String get badgeExplainModerator;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'جديد — انضم إلى Kabso Live مؤخراً'**
  String get badgeExplainNewcomer;

  /// D389 (§10.178): the badge explainer — what a tapped badge is, in a small translucent box beside it
  ///
  /// In ar, this message translates to:
  /// **'عائلة {name} — المستوى {level}'**
  String badgeExplainFamily(String name, int level);

  /// D388 (§10.177): a WhatsApp conversation's customer language AR, shown as a small tag on the inbox row and the chat's status strip.
  ///
  /// In ar, this message translates to:
  /// **'عربي'**
  String get waLangAR;

  /// D388 (§10.177): a WhatsApp conversation's customer language EN, shown as a small tag on the inbox row and the chat's status strip.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get waLangEN;

  /// D388 (§10.177): the semantics of the customer-language tag.
  ///
  /// In ar, this message translates to:
  /// **'لغة العميل: {language}'**
  String waLangLabel(String language);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'برنامج سفراء Kabso'**
  String get ambProgrammeTitle;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'كن سفيراً لـ Kabso'**
  String get ambProgrammeEntry;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مثّل Kabso في منطقتك واربح عمولة على شحن أصدقائك النشطين'**
  String get ambProgrammeEntryHint;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'سفير Kabso ليس مجرد ناشر إعلانات، بل ممثل Kabso في منطقته'**
  String get ambHeroTitle;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'ماذا يفعل السفير'**
  String get ambWhatYouDo;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'يجلب مستخدمين جدداً عبر رمزه ورابطه الشخصي'**
  String get ambDo1;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'ينشر محتوى ترويجياً على وسائل التواصل'**
  String get ambDo2;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'يعرّف بـ Kabso في بلده'**
  String get ambDo3;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'ينظّم حملات وفعاليات ومسابقات بالتنسيق مع الإدارة'**
  String get ambDo4;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'ماذا يحصل عليه'**
  String get ambWhatYouGet;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'عمولة على الشحن المؤهل لأصدقائه النشطين'**
  String get ambGet1;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مكافآت شهرية عند تحقيق الأهداف: كوينز أو أيام VIP أو عناصر'**
  String get ambGet2;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'شارة السفير الحصرية'**
  String get ambGet3;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مستويات بمكافآت متصاعدة'**
  String get ambGet4;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'المستويات'**
  String get ambLevelsTitle;

  /// D390: «برنامج سفراء Kabso» — a level's name; the owner's «سفراء النجوم» set (2026-11-14): SPARK شرارة, STAR نجم, CONSTELLATION كوكبة, GALAXY مجرّة; the app maps the old codes BRONZE / SILVER / GOLD / DIAMOND to them first (ambassadorLevelName); a level the OWNER added shows its code (CONVENTIONS §10.179.6).
  ///
  /// In ar, this message translates to:
  /// **'{code, select, SPARK{شرارة} STAR{نجم} CONSTELLATION{كوكبة} GALAXY{مجرّة} other{{code}}}'**
  String ambLevelName(String code);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'إحالات نشطة: {active} · شحن: {coins} كوينز شهرياً'**
  String ambLevelRequirement(String active, String coins);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'عمولة {pct}'**
  String ambLevelCommission(String pct);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'بلا مكافأة شهرية'**
  String get ambRewardNone;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة: {amount} كوينز'**
  String ambRewardCoins(String amount);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة: {tier} · أيام: {days}'**
  String ambRewardVip(String tier, String days);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مكافأة: عنصر حقيبة · أيام: {days}'**
  String ambRewardItem(String days);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'القواعد'**
  String get ambRulesTitle;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'نافذة الإسناد بعد تسجيل الصديق (أيام): {days}'**
  String ambRuleWindow(String days);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مدة الحجز قبل الدفع (أيام): {days}'**
  String ambRuleHold(String days);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'الصديق النشط — عمر الحساب بالأيام: {days} · الشحن بالكوينز: {coins}'**
  String ambRuleActive(String days, String coins);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'الإحالات الوهمية والدفع من حسابك والاسترجاع تلغي العمولة'**
  String get ambRuleFraud;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'صديق يسجّل برمزك يُحتسب في برنامج السفراء بدلاً من مكافأة «دعوة الأصدقاء»'**
  String get ambRuleTrack;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'طلب الانضمام'**
  String get ambFormTitle;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get ambCountry;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'اختر بلدك'**
  String get ambCountryError;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'روابط حساباتك على التواصل الاجتماعي'**
  String get ambLinks;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'إضافة رابط'**
  String get ambAddLink;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'أدخل رابطاً يبدأ بـ https://'**
  String get ambLinkError;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'حجم جمهورك (عدد المتابعين)'**
  String get ambAudience;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقماً'**
  String get ambAudienceError;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لماذا تريد أن تكون سفيراً؟'**
  String get ambMotivation;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'اكتب سبباً قصيراً'**
  String get ambMotivationError;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get ambSubmit;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك'**
  String get ambSent;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة من الإدارة'**
  String get ambStatusPending;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لم تتم الموافقة على طلبك: {reason}. يمكنك التقديم مرة أخرى.'**
  String ambStatusRejected(String reason);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'حسابات فريق كابسو لا يمكنها الانضمام إلى برنامج السفراء'**
  String get ambStatusStaff;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'حسابك غير متاح للتقديم حالياً'**
  String get ambStatusNotActive;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'البرنامج قريباً — ستتمكن من التقديم عند إطلاقه'**
  String get ambSoon;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'أنت سفير Kabso'**
  String get ambYouAreAmbassador;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لوحة السفير'**
  String get ambOpenDashboard;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لوحة السفير'**
  String get ambDashTitle;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'رمزك ورابطك'**
  String get ambYourCode;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get ambCopy;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get ambCopied;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get ambShare;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى Kabso Live برمزي {code}: {link}'**
  String ambShareText(String code, String link);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'عمولتك {pct} من الشحن المؤهل'**
  String ambCommissionRate(String pct);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'للوصول إلى {level} هذا الشهر'**
  String ambNextLevel(String level);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'إحالات نشطة متبقية: {n}'**
  String ambNeedActive(String n);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'شحن متبقٍ بالكوينز: {n}'**
  String ambNeedCoins(String n);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'أنت في أعلى مستوى'**
  String get ambTopLevel;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'أهداف هذا الشهر'**
  String get ambThisMonth;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'إحالات نشطة'**
  String get ambActiveReferrals;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'شحن مؤهل (كوينز)'**
  String get ambQualifiedTopups;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'إحالاتك'**
  String get ambReferrals;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get ambTotal;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get ambActive;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'بانتظار النشاط'**
  String get ambPendingRefs;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'العمولات (كرز)'**
  String get ambCommissions;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'قيد الحجز'**
  String get ambPending;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'معلّقة'**
  String get ambHeld;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مدفوعة'**
  String get ambPaid;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مسترجعة'**
  String get ambReversed;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'مدفوعاتك معلّقة مؤقتاً لمراجعة الإدارة'**
  String get ambPayoutsHeld;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'البرنامج متوقف مؤقتاً — تُحفظ عمولاتك حتى يعود'**
  String get ambOff;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'السجل الشهري'**
  String get ambHistory;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'آخر العمولات'**
  String get ambRecent;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لا شيء بعد'**
  String get ambNoHistory;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'{status, select, PENDING{قيد الحجز} CREDITED{مدفوعة} VOID{ملغاة} REVERSED{مسترجعة} other{{status}}}'**
  String ambCommissionStatus(String status);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'{status, select, GRANTED{مُنحت المكافأة} HELD{المكافأة معلّقة} other{بلا مكافأة}}'**
  String ambRewardStatus(String status);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'سفير Kabso · {level}'**
  String ambBadgeLabel(String level);

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'سفراء Kabso'**
  String get meHubAmbassadors;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة على طلبك: أصبحت سفيراً لـ Kabso Live'**
  String get notifAmbassadorApproved;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لم تتم الموافقة على طلبك في برنامج سفراء Kabso. افتح البرنامج لمعرفة السبب'**
  String get notifAmbassadorRejected;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'ارتفع مستواك في برنامج سفراء Kabso'**
  String get notifAmbassadorLevelUp;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'حققت أهداف الشهر وحصلت على مكافأة السفير'**
  String get notifAmbassadorReward;

  /// D390: «برنامج سفراء Kabso» — the ambassadors programme (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك التقديم إلى برنامج السفراء الآن'**
  String get errorAmbassadorApplicationNotAllowed;

  /// D390 follow-up (owner 2026-11-13): the public badge's explainer (D389) and «إنهاء العضوية» (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'سفير Kabso — المستوى {level}'**
  String ambBadgeExplainer(String level);

  /// D390 follow-up (owner 2026-11-13): the public badge's explainer (D389) and «إنهاء العضوية» (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'انتهت عضويتك في برنامج السفراء. لا يمكنك التقديم مجدداً إلا إذا أعادت الإدارة تعيينك.'**
  String get ambStatusEnded;

  /// D390 follow-up (owner 2026-11-13): the public badge's explainer (D389) and «إنهاء العضوية» (CONVENTIONS §10.179).
  ///
  /// In ar, this message translates to:
  /// **'انتهت عضويتك في برنامج سفراء Kabso'**
  String get notifAmbassadorEnded;

  /// D390 (§10.179.10): the owner profit report «الربح» — the ambassadors' two lines.
  ///
  /// In ar, this message translates to:
  /// **'عمولات السفراء'**
  String get ownerProfitAmbassadorCommissions;

  /// D390 (§10.179.10): the owner profit report «الربح» — the ambassadors' two lines.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت السفراء (عملات)'**
  String get ownerProfitAmbassadorRewards;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the 4-way PK's name (the PK sheet card and the lobby sheet).
  ///
  /// In ar, this message translates to:
  /// **'PK رباعي'**
  String get pk4Title;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the lobby sheet's subtitle.
  ///
  /// In ar, this message translates to:
  /// **'٢ ضد ٢ — فريقان من مضيفَين'**
  String get pk4Subtitle;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the lobby sheet's explanation before a lobby is open.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ زميلاً ومنافسَين. تبدأ المعركة حين يقبل الأربعة.'**
  String get pk4LobbyHint;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the button that opens a lobby (the host becomes the organiser).
  ///
  /// In ar, this message translates to:
  /// **'افتح PK رباعي'**
  String get pk4OpenLobby;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the lobby's countdown (PK4_LOBBY_SECONDS).
  ///
  /// In ar, this message translates to:
  /// **'يُغلق خلال {time}'**
  String pk4LobbyEndsIn(String time);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: place 1 (team A).
  ///
  /// In ar, this message translates to:
  /// **'المنظِّم'**
  String get pk4SeatOrganiser;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: place 2 (team A).
  ///
  /// In ar, this message translates to:
  /// **'زميلك'**
  String get pk4SeatTeammate;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: places 3 and 4 (team B).
  ///
  /// In ar, this message translates to:
  /// **'منافس'**
  String get pk4SeatOpponent;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: an empty place.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ مضيفاً'**
  String get pk4SeatInvite;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: a place with an open invitation and its seconds left.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار… {seconds}'**
  String pk4SeatWaiting(String seconds);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: a place whose host accepted.
  ///
  /// In ar, this message translates to:
  /// **'جاهز'**
  String get pk4SeatReady;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the candidate list's title once a place is picked.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ إلى مكان: {place}'**
  String pk4InviteTo(String place);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the hint before a place is picked.
  ///
  /// In ar, this message translates to:
  /// **'اختر مكاناً فارغاً لتدعو إليه'**
  String get pk4PickPlace;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the organiser cancels the lobby.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء PK الرباعي'**
  String get pk4CancelLobby;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: an accepted host leaves the lobby before the start.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get pk4LeaveLobby;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the organiser takes an open invitation back.
  ///
  /// In ar, this message translates to:
  /// **'سحب الدعوة'**
  String get pk4CancelInvite;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the incoming invitation's title.
  ///
  /// In ar, this message translates to:
  /// **'دعوة PK رباعي'**
  String get pk4IncomingTitle;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the incoming invitation's line.
  ///
  /// In ar, this message translates to:
  /// **'{name} يدعوك إلى PK رباعي — {place}'**
  String pk4IncomingBody(String name, String place);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the lobby ran out before all four accepted.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل العدد'**
  String get pk4NoticeExpired;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: an accepted host is told the lobby was cancelled.
  ///
  /// In ar, this message translates to:
  /// **'ألغى المنظِّم PK الرباعي'**
  String get pk4NoticeCancelled;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the organiser is told an invitation was declined.
  ///
  /// In ar, this message translates to:
  /// **'اعتذر المضيف — ادعُ غيره'**
  String get pk4NoticeDeclined;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the organiser is told an invitation ran out.
  ///
  /// In ar, this message translates to:
  /// **'لم يرد المضيف — ادعُ غيره'**
  String get pk4NoticeInviteExpired;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the organiser is told an accepted host left.
  ///
  /// In ar, this message translates to:
  /// **'غادر مضيف مكانه'**
  String get pk4NoticeLeft;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: over the pane of a host who left the battle (their points stay).
  ///
  /// In ar, this message translates to:
  /// **'غادر'**
  String get pk4Out;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the host's per-pane mute switch (their own room only).
  ///
  /// In ar, this message translates to:
  /// **'كتم صوت {name}'**
  String pk4MuteHost(String name);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the host's per-pane mute switch, muted.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء كتم {name}'**
  String pk4UnmuteHost(String name);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the result chip of the winning team's rooms.
  ///
  /// In ar, this message translates to:
  /// **'فاز فريقكم'**
  String get pk4ResultWin;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the result chip of the losing team's rooms.
  ///
  /// In ar, this message translates to:
  /// **'خسر فريقكم'**
  String get pk4ResultLoss;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the team bar for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'فريقكم {own}، المنافسون {other}'**
  String pk4ScoreSemantics(String own, String other);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: a host's pane for screen readers.
  ///
  /// In ar, this message translates to:
  /// **'{name}، {score} نقطة'**
  String pk4PaneSemantics(String name, String score);

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: a CONNECTED match (the organiser's auto-start off).
  ///
  /// In ar, this message translates to:
  /// **'تم ربط المضيفين الأربعة — تبدأ المعركة حين يضغط أحدهم ابدأ'**
  String get pk4ConnectedHint;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: the End confirmation in a 4-way battle.
  ///
  /// In ar, this message translates to:
  /// **'ستغادر المعركة ويكمل زميلك وحده؛ تبقى نقاطك لفريقك.'**
  String get pk4EndConfirmBody;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: 409 PK_LOBBY_CLOSED.
  ///
  /// In ar, this message translates to:
  /// **'لم تعد غرفة PK الرباعي مفتوحة'**
  String get pk4ErrorLobbyClosed;

  /// v1.118-live (D391, CONVENTIONS §10.180) «PK رباعي»: 409 PK_SEAT_TAKEN.
  ///
  /// In ar, this message translates to:
  /// **'هذا المكان فيه دعوة بالفعل'**
  String get pk4ErrorSeatTaken;
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
