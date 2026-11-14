// D243 (owner, staging APK on two Android phones): «عندما أدخل جهاز ككاميرا
// ثانية، الكاميرا الثانية تقف» — the second camera's picture froze / stopped.
//
// Root cause (the second device's screen, D201): the device sits untouched on
// a stand, and nothing kept its screen on, held the live's foreground service
// or followed the app lifecycle. The screen timed out → the activity stopped
// → Android takes the camera from an app that is not in the foreground; the
// published track stayed up with no frames (a frozen picture for viewers and
// the host), and nothing restarted the camera on return. Also, any LiveKit
// reconnect (a network blip: `connected` is false meanwhile) was taken as the
// end: the screen showed «ended» and left the live.
//
// These tests drive the second device's screen with fakes for the media
// session, the foreground service and the keep-screen-on seam, and the real
// `LiveKitMediaEngine` with a stand-in LiveKit room for [LiveSessionLink].

// The stand-in room delivers LiveKit's own room events through LiveKit's
// emitter, as `lk.Room` does internally.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_fx_engine_providers.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/data/live_screen_awake.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/live/tools/second_camera/live_dual_camera_view.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';

// ---- fakes -----------------------------------------------------------------

class _Tools implements LiveToolsRepository {
  final List<String> calls = [];

  @override
  Future<SecondCameraAccess> redeem(String code) async {
    calls.add('redeem:$code');
    return SecondCameraAccess(
      roomId: 'room-1',
      hostUserId: 'u-me',
      url: 'wss://media.example.test',
      token: 'cam2-token',
      expiresAt: DateTime.utc(2030),
      identity: 'cam2:u-me',
    );
  }

