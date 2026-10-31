// D195 (v1.43-live): PK 1 v 1 goldens through the real screens with fake
// repositories shaped like the contract — the viewer's split screen in a
// battle, with a booster (Triple ×5) and its announcement, and the result;
// the host's PK sheet and an incoming invitation. ar and en at 393×852
// (insets 59 / 34) and 360×800, @3x, dark.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_pk_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_pk.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

/// The viewer's room with [match] as the room's PK snapshot.
Future<void> pumpPkViewer(
  WidgetTester tester, {
  required AppLanguage language,
  required GoldenViewport viewport,
  required PkMatch match,
  PkBoosterKind? announce,
  String? announceRoom,
  FakeLiveMediaEngine? engine,
  FakePkOpponentMedia? opponent,
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
  final media = engine ?? FakeLiveMediaEngine()
    ..present.add('user-0');
  final other = opponent ?? FakePkOpponentMedia()
    ..present.add('host-b');
  final prefs = await testPrefs(language: language.name);
  final repo = FakeLivePkRepository(snapshot: PkState(match: match));
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
        currentUserProvider.overrideWithValue(null),
      ],
      child: const LiveRoomScreen(roomId: 'room-0'),
    ),
    language: language,
    viewport: viewport,
    bare: true,
  );
  await tester.pumpAndSettle();
  if (announce != null) {
    final element = tester.element(find.byType(LiveRoomScreen));
    final pk = ProviderScope.containerOf(element);
    final controller = pk.read(livePkProvider('room-0').notifier);
    controller.announceForTest(
      controller.state.match!,
      announce,
      announceRoom ?? 'room-0',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  // Kabi's Lottie loads in real time (reduced motion: a still frame).
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
}

/// The host's own live on air, with [snapshot] as the room's PK state.
Future<ProviderContainer> pumpPkHost(
  WidgetTester tester, {
  required AppLanguage language,
  PkState snapshot = const PkState(),
  List<PkCandidate> candidates = const [],
}) async {
  final ar = language == AppLanguage.ar;
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  final prefs = await testPrefs(language: language.name);
  final repo = FakeLivePkRepository(snapshot: snapshot, list: candidates);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        ...pkOverrides(repo),
        liveMediaEngineProvider.overrideWithValue(FakeLiveMediaEngine.new),
        currentUserProvider.overrideWithValue(
          testUser(displayName: ar ? 'سارة' : 'Sara').copyWith(canHost: true),
        ),
      ],
      child: const GoLiveScreen(),
    ),
    language: language,
    bare: true,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GoLiveScreen)),
  );
  final host = container.read(liveHostControllerProvider.notifier);
  await host.setMode(LiveRoomMode.solo);
  await host.goLive(title: ar ? 'سهرة' : 'Evening');
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  await precacheImages(tester);
  return container;
}

List<PkCandidate> pkCandidates({required bool ar}) => [
  for (final (i, (a, e)) in [
    ('كريم', 'Karim'),
    ('ليلى', 'Layla'),
    ('عمر', 'Omar'),
    ('رنا', 'Rana'),
  ].indexed)
    PkCandidate(
      roomId: 'room-$i',
      title: ar ? 'سهرة غناء $i' : 'Singing night $i',
      viewerCount: 300 - i * 60,
      host: pkUser('host-$i', ar ? a : e),
    ),
];

void main() {
  final now = DateTime.now();
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        final vp = viewport.name;
        testWidgets('room.pk.battle ($vp)', (tester) async {
          await pumpPkViewer(
            tester,
            language: language,
            viewport: viewport,
            match: pkMatchFixture(now: now, ar: ar, ownGuests: 2),
          );
          await expectScreenGolden(
            'room.pk.battle',
            language: language,
            viewport: viewport,
          );
        });

        testWidgets('room.pk.boost ($vp)', (tester) async {
          await pumpPkViewer(
            tester,
            language: language,
            viewport: viewport,
            match: pkMatchFixture(
              now: now,
              ar: ar,
              remaining: const Duration(seconds: 48, milliseconds: 500),
              ownBoost: PkBoosterKind.triple,
              ownScore: 48200,
              otherScore: 39900,
            ),
            announce: PkBoosterKind.triple,
          );
          await expectScreenGolden(
            'room.pk.boost',
            language: language,
            viewport: viewport,
          );
        });

        testWidgets('room.pk.result ($vp)', (tester) async {
          await pumpPkViewer(
            tester,
            language: language,
            viewport: viewport,
            match: pkMatchFixture(
              now: now,
              ar: ar,
              status: PkMatchStatus.result,
              winner: 'room-0',
              ownScore: 61500,
              otherScore: 52100,
            ),
          );
          await expectScreenGolden(
            'room.pk.result',
            language: language,
            viewport: viewport,
          );
        });
      }

      testWidgets('go_live.pk.sheet', (tester) async {
        await pumpPkHost(
          tester,
          language: language,
          candidates: pkCandidates(ar: ar),
        );
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pumpAndSettle();
        expect(find.byType(LivePkSheet), findsOneWidget);
        await precacheImages(tester);
        await expectScreenGolden('go_live.pk.sheet', language: language);
      });

      testWidgets('go_live.pk.incoming', (tester) async {
        await pumpPkHost(
          tester,
          language: language,
          snapshot: PkState(
            invite: PkInvite(
              id: 'invite-1',
              status: 'PENDING',
              fromRoomId: 'room-b',
              toRoomId: 'room-host',
              from: pkUser('host-b', ar ? 'كريم' : 'Karim'),
              to: pkUser('user-0', ar ? 'سارة' : 'Sara'),
              expiresAt: DateTime.now().add(
                const Duration(seconds: 14, milliseconds: 500),
              ),
            ),
          ),
        );
        expect(find.byType(LivePkIncomingInvite), findsOneWidget);
        await expectScreenGolden('go_live.pk.incoming', language: language);
      });
    });
  });
}
