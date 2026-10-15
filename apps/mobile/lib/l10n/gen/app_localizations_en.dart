// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kabso Live';

  @override
  String get brandWordmarkPrimary => 'Kabso';

  @override
  String get brandWordmarkAccent => 'Live';

  @override
  String get brandSemanticLabel => 'Kabso Live';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionContinue => 'Continue';

  @override
  String get loading => 'Loading…';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Welcome back! Sign in to continue.';

  @override
  String get loginIdentifierLabel => 'Email or username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle => 'Join Kabso Live in a minute.';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerUsernameLabel => 'Username';

  @override
  String get registerUsernameHelper =>
      '3–30 characters: lowercase letters, numbers, . and _';

  @override
  String get registerDisplayNameLabel => 'Display name';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerPasswordHelper => '8–128 characters';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerSignIn => 'Sign in';

  @override
  String get usernameChecking => 'Checking availability…';

  @override
  String usernameAvailable(String username) {
    return '@$username is available';
  }

  @override
  String usernameTaken(String username) {
    return '@$username is taken';
  }

  @override
  String get usernameCheckFailed => 'Couldn\'t check availability right now';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSubtitle =>
      'Enter your email and we\'ll send you reset instructions.';

  @override
  String get forgotEmailLabel => 'Email';

  @override
  String get forgotSubmit => 'Send instructions';

  @override
  String get forgotConfirmationTitle => 'Check your email';

  @override
  String forgotConfirmationBody(String email) {
    return 'If an account exists for $email, we\'ve sent it instructions to reset the password.';
  }

  @override
  String get forgotBackToLogin => 'Back to sign in';

  @override
  String get verifyTitle => 'Verify your email';

  @override
  String verifyBody(String email) {
    return 'We sent a verification link to $email. Open it to verify your account.';
  }

  @override
  String get verifyResend => 'Resend email';

  @override
  String get verifyResent => 'Verification email sent';

  @override
  String get verifyContinue => 'Continue to the app';

  @override
  String get validationRequired => 'This field is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String validationTooShort(int min) {
    return 'Must be at least $min characters';
  }

  @override
  String validationTooLong(int max) {
    return 'Must be at most $max characters';
  }

  @override
  String get validationUsernameFormat =>
      'Use only lowercase letters, numbers, . and _; it can\'t start or end with . or _';

  @override
  String get validationInvalid => 'This value isn\'t valid';

  @override
  String get sessionEndedBanner =>
      'Your session has ended. Please sign in again.';

  @override
  String get accountSuspendedBanner => 'This account has been suspended.';

  @override
  String get splashRestoreFailed => 'We couldn\'t restore your session.';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navCreate => 'Create';

  @override
  String get navLive => 'Live';

  @override
  String get navProfile => 'Profile';

  @override
  String get homeComingTitle => 'Your feed is on its way';

  @override
  String get homeComingBody =>
      'Posts and stories from people you follow arrive in Phase 2.';

  @override
  String get discoverComingTitle => 'Discover is coming';

  @override
  String get discoverComingBody =>
      'Search and trending creators arrive in Phase 9.';

  @override
  String get createComingTitle => 'Creating is coming';

  @override
  String get createComingBody =>
      'Photo posts arrive in Phase 3 and short videos in Phase 5.';

  @override
  String get liveComingTitle => 'Live rooms are coming';

  @override
  String get liveComingBody =>
      'Going live and watching streams arrive in Phase 6.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEmailVerified => 'Email verified';

  @override
  String get profileEmailNotVerified => 'Email not verified';

  @override
  String get profileResendVerification => 'Resend verification email';

  @override
  String get profileContentComingTitle => 'Your profile is being built';

  @override
  String get profileContentComingBody =>
      'Your posts, followers and highlights arrive in Phase 2.';

  @override
  String profileUsername(String username) {
    return '@$username';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSessions => 'Active sessions';

  @override
  String get sessionsCurrent => 'This device';

  @override
  String sessionsLastActive(String date) {
    return 'Last active $date';
  }

  @override
  String get sessionsRevoke => 'Sign out';

  @override
  String get sessionsRevokeConfirmTitle => 'Sign out this device?';

  @override
  String get sessionsRevokeConfirmBody =>
      'That device will have to sign in again.';

  @override
  String get sessionsRevoked => 'Device signed out';

  @override
  String get sessionsNoOthers => 'No other active sessions';

  @override
  String get sessionUnknownDevice => 'Unknown device';

  @override
  String get platformAndroid => 'Android';

  @override
  String get platformIos => 'iOS';

  @override
  String get platformWeb => 'Web';

  @override
  String get platformOther => 'Other';

  @override
  String get settingsAccount => 'Account';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirmTitle => 'Sign out of Kabso Live?';

  @override
  String get logoutConfirmBody =>
      'You\'ll need to sign in again on this device.';

  @override
  String get errorValidationFailed =>
      'Some details aren\'t valid. Check them and try again.';

  @override
  String get errorAuthUnauthenticated => 'Please sign in to continue.';

  @override
  String get errorAuthInvalidCredentials =>
      'Incorrect email, username or password.';

  @override
  String get errorAuthRefreshInvalid =>
      'Your session has ended. Please sign in again.';

  @override
  String get errorAuthForbidden => 'You don\'t have permission to do that.';

  @override
  String get errorAccountSuspended => 'This account has been suspended.';

  @override
  String get errorNotFound => 'We couldn\'t find that.';

  @override
  String get errorEmailTaken => 'This email is already registered.';

  @override
  String get errorUsernameTaken => 'This username isn\'t available.';

  @override
  String get errorIdempotencyConflict =>
      'This request was already sent with different details.';

  @override
  String get errorTokenExpired => 'This link has expired or was already used.';

  @override
  String get errorTokenInvalid => 'This link isn\'t valid.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get errorInternal =>
      'Something went wrong on our side. Please try again later.';

  @override
  String get errorServiceUnavailable =>
      'The service is temporarily unavailable. Try again shortly.';

  @override
  String get errorNetworkOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorNetworkTimeout =>
      'The connection timed out. Please try again.';

  @override
  String get errorUnknown => 'Something unexpected happened. Please try again.';
}
