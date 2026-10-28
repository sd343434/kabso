/// Route registry (owned by the Flutter specialist; changes need CTO review).
abstract final class AppRoutes {
  static const splash = '/splash';

  /// D64/D65: first screen of the first signed-out launch.
  static const welcome = '/auth/welcome';

  /// D65: "Create account" or "Log in", after the welcome screen.
  static const join = '/auth/join';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';

  /// Verify-first registration: enter the emailed 8-digit code (v1.2).
  static const registerCode = '/auth/register/code';

  /// Home is the live-discovery hub (D48).
  static const home = '/home';
  static const discover = '/discover';
  static const create = '/create';

  /// Posts · Reels (D47/D48/D52), the second shell tab (D86).
  static const reels = '/reels';

  /// KL-034: a live room, nested under the Home (live hub) branch but shown
  /// above the shell (no bottom nav on full-screen live surfaces, HL-N1 §2).
  static const liveRoomSegment = 'room/:roomId';

  /// The location of the live room [roomId].
  static String liveRoom(String roomId) =>
      '$home/room/${Uri.encodeComponent(roomId)}';
  static const profile = '/profile';

  /// KL-060: one post (from a profile grid, search or a hashtag), pushed
  /// above the shell.
  static const postPattern = '/posts/:postId';

  /// KL-060: a hashtag's posts (lower case, without `#`).
  static const hashtagPattern = '/hashtags/:tag';

  /// D147: the hashtags of the week ("More" on the search home).
  static const trendingHashtags = '/search/hashtags';

  /// The page of [tag] (with or without `#`).
  static String hashtag(String tag) =>
      '/hashtags/${Uri.encodeComponent(tag.replaceFirst('#', '').toLowerCase())}';

  /// The screen of post [postId]; with [comments] its comments open at
  /// once (a comment notification, CP-009).
  static String post(String postId, {bool comments = false}) =>
      '/posts/${Uri.encodeComponent(postId)}${comments ? '?comments=1' : ''}';

  /// CP-008: one account's stories, full screen (then the next accounts
  /// of the tray).
  static const storiesPattern = '/stories/:username';

  /// The stories of [username].
  static String stories(String username) =>
      '/stories/${Uri.encodeComponent(username)}';

  /// CP-008: post a photo story.
  static const newStory = '/story/new';

  /// CP-010: go live (camera preview, then on air).
  static const goLive = '/live/new';

  /// D131: the voice rooms (the Live hub's party button), above the shell.
  static const voiceRooms = '/live/voice';

  /// CP-008: your story archive.
  static const storyArchive = '/me/stories';

  /// KL-060: your drafts and scheduled posts.
  static const drafts = '/me/drafts';

  /// KL-060: edit your post (caption, place, settings).
  static const editPostPattern = '/posts/:postId/edit';

  /// The edit screen of post [postId].
  static String editPost(String postId) => '${post(postId)}/edit';

  /// KL-060: who liked a post.
  static const postLikesPattern = '/posts/:postId/likes';

  /// The likers of post [postId].
  static String postLikes(String postId) => '${post(postId)}/likes';

  /// D60: another user's public profile (pushed above the shell).
  static const userProfilePattern = '/users/:username';

  /// The public profile of [username].
  static String userProfile(String username) =>
      '/users/${Uri.encodeComponent(username)}';

  /// D86: the Messages tab (the conversation list).
  static const messages = '/messages';

  /// D61: a private conversation with a user (not connected yet).
  static const chatPattern = '/messages/:username';

  /// The conversation with [username].
  static String chat(String username) =>
      '/messages/${Uri.encodeComponent(username)}';

  /// D58: edit the own profile (read-only until the contract allows saving).
  static const editProfile = '/profile/edit';

  static const settings = '/settings';

  /// KL-060: privacy settings and blocked accounts.
  static const privacy = '/settings/privacy';
  static const blockedAccounts = '/settings/blocked';

  /// CP-007: muted accounts.
  static const mutedAccounts = '/settings/muted';

  /// CP-009: in-app notifications and their settings.
  static const notifications = '/notifications';
  static const notificationSettings = '/settings/notifications';

  /// D72: the caller's four levels (CP-005), pushed above the shell.
  static const levels = '/levels';
  static const levelPattern = '/levels/:category';

  /// One category's levels; [category] is its lower-case code.
  static String level(String category) =>
      '/levels/${Uri.encodeComponent(category)}';

