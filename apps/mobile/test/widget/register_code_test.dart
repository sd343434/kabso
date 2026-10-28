// KL-019: verify-first registration — register → code entry → signed in
// (contract v1.2, PHASE1_1_SCREENS §1).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/features/auth/presentation/widgets/code_field.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const _tokenInvalid = ServerFailure(
  code: ErrorCode.tokenInvalid,
  rawCode: 'TOKEN_INVALID',
  debugMessage: 'invalid',
  statusCode: 422,
);

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  /// Login → Register → submit (202) → code screen.
  Future<AppLocalizations> openCodeScreen(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    await pumpKabsoApp(
      tester,
      language: language.name,
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        usernameDebounceProvider.overrideWithValue(Duration.zero),
      ],
    );
    await tester.pumpAndSettle();
    final l10n = l10nFor(language);
    // D64: signed out, the app opens on welcome; open register.
    await openRegister(tester);
    await tester.enterText(
      find.byKey(RegisterScreen.emailKey),
      ' Layla@Example.com ',
    );
    await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla_22');
    await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'ليلى');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), 'pa55word!');
    await tester.pump();
    await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
    await tester.tap(find.byKey(RegisterScreen.submitKey));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterCodeScreen), findsOneWidget);
    return l10n;
  }

  String statusText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(RegisterCodeScreen.statusKey),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data)
      .join();

  testWidgets('register 202 opens the code screen with the normalized email '
      'and the default hint; no account or session yet', (tester) async {
    final l10n = await openCodeScreen(tester);
    expect(repo.registerCalls, 1);
    expect(
      find.text(l10n.codeBody('\u2068layla@example.com\u2069')),
      findsOneWidget,
    );
    expect(statusText(tester), l10n.codeExpiryHint);
    expect(find.byKey(const Key('nav.home')), findsNothing);
  });

  testWidgets('Arabic-Indic paste is normalized to Latin and auto-submits '
      'once; success signs in and lands on Home', (tester) async {
    final l10n = await openCodeScreen(tester);
    await tester.enterText(
      find.byKey(RegisterCodeScreen.codeFieldKey),
      '\u200F٤٨٢١ ٠٩٣٧',
    );
    await tester.pump();
    expect(repo.verifyCalls, ['48210937']);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav.home')), findsOneWidget);
    expect(find.text(l10n.codeWelcome), findsOneWidget);
    expect(repo.verifyCalls, hasLength(1), reason: 'submitted once');
  });

  testWidgets('typing digit by digit auto-submits at the 8th digit only', (
    tester,
  ) async {
    await openCodeScreen(tester);
    final field = find.byKey(RegisterCodeScreen.codeFieldKey);
    const code = '12345678';
    for (var n = 1; n < code.length; n++) {
      await tester.enterText(field, code.substring(0, n));
      await tester.pump();
    }
    expect(repo.verifyCalls, isEmpty);
    await tester.enterText(field, code);
    await tester.pump();
    expect(repo.verifyCalls, ['12345678']);
  });

  testWidgets('TOKEN_INVALID: error copy, no auto-resubmit of the rejected '
      'value, stronger copy after the 3rd failure', (tester) async {
    final l10n = await openCodeScreen(tester);
    repo.verifyFailures.addAll([_tokenInvalid, _tokenInvalid, _tokenInvalid]);
    final field = find.byKey(RegisterCodeScreen.codeFieldKey);

    await tester.enterText(field, '11112222');
    await tester.pumpAndSettle();
    expect(statusText(tester), l10n.errCodeInvalid);
    expect(
      find.text(l10n.errorTokenInvalid),
      findsNothing,
      reason: 'link copy',
    );

    // The same rejected value is not auto-submitted again…
    await tester.enterText(field, '11112222');
    await tester.pumpAndSettle();
    expect(repo.verifyCalls, ['11112222']);
    // …but the Verify button retries it.
    await tester.tap(find.byKey(RegisterCodeScreen.submitKey));
    await tester.pumpAndSettle();
    expect(repo.verifyCalls, ['11112222', '11112222']);
    expect(statusText(tester), l10n.errCodeInvalid);

    // Any edit re-arms auto-submit.
    await tester.enterText(field, '33334444');
    await tester.pumpAndSettle();
    expect(repo.verifyCalls, hasLength(3));
    expect(statusText(tester), l10n.errCodeInvalidRepeated);
  });

  testWidgets('a paste without exactly 8 digits fills and does not submit', (
    tester,
  ) async {
    final l10n = await openCodeScreen(tester);
    final field = find.byKey(RegisterCodeScreen.codeFieldKey);
    await tester.enterText(field, '123-45');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '12345');
    expect(statusText(tester), l10n.codePasteInvalid);

    await tester.enterText(field, '1234 5678 90');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '12345678');
    expect(statusText(tester), l10n.codePasteInvalid);
    expect(repo.verifyCalls, isEmpty);
  });

  testWidgets('RTL: in Arabic the cells still fill left → right', (
    tester,
  ) async {
    await openCodeScreen(tester, language: AppLanguage.ar);
    await tester.enterText(find.byKey(RegisterCodeScreen.codeFieldKey), '12');
    await tester.pump();

    expect(
      Directionality.of(tester.element(find.byType(RegisterCodeScreen))),
      TextDirection.rtl,
    );
    final first = find.byKey(const Key('code.cell.0'));
    final last = find.byKey(const Key('code.cell.7'));
    expect(Directionality.of(tester.element(first)), TextDirection.ltr);
    expect(tester.getCenter(first).dx, lessThan(tester.getCenter(last).dx));
    expect(
      find.descendant(of: first, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('text scale 2.0: a single plain field, no overflow at 360×640', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openCodeScreen(tester);

    expect(find.byKey(const Key('code.cell.0')), findsNothing);
    expect(find.byKey(RegisterCodeScreen.codeFieldKey), findsOneWidget);
    await tester.enterText(
      find.byKey(RegisterCodeScreen.codeFieldKey),
      '12345678',
    );
    await tester.pump();
    expect(repo.verifyCalls, ['12345678']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend: 60 s cooldown, then resend clears the field and '
      'restarts the cooldown', (tester) async {
    final l10n = await openCodeScreen(tester);
    final resend = find.byKey(RegisterCodeScreen.resendKey);
    expect(find.text(l10n.codeResendIn('1:00')), findsOneWidget);
    await tester.tap(resend);
    await tester.pump();
    expect(repo.resendCalls, 0, reason: 'disabled during cooldown');

    await tester.pump(const Duration(seconds: 30));
    expect(find.text(l10n.codeResendIn('0:30')), findsOneWidget);

    await tester.enterText(find.byKey(RegisterCodeScreen.codeFieldKey), '12');
    await tester.pump(const Duration(seconds: 31));
    expect(find.text(l10n.codeResend), findsOneWidget);
    await tester.tap(resend);
    await tester.pump();
    await tester.pump();

    expect(repo.resendCalls, 1);
    expect(find.text(l10n.codeResent), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(RegisterCodeScreen.codeFieldKey))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text(l10n.codeResendIn('1:00')), findsOneWidget);
  });

  testWidgets('after 30 minutes the status warns that the code may have '
      'expired', (tester) async {
    final l10n = await openCodeScreen(tester);
    expect(statusText(tester), l10n.codeExpiryHint);
    await tester.pump(const Duration(minutes: 30));
    expect(statusText(tester), l10n.codeMaybeExpired);
  });

  testWidgets('429 on verify: countdown banner, field and Verify disabled', (
    tester,
  ) async {
    final l10n = await openCodeScreen(tester);
    repo.verifyFailures.add(
      const ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'slow',
        statusCode: 429,
        retryAfter: Duration(seconds: 90),
      ),
    );
    await tester.enterText(
      find.byKey(RegisterCodeScreen.codeFieldKey),
      '12345678',
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.errorRateLimitedRetryIn('1:30')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(RegisterCodeScreen.codeFieldKey))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(RegisterCodeScreen.submitKey));
    await tester.pump();
    expect(repo.verifyCalls, hasLength(1));

    await tester.pump(const Duration(seconds: 90));
    expect(
      tester
          .widget<TextField>(find.byKey(RegisterCodeScreen.codeFieldKey))
          .enabled,
      isTrue,
    );
  });

  testWidgets('USERNAME_TAKEN race → back to Register with the username '
      'taken and the explanation banner', (tester) async {
    final l10n = await openCodeScreen(tester);
    repo.verifyFailures.add(
      const ServerFailure(
        code: ErrorCode.usernameTaken,
        rawCode: 'USERNAME_TAKEN',
        debugMessage: 'taken',
        statusCode: 409,
      ),
    );
    await tester.enterText(
      find.byKey(RegisterCodeScreen.codeFieldKey),
      '12345678',
    );
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(RegisterCodeScreen), findsNothing);
    expect(find.text(l10n.errUsernameTakenDuringVerify), findsOneWidget);
    expect(find.text(l10n.usernameTaken('layla_22')), findsOneWidget);
    expect(find.text('layla_22'), findsOneWidget, reason: 'form kept');
  });

  testWidgets('"Change email" returns to a filled Register form', (
    tester,
  ) async {
    await openCodeScreen(tester);
    await tester.tap(find.byKey(RegisterCodeScreen.changeEmailKey));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    // The form keeps what was typed (normalization happens on submit).
    expect(find.text(' Layla@Example.com '), findsOneWidget);
    expect(find.text('layla_22'), findsOneWidget);
  });

  testWidgets('"Log in" goes to Login with the email prefilled', (
    tester,
  ) async {
    await openCodeScreen(tester);
    await tester.ensureVisible(find.byKey(RegisterCodeScreen.logInKey));
    await tester.tap(find.byKey(RegisterCodeScreen.logInKey));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('layla@example.com'), findsOneWidget);
  });

  testWidgets('register sends the language displayed at submit time', (
    tester,
  ) async {
    await pumpKabsoApp(
      tester,
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        usernameDebounceProvider.overrideWithValue(Duration.zero),
      ],
    );
    await tester.pumpAndSettle();
    await openRegister(tester);
    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
    await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla_22');
    await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), 'pa55word!');
    // Switch to Arabic on the Register screen, then submit. (D64: the
    // switch sits on Kabi's stage, which scrolls with the form.)
    await tester.ensureVisible(find.byKey(AuthLanguageSwitch.switchKey));
    await tester.tap(find.byKey(AuthLanguageSwitch.switchKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
    await tester.tap(find.byKey(RegisterScreen.submitKey));
    await tester.pumpAndSettle();
    expect(repo.registerLocales, ['ar']);
  });

  test('normalizeCodeDigits', () {
    expect(normalizeCodeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    expect(normalizeCodeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    expect(normalizeCodeDigits('\u200E4821\u00A00937-'), '48210937');
    expect(normalizeCodeDigits('abc'), '');
  });

  testWidgets('the code route without a registration in progress bounces '
      'to Register', (tester) async {
    await pumpKabsoApp(
      tester,
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(KabsoApp)))
        .read(routerProvider)
        .go(AppRoutes.registerCode);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(RegisterCodeScreen), findsNothing);
  });

  group('v1.2.3 (SEC-025): 409 USERNAME_TAKEN for your own reservation', () {
    const usernameTaken = ServerFailure(
      code: ErrorCode.usernameTaken,
      rawCode: 'USERNAME_TAKEN',
      debugMessage: 'taken',
      statusCode: 409,
    );

    /// Code screen → "Change email" → submit the same email + username.
    Future<AppLocalizations> submitAgain(
      WidgetTester tester, {
      AppLanguage language = AppLanguage.en,
      String? email,
    }) async {
      final l10n = await openCodeScreen(tester, language: language);
      await tester.tap(find.byKey(RegisterCodeScreen.changeEmailKey));
      await tester.pumpAndSettle();
      if (email != null) {
        await tester.enterText(find.byKey(RegisterScreen.emailKey), email);
      }
      repo.registerFailure = usernameTaken;
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pumpAndSettle();
      return l10n;
    }

    testWidgets('offers "Resend code", which calls register/resend and '
        'returns to the code screen', (tester) async {
      final l10n = await submitAgain(tester);
      expect(find.byKey(RegisterScreen.usernameReservedKey), findsOneWidget);
      expect(find.text(l10n.registerUsernameReservedHint), findsOneWidget);
      expect(find.text(l10n.registerResendCode), findsOneWidget);
      expect(find.text(l10n.registerChooseAnotherUsername), findsOneWidget);

      await tester.ensureVisible(find.byKey(RegisterScreen.resendCodeKey));
      await tester.tap(find.byKey(RegisterScreen.resendCodeKey));
      await tester.pumpAndSettle();
      expect(repo.resendCalls, 1);
      expect(repo.registerCalls, 2, reason: 'no third register call');
      expect(find.byType(RegisterCodeScreen), findsOneWidget);
    });

    testWidgets('"Choose another username" clears and focuses the field', (
      tester,
    ) async {
      await submitAgain(tester);
      await tester.ensureVisible(find.byKey(RegisterScreen.chooseAnotherKey));
      await tester.tap(find.byKey(RegisterScreen.chooseAnotherKey));
      await tester.pumpAndSettle();
      expect(find.byKey(RegisterScreen.usernameReservedKey), findsNothing);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(RegisterScreen.usernameKey),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, isEmpty);
      expect(field.focusNode.hasFocus, isTrue);
      expect(repo.resendCalls, 0);
    });

    testWidgets('a failed resend shows the failure and keeps both options', (
      tester,
    ) async {
      await submitAgain(tester);
      repo.resendFailure = const ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'slow',
        statusCode: 429,
        retryAfter: Duration(seconds: 30),
      );
      await tester.ensureVisible(find.byKey(RegisterScreen.resendCodeKey));
      await tester.tap(find.byKey(RegisterScreen.resendCodeKey));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterCodeScreen), findsNothing);
      expect(find.byType(FailureBanner), findsOneWidget);
      expect(find.byKey(RegisterScreen.chooseAnotherKey), findsOneWidget);
    });

    testWidgets('Arabic copy', (tester) async {
      final l10n = await submitAgain(tester, language: AppLanguage.ar);
      expect(find.text(l10n.registerUsernameReservedHint), findsOneWidget);
      expect(find.text('أعد إرسال الرمز'), findsOneWidget);
      expect(find.text('اختر اسم مستخدم آخر'), findsOneWidget);
    });

    testWidgets('QA-013: another email also gets the hint; Resend uses the '
        'email in the form', (tester) async {
      final l10n = await submitAgain(tester, email: ' Other@Example.com ');
      expect(find.byKey(RegisterScreen.usernameReservedKey), findsOneWidget);
      expect(find.text(l10n.errorUsernameTaken), findsOneWidget);

      await tester.ensureVisible(find.byKey(RegisterScreen.resendCodeKey));
      await tester.tap(find.byKey(RegisterScreen.resendCodeKey));
      await tester.pumpAndSettle();
      expect(repo.resendEmails, ['other@example.com']);
      expect(find.byType(RegisterCodeScreen), findsOneWidget);
      expect(find.textContaining('other@example.com'), findsWidgets);
    });

    testWidgets('QA-013 repro: register → app killed (fresh state) → same '
        'email + username → 409 → hint → Resend → code screen, then verify '
        'signs in', (tester) async {
      // First run: register (202) opens the code screen.
      await openCodeScreen(tester);
      expect(repo.registerCalls, 1);

      // "Kill" the app: a brand-new widget tree and ProviderScope, so the
      // in-memory draft is gone.
      await tester.pumpWidget(const SizedBox.shrink());
      repo.registerFailure = usernameTaken;
      await pumpKabsoApp(
        tester,
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          usernameDebounceProvider.overrideWithValue(Duration.zero),
        ],
      );
      await tester.pumpAndSettle();
      final l10n = l10nFor(AppLanguage.en);
      // D64: signed out, the app opens on welcome; open register.
      await openRegister(tester);
      await tester.enterText(
        find.byKey(RegisterScreen.emailKey),
        'layla@example.com',
      );
      await tester.enterText(
        find.byKey(RegisterScreen.usernameKey),
        'layla_22',
      );
      await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'ليلى');
      await tester.enterText(
        find.byKey(RegisterScreen.passwordKey),
        'pa55word!',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
      await tester.tap(find.byKey(RegisterScreen.submitKey));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, 2);
      expect(find.byKey(RegisterScreen.usernameReservedKey), findsOneWidget);
      expect(find.text(l10n.registerUsernameReservedHint), findsOneWidget);
      expect(find.byKey(RegisterScreen.chooseAnotherKey), findsOneWidget);

      await tester.ensureVisible(find.byKey(RegisterScreen.resendCodeKey));
      await tester.tap(find.byKey(RegisterScreen.resendCodeKey));
      await tester.pumpAndSettle();
      expect(repo.resendEmails, ['layla@example.com']);
      expect(find.byType(RegisterCodeScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(RegisterCodeScreen.codeFieldKey),
        '12345678',
      );
      await tester.pumpAndSettle();
      expect(repo.verifyCalls, ['12345678']);
      expect(find.byType(RegisterCodeScreen), findsNothing);
    });
  });

  testWidgets('v1.2.3: attempts cap → 429 on verify blocks entry for the '
      'whole Retry-After (h:mm:ss), then allows it again', (tester) async {
    final l10n = await openCodeScreen(tester);
    // Wrong codes (422), then the per-email daily cap answers 429.
    repo.verifyFailures.addAll([
      _tokenInvalid,
      const ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'attempts exhausted',
        statusCode: 429,
        retryAfter: Duration(hours: 2, minutes: 5),
      ),
    ]);
    await tester.enterText(
      find.byKey(RegisterCodeScreen.codeFieldKey),
      '11111111',
    );
    await tester.pump();
    await tester.pump();
    expect(repo.verifyCalls, ['11111111']);
    await tester.enterText(
      find.byKey(RegisterCodeScreen.codeFieldKey),
      '22222222',
    );
    await tester.pump();
    await tester.pump();
    expect(repo.verifyCalls, ['11111111', '22222222']);
    expect(find.text(l10n.errorRateLimitedRetryIn('2:05:00')), findsOneWidget);
    TextField field() =>
        tester.widget<TextField>(find.byKey(RegisterCodeScreen.codeFieldKey));
    expect(field().enabled, isFalse);

    await tester.pump(const Duration(hours: 1));
    expect(find.text(l10n.errorRateLimitedRetryIn('1:05:00')), findsOneWidget);
    expect(field().enabled, isFalse);
    expect(repo.verifyCalls, hasLength(2));

    await tester.pump(const Duration(hours: 1, minutes: 5));
    expect(field().enabled, isTrue);
  });
}
