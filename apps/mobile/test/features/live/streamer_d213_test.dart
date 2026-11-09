// D213 (owner 2026-11-02, v1.56-live, CONVENTIONS §10.86): the streamer
// live «بث ستريمر» — the host's phone screen with a round front-camera
// bubble. Android hosts (iOS: an honest «قريباً على آيفون»), viewers
// anywhere. Fakes stand in for the API, the media engine, the foreground
// service and the native screen-capture side (tests only; no device: the
// real MediaProjection, game sound and FLAG_SECURE are not exercised here).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_streamer_host.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/streamer/streamer_widgets.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/component_harness.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_streamer_platform.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

typedef _Host = ({
  FakeLiveRepository repo,
  FakeLiveMediaEngine engine,
  FakeStreamerPlatform platform,
  FakeBackground service,
});

Future<_Host> _goLive(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.ar,
  FakeStreamerPlatform? platform,
  FakeBackground? background,
  bool start = true,
  LiveRoomMode mode = LiveRoomMode.streamer,
}) async {
  final repo = FakeLiveRepository(
    categories: const [LiveCategory(slug: 'games', name: 'Games')],
  );
  final engine = FakeLiveMediaEngine();
  final native = platform ?? FakeStreamerPlatform();
  final service = background ?? FakeBackground();
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      streamerPlatformProvider.overrideWithValue(native),
      liveBackgroundServiceProvider.overrideWithValue(service),
    ],
  );
  await tester.pumpAndSettle();
  final tab = find.byKey(GoLiveKeys.mode(mode));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
  if (start) {
    await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'ببجي');
    await tester.tap(find.byKey(GoLiveScreen.startKey));
    await tester.pumpAndSettle();
  }
  return (repo: repo, engine: engine, platform: native, service: service);
}

/// The app leaves for the game (Android's lifecycle order).
Future<void> _toBackground(WidgetTester tester) async {
  [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ].forEach(tester.binding.handleAppLifecycleStateChanged);
  await tester.pumpAndSettle();
}

/// Kabso comes back to the front.
Future<void> _toForeground(WidgetTester tester) async {
  [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ].forEach(tester.binding.handleAppLifecycleStateChanged);
  await tester.pumpAndSettle();
}

/// D346: goes live with [failure] thrown by the screen's capture.
Future<_Host> _goLiveWithScreenFailure(
  WidgetTester tester,
  Exception failure,
) async {
  final h = await _goLive(tester, start: false);
  h.engine.screenFailure = failure;
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'ببجي');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
  return h;
}

/// D346: a streamer failure is said once in the snack and kept on the
/// problem card (with «نسخ تقرير المشكلة»).
void _said(String text) {
  expect(
    find.descendant(of: find.byType(SnackBar), matching: find.text(text)),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: find.byKey(StreamerProblemCard.cardKey),
      matching: find.text(text),
    ),
    findsOneWidget,
  );
  expect(find.byKey(StreamerProblemCard.copyKey), findsOneWidget);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

LiveRoom _streamerRoom({
  LiveStreamer streamer = const LiveStreamer(),
  bool ar = true,
}) => apiRoom(ar: ar).copyWith(mode: LiveRoomMode.streamer, streamer: streamer);

