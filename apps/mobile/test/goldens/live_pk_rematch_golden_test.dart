// D242 «جولة أخرى» goldens through the real screens with fake repositories
// shaped like the contract (v1.55-live): the host's result with the offer
// button, the asking host waiting, the other host's prompt (both with the
// answer's ring pinned), and a viewer's «جولة أخرى!» banner as the new
// battle starts. ar and en at 393×852 (insets 59 / 34), @3x, dark (the card
// is the white leave-prompt card in every theme).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_pk_rematch_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_rematch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_pk.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';
import 'live_pk_golden_test.dart' show pumpPkHost;

late DateTime _now;

void main() {
  setUp(() {
    _now = DateTime.now();
    LivePkStage.debugNow = () => _now;
    PkRematchDock.debugSeconds = 12;
  });
  tearDown(() {
    LivePkStage.debugNow = null;
    PkRematchDock.debugSeconds = null;
  });
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    for (final (name, offerBy) in [
      ('offer', null),
      ('waiting', 'room-host'),
      ('prompt', 'room-b'),
    ]) {
      testWidgets('go_live.pk.rematch.$name', (tester) async {
        await pumpPkHost(
          tester,
          language: language,
          pkRepo: FakeLivePkRepository()
            ..snapshotOf = () => PkState(
              match: pkRematchFixture(
                now: _now,
                ar: ar,
                ownRoom: 'room-host',
                offerBy: offerBy,
              ),
            ),
        );
        await expectScreenGolden(
          'go_live.pk.rematch.$name',
          language: language,
        );
      });
    }

    testWidgets('room.pk.rematch.banner (a viewer)', (tester) async {
      tester.view.padding = const FakeViewPadding(
        top: 59 * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      KabsoPkBar.enabled = true;
      addTearDown(() => KabsoPkBar.enabled = false);
      final media = FakeLiveMediaEngine()..present.add('user-0');
      final other = FakePkOpponentMedia()..present.add('host-b');
      final prefs = await testPrefs(language: language.name);
      final repo = FakeLivePkRepository()
        ..snapshotOf = () => PkState(
          match: pkRematchFixture(
            now: _now,
            ar: ar,
            status: PkMatchStatus.battle,
            rematchOf: 'm1',
          ),
        );
      await pumpGolden(
        tester,
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(prefs),
            liveRepositoryProvider.overrideWithValue(
              FakeLiveRepository(
                room: (id) => apiRoom(id: id, ar: ar),
              ),
            ),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile(ar: ar)),
            ),
            ...pkOverrides(repo, other),
            liveMediaEngineProvider.overrideWithValue(() => media),
            currentUserProvider.overrideWithValue(testUser()),
          ],
          child: const LiveRoomScreen(roomId: 'room-0'),
        ),
        language: language,
        bare: true,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      ProviderScope.containerOf(tester.element(find.byType(LiveRoomScreen)))
          .read(livePkProvider('room-0').notifier)
          .announceRematchForTest();
      await tester.pump();
      expect(find.byKey(PkRematchBanner.bannerKey), findsOneWidget);
      await expectScreenGolden('room.pk.rematch.banner', language: language);
    });
  });
}
