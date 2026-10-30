// KL-006 re-test (A6, QA) of the KL-012 fixes for QA-003..QA-007, written
// independently of A2's tests: covers register and forgot-password (A2 tested
// login), unknown codes, Arabic digits in countdowns, the "already ended"
// copy, and text scale 2.0 on screens the first QA pass did not reach.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/registration_flow.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

final _arabicIndicDigits = RegExp('[٠-٩۰-۹]');

ServerFailure _failure(
  String wire,
  ErrorCode code,
  int status, {
  Duration? retryAfter,
  String? requestId,
}) => ServerFailure(
  code: code,
  rawCode: wire,
  debugMessage: wire,
  statusCode: status,
  retryAfter: retryAfter,
  requestId: requestId,
);

/// Adds failure injection for forgot-password and revoke, and counts calls.
class _Repo extends FakeAuthRepository {
  AppFailure? forgotFailure;
  int forgotCalls = 0;
  AppFailure? restoreFailure;
  List<Session> sessions = [];
  AppFailure? revokeFailure;

  @override
  Future<User?> restoreSession() async {
    final f = restoreFailure;
    if (f != null) throw f;
    return storedUser;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    forgotCalls++;
    final f = forgotFailure;
    if (f != null) throw f;
  }

  @override
  Future<List<Session>> listSessions() async => List.of(sessions);

  @override
  Future<void> revokeSession(String sessionId) async {
    sessions = sessions.where((s) => s.id != sessionId).toList();
    final f = revokeFailure;
    if (f != null) throw f;
  }
}

