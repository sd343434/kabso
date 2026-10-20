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

  /// For you · Posts · Reels (D47/D48), the fourth shell tab.
  static const reels = '/reels';

  /// KL-034: a live room, nested under the Home (live hub) branch but shown
  /// above the shell (no bottom nav on full-screen live surfaces, HL-N1 §2).
  static const liveRoomSegment = 'room/:roomId';

  /// The location of the live room [roomId].
  static String liveRoom(String roomId) =>
      '$home/room/${Uri.encodeComponent(roomId)}';
  static const profile = '/profile';

  /// D60: another user's public profile (pushed above the shell).
  static const userProfilePattern = '/users/:username';

  /// The public profile of [username].
  static String userProfile(String username) =>
      '/users/${Uri.encodeComponent(username)}';

  /// D61: a private conversation with a user (not connected yet).
  static const chatPattern = '/messages/:username';

  /// The conversation with [username].
  static String chat(String username) =>
      '/messages/${Uri.encodeComponent(username)}';

  /// D58: edit the own profile (read-only until the contract allows saving).
  static const editProfile = '/profile/edit';

  static const settings = '/settings';

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

  /// Shell branches, in navigation order (start → end).
  static const List<String> shellBranches = [
    home,
    discover,
    create,
    reels,
    profile,
  ];
}
