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
  String get navReels => 'Reels';

  @override
  String get navLive => 'Live';

  @override
  String get navProfile => 'Profile';

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
  String profileUsername(String username) {
    return '@$username';
  }

  @override
  String get profileContentComingTitle => 'Your posts will live here';

  @override
  String get profileContentComingBody =>
      'Posts arrive in Phase 3 and reels in Phase 5. Profile editing, stories and highlights come later.';

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
  String get debugComponentGallery => 'Component gallery';

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
  String get liveRoomEndedTitle => 'This live has ended';

  @override
  String get liveRoomEndedByHost => 'The host ended this live.';

  @override
  String get liveRoomEndedTimeout =>
      'The live stopped after the host\'s connection was lost.';

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
  String get previewsHubComponents => 'Components';

  @override
  String get commentsYou => 'You';

  @override
  String get conversationsTitle => 'Chats';

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
  String get reelsTabForYou => 'For you';

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
  String get profileEditSave => 'Save';

  @override
  String get profileEditName => 'Name';

  @override
  String get profileEditUsername => 'Username';

  @override
  String get profileEditBio => 'Bio';

  @override
  String get profileEditUnavailable =>
      'Changing your name, bio and photo needs a server update that isn\'t available yet.';

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
  String get profileOtherComingTitle => 'Posts and reels are coming';

  @override
  String get profileOtherComingBody =>
      'Posts arrive in Phase 3 and reels in Phase 5.';

  @override
  String get profileOtherEmptyBody => 'Nothing shared yet.';

  @override
  String get profilePrivateTitle => 'This account is private';

  @override
  String get profilePrivateBody =>
      'Their posts and reels are visible to approved followers only.';

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
  String get kabiEmojiHi => 'Hi';

  @override
  String get kabiEmojiLove => 'Love';

  @override
  String get kabiEmojiLol => 'Laughing';

  @override
  String get kabiEmojiWow => 'Wow';

  @override
  String get kabiEmojiSad => 'Sad';

  @override
  String get kabiEmojiAngry => 'Angry';

  @override
  String get kabiEmojiWink => 'Wink';

  @override
  String get kabiEmojiLive => 'Live';

  @override
  String get kabiEmojiCool => 'Cool';

  @override
  String get kabiEmojiDizzy => 'Dizzy';

  @override
  String get kabiEmojiSleepy => 'Sleepy';

  @override
  String get kabiEmojiSilly => 'Silly';

  @override
  String get kabiEmojiShy => 'Shy';

  @override
  String get kabiEmojiThink => 'Thinking';

  @override
  String get kabiEmojiParty => 'Party';

  @override
  String get kabiEmojiDead => 'Dying of laughter';

  @override
  String get kabiEmojiMelt => 'Melting';

  @override
  String get kabiEmojiKiss => 'Kiss';

  @override
  String get kabiEmojiPickerTitle => 'Kabi emojis';

  @override
  String get kabiEmojiButton => 'Emojis';

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
  String get chatVoiceSoon => 'Voice messages are coming soon';

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
  String get levelsIntro =>
      'Your points grow from gifts and game spending once they are confirmed. Each level has its own points.';

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
  String levelsToNext(String points) {
    return '$points to next level';
  }

  @override
  String levelsToNamed(String points, String level) {
    return '$points pts to reach $level';
  }

  @override
  String get levelsMax => 'Top level reached';

  @override
  String get levelsLadder => 'All levels';

  @override
  String get levelsCurrent => 'You\'re here';

  @override
  String get levelsLoadError => 'Couldn\'t load your levels';
}
