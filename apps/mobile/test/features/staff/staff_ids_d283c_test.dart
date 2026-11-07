// D283c (owner: «ايدي للمشرفين والادارة بحيث ايدي الموظفين يبدأ Kabso01»;
// contract v1.73-live, CONVENTIONS §10.96.12): a staff account's official
// staff ID «Kabso01» replaces the @username wherever it is shown — the
// profile header and bar «ID: Kabso01», the person card's ID line, the Me
// tab, lists and search rows (KHandle) — while the username stays the
// person's (login, links, the profile route).
//
// D299e (owner: «كلها لـ @»): the profile's title (the bar) shows the staff
// ID in the @username's form, «@Kabso01»; the Me tab keeps «ID: Kabso01».
//
// The goldens are in test/goldens/staff_ids_d283c_golden_test.dart.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../goldens/live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show pumpOther;
import 'staff_d283_test.dart';

/// A limited staff member's profile with its staff ID.
PublicProfile staffIdProfile({required bool ar}) =>
    staffProfile(ar: ar).copyWith(staffId: 'Kabso01');

/// The primary OWNER (a normal account that hosts lives) with its plain
/// staff ID «Kabso» (D283d): the person card over a live.
PublicProfile ownerCardProfile({required bool ar}) =>
    personCardProfile(ar: ar).copyWith(kabsoTeam: true, staffId: 'Kabso');

void main() {
  group('KHandle', () {
    test('a staff ID replaces the @username, bare, even over a premium', () {
      final en = l10nFor(AppLanguage.en);
      expect(KHandle.plain('sara_2026'), '@sara_2026');
      expect(KHandle.plain('sara_2026', staffId: 'Kabso01'), 'Kabso01');
      expect(
        KHandle.plain(
          '7777',
          premiumTier: PremiumTier.gold,
          staffId: 'Kabso07',
        ),
        'Kabso07',
      );
      expect(
        KHandle.isolated('sara_2026', staffId: 'Kabso100'),
        '\u2066Kabso100\u2069',
      );
      expect(
        KHandle.text(en, 'sara_2026', staffId: 'Kabso02'),
        '\u2066Kabso02\u2069',
      );
      expect(KHandle.text(en, 'sara_2026'), en.profileUsername('sara_2026'));
      expect(KHandle.id('sara_2026', staffId: 'Kabso02'), 'Kabso02');
      expect(KHandle.id('sara_2026'), 'sara_2026');
    });
  });

  group('the wire', () {
    test('UserSummary, PublicProfile and Me read `staffId` (absent: null)', () {
      final u = UserSummary.fromJson({
        'id': '0192f1c2-0000-7000-8000-000000000001',
        'username': 'sara.staff',
        'displayName': 'Sara',
        'avatarUrl': null,
        'staffId': 'Kabso01',
      });
      expect(u.staffId, 'Kabso01');
      expect(u.username, 'sara.staff');
      expect(u.toJson()['staffId'], 'Kabso01');
      final plain = UserSummary.fromJson({
        'id': '0192f1c2-0000-7000-8000-000000000002',
        'username': 'ali',
        'displayName': 'Ali',
        'avatarUrl': null,
      });
      expect(plain.staffId, isNull);
      expect(plain.toJson().containsKey('staffId'), isFalse);

      // A round trip through JSON text (nested parts serialised too).
      final json =
          jsonDecode(jsonEncode(apiProfile().toJson())) as Map<String, dynamic>
            ..['staffId'] = 'Kabso03';
      expect(PublicProfile.fromJson(json).staffId, 'Kabso03');

      final me = MeDto.fromJson({
        'id': '0192f1c2-0000-7000-8000-000000000003',
        'email': 'owner@kabso.test',
        'emailVerified': true,
        'username': 'the.owner',
        'displayName': 'Owner',
        'locale': 'ar',
        'role': 'ADMIN',
        'isPrivate': false,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'staffId': 'Kabso',
      }).toEntity();
      expect(me.staffId, 'Kabso');
      expect(me.username, 'the.owner');
    });
  });

  for (final language in AppLanguage.values) {
    final name = language.name;
    final ar = language == AppLanguage.ar;

    testWidgets('a staff profile shows «@Kabso01» (D299e), not the '
        '@username ($name)', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(tester, staffIdProfile(ar: ar), language: language);
      });
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.byKey(ProfileCoverHeader.staffIdKey)).data,
        l10nFor(language).profileUsername('Kabso01'),
      );
      // Read as the official staff ID (D283c's hint).
      expect(
        tester.getSemantics(find.byKey(ProfileCoverHeader.staffIdKey)).hint,
        l10nFor(language).profileStaffIdHint,
      );
      expect(
        find.text(l10nFor(language).profileUsername('host0')),
        findsNothing,
      );
      // D283d: the region line only in the official bio card's header.
      expect(staffBioTitle(tester), isNotEmpty);
      expect(
        find.text(ar ? 'مشرف للوطن العربي' : 'Moderator — Arab World'),
        findsNothing,
      );
    });

    testWidgets('the staff-only Me tab shows «ID: Kabso01» under the name '
        '($name)', (tester) async {
      await pumpStaffHub(tester, language: language, staffId: 'Kabso01');
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.byKey(MeHubScreen.staffIdKey)).data,
        'ID: Kabso01',
      );
    });

    testWidgets('the person card shows the primary OWNER «ID: Kabso» '
        '($name)', (tester) async {
      await pumpPersonCardRoom(
        tester,
        language: language,
        profile: ownerCardProfile(ar: ar),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LivePersonSheet), findsOneWidget);
      // The card's ID line (the room's own host pill is not the card).
      bool idLine(Widget w, String v) =>
          w is Text && (w.data ?? '').startsWith('ID:') && w.data!.contains(v);
      expect(find.byWidgetPredicate((w) => idLine(w, 'Kabso')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => idLine(w, 'host0')), findsNothing);
    });
  }

  testWidgets('a normal profile keeps its @username (no staff ID line)', (
    tester,
  ) async {
    await pumpOther(tester, apiProfile(), language: AppLanguage.en);
    expect(find.byKey(ProfileCoverHeader.staffIdKey), findsNothing);
    expect(
      find.text(l10nFor(AppLanguage.en).profileUsername('host0')),
      findsWidgets,
    );
  });

  testWidgets('a Me tab without a staff ID shows no ID line', (tester) async {
    await pumpStaffHub(tester, language: AppLanguage.en);
    expect(find.byKey(MeHubScreen.staffIdKey), findsNothing);
  });
}
