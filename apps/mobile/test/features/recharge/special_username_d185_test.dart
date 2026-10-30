// D185 (owner, same day; CONVENTIONS §10.48.1): the special username
// «يوزر مميز». An active recharge agent's username is their code (`@coin0007`)
// while the frame's plate shows the display name («سارة»); the person's own
// base username is shown only to them, in Settings and on the change screen,
// and the username is locked. Arabic RTL and English LTR. Fakes only.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/special_username.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/premium/presentation/change_username_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_premium_repository.dart';
import '../../helpers/fake_recharge_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../premium/premium_harness.dart';

const _base = 'sara_2026';

final _special = SpecialUsername(
  username: 'coin0007',
  baseUsername: _base,
  source: SpecialUsernameSource.rechargeAgent,
  grantedAt: DateTime.utc(2026, 10, 30),
  locked: true,
);

User _agent(AppLanguage language) => User(
  id: '0192f1c2-0000-7000-8000-000000000007',
  email: 'sara@example.com',
  emailVerified: true,
  username: 'coin0007',
  displayName: language == AppLanguage.ar ? 'سارة' : 'Sara',
  locale: language.name,
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
  specialUsername: _special,
);

void main() {
  test('Me.specialUsername reads the wire object (and only a valid one)', () {
    final me = MeDto.fromJson({
      'id': '0192f1c2-0000-7000-8000-000000000007',
      'email': 'sara@example.com',
      'emailVerified': true,
      'username': 'coin0007',
      'displayName': 'Sara',
      'locale': 'en',
      'role': 'USER',
      'isPrivate': false,
      'createdAt': '2026-10-01T00:00:00.000Z',
      'specialUsername': {
        'username': 'coin0007',
        'baseUsername': _base,
        'source': 'RECHARGE_AGENT',
        'grantedAt': '2026-10-30T00:00:00.000Z',
        'expiresAt': null,
        'locked': true,
      },
    }).toEntity();
    expect(me.specialUsername, _special);
    expect(me.specialUsername!.expiresAt, isNull);
    expect(SpecialUsername.fromJson({'username': 'x'}), isNull);
    expect(
      SpecialUsernameSource.fromWire('SOMETHING_NEW'),
      SpecialUsernameSource.other,
    );
    // Absent: no field written back either.
    final plain = MeDto.fromJson({
      'id': 'u',
      'email': 'a@b.c',
      'emailVerified': true,
      'username': 'sara_2026',
      'displayName': 'Sara',
      'locale': 'en',
      'role': 'USER',
      'isPrivate': false,
      'createdAt': '2026-10-01T00:00:00.000Z',
    });
    expect(plain.specialUsername, isNull);
    expect(plain.toJson().containsKey('specialUsername'), isFalse);
  });

  for (final language in AppLanguage.values) {
    final l10n = l10nFor(language);
    final user = _agent(language);

    testWidgets('own profile: @coin0007 in the bar, the display name on the '
        'plate, never the base username (${language.name})', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const ProfileScreen(),
        language: language,
        overrides: [
          currentUserProvider.overrideWithValue(user),
          meProvider.overrideWith((ref) => user),
          profileStatsProvider.overrideWith(
            (ref, username) => apiProfile(isSelf: true),
          ),
          profileGridProvider.overrideWith(
            (ref, _) => const FeedUnavailable<ProfileGridItem>(),
          ),
        ],
        rechargeRepository: FakeRechargeRepository(mine: fixtureActive()),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('profile.title'))).data,
        l10n.profileUsername('coin0007'),
      );
      expect(find.byKey(ProfileHeaderView.agentFrameKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(RechargeAgentFrame.plateKey)).data,
        user.displayName,
      );
      expect(find.textContaining(_base), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings › Username: the locked special username and the '
        'base username, for the person only (${language.name})', (
      tester,
    ) async {
      await pumpPremium(
        tester,
        const SettingsScreen(),
        premium: FakePremiumRepository(user: user),
        language: language,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await testPrefs(language: language.name),
          ),
          sessionControllerProvider.overrideWith(() => FixedSession(user)),
        ],
      );
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.usernameKey),
        200,
      );
      final row = find.byKey(SettingsScreen.usernameKey);
      expect(
        find.descendant(
          of: row,
          matching: find.text(KHandle.isolated('coin0007')),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(SettingsScreen.baseUsernameKey)).data,
        l10n.settingsBaseUsername(KHandle.isolated(_base)),
      );
      expect(find.byKey(SettingsScreen.usernameLockedKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the change screen says the username is locked and offers no '
        'field (${language.name})', (tester) async {
      await pumpPremium(
        tester,
        const ChangeUsernameScreen(),
        premium: FakePremiumRepository(user: user),
        language: language,
        overrides: [
          sessionControllerProvider.overrideWith(() => FixedSession(user)),
        ],
      );
      expect(find.byKey(ChangeUsernameScreen.specialLockedKey), findsOneWidget);
      expect(
        find.textContaining(
          l10n.changeUsernameSpecialLocked(
            KHandle.isolated('coin0007'),
            KHandle.isolated(_base),
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(ChangeUsernameScreen.fieldKey), findsNothing);
      expect(find.byKey(ChangeUsernameScreen.saveKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
