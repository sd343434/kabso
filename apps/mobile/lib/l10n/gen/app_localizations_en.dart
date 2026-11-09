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
  String get loginSubtitle => 'Log in and pick up where you left off.';

  @override
  String get loginIdentifierLabel => 'Email, username or staff ID';

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
  String get usernameTooShort => 'Use at least 6 characters';

  @override
  String get usernameTooLong => 'Use 30 characters or fewer';

  @override
  String get usernameBadChars => 'Use only a–z, 0–9 and underscore (_)';

  @override
  String get usernameBadEdges => 'Can\'t start or end with an underscore';

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
  String get splashSkip => 'Skip';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navCreate => 'Create';

  @override
  String get navReels => 'Reels';

  @override
  String get navLive => 'Live';

  @override
  String get navProfile => 'Me';

  @override
  String get discoverComingTitle => 'Discover is coming';

  @override
  String get discoverComingBody =>
      'People search arrives in Phase 2; trending lives, videos and creators in Phase 9.';

  @override
  String profileUsername(String username) {
    return '@$username';
  }

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
  String get settingsSoundEffects => 'Sound effects';

  @override
  String get settingsSoundEffectsHint => 'MAX X, lucky wins and notifications';

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
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes ago',
      one: '$n minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours ago',
      one: '$n hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '$n day ago',
    );
    return '$_temp0';
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
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsThemeFollowsDevice => 'Following your device';

  @override
  String get settingsThemeFollowDevice => 'Follow device';

  @override
  String settingsLanguageCurrent(String language) {
    return 'Language: $language';
  }

  @override
  String settingsLanguageSwitchTo(String language) {
    return 'Switch to $language';
  }

  @override
  String sessionsShowAll(int count) {
    return 'Show all ($count)';
  }

  @override
  String get sessionsRevokeOthers => 'Log out of all other devices';

  @override
  String get sessionsRevokeOthersTitle => 'Log out of all other devices?';

  @override
  String sessionsRevokeOthersBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n other devices will be logged out right away.',
      one: '$n other device will be logged out right away.',
    );
    return '$_temp0';
  }

  @override
  String get sessionsRevokeOthersPasswordHint =>
      'Enter your password to confirm.';

  @override
  String get sessionsRevokeOthersConfirm => 'Log out';

  @override
  String sessionsRevokedOthers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n other devices logged out',
      one: '$n other device logged out',
    );
    return '$_temp0';
  }

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
  String get errorLiveHostingUnavailable => 'Going live isn\'t available yet.';

  @override
  String get errorLiveRoomAlreadyActive =>
      'You\'re already live in another room. Resume or end it first.';

  @override
  String get errorLiveRoomEnded => 'This live has ended.';

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
  String get giftSendComingSoon => 'Gifts can\'t be sent yet.';

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
  String get registerUsernameReservedHint =>
      'If you started signing up with this email and username, your code may still work. Get a new code to continue, or choose another username.';

  @override
  String get registerResendCode => 'Resend code';

  @override
  String get registerChooseAnotherUsername => 'Choose another username';

  @override
  String get feedTabFollowing => 'Following';

  @override
  String get feedTabPopular => 'Popular';

  @override
  String get feedTabNew => 'New';

  @override
  String get feedPreviewTestData => 'Test data';

  @override
  String get feedOpenLive => 'Live';

  @override
  String get feedActionLike => 'Like';

  @override
  String get feedActionComment => 'Comments';

  @override
  String get feedActionSave => 'Save';

  @override
  String get livePreviewMinimize => 'Minimise';

  @override
  String get livePreviewBalance => 'Balance';

  @override
  String get livePreviewMore => 'More';

  @override
  String get livePreviewEmoji => 'Emoji';

  @override
  String get feedSearch => 'Search';

  @override
  String get feedSeePopular => 'See popular';

  @override
  String get feedPullToRefresh => 'Pull down to refresh.';

  @override
  String get homeFollowingUnavailableTitle => 'Stay close to your people';

  @override
  String get homeFollowingUnavailableBody =>
      'Posts from people you follow will appear here soon. Meanwhile, see who\'s live right now.';

  @override
  String get homePopularUnavailableTitle => 'Posts are on their way';

  @override
  String get homePopularUnavailableBody =>
      'Soon the posts everyone is talking about will show up here. Until then, join a live stream.';

  @override
  String get homeNewUnavailableTitle => 'Fresh posts, coming soon';

  @override
  String get homeNewUnavailableBody =>
      'The newest posts from the community will land here first. For now, see who just went live.';

  @override
  String get homeEmptyTitle => 'No posts yet';

  @override
  String get homeFollowingEmptyTitle => 'No posts from people you follow yet';

  @override
  String get homeErrorTitle => 'Couldn\'t load posts';

  @override
  String get liveHubChipAll => 'All';

  @override
  String get liveHubFollowingUnavailableTitle => 'Live from people you follow';

  @override
  String get liveHubFollowingUnavailableBody =>
      'Live streaming isn\'t open yet. Once it is, you\'ll see here when people you follow go live.';

  @override
  String get liveHubPopularUnavailableTitle => 'Live streaming isn\'t open yet';

  @override
  String get liveHubPopularUnavailableBody =>
      'We\'re getting it ready. When it opens, the most-watched streams will appear here.';

  @override
  String get liveHubNewUnavailableTitle => 'New streams will start here';

  @override
  String get liveHubNewUnavailableBody =>
      'Live streaming isn\'t open yet. Once it is, streams that just started will appear here first.';

  @override
  String get liveHubEmptyTitle => 'No live streams right now';

  @override
  String get liveHubFollowingEmptyTitle => 'No one you follow is live';

  @override
  String get liveHubErrorTitle => 'Couldn\'t load live streams';

  @override
  String get liveHubLoadMoreFailed => 'Couldn\'t load more';

  @override
  String get liveHubListEnd => 'Pull down for new streams';

  @override
  String get liveCardNew => 'New';

  @override
  String liveMultiGuest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guests',
      one: '$count guest',
    );
    return '$_temp0';
  }

  @override
  String liveCardSemanticsMode(String card, String mode) {
    return '$card, $mode';
  }

  @override
  String get feedPostJustNow => 'Just now';

  @override
  String get feedOfflineTitle => 'You\'re offline';

  @override
  String get feedOfflineBody => 'Check your connection, then try again.';

  @override
  String get homeWatchLive => 'Watch live streams';

  @override
  String get homeSeeWhoIsLive => 'See who\'s live';

  @override
  String get liveHubEmptyBody => 'Explore new streams or check back later.';

  @override
  String get liveHubSeeNew => 'See new streams';

  @override
  String get liveHubFollowingEmptyBody =>
      'When people you follow go live, you\'ll find them here.';

  @override
  String liveCardSemanticsCategory(String card, String category) {
    return '$card, $category';
  }

  @override
  String get liveRoomVideoUnavailableTitle => 'Live video isn\'t available yet';

  @override
  String get liveRoomVideoUnavailableBody =>
      'Video can\'t play in the app yet. The room details here are live.';

  @override
  String get liveRoomChatUnavailable =>
      'Chat isn\'t open yet. Messages will appear here.';

  @override
  String liveRoomFollowers(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted followers',
      one: '$formatted follower',
    );
    return '$_temp0';
  }

  @override
  String liveRoomHostSemantics(String host) {
    return '$host, host profile';
  }

  @override
  String liveRoomUsername(String username) {
    return '@$username';
  }

  @override
  String liveRoomCategory(String category) {
    return 'Category: $category';
  }

  @override
  String get liveStatusEnded => 'Live ended';

  @override
  String get liveStatusConnectionLost => 'Connection lost';

  @override
  String get liveStatusHostAway => 'Host away';

  @override
  String get liveStatusCantConnect => 'Can\'t connect';

  @override
  String get liveStatusOffline => 'Offline';

  @override
  String get liveStatusUnavailable => 'Unavailable';

  @override
  String get liveStatusRemoved => 'Removed';

  @override
  String get liveRoomEndedTitle => 'This live has ended';

  @override
  String get liveRoomEndedByHost => 'The host ended this live.';

  @override
  String get liveRoomEndedTimeout =>
      'The live stopped after the host\'s connection was lost.';

  @override
  String get liveRoomEndedHostAway =>
      'The live ended because the host was away for more than 5 minutes.';

  @override
  String get liveRoomEndedOther => 'This live is no longer available.';

  @override
  String get liveRoomBackToLive => 'Back to live rooms';

  @override
  String get liveRoomNotFoundTitle => 'This live isn\'t available';

  @override
  String get liveRoomNotFoundBody => 'It may have ended or been removed.';

  @override
  String get liveRoomErrorTitle => 'Couldn\'t open this live';

  @override
  String get liveRoomLoading => 'Opening the live';

  @override
  String get liveRoomWeakConnection => 'Weak connection';

  @override
  String get liveRoomReconnecting => 'Reconnecting…';

  @override
  String get liveRoomReconnectingBody =>
      'Hang on, the live picks up where it stopped.';

  @override
  String get liveRoomJoinFailedTitle => 'The live couldn\'t play';

  @override
  String get liveHostAwayBody =>
      'Stay here, the live resumes as soon as they\'re back.';

  @override
  String get liveRoomCameraOff => 'Camera is off';

  @override
  String get giftNameHeart => 'Heart';

  @override
  String get giftNameStar => 'Star';

  @override
  String get giftNameDiamond => 'Diamond';

  @override
  String get giftNameCrown => 'Crown';

  @override
  String get pkVersus => 'VS';

  @override
  String pkSupporters(String names) {
    return 'Top supporters: $names';
  }

  @override
  String get multiGuestOpenSeat => 'Open seat';

  @override
  String multiGuestMicOff(String name) {
    return '$name, microphone off';
  }

  @override
  String get multiGuestHost => 'Host';

  @override
  String get shareSheetTitle => 'Share to';

  @override
  String get shareRepost => 'Repost';

  @override
  String get shareCopyLink => 'Copy link';

  @override
  String get shareSend => 'Send';

  @override
  String get shareSaveVideo => 'Save video';

  @override
  String get shareReport => 'Report';

  @override
  String get messagesPreviewHint => 'Send a message…';

  @override
  String get messagesPreviewSend => 'Send';

  @override
  String get messagesPreviewPlay => 'Play video';

  @override
  String messagesPreviewReaction(String emoji) {
    return 'Reaction $emoji';
  }

  @override
  String commentsSheetTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '$count comment',
    );
    return '$_temp0';
  }

  @override
  String get commentsCreator => 'Creator';

  @override
  String get commentsReply => 'Reply';

  @override
  String commentsViewReplies(int count) {
    return 'View replies ($count)';
  }

  @override
  String get commentsHideReplies => 'Hide replies';

  @override
  String get commentsHint => 'Add comment…';

  @override
  String get commentsPost => 'Post';

  @override
  String commentsLike(String count) {
    return 'Like, $count';
  }

  @override
  String get commentsVerified => 'Verified';

  @override
  String get previewsHubTitle => 'Design previews';

  @override
  String get previewsHubNote =>
      'Test data only. Nothing here is connected to a server.';

  @override
  String get previewsHubFeed => 'Feed';

  @override
  String get previewsHubLive => 'Live room';

  @override
  String get previewsHubMessages => 'Messages';

  @override
  String get commentsYou => 'You';

  @override
  String get conversationsTitle => 'Messages';

  @override
  String get conversationsSharedVideo => 'Shared a video';

  @override
  String conversationsSayHi(String name) {
    return 'Say hi to $name';
  }

  @override
  String conversationsUnread(String name) {
    return '$name, unread';
  }

  @override
  String get conversationsEmptyTitle => 'No messages yet';

  @override
  String get conversationsEmptyBody =>
      'When you message someone, the conversation shows up here.';

  @override
  String get conversationsUnavailableTitle => 'Messages aren\'t available yet';

  @override
  String get conversationsUnavailableBody =>
      'Private messages will open here once they\'re ready.';

  @override
  String get previewStateLabel => 'Preview state';

  @override
  String get previewStateLoading => 'Loading';

  @override
  String get previewStateError => 'Error';

  @override
  String get previewStateUnavailable => 'Unavailable';

  @override
  String get previewStateEmpty => 'Empty';

  @override
  String get previewStatePopulated => 'With data';

  @override
  String get messagesGreetingHi => 'Hi';

  @override
  String get messagesGreetingHello => 'Hello there';

  @override
  String get messagesGreetingHowAreYou => 'How are you?';

  @override
  String get previewsHubConversations => 'Conversations';

  @override
  String get discoverTrendingHashtag => 'Trending hashtag';

  @override
  String discoverHashtagVideos(String name, String count) {
    return '$name, $count videos';
  }

  @override
  String discoverBanner(int index, int total) {
    return 'Featured $index of $total';
  }

  @override
  String get discoverNoResultsTitle => 'No results';

  @override
  String discoverNoResultsBody(String query) {
    return 'Nothing in the test data matches $query.';
  }

  @override
  String get discoverClearSearch => 'Clear search';

  @override
  String discoverOpenVideo(int index, String name) {
    return 'Open video $index of $name';
  }

  @override
  String get reelsModeLabel => 'Show reels or posts';

  @override
  String get reelsModeReels => 'Reels';

  @override
  String get reelsModePosts => 'Posts';

  @override
  String get reelsTabFriends => 'Friends';

  @override
  String reelsCoins(String count) {
    return 'Coin balance, $count';
  }

  @override
  String get reelsSave => 'Save';

  @override
  String get reelsSaved => 'Saved';

  @override
  String get reelsNotInterested => 'Not interested';

  @override
  String get reelsProgress => 'Playback position';

  @override
  String postsLikes(String count) {
    return '$count likes';
  }

  @override
  String postsViewComments(String count) {
    return 'View all $count comments';
  }

  @override
  String get previewsHubReels => 'Reels and posts';

  @override
  String get previewsHubReelsTab => 'Reels tab (posts)';

  @override
  String get homeTabPosts => 'Posts';

  @override
  String get homeTabReels => 'Reels';

  @override
  String get homeReelsUnavailableTitle => 'Reels are coming';

  @override
  String get homeReelsUnavailableBody =>
      'Short vertical videos will appear here once reels launch. For now, watch live streams.';

  @override
  String get homeReelsEmptyTitle => 'No reels yet';

  @override
  String get homeReelsErrorTitle => 'Couldn\'t load reels';

  @override
  String homeReelBy(String name) {
    return 'Reel by $name';
  }

  @override
  String get liveHubJoin => 'Join live';

  @override
  String get liveHubLoadingMore => 'Loading more streams';

  @override
  String get homeShowReels => 'Show reels';

  @override
  String get homeShowPosts => 'Show posts';

  @override
  String get feedSeeMore => 'see more';

  @override
  String get feedPostVideo => 'Video';

  @override
  String feedPostCounts(String likes, String comments, String shares) {
    return '$likes likes, $comments comments, $shares shares';
  }

  @override
  String get homeFeedTrending => 'Trending';

  @override
  String homeFollowAuthor(String name) {
    return 'Follow $name';
  }

  @override
  String homeFollowingAuthor(String name) {
    return 'Following $name';
  }

  @override
  String get homeReelsFollowingUnavailableTitle =>
      'Reels from people you follow';

  @override
  String get homeReelsFollowingUnavailableBody =>
      'Reels from the people you follow will appear here once reels launch. For now, watch live streams.';

  @override
  String get homeReelsFollowingEmptyTitle =>
      'No reels from people you follow yet';

  @override
  String get feedPostMore => 'More options';

  @override
  String homeUnfollowAuthor(String name) {
    return 'Unfollow $name';
  }

  @override
  String get profileFollowers => 'Followers';

  @override
  String get profileFollowingCount => 'Following';

  @override
  String get profileNoPosts => 'No posts yet';

  @override
  String get profileNoReels => 'No reels yet';

  @override
  String get profileGridEmptyBody =>
      'When you share something, it will show up here.';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditShort => 'Edit profile';

  @override
  String get profileEditSave => 'Save';

  @override
  String get profileEditName => 'Name';

  @override
  String get profileEditUsername => 'Username';

  @override
  String get profileEditBio => 'Bio';

  @override
  String get profileEditPhoto => 'Change photo';

  @override
  String get profileEditLinks => 'Links';

  @override
  String get profileEditGender => 'Gender';

  @override
  String get profileEditCategory => 'Category';

  @override
  String get profileEditReorderGrid => 'Reorder grid';

  @override
  String get profileEditPrivacy => 'Account privacy';

  @override
  String get profilePrivacyPublic => 'Public';

  @override
  String get profilePrivacyPrivate => 'Private';

  @override
  String get profileEditSoon => 'Coming soon';

  @override
  String get profileSaved => 'Saved';

  @override
  String get profileNoSaved => 'Nothing saved yet';

  @override
  String get profileSavedEmptyBody =>
      'Save posts and reels to find them here. Only you can see what you save.';

  @override
  String get profileSavedComingTitle => 'Your saved posts and reels';

  @override
  String get profileSavedComingBody =>
      'Saving arrives with posts and reels. Only you will see what you save.';

  @override
  String get profileWatchLive => 'Watch live';

  @override
  String get profileOtherEmptyBody => 'Nothing shared yet.';

  @override
  String get profilePrivateTitle => 'This account is private';

  @override
  String get profilePrivateBody =>
      'Their posts, reels and stories are visible to approved followers only.';

  @override
  String get profileNotFoundTitle => 'This account isn\'t available';

  @override
  String get profileNotFoundBody =>
      'The link may be broken, or the account may have been removed.';

  @override
  String profileUnfollowConfirm(String name) {
    return 'Unfollow $name?';
  }

  @override
  String get previewsHubUserProfile => 'Public profile';

  @override
  String get profileBondsShow => 'Show family, couple and medals';

  @override
  String get profileBondsHide => 'Hide family, couple and medals';

  @override
  String get profileMessage => 'Message';

  @override
  String get chatUnavailable =>
      'Private messages aren\'t available yet. When they are, your conversation will appear here.';

  @override
  String get profileCopyUsername => 'Copy username';

  @override
  String get profileCopyLink => 'Copy profile link';

  @override
  String get profileReport => 'Report';

  @override
  String get profileCopied => 'Copied';

  @override
  String get welcomeBody =>
      'Live streams, reels, podcasts and gifts for your favourite creators. Come in and let your voice be heard.';

  @override
  String get authProviderGoogle => 'Google';

  @override
  String get authProviderApple => 'Apple';

  @override
  String get authSocialSoon => 'Soon';

  @override
  String authSocialSoonLabel(String provider) {
    return 'Continue with $provider, coming soon';
  }

  @override
  String get welcomeLiveChip => 'Live right now';

  @override
  String get welcomeHeadline1 => 'The whole';

  @override
  String get welcomeHeadline2 => 'world';

  @override
  String get welcomeHeadline3 => 'on air.';

  @override
  String get welcomeStart => 'Let\'s start';

  @override
  String get welcomeHaveAccount => 'I have an account · ';

  @override
  String get welcomeComment1 => 'Hi Kabi 🔥';

  @override
  String get welcomeComment2 => 'First time here 😍';

  @override
  String get welcomeComment3 => 'Kab kab 🎧';

  @override
  String get joinTitleLead => 'Let your voice';

  @override
  String get joinTitleAccent => 'reach the world';

  @override
  String get joinBody =>
      'Live streams, reels and podcasts in one place.\nWelcome to Kabso Live.';

  @override
  String get joinCreate => 'Create account';

  @override
  String get loginTitleLead => 'Ready to go ';

  @override
  String get loginTitleAccent => 'live?';

  @override
  String get kabiEmojiPickerTitle => 'Emojis';

  @override
  String get kabiEmojiButton => 'Emojis';

  @override
  String get emojiPackKabi => 'Kabi';

  @override
  String get emojiPackKiki => 'Kiki';

  @override
  String get emojiPackBoo => 'Boo';

  @override
  String get emojiPackPipo => 'Pipo';

  @override
  String get emojiPackDubi => 'Dubi';

  @override
  String get emojiPackGogo => 'Gogo';

  @override
  String get emojiPackLulu => 'Lulu';

  @override
  String get emojiPackNeno => 'Neno';

  @override
  String get emojiPackFlags => 'Flags';

  @override
  String get emojiKabiHi => 'Hi';

  @override
  String get emojiKabiLove => 'Love';

  @override
  String get emojiKabiLol => 'Laughing';

  @override
  String get emojiKabiWow => 'Wow';

  @override
  String get emojiKabiSad => 'Sad';

  @override
  String get emojiKabiAngry => 'Angry';

  @override
  String get emojiKabiWink => 'Wink';

  @override
  String get emojiKabiLive => 'Live';

  @override
  String get emojiKabiCool => 'Cool';

  @override
  String get emojiKabiDizzy => 'Dizzy';

  @override
  String get emojiKabiSleepy => 'Sleepy';

  @override
  String get emojiKabiSilly => 'Silly';

  @override
  String get emojiKabiShy => 'Shy';

  @override
  String get emojiKabiThink => 'Thinking';

  @override
  String get emojiKabiParty => 'Party';

  @override
  String get emojiKabiDead => 'Dying of laughter';

  @override
  String get emojiKabiMelt => 'Melting';

  @override
  String get emojiKabiKiss => 'Kiss';

  @override
  String get emojiKabiGift => 'Gift';

  @override
  String get emojiKabiFire => 'Fire';

  @override
  String get emojiKabiCrown => 'VIP';

  @override
  String get emojiKabiMoney => 'Money';

  @override
  String get emojiKabiSing => 'Singing';

  @override
  String get emojiKabiStar => 'Starstruck';

  @override
  String get emojiKikiHi => 'Hi';

  @override
  String get emojiKikiLove => 'Love';

  @override
  String get emojiKikiLol => 'Laughing';

  @override
  String get emojiKikiWow => 'Wow';

  @override
  String get emojiKikiSad => 'Sad';

  @override
  String get emojiKikiAngry => 'Angry';

  @override
  String get emojiKikiCool => 'Cool';

  @override
  String get emojiKikiSleepy => 'Sleepy';

  @override
  String get emojiKikiWink => 'Wink';

  @override
  String get emojiKikiKiss => 'Kiss';

  @override
  String get emojiKikiSing => 'Singing';

  @override
  String get emojiKikiShy => 'Shy';

  @override
  String get emojiKikiThink => 'Thinking';

  @override
  String get emojiKikiParty => 'Party';

  @override
  String get emojiKikiClap => 'Clapping';

  @override
  String get emojiKikiFire => 'Fire';

  @override
  String get emojiKikiOk => 'OK';

  @override
  String get emojiKikiDizzy => 'Dizzy';

  @override
  String get emojiBooBoo => 'Boo';

  @override
  String get emojiBooScared => 'Scared';

  @override
  String get emojiBooFade => 'Fading away';

  @override
  String get emojiBooPeek => 'Peeking';

  @override
  String get emojiBooSpin => 'Dancing';

  @override
  String get emojiBooLaugh => 'Laughing';

  @override
  String get emojiBooLove => 'Love';

  @override
  String get emojiBooCry => 'Crying';

  @override
  String get emojiBooSneaky => 'Sneaky';

  @override
  String get emojiBooSleep => 'Asleep';

  @override
  String get emojiBooShock => 'Shocked';

  @override
  String get emojiBooParty => 'Party';

  @override
  String get emojiPipoHi => 'Hi';

  @override
  String get emojiPipoChirp => 'Chirping';

  @override
  String get emojiPipoHungry => 'Hungry';

  @override
  String get emojiPipoCold => 'Cold';

  @override
  String get emojiPipoFly => 'Flying';

  @override
  String get emojiPipoLove => 'Love';

  @override
  String get emojiPipoCry => 'Crying';

  @override
  String get emojiPipoAngry => 'Angry';

  @override
  String get emojiPipoSleepy => 'Sleepy';

  @override
  String get emojiPipoYay => 'Yay';

  @override
  String get emojiPipoShy => 'Shy';

  @override
  String get emojiPipoWow => 'Wow';

  @override
  String get emojiDubiHug => 'Hug';

  @override
  String get emojiDubiThanks => 'Thanks';

  @override
  String get emojiDubiStrong => 'Strong';

  @override
  String get emojiDubiHoney => 'Honey';

  @override
  String get emojiDubiSleep => 'Asleep';

  @override
  String get emojiDubiGrr => 'Grumpy';

  @override
  String get emojiDubiLol => 'Laughing';

  @override
  String get emojiDubiLove => 'Love';

  @override
  String get emojiDubiCool => 'Cool';

  @override
  String get emojiDubiOk => 'OK';

  @override
  String get emojiDubiSad => 'Sad';

  @override
  String get emojiDubiClap => 'Clapping';

  @override
  String get emojiGogoHi => 'Hi';

  @override
  String get emojiGogoRoar => 'Roar';

  @override
  String get emojiGogoStomp => 'Stomping';

  @override
  String get emojiGogoHatch => 'Hatching';

  @override
  String get emojiGogoMunch => 'Munching';

  @override
  String get emojiGogoDance => 'Dancing';

  @override
  String get emojiGogoSneeze => 'Sneezing';

  @override
  String get emojiGogoCool => 'Cool';

  @override
  String get emojiGogoLove => 'Love';

  @override
  String get emojiGogoLol => 'Laughing';

  @override
  String get emojiGogoCry => 'Crying';

  @override
  String get emojiGogoWow => 'Wow';

  @override
  String get emojiLuluHi => 'Hi';

  @override
  String get emojiLuluSun => 'Sunny';

  @override
  String get emojiLuluRain => 'Rainy';

  @override
  String get emojiLuluThunder => 'Thunder';

  @override
  String get emojiLuluRainbow => 'Rainbow';

  @override
  String get emojiLuluSnow => 'Snow';

  @override
  String get emojiLuluWind => 'Windy';

  @override
  String get emojiLuluSleep => 'Asleep';

  @override
  String get emojiLuluLove => 'Love';

  @override
  String get emojiLuluWow => 'Wow';

  @override
  String get emojiLuluLol => 'Laughing';

  @override
  String get emojiLuluShy => 'Shy';

  @override
  String get emojiNenoHi => 'Hi';

  @override
  String get emojiNenoLove => 'Love';

  @override
  String get emojiNenoLol => 'Laughing';

  @override
  String get emojiNenoWow => 'Wow';

  @override
  String get emojiNenoCry => 'Crying';

  @override
  String get emojiNenoAngry => 'Angry';

  @override
  String get emojiNenoCool => 'Cool';

  @override
  String get emojiNenoThink => 'Thinking';

  @override
  String get emojiNenoWink => 'Wink';

  @override
  String get emojiNenoSleepy => 'Sleepy';

  @override
  String get emojiNenoMoney => 'Business';

  @override
  String get emojiNenoOk => 'OK';

  @override
  String get emojiNenoClap => 'Clapping';

  @override
  String get emojiNenoParty => 'Party';

  @override
  String get emojiNenoKiss => 'Kiss';

  @override
  String get emojiNenoBlush => 'Blushing';

  @override
  String get emojiNenoRose => 'Rose';

  @override
  String get emojiNenoHeartbeat => 'Heartbeat';

  @override
  String get emojiNenoFlirt => 'Flirting';

  @override
  String get emojiNenoMelt => 'Melting';

  @override
  String get emojiNenoIloveu => 'I love you';

  @override
  String get emojiNenoSerenade => 'Serenade';

  @override
  String get emojiFlagsJo => 'Jordan';

  @override
  String get emojiFlagsPs => 'Palestine';

  @override
  String get emojiFlagsSa => 'Saudi Arabia';

  @override
  String get emojiFlagsEg => 'Egypt';

  @override
  String get emojiFlagsIq => 'Iraq';

  @override
  String get emojiFlagsSy => 'Syria';

  @override
  String get emojiFlagsYe => 'Yemen';

  @override
  String get emojiFlagsAe => 'UAE';

  @override
  String get emojiFlagsKw => 'Kuwait';

  @override
  String get emojiFlagsQa => 'Qatar';

  @override
  String get emojiFlagsBh => 'Bahrain';

  @override
  String get emojiFlagsOm => 'Oman';

  @override
  String get emojiFlagsLb => 'Lebanon';

  @override
  String get emojiFlagsMa => 'Morocco';

  @override
  String get emojiFlagsDz => 'Algeria';

  @override
  String get emojiFlagsTn => 'Tunisia';

  @override
  String get emojiFlagsLy => 'Libya';

  @override
  String get emojiFlagsSd => 'Sudan';

  @override
  String get attachButton => 'Attach a photo or video';

  @override
  String get attachGallery => 'Photo or video from your library';

  @override
  String get attachTakePhoto => 'Take a photo';

  @override
  String get attachRecordVideo => 'Record a video';

  @override
  String get attachFailed =>
      'Couldn\'t open your photos or camera. Check the app\'s permissions in Settings.';

  @override
  String get attachPhotoLabel => 'Photo';

  @override
  String get attachPlayVideo => 'Play video';

  @override
  String get attachPause => 'Pause video';

  @override
  String get chatOnline => 'Online';

  @override
  String get chatToday => 'Today';

  @override
  String get chatStatusSent => 'Sent';

  @override
  String get chatStatusDelivered => 'Delivered';

  @override
  String get chatStatusRead => 'Read';

  @override
  String chatTyping(String name) {
    return '$name is typing';
  }

  @override
  String get conversationsSearch => 'Search conversations';

  @override
  String get conversationsActiveNow => 'Active now';

  @override
  String get conversationsFilterAll => 'All';

  @override
  String get conversationsFilterUnread => 'Unread';

  @override
  String get conversationsFilterGroups => 'Groups';

  @override
  String get conversationsFilterFavorites => 'Favorites';

  @override
  String get conversationsNoMatch => 'No conversations match';

  @override
  String get conversationsMuted => 'muted';

  @override
  String conversationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get conversationsNewMessage => 'New message';

  @override
  String get conversationsSearchPeople => 'Search people';

  @override
  String get chatGiftButton => 'Send a gift';

  @override
  String chatGiftTitle(String name) {
    return 'Send a gift to $name';
  }

  @override
  String get chatGiftQuantity => 'Quantity';

  @override
  String get chatGiftPick => 'Choose a gift';

  @override
  String chatGiftSendNamed(String gift) {
    return 'Send $gift';
  }

  @override
  String chatGiftYours(String gift) {
    return 'Your gift: $gift';
  }

  @override
  String chatGiftFrom(String name, String gift) {
    return 'Gift from $name: $gift';
  }

  @override
  String get chatGiftYoursCaption => 'Your gift';

  @override
  String chatGiftFromCaption(String name) {
    return 'Gift from $name';
  }

  @override
  String pkFinalRound(String time) {
    return 'Final round $time';
  }

  @override
  String get livePreviewMuted => 'Muted';

  @override
  String livePreviewGiftSent(String name, String gift) {
    return '$gift from $name';
  }

  @override
  String get livePreviewGallery => 'Gallery';

  @override
  String livePreviewGalleryProgress(String have, String total) {
    return 'Gift gallery $have of $total';
  }

  @override
  String get livePreviewGuests => 'Invite guests';

  @override
  String get previewsHubLivePk2 => 'PK 1 v 1';

  @override
  String get previewsHubLivePk4 => 'PK 2 v 2';

  @override
  String get pkBattleStart => 'Battle on';

  @override
  String get livePreviewPlayBattle => 'Play a battle animation (test)';

  @override
  String get livePreviewSimulateRound => 'Simulate a whole round';

  @override
  String get livePreviewJoinedLine => 'joined the live';

  @override
  String get livePreviewHostSettings => 'Host settings';

  @override
  String get livePreviewChatTextSize => 'Chat text size';

  @override
  String get livePreviewTextSmall => 'Small';

  @override
  String get livePreviewTextMedium => 'Medium';

  @override
  String get livePreviewTextLarge => 'Large';

  @override
  String liveViewersTab(String count) {
    return 'Viewers $count';
  }

  @override
  String get liveRankingTab => 'Contribution ranking';

  @override
  String get livePeriodDaily => 'Daily';

  @override
  String get livePeriodWeekly => 'Weekly';

  @override
  String get livePeriodMonthly => 'Monthly';

  @override
  String get liveRankingHelp => 'How is the ranking made?';

  @override
  String get liveRankingHelpBody =>
      'Users are ranked by the points they earned in the selected period. Charm gifts count the gifts they received (Attractiveness); Wizard gifts count the lucky gifts they sent (Wizard). The two are never mixed. The countdown shows when the current round ends.';

  @override
  String get liveRankingEmpty => 'Send gifts to become a top supporter';

  @override
  String get liveRankingYou => 'You';

  @override
  String get liveGetRanked => 'Get ranked';

  @override
  String get livePeriodHourly => 'Hourly';

  @override
  String get livePeriodPrevious => 'Previous period';

  @override
  String get livePeriodNext => 'Next period';

  @override
  String get liveCountdown => 'Countdown';

  @override
  String get liveGiftFilter => 'Gift filter';

  @override
  String get liveGiftsAttraction => 'Charm gifts';

  @override
  String get liveGiftsWizard => 'Wizard gifts';

  @override
  String get liveRankingList => 'Ranking list';

  @override
  String get livePeriodOverall => 'All time';

  @override
  String get liveRankingAllTime => 'All-time ranking';

  @override
  String get liveHostRankingPlace => 'This host\'s place';

  @override
  String get liveHostRankingHelpBody =>
      'Hosts are ranked against each other by the gifts they received in the selected period: this hour, today, this month or of all time. The countdown shows when the current round ends.';

  @override
  String get levelsTitle => 'My levels';

  @override
  String get levelsPreparing =>
      'Levels are on their way. Your points will show here once gifts and games are switched on.';

  @override
  String get levelsUnavailable => 'Not active yet';

  @override
  String get levelsUnavailableBody =>
      'This level isn\'t active yet. Your points and level will show here once it is.';

  @override
  String get levelsNoLevel => 'No level yet';

  @override
  String levelsLevelNumber(int number) {
    return 'Level $number';
  }

  @override
  String levelsPoints(String points) {
    return '$points pts';
  }

  @override
  String get levelsMax => 'Top level reached';

  @override
  String get levelsCurrent => 'You\'re here';

  @override
  String get levelsLoadError => 'Couldn\'t load your levels';

  @override
  String levelsLv(int number) {
    return 'Lv.$number';
  }

  @override
  String levelsNeedXp(String points) {
    return 'Need $points experience to the next level';
  }

  @override
  String get levelsCategories => 'Level categories';

  @override
  String get levelsHowItGrows => 'How it grows';

  @override
  String get levelsTiers => 'Badges by level';

  @override
  String levelsTierRange(int from, int to) {
    return 'Lv.$from–$to';
  }

  @override
  String get levelsTierFrame => 'Comes with an avatar frame';

  @override
  String get levelsTierCurrent => 'Current';

  @override
  String get levelsTierOpen => 'Open';

  @override
  String get levelsTierLocked => 'Locked';

  @override
  String get levelsTierUnlocked => 'Unlocked';

  @override
  String levelsTierToUnlock(String points) {
    return '$points pts to unlock';
  }

  @override
  String levelsTierFrom(String points) {
    return 'From $points pts';
  }

  @override
  String get levelsTabAttractiveness => 'Charm';

  @override
  String get levelsTabSupport => 'Support';

  @override
  String get levelsTabWizard => 'Wizard';

  @override
  String get levelsTabGaming => 'Gaming';

  @override
  String get navMoments => 'Moments';

  @override
  String get navMessages => 'Messages';

  @override
  String get demoDataTitle => 'Demo data';

  @override
  String get demoDataBody =>
      'Test builds only: show the designed screens with labelled test data where no service exists yet. Turning it off signs the demo account out.';

  @override
  String get demoDataTry => 'Try with demo data';

  @override
  String get feedPostsLoadMoreFailed => 'Couldn\'t load more posts';

  @override
  String get feedPostLike => 'Like';

  @override
  String get feedPostUnlike => 'Unlike';

  @override
  String get feedPostSave => 'Save';

  @override
  String get feedPostUnsave => 'Remove from saved';

  @override
  String feedPostCommentCount(String count) {
    return '$count comments';
  }

  @override
  String feedPostShareCount(String count) {
    return '$count shares';
  }

  @override
  String feedPostRepostedBy(String name) {
    return '$name reposted';
  }

  @override
  String get feedPostPending =>
      'In review — only you can see it until it\'s reviewed';

  @override
  String get feedPostHide => 'Hide this post';

  @override
  String get feedPostHidden => 'Post hidden from your feed';

  @override
  String get feedPostReport => 'Report post';

  @override
  String get feedPostReportTitle => 'Why are you reporting this post?';

  @override
  String get feedPostReported => 'Thanks, we received your report';

  @override
  String get feedPostDelete => 'Delete post';

  @override
  String get feedPostDeleteConfirm => 'Delete this post for good?';

  @override
  String get feedPostDeleted => 'Post deleted';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonNudity => 'Nudity or sexual content';

  @override
  String get reportReasonViolence => 'Violence';

  @override
  String get reportReasonHate => 'Hate speech';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonIllegal => 'Illegal content';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get errorMediaUploadsUnavailable =>
      'Photo uploads aren\'t available right now.';

  @override
  String get errorMediaInvalid =>
      'We couldn\'t read that photo. Try another one.';

  @override
  String get errorPinLimitReached => 'You can pin up to 3 posts.';

  @override
  String get errorReportAlreadyResolved => 'This report was already handled.';

  @override
  String get createTitle => 'New post';

  @override
  String get createShare => 'Share';

  @override
  String get createTextHint => 'Write a caption…';

  @override
  String get createLocationHint => 'Add a place (optional)';

  @override
  String get createAddPhotos => 'Add photos';

  @override
  String get createRemovePhoto => 'Remove photo';

  @override
  String createPhotoNumber(int index) {
    return '$index';
  }

  @override
  String createPhotoLabel(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String createUploading(int current, int total) {
    return 'Uploading photos ($current of $total)…';
  }

  @override
  String get createPublishing => 'Sharing…';

  @override
  String get createPosted => 'Your post is live';

  @override
  String get createPostedInReview =>
      'Shared. Others will see it once the photos are reviewed';

  @override
  String get createPhotosReviewNote =>
      'Posts with photos appear to others after review.';

  @override
  String get createPhotoUnsupported =>
      'This photo format isn\'t supported. Use JPEG, PNG or WebP.';

  @override
  String get createPhotoTooLarge => 'This photo is larger than 15 MB.';

  @override
  String createPhotoTooMany(int max) {
    return 'You can add up to $max photos.';
  }

  @override
  String get createPhotoAccessDenied =>
      'Can\'t open your photos. Allow access in Settings.';

  @override
  String get createUploadsUnavailable =>
      'Photo uploads aren\'t available right now. Remove the photos to share text only, or try later.';

  @override
  String get createPhotoInvalid =>
      'One of the photos couldn\'t be processed. Remove it and try again.';

  @override
  String get createSubtitle => 'Share your moments with your followers';

  @override
  String get createClose => 'Close';

  @override
  String get createDiscardTitle => 'Discard this post?';

  @override
  String get createDiscardBody =>
      'The text and photos you added will be removed.';

  @override
  String get createDiscard => 'Discard';

  @override
  String get createKeepEditing => 'Keep editing';

  @override
  String get createAddMore => 'Add more';

  @override
  String createUpTo(int max) {
    return 'Up to $max photos';
  }

  @override
  String get createEmoji => 'Add an emoji';

  @override
  String get createAddHashtag => 'Add a hashtag';

  @override
  String get createTypePhotos => 'Photos';

  @override
  String get createSoon => 'Coming soon';

  @override
  String get createPlaceTitle => 'Place';

  @override
  String get createPlaceSubtitle => 'Add a place';

  @override
  String get createPlaceSave => 'Save';

  @override
  String get createAudienceTitle => 'Who can see this post?';

  @override
  String get createAudiencePublic => 'Public - everyone can see it';

  @override
  String get createAudiencePrivate => 'Private - only your followers';

  @override
  String get createAudienceExplain =>
      'Who sees your posts follows your account privacy. Change it in Settings.';

  @override
  String get createAudienceSettings => 'Open settings';

  @override
  String get createMentionTitle => 'Mention people';

  @override
  String get createMentionSubtitle => 'Add people';

  @override
  String get createMentionSome => 'You mentioned people in the text';

  @override
  String get createMentionSearchHint => 'Search by username or name';

  @override
  String get createMentionStart => 'Type to find people';

  @override
  String get createMentionNone => 'No results';

  @override
  String get createMentionFailed => 'Search failed. Try again.';

  @override
  String get createHashtagsTitle => 'Add hashtags';

  @override
  String get createAdvancedTitle => 'More options';

  @override
  String get createAdvancedSubtitle => 'Comments and like count';

  @override
  String get createCommentsOn => 'Allow comments';

  @override
  String get createWhoEveryone => 'Everyone can comment';

  @override
  String get createWhoFollowers => 'Your followers only';

  @override
  String get createWhoNobody => 'No one';

  @override
  String get createHideLikes => 'Hide the like count';

  @override
  String get createMediaSubtitle => 'Choose one or more photos';

  @override
  String get createNext => 'Next';

  @override
  String get createBack => 'Back';

  @override
  String get createTabAll => 'All';

  @override
  String get createTabVideo => 'Video';

  @override
  String get createSelected => 'Selected';

  @override
  String createSelectUpTo(int max) {
    return 'You can select up to $max photos';
  }

  @override
  String get createStepMedia => 'Media';

  @override
  String get createStepDetails => 'Details';

  @override
  String createStepOf(int step, int total, String label) {
    return 'Step $step of $total: $label';
  }

  @override
  String get createLongPressReorder => 'Long-press and drag to reorder';

  @override
  String get createAiCaption => 'Suggest a caption with AI';

  @override
  String get createHashtagsExample => 'e.g. #Petra #travel #Jordan';

  @override
  String get createLibraryUnsupported =>
      'The photo gallery isn\'t available here. Choose photos from your device.';

  @override
  String get createLibraryDenied =>
      'Allow Kabso to access your photos to choose them here, or pick from your device.';

  @override
  String get createLibraryFailed => 'Couldn\'t open your photo gallery.';

  @override
  String get createLibraryEmpty => 'There are no photos on this device.';

  @override
  String get createLibraryLimited => 'Kabso sees only some of your photos.';

  @override
  String get createLibraryManage => 'Manage';

  @override
  String get createLibraryAllow => 'Allow access';

  @override
  String get createPickFromDevice => 'Choose from device';

  @override
  String get createLibraryPhoto => 'Gallery photo';

  @override
  String get commentsEmpty => 'No comments yet';

  @override
  String get commentsEmptyHint => 'Be the first to comment.';

  @override
  String get commentsFailed => 'Couldn\'t load the comments.';

  @override
  String get commentsMoreFailed => 'Couldn\'t load more.';

  @override
  String commentsReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get commentsCancelReply => 'Cancel reply';

  @override
  String get commentsClosed => 'Comments are turned off for this post.';

  @override
  String get commentsNotAllowed => 'You can\'t comment on this post.';

  @override
  String get commentsPinned => 'Pinned';

  @override
  String get commentsPin => 'Pin comment';

  @override
  String get commentsUnpin => 'Unpin';

  @override
  String get commentsDelete => 'Delete comment';

  @override
  String get commentsDeleteTitle => 'Delete this comment?';

  @override
  String get commentsDeleteWithReplies => 'Its replies will be deleted too.';

  @override
  String get commentsDeleted => 'Comment deleted';

  @override
  String get commentsReport => 'Report comment';

  @override
  String get commentsReportTitle => 'Why are you reporting this comment?';

  @override
  String get commentsMore => 'Comment options';

  @override
  String commentsMoreReplies(int count) {
    return 'View more replies ($count)';
  }

  @override
  String get commentsOpen => 'View comments';

  @override
  String get postTitle => 'Post';

  @override
  String get postUnavailableTitle => 'This post isn\'t available';

  @override
  String get postUnavailableBody =>
      'It may have been deleted, or its owner does not share it with you.';

  @override
  String get profileGridPinned => 'Pinned';

  @override
  String get profileGridOpenPost => 'Open post';

  @override
  String get searchHint => 'Search people, hashtags or posts';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchTabUsers => 'Accounts';

  @override
  String get searchTabHashtags => 'Hashtags';

  @override
  String get searchTabPosts => 'Posts';

  @override
  String get searchPromptTitle => 'Search Kabso';

  @override
  String get searchPromptBody =>
      'Type a name, a hashtag or a word from a post.';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String hashtagPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '$count post',
    );
    return '$_temp0';
  }

  @override
  String get hashtagRecent => 'Recent';

  @override
  String get hashtagTop => 'Top';

  @override
  String get hashtagNotFoundTitle => 'No posts with this hashtag';

  @override
  String get hashtagNotFoundBody =>
      'This hashtag isn\'t on any visible post yet.';

  @override
  String get hashtagEmpty => 'No posts here yet';

  @override
  String hashtagLabel(String tag) {
    return '#$tag';
  }

  @override
  String get safetyBlock => 'Block';

  @override
  String safetyBlockUser(String name) {
    return 'Block $name';
  }

  @override
  String safetyBlockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get safetyBlockBody =>
      'Neither of you will see the other\'s posts, comments or profile, and follows between you are removed. You can unblock in Settings.';

  @override
  String safetyBlocked(String name) {
    return '$name is blocked';
  }

  @override
  String get safetyUnblock => 'Unblock';

  @override
  String safetyUnblocked(String name) {
    return '$name is unblocked';
  }

  @override
  String safetyMuteUser(String name) {
    return 'Mute $name';
  }

  @override
  String safetyMuted(String name) {
    return '$name is muted: their posts leave your feeds';
  }

  @override
  String get safetyUndo => 'Undo';

  @override
  String get safetyReportUser => 'Report account';

  @override
  String get safetyReportTitle => 'Why are you reporting this account?';

  @override
  String get safetySection => 'Privacy and safety';

  @override
  String get safetyPrivacy => 'Privacy';

  @override
  String get safetyBlockedAccounts => 'Blocked accounts';

  @override
  String get safetyNoBlocked => 'You have not blocked anyone';

  @override
  String get safetyNoBlockedBody =>
      'People you block appear here; you can unblock them any time.';

  @override
  String get privacyMentionTitle => 'Who can mention you';

  @override
  String get privacyMentionEveryone => 'Everyone';

  @override
  String get privacyMentionFollowing => 'Only people you follow';

  @override
  String get privacyMentionNobody => 'No one';

  @override
  String get privacyCommentTitle => 'Who can comment on your new posts';

  @override
  String get privacyCommentHint =>
      'You can change it for each post in “More options”.';

  @override
  String get privacySaved => 'Saved';

  @override
  String get safetyMutedAccounts => 'Muted accounts';

  @override
  String get safetyNoMuted => 'You have not muted anyone';

  @override
  String get safetyNoMutedBody =>
      'People you mute appear here; you can unmute them any time. No one is told you muted them.';

  @override
  String get safetyUnmute => 'Unmute';

  @override
  String safetyUnmuteUser(String name) {
    return 'Unmute $name';
  }

  @override
  String safetyUnmuted(String name) {
    return '$name is unmuted';
  }

  @override
  String get likersTitle => 'Likes';

  @override
  String get likersOpen => 'Show who liked this';

  @override
  String get likersEmpty => 'No likes yet';

  @override
  String get likersEmptyBody =>
      'When someone likes this post, they appear here.';

  @override
  String get likersHiddenTitle => 'Likes are hidden';

  @override
  String get likersHiddenBody =>
      'The author hid the like count, so only they can see who liked it.';

  @override
  String get feedPostRepost => 'Repost';

  @override
  String get feedPostUnrepost => 'Undo repost';

  @override
  String get feedPostReposted => 'Reposted to your followers';

  @override
  String get feedPostUnreposted => 'Repost removed';

  @override
  String get feedPostRepostRefused => 'This post can\'t be reposted';

  @override
  String get profileReposts => 'Reposts';

  @override
  String get profileNoReposts => 'No reposts yet';

  @override
  String get profileRepostsEmptyBody =>
      'Posts reposted from this profile appear here.';

  @override
  String get feedPostPin => 'Pin to profile';

  @override
  String get feedPostUnpin => 'Unpin from profile';

  @override
  String get feedPostPinned => 'Pinned to your profile';

  @override
  String get feedPostUnpinned => 'Unpinned';

  @override
  String get feedPostEdit => 'Edit';

  @override
  String feedPostTimeEdited(String time) {
    return '$time · Edited';
  }

  @override
  String get editPostTitle => 'Edit post';

  @override
  String get editPostSave => 'Save';

  @override
  String get editPostSaved => 'Changes saved';

  @override
  String get editPostPhotosFixed => 'Photos can\'t be changed after posting.';

  @override
  String get editPostTextRequired => 'A text post needs some text.';

  @override
  String get editPostDiscardTitle => 'Discard changes?';

  @override
  String get editPostKeep => 'Keep editing';

  @override
  String get editPostDiscard => 'Discard';

  @override
  String get editPostNoPlace => 'No location';

  @override
  String get editPostRemovePlace => 'Remove location';

  @override
  String get createScheduleTitle => 'When to post';

  @override
  String get createScheduleNow => 'Now';

  @override
  String createScheduleAt(String date, String time) {
    return '$date, $time';
  }

  @override
  String get createScheduleAction => 'Schedule';

  @override
  String get createScheduleClear => 'Post now instead';

  @override
  String get createScheduleWindow =>
      'Pick a time at least 5 minutes ahead and within 30 days.';

  @override
  String createScheduled(String when) {
    return 'Scheduled for $when';
  }

  @override
  String get createSaveDraft => 'Save draft';

  @override
  String get createDiscardOrDraftBody =>
      'Save it as a draft to finish later, or discard it.';

  @override
  String get createDraftSaved => 'Draft saved';

  @override
  String get draftsTitle => 'Drafts and scheduled';

  @override
  String get draftsTabDrafts => 'Drafts';

  @override
  String get draftsTabScheduled => 'Scheduled';

  @override
  String get draftsEmpty => 'No drafts';

  @override
  String get draftsEmptyBody =>
      'When you close a post, you can save it as a draft.';

  @override
  String get scheduledEmpty => 'Nothing scheduled';

  @override
  String get scheduledEmptyBody =>
      'Choose \"When to post\" while creating a post to schedule it.';

  @override
  String draftsSavedOn(String when) {
    return 'Saved $when';
  }

  @override
  String draftsPublishesOn(String when) {
    return 'Posts $when';
  }

  @override
  String get draftsNoText => 'No caption';

  @override
  String get draftsDeleteConfirm => 'Delete this draft?';

  @override
  String get draftsDeleted => 'Deleted';

  @override
  String get editPostPublishNow => 'Post now';

  @override
  String get editPostSchedule => 'Schedule';

  @override
  String get editPostReschedule => 'Change time';

  @override
  String get editPostToDrafts => 'Move to drafts';

  @override
  String get editPostPublished => 'Your post is live';

  @override
  String get editPostMovedToDrafts => 'Moved to drafts';

  @override
  String get editPostDraftBadge => 'Draft';

  @override
  String editPostScheduledBadge(String when) {
    return 'Scheduled: $when';
  }

  @override
  String get storyYourStory => 'Your story';

  @override
  String get storyAdd => 'Add a story';

  @override
  String storyOpen(String name) {
    return 'Open $name\'s story';
  }

  @override
  String get storyMore => 'Story options';

  @override
  String get storyClose => 'Close';

  @override
  String get storyDelete => 'Delete story';

  @override
  String get storyDeleteConfirm => 'Delete this story?';

  @override
  String get storyDeleted => 'Story deleted';

  @override
  String get storyReport => 'Report story';

  @override
  String get storyReportTitle => 'Why are you reporting this story?';

  @override
  String get storyReported => 'Thanks, we got your report';

  @override
  String storyPhotoOf(String name) {
    return '$name\'s story';
  }

  @override
  String storyViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count views',
      one: '$count view',
    );
    return '$_temp0';
  }

  @override
  String get storyNoViewers => 'No views yet';

  @override
  String get storyNoViewersBody =>
      'People who view your story appear here for 48 hours after you post it.';

  @override
  String get storyNewTitle => 'New story';

  @override
  String get storyNewBody =>
      'One photo that stays for 24 hours, with an optional short text.';

  @override
  String get storyPickPhoto => 'Choose a photo';

  @override
  String get storyChangePhoto => 'Change photo';

  @override
  String get storyShare => 'Share';

  @override
  String get storyShared => 'Your story is up';

  @override
  String get storyTextHint => 'Add text (optional)';

  @override
  String get storyPreview => 'Story preview';

  @override
  String get storyArchiveTitle => 'Story archive';

  @override
  String get storyArchiveEmpty => 'No stories yet';

  @override
  String get storyArchiveEmptyBody =>
      'Your stories are kept here after they end; only you can see them.';

  @override
  String storyArchiveCell(String date) {
    return 'Story from $date';
  }

  @override
  String get storyOpenOwn => 'Open your story';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsBell(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '$count unread notification',
      zero: '$count unread notifications',
    );
    return '$_temp0';
  }

  @override
  String notifActors(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name and $count others',
      one: '$name and $count other',
      zero: '$name',
    );
    return '$_temp0';
  }

  @override
  String notifLikePost(String who) {
    return '$who liked your post';
  }

  @override
  String notifLikeComment(String who) {
    return '$who liked your comment';
  }

  @override
  String notifComment(String who) {
    return '$who commented on your post';
  }

  @override
  String notifReply(String who) {
    return '$who replied to your comment';
  }

  @override
  String notifMentionPost(String who) {
    return '$who mentioned you in a post';
  }

  @override
  String notifMentionComment(String who) {
    return '$who mentioned you in a comment';
  }

  @override
  String notifMentionStory(String who) {
    return '$who mentioned you in a story';
  }

  @override
  String notifFollow(String who) {
    return '$who started following you';
  }

  @override
  String notifRepost(String who) {
    return '$who reposted your post';
  }

  @override
  String get notifPostPublished => 'Your scheduled post is now live';

  @override
  String get notifRemovedPost =>
      'Your post was removed for breaking the community guidelines';

  @override
  String get notifRemovedComment =>
      'Your comment was removed for breaking the community guidelines';

  @override
  String get notifRemovedStory =>
      'Your story was removed for breaking the community guidelines';

  @override
  String get notifSectionToday => 'Today';

  @override
  String get notifSectionWeek => 'This week';

  @override
  String get notifSectionEarlier => 'Earlier';

  @override
  String get notifUnread => 'Unread';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsEmptyBody =>
      'Likes, comments, mentions and new followers will show up here.';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsSettings => 'Notification settings';

  @override
  String get notifSettingLikes => 'Likes';

  @override
  String get notifSettingLikesBody => 'On your posts and comments';

  @override
  String get notifSettingComments => 'Comments and replies';

  @override
  String get notifSettingMentions => 'Mentions';

  @override
  String get notifSettingFollows => 'New followers';

  @override
  String get notifSettingReposts => 'Reposts';

  @override
  String get notifSettingsHint =>
      'Notifications appear in the app. You are always told when a scheduled post goes live or your content is removed.';

  @override
  String get notifSettingsSaved => 'Saved';

  @override
  String get errorLiveHostingNotAllowed => 'Your account can\'t go live yet.';

  @override
  String get errorLiveGuestsNotAllowed =>
      'The host lets only signed-in people watch this live.';

  @override
  String get createModePost => 'Post';

  @override
  String get createModeStory => 'Story';

  @override
  String get createModeLive => 'LIVE';

  @override
  String get goLiveTitleHint => 'Add a live title';

  @override
  String get goLiveTitleRequired => 'Add a title for your live first.';

  @override
  String get goLiveFlip => 'Flip';

  @override
  String get goLiveMic => 'Mic';

  @override
  String get goLiveMicOff => 'Muted';

  @override
  String get goLiveGuests => 'Guests';

  @override
  String get goLiveGuestsOnHint => 'People without an account can watch';

  @override
  String get goLiveGuestsOffHint => 'Only signed-in people can watch';

  @override
  String get goLiveGuestsOn => 'Guests can watch';

  @override
  String get goLiveGuestsOff =>
      'Guests removed; only signed-in people can watch';

  @override
  String get goLiveNoCategory => 'No category';

  @override
  String get goLiveStart => 'Go LIVE';

  @override
  String get goLiveStarting => 'Starting your live…';

  @override
  String get goLiveEnd => 'End';

  @override
  String get goLiveEndConfirmTitle => 'End your live?';

  @override
  String get goLiveEndConfirmBody =>
      'Viewers will see that your live has ended.';

  @override
  String get goLiveEndConfirm => 'End live';

  @override
  String get goLiveKeepGoing => 'Keep going';

  @override
  String goLiveElapsed(String duration) {
    return 'Live for $duration';
  }

  @override
  String get goLiveEndedTitle => 'Your live has ended';

  @override
  String goLiveEndedDuration(String duration) {
    return 'Duration $duration';
  }

  @override
  String get goLiveDone => 'Done';

  @override
  String get goLiveCameraDeniedTitle => 'Allow camera and microphone';

  @override
  String get goLiveCameraDeniedBody =>
      'Kabso Live needs them to show you live. Allow access in your settings, then try again.';

  @override
  String get goLiveCameraUnavailableTitle => 'Camera unavailable';

  @override
  String get goLiveCameraUnavailableBody =>
      'No camera or microphone was found, or another app is using it.';

  @override
  String get goLiveNotAllowedTitle => 'Going live needs a host account';

  @override
  String get goLiveNotAllowedBody =>
      'Hosts go live through a Kabso Live host agency or after verifying their identity. Sign-up is coming soon.';

  @override
  String get goLiveUnavailableTitle => 'Going live isn\'t available yet';

  @override
  String get goLiveModeMulti => 'Multi-guest';

  @override
  String get goLiveModeSolo => 'LIVE';

  @override
  String get goLiveModeAudio => 'Audio LIVE';

  @override
  String goLiveSeat(int number) {
    return 'Seat $number';
  }

  @override
  String get goLiveHostTag => 'Host';

  @override
  String goLiveSeatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return '$_temp0';
  }

  @override
  String get goLiveBeauty => 'Beauty';

  @override
  String get goLiveBeautyTitle => 'Beauty';

  @override
  String get goLiveBeautySwitch => 'Beauty on';

  @override
  String get goLiveBeautySmooth => 'Smooth skin';

  @override
  String get goLiveBeautyBrighten => 'Brighten';

  @override
  String get goLiveBeautyUnsupported =>
      'Beauty isn\'t available on this device yet.';

  @override
  String get goLiveTheme => 'Theme';

  @override
  String get goLiveThemeTitle => 'Room theme';

  @override
  String get liveThemeClassic => 'Classic';

  @override
  String get liveThemeIcePalace => 'Ice palace';

  @override
  String get liveThemeDesertNight => 'Desert night';

  @override
  String get liveThemeRoseGarden => 'Rose garden';

  @override
  String get liveThemeSunsetSky => 'Sunset sky';

  @override
  String get liveThemeMoonPalace => 'Moon palace';

  @override
  String get liveThemeOceanDepths => 'Ocean depths';

  @override
  String get liveThemeGoldenHall => 'Golden hall';

  @override
  String get liveThemeGameArena => 'Game arena';

  @override
  String get liveThemeHeartGarden => 'Heart garden';

  @override
  String get liveThemeGalaxy => 'Galaxy';

  @override
  String get goLiveGuestsAllowedChip => 'Guests allowed';

  @override
  String get goLiveGuestsOffChip => 'Signed-in only';

  @override
  String get liveSeatRequest => 'Ask for a seat';

  @override
  String get liveSeatRequested => 'Requested · Cancel';

  @override
  String get liveSeatLeave => 'Leave seat';

  @override
  String get liveSeatInviteTitle => 'Invitation to a seat';

  @override
  String liveSeatInviteBody(String name) {
    return '$name invites you onto a seat.';
  }

  @override
  String get liveSeatInviteAccept => 'Join';

  @override
  String get liveSeatInviteDecline => 'Not now';

  @override
  String get liveHostAway => 'The host will be right back';

  @override
  String get liveSeatMutedByHost => 'The host muted you';

  @override
  String get liveSeatCaptureFailed =>
      'Couldn\'t start your camera or microphone.';

  @override
  String get liveSeatMute => 'Mute';

  @override
  String get liveSeatUnmute => 'Unmute';

  @override
  String get liveSeatRemove => 'Take off the seat';

  @override
  String get liveSeatLock => 'Lock the mic';

  @override
  String get liveSeatUnlock => 'Unlock the mic';

  @override
  String get liveSeatInvite => 'Invite a viewer';

  @override
  String get liveSeatMakeModerator => 'Make moderator';

  @override
  String get liveSeatRemoveModerator => 'Remove moderator';

  @override
  String get liveSeatModeratorTag => 'Moderator';

  @override
  String get liveSeatRequests => 'Requests';

  @override
  String get liveSeatRequestsTitle => 'Seat requests';

  @override
  String get liveSeatRequestsEmpty => 'No requests right now.';

  @override
  String get liveSeatAccept => 'Accept';

  @override
  String get liveSeatDecline => 'Decline';

  @override
  String get liveSeatInviteSheetTitle => 'Invite to a seat';

  @override
  String get liveSeatInviteEmpty => 'No signed-in viewers right now.';

  @override
  String get liveSeatInviteSend => 'Invite';

  @override
  String get liveSeatInvited => 'Invitation sent';

  @override
  String get liveSeats => 'Seats';

  @override
  String get liveSeatsTitle => 'Number of seats';

  @override
  String liveSeatGuestNumber(int number) {
    return 'Guest $number';
  }

  @override
  String get goLiveAudioHeadline => 'Start an audio live';

  @override
  String get goLiveAudioSubtitle =>
      'Share your voice and connect with your audience';

  @override
  String get goLiveChooseCategory => 'Choose a category';

  @override
  String get goLiveWhoCanWatch => 'Who can watch?';

  @override
  String get goLiveWatchEveryone => 'Everyone';

  @override
  String get goLiveWatchEveryoneHint => 'Even people without an account';

  @override
  String get goLiveWatchSignedIn => 'Signed-in only';

  @override
  String get goLiveWatchSignedInHint => 'Only people with an account';

  @override
  String get goLiveVoiceSettings => 'Voice settings';

  @override
  String get goLiveMicrophone => 'Microphone';

  @override
  String get goLiveMicrophoneHint => 'You can mute it any time';

  @override
  String get goLiveNoiseReduction => 'Noise reduction';

  @override
  String get goLiveNoiseReductionHint => 'A clearer voice in noisy places';

  @override
  String get goLiveVoiceEnhance => 'Voice enhancement';

  @override
  String get goLiveVoiceEnhanceHint => 'A balanced level with no echo';

  @override
  String get goLiveStartAudio => 'Start audio live';

  @override
  String get goLiveChangeTheme => 'Change theme';

  @override
  String get goLiveSeatsSection => 'Number of seats';

  @override
  String get goLiveMinimize => 'Minimize live';

  @override
  String get liveBgChannel => 'Live';

  @override
  String get liveBgHostTitle => 'Kabso: You\'re live';

  @override
  String get liveBgGuestTitle => 'You\'re on a seat in a live';

  @override
  String get liveBgListenerTitle => 'You\'re listening to a live';

  @override
  String get liveBgBody => 'Tap to return to the room';

  @override
  String get liveBgEnd => 'End live';

  @override
  String get liveBgLeave => 'Leave';

  @override
  String get goLiveBackToLive => 'Back to your live';

  @override
  String get goLiveAllCategories => 'View all';

  @override
  String goLiveRoomLook(String name) {
    return 'Room look: $name';
  }

  @override
  String get goLiveLiveType => 'Live type';

  @override
  String get goLiveMuteMic => 'Mute';

  @override
  String get goLiveUnmuteMic => 'Unmute';

  @override
  String get goLiveChat => 'Chat';

  @override
  String get goLivePk => 'PK challenge';

  @override
  String get goLivePkSoon => 'PK challenges aren\'t available yet.';

  @override
  String get goLiveChatHint => 'Say something…';

  @override
  String get goLiveChatSend => 'Send';

  @override
  String get goLiveChatPill => 'Chat…';

  @override
  String get goLiveShare => 'Share';

  @override
  String goLiveShareText(String title, String handle) {
    return 'I\'m live on Kabso Live: “$title” — follow $handle';
  }

  @override
  String get goLiveShareCopied => 'Live invite copied — paste it anywhere';

  @override
  String liveScore(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted points',
      one: '$formatted point',
    );
    return '$_temp0';
  }

  @override
  String get liveScoreTitle => 'Live points';

  @override
  String get liveScoreTaps => 'Taps';

  @override
  String get liveScoreSupport => 'Support';

  @override
  String get liveScoreHint =>
      'Each tap is 1 point and each support coin is 100 points. Support starts with gifts.';

  @override
  String get liveTapHint => 'Tap the live to cheer the host';

  @override
  String get errorLiveChatNotInRoom =>
      'You\'re not in this live right now. Open it again.';

  @override
  String get errorLiveChatMuted =>
      'The host or a moderator muted you in this live\'s chat.';

  @override
  String get errorLiveChatClosed => 'The host turned the chat off.';

  @override
  String get liveChatOff => 'Chat is off';

  @override
  String get liveChatMutedPill => 'You\'re muted in this live\'s chat';

  @override
  String get liveChatSignIn => 'Log in to chat';

  @override
  String get liveChatFailed => 'Not sent. Tap to retry';

  @override
  String get liveChatNewMessages => 'New messages ↓';

  @override
  String get liveChatRetry => 'Send again';

  @override
  String get liveChatDiscard => 'Remove';

  @override
  String get liveChatHostBadge => 'Host';

  @override
  String get liveChatModeratorBadge => 'Mod';

  @override
  String get liveChatViewProfile => 'View profile';

  @override
  String get liveChatDelete => 'Delete message';

  @override
  String get liveChatDeleted => 'Message deleted';

  @override
  String liveChatMuteUser(String name) {
    return 'Mute $name in chat';
  }

  @override
  String liveChatUnmuteUser(String name) {
    return 'Unmute $name';
  }

  @override
  String liveChatUserMuted(String name) {
    return '$name is muted in this live\'s chat';
  }

  @override
  String liveChatUserUnmuted(String name) {
    return '$name can chat again';
  }

  @override
  String liveSeatMuteUser(String name) {
    return 'Mute $name\'s mic';
  }

  @override
  String liveSeatUnmuteUser(String name) {
    return 'Unmute $name\'s mic';
  }

  @override
  String liveSeatUserMuted(String name) {
    return '$name\'s mic is muted';
  }

  @override
  String liveSeatUserUnmuted(String name) {
    return '$name\'s mic is on again';
  }

  @override
  String get liveChatReport => 'Report message';

  @override
  String get liveChatReportTitle => 'Why are you reporting this message?';

  @override
  String get liveChatTurnedOff => 'Chat is off. Viewers can\'t write.';

  @override
  String get liveChatTurnedOn => 'Chat is on';

  @override
  String liveChatLineLabel(String name, String text) {
    return '$name: $text';
  }

  @override
  String liveChatCharmLabel(int level) {
    return 'Charm level $level';
  }

  @override
  String liveChatSupportLabel(int level) {
    return 'Support level $level';
  }

  @override
  String liveChatFamilyLabel(String name, int level) {
    return 'Family $name, level $level';
  }

  @override
  String liveChatMedalsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medals',
      one: '$count medal',
    );
    return '$_temp0';
  }

  @override
  String get liveChatTool => 'Chat';

  @override
  String get liveToolsRoom => 'Room tools';

  @override
  String get liveToolsOther => 'Other tools';

  @override
  String get liveToolOn => 'On';

  @override
  String get liveToolOff => 'Off';

  @override
  String get liveToolsVoice => 'Voice';

  @override
  String get liveToolsViewers => 'Viewers';

  @override
  String get liveSeatGuestsTab => 'Guests';

  @override
  String get liveSeatGuestsEmpty => 'Nobody is on a seat right now';

  @override
  String get liveSeatInviteFriends => 'Invite friends';

  @override
  String get liveUserManage => 'Manage';

  @override
  String get liveUserViewProfile => 'View profile';

  @override
  String get liveUserFamily => 'Family';

  @override
  String get liveUserGiftWall => 'Gift wall';

  @override
  String get liveUserMedals => 'Medals';

  @override
  String get liveUserSoon => 'Soon';

  @override
  String liveUserBoxSoon(String box) {
    return '$box: coming soon';
  }

  @override
  String liveSeatNumberLabel(int number) {
    return 'Seat $number';
  }

  @override
  String get liveEditRoom => 'Edit room';

  @override
  String get liveEditRoomName => 'Room name';

  @override
  String get liveEditRoomCategory => 'Category';

  @override
  String get liveEditRoomTopic => 'Topic';

  @override
  String get liveEditRoomTopicHint => 'What are you talking about?';

  @override
  String get liveEditRoomSave => 'Save';

  @override
  String get liveEditRoomSaved => 'Room saved';

  @override
  String liveRoomTopic(String topic) {
    return 'Topic: $topic';
  }

  @override
  String get liveContributionTab => 'Contribution list';

  @override
  String get liveContributionEmpty =>
      'No contributions yet. Taps on the live count here.';

  @override
  String liveContributionRow(int rank, String name, String points) {
    return 'Rank $rank, $name, $points';
  }

  @override
  String get liveCoverEdit => 'Edit';

  @override
  String get liveCoverEditLabel => 'Edit the live cover';

  @override
  String get liveCoverSheetTitle => 'Live cover';

  @override
  String get liveCoverSheetBody =>
      'Shown on your live\'s card and in the room, every time you go live.';

  @override
  String get liveCoverChoose => 'Choose a photo';

  @override
  String get liveCoverRemove => 'Remove cover, use my picture';

  @override
  String get liveCoverUpdated => 'Live cover updated.';

  @override
  String get liveCoverRemoved => 'Cover removed; your picture is shown.';

  @override
  String get liveCoverUploading => 'Uploading the cover…';

  @override
  String get liveSettingsShare => 'Share';

  @override
  String get liveSettingsBlockedWords => 'Blocked words';

  @override
  String get liveSettingsSchedule => 'Live schedule';

  @override
  String get liveSettingsEventCenter => 'Event center';

  @override
  String get liveSettingsCreatorCenter => 'Creator center';

  @override
  String get liveSoon => 'Soon';

  @override
  String get liveRoomInfoChange => 'Change';

  @override
  String get liveRoomLevel => 'Room level';

  @override
  String get liveRoomSettings => 'Room settings';

  @override
  String get liveRoomTag => 'Tag';

  @override
  String get liveRoomNoTag => 'No tag';

  @override
  String get liveRoomAnnouncement => 'Announcement';

  @override
  String get liveRoomBoost => 'Boost my room';

  @override
  String get liveBlockedWordsHint =>
      'These words are hidden with *** in the chat of all your lives.';

  @override
  String get liveBlockedWordsAddHint => 'Add a word or short phrase';

  @override
  String get liveBlockedWordsAdd => 'Add';

  @override
  String get liveBlockedWordsFull => 'You\'ve reached 100 words';

  @override
  String get liveBlockedWordsEmpty => 'No blocked words yet.';

  @override
  String liveBlockedWordsRemove(String word) {
    return 'Remove $word';
  }

  @override
  String get liveRankTitle => 'Popularity rank';

  @override
  String get liveRankRich => 'Rich';

  @override
  String get liveRankHour => 'This hour';

  @override
  String get liveRankDay => 'Today';

  @override
  String get liveRankWeek => 'This week';

  @override
  String get liveRankEmpty => 'No points yet in this period.';

  @override
  String get liveRankLive => 'LIVE';

  @override
  String get liveRankChip => 'Room rank';

  @override
  String liveRankCountdown(String days, String hours, String minutes) {
    return 'Countdown: ${days}d ${hours}h ${minutes}m';
  }

  @override
  String liveRankRow(int rank, String name, String points) {
    return 'Rank $rank, $name, $points';
  }

  @override
  String notifLiveScheduled(String who, String time) {
    return '$who goes live at $time';
  }

  @override
  String get notifSettingLives => 'Scheduled lives';

  @override
  String get notifSettingLivesBody =>
      'When a host you follow is about to go live';

  @override
  String get errorLiveScheduleFull => 'You can schedule up to 10 lives.';

  @override
  String get liveScheduleHint =>
      'Your followers are reminded 15 minutes before. You start the live yourself.';

  @override
  String get liveScheduleEmpty => 'No lives scheduled.';

  @override
  String get liveScheduleAdd => 'Schedule a live';

  @override
  String get liveScheduleTitleHint => 'Live title';

  @override
  String get liveSchedulePickTime => 'Pick date and time';

  @override
  String get liveScheduleSave => 'Save';

  @override
  String get liveScheduleTooSoon => 'Pick a time at least 15 minutes from now.';

  @override
  String get liveScheduleTooFar => 'Pick a time within the next 30 days.';

  @override
  String liveScheduleRemove(String title) {
    return 'Cancel $title';
  }

  @override
  String liveScheduleWhen(String date, String time) {
    return '$date, $time';
  }

  @override
  String liveRoomNumber(String number) {
    return 'ID: $number';
  }

  @override
  String liveRoomLevelBadge(int level) {
    return 'Room level $level';
  }

  @override
  String get liveToolMusic => 'Music';

  @override
  String get liveToolSounds => 'Sounds';

  @override
  String get liveToolProgramList => 'Program list';

  @override
  String get liveToolShareScreen => 'Share screen';

  @override
  String get liveToolYoutube => 'YouTube';

  @override
  String get liveToolSinging => 'Singing';

  @override
  String get liveToolTopic => 'Topic';

  @override
  String get liveToolManagement => 'Management';

  @override
  String get liveToolAssistance => 'Live assistance';

  @override
  String get liveToolRecorder => 'Recorder';

  @override
  String get liveToolsFailed => 'That did not work. Try again.';

  @override
  String get liveToolsCancel => 'Cancel';

  @override
  String get liveToolsClose => 'Close';

  @override
  String get liveCam2JoinTile => '2nd camera';

  @override
  String get liveSecondCameraJoin => 'Join as second camera';

  @override
  String get liveCam2Intro =>
      'Stream from two devices: this phone, and a second camera on another phone or tablet signed in to the same account.';

  @override
  String get liveCam2Steps =>
      'On the second device: log in to the same account, open Go live, then “Join as second camera”, and enter the code.';

  @override
  String get liveCam2Layout =>
      'Viewers see one camera full screen and the other as a small picture they can drag and tap to swap.';

  @override
  String get liveCam2CreateCode => 'Create pairing code';

  @override
  String get liveCam2CodeLabel => 'Pairing code';

  @override
  String liveCam2CodeExpires(String time) {
    return 'Expires in $time';
  }

  @override
  String get liveCam2CodeOnce => 'Works once, and only for your account.';

  @override
  String get liveCam2CodeExpired => 'The code expired. Create a new one.';

  @override
  String get liveCam2NewCode => 'New code';

  @override
  String get liveCam2Cancel => 'Cancel the code';

  @override
  String get liveCam2Waiting => 'Waiting for the second device…';

  @override
  String get liveCam2Connected => 'Second camera connected';

  @override
  String get liveCam2MainLabel => 'Full screen for viewers';

  @override
  String get liveCam2MainHost => 'This phone';

  @override
  String get liveCam2MainSecond => 'Second camera';

  @override
  String get liveCam2MainNote =>
      'Each viewer can still swap the two on their own screen.';

  @override
  String get liveCam2End => 'Disconnect the second camera';

  @override
  String get liveCam2NotLive =>
      'Go live first, then connect your second device.';

  @override
  String get liveCam2InPk =>
      'The second camera is not available during a PK. Pair it again after the PK.';

  @override
  String get liveCam2NotSolo =>
      'A second camera works in a solo video live only.';

  @override
  String get liveCam2Busy => 'This live already has a second camera.';

  @override
  String get liveCam2Unavailable =>
      'This live cannot take a second camera now: it ended or is in a PK.';

  @override
  String get liveCam2Swap => 'Swap the cameras';

  @override
  String get liveCam2JoinIntro =>
      'Log in to the account you stream from, then enter the code shown in “Dual” on your main device.';

  @override
  String get liveCam2JoinPermissions =>
      'Kabso Live will ask for the camera and the microphone. The microphone starts muted; this device shows no chat.';

  @override
  String get liveCam2JoinButton => 'Join';

  @override
  String get liveCam2CodeInvalid =>
      'That code is wrong or expired. Create a new one on your main device.';

  @override
  String get liveCam2TooMany => 'Too many tries. Wait a little and try again.';

  @override
  String get liveCam2Failed => 'Could not connect. Try again.';

  @override
  String get liveCam2PermissionDenied =>
      'Allow Kabso to use the camera and microphone in the device settings.';

  @override
  String get liveCam2OnAir => 'Second camera · live';

  @override
  String get liveCam2Connecting => 'Connecting…';

  @override
  String get liveCam2Flip => 'Flip';

  @override
  String get liveCam2MicOn => 'Unmute';

  @override
  String get liveCam2MicOff => 'Mute';

  @override
  String get liveCam2Leave => 'Leave';

  @override
  String get liveCam2KeepOpen =>
      'Keep this screen open: it stays on while you stream. If you leave the app, this camera pauses until you come back.';

  @override
  String get liveCam2CopyLog => 'Copy diagnostics log';

  @override
  String get liveCam2LogCopied =>
      'Diagnostics log copied. Paste it in a message to support.';

  @override
  String get liveCam2AwakeFailed =>
      'Couldn\'t keep the screen on automatically. Touch it now and then so it doesn\'t turn off.';

  @override
  String get liveCam2BackgroundFailed =>
      'The live\'s background service couldn\'t start. Keep the app open on this screen.';

  @override
  String get liveCam2CameraSlow =>
      'The camera isn\'t responding right now. If the picture stays frozen, tap Flip, or leave and join again.';

  @override
  String get liveCam2FilterFailed =>
      'Couldn\'t apply the filter on this device, so the picture stays without a filter.';

  @override
  String get liveCam2Ended =>
      'The second camera ended: the live ended or the main device disconnected it.';

  @override
  String get liveMusicRightsTitle => 'Music rights';

  @override
  String get liveMusicRightsBody =>
      'Make sure you hold the rights to play this music. Playing copyrighted music without a licence is not allowed.';

  @override
  String get liveMusicRightsAccept => 'I confirm';

  @override
  String get liveMusicAdd => 'Add audio files';

  @override
  String get liveMusicPickerNote =>
      'Opens your device’s file picker; Kabso sees only the files you choose, and they are never uploaded.';

  @override
  String get liveMusicMixNote =>
      'The music is mixed under your voice in your live and dips while you speak. You don’t hear it from your phone, and muting the microphone mutes it too.';

  @override
  String get liveMusicEmpty =>
      'No music yet. Nothing plays until you choose a file and press play.';

  @override
  String get liveMusicNothing => 'Nothing playing';

  @override
  String get liveMusicPlay => 'Play';

  @override
  String get liveMusicPause => 'Pause';

  @override
  String get liveMusicNext => 'Next';

  @override
  String get liveMusicRemove => 'Remove';

  @override
  String get liveMusicVolume => 'Music volume';

  @override
  String get liveMusicDucking => 'Lower the music while I speak';

  @override
  String liveMusicQueueFull(int max) {
    return 'The queue is full (up to $max files).';
  }

  @override
  String get liveMusicUnreadable => 'This file cannot be played.';

  @override
  String get liveMusicNotReady =>
      'Music is mixed into the live microphone: turn the microphone on and wait for the live to start, then play it.';

  @override
  String get liveMusicUnsupportedFormat =>
      'Your phone can’t play this file’s format. Try an MP3 or M4A file.';

  @override
  String get liveMusicMicOff =>
      'Your microphone is muted: viewers won’t hear the music.';

  @override
  String get liveMusicUnsupportedIos =>
      'Music is not available on iOS in this version: mixing a file into the live microphone needs an iOS audio module that is not built yet.';

  @override
  String get liveMusicUnsupportedWeb =>
      'Music is not available on the web. Use the Android app.';

  @override
  String get liveClipTitle => 'Record a clip';

  @override
  String get liveClipIntro =>
      'Record up to 60 seconds of your live as viewers see it: your camera and your voice. You can stop earlier.';

  @override
  String get liveClipTransparency =>
      'Viewers see “Recording” while you record.';

  @override
  String get liveClipLimits =>
      'The clip has no second camera, music, comments or gifts on screen.';

  @override
  String get liveClipStart => 'Start recording';

  @override
  String get liveClipStop => 'Stop recording';

  @override
  String get liveClipRec => 'REC';

  @override
  String liveClipRecSemantics(int seconds) {
    return 'Recording, $seconds seconds left';
  }

  @override
  String get liveClipViewerBadge => 'Recording';

  @override
  String get liveClipPreviewTitle => 'Your clip';

  @override
  String get liveClipCaption => 'Caption (optional)';

  @override
  String get liveClipSave => 'Save to device';

  @override
  String get liveClipSavedShort => 'Saved';

  @override
  String get liveClipSaved => 'Saved to your gallery.';

  @override
  String get liveClipSaveFailed =>
      'Could not save. Allow Kabso to add photos and videos in the settings.';

  @override
  String get liveClipPostReel => 'Post as reel';

  @override
  String get liveClipPostFailed =>
      'Could not post. The clip is kept; try again.';

  @override
  String get liveClipDiscard => 'Discard';

  @override
  String get liveClipFailed => 'Recording could not start on this device.';

  @override
  String get liveClipTooShort =>
      'The clip is shorter than a second; record a longer one.';

  @override
  String get liveClipUnreadable => 'The clip could not be read.';

  @override
  String get liveClipUnsupportedIos =>
      'Clip recording is not available on iOS in this version: the WebRTC recorder there does not capture the live’s sound.';

  @override
  String get liveClipUnsupportedWeb =>
      'Clip recording is not available on the web.';

  @override
  String get liveClipNoCamera => 'Turn the camera on to record a clip.';

  @override
  String get liveToolNewcomers => 'Newcomers';

  @override
  String get liveToolDataCenter => 'Data center';

  @override
  String get liveToolLiveTime => 'Live time';

  @override
  String get errorInsufficientCoins =>
      'You need 15 coins for a public message. For now the team adds coins; there is no purchase yet.';

  @override
  String get liveBulletToggle => 'Public message';

  @override
  String liveBulletHint(String coins) {
    return 'Public message for 15 coins · You have $coins';
  }

  @override
  String get liveBulletHintNoBalance => 'Public message for 15 coins';

  @override
  String get liveBulletSent => 'Your public message went to every live';

  @override
  String liveBulletLabel(String name, String text) {
    return 'Public message from $name: $text';
  }

  @override
  String get liveVoiceRecord => 'Voice clip';

  @override
  String get liveVoiceSend => 'Send voice clip';

  @override
  String get liveVoiceCancel => 'Cancel recording';

  @override
  String liveVoiceRecording(String time) {
    return 'Recording $time of 0:30';
  }

  @override
  String get liveVoiceDenied =>
      'Allow the microphone in Settings to send voice clips.';

  @override
  String get liveVoiceUnavailable =>
      'The microphone isn\'t available right now.';

  @override
  String get liveVoiceUploadsUnavailable =>
      'Voice messages aren\'t available right now.';

  @override
  String get liveRoomRulesNotice =>
      'Welcome to Kabso Live. Offensive content and anything against our community guidelines isn\'t allowed. Our moderators watch lives around the clock.';

  @override
  String get liveRoomRulesLabel => 'Kabso notice';

  @override
  String get liveVoiceTooLarge =>
      'This voice clip is too large. Record a shorter one.';

  @override
  String get liveVoiceLiveMicPaused =>
      'Your live mic is paused while you record';

  @override
  String get liveVoiceLiveMicBusy =>
      'Your live mic couldn\'t be paused, so a voice clip can\'t be recorded right now.';

  @override
  String get liveVoicePlayFailed => 'This voice clip couldn\'t be played.';

  @override
  String get liveVoiceSilent =>
      'No sound was picked up in this clip, so it wasn\'t sent. Try again.';

  @override
  String get liveChatPrivateMessages => 'Private messages';

  @override
  String get liveChatPicture => 'Picture';

  @override
  String get liveChatSending => 'Sending…';

  @override
  String liveChatVoiceLine(String name, String duration) {
    return '$name: voice clip, $duration';
  }

  @override
  String liveChatPictureLine(String name) {
    return '$name: picture';
  }

  @override
  String get liveChatPlay => 'Play';

  @override
  String get liveChatPause => 'Pause';

  @override
  String get errorLiveKicked =>
      'You were removed from this live. You can watch the host\'s next live.';

  @override
  String get liveKickedTitle => 'You were removed from this live';

  @override
  String get liveKickedBody =>
      'The host or a moderator removed you, and you cannot come back until it ends. You can watch the host\'s next live.';

  @override
  String get liveUserPoints => 'Points in this live';

  @override
  String liveUserRank(String rank) {
    return '#$rank in this live';
  }

  @override
  String get liveUserNoPoints => 'No points in this live yet';

  @override
  String get liveUserKick => 'Remove from live';

  @override
  String liveUserKickTitle(String name) {
    return 'Remove $name from this live?';
  }

  @override
  String get liveUserKickBody =>
      'They leave the live now and cannot come back until it ends.';

  @override
  String get liveUserKickConfirm => 'Remove';

  @override
  String liveUserKicked(String name) {
    return '$name was removed from this live';
  }

  @override
  String liveUserModeratorAdded(String name) {
    return '$name is now a moderator';
  }

  @override
  String liveUserModeratorRemoved(String name) {
    return '$name is no longer a moderator';
  }

  @override
  String get liveUserMore => 'More';

  @override
  String get liveUserCp => 'Relationship';

  @override
  String get liveUserNone => 'None yet';

  @override
  String get liveUserFamilyNone => 'Not in a family yet';

  @override
  String get liveUserFamilyNoneSelf => 'You\'re not in a family yet';

  @override
  String get liveUserFamilyHint => 'Join a family or start your own';

  @override
  String get liveUserCpNone => 'No partner yet';

  @override
  String get liveUserCpBar =>
      'CP gifts are coming soon: send them to someone special to become a pair';

  @override
  String get liveUserCpPartner => 'Partner slot, empty';

  @override
  String get liveBulletTag => 'Public message';

  @override
  String get errorAlreadyInFamily =>
      'You\'re already in a family. You can be in one family at a time.';

  @override
  String get errorFamilyFull =>
      'This family is full and cannot take new members.';

  @override
  String get errorFamilyNameTaken =>
      'Another family has this name. No coins were taken.';

  @override
  String get errorFamilyRequestPending =>
      'You already asked another family to join. Cancel that request first.';

  @override
  String get errorFamilyRequestNotPending =>
      'This request was already answered, cancelled or expired.';

  @override
  String get errorFamilyNotEmpty =>
      'You can disband the family only when you\'re its only member.';

  @override
  String get errorFamilyLeaderCannotLeave =>
      'The leader can\'t leave: hand the family over or disband it.';

  @override
  String get errorCpAlreadyPaired =>
      'You or this person already has a partner. No coins were taken.';

  @override
  String get errorCpRequestPending =>
      'You already have a pending CP request. Cancel it on the Relationship page first.';

  @override
  String get errorCpRequestNotPending =>
      'This CP request was already answered, cancelled or expired.';

  @override
  String get errorCpNotPaired =>
      'You don\'t have a partner now. No coins were taken.';

  @override
  String get errorMedalNotUnlocked => 'Choose only medals you\'ve earned.';

  @override
  String bondsCoins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '$count coin',
    );
    return '$_temp0';
  }

  @override
  String bondsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String bondsBalance(String coins) {
    return 'Your balance: $coins';
  }

  @override
  String get bondsConfirm => 'Confirm';

  @override
  String get bondsCancel => 'Cancel';

  @override
  String get familiesTitle => 'Families';

  @override
  String get familiesSearchHint => 'Search by name or number';

  @override
  String get familiesMine => 'My family';

  @override
  String get familiesCreate => 'Create a family';

  @override
  String get familiesTop => 'Top families';

  @override
  String get familiesResults => 'Search results';

  @override
  String get familiesEmpty => 'No families yet';

  @override
  String get familiesEmptyBody => 'Be the first to create one.';

  @override
  String get familiesNoMatch => 'No family matches';

  @override
  String get familiesNoMatchBody =>
      'Try another name or the 8-digit family number.';

  @override
  String get familiesLoadError => 'Couldn\'t load families';

  @override
  String get familiesNumberNotFound => 'No family has this number';

  @override
  String familyNumber(String number) {
    return 'Family No. $number';
  }

  @override
  String familyLevel(int level) {
    return 'Lv $level';
  }

  @override
  String familyMembersCount(int count, int capacity) {
    return 'Members $count / $capacity';
  }

  @override
  String familyPendingRequest(String name) {
    return 'Your request to join $name is waiting';
  }

  @override
  String get familyCancelRequest => 'Cancel request';

  @override
  String get familyRequestCancelled => 'Join request cancelled';

  @override
  String get familyNotFoundTitle => 'Family not found';

  @override
  String get familyNotFoundBody => 'This family may have been disbanded.';

  @override
  String get familyLoadError => 'Couldn\'t load the family';

  @override
  String familyPoints(String points) {
    return 'Points: $points';
  }

  @override
  String familyProgress(String points, String next, int level) {
    return '$points / $next to reach level $level';
  }

  @override
  String get familyTopLevel => 'The family reached the top level';

  @override
  String familyLeader(String name) {
    return 'Leader: $name';
  }

  @override
  String get familyJoin => 'Ask to join';

  @override
  String get familyJoinSent =>
      'Request sent. The leader or a deputy will answer.';

  @override
  String get familyRequested => 'Request sent';

  @override
  String get familyFullLabel => 'Family is full';

  @override
  String get familyInOther => 'You\'re in another family';

  @override
  String get familyLeave => 'Leave family';

  @override
  String familyLeaveTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String get familyLeaveBody => 'The points you gave stay with the family.';

  @override
  String get familyLeft => 'You left the family';

  @override
  String get familyManage => 'Manage family';

  @override
  String get familyChangeEmblem => 'Change emblem';

  @override
  String get familyRemoveEmblem => 'Remove emblem';

  @override
  String get familyEmblemUpdated => 'Emblem updated';

  @override
  String get familyEmblemRemoved => 'Emblem removed';

  @override
  String get familyDisband => 'Disband family';

  @override
  String familyDisbandTitle(String name) {
    return 'Disband $name?';
  }

  @override
  String get familyDisbandBody =>
      'The name becomes free and no coins come back.';

  @override
  String get familyDisbanded => 'Family disbanded';

  @override
  String get familyDisbandOnlyAlone =>
      'You can disband when you\'re the only member';

  @override
  String get familyRequestsTitle => 'Join requests';

  @override
  String get familyRequestsEmpty => 'No requests right now';

  @override
  String get familyAccept => 'Accept';

  @override
  String get familyDecline => 'Decline';

  @override
  String familyAccepted(String name) {
    return '$name joined the family';
  }

  @override
  String get familyDeclined => 'Request declined';

  @override
  String get familyMembersTitle => 'Members';

  @override
  String get familyRoleLeader => 'Leader';

  @override
  String get familyRoleDeputy => 'Deputy';

  @override
  String get familyRoleMember => 'Member';

  @override
  String get familyMakeDeputy => 'Make deputy';

  @override
  String get familyMakeMember => 'Make member';

  @override
  String get familyTransfer => 'Hand over the family';

  @override
  String familyTransferTitle(String name) {
    return 'Hand the family over to $name?';
  }

  @override
  String familyTransferBody(String name) {
    return '$name becomes the leader and you become a deputy.';
  }

  @override
  String familyTransferred(String name) {
    return '$name is now the leader';
  }

  @override
  String get familyRemove => 'Remove from family';

  @override
  String familyRemoveTitle(String name) {
    return 'Remove $name from the family?';
  }

  @override
  String familyRemoved(String name) {
    return '$name was removed';
  }

  @override
  String familyRoleChanged(String name) {
    return '$name\'s role changed';
  }

  @override
  String get familyMemberActions => 'Member options';

  @override
  String get familyCreateTitle => 'New family';

  @override
  String get familyNameLabel => 'Family name';

  @override
  String get familyNameHelp => '2 to 20 characters, unique among families.';

  @override
  String get familyNameInvalid =>
      'Use 2 to 20 characters without disallowed symbols.';

  @override
  String get familyEmblemLabel => 'Emblem (optional)';

  @override
  String get familyEmblemChoose => 'Choose an emblem photo';

  @override
  String familyCreateCost(String coins) {
    return 'Creating a family costs $coins';
  }

  @override
  String familyCreateSubmit(String coins) {
    return 'Create for $coins';
  }

  @override
  String familyCreateNotEnough(String coins) {
    return 'You need $coins to create a family. For now the team adds coins; there is no purchase yet.';
  }

  @override
  String familyCreated(String name) {
    return '$name was created';
  }

  @override
  String get cpTitle => 'Relationship';

  @override
  String cpDay(int days) {
    return 'Day $days together';
  }

  @override
  String cpPoints(String points) {
    return 'CP points: $points';
  }

  @override
  String cpToNext(String points, String name) {
    return '$points more to $name';
  }

  @override
  String get cpTopTier => 'You reached the highest tier';

  @override
  String cpSince(String date) {
    return 'Since $date';
  }

  @override
  String get cpGiftTitle => 'Send a CP gift';

  @override
  String get cpGiftBody =>
      'A gift adds CP points to your couple; your partner gets no coins.';

  @override
  String cpGiftConfirmTitle(String coins) {
    return 'Send $coins as a CP gift?';
  }

  @override
  String cpGiftSent(String points) {
    return 'Gift sent: +$points CP points';
  }

  @override
  String get cpGiftNotEnough =>
      'You don\'t have enough coins for this gift. For now the team adds coins.';

  @override
  String get cpEnd => 'End relationship';

  @override
  String cpEndTitle(String name) {
    return 'End your relationship with $name?';
  }

  @override
  String get cpEndBody => 'No coins come back.';

  @override
  String get cpEnded => 'Relationship ended';

  @override
  String get cpNoneTitle => 'No partner yet';

  @override
  String get cpNoneBody =>
      'Send a CP request from someone\'s profile or their card in a live.';

  @override
  String get cpRequestsTitle => 'CP requests';

  @override
  String get cpIncoming => 'Received';

  @override
  String get cpOutgoing => 'Sent';

  @override
  String get cpIncomingEmpty => 'No requests received';

  @override
  String get cpOutgoingEmpty => 'No requests sent';

  @override
  String cpRequestFrom(String name) {
    return '$name wants to be your CP';
  }

  @override
  String cpRequestTo(String name) {
    return 'Waiting for $name';
  }

  @override
  String cpExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get cpAccept => 'Accept';

  @override
  String get cpDecline => 'Decline';

  @override
  String get cpCancel => 'Cancel request';

  @override
  String cpAccepted(String name) {
    return 'You and $name are a couple now';
  }

  @override
  String get cpDeclined => 'Request declined';

  @override
  String get cpCancelled => 'Request cancelled; your coins came back';

  @override
  String get cpSendRequest => 'Send CP request';

  @override
  String get cpSendShort => 'Send request';

  @override
  String cpSendTitle(String name) {
    return 'Send a CP request to $name?';
  }

  @override
  String cpSendBody(String coins, String days) {
    return 'It costs $coins. They come back if it\'s declined, cancelled or not answered within $days.';
  }

  @override
  String cpSent(String name) {
    return 'CP request sent to $name';
  }

  @override
  String cpSendNotEnough(String coins) {
    return 'You need $coins to send a CP request. For now the team adds coins; there is no purchase yet.';
  }

  @override
  String get cpLoadError => 'Couldn\'t load your relationship';

  @override
  String cpBoxValue(String name, String tier) {
    return '$name · $tier';
  }

  @override
  String familyBoxValue(String name, int level) {
    return '$name · Lv $level';
  }

  @override
  String get medalsTitle => 'Medals';

  @override
  String medalsOwned(int owned, int total) {
    return '$owned of $total';
  }

  @override
  String get medalsChoose => 'Choose medals to show';

  @override
  String get medalsLocked => 'Locked';

  @override
  String medalsEarnedOn(String date) {
    return 'Earned on $date';
  }

  @override
  String get medalsEmptyTitle => 'No medals yet';

  @override
  String get medalsEmptyBody =>
      'Medals come automatically from hosting lives, charm levels, families and couples.';

  @override
  String get medalsLoadError => 'Couldn\'t load medals';

  @override
  String get medalsShowcaseTitle => 'Medals on your profile';

  @override
  String medalsShowcaseHint(int max) {
    return 'Choose up to $max medals, in the order you want.';
  }

  @override
  String medalsShowcaseCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String medalsShowcaseLimit(int max) {
    return 'You can show up to $max medals';
  }

  @override
  String get medalsShowcaseSave => 'Save';

  @override
  String get medalsShowcaseSaved => 'Your profile medals were saved';

  @override
  String get medalsShowcaseEmptyPreview =>
      'Nothing shown. Choose medals below.';

  @override
  String get medalsShowcaseNoneEarned =>
      'You haven\'t earned a medal yet, so there is nothing to show.';

  @override
  String medalsRowLabel(String names) {
    return 'Medals: $names';
  }

  @override
  String medalsPosition(String name, int position) {
    return '$name, position $position';
  }

  @override
  String get medalsDiscard => 'Discard changes?';

  @override
  String get medalsDiscardConfirm => 'Discard';

  @override
  String notifCpRequest(String who) {
    return '$who sent you a CP request';
  }

  @override
  String notifCpAccepted(String who) {
    return '$who accepted your CP request';
  }

  @override
  String notifFamilyJoinAccepted(String family) {
    return 'You\'re now a member of $family';
  }

  @override
  String notifFamilyJoinDeclined(String family) {
    return 'Your request to join $family was declined';
  }

  @override
  String notifMedalAwarded(String name) {
    return 'You earned a new medal: $name';
  }

  @override
  String get notifMedalAwardedUnnamed => 'You earned a new medal';

  @override
  String get errorBagItemNotOwned => 'This item isn\'t in your bag.';

  @override
  String get bagTitle => 'Bag';

  @override
  String get bagTileValue => 'Decorate your card';

  @override
  String get bagCategoryProfileCard => 'Profile card';

  @override
  String get bagLoadError => 'Couldn\'t load your bag';

  @override
  String get bagWorn => 'Worn';

  @override
  String get bagWear => 'Wear';

  @override
  String get bagTakeOff => 'Remove';

  @override
  String get bagEmptyTitle => 'Your bag is empty';

  @override
  String get bagEmptyMessage => 'Items you get will appear here.';

  @override
  String get bagOwnedSection => 'Your items';

  @override
  String get errorGiftUnavailable => 'This gift isn\'t available anymore.';

  @override
  String get errorGiftBagInsufficient =>
      'There isn\'t enough of this gift in your bag.';

  @override
  String get errorLiveGiftRecipientUnavailable =>
      'One of the recipients isn\'t on the mic anymore.';

  @override
  String get liveGiftTabPopular => 'Popular';

  @override
  String get liveGiftTabEvent => 'Events';

  @override
  String get liveGiftTabFun => 'Fun';

  @override
  String get liveGiftTabBag => 'Bag';

  @override
  String get liveGiftHost => 'Host';

  @override
  String get liveGiftAllOnMic => 'All';

  @override
  String get liveGiftAllOnMicSemantics => 'Send to everyone on the mic';

  @override
  String get liveGiftEmptyTitle => 'No gifts yet';

  @override
  String get liveGiftEmptyMessage =>
      'Gifts will appear here once the Kabso Live team adds them.';

  @override
  String get liveGiftBagEmptyTitle => 'Your gift bag is empty';

  @override
  String get liveGiftBagEmptyMessage =>
      'Gifts you get appear here, and you send them without coins.';

  @override
  String get liveGiftLoadError => 'Couldn\'t load the gifts';

  @override
  String get liveGiftPickGift => 'Pick a gift';

  @override
  String get liveGiftPickRecipient => 'Choose who gets the gift';

  @override
  String get liveGiftNoRecipients => 'Nobody is on the mic to receive a gift';

  @override
  String get liveGiftSignIn => 'Log in to send gifts';

  @override
  String get liveGiftNotEnoughCoins =>
      'You don\'t have enough coins for this gift.';

  @override
  String liveGiftBalance(String coins) {
    return 'Your balance: $coins';
  }

  @override
  String liveGiftQuantity(String count) {
    return 'Quantity $count';
  }

  @override
  String get liveGiftBadgeNew => 'New';

  @override
  String get liveGiftBadgeEvent => 'Event';

  @override
  String liveGiftBannerSent(String gift, String recipients) {
    return 'sent $gift to $recipients';
  }

  @override
  String liveGiftRecipientsTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String liveGiftRecipientsMore(String name, int count) {
    return '$name +$count';
  }

  @override
  String get liveGiftGeneric => 'a gift';

  @override
  String liveGiftNotOnMic(String name) {
    return '$name isn\'t on the mic. Gifts go to the host and people on the mic.';
  }

  @override
  String liveGiftBagCount(String count) {
    return 'You have $count';
  }

  @override
  String get liveGiftTagAll => 'All';

  @override
  String get liveGiftTagsSemantics => 'Gift categories';

  @override
  String get cpSpaceTitle => 'CP space';

  @override
  String get cpSpaceOpen => 'Open CP space';

  @override
  String get cpSpaceHelpTitle => 'How the CP space works';

  @override
  String cpSpaceHelpBody(String zone) {
    return 'Intimacy is your couple\'s CP points: CP gifts and daily task rewards add to them, and a higher CP level unlocks more privileges. Daily tasks start again every day at 00:00 ($zone).';
  }

  @override
  String cpSpaceDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String get cpSpaceActionTasks => 'Daily tasks';

  @override
  String get cpSpaceActionPrivileges => 'CP privileges';

  @override
  String get cpSpaceActionGifts => 'Couple gifts';

  @override
  String get cpSpaceActionRanking => 'Ranking';

  @override
  String get cpSpaceLevelTitle => 'CP level';

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
    return 'Intimacy $points';
  }

  @override
  String cpSpaceToNext(String points, String name) {
    return '$points more intimacy to reach $name';
  }

  @override
  String cpSpaceTasksResets(String time) {
    return 'Starts again at $time';
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
  String get cpSpaceClaim => 'Claim';

  @override
  String get cpSpaceClaimed => 'Claimed';

  @override
  String get cpSpaceNotDone => 'Not done';

  @override
  String cpSpaceClaimedToast(String points) {
    return '+$points intimacy';
  }

  @override
  String get cpSpaceClaimedBefore => 'Already claimed today';

  @override
  String get cpSpaceTasksError => 'Couldn\'t load today\'s tasks';

  @override
  String get cpPrivSpecialFrame => 'Special frame';

  @override
  String get cpPrivChatBubble => 'Exclusive bubble';

  @override
  String get cpPrivMicEffect => 'Couple mic effect';

  @override
  String get cpPrivEntranceEffect => 'Entrance effect';

  @override
  String get cpPrivGiftWall => 'CP gift wall';

  @override
  String get cpPrivSpecialFrameAbout => 'A heart frame around your pictures.';

  @override
  String get cpPrivChatBubbleAbout =>
      'Your messages in a live\'s chat show in a couple bubble.';

  @override
  String get cpPrivMicEffectAbout =>
      'A couple effect on your seats when you\'re both on the mic.';

  @override
  String get cpPrivEntranceEffectAbout =>
      'When you enter a live, the room sees you arrive as a couple.';

  @override
  String get cpPrivGiftWallAbout =>
      'Everyone can see the CP gifts you sent each other.';

  @override
  String cpSpaceUnlocksAt(int level) {
    return 'Unlocks at Lv.$level';
  }

  @override
  String get cpSpaceUnlocked => 'Unlocked';

  @override
  String get cpSpaceLocked => 'Locked';

  @override
  String get cpSpaceGiftWall => 'Gift wall';

  @override
  String cpSpaceGiftWallTotals(String gifts, String coins) {
    return 'Gifts $gifts · Coins $coins';
  }

  @override
  String cpSpaceGiftWallEntry(String from, String to) {
    return '$from to $to';
  }

  @override
  String get cpSpaceGiftWallEmpty => 'No CP gifts yet';

  @override
  String cpSpaceGiftWallLocked(int level) {
    return 'This couple\'s gift wall opens at Lv.$level.';
  }

  @override
  String get cpSpaceGiftWallError => 'Couldn\'t load the gift wall';

  @override
  String cpSpaceGiftConfirm(String gift, String coins) {
    return 'Send $gift for $coins?';
  }

  @override
  String get cpSpaceConfessionsTitle => 'Confession wall';

  @override
  String get cpSpaceConfessionsEmpty =>
      'Be the first to leave a confession for your CP';

  @override
  String get cpSpaceConfessionsEmptyPublic => 'No confessions yet';

  @override
  String cpSpaceConfessionHint(String name) {
    return 'Write to $name';
  }

  @override
  String get cpSpaceConfessionSend => 'Send';

  @override
  String get cpSpaceConfessionSent => 'Confession left';

  @override
  String cpSpaceConfessionTo(String from, String to) {
    return '$from to $to';
  }

  @override
  String get cpSpaceConfessionMenu => 'Confession options';

  @override
  String get cpSpaceConfessionDelete => 'Delete';

  @override
  String get cpSpaceConfessionDeleteTitle => 'Delete this confession?';

  @override
  String get cpSpaceConfessionDeleted => 'Confession deleted';

  @override
  String get cpSpaceConfessionReport => 'Report';

  @override
  String get cpSpaceConfessionReportTitle =>
      'Why are you reporting this confession?';

  @override
  String get cpSpaceConfessionsError => 'Couldn\'t load the confessions';

  @override
  String get cpSpaceRankingTitle => 'Couples ranking';

  @override
  String get cpSpaceRankingWeek => 'This week';

  @override
  String get cpSpaceRankingAll => 'All time';

  @override
  String get cpSpaceRankingEmpty => 'No couples here yet';

  @override
  String get cpSpaceRankingError => 'Couldn\'t load the ranking';

  @override
  String cpSpaceRankingMe(String rank) {
    return 'Your couple: #$rank';
  }

  @override
  String get cpSpaceRankingMeUnranked => 'Your couple isn\'t ranked yet';

  @override
  String cpSpacePair(String first, String second) {
    return '$first & $second';
  }

  @override
  String get cpSpaceLoadError => 'Couldn\'t load the CP space';

  @override
  String get cpSpaceGoneTitle => 'This couple\'s space isn\'t available';

  @override
  String get cpSpaceGoneBody =>
      'The couple may have ended, or it can\'t be shown to you.';

  @override
  String get errorCpTaskNotCompleted => 'This task isn\'t done yet today.';

  @override
  String get errorCpPrivilegeLocked => 'This couple hasn\'t unlocked this yet.';

  @override
  String liveCpEntranceCouple(String name, String partner) {
    return '$name and $partner';
  }

  @override
  String liveCpEntranceLevel(String level) {
    return 'Couple entrance · $level';
  }

  @override
  String get errorFamilyChatMuted => 'You are muted in the family chat.';

  @override
  String get familiesListTitle => 'Families list';

  @override
  String get familiesSearchShort => 'Search families';

  @override
  String get familiesTabPrestige => 'Prestige';

  @override
  String get familiesTabBattle => 'Battles';

  @override
  String get familiesTabActive => 'Most active';

  @override
  String familiesSoonLabel(String feature) {
    return '$feature, coming soon';
  }

  @override
  String get familiesBoardEmpty => 'No families on this board yet';

  @override
  String get familiesBoardEmptyPrestige =>
      'Families that gain points this month show up here.';

  @override
  String get familiesBoardEmptyActive =>
      'Families whose members are active this week show up here.';

  @override
  String familiesScoreMonth(String points) {
    return 'Points this month: $points';
  }

  @override
  String familiesScoreActive(String count) {
    return 'Active this week: $count';
  }

  @override
  String familiesPodiumLabel(int place, String name) {
    return 'Place $place: $name';
  }

  @override
  String get familiesMyRankNone => 'Your family is not ranked yet';

  @override
  String get familyJoinShort => 'Join';

  @override
  String familyJoinNamed(String name) {
    return 'Join $name';
  }

  @override
  String familyLevelLong(int level) {
    return 'Level $level';
  }

  @override
  String get familyActiveJustNow => 'Active just now';

  @override
  String get familyOnlineNow => 'Online now';

  @override
  String get familySoon => 'Soon';

  @override
  String get familyPageTitle => 'Family';

  @override
  String get familyShare => 'Share the family';

  @override
  String get familyInvite => 'Invite members';

  @override
  String get familyInviteCopied => 'Invite copied. Send it to anyone.';

  @override
  String familyInviteText(String name, String number) {
    return 'Join my family “$name” on Kabso Live. Family number: $number';
  }

  @override
  String get familyNumberLabel => 'Family number';

  @override
  String familyNumberCopy(String number) {
    return 'Family number $number, copy';
  }

  @override
  String get familyCopyNumber => 'Copy family number';

  @override
  String get familyMemberWord => 'members';

  @override
  String familyMembersShort(String count) {
    return '$count members';
  }

  @override
  String get familyMembersSearchHint => 'Search members';

  @override
  String get familyMembersNoMatch => 'No member matches';

  @override
  String familyToReach(int level) {
    return 'to reach level $level';
  }

  @override
  String get familyToolManage => 'Manage';

  @override
  String get familyToolCompetitions => 'Contests';

  @override
  String get familyToolShop => 'Family shop';

  @override
  String get familyToolTasks => 'Tasks';

  @override
  String get familyTabMembers => 'Members';

  @override
  String get familyTabEvents => 'Events';

  @override
  String get familyTabContributions => 'Contributions';

  @override
  String get familyTabRanking => 'Ranking';

  @override
  String get familyContributionsThisMonth =>
      'Members\' contributions this month';

  @override
  String get familyContributionsEmpty => 'No contributions this month yet';

  @override
  String get familyContributionsEmptyBody =>
      'Every coin members spend in the app counts for the family.';

  @override
  String get familyRankNone => '—';

  @override
  String get familyRankingNote =>
      'The place among all families: prestige this month, activity this week.';

  @override
  String get familyChangeCover => 'Change cover';

  @override
  String get familyRemoveCover => 'Remove cover';

  @override
  String get familyCoverUpdated => 'Cover updated';

  @override
  String get familyCoverRemoved => 'Cover removed';

  @override
  String get familyTaglineTitle => 'Family tagline';

  @override
  String get familyTaglineHint => 'e.g. Global family · Fun · Live';

  @override
  String get familySave => 'Save';

  @override
  String get familySaved => 'Saved';

  @override
  String get familyViewProfile => 'View profile';

  @override
  String get familyChatOpen => 'Chat';

  @override
  String get familyChatTitle => 'Family chat';

  @override
  String get familyChatHint => 'Message the family';

  @override
  String get familyChatSend => 'Send';

  @override
  String get familyChatEmpty => 'Start the conversation';

  @override
  String get familyChatEmptyBody => 'Only family members see messages here.';

  @override
  String get familyChatLoadError => 'Couldn\'t load the chat';

  @override
  String get familyChatMembersOnly => 'The chat is for family members';

  @override
  String get familyChatMembersOnlyBody => 'Join the family to take part.';

  @override
  String get familyChatDelete => 'Delete message';

  @override
  String get familyChatDeleted => 'Message deleted';

  @override
  String get familyChatReport => 'Report message';

  @override
  String get familyChatReported => 'Thanks, report sent';

  @override
  String get familyChatMute => 'Mute in chat';

  @override
  String get familyChatUnmute => 'Unmute in chat';

  @override
  String familyChatMutedName(String name) {
    return '$name is muted in the chat';
  }

  @override
  String familyChatUnmutedName(String name) {
    return '$name can chat again';
  }

  @override
  String get privacyActivityTitle => 'Activity status';

  @override
  String get privacyActivityLabel => 'Show activity status';

  @override
  String get privacyActivityHint =>
      'Your family members see if you are online now or when you were last active.';

  @override
  String get followListsFollowBack => 'Follow back';

  @override
  String get followListsFollowersEmpty => 'No followers yet';

  @override
  String get followListsFollowersEmptyBody =>
      'When someone follows this account, they\'ll appear here.';

  @override
  String get followListsFollowingEmpty => 'Not following anyone yet';

  @override
  String get followListsFollowingEmptyBody =>
      'Accounts this person follows will appear here.';

  @override
  String get followListsPrivateBody =>
      'Only approved followers can see this account\'s followers and who it follows.';

  @override
  String followListsTabFollowers(String count) {
    return '$count followers';
  }

  @override
  String followListsTabFollowing(String count) {
    return '$count following';
  }

  @override
  String get followListsAddPeople => 'Find people';

  @override
  String get followListsSearchHint => 'Search';

  @override
  String get followListsSortBy => 'Sort by';

  @override
  String get followListsSortDefault => 'Default';

  @override
  String get followListsSortOldest => 'Oldest first';

  @override
  String get followListsSortToggle => 'Change order';

  @override
  String followListsRowMore(String name) {
    return 'Options for $name';
  }

  @override
  String get followListsRemoveFollower => 'Remove follower';

  @override
  String followListsRemoveFollowerTitle(String name) {
    return 'Remove $name from your followers?';
  }

  @override
  String get followListsRemoveFollowerBody =>
      'They won\'t be told. They can follow you again unless your account is private.';

  @override
  String get followListsRemoveFollowerConfirm => 'Remove';

  @override
  String followListsFollowerRemoved(String name) {
    return '$name was removed from your followers';
  }

  @override
  String get followListsNoMatch => 'No matches';

  @override
  String followListsNoMatchBody(String query) {
    return 'No one in this list has a name starting with “$query”.';
  }

  @override
  String get profileOpenFollowers => 'Show followers';

  @override
  String get profileOpenFollowing => 'Show following';

  @override
  String get liveHubBrand => 'Kabso Live';

  @override
  String get liveGridAudio => 'Audio';

  @override
  String get liveGridVideo => 'Video';

  @override
  String homeBannerSemantics(int index, int count) {
    return 'Promotion $index of $count';
  }

  @override
  String homeBannerTitledSemantics(String title, int index, int count) {
    return '$title, promotion $index of $count';
  }

  @override
  String get familiesActivitiesTitle => 'Family activities';

  @override
  String get familiesActivityMonthly => 'Monthly ranking\nFamily prestige';

  @override
  String familiesRowMembers(int count, int capacity) {
    return 'Members: $count/$capacity';
  }

  @override
  String get familiesMonthPointsLabel => 'Points this month:';

  @override
  String get familiesActiveLabel => 'Active this week:';

  @override
  String navMessagesUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get navMessagesUnreadMany => 'more than 99 unread messages';

  @override
  String get navMomentsNew => 'new stories';

  @override
  String get liveVoiceRoomsTitle => 'Voice rooms';

  @override
  String get liveVoiceRoomsToLive => 'Live';

  @override
  String get liveHubFilterLabel => 'Filters';

  @override
  String get liveHubFilterFollowing => 'Following';

  @override
  String get livePartyTabFollowing => 'Following';

  @override
  String get liveCardPopular => 'Popular';

  @override
  String get liveHubFilterNearby => 'Nearby';

  @override
  String get liveHubFilterPopular => 'Popular';

  @override
  String get liveHubFilterFeatured => 'Featured';

  @override
  String get liveHubFilterExplore => 'Explore';

  @override
  String get liveHubPopularMenuHint => 'Opens a menu: Following or a category';

  @override
  String get liveNearbyNoCountryTitle =>
      'Set your country to see lives near you';

  @override
  String get liveNearbyNoCountryBody =>
      'Nearby shows lives from hosts in your country. Your country isn\'t shown on your profile.';

  @override
  String get liveNearbySetCountry => 'Set your country';

  @override
  String get liveNearbyChangeCountry => 'Change country';

  @override
  String liveNearbyEmptyTitle(String country) {
    return 'No lives from $country right now';
  }

  @override
  String get liveNearbyEmptyBody => 'Check back later or try Popular.';

  @override
  String get liveFeaturedEmptyTitle => 'No featured lives right now';

  @override
  String get liveFeaturedEmptyBody =>
      'Lives from hosts the Kabso Live team picks show up here.';

  @override
  String get liveVoiceTabFollow => 'Follow';

  @override
  String get liveVoiceTabHot => 'Hot';

  @override
  String get liveVoiceTabNew => 'New';

  @override
  String get liveVoiceRecommended => 'Recommendations';

  @override
  String get liveVoiceSection => 'Rooms';

  @override
  String get liveVoiceListView => 'List view';

  @override
  String get liveVoiceGridView => 'Grid view';

  @override
  String liveVoiceSeats(int taken, int total) {
    return '$taken/$total';
  }

  @override
  String get liveVoiceEmptyTitle => 'No voice rooms right now';

  @override
  String get liveVoiceEmptyBody => 'Check back later or try another category.';

  @override
  String get countryPickerTitle => 'Your country';

  @override
  String get countryPickerBody =>
      'It decides Nearby lives. It isn\'t shown on your profile.';

  @override
  String get countryPickerSearch => 'Search countries';

  @override
  String get countryPickerClear => 'Remove my country';

  @override
  String get settingsCountry => 'Country';

  @override
  String get settingsCountryNotSet => 'Not set';

  @override
  String get liveGiftRecipientRefused =>
      'This gift can\'t go to that recipient here right now.';

  @override
  String get liveLeaveTitle =>
      'Enjoying the live? Follow the host before you go';

  @override
  String get liveLeaveFollow => 'Follow and exit';

  @override
  String get liveLeaveExit => 'Exit live room';

  @override
  String liveHostPillPoints(String points) {
    return 'This live\'s points $points';
  }

  @override
  String liveHostPillCherries(String cherries) {
    return 'This live\'s cherries $cherries';
  }

  @override
  String liveHostPillTaps(String taps) {
    return 'This live\'s taps $taps';
  }

  @override
  String get liveChatSayHi => 'Say Hi…';

  @override
  String get liveQuickHello => 'Hello 😊';

  @override
  String get liveQuickFire => '🔥🔥🔥';

  @override
  String get liveQuickNiceMood => 'Nice mood~';

  @override
  String get liveQuickGotMe => 'You got me';

  @override
  String liveQuickReplyLabel(String text) {
    return 'Send: $text';
  }

  @override
  String get liveToolDual => 'Dual';

  @override
  String get liveToolSticker => 'Sticker';

  @override
  String get liveToolInfo => 'Info';

  @override
  String get liveToolTrafficCard => 'Visit rockets';

  @override
  String get liveToolMagic => 'Filters';

  @override
  String get liveToolFillLight => 'Fill light';

  @override
  String get liveFillLightNoTorch => 'This camera has no torch.';

  @override
  String get liveFillLightTitle => 'Fill light';

  @override
  String get liveFillLightOff => 'Off';

  @override
  String get liveFillLightLow => 'Low';

  @override
  String get liveFillLightMedium => 'Medium';

  @override
  String get liveFillLightHigh => 'High';

  @override
  String get liveFillLightOnPicture =>
      'Gently brightens the picture itself, so your viewers see it as you do.';

  @override
  String get liveFillLightScreenOnly =>
      'On this device the screen lights your face with a soft glow at its edges; the broadcast picture doesn\'t change.';

  @override
  String get liveFilterTitle => 'Colour filters';

  @override
  String get liveFilterUnsupported =>
      'Colour filters aren\'t available on this device yet — they must reach your viewers, not only your screen.';

  @override
  String get liveFilterNatural => 'Natural';

  @override
  String get liveFilterWarm => 'Warm';

  @override
  String get liveFilterCool => 'Cool';

  @override
  String get liveFilterMono => 'Mono';

  @override
  String get liveFilterCinematic => 'Cinematic';

  @override
  String get liveFilterVivid => 'Vivid';

  @override
  String get liveFilterSoft => 'Soft';

  @override
  String get liveEffectsTitle => 'Effects (beta)';

  @override
  String get liveEffectNone => 'None';

  @override
  String get liveEffectBackgroundBlur => 'Background blur';

  @override
  String get liveEffectsUnavailable =>
      'Effects aren\'t available in this build yet.';

  @override
  String get liveManageAddModerator => 'Add a moderator';

  @override
  String get liveToolMixer => 'Mixer';

  @override
  String get liveBeautyToolsTitle => 'Beautification tools';

  @override
  String get liveHostGuests => 'Guest connection';

  @override
  String get liveHostGuestsSoon =>
      'Guests can join a multi-guest live. In a solo live this is coming later.';

  @override
  String get liveHostTools => 'Tools';

  @override
  String get liveManageTitle => 'User management';

  @override
  String get liveManageMuted => 'Muted in chat';

  @override
  String get liveManageKicked => 'Removed from the live';

  @override
  String get liveManageModerators => 'Moderators';

  @override
  String get liveManageModeratorsHint =>
      'Open someone\'s card to make them a moderator.';

  @override
  String get liveManageSignedInOnly => 'Signed-in viewers only';

  @override
  String get liveManageSignedInOnlyBody =>
      'People without an account can\'t watch.';

  @override
  String get liveManageEmpty => 'No one yet';

  @override
  String get liveManageUnmute => 'Unmute';

  @override
  String get liveManageLetBack => 'Let back in';

  @override
  String get liveManageRemove => 'Remove';

  @override
  String get goLiveSummaryTime => 'Live time';

  @override
  String get goLiveSummaryTaps => 'From taps';

  @override
  String get goLiveSummaryGifts => 'From gifts';

  @override
  String get goLiveSummarySupporters => 'Supporters';

  @override
  String goLiveSummaryCharm(String level) {
    return 'Charm level $level';
  }

  @override
  String goLiveSummaryCharmNext(String points) {
    return '$points to the next level';
  }

  @override
  String get liveGiftTabRecent => 'Recent';

  @override
  String get liveGiftTabLucky => 'Lucky';

  @override
  String get liveGiftRecentEmptyTitle => 'No recent gifts';

  @override
  String get liveGiftRecentEmptyMessage =>
      'Gifts you send from this phone show here.';

  @override
  String get liveGiftPriceSort => 'Price';

  @override
  String get liveGiftPriceSortOff => 'Sort by price';

  @override
  String get liveGiftPriceSortUp => 'Price, low to high';

  @override
  String get liveGiftPriceSortDown => 'Price, high to low';

  @override
  String liveGiftWealthLevel(String level) {
    return 'Wealth level $level';
  }

  @override
  String liveGiftWealthToNext(String points) {
    return '$points to the next level';
  }

  @override
  String get liveLuckyOdds => 'Odds';

  @override
  String get liveLuckyOddsTitle => 'Lucky gift odds';

  @override
  String get liveLuckyOddsIntro =>
      'Every gift you send is one draw. A win pays the multiplier times the gift\'s price in coins.';

  @override
  String liveLuckyOddsRow(String multiplier) {
    return '×$multiplier';
  }

  @override
  String get liveLuckyOddsNoWin => 'No win';

  @override
  String liveLuckyOddsReturn(String percent) {
    return 'Expected return: $percent of the coins spent';
  }

  @override
  String liveLuckyOddsHostShare(String percent) {
    return '$percent of the gift\'s value counts for the host.';
  }

  @override
  String get liveLuckyOddsProtection =>
      'A day\'s wins never pass the expected return of that day\'s lucky gifts; a win that would pass it pays less or nothing.';

  @override
  String get liveLuckyOddsAge => 'For people 18 or older only.';

  @override
  String get liveLuckyAgeTitle => 'Are you 18 or older?';

  @override
  String get liveLuckyAgeBody =>
      'Lucky gifts are a game of chance played with coins. Confirm that you are 18 or older to send them.';

  @override
  String get liveLuckyAgeConfirm => 'I\'m 18 or older';

  @override
  String get liveLuckyRegion =>
      'Lucky gifts aren\'t available in your country.';

  @override
  String get liveLuckyOff => 'Lucky gifts are off right now.';

  @override
  String liveLuckyWon(String coins, String multiplier) {
    return 'You won $coins coins, best ×$multiplier';
  }

  @override
  String get liveLuckyNoWin => 'No win this time';

  @override
  String liveLuckyBanner(String name, String multiplier, String coins) {
    return '$name won ×$multiplier: $coins coins';
  }

  @override
  String get errorLuckyGiftAgeUnconfirmed =>
      'Confirm that you are 18 or older to send lucky gifts.';

  @override
  String get errorLuckyGiftRegionUnavailable =>
      'Lucky gifts aren\'t available in your country.';

  @override
  String get liveEmojiPanel => 'Emoji';

  @override
  String get liveEmojiKeyboard => 'Keyboard';

  @override
  String get liveEmojiSmileys => 'Smileys';

  @override
  String get liveEmojiPeople => 'Hands and people';

  @override
  String get liveEmojiLove => 'Love';

  @override
  String get liveEmojiAnimals => 'Animals and nature';

  @override
  String get liveEmojiFood => 'Food and drink';

  @override
  String get liveEmojiActivities => 'Activities';

  @override
  String get liveEmojiTravel => 'Travel and places';

  @override
  String get liveEmojiObjects => 'Objects';

  @override
  String get liveEmojiSymbols => 'Symbols';

  @override
  String get goLiveToolsMore => 'More';

  @override
  String get goLiveToolsLess => 'Less';

  @override
  String get goLiveCategoriesAll => 'All topics';

  @override
  String get liveUserMention => 'Mention';

  @override
  String get liveQuickHostWelcome => 'Welcome to my live 👋';

  @override
  String get liveQuickHostThanks => 'Thanks for the support 🌹';

  @override
  String get liveQuickHostFollow => 'Follow me ❤️';

  @override
  String get liveQuickHostShare => 'Share the live 🔥';

  @override
  String get liveRoomIdCopyHint => 'Tap to copy';

  @override
  String get liveWishTitle => 'Wish list';

  @override
  String get liveWishHint =>
      'Pick up to 4 gifts you wish for; viewers see them in your live.';

  @override
  String get liveWishSave => 'Save';

  @override
  String get liveWishFull => '4 gifts at most';

  @override
  String liveWishRemove(String name) {
    return 'Remove $name';
  }

  @override
  String liveWishMoveEarlier(String name) {
    return 'Move $name up';
  }

  @override
  String liveWishRowLabel(String name, String count) {
    return '$name, received $count';
  }

  @override
  String get liveWishCardLabel => 'The host\'s wish list';

  @override
  String get liveWishEditLabel => 'Edit the wish list';

  @override
  String get liveToolWish => 'Wish list';

  @override
  String get livePromoClose => 'Hide the promo';

  @override
  String get liveSeatEmoji => 'Emoji on my seat';

  @override
  String get liveSeatEmojiHint =>
      'Plays once on your seat, for everyone in the room';

  @override
  String liveWishChosenCount(int count) {
    return '$count of 4 chosen';
  }

  @override
  String get liveUsernameCopied => 'Copied';

  @override
  String get liveChatTooFast => 'Sent too fast. Tap to retry';

  @override
  String liveBulletTime(String time) {
    return 'Sent $time';
  }

  @override
  String get liveGames => 'Games';

  @override
  String get liveGamesSoon => 'Games are coming soon';

  @override
  String get liveGamesSoonBody =>
      'We are adding games you can play in the live. They are not available yet.';

  @override
  String liveChatGiftLine(
    String sender,
    String gift,
    int count,
    String recipient,
  ) {
    return '$sender sent $gift ×$count to $recipient';
  }

  @override
  String liveChatGiftRecipients(String name, int more) {
    return '$name +$more';
  }

  @override
  String liveChatLuckyLine(String sender, String multiplier, String coins) {
    return '$sender won ×$multiplier = $coins coins from a lucky gift';
  }

  @override
  String liveStripGift(String sender, String receiver, String gift) {
    return '$sender sent $gift to $receiver';
  }

  @override
  String liveStripGameWin(String winner, String amount) {
    return '$winner won a prize worth $amount tickets';
  }

  @override
  String get liveStripShowGifts => 'Show the gifts strip';

  @override
  String get liveStripShowGames => 'Show the games strip';

  @override
  String get liveStripSwitchHint => 'In every live, on all your devices';

  @override
  String get liveViewerMenu => 'More';

  @override
  String get liveToolsModerator => 'Moderator tools';

  @override
  String get liveToolReportHost => 'Report host';

  @override
  String get liveToolViewers => 'Viewers';

  @override
  String get liveToolContributions => 'Contributions';

  @override
  String get liveToolGiftSounds => 'Gift sounds';

  @override
  String get liveToolGiftEffects => 'Gift effects';

  @override
  String get liveToolClearScreen => 'Clear screen';

  @override
  String get liveBroadcastSettings => 'Live settings';

  @override
  String get liveSettingsSound => 'Sound';

  @override
  String get liveSettingsCamera => 'Camera';

  @override
  String get liveSettingsCameraHint =>
      'When it is off, the others see your picture';

  @override
  String get liveSettingsFlip => 'Flip camera';

  @override
  String get liveSettingsQuality => 'Quality';

  @override
  String get liveSettingsSeatCount => 'Number of seats';

  @override
  String get liveSettingsQuestions => 'Questions';

  @override
  String get liveSettingsRoom => 'Room';

  @override
  String get liveSettingsGeneral => 'General';

  @override
  String get liveSettingsGuestsHint => 'Watching without an account';

  @override
  String get liveMuteAll => 'Mute everyone';

  @override
  String get liveMuteAllHint => 'Mutes the mic of everyone on a seat';

  @override
  String get liveMuteAllDone => 'Everyone on a seat is muted';

  @override
  String get liveMuteAllNone => 'No one on a seat to mute';

  @override
  String get liveCameraOff => 'Camera turned off';

  @override
  String get liveViewerSettings => 'Viewing settings';

  @override
  String get liveViewerThisLive => 'This live';

  @override
  String get liveViewerEffects => 'Gifts and effects';

  @override
  String get liveViewerDisplay => 'Display';

  @override
  String get liveViewerMuteLive => 'Mute this live on my phone';

  @override
  String get liveViewerMuteLiveHint =>
      'This live only; nothing changes for anyone else';

  @override
  String get liveViewerVolume => 'Volume';

  @override
  String get liveViewerGiftSounds => 'Mute gift sounds';

  @override
  String get liveViewerGiftEffects => 'Hide gift effects';

  @override
  String get liveViewerGiftEffectsHint => 'The gift\'s strip still shows';

  @override
  String get liveViewerQuipSounds => 'Mute quip sounds';

  @override
  String get liveViewerEntrances => 'Hide entrance effects';

  @override
  String get liveViewerCleanHint =>
      'Hides the chat and cards; tap «Show all» to bring them back';

  @override
  String get liveViewerCleanRestore => 'Show all';

  @override
  String get liveViewerChatText => 'Chat text size';

  @override
  String get liveViewerChatSmall => 'Small';

  @override
  String get liveViewerChatNormal => 'Normal';

  @override
  String get liveViewerChatLarge => 'Large';

  @override
  String get liveViewerDataSaver => 'Data saver';

  @override
  String get liveViewerDataSaverHint => 'Sound only, no video';

  @override
  String get liveViewerDataSaverOn => 'Data saver: sound only';

  @override
  String get liveToolSeatRequests => 'Seat requests';

  @override
  String liveCinemaMoved(int seat) {
    return 'Cinema mode has 10 seats: you were moved to seat $seat.';
  }

  @override
  String get liveCinemaOffSeat =>
      'You left the seat because cinema mode has only 10 seats.';

  @override
  String get liveGuestJoin => 'Join as a guest';

  @override
  String get liveGuestsFull =>
      'The 3 guest seats of this live are taken. Try again when one is free.';

  @override
  String get liveStatsCherries => 'Cherries this live';

  @override
  String liveStatsIncludesYours(String points) {
    return 'Includes $points from your own taps and gifts';
  }

  @override
  String get liveStatsViewers => 'Viewers';

  @override
  String get liveStatsPeak => 'Peak viewers';

  @override
  String get liveStatsAverageWatch => 'Avg. watch time';

  @override
  String get liveStatsNewFollowers => 'New followers';

  @override
  String get liveStatsChatMessages => 'Chat messages';

  @override
  String get liveStatsGiftsSent => 'Gifts sent';

  @override
  String get liveStatsCountriesTitle => 'Where your viewers came from';

  @override
  String get liveStatsCountryOther => 'Other countries';

  @override
  String get liveStatsCountryUnknown => 'Not shared';

  @override
  String liveStatsCountriesNote(String count) {
    return 'Shares of all viewers ($count), rounded to one decimal';
  }

  @override
  String liveStatsCountryRow(String country, String percent, String count) {
    return '$country: $percent of viewers ($count)';
  }

  @override
  String get liveStatsNoViewers =>
      'No one watched this time. Your next live is a fresh start.';

  @override
  String get liveStatsTopSupporters => 'Top supporters';

  @override
  String get liveStatsNoSupporters =>
      'No supporters this time. Gifts and taps from your viewers show here.';

  @override
  String liveStatsSupporterRank(int rank, String name, String points) {
    return 'Rank $rank: $name, $points cherries';
  }

  @override
  String get liveStatsLoadFailed => 'Couldn\'t load your live\'s data';

  @override
  String get liveStatsLoadFailedBody => 'Check your connection and try again.';

  @override
  String get liveComboLabel => 'MAX';

  @override
  String get liveMaxXJackpot => 'JACKPOT';

  @override
  String get liveMaxXSuperJackpot => 'SUPER JACKPOT';

  @override
  String liveComboSemantics(String gift, int count) {
    return 'Max X: send $gift again ×$count';
  }

  @override
  String liveComboBalance(String coins) {
    return 'Balance $coins coins';
  }

  @override
  String get usernameLettersAndDigits =>
      'Use both letters and numbers (e.g. sara22)';

  @override
  String get usernamePremium =>
      'This is a premium username. Premium names are rented from the Premium usernames store.';

  @override
  String get errorPremiumUsernameUnavailable =>
      'This username can\'t be rented right now.';

  @override
  String get errorPremiumUsernamePriceChanged =>
      'The price just changed. Check the new price and try again.';

  @override
  String get errorPremiumUsernameActive =>
      'You already have a premium username. Give it back first.';

  @override
  String get premiumTitle => 'Premium usernames';

  @override
  String get premiumTileValue => 'Rent a special @username';

  @override
  String get premiumSearchHint => 'Search a username, e.g. 777';

  @override
  String get premiumSearchHelp => 'Type a name to see if you can rent it.';

  @override
  String get premiumLoadError => 'Couldn\'t load the store';

  @override
  String get premiumTierAll => 'All';

  @override
  String get premiumTierLegend => 'Legend';

  @override
  String get premiumTierRuby => 'Ruby';

  @override
  String get premiumTierGold => 'Gold';

  @override
  String get premiumTierSilver => 'Silver';

  @override
  String get premiumTierLegendRule => '1–3 characters';

  @override
  String get premiumTierRubyRule => 'One character repeated (7777)';

  @override
  String get premiumTierGoldRule =>
      '4–5 characters or a pattern (1221, 1212, 123456)';

  @override
  String get premiumTierSilverRule => '6+ letters only or digits only';

  @override
  String get premiumTierNotOnSale => 'Not on sale yet';

  @override
  String premiumPricePerPeriod(String coins, int days) {
    return '$coins coins / $days days';
  }

  @override
  String premiumCoins(String coins) {
    return '$coins coins';
  }

  @override
  String get premiumSuggestions => 'Available now';

  @override
  String get premiumNotOnSaleTitle => 'Premium usernames aren\'t on sale yet';

  @override
  String get premiumNotOnSaleMessage =>
      'Prices haven\'t been set. Check back soon.';

  @override
  String get premiumNoSuggestionsTitle => 'Nothing free here right now';

  @override
  String get premiumNoSuggestionsMessage =>
      'Search for a name above, or try another tier.';

  @override
  String premiumRules(int days, int grace) {
    return 'Each rent lasts $days days and you can renew any time. When it ends you go back to your regular username, and the name is kept for you for $grace days.';
  }

  @override
  String get premiumStateAvailable => 'Available to rent';

  @override
  String get premiumStateNotForSale => 'Not on sale yet';

  @override
  String get premiumStateTaken => 'Someone already has this username';

  @override
  String get premiumStateHeld => 'Kept for its last renter for a few days';

  @override
  String get premiumStateYours => 'This is your username. You can renew it.';

  @override
  String get premiumStateYoursGrace =>
      'Your rent ended. Renew now to get it back.';

  @override
  String get premiumStateReserved => 'This username is reserved';

  @override
  String get premiumStateRegular =>
      'Not a premium username: you can take it for free from Settings › Username if it\'s free.';

  @override
  String get premiumStateInvalid => 'Not a valid username';

  @override
  String premiumHeldUntil(String date) {
    return 'Free again after $date';
  }

  @override
  String get premiumRent => 'Rent';

  @override
  String get premiumRenew => 'Renew';

  @override
  String premiumRentFor(String coins) {
    return 'Rent · $coins coins';
  }

  @override
  String premiumRenewFor(String coins) {
    return 'Renew · $coins coins';
  }

  @override
  String get premiumRentTitle => 'Rent this username';

  @override
  String get premiumRenewTitle => 'Renew your username';

  @override
  String get premiumSheetPrice => 'Price';

  @override
  String get premiumSheetBalance => 'Your balance';

  @override
  String get premiumSheetUntil => 'Yours until';

  @override
  String premiumSheetAfter(String username) {
    return 'After that you go back to @$username unless you renew.';
  }

  @override
  String get premiumNotEnoughCoins => 'You don\'t have enough coins.';

  @override
  String premiumRented(String username) {
    return 'You\'re now $username';
  }

  @override
  String premiumRenewed(String username) {
    return '$username renewed';
  }

  @override
  String get premiumMineTitle => 'Your premium username';

  @override
  String get premiumMineGraceTitle => 'Your premium username ended';

  @override
  String premiumMineLeft(String left) {
    return '$left left';
  }

  @override
  String get premiumMineNoEnd => 'No end date';

  @override
  String get premiumMineGranted => 'Given by the Kabso team';

  @override
  String premiumMineGrace(String username, String left) {
    return 'You\'re @$username again. It\'s kept for you for $left.';
  }

  @override
  String get premiumRelease => 'Give back';

  @override
  String get premiumReleaseTitle => 'Give back your premium username?';

  @override
  String premiumReleaseBody(String premium, String regular) {
    return '$premium goes back to the store now and you become @$regular again. Coins aren\'t refunded.';
  }

  @override
  String premiumReleased(String username) {
    return 'You\'re @$username again';
  }

  @override
  String get premiumLeftUnderMinute => 'less than a minute';

  @override
  String premiumLeftMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String premiumLeftHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String premiumLeftDays(int days, int hours) {
    return '$days d $hours h';
  }

  @override
  String premiumBadgeLabel(String tier, String username) {
    return '$tier premium username $username';
  }

  @override
  String get settingsUsername => 'Username';

  @override
  String get changeUsernameTitle => 'Change username';

  @override
  String get changeUsernameCurrent => 'Your username now';

  @override
  String get changeUsernameNew => 'New username';

  @override
  String get changeUsernameRule =>
      '6–30 characters: letters and numbers (a–z, 0–9), _ allowed';

  @override
  String get changeUsernameSave => 'Save';

  @override
  String changeUsernameDone(String username) {
    return 'You\'re now @$username';
  }

  @override
  String get changeUsernameNote =>
      'Your old username becomes free for others right away.';

  @override
  String changeUsernameRentInstead(String username) {
    return 'Rent $username as a premium username';
  }

  @override
  String changeUsernamePremiumActive(String premium, String regular) {
    return 'You\'re using the premium username $premium. To change your regular username (@$regular), give the premium one back first.';
  }

  @override
  String notificationPremiumExpiring(String username, String left) {
    return 'Your premium username $username ends in $left. Renew to keep it.';
  }

  @override
  String notificationPremiumExpired(String username) {
    return 'Your premium username $username ended. It\'s kept for you for a few days.';
  }

  @override
  String searchTryHint(String term) {
    return 'Try searching:  $term';
  }

  @override
  String get searchCancel => 'Cancel';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchRecentClear => 'Clear all';

  @override
  String searchRecentRemove(String term) {
    return 'Remove “$term” from recent searches';
  }

  @override
  String get searchHotTitle => 'Hot Searches';

  @override
  String searchHotSemantics(int rank, String term) {
    return 'Hot search $rank: $term';
  }

  @override
  String get searchTagTrending => 'Trending';

  @override
  String get searchTagNew => 'New';

  @override
  String get searchHotTakeTitle => 'Hot Take';

  @override
  String get searchMore => 'More';

  @override
  String get searchMayLikeTitle => 'You may like';

  @override
  String get trendingHashtagsTitle => 'Trending hashtags';

  @override
  String get trendingHashtagsEmpty => 'No trending hashtags this week';

  @override
  String trendingHashtagWeekCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts this week',
      one: '$count post this week',
    );
    return '$_temp0';
  }

  @override
  String get liveEffectStarting => 'Starting the effect…';

  @override
  String get liveEffectUnavailableStopped =>
      'The effect isn\'t available right now: it stopped giving new pictures, so the camera went on without it. Try it again in a moment.';

  @override
  String get liveEffectUnavailableLicence =>
      'The effect isn\'t available right now: this build\'s effects licence was not accepted.';

  @override
  String get liveEffectUnavailableFailed =>
      'The effect isn\'t available right now: it didn\'t start on this device. Try it again in a moment.';

  @override
  String get liveEffectUnavailableBlack =>
      'The effect isn\'t available right now: its picture came out black, so the camera went on without it before viewers saw it. Try it again later.';

  @override
  String get liveEffectUnavailableSlow =>
      'The effect isn\'t available right now: it was too slow to keep up with the camera on this phone, so the camera went on without it.';

  @override
  String get liveEffectsEngineFree =>
      'Engine: free, on the device (ML Kit + MediaPipe)';

  @override
  String get liveFreeBeautyTitle => 'Beauty';

  @override
  String get liveFreeBeautyOn => 'Face beauty';

  @override
  String get liveFreeBeautyNote =>
      'The face model (3.6 MB) downloads once on first use; then everything runs on the phone.';

  @override
  String get liveFreeBeautyUnavailable =>
      'Beauty isn\'t available right now: the face model couldn\'t be loaded. Check your connection and try again.';

  @override
  String get liveFreeBeautySmooth => 'Smooth skin';

  @override
  String get liveFreeBeautyBrighten => 'Brighten';

  @override
  String get liveFreeBeautySlim => 'Slim face';

  @override
  String get liveFreeBeautyEyes => 'Bigger eyes';

  @override
  String get liveLuckyBigWin => 'BIG WIN';

  @override
  String get livePermissionTitleVideo => 'Camera and microphone for your live';

  @override
  String get livePermissionTitleAudio => 'Microphone for your audio room';

  @override
  String get livePermissionBodyVideo =>
      'Kabso Live uses the camera and microphone only while you\'re live or on a seat, so people can see and hear you. Your phone will ask you once.';

  @override
  String get livePermissionBodyAudio =>
      'Kabso Live uses the microphone only while you\'re in the audio room, so people can hear you. No camera is needed here. Your phone will ask you once.';

  @override
  String get livePermissionContinue => 'Continue';

  @override
  String get livePermissionNotNow => 'Not now';

  @override
  String get livePermissionOpenSettings => 'Open settings';

  @override
  String get livePermissionBlockedVideo =>
      'You turned access off earlier and your phone won\'t ask again. Open Settings, then Permissions, and allow the camera and microphone.';

  @override
  String get livePermissionBlockedAudio =>
      'You turned access off earlier and your phone won\'t ask again. Open Settings, then Permissions, and allow the microphone.';

  @override
  String get goLiveMicDeniedTitle => 'Allow the microphone';

  @override
  String get goLiveMicDeniedBody =>
      'The audio room needs it so people can hear you. Tap Retry and your phone will ask again.';

  @override
  String get livePermissionSeatRefused =>
      'You can\'t take a seat without allowing access.';

  @override
  String get pushPermissionTitle => 'Turn on notifications';

  @override
  String get pushPermissionBody =>
      'Hear Kabso Live\'s sound when a message arrives in your family chat, and when someone follows you, likes or comments. You can change this any time in Settings.';

  @override
  String get pushPermissionAllow => 'Allow notifications';

  @override
  String get pushPermissionNotNow => 'Not now';

  @override
  String get pushOffTitle => 'Notifications are off on this phone';

  @override
  String get pushOffBody =>
      'Turn them on to hear about new messages and activity, even when the app is closed.';

  @override
  String get pushOffBlockedBody =>
      'You turned notifications off earlier and your phone won\'t ask again. Open Settings and turn on notifications for Kabso Live.';

  @override
  String get pushTurnOn => 'Turn on';

  @override
  String get pushOpenSettings => 'Open settings';

  @override
  String get notifSettingMessages => 'Messages';

  @override
  String get notifSettingMessagesBody =>
      'A notification on your phone for new messages in your family chat and your direct messages';

  @override
  String get liveMaxXGuaranteed => 'Guaranteed';

  @override
  String liveLuckyOddsPity(String multiplier, String after) {
    return '×$multiplier guaranteed after $after draws without a win';
  }

  @override
  String liveLuckyTicker(String name, String multiplier, String room) {
    return '$name won ×$multiplier in $room';
  }

  @override
  String get dmTabChats => 'Chats';

  @override
  String get dmTabRequests => 'Requests';

  @override
  String dmTabRequestsCount(String count) {
    return 'Requests ($count)';
  }

  @override
  String get dmRequestsEmptyTitle => 'No message requests';

  @override
  String get dmRequestsHint =>
      'Messages from people you don\'t follow wait here. They won\'t know you\'ve seen them until you accept.';

  @override
  String get dmRetentionNotice =>
      'Messages are deleted automatically 24 hours after they are sent.';

  @override
  String get dmNoRecentMessages => 'No messages in the last 24 hours.';

  @override
  String get dmLastPhoto => '📷 Photo';

  @override
  String get dmPreviewVoice => '🎤 Voice message';

  @override
  String get dmPreviewSticker => 'Sticker';

  @override
  String dmPreviewGift(String count) {
    return '🎁 Gift ×$count';
  }

  @override
  String get dmPreviewExpired => 'Messages expired';

  @override
  String dmPreviewYou(String text) {
    return 'You: $text';
  }

  @override
  String get dmPreviewUnsupported => 'A message this version can\'t show';

  @override
  String dmRequestBanner(String name) {
    return '$name wants to send you messages. Accept to move the chat to your messages.';
  }

  @override
  String get dmAccept => 'Accept';

  @override
  String get dmDecline => 'Delete';

  @override
  String dmRequestLeft(String name, String count) {
    return 'Until $name replies you can send $count more';
  }

  @override
  String dmRequestLimit(String name) {
    return 'Wait for $name to reply before sending more.';
  }

  @override
  String dmNotAllowed(String name) {
    return '$name doesn\'t accept messages from you.';
  }

  @override
  String get dmUnavailable => 'This conversation isn\'t available.';

  @override
  String get dmMenu => 'Conversation options';

  @override
  String get dmMute => 'Mute';

  @override
  String get dmUnmute => 'Unmute';

  @override
  String get dmMuted => 'Conversation muted';

  @override
  String get dmUnmuted => 'Conversation unmuted';

  @override
  String get dmDeleteConversation => 'Delete conversation';

  @override
  String get dmDeleteConversationTitle => 'Delete this conversation?';

  @override
  String get dmDeleteConversationBody =>
      'It disappears for you only. A new message brings it back.';

  @override
  String get dmReportPerson => 'Report';

  @override
  String get dmDeleteForMe => 'Delete for me';

  @override
  String get dmDeleteForEveryone => 'Delete for everyone';

  @override
  String get dmReportMessage => 'Report message';

  @override
  String get dmReported => 'Thanks. We\'ll review it.';

  @override
  String get dmVideoNotSupported =>
      'Videos can\'t be sent in messages. Send a photo instead.';

  @override
  String get dmPhotoUnsupported =>
      'This photo type can\'t be sent. Choose a JPEG, PNG or WebP photo.';

  @override
  String get dmSending => 'Sending…';

  @override
  String get dmGiftRequestTitle => 'Send a gift as a message request?';

  @override
  String dmGiftRequestBody(String name) {
    return '$name hasn\'t accepted your messages yet. The gift is paid now and counts as one of your request messages, even if they never accept.';
  }

  @override
  String get dmGiftContinue => 'Continue';

  @override
  String dmGiftMine(String count) {
    return 'Your gift ×$count';
  }

  @override
  String dmGiftTheirs(String name, String count) {
    return 'Gift from $name ×$count';
  }

  @override
  String dmLuckyWon(String coins, String multiplier) {
    return 'Won $coins coins (×$multiplier)';
  }

  @override
  String get dmLuckyNoWin => 'No win this time';

  @override
  String dmVoiceNote(String length) {
    return 'Voice message, $length';
  }

  @override
  String get dmPhoto => 'Photo';

  @override
  String get dmStartConversation => 'Send a message to start the conversation.';

  @override
  String get privacyMessageTitle => 'Who can message you';

  @override
  String get privacyMessageHint =>
      'People you don\'t follow send message requests. Messages are deleted 24 hours after they are sent.';

  @override
  String get errorDmNotAllowed =>
      'This person doesn\'t accept messages from you.';

  @override
  String get errorDmRequestLimit =>
      'Wait for a reply before sending more messages.';

  @override
  String get errorDmRequestTextOnly =>
      'Only text, stickers and gifts can be sent until your request is accepted.';

  @override
  String get errorDmDeleteWindowPassed =>
      'This message can no longer be deleted for everyone.';

  @override
  String get liveGiftTabQuips => 'Quips';

  @override
  String get liveQuipFree => 'Free';

  @override
  String get liveQuipSoundboardFree => '∞ Free';

  @override
  String get liveQuipFreeOnce => 'One free quip for you in each live.';

  @override
  String get liveQuipSoundboardHint =>
      'Free for you and your moderators — one sound every 2 seconds, heard by everyone.';

  @override
  String get liveQuipSoundEffectsOff =>
      'Sound effects are off in Settings: you won\'t hear them, but the room will.';

  @override
  String get liveQuipSoundboardTitle => 'Sound effects';

  @override
  String get liveQuipSoundboardEmpty => 'No free sounds yet.';

  @override
  String get liveQuipMute => 'Mute quips';

  @override
  String get liveQuipUnmute => 'Unmute quips';

  @override
  String liveQuipQueued(int seconds) {
    return 'Queued — starts in $seconds s';
  }

  @override
  String liveQuipBannerSent(String words) {
    return 'sent a quip: $words';
  }

  @override
  String liveChatQuipLine(String sender, String words) {
    return '$sender sent a quip: $words';
  }

  @override
  String get errorQuipFreeUsed => 'You\'ve used your free quip in this live.';

  @override
  String get errorQuipQueueFull =>
      'Too many quips are waiting. Try again in a moment.';

  @override
  String get liveBoostTitle => 'Visit rockets';

  @override
  String liveBoostHint(int slots) {
    return 'Pick a rocket: your live shows at the top of the live list, marked «Featured» with a moving frame. Only $slots places; when they\'re full it waits its turn.';
  }

  @override
  String liveBoostGiftHint(String name) {
    return 'A gift for $name: a rocket lifts their live to the top of the list, marked «Featured». The host earns no coins from it.';
  }

  @override
  String liveBoostMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return '$_temp0';
  }

  @override
  String liveBoostPrice(String coins) {
    return '$coins coins';
  }

  @override
  String liveBoostSave(int percent) {
    return 'Save $percent%';
  }

  @override
  String liveBoostHeld(int count) {
    return 'You have $count';
  }

  @override
  String get liveBoostStartsNow => 'Starts right away.';

  @override
  String liveBoostStartsIn(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'All places taken: starts within $_temp0 at the latest.';
  }

  @override
  String liveBoostUseCard(int count) {
    return 'Use a card (you have $count)';
  }

  @override
  String get liveBoostUseCardAction => 'Use the card';

  @override
  String liveBoostBuy(String coins) {
    return 'Buy for $coins coins';
  }

  @override
  String get liveBoostConfirmTitle => 'Visit rockets';

  @override
  String liveBoostConfirmCoins(int minutes, String coins) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return '$_temp0 in the featured places for $coins coins?';
  }

  @override
  String liveBoostConfirmCard(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Use a card of $_temp0?';
  }

  @override
  String get liveBoostConfirmAction => 'Confirm';

  @override
  String get liveBoostDoneNow =>
      'Lift-off: the live is featured at the top of the list now.';

  @override
  String liveBoostDoneWaiting(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Queued: starts within $_temp0 at the latest.';
  }

  @override
  String liveBoostRunning(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'Featured now — ends in $_temp0.';
  }

  @override
  String liveBoostWaiting(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'A rocket is queued — starts within $_temp0 at the latest.';
  }

  @override
  String get liveBoostLoadError => 'Couldn\'t load the visit rockets';

  @override
  String get liveBoostFeatured => 'Featured';

  @override
  String get liveBoostGiftAction => 'Visit rocket';

  @override
  String liveRocketStage(int stage) {
    return 'Rocket $stage';
  }

  @override
  String get errorBoostQueueFull =>
      'The featured places are booked far ahead; try a shorter card or later.';

  @override
  String get errorBoostCardInsufficient => 'You have no card of that length.';

  @override
  String get errorBoostRoomBusy =>
      'This live already has a visit rocket running or queued.';

  @override
  String get liveNewcomerBadge => 'New 🌱';

  @override
  String liveNewcomersHint(int days) {
    return 'Accounts less than $days days old, in this live now.';
  }

  @override
  String get liveNewcomersEmpty => 'No newcomers in this live right now.';

  @override
  String get liveNewcomersLoadError => 'Couldn\'t load the newcomers';

  @override
  String get liveNewcomerWelcome => 'Welcome';

  @override
  String get liveNewcomerWelcomed => 'Welcomed ✓';

  @override
  String liveNewcomerWelcomeText(String username) {
    return 'Welcome @$username 🌱 glad you\'re here';
  }

  @override
  String get liveStatsGiftCoins => 'Gifts\' value';

  @override
  String get liveStatsEarnings => 'Your earnings (display only)';

  @override
  String liveDataDuration(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get liveDataLoadError => 'Couldn\'t load the data center';

  @override
  String get liveDataLives => 'Lives';

  @override
  String get liveDataLiveTime => 'Live time';

  @override
  String get liveDataNewFollowers => 'New followers';

  @override
  String get liveDataViewers => 'Viewers';

  @override
  String get liveDataChartTitle => 'Live time over time';

  @override
  String get liveDataEmpty => 'No ended lives in this period.';

  @override
  String get liveDataBestHours => 'Best hours';

  @override
  String liveDataBestHourSemantics(String day, int hour) {
    return 'Best time: $day at $hour:00';
  }

  @override
  String get liveDataPeriodDay => 'Day';

  @override
  String get liveDataPeriodWeek => 'Week';

  @override
  String get liveDataPeriodMonth => 'Month';

  @override
  String get liveDataPeriodYear => 'Year';

  @override
  String get liveDataHint =>
      'Your ended lives only; the live on now counts once it ends.';

  @override
  String get liveDataMon => 'Mon';

  @override
  String get liveDataTue => 'Tue';

  @override
  String get liveDataWed => 'Wed';

  @override
  String get liveDataThu => 'Thu';

  @override
  String get liveDataFri => 'Fri';

  @override
  String get liveDataSat => 'Sat';

  @override
  String get liveDataSun => 'Sun';

  @override
  String get liveProgramTitle => 'Program';

  @override
  String get liveProgramNow => 'Now';

  @override
  String liveProgramNext(String time) {
    return 'Next at $time';
  }

  @override
  String get liveProgramStarted => 'Starting now';

  @override
  String get liveProgramOpenHint => 'show the program';

  @override
  String get liveProgramEmpty => 'No segments yet';

  @override
  String get liveProgramEditorHint =>
      'Up to 10 segments. Everyone in the room sees them, and each one is announced when it starts.';

  @override
  String get liveProgramTitleHint => 'Segment title';

  @override
  String liveProgramTimeLabel(String time) {
    return 'Starts at $time, change it';
  }

  @override
  String get liveProgramAdd => 'Add a segment';

  @override
  String get liveProgramRemove => 'Remove the segment';

  @override
  String get liveProgramSave => 'Save the program';

  @override
  String get liveProgramOrderError =>
      'Put the segments in order of their start times';

  @override
  String liveAssistantWelcomeOne(String name) {
    return 'Welcome $name, who just joined';
  }

  @override
  String liveAssistantWelcomeMany(String name, int count) {
    return 'Welcome $name and $count more who just joined';
  }

  @override
  String liveAssistantThank(String name, String coins) {
    return 'Thank $name for a gift worth $coins coins';
  }

  @override
  String liveAssistantSilence(int minutes) {
    return 'You haven\'t spoken for $minutes minutes, say something to the room';
  }

  @override
  String liveAssistantRising(int before, int now) {
    return 'More people are here: $before to $now. Keep going';
  }

  @override
  String liveAssistantFalling(int before, int now) {
    return 'Fewer people now: $before to $now. Try something new or a question';
  }

  @override
  String liveAssistantRest(int hours) {
    return 'You\'ve been live for $hours hours, take a short break';
  }

  @override
  String get liveAssistantQuestion =>
      'The chat is quiet, ask the room a question';

  @override
  String get liveAssistantDismiss => 'hide';

  @override
  String get liveAssistantAbout =>
      'Light hints only you see during your live, from the room\'s own events. Nothing is sent anywhere.';

  @override
  String get liveAssistantOn => 'Assistant on';

  @override
  String get liveAssistantKindWelcome => 'Welcome people who join';

  @override
  String get liveAssistantKindThank => 'Thank big gifts';

  @override
  String get liveAssistantKindSilence => 'Remind me when I\'m quiet';

  @override
  String get liveAssistantKindAudience => 'Audience up or down';

  @override
  String get liveAssistantKindRest => 'Breaks in long lives';

  @override
  String get liveAssistantKindQuestion =>
      'Suggest a question when the chat is quiet';

  @override
  String get liveToolQuality => 'Quality';

  @override
  String get liveQualitySmooth => 'Smooth';

  @override
  String get liveQualitySmoothDetail => '480p, lighter on a weak connection';

  @override
  String get liveQualityNormal => 'Normal';

  @override
  String get liveQualityNormalDetail => '720p, the default';

  @override
  String get liveQualityConnExcellent => 'Connection excellent';

  @override
  String get liveQualityConnGood => 'Connection good';

  @override
  String get liveQualityConnPoor => 'Connection weak';

  @override
  String get liveQualityConnLost => 'Connection lost, retrying';

  @override
  String get liveQualityConnUnknown => 'Measuring the connection';

  @override
  String get liveQualityFailed =>
      'Couldn\'t change the quality, it stays as it was';

  @override
  String get liveQualitySuggest => 'Your connection is weak, switch to Smooth?';

  @override
  String get liveQualitySuggestAction => 'Switch';

  @override
  String get liveQualityHigh => 'High 1080p';

  @override
  String get liveQualityHighDetail =>
      '1080p at 30 fps, back to 720p by itself if the connection weakens';

  @override
  String get liveQualityHighSlowUplink =>
      'Your upload speed is below what 1080p needs right now';

  @override
  String get liveQualityHighUnsupported =>
      'This camera doesn\'t capture 1080p, the quality stays as it was';

  @override
  String get liveQualityHighFallback =>
      'Quality lowered because of a weak connection';

  @override
  String get liveQualitySmoothOn => 'Smooth is on';

  @override
  String get liveStickersHint =>
      'Up to 3 stickers everyone sees. Drag a sticker on the live to move it; use two fingers to resize and rotate it.';

  @override
  String liveStickersOnLive(int count, int max) {
    return 'On the live ($count of $max)';
  }

  @override
  String get liveStickersNone => 'No stickers yet';

  @override
  String get liveStickersFull =>
      '3 stickers at most, remove one to add another';

  @override
  String get liveStickersRemove => 'Remove the sticker';

  @override
  String get liveStickersTextHint => 'Write a text sticker';

  @override
  String get liveStickersAddText => 'Add';

  @override
  String get errorYoutubeVideoUnavailable =>
      'This video can\'t be played here. It may be private or blocked outside YouTube.';

  @override
  String get errorYoutubeSearchUnavailable =>
      'YouTube search isn\'t available yet. Paste the video\'s link.';

  @override
  String get liveWatchTitle => 'YouTube';

  @override
  String get liveWatchLinkHint => 'Paste a YouTube link';

  @override
  String get liveWatchPlay => 'Watch together';

  @override
  String get liveWatchSearchHint => 'Search YouTube';

  @override
  String get liveWatchSearchOff => 'Search isn\'t on yet, paste a link';

  @override
  String get liveWatchNowPlaying => 'Now showing';

  @override
  String get liveWatchStop => 'Stop showing';

  @override
  String liveWatchSuggestions(int count) {
    return 'Viewers\' suggestions ($count)';
  }

  @override
  String get liveWatchNoSuggestions => 'No suggestions now';

  @override
  String get liveWatchApprove => 'Show it';

  @override
  String get liveWatchReject => 'Dismiss';

  @override
  String liveWatchSuggestedBy(String name) {
    return 'Suggested by $name';
  }

  @override
  String get liveWatchSuggest => 'Suggest a video';

  @override
  String get liveWatchSuggestSend => 'Send the suggestion';

  @override
  String get liveWatchSuggestSent => 'Your suggestion reached the host';

  @override
  String get liveWatchBadLink => 'That isn\'t a YouTube video link';

  @override
  String get liveWatchHide => 'Hide the video';

  @override
  String get liveWatchShow => 'Show the video';

  @override
  String get liveWatchDrag => 'Drag to move the video window';

  @override
  String get liveWatchPlayerError => 'The video couldn\'t play on this phone';

  @override
  String liveWatchNewSuggestion(String title) {
    return 'New suggestion: $title';
  }

  @override
  String get liveWinTierWin => 'WIN';

  @override
  String get liveWinTierHuge => 'HUGE WIN';

  @override
  String liveWinBannerSemantics(
    String label,
    String name,
    String multiplier,
    String coins,
  ) {
    return '$label: $name won ×$multiplier, $coins coins';
  }

  @override
  String liveWinBannerSent(String name, String gift) {
    return '$name sent $gift';
  }

  @override
  String liveWinBannerWon(String multiplier, String coins) {
    return 'won $multiplier and got $coins';
  }

  @override
  String get meHubOpenProfile => 'Open your profile';

  @override
  String get meHubFans => 'Fans';

  @override
  String get meHubLevels => 'Levels';

  @override
  String get meHubVip => 'Purchase VIP';

  @override
  String get meHubEarn => 'Earn money';

  @override
  String get meHubCreatorCenter => 'Creator Center';

  @override
  String get meHubEventCenter => 'Event Center';

  @override
  String get meHubWallet => 'Wallet';

  @override
  String get meHubItemBag => 'Item Bag';

  @override
  String get meHubMyProfile => 'My profile';

  @override
  String get meHubSvip => 'SVIP';

  @override
  String get meHubTaskCenter => 'Task Center';

  @override
  String get meHubRanking => 'Ranking';

  @override
  String meHubSoonItem(String item) {
    return '$item, coming soon';
  }

  @override
  String meHubCoins(String coins) {
    return '$coins coins';
  }

  @override
  String get createMenuTitle => 'Create';

  @override
  String get createMenuPost => 'Post';

  @override
  String get createMenuPostHint => 'Photos, a video or text';

  @override
  String get createMenuReel => 'Reel';

  @override
  String get createMenuReelHint => 'A short vertical video for Moments';

  @override
  String get createMenuStory => 'Story';

  @override
  String get createMenuStoryHint => 'A photo for 24 hours';

  @override
  String get createMenuLive => 'Go live';

  @override
  String get createMenuLiveHint => 'Video or voice, right now';

  @override
  String get createVideoUpTo => 'One video, up to 90 seconds';

  @override
  String get createLibraryVideo => 'Video';

  @override
  String get createLibraryNoVideos => 'There are no videos on this device.';

  @override
  String get createPickVideo => 'Choose a video';

  @override
  String get createRemoveVideo => 'Remove video';

  @override
  String createVideoLabel(String length) {
    return 'Video, $length';
  }

  @override
  String get createVideoOrPhotos =>
      'A post holds photos or one video, not both.';

  @override
  String get createVideoTooLong => 'Videos in posts can be up to 90 seconds.';

  @override
  String get createVideoTooLarge => 'This video is larger than 200 MB.';

  @override
  String get createVideoTooShort => 'Choose a video of at least 1 second.';

  @override
  String get createVideoUnsupported =>
      'This video format isn\'t supported. Use MP4 or MOV.';

  @override
  String get createVideoUnreadable =>
      'This video couldn\'t be read on this device.';

  @override
  String get createVideoInvalid =>
      'The video couldn\'t be processed. Try another one.';

  @override
  String get createVideoUploadsUnavailable =>
      'Video uploads aren\'t available right now. Try again later.';

  @override
  String createUploadingVideo(int percent) {
    return 'Uploading the video… $percent%';
  }

  @override
  String get createPostedVideoInReview =>
      'Shared. Others will see it once the video is reviewed';

  @override
  String get reelNewTitle => 'New reel';

  @override
  String get reelNewBody =>
      'A vertical video up to 60 seconds. It shows in Moments.';

  @override
  String get reelPickVideo => 'Choose a video';

  @override
  String get reelChangeVideo => 'Change video';

  @override
  String get reelCaptionHint => 'Write a caption… #hashtags @mentions';

  @override
  String get reelShare => 'Share';

  @override
  String get reelShared => 'Your reel is shared';

  @override
  String get reelSharedInReview =>
      'Shared. Others will see your reel once it is reviewed';

  @override
  String get reelTooLong => 'A reel can be up to 60 seconds.';

  @override
  String get reelTooLarge => 'This video is larger than 100 MB.';

  @override
  String get reelVertical =>
      'Reels look best vertical; this video will show with bars.';

  @override
  String get reelPreview => 'The reel\'s first frame';

  @override
  String get videoPlay => 'Play video';

  @override
  String get videoPause => 'Pause video';

  @override
  String get videoMute => 'Mute';

  @override
  String get videoUnmute => 'Turn sound on';

  @override
  String get videoCannotPlay => 'This video can\'t play right now';

  @override
  String get liveGuestCamera => 'Camera';

  @override
  String get liveGuestCameraOff => 'Camera off';

  @override
  String get liveMiniOpen => 'Back to the live';

  @override
  String get liveMiniLeave => 'Leave the live';

  @override
  String get walletBalanceLabel => 'Coin balance';

  @override
  String get walletRecharge => 'Recharge';

  @override
  String get walletRechargeSoon =>
      'Recharge is coming soon — the payment method isn\'t decided yet.';

  @override
  String get walletHistoryTitle => 'Transaction history';

  @override
  String get walletHistoryEmpty => 'No transactions yet';

  @override
  String get walletHistoryEmptyBody =>
      'Every change to your balance shows here.';

  @override
  String get walletLoadError => 'Couldn\'t load your wallet';

  @override
  String walletBalanceAfter(String coins) {
    return 'Balance after: $coins';
  }

  @override
  String get walletReasonAdminGrant => 'Granted by the team';

  @override
  String get walletReasonAdminRevoke => 'Removed by the team';

  @override
  String get walletReasonBulletMessage => 'Bullet message';

  @override
  String get walletReasonFamilyCreate => 'Family created';

  @override
  String get walletReasonCpRequest => 'CP request';

  @override
  String get walletReasonCpRefund => 'CP request refund';

  @override
  String get walletReasonCpGift => 'CP gift';

  @override
  String get walletReasonLiveGift => 'Gift in a live';

  @override
  String get walletReasonLuckyGift => 'Lucky gift';

  @override
  String get walletReasonLuckyGiftWin => 'Lucky gift win';

  @override
  String get walletReasonPremiumRent => 'Premium username rent';

  @override
  String get walletReasonPremiumRenew => 'Premium username renewal';

  @override
  String get walletReasonDmGift => 'Gift in a chat';

  @override
  String get walletReasonLiveBoost => 'Visit rocket';

  @override
  String get walletReasonLiveBoostRefund => 'Visit rocket refund';

  @override
  String get walletReasonOther => 'Balance change';

  @override
  String get earnTotal => 'Your total earnings';

  @override
  String get earnLast7Days => 'Last 7 days';

  @override
  String get earnLast30Days => 'Last 30 days';

  @override
  String get earnDisplayOnly =>
      'Earnings are display only: your share of the gifts you receive in lives and chats. They are not added to your coins.';

  @override
  String get earnWithdraw => 'Withdraw';

  @override
  String get earnWithdrawSoon =>
      'Withdrawal is coming soon — the payout method isn\'t decided yet.';

  @override
  String get earnHistoryTitle => 'Earnings history';

  @override
  String get earnEmpty => 'No earnings yet';

  @override
  String get earnEmptyBody =>
      'When you receive gifts in lives or chats, your share shows here.';

  @override
  String get earnLoadError => 'Couldn\'t load your earnings';

  @override
  String earnGiftLine(String gift, int quantity) {
    return '$gift × $quantity';
  }

  @override
  String earnFrom(String name) {
    return 'From $name';
  }

  @override
  String get earnFromHidden => 'From an unavailable account';

  @override
  String get earnContextLive => 'In a live';

  @override
  String get earnContextDm => 'In a chat';

  @override
  String earnShare(String percent, String coins) {
    return 'Your $percent% of $coins';
  }

  @override
  String get creatorPeriod7 => '7 days';

  @override
  String get creatorPeriod30 => '30 days';

  @override
  String get creatorPeriodAll => 'All time';

  @override
  String get creatorFollowers => 'Followers';

  @override
  String get creatorFollowersTotal => 'All followers';

  @override
  String get creatorFollowersNew => 'Followed you in this period';

  @override
  String get creatorPosts => 'Posts';

  @override
  String get creatorReels => 'Reels';

  @override
  String get creatorPublished => 'Published';

  @override
  String get creatorViews => 'Views';

  @override
  String get creatorLikes => 'Likes';

  @override
  String get creatorComments => 'Comments';

  @override
  String get creatorShares => 'Shares';

  @override
  String get creatorContentHint =>
      'What you published in this period, with its numbers so far.';

  @override
  String get creatorNoPosts => 'Nothing published in this period.';

  @override
  String get creatorLive => 'Live';

  @override
  String get creatorLiveHint =>
      'Lives that started in this period and have ended.';

  @override
  String get creatorNoLives => 'No ended lives in this period.';

  @override
  String get creatorPeakViewers => 'Peak viewers';

  @override
  String get creatorOpenProfile => 'My posts and reels';

  @override
  String get creatorTabLive => 'Live';

  @override
  String get creatorTabAgency => 'Agency';

  @override
  String creatorMonthData(String month) {
    return '$month data';
  }

  @override
  String get creatorLiveData => 'Live Data';

  @override
  String get creatorLiveMinutes => 'Live minutes';

  @override
  String get creatorNewFans => 'New followers';

  @override
  String get creatorNewEarnings => 'New earnings';

  @override
  String get creatorServices => 'Live Services';

  @override
  String get creatorSvcPreview => 'Live Preview';

  @override
  String get creatorSvcCover => 'Cover Adjustment';

  @override
  String get creatorSvcEvents => 'Check my events';

  @override
  String get creatorSvcHostLevel => 'Host level';

  @override
  String get creatorSvcViolations => 'Account Violations';

  @override
  String get creatorSvcAcademy => 'Host Academy';

  @override
  String get creatorSvcSupport => 'Customer Services';

  @override
  String get creatorSvcIdentity => 'Real name authentication';

  @override
  String get creatorSvcFans => 'Fan Growth';

  @override
  String get creatorTrafficHint =>
      'Buy a visit rocket from Room Tools during your live.';

  @override
  String get creatorGoLive => 'Go Live';

  @override
  String get creatorLoadError => 'Couldn\'t load your statistics';

  @override
  String get dmSearch => 'Search conversations';

  @override
  String get dmSearchHint => 'Search by name or username';

  @override
  String get dmSearchClose => 'Close search';

  @override
  String dmSearchEmpty(String query) {
    return 'No conversation matches “$query”';
  }

  @override
  String get dmNewMessageHint => 'Type a name or a username';

  @override
  String get dmNewMessageEmpty => 'No one found with that name';

  @override
  String get dmNewMessageStart => 'Search for someone to start a conversation';

  @override
  String get dmConversationActions => 'Conversation options';

  @override
  String get dmMarkRead => 'Mark as read';

  @override
  String get dmMarkUnread => 'Mark as unread';

  @override
  String get dmMarkedUnread => 'Marked as unread';

  @override
  String get dmCopy => 'Copy';

  @override
  String get dmCopied => 'Message copied';

  @override
  String get dmViewProfile => 'View profile';

  @override
  String get chatVoiceUnavailable =>
      'Voice messages aren\'t available on this device';

  @override
  String get profileEditPhotoSheetTitle => 'Profile photo';

  @override
  String get profileEditPhotoLibrary => 'Choose from photos';

  @override
  String get profileEditPhotoCamera => 'Take a photo';

  @override
  String get profileEditPhotoRemove => 'Remove photo';

  @override
  String get profileEditPhotoUpdated => 'Your photo was updated';

  @override
  String get profileEditPhotoRemoved => 'Your photo was removed';

  @override
  String get profileEditPhotoUploading => 'Uploading photo…';

  @override
  String get profileEditCropTitle => 'Crop photo';

  @override
  String get profileEditCropHint =>
      'Drag and zoom the photo to fill the square';

  @override
  String get profileEditCropDone => 'Done';

  @override
  String get profileEditSaved => 'Saved';

  @override
  String get profileEditBioPlaceholder => 'Add a bio';

  @override
  String profileEditBioTooLong(int max, int lines) {
    return 'A bio can be up to $max characters and $lines lines.';
  }

  @override
  String get profileEditBioInvalid =>
      'The bio has characters that aren\'t allowed.';

  @override
  String get profileEditNameHelp =>
      'Your name shows on your profile, in lives and in messages. Other accounts can have the same name.';

  @override
  String get profileEditBioHelp =>
      'Your bio is shown to everyone on your profile.';

  @override
  String createLibraryVideoTooLong(String length, int seconds) {
    return 'Video, $length, longer than $seconds seconds, can\'t be used';
  }

  @override
  String get tasksLoadError => 'Couldn\'t load the tasks';

  @override
  String get tasksCheckInCalendar => 'Calendar';

  @override
  String tasksCheckInMoreDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days more check-ins bring an extra reward',
      one: '$days more check-in brings an extra reward',
    );
    return '$_temp0';
  }

  @override
  String get tasksCalendarTitle => 'Check-in calendar';

  @override
  String tasksCalendarBody(String coins) {
    return 'Check in every day: every 7th day in a row adds $coins extra coins, and a missed day starts again.';
  }

  @override
  String tasksDayCoins(String coins) {
    return '$coins coins';
  }

  @override
  String get eventsTitle => 'Activities';

  @override
  String get tasksCheckInTitle => 'Check-in rewards';

  @override
  String tasksCheckInBonusToday(String coins) {
    return 'Today is bonus day: $coins extra coins';
  }

  @override
  String get tasksCheckInAction => 'Check in';

  @override
  String tasksStreak(String days) {
    return '$days days in a row';
  }

  @override
  String get tasksToday => 'Today';

  @override
  String tasksDailyCap(String earned, String cap) {
    return 'Today\'s rewards: $earned of $cap cherries';
  }

  @override
  String tasksMonthlyCap(String earned, String cap) {
    return 'This month\'s rewards: $earned of $cap cherries';
  }

  @override
  String get tasksRewardsTitle => 'Task rewards';

  @override
  String get tasksWeeklyTitle => 'Weekly host tasks';

  @override
  String get tasksWeeklyHint => 'They renew every Monday.';

  @override
  String get tasksCreatorTitle => 'Content creator tasks';

  @override
  String get tasksCreatorHint => 'Count toward today\'s rewards.';

  @override
  String get tasksCreatorWeeklyTitle => 'Weekly creator tasks';

  @override
  String get tasksEmpty => 'No tasks right now';

  @override
  String get tasksEmptyBody =>
      'Tasks will show up here when the Kabso team adds them.';

  @override
  String get tasksActionGo => 'Go';

  @override
  String get tasksActionClaim => 'Claim';

  @override
  String get tasksActionDone => 'Done';

  @override
  String tasksRewardReceived(String coins) {
    return 'You got $coins coins';
  }

  @override
  String get tasksNoCoinsCap => 'Done — you reached today\'s reward limit';

  @override
  String tasksRewardReceivedCherries(String cherries) {
    return 'You got $cherries cherries';
  }

  @override
  String get tasksCapReached => 'You reached today\'s task reward limit';

  @override
  String get tasksMonthlyCapReached =>
      'You reached this month\'s task reward limit';

  @override
  String get eventsTabCalendar => 'Event calendar';

  @override
  String get eventsTabPermanent => 'Permanent events';

  @override
  String get eventsTabRegional => 'Regional';

  @override
  String get eventsIntroTitle => 'Event calendar';

  @override
  String get eventsIntroBody =>
      'Kabso\'s main official events every month — see the rewards and how to take part early. Tap any event for details.';

  @override
  String eventsCalendarMonth(String month) {
    return '$month event calendar';
  }

  @override
  String get eventsPreviousMonth => 'Previous month';

  @override
  String get eventsNextMonth => 'Next month';

  @override
  String eventsMore(String count) {
    return 'and $count more';
  }

  @override
  String get eventsEmptyMonth => 'No events this month';

  @override
  String get eventsEmpty => 'No events right now';

  @override
  String get eventsEmptyBody =>
      'When the Kabso team announces an event, it will show up here.';

  @override
  String get eventsNoCountry => 'Set your country to see your region\'s events';

  @override
  String get eventsNoCountryBody =>
      'You can choose your country when you edit your profile.';

  @override
  String get eventsLoadError => 'Couldn\'t load the events';

  @override
  String get eventsEnded => 'Ended';

  @override
  String get eventsFeatured => 'Hot';

  @override
  String get eventsUpcoming => 'Coming up';

  @override
  String get eventsRunning => 'Live now';

  @override
  String eventsDates(String start, String end) {
    return '$start to $end';
  }

  @override
  String eventsSince(String start) {
    return 'Since $start';
  }

  @override
  String get eventsDetailTitle => 'Event details';

  @override
  String get eventsForHosts => 'Hosts only';

  @override
  String get eventsRules => 'Rules';

  @override
  String get eventsNoRules => 'No extra rules.';

  @override
  String get eventsPrizes => 'Prizes';

  @override
  String get eventsNoPrizes => 'This event has no prizes.';

  @override
  String get eventsPrizesReview =>
      'Prizes are paid automatically 24 hours after the event ends.';

  @override
  String get eventsPrizesPaid => 'The prizes have been paid.';

  @override
  String eventsRank(String rank) {
    return 'Place $rank';
  }

  @override
  String eventsRanks(String from, String to) {
    return 'Places $from–$to';
  }

  @override
  String get eventsBoard => 'Leaderboard';

  @override
  String get eventsBoardLive => 'Live';

  @override
  String get eventsBoardFinal => 'Final results';

  @override
  String get eventsBoardEmpty => 'No one on the board yet.';

  @override
  String eventsMeRank(String rank) {
    return 'Your place: $rank';
  }

  @override
  String get eventsMeNotRanked => 'You\'re not on the board yet';

  @override
  String get eventsMetricGiftsReceived => 'Gift coins received';

  @override
  String get eventsMetricGiftsSent => 'Gift coins sent';

  @override
  String get eventsMetricLiveMinutes => 'Live minutes';

  @override
  String get eventsMetricTaps => 'Taps received';

  @override
  String get eventsMetricFollowers => 'New followers';

  @override
  String get eventsMetricOther => 'Points';

  @override
  String get svipLoadError => 'Couldn\'t load SVIP';

  @override
  String get svipRules => 'SVIP rules';

  @override
  String svipRulesBody(String days) {
    return 'You earn SVIP by sending gifts: spend coins on gifts within $days days to reach a level, and it stays with you for 30 days from the last time you reached it. SVIP can\'t be bought with money.';
  }

  @override
  String get svipNotYet => 'You\'re not SVIP yet';

  @override
  String svipTier(String tier) {
    return 'SVIP $tier';
  }

  @override
  String svipUntil(String tier, String date) {
    return '$tier until $date';
  }

  @override
  String svipTrack(String tier, String count) {
    return 'Level $tier of $count';
  }

  @override
  String get svipLocked => 'Locked';

  @override
  String get svipUnlocked => 'Unlocked';

  @override
  String svipSpendToUpgrade(String coins, String days) {
    return 'Spend $coins coins on gifts within $days days to upgrade';
  }

  @override
  String svipSpent(String coins, String days) {
    return 'You spent $coins coins in the last $days days';
  }

  @override
  String get svipTop => 'You reached the top SVIP level';

  @override
  String get svipPerksTitle => 'SVIP perks';

  @override
  String get svipPerksSoon =>
      'Perks are being prepared and will switch on one by one.';

  @override
  String svipSpendMore(String coins, String tier) {
    return 'Spend $coins more coins to reach $tier';
  }

  @override
  String get svipCta => 'Send a gift';

  @override
  String get walletTabCoins => 'Coins';

  @override
  String get walletRechargeTitle => 'Recharge coins';

  @override
  String walletBonus(String coins) {
    return '$coins bonus';
  }

  @override
  String get walletOffer => 'Big deal';

  @override
  String walletGetCoins(String coins, String total) {
    return 'Get $coins coins · Total $total';
  }

  @override
  String get walletPackagesEmpty => 'No recharge packages right now';

  @override
  String get walletPackagesError => 'Couldn\'t load the recharge packages';

  @override
  String get walletReasonTaskReward => 'Task reward';

  @override
  String get walletReasonCheckIn => 'Check-in reward';

  @override
  String get walletReasonEventPrize => 'Event prize';

  @override
  String get registerGenderLabel => 'Gender';

  @override
  String get registerGenderHelper =>
      'Not shown on your profile unless you choose to later.';

  @override
  String get registerGenderRequired => 'Choose one';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderUndisclosed => 'Prefer not to say';

  @override
  String get categorySinger => 'Singer';

  @override
  String get categoryMusician => 'Musician';

  @override
  String get categoryPoet => 'Poet';

  @override
  String get categoryPresenter => 'Presenter';

  @override
  String get categoryGamer => 'Gamer';

  @override
  String get categoryContentCreator => 'Content creator';

  @override
  String get categoryAthlete => 'Athlete';

  @override
  String get categoryArtist => 'Artist';

  @override
  String get categoryBlogger => 'Blogger';

  @override
  String get categoryPublicFigure => 'Public figure';

  @override
  String get categoryOther => 'Other';

  @override
  String get profileEditNotSet => 'Not set';

  @override
  String get profileEditGenderShow => 'Show on my profile';

  @override
  String get profileEditGenderShowHint =>
      'Hidden by default. “Prefer not to say” is never shown.';

  @override
  String profileEditGenderHidden(String gender) {
    return '$gender · hidden';
  }

  @override
  String get profileEditCategoryNone => 'No category';

  @override
  String get profileEditCategoryHint =>
      'Shown under your name on your profile.';

  @override
  String profileEditLinksValue(int count) {
    return '$count of 3';
  }

  @override
  String get profileEditLinksHint =>
      'Up to 3 links starting with https://. Instagram, TikTok, YouTube, Facebook and X links open directly; any other link after a warning.';

  @override
  String get profileEditLinkUrl => 'Link';

  @override
  String get profileEditLinkLabel => 'Label (optional)';

  @override
  String get profileEditLinkAdd => 'Add a link';

  @override
  String get profileEditLinkRemove => 'Remove link';

  @override
  String get profileEditLinkInvalid =>
      'Not a valid link: it must start with https:// and name a website (no password, port or IP address).';

  @override
  String get profileEditLinkTooLong => 'The link is too long.';

  @override
  String profileEditLinkLabelTooLong(int max) {
    return 'The label is at most $max characters on one line.';
  }

  @override
  String get profileEditLinkDuplicate => 'This link is already added.';

  @override
  String get profileEditPinHint =>
      'Pin up to 3 posts to show them first on your profile, from a post’s “…” menu.';

  @override
  String get privacyPrivateTitle => 'Private account';

  @override
  String get privacyPrivateLabel => 'Private account';

  @override
  String get privacyPrivateHint =>
      'Only your followers see your posts, reels and stories. Anyone who wants to follow you sends a request you accept or decline. Lives stay public.';

  @override
  String get privacyMakePublicTitle => 'Make your account public?';

  @override
  String get privacyMakePublicBody =>
      'Everyone will see your posts, reels and stories, and every pending follow request will be accepted.';

  @override
  String get privacyMakePublicConfirm => 'Make public';

  @override
  String get followRequestsTitle => 'Follow requests';

  @override
  String get followRequestsEmptyTitle => 'No requests';

  @override
  String get followRequestsEmptyBody =>
      'When someone asks to follow your private account, they appear here.';

  @override
  String get followRequestAccept => 'Accept';

  @override
  String get followRequestDecline => 'Decline';

  @override
  String followRequestAccepted(String name) {
    return '$name follows you now';
  }

  @override
  String get followRequestDeclined => 'Request declined';

  @override
  String get followRequested => 'Requested';

  @override
  String profileCancelRequestConfirm(String name) {
    return 'Cancel your request to follow $name?';
  }

  @override
  String get profileCancelRequest => 'Cancel request';

  @override
  String get profileRequestSent => 'Follow request sent';

  @override
  String get linkLeavingTitle => 'You’re leaving Kabso';

  @override
  String get linkLeavingBody =>
      'This link opens a site outside Kabso. Make sure you trust it before you continue.';

  @override
  String get linkLeavingOpen => 'Open link';

  @override
  String get linkReport => 'Report link';

  @override
  String get linkReportTitle => 'Why are you reporting this link?';

  @override
  String get linkCopy => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get linkOpenFailed => 'Couldn’t open the link';

  @override
  String linkSemantics(String name) {
    return 'Link: $name';
  }

  @override
  String notifFollowRequest(String who) {
    return '$who asked to follow you';
  }

  @override
  String notifFollowRequestAccepted(String who) {
    return '$who accepted your follow request';
  }

  @override
  String get notifAvatarRemoved =>
      'Moderators removed your profile photo for breaking the community guidelines';

  @override
  String bagDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String bagHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '$hours hour',
    );
    return '$_temp0';
  }

  @override
  String bagMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return '$_temp0';
  }

  @override
  String bagDurationPair(String first, String second) {
    return '$first $second';
  }

  @override
  String bagRemaining(String duration) {
    return '$duration left';
  }

  @override
  String get bagEndsToday => 'Ends today';

  @override
  String get bagPermanent => 'Permanent';

  @override
  String get bagFromKabso => 'Gift from Kabso';

  @override
  String bagFromUser(String name) {
    return 'Gift from $name';
  }

  @override
  String get bagFromSomeone => 'Gift';

  @override
  String get bagFromLevel => 'Level reward';

  @override
  String get bagFromPurchase => 'Bought';

  @override
  String get bagSend => 'Send';

  @override
  String get bagNoSendFree => 'Free items can\'t be sent';

  @override
  String get bagNoSendLevel =>
      'Level rewards can\'t be sent: they belong to your level';

  @override
  String get bagNoSendOther => 'This item can\'t be sent';

  @override
  String get bagCategoryOther => 'Other items';

  @override
  String bagSendTitle(String item) {
    return 'Send $item';
  }

  @override
  String bagSendYouHave(String left) {
    return 'You have: $left';
  }

  @override
  String get bagSendAmount => 'How much to send?';

  @override
  String get bagSendAll => 'All';

  @override
  String get bagSendPermanentNote =>
      'A permanent item is sent whole and leaves your bag.';

  @override
  String get bagSendWholeNote =>
      'The item leaves your bag with all its remaining time.';

  @override
  String bagSendPartNote(String left) {
    return 'You keep: $left';
  }

  @override
  String get bagSendTo => 'To';

  @override
  String get bagSendSearchHint => 'Search by name or username';

  @override
  String get bagSendSearchStart => 'Choose who gets the item.';

  @override
  String get bagSendSearchEmpty => 'No one by that name.';

  @override
  String get bagSendChange => 'Change';

  @override
  String get bagSendConfirmTitle => 'Confirm sending';

  @override
  String bagSendConfirmBody(String item, String amount, String user) {
    return 'Send $item ($amount) to $user?';
  }

  @override
  String bagSendDone(String user) {
    return 'Sent to $user';
  }

  @override
  String get errorBagItemNotTransferable => 'This item can\'t be sent.';

  @override
  String get errorBagSendPermanentWholeOnly =>
      'A permanent item can only be sent whole.';

  @override
  String get errorBagSendExceedsRemaining =>
      'That\'s more time than the item has left.';

  @override
  String get errorBagRecipientHasPermanent =>
      'They already own this item permanently.';

  @override
  String notifBagItemReceived(String who, String item) {
    return '$who sent you $item';
  }

  @override
  String get notifBagItemProfileCard => 'a profile card';

  @override
  String get notifBagItemGeneric => 'an item for your bag';

  @override
  String get bagTabTools => 'Tools';

  @override
  String get bagTabItems => 'Item Bag';

  @override
  String get bagInUse => 'Tools in use';

  @override
  String get bagAllTools => 'All tools';

  @override
  String get bagUse => 'Use';

  @override
  String get bagNothingWorn => 'None';

  @override
  String get walletTabGold => 'Gold coins';

  @override
  String get walletTabCherries => 'Cherries';

  @override
  String get walletGoldBalance => 'My coin balance';

  @override
  String get walletCherryBalance => 'My cherry balance';

  @override
  String walletCherries(String cherries) {
    return '$cherries cherries';
  }

  @override
  String get walletRewards => 'Rewards';

  @override
  String get walletRewardsBase => 'Coins';

  @override
  String get walletRewardsBonus => 'Bonus';

  @override
  String get walletRewardsTotal => 'Total';

  @override
  String get walletGet => 'Get';

  @override
  String walletTotal(String total) {
    return 'Total: $total';
  }

  @override
  String get walletPayUnavailable => 'Payment isn\'t available yet';

  @override
  String get walletWithdraw => 'Withdraw';

  @override
  String cherryValue(Object amount) {
    return '≈ $amount';
  }

  @override
  String cherryHeld(Object cherries) {
    return 'Held for withdrawal: $cherries';
  }

  @override
  String get cherryUnitShort => '1 coin of your share of a gift = 10 cherries.';

  @override
  String cherryUnit(Object amount, Object cherries, Object min) {
    return '1 coin of your share of a gift = 10 cherries. $cherries cherries = $amount. Withdrawals from $min. Not the cherry score of a live.';
  }

  @override
  String get cherryHistoryTitle => 'Cherry history';

  @override
  String get cherryReasonGift => 'Gift received';

  @override
  String get cherryReasonAgency => 'Agency commission';

  @override
  String get cherryReasonParent => 'Agency admin commission';

  @override
  String get cherryReasonGiftReversal => 'Gift reversed by the team';

  @override
  String get cherryReasonCommissionReversal => 'Commission reversed';

  @override
  String get cherryReasonWithdrawal => 'Withdrawal request (held)';

  @override
  String get cherryReasonRefund => 'Withdrawal refused: cherries returned';

  @override
  String get cherryReasonTask => 'Task reward';

  @override
  String cherryTaskLocked(String cherries) {
    return '$cherries cherries from tasks are locked — they unlock for withdrawal once the earnings condition is met';
  }

  @override
  String get cherryReasonOther => 'Cherry change';

  @override
  String get cherryWithdrawalsTitle => 'Withdrawal requests';

  @override
  String get cherryWithdrawalPending => 'Waiting';

  @override
  String get cherryWithdrawalPaid => 'Paid';

  @override
  String get cherryWithdrawalRejected => 'Refused';

  @override
  String cherryWithdrawalLine(Object cherries) {
    return '$cherries cherries';
  }

  @override
  String cherryPendingNote(Object amount, Object days) {
    return 'Your request of $amount is waiting: the Kabso team pays it by hand within $days days.';
  }

  @override
  String get withdrawTitle => 'Withdraw cherries';

  @override
  String withdrawBalance(Object amount, Object cherries) {
    return 'Available: $cherries cherries ≈ $amount';
  }

  @override
  String withdrawRate(Object amount, Object cherries, Object min) {
    return '$cherries cherries = $amount · minimum $min';
  }

  @override
  String withdrawAmountLabel(Object currency) {
    return 'Amount ($currency)';
  }

  @override
  String withdrawAmountHelper(Object cherries) {
    return '= $cherries cherries';
  }

  @override
  String withdrawAmountMin(Object amount) {
    return 'At least $amount';
  }

  @override
  String withdrawAmountShort(Object amount) {
    return 'Your cherries cover up to $amount';
  }

  @override
  String get withdrawAmountInvalid => 'Enter an amount like 10 or 12.50';

  @override
  String get withdrawDetailsLabel => 'Where should we pay you?';

  @override
  String get withdrawDetailsHint =>
      'Bank name and IBAN, or wallet name and number';

  @override
  String withdrawManualNote(Object days) {
    return 'No automatic payout yet: the Kabso team checks your request and pays it by hand within $days days. The cherries are held now and come back to you if the request is refused.';
  }

  @override
  String get withdrawSubmit => 'Send the request';

  @override
  String withdrawSubmitAmount(Object amount) {
    return 'Request $amount';
  }

  @override
  String get withdrawSent => 'Withdrawal request sent';

  @override
  String get errorAgencyAlreadyMember =>
      'You\'re already a host of another agency.';

  @override
  String get errorAgencyJoinNotAllowed =>
      'An agency\'s agent can\'t join an agency as a host.';

  @override
  String get errorAgencyLeaveWindowClosed =>
      'The time to leave is over. Send a complaint to the admin.';

  @override
  String get errorInsufficientCherries =>
      'You don\'t have enough cherries for this amount.';

  @override
  String get errorWithdrawalPending =>
      'You already have a withdrawal request waiting to be paid.';

  @override
  String get meHubAgency => 'Agency';

  @override
  String get agencyTitle => 'Agency';

  @override
  String get agencyLoadError => 'Couldn\'t load the agency';

  @override
  String get agencyJoinTitle => 'Join an agency';

  @override
  String get agencyJoinBody =>
      'Enter your agent\'s invite code, check the agency, then accept.';

  @override
  String get agencyCodeLabel => 'Invite code';

  @override
  String get agencyFind => 'Show the agency';

  @override
  String get agencyNotFound => 'No agency has this code.';

  @override
  String agencyPreviewOwner(Object name) {
    return 'Agent: $name';
  }

  @override
  String agencyHostCount(Object count) {
    return 'Hosts: $count';
  }

  @override
  String get agencyAccept => 'Accept and join';

  @override
  String agencyLeaveRule(Object days) {
    return 'You can leave within $days days of joining; after that only through a complaint to the admin.';
  }

  @override
  String get agencyJoined => 'You joined the agency';

  @override
  String get agencyMyAgency => 'My agency';

  @override
  String agencyJoinedAt(Object date) {
    return 'Joined on $date';
  }

  @override
  String agencyLeaveUntil(Object date) {
    return 'You can leave until $date';
  }

  @override
  String agencyLeaveClosed(Object days) {
    return 'The $days days to leave are over. To leave, send a complaint to the admin.';
  }

  @override
  String get agencyLeave => 'Leave the agency';

  @override
  String get agencyLeaveConfirm =>
      'The agency stops earning a commission on your gifts. You can join another agency with its code.';

  @override
  String get agencyLeft => 'You left the agency';

  @override
  String get agencyComplain => 'Complain to the admin';

  @override
  String get agencyComplaintHint => 'What\'s the problem?';

  @override
  String get agencyComplaintSend => 'Send the complaint';

  @override
  String get agencyComplaintSent => 'Complaint sent to the admin';

  @override
  String agencyComplaintOpen(Object date) {
    return 'Your complaint is with the admin (sent on $date).';
  }

  @override
  String get agencyComplaintDone => 'The admin answered your complaint.';

  @override
  String get agencyInviteCode => 'Your invite code';

  @override
  String get agencyCopy => 'Copy the code';

  @override
  String get agencyCopied => 'Code copied';

  @override
  String get agencyInviteHint =>
      'Hosts enter this code in «Agency» and accept.';

  @override
  String get agencyRankTitle => 'Rank';

  @override
  String get agencyRankNew => 'New (grace period)';

  @override
  String get agencyRankAgent => 'Host agent';

  @override
  String get agencyRankAdmin => 'Agency admin';

  @override
  String get agencyRankLapsed => 'Not qualified this month';

  @override
  String agencyRate(Object percent) {
    return 'Your commission this month: $percent%';
  }

  @override
  String agencyRateNote(Object tier) {
    return 'Paid by Kabso on top of your hosts\' cherries, never taken from them. 16% in the month after your hosts earn $tier cherries in a month.';
  }

  @override
  String agencyParent(Object name) {
    return 'Agency admin: $name';
  }

  @override
  String get agencyProgressTitle => 'Progress';

  @override
  String agencyActiveHosts(Object count, Object required) {
    return 'Active hosts: $count / $required';
  }

  @override
  String agencyActiveRule(Object days, Object hours, Object window) {
    return 'Active = live on $days days and for $hours hours in the last $window days.';
  }

  @override
  String agencyMonthCherries(Object cherries) {
    return 'Your hosts\' cherries this month: $cherries';
  }

  @override
  String agencyException(Object cherries, Object hosts) {
    return 'Or $cherries cherries in a month with fewer than $hosts active hosts.';
  }

  @override
  String agencySubProgress(Object count, Object required) {
    return 'Qualified sub-agencies: $count / $required';
  }

  @override
  String get agencyQualifiesNow => 'You qualify now.';

  @override
  String get agencyNotQualifiedNow => 'You don\'t qualify yet.';

  @override
  String get agencyEvaluationNote =>
      'Ranks are checked at the start of each month and kept until its end.';

  @override
  String get agencyCommissionTitle => 'Commissions (cherries)';

  @override
  String get agencyThisMonth => 'This month';

  @override
  String get agencyLastMonth => 'Last month';

  @override
  String get agencyTotal => 'Total';

  @override
  String get agencyParentCommissionTitle => 'Agency admin commission (3%)';

  @override
  String get agencySubAgenciesTitle => 'Sub-agencies';

  @override
  String agencySubLine(Object active, Object cherries) {
    return '$active active · $cherries cherries this month';
  }

  @override
  String get agencyQualified => 'Qualified';

  @override
  String get agencyNotQualified => 'Not qualified';

  @override
  String agencyHostsTitle(Object count) {
    return 'Hosts ($count)';
  }

  @override
  String get agencyHostsEmpty => 'No hosts yet';

  @override
  String get agencyHostsEmptyBody => 'Share your invite code with hosts.';

  @override
  String get agencyHostActive => 'Active';

  @override
  String get agencyHostInactive => 'Not active';

  @override
  String agencyHostLine(Object cherries, Object days, Object hours) {
    return '$days days · $hours h live (30 days) · $cherries cherries this month';
  }

  @override
  String get agencyHostNoCommission =>
      'Joined while the agency wasn\'t qualified: no commission';

  @override
  String rechargeBadgeLabel(int tier) {
    return 'Daily recharge badge, tier $tier';
  }

  @override
  String rechargeAgentBadgeLabel(String code) {
    return 'Top-up agent $code';
  }

  @override
  String rechargeAgentFrameLabel(String name, String code) {
    return '$name, top-up agent $code';
  }

  @override
  String rechargeEntranceJoined(String name) {
    return 'Top-up agent $name joined the live';
  }

  @override
  String agentEntranceJoined(String name) {
    return '$name joined the live';
  }

  @override
  String rechargeAgentIdLine(String code) {
    return 'Top-up agent · $code';
  }

  @override
  String rechargeIdLine(String code) {
    return 'Top-up agent · $code';
  }

  @override
  String get rechargeTitle => 'Top-up agent';

  @override
  String get rechargeDirectoryTitle => 'Top-up agents';

  @override
  String get rechargeDirectoryHint =>
      'Buy coins from an agent in your country and pay them directly';

  @override
  String get rechargeBuyViaAgent => 'Top up through an agent';

  @override
  String get rechargeBecome => 'Become a top-up agent';

  @override
  String get rechargeIntroTitle => 'Sell Kabso coins in your country';

  @override
  String get rechargeIntroBody =>
      'An agent buys coins wholesale from Kabso and sells them to Kabso users, who pay the agent outside the app. Agents get a frame, a badge and a special room entrance.';

  @override
  String rechargeIntroActivation(String coins) {
    return 'An agent is activated by a first top-up of at least $coins coins.';
  }

  @override
  String get rechargePendingTitle => 'Your application is under review';

  @override
  String get rechargePendingBody =>
      'The Kabso team will contact you on WhatsApp. Your application is private: only the team sees it.';

  @override
  String get rechargeRejectedTitle => 'Your last application was not accepted.';

  @override
  String rechargeRejectedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get rechargeApplyAgain => 'Apply again';

  @override
  String get rechargeApprovedTitle =>
      'Approved — waiting for your first top-up';

  @override
  String rechargeApprovedBody(String coins) {
    return 'Activate your agency with a first top-up of at least $coins coins through the Kabso team. Your code and frame appear after activation.';
  }

  @override
  String get rechargeSuspendedTitle => 'Agency suspended';

  @override
  String get rechargeSuspendedBody =>
      'You can\'t sell now and you are not listed; the frame, badge and entrance are removed. Contact the Kabso team.';

  @override
  String get rechargeStock => 'Coin stock';

  @override
  String rechargeStockLabel(String coins) {
    return 'Coin stock: $coins';
  }

  @override
  String get rechargeSell => 'Sell coins';

  @override
  String get rechargeManage => 'Manage the agency';

  @override
  String get rechargeSalesTitle => 'Sales';

  @override
  String rechargeSalesTotals(int count, String coins) {
    return '$count sales\n$coins coins';
  }

  @override
  String get rechargeToday => 'Today';

  @override
  String get rechargeLast7 => '7 days';

  @override
  String get rechargeLast30 => '30 days';

  @override
  String rechargeCherryToday(String today, String cap) {
    return 'Hosts\' cherries today: $today of $cap';
  }

  @override
  String get rechargeEmployeesTitle => 'Employees';

  @override
  String get rechargeEmployeesHint =>
      'Add employees who sell from your stock during their hours';

  @override
  String get rechargeAvailabilityTitle => 'Contact times and payment';

  @override
  String get rechargeAvailabilityEmpty =>
      'No times yet: the contact button won\'t show in the directory';

  @override
  String rechargeSlotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count time slots',
      one: '$count time slot',
    );
    return '$_temp0';
  }

  @override
  String get rechargeAvailabilityNote =>
      'The WhatsApp number and payment method of the current slot are shown to everyone in the directory.';

  @override
  String get rechargeCherryBuyTitle => 'Buy hosts\' cherries';

  @override
  String get rechargeCherrySellTitle => 'Sell cherries to an agent';

  @override
  String rechargeCherryRate(String cherries, String coins) {
    return '$cherries cherries = $coins coins in the agent\'s stock';
  }

  @override
  String rechargeEmployeeOf(String name) {
    return 'Employee of $name';
  }

  @override
  String get rechargeOnShift => 'On shift';

  @override
  String get rechargeOffShift => 'Off shift';

  @override
  String get rechargeSellTitle => 'Sell coins from the stock';

  @override
  String rechargeStockLeft(String coins) {
    return 'In stock: $coins coins';
  }

  @override
  String get rechargeBuyer => 'Buyer';

  @override
  String get rechargeBuyerHint => 'Username or ID';

  @override
  String get rechargeCoins => 'Coins';

  @override
  String get rechargeSellInvalid => 'Enter the buyer and the coins';

  @override
  String rechargeSold(String coins, String buyer) {
    return '$coins coins sent to $buyer';
  }

  @override
  String get rechargeSellNote =>
      'The buyer pays you outside the app. Make sure you were paid before selling.';

  @override
  String get rechargeApplyTitle => 'Top-up agent application';

  @override
  String get rechargePrivacyNote =>
      'Your application is private: only the Kabso team sees it, and it is deleted 90 days after a refusal.';

  @override
  String get rechargeFullName => 'Full four-part name';

  @override
  String get rechargeFullNameHint => 'As on your ID';

  @override
  String get rechargeFullNameError =>
      'Enter your full name (at least four names)';

  @override
  String get rechargePhone => 'Phone number (WhatsApp)';

  @override
  String get rechargePhoneHint => 'International format, e.g. +201001234567';

  @override
  String get rechargePhoneError =>
      'Enter an international number starting with + (e.g. +201001234567)';

  @override
  String get rechargePhoto => 'Your photo';

  @override
  String get rechargePhotoHint => 'A clear photo of you';

  @override
  String get rechargeSelfie => 'Verification selfie';

  @override
  String get rechargeSelfieHint => 'Front camera, now; the team reviews it';

  @override
  String get rechargeLocations => 'Where you sell';

  @override
  String get rechargeCountry => 'Country';

  @override
  String get rechargeCities => 'Cities (comma separated)';

  @override
  String get rechargeAddLocation => 'Add a country';

  @override
  String get rechargeLocationError =>
      'Enter a two-letter country code (e.g. EG) and at least one city';

  @override
  String get rechargePaymentMethods => 'Payment methods in each country';

  @override
  String get rechargePaymentType => 'Type';

  @override
  String get rechargePaymentDetails => 'Details (e.g. Vodafone Cash, InstaPay)';

  @override
  String get rechargeAddPayment => 'Add a payment method';

  @override
  String get rechargePaymentError =>
      'Each payment method needs a country you sell in and details';

  @override
  String get rechargeMissingPhotos =>
      'Add your photo and the selfie (JPEG, PNG or WebP)';

  @override
  String get rechargeSubmit => 'Send the application';

  @override
  String get rechargeSubmitted => 'Application sent';

  @override
  String get rechargePayBank => 'Bank transfer';

  @override
  String get rechargePayWallet => 'Mobile wallet';

  @override
  String get rechargePayCash => 'Cash';

  @override
  String get rechargePayCard => 'Card';

  @override
  String get rechargePayCrypto => 'Crypto';

  @override
  String get rechargePayOther => 'Other';

  @override
  String get rechargeRemove => 'Remove';

  @override
  String get rechargeAddEmployee => 'Add an employee';

  @override
  String get rechargeEmployeeUsername => 'Username';

  @override
  String get rechargeEmployeesEmpty => 'No employees yet';

  @override
  String rechargeRemoveEmployeeConfirm(String name) {
    return 'Remove $name? They stop selling at once.';
  }

  @override
  String get rechargeHours => 'Working hours';

  @override
  String get rechargeTimeZone => 'Time zone';

  @override
  String get rechargeFrom => 'From';

  @override
  String get rechargeTo => 'To';

  @override
  String get rechargeAddSlot => 'Add a time slot';

  @override
  String get rechargeWhatsapp => 'WhatsApp number';

  @override
  String get rechargePaymentNow => 'Payment method in this slot';

  @override
  String get rechargeSave => 'Save';

  @override
  String get rechargeSaved => 'Saved';

  @override
  String get rechargeDay1 => 'Mon';

  @override
  String get rechargeDay2 => 'Tue';

  @override
  String get rechargeDay3 => 'Wed';

  @override
  String get rechargeDay4 => 'Thu';

  @override
  String get rechargeDay5 => 'Fri';

  @override
  String get rechargeDay6 => 'Sat';

  @override
  String get rechargeDay7 => 'Sun';

  @override
  String get rechargeDirectoryNote =>
      'You pay the agent outside the app; they send the coins to your account.';

  @override
  String get rechargeDirectoryEmpty => 'No agents in this country yet';

  @override
  String get rechargeDirectoryEmptyBody =>
      'Try another country or come back later.';

  @override
  String rechargeAvailableNowLine(String method) {
    return 'Available now · Payment: $method';
  }

  @override
  String get rechargeNotAvailableNow => 'Not available now';

  @override
  String get rechargeContact => 'Contact';

  @override
  String get rechargeCherryOffer => 'Sell cherries to an agent';

  @override
  String get rechargeCherryAsk => 'Ask a host for cherries';

  @override
  String get rechargeAgentCodeField => 'Agent code (e.g. coin0001)';

  @override
  String get rechargeHostField => 'Host\'s username';

  @override
  String get rechargeCherryAmount => 'Cherries';

  @override
  String rechargeCherryRules(String min, String step) {
    return 'At least $min cherries, in steps of $step';
  }

  @override
  String get rechargeCherryLockedNote => 'Locked task cherries are never sold.';

  @override
  String rechargeCherryPreview(String coins, String money) {
    return 'The agent gets $coins coins and pays the host $money in cash';
  }

  @override
  String get rechargeCherrySend => 'Send request';

  @override
  String get rechargeCherrySent => 'Request sent; waiting for the other side';

  @override
  String get rechargeCherryEmpty => 'No requests';

  @override
  String get rechargeCherryConfirmHint =>
      'Confirm only after the cash was paid. A request ends after 30 minutes.';

  @override
  String get rechargeCherryWaiting => 'Waiting for the other side';

  @override
  String get rechargeCherryCancel => 'Cancel request';

  @override
  String get rechargeConfirm => 'Confirm';

  @override
  String get rechargeDecline => 'Decline';

  @override
  String get rechargeCherryPending => 'Pending';

  @override
  String get rechargeCherryConfirmed => 'Confirmed';

  @override
  String get rechargeCherryDeclined => 'Declined';

  @override
  String get rechargeCherryCancelled => 'Cancelled';

  @override
  String get rechargeCherryExpired => 'Expired';

  @override
  String rechargeCherryLine(String cherries, String coins) {
    return '$cherries cherries → $coins coins';
  }

  @override
  String rechargeMoney(String amount) {
    return 'Cash amount: $amount';
  }

  @override
  String notifRechargeCoins(String name, String coins) {
    return '$name topped up $coins coins for you';
  }

  @override
  String notifRechargeCherry(String name) {
    return '$name asks you to confirm a cherry sale';
  }

  @override
  String get errorRechargeApplicationNotAllowed =>
      'You can\'t apply to be a top-up agent now.';

  @override
  String get errorRechargeAgentNotActive => 'This top-up agent is not active.';

  @override
  String get errorRechargeOffShift =>
      'You can sell only during your working hours.';

  @override
  String get errorRechargeStockInsufficient => 'Not enough coins in the stock.';

  @override
  String get errorRechargeEmployeeNotAllowed =>
      'This person can\'t be added as an employee.';

  @override
  String get errorRechargeCherryRequestPending =>
      'There is already an open request between you.';

  @override
  String get errorRechargeCherryRequestClosed =>
      'This request is no longer open.';

  @override
  String get errorRechargeCherryCapReached =>
      'The agent\'s daily cherry limit is reached.';

  @override
  String get errorUsernameLocked =>
      'Your username is locked while your special username is active.';

  @override
  String get settingsUsernameLocked => 'Locked';

  @override
  String settingsBaseUsername(String username) {
    return 'Your own username: $username';
  }

  @override
  String changeUsernameSpecialLocked(String special, String base) {
    return '$special is a locked special username and can\'t be changed while it\'s active. Everyone else sees only it; your own username $base is visible only to you, and you can still log in with it.';
  }

  @override
  String changeUsernameSpecialEnds(String date) {
    return 'It ends on $date, then your own username comes back.';
  }

  @override
  String hostAgentBadgeLabel(String code) {
    return 'Host agent $code';
  }

  @override
  String hostAgentFrameLabel(String name) {
    return '$name, host agent';
  }

  @override
  String hostAgentEntranceJoined(String name) {
    return 'Host agent $name joined the live';
  }

  @override
  String hostAgentIdLine(String code) {
    return 'Host agent · $code';
  }

  @override
  String get hostAgentCardTitle => 'Host agent';

  @override
  String get hostAgentCodeLabel => 'Host-agent code';

  @override
  String get hostAgentPerksNote =>
      'Your frame, badge and live entrance show while your agency is active.';

  @override
  String hostAgentReservedNote(String code, String shown) {
    return '$code is reserved for you. Your username shows $shown because it was activated first.';
  }

  @override
  String hostAgentSuspendedNote(String code) {
    return 'Your host-agent perks are suspended. $code stays reserved for you.';
  }

  @override
  String get hostAgentPendingNote => 'Your host-agent code is on its way.';

  @override
  String get bagCategoryAvatarFrame => 'Avatar frames';

  @override
  String get bagFromHostActive => 'Active host reward';

  @override
  String get bagNoSendHostActive => 'The host frame can\'t be sent';

  @override
  String get hostFrameChooseTitle => 'Choose your host frame colour';

  @override
  String get hostFrameChooseBody =>
      'You\'re an active host: pick the frame you like. You can change it later.';

  @override
  String get hostFrameChoose => 'Choose';

  @override
  String get hostFrameChangeColour => 'Change colour';

  @override
  String get hostFrameBlue => 'Blue';

  @override
  String get hostFramePink => 'Pink';

  @override
  String get hostFrameSaved => 'Host frame chosen';

  @override
  String get errorHostFrameStyleFromGender =>
      'Your gender sets the colour of your host frame.';

  @override
  String get rechargeStatusActive => 'Active';

  @override
  String get rechargeStatusSuspended => 'Suspended';

  @override
  String rechargeCherryTodayNoCap(String today) {
    return 'Hosts\' cherries today: $today';
  }

  @override
  String rechargeSalesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sales',
      one: '$count sale',
    );
    return '$_temp0';
  }

  @override
  String get rechargeMore => 'More';

  @override
  String get rechargeBuyerNotFound => 'No user with this username';

  @override
  String get rechargeBuyerChecking => 'Checking the buyer…';

  @override
  String get rechargeSellOverStock => 'More than your stock';

  @override
  String rechargeStockAfter(String coins) {
    return 'Stock after the sale: $coins';
  }

  @override
  String get rechargeSellConfirmTitle => 'Confirm the sale';

  @override
  String get rechargeSellIrreversible =>
      'A sale can\'t be undone once confirmed.';

  @override
  String get rechargeApplyStepPersonal => 'Your details';

  @override
  String get rechargeApplyStepPhotos => 'Photos';

  @override
  String get rechargePhotoAdded => 'Added';

  @override
  String get rechargePhotoRequired => 'Required';

  @override
  String get rechargeApplyStepPrivacy => 'Privacy';

  @override
  String get rechargeChooseCountry => 'Choose a country';

  @override
  String get rechargeStockAfterLabel => 'Stock after the sale';

  @override
  String get walletTopupWebsite => 'Top up on the website';

  @override
  String get walletTopupWebsiteHint =>
      'Pay by card on the official Kabso Live website';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountHint =>
      'Deleted for good 30 days after you ask';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String deleteAccountStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get deleteAccountIntroTitle => 'Before you delete your account';

  @override
  String get deleteAccountWhatGoes => 'What is deleted';

  @override
  String get deleteAccountWhatGoesBody =>
      'Your profile, name and photo, your posts, reels and stories, your messages, who you follow and who follows you, and your email address.';

  @override
  String get deleteAccountForfeit => 'What you lose';

  @override
  String get deleteAccountForfeitBody =>
      'Your coin and cherry balance, the items in your bag and your premium username time. They are not refunded or transferred.';

  @override
  String get deleteAccountKept => 'What we keep';

  @override
  String get deleteAccountKeptBody =>
      'Records of payments and gifts that the law, accounting and fraud prevention require, with nothing that identifies you. Others will see “Deleted user” instead of your name.';

  @override
  String deleteAccountGrace(int days) {
    return 'You have $days days to change your mind: log in during that time and choose “Cancel deletion”. After that the account is deleted for good.';
  }

  @override
  String get deleteAccountBlockedTitle => 'Settle this first';

  @override
  String get deleteAccountBlockerRechargeAgent =>
      'You are a recharge agent: contact the team to settle your stock and close the agency.';

  @override
  String get deleteAccountBlockerHostAgency =>
      'You own a host agency: contact the team to move your hosts and close the agency.';

  @override
  String get deleteAccountBlockerPendingWithdrawal =>
      'You have a cherry withdrawal waiting: wait until it is paid.';

  @override
  String get deleteAccountBlockerPendingCherrySale =>
      'You have an open cherry sale to a recharge agent: finish or cancel it.';

  @override
  String get deleteAccountBlockerNegativeBalance =>
      'Your balance is negative: contact the team to settle it.';

  @override
  String get deleteAccountBlockerOther =>
      'Something must be settled first: contact the team.';

  @override
  String deleteAccountContact(String email) {
    return 'For help, write to $email';
  }

  @override
  String get deleteAccountPasswordTitle => 'Confirm it’s you';

  @override
  String get deleteAccountPasswordBody =>
      'Enter your account password to continue.';

  @override
  String get deleteAccountConfirmTitle => 'Final confirmation';

  @override
  String deleteAccountConfirmBody(String word) {
    return 'Type “$word” to confirm deleting your account.';
  }

  @override
  String get deleteAccountConfirmWord => 'DELETE';

  @override
  String get deleteAccountConfirmLabel => 'Confirmation word';

  @override
  String get deleteAccountConfirmMismatch => 'Type the word exactly.';

  @override
  String get deleteAccountSubmit => 'Delete my account';

  @override
  String get deleteAccountDoneBanner =>
      'We received your request and signed you out on every device. You can cancel by signing in within 30 days.';

  @override
  String get deletionPendingTitle => 'Deletion in progress';

  @override
  String get deletionPendingQuestion => 'Cancel the deletion?';

  @override
  String deletionPendingBody(String date) {
    return 'This account will be deleted for good on $date. Cancel the deletion to get your account back as it was.';
  }

  @override
  String get deletionPendingBodyNoDate =>
      'This account will be deleted for good soon. Cancel the deletion to get your account back as it was.';

  @override
  String get deletionPendingCancel => 'Cancel deletion';

  @override
  String get deletionPendingKeep => 'Keep the deletion';

  @override
  String get deletionPendingRestored => 'Deletion cancelled. Welcome back.';

  @override
  String get deletedUser => 'Deleted user';

  @override
  String get errorReauthFailed => 'The password is not correct.';

  @override
  String get errorAccountDeletionBlocked =>
      'Some things must be settled before the account can be deleted.';

  @override
  String get errorAccountDeletionPending =>
      'This account is scheduled for deletion.';

  @override
  String get privacyDataTitle => 'Your data';

  @override
  String get dataExportTitle => 'Download my data';

  @override
  String get dataExportTileHint => 'A copy of your data you can take elsewhere';

  @override
  String get dataExportIntro =>
      'We prepare a ZIP file with your data as JSON and a short README in Arabic and English: your profile and settings, posts, reels and stories, comments, messages, follows and blocks, coin, cherry and level records, gifts, withdrawals, your recharge-agent application, your consents, and your device and sign-in history.';

  @override
  String get dataExportRules =>
      'You can ask for one copy every 24 hours. When it is ready we send you a notification and an email; the download works once, within 7 days.';

  @override
  String get dataExportNoSecrets =>
      'The file never contains your password or other people’s private data.';

  @override
  String get dataExportRequest => 'Request a copy of my data';

  @override
  String get dataExportPasswordTitle => 'Confirm it’s you';

  @override
  String get dataExportPasswordBody =>
      'Enter your account password to ask for a copy of your data.';

  @override
  String get dataExportPasswordLabel => 'Password';

  @override
  String get dataExportContinue => 'Continue';

  @override
  String get dataExportRequested =>
      'Request received. We will notify you when your data is ready.';

  @override
  String get dataExportPreparing =>
      'Preparing your data… we will notify you when it is ready.';

  @override
  String dataExportReady(String date) {
    return 'Your data is ready. You can download it once, until $date.';
  }

  @override
  String get dataExportDownload => 'Download the file';

  @override
  String dataExportSaved(String path) {
    return 'Saved to: $path';
  }

  @override
  String dataExportDownloaded(String date) {
    return 'You downloaded this copy on $date.';
  }

  @override
  String get dataExportExpired =>
      'The last copy expired before it was downloaded.';

  @override
  String get dataExportFailed =>
      'We could not prepare the last copy. You can ask for a new one.';

  @override
  String dataExportNextAt(String date) {
    return 'You can ask for a new copy after $date.';
  }

  @override
  String get dataExportRefresh => 'Refresh';

  @override
  String get consentTitle => 'We updated our terms';

  @override
  String get consentBody =>
      'Read the summary of the changes, then accept to keep using Kabso Live.';

  @override
  String get consentTermsName => 'Terms of Service';

  @override
  String get consentPrivacyName => 'Privacy Policy';

  @override
  String consentVersion(String version, String date) {
    return 'Version $version · effective $date';
  }

  @override
  String get consentReadFull => 'Read the full text';

  @override
  String get consentAccept => 'I agree and continue';

  @override
  String get consentNotNow =>
      'Don’t agree? You can download your data, delete your account or log out.';

  @override
  String get consentLogout => 'Log out';

  @override
  String get consentAccepted => 'Thank you, your acceptance is recorded.';

  @override
  String get registerLegalAccept =>
      'I am 18 or older, and I accept the Terms of Service and the Privacy Policy.';

  @override
  String get registerLegalRequired =>
      'Confirm your age and accept the terms to continue.';

  @override
  String get notifDataExportReady => 'Your data is ready to download';

  @override
  String get errorConsentRequired =>
      'Please review and accept the updated terms and privacy policy.';

  @override
  String get errorConsentVersionMismatch =>
      'A newer version was just published. Please review it again.';

  @override
  String get errorDataExportLimit =>
      'You can ask for one copy of your data every 24 hours.';

  @override
  String get errorDataExportLinkInvalid =>
      'This download link is no longer valid.';

  @override
  String get liveGiftTabPk => 'PK';

  @override
  String get pkSheetTitle => 'PK battle';

  @override
  String get pkTabInvite => 'Invite a host';

  @override
  String get pkTabRandom => 'Random match';

  @override
  String get pkSearchHint => 'Search live hosts';

  @override
  String get pkLiveNow => 'Live now';

  @override
  String get pkNoCandidates => 'No hosts are free right now';

  @override
  String get pkInvite => 'Invite';

  @override
  String pkInviteSent(String name) {
    return 'Invite sent to $name';
  }

  @override
  String pkWaitingFor(String name, String seconds) {
    return 'Waiting for $name… $seconds';
  }

  @override
  String get pkCancel => 'Cancel';

  @override
  String get pkRandomStart => 'Find an opponent';

  @override
  String pkRandomSearching(String time) {
    return 'Looking for an opponent… $time';
  }

  @override
  String get pkRandomStop => 'Stop searching';

  @override
  String get pkRandomHint =>
      'We pair you with a live host looking for a battle now.';

  @override
  String get pkInvitesSwitch => 'Accept PK invites';

  @override
  String get pkIncomingTitle => 'PK invite';

  @override
  String pkIncomingBody(String name) {
    return '$name invites you to a PK battle';
  }

  @override
  String get pkAccept => 'Accept';

  @override
  String get pkDecline => 'Decline';

  @override
  String get pkNoticeDeclined => 'Your invite was declined';

  @override
  String get pkNoticeExpired => 'The invite expired';

  @override
  String get pkNoticeQueueExpired => 'No opponent found. Try again.';

  @override
  String get pkEnd => 'End PK';

  @override
  String get pkEndConfirmTitle => 'End the PK now?';

  @override
  String get pkEndConfirmBody =>
      'Ending early counts as a forfeit: your opponent wins.';

  @override
  String get pkMuteOpponent => 'Mute opponent';

  @override
  String get pkUnmuteOpponent => 'Unmute opponent';

  @override
  String get pkBoosterDouble => 'Double';

  @override
  String get pkBoosterDoubleTurbo => 'Double Turbo';

  @override
  String get pkBoosterTriple => 'Triple';

  @override
  String get pkBoosterTripleTurbo => 'Triple Turbo';

  @override
  String pkBoostChip(String multiplier, String time) {
    return '×$multiplier $time';
  }

  @override
  String pkRoundTimer(String time) {
    return 'PK $time';
  }

  @override
  String get pkResultWin => 'Victory';

  @override
  String get pkResultLose => 'Defeat';

  @override
  String get pkResultDraw => 'Draw';

  @override
  String pkEndedForfeit(String name) {
    return '$name forfeited';
  }

  @override
  String pkEndedDisconnect(String name) {
    return '$name disconnected';
  }

  @override
  String pkEndedAway(String name) {
    return '$name was away';
  }

  @override
  String get pkEndedAdmin => 'A moderator ended the PK';

  @override
  String get pkBoosterNoMatch => 'Boosters work only during a PK battle';

  @override
  String pkBoosterTooEarly(String minutes) {
    return 'Available in the last $minutes of the battle';
  }

  @override
  String get pkBoosterLastMinute => 'minute';

  @override
  String get pkBoosterLastTwoMinutes => '2 minutes';

  @override
  String get pkBoosterLimit => 'This booster is used up for this battle';

  @override
  String get pkBoosterActiveHigher =>
      'A booster as strong or stronger is active';

  @override
  String get pkErrorBusy => 'That host is busy with another PK or invite';

  @override
  String get pkErrorInvitesOff => 'This host doesn’t take PK invites';

  @override
  String get pkErrorCooldown => 'Wait a moment before inviting again';

  @override
  String get pkErrorUnavailable => 'A PK can’t start now';

  @override
  String get pkErrorInviteClosed => 'This invite is no longer open';

  @override
  String pkRecord(String wins, String losses, String draws) {
    return 'PK: $wins W · $losses L · $draws D';
  }

  @override
  String pkOpponentPane(String name) {
    return 'Opponent $name';
  }

  @override
  String pkOwnPane(String name) {
    return 'Host $name';
  }

  @override
  String pkGuestSemantics(String name) {
    return 'Guest $name';
  }

  @override
  String get pkModeOneVsOne => '1v1 PK';

  @override
  String get pkModeTeam => 'Team PK';

  @override
  String get pkModeMulti => 'Multi PK';

  @override
  String pkModeSoon(String mode) {
    return '$mode is coming soon — not built yet';
  }

  @override
  String get pkFriendsTab => 'Friends';

  @override
  String get pkNoFriends => 'No friends to invite currently';

  @override
  String get pkFriendsHelp =>
      'Friends are hosts you follow who follow you back and are in a video live now. Search any other host by name, or try a random match.';

  @override
  String get pkHelpTitle => 'What is PK?';

  @override
  String get pkHelpBody =>
      'A battle between two hosts: each room\'s gifts during the round become PK points (the gift\'s value × the booster). The higher score wins. Boosters ×2 / ×3 / ×5 / ×10 multiply points only, never money.';

  @override
  String get pkHistoryTitle => 'PK history';

  @override
  String get pkHistoryEmpty => 'No PK battles yet';

  @override
  String get pkHistoryNotCounted => 'Not counted';

  @override
  String get pkHistoryVoid => 'Void';

  @override
  String pkHistoryRounds(String own, String other) {
    return 'Rounds $own–$other';
  }

  @override
  String pkHistoryVs(String name) {
    return 'vs $name';
  }

  @override
  String get pkHistoryLoadError => 'Couldn\'t load the PK history';

  @override
  String get pkSettingsTitle => 'PK Setting';

  @override
  String get pkSettingsLoadError => 'Couldn\'t load the PK settings';

  @override
  String get pkSettingMode => 'PK mode';

  @override
  String get pkSettingModeHelp =>
      'Single round: one round decides. Best of three: up to 3 rounds of the chosen time; the first to win 2 rounds wins. Each round has its own points and boosters.';

  @override
  String get pkModeSingle => 'Single Round PK';

  @override
  String get pkModeBestOfThree => 'Best of three PK';

  @override
  String get pkSettingTime => 'Time';

  @override
  String pkMinutes(String minutes) {
    return '${minutes}mins';
  }

  @override
  String pkMinutesLong(String minutes) {
    return '$minutes minutes';
  }

  @override
  String get pkSettingAutoStart =>
      'Will PK be opened directly after the connection';

  @override
  String get pkSettingGender => 'Random PK gender preference';

  @override
  String get pkGenderBoth => 'Both';

  @override
  String get pkGenderMale => 'Male';

  @override
  String get pkGenderFemale => 'Female';

  @override
  String get pkSettingRegion => 'Random PK region preference';

  @override
  String get pkRegionGlobal => 'Global';

  @override
  String get pkRegionSame => 'My country';

  @override
  String get pkSettingAutoMatch => 'Auto Match';

  @override
  String get pkSettingAutoMatchHelp =>
      'While you are in a video live and not in a PK, you join random matching by yourself.';

  @override
  String get pkSettingRecommend => 'Allow to be recommended to other hosts';

  @override
  String pkSettingsNoteEffective(String points) {
    return '1. An effective PK: both hosts\' PK points together ≥ $points (it counts in your record).';
  }

  @override
  String get pkSettingsNoteRandom =>
      '2. If the PK settings of matched hosts are different, one host\'s setting will be selected randomly.';

  @override
  String get pkSettingsSoonTab => 'This mode is coming soon — no settings yet';

  @override
  String get pkSettingSaveError => 'Couldn\'t save the setting';

  @override
  String get pkStart => 'Start PK';

  @override
  String get pkConnectedHint =>
      'Connected — PK starts when either of you taps Start PK';

  @override
  String pkRoundLabel(String round) {
    return 'Round $round/3';
  }

  @override
  String pkSettingsFromOther(String name) {
    return '$name\'s settings apply (picked at random)';
  }

  @override
  String pkBoostActivated(String host, String booster) {
    return '$host\'s team activated $booster';
  }

  @override
  String pkBoostGain(String points, String multiplier) {
    return '+$points ×$multiplier';
  }

  @override
  String pkBoostChipSemantics(
    String booster,
    String multiplier,
    String seconds,
  ) {
    return '$booster ×$multiplier, $seconds s left';
  }

  @override
  String get liveDataPageTitle => 'Live Data';

  @override
  String get liveDataNowLiveTime => 'Live Time';

  @override
  String get liveDataNowViewers => 'Unique viewers';

  @override
  String liveDataNowViewersHint(String peak) {
    return 'Peak $peak';
  }

  @override
  String get liveDataNowCherries => 'New cherries';

  @override
  String get liveDataNowGivers => 'Gift-givers';

  @override
  String get liveDataNowFans => 'New fans';

  @override
  String get liveDataCreatorCenter => 'Creator Center';

  @override
  String liveDataLevel(String level) {
    return 'Lv.$level';
  }

  @override
  String get liveDataLevelHelp =>
      'Charm level: it grows with the value of the gifts you receive.';

  @override
  String get liveDataHistory => 'Earlier periods';

  @override
  String get liveDataNotLive => 'Live data shows while you are live.';

  @override
  String get liveToolHd => 'HD';

  @override
  String get liveToolFlash => 'Flash';

  @override
  String get liveHostBox => 'Games';

  @override
  String get liveTargetChip => 'Target';

  @override
  String liveTargetCherriesSemantics(String received) {
    return 'Gifts target today: $received cherries';
  }

  @override
  String liveTargetLuckySemantics(String received) {
    return 'Lucky gifts target today: $received cherries';
  }

  @override
  String get liveTargetReached => 'Target reached';

  @override
  String get liveTargetPeriodDay => 'Daily';

  @override
  String get liveTargetPeriodWeek => 'Weekly';

  @override
  String get liveTargetPeriodMonth => 'Monthly';

  @override
  String get liveTargetPeriodAll => 'All';

  @override
  String get liveTargetCherriesSection => 'Gifts';

  @override
  String get liveTargetLuckySection => 'Lucky gifts';

  @override
  String get liveTargetTopSupporters => 'Top supporters';

  @override
  String get liveTargetNoSupporters => 'No supporters yet';

  @override
  String get liveTargetToday => 'Today’s targets';

  @override
  String get liveTargetCherriesGoal => 'Gifts target';

  @override
  String get liveTargetLuckyGoal => 'Lucky gifts target';

  @override
  String get liveTargetNoTarget => 'No target today';

  @override
  String liveTargetConversion(int band) {
    return 'The gifts target is your band’s ($band) «Gifts target» task target, in cherries.';
  }

  @override
  String get liveTargetTaskCenter => 'Task center';

  @override
  String get liveTargetLoadError => 'Couldn’t load the stats';

  @override
  String get liveTargetZoneHint => 'Periods follow Riyadh time.';

  @override
  String get reelsChipStories => 'Stories';

  @override
  String get reelsChipRooms => 'Rooms';

  @override
  String get reelsOpenStories => 'Open stories';

  @override
  String get reelsOpenRooms => 'Open voice rooms';

  @override
  String get reelsStoriesEmpty =>
      'No stories right now. Add yours, or follow people to see theirs.';

  @override
  String reelsShareLabel(String count) {
    return 'Share, $count';
  }

  @override
  String reelsCommentsLabel(String count) {
    return 'Comments, $count';
  }

  @override
  String reelsShareText(String author, String caption) {
    return '$author on Kabso Live: $caption';
  }

  @override
  String reelsShareTextNoCaption(String author) {
    return 'Watch $author\'s reel on Kabso Live';
  }

  @override
  String reelsOriginalSound(String name) {
    return 'Original sound · $name';
  }

  @override
  String get reelsMore => 'more';

  @override
  String reelsRequestFollow(String name) {
    return 'Request to follow $name';
  }

  @override
  String reelsFollowRequested(String name) {
    return 'Follow request sent to $name';
  }

  @override
  String liveTargetCountdownHours(String hours, String minutes) {
    return 'Countdown ${hours}H ${minutes}M';
  }

  @override
  String liveTargetCountdownDays(String days, String hours) {
    return 'Countdown ${days}D ${hours}H';
  }

  @override
  String get liveTargetRangeToday => 'Today';

  @override
  String get liveTargetRangeWeek => 'This week';

  @override
  String get liveTargetRangeMonth => 'This month';

  @override
  String get liveTargetRangeAll => 'All time';

  @override
  String get liveTargetHelpTitle => 'What is the target?';

  @override
  String get liveTargetHelp =>
      'A host has two targets each day, both in the cherries they really receive: the gifts target (every gift from others except lucky gifts) and the lucky gifts target (lucky gifts, the ones the host sends themself included). They start again at midnight Riyadh time. The list ranks the supporters of the chosen period: by cherries under «Gifts», by coins under «Lucky gifts».';

  @override
  String get liveTargetSupport => 'Support';

  @override
  String liveTargetMyPlace(String rank, String amount) {
    return 'Your place $rank: $amount';
  }

  @override
  String get liveTargetClose => 'Close';

  @override
  String goLiveFailureDetails(String code) {
    return 'Details: $code';
  }

  @override
  String get goLiveToolsDegraded =>
      'Some live tools didn’t start and were switched off. Your live goes on.';

  @override
  String get rechargeOrdersTitle => 'Recharge orders';

  @override
  String get rechargeOrdersHint =>
      'Your orders with agents and each order\'s chat';

  @override
  String get rechargeOrdersMine => 'My orders';

  @override
  String get rechargeOrdersIncoming => 'Incoming orders';

  @override
  String rechargeOrdersIncomingHint(String count, String coins) {
    return '$count waiting for you · $coins coins frozen';
  }

  @override
  String get rechargeOrdersEmpty => 'No orders yet';

  @override
  String get rechargeOrdersEmptyBody =>
      'Choose an agent in «Recharge agents», then «Order coins».';

  @override
  String get rechargeOrderNew => 'Order coins';

  @override
  String get rechargeOrderNewTitle => 'New recharge order';

  @override
  String get rechargeOrderCoins => 'Coins';

  @override
  String rechargeOrderCoinsRange(String min, String max) {
    return 'From $min to $max coins';
  }

  @override
  String get rechargeOrderPrice => 'Price';

  @override
  String rechargeOrderUsd(String amount) {
    return '$amount USD';
  }

  @override
  String rechargeOrderLocal(String amount, String currency, String rate) {
    return '≈ $amount $currency (1 USD = $rate)';
  }

  @override
  String get rechargeOrderUsdOnly =>
      'No exchange rate for this country: the price is in USD only.';

  @override
  String get rechargeOrderPriceNote =>
      'Kabso computes the price at the unified coin price.';

  @override
  String get rechargeOrderPaymentMethod => 'Payment method';

  @override
  String get rechargeOrderSubmit => 'Send the order';

  @override
  String get rechargeOrderOutsideNote =>
      'You pay the agent outside the app. When the agent sends the payment details, the coins are frozen from the agent\'s stock until they confirm the payment.';

  @override
  String get rechargeOrderTitle => 'Recharge order';

  @override
  String get rechargeOrderStatusRequested =>
      'Waiting for the agent\'s payment details';

  @override
  String get rechargeOrderStatusAwaiting => 'Waiting for the transfer';

  @override
  String get rechargeOrderStatusPaid => 'Sent — waiting for the agent';

  @override
  String get rechargeOrderStatusDisputed =>
      'Disputed — the team is reviewing it';

  @override
  String get rechargeOrderStatusCompleted => 'Completed — the coins were added';

  @override
  String get rechargeOrderStatusByAdmin => 'The coins were added by the team';

  @override
  String get rechargeOrderStatusRefunded =>
      'The coins went back to the agent (team decision)';

  @override
  String get rechargeOrderStatusCancelled => 'Cancelled';

  @override
  String get rechargeOrderStatusExpired => 'Expired';

  @override
  String get rechargeOrderStatusUnknown => 'Recharge order';

  @override
  String rechargeOrderFrozen(String coins) {
    return '$coins coins frozen for this order';
  }

  @override
  String rechargeOrderCoinsLine(String coins) {
    return '$coins coins';
  }

  @override
  String get rechargeOrderNoticeTitle => 'Protection notice';

  @override
  String get rechargeOrderNotice =>
      'Please take a screenshot and record a screen video from the moment you leave this chat until the transfer reaches the details the agent gave you, to protect you from any mistake or fraud. When you transfer, send a screenshot of the transfer and keep the screen video until your coins arrive.';

  @override
  String get rechargeOrderNoticeAck => 'I have read and understood';

  @override
  String get rechargeOrderSent => 'I sent it';

  @override
  String get rechargeOrderSentTitle => 'Attach the transfer screenshot';

  @override
  String get rechargeOrderSentBody =>
      'Choose the screenshot of the transfer; it is sent in the chat as proof. Keep the screen video until your coins arrive.';

  @override
  String get rechargeOrderPickScreenshot => 'Choose the screenshot';

  @override
  String get rechargeOrderBadImage => 'Choose a JPEG, PNG or WebP picture.';

  @override
  String rechargeOrderCountdown(String time) {
    return 'You can open a dispute in $time';
  }

  @override
  String rechargeOrderCountdownAgent(String time) {
    return 'Check the transfer · $time before the buyer can open a dispute';
  }

  @override
  String get rechargeOrderWaitOver =>
      'The wait is over. If your coins have not arrived, open a dispute.';

  @override
  String get rechargeOrderWaitOverAgent =>
      'The wait is over: the buyer can open a dispute now.';

  @override
  String get rechargeOrderDispute => 'Dispute';

  @override
  String get rechargeOrderDisputeTitle => 'Open a dispute';

  @override
  String get rechargeOrderDisputeBody =>
      'The coins stay frozen; the team joins the chat, reviews the evidence and decides.';

  @override
  String get rechargeOrderDisputeReason => 'What happened? (optional)';

  @override
  String get rechargeOrderReceived => 'Received';

  @override
  String get rechargeOrderReceivedTitle => 'Confirm the payment';

  @override
  String rechargeOrderReceivedBody(String coins) {
    return 'Make sure the money really reached your account. After you confirm, $coins coins go to the buyer; this cannot be undone.';
  }

  @override
  String get rechargeOrderSendDetails => 'Send payment details';

  @override
  String get rechargeOrderDetailsLabel => 'Transfer details';

  @override
  String get rechargeOrderDetailsHint =>
      'The wallet or account number and the recipient\'s name';

  @override
  String rechargeOrderDetailsBody(String coins) {
    return 'When you send, $coins coins are frozen from your stock for this order until you confirm the payment.';
  }

  @override
  String get rechargeOrderCancel => 'Cancel the order';

  @override
  String get rechargeOrderCancelBody =>
      'Cancel the order? Any frozen coins go back to the agent\'s stock.';

  @override
  String get rechargeOrderKeep => 'Keep it';

  @override
  String get rechargeOrderChatHint => 'Write a message…';

  @override
  String get rechargeOrderChatClosed => 'The chat is closed';

  @override
  String get rechargeOrderRoleAdmin => 'Team';

  @override
  String rechargeOrderPaymentDetails(String method) {
    return 'Payment details · $method';
  }

  @override
  String get rechargeOrderProof => 'Transfer screenshot';

  @override
  String get rechargeOrderCopied => 'Payment details copied';

  @override
  String get rechargeOrderEventCreated => 'Order created';

  @override
  String get rechargeOrderEventDetails =>
      'The agent sent the payment details; the coins are frozen';

  @override
  String get rechargeOrderEventNotice =>
      'The buyer acknowledged the protection notice';

  @override
  String get rechargeOrderEventPaid => 'The buyer pressed «I sent it»';

  @override
  String get rechargeOrderEventCompleted =>
      'The agent confirmed; the coins were added';

  @override
  String get rechargeOrderEventDisputedBuyer => 'The buyer opened a dispute';

  @override
  String get rechargeOrderEventDisputedAgent => 'The agent opened a dispute';

  @override
  String get rechargeOrderEventCancelledBuyer =>
      'The buyer cancelled the order';

  @override
  String get rechargeOrderEventCancelledAgent =>
      'The agent cancelled the order';

  @override
  String get rechargeOrderEventExpired => 'The order expired';

  @override
  String get rechargeOrderEventForBuyer =>
      'Team decision: the coins go to the buyer';

  @override
  String get rechargeOrderEventForAgent =>
      'Team decision: the coins go back to the agent';

  @override
  String get rechargeOrderEventOther => 'Order updated';

  @override
  String notifRechargeOrderCreated(String coins) {
    return 'A new recharge order is waiting for your payment details ($coins coins)';
  }

  @override
  String get notifRechargeOrderDetails =>
      'The agent sent the payment details for your order';

  @override
  String get notifRechargeOrderPaid =>
      'The buyer says the money was sent: check the transfer';

  @override
  String notifRechargeOrderCompleted(String coins) {
    return '$coins coins of your recharge order were added';
  }

  @override
  String get notifRechargeOrderDisputed =>
      'A dispute was opened on the recharge order';

  @override
  String get notifRechargeOrderRefunded =>
      'The dispute was closed; the coins went back to the agent';

  @override
  String get notifRechargeOrderCancelled => 'The recharge order was cancelled';

  @override
  String get notifRechargeOrderExpired => 'The recharge order expired';

  @override
  String get notifRechargeOrderAdmin =>
      'A message from the team on the recharge order';

  @override
  String get notifRechargeOrderMessage => 'A new message on the recharge order';

  @override
  String get errorRechargeOrdersUnavailable =>
      'Recharge orders are not available right now.';

  @override
  String get errorRechargeOrderOpenExists =>
      'You already have an open order with this agent.';

  @override
  String get errorRechargeOrderStateChanged =>
      'This order has changed. Refresh the page.';

  @override
  String get errorRechargeOrderNoticeRequired =>
      'Read and acknowledge the protection notice first.';

  @override
  String get errorRechargeOrderDisputeTooEarly =>
      'You can open a dispute when the wait is over.';

  @override
  String agencyDaysCount(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String agencyHostsCount(int hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      hosts,
      locale: localeName,
      other: '$hosts hosts',
      one: '$hosts host',
    );
    return '$_temp0';
  }

  @override
  String agencyHoursCount(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '$hours hour',
    );
    return '$_temp0';
  }

  @override
  String get agencyOpenButton => 'Open an agency';

  @override
  String get agencyOpenButtonHint => 'Free — your agency is created at once';

  @override
  String get agencyOpenTitle => 'Open an agency';

  @override
  String get agencyOpenFree => 'Opening an agency is free';

  @override
  String agencyOpenRule(String days, String hosts) {
    return 'Your agency is created as soon as you send this. Within $days you must activate at least $hosts: a host joins your agency, then goes live and receives gifts. Otherwise the agency is closed automatically and you are told why.';
  }

  @override
  String get agencyOpenStepInfo => 'Agency details';

  @override
  String get agencyOpenName => 'Agency name';

  @override
  String get agencyOpenNameError => 'Use 2 to 40 characters';

  @override
  String get agencyOpenCountry => 'Country';

  @override
  String get agencyOpenCountryError => 'Choose the country';

  @override
  String get agencyOpenContactType => 'Contact method';

  @override
  String get agencyOpenContactValue => 'Number or handle';

  @override
  String get agencyOpenContactError => 'Use at least 3 characters';

  @override
  String get agencyContactWhatsapp => 'WhatsApp';

  @override
  String get agencyContactTelegram => 'Telegram';

  @override
  String get agencyContactPhone => 'Phone';

  @override
  String get agencyContactEmail => 'Email';

  @override
  String get agencyContactOther => 'Other';

  @override
  String get agencyOpenExpected => 'Expected number of hosts';

  @override
  String get agencyOpenExpectedError => 'From 1 to 10000';

  @override
  String get agencyOpenBio => 'Short bio';

  @override
  String get agencyOpenBioHint => 'Optional, up to 300 characters';

  @override
  String get agencyOpenStepId => 'Identity check (required)';

  @override
  String get agencyOpenIdCard => 'ID card';

  @override
  String get agencyOpenIdCardHint =>
      'A clear photo of your ID card or passport';

  @override
  String get agencyOpenIdMissing => 'Add the ID card and the selfie';

  @override
  String get agencyOpenPrivacy =>
      'The ID pictures are private: only the Kabso Live team sees them, and every view is recorded.';

  @override
  String get agencyOpenSubmit => 'Open the agency for free';

  @override
  String get agencyOpenDone =>
      'Your agency is open. Activate your hosts during the trial';

  @override
  String get agencyOpenOwns => 'You already have an agency';

  @override
  String get agencyOpenIsHost =>
      'You are a host of an agency. Leave it first to open one';

  @override
  String get agencyOpenNotActive => 'Your account is not active';

  @override
  String agencyOpenCooldown(String date) {
    return 'You can open a new agency from $date';
  }

  @override
  String get agencyProbationTitle => 'Trial period';

  @override
  String agencyProbationLeft(String days, String hours) {
    return 'Left: $days and $hours';
  }

  @override
  String agencyProbationLeftHours(String hours) {
    return 'Left: $hours';
  }

  @override
  String get agencyProbationEnding => 'Time is up, checking now';

  @override
  String agencyProbationActivated(String count, String required) {
    return 'Activated hosts: $count / $required';
  }

  @override
  String agencyProbationRuleShort(String hosts, String days) {
    return 'Activate $hosts within $days: a host joins, goes live and receives gifts.';
  }

  @override
  String get agencyProbationJoined => 'Joined';

  @override
  String get agencyProbationLive => 'Went live';

  @override
  String get agencyProbationGifts => 'Got gifts';

  @override
  String get agencyProbationNoHosts =>
      'No hosts yet. Share the invite code to get started.';

  @override
  String get agencyProbationPassed => 'Your agency passed its trial';

  @override
  String get agencyShare => 'Share';

  @override
  String agencyShareText(String code) {
    return 'Join my agency on Kabso Live with the invite code: $code';
  }

  @override
  String get agencyClosedTitle => 'The agency was closed';

  @override
  String agencyClosedProbation(String hosts, String count) {
    return 'It did not activate $hosts (live + gifts) during the trial. Activated: $count';
  }

  @override
  String get agencyClosedAdmin => 'Closed by the Kabso Live team';

  @override
  String agencyClosedOn(String date) {
    return 'Closed on: $date';
  }

  @override
  String get agencyReopenNow => 'You can open a new agency now';

  @override
  String get notifAgencyOpened =>
      'Your agency is open. Activate your hosts during the trial';

  @override
  String notifAgencyReminder(String count, String required) {
    return 'Less than a day left in your agency trial: $count / $required activated';
  }

  @override
  String get notifAgencyPassed => 'Your agency passed its trial';

  @override
  String notifAgencyClosedProbation(String hosts, String count) {
    return 'Your agency was closed because it did not activate $hosts (live + gifts) during the trial. Activated: $count';
  }

  @override
  String get notifAgencyClosedAdmin =>
      'Your agency was closed by the Kabso Live team';

  @override
  String get notifAgencyHostReleased =>
      'Your agency was closed; you are free to join another agency';

  @override
  String get errorAgencyOpenNotAllowed => 'You cannot open an agency now';

  @override
  String get errorAccountLocked =>
      'Your account is locked for a while by the Kabso team.';

  @override
  String errorAccountLockedUntil(String date, String reason) {
    return 'Your account is locked until $date. Reason: $reason';
  }

  @override
  String get errorAccountRestricted =>
      'This is switched off for your account for a while.';

  @override
  String errorAccountRestrictedUntil(String what, String date) {
    return '$what is switched off for your account until $date.';
  }

  @override
  String get restrictionChatMute => 'Sending messages and comments';

  @override
  String get restrictionNoLive => 'Going live';

  @override
  String get restrictionNoGifts => 'Sending gifts';

  @override
  String get restrictionNoPosting => 'Posting';

  @override
  String get errorPasswordChangeRequired =>
      'Choose a new password to continue.';

  @override
  String get passwordChangeTitle => 'New password';

  @override
  String get passwordChangeBody =>
      'The Kabso team asked for your account’s password to be changed. Choose a new password to log in; your other sessions will end.';

  @override
  String get passwordChangeNew => 'New password';

  @override
  String get passwordChangeConfirm => 'Confirm the password';

  @override
  String get passwordChangeMismatch => 'The passwords do not match.';

  @override
  String get passwordChangeSame =>
      'Choose a password different from the current one.';

  @override
  String get passwordChangeTooShort => 'At least 8 characters.';

  @override
  String get passwordChangeSubmit => 'Save and log in';

  @override
  String get hostApplyTitle => 'Host with the Kabso Live team';

  @override
  String get hostApplyIntro =>
      'You host directly with the Kabso Live team: no agency and no agency commission. We review your application and tell you the result.';

  @override
  String get hostApplyButton => 'Apply';

  @override
  String get hostApplyPendingTitle => 'Your application is under review';

  @override
  String hostApplyPendingBody(String date) {
    return 'You applied on $date. We will tell you when it is decided.';
  }

  @override
  String get hostApplyCancel => 'Cancel application';

  @override
  String get hostApplyCancelConfirmTitle => 'Cancel your application?';

  @override
  String get hostApplyCancelConfirmBody => 'You can apply again at any time.';

  @override
  String get hostApplyCancelKeep => 'Keep it';

  @override
  String get hostApplyCancelled => 'Your application was cancelled';

  @override
  String get hostApplyApprovedTitle => 'You host with the Kabso Live team ✓';

  @override
  String get hostApplyApprovedBody =>
      'You can go live now, directly with the Kabso Live team, with no agency.';

  @override
  String get hostApplyGoLive => 'Go live';

  @override
  String get hostApplyHostAgencyTitle => 'You can go live';

  @override
  String get hostApplyRejectedTitle => 'Your application was not approved';

  @override
  String hostApplyRejectedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String hostApplyReapplyOn(String date) {
    return 'You can apply again from $date';
  }

  @override
  String get hostApplyReapplyNow => 'You can apply again now';

  @override
  String get hostApplyNotActive =>
      'Your account is not active, so you cannot apply';

  @override
  String get hostApplyFormTitle => 'Host with the team';

  @override
  String get hostApplyStepInfo => 'About you';

  @override
  String get hostApplyName => 'Your name on lives';

  @override
  String get hostApplyNameHint => 'Check it is the name viewers should see';

  @override
  String get hostApplyNameError => 'Enter your display name';

  @override
  String get hostApplyCountry => 'Country';

  @override
  String get hostApplyCountryError => 'Choose your country';

  @override
  String get hostApplyBirth => 'Date of birth';

  @override
  String get hostApplyBirthPick => 'Choose the date';

  @override
  String get hostApplyBirthError => 'Choose your date of birth';

  @override
  String hostApplyMinAge(String age) {
    return 'Hosting with the team is for adults only ($age+)';
  }

  @override
  String get hostApplyContactType => 'Contact method';

  @override
  String get hostApplyContactValue => 'Your number or handle';

  @override
  String get hostApplyContactError => 'Enter a contact we can reach you on';

  @override
  String get hostApplyBio => 'Short bio: what will you stream?';

  @override
  String get hostApplyBioHint => 'For example: cooking, games, chat, music';

  @override
  String get hostApplyBioError => 'Write a short bio of what you will stream';

  @override
  String get hostApplyLinks => 'Your streaming accounts (optional)';

  @override
  String get hostApplyAddLink => 'Add a link';

  @override
  String get hostApplyLinkError => 'A link starting with https://';

  @override
  String get hostApplyStepId => 'Identity check (required)';

  @override
  String get hostApplyStepRules => 'Host rules';

  @override
  String get hostApplyRulesText =>
      '• Respect your viewers; no abusive or adult content.\n• Never pressure or trick anyone into sending gifts; do not stream others\' content without the right to.\n• Protect your privacy and other people\'s.\n• The team takes the hosting permission back when the rules are broken.';

  @override
  String get hostApplyRulesAccept => 'I have read and accept the host rules';

  @override
  String get hostApplyRulesError => 'Accept the rules to continue';

  @override
  String get hostApplyPrivacy =>
      'Your pictures and details are private: only the review team sees them.';

  @override
  String get hostApplySubmit => 'Send application';

  @override
  String get hostApplySent => 'Application sent. We will tell you the result';

  @override
  String get hostApplyRefusedPending =>
      'You already have an application under review';

  @override
  String get hostApplyRefusedHost => 'You can already go live';

  @override
  String get hostApplyRefusedAgency =>
      'You are in an agency: hosting with the team is for people in no agency';

  @override
  String get hostApplyRefusedCooldown => 'You cannot apply again yet';

  @override
  String get notifHostApproved =>
      'Your application was approved: you now host with the Kabso Live team and can go live';

  @override
  String get notifHostRejected =>
      'Your application to host with the team was not approved. Open Agency to see why';

  @override
  String get errorHostApplicationNotAllowed => 'You cannot apply now';

  @override
  String get liveCategoryRowLabel => 'Live categories';

  @override
  String get liveCategoryAll => 'All';

  @override
  String get liveCategoryLive => 'Live';

  @override
  String get liveCategoryAudio => 'Audio';

  @override
  String get liveCategoryPodcast => 'Podcast';

  @override
  String get liveCategoryMulti => 'Multi';

  @override
  String get liveCategoryStreamer => 'Streamer';

  @override
  String get liveStreamerSoonTitle => 'Streamer lives are coming soon';

  @override
  String get liveStreamerSoonBody =>
      'Soon you can stream your phone screen live to your followers.';

  @override
  String get livePodcastEmptyTitle => 'No podcast is live right now';

  @override
  String get livePodcastEmptyBody =>
      'Start your own episode or come back later.';

  @override
  String get podcastUpcoming => 'Upcoming episodes';

  @override
  String get podcastRemindMe => 'Remind me';

  @override
  String get podcastReminderOn => 'You’ll be reminded';

  @override
  String podcastStartsAt(String time) {
    return '$time';
  }

  @override
  String podcastListeners(String count) {
    return 'Listeners · $count';
  }

  @override
  String get podcastSeeAll => 'See all ‹';

  @override
  String podcastEpisode(int number) {
    return 'Episode $number';
  }

  @override
  String get podcastLiveTag => 'LIVE';

  @override
  String get podcastTopicBusiness => 'Business';

  @override
  String get podcastTopicTech => 'Tech';

  @override
  String get podcastTopicSports => 'Sports';

  @override
  String get podcastTopicReligion => 'Faith';

  @override
  String get podcastTopicSociety => 'Society';

  @override
  String get podcastTopicEntertainment => 'Entertainment';

  @override
  String get podcastTopicOther => 'Other';

  @override
  String get podcastRaiseHand => 'Raise your hand';

  @override
  String get podcastLowerHand => 'Lower your hand';

  @override
  String get podcastHandUp => 'Your hand is up. Tap to lower it.';

  @override
  String get podcastLeaveStage => 'Back to the listeners';

  @override
  String get podcastAskTitle => 'Raise your hand';

  @override
  String get podcastAskHint => 'Your question in short (optional)';

  @override
  String get podcastAskSend => 'Raise my hand';

  @override
  String get podcastHandsTitle => 'Raised hands ✋';

  @override
  String podcastHandsRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '$count request',
    );
    return '$_temp0';
  }

  @override
  String podcastHandsSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats free',
      one: '$count seat free',
    );
    return '$_temp0';
  }

  @override
  String get podcastLater => 'Later';

  @override
  String get podcastBringUp => 'Bring up';

  @override
  String get podcastNoHands => 'No hands are up right now.';

  @override
  String podcastHandsBadge(int count) {
    return '$count hands up';
  }

  @override
  String get podcastQuestionTime => 'Question time';

  @override
  String podcastMinutes(int count) {
    return '$count min';
  }

  @override
  String get podcastNoLimit => 'No limit';

  @override
  String get podcastQuestionsOpen => 'Take questions';

  @override
  String podcastQuestionPill(String time) {
    return 'Question · $time';
  }

  @override
  String get podcastQuestionsClosed => 'The host isn’t taking questions now.';

  @override
  String get podcastSeatsFull =>
      'All three seats are taken. Move a speaker down first.';

  @override
  String get podcastDeferred => 'Later';

  @override
  String get podcastSpeakerDown => 'Move to the listeners';

  @override
  String get podcastSetupTopic => 'Episode topic';

  @override
  String get podcastSetupTitleHint => 'Episode title';

  @override
  String get podcastSetupTitleRequired => 'Write the episode title first.';

  @override
  String get podcastSetupGuests => 'Guests (up to 3)';

  @override
  String get podcastSetupAddGuest => 'Add a guest';

  @override
  String get podcastSetupGuestsNote =>
      'Each guest is invited as soon as they join the live.';

  @override
  String get podcastSetupGuestSearch => 'Search by username';

  @override
  String get podcastSetupQuestions => 'Listener questions';

  @override
  String get podcastSetupOpen => 'Open';

  @override
  String get podcastSetupClosed => 'Closed';

  @override
  String get podcastSetupWhen => 'When';

  @override
  String get podcastSetupNow => 'Now';

  @override
  String get podcastSetupSchedule => 'Schedule';

  @override
  String get podcastSetupScheduled =>
      'Episode scheduled. Your followers are reminded 15 minutes before.';

  @override
  String get podcastSetupScheduleAction => 'Schedule the episode';

  @override
  String get goLiveModePodcast => 'Podcast';

  @override
  String get goLiveModeStreamer => 'Streamer';

  @override
  String get liveCardTagStreamer => 'Streamer';

  @override
  String get goLiveStreamerSoonIos => 'Soon on iPhone';

  @override
  String get goLiveStreamerIosSnack =>
      'Streamer lives are coming soon on iPhone';

  @override
  String get streamerSetupBody =>
      'Viewers see your phone screen (a game or an app) with a small bubble from your front camera.';

  @override
  String get streamerCameraBubble => 'Camera bubble';

  @override
  String get streamerCameraCorner => 'Bubble corner';

  @override
  String get streamerCornerTopLeft => 'Top left';

  @override
  String get streamerCornerTopRight => 'Top right';

  @override
  String get streamerCornerBottomLeft => 'Bottom left';

  @override
  String get streamerCornerBottomRight => 'Bottom right';

  @override
  String get streamerMic => 'Microphone';

  @override
  String get streamerGameAudio => 'Game sound';

  @override
  String get streamerGameAudioNote =>
      'Some games don\'t allow their sound to be captured';

  @override
  String get streamerHeadphonesTip =>
      'Use headphones so the game sound isn\'t heard twice';

  @override
  String get streamerGameAudioOld =>
      'Game sound needs Android 10 or newer — only your microphone will be heard';

  @override
  String get streamerPrivacyNote =>
      'Viewers don\'t see your screen while you\'re in Kabso Live';

  @override
  String get streamerConsentRefused =>
      'Screen capture wasn\'t allowed, so the live didn\'t start';

  @override
  String streamerConsentFailed(String code) {
    return 'Couldn\'t ask for screen capture permission ($code)';
  }

  @override
  String get streamerConsentHint =>
      'Tap \"Start\" in Android\'s window to share your screen';

  @override
  String get streamerShareAgainFailed =>
      'Couldn\'t share the screen again, try once more';

  @override
  String get streamerOnAir => 'Your screen is live';

  @override
  String get streamerPausedInApp =>
      'Your screen is paused while you\'re in Kabso Live';

  @override
  String get streamerPausedCall => 'Your screen is paused during the call';

  @override
  String get streamerPausedScreenOff =>
      'Your screen is paused while the phone is locked';

  @override
  String get streamerGoToGame => 'Go to your game';

  @override
  String get streamerStoppedTitle => 'Screen sharing stopped';

  @override
  String get streamerShareAgain => 'Share the screen again';

  @override
  String get streamerGameLive => 'Game sound is live';

  @override
  String get streamerGameMuted => 'Game sound is muted';

  @override
  String get streamerGameUnavailable =>
      'Game sound isn\'t available on this phone — only your microphone is live';

  @override
  String get streamerShowCamera => 'Show camera';

  @override
  String get streamerHideCamera => 'Hide camera';

  @override
  String get streamerMuteGame => 'Mute game sound';

  @override
  String get streamerUnmuteGame => 'Unmute game sound';

  @override
  String get streamerNotifMicOff => 'Mute mic';

  @override
  String get streamerNotifMicOn => 'Unmute mic';

  @override
  String get streamerDragHint => 'Drag the bubble to any corner';

  @override
  String get streamerPausedViewer =>
      'The screen is paused — the stream will be back shortly';

  @override
  String get streamerWaiting => 'Waiting for the host\'s screen…';

  @override
  String get streamerWaitingCamera => 'Waiting for the host\'s picture…';

  @override
  String get streamerFullscreen => 'Full screen';

  @override
  String get streamerExitFullscreen => 'Exit full screen';

  @override
  String streamerScreenSemantics(String name) {
    return '$name\'s screen';
  }

  @override
  String chatJoinedMale(String name) {
    return '$name joined';
  }

  @override
  String chatJoinedFemale(String name) {
    return '$name joined';
  }

  @override
  String get liveThemePodcastStudio => 'Podcast studio';

  @override
  String get liveThemePodcastMajlis => 'Tent majlis';

  @override
  String get liveThemePodcastLibrary => 'Emerald library';

  @override
  String get errorLiveQuestionsClosed => 'The host isn’t taking questions now.';

  @override
  String get podcastSpeaking => 'speaking';

  @override
  String get podcastMuted => 'mic off';

  @override
  String get inviteTitle => 'Invite a friend';

  @override
  String get inviteRulesTooltip => 'Rules';

  @override
  String get inviteHeroLine => 'Invite friends and earn up to';

  @override
  String inviteMoneyHint(String money) {
    return '≈ $money';
  }

  @override
  String inviteTickerLine(String name, String amount) {
    return '$name earned $amount cherries, congratulations';
  }

  @override
  String get inviteCardTitle => 'Invite new friends to join Kabso';

  @override
  String inviteStepSignup(String amount) {
    return 'Your friend signs up with your code: you get $amount cherries.';
  }

  @override
  String inviteStepRecharge(String percent) {
    return 'Your friend\'s first recharge: you get $percent of its value in cherries.';
  }

  @override
  String inviteStepHold(String hours) {
    return 'Rewards reach your withdrawable cherries after a check ($hours hours).';
  }

  @override
  String inviteYouGet(String you, String friend) {
    return 'You get $you, your friend gets $friend';
  }

  @override
  String inviteYouGetOnly(String you) {
    return 'You get $you for each friend';
  }

  @override
  String inviteCherries(String amount) {
    return '$amount cherries';
  }

  @override
  String get inviteNow => 'Invite now';

  @override
  String get inviteMyCode => 'My invite code:';

  @override
  String get inviteCopy => 'Copy';

  @override
  String get inviteCodeCopied => 'Invite code copied';

  @override
  String get inviteLinkCopied => 'Invite link copied';

  @override
  String get inviteMilestonesTitle => 'Invite new friends to earn up to';

  @override
  String inviteInvitedCount(String count) {
    return '$count invited';
  }

  @override
  String inviteMilestoneFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends',
      one: '$count friend',
    );
    return '$_temp0';
  }

  @override
  String get inviteMilestoneLocked => 'Locked';

  @override
  String get inviteMilestoneUnlocked => 'Reached, being checked';

  @override
  String get inviteMilestoneClaimed => 'Added';

  @override
  String inviteMilestoneSemantics(String friends, String amount, String state) {
    return 'Milestone $friends: $amount cherries, $state';
  }

  @override
  String inviteRewardsPending(String amount) {
    return 'Held: $amount';
  }

  @override
  String inviteRewardsCredited(String amount) {
    return 'Added: $amount';
  }

  @override
  String get inviteFriendsTitle => 'Your friends';

  @override
  String get inviteStatusPending => 'Being checked';

  @override
  String get inviteStatusQualified => 'Qualified';

  @override
  String get inviteStatusRejected => 'Not eligible';

  @override
  String get inviteStatusVoid => 'Void';

  @override
  String get inviteRecharged => 'Recharged';

  @override
  String get inviteNoFriends =>
      'You have not invited anyone yet. Share your code with your friends.';

  @override
  String get inviteErrorTitle => 'Could not load the invite page';

  @override
  String inviteShareText(String code, String link) {
    return 'Join me on Kabso Live. Use my invite code $code when you sign up: $link';
  }

  @override
  String get inviteShareWhatsapp => 'WhatsApp';

  @override
  String get inviteShareMore => 'Share';

  @override
  String get inviteShareCopyLink => 'Copy link';

  @override
  String get inviteShareFailed =>
      'Could not open the app; the link was copied instead';

  @override
  String get inviteRulesTitle => 'Invite rules';

  @override
  String inviteRuleSignup(String amount) {
    return 'When a new friend signs up with your invite code you get $amount cherries.';
  }

  @override
  String inviteRuleInvitee(String amount) {
    return 'Your friend gets $amount cherries.';
  }

  @override
  String inviteRuleRecharge(String percent) {
    return 'On your friend\'s first recharge (the website, a recharge agent or a recharge order) you get $percent of its value in cherries.';
  }

  @override
  String inviteRuleHold(String hours) {
    return 'Every reward is held $hours hours, then added to your withdrawable cherries. It is voided if your friend\'s account is banned, deleted or locked.';
  }

  @override
  String get inviteRuleFair =>
      'One reward per device and per email; inviting yourself or your other accounts does not count.';

  @override
  String inviteRuleCap(String count) {
    return 'Up to $count sign-ups are rewarded a day.';
  }

  @override
  String inviteRuleLater(String days) {
    return 'Your friend can enter your code in Settings within $days days of signing up, once.';
  }

  @override
  String inviteRuleMilestones(String list) {
    return 'Milestone bonuses, once each, by the number of your qualified friends:\n$list';
  }

  @override
  String get inviteRuleWithdraw =>
      'Cherries follow the usual withdrawal rules of the cherry wallet.';

  @override
  String get referralApplyRow => 'Invite code';

  @override
  String get referralApplyTitle => 'Enter an invite code';

  @override
  String get referralApplyLabel => 'Your friend\'s code or invite link';

  @override
  String referralApplyBody(String date) {
    return 'You can enter it once, until $date.';
  }

  @override
  String get referralApplySubmit => 'Confirm';

  @override
  String get referralApplied => 'Your account is linked to your friend\'s code';

  @override
  String get referralAppliedNotEligible =>
      'The code was saved, but this invitation does not qualify';

  @override
  String get errorReferralUnavailable => 'Invitations are not available now';

  @override
  String get errorReferralCodeInvalid => 'This invite code is not valid';

  @override
  String get errorReferralNotAllowed => 'You cannot enter an invite code now';

  @override
  String get errorDeviceAccountLimit =>
      'You cannot create more than 2 accounts on the same device. You can log in to your existing accounts.';

  @override
  String errorDeviceAccountLimitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' $count accounts',
      one: ' one account',
    );
    return 'You cannot create more than$_temp0 on the same device. You can log in to your existing accounts.';
  }

  @override
  String get registerReferralLabel => 'Invite code (optional)';

  @override
  String get registerReferralHelper =>
      'If a friend invited you, type their code or paste the invite link';

  @override
  String get cherryReasonReferral => 'Referral reward';

  @override
  String inviteStepMilestones(String list) {
    return 'Extra rewards by the number of your qualified friends:\n$list';
  }

  @override
  String inviteMilestoneItem(String friends, String amount) {
    return '$friends: $amount cherries';
  }

  @override
  String get inviteRuleClawback =>
      'If the Kabso team voids an invalid invite, the cherries it brought are taken back; if your balance does not cover them it goes below 0 and withdrawals wait until it is earned back.';

  @override
  String get cherryReasonReferralReversal => 'Referral reward taken back';

  @override
  String get notifReferralReversed =>
      'The Kabso team voided an invalid invite and took back its cherries. Open the cherry wallet for details';

  @override
  String get feedSuggested => 'Suggested for you';

  @override
  String get feedPostSeeMore => 'more';

  @override
  String feedPostViewCount(String count) {
    return '$count views';
  }

  @override
  String storyWatchLive(String name) {
    return 'Watch $name\'s live';
  }

  @override
  String get storyReplyHint => 'Send a message…';

  @override
  String get storyReplySend => 'Send';

  @override
  String get storyReplySent => 'Sent to messages';

  @override
  String storyReact(String name) {
    return 'Like $name\'s story';
  }

  @override
  String get notifCoverRemoved =>
      'The moderation team removed your profile cover for breaking the guidelines';

  @override
  String get profileEditCover => 'Cover photo';

  @override
  String get profileEditCoverSet => 'Set';

  @override
  String get profileEditCoverRemove => 'Remove cover photo';

  @override
  String get profileEditCoverUpdated => 'Cover photo updated';

  @override
  String get profileEditCoverRemoved => 'Cover photo removed';

  @override
  String profileCoverOf(String name) {
    return '$name\'s cover photo';
  }

  @override
  String get profileTabPostsWord => 'Posts';

  @override
  String get profileTabReelsWord => 'Reels';

  @override
  String get profileTabRepostsWord => 'Reposts';

  @override
  String get profileFollowerWord => 'Followers';

  @override
  String get profileFollowingWord => 'Following';

  @override
  String profileJoined(String date) {
    return 'Joined $date';
  }

  @override
  String get profileBlockedTitle => 'You blocked this account';

  @override
  String get profileBlockedBody =>
      'You won\'t see their posts and they can\'t message you. Unblock to see them.';

  @override
  String get profileTabSavedWord => 'Saved';

  @override
  String get profileBondFamily => 'Family';

  @override
  String get profileBondCouple => 'Couple';

  @override
  String get profileBondMedals => 'Medals';

  @override
  String liveCardId(String id) {
    return 'ID: $id';
  }

  @override
  String get liveCardReport => 'Report';

  @override
  String get liveCardFollowers => 'Followers';

  @override
  String get liveCardFollowing => 'Following';

  @override
  String get liveCardCherries => 'Cherries received';

  @override
  String get liveCardCoinsSent => 'Coins sent';

  @override
  String get liveCardFollow => 'Follow';

  @override
  String get liveCardUnfollow => 'Unfollow';

  @override
  String get liveCardChat => 'Chat';

  @override
  String get liveCardSendGift => 'Send a gift';

  @override
  String get liveCardEditProfile => 'Edit profile';

  @override
  String get liveCardFamilyNone => 'No family';

  @override
  String get privacyCardStatsTitle => 'Numbers on your card';

  @override
  String get privacyHideCherries => 'Hide cherries received';

  @override
  String get privacyHideCoins => 'Hide coins sent';

  @override
  String get privacyCardStatsHint =>
      'A hidden number is not shown to anyone else on your card in lives or on your profile. You and the Kabso team still see it.';

  @override
  String get kycStepTitle => 'Confirm your identity';

  @override
  String get kycStepIntro =>
      'We confirm your identity with Didit: a photo of your ID document, then of your face. No manual ID card or selfie upload is needed.';

  @override
  String get kycStatusNotStarted => 'Not started yet';

  @override
  String get kycStatusNotStartedHint =>
      'Photograph your ID document (card, passport or licence), then your face. It takes about two minutes.';

  @override
  String get kycStatusInProgress => 'Not finished';

  @override
  String get kycStatusInProgressHint =>
      'Continue where you stopped; the result shows here when you finish.';

  @override
  String get kycStatusInReview => 'Under review';

  @override
  String get kycStatusInReviewHint =>
      'Your check is being reviewed; we will notify you of the result.';

  @override
  String get kycStatusApproved => 'Identity confirmed';

  @override
  String get kycStatusApprovedHint =>
      'Your identity is confirmed; you can send the application.';

  @override
  String get kycStatusDeclined => 'Identity not confirmed';

  @override
  String get kycStatusDeclinedHint =>
      'You can try again, keeping the reason in mind:';

  @override
  String get kycStatusExpired => 'The session expired';

  @override
  String get kycStatusExpiredHint =>
      'The session ended before it was finished. Start again.';

  @override
  String get kycStart => 'Start verification';

  @override
  String get kycContinue => 'Continue verification';

  @override
  String get kycRetry => 'Try again';

  @override
  String kycWhatHappens(String provider) {
    return 'Verification opens inside the app with $provider. We do not keep pictures of your document or face.';
  }

  @override
  String get kycRefusedDailyLimit =>
      'You reached today\'s limit of verification attempts. Try again tomorrow.';

  @override
  String get kycUnavailable =>
      'Identity verification is not available right now. Try again later.';

  @override
  String get kycRequiredToSubmit => 'Finish «Confirm your identity» first.';

  @override
  String get kycRequiredApproved =>
      'Your identity must be confirmed (approved) before opening an agency.';

  @override
  String get kycReasonUnderAge => 'The document shows you are under 18.';

  @override
  String get kycReasonNoBirthDate =>
      'The date of birth could not be read. Photograph the document clearly.';

  @override
  String get kycReasonDocumentExpired =>
      'The document has expired. Use a valid one.';

  @override
  String get kycReasonNoFace =>
      'Your face was not clear. Take the photo in good light.';

  @override
  String get kycReasonLiveness =>
      'The liveness check failed. Show your real face, not a photo or a screen.';

  @override
  String get kycReasonFaceMatch =>
      'Your face does not match the document photo.';

  @override
  String get kycReasonOther => 'One of the verification steps did not pass.';

  @override
  String get kycClose => 'Close';

  @override
  String get kycOpenInBrowser => 'Open in the browser';

  @override
  String get notifKycApproved => 'Your identity was verified';

  @override
  String get notifKycDeclined =>
      'Your identity could not be verified. Open the application to see why and try again';

  @override
  String get notifKycInReview =>
      'Your identity check is being reviewed; we will tell you the result';

  @override
  String get errorKycNotAllowed => 'Verification cannot start now';

  @override
  String get agencyOpenRefusedKyc =>
      'Confirm your identity first (the «Confirm your identity» step).';

  @override
  String pkFollowHost(String name) {
    return 'Follow $name';
  }

  @override
  String get pkTypeNormal => 'Normal PK';

  @override
  String get pkTypeDares => 'PK dares';

  @override
  String get pkTypeDaresHint => 'The loser does a dare picked by the draw';

  @override
  String get pkTypeLabel => 'PK type';

  @override
  String get pkRandomDares => 'Random dares';

  @override
  String pkInviteSentDares(String name) {
    return 'PK dares invitation sent to $name';
  }

  @override
  String get pkDareDrawTitle => 'Drawing the dare';

  @override
  String get pkDareLevelEasy => 'Easy';

  @override
  String get pkDareLevelMedium => 'Medium';

  @override
  String get pkDareLevelHard => 'Hard';

  @override
  String pkDareLoserDeciding(String name) {
    return 'Waiting for $name to decide';
  }

  @override
  String get pkDareYourDare => 'Your dare';

  @override
  String get pkDareAccept => 'Accept';

  @override
  String get pkDareRefuse => 'Refuse';

  @override
  String get pkDareRefuseTitle => 'Refuse the dare?';

  @override
  String pkDareRefuseBody(String points) {
    return 'Refusing counts in your PK points: $points';
  }

  @override
  String get pkDareDone => 'Done ✅';

  @override
  String get pkDareNotDone => 'Not done ❌';

  @override
  String get pkDareJudge => 'Was the dare done?';

  @override
  String get pkDareOutcomeDone => 'Dare done 🎉';

  @override
  String get pkDareOutcomeRefused => 'Dare refused';

  @override
  String get pkDareOutcomeNotDone => 'Dare not done';

  @override
  String get pkDareReport => 'Report this dare';

  @override
  String get pkDareReported => 'Thanks, the report was sent';

  @override
  String pkDareSemantics(String text, String time) {
    return 'Dare: $text. $time left';
  }

  @override
  String get pkDareDrawSemantics =>
      'Drawing the dare from three: easy, medium and hard';

  @override
  String pkRecordPoints(String points) {
    return 'PK points: $points';
  }

  @override
  String pkRecordDares(String done, String refused) {
    return 'Dares done: $done · refused: $refused';
  }

  @override
  String get pkFailureDareClosed => 'This dare can no longer be answered';

  @override
  String get liveCountryPickerTitle => 'Nearby country';

  @override
  String get liveCountryPickerBody =>
      'Pick a country to see its lives in Nearby. Your profile doesn\'t change.';

  @override
  String liveNearbyCountryRow(String country) {
    return 'Nearby country: $country. Change';
  }

  @override
  String get liveNearbyChooseCountry => 'Choose a country';

  @override
  String get pkRematch => 'Another round';

  @override
  String pkRematchAsk(String name) {
    return 'Play another round with $name?';
  }

  @override
  String pkRematchWaiting(String name) {
    return 'Waiting for $name…';
  }

  @override
  String pkRematchOffered(String name) {
    return '$name wants another round';
  }

  @override
  String get pkRematchBanner => 'Another round starts';

  @override
  String get pkRematchDeclined => 'The other host said no to another round';

  @override
  String get pkRematchExpired => 'The other host did not answer';

  @override
  String pkRematchSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get pkPointsLabel => 'PK points';

  @override
  String pkPointsSemantics(String name, String points) {
    return '$name\'s PK points: $points';
  }

  @override
  String get pkRematchAfterDare => 'Another round once the dare is over';

  @override
  String pkEndForfeitPoints(String points) {
    return 'Withdrawing takes $points PK points off';
  }

  @override
  String get liveToolReportLive => 'Report live';

  @override
  String get liveReportTitle => 'Why are you reporting this live?';

  @override
  String get liveReportNoteLabel => 'Note (optional)';

  @override
  String get liveReportNoteHint => 'Describe what happened in the live';

  @override
  String get liveReportSend => 'Send report';

  @override
  String get liveReportSent =>
      'Report sent. The Kabso team will review the live.';

  @override
  String get errorDeviceBanned => 'This device is banned by the Kabso team.';

  @override
  String errorDeviceBannedUntil(String date, String reason) {
    return 'This device is banned by the Kabso team until $date. Reason: $reason';
  }

  @override
  String errorDeviceBannedPermanent(String reason) {
    return 'This device is banned by the Kabso team permanently. Reason: $reason';
  }

  @override
  String errorAccountRestrictedUntilReason(
    String what,
    String date,
    String reason,
  ) {
    return '$what is switched off for your account until $date. Reason: $reason';
  }

  @override
  String get notifLiveModeratedEnd => 'The Kabso team ended your live.';

  @override
  String notifLiveModeratedNoLive(String date) {
    return 'The Kabso team ended your live and banned you from going live until $date.';
  }

  @override
  String notifLiveModeratedSuspend(String date) {
    return 'The Kabso team ended your live and suspended your account until $date.';
  }

  @override
  String notifLiveModeratedDevice(String date) {
    return 'The Kabso team ended your live and banned your device until $date.';
  }

  @override
  String get notifLiveModeratedDevicePermanent =>
      'The Kabso team ended your live and banned your device permanently.';

  @override
  String notifLiveModeratedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get liveHostTasksTitle => 'Host tasks';

  @override
  String get liveHostTasksHide => 'Hide host tasks';

  @override
  String liveHostTasksLevel(int level) {
    return 'Lv$level';
  }

  @override
  String liveHostTasksDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String liveHostTasksLabel(
    String task,
    String progress,
    String target,
    int days,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '$days day left',
    );
    return 'Host tasks: $task, $progress of $target, $_temp0';
  }

  @override
  String get liveToolQuickReplies => 'Quick replies';

  @override
  String get liveToolRoomRank => 'Room rank';

  @override
  String get livePerformanceTitle => 'Performance status';

  @override
  String get livePerformanceRealtime => 'Real-time data';

  @override
  String get livePerformancePeak => 'Peak viewers';

  @override
  String get livePerformanceHelpLabel => 'About these numbers';

  @override
  String get livePerformanceHelp =>
      'The numbers of this live, updated every 15 seconds: the live time, the unique viewers and the most at once, new followers, the cherries received and the people who sent gifts. The chart shows the readings taken while this card was open.';

  @override
  String liveLevelTicker(String name, int level, String host) {
    return 'Congratulations to $name on reaching level $level in the live room of $host';
  }

  @override
  String get liveLevelTickerSupport => 'Support level';

  @override
  String get liveLevelTickerCharm => 'Charm level';

  @override
  String get vipLoadError => 'Couldn\'t load VIP';

  @override
  String get vipEmpty => 'No VIP tiers are on sale right now.';

  @override
  String get vipNotYet => 'You\'re not VIP yet';

  @override
  String vipUntil(String tier, String date) {
    return '$tier until $date';
  }

  @override
  String vipDaysLeft(String days) {
    return '$days days left';
  }

  @override
  String vipOffSale(String tier) {
    return '$tier is no longer on sale; you keep it until it ends, and it can\'t be renewed.';
  }

  @override
  String get vipCurrent => 'Your current tier';

  @override
  String vipForDays(String days) {
    return 'for $days days';
  }

  @override
  String vipPriceSemantics(String coins, String days) {
    return '$coins coins for $days days';
  }

  @override
  String vipPerksTitle(String tier) {
    return '$tier privileges';
  }

  @override
  String get vipPerksSoon => 'Perks marked «Soon» turn on when they launch.';

  @override
  String get vipPerksEmpty => 'No perks for this tier yet.';

  @override
  String get vipPerkActive => 'Active';

  @override
  String vipPerkWith(String tier) {
    return 'With $tier';
  }

  @override
  String get vipBuy => 'Buy now';

  @override
  String get vipRenew => 'Renew';

  @override
  String get vipUpgrade => 'Upgrade';

  @override
  String get vipLowerTier => 'Below your tier';

  @override
  String get vipRenewLimit => 'Renewal limit reached';

  @override
  String vipConfirmBuy(String tier) {
    return 'Buy $tier';
  }

  @override
  String vipConfirmRenew(String tier) {
    return 'Renew $tier';
  }

  @override
  String vipConfirmUpgrade(String tier) {
    return 'Upgrade to $tier';
  }

  @override
  String get vipConfirmPrice => 'Price';

  @override
  String get vipConfirmBalance => 'Your balance';

  @override
  String get vipConfirmUntil => 'Ends on';

  @override
  String vipUpgradeNote(String tier) {
    return 'The new tier starts now; the days left of $tier are not carried over or refunded.';
  }

  @override
  String get vipManualRenew =>
      'Renewal is manual: nothing is charged on its own.';

  @override
  String get vipShort => 'You don\'t have enough coins.';

  @override
  String get vipRecharge => 'Recharge coins';

  @override
  String vipPay(String coins) {
    return 'Pay $coins';
  }

  @override
  String vipDone(String tier, String date) {
    return 'You\'re $tier until $date';
  }

  @override
  String get vipRules => 'VIP rules';

  @override
  String vipRulesBody(String days) {
    return 'VIP is bought with coins from your balance for the tier\'s length. Renewing is manual and adds the length to your end date (up to $days days ahead). Upgrading to a higher tier starts at once at its full price; the days left of your previous tier are not carried over. A lower tier can\'t be bought until yours ends. Nothing is charged on its own.';
  }

  @override
  String get vipErrorDowngrade =>
      'You can\'t buy a lower tier until yours ends.';

  @override
  String get vipErrorRenewLimit =>
      'You\'ve reached the longest you can renew ahead.';

  @override
  String get vipErrorTierOff => 'This tier is no longer on sale.';

  @override
  String get errorVipUnavailable => 'This VIP tier can\'t be bought now.';

  @override
  String get errorVipPriceChanged =>
      'The price of this tier changed. Check the new price.';

  @override
  String get walletReasonVipPurchase => 'Purchase VIP';

  @override
  String vipCurrently(String status) {
    return 'Currently: $status';
  }

  @override
  String get vipStatusNone => 'non-VIP';

  @override
  String vipUpgradeTo(String tier) {
    return 'Upgrade: $tier';
  }

  @override
  String get vipMaxTier => 'Top tier';

  @override
  String get vipBalanceLabel => 'Your balance';

  @override
  String get vipStore => 'VIP store';

  @override
  String get vipStoreSoon => 'VIP gifts store — coming soon.';

  @override
  String vipPerksSection(String tier) {
    return '$tier privileges';
  }

  @override
  String get vipSectionIdentity => 'Identification';

  @override
  String get vipSectionPrivilege => 'Exclusive privilege';

  @override
  String vipPrivilegeTitle(String tier, String count, String total) {
    return 'Exclusive privileges $tier $count/$total';
  }

  @override
  String get vipMine => 'My VIP';

  @override
  String get vipPageTitle => 'VIP';

  @override
  String get vipPrivilegesHeader => 'VIP Privileges';

  @override
  String get vipPayCoins => 'Pay with gold coins';

  @override
  String get liveDailyRankTitle => 'Daily rank';

  @override
  String get liveDailyRankHide => 'Hide the daily rank';

  @override
  String liveDailyRankGap(String gap) {
    return '$gap to the one above';
  }

  @override
  String liveDailyRankLabel(String name, String rank, String points) {
    return '$name: today\'s rank $rank, $points points';
  }

  @override
  String get liveToolRecharge => 'Recharge';

  @override
  String get walletReasonVipDailyCoins => 'VIP daily coins';

  @override
  String vipDailyCoins(String amount) {
    return 'Daily coins: $amount';
  }

  @override
  String get vipDailyCoinsClaim => 'Claim';

  @override
  String get vipDailyCoinsClaimed => 'Claimed today';

  @override
  String vipDailyCoinsAdded(String amount) {
    return '$amount coins added';
  }

  @override
  String liveBulletSentFree(String count) {
    return 'Free public message sent · $count left today';
  }

  @override
  String vipEntranceJoined(String name) {
    return '$name enters the room';
  }

  @override
  String get vipVisitorsTitle => 'Profile visitors';

  @override
  String get vipVisitorsEntry => 'Who visited my profile';

  @override
  String vipVisitorsTotal(String count) {
    return '$count visitors in the last 30 days';
  }

  @override
  String vipVisitorsVisits(String count) {
    return '$count visits';
  }

  @override
  String get vipVisitorsEmptyTitle => 'No visitors yet';

  @override
  String get vipVisitorsEmptyMessage =>
      'People who open your profile show here.';

  @override
  String get vipVisitorsNoPerkTitle => 'A VIP perk';

  @override
  String get vipVisitorsNoPerkMessage =>
      'See who visited your profile with VIP.';

  @override
  String get vipVisitorsNoPerkAction => 'Get VIP';

  @override
  String get vipIdentity => 'Identification';

  @override
  String get vipPreviewName => 'Your name';

  @override
  String vipPerkPerDay(String value) {
    return '$value a day';
  }

  @override
  String vipDailyCoinsTotal(String total) {
    return 'Daily coins: $total coins in total';
  }

  @override
  String vipPricePer(String days) {
    return 'coins / $days days';
  }

  @override
  String vipCashback(String total, String daily) {
    return '$total coins back in total ($daily a day)';
  }

  @override
  String vipSpeedupLine(String percent) {
    return '+$percent% level speed-up';
  }

  @override
  String vipRenewalDiscountLine(String percent) {
    return '$percent% off when you renew';
  }

  @override
  String get liveKabsoTeam => 'Kabso Team';

  @override
  String get liveKabsoTeamInfoTitle => 'Kabso Team';

  @override
  String get liveKabsoTeamInfo =>
      'A member of the Kabso Team is following this live to keep the community safe. They are not counted as a viewer or a supporter.';

  @override
  String liveKabsoTeamWatching(String name) {
    return '$name, Kabso Team';
  }

  @override
  String get liveKabsoTeamHere => 'The Kabso Team is following this live';

  @override
  String get bagCategoryChatBubble => 'Chat bubbles';

  @override
  String get bagCategoryEntryBanner => 'Entry banners';

  @override
  String get bagCategoryEntryEffect => 'Entry effects';

  @override
  String get bagCategoryMicWave => 'Mic waves';

  @override
  String bagFromVip(String tier) {
    return 'From your $tier membership';
  }

  @override
  String get bagNoSendVip =>
      'VIP items belong to your membership and can\'t be sent';

  @override
  String get bagNoSendPermanent => 'Permanent items can\'t be sent';

  @override
  String get meHubStore => 'Store';

  @override
  String get storeTitle => 'Store';

  @override
  String get storeKindAvatarFrame => 'Avatar frames';

  @override
  String get storeKindProfileCard => 'Profile cards';

  @override
  String get storeKindChatBubble => 'Chat bubbles';

  @override
  String get storeKindEntryBanner => 'Entry banners';

  @override
  String get storeKindEntryEffect => 'Entry cars';

  @override
  String get storeNew => 'New';

  @override
  String get storeOwned => 'Owned';

  @override
  String storeOwnedUntil(String date) {
    return 'Yours until $date — buying adds the days';
  }

  @override
  String get storeCoins => 'Coins';

  @override
  String get storeCherries => 'Cherries';

  @override
  String get storeDuration => 'Duration';

  @override
  String get storePayWith => 'Pay with';

  @override
  String get storePrice => 'Price';

  @override
  String get storeBalance => 'Your balance';

  @override
  String get storeBuy => 'Buy';

  @override
  String get storeGift => 'Gift';

  @override
  String get storeRecharge => 'Recharge';

  @override
  String get storeShortCoins => 'You don\'t have enough coins for this item.';

  @override
  String get storeShortCherries =>
      'You don\'t have enough cherries. Cherries are earned from gifts you receive in lives; they can\'t be recharged.';

  @override
  String storeBuyConfirm(String name, String days, String price) {
    return 'Buy “$name” for $days for $price?';
  }

  @override
  String storeGiftConfirm(String name, String days, String user, String price) {
    return 'Give “$name” for $days to $user for $price?';
  }

  @override
  String storeBought(String name, String date) {
    return 'Bought. “$name” is in your bag until $date.';
  }

  @override
  String storeGiftSent(String user) {
    return 'Your gift was sent to $user.';
  }

  @override
  String get storeWearNow => 'Wear now';

  @override
  String get storeWorn => 'You\'re wearing it now';

  @override
  String get storeGiftTitle => 'Give to…';

  @override
  String get storeGiftSearch => 'Username';

  @override
  String get storeGiftFollowing => 'People you follow';

  @override
  String get storeGiftNone => 'No one here yet.';

  @override
  String get storeEmpty => 'Nothing in the store yet. Check back soon.';

  @override
  String get storePreviewSample => 'Hello everyone 👋';

  @override
  String storeTotal(String price, String days) {
    return '$price · $days';
  }

  @override
  String get errorStoreUnavailable => 'This item can\'t be bought now.';

  @override
  String get errorStorePriceChanged =>
      'The price of this item changed. Check the new price.';

  @override
  String get walletReasonStorePurchase => 'Store purchase';

  @override
  String storeLockedCherries(String amount) {
    return 'Locked task cherries can\'t be spent in the store ($amount locked).';
  }

  @override
  String get staffToolsTitle => 'Kabso Team tools';

  @override
  String get staffMeIntro => 'Moderate lives from your phone';

  @override
  String get staffRoleOwner => 'Owner';

  @override
  String get staffRoleModeration => 'Moderator';

  @override
  String get staffRoleSupport => 'Support';

  @override
  String get staffRoleFinance => 'Finance';

  @override
  String get staffShift => 'On shift';

  @override
  String get staffShiftAutoHint =>
      'Turns on by itself when you enter a live, use the team tools or open «My lives»; lives are assigned to you and their reports reach your phone. You turn it off';

  @override
  String get staffShiftOff => 'Off shift';

  @override
  String get staffMyLives => 'My lives';

  @override
  String get staffMyLivesEmpty => 'No lives assigned to you now';

  @override
  String get staffMyLivesOffShift => 'Turn on «On shift» to get lives';

  @override
  String get staffAnyLive =>
      'You can enter any live as the Kabso Team from the live lists';

  @override
  String staffReportsCount(String count) {
    return '$count reports';
  }

  @override
  String staffViewersCount(String count) {
    return '$count watching';
  }

  @override
  String get staffEnterTitle => 'How do you enter this live?';

  @override
  String get staffEnterVisible => 'Visible (Kabso Team)';

  @override
  String get staffEnterVisibleHint =>
      'Listed with the Kabso Team badge, never counted';

  @override
  String get staffEnterHidden => 'Watch hidden';

  @override
  String get staffEnterHiddenHint => 'Nobody sees you; no chat';

  @override
  String staffModeNow(String mode) {
    return 'You are: $mode';
  }

  @override
  String get staffModeSwitch => 'Switch';

  @override
  String get staffReports => 'Reports';

  @override
  String get staffReportsEmpty => 'No reports on this live';

  @override
  String get staffReportOnLive => 'On the live';

  @override
  String staffReportOnUser(String name) {
    return 'On $name';
  }

  @override
  String staffReportOnMessage(String name) {
    return 'A message by $name';
  }

  @override
  String staffReportBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get staffReportClosed => 'Handled';

  @override
  String get staffActions => 'Actions';

  @override
  String get staffActionWarn => 'Warn the host';

  @override
  String get staffActionEnd => 'End the live';

  @override
  String get staffActionNoLive => 'Ban from going live';

  @override
  String get staffActionSuspend => 'Suspend the account';

  @override
  String get staffActionDismiss => 'Reviewed — no violation';

  @override
  String get staffActionKick => 'Remove from the live';

  @override
  String get staffActionMute => 'Mute in chat';

  @override
  String get staffActionRemoveMessage => 'Remove the message';

  @override
  String get staffPersonActions => 'Act on a person';

  @override
  String get staffPersonField => 'Username';

  @override
  String get staffReason => 'Reason (recorded)';

  @override
  String get staffReasonHostHint =>
      'The host is told the reason from «the Kabso team», never your name.';

  @override
  String get staffDuration => 'Duration';

  @override
  String get staffDuration1h => '1 hour';

  @override
  String get staffDuration24h => '24 hours';

  @override
  String get staffDuration3d => '3 days';

  @override
  String get staffDuration7d => '7 days';

  @override
  String get staffDuration30d => '30 days';

  @override
  String get staffApply => 'Apply';

  @override
  String get staffDone => 'Done';

  @override
  String get staffReadOnly => 'Your role: reports only';

  @override
  String get staffNoEconomy =>
      'The Kabso Team doesn’t send gifts or tap in a live';

  @override
  String notifLiveStaffReport(String host) {
    return 'New report on $host’s live';
  }

  @override
  String get errorStaffProtected => 'This can’t be done to the Kabso Team';

  @override
  String get errorLiveStaffRefused =>
      'The Kabso Team doesn’t do this in a live';

  @override
  String get errorStaffStepUpRequired =>
      'Enter your authenticator code to use the team tools';

  @override
  String get errorStaffTotpNotEnrolled =>
      'Set up the authenticator in the admin panel first';

  @override
  String get errorAdminTotpInvalid => 'The authenticator code is not valid';

  @override
  String get errorAdminLocked => 'Too many wrong codes. Try again later';

  @override
  String get errorAdminActionRefused => 'The action was refused';

  @override
  String get profileLiveNowTitle => 'Live now';

  @override
  String get profileLiveNowSelfTitle => 'You\'re live now';

  @override
  String profileLiveFor(String duration) {
    return 'Live for $duration';
  }

  @override
  String profileLiveHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String profileLiveMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String profileLiveCardSemantics(
    String title,
    String duration,
    String details,
  ) {
    return '$title, $duration, $details';
  }

  @override
  String profileTagsMore(int count) {
    return '$count more tags';
  }

  @override
  String get profileEditTags => 'Tags';

  @override
  String profileEditTagsValue(int count) {
    return '$count of 10';
  }

  @override
  String get profileEditTagsHint =>
      'Up to 10 short tags shown on your profile cover, up to 24 characters each.';

  @override
  String get profileEditTagField => 'New tag';

  @override
  String get profileEditTagAdd => 'Add';

  @override
  String profileEditTagRemove(String tag) {
    return 'Remove $tag';
  }

  @override
  String profileEditTagTooLong(int max) {
    return 'At most $max characters.';
  }

  @override
  String get profileEditTagDuplicate => 'This tag is already added.';

  @override
  String get profileEditTagInvalid =>
      'Contains characters that aren\'t allowed.';

  @override
  String get profileEditTagsFull => 'You have 10 tags.';

  @override
  String get profileTagIconDefault => 'No icon';

  @override
  String get profileTagIconCrown => 'Crown';

  @override
  String get profileTagIconFlag => 'Country flag';

  @override
  String get profileTagIconFire => 'Fire';

  @override
  String get profileTagIconTrophy => 'Trophy';

  @override
  String get profileTagIconGamepad => 'Games';

  @override
  String get profileTagIconMusic => 'Music';

  @override
  String get profileTagIconMic => 'Microphone';

  @override
  String get profileTagIconMoon => 'Moon';

  @override
  String get profileTagIconHeart => 'Heart';

  @override
  String get profileTagIconStar => 'Star';

  @override
  String get profileTagIconGem => 'Gem';

  @override
  String get profileTagIconCamera => 'Camera';

  @override
  String get profileTagIconBook => 'Book';

  @override
  String get profileTagIconSport => 'Sport';

  @override
  String get profileTagIconPalette => 'Art';

  @override
  String get profileTagIconGlobe => 'Globe';

  @override
  String profileTagIconFlagOf(String country) {
    return 'Flag of $country';
  }

  @override
  String get profileTagIconPick => 'Tag icon';

  @override
  String profileTagIconChange(String tag) {
    return 'Change the icon of $tag';
  }

  @override
  String profileTagIconNew(String icon) {
    return 'New tag icon: $icon';
  }

  @override
  String get profileEditTagsIconHint => 'Tap a tag to choose its icon.';

  @override
  String get liveTargetLevelEasy => 'Easy';

  @override
  String get liveTargetLevelMedium => 'Medium';

  @override
  String get liveTargetLevelHard => 'Hard';

  @override
  String liveTargetRewardLocked(String amount) {
    return '+$amount locked cherries';
  }

  @override
  String liveTargetRewardPaid(String amount) {
    return 'Done · +$amount locked cherries';
  }

  @override
  String get liveTargetRewardHint =>
      'The reward is a share of the platform\'s actual profit, paid as locked cherries like tasks when the target is reached.';

  @override
  String liveTargetDailySemantics(
    String level,
    String title,
    String progress,
    String amount,
    String reward,
  ) {
    return '$level: $title, $progress of $amount, reward $reward cherries';
  }

  @override
  String tasksWindowLabel(String from, String to) {
    return 'between $from and $to';
  }

  @override
  String get cherryReasonHostTarget => 'Daily target reward';

  @override
  String get staffRegionArabWorld => 'Arab World';

  @override
  String get staffRegionGreaterChina => 'Greater China';

  @override
  String get staffRegionTurkey => 'Türkiye';

  @override
  String get staffRegionIran => 'Iran';

  @override
  String get staffRegionSouthAsia => 'South Asia';

  @override
  String get staffRegionSoutheastAsia => 'Southeast Asia';

  @override
  String get staffRegionEastAsia => 'East Asia';

  @override
  String get staffRegionEurope => 'Europe';

  @override
  String get staffRegionNorthAmerica => 'North America';

  @override
  String get staffRegionLatinAmerica => 'Latin America';

  @override
  String get staffRegionSubSaharanAfrica => 'Sub-Saharan Africa';

  @override
  String get staffRegionRussiaCentralAsia => 'Russia & Central Asia';

  @override
  String get staffRegionOceania => 'Oceania';

  @override
  String staffRegionsTwo(String first, String second) {
    return '$first & $second';
  }

  @override
  String staffRegionsMore(String first, String second) {
    return '$first, $second and more';
  }

  @override
  String staffLineModeration(String regions) {
    return 'Moderator — $regions';
  }

  @override
  String staffLineSupport(String regions) {
    return 'Support — $regions';
  }

  @override
  String get staffLineFinance => 'Finance';

  @override
  String get postAnnouncementLabel => 'Official announcement — Kabso Team';

  @override
  String get postComposerAnnouncementOnly =>
      'Kabso Team accounts publish official announcements only.';

  @override
  String get meStaffAnnouncement => 'Post an announcement';

  @override
  String get meStaffAnnouncementReel => 'Post an announcement reel';

  @override
  String get staffFeatureUnavailable =>
      'Not available for Kabso Team accounts.';

  @override
  String get staffPictureLocked =>
      'The Kabso Team picture is fixed and cannot be changed.';

  @override
  String get staffCoverLocked =>
      'The Kabso Team cover is fixed and cannot be changed.';

  @override
  String get staffOfficialBioTitle => 'Official account';

  @override
  String get staffOfficialBio =>
      'The official account of the Kabso Live Team. We work around the clock to keep Kabso Live safe and fun for everyone. For support or to report a problem, message us directly.';

  @override
  String get staffBioLocked => 'Official bio, fixed and not editable';

  @override
  String get staffFrameLocked => 'The Kabso Team frame is locked.';

  @override
  String get staffTeamPicture => 'Kabso Team picture';

  @override
  String profileStaffId(String id) {
    return 'ID: $id';
  }

  @override
  String get profileStaffIdHint => 'Official Kabso Team staff ID';

  @override
  String get staffRoleBd => 'Business development';

  @override
  String staffLineBd(String regions) {
    return 'Business development — $regions';
  }

  @override
  String get recruiterFieldLabel =>
      'If a Kabso Team member referred you, enter their ID';

  @override
  String get recruiterFieldHint =>
      'Optional — their staff ID like Kabso01 or their username';

  @override
  String get recruiterChecking => 'Checking…';

  @override
  String get recruiterNotFound => 'Not found';

  @override
  String get recruiterFixError => 'Fix the team member\'s ID or leave it empty';

  @override
  String recruiterFoundSemantics(String name) {
    return 'Recruiter: $name';
  }

  @override
  String get staffMyRecruits => 'My recruits';

  @override
  String get staffMyEarnings => 'My earnings';

  @override
  String get staffRecruitsIntro =>
      'People who joined through you. You automatically earn a share of the platform profit from each of them, computed daily.';

  @override
  String get staffRecruitsEmpty =>
      'No recruits yet. Share your ID so applicants enter it in their forms.';

  @override
  String get recruitTypeAll => 'All';

  @override
  String get recruitTypeHost => 'Host';

  @override
  String get recruitTypeAgency => 'Agency';

  @override
  String get recruitTypeRechargeAgent => 'Recharge agent';

  @override
  String get recruitTypeCreator => 'Creator';

  @override
  String get recruitStatusActive => 'Active';

  @override
  String get recruitStatusInactive => 'Inactive';

  @override
  String recruitSince(String date) {
    return 'Since $date';
  }

  @override
  String recruitCherries(String cherries) {
    return '$cherries cherries';
  }

  @override
  String get staffEarningsBalance => 'Cherry balance';

  @override
  String staffEarningsWithdrawable(String cherries, String amount) {
    return 'Withdrawable: $cherries ≈ $amount';
  }

  @override
  String get staffEarningsTotal => 'Total commissions';

  @override
  String get staffEarnings30 => 'Last 30 days';

  @override
  String get staffEarningsWithdraw => 'Withdraw earnings';

  @override
  String get staffEarningsPending => 'A withdrawal is being paid';

  @override
  String get staffEarningsByRecruit => 'By recruit';

  @override
  String get staffEarningsHistory => 'Daily history';

  @override
  String get staffEarningsEmpty =>
      'No commissions yet — they are computed every day from the actual platform profit.';

  @override
  String staffEarningsShares(
    String host,
    String creator,
    String agency,
    String recharge,
  ) {
    return 'Your share: $host hosts · $creator creators · $agency agencies · $recharge recharge agents';
  }

  @override
  String staffEarningsDayLine(String profit, String pct) {
    return 'Platform profit $profit × $pct';
  }

  @override
  String get creatorProgrammeEntry => 'Creator programme';

  @override
  String get creatorProgrammeTitle => 'Join as a content creator';

  @override
  String get creatorProgrammeIntro =>
      'Apply and the Kabso team will review it. Once approved you are a Kabso Live content creator.';

  @override
  String get creatorProgrammeCountry => 'Country';

  @override
  String get creatorProgrammeCategory => 'Content type';

  @override
  String get creatorProgrammeLinks => 'Links to your work (1 to 5)';

  @override
  String get creatorProgrammeLinkError => 'A link starting with https://';

  @override
  String get creatorProgrammeAddLink => 'Add a link';

  @override
  String get creatorProgrammeBio => 'About you (optional)';

  @override
  String get creatorProgrammeSubmit => 'Send the application';

  @override
  String get creatorProgrammeSent => 'Your application was sent';

  @override
  String get creatorProgrammePending => 'Your application is under review';

  @override
  String get creatorProgrammeMember => 'You are a Kabso Live content creator';

  @override
  String creatorProgrammeRejected(String reason) {
    return 'Your application was declined: $reason';
  }

  @override
  String get creatorProgrammeCancel => 'Withdraw the application';

  @override
  String get creatorProgrammeStaff =>
      'Kabso Team accounts do not apply to the creator programme.';

  @override
  String get creatorCatVideo => 'Video';

  @override
  String get creatorCatPhoto => 'Photos';

  @override
  String get creatorCatMusic => 'Music';

  @override
  String get creatorCatGaming => 'Gaming';

  @override
  String get creatorCatComedy => 'Comedy';

  @override
  String get creatorCatEducation => 'Education';

  @override
  String get creatorCatLifestyle => 'Lifestyle';

  @override
  String get creatorCatOther => 'Other';

  @override
  String get rechargeCherryBuyForAgentTitle => 'Buy cherries for the agent';

  @override
  String rechargeWorksFor(String name) {
    return 'Working for $name';
  }

  @override
  String rechargeCherryForAgentNote(String name) {
    return 'You buy for $name: the coins go to the agent\'s stock and the agent pays the host.';
  }

  @override
  String get rechargeBlockOffShift => 'Off shift: you can only look.';

  @override
  String get rechargeBlockNotPermitted =>
      'The agent has not allowed you to do this.';

  @override
  String get rechargeOrderClaimedByOther => 'Taken by another employee';

  @override
  String get rechargeOrderClaimedByAgent => 'The agent is handling it';

  @override
  String rechargeOrderClaimedBy(String name) {
    return 'Handled by $name';
  }

  @override
  String get rechargeOrderClaimedByYou => 'You are handling this order';

  @override
  String rechargeActedBy(String name) {
    return 'By $name';
  }

  @override
  String get rechargePermBuyCherries => 'Can buy cherries';

  @override
  String get rechargePermBuyCherriesHint =>
      'Buys hosts’ cherries for you during their shift';

  @override
  String get rechargePermReceivesOrders => 'Receives purchase orders';

  @override
  String get rechargePermReceivesOrdersHint =>
      'Gets buyers’ orders and handles them during their shift';

  @override
  String rechargeEmployeeActsToday(int cherries, int orders) {
    return 'Today: $cherries cherry purchases · $orders orders done';
  }

  @override
  String get errorRechargeEmployeeNotPermitted =>
      'The agent has not allowed you to do this.';

  @override
  String get errorRechargeOrderClaimed =>
      'Another employee already took this order.';

  @override
  String rechargeOrdersForAgentHint(String name) {
    return 'Buyers\' orders for $name; whoever takes one first owns it';
  }

  @override
  String get rechargeBlockStaff =>
      'You are on the Kabso Team now: you can’t work as a recharge employee, only look.';

  @override
  String get rechargeEmployeeIsStaffNote =>
      'On the Kabso Team now: can’t work for you. You can remove them.';

  @override
  String get errorRechargeEmployeeIsStaff =>
      'This is a Kabso Team account; it can’t be added as a recharge employee.';

  @override
  String get errorStaffAccountLimited => 'A Kabso Team account can’t do this.';

  @override
  String get staffSharedReports => 'Reports';

  @override
  String get staffSharedReportsTitle => 'Reports';

  @override
  String staffSharedReportsBadge(int count) {
    return '$count unresolved reports';
  }

  @override
  String get staffSharedReportsHint =>
      'Reports are shared by the moderators and the support: whoever resolves one presses «Mark resolved».';

  @override
  String get staffSharedTabOpen => 'Unresolved';

  @override
  String get staffSharedTabResolved => 'Resolved';

  @override
  String get staffSharedEmptyOpen => 'No reports waiting';

  @override
  String get staffSharedEmptyResolved => 'No resolved reports yet';

  @override
  String get staffSharedResolve => 'Mark resolved';

  @override
  String get staffSharedResolveTitle => 'Mark the report resolved';

  @override
  String get staffSharedResolveIntro =>
      'The report becomes resolved for every moderator and support member, with your name and the time.';

  @override
  String get staffSharedResolveNote => 'Note (optional)';

  @override
  String staffSharedResolvedBy(String name, String when) {
    return 'Resolved by $name · $when';
  }

  @override
  String staffSharedResolvedAt(String when) {
    return 'Resolved · $when';
  }

  @override
  String staffSharedResolutionNote(String note) {
    return 'Resolution note: $note';
  }

  @override
  String get staffSharedAlreadyResolved =>
      'Another team member already resolved it';

  @override
  String get staffSharedDone => 'Report resolved';

  @override
  String staffSharedReportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String staffSharedAuthor(String name) {
    return 'Author: $name';
  }

  @override
  String staffSharedReporterNote(String note) {
    return 'Reporter’s note: $note';
  }

  @override
  String get staffSharedGone => 'The content is gone or hidden';

  @override
  String get staffSharedOutcomeDismissed => 'Dismissed';

  @override
  String get staffReportTypePost => 'Post';

  @override
  String get staffReportTypeComment => 'Comment';

  @override
  String get staffReportTypeStory => 'Story';

  @override
  String get staffReportTypeUser => 'Account';

  @override
  String get staffReportTypeLive => 'Live';

  @override
  String get staffReportTypeLiveChat => 'Live chat message';

  @override
  String get staffReportTypeConfession => 'CP confession';

  @override
  String get staffReportTypeFamilyChat => 'Family chat message';

  @override
  String get staffReportTypeDm => 'Direct message';

  @override
  String get staffReportTypeLink => 'Profile link';

  @override
  String get notifStaffReportNew => 'A new report is waiting to be resolved';

  @override
  String get itemBadgeLimited => 'Limited time';

  @override
  String get itemBadgeNew => 'New';

  @override
  String get itemBadgeSeasonal => 'Seasonal';

  @override
  String get itemBadgeExclusive => 'Exclusive';

  @override
  String get itemBadgeMostWanted => 'Most wanted';

  @override
  String get itemBadgeFeatured => 'Featured';

  @override
  String get itemBadgeFullscreen => 'Full screen';

  @override
  String get itemBadgeSound => 'With sound';

  @override
  String get itemBadgeNoSound => 'No sound';

  @override
  String itemBadgeDaysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days left',
      one: '$n day left',
    );
    return '$_temp0';
  }

  @override
  String get itemBadgeEndsToday => 'Ends today';

  @override
  String get itemBadgesTitle => 'Badges';

  @override
  String get giftDetailsHint => 'Long press for details';

  @override
  String get giftDetailsLucky => 'Lucky gift';

  @override
  String get lrTitle => 'Level-raise requests';

  @override
  String get lrMeRow => 'Level-raise request';

  @override
  String get lrIntro =>
      'A new supporter from another app? Send the owner a request with a video of their account there; the owner sets the right support level.';

  @override
  String get lrNew => 'New request';

  @override
  String get lrEmpty => 'You haven’t sent a request yet.';

  @override
  String get lrStatusPending => 'Pending';

  @override
  String get lrStatusApproved => 'Approved';

  @override
  String get lrStatusRejected => 'Rejected';

  @override
  String lrApprovedLevel(String level) {
    return 'Raised to level $level';
  }

  @override
  String lrRejectReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String lrSourceLine(String app, String level, String id) {
    return '$app · level $level · ID $id';
  }

  @override
  String get lrFormTitle => 'Level-raise request';

  @override
  String get lrUsername => 'Kabso username';

  @override
  String get lrCheck => 'Check';

  @override
  String get lrNotFound => 'No account with this username';

  @override
  String get lrStaffAccount => 'A Kabso Team account: it has no levels';

  @override
  String get lrOpenExists => 'This supporter already has a pending request';

  @override
  String lrTotalRecharge(String coins) {
    return 'Total recharge: $coins';
  }

  @override
  String lrFirstDaysRecharge(String days, String coins) {
    return 'First $days days: $coins';
  }

  @override
  String lrLevels(String support, String charm) {
    return 'Support level $support · charm $charm';
  }

  @override
  String lrNotEligible(String min) {
    return 'You can send it now, but it can’t be approved before $min coins are recharged';
  }

  @override
  String get lrEligible => 'The recharge is enough for approval';

  @override
  String get lrSourceApp => 'App';

  @override
  String get lrConfirmed => 'Confirmed';

  @override
  String get lrEstimate => 'Estimate';

  @override
  String get lrOtherName => 'App name';

  @override
  String get lrAccountId => 'ID in the app';

  @override
  String get lrSourceLevel => 'Level in the app';

  @override
  String get lrVideo => 'Account video';

  @override
  String get lrVideoHint =>
      'Record the account page in the app showing the level and the ID (up to 90 seconds).';

  @override
  String get lrVideoPick => 'Choose the video';

  @override
  String lrVideoChosen(String seconds) {
    return '$seconds s video';
  }

  @override
  String lrVideoUploading(String percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get lrNote => 'Note (optional)';

  @override
  String get lrSend => 'Send the request';

  @override
  String get lrSent => 'The request was sent to the owner';

  @override
  String get lrRequired => 'Required';

  @override
  String get lrLevelRange => 'From 1 to 999';

  @override
  String notifLevelRaiseApproved(String user, String level) {
    return 'Level raise for $user approved: level $level';
  }

  @override
  String notifLevelRaiseRejected(String user) {
    return 'Level raise for $user not approved';
  }

  @override
  String notifLevelRaised(String level) {
    return 'Your support level was raised to level $level';
  }

  @override
  String lrDidYouMean(String name) {
    return 'Did you mean: $name?';
  }

  @override
  String lrDuplicate(String status, String date, String name) {
    return 'This account in this app already has a request ($status) since $date, sent by $name';
  }

  @override
  String get lrDuplicateShort =>
      'This account in this app already has a request';

  @override
  String get lrPreviouslyRejected =>
      'A request for this account was rejected before';

  @override
  String get medalsStageTitle => 'The medals I wear';

  @override
  String get medalsNotWorn => 'Not worn';

  @override
  String get medalsNoneWorn => 'You don\'t wear any medal';

  @override
  String medalsWornCount(int count, int max) {
    return 'Wearing $count of $max';
  }

  @override
  String get medalsTabAchievements => 'Achievements';

  @override
  String get medalsTabActivity => 'Activity';

  @override
  String get medalsTabEmpty => 'No medals in this tab';

  @override
  String get medalsNotObtained => 'Not obtained';

  @override
  String medalsLevel(int level) {
    return 'Level $level';
  }

  @override
  String get medalsWorn => 'Worn';

  @override
  String get medalsTopLevel => 'Top level';

  @override
  String medalsProgress(String value, String next) {
    return '$value / $next';
  }

  @override
  String get medalsLevelsTitle => 'Levels';

  @override
  String get medalsWear => 'Wear';

  @override
  String get medalsTakeOff => 'Take off';

  @override
  String get medalsWearSaved => 'Your worn medals were updated';

  @override
  String medalsThresholdLives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lives',
      one: '$count live',
    );
    return '$_temp0';
  }

  @override
  String medalsThresholdHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count live hours',
      one: '$count live hour',
    );
    return '$_temp0';
  }

  @override
  String medalsThresholdCharm(int count) {
    return 'Charm level $count';
  }

  @override
  String medalsThresholdBullets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bullet messages',
      one: '$count bullet message',
    );
    return '$_temp0';
  }

  @override
  String get medalsThresholdOnce => 'Once';

  @override
  String medalsLevelReachedLabel(String level) {
    return '$level, reached';
  }

  @override
  String medalsCardLabel(String name, String status) {
    return '$name, $status';
  }

  @override
  String notifMedalLevelUp(String name, int level) {
    return 'Your medal $name reached level $level';
  }

  @override
  String notifMedalLevelUpUnnamed(int level) {
    return 'Your medal reached level $level';
  }

  @override
  String medalsProfileWornCount(int count, int max) {
    return 'On your profile: $count of $max';
  }

  @override
  String medalsThresholdGiftCoins(String amount) {
    return '$amount coins of gifts';
  }

  @override
  String medalsThresholdLuckyCoins(String amount) {
    return '$amount coins of lucky gifts';
  }

  @override
  String get staffReportViewTitle => 'Report';

  @override
  String get staffReportBanner => 'Reported content';

  @override
  String get staffReportBannerHint =>
      'You see it as the Kabso Team whatever its state — others see it only while it is visible.';

  @override
  String get staffReportStateVisible => 'Visible';

  @override
  String get staffReportStateHidden => 'Hidden by moderation';

  @override
  String get staffReportStateDeleted => 'Deleted';

  @override
  String get staffReportStateExpired => 'Expired';

  @override
  String get staffReportStateLive => 'On air';

  @override
  String get staffReportStateEnded => 'Live ended';

  @override
  String get staffReportStateGone => 'Gone';

  @override
  String get staffReportContentDeleted => 'The content was deleted';

  @override
  String get staffReportSnapshotShown =>
      'What the report kept when it was made is shown.';

  @override
  String get staffReportReelMark => 'Reel';

  @override
  String get staffReportVideoMark => 'Video';

  @override
  String get staffReportOnPost => 'The comment is on this post';

  @override
  String get staffReportReportedComment => 'The reported comment';

  @override
  String get staffReportOpenProfile => 'Open the profile';

  @override
  String get staffReportEnterLive => 'Enter the live as the Kabso Team';

  @override
  String get staffReportLiveEnded =>
      'The live has ended — this is its summary.';

  @override
  String get staffReportDmTitle => 'Conversation — read only';

  @override
  String staffReportDmBetween(String sender, String recipient) {
    return 'From $sender to $recipient';
  }

  @override
  String get staffReportDmPrivacy =>
      'A snapshot kept by the report: only the reported message, not the rest of the conversation. Every opening is logged.';

  @override
  String get staffReportDmExpired =>
      'The original message ended after 24 hours; the snapshot stays.';

  @override
  String get staffReportDmPurged =>
      'The snapshot\'s content was cleared after the retention period.';

  @override
  String get staffReportDmImage => 'Picture';

  @override
  String get staffReportDmVoice => 'Voice note';

  @override
  String staffReportDmGift(String code, String quantity) {
    return 'Gift $code ×$quantity';
  }

  @override
  String get staffReportActionsTitle => 'Actions';

  @override
  String get staffReportActionWarn => 'Warn';

  @override
  String get staffReportActionRestrict => 'Restrict';

  @override
  String get staffReportActionSuspend => 'Suspend';

  @override
  String get staffReportActionBan => 'Ban';

  @override
  String get staffReportActionRemove => 'Hide the content';

  @override
  String get staffReportActionEndLive => 'End the live';

  @override
  String get staffReportRestrictNoPosting => 'No posting';

  @override
  String get staffReportRestrictNoLive => 'No live';

  @override
  String get staffReportRestrictChat => 'No messages';

  @override
  String staffReportDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get staffReportDuration => 'Duration';

  @override
  String get staffReportReason => 'Reason (kept in the log)';

  @override
  String get staffReportReasonRequired => 'Write the reason';

  @override
  String get staffReportAutoResolve =>
      'The report is resolved automatically after the action.';

  @override
  String staffReportConfirmWarn(String name) {
    return 'Warn $name?';
  }

  @override
  String staffReportConfirmRestrict(String name) {
    return 'Restrict $name?';
  }

  @override
  String staffReportConfirmSuspend(String name) {
    return 'Suspend $name\'s account for a while?';
  }

  @override
  String staffReportConfirmBan(String name) {
    return 'Ban $name for good?';
  }

  @override
  String get staffReportConfirmRemove => 'Hide this content from everyone?';

  @override
  String get staffReportConfirmBanHint =>
      'The account is suspended and cannot log in. The team can lift it from the panel.';

  @override
  String get staffReportConfirmSuspendHint =>
      'They cannot log in until the time is over.';

  @override
  String get staffReportApply => 'Apply';

  @override
  String get staffReportActionDone => 'Done — the report is resolved';

  @override
  String staffReportResolvedByAction(String action) {
    return 'Resolved by an action: $action';
  }

  @override
  String get staffReportNoActions => 'No actions for your role on this report.';

  @override
  String get staffReportOpen => 'Open';

  @override
  String get staffReportThreadTitle => 'The whole conversation — read only';

  @override
  String get staffReportThreadPrivacy =>
      'A copy kept when the report was made: every message of the conversation that existed then; later messages are never added. Every opening is logged.';

  @override
  String staffReportThreadCaptured(String when) {
    return 'Kept $when';
  }

  @override
  String staffReportThreadTruncated(String count) {
    return 'Only the last $count messages were kept.';
  }

  @override
  String get staffReportThreadReported => 'The reported message';

  @override
  String get staffReportThreadMediaMissing => 'File not kept';

  @override
  String get staffReportThreadEmpty =>
      'The conversation had no messages when it was reported.';

  @override
  String get staffReportActionDeleteContent => 'Delete for good';

  @override
  String get staffReportActionDeleteAccount => 'Delete the account';

  @override
  String get staffReportConfirmDeleteContent => 'Delete this content for good?';

  @override
  String staffReportConfirmDeleteAccount(String name) {
    return 'Delete $name\'s account?';
  }

  @override
  String get staffReportConfirmDeleteContentHint =>
      'A permanent deletion cannot be undone; the author is told.';

  @override
  String get staffReportConfirmDeleteAccountHint =>
      'The account\'s deletion starts with its grace period (it can be cancelled from the panel meanwhile); it is signed out everywhere.';

  @override
  String get staffReportConfirmWord => 'DELETE';

  @override
  String staffReportTypeToConfirm(String word) {
    return 'Type “$word” to confirm';
  }

  @override
  String get staffReportConfirmMismatch => 'Type the word exactly';

  @override
  String get staffReportThreadOpen => 'Tap to open the conversation';

  @override
  String staffReportThreadCount(String count) {
    return 'Messages kept: $count';
  }

  @override
  String get staffReportThreadOnlyReported =>
      'An older report: the reported message only';

  @override
  String get liveCreatorBadge => 'Creator';

  @override
  String get hostApplyRefusedCreator =>
      'You are a content creator: you go live through the creator programme and cannot also be a host';

  @override
  String get creatorProgrammeHost =>
      'You are a host: a host cannot also be a content creator.';

  @override
  String get agencyOpenBanned =>
      'Your agency was banned and cannot be opened again';

  @override
  String get agencyClosedBanned =>
      'Banned for activating a fake content creator';

  @override
  String get errorAgencyActivationNotAllowed =>
      'This member cannot be activated that way';

  @override
  String get agencyActivate => 'Activate';

  @override
  String agencyActivateTitle(String name) {
    return 'Activate $name';
  }

  @override
  String get agencyActivateIntro => 'Choose how this member goes live:';

  @override
  String get agencyActivateAsHost => 'Host';

  @override
  String get agencyActivateAsHostBody =>
      'Goes live in your agency at the usual host share.';

  @override
  String get agencyActivateAsCreator => 'Content creator';

  @override
  String get agencyActivateAsCreatorBody =>
      'For someone who makes content on other platforms. Needs their details and links to their work.';

  @override
  String get agencyCreatorShareNote => 'Creator share: 70%';

  @override
  String get agencyCreatorWarning =>
      'If you activate someone as a content creator who is not one, the agency will be banned and you will lose your earnings.';

  @override
  String get agencyCreatorConfirm =>
      'I read the warning and confirm this person is a content creator';

  @override
  String get agencyCreatorConfirmError => 'Tick the confirmation to continue';

  @override
  String get agencyActivateHostButton => 'Activate as host';

  @override
  String get agencyActivateCreatorButton => 'Activate as creator';

  @override
  String agencyActivatedHost(String name) {
    return '$name is now a host';
  }

  @override
  String agencyActivatedCreator(String name) {
    return '$name is now a content creator';
  }

  @override
  String get agencyActivationRefusedHost =>
      'This member is a host: they cannot be made a creator';

  @override
  String get agencyActivationRefusedCreator =>
      'This member is a content creator: they cannot be made a host';

  @override
  String get agencyActivationRefusedSuspended =>
      'Your agency is suspended by the team';

  @override
  String get verificationBadgeOwner => 'app owner';

  @override
  String get verificationBadgeStaff => 'Kabso Team';

  @override
  String get verificationBadgeRechargeAgent => 'recharge agent';

  @override
  String get verificationBadgeHostAgent => 'host agent';

  @override
  String get verificationBadgeCreator => 'content creator';

  @override
  String get verificationBadgeVerifiedHost => 'identity-verified host';

  @override
  String verificationBadgeLabel(String kind) {
    return 'Verified: $kind';
  }

  @override
  String get verificationBadgeAbout => 'Granted automatically by conditions';

  @override
  String get medalsReqFollowers => 'Followers';

  @override
  String get medalsReqLikes => 'Likes';

  @override
  String get medalsReqViews => 'Views';

  @override
  String get medalsReqAllTogether => 'All three together for the next level';

  @override
  String get medalsCreatorsOnly => 'Content creators only';

  @override
  String get medalsCreatorsOnlyBody =>
      'Followers, likes and views count for content creators only. A level you reached stays yours.';

  @override
  String medalsThresholdPkPoints(String points) {
    return '$points PK points';
  }

  @override
  String get ownerFollow => 'Follow the founder';

  @override
  String get ownerFollowing => 'Following the founder';

  @override
  String get ownerFeedbackButton => 'Suggest / report';

  @override
  String get ownerPrivate => 'Private';

  @override
  String get ownerEdit => 'Edit';

  @override
  String get ownerDelete => 'Delete';

  @override
  String get ownerSave => 'Save';

  @override
  String get ownerSeeAll => 'See all';

  @override
  String get ownerMoveUp => 'Move up';

  @override
  String get ownerMoveDown => 'Move down';

  @override
  String get ownerFieldRequired => 'Required';

  @override
  String get ownerDashboardTitle => 'Founder dashboard';

  @override
  String get ownerDashboardOnline => 'Online now';

  @override
  String ownerDashboardOnlineLong(int minutes) {
    return 'Users active in the last $minutes minutes';
  }

  @override
  String get ownerDashboardLives => 'Lives now';

  @override
  String get ownerDashboardIncome => 'Today\'s income';

  @override
  String get ownerDashboardIncomeHidden => 'hidden, tap to show';

  @override
  String get ownerDashboardIncomeWebsite => 'Website top-ups (cards)';

  @override
  String get ownerDashboardIncomeAgents => 'Agent top-ups';

  @override
  String ownerDashboardUpdated(String time) {
    return 'Updated $time · refreshed every minute';
  }

  @override
  String get ownerDashboardFailed =>
      'Couldn\'t load the numbers — tap to retry';

  @override
  String get ownerOfficialTitle => 'Official announcements';

  @override
  String get ownerOfficialLabel => 'Official';

  @override
  String get ownerOfficialMark => 'Mark as official announcement';

  @override
  String get ownerOfficialUnmark => 'Remove from official announcements';

  @override
  String get ownerOfficialMarked =>
      'Now an official announcement on your profile';

  @override
  String get ownerOfficialUnmarked => 'Removed from official announcements';

  @override
  String get ownerOfficialEmptyOwn =>
      'No official announcements yet. Choose “Mark as official announcement” in any of your posts\' menu.';

  @override
  String get ownerOfficialUntitled => 'Announcement';

  @override
  String get ownerJourneyTitle => 'The Kabso journey';

  @override
  String get ownerJourneySubtitle => 'The founder\'s and the platform\'s story';

  @override
  String get ownerJourneyLatest => 'Latest';

  @override
  String get ownerJourneyAdd => 'Add a milestone';

  @override
  String get ownerJourneyAddFirst => 'Add the first milestone of the journey';

  @override
  String get ownerJourneyEditOne => 'Edit the milestone';

  @override
  String get ownerJourneyEditorTitle => 'Edit the Kabso journey';

  @override
  String ownerJourneyEditorHint(int max) {
    return 'Drag or use the arrows to reorder · up to $max milestones';
  }

  @override
  String get ownerJourneyEmptyOwn => 'No milestones yet — add the first.';

  @override
  String get ownerJourneyDeleteConfirm => 'Delete this milestone?';

  @override
  String get ownerMilestoneTitleAr => 'Title (Arabic)';

  @override
  String get ownerMilestoneTitleEn => 'Title (English)';

  @override
  String get ownerMilestoneLineAr => 'Short line (Arabic)';

  @override
  String get ownerMilestoneLineEn => 'Short line (English)';

  @override
  String get ownerMilestoneMonth => 'Month';

  @override
  String get ownerMilestoneYear => 'Year';

  @override
  String get ownerMilestoneIcon => 'Icon';

  @override
  String get ownerMilestoneLatestHint => 'Marked “Latest” (one milestone only)';

  @override
  String get ownerCoverVideoTitle => 'Cover video';

  @override
  String get ownerCoverVideoHint =>
      'A short looping video instead of the cover picture (up to 60 s). Viewers whose app is in Arabic see the Arabic one, everyone else the English one; with only one, everyone sees it.';

  @override
  String get ownerCoverVideoArabic => 'Arabic video';

  @override
  String get ownerCoverVideoEnglish => 'English video';

  @override
  String get ownerCoverVideoNone => 'None';

  @override
  String ownerCoverVideoSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String ownerCoverVideoUploading(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get ownerCoverVideoChoose => 'Choose a video';

  @override
  String get ownerCoverVideoReplace => 'Replace';

  @override
  String get ownerCoverVideoRemove => 'Remove the video';

  @override
  String get ownerCoverVideoSaved => 'Cover video saved';

  @override
  String get ownerCoverVideoRemoved => 'Cover video removed';

  @override
  String get ownerBioDefault =>
      'Founder of Kabso Live. I built this place to bring us together through live streams, content and one community. Your ideas reach me directly, so share yours.';

  @override
  String get ownerBioTitle => 'Founder bio';

  @override
  String get ownerBioHint =>
      'Every visitor sees it in their app\'s language. Leave a field empty to show the default text.';

  @override
  String get ownerBioArabic => 'Arabic';

  @override
  String get ownerBioEnglish => 'English';

  @override
  String get ownerBioSaved => 'Bio saved';

  @override
  String get ownerCoverVideoPlay => 'Play the cover video';

  @override
  String get ownerCoverVideoPause => 'Pause the cover video';

  @override
  String get ownerCoverVideoMute => 'Mute';

  @override
  String get ownerCoverVideoUnmute => 'Unmute';

  @override
  String get ownerFeedbackTitle => 'Suggest a feature or report a staff member';

  @override
  String get ownerFeedbackSubtitle => 'Goes straight to the founder\'s inbox.';

  @override
  String get ownerFeedbackFeature => 'Suggest a feature';

  @override
  String get ownerFeedbackReport => 'Report a staff member';

  @override
  String get ownerFeedbackFeatureHint => 'What would you like to see?';

  @override
  String get ownerFeedbackReportHint => 'What happened? Give the details';

  @override
  String get ownerFeedbackStaff => 'Staff member';

  @override
  String get ownerFeedbackStaffHint => '@username or staff ID';

  @override
  String get ownerFeedbackStaffNone => 'No staff member matches';

  @override
  String get ownerFeedbackCategory => 'Reason';

  @override
  String get ownerFeedbackImage => 'Add a picture';

  @override
  String ownerFeedbackEvidence(int count) {
    return 'Evidence pictures (up to $count)';
  }

  @override
  String get ownerFeedbackImageInvalid =>
      'That picture is not supported or too large';

  @override
  String get ownerFeedbackConfidential =>
      'Your report is confidential: the staff member and the moderators never see it — only the top management reads it.';

  @override
  String get ownerFeedbackSend => 'Send';

  @override
  String get ownerFeedbackSent => 'Sent to the founder\'s inbox. Thank you.';

  @override
  String get ownerCategoryRudeness => 'Rudeness';

  @override
  String get ownerCategoryAbuseOfPower => 'Abuse of power';

  @override
  String get ownerCategoryUnfairAction => 'Unfair action';

  @override
  String get ownerCategoryNoResponse => 'No response';

  @override
  String get ownerCategoryCorruption => 'Bribery or corruption';

  @override
  String get ownerCategoryOther => 'Other';

  @override
  String get errorOwnerOnly => 'Only the app owner can do this.';

  @override
  String get errorOwnerJourneyLimit =>
      'The journey already has the most milestones allowed.';

  @override
  String get notifOwnerFeedbackFeature =>
      'A new feature suggestion in the founder\'s inbox';

  @override
  String get notifOwnerFeedbackReport =>
      'A new staff report in the founder\'s inbox';

  @override
  String get ownerAnnouncementNew => 'New official announcement';

  @override
  String get ownerAnnouncementEdit => 'Edit the announcement';

  @override
  String get ownerAnnouncementTextAr => 'Text in Arabic';

  @override
  String get ownerAnnouncementTextEn => 'Text in English';

  @override
  String get ownerAnnouncementHint =>
      'Arabic-language apps show the Arabic text, every other language the English one. It is everyone\'s first post until you publish a newer one, and everyone is notified once.';

  @override
  String get ownerAnnouncementEditHint => 'Editing sends no new notification.';

  @override
  String get ownerAnnouncementPhotos => 'Photos (optional)';

  @override
  String get ownerAnnouncementPublish => 'Publish to everyone';

  @override
  String get ownerAnnouncementPublished =>
      'Published. Everyone is notified within minutes.';

  @override
  String get ownerAnnouncementSaved => 'Saved, with no new notification.';

  @override
  String get ownerDashboardIncomeNote =>
      'Only money Kabso receives: store card top-ups less refunds, and what agents pay Kabso for their coin stock. An agent\'s sales to users are not counted.';

  @override
  String ownerDashboardIncomeOther(String currency) {
    return 'In another currency ($currency)';
  }

  @override
  String notifOwnerAnnouncement(String text) {
    return 'Official announcement from the founder: $text';
  }

  @override
  String get ownerSearchRole => 'Founder of Kabso Live';

  @override
  String get ownerSearchFollow => 'Follow';

  @override
  String get ownerSearchFollowing => 'Following';

  @override
  String get ownerProfitTitle => 'Profit';

  @override
  String get ownerProfitToday => 'Today\'s profit';

  @override
  String get ownerProfitBeforeShort => 'Before';

  @override
  String get ownerProfitAfterShort => 'After';

  @override
  String get ownerProfitBefore => 'Income before';

  @override
  String get ownerProfitAfter => 'Final profit after';

  @override
  String get ownerProfitDay => 'Day';

  @override
  String get ownerProfitMonth => 'Month';

  @override
  String get ownerProfitPickDay => 'Pick a day';

  @override
  String get ownerProfitCardCharged => 'Store card top-ups';

  @override
  String get ownerProfitRefunds => 'Refunds';

  @override
  String get ownerProfitChargebacks => 'Chargebacks';

  @override
  String get ownerProfitAgents => 'Agents\' purchases from Kabso';

  @override
  String get ownerProfitDeductions => 'Deductions';

  @override
  String get ownerProfitGifts => 'Hosts\' and creators\' share of gifts';

  @override
  String get ownerProfitAgencies => 'Agency commissions';

  @override
  String get ownerProfitReferrals => 'Referral rewards';

  @override
  String get ownerProfitTasks => 'Task and target rewards';

  @override
  String get ownerProfitStaff => 'Recruiters\' commissions';

  @override
  String get ownerProfitTeam => 'Team adjustments';

  @override
  String get ownerProfitCardFees => 'Card fees (estimated)';

  @override
  String ownerProfitCherries(String count, String rate) {
    return 'Cherries: $count, at the payout rate of $rate per million';
  }

  @override
  String ownerProfitFees(String count, String percent, String fixed) {
    return 'Orders: $count, at $percent plus $fixed each';
  }

  @override
  String get ownerProfitFixed => 'Fixed costs';

  @override
  String ownerProfitFixedShare(String days, String monthly) {
    return 'Days: $days of $monthly a month';
  }

  @override
  String get ownerProfitFixedNone => 'No fixed costs in this period';

  @override
  String get ownerProfitPartial =>
      'To date: the elapsed share of the fixed costs';

  @override
  String ownerProfitOther(String currency, String before, String after) {
    return '$currency: before $before, after $after';
  }

  @override
  String get ownerProfitFailed => 'Couldn\'t compute the profit';

  @override
  String get ownerProfitRetry => 'Try again';

  @override
  String get ownerCostsManage => 'Manage fixed costs';

  @override
  String get ownerCostsHint =>
      'A monthly amount in US dollars, split over the days of the month';

  @override
  String get ownerCostsEmpty => 'No fixed costs yet';

  @override
  String get ownerCostsAdd => 'Add a cost';

  @override
  String get ownerCostsEdit => 'Edit the cost';

  @override
  String get ownerCostsName => 'Name';

  @override
  String get ownerCostsNameHint => 'e.g. Claude, LiveKit or servers';

  @override
  String get ownerCostsMonthly => 'Monthly amount (USD)';

  @override
  String get ownerCostsFrom => 'From';

  @override
  String get ownerCostsTo => 'To (optional)';

  @override
  String get ownerCostsOngoing => 'Ongoing';

  @override
  String ownerCostsPerMonth(String amount) {
    return '$amount a month';
  }

  @override
  String get ownerCostsEnded => 'Ended';

  @override
  String get ownerCostsInvalid => 'Enter a name and an amount above zero';

  @override
  String get ownerCostsDelete => 'Delete';

  @override
  String ownerCostsDeleteConfirm(String name) {
    return 'Delete $name? It will no longer count in the profit.';
  }

  @override
  String get ownerCostsCancel => 'Cancel';

  @override
  String get ownerCostsSaved => 'Cost saved';

  @override
  String get ownerProfitCoins => 'Coins given away (prizes and rewards)';

  @override
  String ownerProfitCoinsDetail(String count, String rate) {
    return 'Coins: $count, at the lowest agent price of $rate per million';
  }

  @override
  String get eventsGifts => 'Event gifts';

  @override
  String eventsGiftPoints(String points) {
    return '$points pts';
  }

  @override
  String get eventsGiftPointsHint =>
      'Every coin sent in an event gift earns points';

  @override
  String get eventsRuleOnlyGifts =>
      'Points come only from sending the event gifts during the event.';

  @override
  String get eventsRuleMinimum =>
      'You must reach the minimum points to qualify for a prize.';

  @override
  String get eventsRuleAutoPayout =>
      'Prizes are sent automatically after the event ends.';

  @override
  String get eventsLocalTime => 'Dates in your local time';

  @override
  String get eventsBoardSenders => 'Supporters';

  @override
  String get eventsBoardReceivers => 'Hosts';

  @override
  String get eventsBoardCreators => 'Creators';

  @override
  String get eventsBoardAgencies => 'Agencies';

  @override
  String get eventsBoardCp => 'CP couples';

  @override
  String eventsMinPoints(String points) {
    return 'Minimum to qualify: $points pts';
  }

  @override
  String eventsPointsToQualify(String points) {
    return '$points pts to qualify';
  }

  @override
  String get eventsQualified => 'Qualified for a prize';

  @override
  String get eventsNotQualified => 'Not qualified';

  @override
  String eventsPrizeCherries(String amount) {
    return '$amount cherries';
  }

  @override
  String eventsPrizeDays(String name, String days) {
    return '$name · $days days';
  }

  @override
  String get eventsPrizeVip => 'VIP card';

  @override
  String get eventsPrizeItem => 'Item';

  @override
  String eventsAgencyOwner(String name) {
    return 'Owner: $name';
  }

  @override
  String eventsCpPair(String a, String b) {
    return '$a & $b';
  }

  @override
  String get eventsBoardsTitle => 'Ranks and prizes';

  @override
  String eventsPrizeCpMoney(String cherries, String coins) {
    return '$cherries cherries to a host / $coins coins to others';
  }

  @override
  String eventsPrizePermanent(String name) {
    return '$name · permanent';
  }

  @override
  String eventsPrizeMedalLevel(String name, String level) {
    return '$name (level $level)';
  }

  @override
  String eventsCountdownStarts(String time) {
    return 'Starts in $time';
  }

  @override
  String eventsCountdownEnds(String time) {
    return 'Ends in $time';
  }

  @override
  String get eventsCountdownEnded => 'The event has ended';

  @override
  String eventsMyBar(String rank, String points) {
    return 'My place: $rank · $points pts';
  }

  @override
  String eventsMyBarNone(String points) {
    return 'Not ranked yet · $points pts';
  }

  @override
  String eventsToNextRank(String points, String rank) {
    return '$points pts to place $rank';
  }

  @override
  String eventsSendGiftTitle(String name) {
    return 'Send $name in a live';
  }

  @override
  String get eventsSendGiftBody =>
      'Event gifts are sent from the gift panel inside any live; their points count at once.';

  @override
  String get eventsGoLive => 'Go to lives';

  @override
  String get eventsPrizePreview => 'Prize preview';

  @override
  String get notifEventPrizeWon =>
      'Congratulations, your event prize has arrived';

  @override
  String get founderActionsTitle => 'Founder actions';

  @override
  String founderActionsFor(String name) {
    return 'Founder actions · $name';
  }

  @override
  String get founderActionWarn => 'Warn';

  @override
  String get founderActionSuspend => 'Temporary ban';

  @override
  String get founderActionBan => 'Permanent ban';

  @override
  String get founderActionDelete => 'Delete account';

  @override
  String get founderActionWarnHint =>
      'The person gets a warning notification; their account stays as it is.';

  @override
  String get founderActionSuspendHint =>
      'They cannot log in until it ends; their live, if any, ends now.';

  @override
  String get founderActionBanHint =>
      'The account stays banned until it is lifted in the admin panel.';

  @override
  String get founderActionDeleteHint =>
      'The account enters its deletion grace period (they can restore it by logging in), then it is deleted for good.';

  @override
  String get founderActionReason => 'Reason';

  @override
  String get founderActionReasonHint => 'Required — kept in the audit log';

  @override
  String get founderActionDuration => 'Duration';

  @override
  String founderActionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String founderActionConfirmTitle(String action, String name) {
    return '$action — $name';
  }

  @override
  String get founderActionConfirm => 'Confirm';

  @override
  String founderActionDone(String action) {
    return 'Done: $action';
  }

  @override
  String get founderActionNotActive =>
      'Refused: the account is not active or already has a pending action.';

  @override
  String get founderActionSelfOrOwner =>
      'This action cannot be done on this account.';

  @override
  String giftOwnerBy(String name) {
    return 'By $name';
  }

  @override
  String giftOwnerSemantics(String name) {
    return 'Custom gift by $name';
  }

  @override
  String get liveRankMonth => 'This month';

  @override
  String get liveRankYear => 'This year';

  @override
  String get liveRankGames => 'Game Crazy';

  @override
  String get liveRankGamesEmpty => 'No game tickets spent yet in this period.';

  @override
  String liveRankTickets(String formatted) {
    return '$formatted tickets';
  }

  @override
  String liveRankCoins(String formatted) {
    return '$formatted coins';
  }

  @override
  String get liveRankRichEmpty => 'No gifts sent yet in this period.';

  @override
  String get navParty => 'Party';

  @override
  String get liveHubGoLive => 'Go live';

  @override
  String get feedCreate => 'Create';

  @override
  String get photoEditTitle => 'Edit photo';

  @override
  String get photoEditDone => 'Done';

  @override
  String get photoEditCancel => 'Cancel';

  @override
  String get photoEditPreview => 'The edited photo';

  @override
  String get photoEditRotate => 'Rotate';

  @override
  String get photoEditFailed => 'Couldn\'t edit this photo';

  @override
  String get photoToolCrop => 'Crop';

  @override
  String get photoToolFilters => 'Filters';

  @override
  String get photoToolAdjust => 'Adjust';

  @override
  String get photoAspectOriginal => 'Original';

  @override
  String get photoFilterNormal => 'Normal';

  @override
  String get photoFilterVivid => 'Vivid';

  @override
  String get photoFilterWarm => 'Warm';

  @override
  String get photoFilterCool => 'Cool';

  @override
  String get photoFilterMono => 'Mono';

  @override
  String get photoFilterFade => 'Fade';

  @override
  String get photoAdjustBrightness => 'Brightness';

  @override
  String get photoAdjustContrast => 'Contrast';

  @override
  String get createKindPost => 'Post';

  @override
  String get createKindReel => 'Reels';

  @override
  String get createKindStory => 'Story';

  @override
  String get createEditPhoto => 'Edit';

  @override
  String get createSuggestions => 'Suggestions';

  @override
  String get uploadRetrying => 'Connection lost — trying again…';

  @override
  String get uploadView => 'View';

  @override
  String createSuggestionPosts(String count) {
    return '$count posts';
  }

  @override
  String get dmStoriesTitle => 'Stories';

  @override
  String get dmStoriesAdd => 'Add story';

  @override
  String relativeShortMinutes(int n) {
    return '${n}m';
  }

  @override
  String relativeShortHours(int n) {
    return '${n}h';
  }

  @override
  String relativeShortDays(int n) {
    return '${n}d';
  }

  @override
  String get dmBoxes => 'Message boxes';

  @override
  String get dmTabArchived => 'Archived';

  @override
  String get dmArchive => 'Archive';

  @override
  String get dmUnarchive => 'Unarchive';

  @override
  String get dmArchivedDone => 'Archived';

  @override
  String get dmUnarchivedDone => 'Moved back to Chats';

  @override
  String get dmArchivedEmptyTitle => 'No archived chats';

  @override
  String get dmArchivedHint =>
      'Chats you archive show here, only for you. They move back to Chats when a new reply arrives.';

  @override
  String get dmNewGroup => 'New group';

  @override
  String get dmGroupNameLabel => 'Group name';

  @override
  String get dmGroupNameHint => 'e.g. Uni friends';

  @override
  String get dmGroupNameRequired => 'Enter a group name';

  @override
  String get dmGroupAddPhoto => 'Add photo';

  @override
  String get dmGroupChangePhoto => 'Change photo';

  @override
  String get dmGroupRemovePhoto => 'Remove photo';

  @override
  String get dmGroupPhoto => 'Group photo';

  @override
  String get dmGroupPickMembers => 'Choose members';

  @override
  String get dmGroupPickHint =>
      'You can add people you follow who follow you back.';

  @override
  String get dmGroupPickAtLeastOne => 'Choose at least one person';

  @override
  String dmGroupSelected(String count) {
    return 'Selected: $count';
  }

  @override
  String get dmGroupSearchPeople => 'Search people';

  @override
  String get dmGroupCreate => 'Create';

  @override
  String get dmGroupCandidatesEmpty => 'No one to add yet';

  @override
  String get dmGroupCandidatesEmptyBody =>
      'Follow people who follow you back to add them to a group.';

  @override
  String dmGroupMembersCount(String count) {
    return 'Members: $count';
  }

  @override
  String get dmGroupInfo => 'Group info';

  @override
  String get dmGroupMembers => 'Members';

  @override
  String get dmGroupAddMembers => 'Add members';

  @override
  String get dmGroupMembersAdded => 'Members added';

  @override
  String get dmGroupAdmin => 'Admin';

  @override
  String get dmGroupCreator => 'Creator';

  @override
  String get dmGroupYou => 'You';

  @override
  String get dmGroupMakeAdmin => 'Make admin';

  @override
  String get dmGroupRemoveAdmin => 'Remove as admin';

  @override
  String get dmGroupRemoveMember => 'Remove from group';

  @override
  String get dmGroupRename => 'Rename';

  @override
  String get dmGroupSave => 'Save';

  @override
  String get dmGroupLeave => 'Leave group';

  @override
  String get dmGroupLeaveTitle => 'Leave the group?';

  @override
  String get dmGroupLeaveBody =>
      'You won\'t get its messages any more. An admin can add you again.';

  @override
  String get dmGroupReport => 'Report group';

  @override
  String get dmGroupUnavailable => 'This group is no longer available';

  @override
  String get dmGroupUnknownSender => 'Unavailable account';

  @override
  String dmPreviewSender(String name, String text) {
    return '$name: $text';
  }

  @override
  String get dmGroupNoGifts => 'Gifts can\'t be sent in groups';

  @override
  String get errorDmNotArchivable =>
      'A message request can\'t be archived. Accept or delete it.';

  @override
  String get errorDmGroupFull => 'This group has reached its member limit.';

  @override
  String get errorDmGroupMemberNotAllowed =>
      'You can\'t add some of these people to a group.';

  @override
  String eventsFinalRank(String rank) {
    return 'Your final place: $rank';
  }

  @override
  String get eventsNotParticipated => 'You did not take part';

  @override
  String eventsNotQualifiedFinal(String points) {
    return 'Not qualified — minimum $points pts';
  }

  @override
  String get eventsYouWon => 'You won:';

  @override
  String eventsYouWonShort(String prize) {
    return 'You won $prize';
  }

  @override
  String eventsYouWonMore(String prize, String count) {
    return 'You won $prize +$count';
  }

  @override
  String get eventsPrizePending => 'Your prize is delivered after the review';

  @override
  String get eventsResultsPending => 'Final results being confirmed';

  @override
  String eventsMyBarFinal(String rank, String points) {
    return 'Final place: $rank · $points pts';
  }

  @override
  String get eventsMyBarNotRanked => 'Not ranked yet';

  @override
  String get eventsAnnounceStarted => 'A new event has started';

  @override
  String get eventsAnnounceJoin => 'Join now';

  @override
  String get eventsAnnounceLater => 'Later';

  @override
  String get eventsAnnounceTopPrize => 'Top prize';

  @override
  String get eventsAnnounceWinTitle => 'Congratulations';

  @override
  String eventsAnnounceWinBody(String rank, String event) {
    return 'You took place $rank in $event';
  }

  @override
  String get eventsAnnounceYourPrize => 'Your prize';

  @override
  String get eventsAnnounceResults => 'See the results';

  @override
  String get eventsAnnounceClose => 'Close the announcement';

  @override
  String get eventsNotQualifiedYou => 'Not qualified';

  @override
  String get storeIapTitle => 'Buy from the store';

  @override
  String storeIapVia(String store) {
    return 'Pay with $store';
  }

  @override
  String storeIapCoins(String coins) {
    return '$coins coins';
  }

  @override
  String storeIapBuyLabel(String coins, String price) {
    return 'Buy $coins coins for $price';
  }

  @override
  String get storeIapConsentTitle => 'Before you buy';

  @override
  String get storeIapConsentDelivery =>
      'The coins are added to your balance at once and used up as you spend them; they are not refundable after purchase.';

  @override
  String get storeIapConsentFraud =>
      'A refund request through the store is treated as fraud: the coins are taken back (your balance may go below zero) and the account and the device are banned.';

  @override
  String storeIapConsentShare(String store) {
    return 'If you ask for a refund, Kabso tells $store how much of these coins was used, to help it decide.';
  }

  @override
  String get storeIapConsentCheck =>
      'I agree to the no-refund policy and to sharing usage data if I ask for a refund';

  @override
  String storeIapConsentContinue(String store) {
    return 'Continue to $store';
  }

  @override
  String storeIapConsentPrice(String coins, String price) {
    return '$coins coins — $price';
  }

  @override
  String get storeIapConsentTerms =>
      'Details in the Terms of Use: “Store purchases and the no-refund policy”.';

  @override
  String get storeIapVerifying => 'Confirming the purchase with the store…';

  @override
  String get storeIapPending =>
      'The store is still processing the payment. The coins are added when it completes.';

  @override
  String storeIapSuccess(String coins) {
    return '$coins coins were added to your balance.';
  }

  @override
  String get storeIapRejected =>
      'No coins were added: one store purchase per account and device. The store refunds you automatically.';

  @override
  String get storeIapStoreError =>
      'The purchase was not completed in the store.';

  @override
  String get storeIapDeviceBanned =>
      'Store purchases are not available on this device because it is banned.';

  @override
  String get storeIapLimitReached =>
      'This account or device already bought from the store. Store purchases are limited to one.';

  @override
  String get storeIapDismiss => 'OK';

  @override
  String get errorStoreIapUnavailable =>
      'Store purchases are not available right now.';

  @override
  String get errorStoreIapVerificationFailed =>
      'The store did not confirm this purchase; no coins were added.';

  @override
  String get errorStoreIapPurchaseConflict =>
      'This purchase belongs to another account.';

  @override
  String get errorStoreIapPending =>
      'The store is still processing the payment.';

  @override
  String get walletReasonStoreIap => 'Store purchase';

  @override
  String get walletReasonStoreIapReversal => 'Store refund (coins taken back)';
}
