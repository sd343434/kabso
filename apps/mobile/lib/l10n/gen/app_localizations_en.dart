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
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSwitchHint => 'Changes the app language';

  @override
  String get loginTitle => 'Log in';

  @override
  String get loginSubtitle => 'Welcome back. Log in to continue.';

  @override
  String get loginIdentifierLabel => 'Email or username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginSubmit => 'Log in';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

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
  String get registerDisplayNameHelper =>
      'Your name as others see it. Up to 50 characters; emoji are fine.';

  @override
  String displayNameCounter(int count) {
    return '$count/50';
  }

  @override
  String get displayNameTooLong =>
      'This name is too long. Use up to 50 characters (some emoji count as more than one).';

  @override
  String get displayNameInvalid =>
      'This name has characters that can\'t be used. Use letters, numbers, spaces and emoji.';

  @override
  String get displayNameReserved =>
      'This name can\'t be used. Choose a different name.';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerPasswordHelper => 'At least 8 characters';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerCodeNotice =>
      'We\'ll email you an 8-digit code to confirm your address.';

  @override
  String get registerTerms =>
      'By creating an account, you agree to the Terms and the Privacy Policy.';

  @override
  String get registerHaveAccount => 'Already have an account?';

  @override
  String get registerSignIn => 'Log in';

  @override
  String get usernameChecking => 'Checking availability…';

  @override
  String usernameAvailable(String username) {
    return '@$username is available';
  }

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
  String get codeTitle => 'Check your email';

  @override
  String codeBody(String email) {
    return 'If $email can be used for a new account, we\'ve sent an 8-digit code to it. Enter the code below.';
  }

  @override
  String get codeChangeEmail => 'Change email';

  @override
  String get codeFieldLabel => '8-digit code';

  @override
  String get codeFieldHint => 'Enter or paste the code from the email';

  @override
  String get codeExpiryHint =>
      'The code expires in 30 minutes. Check your spam folder if you can\'t find it.';

  @override
  String get codeMaybeExpired => 'This code may have expired. Send a new one.';

  @override
  String get codePasteInvalid =>
      'The code has 8 digits. Check it and try again.';

  @override
  String get codeSubmit => 'Verify';

  @override
  String get codeResend => 'Send a new code';

  @override
  String codeResendIn(String time) {
    return 'Send a new code in $time';
  }

  @override
  String get codeResent =>
      'If this email can be used, a new code is on its way. Earlier codes no longer work.';

  @override
  String get codeHaveAccount => 'Already have an account?';

  @override
  String get codeLogIn => 'Log in';

  @override
  String get codeWelcome => 'Welcome to Kabso Live';

  @override
  String get errCodeInvalid => 'This code is incorrect or has expired.';

  @override
  String get errCodeInvalidRepeated =>
      'Still not working? Send a new code and use the latest email.';

  @override
  String get errUsernameTakenDuringVerify =>
      'Someone took this username before you finished. Choose another one and we\'ll send a new code.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSubtitle =>
      'Enter the email you signed up with and we\'ll send you a reset link.';

  @override
  String get forgotEmailLabel => 'Email';

  @override
  String get forgotSubmit => 'Send link';

  @override
  String get forgotConfirmationTitle => 'Check your email';

  @override
  String forgotConfirmationBody(String email) {
    return 'If an account exists for $email, we\'ve sent a link to reset the password. The link expires in 1 hour.';
  }

  @override
  String get forgotBackToLogin => 'Back to log in';

  @override
  String get validationRequired => 'This field is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String validationTooShort(int min) {
    return 'Use at least $min characters';
  }

  @override
  String validationTooLong(int max) {
    return 'Use $max characters or fewer';
  }

  @override
  String get validationInvalid => 'This value isn\'t valid';

  @override
  String get sessionEndedBanner =>
      'Your session has ended. Please log in again.';

  @override
  String get accountSuspendedBanner =>
      'This account has been suspended. If you think this is a mistake, contact support.';

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
      'Following people and your home feed arrive in Phase 2; posts in Phase 3.';

  @override
  String get discoverComingTitle => 'Discover is coming';

  @override
  String get discoverComingBody =>
      'People search arrives in Phase 2; trending lives, videos and creators in Phase 9.';

  @override
  String get createComingTitle => 'Creating is coming';

  @override
  String get createComingBody =>
      'Posts arrive in Phase 3, stories in Phase 4, short videos in Phase 5 and going live in Phase 6.';

  @override
  String get liveComingTitle => 'Live rooms are coming';

  @override
  String get liveComingBody =>
      'Watching and hosting live streams arrive in Phase 6; PK battles and gifts in Phase 7.';

  @override
  String profileUsername(String username) {
    return '@$username';
  }

  @override
  String get profileContentComingTitle => 'Your posts will live here';

  @override
  String get profileContentComingBody =>
      'Profile editing and followers arrive in Phase 2, posts in Phase 3, stories and highlights in Phase 4.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSessions => 'Active sessions';

  @override
  String get sessionsCurrent => 'This device';

  @override
  String get sessionUnknownDevice => 'Unknown device';

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
  String get sessionsRevokeConfirm => 'End session';

  @override
  String get sessionsRevoked => 'Session ended';

  @override
  String get sessionsAlreadyEnded => 'This session had already ended';

  @override
  String get sessionsNoOthers => 'You\'re signed in on this device only.';

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
  String get logout => 'Log out';

  @override
  String get logoutConfirmTitle => 'Log out of Kabso Live?';

  @override
  String get logoutConfirmBody =>
      'You\'ll need your password to log back in on this device.';

  @override
  String get logoutDone => 'You\'ve logged out';

  @override
  String get errorValidationFailed =>
      'Some details need fixing. Check the highlighted fields.';

  @override
  String get errorAuthUnauthenticated =>
      'Your session has ended. Please log in again.';

  @override
  String get errorAuthInvalidCredentials =>
      'Incorrect email, username or password.';

  @override
  String get errorAuthRefreshInvalid =>
      'Your session has ended. Please log in again.';

  @override
  String get errorAuthForbidden => 'You don\'t have permission to do that.';

  @override
  String get errorAccountSuspended =>
      'This account has been suspended. If you think this is a mistake, contact support.';

  @override
  String get errorNotFound =>
      'This isn\'t available. It may have been removed.';

  @override
  String get errorUsernameTaken =>
      'This username isn\'t available. Try another.';

  @override
  String get errorIdempotencyConflict =>
      'This request was already sent with different details. Refresh and try again.';

  @override
  String get errorTokenExpired =>
      'This link has expired or has already been used. Request a new one.';

  @override
  String get errorTokenInvalid => 'This link isn\'t valid. Request a new one.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment, then try again.';

  @override
  String errorRateLimitedRetryIn(String wait) {
    return 'Too many attempts. Try again in $wait.';
  }

  @override
  String get errorInternal =>
      'Something went wrong on our side. Please try again.';

  @override
  String get errorServiceUnavailable =>
      'We\'re busy right now. Please try again in a moment.';

  @override
  String errorServiceBusyRetryIn(String wait) {
    return 'We\'re busy right now. Please try again in $wait.';
  }

  @override
  String get errorNetworkOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorNetworkTimeout =>
      'The connection timed out. Please try again.';

  @override
  String get errorUnknown => 'Something unexpected happened. Please try again.';

  @override
  String errorIdLabel(String requestId) {
    return 'Error ID: $requestId';
  }

  @override
  String get liveBadge => 'LIVE';

  @override
  String get pkBadge => 'PK';

  @override
  String liveViewers(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted viewers',
      one: '$formatted viewer',
    );
    return '$_temp0';
  }

  @override
  String liveCardSemantics(String host, String viewers, String title) {
    return '$host, live, $viewers, $title';
  }

  @override
  String get liveCoverUnavailable => 'Cover couldn\'t load';

  @override
  String get avatarLiveNow => 'live now';

  @override
  String get avatarStoryUnseen => 'has new story';

  @override
  String get avatarStorySeen => 'story viewed';

  @override
  String get liveFollow => 'Follow';

  @override
  String get liveFollowing => 'Following';

  @override
  String get liveClose => 'Close';

  @override
  String get liveCommentHint => 'Say something…';

  @override
  String get liveGifts => 'Gifts';

  @override
  String get liveShare => 'Share';

  @override
  String get liveVideoPlaceholder => 'Live video';

  @override
  String chatJoined(String name) {
    return '$name joined';
  }

  @override
  String chatGiftSent(String name, String gift, int count) {
    return '$name sent $gift ×$count';
  }

  @override
  String get giftPanelTitle => 'Send a gift';

  @override
  String get giftSend => 'Send';

  @override
  String get giftSendComingSoon => 'Sending gifts is coming soon.';

  @override
  String giftCombo(int count) {
    return '×$count';
  }

  @override
  String giftCellSemantics(String gift, String price) {
    return '$gift, price $price';
  }

  @override
  String pkTimeLeft(String time) {
    return '$time left';
  }

  @override
  String pkScoreSemantics(String left, String right) {
    return 'Score $left to $right';
  }

  @override
  String get pkWin => 'Win';

  @override
  String get pkLose => 'Loss';

  @override
  String get pkDraw => 'Draw';

  @override
  String compactThousand(String value) {
    return '${value}K';
  }

  @override
  String compactMillion(String value) {
    return '${value}M';
  }

  @override
  String compactBillion(String value) {
    return '${value}B';
  }

  @override
  String get debugComponentGallery => 'Component gallery';
}