String _allText(WidgetTester tester) => tester
    .widgetList<Widget>(
      find.byWidgetPredicate((w) => w is Text || w is SelectableText),
    )
    .map((w) => w is Text ? (w.data ?? '') : (w as SelectableText).data ?? '')
    .join(' | ');

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    AppLanguage language = AppLanguage.en,
  }) => pumpScreen(
    tester,
    screen,
    language: language,
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      usernameDebounceProvider.overrideWithValue(Duration.zero),
    ],
  );

  Future<void> fillRegister(WidgetTester tester) async {
    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
    await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla_22');
    await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), 'pa55word!');
    await chooseGender(tester);
    await tester.pump();
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
  }

  group('QA-007 register', () {
    testWidgets('RATE_LIMITED: 2:05 countdown, submit disabled until zero', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      repo.registerFailure = _failure(
        'RATE_LIMITED',
        ErrorCode.rateLimited,
        429,
        retryAfter: const Duration(seconds: 125),
      );
      await pump(tester, const RegisterScreen());
      await fillRegister(tester);
      await submit(tester, RegisterScreen.submitKey);
      expect(repo.registerCalls, 1);
      expect(find.text(l10n.errorRateLimitedRetryIn('2:05')), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text(l10n.errorRateLimitedRetryIn('2:03')), findsOneWidget);
      await submit(tester, RegisterScreen.submitKey);
      expect(repo.registerCalls, 1, reason: 'submit must be disabled');

      await tester.pump(const Duration(seconds: 123));
      repo.registerFailure = null;
      await submit(tester, RegisterScreen.submitKey);
      expect(repo.registerCalls, 2, reason: 'enabled again at zero');
    });

    testWidgets('503 from the Argon2 cap: busy countdown, disabled, Error ID', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      repo.registerFailure = _failure(
        'SERVICE_UNAVAILABLE',
        ErrorCode.serviceUnavailable,
        503,
        retryAfter: const Duration(seconds: 3),
        requestId: 'rid-argon-503',
      );
      await pump(tester, const RegisterScreen());
      await fillRegister(tester);
      await submit(tester, RegisterScreen.submitKey);

      expect(find.text(l10n.errorServiceBusyRetryIn('0:03')), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, l10n.errorIdLabel('rid-argon-503')),
        findsOneWidget,
      );
      await submit(tester, RegisterScreen.submitKey);
      expect(repo.registerCalls, 1);
      await tester.pump(const Duration(seconds: 3));
      await submit(tester, RegisterScreen.submitKey);
      expect(repo.registerCalls, 2);
    });

    testWidgets('Arabic countdown uses Latin digits', (tester) async {
      repo.registerFailure = _failure(
        'RATE_LIMITED',
        ErrorCode.rateLimited,
        429,
        retryAfter: const Duration(seconds: 754),
      );
      await pump(tester, const RegisterScreen(), language: AppLanguage.ar);
      await fillRegister(tester);
      await submit(tester, RegisterScreen.submitKey);
      final text = _allText(tester);
      expect(text, contains('12:34'), reason: text);
      expect(text, isNot(contains(_arabicIndicDigits)), reason: text);
    });
  });

  group('QA-007 forgot password', () {
    testWidgets('RATE_LIMITED over an hour: h:mm:ss, submit disabled', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      repo.forgotFailure = _failure(
        'RATE_LIMITED',
        ErrorCode.rateLimited,
        429,
        retryAfter: const Duration(seconds: 3600),
      );
      await pump(tester, const ForgotPasswordScreen());
      await tester.enterText(
        find.byKey(ForgotPasswordScreen.emailKey),
        'a@b.co',
      );
      await submit(tester, ForgotPasswordScreen.submitKey);
      expect(repo.forgotCalls, 1);
      expect(find.text(l10n.errorRateLimitedRetryIn('1:00:00')), findsOne);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.errorRateLimitedRetryIn('59:59')), findsOne);
      await submit(tester, ForgotPasswordScreen.submitKey);
      expect(repo.forgotCalls, 1);
      // Let the countdown finish so no timer is pending at teardown.
      await tester.pump(const Duration(seconds: 3600));
    });

    testWidgets('503 busy with Retry-After also disables submit', (
      tester,
    ) async {
      repo.forgotFailure = _failure(
        'SERVICE_UNAVAILABLE',
        ErrorCode.serviceUnavailable,
        503,
        retryAfter: const Duration(seconds: 2),
      );
      await pump(tester, const ForgotPasswordScreen());
      await tester.enterText(
        find.byKey(ForgotPasswordScreen.emailKey),
        'a@b.co',
      );
      await submit(tester, ForgotPasswordScreen.submitKey);
      await submit(tester, ForgotPasswordScreen.submitKey);
      expect(repo.forgotCalls, 1);
      await tester.pump(const Duration(seconds: 2));
      await submit(tester, ForgotPasswordScreen.submitKey);
      expect(repo.forgotCalls, 2);
    });
  });

  group('QA-007 Error ID', () {
    testWidgets('an unknown server code shows the generic copy + Error ID', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      repo.loginFailure = _failure(
        'SOMETHING_NEW',
        ErrorCode.unknown,
        418,
        requestId: 'rid-unknown',
      );
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla_22');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await submit(tester, LoginScreen.submitKey);
      expect(find.text(l10n.errorUnknown), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, l10n.errorIdLabel('rid-unknown')),
        findsOneWidget,
      );
    });
  });

  group('QA-006 revoke NOT_FOUND', () {
    testWidgets('shows "already ended" and removes the row', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final now = DateTime.now().toUtc();
      repo
        ..sessions = [
          Session(
            id: '0192f1c2-0000-7000-8000-000000000001',
            current: true,
            createdAt: now,
            lastUsedAt: now,
          ),
          Session(
            id: '0192f1c2-0000-7000-8000-000000000002',
            current: false,
            deviceName: 'Old Tablet',
            createdAt: now.subtract(const Duration(days: 3)),
            lastUsedAt: now.subtract(const Duration(hours: 5)),
          ),
        ]
        ..revokeFailure = _failure('NOT_FOUND', ErrorCode.notFound, 404);
      await pump(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      final tile = find.byKey(
        const Key('session.0192f1c2-0000-7000-8000-000000000002'),
      );
      await tester.scrollUntilVisible(tile, 100);
      expect(_allText(tester), contains(l10n.relativeHoursAgo(5)));
      await tester.tap(
        find.descendant(of: tile, matching: find.text(l10n.sessionsRevoke)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionsAlreadyEnded), findsOneWidget);
      expect(find.text(l10n.errorNotFound), findsNothing);
      expect(tile, findsNothing);
    });
  });

  group('QA-004 text scale 2.0 on further screens (360×640)', () {
    Future<ProviderContainer> app(
      WidgetTester tester,
      AppLanguage language,
      _Repo r,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.languageCode: language.name,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(r),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          ],
          child: const KabsoApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(KabsoApp)));
    }

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: splash restore error', (tester) async {
        final r = _Repo()..restoreFailure = const NetworkFailure.offline();
        await app(tester, language, r);
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      // Contract v1.2 retired the verify-email notice (PHASE1_1_SCREENS §0);
      // its replacement in the registration flow is the code-entry screen.
      testWidgets('${language.name}: registration code entry', (tester) async {
        // Signed out (login screen), then a register 202 opened the flow.
        final r = _Repo();
        final container = await app(tester, language, r);
        container
            .read(registrationFlowProvider.notifier)
            .draft = RegistrationDraft(
          email: 'layla@example.com',
          username: 'layla_22',
          displayName: 'ليلى',
          password: 'pa55word!',
          codeSentAt: DateTime.now(),
        );
        container.read(routerProvider).go(AppRoutes.registerCode);
        await tester.pumpAndSettle();
        expect(find.byType(RegisterCodeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${language.name}: login with countdown + Error ID banner', (
        tester,
      ) async {
        repo.loginFailure = _failure(
          'SERVICE_UNAVAILABLE',
          ErrorCode.serviceUnavailable,
          503,
          retryAfter: const Duration(seconds: 3725),
          requestId: '0192f1c2-aaaa-7bbb-8ccc-1234567890ab',
        );
        tester.view
          ..physicalSize = const Size(360, 640)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(tester, const LoginScreen(), language: language);
        await tester.enterText(
          find.byKey(LoginScreen.identifierKey),
          'layla_22',
        );
        await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
        await submit(tester, LoginScreen.submitKey);
        expect(_allText(tester), contains('1:02:05'));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3725));
      });

      testWidgets('${language.name}: register with every field error', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 640)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(tester, const RegisterScreen(), language: language);
        await tester.enterText(find.byKey(RegisterScreen.emailKey), 'nope');
        await tester.enterText(find.byKey(RegisterScreen.usernameKey), '_A');
        await tester.enterText(find.byKey(RegisterScreen.passwordKey), 'x');
        await tester.pump();
        await submit(tester, RegisterScreen.submitKey);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
