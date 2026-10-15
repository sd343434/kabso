import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

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
      usernameDebounceProvider.overrideWithValue(
        const Duration(milliseconds: 300),
      ),
    ],
  );

  group('LoginScreen', () {
    final l10n = l10nFor(AppLanguage.en);

    testWidgets('empty submit shows required messages', (tester) async {
      await pump(tester, const LoginScreen());
      await tester.tap(find.byKey(LoginScreen.submitKey));
      await tester.pump();

      expect(find.text(l10n.validationRequired), findsNWidgets(2));
    });

    testWidgets('identifier shorter than 3 chars is rejected', (tester) async {
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'ab');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tester.tap(find.byKey(LoginScreen.submitKey));
      await tester.pump();

      expect(find.text(l10n.validationTooShort(3)), findsOneWidget);
      expect(find.text(l10n.validationRequired), findsNothing);
    });

    testWidgets('503 under load shows the busy message with Retry-After', (
      tester,
    ) async {
      repo.loginFailure = const ServerFailure(
        code: ErrorCode.serviceUnavailable,
        rawCode: 'SERVICE_UNAVAILABLE',
        debugMessage: 'busy',
        statusCode: 503,
        retryAfter: Duration(seconds: 5),
      );
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tester.tap(find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(l10n.errorServiceBusyRetryIn(l10n.durationSeconds(5))),
        findsOneWidget,
      );
    });

    testWidgets('server error code is shown localized', (tester) async {
      repo.loginFailure = const ServerFailure(
        code: ErrorCode.authInvalidCredentials,
        rawCode: 'AUTH_INVALID_CREDENTIALS',
        debugMessage: 'Invalid email/username or password.',
        statusCode: 401,
      );
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tester.tap(find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.errorAuthInvalidCredentials), findsOneWidget);
      expect(find.text('Invalid email/username or password.'), findsNothing);
    });

    testWidgets('Arabic: RTL and Arabic validation copy', (tester) async {
      final ar = l10nFor(AppLanguage.ar);
      await pump(tester, const LoginScreen(), language: AppLanguage.ar);
      await tester.tap(find.byKey(LoginScreen.submitKey));
      await tester.pump();

      expect(find.text(ar.validationRequired), findsNWidgets(2));
      expect(
        Directionality.of(tester.element(find.text(ar.loginTitle).first)),
        TextDirection.rtl,
      );
    });
  });

  group('RegisterScreen username availability', () {
    final l10n = l10nFor(AppLanguage.en);

    testWidgets('checking → available', (tester) async {
      await pump(tester, const RegisterScreen());
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla');
      await tester.pump();

      expect(find.text(l10n.usernameChecking), findsOneWidget);
      expect(repo.availabilityChecks, isEmpty, reason: 'debounced');

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text(l10n.usernameAvailable('layla')), findsOneWidget);
      expect(repo.availabilityChecks, ['layla']);
    });

    testWidgets('checking → taken', (tester) async {
      repo.takenUsernames = {'admin'};
      await pump(tester, const RegisterScreen());
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'admin');
      await tester.pump();
      expect(find.text(l10n.usernameChecking), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text(l10n.usernameTaken('admin')), findsOneWidget);
    });

    testWidgets('typing quickly only checks the last value', (tester) async {
      await pump(tester, const RegisterScreen());
      final field = find.byKey(RegisterScreen.usernameKey);
      await tester.enterText(field, 'lay');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'layl');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'layla');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(repo.availabilityChecks, ['layla']);
    });

    testWidgets('input is lowercased; invalid names are not sent', (
      tester,
    ) async {
      await pump(tester, const RegisterScreen());
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), '_Bad');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('_bad'), findsOneWidget);
      expect(find.text(l10n.usernameChecking), findsNothing);
      expect(repo.availabilityChecks, isEmpty);

      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();
      expect(find.text(l10n.validationUsernameFormat), findsOneWidget);
    });

    testWidgets('client-side validation mirrors the contract', (tester) async {
      await pump(tester, const RegisterScreen());
      await tester.enterText(find.byKey(RegisterScreen.emailKey), 'nope');
      await tester.enterText(find.byKey(RegisterScreen.passwordKey), 'short');
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();

      expect(find.text(l10n.validationEmailInvalid), findsOneWidget);
      expect(find.text(l10n.validationTooShort(8)), findsOneWidget);
      // username + display name are empty
      expect(find.text(l10n.validationRequired), findsNWidgets(2));
    });
  });

  group('RegisterScreen server validation (contract v1.0.3)', () {
    final l10n = l10nFor(AppLanguage.en);

    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla');
      await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
      await tester.enterText(
        find.byKey(RegisterScreen.passwordKey),
        'pa55word!',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('field issue is shown on the field', (tester) async {
      repo.registerFailure = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'invalid',
        details: [FieldIssue(field: 'username', issue: 'invalid_format')],
      );
      await pump(tester, const RegisterScreen());
      await fillAndSubmit(tester);

      expect(find.text(l10n.validationUsernameFormat), findsOneWidget);
      expect(find.text(l10n.errorValidationFailed), findsNothing);
    });

    testWidgets('body-level error falls back to the form message', (
      tester,
    ) async {
      repo.registerFailure = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'bad json',
        details: [FieldIssue(field: '', issue: 'malformed_json')],
      );
      await pump(tester, const RegisterScreen());
      await fillAndSubmit(tester);

      expect(find.text(l10n.errorValidationFailed), findsOneWidget);
    });

    testWidgets('EMAIL_TAKEN is shown on the email field', (tester) async {
      repo.registerFailure = const ServerFailure(
        code: ErrorCode.emailTaken,
        rawCode: 'EMAIL_TAKEN',
        debugMessage: 'taken',
      );
      await pump(tester, const RegisterScreen());
      await fillAndSubmit(tester);

      expect(find.text(l10n.errorEmailTaken), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('always shows the same neutral confirmation', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await pump(tester, const ForgotPasswordScreen());
      await tester.enterText(
        find.byKey(ForgotPasswordScreen.emailKey),
        ' Someone@Example.com ',
      );
      await tester.tap(find.byKey(ForgotPasswordScreen.submitKey));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(l10n.forgotConfirmationBody('someone@example.com')),
        findsOneWidget,
      );
    });
  });

  group('text scaling 1.3 on a small phone', () {
    for (final entry in {
      'login': const LoginScreen(),
      'register': const RegisterScreen(),
      'forgot': const ForgotPasswordScreen(),
    }.entries) {
      for (final language in AppLanguage.values) {
        testWidgets('${entry.key} (${language.name}) has no overflow', (
          tester,
        ) async {
          tester.view
            ..physicalSize = const Size(320, 568)
            ..devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pump(tester, entry.value, language: language);
          await tester.pump();
          // Validation errors make the form taller; still no overflow.
          final submit = find.byWidgetPredicate(
            (w) =>
                w.key == LoginScreen.submitKey ||
                w.key == RegisterScreen.submitKey ||
                w.key == ForgotPasswordScreen.submitKey,
          );
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await tester.pump();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