  /// CP-018: families (browse and search), a new family, one family.
  static const families = '/families';
  static const newFamily = '/families/new';
  static const familyPattern = '/families/:familyId';

  /// The page of family [familyId].
  static String family(String familyId) =>
      '/families/${Uri.encodeComponent(familyId)}';

  /// CP-022: the family chat of a family (members only).
  static const familyChatPattern = '/families/:familyId/chat';
  static String familyChat(String familyId) =>
      '/families/${Uri.encodeComponent(familyId)}/chat';

  /// CP-018: your relationship (CP) and its requests.
  static const cp = '/cp';

  /// CP-021: your couple's CP space, and a couple's read-only page.
  static const cpSpace = '/cp/space';
  static const cpCouplePattern = '/cp/couples/:coupleId';

  /// The CP space of couple [coupleId] (yours opens in full).
  static String cpCouple(String coupleId) =>
      '/cp/couples/${Uri.encodeComponent(coupleId)}';

  /// CP-018: the medal catalogue (yours) and the showcase picker.
  static const medals = '/medals';
  static const medalShowcase = '/medals/showcase';

  /// CP-019: the bag (owned items by category; the one worn).
  static const bag = '/bag';

  /// D146: the premium usernames store; [premiumFor] checks a name at once.
  static const premium = '/premium';
  static String premiumFor(String username) =>
      '$premium?q=${Uri.encodeQueryComponent(username)}';

  /// D146: change the regular username (`PUT /me/username`).
  static const changeUsername = '/settings/username';

  /// CP-018: another user's medals.
  static const userMedalsPattern = '/users/:username/medals';

  /// The medals of [username].
  static String userMedals(String username) =>
      '${userProfile(username)}/medals';

  /// D121: a user's followers and following (two tabs; `?tab=following`
  /// opens the second).
  static const userFollowsPattern = '/users/:username/follows';

  /// The follow lists of [username], on Following when [following].
  static String userFollows(String username, {bool following = false}) =>
      '${userProfile(username)}/follows${following ? '?tab=following' : ''}';

  /// Prefix of every debug-only route (`!kReleaseMode`).
  static const debugPrefix = '/debug/';

  /// KL-056 hub listing the design previews (test builds open here when
  /// built with `--dart-define=KABSO_START_ROUTE=/debug/previews`).
  /// Registered only when `!kReleaseMode`.
  static const debugPreviews = '/debug/previews';

  /// KL-022 component gallery. Registered only when `!kReleaseMode`.
  static const debugComponents = '/debug/components';

  /// KL-056 full-screen vertical feed preview with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugFeedPreview = '/debug/feed-preview';

  /// KL-056 full-screen live room preview with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugLivePreview = '/debug/live-preview';

  /// KL-056 private conversation preview with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugMessagesPreview = '/debug/messages-preview';

  /// KL-056 conversation list preview (test data, state switcher).
  /// Registered only when `!kReleaseMode`.
  static const debugConversationsPreview = '/debug/conversations-preview';

  /// KL-056 Discover preview (test data, state switcher).
  /// Registered only when `!kReleaseMode`.
  static const debugDiscoverPreview = '/debug/discover-preview';
  static const debugReelsPreview = '/debug/reels-preview';

  /// KL-056 the real Reels tab (Posts · Reels, D52) with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugPostsPreview = '/debug/posts-preview';

  /// KL-056 the real profile tab (D57) with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugProfilePreview = '/debug/profile-preview';

  /// KL-056 the edit-profile screen (D58) with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugProfileEditPreview = '/debug/profile-edit-preview';

  /// KL-056 another user's public profile (D60) with labelled test data.
  /// Registered only when `!kReleaseMode`.
  static const debugUserPreview = '/debug/user-preview';

  /// KL-056 the (not connected) conversation screen (D61), test name.
  /// Registered only when `!kReleaseMode`.
  static const debugChatPreview = '/debug/chat-preview';

  /// Reachable without a session.
  static const Set<String> publicAuthRoutes = {
    welcome,
    join,
    login,
    register,
    registerCode,
    forgotPassword,
  };

  /// Shell branches, in navigation order (start → end). D86 (owner): Live ·
  /// Posts · Create · Messages · Me; Discover opens from the search buttons.
  static const List<String> shellBranches = [
    home,
    reels,
    create,
    messages,
    profile,
  ];
}
