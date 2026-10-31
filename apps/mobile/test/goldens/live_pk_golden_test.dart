// D195 (v1.43-live): PK 1 v 1 goldens through the real screens with fake
// repositories shaped like the contract — the viewer's split screen in a
// battle, with a booster (Triple ×5) and its announcement, and the result;
// the host's PK sheet and an incoming invitation. ar and en at 393×852
// (insets 59 / 34) and 360×800, @3x, dark.
//
// D199: the owner's layouts — the PK sheet (refs 276 / 277; Kabi when no
// friends), the PK Setting page, the PK history, a connected PK and a best
// of three round, the booster's activation per tier (mid-animation) and the
// active state with «+N ×5», the host's Room Tools (ref 273 / B) and the
// live's data page (ref 274).
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
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_data_now_page.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
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
  FakeLivePkRepository? pkRepo,
  FakeLiveRepository? live,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final ar = language == AppLanguage.ar;
  if (viewport == GoldenViewport.phone) {
    tester.view.padding = const FakeViewPadding(
      top: 59 * GoldenViewport.pixelRatio,
      bottom: 34 * GoldenViewport.pixelRatio,
    );
    addTearDown(tester.view.resetPadding);
  }
  final prefs = await testPrefs(language: language.name);
  final repo =
      pkRepo ?? FakeLivePkRepository(snapshot: snapshot, list: candidates);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(live ?? FakeLiveRepository()),
        ...pkOverrides(repo),
        liveMediaEngineProvider.overrideWithValue(FakeLiveMediaEngine.new),
        currentUserProvider.overrideWithValue(
          testUser(displayName: ar ? 'سارة' : 'Sara').copyWith(canHost: true),
        ),
      ],
      child: const GoLiveScreen(),
    ),
    language: language,
    viewport: viewport,
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
        // The invitation is built when the room reads it (D199: a slow
        // setup under load no longer turns «14» into «13»).
        await pumpPkHost(
          tester,
          language: language,
          pkRepo: FakeLivePkRepository()
            ..snapshotOf = () => PkState(
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

      // ---- D199 -------------------------------------------------------------
      for (final kind in PkBoosterKind.values) {
        testWidgets('room.pk.activate.${kind.name}', (tester) async {
          PkBoostBurst.debugProgress = 0.3;
          addTearDown(() => PkBoostBurst.debugProgress = null);
          await pumpPkViewer(
            tester,
            language: language,
            viewport: GoldenViewport.phone,
            match: pkMatchFixture(
              now: now,
              ar: ar,
              remaining: const Duration(seconds: 52, milliseconds: 500),
              ownBoost: kind,
              ownScore: 48200,
              otherScore: 39900,
              ownGuests: 2,
              otherGuests: 1,
            ),
            announce: kind,
          );
          await expectScreenGolden(
            'room.pk.activate.${kind.name}',
            language: language,
          );
        });
      }

      testWidgets('room.pk.active_gain', (tester) async {
        PkGainFloat.debugProgress = 0.35;
        addTearDown(() => PkGainFloat.debugProgress = null);
        final boosted = pkMatchFixture(
          now: now,
          ar: ar,
          remaining: const Duration(seconds: 52, milliseconds: 500),
          ownBoost: PkBoosterKind.triple,
          ownScore: 48200,
          otherScore: 39900,
          ownGuests: 2,
        );
        await pumpPkViewer(
          tester,
          language: language,
          viewport: GoldenViewport.phone,
          match: boosted,
        );
        ProviderScope.containerOf(tester.element(find.byType(LiveRoomScreen)))
            .read(livePkProvider('room-0').notifier)
            .debugSetMatch(
              pkMatchFixture(
                now: now,
                ar: ar,
                remaining: const Duration(seconds: 52, milliseconds: 500),
                ownBoost: PkBoosterKind.triple,
                ownScore: 48200 + 5000,
                otherScore: 39900,
                ownGuests: 2,
                seq: 6,
              ),
            );
        await tester.pump();
        await tester.pump();
        await expectScreenGolden('room.pk.active_gain', language: language);
      });

      testWidgets('room.pk.best_of_three', (tester) async {
        await pumpPkViewer(
          tester,
          language: language,
          viewport: GoldenViewport.phone,
          match: pkMatchFixture(
            now: now,
            ar: ar,
            bestOfThree: true,
            round: 2,
            ownRounds: 1,
            remaining: const Duration(minutes: 2, seconds: 30),
          ),
        );
        await expectScreenGolden('room.pk.best_of_three', language: language);
      });

      testWidgets('go_live.pk.sheet.empty', (tester) async {
        await pumpPkHost(
          tester,
          language: language,
          pkRepo: FakeLivePkRepository()..friendList = const [],
        );
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pump();
        expect(find.byKey(LivePkSheet.emptyKey), findsOneWidget);
        await expectScreenGolden('go_live.pk.sheet.empty', language: language);
      });

      testWidgets('go_live.pk.settings', (tester) async {
        await pumpPkHost(tester, language: language);
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LivePkSheet.settingsKey));
        await tester.pumpAndSettle();
        await expectScreenGolden('go_live.pk.settings', language: language);
      });

      testWidgets('go_live.pk.history', (tester) async {
        final repo = FakeLivePkRepository()
          ..pkHistory = PkHistory(
            record: const PkRecord(wins: 3, losses: 1, draws: 1),
            recent: [
              PkHistoryItem(
                id: 'm1',
                result: 'WIN',
                score: 11000,
                opponentScore: 6000,
                opponent: pkUser('host-b', ar ? 'كريم' : 'Karim'),
                startedAt: DateTime(2026, 10, 30),
                bestOfThree: true,
                roundsWon: 2,
                opponentRoundsWon: 1,
              ),
              PkHistoryItem(
                id: 'm2',
                result: 'LOSS',
                score: 1200,
                opponentScore: 1500,
                opponent: pkUser('host-c', ar ? 'ليلى' : 'Layla'),
                startedAt: DateTime(2026, 10, 29),
                effective: false,
              ),
              PkHistoryItem(
                id: 'm3',
                result: 'DRAW',
                score: 4000,
                opponentScore: 4000,
                opponent: pkUser('host-d', ar ? 'عمر' : 'Omar'),
                startedAt: DateTime(2026, 10, 28),
              ),
            ],
          );
        await pumpPkHost(tester, language: language, pkRepo: repo);
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LivePkSheet.historyKey));
        await tester.pumpAndSettle();
        await expectScreenGolden('go_live.pk.history', language: language);
      });

      testWidgets('go_live.pk.connected', (tester) async {
        final base = pkMatchFixture(now: now, ar: ar, ownRoom: 'room-host');
        await pumpPkHost(
          tester,
          language: language,
          snapshot: PkState(
            match: PkMatch(
              id: base.id,
              status: PkMatchStatus.connected,
              startedAt: now,
              battleEndsAt: now.add(const Duration(minutes: 5)),
              sides: base.sides,
              seq: 1,
              serverTime: now,
              boosters: base.boosters,
            ),
          ),
        );
        await expectScreenGolden('go_live.pk.connected', language: language);
      });

      for (final viewport in GoldenViewport.values) {
        testWidgets('go_live.tools (${viewport.name})', (tester) async {
          await pumpPkHost(tester, language: language, viewport: viewport);
          await tester.tap(find.byKey(KHostBar.toolsKey));
          await tester.pumpAndSettle();
          await expectScreenGolden(
            'go_live.tools',
            language: language,
            viewport: viewport,
          );
        });
      }

      testWidgets('go_live.data_now', (tester) async {
        final live = FakeLiveRepository()
          ..stats = LiveRoomStats(
            roomId: 'room-host',
            ended: false,
            startedAt: now.subtract(const Duration(seconds: 33)),
            endedAt: null,
            duration: const Duration(seconds: 33),
            total: 0,
            tapPoints: 0,
            supportPoints: 0,
            hostOwnPoints: 0,
            supporters: 0,
            topSupporters: const [],
            giftCount: 0,
            chatMessages: 0,
            newFollowers: 0,
            viewers: const LiveViewerStats(
              unique: 21,
              guests: 0,
              peak: 9,
              atEnd: 8,
              averageWatch: Duration.zero,
            ),
            viewerCountries: const [],
          );
        await pumpPkHost(tester, language: language, live: live);
        await tester.tap(find.byKey(KHostBar.toolsKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(GoLiveKeys.tool('data')));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveDataNowPage.pageKey), findsOneWidget);
        await expectScreenGolden('go_live.data_now', language: language);
      });
    });
  });
}
