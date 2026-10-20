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
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();

      expect(find.text(l10n.validationRequired), findsNWidgets(2));
    });

    testWidgets('identifier shorter than 3 chars is rejected', (tester) async {
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'ab');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
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
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.errorServiceBusyRetryIn('0:05')), findsOneWidget);
    });

    testWidgets('RATE_LIMITED: m:ss countdown, submit disabled until zero', (
      tester,
    ) async {
      repo.loginFailure = const ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'slow down',
        statusCode: 429,
        retryAfter: Duration(seconds: 65),
      );
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();
      expect(repo.loginCalls, 1);
      expect(find.text(l10n.errorRateLimitedRetryIn('1:05')), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.errorRateLimitedRetryIn('1:04')), findsOneWidget);

      // Disabled: tapping does not submit again. (D64: Kabi's stage and the
      // error banner push the button below the 800×600 test view.)
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      expect(repo.loginCalls, 1);

      await tester.pump(const Duration(seconds: 64));
      expect(find.text(l10n.errorRateLimited), findsOneWidget);

      repo.loginFailure = null;
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      expect(repo.loginCalls, 2);
    });

    testWidgets('INTERNAL_ERROR shows a selectable Error ID', (tester) async {
      repo.loginFailure = const ServerFailure(
        code: ErrorCode.internalError,
        rawCode: 'INTERNAL_ERROR',
        debugMessage: 'boom',
        statusCode: 500,
        requestId: '0192f1c2-aaaa-7bbb-8ccc-1234567890ab',
      );
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.errorInternal), findsOneWidget);
      final id = find.widgetWithText(
        SelectableText,
        l10n.errorIdLabel('0192f1c2-aaaa-7bbb-8ccc-1234567890ab'),
      );
      expect(id, findsOneWidget);
    });

    testWidgets('AUTH_INVALID_CREDENTIALS shows no Error ID', (tester) async {
      repo.loginFailure = const ServerFailure(
        code: ErrorCode.authInvalidCredentials,
        rawCode: 'AUTH_INVALID_CREDENTIALS',
        debugMessage: 'bad',
        statusCode: 401,
        requestId: 'req-1',
      );
      await pump(tester, const LoginScreen());
      await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
      await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SelectableText), findsNothing);
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
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.errorAuthInvalidCredentials), findsOneWidget);
      expect(find.text('Invalid email/username or password.'), findsNothing);
    });

    testWidgets('Arabic: RTL and Arabic validation copy', (tester) async {
      final ar = l10nFor(AppLanguage.ar);
      await pump(tester, const LoginScreen(), language: AppLanguage.ar);
      await tapVisible(tester, find.byKey(LoginScreen.submitKey));
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
      // `invalid` state: the specific reason, live.
      expect(find.text(l10n.usernameBadEdges), findsOneWidget);

      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();
      // Shown once (field error), not twice.
      expect(find.text(l10n.usernameBadEdges), findsOneWidget);
    });

    for (final (input, expected) in [
      ('a-b', 'badChars'),
      ('ab', 'tooShort'),
      ('abc.', 'badEdges'),
    ]) {
      testWidgets('invalid state reason for "$input" ($expected)', (
        tester,
      ) async {
        await pump(tester, const RegisterScreen());
        await tester.enterText(find.byKey(RegisterScreen.usernameKey), input);
        await tester.pump(const Duration(milliseconds: 350));
        final text = switch (expected) {
          'badChars' => l10n.usernameBadChars,
          'tooShort' => l10n.usernameTooShort,
          _ => l10n.usernameBadEdges,
        };
        expect(find.text(text), findsOneWidget);
        expect(repo.availabilityChecks, isEmpty);
      });
    }

    testWidgets('unknown state: check failed → neutral hint, submit allowed', (
      tester,
    ) async {
      repo.availabilityFailure = const NetworkFailure.offline();
      await pump(tester, const RegisterScreen());
      await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla');
      await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
      await tester.enterText(
        find.byKey(RegisterScreen.passwordKey),
        'pa55word!',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text(l10n.usernameCheckFailed), findsOneWidget);

      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();
      expect(repo.registerCalls, 1);
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

  group('RegisterScreen displayName (KL-017)', () {
    final l10n = l10nFor(AppLanguage.en);

    testWidgets('counter counts graphemes and turns red above 50; the '
        'name is never truncated', (tester) async {
      await pump(tester, const RegisterScreen());
      final field = find.byKey(RegisterScreen.displayNameKey);
      await tester.enterText(field, 'Layla 👨\u200D👩\u200D👧');
      await tester.pump();
      expect(find.text(l10n.displayNameCounter(7)), findsOneWidget);

      final long = 'x' * 51;
      await tester.enterText(field, long);
      await tester.pump();
      expect(find.text(l10n.displayNameCounter(51)), findsOneWidget);
      final counter = tester.widget<Text>(
        find.text(l10n.displayNameCounter(51)),
      );
      expect(counter.style?.color, isNotNull);
      expect(find.text(long), findsOneWidget, reason: 'no silent truncation');

      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();
      expect(find.text(l10n.displayNameTooLong), findsOneWidget);
    });

    testWidgets('server reserved_term → neutral copy on the field', (
      tester,
    ) async {
      repo.registerFailure = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'reserved',
        details: [FieldIssue(field: 'displayName', issue: 'reserved_term')],
      );
      await pump(tester, const RegisterScreen());
      await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
      await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla');
      await tester.enterText(
        find.byKey(RegisterScreen.displayNameKey),
        'Kabso Official',
      );
      await tester.enterText(
        find.byKey(RegisterScreen.passwordKey),
        'pa55word!',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.displayNameReserved), findsOneWidget);
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

      expect(find.text(l10n.usernameBadChars), findsOneWidget);
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

    testWidgets('v1.2 (D24): an EMAIL_TAKEN from an old server never '
        'reveals email use — generic banner, no email field error', (
      tester,
    ) async {
      repo.registerFailure = const ServerFailure(
        code: ErrorCode.emailTaken,
        rawCode: 'EMAIL_TAKEN',
        debugMessage: 'taken',
      );
      await pump(tester, const RegisterScreen());
      await fillAndSubmit(tester);

      expect(find.text(l10n.errorUnknown), findsOneWidget);
      final email = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(RegisterScreen.emailKey),
          matching: find.byType(TextField),
        ),
      );
      expect(email.decoration?.errorText, isNull);
      // Nothing on screen talks about the email being registered.
      expect(find.textContaining('already'), findsNothing);
      expect(find.textContaining('registered'), findsNothing);
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
