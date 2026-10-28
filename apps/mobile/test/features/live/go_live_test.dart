// CP-010 L1: go live — the gates (hosting off, no hosting permission), the
// camera preview and its problems, the title rule, starting (room, token,
// publish, heartbeats), the guests switch while live, ending (confirmed),
// failures that roll back, the server ending the room, leaving while live,
// the Create mode bar, and Arabic RTL placement.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_mode_bar.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/levels/data/levels_repository.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_setup_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_end_summary.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_fill_light.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_program_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_info_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_schedule_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_emoji.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_program_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _notAllowed = ServerFailure(
  code: ErrorCode.liveHostingNotAllowed,
  rawCode: 'LIVE_HOSTING_NOT_ALLOWED',
  debugMessage: 'x',
  statusCode: 403,
);

const _ended = ServerFailure(
  code: ErrorCode.liveRoomEnded,
  rawCode: 'LIVE_ROOM_ENDED',
  debugMessage: 'x',
  statusCode: 409,
);

const _internal = ServerFailure(
  code: ErrorCode.internalError,
  rawCode: 'INTERNAL_ERROR',
  debugMessage: 'x',
  statusCode: 500,
);

final _categories = [
  const LiveCategory(slug: 'music', name: 'Music'),
  const LiveCategory(slug: 'chat', name: 'Chat'),
];

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  bool hostingEnabled = true,
  bool canHost = true,
  AppLanguage language = AppLanguage.en,
  FakeLiveMediaEngine? engine,
  FakeLiveRepository? repo,
  GoldenViewport viewport = GoldenViewport.phone,
  LevelsRepository? levels,
  FakeLiveGiftRepository? gifts,
  FakeLiveScheduleRepository? schedule,
}) async {
  final live =
      repo ??
      FakeLiveRepository(
        hostingEnabled: hostingEnabled,
        categories: _categories,
      );
  final camera = engine ?? FakeLiveMediaEngine();
  setViewport(tester, viewport);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: camera,
    liveGiftRepository: gifts,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      currentUserProvider.overrideWithValue(
        testUser().copyWith(canHost: canHost),
      ),
      // CP-016 B and C: the settings rows read these; never the network.
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        schedule ?? FakeLiveScheduleRepository(),
      ),
      // A person's card reads their profile.
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      if (levels != null) levelsRepositoryProvider.overrideWithValue(levels),
    ],
  );
  await tester.pumpAndSettle();
  return (live, camera);
}

/// Disposes the screen (and its provider scope) so no timer outlives the
/// test.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _goLive(
  WidgetTester tester, {
  String title = 'Evening chat',
}) async {
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), title);
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
}

/// Audio: Go LIVE, then the 3-2-1 countdown, then the room.
Future<void> _startAudio(WidgetTester tester) async {
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pump();
  expect(find.byKey(GoLiveScreen.countdownKey), findsOneWidget);
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
  expect(find.byKey(GoLiveScreen.countdownKey), findsNothing);
}

/// Waits until a snack bar (which covers the host bar) is gone.
Future<void> _snackGone(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 5));
  }
  await tester.pumpAndSettle();
}

/// D131: the host's ≡ (room tools) on a video live.
Future<void> _openTools(WidgetTester tester) async {
  await tester.tap(find.byKey(KHostBar.toolsKey));
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(GoLiveScreen)));

/// D135: the host's own levels (`GET /levels/me`): charm 12, 3 510 of the
/// 5 000 points level 13 needs.
class _Levels implements LevelsRepository {
  @override
  Future<List<LevelSummary>> getMyLevels() async => [
    LevelSummary(
      category: LevelCategory.attractiveness,
      available: true,
      name: 'Charm',
      description: '',
      points: BigInt.from(3510),
      level: LevelBrief(
        levelNumber: 12,
        name: '12',
        requiredPoints: BigInt.from(3000),
      ),
      nextLevel: LevelBrief(
        levelNumber: 13,
        name: '13',
        requiredPoints: BigInt.from(5000),
      ),
      pointsToNext: BigInt.from(1490),
      progressPercent: 70.2,
    ),
  ];

  @override
  Future<LevelDetail> getMyLevel(LevelCategory category) =>
      throw UnimplementedError();

  @override
  Future<List<PublicLevel>> getUserLevels(String username) async => const [];
}

