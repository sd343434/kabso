// D229 (v1.50-live): «PK أحكام» goldens through the real screens with fake
// repositories shaped like the contract — the viewer's draw (three cards),
// the losing host's «قبول» / «رفض» with its ring, the dare's banner with the
// 3:00 countdown in a viewer's room, the winning host's «نُفّذ» / «لم يُنفّذ»,
// and «رفض الحكم». ar and en at 393×852 (insets 59 / 34), @3x, dark; the
// banner also at 360×800. The snapshot is built when it is read, so the
// countdowns never move under load.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_pk_dares_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
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

Future<void> _pumpViewer(
  WidgetTester tester, {
  required AppLanguage language,
  required GoldenViewport viewport,
  required PkMatch Function(DateTime now) match,
}) async {
  final ar = language == AppLanguage.ar;
  if (viewport == GoldenViewport.phone) {
    tester.view.padding = const FakeViewPadding(
      top: 59 * GoldenViewport.pixelRatio,
      bottom: 34 * GoldenViewport.pixelRatio,
    );
    addTearDown(tester.view.resetPadding);
  }
  KabsoPkBar.enabled = true;
  addTearDown(() => KabsoPkBar.enabled = false);
  final media = FakeLiveMediaEngine()..present.add('user-0');
  final other = FakePkOpponentMedia()..present.add('host-b');
  final prefs = await testPrefs(language: language.name);
  final repo = FakeLivePkRepository()
    ..snapshotOf = () => PkState(match: match(DateTime.now()));
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
    viewport: viewport,
    bare: true,
  );
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    PkDareLayer.debugRemaining = const Duration(minutes: 2, seconds: 14);
    PkDareLayer.debugDecideSeconds = 21;
  });
  tearDown(() {
    PkDareLayer.debugRemaining = null;
    PkDareLayer.debugDecideSeconds = null;
  });
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    group(language.name, () {
      testWidgets('room.pk.dare.draw', (tester) async {
        await _pumpViewer(
          tester,
          language: language,
          viewport: GoldenViewport.phone,
          match: (now) => pkDareMatchFixture(
            now: now,
            ar: ar,
            dare: pkDareFixture(now: now, status: PkDareStatus.drawing),
          ),
        );
        await expectScreenGolden('room.pk.dare.draw', language: language);
      });

      for (final viewport in GoldenViewport.values) {
        testWidgets('room.pk.dare.banner (${viewport.name})', (tester) async {
          await _pumpViewer(
            tester,
            language: language,
            viewport: viewport,
            match: (now) => pkDareMatchFixture(
              now: now,
              ar: ar,
              dare: pkDareFixture(now: now, status: PkDareStatus.active),
            ),
          );
          await expectScreenGolden(
            'room.pk.dare.banner',
            language: language,
            viewport: viewport,
          );
        });
      }

      testWidgets('room.pk.dare.refused', (tester) async {
        await _pumpViewer(
          tester,
          language: language,
          viewport: GoldenViewport.phone,
          match: (now) => pkDareMatchFixture(
            now: now,
            ar: ar,
            dare: pkDareFixture(
              now: now,
              status: PkDareStatus.refused,
              cause: 'LOSER_REFUSED',
              points: -3,
            ),
          ),
        );
        await expectScreenGolden('room.pk.dare.refused', language: language);
      });

      testWidgets('go_live.pk.dare.decide (the loser)', (tester) async {
        await pumpPkHost(
          tester,
          language: language,
          pkRepo: FakeLivePkRepository()
            ..snapshotOf = () {
              final now = DateTime.now();
              return PkState(
                match: pkDareMatchFixture(
                  now: now,
                  ar: ar,
                  ownRoom: 'room-host',
                  dare: pkDareFixture(now: now, loserRoom: 'room-host'),
                ),
              );
            },
        );
        await expectScreenGolden('go_live.pk.dare.decide', language: language);
      });

      testWidgets('go_live.pk.dare.judge (the winner)', (tester) async {
        await pumpPkHost(
          tester,
          language: language,
          pkRepo: FakeLivePkRepository()
            ..snapshotOf = () {
              final now = DateTime.now();
              return PkState(
                match: pkDareMatchFixture(
                  now: now,
                  ar: ar,
                  ownRoom: 'room-host',
                  dare: pkDareFixture(
                    now: now,
                    status: PkDareStatus.active,
                    loserRoom: 'room-b',
                    winnerRoom: 'room-host',
                  ),
                ),
              );
            },
        );
        await expectScreenGolden('go_live.pk.dare.judge', language: language);
      });
    });
  });
}
