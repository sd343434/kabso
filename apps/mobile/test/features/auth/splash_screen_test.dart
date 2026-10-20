import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _Voice implements SplashVoice {
  int plays = 0;

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> dispose() async {}
}

/// Restore controlled by the test: completes, fails or never returns.
class _Repo extends FakeAuthRepository {
  final restore = Completer<User?>();

  @override
  Future<User?> restoreSession() => restore.future;
}

Future<_Voice> _pump(WidgetTester tester, _Repo repo) async {
  final voice = _Voice();
  await pumpKabsoApp(
    tester,
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      splashVoiceProvider.overrideWithValue(voice),
    ],
  );
  await tester.pump();
  return voice;
}

double _wordmarkOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(
        of: find.byKey(SplashScreen.wordmarkKey),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  test('the asset is the canvas and length the screen is built for', () {
    final json = jsonDecode(
      File(KSplash.animationAsset).readAsStringSync(),
    ) as Map<String, Object?>;
    final fps = json['fr']! as num;
    final frames = (json['op']! as num) - (json['ip']! as num);
    expect(json['w'], KSplash.canvas.width);
    expect(json['h'], KSplash.canvas.height);
    expect(frames / fps * 1000, KSplash.animation.inMilliseconds);
    expect(KSplash.total, KSplash.animation + KSplash.hold);
  });

  group('authRedirect while the intro plays', () {
    test('the splash stays, whatever the auth state', () {
      for (final state in [
        const AuthRestoring(),
        const AuthRestoreFailed(NetworkFailure.offline()),
        const Unauthenticated(),
        Authenticated(testUser()),
      ]) {
        expect(
          authRedirect(state, AppRoutes.splash, introDone: false),
          isNull,
          reason: '$state',
        );
      }
    });

    test('other routes keep their rules', () {
      expect(
        authRedirect(const Unauthenticated(), AppRoutes.home, introDone: false),
        AppRoutes.welcome,
      );
      expect(
        authRedirect(
          Authenticated(testUser()),
          AppRoutes.home,
          introDone: false,
        ),
        isNull,
      );
    });
  });

  testWidgets('signed out: the whole intro plays, with the voice once, '
      'then the welcome screen', (tester) async {
    final repo = _Repo()..restore.complete(null);
    final voice = await _pump(tester, repo);

    expect(find.byKey(SplashScreen.animationKey), findsOneWidget);
    expect(voice.plays, 1);
    expect(_wordmarkOpacity(tester), 0);

    // The session is known long before the animation ends.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);

    // The wordmark is fully in by frame 135 of 180 (2.25 s).
    await tester.pump(const Duration(milliseconds: 400));
    expect(_wordmarkOpacity(tester), 1);

    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(voice.plays, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in: home after the intro', (tester) async {
    final repo = _Repo()..restore.complete(testUser());
    await _pump(tester, repo);
    await tester.pump(KSplash.total - const Duration(milliseconds: 100));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('a slow restore shows the loading indicator after the intro, '
      'then moves on', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pump(KSplash.total - const Duration(milliseconds: 100));
    expect(find.byKey(SplashScreen.loadingKey), findsNothing);

    // The spinner never settles: pump past the end of the intro instead.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(SplashScreen.loadingKey), findsOneWidget);

    repo.restore.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('a failed restore shows the error state only after the intro', (
    tester,
  ) async {
    final repo = _Repo();
    await _pump(tester, repo);
    repo.restore.completeError(const NetworkFailure.offline());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FailureErrorState), findsNothing);
    expect(find.byKey(SplashScreen.animationKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(FailureErrorState), findsOneWidget);
  });

  testWidgets('reduced motion: last frame for the hold, no voice', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = _Repo()..restore.complete(null);
    final voice = await _pump(tester, repo);
    expect(voice.plays, 0);
    expect(_wordmarkOpacity(tester), 1);

    await tester.pump(KSplash.hold + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('screen readers hear the brand name once', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = _Repo();
    await _pump(tester, repo);
    expect(find.bySemanticsLabel('Kabso Live'), findsOneWidget);
    handle.dispose();
  });
}
