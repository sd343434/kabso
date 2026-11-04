// D277 «تارجت» chip goldens: «هدف الهدايا» and «هدف هدايا الحظ» (both in
// cherries) with each target's badge from its asset slot
// (assets/host_targets/), on the room's chips row over a dark live, at
// 393×852 @3x with the phone's insets (59 / 34). Reduced motion (the golden
// app) shows both faces side by side; the lucky target is reached (check
// and glow).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_target_chip_d277_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_host_targets_repository.dart';
import '../helpers/golden.dart';

LiveHostTargets _targets() => LiveHostTargets.fromJson(const {
  'day': '2026-11-04',
  'timeZone': 'Asia/Riyadh',
  'endsAt': '2026-11-04T21:00:00.000Z',
  'band': 1,
  'gifts': {'received': 12_400, 'target': 650_000, 'reached': false},
  'cherries': {'received': 12_400, 'target': 650_000, 'reached': false},
  'lucky': {'received': 20_300, 'target': 20_000, 'reached': true},
  'topSupporters': <Object?>[],
  'luckySupporters': <Object?>[],
  'me': null,
});

void main() {
  forEachLanguage((language) {
    testWidgets('live_target_chip_d277 (${language.name})', (tester) async {
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
              FakeLiveHostTargetsRepository(byHost: {'host': _targets()}),
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
                      isHost: true,
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
      expect(find.byKey(LiveHostTargetChip.giftsKey), findsOneWidget);
      await expectScreenGolden('live_target_chip_d277', language: language);
    });
  });
}
