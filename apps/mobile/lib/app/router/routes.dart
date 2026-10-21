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

  /// The page of [tag] (with or without `#`).
  static String hashtag(String tag) =>
      '/hashtags/${Uri.encodeComponent(tag.replaceFirst('#', '').toLowerCase())}';

  /// The screen of post [postId].
  static String post(String postId) => '/posts/${Uri.encodeComponent(postId)}';

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

  /// D72: the caller's four levels (CP-005), pushed above the shell.
  static const levels = '/levels';
  static const levelPattern = '/levels/:category';

  /// One category's levels; [category] is its lower-case code.
  static String level(String category) =>
      '/levels/${Uri.encodeComponent(category)}';

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
