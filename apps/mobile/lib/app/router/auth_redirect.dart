import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// Pure redirect rules of the auth guard (unit-testable).
///
/// - Restoring / restore failed → stay on the splash.
/// - Signed out → only the public auth routes.
/// - Signed in → never the splash or the public auth routes.
String? authRedirect(AuthState state, String location) {
  final isSplash = location == AppRoutes.splash;
  final isPublicAuth = AppRoutes.publicAuthRoutes.contains(location);

  switch (state) {
    case AuthRestoring():
    case AuthRestoreFailed():
      return isSplash ? null : AppRoutes.splash;
    case Unauthenticated():
      return isPublicAuth ? null : AppRoutes.login;
    case Authenticated():
      return isSplash || isPublicAuth ? AppRoutes.home : null;
  }
}
