// D251 (owner, int11 APK on two Android phones): «الكاميرا الثانية: تشبك،
// لكن أوّل ما تفتح تعلق ولا تعود تستجيب» — pairing works, then the second
// device hangs as soon as its camera screen goes on air.
//
// Root cause (see the board row): on Android, flutter_webrtc 1.6.2 waits for
// a camera to close (`trackDispose` → `waitForCameraClosed`) and to open
// (`getUserMedia` → `waitForCameraOpen`) on the main thread with no limit,
// and a camera that ends DISCONNECTED reaches neither state. D243 made this
// screen stop and reopen its camera on every app away/back (LiveKit's mute /
// unmute), started the foreground service (a second Flutter engine built on
// the main thread, and Android 13+'s notification dialog over the camera) at
// the moment it went on air, and waited on keep-screen-on and the service
// without limits.
//
// These tests pin the fix: every platform call of the screen is
// time-limited (fakes that throw or never answer must not hang it), the away
// / back is debounced, serialized and never stops the capture, the service
// starts late and never asks the notification permission, and the second
// camera offers the host's filters with the admin's engine.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_fx_engine_providers.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/data/live_screen_awake.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_log.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';

// ---- fakes -----------------------------------------------------------------

/// How a fake platform call behaves.
enum _Mode { ok, throws, hangs }

Future<void> _act(_Mode mode) => switch (mode) {
  _Mode.ok => Future<void>.value(),
  _Mode.throws => Future<void>.error(
    PlatformException(code: 'boom', message: 'secret-free'),
  ),
  _Mode.hangs => Completer<void>().future,
};

class _Tools implements LiveToolsRepository {
  final List<String> calls = [];
  _Mode end = _Mode.ok;

