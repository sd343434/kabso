import 'package:flutter/foundation.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// Pure redirect rules of the auth guard (unit-testable).
///
/// - Launch animation still playing ([introDone] false) → stay on the
///   splash, whatever the auth state (D63).
/// - Restoring / restore failed → stay on the splash.
/// - Signed out → only the public auth routes; the welcome screen on the
///   first launch, login afterwards or when the session ended with a
///   reason to show (D64/D65).
/// - Signed in → never the splash or the public auth routes.
/// - Debug-only routes (labelled test data, never in release builds) open in
///   any state, so a test build can show the design previews without a
///   server or a session.
String? authRedirect(
  AuthState state,
  String location, {
  bool allowDebugRoutes = !kReleaseMode,
  bool introDone = true,
  bool welcomeSeen = false,
}) {
  if (allowDebugRoutes && location.startsWith(AppRoutes.debugPrefix)) {
    return null;
  }
  final isSplash = location == AppRoutes.splash;
  final isPublicAuth = AppRoutes.publicAuthRoutes.contains(location);
  if (isSplash && !introDone) return null;

  switch (state) {
    case AuthRestoring():
    case AuthRestoreFailed():
      return isSplash ? null : AppRoutes.splash;
    case Unauthenticated(:final reason):
      if (isPublicAuth) return null;
      // A session that ended (suspended, refresh refused) lands on login,
      // which explains why. Otherwise the first launch shows the welcome
      // screen and every later one goes straight to login (D65).
      if (reason != null || welcomeSeen) return AppRoutes.login;
      return AppRoutes.welcome;
    case Authenticated():
      return isSplash || isPublicAuth ? AppRoutes.home : null;
  }
}
