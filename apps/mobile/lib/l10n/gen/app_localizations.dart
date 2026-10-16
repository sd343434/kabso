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
  /// **'مرحبًا بعودتك. سجّل الدخول للمتابعة.'**
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
  /// **'ستتوفر متابعة الأشخاص وخلاصتك الرئيسية في المرحلة 2، والمنشورات في المرحلة 3.'**
  String get homeComingBody;

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

  /// No description provided for @createComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإنشاء قادم'**
  String get createComingTitle;

  /// No description provided for @createComingBody.
  ///
  /// In ar, this message translates to:
  /// **'تتوفر المنشورات في المرحلة 3، والقصص في المرحلة 4، والفيديوهات القصيرة في المرحلة 5، والبث المباشر في المرحلة 6.'**
  String get createComingBody;

  /// No description provided for @liveComingTitle.
  ///
  /// In ar, this message translates to:
  /// **'غرف البث المباشر قادمة'**
  String get liveComingTitle;

  /// No description provided for @liveComingBody.
  ///
  /// In ar, this message translates to:
  /// **'تتوفر مشاهدة البث المباشر واستضافته في المرحلة 6، ومعارك PK والهدايا في المرحلة 7.'**
  String get liveComingBody;

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
  /// **'يتوفر تعديل الملف الشخصي والمتابعون في المرحلة 2، والمنشورات في المرحلة 3، والقصص واللقطات المميزة في المرحلة 4.'**
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
  /// **'منذ {n} د'**
  String relativeMinutesAgo(int n);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {n} س'**
  String relativeHoursAgo(int n);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {n} ي'**
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

  /// No description provided for @liveCoverUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الغلاف'**
  String get liveCoverUnavailable;

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
  /// **'إرسال الهدايا قادم قريبًا.'**
  String get giftSendComingSoon;

  /// No description provided for @giftCombo.
  ///
  /// In ar, this message translates to:
  /// **'×{count}'**
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
