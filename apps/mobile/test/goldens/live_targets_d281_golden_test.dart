// D281 «الأهداف الذكية» goldens (test fixtures only): the «تارجت» chip with
// the three smart targets side by side (the golden app's reduced motion:
// each target's mark — the gift's own picture for «استقبل 100 هدية من
// المحارب», the gift-box badge for the cherries target — and its progress),
// and the ranking sheet's daily tab with the three rows («سهل / متوسط /
// صعب», title, progress, the reward in locked cherries, «تم ✓» once paid).
// 393×852 @3x with the phone's insets; a fixed clock for the countdown.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_targets_d281_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../features/live/host_target_d281_test.dart' show d281Json;
import '../helpers/fake_live_host_targets_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';

void main() {
  forEachLanguage((language) {
    final targets = LiveHostTargets.fromJson(d281Json(lang: language.name));

    testWidgets('live_targets_d281_chip (${language.name})', (tester) async {
      tester.view.padding = const FakeViewPadding(
        top: 59 * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await pumpGolden(
        tester,
        ProviderScope(
          overrides: [
            liveHostTargetsRepositoryProvider.overrideWithValue(
              FakeLiveHostTargetsRepository(byHost: {'host': targets}),
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
                    targetChip: LiveHostTargetChip(
                      username: 'host',
                      isHost: false,
                    ),
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
      for (final level in TargetLevel.values) {
        expect(find.byKey(LiveHostTargetChip.dailyKey(level)), findsOneWidget);
      }
      await expectScreenGolden('live_targets_d281_chip', language: language);
    });

    testWidgets('live_targets_d281_sheet (${language.name})', (tester) async {
      HostTargetSheet.clock = () => DateTime.utc(2027, 1, 14, 15, 43);
      addTearDown(() => HostTargetSheet.clock = DateTime.now);
      tester.view.padding = const FakeViewPadding(
        top: 59 * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await pumpGolden(
        tester,
        ProviderScope(
          overrides: [
            liveHostTargetsRepositoryProvider.overrideWithValue(
              FakeLiveHostTargetsRepository(byHost: {'host': targets}),
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
      expect(find.byKey(HostTargetSheet.targetsKey), findsOneWidget);
      await expectScreenGolden('live_targets_d281_sheet', language: language);
    });
  });
}
