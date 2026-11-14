// v1.108-social (D343, CONVENTIONS §10.142; owner): the sign-up page without
// Kabi, with one optional field «رمز الدعوة أو رمز المشرف» collapsed under
// «لديك رمز دعوة؟» unless the invite link pre-filled it (Play install
// referrer); «لصق الرمز» reads the clipboard on that tap only; the live check
// says INVITE / SUPERVISOR / not found; the 400 at sign-up lands on the field;
// the referrer's code is read once per install and forgotten once used.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/data/signup_code.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/features/auth/presentation/widgets/kabi_mascot.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// The server's answers: [valid] codes by kind; anything else is not found.
class FakeSignupCodeRepository implements SignupCodeRepository {
  new({this.valid = const {}, this.fail = false});

  final Map<String, SignupCodeKind> valid;
  final bool fail;
  final List<String> checks = [];

  @override
  Future<SignupCodeCheck> check(String code) async {
    checks.add(code);
    if (fail) throw StateError('offline');
    final key = valid.keys.where(
      (k) => k.toLowerCase() == code.trim().toLowerCase(),
    );
    if (key.isEmpty) return const SignupCodeNotFound();
    return SignupCodeValid(valid[key.first]!, key.first);
  }
}

class FakeInstallReferrer implements InstallReferrerSource {
  new(this.referrer);

  final String? referrer;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    return referrer;
  }
}

const Map<String, SignupCodeKind> d343Codes = {
  'K7QM4P2X': SignupCodeKind.invite,
  'Kabso07': SignupCodeKind.supervisor,
};

/// The sign-up screen with the D343 fakes ([referrer]: the Play referrer).
Future<FakeInstallReferrer> pumpSignup(
  WidgetTester tester, {
  FakeAuthRepository? repo,
  String? referrer,
  FakeSignupCodeRepository? codes,
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.dark,
}) async {
  final source = FakeInstallReferrer(referrer);
  await pumpScreen(
    tester,
    const RegisterScreen(),
    language: language,
    brightness: brightness,
    overrides: [
      authRepositoryProvider.overrideWithValue(repo ?? FakeAuthRepository()),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      usernameDebounceProvider.overrideWithValue(
        const Duration(milliseconds: 300),
      ),
      signupCodeRepositoryProvider.overrideWithValue(
        codes ?? FakeSignupCodeRepository(valid: d343Codes),
      ),
      signupCodeDebounceProvider.overrideWithValue(
        const Duration(milliseconds: 300),
      ),
      installReferrerSourceProvider.overrideWithValue(source),
    ],
  );
  await tester.pumpAndSettle();
  return source;
}