  @override
  Future<SecondCameraAccess> redeem(String code) async {
    calls.add('redeem');
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
  Future<void> endSecondCamera(String roomId) {
    calls.add('end:$roomId');
    return _act(end);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The second device's media session (`_SoftEngine` adds D251's soft pause).
class _Engine extends FakeLiveMediaEngine implements LiveSessionLink {
  bool closed = false;
  _Mode pause = _Mode.ok;
  _Mode stopMode = _Mode.ok;
  _Mode beautyMode = _Mode.ok;
  _Mode flipMode = _Mode.ok;
  Completer<void>? previewHang;

  @override
  bool get sessionClosed => closed;

  @override
  Future<void> startPreview({bool video = true}) async {
    if (previewHang case final hang?) await hang.future;
    await super.startPreview(video: video);
  }

  @override
  Future<void> setVideoPaused({required bool paused}) async {
    await super.setVideoPaused(paused: paused);
    await _act(pause);
  }

  @override
  Future<void> stop() async {
    await super.stop();
    await _act(stopMode);
  }

  final List<LiveBeauty> beauties = [];

  @override
  Future<void> setBeauty(LiveBeauty beauty) async {
    beauties.add(beauty);
    if (beautyMode == _Mode.ok) this.beauty = beauty;
    await _act(beautyMode);
  }

  @override
  Future<void> flipCamera() async {
    await super.flipCamera();
    await _act(flipMode);
  }
}

class _SoftEngine extends _Engine implements LiveSoftVideoPause {
  final List<bool> aways = [];

  @override
  Future<void> setVideoAway({required bool away}) async {
    aways.add(away);
    await _act(pause);
  }
}

class _Awake implements LiveScreenAwake {
  final List<bool> calls = [];
  _Mode mode = _Mode.ok;

  @override
  Future<void> keepOn({required bool on}) {
    calls.add(on);
    return _act(mode);
  }
}

class _Service implements LiveBackgroundService {
  final List<LiveBackgroundSpec?> calls = [];
  final actionsOut = StreamController<LiveBackgroundAction>.broadcast();
  _Mode startMode = _Mode.ok;

  LiveBackgroundSpec? get shown => calls.isEmpty ? null : calls.last;

  @override
  Stream<LiveBackgroundAction> get actions => actionsOut.stream;

  @override
  Future<void> start(LiveBackgroundSpec spec) {
    calls.add(spec);
    return _act(startMode);
  }

  @override
  Future<void> stop() async => calls.add(null);
}

/// A keeper whose hold throws (the platform service broken).
class _BrokenKeeper extends LiveBackgroundKeeper {
  new() : super(_Service());

  @override
  void hold(
    Object owner,
    LiveBackgroundSpec spec, {
    required VoidCallback onEnd,
    VoidCallback? onOpen,
    VoidCallback? onBackground,
    VoidCallback? onForeground,
    VoidCallback? onToggleMic,
    VoidCallback? onToggleCamera,
    VoidCallback? onUnavailable,
  }) => throw StateError('background service broken');
}

/// The admin's `cameraFxEngine` as the app sees it (switchable here).
class _FxEngine extends Notifier<LiveFxEngine> {
  @override
  LiveFxEngine build() => LiveFxEngine.deepAr;

  LiveFxEngine get value => state;

  set value(LiveFxEngine engine) => state = engine;
}

final NotifierProvider<_FxEngine, LiveFxEngine> _fxEngine =
    NotifierProvider<_FxEngine, LiveFxEngine>(_FxEngine.new);

// ---- harness ---------------------------------------------------------------

class _Harness {
  final tools = _Tools();
  final awake = _Awake();
  final service = _Service();
  late ProviderContainer container;
}

Future<void> _pump(
  WidgetTester tester,
  _Harness h,
  LiveMediaEngine engine, {
  AppLanguage language = AppLanguage.ar,
  Size size = const Size(360, 800),
  double scale = 1,
  LiveBackgroundKeeper? keeper,
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
    liveFxEngineProvider.overrideWith((ref) => ref.watch(_fxEngine)),
    if (keeper != null) liveBackgroundKeeperProvider.overrideWithValue(keeper),
  ];
  h.container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  addTearDown(h.container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
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

/// Joins and waits until on air (not for the service).
Future<void> _join(WidgetTester tester) async {
  await tester.enterText(find.byKey(SecondCameraScreen.codeKey), '123456');
  await tester.pump();
  await tester.tap(find.byKey(SecondCameraScreen.joinKey));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _settleService(WidgetTester tester) async {
  await tester.pump(SecondCameraScreen.backgroundDelay);
  await tester.pump();
}

/// Ends with no pending timers (the time limits have run out).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 40));
}

void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
    states.forEach(tester.binding.handleAppLifecycleStateChanged);

const List<AppLifecycleState> _away = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const List<AppLifecycleState> _back = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(SecondCameraScreen).first));

/// The screen still answers: a tap on the microphone toggles it.
Future<void> _responsive(
  WidgetTester tester,
  FakeLiveMediaEngine engine,
) async {
  final before = engine.micEnabled;
  await tester.tap(find.byKey(SecondCameraScreen.micKey));
  await tester.pump();
  await tester.pump();
  expect(engine.micEnabled, !before);
}

// ---- a stand-in camera track for the real engine ---------------------------

class _NativeTrack implements rtc.MediaStreamTrack {
  final List<bool> enabledSets = [];

  @override
  String? get id => 'cam-native-1';

  @override
  set enabled(bool value) => enabledSets.add(value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Camera implements lk.LocalVideoTrack {
  final native = _NativeTrack();
  final List<String> calls = [];
  bool _muted = false;

  @override
  bool get muted => _muted;

  @override
  rtc.MediaStreamTrack get mediaStreamTrack => native;

  @override
  Future<bool> start() async => true;

  @override
  Future<bool> mute({bool stopOnMute = true}) async {
    calls.add('mute stopOnMute=$stopOnMute');
    _muted = true;
    return true;
  }

  @override
  Future<bool> unmute({bool stopOnMute = true}) async {
    calls.add('unmute stopOnMute=$stopOnMute');
    _muted = false;
    return true;
  }

  @override
  Future<bool> stop() async {
    calls.add('stop');
    return true;
  }

  @override
  Future<void> restartTrack([lk.LocalTrackOptions? options]) async =>
      calls.add('restart');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mic implements lk.LocalAudioTrack {
  @override
  bool get muted => false;

  @override
  Future<bool> stop() async => true;

  @override
  Future<bool> dispose() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'D251b a platform error logs its code and a known reason, never ids',
    () {
      expect(
        platformErrorTag(
          PlatformException(
            code: 'switchCameraFailed',
            message: 'Switching camera failed: track-123',
          ),
        ),
        'code=switchCameraFailed why=switch-error',
      );
      expect(
        platformErrorTag(
          PlatformException(
            code: 'switchCameraFailed',
            message: 'Video capturer not found for id: track-9',
          ),
        ),
        'code=switchCameraFailed why=no-capturer',
      );
      expect(
        platformErrorTag(PlatformException(code: 'a b', message: 'secret')),
        isNull,
      );
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  final defaults = (
    keeper: LiveBackgroundKeeper.stepTimeout,
    platform: SecondCameraScreen.platformLimit,
    camera: SecondCameraScreen.cameraLimit,
    join: SecondCameraScreen.joinLimit,
    leave: SecondCameraScreen.leaveLimit,
  );
  setUp(() {
    LiveBackgroundKeeper.stepTimeout = const Duration(seconds: 5);
    SecondCameraScreen.platformLimit = const Duration(seconds: 3);
    SecondCameraScreen.cameraLimit = const Duration(seconds: 6);
    SecondCameraScreen.joinLimit = const Duration(seconds: 20);
    SecondCameraScreen.leaveLimit = const Duration(seconds: 6);
  });
  tearDown(() {
    LiveBackgroundKeeper.stepTimeout = defaults.keeper;
    SecondCameraScreen.platformLimit = defaults.platform;
    SecondCameraScreen.cameraLimit = defaults.camera;
    SecondCameraScreen.joinLimit = defaults.join;
    SecondCameraScreen.leaveLimit = defaults.leave;
  });

  group('D251 platform calls that throw or never answer never hang the '
      'second camera', () {
    for (final mode in [_Mode.throws, _Mode.hangs]) {
      testWidgets('keep-screen-on ${mode.name}: on air, the controls answer, '
          'a note says to touch the screen; leaving still ends', (
        tester,
      ) async {
        final h = _Harness()..awake.mode = mode;
        final engine = _Engine();
        await _pump(tester, h, engine);
        await _join(tester);
        expect(find.byKey(SecondCameraScreen.cameraKey), findsOneWidget);
        await _responsive(tester, engine);
        await tester.pump(SecondCameraScreen.platformLimit);
        await tester.pump();
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.keepAwake)),
          findsOneWidget,
        );
        expect(find.text(_l10n(tester).liveCam2AwakeFailed), findsOneWidget);
        await tester.tap(find.byKey(SecondCameraScreen.leaveKey));
        await tester.pump();
        await tester.pump();
        expect(h.tools.calls, contains('end:room-1'));
        expect(h.awake.calls, [true, false]);
        await _unmount(tester);
      });

      testWidgets('the foreground service ${mode.name}: on air, a note says '
          'to keep the app open; leaving still stops the service', (
        tester,
      ) async {
        final h = _Harness()..service.startMode = mode;
        final engine = _Engine();
        await _pump(tester, h, engine);
        await _join(tester);
        await _settleService(tester);
        expect(h.service.calls, hasLength(1));
        await _responsive(tester, engine);
        await tester.pump(LiveBackgroundKeeper.stepTimeout);
        await tester.pump();
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.background)),
          findsOneWidget,
        );
        expect(
          find.text(_l10n(tester).liveCam2BackgroundFailed),
          findsOneWidget,
        );
        await tester.tap(find.byKey(SecondCameraScreen.leaveKey));
        await tester.pump();
        await tester.pump();
        // A start that never answered no longer blocks the stop.
        expect(h.service.shown, isNull);
        await _unmount(tester);
      });

      testWidgets('pausing the camera ${mode.name} when the app leaves: the '
          'screen answers, one call at a time, a note; back is tried once', (
        tester,
      ) async {
        final h = _Harness();
        final engine = _SoftEngine()..pause = mode;
        await _pump(tester, h, engine);
        await _join(tester);
        await _settleService(tester);
        _lifecycle(tester, _away);
        await tester.pump(SecondCameraScreen.awayDebounce);
        await tester.pump();
        expect(engine.aways, [true]);
        _lifecycle(tester, _back);
        await tester.pump();
        // Still waiting for the first call: nothing stacked on top.
        if (mode == _Mode.hangs) expect(engine.aways, [true]);
        await tester.pump(SecondCameraScreen.cameraLimit);
        await tester.pump();
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.camera)),
          findsOneWidget,
        );
        await _responsive(tester, engine);
        // The latest wish (back) is applied once, after the failure, when
        // the app moves again.
        _lifecycle(tester, _away);
        await tester.pump(SecondCameraScreen.awayDebounce);
        _lifecycle(tester, _back);
        await tester.pump(SecondCameraScreen.cameraLimit);
        await tester.pump();
        // One call per change of wish at most (away, back, away, back).
        expect(engine.aways.length, lessThanOrEqualTo(4));
        await _unmount(tester);
      });

