/// Route registry (owned by the Flutter specialist; changes need CTO review).
abstract final class AppRoutes {
  static const splash = '/splash';

  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';

  /// Verify-first registration: enter the emailed 8-digit code (v1.2).
  static const registerCode = '/auth/register/code';

  static const home = '/home';
  static const discover = '/discover';
  static const create = '/create';
  static const live = '/live';

  /// KL-034: a live room, nested under the Live branch but shown above the
  /// shell (no bottom nav on full-screen live surfaces, HL-N1 §2).
  static const liveRoomSegment = 'room/:roomId';

  /// The location of the live room [roomId].
  static String liveRoom(String roomId) =>
      '$live/room/${Uri.encodeComponent(roomId)}';
  static const profile = '/profile';

  static const settings = '/settings';

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

  /// Reachable without a session.
  static const Set<String> publicAuthRoutes = {
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
    live,
    profile,
  ];
}