void main() {
  final l10n = l10nFor(AppLanguage.en);

  group('pure rules', () {
    test('extractSignupCode reads codes, staff IDs and invite links', () {
      expect(extractSignupCode(' k7qm-4p2x '), 'K7QM4P2X');
      expect(extractSignupCode('@Kabso07'), 'Kabso07');
      expect(extractSignupCode('https://kabsolive.com/i/Kabso07'), 'Kabso07');
      expect(
        extractSignupCode('Join me: https://kabsolive.com/i/K7QM4P2X/'),
        'K7QM4P2X',
      );
      expect(extractSignupCode('hello there'), isNull);
      expect(extractSignupCode(''), isNull);
    });

    test(
      'the Play referrer carries kabso_code=<code>; organic installs none',
      () {
        expect(signupCodeFromReferrer('kabso_code=Kabso07'), 'Kabso07');
        expect(
          signupCodeFromReferrer('utm_source=site&kabso_code=k7qm4p2x'),
          'K7QM4P2X',
        );
        expect(
          signupCodeFromReferrer('utm_source=google-play&utm_medium=organic'),
          isNull,
        );
        expect(signupCodeFromReferrer(null), isNull);
      },
    );
  });

  testWidgets('no Kabi, no hero; the code field is collapsed under '
      '«Have an invite code?» and opens on tap', (tester) async {
    await pumpSignup(tester);
    expect(find.byType(AuthHero), findsNothing);
    expect(find.byType(KabiMascot), findsNothing);
    expect(find.byKey(RegisterScreen.referralKey), findsNothing);
    expect(find.text(l10n.signupCodeToggle), findsOneWidget);

    await tapVisible(tester, find.byKey(RegisterScreen.referralToggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(RegisterScreen.referralKey), findsOneWidget);
    expect(find.text(l10n.signupCodeLabel), findsOneWidget);
    expect(find.byKey(RegisterScreen.referralPasteKey), findsOneWidget);
  });

  testWidgets('the live check: supervisor, invite, not found', (tester) async {
    final codes = FakeSignupCodeRepository(valid: d343Codes);
    await pumpSignup(tester, codes: codes);
    await tapVisible(tester, find.byKey(RegisterScreen.referralToggleKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(RegisterScreen.referralKey), 'kabso07');
    await tester.pump();
    expect(find.text(l10n.signupCodeChecking), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signupCodeSupervisorOk('Kabso07')), findsOneWidget);

    await tester.enterText(find.byKey(RegisterScreen.referralKey), 'K7QM4P2X');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signupCodeInviteOk), findsOneWidget);

    await tester.enterText(find.byKey(RegisterScreen.referralKey), 'ZZZZZZZZ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signupCodeNotFound), findsOneWidget);
    // Debounced: one check per pause, not per keystroke.
    expect(codes.checks, ['kabso07', 'K7QM4P2X', 'ZZZZZZZZ']);
  });

  testWidgets('offline check says nothing (the sign-up decides)', (
    tester,
  ) async {
    await pumpSignup(tester, codes: FakeSignupCodeRepository(fail: true));
    await tapVisible(tester, find.byKey(RegisterScreen.referralToggleKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RegisterScreen.referralKey), 'Kabso07');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(RegisterScreen.referralStatusKey), findsNothing);
  });

  testWidgets('pre-filled from the invite link: shown open with the note; '
      'remove clears it and it is not offered again', (tester) async {
    final source = await pumpSignup(tester, referrer: 'kabso_code=Kabso07');
    expect(source.reads, 1);
    final field = tester.widget<TextFormField>(
      find.byKey(RegisterScreen.referralKey),
    );
    expect(field.controller!.text, 'Kabso07');
    expect(find.byKey(RegisterScreen.referralFromLinkKey), findsOneWidget);
    expect(find.text(l10n.signupCodeSupervisorOk('Kabso07')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SignupCodePrefs.referrerRead), isTrue);
    expect(prefs.getString(SignupCodePrefs.referrerCode), 'Kabso07');

    await tapVisible(tester, find.byKey(RegisterScreen.referralRemoveKey));
    await tester.pumpAndSettle();
    expect(find.byKey(RegisterScreen.referralFromLinkKey), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(RegisterScreen.referralKey))
          .controller!
          .text,
      isEmpty,
    );
    expect(prefs.getString(SignupCodePrefs.referrerCode), isNull);
    expect(prefs.getBool(SignupCodePrefs.referrerRead), isTrue);
  });

  testWidgets('the referrer is read once per install', (tester) async {
    SharedPreferences.setMockInitialValues({
      SignupCodePrefs.referrerRead: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final source = FakeInstallReferrer('kabso_code=Kabso07');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        installReferrerSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(pendingSignupCodeProvider.future), isNull);
    expect(source.reads, 0);
  });

  testWidgets('«Paste code» reads the clipboard only when tapped', (
    tester,
  ) async {
    var reads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          reads++;
          return {'text': 'https://kabsolive.com/i/k7qm4p2x'};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpSignup(tester);
    await tapVisible(tester, find.byKey(RegisterScreen.referralToggleKey));
    await tester.pumpAndSettle();
    expect(reads, 0, reason: 'no silent clipboard read');
    await tapVisible(tester, find.byKey(RegisterScreen.referralPasteKey));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(
      tester
          .widget<TextFormField>(find.byKey(RegisterScreen.referralKey))
          .controller!
          .text,
      'K7QM4P2X',
    );
    expect(find.text(l10n.signupCodeInviteOk), findsOneWidget);
  });

  testWidgets('the 400 not_found at sign-up shows on the code field, and the '
      'code is sent with the sign-up', (tester) async {
    final repo = FakeAuthRepository()
      ..registerFailure = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'not found',
        details: [FieldIssue(field: 'referralCode', issue: 'not_found')],
      );
    await pumpSignup(
      tester,
      repo: repo,
      codes: FakeSignupCodeRepository(fail: true),
    );
    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
    await tester.enterText(find.byKey(RegisterScreen.usernameKey), 'layla_22');
    await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
    await tester.enterText(find.byKey(RegisterScreen.passwordKey), 'pa55word!');
    await chooseGender(tester);
    await tapVisible(tester, find.byKey(RegisterScreen.referralToggleKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RegisterScreen.referralKey), 'Kabso77');
    await tester.pump(const Duration(milliseconds: 350));
    await tapVisible(tester, find.byKey(RegisterScreen.submitKey));
    await tester.pump();
    await tester.pump();
    expect(repo.registerReferralCodes, ['Kabso77']);
    expect(find.text(l10n.signupCodeNotFound), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360×800, text scale 1.3, ${language.name}: no overflow, '
        'the code field fits', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800) * 3
        ..devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSignup(
        tester,
        referrer: 'kabso_code=Kabso07',
        language: language,
        brightness: Brightness.light,
      );
      await tester.ensureVisible(find.byKey(RegisterScreen.referralKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(RegisterScreen.referralFromLinkKey), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(RegisterScreen.referralRemoveKey)),
        matchesSemantics(
          tooltip: l10nFor(language).signupCodeRemove,
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    });
  }
}