      testWidgets('leaving while the media session ${mode.name} on stop and '
          'the server ${mode.name}: the screen still leaves in time', (
        tester,
      ) async {
        final h = _Harness()..tools.end = mode;
        final engine = _Engine()..stopMode = mode;
        await _pump(tester, h, engine);
        await _join(tester);
        await _settleService(tester);
        await tester.tap(find.byKey(SecondCameraScreen.leaveKey));
        await tester.pump(SecondCameraScreen.leaveLimit * 2);
        await tester.pump();
        expect(engine.stops, greaterThanOrEqualTo(1));
        expect(h.tools.calls, contains('end:room-1'));
        expect(h.service.shown, isNull);
        expect(h.awake.calls.last, isFalse);
        await _unmount(tester);
      });

      testWidgets('flip ${mode.name}: the button comes back and a note says '
          'what to do', (tester) async {
        final h = _Harness();
        final engine = _Engine()..flipMode = mode;
        await _pump(tester, h, engine);
        await _join(tester);
        await tester.tap(find.byKey(SecondCameraScreen.flipKey));
        await tester.pump();
        await tester.pump(SecondCameraScreen.cameraLimit);
        await tester.pump();
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.camera)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(SecondCameraScreen.flipKey));
        await tester.pump();
        expect(engine.flips, 2);
        await _unmount(tester);
      });
    }

    testWidgets('a background keeper whose hold throws: on air with a '
        'note, nothing escapes', (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine, keeper: _BrokenKeeper());
      await _join(tester);
      await _settleService(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.background)),
        findsOneWidget,
      );
      await _responsive(tester, engine);
      await _unmount(tester);
    });

    testWidgets('a camera that never opens while joining: back to the code '
        'with an error after the limit, the screen may sleep again', (
      tester,
    ) async {
      final h = _Harness();
      final engine = _Engine()..previewHang = Completer<void>();
      await _pump(tester, h, engine);
      await _join(tester);
      expect(find.byKey(SecondCameraScreen.cameraKey), findsNothing);
      await tester.pump(SecondCameraScreen.joinLimit);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(SecondCameraScreen.codeKey), findsOneWidget);
      expect(find.text(_l10n(tester).liveCam2Failed), findsOneWidget);
      expect(h.awake.calls, [true, false]);
      expect(h.tools.calls, contains('end:room-1'));
      expect(h.service.calls, isEmpty);
      // The log can be copied from there.
      expect(find.byKey(SecondCameraScreen.copyLogKey), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('D251 the app away / back', () {
    testWidgets('a quick away and back (a system dialog, the permission '
        'sheet) touches no camera; a real away is one call, back one call; '
        'thrash never stacks calls', (tester) async {
      final h = _Harness();
      final engine = _SoftEngine();
      await _pump(tester, h, engine);
      await _join(tester);
      await _settleService(tester);
      for (var i = 0; i < 10; i++) {
        _lifecycle(tester, _away);
        await tester.pump(const Duration(milliseconds: 50));
        _lifecycle(tester, _back);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(SecondCameraScreen.awayDebounce * 2);
      expect(engine.aways, isEmpty);
      expect(engine.videoPauses, isEmpty);
      _lifecycle(tester, _away);
      await tester.pump(SecondCameraScreen.awayDebounce);
      await tester.pump();
      expect(engine.aways, [true]);
      _lifecycle(tester, _back);
      await tester.pump();
      expect(engine.aways, [true, false]);
      // The soft pause only: the capture is never stopped / reopened.
      expect(engine.videoPauses, isEmpty);
      expect(engine.stops, 0);
      await _unmount(tester);
    });

    testWidgets('the foreground service starts after going on air (not '
        'with the camera), never asks the notification permission, and is '
        'not started at all when leaving first', (tester) async {
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine);
      await _join(tester);
      expect(find.byKey(SecondCameraScreen.cameraKey), findsOneWidget);
      expect(h.service.calls, isEmpty);
      await _settleService(tester);
      expect(h.service.shown, isNotNull);
      expect(h.service.shown!.askNotifications, isFalse);
      expect(h.service.shown!.role, LiveBackgroundRole.guest);
      await _unmount(tester);

      final h2 = _Harness();
      await _pump(tester, h2, _Engine());
      await _join(tester);
      await tester.tap(find.byKey(SecondCameraScreen.leaveKey));
      await tester.pump();
      await tester.pump(SecondCameraScreen.backgroundDelay * 2);
      expect(h2.service.calls, isEmpty);
      await _unmount(tester);
    });
  });

  group('D251 the real engine pauses without stopping the capture', () {
    final probe = LiveKitMediaEngine.hdProbe;
    late _Camera camera;
    setUp(() {
      camera = _Camera();
      LiveKitMediaEngine.hdProbe = ({required front}) async => null;
      LiveKitMediaEngine.createCamera = (_) async => camera;
      LiveKitMediaEngine.createMicrophone = (_) async => _Mic();
    });
    tearDown(() {
      LiveKitMediaEngine.hdProbe = probe;
      LiveKitMediaEngine.createCamera = lk.LocalVideoTrack.createCameraTrack;
      LiveKitMediaEngine.createMicrophone = lk.LocalAudioTrack.create;
    });

    test('setVideoAway mutes without stopping (no trackDispose), '
        "keeps the native track enabled for flutter_webrtc's own camera "
        'restart, and unmutes without reopening (no getUserMedia)', () async {
      final engine = LiveKitMediaEngine();
      expect(engine, isA<LiveSoftVideoPause>());
      await engine.startPreview();
      await engine.setVideoAway(away: true);
      expect(camera.calls, ['mute stopOnMute=false']);
      expect(camera.native.enabledSets, [true]);
      expect(engine.videoPaused, isTrue);
      // Twice is nothing.
      await engine.setVideoAway(away: true);
      expect(camera.calls, ['mute stopOnMute=false']);
      await engine.setVideoAway(away: false);
      expect(camera.calls, [
        'mute stopOnMute=false',
        'unmute stopOnMute=false',
      ]);
      expect(camera.calls, isNot(contains('stop')));
      expect(camera.calls, isNot(contains('restart')));
      expect(engine.videoPaused, isFalse);
    });
  });

  group('D251 the keeper never waits for ever', () {
    testWidgets('a start that never answers: the holder hears it is '
        'unavailable, and a later stop still runs', (tester) async {
      final service = _Service()..startMode = _Mode.hangs;
      final keeper = LiveBackgroundKeeper(service);
      var unavailable = 0;
      final owner = Object();
      keeper.hold(
        owner,
        const LiveBackgroundSpec(
          role: LiveBackgroundRole.guest,
          title: 't',
          body: 'b',
          actionLabel: 'a',
          channelName: 'c',
        ),
        onEnd: () {},
        onUnavailable: () => unavailable++,
      );
      await tester.pump();
      expect(service.calls, hasLength(1));
      await tester.pump(LiveBackgroundKeeper.stepTimeout);
      await tester.pump();
      expect(unavailable, 1);
      // The start still has not answered; the stop is not blocked by it.
      keeper.release(owner);
      await tester.pump();
      expect(service.calls.last, isNull);
      keeper.dispose();
    });

    test('a start that throws tells the holder', () async {
      final service = _Service()..startMode = _Mode.throws;
      final keeper = LiveBackgroundKeeper(service);
      var unavailable = 0;
      keeper.hold(
        Object(),
        const LiveBackgroundSpec(
          role: LiveBackgroundRole.host,
          title: 't',
          body: 'b',
          actionLabel: 'a',
          channelName: 'c',
        ),
        onEnd: () {},
        onUnavailable: () => unavailable++,
      );
      await keeper.settled;
      expect(unavailable, 1);
      keeper.dispose();
    });
  });

  group("D251 the second camera has the host's filters", () {
    testWidgets('«بدون فلتر» at first; the filters button opens the '
        'go-live sheet; a colour filter reaches this camera; the badge shows', (
      tester,
    ) async {
      final h = _Harness();
      final engine = _Engine()..supportsFilters = true;
      await _pump(tester, h, engine);
      await _join(tester);
      expect(engine.beauties, isEmpty);
      expect(find.byKey(SecondCameraScreen.filtersKey), findsOneWidget);
      await tester.tap(find.byKey(SecondCameraScreen.filtersKey));
      await tester.pumpAndSettle();
      expect(
        find.byKey(GoLiveKeys.filter(LiveColorFilter.warm)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(GoLiveKeys.filter(LiveColorFilter.warm)));
      await tester.pump();
      await tester.pump();
      expect(engine.beauty.filter, LiveColorFilter.warm);
      await _unmount(tester);
    });

    testWidgets("the admin's engine follows on this camera: FREE shows the "
        "free beauty, back to DeepAR; DeepAR's effects when licensed", (
      tester,
    ) async {
      final h = _Harness();
      final engine = _Engine()
        ..supportsFilters = true
        ..arSupport = LiveArSupport.ready;
      await _pump(tester, h, engine);
      h.container.read(_fxEngine.notifier).value = LiveFxEngine.free;
      await _join(tester);
      await tester.pump();
      expect(engine.enginePicks, [LiveFxEngine.free]);
      await tester.tap(find.byKey(SecondCameraScreen.filtersKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.effectsEngineFree), findsOneWidget);
      expect(find.byKey(GoLiveKeys.freeBeautyOn), findsOneWidget);
      await tester.tap(
        find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur)),
      );
      await tester.pump();
      await tester.pump();
      expect(engine.beauty.effect, LiveArEffect.backgroundBlur);
      Navigator.of(tester.element(find.byKey(GoLiveKeys.freeBeautyOn))).pop();
      await tester.pumpAndSettle();
      // The admin switches the provider back to DeepAR.
      h.container.read(_fxEngine.notifier).value = LiveFxEngine.deepAr;
      await tester.pump();
      await tester.pump();
      expect(engine.enginePicks, [LiveFxEngine.free, LiveFxEngine.deepAr]);
      await tester.tap(find.byKey(SecondCameraScreen.filtersKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.effectsEngineFree), findsNothing);
      expect(
        find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur)),
        findsOneWidget,
      );
      await _unmount(tester);
    });

    for (final mode in [_Mode.throws, _Mode.hangs]) {
      testWidgets('a filter that ${mode.name}: back to «بدون فلتر» with a '
          'note; the camera goes on', (tester) async {
        final h = _Harness();
        final engine = _Engine()
          ..supportsFilters = true
          ..beautyMode = mode;
        await _pump(tester, h, engine);
        await _join(tester);
        await tester.tap(find.byKey(SecondCameraScreen.filtersKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(GoLiveKeys.filter(LiveColorFilter.mono)));
        await tester.pump();
        await tester.pump(SecondCameraScreen.cameraLimit);
        await tester.pump();
        Navigator.of(
          tester.element(find.byKey(GoLiveKeys.filter(LiveColorFilter.mono))),
        ).pop();
        await tester.pumpAndSettle();
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.filters)),
          findsOneWidget,
        );
        expect(engine.beauties.last, const LiveBeauty());
        expect(find.byKey(SecondCameraScreen.cameraKey), findsOneWidget);
        await _responsive(tester, engine);
        await _unmount(tester);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('four controls and the notes fit at 360×800 ×1.3 '
          '(${language.name})', (tester) async {
        final h = _Harness()
          ..awake.mode = _Mode.throws
          ..service.startMode = _Mode.throws;
        await _pump(tester, h, _Engine(), language: language, scale: 1.3);
        await _join(tester);
        await _settleService(tester);
        await tester.pump(SecondCameraScreen.platformLimit);
        await tester.pump();
        expect(find.byKey(SecondCameraScreen.filtersKey), findsOneWidget);
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.keepAwake)),
          findsOneWidget,
        );
        expect(
          find.byKey(SecondCameraScreen.noteKey(SecondCameraNote.background)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    }
  });

  group('D251 the state log', () {
    testWidgets('copied from the camera screen: states and steps, never the '
        'code, the token, ids or error text', (tester) async {
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
      final h = _Harness()..awake.mode = _Mode.throws;
      final engine = _Engine();
      await _pump(tester, h, engine, language: AppLanguage.en);
      await _join(tester);
      await _settleService(tester);
      await tester.tap(find.byKey(SecondCameraScreen.copyLogKey));
      await tester.pump();
      await tester.pump();
      expect(copied, isNotNull);
      final text = copied!;
      expect(text, contains('kabso cam2 log v1'));
      expect(text, contains('phase live'));
      expect(text, contains('preview ok'));
      expect(text, contains('publish ok'));
      expect(text, contains('keep-on failed PlatformException code=boom'));
      expect(text, contains('fgs hold'));
      for (final secret in [
        '123456',
        'cam2-token',
        'room-1',
        'u-me',
        'media.example.test',
        'secret-free',
      ]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
      expect(find.text(_l10n(tester).liveCam2LogCopied), findsOneWidget);
      await _unmount(tester);
    });

    test('keeps the last lines only; guardCall never throws and says how '
        'each call ended', () async {
      final log = SecondCameraLog(capacity: 3);
      for (var i = 0; i < 5; i++) {
        log.add('e$i');
      }
      expect(log.lines.map((l) => l.split(' ').last), ['e2', 'e3', 'e4']);
      final ok = await guardCall(
        log,
        'a',
        const Duration(seconds: 1),
        () async => 7,
      );
      expect(ok.ok, isTrue);
      expect(ok.value, 7);
      final failed = await guardCall<void>(
        log,
        'b',
        const Duration(seconds: 1),
        () => throw StateError('private text'),
      );
      expect(failed.end, Cam2CallEnd.failed);
      final late = await guardCall<void>(
        log,
        'c',
        const Duration(milliseconds: 10),
        () => Completer<void>().future,
      );
      expect(late.end, Cam2CallEnd.timedOut);
      expect(log.lines.join('\n'), isNot(contains('private text')));
      expect(log.lines.last, contains('c timeout'));
    });
  });

  group('D251c the flip', () {
    test("flutter_webrtc's `switchCamera(): ` prefix no longer hides the "
        'reason; ids stay out', () {
      // The owner's log: code=switchCamera and no reason.
      expect(
        platformErrorTag(
          PlatformException(
            code: 'switchCamera',
            message: 'switchCamera(): Switching camera failed: track-123',
          ),
        ),
        'code=switchCamera why=switch-error',
      );
      expect(
        platformErrorTag(
          PlatformException(
            code: 'switchCamera',
            message: 'switchCamera(): Video capturer not found for id: t-9',
          ),
        ),
        'code=switchCamera why=no-capturer',
      );
      final text = platformErrorTag(
        PlatformException(
          code: 'switchCamera',
          message: 'switchCamera(): camera is not running track-123',
        ),
      );
      expect(text, 'code=switchCamera');
    });

    test("the native flip's reason and camera state are kept; anything "
        'else is not', () {
      expect(
        platformErrorTag(
          PlatformException(
            code: 'cameraFlip',
            message: 'why=switch-error state=DISCONNECTED',
          ),
        ),
        'code=cameraFlip why=switch-error state=DISCONNECTED',
      );
      expect(
        platformErrorTag(
          PlatformException(code: 'cameraFlip', message: 'why=no-device'),
        ),
        'code=cameraFlip why=no-device',
      );
      expect(
        platformErrorTag(
          PlatformException(
            code: 'cameraFlip',
            message: 'why=track-123 state=room-1',
          ),
        ),
        'code=cameraFlip',
      );
    });

    test('the native answer keeps fixed words only', () {
      final flip = KabsoCameraFlip.fromMap(const {
        'front': true,
        'path': 'restart',
        'state': 'FREEZED',
      });
      expect(flip.front, isTrue);
      expect(flip.path, 'restart');
      expect(flip.state, 'FREEZED');
      final odd = KabsoCameraFlip.fromMap(const {
        'path': 'track-1',
        'state': 'room-1',
      });
      expect(odd.front, isFalse);
      expect(odd.path, 'other');
      expect(odd.state, isNull);
    });

    test('the flipper asks the plugin for the track, null without a '
        'plugin, and passes a refusal on', () async {
      const channel = MethodChannel('test/flip');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <Object?>[];
      var refuse = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.arguments);
        if (call.method != 'flipCamera') return null;
        if (refuse) {
          throw PlatformException(
            code: 'cameraFlip',
            message: 'why=switch-busy',
          );
        }
        return {'front': false, 'path': 'switch', 'state': 'OPENED'};
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final flipper = KabsoCameraFlipper(channel: channel, supported: true);
      final flip = await flipper.flip('t-1');
      expect(calls.single, {'trackId': 't-1'});
      expect(flip?.path, 'switch');
      expect(flip?.front, isFalse);
      refuse = true;
      await expectLater(flipper.flip('t-1'), throwsA(isA<PlatformException>()));
      expect(
        await KabsoCameraFlipper(channel: channel, supported: false).flip('t'),
        isNull,
      );
      messenger.setMockMethodCallHandler(channel, null);
      expect(await flipper.flip('t-1'), isNull);
    });

    testWidgets('the log says which path flipped the camera', (tester) async {
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
      final before = LiveKitMediaEngine.lastFlipPath;
      LiveKitMediaEngine.lastFlipPath = 'restart state=DISCONNECTED';
      addTearDown(() => LiveKitMediaEngine.lastFlipPath = before);
      final h = _Harness();
      final engine = _Engine();
      await _pump(tester, h, engine, language: AppLanguage.en);
      await _join(tester);
      await _settleService(tester);
      await tester.tap(find.byKey(SecondCameraScreen.flipKey));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(SecondCameraScreen.copyLogKey));
      await tester.pump();
      await tester.pump();
      expect(engine.flips, 1);
      expect(copied, contains('flip ok'));
      expect(copied, contains('flip-path restart state=DISCONNECTED'));
      await _unmount(tester);
    });
  });
}