Future<(FakeLiveMediaEngine, FakeLiveRepository)> _watch(
  WidgetTester tester, {
  required AppLanguage language,
  LiveStreamer streamer = const LiveStreamer(),
  bool screen = true,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final engine = FakeLiveMediaEngine();
  final hostId = apiRoom().host.id;
  engine.present.add(hostId);
  if (screen) engine.screenIds.add(hostId);
  final repo = FakeLiveRepository(
    room: (id) => _streamerRoom(
      streamer: streamer,
      ar: language == AppLanguage.ar,
    ).copyWith(id: id),
  );
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [liveRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.pumpAndSettle();
  return (engine, repo);
}

void main() {
  group('domain', () {
    test('LiveStreamer reads the wire, defaults and keeps the newest', () {
      final s = LiveStreamer.fromJson(const {
        'orientation': 'LANDSCAPE',
        'cameraOverlay': {'visible': false, 'corner': 'BOTTOM_RIGHT'},
        'version': 3,
      });
      expect(s.landscape, isTrue);
      expect(s.cameraVisible, isFalse);
      expect(s.corner, StreamerCorner.bottomRight);
      expect(s.version, 3);
      expect(LiveStreamer.fromJson(const {}), const LiveStreamer());
      expect(
        LiveStreamer.fromJson(const {
          'orientation': 'SIDEWAYS',
          'cameraOverlay': {'corner': 'MIDDLE'},
        }),
        const LiveStreamer(),
      );
      expect(LiveStreamer.fromJson(s.toJson()), s);
      final older = s.copyWith(version: 2, corner: StreamerCorner.topLeft);
      expect(s.newest(older), s);
      expect(older.newest(s), s);
      expect(s.newest(null), s);
    });

    test('the `streamer` data message', () {
      final e = LiveStreamerEvent.parse({
        'type': 'streamer',
        'roomId': 'r1',
        'streamer': {
          'orientation': 'PORTRAIT',
          'cameraOverlay': {'visible': true, 'corner': 'TOP_RIGHT'},
          'version': 9,
        },
      });
      expect(e?.roomId, 'r1');
      expect(e?.streamer.corner, StreamerCorner.topRight);
      expect(LiveStreamerEvent.parse({'type': 'chat'}), isNull);
      expect(LiveStreamerEvent.parse('x'), isNull);
    });

    test('STREAMER is a video live in `solo` (the main hub) and `video`', () {
      const m = LiveRoomMode.streamer;
      expect(m.wire, 'STREAMER');
      expect(m.isVoice, isFalse);
      expect(m.hasSeats, isFalse);
      expect(m.hasGuestSeats, isFalse);
      expect(LiveRoomsKind.streamer.wire, 'streamer');
      expect(LiveRoomsKind.streamer.includes(m), isTrue);
      expect(LiveRoomsKind.solo.includes(m), isTrue);
      expect(LiveRoomsKind.video.includes(m), isTrue);
      for (final k in [
        LiveRoomsKind.audio,
        LiveRoomsKind.podcast,
        LiveRoomsKind.multi,
        LiveRoomsKind.party,
      ]) {
        expect(k.includes(m), isFalse, reason: k.wire);
      }
      final room = LiveRoom.fromJson({
        ...(jsonDecode(jsonEncode(apiRoom().toJson())) as Map<String, dynamic>),
        'mode': 'STREAMER',
        'streamer': {
          'orientation': 'LANDSCAPE',
          'cameraOverlay': {'visible': true, 'corner': 'BOTTOM_LEFT'},
          'version': 1,
        },
      });
      expect(room.mode, m);
      expect(room.streamer?.corner, StreamerCorner.bottomLeft);
    });

    test('corners: physical, the nearest to a drop', () {
      expect(StreamerCorner.nearest(10, 10, 100, 200), StreamerCorner.topLeft);
      expect(StreamerCorner.nearest(90, 10, 100, 200), StreamerCorner.topRight);
      expect(
        StreamerCorner.nearest(10, 190, 100, 200),
        StreamerCorner.bottomLeft,
      );
      expect(
        StreamerCorner.nearest(90, 190, 100, 200),
        StreamerCorner.bottomRight,
      );
      const box = Size(300, 600);
      expect(
        streamerBubbleOffset(StreamerCorner.topLeft, box, 80),
        const Offset(10, 10),
      );
      expect(
        streamerBubbleOffset(StreamerCorner.bottomRight, box, 80),
        const Offset(210, 510),
      );
    });

    test('the picture: portrait fills the room, landscape is letterboxed', () {
      const room = Size(393, 852);
      final portrait = streamerPictureRect(room, landscape: false);
      expect(portrait.width, closeTo(393, 0.01));
      expect(portrait.center.dy, closeTo(426, 0.01));
      final landscape = streamerPictureRect(room, landscape: true);
      expect(landscape.width, closeTo(393, 0.01));
      expect(landscape.height, closeTo(393 * 9 / 19.5, 0.01));
      expect(landscape.center.dy, closeTo(426, 0.01));
      // The bubble shrinks with a short picture, never under 56 dp.
      expect(KStreamer.bubbleFor(landscape.size), 56);
      expect(KStreamer.bubbleFor(portrait.size), 96);
    });

    test('the notification spec: the screen types and the two toggles', () {
      const texts = LiveBackgroundTexts(
        channelName: 'c',
        hostTitle: 'h',
        guestTitle: 'g',
        listenerTitle: 'l',
        body: 'b',
        endLive: 'e',
        leave: 'x',
      );
      final plain = LiveBackgroundSpec.of(LiveBackgroundRole.host, texts);
      final s = plain.streamer(mic: 'mute', camera: 'hide');
      expect(plain.screen, isFalse);
      expect(s.screen, isTrue);
      expect(s.buttons.map((b) => b.action), [
        LiveBackgroundAction.toggleMic,
        LiveBackgroundAction.toggleCamera,
      ]);
      expect(s == plain.streamer(mic: 'mute', camera: 'hide'), isTrue);
      expect(s == plain.streamer(mic: 'unmute', camera: 'hide'), isFalse);
    });
  });

  group('go-live (Android)', () {
    testWidgets('«بث ستريمر» is a real mode: the setup panel, no «قريباً»', (
      tester,
    ) async {
      await _goLive(tester, start: false);
      // The mode tab is selectable (no «قريباً» caption under it).
      expect(
        find.descendant(
          of: find.byKey(GoLiveKeys.mode(LiveRoomMode.streamer)),
          matching: find.text('قريباً'),
        ),
        findsNothing,
      );
      expect(find.byKey(GoLiveStreamerPanel.panelKey), findsOneWidget);
      expect(
        find.text('بعض الألعاب تمنع التقاط صوتها'),
        findsOneWidget,
        reason: 'the honest game-sound note',
      );
      expect(
        find.text('لا يرى المشاهدون شاشتك وأنت داخل Kabso Live'),
        findsOneWidget,
      );
      // The bubble off hides its corner picker.
      expect(
        find.byKey(StreamerCornerPicker.cornerKey(StreamerCorner.topRight)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key(GoLiveStreamerPanel.cameraKey)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(StreamerCornerPicker.cornerKey(StreamerCorner.topRight)),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key(GoLiveStreamerPanel.cameraKey)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(StreamerCornerPicker.cornerKey(StreamerCorner.bottomRight)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('أسفل اليمين'), findsOneWidget);
      // Owner: the host's corner is kept on this phone for the next live.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PreferenceKeys.streamerCorner), 'BOTTOM_RIGHT');
      await _leave(tester);
    });

    testWidgets('setup: «use headphones» while the game sound is on and no '
        'headset is connected', (tester) async {
      final native = FakeStreamerPlatform();
      await _goLive(tester, start: false, platform: native);
      expect(native.headsetReads, 1);
      expect(find.byKey(GoLiveStreamerPanel.headphonesKey), findsOneWidget);
      expect(
        find.text('استخدم سماعات حتى لا يُسمع صوت اللعبة مرتين'),
        findsOneWidget,
      );
      // The game sound off: nothing to hear twice.
      await tester.tap(find.byKey(const Key(GoLiveStreamerPanel.gameKey)));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveStreamerPanel.headphonesKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('setup: no tip with a headset connected (English)', (
      tester,
    ) async {
      await _goLive(
        tester,
        start: false,
        language: AppLanguage.en,
        platform: FakeStreamerPlatform()..headset = true,
      );
      expect(find.byKey(GoLiveStreamerPanel.headphonesKey), findsNothing);
      expect(
        find.text("Use headphones so the game sound isn't heard twice"),
        findsNothing,
      );
      await _leave(tester);
    });

    testWidgets('on air: the tip once — gone after the host goes to the game; '
        'a headset plugged in hides it', (tester) async {
      final h = await _goLive(tester);
      expect(find.byKey(StreamerHostStage.headphonesKey), findsOneWidget);
      await _toBackground(tester);
      await _toForeground(tester);
      expect(find.byKey(StreamerHostStage.headphonesKey), findsNothing);
      await _leave(tester);

      final again = await _goLive(tester);
      expect(find.byKey(StreamerHostStage.headphonesKey), findsOneWidget);
      again.platform.emit(const StreamerHeadset(connected: true));
      await tester.pumpAndSettle();
      expect(find.byKey(StreamerHostStage.headphonesKey), findsNothing);
      expect(h.platform, isNot(same(again.platform)));
      await _leave(tester);
    });

    testWidgets('below Android 10: the game sound is off with why', (
      tester,
    ) async {
      await _goLive(
        tester,
        start: false,
        platform: FakeStreamerPlatform()..sdk = 28,
      );
      final game = tester.widget<Switch>(
        find.byKey(const Key(GoLiveStreamerPanel.gameKey)),
      );
      expect(game.onChanged, isNull);
      expect(game.value, isFalse);
      expect(find.byKey(GoLiveStreamerPanel.headphonesKey), findsNothing);
      expect(
        find.text(
          'صوت اللعبة يحتاج أندرويد 10 أو أحدث، سيُبث صوت الميكروفون فقط',
        ),
        findsOneWidget,
      );
      await _leave(tester);
    });

    testWidgets('capture refused: nothing is created, the reason is said', (
      tester,
    ) async {
      final h = await _goLive(
        tester,
        platform: FakeStreamerPlatform()..allowCapture = false,
      );
      expect(h.platform.consents, 1);
      expect(h.repo.startRequests, isEmpty);
      expect(h.engine.screenPublishes, 0);
      _said('لم تسمح بتصوير الشاشة، لذلك لم يبدأ البث');
      await _leave(tester);
    });

    testWidgets('D262: the consent could not be asked → its own message with '
        'the code, not «you refused»; nothing is created', (tester) async {
      final h = await _goLive(
        tester,
        platform: FakeStreamerPlatform()
          ..consentAnswer = const StreamerConsent.failed('instant_cancel'),
      );
      expect(h.platform.consents, 1);
      expect(h.repo.startRequests, isEmpty);
      expect(h.service.starts, isEmpty);
      expect(h.engine.screenPublishes, 0);
      _said('تعذّر طلب إذن تصوير الشاشة (instant_cancel)');
      expect(
        find.text('لم تسمح بتصوير الشاشة، لذلك لم يبدأ البث'),
        findsNothing,
      );
      await _leave(tester);
    });

    testWidgets('D262b: the setup says what to press in the Android dialog', (
      tester,
    ) async {
      await _goLive(tester, start: false);
      expect(find.byKey(GoLiveStreamerPanel.consentHintKey), findsOneWidget);
      expect(
        find.text('اضغط "بدء" في نافذة أندرويد لمشاركة شاشتك'),
        findsOneWidget,
      );
      await _leave(tester);
    });

    testWidgets('D262: a consent that throws is a failure with its type', (
      tester,
    ) async {
      final h = await _goLive(
        tester,
        platform: FakeStreamerPlatform()..throwOnConsent = true,
      );
      expect(h.repo.startRequests, isEmpty);
      _said('تعذّر طلب إذن تصوير الشاشة (stateerror)');
      await _leave(tester);
    });

    testWidgets('on air: consent → service with the screen → room → screen, '
        'paused while Kabso is in front', (tester) async {
      final h = await _goLive(tester);
      expect(h.platform.consents, 1);
      final start = h.repo.startRequests.single;
      expect(start.mode, LiveRoomMode.streamer);
      expect(start.streamer?.cameraVisible, isTrue);
      expect(start.seatCount, isNull);
      // The service gained the screen's types before the screen started.
      final spec = h.service.starts.first;
      expect(spec.screen, isTrue);
      expect(spec.buttons, hasLength(2));
      expect(spec.buttons.first.label, 'كتم المايك');
      expect(h.engine.screenPublishes, 1);
      expect(h.engine.screenPauses.first, isTrue);
      expect(h.platform.attaches, [true]);
      expect(h.platform.secure, [true]);
      expect(find.byKey(StreamerHostStage.stageKey), findsOneWidget);
      expect(
        find.text('الشاشة متوقفة مؤقتاً وأنت داخل Kabso Live'),
        findsOneWidget,
      );
      expect(find.text('صوت اللعبة يُبث'), findsOneWidget);

      // To the game: the screen goes out; back in Kabso: paused again.
      await _toBackground(tester);
      expect(h.engine.screenPaused, isFalse);
      // The camera bubble is not paused in the background.
      expect(h.engine.videoPaused, isFalse);
      await _toForeground(tester);
      expect(h.engine.screenPaused, isTrue);

      // «اذهب إلى اللعبة».
      await tester.tap(find.byKey(StreamerHostStage.goToGameKey));
      await tester.pumpAndSettle();
      expect(h.platform.toBack, 1);
      await _leave(tester);
    });

    testWidgets('the microphone and the game sound mute separately; the '
        'camera bubble hides for everyone', (tester) async {
      final h = await _goLive(tester);
      await tester.tap(find.byKey(StreamerHostStage.micKey));
      await tester.pumpAndSettle();
      // The voice is silenced in the mixer; the track (and the game) go on.
      expect(h.platform.micMutes, [true]);
      expect(h.engine.micEnabled, isTrue);
      expect(h.service.running?.buttons.first.label, 'تشغيل المايك');
      await tester.tap(find.byKey(StreamerHostStage.gameKey));
      await tester.pumpAndSettle();
      expect(h.platform.gameMutes, [true]);
      expect(find.text('صوت اللعبة مكتوم'), findsOneWidget);
      await tester.tap(find.byKey(StreamerHostStage.cameraKey));
      await tester.pumpAndSettle();
      expect(h.repo.streamerUpdates.single.cameraVisible, isFalse);
      expect(h.engine.videoPaused, isTrue);
      expect(h.service.running?.buttons.last.label, 'إظهار الكاميرا');
      // From the notification too.
      h.service.tap(LiveBackgroundAction.toggleMic);
      await tester.pumpAndSettle();
      expect(h.platform.micMutes, [true, false]);
      h.service.tap(LiveBackgroundAction.toggleCamera);
      await tester.pumpAndSettle();
      expect(h.repo.streamerUpdates.last.cameraVisible, isTrue);
      expect(h.engine.videoPaused, isFalse);
      await _leave(tester);
    });

    testWidgets('a call or a dark screen pauses; the display turning tells '
        'viewers; stopped from the system → share again', (tester) async {
      final h = await _goLive(tester);
      await _toBackground(tester);
      expect(h.engine.screenPaused, isFalse);
      h.platform.emit(const StreamerPhoneCall(active: true));
      await tester.pumpAndSettle();
      expect(h.engine.screenPaused, isTrue);
      h.platform.emit(const StreamerScreenPower(on: false));
      h.platform.emit(const StreamerPhoneCall(active: false));
      await tester.pumpAndSettle();
      expect(h.engine.screenPaused, isTrue, reason: 'still off');
      h.platform.emit(const StreamerScreenPower(on: true));
      await tester.pumpAndSettle();
      expect(h.engine.screenPaused, isFalse);

      h.platform.emit(const StreamerRotation(landscape: true));
      await tester.pumpAndSettle();
      expect(
        h.repo.streamerUpdates.last.orientation,
        StreamerOrientation.landscape,
      );

      await _toForeground(tester);
      h.platform.emit(const StreamerProjectionStopped());
      await tester.pumpAndSettle();
      expect(h.engine.screenPublished, isFalse);
      expect(find.text('توقفت مشاركة الشاشة'), findsOneWidget);
      await tester.tap(find.byKey(StreamerHostStage.shareAgainKey));
      await tester.pumpAndSettle();
      expect(h.platform.consents, 2);
      expect(h.engine.screenPublishes, 2);
      expect(h.engine.screenPublished, isTrue);
      expect(find.text('توقفت مشاركة الشاشة'), findsNothing);
      await _leave(tester);
    });

    testWidgets('D262: share again — a «no», a failed dialog and a screen '
        'that cannot start each say their own thing', (tester) async {
      final h = await _goLive(tester);
      Future<void> stopAndShare() async {
        h.platform.emit(const StreamerProjectionStopped());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(StreamerHostStage.shareAgainKey));
        await tester.pumpAndSettle();
      }

      h.platform.consentAnswer = StreamerConsent.refused;
      await stopAndShare();
      _said('لم تسمح بتصوير الشاشة، لذلك لم يبدأ البث');
      expect(h.engine.screenPublishes, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      h.platform.consentAnswer = const StreamerConsent.failed('no_activity');
      await tester.tap(find.byKey(StreamerHostStage.shareAgainKey));
      await tester.pumpAndSettle();
      _said('تعذّر طلب إذن تصوير الشاشة (no_activity)');
      expect(h.engine.screenPublishes, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      h.platform.consentAnswer = StreamerConsent.granted;
      h.engine.screenFailure = Exception('capture');
      await tester.tap(find.byKey(StreamerHostStage.shareAgainKey));
      await tester.pumpAndSettle();
      expect(h.engine.screenPublishes, 2);
      // D346: the capture's own failure (its class as the code), with the
      // report — no longer the generic «try again».
      _said('تعذّر بدء تصوير الشاشة (exception)');
      expect(find.text('توقفت مشاركة الشاشة'), findsOneWidget);
      h.engine.screenFailure = null;
      await _leave(tester);
    });

    testWidgets('ending undoes the native side (FLAG_SECURE off)', (
      tester,
    ) async {
      final h = await _goLive(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      unawaited(container.read(liveHostControllerProvider.notifier).end());
      await tester.pumpAndSettle();
      expect(h.platform.detaches, 1);
      expect(h.platform.secure, [true, false]);
      expect(h.service.running, isNull);
      await _leave(tester);
    });

    testWidgets('no game sound on this phone: said honestly', (tester) async {
      await _goLive(
        tester,
        platform: FakeStreamerPlatform()..answer = StreamerGameAudio.failed,
      );
      expect(
        find.text('صوت اللعبة غير متاح على هذا الهاتف، يُبث الميكروفون فقط'),
        findsOneWidget,
      );
      expect(find.byKey(StreamerHostStage.gameKey), findsNothing);
      // No game sound: no headphones tip either.
      expect(find.byKey(StreamerHostStage.headphonesKey), findsNothing);
      await _leave(tester);
    });
  });

  // D346: the real root cause (the live's service stopped as soon as the
  // host left Kabso) is native; here: the order, the precise messages, the
  // problem report and the PK button.
  group('D346', () {
    /// The clipboard's last text (the report).
    String? copied;
    setUp(() {
      copied = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> copyReport(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(StreamerProblemCard.copyKey));
      await tester.tap(find.byKey(StreamerProblemCard.copyKey));
      await tester.pumpAndSettle();
    }

    testWidgets('consent → the service with mediaProjection → the capture '
        'check → the screen, in that order', (tester) async {
      final log = <String>[];
      final h = await _goLive(
        tester,
        platform: FakeStreamerPlatform()..log = log,
        background: FakeBackground()..log = log,
      );
      expect(log, ['consent', 'service:screen', 'captureCheck']);
      expect(h.engine.screenPublishes, 1);
      expect(find.byKey(StreamerProblemCard.cardKey), findsNothing);
      final trail = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      ).read(liveStreamerHostProvider.notifier).trail;
      expect(trail, [
        'consent ok',
        'service ok',
        'capture ok',
        'publish ok',
        'attach ok',
      ]);
      await _leave(tester);
    });

    testWidgets('the service could not start → no capture, no room; its own '
        'message and «نسخ تقرير المشكلة» copies the report', (tester) async {
      final h = await _goLive(
        tester,
        background: FakeBackground()
          ..failStart = const LiveBackgroundStartException('refused'),
      );
      expect(h.platform.captureChecks, 0);
      expect(h.engine.screenPublishes, 0);
      expect(h.repo.startRequests, isEmpty);
      _said(
        'لم يسمح أندرويد بتشغيل خدمة البث، فلا يمكن تصوير الشاشة. '
        'افتح Kabso Live من جديد وحاول مرة أخرى',
      );
      expect(find.text('نسخ تقرير المشكلة'), findsOneWidget);
      await copyReport(tester);
      final report = copied!;
      expect(report, contains('android: 14 (SDK 34)'));
      expect(report, contains('device: Google Pixel 8'));
      expect(report, contains('step: service'));
      expect(report, contains('problem: serviceDenied'));
      expect(report, contains('error: LiveBackgroundStartException(String)'));
      expect(
        report,
        contains(
          'service: foreground=yes '
          'types=microphone|mediaPlayback|mediaProjection|camera',
        ),
      );
      expect(report, contains('steps: consent ok > service FAILED'));
      expect(report, startsWith('Kabso Live — streamer problem report'));
      // No personal data: not the title, the user or a room.
      expect(report, isNot(contains('ببجي')));
      expect(report, isNot(contains(testUser().username)));
      expect(report, isNot(contains('room-')));
      expect(find.text('نُسخ التقرير، أرسله لنا'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the capture check refuses (the service is not in the '
        'foreground) → never captured, the room ended, said', (tester) async {
      final h = await _goLive(
        tester,
        platform: FakeStreamerPlatform()..blocker = 'no_service',
      );
      expect(h.platform.captureChecks, 1);
      expect(h.engine.screenPublishes, 0);
      expect(h.repo.startRequests, hasLength(1));
      expect(find.byKey(StreamerHostStage.stageKey), findsNothing);
      _said(
        'لم يسمح أندرويد بتشغيل خدمة البث، فلا يمكن تصوير الشاشة. '
        'افتح Kabso Live من جديد وحاول مرة أخرى',
      );
      await copyReport(tester);
      expect(copied, contains('step: capture'));
      expect(copied, contains('error: CaptureBlocked'));
      expect(copied, contains('detail: no_service'));
      await _leave(tester);
    });

    testWidgets('a SecurityException from the capture → the security '
        'message (not a generic one)', (tester) async {
      final engineFailure = PlatformException(
        code: 'error',
        message:
            "Don't re-use the resultData to retrieve the same projection "
            'instance',
        details: "java.lang.SecurityException: Don't re-use the resultData",
      );
      final h = await _goLiveWithScreenFailure(tester, engineFailure);
      expect(h.engine.screenPublishes, 1);
      _said(
        'رفض أندرويد تصوير الشاشة لأسباب أمان. اضغط «ابدأ البث» من جديد '
        'واختر «بدء» في نافذة أندرويد',
      );
      await copyReport(tester);
      expect(
        copied,
        contains('error: PlatformException(error) java.lang.SecurityException'),
      );
      expect(copied, contains('problem: security'));
      await _leave(tester);
    });

    testWidgets('Android stops the capture because the service is gone → '
        'said on the stage, with the report', (tester) async {
      final h = await _goLive(tester);
      h.platform.emit(
        const StreamerProjectionStopped(serviceForeground: false),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(StreamerHostStage.shareAgainKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(StreamerProblemCard.cardKey),
          matching: find.text('أوقف أندرويد تصوير الشاشة لأن خدمة البث توقفت'),
        ),
        findsOneWidget,
      );
      await copyReport(tester);
      expect(copied, contains('problem: stoppedBySystem'));
      await _leave(tester);
    });

    testWidgets('stopped by the host from the status bar → share again, no '
        'problem card', (tester) async {
      final h = await _goLive(tester);
      h.platform.emit(const StreamerProjectionStopped(serviceForeground: true));
      await tester.pumpAndSettle();
      expect(find.byKey(StreamerHostStage.shareAgainKey), findsOneWidget);
      expect(find.byKey(StreamerProblemCard.cardKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('owner: no PK button on a streamer live (host)', (
      tester,
    ) async {
      await _goLive(tester);
      expect(find.byKey(GoLiveScreen.hostBarKey), findsOneWidget);
      expect(find.byKey(KHostBar.pkKey), findsNothing);
      expect(find.byKey(KHostBar.giftKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a SOLO live keeps its PK button', (tester) async {
      await _goLive(
        tester,
        mode: LiveRoomMode.solo,
        background: FakeBackground(),
      );
      expect(find.byKey(GoLiveScreen.hostBarKey), findsOneWidget);
      expect(find.byKey(KHostBar.pkKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('no PK entry for a streamer viewer either', (tester) async {
      await _watch(tester, language: AppLanguage.ar);
      expect(find.byKey(StreamerViewerStage.stageKey), findsOneWidget);
      expect(find.byKey(KHostBar.pkKey), findsNothing);
      expect(find.text('تحدي PK'), findsNothing);
      await _leave(tester);
    });
  });

  group('go-live (iOS)', () {
    testWidgets('«قريباً على آيفون»: greyed, a tap says so, no flow', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final repo = FakeLiveRepository();
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          const GoLiveScreen(),
          language: AppLanguage.ar,
          overrides: [
            liveRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(
              testUser().copyWith(canHost: true),
            ),
          ],
        );
        await tester.pumpAndSettle();
        final soon = find.byKey(GoLiveKeys.streamer);
        await tester.ensureVisible(soon);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: soon, matching: find.text('قريباً على آيفون')),
          findsOneWidget,
        );
        await tester.tap(soon);
        await tester.pump();
        expect(find.text('بث ستريمر قريباً على آيفون'), findsOneWidget);
        expect(find.byKey(GoLiveStreamerPanel.panelKey), findsNothing);
        await tester.pumpAndSettle(const Duration(seconds: 5));
        await _leave(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('viewer', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: portrait fills the room; the bubble at '
          "the host's corner (never mirrored)", (tester) async {
        await _watch(
          tester,
          language: language,
          streamer: const LiveStreamer(corner: StreamerCorner.topRight),
        );
        expect(find.byKey(StreamerViewerStage.stageKey), findsOneWidget);
        expect(find.byKey(FakeLiveMediaEngine.screenKey), findsOneWidget);
        final picture = tester.getRect(
          find.byKey(StreamerViewerStage.pictureKey),
        );
        expect(picture.width, closeTo(393, 0.5));
        final bubble = tester.getRect(
          find.byKey(StreamerViewerStage.bubbleKey),
        );
        expect(bubble.width, 96);
        expect(bubble.right, closeTo(picture.right - 10, 0.5));
        // Below the room's host pill and chips (the picture fills the room).
        expect(bubble.top, closeTo(KStreamer.roomTop + 10, 0.5));
        await _leave(tester);
      });
    }

    for (final corner in StreamerCorner.values) {
      testWidgets('landscape letterboxed, the bubble at ${corner.wire}', (
        tester,
      ) async {
        await _watch(
          tester,
          language: AppLanguage.ar,
          streamer: LiveStreamer(
            orientation: StreamerOrientation.landscape,
            corner: corner,
          ),
        );
        final picture = tester.getRect(
          find.byKey(StreamerViewerStage.pictureKey),
        );
        expect(picture.width, closeTo(393, 0.5));
        expect(picture.height, lessThan(200));
        expect(picture.center.dy, closeTo(426, 1));
        final bubble = tester.getRect(
          find.byKey(StreamerViewerStage.bubbleKey),
        );
        expect(bubble.width, 56);
        expect(
          corner.left ? bubble.left : picture.right - bubble.right,
          closeTo(corner.left ? picture.left + 10 : 10, 0.5),
        );
        expect(
          corner.top ? bubble.top : picture.bottom - bubble.bottom,
          closeTo(corner.top ? picture.top + 10 : 10, 0.5),
        );
        expect(find.byKey(StreamerViewerStage.fullscreenKey), findsOneWidget);
        await _leave(tester);
      });
    }

    testWidgets('the layout follows the `streamer` messages; a missed one is '
        're-read from the room', (tester) async {
      final (engine, repo) = await _watch(tester, language: AppLanguage.ar);
      engine.streamer.add(
        const LiveStreamerEvent(
          'room-0',
          LiveStreamer(
            orientation: StreamerOrientation.landscape,
            corner: StreamerCorner.bottomLeft,
            version: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(StreamerViewerStage.pictureKey)).height,
        lessThan(200),
      );
      // An older message changes nothing.
      engine.streamer.add(const LiveStreamerEvent('room-0', LiveStreamer()));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(StreamerViewerStage.pictureKey)).height,
        lessThan(200),
      );
      // The metadata says version 5: the room is read again.
      final reads = repo.roomRequests.length;
      engine
        ..streamerVersionNow = 5
        ..ping();
      await tester.pumpAndSettle();
      expect(repo.roomRequests.length, greaterThan(reads));
      await _leave(tester);
    });

    testWidgets('paused, waiting and a hidden bubble', (tester) async {
      final (engine, _) = await _watch(
        tester,
        language: AppLanguage.ar,
        streamer: const LiveStreamer(cameraVisible: false),
      );
      expect(find.byKey(StreamerViewerStage.bubbleKey), findsNothing);
      engine
        ..screenPausedIds.add(apiRoom().host.id)
        ..ping();
      await tester.pump();
      expect(find.byKey(StreamerViewerStage.pausedKey), findsOneWidget);
      expect(
        find.text('الشاشة متوقفة مؤقتاً، سيعود البث بعد قليل'),
        findsOneWidget,
      );
      expect(find.byKey(StreamerViewerStage.fullscreenKey), findsNothing);
      engine
        ..screenIds.clear()
        ..screenPausedIds.clear()
        ..ping();
      await tester.pump();
      expect(find.byKey(StreamerViewerStage.waitingKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('fullscreen and back', (tester) async {
      await _watch(
        tester,
        language: AppLanguage.en,
        streamer: const LiveStreamer(
          orientation: StreamerOrientation.landscape,
        ),
      );
      await tester.tap(find.byKey(StreamerViewerStage.fullscreenKey));
      await tester.pumpAndSettle();
      expect(find.byKey(StreamerFullscreenPage.pageKey), findsOneWidget);
      expect(find.byKey(StreamerViewerStage.exitKey), findsOneWidget);
      await tester.tap(find.byKey(StreamerViewerStage.exitKey));
      await tester.pumpAndSettle();
      expect(find.byKey(StreamerFullscreenPage.pageKey), findsNothing);
      await _leave(tester);
    });
  });

  // D247 (v1.57-live, CONVENTIONS §10.88): «استوديو البث» on a computer can
  // send the camera track alone as the picture (OBS Virtual Camera holding a
  // whole scene) — `main: CAMERA`. Viewers lay it out like a screen.
  group('camera as the main picture (D247)', () {
    test('`main` reads the wire; unknown or absent is the screen', () {
      final s = LiveStreamer.fromJson(const {
        'orientation': 'LANDSCAPE',
        'cameraOverlay': {'visible': false, 'corner': 'TOP_LEFT'},
        'main': 'CAMERA',
        'version': 4,
      });
      expect(s.main, StreamerMain.camera);
      expect(s.cameraMain, isTrue);
      expect(LiveStreamer.fromJson(s.toJson()), s);
      expect(s.toJson()['main'], 'CAMERA');
      expect(
        LiveStreamer.fromJson(const {'main': 'WINDOW'}).cameraMain,
        isFalse,
      );
      expect(const LiveStreamer().main, StreamerMain.screen);
      expect(s.copyWith(main: StreamerMain.screen).cameraMain, isFalse);
      expect(s == s.copyWith(main: StreamerMain.screen), isFalse);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: the camera fills the picture, landscape '
          'letterboxed, no bubble, no screen expected', (tester) async {
        await _watch(
          tester,
          language: language,
          screen: false,
          streamer: const LiveStreamer(
            orientation: StreamerOrientation.landscape,
            main: StreamerMain.camera,
            cameraVisible: false,
          ),
        );
        expect(
          find.byKey(FakeLiveMediaEngine.cameraPictureKey),
          findsOneWidget,
        );
        expect(find.byKey(FakeLiveMediaEngine.screenKey), findsNothing);
        expect(find.byKey(StreamerViewerStage.bubbleKey), findsNothing);
        expect(find.byKey(StreamerViewerStage.waitingKey), findsNothing);
        final picture = tester.getRect(
          find.byKey(StreamerViewerStage.pictureKey),
        );
        expect(picture.width, closeTo(393, 0.5));
        expect(picture.height, lessThan(200));
        expect(find.byKey(StreamerViewerStage.fullscreenKey), findsOneWidget);
        await _leave(tester);
      });
    }

    testWidgets('a bubble setting never draws the camera twice', (
      tester,
    ) async {
      await _watch(
        tester,
        language: AppLanguage.ar,
        screen: false,
        streamer: const LiveStreamer(main: StreamerMain.camera),
      );
      expect(find.byKey(FakeLiveMediaEngine.cameraPictureKey), findsOneWidget);
      expect(find.byKey(StreamerViewerStage.bubbleKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('paused camera and waiting for the picture', (tester) async {
      final (engine, _) = await _watch(
        tester,
        language: AppLanguage.ar,
        screen: false,
        streamer: const LiveStreamer(main: StreamerMain.camera),
      );
      final hostId = apiRoom().host.id;
      engine
        ..videoMutedIds.add(hostId)
        ..ping();
      await tester.pump();
      expect(find.byKey(StreamerViewerStage.pausedKey), findsOneWidget);
      engine
        ..videoMutedIds.clear()
        ..present.remove(hostId)
        ..ping();
      await tester.pump();
      expect(find.byKey(StreamerViewerStage.waitingKey), findsOneWidget);
      expect(find.text('بانتظار صورة المضيف…'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the host switches screen ⇄ camera with a `streamer` message', (
      tester,
    ) async {
      final (engine, _) = await _watch(tester, language: AppLanguage.en);
      expect(find.byKey(FakeLiveMediaEngine.screenKey), findsOneWidget);
      expect(find.byKey(StreamerViewerStage.bubbleKey), findsOneWidget);
      engine.streamer.add(
        const LiveStreamerEvent(
          'room-0',
          LiveStreamer(main: StreamerMain.camera, version: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(FakeLiveMediaEngine.cameraPictureKey), findsOneWidget);
      expect(find.byKey(FakeLiveMediaEngine.screenKey), findsNothing);
      expect(find.byKey(StreamerViewerStage.bubbleKey), findsNothing);
      engine.streamer.add(
        const LiveStreamerEvent('room-0', LiveStreamer(version: 2)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(FakeLiveMediaEngine.screenKey), findsOneWidget);
      await _leave(tester);
    });
  });

  group('hub', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: a streamer card says «ستريمر»', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          const Center(
            child: SizedBox(
              width: 180,
              height: 201,
              child: KLiveGridCard(
                room: LiveRoomCardData(
                  hostName: 'A',
                  title: 'game',
                  viewerCount: 3,
                  isStreamer: true,
                ),
              ),
            ),
          ),
          language: language,
        );
        expect(
          tester.widget<Text>(find.byKey(KLiveGridCard.typeKey)).data,
          language == AppLanguage.ar ? 'ستريمر' : 'Streamer',
        );
      });
    }

    test('a summary maps STREAMER to the tag', () {
      final summary = LiveRoomSummary.fromJson({
        ...(jsonDecode(jsonEncode(apiRoom().toJson())) as Map<String, dynamic>),
        'mode': 'STREAMER',
      });
      expect(LiveRoomCardData.fromSummary(summary).isStreamer, isTrue);
    });
  });

  test('the host provider starts as set up (portrait, bubble top left)', () {
    const s = StreamerHostState();
    expect(s.startLayout, const LiveStreamer());
    expect(s.paused, isTrue);
    expect(s.gameAudioPossible, isTrue);
    expect(const StreamerHostState(sdkInt: 28).gameAudioPossible, isFalse);
  });

  test(
    'the bubble corner: the one saved on this phone, else top left',
    () async {
      Future<StreamerCorner> corner(Map<String, Object> saved) async {
        SharedPreferences.setMockInitialValues(saved);
        final prefs = await SharedPreferences.getInstance();
        final c = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(c.dispose);
        final host = c.read(liveStreamerHostProvider);
        expect(host.startLayout.corner, host.corner);
        return host.corner;
      }

      expect(await corner({}), StreamerCorner.topLeft);
      expect(
        await corner({PreferenceKeys.streamerCorner: 'BOTTOM_RIGHT'}),
        StreamerCorner.bottomRight,
      );
      expect(
        await corner({PreferenceKeys.streamerCorner: 'MIDDLE'}),
        StreamerCorner.topLeft,
      );
      // No preferences at all (some tests): top left, kept in memory.
      final bare = ProviderContainer();
      addTearDown(bare.dispose);
      final n = bare.read(liveStreamerHostProvider.notifier);
      await n.setCorner(StreamerCorner.topRight);
      expect(
        bare.read(liveStreamerHostProvider).corner,
        StreamerCorner.topRight,
      );
    },
  );

  test('the headphones tip: game sound on, no headset known', () {
    const s = StreamerHostState();
    expect(s.headsetTipInSetup, isTrue);
    expect(s.copyWith(headset: true).headsetTipInSetup, isFalse);
    expect(s.copyWith(gameAudioOn: false).headsetTipInSetup, isFalse);
    expect(const StreamerHostState(sdkInt: 28).headsetTipInSetup, isFalse);
    const live = StreamerHostState(live: true, gameAudio: StreamerGameAudio.ok);
    expect(live.headsetTipOnAir, isTrue);
    expect(live.copyWith(headsetTipSeen: true).headsetTipOnAir, isFalse);
    expect(live.copyWith(headset: true).headsetTipOnAir, isFalse);
    expect(
      live.copyWith(gameAudio: StreamerGameAudio.failed).headsetTipOnAir,
      isFalse,
    );
  });
}
