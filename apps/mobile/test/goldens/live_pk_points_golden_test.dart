// D276 goldens through the real screens with fake repositories shaped like
// the contract (v1.67-live): both hosts' «نقاط PK» on their halves — a
// viewer's room and the host's own screen — and the host's PK controls in
// the result with «جولة أخرى» next to «كتم الخصم» and «إنهاء التحدي». ar and
// en at 393×852 (insets 59 / 34), @3x.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_pk_points_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_rematch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_banner.dart';

import '../helpers/fake_live_pk.dart';
import '../helpers/golden.dart';
import 'live_pk_golden_test.dart' show pumpPkHost, pumpPkViewer;

late DateTime _now;

void main() {
  setUp(() {
    _now = DateTime.now();
    LivePkStage.debugNow = () => _now;
    PkPowerBanner.debugRemaining = const Duration(seconds: 14);
    PkRematchDock.debugSeconds = 12;
  });
  tearDown(() {
    LivePkStage.debugNow = null;
    PkPowerBanner.debugRemaining = null;
    PkRematchDock.debugSeconds = null;
  });
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;

    testWidgets("room.pk.points (a viewer sees both hosts' points)", (
      tester,
    ) async {
      await pumpPkViewer(
        tester,
        language: language,
        viewport: GoldenViewport.phone,
        match: pkMatchFixture(
          now: _now,
          ar: ar,
          ownPkPoints: 42,
          otherPkPoints: -3,
        ),
      );
      expect(find.byKey(LivePkStage.pointsKey('room-0')), findsOneWidget);
      expect(find.byKey(LivePkStage.pointsKey('room-b')), findsOneWidget);
      await expectScreenGolden('room.pk.points', language: language);
    });

    testWidgets("go_live.pk.points (the host sees the opponent's too)", (
      tester,
    ) async {
      await pumpPkHost(
        tester,
        language: language,
        pkRepo: FakeLivePkRepository()
          ..snapshotOf = () => PkState(
            match: pkMatchFixture(
              now: _now,
              ar: ar,
              ownRoom: 'room-host',
              ownPkPoints: 1250,
              otherPkPoints: 87,
            ),
          ),
      );
      expect(find.byKey(LivePkStage.pointsKey('room-host')), findsOneWidget);
      expect(find.byKey(LivePkStage.pointsKey('room-b')), findsOneWidget);
      await expectScreenGolden('go_live.pk.points', language: language);
    });

    testWidgets('go_live.pk.sheet.rematch (the controls in the result)', (
      tester,
    ) async {
      await pumpPkHost(
        tester,
        language: language,
        pkRepo: FakeLivePkRepository()
          ..snapshotOf = () => PkState(
            match: pkRematchFixture(
              now: _now,
              ar: ar,
              ownRoom: 'room-host',
              ownPkPoints: 45,
              otherPkPoints: 0,
            ),
          ),
      );
      await tester.tap(find.byKey(KHostBar.pkKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LivePkSheet.rematchKey), findsOneWidget);
      expect(find.byKey(LivePkSheet.muteKey), findsOneWidget);
      expect(find.byKey(LivePkSheet.endKey), findsOneWidget);
      await precacheImages(tester);
      await expectScreenGolden('go_live.pk.sheet.rematch', language: language);
    });
  });
}
