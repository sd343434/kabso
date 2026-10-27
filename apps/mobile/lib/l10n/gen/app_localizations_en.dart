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
  String get liveToolbox => 'Toolbox';

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

  @override
  String get navPosts => 'Posts';

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
  String get liveBgHostTitle => 'Your live is on';

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
  String goLiveShareText(String title, String username) {
    return 'I\'m live on Kabso Live: “$title” — follow @$username';
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
  String get liveChatEmpty => 'No messages yet. Say hi.';

  @override
  String get liveChatOff => 'Chat is off';

  @override
  String get liveChatMutedPill => 'You\'re muted in this live\'s chat';

  @override
  String get liveChatSignIn => 'Log in to chat';

  @override
  String get liveChatFailed => 'Not sent. Tap to retry';

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
  String get liveToolFluent => 'Fluent';

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
  String get bagTakeOff => 'Take off';

  @override
  String get bagLocked => 'Not owned yet';

  @override
  String get bagEmptyTitle => 'Your bag is empty';

  @override
  String get bagEmptyMessage => 'Items you get will appear here.';

  @override
  String get bagOwnedSection => 'Your items';

  @override
  String get bagLockedSection => 'More items';

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
  String get liveHubBrand => 'Kabso';

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
}