void main() {
  group('gates', () {
    testWidgets('hosting switched off: explained, the camera never starts', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester, hostingEnabled: false);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveScreen.unavailableKey), findsOneWidget);
      expect(find.text(l10n.goLiveUnavailableTitle), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(camera.previewStarts, 0);
      expect(repo.startRequests, isEmpty);
      await _leave(tester);
    });

    testWidgets('no hosting permission: explained, the camera never starts', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester, canHost: false);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveScreen.notAllowedKey), findsOneWidget);
      expect(find.text(l10n.goLiveNotAllowedBody), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(camera.previewStarts, 0);
      // The modes are still there.
      expect(find.byType(GoLiveModePager), findsOneWidget);
      await _leave(tester);
    });
  });

  group('preview', () {
    testWidgets('the camera starts with the tools and the categories', (
      tester,
    ) async {
      final (_, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      expect(camera.previewStarts, 1);
      expect(find.byKey(FakeLiveMediaEngine.previewKey), findsOneWidget);
      for (final key in [
        GoLiveScreen.closeKey,
        GoLiveScreen.titleKey,
        GoLiveScreen.flipKey,
        GoLiveScreen.micKey,
        GoLiveScreen.beautyKey,
        // D131 (ref 164): Share and Settings (who may watch) are tools.
        GoLiveKeys.tool('share'),
        GoLiveKeys.tool('settings'),
        GoLiveScreen.startKey,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.text(l10n.goLiveNoCategory), findsOneWidget);
      expect(find.text('# Music'), findsOneWidget);
      expect(find.text(l10n.goLiveTitleHint), findsOneWidget);
      // Nothing that does not work: no flash, timer or sound. D143: Magic
      // (colour filters) and Fill light are working tools, not Soon.
      expect(
        find.bySemanticsLabel('${l10n.liveToolMagic}, ${l10n.liveSoon}'),
        findsNothing,
      );
      expect(find.byKey(GoLiveKeys.tool('magic')), findsOneWidget);
      expect(find.byKey(GoLiveKeys.tool('fillLight')), findsOneWidget);
      expect(find.byIcon(Icons.flash_on), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      await _leave(tester);
    });

    testWidgets('flip and microphone act on the camera', (tester) async {
      final (_, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      expect(camera.flips, 1);
      expect(camera.frontCamera, isFalse);

      await tester.tap(find.byKey(GoLiveScreen.micKey));
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      expect(find.text(l10n.goLiveMicOff), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('camera denied: explained with Try again', (tester) async {
      final camera = FakeLiveMediaEngine()
        ..previewProblem = LiveCaptureProblem.denied;
      await _pump(tester, engine: camera);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveScreen.captureFailedKey), findsOneWidget);
      expect(find.text(l10n.goLiveCameraDeniedTitle), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);

      camera.previewProblem = null;
      await tester.tap(find.byKey(GoLiveScreen.retryKey));
      await tester.pumpAndSettle();
      expect(camera.previewStarts, 2);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('no camera: the unavailable message', (tester) async {
      await _pump(
        tester,
        engine: FakeLiveMediaEngine()
          ..previewProblem = LiveCaptureProblem.unavailable,
      );
      expect(
        find.text(_l10n(tester).goLiveCameraUnavailableTitle),
        findsOneWidget,
      );
      await _leave(tester);
    });

    testWidgets('a title is required', (tester) async {
      final (repo, _) = await _pump(tester);
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      await tester.pump();
      expect(find.text(_l10n(tester).goLiveTitleRequired), findsOneWidget);
      expect(repo.startRequests, isEmpty);
      await _leave(tester);
    });

    testWidgets('the title is capped at 80 characters', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'x' * 100);
      final field = tester.widget<TextField>(find.byKey(GoLiveScreen.titleKey));
      expect(field.controller!.text.length, GoLiveScreen.titleMaxLength);
      await _leave(tester);
    });
  });

  group('on air', () {
    testWidgets('CP-016 D: the room level shows after the title and follows '
        'a level change the media room announces', (tester) async {
      final repo = FakeLiveRepository(categories: _categories)
        ..startRoomLevel = 9;
      final (_, camera) = await _pump(tester, repo: repo);
      await _goLive(tester);
      CharmLevelBadge badge() =>
          tester.widget<CharmLevelBadge>(find.byType(CharmLevelBadge));
      expect(badge().level, 9);

      // A viewer's taps raised the host's charm level: the server raised
      // the room's info version, the host reads the room again.
      repo.hostRoom = repo.hostRoom!.copyWith(roomLevel: 11);
      camera
        ..infoVersion = 1
        ..ping();
      await tester.pumpAndSettle();
      expect(repo.roomRequests, ['room-host']);
      expect(badge().level, 11);
      expect(CharmTier.of(badge().level), CharmTier.bunny);

      // The same version again reads nothing.
      camera.ping();
      await tester.pumpAndSettle();
      expect(repo.roomRequests, ['room-host']);
      await _leave(tester);
    });

    testWidgets('start: room, token, publish, then heartbeats', (tester) async {
      final (repo, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveScreen.categoryKey('music')));
      // D131 (ref 164): who may watch is in Settings.
      await tester.tap(find.byKey(GoLiveKeys.tool('settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.guestsChipKey));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      await _goLive(tester, title: '  Evening chat  ');

      expect(repo.startRequests, [
        (
          title: 'Evening chat',
          categorySlug: 'music',
          allowGuests: false,
          mode: LiveRoomMode.solo,
          seatCount: null,
          theme: null,
        ),
      ]);
      expect(repo.tokenRequests, [(roomId: 'room-host', guestId: null)]);
      expect(camera.published?.token, 'token-room-host');
      expect(find.byKey(GoLiveScreen.elapsedKey), findsOneWidget);
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(find.byType(GoLiveModePager), findsNothing);
      // D131: the viewer's frame — the host pill, not the title.
      expect(find.byType(KHostPill), findsOneWidget);
      expect(find.byType(KHostBar), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, ['room-host']);
      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, hasLength(2));
      // The label is the (fake) time since going live, read when the last
      // frame was drawn. Not a fixed "0:30": how many frames pumpAndSettle
      // drew after going live depends on asynchronous work outside the fake
      // clock (image decoding), so the label could read 0:30 or 0:31.
      final since = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      ).read(liveHostControllerProvider).liveSince!;
      final onAir = clock.now().difference(since);
      expect(onAir, greaterThanOrEqualTo(const Duration(seconds: 30)));
      expect(
        find.bySemanticsLabel(l10n.goLiveElapsed(formatLiveDuration(onAir))),
        findsOneWidget,
      );
      await _leave(tester);
    });

    testWidgets('guests switch while live goes to the server', (tester) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      await _goLive(tester);
      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveScreen.liveGuestsKey));
      await tester.pump();
      expect(repo.guestUpdates, [(roomId: 'room-host', allow: false)]);
      expect(find.text(l10n.goLiveGuestsOff), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a failed guests change keeps the switch', (tester) async {
      final (repo, _) = await _pump(tester);
      await _goLive(tester);
      repo.guestsFailure = _internal;
      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveScreen.liveGuestsKey));
      await tester.pumpAndSettle();
      await _snackGone(tester);
      await _openTools(tester);
      final semantics = tester.getSemantics(
        find.byKey(GoLiveScreen.liveGuestsKey),
      );
      expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
      await _leave(tester);
    });

    testWidgets('end asks first, then ends and stops the camera', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await _goLive(tester);

      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.goLiveKeepGoing));
      await tester.pumpAndSettle();
      expect(repo.endRequests, isEmpty);

      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      expect(camera.stops, greaterThanOrEqualTo(1));
      expect(camera.running, isFalse);
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(find.text(l10n.goLiveEndedTitle), findsOneWidget);

      // No heartbeat after the end.
      await tester.pump(const Duration(seconds: 30));
      expect(repo.heartbeats, isEmpty);
      await _leave(tester);
    });

    testWidgets('close while live asks to end too', (tester) async {
      final (repo, _) = await _pump(tester);
      await _goLive(tester);
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.endConfirmKey), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      await _leave(tester);
    });

    testWidgets('the server ended the room: the heartbeat stops the live', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await _goLive(tester);
      repo.heartbeatFailure = _ended;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(camera.running, isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.heartbeats, hasLength(1));
      await _leave(tester);
    });

    testWidgets('a transient heartbeat failure keeps the live', (tester) async {
      final (repo, _) = await _pump(tester);
      await _goLive(tester);
      repo.heartbeatFailure = _internal;
      await tester.pump(const Duration(seconds: 15));
      repo.heartbeatFailure = null;
      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, hasLength(2));
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('leaving while live ends the room and stops the camera', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await _goLive(tester);
      await _leave(tester);
      expect(repo.endRequests, ['room-host']);
      expect(camera.running, isFalse);
    });
  });

  group('failures', () {
    testWidgets('no permission on the server: message, back to preview', (
      tester,
    ) async {
      final repo = FakeLiveRepository(categories: _categories)
        ..startFailure = _notAllowed;
      final (_, camera) = await _pump(tester, repo: repo);
      await _goLive(tester);
      expect(
        find.text(_l10n(tester).errorLiveHostingNotAllowed),
        findsOneWidget,
      );
      expect(repo.tokenRequests, isEmpty);
      expect(camera.published, isNull);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('publish fails: the new room is ended, not left behind', (
      tester,
    ) async {
      final camera = FakeLiveMediaEngine()..publishFailure = _internal;
      final (repo, _) = await _pump(tester, engine: camera);
      await _goLive(tester);
      expect(repo.endRequests, ['room-host']);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      expect(find.byKey(KHostBar.toolsKey), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.heartbeats, isEmpty);
      await _leave(tester);
    });
  });

  group('modes (CP-011)', () {
    Future<void> mode(WidgetTester tester, LiveRoomMode m) async {
      await tester.tap(find.byKey(GoLiveKeys.mode(m)));
      await tester.pumpAndSettle();
    }

    testWidgets('audio picked while the camera is still starting: the camera '
        'stops and the room publishes the microphone only', (tester) async {
      final gate = Completer<void>();
      final camera = FakeLiveMediaEngine()..previewGate = gate;
      final setup = FakeLiveRepository(categories: _categories);
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const GoLiveScreen(),
        liveMediaEngine: camera,
        overrides: [
          liveRepositoryProvider.overrideWithValue(setup),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(canHost: true),
          ),
          liveBlockedWordsRepositoryProvider.overrideWithValue(
            FakeLiveBlockedWordsRepository(),
          ),
          liveScheduleRepositoryProvider.overrideWithValue(
            FakeLiveScheduleRepository(),
          ),
        ],
      );
      await tester.pump();
      // Still preparing (the camera has not started): pick Audio.
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pump();
      gate.complete();
      camera.previewGate = null;
      await tester.pumpAndSettle();
      expect(camera.videoEnabled, isFalse);
      expect(camera.previewModes.first, isTrue);
      expect(camera.previewModes.last, isFalse);

      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      await _startAudio(tester);
      expect(setup.startRequests.single.mode, LiveRoomMode.audio);
      expect(camera.publishedWithVideo, isFalse);
      await _leave(tester);
    });

    testWidgets('audio: microphone only, its own setup, sent with the room', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await mode(tester, LiveRoomMode.audio);
      expect(camera.previewModes, [true, false]);
      expect(find.byType(GoLiveAudioSetup), findsOneWidget);
      expect(find.byKey(GoLiveScreen.flipKey), findsNothing);
      expect(find.byKey(GoLiveScreen.beautyKey), findsNothing);
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      // Categories as tiles in the room card.
      await tester.tap(find.byKey(GoLiveScreen.categoryKey('music')));
      // Settings: guests off (signed-in only).
      await tester.tap(find.byKey(GoLiveAudioSetup.settingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveAudioSetup.guestsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_l10n(tester).liveClose).last);
      await tester.pumpAndSettle();
      // Seats (D103, D123): 5 / 10 / 15 / 20 in the sheet (25 is gone); a
      // pick closes it.
      await tester.tap(find.byKey(GoLiveAudioSetup.seatsKey));
      await tester.pumpAndSettle();
      for (final c in [5, 10, 15, 20]) {
        expect(find.byKey(GoLiveKeys.seatCount(c)), findsOneWidget);
      }
      expect(find.byKey(GoLiveKeys.seatCount(6)), findsNothing);
      expect(find.byKey(GoLiveKeys.seatCount(9)), findsNothing);
      expect(find.byKey(GoLiveKeys.seatCount(25)), findsNothing);
      await tester.tap(find.byKey(GoLiveKeys.seatCount(20)));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.seatCount(20)), findsNothing);

      await _startAudio(tester);
      final request = repo.startRequests.single;
      expect(request.mode, LiveRoomMode.audio);
      expect(request.seatCount, 20);
      expect(request.theme, LiveThemes.classic);
      expect(request.categorySlug, 'music');
      expect(request.allowGuests, isFalse);
      // On air: the host and 19 seats in rows.
      expect(find.byKey(AudioSeatRing.seatKey(19)), findsOneWidget);
      expect(find.byKey(AudioSeatRing.seatKey(20)), findsNothing);
      await _leave(tester);
    });

    testWidgets('audio room (D94 reference): the mode pill, the centre '
        'mic, numbered seats and ✕ to end', (tester) async {
      final (repo, camera) = await _pump(tester);
      await mode(tester, LiveRoomMode.audio);
      // The mode tabs: picking LIVE leaves the setup (Multi-guest runs off
      // the edge, as in the reference).
      expect(find.byKey(GoLiveKeys.mode(LiveRoomMode.multi)), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.solo)));
      await tester.pumpAndSettle();
      expect(find.byType(GoLiveAudioSetup), findsNothing);
      await mode(tester, LiveRoomMode.audio);

      repo.viewerList = [
        LiveViewer(
          kind: LiveViewerKind.user,
          user: const UserSummary(
            id: 'u-huda',
            username: 'huda',
            displayName: 'Huda',
            avatarUrl: null,
          ),
          guestNumber: null,
          joinedAt: DateTime.utc(2026, 10, 23),
        ),
      ];
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      final startSemantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(GoLiveScreen.startKey))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      startSemantics.dispose();
      await _startAudio(tester);
      final l10n = _l10n(tester);
      // Who is watching, from GET /viewers: the avatar and the count.
      expect(
        find.descendant(
          of: find.byKey(GoLiveScreen.viewersKey),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // Tapping who is watching: the viewers sheet with Viewers / Guests
      // tabs and an invite-to-seat button (owner's reference).
      await tester.tap(find.byKey(GoLiveScreen.viewersKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SeatControlKeys.viewersTab), findsOneWidget);
      expect(find.byKey(SeatControlKeys.guestsTab), findsOneWidget);
      final invite = find.byKey(SeatControlKeys.inviteUser('huda'));
      expect(invite, findsOneWidget);
      await tester.tap(invite);
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatInvited), findsOneWidget);
      // Tapping the person: their card, with the host's tools (points,
      // kick, chat mute, make moderator, ⋯) and Invite.
      await tester.tap(find.byKey(SeatControlKeys.moderatorUser('huda')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
      expect(find.byKey(const Key('room.userCard.manage')), findsNothing);
      for (final key in [
        LivePersonToolKeys.points,
        LivePersonToolKeys.kick,
        LivePersonToolKeys.mute,
        LivePersonToolKeys.admin,
        LivePersonToolKeys.more,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      // Make moderator from the card: the API, then the button flips.
      await tester.tap(find.byKey(LivePersonToolKeys.admin));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('addModerator:huda'));
      expect(find.byTooltip(l10n.liveSeatRemoveModerator), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.userCard.invite')), findsOneWidget);
      // The card is at most half the screen: scroll to the button.
      await tester.ensureVisible(find.byKey(const Key('room.userCard.invite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('room.userCard.invite')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsNothing);
      expect(
        repo.seatCalls.where((c) => c.startsWith('inviteToSeat')),
        hasLength(2),
      );
      await tester.tap(find.byKey(SeatControlKeys.guestsTab));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatGuestsEmpty), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.liveClose).last);
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      // The host's seat ("Host"), then numbered empty seats with +.
      expect(find.bySemanticsLabel(RegExp(l10n.goLiveHostTag)), findsOneWidget);
      expect(find.byKey(AudioSeatRing.seatKey(8)), findsOneWidget);
      // Owner (2026-10-26): no mic button in the bar; the host mutes and
      // unmutes on their own picture. D141: games (in place of the
      // toolbox) and the gift box show.
      expect(find.byKey(GoLiveScreen.micKey), findsNothing);
      expect(find.byKey(GoLiveScreen.audioGamesKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.audioGiftKey), findsOneWidget);
      // CP-020: the host's gift panel (to people on the mic; the catalogue
      // is empty here, as in production today).
      await tester.tap(find.byKey(GoLiveScreen.audioGiftKey));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGiftSheet), findsOneWidget);
      expect(find.text(l10n.liveGiftEmptyTitle), findsOneWidget);
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGiftSheet), findsNothing);
      // Owner (2026-10-26): a tap on the host's own picture opens their
      // card (no mute); the mic button on that card mutes and unmutes.
      await tester.tap(find.byKey(AudioSeatRing.seatKey(0)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
      expect(camera.micEnabled, isTrue);
      final selfMic = find.byKey(LivePersonToolKeys.selfMic);
      expect(selfMic, findsOneWidget);
      expect(find.byTooltip(l10n.goLiveMuteMic), findsOneWidget);
      await tester.tap(selfMic);
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      expect(find.byTooltip(l10n.goLiveUnmuteMic), findsOneWidget);
      await tester.tap(selfMic);
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isTrue);
      await tester.tap(selfMic);
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      // Close the card (a tap outside it).
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsNothing);
      // Share copies the live's invite (no public link exists yet).
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(GoLiveScreen.shareKey));
      await tester.pump();
      expect(copied, contains('Voices'));
      expect(find.text(l10n.goLiveShareCopied), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      // The seat button (owner, 2026-10-26): the room's people on the Guests
      // tab, the request first with Accept; accepting it takes it away.
      repo.pendingSeatRequests = [
        LiveSeatRequest(
          id: 'req-1',
          user: const UserSummary(
            id: 'u-huda',
            username: 'huda',
            displayName: 'Huda',
            avatarUrl: null,
          ),
          seatIndex: null,
          createdAt: DateTime.utc(2026, 10, 23),
        ),
      ];
      await tester.tap(find.byKey(GoLiveKeys.tool('requests')));
      await tester.pumpAndSettle();
      expect(find.byKey(SeatControlKeys.guestsTab), findsOneWidget);
      expect(find.textContaining('Huda'), findsOneWidget);
      // Full width (it showed as a small box, owner 2026-10-26).
      expect(
        tester.getSize(find.byType(BottomSheet)).width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      await tester.tap(find.byKey(SeatControlKeys.accept('req-1')));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('acceptSeatRequest:req-1:'));
      expect(find.byKey(SeatControlKeys.accept('req-1')), findsNothing);
      await tester.tap(find.byTooltip(l10n.liveClose).last);
      await tester.pumpAndSettle();
      expect(find.byKey(SeatControlKeys.guestsTab), findsNothing);
      // CP-012: the score replaces @username once there are points; the
      // room bar opens the breakdown.
      expect(find.byKey(LiveAudioRoomHeader.scoreKey), findsNothing);
      camera
        ..scoreNow = 12400
        ..ping();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(LiveAudioRoomHeader.scoreKey),
          matching: find.text('12.4K'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LiveAudioRoomHeader.scoreKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveScoreTitle), findsOneWidget);
      expect(find.text(l10n.liveScoreTaps), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // PK is not in the contract yet: the button says so.
      await tester.tap(find.byKey(GoLiveScreen.audioPkKey));
      await tester.pump();
      expect(find.text(l10n.goLivePkSoon), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      // The mixer holds seats, guests, the chat switch (CP-013) and theme.
      await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.tool('seats')), findsOneWidget);
      expect(find.byKey(GoLiveScreen.liveGuestsKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.themeKey), findsOneWidget);
      expect(find.text(l10n.liveChatTool), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.tool('chat')));
      await tester.pumpAndSettle();
      expect(repo.chatCalls, contains('enabled:false'));
      expect(find.text(l10n.liveChatTurnedOff), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      // The sheet closed with the choice.
      expect(find.byKey(GoLiveKeys.tool('chat')), findsNothing);
      // The tools sheet (owner's reference): room tools and other tools;
      // voice settings work while live.
      await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveToolsRoom), findsOneWidget);
      expect(find.text(l10n.liveToolsOther), findsOneWidget);
      expect(find.byKey(GoLiveKeys.tool('viewers')), findsOneWidget);
      // Chat is off: the tool says so to screen readers (no extra text on
      // screen, as in the reference).
      expect(
        find.bySemanticsLabel('${l10n.liveChatTool}, ${l10n.liveToolOff}'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(GoLiveKeys.tool('voice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('liveVoice.noise')));
      await tester.pumpAndSettle();
      expect(camera.voice.noiseReduction, isFalse);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // 💬 opens the chat box in place of the buttons; the host's message
      // goes to the room chat (CP-013) and shows in the room. (D135: the
      // rules line is the first line of the visit.)
      expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.audioChatKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.audioChatKey), findsNothing);
      await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hello');
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      expect(repo.chatCalls, contains('send:Hello'));
      expect(
        find.descendant(
          of: find.byKey(LiveRoomChatLines.listKey),
          matching: find.textContaining('Hello', findRichText: true),
        ),
        findsOneWidget,
      );
      // The field empties at once.
      expect(
        tester
            .widget<TextField>(find.byKey(LiveChatComposer.fieldKey))
            .controller!
            .text,
        isEmpty,
      );
      // A tap outside closes it (an empty spot: the host's picture in the
      // middle opens their card); the buttons are back.
      await tester.tapAt(const Offset(4, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveChatComposer.fieldKey), findsNothing);
      expect(find.byKey(GoLiveScreen.audioChatKey), findsOneWidget);
      // Screen readers (and the web's semantics layer) can press every
      // room button: each offers the tap action (regression, real web run).
      final handle = tester.ensureSemantics();
      for (final key in [
        AudioSeatRing.seatKey(0),
        GoLiveScreen.audioGamesKey,
        GoLiveScreen.audioGiftKey,
        GoLiveScreen.closeKey,
        GoLiveScreen.minimizeKey,
        GoLiveScreen.shareKey,
        GoLiveScreen.audioMoreKey,
        GoLiveScreen.audioChatKey,
        GoLiveScreen.audioPkKey,
        GoLiveKeys.tool('requests'),
      ]) {
        expect(
          tester
              .getSemantics(
                find
                    .descendant(
                      of: find.byKey(key),
                      matching: find.byType(GestureDetector),
                    )
                    .first,
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
          reason: '$key',
        );
      }
      handle.dispose();
      // ✕ at the top asks first, then ends.
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, isEmpty);
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      await _leave(tester);
    });

    testWidgets('audio: noise reduction and voice enhancement reach the mic', (
      tester,
    ) async {
      final (_, camera) = await _pump(tester);
      await mode(tester, LiveRoomMode.audio);
      // The voice tool's sheet: microphone, noise reduction, enhancement.
      await tester.tap(find.byKey(GoLiveAudioSetup.voiceKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveAudioSetup.noiseKey));
      await tester.pumpAndSettle();
      expect(camera.voice, (noiseReduction: false, enhance: true));
      await tester.tap(find.byKey(GoLiveAudioSetup.enhanceKey));
      await tester.pumpAndSettle();
      expect(camera.voice, (noiseReduction: false, enhance: false));
      await tester.tap(find.byKey(GoLiveAudioSetup.micKey));
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      await _leave(tester);
    });

    testWidgets('D138: the host plays an emoji once on their own tile '
        '(≡ → Emoji on my seat)', (tester) async {
      final (repo, _) = await _pump(tester);
      await mode(tester, LiveRoomMode.audio);
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      await _startAudio(tester);
      await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.tool('seatEmoji')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(SeatEmojiSheet.panelKey), findsOneWidget);
      await tester.tap(
        find.byKey(EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.lulu))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find.byKey(EmojiPanel.packKey(KabsoEmoji.byKey('lulu_rainbow')!)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.seatEmojiCalls, [':lulu_rainbow:']);
      final burst = find.descendant(
        of: find.byKey(AudioSeatRing.seatKey(0)),
        matching: find.byType(SeatEmojiBurst),
      );
      expect(burst, findsOneWidget);
      // Once: gone after its cycle and the fade.
      await tester.pumpAndSettle();
      expect(burst, findsNothing);
      await _leave(tester);
    });

    testWidgets('multi-guest: seats, theme, and the seats on air', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await mode(tester, LiveRoomMode.multi);
      expect(camera.previewModes, [true]);
      expect(find.byKey(VideoSeatGrid.seatKey(5)), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.seatCount(9)));
      await tester.pumpAndSettle();
      expect(find.byKey(VideoSeatGrid.seatKey(8)), findsOneWidget);

      await tester.tap(find.byKey(GoLiveScreen.themeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.theme('ice-palace')));
      await tester.pumpAndSettle();

      await _goLive(tester);
      final request = repo.startRequests.single;
      expect(request.mode, LiveRoomMode.multi);
      expect(request.seatCount, 9);
      expect(request.theme, 'ice-palace');

      // A guest takes seat 1 on the server; the grid shows them.
      repo.seatState = repo.seatState!.copyWith(
        version: 1,
        seats: [
          for (final seat in repo.seatState!.seats)
            if (seat.index == 1)
              seat.copyWith(
                state: LiveSeatState.taken,
                user: const UserSummary(
                  id: 'u-omar',
                  username: 'omar',
                  displayName: 'Omar',
                  avatarUrl: null,
                ),
              )
            else
              seat,
        ],
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Omar'), findsOneWidget);
      expect(repo.seatCalls, contains('seats'));
      await _leave(tester);
    });

    testWidgets('the mode cannot change once live', (tester) async {
      await _pump(tester);
      await _goLive(tester);
      expect(find.byType(GoLiveModePager), findsNothing);
      await _leave(tester);
    });
  });

  group('beauty (D94)', () {
    testWidgets('on, smoothing and brightening reach the camera', (
      tester,
    ) async {
      final (_, camera) = await _pump(tester);
      await tester.tap(find.byKey(GoLiveScreen.beautyKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.beautySwitch));
      await tester.pumpAndSettle();
      expect(camera.beauty.enabled, isTrue);
      await tester.drag(
        find.byKey(GoLiveKeys.beautySmooth),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      expect(camera.beauty.smooth, greaterThan(0.5));
      await _leave(tester);
    });

    testWidgets('not supported: says so and stays off', (tester) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()..supportsBeauty = false,
      );
      await tester.tap(find.byKey(GoLiveScreen.beautyKey));
      await tester.pumpAndSettle();
      expect(find.text(_l10n(tester).goLiveBeautyUnsupported), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.beautySwitch));
      await tester.pumpAndSettle();
      expect(camera.beauty.enabled, isFalse);
      await _leave(tester);
    });
  });

  testWidgets('Arabic RTL: close at the end (left), tools start at the right', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final close = tester.getCenter(find.byKey(GoLiveScreen.closeKey));
    final flip = tester.getCenter(find.byKey(GoLiveScreen.flipKey));
    final mic = tester.getCenter(find.byKey(GoLiveScreen.micKey));
    expect(close.dx, lessThan(width / 2));
    expect(flip.dx, greaterThan(mic.dx));
    expect(find.text('ابدأ البث'), findsOneWidget);
    expect(find.text('بث مباشر'), findsOneWidget);
    await _leave(tester);
  });

  group('Create mode bar', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, _) => Scaffold(
              body: Center(
                child: CreateModeBar(
                  selected: CreateMode.post,
                  onSelect: (mode) => switch (mode) {
                    CreateMode.post => null,
                    CreateMode.story => context.push(AppRoutes.newStory),
                    CreateMode.live => context.push(AppRoutes.goLive),
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.goLive,
            builder: (_, _) => const Text('go-live'),
          ),
          GoRoute(
            path: AppRoutes.newStory,
            builder: (_, _) => const Text('new-story'),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: AppLanguage.en.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildAppTheme(
            brightness: Brightness.dark,
            locale: AppLanguage.en.locale,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('LIVE opens go live, Story opens a new story', (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.byKey(CreateModeBar.modeKey(CreateMode.live)));
      await tester.pumpAndSettle();
      expect(find.text('go-live'), findsOneWidget);
    });

    testWidgets('Story opens a new story', (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.byKey(CreateModeBar.modeKey(CreateMode.story)));
      await tester.pumpAndSettle();
      expect(find.text('new-story'), findsOneWidget);
    });

    testWidgets('the selected mode is marked for screen readers', (
      tester,
    ) async {
      await pumpRouter(tester);
      final post = tester.getSemantics(
        find.byKey(CreateModeBar.modeKey(CreateMode.post)),
      );
      expect(post.flagsCollection.isSelected, Tristate.isTrue);
    });
  });

  group('minimize (D94)', () {
    Future<(FakeLiveRepository, FakeLiveMediaEngine, GoRouter)> pumpApp(
      WidgetTester tester,
    ) async {
      final repo = FakeLiveRepository(categories: _categories);
      final camera = FakeLiveMediaEngine();
      final prefs = await testPrefs();
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(path: '/start', builder: (_, _) => const Text('home')),
          GoRoute(
            path: AppRoutes.goLive,
            builder: (_, _) => const GoLiveScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      setViewport(tester, GoldenViewport.phone);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            liveRepositoryProvider.overrideWithValue(repo),
            liveMediaEngineProvider.overrideWithValue(() => camera),
            currentUserProvider.overrideWithValue(
              testUser().copyWith(canHost: true),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.dark,
              locale: AppLanguage.en.locale,
            ),
            builder: (context, child) => Stack(
              children: [
                child!,
                LiveMiniWindow(router: router),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.goLive));
      await tester.pumpAndSettle();
      await _goLive(tester);
      return (repo, camera, router);
    }

    testWidgets('minimize: the live goes on in a floating window', (
      tester,
    ) async {
      final (repo, camera, _) = await pumpApp(tester);
      // D135: minimize is in ≡ (Room Tools).
      await tester.tap(find.byKey(KHostBar.toolsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.tool('minimize')));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(GoLiveScreen), findsNothing);
      expect(find.byKey(LiveMiniWindow.windowKey), findsOneWidget);
      // Still on air: no end, heartbeats go on, the camera still runs.
      expect(repo.endRequests, isEmpty);
      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, ['room-host']);
      expect(camera.running, isTrue);

      // A tap opens the same live full screen.
      await tester.tap(find.byKey(LiveMiniWindow.windowKey));
      await tester.pumpAndSettle();
      expect(find.byType(GoLiveScreen), findsOneWidget);
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
      expect(find.byKey(LiveMiniWindow.windowKey), findsNothing);
      expect(camera.previewStarts, 1);
      expect(repo.startRequests, hasLength(1));
      await _leave(tester);
    });

    testWidgets('system back while live minimizes too', (tester) async {
      final (repo, _, _) = await pumpApp(tester);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMiniWindow.windowKey), findsOneWidget);
      expect(repo.endRequests, isEmpty);
      await _leave(tester);
    });

    testWidgets('ending from ✕ removes the floating window for good', (
      tester,
    ) async {
      final (repo, _, _) = await pumpApp(tester);
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(find.byKey(KHostBar.toolsKey), findsNothing);
      expect(find.byKey(LiveMiniWindow.windowKey), findsNothing);
      await _leave(tester);
    });
  });

  group('host taps (owner, 2026-10-26: "the host cannot tap")', () {
    const huda = UserSummary(
      id: 'u-huda',
      username: 'huda',
      displayName: 'Huda',
      avatarUrl: null,
    );

    /// Audio on [theme] (the default 10 seats), Huda on seat 2.
    Future<(FakeLiveRepository, FakeLiveMediaEngine)> hostRoom(
      WidgetTester tester, {
      String theme = LiveThemes.classic,
      AppLanguage language = AppLanguage.en,
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final (repo, camera) = await _pump(
        tester,
        language: language,
        viewport: viewport,
      );
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      await ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
          .read(liveHostControllerProvider.notifier)
          .setTheme(theme);
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      await _startAudio(tester);
      final seats = repo.seatState!;
      repo.seatState = seats.copyWith(
        version: seats.version + 1,
        seats: [
          for (final s in seats.seats)
            if (s.index == 2)
              const LiveSeat(index: 2, state: LiveSeatState.taken, user: huda)
            else
              s,
        ],
      );
      camera
        ..version = 1
        ..ping();
      await tester.pumpAndSettle();
      return (repo, camera);
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
    }

    // The owner's phone: 360 × 800, Arabic, the ice palace.
    for (final (theme, language, viewport) in [
      (LiveThemes.classic, AppLanguage.en, GoldenViewport.phone),
      ('ice-palace', AppLanguage.ar, GoldenViewport.android),
      ('galaxy', AppLanguage.en, GoldenViewport.android),
    ]) {
      testWidgets('$theme, ${language.name}, ${viewport.name}: the host taps '
          'their picture, a guest, an empty seat and every bottom button', (
        tester,
      ) async {
        final (repo, camera) = await hostRoom(
          tester,
          theme: theme,
          language: language,
          viewport: viewport,
        );
        final l10n = _l10n(tester);
        // The default room (D118): 10 tiles, so seats 1 … 9.
        expect(repo.startRequests.single.seatCount, 10);
        expect(find.byKey(AudioSeatRing.seatKey(9)), findsOneWidget);
        expect(find.byKey(AudioSeatRing.seatKey(10)), findsNothing);
        // Nothing over the room takes the taps: each tile is the widget hit
        // at its centre.
        for (final i in [0, 1, 2, 5, 9]) {
          final seat = find.byKey(AudioSeatRing.seatKey(i));
          final hit = tester.hitTestOnBinding(tester.getCenter(seat));
          // The first render object hit is inside the seat.
          final first = hit.path
              .map((e) => e.target)
              .whereType<RenderObject>()
              .first;
          expect(
            _isDescendant(tester.renderObject(seat), first),
            isTrue,
            reason: 'seat $i is hit first',
          );
        }
        // The host's own picture: their card with the mic.
        await tester.tap(find.byKey(AudioSeatRing.seatKey(0)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
        await tester.tap(find.byKey(LivePersonToolKeys.selfMic));
        await tester.pumpAndSettle();
        expect(camera.micEnabled, isFalse);
        await closeSheet(tester);
        // A guest: the seat's actions (mute, remove, moderator).
        await tester.tap(find.byKey(AudioSeatRing.seatKey(2)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.liveSeatRemove), findsOneWidget);
        await tester.tap(find.byKey(SeatControlKeys.cancel));
        await tester.pumpAndSettle();
        // An empty seat: invite and lock.
        await tester.tap(find.byKey(AudioSeatRing.seatKey(5)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.liveSeatLock), findsOneWidget);
        expect(find.text(l10n.liveSeatInvite), findsOneWidget);
        await tester.tap(find.byKey(SeatControlKeys.cancel));
        await tester.pumpAndSettle();
        // With the chat box open, a seat still answers (and the box
        // closes).
        await tester.tap(find.byKey(GoLiveScreen.audioChatKey));
        await tester.pumpAndSettle();
        expect(find.byType(LiveRoomComposer), findsOneWidget);
        await tester.tap(find.byKey(AudioSeatRing.seatKey(9)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.liveSeatLock), findsOneWidget);
        await tester.tap(find.byKey(SeatControlKeys.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(LiveRoomComposer), findsNothing);
        // The bottom bar.
        await tester.tap(find.byKey(GoLiveKeys.tool('requests')));
        await tester.pumpAndSettle();
        expect(find.byKey(SeatControlKeys.guestsTab), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.liveClose).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(GoLiveScreen.audioGiftKey));
        await tester.pumpAndSettle();
        expect(find.byType(KLiveGiftSheet), findsOneWidget);
        await closeSheet(tester);
        await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
        await tester.pumpAndSettle();
        expect(find.byKey(GoLiveKeys.tool('seats')), findsOneWidget);
        await closeSheet(tester);
        // D141: games are not there yet — the button says so, no list.
        await tester.tap(find.byKey(GoLiveScreen.audioGamesKey));
        await tester.pump();
        expect(find.text(l10n.liveGamesSoon), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(GoLiveScreen.audioPkKey));
        await tester.pump();
        expect(find.text(l10n.goLivePkSoon), findsOneWidget);
        await _leave(tester);
      });
    }

    testWidgets('the seats could not be read: a tap on a seat reads them '
        'again and opens its actions, or says why (never nothing)', (
      tester,
    ) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      repo.seatFailure = _internal;
      await _startAudio(tester);
      // The room still shows its 10 tiles (from the room itself).
      expect(find.byKey(AudioSeatRing.seatKey(9)), findsOneWidget);
      await tester.tap(find.byKey(AudioSeatRing.seatKey(5)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatLock), findsNothing);
      expect(find.text(failureMessage(l10n, _internal)), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      repo.seatFailure = null;
      await tester.tap(find.byKey(AudioSeatRing.seatKey(5)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatLock), findsOneWidget);
      await tester.tap(find.byKey(SeatControlKeys.cancel));
      await tester.pumpAndSettle();
      await _leave(tester);
    });
  });

  group('owner refs 71–75', () {
    Future<void> audioLive(WidgetTester tester, FakeLiveRepository repo) async {
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      await _startAudio(tester);
    }

    for (final audio in [false, true]) {
      testWidgets('D141: ≡ «Live time» is a working host tool '
          '(${audio ? 'audio' : 'video'}): it opens the live schedule, which '
          'adds and removes a slot', (tester) async {
        final schedule = FakeLiveScheduleRepository([
          LiveScheduleSlot(
            id: 'a',
            title: 'Morning chat',
            startsAt: DateTime.now().add(const Duration(hours: 2)),
          ),
        ]);
        final (repo, _) = await _pump(tester, schedule: schedule);
        if (audio) {
          await audioLive(tester, repo);
          await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
          await tester.pumpAndSettle();
        } else {
          await _goLive(tester);
          await _openTools(tester);
        }
        final l10n = _l10n(tester);
        final tool = find.byKey(GoLiveKeys.tool('time'));
        expect(tool, findsOneWidget);
        // No "Soon" any more.
        expect(
          find.bySemanticsLabel('${l10n.liveToolLiveTime}, ${l10n.liveSoon}'),
          findsNothing,
        );
        await tester.ensureVisible(tool);
        await tester.tap(tool);
        await tester.pumpAndSettle();
        expect(find.byKey(LiveScheduleKeys.count), findsOneWidget);
        await tester.tap(find.byKey(LiveScheduleKeys.add));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(LiveScheduleKeys.title),
          'Evening songs',
        );
        await tester.tap(find.byKey(LiveScheduleKeys.pick));
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          final ok = MaterialLocalizations.of(
            tester.element(find.byType(Dialog).last),
          ).okButtonLabel;
          await tester.tap(find.text(ok).last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(LiveScheduleKeys.save));
        await tester.pumpAndSettle();
        expect(schedule.created.single.title, 'Evening songs');
        await tester.tap(find.byKey(LiveScheduleKeys.remove('a')));
        await tester.pumpAndSettle();
        expect(schedule.removed, ['a']);
        await _leave(tester);
      });
    }

    testWidgets('D141: the audio bar uses the owner art — gift and PK as on '
        'the video bar, games (in place of the toolbox) says it is coming, '
        "and the seat button shows the video bar's ∞", (tester) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      await audioLive(tester, repo);
      for (final (key, art) in [
        (GoLiveScreen.audioGiftKey, 'assets/live_bar/bar_gift.png'),
        (GoLiveScreen.audioPkKey, 'assets/live_bar/bar_pk.png'),
        (GoLiveScreen.audioGamesKey, 'assets/live_bar/bar_games.png'),
      ]) {
        final image = tester.widget<Image>(
          find.descendant(of: find.byKey(key), matching: find.byType(Image)),
        );
        expect((image.image as AssetImage).assetName, art);
        expect(image.width, KAudioRoom.barArt);
        expect(tester.getSize(find.byKey(key)).width, greaterThanOrEqualTo(48));
      }
      expect(
        find.descendant(
          of: find.byKey(GoLiveKeys.tool('requests')),
          matching: find.byIcon(Icons.all_inclusive_rounded),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.liveGames), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.audioGamesKey));
      await tester.pump();
      expect(find.text(l10n.liveGamesSoon), findsOneWidget);
      await _snackGone(tester);
      await _leave(tester);
    });

    testWidgets('setup Settings (ref 71): Share copies the invitation; the '
        'features without a server are greyed "Soon"', (tester) async {
      await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveAudioSetup.settingsKey));
      await tester.pumpAndSettle();
      for (final label in [
        l10n.liveSettingsEventCenter,
        l10n.liveSettingsCreatorCenter,
      ]) {
        expect(
          find.bySemanticsLabel('$label, ${l10n.liveSoon}'),
          findsOneWidget,
        );
      }
      // CP-016 C: the live schedule has its server now (not "Soon").
      expect(find.text(l10n.liveSoon), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('${l10n.liveSettingsSchedule}, ${l10n.liveSoon}'),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(LiveSettingsRow.scheduleKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveSettingsRow.scheduleKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveScheduleEmpty), findsOneWidget);
      Navigator.of(tester.element(find.byKey(LiveScheduleKeys.count))).pop();
      await tester.pumpAndSettle();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(LiveSettingsRow.shareKey));
      await tester.pumpAndSettle();
      expect(copied, isNotNull);
      expect(find.text(l10n.goLiveShareCopied), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('room info (ref 73): title, tag and announcement go to '
        'PATCH; level and boost wait ("Soon")', (tester) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      await audioLive(tester, repo);
      // The card's cover (D141: its @username copies instead).
      await tester.tap(
        find
            .descendant(
              of: find.byKey(LiveAudioRoomHeader.barKey),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomInfoKeys.sheet), findsOneWidget);
      expect(find.text(l10n.liveRoomInfoChange), findsOneWidget);
      expect(find.text(l10n.liveRoomNoTag), findsOneWidget);
      expect(
        find.bySemanticsLabel('${l10n.liveRoomLevel}, ${l10n.liveSoon}'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('${l10n.liveRoomBoost}, ${l10n.liveSoon}'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(LiveRoomInfoKeys.editTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(LiveRoomInfoKeys.titleField),
        'Night talk',
      );
      await tester.tap(find.byKey(LiveRoomInfoKeys.save));
      await tester.pumpAndSettle();
      expect(repo.edits.last, (
        title: 'Night talk',
        categorySlug: null,
        topic: null,
      ));
      expect(find.text('Night talk'), findsWidgets);

      await tester.tap(find.byKey(LiveRoomInfoKeys.tag));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveRoomInfoKeys.category('music')));
      await tester.pumpAndSettle();
      expect(repo.edits.last.categorySlug, 'music');
      expect(find.text('Music'), findsOneWidget);

      await tester.tap(find.byKey(LiveRoomInfoKeys.announcement));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(LiveRoomInfoKeys.topicField),
        'Be kind',
      );
      await tester.tap(find.byKey(LiveRoomInfoKeys.save));
      await tester.pumpAndSettle();
      expect(repo.edits.last, (
        title: 'Night talk',
        categorySlug: 'music',
        topic: 'Be kind',
      ));
      expect(find.text('Be kind'), findsOneWidget);

      // Room settings opens the settings sheet.
      await tester.tap(find.byKey(LiveRoomInfoKeys.settings));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveSettingsRow.shareKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('seat sheet (ref 72) has Cancel; the viewers sheet has the '
        'Contribution list (ref 75)', (tester) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      repo
        ..contributorList = [
          const LiveContributor(
            user: UserSummary(
              id: 'u-huda',
              username: 'huda',
              displayName: 'Huda',
              avatarUrl: null,
            ),
            points: 12400,
          ),
        ]
        ..viewerList = [
          LiveViewer(
            kind: LiveViewerKind.user,
            user: const UserSummary(
              id: 'u-huda',
              username: 'huda',
              displayName: 'Huda',
              avatarUrl: null,
            ),
            guestNumber: null,
            joinedAt: DateTime.utc(2026, 10, 24),
          ),
        ];
      await audioLive(tester, repo);
      await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatLock), findsOneWidget);
      await tester.tap(find.byKey(SeatControlKeys.cancel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatLock), findsNothing);

      await tester.tap(find.byKey(GoLiveScreen.viewersKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(SeatControlKeys.contributionTab));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SeatControlKeys.contributionTab));
      await tester.pumpAndSettle();
      expect(repo.contributorCalls, 1);
      expect(find.byKey(SeatControlKeys.contributor('huda')), findsOneWidget);
      expect(find.text('12.4K'), findsOneWidget);
      await _leave(tester);
    });
  });

  group('D131 host video live (owner recording)', () {
    const someone = UserSummary(
      id: 'u-9',
      username: 'mona',
      displayName: 'Mona',
      avatarUrl: null,
    );

    testWidgets('the host pill (cherries, no follow) and the host bar: '
        '💬 ✨ ≡ … ∞ PK 🎁, 48 pt targets; flip and mic are in ≡', (
      tester,
    ) async {
      await _pump(tester);
      await _goLive(tester);
      expect(
        find.descendant(
          of: find.byKey(GoLiveScreen.scoreKey),
          matching: find.byType(KCherryIcon),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(_l10n(tester).liveFollow), findsNothing);
      final keys = [
        GoLiveScreen.videoChatKey,
        KHostBar.beautyKey,
        KHostBar.toolsKey,
        KHostBar.guestsKey,
        KHostBar.pkKey,
        KHostBar.giftKey,
      ];
      double? last;
      for (final key in keys) {
        final r = tester.getRect(find.byKey(key));
        expect(r.width, greaterThanOrEqualTo(48));
        expect(r.height, greaterThanOrEqualTo(48));
        if (last != null) expect(r.left, greaterThanOrEqualTo(last));
        last = r.right;
      }
      expect(find.byKey(GoLiveScreen.flipKey), findsNothing);
      expect(find.byKey(GoLiveScreen.micKey), findsNothing);
      await _leave(tester);
    });

    for (final language in AppLanguage.values) {
      for (final (top, bottom) in [(59.0, 34.0), (24.0, 48.0)]) {
        testWidgets('D135 (${language.name}, insets $top/$bottom): nothing '
            'under the status bar; the second row is board + charm level '
            'with points/target at the start, the timer at the end, the room '
            'ID beside the name; '
            'host quick replies send', (tester) async {
          final pad = FakeViewPadding(top: top * 3, bottom: bottom * 3);
          tester.view
            ..padding = pad
            ..viewPadding = pad;
          final repo = FakeLiveRepository(categories: _categories)
            ..startRoomLevel = 12
            ..startRoomNumber = 120345678;
          await _pump(
            tester,
            language: language,
            repo: repo,
            levels: _Levels(),
          );
          await _goLive(tester);
          final l10n = _l10n(tester);
          final ar = language == AppLanguage.ar;
          // Nothing drawn above the inset: the 48 pt targets of the host
          // pill, ✕ and minimize start at most 8 pt above it, their drawn
          // pill and glyphs below it.
          for (final f in [
            find.byType(KHostPill),
            find.byKey(GoLiveScreen.closeKey),
          ]) {
            expect(tester.getRect(f).top + 8, greaterThanOrEqualTo(top));
          }
          // The bar above the bottom inset.
          expect(
            tester.getRect(find.byKey(KHostBar.giftKey)).bottom,
            lessThanOrEqualTo(852 - bottom + 0.5),
          );
          // The level chip: the charm badge and 3,510/5,000, right after
          // the board chip; no other charm level chip on the screen.
          final chip = find.byKey(KRoomChipsRow.levelKey);
          expect(chip, findsOneWidget);
          expect(
            find.descendant(of: chip, matching: find.byType(CharmLevelBadge)),
            findsOneWidget,
          );
          expect(find.byType(CharmLevelBadge), findsOneWidget);
          expect(
            find.descendant(of: chip, matching: find.textContaining('/')),
            findsOneWidget,
          );
          final rank = tester.getRect(find.byType(LiveRankChip));
          final level = tester.getRect(chip);
          final timer = tester.getRect(find.byKey(GoLiveScreen.elapsedKey));
          if (ar) {
            expect(rank.left, greaterThan(level.right - 0.5));
            expect(level.left, greaterThan(timer.right));
          } else {
            expect(level.left, greaterThan(rank.right - 0.5));
            expect(timer.left, greaterThan(level.right));
          }
          // D141: the host's @username beside the name, in the host pill
          // (not the room number); a tap copies it.
          expect(
            find.descendant(
              of: find.byType(KHostPill),
              matching: find.byKey(KLiveUsernameTag.tagKey),
            ),
            findsOneWidget,
          );
          expect(find.byKey(KRoomChipsRow.numberKey), findsNothing);
          // No minimize at the top (D135: it is in ≡).
          expect(find.byKey(GoLiveScreen.minimizeKey), findsNothing);
          // The owner's colourful PK and gift art, 33 pt, 48 pt targets.
          for (final (key, art) in [
            (KHostBar.pkKey, 'assets/live_bar/bar_pk.png'),
            (KHostBar.giftKey, 'assets/live_bar/bar_gift.png'),
          ]) {
            final image = tester.widget<Image>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(Image),
              ),
            );
            expect((image.image as AssetImage).assetName, art);
            expect(image.width, KViewerBarButton.artSize);
            expect(
              tester.getSize(find.byKey(key)).width,
              greaterThanOrEqualTo(48),
            );
          }
          // Host quick replies: one tap sends it as a chat message.
          final replies = find.byKey(GoLiveScreen.hostQuickRepliesKey);
          expect(replies, findsOneWidget);
          await tester.tap(find.byKey(KQuickReplies.chipKey(0)));
          await tester.pumpAndSettle();
          expect(repo.chatCalls, contains('send:${l10n.liveQuickHostWelcome}'));
          await _leave(tester);
        });
      }
    }

    testWidgets('D136: the host sets the wish list in ≡ (up to 4, ordered); '
        'the card shows it and a tap on it opens the list again; D135: '
        'minimize is in ≡', (tester) async {
      final repo = FakeLiveRepository(categories: _categories);
      await _pump(
        tester,
        repo: repo,
        gifts: FakeLiveGiftRepository(codes: giftFixtureCodes),
      );
      await _goLive(tester);
      expect(find.byKey(GoLiveScreen.minimizeKey), findsNothing);
      await _openTools(tester);
      expect(find.byKey(GoLiveKeys.tool('minimize')), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.tool('wish')));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveWishSheetKeys.sheet), findsOneWidget);
      // D141: the gift panel's category tabs; a gift is on its own tab.
      for (final code in ['rose', 'crown', 'cake', 'confetti', 'lantern']) {
        final gift = find.byKey(LiveWishSheetKeys.gift(code));
        for (final c in GiftCategory.values) {
          if (gift.evaluate().isNotEmpty) break;
          final tab = find.byKey(KLiveGiftSheet.tabKey(c.wire));
          if (tab.evaluate().isEmpty) continue;
          await tester.tap(tab);
          await tester.pump();
        }
        await tester.ensureVisible(gift);
        await tester.tap(gift);
        await tester.pump();
      }
      // The fifth is refused (4 at most); crown moves first; cake removed.
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byKey(LiveWishSheetKeys.earlier('crown')));
      await tester.pump();
      await tester.tap(find.byKey(LiveWishSheetKeys.remove('cake')));
      await tester.pump();
      await tester.tap(find.byKey(LiveWishSheetKeys.save));
      await tester.pumpAndSettle();
      expect(repo.wishUpdates, [
        ['crown', 'rose', 'confetti'],
      ]);
      expect(find.byKey(LiveWishSheetKeys.sheet), findsNothing);
      expect(find.byKey(LiveWishCard.cardKey), findsOneWidget);
      expect(find.byKey(LiveWishCard.rowKey('crown')), findsOneWidget);
      await tester.tap(find.byKey(LiveWishCard.cardKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveWishSheetKeys.sheet), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('≡ keeps every tool: flip and mic work; the missing ones say '
        'Soon', (tester) async {
      final (_, camera) = await _pump(tester);
      await _goLive(tester);
      await _openTools(tester);
      for (final id in [
        'share',
        'flip',
        'mic',
        'beauty',
        'voice',
        'topic',
        'viewers',
        'chat',
        'management',
        'guests',
        // D143: Fill light replaces the "Flash" that said Soon.
        'fillLight',
        // D154a/D154b: the soundboard and the traffic card work now.
        'sounds',
        'traffic',
        // D154e: the program list works now.
        'program',
      ]) {
        expect(find.byKey(GoLiveKeys.tool(id)), findsOneWidget, reason: id);
      }
      final l10n = _l10n(tester);
      for (final label in [
        l10n.liveToolSounds,
        l10n.liveToolTrafficCard,
        l10n.liveToolProgramList,
      ]) {
        expect(
          find.bySemanticsLabel('$label, ${l10n.liveSoon}'),
          findsNothing,
          reason: label,
        );
      }
      for (final label in [
        l10n.liveToolDual,
        l10n.liveToolHd,
        l10n.liveToolSticker,
      ]) {
        expect(
          find.bySemanticsLabel('$label, ${l10n.liveSoon}'),
          findsOneWidget,
          reason: label,
        );
      }
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      expect(camera.flips, 1);
      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveScreen.micKey));
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      // Muted: the host pill says so.
      expect(find.byKey(GoLiveScreen.micOffKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('D154e: the host sets the program from ≡; its card shows '
        'in the live', (tester) async {
      await _pump(tester);
      await _goLive(tester);
      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('program')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(LiveProgramEditor.titleKey(0)),
        'Opening',
      );
      await tester.tap(find.byKey(LiveProgramEditor.saveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveProgramEditor.saveKey), findsNothing);
      expect(find.byKey(LiveProgramCard.cardKey), findsOneWidget);
      expect(find.text('Opening'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('PK and (solo) guest connection say they are coming; 🎁 '
        'opens the gifts', (tester) async {
      await _pump(tester);
      await _goLive(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(KHostBar.pkKey));
      await tester.pump();
      expect(find.text(l10n.goLivePkSoon), findsOneWidget);
      await _snackGone(tester);
      await tester.tap(find.byKey(KHostBar.guestsKey));
      await tester.pump();
      expect(find.text(l10n.liveHostGuestsSoon), findsOneWidget);
      await _snackGone(tester);
      await tester.tap(find.byKey(KHostBar.giftKey));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGiftSheet), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('Beautification: Beauty, Magic, Fill light and Mixer all '
        'work (D143: no longer Soon)', (tester) async {
      await _pump(tester);
      await _goLive(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(KHostBar.beautyKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveBeautyToolsTitle), findsOneWidget);
      for (final label in [l10n.liveToolMagic, l10n.liveToolFillLight]) {
        expect(
          find.bySemanticsLabel('$label, ${l10n.liveSoon}'),
          findsNothing,
          reason: label,
        );
      }
      expect(find.byKey(GoLiveKeys.tool('magic')), findsOneWidget);
      expect(find.byKey(GoLiveKeys.tool('fillLight')), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.tool('mixer')));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.tool('mixer')), findsNothing);
      expect(find.byType(Switch), findsWidgets);
      await _leave(tester);
    });

    testWidgets('User management: muted, removed, moderators (solo: how), '
        'and signed-in only', (tester) async {
      final repo = FakeLiveRepository(categories: _categories)
        ..chatMuteList = [
          LiveChatMute(user: someone, mutedAt: DateTime.utc(2026, 10, 27)),
        ]
        ..kickList = [
          LiveKick(user: someone, kickedAt: DateTime.utc(2026, 10, 27)),
        ];
      await _pump(tester, repo: repo);
      await _goLive(tester);
      final l10n = _l10n(tester);
      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('management')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveManageTitle), findsOneWidget);
      expect(find.text(l10n.liveManageModeratorsHint), findsOneWidget);
      await tester.tap(find.byKey(LiveManageKeys.muted));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveManageKeys.action('mona')));
      await tester.pumpAndSettle();
      expect(repo.chatCalls, contains('unmute:mona'));
      await tester.tap(find.byKey(LiveManageKeys.back));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveManageKeys.kicked));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveManageKeys.action('mona')));
      await tester.pumpAndSettle();
      expect(repo.kickCalls, contains('unkick:mona'));
      await tester.tap(find.byKey(LiveManageKeys.back));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveManageKeys.signedInOnly));
      await tester.pumpAndSettle();
      expect(repo.guestUpdates, [(roomId: 'room-host', allow: false)]);
      await _leave(tester);
    });

    testWidgets('the end summary: full screen, real data only (time, '
        'cherries from taps and gifts, supporters)', (tester) async {
      final repo = FakeLiveRepository(categories: _categories)
        ..contributorList = [const LiveContributor(user: someone, points: 120)];
      await _pump(tester, repo: repo);
      await _goLive(tester);
      repo.hostRoom = repo.hostRoom!.copyWith(
        score: 1520,
        scoreParts: const LiveScore(
          total: 1520,
          tapPoints: 20,
          supportPoints: 1500,
        ),
      );
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(find.byType(GoLiveSummary), findsOneWidget);
      // D140: the summary takes the whole screen, from the live's statistics.
      final view = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getSize(find.byType(GoLiveSummary)), view);
      expect(tester.getTopLeft(find.byType(GoLiveSummary)), Offset.zero);
      expect(repo.statsCalls, 1);
      expect(find.text('1,520'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(GoLiveSummary.tapsKey),
          matching: find.textContaining('20'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(GoLiveSummary.giftsKey),
          matching: find.textContaining('1,500'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(GoLiveSummary.supportersKey),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(GoLiveScreen.doneKey), findsOneWidget);
      await _leave(tester);
    });
  });

  group('D143 fill light, Magic colour filters, audio-room management', () {
    final frame = find.byKey(LiveFillLightFrame.frameKey);
    final fillLight = find.byKey(GoLiveKeys.tool('fillLight'));

    Future<void> toggleFillLight(WidgetTester tester) async {
      await tester.ensureVisible(fillLight);
      await tester.tap(fillLight);
      await tester.pumpAndSettle();
    }

    GoLiveState hostState(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
            .read(liveHostControllerProvider);

    Future<void> pickLevel(WidgetTester tester, LiveFillLight level) async {
      await tester.tap(find.byKey(GoLiveKeys.fillLightLevel(level)));
      await tester.pumpAndSettle();
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }

    testWidgets('D157 front camera: a level sheet; the soft light goes on '
        'the published picture (no frame, no torch); kept into the live', (
      tester,
    ) async {
      final (_, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      expect(frame, findsNothing);
      await toggleFillLight(tester);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l10n.liveFillLightTitle),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(GoLiveKeys.fillLightNote)).data,
        l10n.liveFillLightOnPicture,
      );
      for (final l in LiveFillLight.values) {
        expect(find.byKey(GoLiveKeys.fillLightLevel(l)), findsOneWidget);
      }
      expect(hostState(tester).fillLight, isFalse, reason: 'opens off');
      await pickLevel(tester, LiveFillLight.medium);
      expect(camera.beauty.light, LiveFillLight.medium);
      expect(hostState(tester).fillLight, isTrue);
      await pickLevel(tester, LiveFillLight.high);
      expect(camera.beauty.light, LiveFillLight.high);
      expect(hostState(tester).fillLightLevel, LiveFillLight.high);
      await closeSheet(tester);
      expect(frame, findsNothing, reason: 'the picture itself is lit');
      expect(camera.torchCalls, isEmpty);
      // Magic keeps the light (one colour stage: light, then filter).
      await ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
          .read(liveHostControllerProvider.notifier)
          .setColorFilter(LiveColorFilter.warm);
      expect(camera.beauty.filter, LiveColorFilter.warm);
      expect(camera.beauty.light, LiveFillLight.high);
      await _goLive(tester);
      expect(camera.beauty.light, LiveFillLight.high, reason: 'remembered');
      await _openTools(tester);
      await toggleFillLight(tester);
      await pickLevel(tester, LiveFillLight.off);
      expect(camera.beauty.light, LiveFillLight.off);
      expect(camera.beauty.filter, LiveColorFilter.warm);
      expect(hostState(tester).fillLight, isFalse);
      await closeSheet(tester);
      await _leave(tester);
    });

    testWidgets('D157 Arabic: the sheet reads right to left', (tester) async {
      await _pump(tester, language: AppLanguage.ar);
      await toggleFillLight(tester);
      final l10n = _l10n(tester);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('الإضاءة'),
        ),
        findsOneWidget,
      );
      expect(l10n.liveFillLightLow, 'خفيفة');
      final off = tester.getCenter(
        find.byKey(GoLiveKeys.fillLightLevel(LiveFillLight.off)),
      );
      final high = tester.getCenter(
        find.byKey(GoLiveKeys.fillLightLevel(LiveFillLight.high)),
      );
      expect(off.dx, greaterThan(high.dx), reason: 'Off first, on the right');
      await closeSheet(tester);
      await _leave(tester);
    });

    testWidgets('D157 no camera pipeline: only a thin, faint glow at the very '
        'edges, and the sheet says the broadcast is unchanged', (tester) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()..supportsFilters = false,
      );
      await toggleFillLight(tester);
      expect(
        tester.widget<Text>(find.byKey(GoLiveKeys.fillLightNote)).data,
        _l10n(tester).liveFillLightScreenOnly,
      );
      await pickLevel(tester, LiveFillLight.high);
      await closeSheet(tester);
      expect(frame, findsOneWidget);
      final width = tester.getSize(frame).width;
      expect(LiveFillLightFrame.edgeWidth(width), lessThanOrEqualTo(14));
      expect(
        LiveFillLightFrame.edgeWidth(width) / width,
        lessThanOrEqualTo(0.04),
      );
      expect(
        LiveFillLightFrame.edgeOpacity(LiveFillLight.high),
        lessThanOrEqualTo(0.45),
      );
      expect(
        find.ancestor(of: frame, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      expect(camera.torchCalls, isEmpty);
      await _leave(tester);
    });

    testWidgets('back camera: the real torch; it follows the camera flips', (
      tester,
    ) async {
      final (_, camera) = await _pump(tester);
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      await toggleFillLight(tester);
      expect(camera.torchCalls, [true]);
      expect(frame, findsNothing, reason: 'the torch lights, not the screen');
      expect(camera.beauty.light, LiveFillLight.off);
      // To the front: torch off, the soft light on the picture instead.
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      expect(camera.torchCalls, [true, false]);
      expect(camera.beauty.light, LiveFillLight.medium);
      expect(frame, findsNothing);
      // Back again: the torch comes back on, the picture's light goes off.
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      expect(camera.torchCalls, [true, false, true]);
      expect(camera.beauty.light, LiveFillLight.off);
      await toggleFillLight(tester);
      expect(camera.torchCalls, [true, false, true, false]);
      expect(hostState(tester).fillLight, isFalse);
      await _leave(tester);
    });

    testWidgets('a back camera without a torch says so and stays off', (
      tester,
    ) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()..backTorch = false,
      );
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(fillLight);
      await tester.tap(fillLight);
      await tester.pump();
      expect(find.text(_l10n(tester).liveFillLightNoTorch), findsOneWidget);
      expect(camera.torchCalls, isEmpty);
      expect(hostState(tester).fillLight, isFalse);
      expect(frame, findsNothing);
      await _snackGone(tester);
      await _leave(tester);
    });

    testWidgets('reduced motion: the edge glow appears at once', (
      tester,
    ) async {
      await _pump(
        tester,
        engine: FakeLiveMediaEngine()..supportsFilters = false,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await toggleFillLight(tester);
      await pickLevel(tester, LiveFillLight.low);
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: frame, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.duration, Duration.zero);
      await closeSheet(tester);
      await _leave(tester);
    });

    testWidgets('Magic: the picked colour filter reaches the camera '
        'pipeline (published picture) and is marked', (tester) async {
      final (_, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveFilterTitle), findsOneWidget);
      expect(find.byKey(GoLiveKeys.filterUnsupported), findsNothing);
      expect(
        find.byKey(GoLiveKeys.filter(LiveColorFilter.natural)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(GoLiveKeys.filter(LiveColorFilter.warm)));
      await tester.pumpAndSettle();
      expect(camera.beauty.filter, LiveColorFilter.warm);
      await tester.dragUntilVisible(
        find.byKey(GoLiveKeys.filter(LiveColorFilter.soft)),
        find.byKey(GoLiveKeys.filter(LiveColorFilter.warm)),
        const Offset(-100, 0),
      );
      await tester.tap(find.byKey(GoLiveKeys.filter(LiveColorFilter.soft)));
      await tester.pumpAndSettle();
      expect(camera.beauty.filter, LiveColorFilter.soft);
      // Beauty keeps its own settings; the filter rides with them.
      expect(camera.beauty.enabled, isFalse);
      expect(hostState(tester).beauty.filter, LiveColorFilter.soft);
      await _leave(tester);
    });

    testWidgets('Magic where the device cannot publish filters: says why '
        'and changes nothing (no preview-only filter)', (tester) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()..supportsBeauty = false,
      );
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.filterUnsupported), findsOneWidget);
      expect(find.text(_l10n(tester).liveFilterUnsupported), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.filter(LiveColorFilter.mono)));
      await tester.pumpAndSettle();
      expect(camera.beauty.filter, LiveColorFilter.natural);
      await _leave(tester);
    });

    testWidgets('D144 Android: Magic works through the native processor '
        'while Beauty (skin) stays unsupported', (tester) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()
          ..supportsBeauty = false
          ..supportsFilters = true,
      );
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.filterUnsupported), findsNothing);
      // No processor for effects on this platform: no Effects section.
      expect(find.text(_l10n(tester).liveEffectsTitle), findsNothing);
      expect(find.byKey(GoLiveKeys.effect(LiveArEffect.none)), findsNothing);
      await tester.tap(find.byKey(GoLiveKeys.filter(LiveColorFilter.mono)));
      await tester.pumpAndSettle();
      expect(camera.beauty.filter, LiveColorFilter.mono);
      expect(camera.beauty.enabled, isFalse);
      await _leave(tester);
    });

    testWidgets('D144 Effects (beta): background blur reaches the camera, '
        'marks Magic, and None turns it off', (tester) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()
          ..supportsBeauty = false
          ..supportsFilters = true
          ..arSupport = LiveArSupport.ready,
      );
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveEffectsTitle), findsOneWidget);
      expect(find.byKey(GoLiveKeys.effectsUnavailable), findsNothing);
      final blur = find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur));
      await tester.ensureVisible(blur);
      await tester.tap(blur);
      await tester.pumpAndSettle();
      expect(camera.beauty.effect, LiveArEffect.backgroundBlur);
      expect(hostState(tester).beauty.effect, LiveArEffect.backgroundBlur);
      // The colour filter is independent of the effect.
      expect(camera.beauty.filter, LiveColorFilter.natural);
      expect(
        tester
            .widget<Semantics>(
              find.descendant(of: blur, matching: find.byType(Semantics)).first,
            )
            .properties
            .selected,
        isTrue,
      );
      final none = find.byKey(GoLiveKeys.effect(LiveArEffect.none));
      await tester.tap(none);
      await tester.pumpAndSettle();
      expect(camera.beauty.effect, LiveArEffect.none);
      await _leave(tester);
    });

    testWidgets('D144 Effects without a DeepAR licence in this build: shown '
        'greyed with why, nothing changes', (tester) async {
      final (_, camera) = await _pump(
        tester,
        engine: FakeLiveMediaEngine()
          ..supportsFilters = true
          ..arSupport = LiveArSupport.unlicensed,
      );
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.effectsUnavailable), findsOneWidget);
      expect(find.text(_l10n(tester).liveEffectsUnavailable), findsOneWidget);
      final blur = find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur));
      await tester.ensureVisible(blur);
      await tester.tap(blur, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(camera.beauty.effect, LiveArEffect.none);
      await _leave(tester);
    });

    testWidgets('audio room ≡ → Management: the moderators (remove), add '
        'one from the viewers (host only, the same sheet as video)', (
      tester,
    ) async {
      final (repo, _) = await _pump(tester);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      await _startAudio(tester);
      const mona = UserSummary(
        id: 'u-9',
        username: 'mona',
        displayName: 'Mona',
        avatarUrl: null,
      );
      repo
        ..seatState = repo.seatState!.copyWith(moderators: const [mona])
        ..viewerList = [
          LiveViewer(
            kind: LiveViewerKind.user,
            user: const UserSummary(
              id: 'u-huda',
              username: 'huda',
              displayName: 'Huda',
              avatarUrl: null,
            ),
            guestNumber: null,
            joinedAt: DateTime.utc(2026, 10, 23),
          ),
        ];
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('${l10n.liveToolManagement}, ${l10n.liveSoon}'),
        findsNothing,
      );
      await tester.tap(find.byKey(GoLiveKeys.tool('management')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveManageTitle), findsOneWidget);
      // A seat room lists its moderators (no "open a card" hint).
      expect(find.text(l10n.liveManageModeratorsHint), findsNothing);
      await tester.tap(find.byKey(LiveManageKeys.moderators));
      await tester.pumpAndSettle();
      expect(find.text('Mona'), findsOneWidget);
      await tester.tap(find.byKey(LiveManageKeys.action('mona')));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('removeModerator:mona'));
      expect(repo.seatState!.moderators, isEmpty);
      // Add: the viewers, then make one a moderator from their card.
      await tester.tap(find.byKey(LiveManageKeys.addModerator));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveManageTitle), findsNothing);
      expect(find.byKey(SeatControlKeys.viewersTab), findsOneWidget);
      await tester.tap(find.byKey(SeatControlKeys.moderatorUser('huda')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePersonToolKeys.admin));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('addModerator:huda'));
      await _leave(tester);
    });
  });
}

/// Whether [target] is [ancestor] or inside it.
bool _isDescendant(RenderObject ancestor, RenderObject? target) {
  for (var o = target; o != null; o = o.parent) {
    if (identical(o, ancestor)) return true;
  }
  return false;
}
