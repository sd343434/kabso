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
  String get discoverComingTitle => 'Discover is coming';

  @override
  String get createComingTitle => 'Creating is coming';

  @override
  String get createComingBody =>
      'Photo posts arrive in Phase 3 and short videos in Phase 5.';

  @override
  String get liveComingTitle => 'Live rooms are coming';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEmailVerified => 'Email verified';

  @override
  String get profileEmailNotVerified => 'Email not verified';

  @override
  String get profileResendVerification => 'Resend verification email';

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
  String get errorUsernameTaken => 'This username isn\'t available.';

  @override
  String get errorIdempotencyConflict =>
      'This request was already sent with different details.';

  @override
  String get errorTokenExpired => 'This link has expired or was already used.';

  @override
  String get errorTokenInvalid => 'This link isn\'t valid.';

  @override
  String get errorInternal =>
      'Something went wrong on our side. Please try again later.';

  @override
  String get errorServiceUnavailable =>
      'We\'re busy right now. Please try again in a moment.';

  @override
  String get errorNetworkOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorNetworkTimeout =>
      'The connection timed out. Please try again.';

  @override
  String get errorUnknown => 'Something unexpected happened. Please try again.';

  @override
  String get errorEmailTaken =>
      'This email can\'t be used to create a new account. Try logging in or resetting your password.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment, then try again.';

  @override
  String errorRateLimitedRetryIn(String wait) {
    return 'Too many attempts. Try again in $wait.';
  }

  @override
  String errorServiceBusyRetryIn(String wait) {
    return 'We\'re busy right now. Please try again in $wait.';
  }

  @override
  String errorIdLabel(String requestId) {
    return 'Error ID: $requestId';
  }

  @override
  String get homeComingBody =>
      'Following people and your home feed arrive in Phase 2; posts in Phase 3.';

  @override
  String get discoverComingBody =>
      'People search arrives in Phase 2; trending lives, videos and creators in Phase 9.';

  @override
  String get liveComingBody =>
      'Watching and hosting live streams arrive in Phase 6; PK battles and gifts in Phase 7.';

  @override
  String get profileContentComingTitle => 'Your posts will live here';

  @override
  String get profileContentComingBody =>
      'Profile editing and followers arrive in Phase 2, posts in Phase 3, stories and highlights in Phase 4.';

  @override
  String usernameTaken(String username) {
    return '@$username isn\'t available. Try another.';
  }

  @override
  String get usernameCheckFailed =>
      'Couldn\'t check right now. You can still continue.';

  @override
  String get usernameTooShort => 'Use at least 3 characters';

  @override
  String get usernameTooLong => 'Use 30 characters or fewer';

  @override
  String get usernameBadChars =>
      'Use only a–z, 0–9, dot (.) and underscore (_)';

  @override
  String get usernameBadEdges => 'Can\'t start or end with a dot or underscore';

  @override
  String sessionsLastActive(String relativeTime) {
    return 'Active $relativeTime';
  }

  @override
  String get sessionsActiveNow => 'Active now';

  @override
  String sessionsSignedIn(String date) {
    return 'Signed in $date';
  }

  @override
  String relativeMinutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String relativeHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String relativeDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get sessionsRevoke => 'End';

  @override
  String get sessionsRevokeConfirmTitle => 'End this session?';

  @override
  String sessionsRevokeConfirmBody(String device) {
    return '$device will be logged out right away.';
  }

  @override
  String get sessionsRevoked => 'Session ended';

  @override
  String get sessionsAlreadyEnded => 'This session had already ended';

  @override
  String get sessionsNoOthers => 'You\'re signed in on this device only.';
}
