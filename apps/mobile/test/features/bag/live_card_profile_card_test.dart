// CP-019 × D383 (owner 2026-11-12: «الغاء فكرة صندوق او إطار بطاقة الملف
// التعريفية»): the bag's profile card (`PublicProfile.profileCard`, the
// header ornament that sat on the person card's top edge) is no longer drawn
// on a person's card in a live — worn, unknown or none, the card is the same
// plain card. The bag keeps the item (owned, worn) — only the card stops
// drawing it. Arabic and English at 360×800, text scale 2.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
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
}) async {
  setViewport(tester, GoldenViewport.android);
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

void main() {
  testWidgets('D383: a worn profile card is not drawn on the card edge', (
    tester,
  ) async {
    for (final h in KabsoProfileHeader.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _card(tester, _profile(h.code));
      expect(find.byKey(LivePersonSheet.sheetKey), findsOneWidget);
      expect(find.byKey(_headerKey), findsNothing, reason: h.code);
      expect(find.byType(KabsoProfileHeaderArt), findsNothing, reason: h.code);
      // The picture's clean ring on the plain edge, as without one.
      expect(find.byKey(LivePersonSheet.ringKey), findsOneWidget);
    }
  });

  testWidgets('the same card with none, or an unknown code', (tester) async {
    Rect sheetOf() => tester.getRect(find.byKey(LivePersonSheet.ringKey));
    await _card(tester, _profile(null));
    final plain = sheetOf();
    await tester.pumpWidget(const SizedBox.shrink());
    await _card(tester, _profile('emerald_wings'));
    expect(sheetOf(), plain);
    await tester.pumpWidget(const SizedBox.shrink());
    await _card(tester, _profile('neon_dragon'));
    expect(tester.takeException(), isNull);
    expect(sheetOf(), plain);
    expect(find.byType(KabsoProfileHeaderArt), findsNothing);
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
      expect(find.byType(KabsoProfileHeaderArt), findsNothing);
    }
  });
}
