// CP-019 on a person's card in a live: the profile card they wear
// (`PublicProfile.profileCard`) on the card's top edge; nothing when they
// wear none or the app does not know the code; an explicit header wins;
// Arabic and English at 360×800, text scale 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/golden.dart';
import '../bonds/bonds_harness.dart';

const _headerKey = Key('room.userCard.header');

PublicProfile _profile(String? code) => apiProfile().copyWith(
  profileCard: code == null
      ? null
      : ProfileCard(code: code, assetKey: 'header_$code'),
);

Future<void> _card(
  WidgetTester tester,
  PublicProfile profile, {
  AppLanguage language = AppLanguage.en,
  KabsoProfileHeader? header,
}) async {
  setViewport(tester, GoldenViewport.android);
  await pumpBonds(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showHostSheet(context, 'host0', header: header),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    language: language,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

KabsoProfileHeader _shown(WidgetTester tester) =>
    tester.widget<KabsoProfileHeaderArt>(find.byKey(_headerKey)).header;

void main() {
  testWidgets('the worn profile card sits on the card edge', (tester) async {
    for (final h in KabsoProfileHeader.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _card(tester, _profile(h.code));
      expect(find.byKey(_headerKey), findsOneWidget, reason: h.code);
      expect(_shown(tester), h);
      // Its bar's line lies on the card's top edge, above the sheet's top.
      final sheet = tester.getRect(find.byKey(const Key('room.hostSheet')));
      final art = tester.getRect(find.byKey(_headerKey));
      expect(art.width, sheet.width);
      expect(art.top, greaterThanOrEqualTo(sheet.top - 0.01));
    }
  });

  testWidgets('no profile card: no header, the plain edge', (tester) async {
    await _card(tester, _profile(null));
    expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
    expect(find.byKey(_headerKey), findsNothing);
    expect(find.byType(KabsoProfileHeaderArt), findsNothing);
  });

  testWidgets('an unknown code: no header, no crash', (tester) async {
    await _card(tester, _profile('neon_dragon'));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
    expect(find.byKey(_headerKey), findsNothing);
  });

  testWidgets('an explicit header wins over the profile', (tester) async {
    await _card(
      tester,
      _profile('emerald_wings'),
      header: KabsoProfileHeader.kabiRoyal,
    );
    expect(_shown(tester), KabsoProfileHeader.kabiRoyal);
  });

  testWidgets('nothing is drawn before the profile loads', (tester) async {
    setViewport(tester, GoldenViewport.android);
    final repo = FakeProfileRepository(_profile('golden_stags'));
    await pumpBonds(
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
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.byKey(_headerKey), findsNothing);
    await tester.pumpAndSettle();
    expect(_shown(tester), KabsoProfileHeader.goldenStags);
  });

  testWidgets('Arabic (RTL) and English at 360×800, text scale 2', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final language in AppLanguage.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _card(tester, _profile('emerald_wings'), language: language);
      expect(tester.takeException(), isNull, reason: language.name);
      expect(_shown(tester), KabsoProfileHeader.emeraldWings);
    }
  });
}
