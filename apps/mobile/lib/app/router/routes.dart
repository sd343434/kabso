/// Route registry (owned by the Flutter specialist; changes need CTO review).
abstract final class AppRoutes {
  static const splash = '/splash';

  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const verifyEmailNotice = '/auth/verify-email-notice';

  static const home = '/home';
  static const discover = '/discover';
  static const create = '/create';
  static const live = '/live';
  static const profile = '/profile';

  static const settings = '/settings';

  /// Reachable without a session.
  static const Set<String> publicAuthRoutes = {login, register, forgotPassword};

  /// Shell branches, in navigation order (start → end).
  static const List<String> shellBranches = [
    home,
    discover,
    create,
    live,
    profile,
  ];
}
