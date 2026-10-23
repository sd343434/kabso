// CP-010 L1: go live — the gates (hosting off, no hosting permission), the
// camera preview and its problems, the title rule, starting (room, token,
// publish, heartbeats), the guests switch while live, ending (confirmed),
// failures that roll back, the server ending the room, leaving while live,
// the Create mode bar, and Arabic RTL placement.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_mode_bar.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
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
}) async {
  final live =
      repo ??
      FakeLiveRepository(
        hostingEnabled: hostingEnabled,
        categories: _categories,
      );
  final camera = engine ?? FakeLiveMediaEngine();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: camera,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      currentUserProvider.overrideWithValue(
        testUser().copyWith(canHost: canHost),
      ),
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

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(GoLiveScreen)));

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
      expect(find.byType(GoLiveModeBar), findsOneWidget);
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
        GoLiveScreen.guestsChipKey,
        GoLiveScreen.startKey,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.text(l10n.goLiveNoCategory), findsOneWidget);
      expect(find.text('# Music'), findsOneWidget);
      expect(find.text(l10n.goLiveTitleHint), findsOneWidget);
      // Nothing that does not work: no flash, timer or sound.
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
    testWidgets('start: room, token, publish, then heartbeats', (tester) async {
      final (repo, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveScreen.categoryKey('music')));
      await tester.tap(find.byKey(GoLiveScreen.guestsChipKey));
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
      expect(find.byKey(GoLiveScreen.minimizeKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(find.byType(GoLiveModeBar), findsNothing);
      expect(find.text('Evening chat'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, ['room-host']);
      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, hasLength(2));
      expect(find.bySemanticsLabel(l10n.goLiveElapsed('0:30')), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('guests switch while live goes to the server', (tester) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      await _goLive(tester);
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
      await tester.tap(find.byKey(GoLiveScreen.liveGuestsKey));
      await tester.pump();
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
      expect(find.byKey(GoLiveScreen.minimizeKey), findsOneWidget);
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
      expect(find.byKey(GoLiveScreen.minimizeKey), findsNothing);
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

    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(GoLiveAudioSetup),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('audio: microphone only, its own setup, sent with the room', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await mode(tester, LiveRoomMode.audio);
      expect(camera.previewModes, [true, false]);
      expect(find.byType(GoLiveAudioSetup), findsOneWidget);
      expect(find.byKey(GoLiveScreen.flipKey), findsNothing);
      expect(find.byKey(GoLiveScreen.beautyKey), findsNothing);
      expect(find.text(_l10n(tester).goLiveAudioHeadline), findsOneWidget);
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
      // Categories as tiles with icons.
      await tester.tap(find.byKey(GoLiveScreen.categoryKey('music')));
      // Who can watch: signed-in only.
      await reveal(tester, find.byKey(GoLiveAudioSetup.watchSignedInKey));
      await tester.tap(find.byKey(GoLiveAudioSetup.watchSignedInKey));
      await tester.pumpAndSettle();
      // Seats 5 / 9 / 13.
      await reveal(tester, find.byKey(GoLiveKeys.seatCount(13)));
      for (final c in [5, 9, 13]) {
        expect(find.byKey(GoLiveKeys.seatCount(c)), findsOneWidget);
      }
      expect(find.byKey(GoLiveKeys.seatCount(6)), findsNothing);
      await tester.tap(find.byKey(GoLiveKeys.seatCount(13)));
      await tester.pumpAndSettle();

      await reveal(tester, find.byKey(GoLiveScreen.startKey));
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      await tester.pumpAndSettle();
      final request = repo.startRequests.single;
      expect(request.mode, LiveRoomMode.audio);
      expect(request.seatCount, 13);
      expect(request.theme, LiveThemes.classic);
      expect(request.categorySlug, 'music');
      expect(request.allowGuests, isFalse);
      // On air: the host's circle and 12 seats.
      expect(find.byKey(AudioSeatRing.seatKey(12)), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('audio room (D94 reference): the mode pill, the centre '
        'mic, numbered seats and ✕ to end', (tester) async {
      final (repo, camera) = await _pump(tester);
      await mode(tester, LiveRoomMode.audio);
      // The pill opens the three modes; picking multi leaves the setup.
      await tester.tap(find.byKey(GoLiveAudioSetup.modesKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.mode(LiveRoomMode.solo)), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.multi)));
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
      await reveal(tester, find.byKey(GoLiveScreen.startKey));
      final startSemantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(GoLiveScreen.startKey))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      startSemantics.dispose();
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);
      // Who is watching, from GET /viewers: the avatar and the count.
      expect(
        find.descendant(
          of: find.byKey(GoLiveScreen.viewersKey),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // The host's seat ("Host"), then numbered empty seats with +.
      expect(find.bySemanticsLabel(RegExp(l10n.goLiveHostTag)), findsOneWidget);
      expect(find.byKey(AudioSeatRing.seatKey(8)), findsOneWidget);
      // The round mic button mutes and unmutes.
      expect(find.bySemanticsLabel(l10n.goLiveMuteMic), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.micKey));
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      expect(find.bySemanticsLabel(l10n.goLiveUnmuteMic), findsOneWidget);
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
      // The last request accepted: the sheet closes by itself (real run).
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
      expect(find.text(l10n.liveSeatRequestsTitle), findsOneWidget);
      await tester.tap(find.byKey(SeatControlKeys.accept('req-1')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveSeatRequestsTitle), findsNothing);
      expect(find.text(l10n.liveSeatRequestsEmpty), findsNothing);
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
      // The mixer holds seats, guests and theme; chat is not open yet.
      await tester.tap(find.byKey(GoLiveScreen.audioMoreKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.tool('seats')), findsOneWidget);
      expect(find.byKey(GoLiveScreen.liveGuestsKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.themeKey), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // 💬 opens the chat box in place of the buttons. The room chat is
      // not in the contract yet: send says so and keeps the text.
      await tester.tap(find.byKey(GoLiveScreen.audioChatKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.audioChatKey), findsNothing);
      await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hello');
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      expect(find.text(l10n.liveRoomChatUnavailable), findsWidgets);
      expect(find.text('Hello'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GoLiveScreen)))
          .removeCurrentSnackBar();
      // A tap outside closes it; the buttons are back.
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveChatComposer.fieldKey), findsNothing);
      expect(find.byKey(GoLiveScreen.audioChatKey), findsOneWidget);
      // Screen readers (and the web's semantics layer) can press every
      // room button: each offers the tap action (regression, real web run).
      final handle = tester.ensureSemantics();
      for (final key in [
        GoLiveScreen.micKey,
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
      await reveal(tester, find.byKey(GoLiveAudioSetup.enhanceKey));
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
      expect(find.byType(GoLiveModeBar), findsNothing);
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
      await tester.tap(find.byKey(GoLiveScreen.minimizeKey));
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
      expect(find.byKey(GoLiveScreen.minimizeKey), findsOneWidget);
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
      expect(find.byKey(GoLiveScreen.minimizeKey), findsNothing);
      expect(find.byKey(LiveMiniWindow.windowKey), findsNothing);
      await _leave(tester);
    });
  });
}
