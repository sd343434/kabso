// D241 (owner: two lives in a PK battle showed no PK): a real D195 battle
// keeps the rooms SOLO; the server's `inPk` (v1.54-live) makes the hub
// card say «PK» instead of «بث مباشر». The legacy mode PK still does; an
// older server (no field) reads as not in a PK. ar and en.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

LiveRoomSummary _room({String mode = 'SOLO', bool? inPk}) =>
    LiveRoomSummary.fromJson({
      'id': 'r1',
      'title': 'jgjg',
      'topic': null,
      'mode': mode,
      'host': {
        'id': 'h1',
        'username': 'coin0001',
        'displayName': 'jgjg',
        'avatarUrl': null,
      },
      'category': null,
      'viewerCount': 3,
      'startedAt': '2026-11-02T12:00:00.000Z',
      'score': 0,
      'coverUrl': null,
      'inPk': ?inPk,
    });

Future<String?> _tag(
  WidgetTester tester,
  LiveRoomSummary room,
  AppLanguage language,
) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Center(
      child: SizedBox(
        width: 170,
        height: 190,
        child: KLiveGridCard(room: LiveRoomCardData.fromSummary(room)),
      ),
    ),
    language: language,
  );
  // D362: the tag beside the owner's glyph.
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(KLiveGridCard.typeKey),
          matching: find.byKey(LiveTypeTag.textKey),
        ),
      )
      .data;
}

void main() {
  test('parse: inPk true, false and absent (older servers)', () {
    expect(_room(inPk: true).inPk, isTrue);
    expect(_room(inPk: false).inPk, isFalse);
    expect(_room().inPk, isFalse);
  });

  for (final language in AppLanguage.values) {
    final l10n = l10nFor(language);
    testWidgets('a SOLO room in a battle says «PK» (${language.name})', (
      tester,
    ) async {
      expect(await _tag(tester, _room(inPk: true), language), l10n.pkBadge);
    });

    testWidgets('a SOLO room not in a PK says «Live Cam» (${language.name})', (
      tester,
    ) async {
      expect(
        await _tag(tester, _room(inPk: false), language),
        l10n.liveTypeTagCam,
      );
      expect(await _tag(tester, _room(), language), l10n.liveTypeTagCam);
    });

    testWidgets('the legacy mode PK says «PK» (${language.name})', (
      tester,
    ) async {
      expect(await _tag(tester, _room(mode: 'PK'), language), l10n.pkBadge);
    });
  }
}
