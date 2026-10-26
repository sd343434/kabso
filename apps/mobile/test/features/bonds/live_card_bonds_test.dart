// CP-018 on a person's card in a live and on profiles: the family and
// relationship boxes with real data, the medal showcase row (present only
// when chosen, at most six), sending a CP request, Arabic and English,
// 360×800 at text scale 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_boxes.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'bonds_harness.dart';

const _partner = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

PublicProfile _profile({
  bool self = false,
  bool family = true,
  bool cp = true,
  int medals = 6,
}) => apiProfile(isSelf: self).copyWith(
  family: family
      ? const ProfileFamily(
          id: 'fam-1',
          number: 48213907,
          name: 'Stars',
          level: 3,
          emblemUrl: null,
          role: FamilyRole.deputy,
        )
      : null,
  cp: cp
      ? ProfileCp(
          partner: _partner,
          since: DateTime.utc(2026, 10, 20),
          level: 2,
          levelName: 'Silver couple',
          points: 620,
        )
      : null,
  medals: ProfileMedals(
    owned: medals,
    total: 9,
    showcase: [
      for (final code in [
        'FIRST_LIVE',
        'FIRST_CP',
        'FIRST_FAMILY',
        'CHARM_10',
        'CHARM_50',
        'BULLET_FIRST',
      ].take(medals))
        ProfileMedal(
          code: code,
          name: code,
          iconKey: 'medal_${code.toLowerCase()}',
        ),
    ],
  ),
);

