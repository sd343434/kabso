import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/join_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class _Ended extends SessionController {
  @override
  AuthState build() =>
      const Unauthenticated(reason: ErrorCode.authRefreshInvalid);
}

Future<void> _pumpSignedOut(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  Map<String, Object> prefs = const {},
}) async {
  await pumpKabsoApp(
    tester,
    language: language.name,
    prefs: prefs,
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('first launch only (D65)', () {
    testWidgets('the welcome screen marks itself seen', (tester) async {
      await _pumpSignedOut(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PreferenceKeys.welcomeSeen), isTrue);
    });

    testWidgets('a later launch goes from the splash straight to login', (
      tester,
    ) async {
      await _pumpSignedOut(
        tester,
        prefs: const {PreferenceKeys.welcomeSeen: true},
      );
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    test('authRedirect: welcome first, login afterwards', () {
      const out = Unauthenticated();
      expect(authRedirect(out, AppRoutes.home), AppRoutes.welcome);
      expect(
        authRedirect(out, AppRoutes.home, welcomeSeen: true),
        AppRoutes.login,
      );
      // Both stay reachable once there (public routes).
      for (final r in [AppRoutes.welcome, AppRoutes.join]) {
        expect(authRedirect(out, r, welcomeSeen: true), isNull, reason: r);
      }
    });
  });

  group('join screen', () {
    testWidgets('on a 360×640 phone both buttons are on screen without '
        'scrolling, in both languages', (tester) async {
      await tester.runAsync(loadAppFonts);
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final language in AppLanguage.values) {
        await pumpScreen(tester, const JoinScreen(), language: language);
        await tester.pumpAndSettle();
        const screen = Rect.fromLTWH(0, 0, 360, 640);
        for (final key in [JoinScreen.createKey, JoinScreen.logInKey]) {
          final r = tester.getRect(find.byKey(key));
          expect(
            screen.contains(r.topLeft) && screen.contains(r.bottomRight),
            isTrue,
            reason: '${language.name}: $key at $r',
          );
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('large text (2.0) scrolls instead of overflowing', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, const JoinScreen());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(JoinScreen.logInKey));
      expect(tester.takeException(), isNull);
    });

    testWidgets('both buttons are labelled buttons', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = l10nFor(AppLanguage.en);
      await pumpScreen(tester, const JoinScreen());
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(JoinScreen.createKey)),
        isSemantics(label: l10n.joinCreate, isButton: true),
      );
      expect(
        tester.getSemantics(find.byKey(JoinScreen.logInKey)),
        isSemantics(label: l10n.loginSubmit, isButton: true),
      );
      handle.dispose();
    });
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name}: welcome shows the headline, both actions '
        'and Kabi', (tester) async {
      final l10n = l10nFor(language);
      await _pumpSignedOut(tester, language: language);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text(l10n.welcomeHeadline3), findsOneWidget);
      expect(find.text(l10n.welcomeBody), findsOneWidget);
      expect(find.text(l10n.welcomeStart), findsOneWidget);
      expect(find.byKey(WelcomeScreen.signUpKey), findsOneWidget);
      expect(find.byKey(WelcomeScreen.logInKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(WelcomeScreen.heroKey),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is KabiPainter,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('on a 360×640 phone both actions are on screen without '
      'scrolling', (tester) async {
    // Real fonts: the test font (squares) would wrap the headline.
    await tester.runAsync(loadAppFonts);
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final language in AppLanguage.values) {
      await _pumpSignedOut(tester, language: language);

      const screen = Rect.fromLTWH(0, 0, 360, 640);
      for (final key in [WelcomeScreen.signUpKey, WelcomeScreen.logInKey]) {
        final r = tester.getRect(find.byKey(key));
        expect(
          screen.contains(r.topLeft) && screen.contains(r.bottomRight),
          isTrue,
          reason: '${language.name}: $key at $r',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('"Log in" opens login with a back button to welcome', (
    tester,
  ) async {
    await _pumpSignedOut(tester);
    await tester.tap(find.byKey(WelcomeScreen.logInKey));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(LoginScreen.faceKey), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('"Let\'s start" opens join; "Create account" opens register, '
      '"Log in" opens login', (tester) async {
    await _pumpSignedOut(tester);
    await tapVisible(tester, find.byKey(WelcomeScreen.signUpKey));
    await tester.pumpAndSettle();
    expect(find.byType(JoinScreen), findsOneWidget);

    await tapVisible(tester, find.byKey(JoinScreen.createKey));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byKey(AuthHero.stageKey), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(JoinScreen.logInKey));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a session that ended lands on login (with its banner), '
      'without a back button', (tester) async {
    await pumpKabsoApp(
      tester,
      overrides: [
        sessionControllerProvider.overrideWith(_Ended.new),
        splashIntroProvider.overrideWith(_IntroDone.new),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text(l10nFor(AppLanguage.en).sessionEndedBanner),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);
  });

  group('social sign-in (CP-002 not implemented)', () {
    testWidgets('both buttons are disabled and say why', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = l10nFor(AppLanguage.en);
      await _pumpSignedOut(tester);
      await openLogin(tester);

      for (final (key, name) in [
        (AuthSocialButtons.googleKey, l10n.authProviderGoogle),
        (AuthSocialButtons.appleKey, l10n.authProviderApple),
      ]) {
        await tester.ensureVisible(find.byKey(key));
        expect(
          tester.getSemantics(find.byKey(key)),
          isSemantics(
            label: l10n.authSocialSoonLabel(name),
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('side by side on a phone, stacked on a narrow screen with '
        'large text', (tester) async {
      await pumpScreen(tester, const Scaffold(body: _Social(width: 345)));
      final google = tester.getRect(find.byKey(AuthSocialButtons.googleKey));
      final apple = tester.getRect(find.byKey(AuthSocialButtons.appleKey));
      expect(google.top, apple.top);

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, const Scaffold(body: _Social(width: 272)));
      final g = tester.getRect(find.byKey(AuthSocialButtons.googleKey));
      final a = tester.getRect(find.byKey(AuthSocialButtons.appleKey));
      expect(a.top, greaterThan(g.bottom));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('reduced motion: welcome is drawn at rest, no ticking', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpSignedOut(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text(l10nFor(AppLanguage.ar).welcomeComment1), findsNothing);
    expect(find.text(l10nFor(AppLanguage.en).welcomeComment1), findsNothing);
  });

  testWidgets('the welcome motion stops after ${KWelcome.motion} s', (
    tester,
  ) async {
    await pumpKabsoApp(
      tester,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    // Frame by frame through the splash until welcome is up.
    for (
      var i = 0;
      i < 100 && find.byType(WelcomeScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'still moving');

    await tester.pump(const Duration(seconds: 25));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

class _IntroDone extends SplashIntro {
  @override
  bool build() => true;
}

class _Social extends StatelessWidget {
  const new({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: width,
      child: const AuthSocialButtons(palette: KLoginPalette.dark),
    ),
  );
}
