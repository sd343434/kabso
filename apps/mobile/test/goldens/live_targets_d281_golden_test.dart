// D281 / D281b «الأهداف الذكية» goldens (test fixtures only), 393×852 @3x with
// the phone's insets and a fixed clock for the countdown:
// - `live_targets_d281_chip`: the «تارجت» chip turning (its first face: the
//   gifts tab's easy target about ONE gift — that gift's current hosted
//   picture, «سهل», «37/100», the reward);
// - `live_targets_d281_chip_still`: the golden app's reduced motion — one
//   compact face per tab (the gift-box badge «1/3», the lucky badge «0/3»);
// - `live_targets_d281_sheet` / `_sheet_lucky`: the ranking sheet's daily
//   tab — «الهدايا» (the gift's picture on the gift count, the gift box on the
//   others) and «هدايا الحظ» (the lucky badge, the lucky gift's picture on its
//   count), each with «سهل / متوسط / صعب», title, progress and the reward in
//   locked cherries («تم ·» once paid).
// The gifts' hosted art comes from a fake art cache serving real gift images.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_targets_d281_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../features/live/host_target_d281_test.dart' show d281Json, useD281Art;
import '../helpers/fake_live_host_targets_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';

void _insets(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> _chip(WidgetTester tester, AppLanguage language) async {
  _insets(tester);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        liveHostTargetsRepositoryProvider.overrideWithValue(
          FakeLiveHostTargetsRepository(
            byHost: {
              'host': LiveHostTargets.fromJson(d281Json(lang: language.name)),
            },
          ),
        ),
      ],
      child: const ColoredBox(
        color: Color(0xFF2A2333),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: KRoomChipsRow(
                roomNumber: 1234,
                targetChip: LiveHostTargetChip(username: 'host', isHost: false),
              ),
            ),
          ),
        ),
      ),
    ),
    language: language,
    bare: true,
  );
  await tester.pump();
  await precacheImages(tester);
}

Future<void> _sheet(WidgetTester tester, AppLanguage language) async {
  HostTargetSheet.clock = () => DateTime.utc(2027, 1, 14, 15, 43);
  addTearDown(() => HostTargetSheet.clock = DateTime.now);
  _insets(tester);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        liveHostTargetsRepositoryProvider.overrideWithValue(
          FakeLiveHostTargetsRepository(
            byHost: {
              'host': LiveHostTargets.fromJson(d281Json(lang: language.name)),
            },
          ),
        ),
        currentUserProvider.overrideWithValue(
          testUser(displayName: 'Kabso fan'),
        ),
      ],
      child: ColoredBox(
        color: const Color(0xFF3B3346),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: HostTargetSheet(
            isHost: false,
            username: 'host',
            onSupport: () {},
          ),
        ),
      ),
    ),
    language: language,
    bare: true,
  );
  await precacheImages(tester);
}

void main() {
  forEachLanguage((language) {
    testWidgets('live_targets_d281_chip (${language.name})', (tester) async {
      useD281Art();
      LiveHostTargetChip.debugIgnoreReducedMotion = true;
      addTearDown(() => LiveHostTargetChip.debugIgnoreReducedMotion = false);
      await _chip(tester, language);
      expect(
        find.byKey(LiveHostTargetChip.dailyKey(TargetLevel.easy)),
        findsOneWidget,
      );
      expect(find.byKey(KGiftImage.networkKey), findsOneWidget);
      await expectScreenGolden('live_targets_d281_chip', language: language);
    });

    testWidgets('live_targets_d281_chip_still (${language.name})', (
      tester,
    ) async {
      useD281Art();
      await _chip(tester, language);
      for (final track in TargetTrack.values) {
        expect(
          find.byKey(LiveHostTargetChip.summaryKey(track)),
          findsOneWidget,
        );
      }
      await expectScreenGolden(
        'live_targets_d281_chip_still',
        language: language,
      );
    });

    testWidgets('live_targets_d281_sheet (${language.name})', (tester) async {
      useD281Art();
      await _sheet(tester, language);
      expect(find.byKey(HostTargetSheet.targetsKey), findsOneWidget);
      expect(find.byKey(KGiftImage.networkKey), findsOneWidget);
      await expectScreenGolden('live_targets_d281_sheet', language: language);
    });

    testWidgets('live_targets_d281_sheet_lucky (${language.name})', (
      tester,
    ) async {
      useD281Art();
      await _sheet(tester, language);
      await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      expect(find.byKey(HostTargetSheet.targetsKey), findsOneWidget);
      await expectScreenGolden(
        'live_targets_d281_sheet_lucky',
        language: language,
      );
    });
  });
}