  @override
  Future<void> endSecondCamera(String roomId) async => calls.add('end:$roomId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A media session that tells a reconnect from the end (as LiveKit does).
class _Engine extends FakeLiveMediaEngine implements LiveSessionLink {
  bool closed = false;

  @override
  bool get sessionClosed => closed;
}

class _Awake implements LiveScreenAwake {
  final List<bool> calls = [];

  bool get on => calls.isNotEmpty && calls.last;

  @override
  Future<void> keepOn({required bool on}) async => calls.add(on);
}

class _Service implements LiveBackgroundService {
  final List<LiveBackgroundSpec?> calls = [];
  final actionsOut = StreamController<LiveBackgroundAction>.broadcast();

  LiveBackgroundSpec? get shown => calls.isEmpty ? null : calls.last;

  @override
  Stream<LiveBackgroundAction> get actions => actionsOut.stream;

  @override
  Future<void> start(LiveBackgroundSpec spec) async => calls.add(spec);

  @override
  Future<void> stop() async => calls.add(null);
}

// ---- harness ---------------------------------------------------------------

class _Harness {
  final tools = _Tools();
  final awake = _Awake();
  final service = _Service();
}

Future<void> _pump(
  WidgetTester tester,
  _Harness h,
  LiveMediaEngine engine, {
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final overrides = <Override>[
    liveToolsRepositoryProvider.overrideWithValue(h.tools),
    liveMediaEngineProvider.overrideWithValue(() => engine),
    liveScreenAwakeProvider.overrideWithValue(h.awake),
    liveBackgroundServiceProvider.overrideWithValue(h.service),
    // D251: the effects engine follows the admin setting (no server here).
    liveFxEngineProvider.overrideWithValue(LiveFxEngine.deepAr),
  ];
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: app!,
        ),
        home: const SecondCameraScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _join(WidgetTester tester) async {
  await tester.enterText(find.byKey(SecondCameraScreen.codeKey), '123456');
  await tester.pump();
  await tester.tap(find.byKey(SecondCameraScreen.joinKey));
  await tester.pumpAndSettle();
  // D251: the foreground service starts once the camera is on air and
  // settled.
  await tester.pump(SecondCameraScreen.backgroundDelay);
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(SecondCameraScreen).first));

// ---- a stand-in LiveKit room for the real engine ---------------------------

class _Sender implements lk.LocalTrackPublication<lk.LocalAudioTrack> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mic implements lk.LocalAudioTrack {
  @override
  bool get muted => false;

  @override
  Future<bool> start() async => true;

  @override
  Future<bool> stop() async => true;

  @override
  Future<bool> dispose() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Local implements lk.LocalParticipant {
  @override
  Future<lk.LocalTrackPublication<lk.LocalAudioTrack>> publishAudioTrack(
    lk.LocalAudioTrack track, {
    lk.AudioPublishOptions? publishOptions,
  }) async => _Sender();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room implements lk.Room {
  final _Local local = _Local();
  final lk.EventsEmitter<lk.RoomEvent> bus = lk.EventsEmitter();
  lk.ConnectionState state = lk.ConnectionState.connected;

  @override
  lk.ConnectionState get connectionState => state;

  @override
  lk.LocalParticipant get localParticipant => local;

  @override
  String? get metadata => null;

  @override
  lk.EventsListener<lk.RoomEvent> createListener({bool synchronized = false}) =>
      lk.EventsListener<lk.RoomEvent>(bus, synchronized: synchronized);

  @override
  Future<void> connect(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    @Deprecated('deprecated') lk.RoomOptions? roomOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D243 the second device keeps its camera alive', () {
    testWidgets('the screen stays on from joining until leaving; the live '
        "foreground service runs as a seated guest's (microphone type) with "
        "the second camera's words, and stops on leaving", (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      expect(h.awake.calls, isEmpty);
      await _join(tester);
      expect(h.awake.on, isTrue);
      final l10n = _l10n(tester);
      final spec = h.service.shown;
      expect(spec, isNotNull);
      expect(spec!.role, LiveBackgroundRole.guest);
      expect(spec.microphone, isTrue);
      expect(spec.title, l10n.liveCam2OnAir);
      expect(spec.actionLabel, l10n.liveCam2Leave);
      expect(find.byKey(SecondCameraScreen.keepOpenKey), findsOneWidget);
      expect(find.text(l10n.liveCam2KeepOpen), findsOneWidget);
      await tester.tap(find.byKey(SecondCameraScreen.leaveKey));
      await tester.pumpAndSettle();
      expect(h.awake.on, isFalse);
      expect(h.service.shown, isNull);
      expect(h.tools.calls, contains('end:room-1'));
      await _unmount(tester);
    });

    testWidgets('leaving the app pauses the camera (the others see it off, '
        'not a frozen frame); coming back restarts it; the notification '
        'shade (inactive) changes nothing', (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      await _join(tester);
      expect(engine.videoPauses, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(engine.videoPauses, isEmpty);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // D251: told after a short debounce (a system dialog changes nothing).
      expect(engine.videoPauses, isEmpty);
      await tester.pump(SecondCameraScreen.awayDebounce);
      await tester.pump();
      expect(engine.videoPauses, [true]);
      // Still on air meanwhile: the session is kept.
      expect(engine.stops, 0);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(engine.videoPauses, [true, false]);
      expect(find.byKey(SecondCameraScreen.flipKey), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a reconnect (not connected for a while) is not the end; the '
        'session closing for good is', (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      await _join(tester);
      final l10n = _l10n(tester);
      // LiveKit reconnecting: `connected` is false meanwhile.
      engine
        ..dropped = true
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byKey(SecondCameraScreen.endedKey), findsNothing);
      expect(find.text(l10n.liveCam2Connecting), findsOneWidget);
      expect(engine.stops, 0);
      expect(h.awake.on, isTrue);
      // Back.
      engine
        ..dropped = false
        ..ping();
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveCam2OnAir), findsOneWidget);
      // LiveKit gave up (or the room closed): ended.
      engine
        ..dropped = true
        ..closed = true
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byKey(SecondCameraScreen.endedKey), findsOneWidget);
      expect(engine.stops, greaterThanOrEqualTo(1));
      expect(h.awake.on, isFalse);
      expect(h.service.shown, isNull);
      await _unmount(tester);
    });

    testWidgets('removed by the main device: ended at once', (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      await _join(tester);
      engine
        ..dropped = true
        ..kickedOut = true
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byKey(SecondCameraScreen.endedKey), findsOneWidget);
      expect(h.awake.on, isFalse);
      await _unmount(tester);
    });

    testWidgets("the notification's Leave leaves the live", (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      await _join(tester);
      h.service.actionsOut.add(LiveBackgroundAction.end);
      await tester.pumpAndSettle();
      expect(h.tools.calls, contains('end:room-1'));
      expect(engine.stops, greaterThanOrEqualTo(1));
      expect(h.awake.on, isFalse);
      await _unmount(tester);
    });

    testWidgets('closing the screen mid-live lets the screen sleep again', (
      tester,
    ) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      await _join(tester);
      expect(h.awake.on, isTrue);
      await _unmount(tester);
      expect(h.awake.on, isFalse);
      expect(engine.stops, greaterThanOrEqualTo(1));
    });

    for (final language in AppLanguage.values) {
      testWidgets(
        'the keep-open note fits at 360×800 ×1.3 (${language.name})',
        (tester) async {
          final h = _Harness();
          await _pump(
            tester,
            h,
            _Engine(),
            language: language,
            size: const Size(360, 800),
            scale: 1.3,
          );
          await _join(tester);
          expect(find.byKey(SecondCameraScreen.keepOpenKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _unmount(tester);
        },
      );
    }
  });

  group('D243 LiveKitMediaEngine tells a reconnect from the end', () {
    late _Room room;

    setUp(() {
      room = _Room();
      LiveKitMediaEngine.createRoom = () => room;
      LiveKitMediaEngine.createMicrophone = (_) async => _Mic();
    });
    tearDown(() {
      LiveKitMediaEngine.createRoom = lk.Room.new;
      LiveKitMediaEngine.createMicrophone = lk.LocalAudioTrack.create;
    });

    test('reconnecting / resuming: not closed; the final disconnect: '
        'closed', () async {
      final engine = LiveKitMediaEngine();
      var pings = 0;
      engine.changes.addListener(() => pings++);
      await engine.startPreview(video: false);
      await engine.publish(
        LiveMediaAccess(
          url: 'wss://media.test',
          token: 't',
          expiresAt: DateTime(2030),
          role: LiveMediaRole.speaker,
          identity: 'cam2:u-me',
        ),
      );
      expect(engine, isA<LiveSessionLink>());
      expect(engine.sessionClosed, isFalse);
      room.state = lk.ConnectionState.reconnecting;
      final before = pings;
      room.bus.emit(const lk.RoomReconnectingEvent());
      room.bus.emit(const lk.RoomResumingEvent());
      await Future<void>.delayed(Duration.zero);
      expect(pings, greaterThan(before));
      expect(engine.connected, isFalse);
      expect(engine.sessionClosed, isFalse);
      room.state = lk.ConnectionState.connected;
      room.bus.emit(const lk.RoomReconnectedEvent());
      await Future<void>.delayed(Duration.zero);
      expect(engine.connected, isTrue);
      expect(engine.sessionClosed, isFalse);
      room.state = lk.ConnectionState.disconnected;
      room.bus.emit(
        lk.RoomDisconnectedEvent(
          reason: lk.DisconnectReason.signalingConnectionFailure,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(engine.sessionClosed, isTrue);
      expect(engine.removed, isFalse);
    });
  });

  group('D243 the small picture says a tap swaps', () {
    Future<void> pumpView(WidgetTester tester, {Widget? second}) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: KabsoApp.supportedLocales,
          home: LiveDualCameraView(
            host: const ColoredBox(key: Key('host'), color: Color(0xFF112233)),
            second: second,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a swap icon on the small picture; a tap swaps; none without '
        'a second camera', (tester) async {
      await pumpView(
        tester,
        second: const ColoredBox(key: Key('second'), color: Color(0xFF445566)),
      );
      expect(find.byKey(LiveDualCameraView.swapHintKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LiveDualCameraView.pipKey),
          matching: find.byKey(LiveDualCameraView.swapHintKey),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(LiveDualCameraView.pipKey),
          matching: find.byKey(const Key('second')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LiveDualCameraView.pipKey));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(LiveDualCameraView.pipKey),
          matching: find.byKey(const Key('host')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(LiveDualCameraView.swapHintKey), findsOneWidget);
      await pumpView(tester);
      expect(find.byKey(LiveDualCameraView.swapHintKey), findsNothing);
    });
  });
}