Future<BondFakes> _card(
  WidgetTester tester,
  PublicProfile profile, {
  AppLanguage language = AppLanguage.en,
  bool signedIn = true,
}) async {
  setViewport(tester, GoldenViewport.android);
  final fakes = await pumpBonds(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showHostSheet(context, 'host0'),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    language: language,
    signedIn: signedIn,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fakes;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);

  group("a person's card in a live", () {
    testWidgets('family and relationship boxes show the real data', (
      tester,
    ) async {
      await _card(tester, _profile());
      // The narrow box shows the family's name only.
      expect(find.text(KFormat.bidiIsolate('Stars')), findsOneWidget);
      expect(find.text(en.familyBoxValue('Stars', 3)), findsNothing);
      // Owner: the partner's picture, name and a heart.
      expect(find.text(KFormat.bidiIsolate('Omar')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LivePersonBoxes.boxKey(1)),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );
      // The gift wall still says it is coming.
      expect(find.text(en.liveUserSoon), findsOneWidget);
      expect(find.text(en.liveUserNone), findsNothing);
    });

    testWidgets('the family box opens the family page', (tester) async {
      final fakes = await _card(tester, _profile());
      final box = find.byKey(LivePersonBoxes.boxKey(0));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/families/fam-1']);
      expect(find.byKey(const Key('room.hostSheet')), findsNothing);
    });

    testWidgets("someone else's relationship box opens the partner", (
      tester,
    ) async {
      final fakes = await _card(tester, _profile());
      final box = find.byKey(LivePersonBoxes.boxKey(1));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/users/omar']);
    });

    testWidgets("CP-021: someone's couple opens its CP space by id", (
      tester,
    ) async {
      final profile = _profile();
      final fakes = await _card(
        tester,
        profile.copyWith(cp: profile.cp!.copyWith(id: 'couple-9')),
      );
      final box = find.byKey(LivePersonBoxes.boxKey(1));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/cp/couples/couple-9']);
    });

    testWidgets('CP-021: your own couple opens your CP space', (tester) async {
      final fakes = await _card(tester, _profile(self: true));
      final box = find.byKey(LivePersonBoxes.boxKey(1));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/cp/space']);
    });

    testWidgets('your own empty boxes open families and your CP page', (
      tester,
    ) async {
      var fakes = await _card(
        tester,
        _profile(self: true, family: false, cp: false),
      );
      expect(find.text(en.liveUserNone), findsNWidgets(2));
      var box = find.byKey(LivePersonBoxes.boxKey(0));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/families']);

      fakes = await _card(
        tester,
        _profile(self: true, family: false, cp: false),
      );
      box = find.byKey(LivePersonBoxes.boxKey(1));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/cp']);
    });

    testWidgets('no partner: send a CP request after the price', (
      tester,
    ) async {
      final fakes = await _card(tester, _profile(cp: false));
      final box = find.byKey(LivePersonBoxes.boxKey(1));
      expect(find.text(en.cpSendShort), findsOneWidget);
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(find.text(en.cpSendTitle('Sara')), findsOneWidget);
      expect(
        find.text(en.cpSendBody(en.bondsCoins(99), en.bondsDays(7))),
        findsOneWidget,
      );
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(
        fakes.cp.calls.where((c) => c.startsWith('send:host0:')),
        hasLength(1),
      );
      expect(find.text(en.cpSent('Sara')), findsOneWidget);
      // The card stays open.
      expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
    });

    testWidgets('a CP request without enough coins says so', (tester) async {
      final fakes = BondFakes();
      fakes.cp.failNext['send'] = bondFailure(ErrorCode.insufficientCoins);
      setViewport(tester, GoldenViewport.android);
      await pumpBonds(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHostSheet(context, 'host0'),
              child: const Text('open'),
            ),
          ),
        ),
        fakes: fakes,
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(_profile(cp: false)),
          ),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final box = find.byKey(LivePersonBoxes.boxKey(1));
      await _show(tester, box);
      await tester.tap(box);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(bondConfirmKey));
      await tester.pumpAndSettle();
      expect(find.text(en.cpSendNotEnough(en.bondsCoins(99))), findsOneWidget);
    });

    testWidgets('a guest sees no CP request offer', (tester) async {
      await _card(tester, _profile(cp: false), signedIn: false);
      expect(find.text(en.cpSendShort), findsNothing);
      expect(find.text(en.liveUserNone), findsOneWidget);
    });

    testWidgets('the medal row: six icons under the levels, in order', (
      tester,
    ) async {
      await _card(tester, _profile());
      expect(find.byKey(LiveCardKeys.medals), findsOneWidget);
      final codes = [
        'FIRST_LIVE',
        'FIRST_CP',
        'FIRST_FAMILY',
        'CHARM_10',
        'CHARM_50',
        'BULLET_FIRST',
      ];
      final xs = [
        for (final c in codes)
          tester.getCenter(find.byKey(MedalShowcaseRow.medalKey(c))).dx,
      ];
      // One row, left to right in English.
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
      final ys = {
        for (final c in codes)
          tester.getCenter(find.byKey(MedalShowcaseRow.medalKey(c))).dy,
      };
      expect(ys, hasLength(1));
      // Under the name and above the boxes.
      final row = tester.getRect(find.byKey(LiveCardKeys.medals));
      final boxes = tester.getRect(find.byKey(LivePersonBoxes.boxKey(0)));
      expect(row.bottom, lessThanOrEqualTo(boxes.top));
    });

    testWidgets('no chosen medals: no row at all, no placeholders', (
      tester,
    ) async {
      await _card(tester, _profile(medals: 0));
      expect(find.byKey(LiveCardKeys.medals), findsNothing);
      expect(find.byKey(MedalShowcaseRow.rowKey), findsNothing);
    });

    testWidgets('Arabic (RTL) and English at 360×800, text scale 2', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in AppLanguage.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _card(tester, _profile(), language: language);
        expect(tester.takeException(), isNull, reason: language.name);
        final first = tester.getCenter(
          find.byKey(MedalShowcaseRow.medalKey('FIRST_LIVE')),
        );
        final last = tester.getCenter(
          find.byKey(MedalShowcaseRow.medalKey('BULLET_FIRST')),
        );
        // The first medal at the reading start.
        expect(
          first.dx < last.dx,
          language == AppLanguage.en,
          reason: language.name,
        );
        await _show(tester, find.byKey(LivePersonBoxes.boxKey(2)));
        expect(tester.takeException(), isNull, reason: language.name);
      }
    });
  });

  group('profile', () {
    testWidgets("someone's profile: medal row and the three tiles", (
      tester,
    ) async {
      final fakes = await pumpBonds(
        tester,
        const PublicProfileScreen(username: 'host0'),
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(_profile(cp: false, medals: 2)),
          ),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
        ],
      );
      expect(find.byKey(MedalShowcaseRow.rowKey), findsOneWidget);
      expect(find.text(en.familyBoxValue('Stars', 3)), findsOneWidget);
      expect(find.text(en.cpSendShort), findsOneWidget);
      expect(find.text(en.medalsOwned(2, 9)), findsOneWidget);
      await tester.tap(find.byKey(ProfileBondsRow.medalsKey));
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/users/host0/medals']);
    });

    testWidgets('no showcase: no medal row', (tester) async {
      await pumpBonds(
        tester,
        const PublicProfileScreen(username: 'host0'),
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(_profile(medals: 0)),
          ),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
        ],
      );
      expect(find.byKey(MedalShowcaseRow.rowKey), findsNothing);
      expect(find.byKey(ProfileBondsRow.familyKey), findsOneWidget);
    });

    test('bond taps follow the profile', () {
      expect(familyTap(_profile()), BondTap.openFamily);
      expect(familyTap(_profile(family: false)), BondTap.none);
      expect(
        familyTap(_profile(self: true, family: false)),
        BondTap.browseFamilies,
      );
      expect(cpTap(_profile(), signedIn: true), BondTap.openPartner);
      expect(cpTap(_profile(cp: false), signedIn: true), BondTap.sendCp);
      expect(cpTap(_profile(cp: false), signedIn: false), BondTap.none);
      expect(cpTap(_profile(self: true), signedIn: true), BondTap.openCp);
    });
  });

  test('a CpCouple tier in the card text is the server name', () {
    // The box shows `levelName` as the server sent it (localized there).
    final cp = CpCouple(
      id: 'c',
      partner: _partner,
      since: DateTime.utc(2026),
      days: 1,
      points: 0,
      level: 1,
      levelName: 'ثنائي متحمّس',
      nextLevelName: 'ثنائي فضّي',
      pointsToNext: 520,
    );
    expect(en.cpBoxValue('Omar', cp.levelName), 'Omar · ثنائي متحمّس');
  });
}

/// Keys of the person card used here.
abstract final class LiveCardKeys {
  static const medals = Key('room.userCard.medals');
}
