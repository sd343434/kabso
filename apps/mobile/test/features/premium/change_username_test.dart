// D146: the username change — the regular rule with clear messages (6+
// characters, letters and digits, a–z 0–9 _), a premium-shaped name offers
// the store instead, the change goes through PUT /me/username, and while a
// premium username is active the screen says to give it back first.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/features/premium/presentation/change_username_screen.dart';

import '../../helpers/fake_premium_repository.dart';
import '../../helpers/pump_app.dart' show l10nFor;
import 'premium_harness.dart';

final _user = User(
  id: '0192f1c2-0000-7000-8000-000000000001',
  email: 'sara@example.com',
  emailVerified: true,
  username: 'sara_2026',
  displayName: 'Sara',
  locale: 'en',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
);

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('AuthValidators.usernameIssue (D146 rule)', () {
    test('premium shapes, length, characters, letters and digits', () {
      expect(AuthValidators.usernameIssue(''), UsernameIssue.required);
      expect(AuthValidators.usernameIssue('777'), UsernameIssue.premium);
      expect(AuthValidators.usernameIssue('abcdef'), UsernameIssue.premium);
      expect(AuthValidators.usernameIssue('123456'), UsernameIssue.premium);
      expect(AuthValidators.usernameIssue('aaa777'), UsernameIssue.premium);
      expect(AuthValidators.usernameIssue('ab_1'), UsernameIssue.tooShort);
      expect(
        AuthValidators.usernameIssue('abc_def'),
        UsernameIssue.lettersAndDigits,
      );
      expect(AuthValidators.usernameIssue('abc.12'), UsernameIssue.badChars);
      expect(AuthValidators.usernameIssue('_abc12'), UsernameIssue.badEdges);
      expect(
        AuthValidators.usernameIssue('a1${'b' * 29}'),
        UsernameIssue.tooLong,
      );
      expect(AuthValidators.usernameIssue('sara_2026'), isNull);
      expect(AuthValidators.usernameIssue('abc123'), isNull);
    });

    test('server issues map to the same messages', () {
      expect(AuthValidators.issueFromWire('premium'), UsernameIssue.premium);
      expect(
        AuthValidators.issueFromWire('letters_and_digits'),
        UsernameIssue.lettersAndDigits,
      );
      expect(AuthValidators.issueFromWire('too_short'), UsernameIssue.tooShort);
      expect(AuthValidators.issueFromWire('nope'), isNull);
    });
  });

  testWidgets('rule messages as typed; premium names offer the store', (
    tester,
  ) async {
    final premium = FakePremiumRepository(user: _user);
    final pushed = await pumpPremium(
      tester,
      const ChangeUsernameScreen(),
      premium: premium,
      overrides: [
        sessionControllerProvider.overrideWith(() => FixedSession(_user)),
      ],
    );
    expect(find.text(en.changeUsernameTitle), findsOneWidget);
    await tester.enterText(find.byKey(ChangeUsernameScreen.fieldKey), 'ab_1');
    await tester.pump();
    expect(find.text(en.usernameTooShort), findsOneWidget);
    await tester.enterText(
      find.byKey(ChangeUsernameScreen.fieldKey),
      'abc_def',
    );
    await tester.pump();
    expect(find.text(en.usernameLettersAndDigits), findsOneWidget);
    await tester.enterText(find.byKey(ChangeUsernameScreen.fieldKey), '7777');
    await tester.pump();
    expect(find.text(en.usernamePremium), findsOneWidget);
    expect(find.byKey(ChangeUsernameScreen.premiumHintKey), findsOneWidget);
    await tester.tap(find.byKey(ChangeUsernameScreen.premiumHintKey));
    await tester.pumpAndSettle();
    expect(pushed.single, '/premium?q=7777');
  });

  testWidgets('a premium username active: give it back first (Arabic)', (
    tester,
  ) async {
    final premium = FakePremiumRepository(
      user: _user.copyWith(username: '7777', premiumTier: PremiumTier.gold),
      mineValue: MyPremiumUsername(
        username: '7777',
        tier: PremiumTier.gold,
        grace: false,
        granted: false,
        startedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
        graceUntil: null,
        regularUsername: 'sara_2026',
        renewPriceCoins: 1000,
        canRenew: true,
      ),
    );
    await pumpPremium(
      tester,
      const ChangeUsernameScreen(),
      premium: premium,
      language: AppLanguage.ar,
      overrides: [
        sessionControllerProvider.overrideWith(
          () => FixedSession(premium.user!),
        ),
      ],
    );
    expect(find.byKey(ChangeUsernameScreen.premiumActiveKey), findsOneWidget);
    expect(
      find.text(ar.changeUsernamePremiumActive('7777', 'sara_2026')),
      findsOneWidget,
    );
    expect(find.byKey(ChangeUsernameScreen.fieldKey), findsNothing);
  });

  testWidgets('a server 409 USERNAME_TAKEN shows under the field', (
    tester,
  ) async {
    final premium = FakePremiumRepository(user: _user)
      ..failNext['changeUsername'] = premiumFailure(ErrorCode.usernameTaken);
    await pumpPremium(
      tester,
      const ChangeUsernameScreen(),
      premium: premium,
      overrides: [
        sessionControllerProvider.overrideWith(() => FixedSession(_user)),
      ],
    );
    await tester.enterText(
      find.byKey(ChangeUsernameScreen.fieldKey),
      'nora_77',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChangeUsernameScreen.saveKey));
    await tester.pumpAndSettle();
    expect(premium.calls, contains('changeUsername:nora_77'));
    expect(find.text(en.usernameTaken('nora_77')), findsWidgets);
  });
}
