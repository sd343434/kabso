// KL-018: auth-screen language switch (PHASE1_1_SCREENS §3.2).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());

  Future<void> pumpApp(WidgetTester tester) => pumpKabsoApp(
    tester,
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      usernameDebounceProvider.overrideWithValue(Duration.zero),
    ],
  );

  TextDirection dirOf(WidgetTester tester, Type screen) =>
      Directionality.of(tester.element(find.byType(screen)));

  testWidgets('Login: shows the other language, toggles instantly, keeps the '
      'typed fields and persists the choice', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    await openLogin(tester);
    final en = l10nFor(AppLanguage.en);
    final ar = l10nFor(AppLanguage.ar);

    final chip = find.byKey(AuthLanguageSwitch.switchKey);
    expect(
      find.descendant(of: chip, matching: find.text('العربية')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');

    // D65: the switch scrolls with the login page.
    await tapVisible(tester, chip);
    await tester.pumpAndSettle();

    expect(dirOf(tester, LoginScreen), TextDirection.rtl);
    expect(find.text(ar.loginTitle), findsWidgets);
    expect(find.text(en.loginSubtitle), findsNothing);
    expect(find.text('layla'), findsOneWidget, reason: 'field kept');
    expect(
      find.descendant(of: chip, matching: find.text('English')),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PreferenceKeys.languageCode), 'ar');

    // And back.
    // D65: the switch scrolls with the login page.
    await tapVisible(tester, chip);
    await tester.pumpAndSettle();
    expect(dirOf(tester, LoginScreen), TextDirection.ltr);
    expect(prefs.getString(PreferenceKeys.languageCode), 'en');
  });

  testWidgets('Register: visible field errors re-render in the new language', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    final en = l10nFor(AppLanguage.en);
    final ar = l10nFor(AppLanguage.ar);
    // D64: signed out, the app opens on welcome; open register.
    await openRegister(tester);

    await tester.enterText(find.byKey(RegisterScreen.emailKey), 'nope');
    await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
    await tester.tap(find.byKey(RegisterScreen.submitKey));
    await tester.pump();
    expect(find.text(en.validationEmailInvalid), findsOneWidget);

    await tester.ensureVisible(find.byKey(AuthLanguageSwitch.switchKey));
    await tester.tap(find.byKey(AuthLanguageSwitch.switchKey));
    await tester.pumpAndSettle();

    expect(dirOf(tester, RegisterScreen), TextDirection.rtl);
    expect(find.text(ar.validationEmailInvalid), findsOneWidget);
    expect(find.text('nope'), findsOneWidget, reason: 'field kept');
  });

  testWidgets('the switch is disabled while a submit is loading', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const LoginScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(_SlowLoginRepo()),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    await tester.enterText(find.byKey(LoginScreen.identifierKey), 'layla');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
    await tapVisible(tester, find.byKey(LoginScreen.submitKey));
    await tester.pump();

    final chip = tester.widget<ActionChip>(
      find.byKey(AuthLanguageSwitch.switchKey),
    );
    expect(chip.onPressed, isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}

class _SlowLoginRepo extends FakeAuthRepository {
  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    throw const NetworkFailure.offline();
  }
}
