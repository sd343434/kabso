import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

import '../helpers/fakes.dart';

void main() {
  group('restoring', () {
    test('everything goes to the splash', () {
      for (final state in [
        const AuthRestoring(),
        const AuthRestoreFailed(NetworkFailure.offline()),
      ]) {
        expect(authRedirect(state, AppRoutes.splash), isNull);
        expect(authRedirect(state, AppRoutes.home), AppRoutes.splash);
        expect(authRedirect(state, AppRoutes.login), AppRoutes.splash);
      }
    });
  });

  group('signed out', () {
    const state = Unauthenticated();

    test('public auth routes are allowed', () {
      for (final r in AppRoutes.publicAuthRoutes) {
        expect(authRedirect(state, r), isNull, reason: r);
      }
    });

    test('everything else goes to login', () {
      for (final r in [
        AppRoutes.splash,
        AppRoutes.verifyEmailNotice,
        AppRoutes.settings,
        ...AppRoutes.shellBranches,
      ]) {
        expect(authRedirect(state, r), AppRoutes.login, reason: r);
      }
    });
  });

  group('signed in', () {
    final state = Authenticated(testUser());

    test('splash and public auth routes go home', () {
      expect(authRedirect(state, AppRoutes.splash), AppRoutes.home);
      for (final r in AppRoutes.publicAuthRoutes) {
        expect(authRedirect(state, r), AppRoutes.home, reason: r);
      }
    });

    test('app routes are allowed', () {
      for (final r in [AppRoutes.settings, ...AppRoutes.shellBranches]) {
        expect(authRedirect(state, r), isNull, reason: r);
      }
    });

    test('right after registration the verify notice comes first', () {
      final fresh = Authenticated(testUser(), justRegistered: true);
      expect(
        authRedirect(fresh, AppRoutes.register),
        AppRoutes.verifyEmailNotice,
      );
      expect(authRedirect(fresh, AppRoutes.verifyEmailNotice), isNull);
    });
  });
}
