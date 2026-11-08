// D302 (owner: «المشرفين يدخلون من خلال وضع الايدي المميز والباسورد»; contract
// v1.84-live, CONVENTIONS §10.96.12): the login field says it also takes the
// staff ID, and a staff ID typed there goes to `login` as typed.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  Future<void> pump(WidgetTester tester, AppLanguage language) => pumpScreen(
    tester,
    const LoginScreen(),
    language: language,
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );

  test('the label names the email, the username and the staff ID', () {
    expect(
      l10nFor(AppLanguage.ar).loginIdentifierLabel,
      'البريد أو اسم المستخدم أو ايدي الموظف',
    );
    expect(
      l10nFor(AppLanguage.en).loginIdentifierLabel,
      'Email, username or staff ID',
    );
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name}: the field shows the label', (tester) async {
      await pump(tester, language);
      final label = l10nFor(language).loginIdentifierLabel;
      expect(
        find.descendant(
          of: find.byKey(LoginScreen.identifierKey),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a staff ID is sent as typed («Kabso01», «@kabso1»)', (
    tester,
  ) async {
    await pump(tester, AppLanguage.en);
    await tester.enterText(find.byKey(LoginScreen.identifierKey), 'Kabso01');
    await tester.enterText(find.byKey(LoginScreen.passwordKey), 'secret');
    await tapVisible(tester, find.byKey(LoginScreen.submitKey));
    await tester.pump();
    await tester.pump();
    expect(repo.loginIdentifiers, ['Kabso01']);
  });
}
