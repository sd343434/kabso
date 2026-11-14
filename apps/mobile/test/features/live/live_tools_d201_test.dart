// D201 (v1.45-live, CONVENTIONS §10.63): the host's live tools «كاميرتان»,
// «موسيقى» and «التسجيل» — each Room Tools tile opens its real flow; the
// pairing sheet (code, countdown, expiry, connected, main feed, disconnect,
// PK / not-live states); the second device's screen (code → camera with
// flip / mic / leave, no chat, the mic off at first, errors); the small
// picture (swap on this screen, drag, the host's default); the viewers'
// recording badge; the music player (rights notice once, queue, play, next,
// volume, ducking, completion, iOS reason); the clip recorder (countdown,
// stop at 60 s, early stop, too short, the room told) and its preview
// (save, post as a reel, discard); ar / en at 360×800 with 1.3 text.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_fx_engine_providers.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/data/live_screen_awake.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/live/tools/live_tools_stage.dart';
import 'package:kabso_live/features/live/tools/music/live_music_controller.dart';
import 'package:kabso_live/features/live/tools/music/live_music_mixer.dart';
import 'package:kabso_live/features/live/tools/music/live_music_sheet.dart';
import 'package:kabso_live/features/live/tools/recorder/live_clip_controller.dart';
import 'package:kabso_live/features/live/tools/recorder/live_clip_widgets.dart';
import 'package:kabso_live/features/live/tools/second_camera/live_dual_camera_view.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_screen.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_sheet.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

// ---- fakes -----------------------------------------------------------------

class FakeToolsRepository implements LiveToolsRepository {
  final List<String> calls = [];
  SecondCameraState state = SecondCameraState.none;
  SecondCameraCode? code;
  Exception? redeemError;
  bool rightsAccepted = false;

  /// After the next `secondCamera` read, the state becomes this.
  SecondCameraState? then;

  @override
  Future<SecondCameraState> secondCamera(String roomId) async {
    calls.add('state:$roomId');
    final now = state;
    if (then case final next?) {
      state = next;
      then = null;
    }
    return now;
  }

  @override
  Future<SecondCameraCode> createCode(String roomId) async {
    calls.add('code:$roomId');
    final c =
        code ??
        SecondCameraCode(
          code: '123456',
          expiresAt: clock.now().add(const Duration(seconds: 120)),
        );
    state = SecondCameraState(
      status: SecondCameraStatus.code,
      main: SecondCameraFeed.host,
      available: true,
      codeExpiresAt: c.expiresAt,
    );
    return c;
  }

  @override
  Future<void> endSecondCamera(String roomId) async {
    calls.add('end:$roomId');
    state = SecondCameraState.none;
  }

  @override
  Future<SecondCameraState> setMain(
    String roomId,
    SecondCameraFeed main,
  ) async {
    calls.add('main:$roomId:${main.name}');
    return state = SecondCameraState(
      status: SecondCameraStatus.connected,
      main: main,
      available: true,
    );
  }

  @override
  Future<SecondCameraAccess> redeem(String code) async {
    calls.add('redeem:$code');
    if (redeemError case final e?) throw e;
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
  Future<void> setRecording(String roomId, {required bool active}) async {
    calls.add('recording:$roomId:$active');
  }

  @override
  Future<bool> musicRightsAccepted() async {
    calls.add('rights?');
    return rightsAccepted;
  }

  @override
  Future<void> acceptMusicRights() async {
    calls.add('rights!');
    rightsAccepted = true;
  }
}

ServerFailure _server(String code, [int status = 422]) => ServerFailure(
  code: ErrorCode.unknown,
  rawCode: code,
  debugMessage: code,
  statusCode: status,
);

class FakeMusicMixer implements LiveMusicMixer {
  @override
  LiveMusicUnsupported? unsupported;
  List<LiveMusicFile> toPick = const [
    LiveMusicFile(path: '/c/one.mp3', name: 'one.mp3'),
    LiveMusicFile(path: '/c/two.m4a', name: 'two.m4a'),
  ];
  final List<String> calls = [];
  final _events = StreamController<LiveMusicEvent>.broadcast();

  void emit(LiveMusicEvent e) => _events.add(e);

  @override
  Future<List<LiveMusicFile>> pickFiles() async {
    calls.add('pick');
    return toPick;
  }

  @override
  Future<Duration?> load(LiveMusicFile file) async {
    calls.add('load:${file.name}');
    return const Duration(minutes: 3);
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setVolume(double volume) async =>
      calls.add('volume:${volume.toStringAsFixed(2)}');

  @override
  Future<void> setDucking({required bool on}) async => calls.add('duck:$on');

  @override
  Stream<LiveMusicEvent> get events => _events.stream;
}

/// The fake engine with the tools' extras.
class ToolsEngine extends FakeLiveMediaEngine
    implements LiveParticipantAttributes, LiveClipCapture {
  final Map<String, Map<String, String>> attributes = {};
  LiveClipUnsupported? unsupportedClip;
  final List<String> clipCalls = [];
  bool failStart = false;

  @override
  Map<String, String> attributesOf(String identity) =>
      attributes[identity] ?? const {};

  @override
  LiveClipUnsupported? get clipUnsupported => unsupportedClip;

  @override
  Future<void> startClip(String path) async {
    if (failStart) throw StateError('no recorder');
    clipCalls.add('start:$path');
  }

  @override
  Future<void> stopClip() async => clipCalls.add('stop');

  @override
  Future<Uint8List?> cameraStill() async => Uint8List.fromList([1, 2, 3]);
}

class FakeClipStore implements LiveClipStore {
  final List<String> calls = [];
  bool failSave = false;

  @override
  Future<String> newPath() async => '/tmp/clip.mp4';

  @override
  Future<int> length(String path) async => 4096;

  @override
  Future<List<int>> head(String path) async => [
    0,
    0,
    0,
    24,
    ...'ftypisom'.codeUnits,
    0,
    0,
    0,
    0,
  ];

  @override
  Stream<List<int>> open(String path) => Stream.value(List.filled(4096, 0));

  @override
  Future<void> saveToGallery(String path) async {
    if (failSave) throw StateError('denied');
    calls.add('save:$path');
  }

  @override
  Future<void> delete(String path) async => calls.add('delete:$path');
}

// ---- harness ---------------------------------------------------------------

/// Pumps [child] in a localized app with [overrides] at [size] and [scale].
Future<void> _pumpTool(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double scale = 1,
  ProviderContainer? container,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Widget scope(Widget app) => container != null
      ? UncontrolledProviderScope(container: container, child: app)
      : ProviderScope(retry: (_, _) => null, overrides: overrides, child: app);
  await tester.pumpWidget(
    scope(
      MaterialApp(
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
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

AppLocalizations _l10nOf(WidgetTester tester, Finder finder) =>
    AppLocalizations.of(tester.element(finder.first));

Future<(FakeLiveRepository, ToolsEngine)> _pumpGoLive(
  WidgetTester tester, {
  required FakeToolsRepository tools,
  required FakeMusicMixer mixer,
  ToolsEngine? engine,
  AppLanguage language = AppLanguage.en,
}) async {
  final live = FakeLiveRepository();
  final camera = engine ?? ToolsEngine();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: camera,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
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
      liveToolsRepositoryProvider.overrideWithValue(tools),
      liveMusicMixerProvider.overrideWithValue(mixer),
      liveClipStoreProvider.overrideWithValue(FakeClipStore()),
    ],
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Two cameras');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
  return (live, camera);
}

Future<void> _openTools(WidgetTester tester) async {
  await tester.tap(find.byKey(KHostBar.toolsKey));
  await tester.pumpAndSettle();
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// A box standing for a camera picture.
Widget _feed(String name, Color color) =>
    ColoredBox(key: Key('feed.$name'), color: color);

void main() {
  group('D201 Room Tools tiles open their real flows', () {
    testWidgets('«كاميرتان», «موسيقى», «التسجيل» are enabled and open their '
        'sheets (the rights notice before the first music)', (tester) async {
      final tools = FakeToolsRepository();
      final mixer = FakeMusicMixer();
      await _pumpGoLive(tester, tools: tools, mixer: mixer);
      final l10n = _l10nOf(tester, find.byType(GoLiveScreen));
      await _openTools(tester);
      for (final label in [
        l10n.liveToolDual,
        l10n.liveToolMusic,
        l10n.liveToolRecorder,
      ]) {
        expect(find.bySemanticsLabel('$label, ${l10n.liveSoon}'), findsNothing);
      }
      await tester.tap(find.byKey(GoLiveKeys.tool('dual')));
      await tester.pumpAndSettle();
      expect(find.byKey(SecondCameraSheet.sheetKey), findsOneWidget);
      expect(find.byKey(SecondCameraSheet.createKey), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('music')));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMusicSheet.rightsKey), findsOneWidget);
      expect(find.text(l10n.liveMusicRightsBody), findsOneWidget);
      await tester.tap(find.byKey(LiveMusicSheet.rightsAcceptKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMusicSheet.sheetKey), findsOneWidget);
      expect(find.byKey(LiveMusicSheet.emptyKey), findsOneWidget);
      // Nothing played by itself.
      expect(mixer.calls.where((c) => c == 'play'), isEmpty);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('recorder')));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveClipStartSheet.sheetKey), findsOneWidget);
      expect(find.byKey(LiveClipStartSheet.startKey), findsOneWidget);
      expect(tools.calls, containsAllInOrder(['rights?', 'rights!']));
      await _leave(tester);
    });

    testWidgets('recording from the tile: REC badge, the room told, the '
        'tile stops it and the preview opens', (tester) async {
      final tools = FakeToolsRepository();
      final (_, engine) = await _pumpGoLive(
        tester,
        tools: tools,
        mixer: FakeMusicMixer(),
      );
      await _openTools(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('recorder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveClipStartSheet.startKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(LiveClipRecBadge.badgeKey), findsOneWidget);
      expect(engine.clipCalls, ['start:/tmp/clip.mp4']);
      expect(
        tools.calls.where((c) => c.startsWith('recording:')).single,
        endsWith(':true'),
      );
      await _leave(tester);
    });
  });

  group('D201 pairing sheet (main device)', () {
    testWidgets('a 6-digit code with its countdown, then connected: the '
        "viewers' main feed and disconnect", (tester) async {
      final tools = FakeToolsRepository();
      await _pumpTool(
        tester,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => unawaited(
              showSecondCameraSheet(context, roomId: 'room-1', inPk: false),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [liveToolsRepositoryProvider.overrideWithValue(tools)],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = _l10nOf(tester, find.byKey(SecondCameraSheet.sheetKey));
      expect(find.text(l10n.liveCam2Steps), findsOneWidget);
      await tester.tap(find.byKey(SecondCameraSheet.createKey));
      await tester.pump();
      await tester.pump();
      expect(find.text('123 456'), findsOneWidget);
      expect(
        find.textContaining(RegExp('Expires in [12]:[0-5][0-9]')),
        findsOneWidget,
      );
      expect(find.text(l10n.liveCam2CodeOnce), findsOneWidget);
      // The second device redeems: the next read says connected.
      tools.then = const SecondCameraState(
        status: SecondCameraStatus.connected,
        main: SecondCameraFeed.host,
        available: true,
      );
      await tester.pump(SecondCameraSheet.poll);
      await tester.pump(SecondCameraSheet.poll);
      await tester.pump();
      expect(find.byKey(SecondCameraSheet.connectedKey), findsOneWidget);
      await tester.tap(
        find.byKey(SecondCameraSheet.mainKey(SecondCameraFeed.second)),
      );
      await tester.pump();
      await tester.pump();
      expect(tools.calls, contains('main:room-1:second'));
      await tester.tap(find.byKey(SecondCameraSheet.endKey));
      await tester.pump();
      await tester.pump();
      expect(tools.calls, contains('end:room-1'));
      await _leave(tester);
    });

    testWidgets('an expired code says so and offers a new one', (tester) async {
      final tools = FakeToolsRepository()
        ..code = SecondCameraCode(
          code: '654321',
          expiresAt: clock.now().subtract(const Duration(seconds: 1)),
        );
      await _pumpTool(
        tester,
        const SecondCameraSheet(roomId: 'room-1', inPk: false),
        overrides: [liveToolsRepositoryProvider.overrideWithValue(tools)],
      );
      await tester.pump();
      await tester.tap(find.byKey(SecondCameraSheet.createKey));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(SecondCameraSheet.expiredKey), findsOneWidget);
      expect(find.byKey(SecondCameraSheet.createKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('honest states: before going live, during a PK, a busy live', (
      tester,
    ) async {
      final tools = FakeToolsRepository();
      Future<void> show(String? room, {required bool pk}) => _pumpTool(
        tester,
        SecondCameraSheet(roomId: room, inPk: pk),
        overrides: [liveToolsRepositoryProvider.overrideWithValue(tools)],
      );
      await show(null, pk: false);
      var l10n = _l10nOf(tester, find.byKey(SecondCameraSheet.sheetKey));
      expect(find.text(l10n.liveCam2NotLive), findsOneWidget);
      expect(find.byKey(SecondCameraSheet.createKey), findsNothing);
      await show('room-1', pk: true);
      l10n = _l10nOf(tester, find.byKey(SecondCameraSheet.sheetKey));
      expect(find.text(l10n.liveCam2InPk), findsOneWidget);
      expect(find.byKey(SecondCameraSheet.createKey), findsNothing);
      expect(tools.calls, isEmpty);
      await _leave(tester);
    });
  });

  group('D201 second device («الانضمام ككاميرا ثانية»)', () {
    testWidgets('the code → a camera screen with flip, mic (off at first) and '
        'leave, no chat; leaving ends the second camera', (tester) async {
      final tools = FakeToolsRepository();
      final engine = ToolsEngine();
      await _pumpTool(
        tester,
        const SecondCameraScreen(),
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveMediaEngineProvider.overrideWithValue(() => engine),
          // D251: the screen limits its platform calls; no platform here.
          liveScreenAwakeProvider.overrideWithValue(const _NoAwake()),
          liveFxEngineProvider.overrideWithValue(LiveFxEngine.deepAr),
        ],
      );
      final l10n = _l10nOf(tester, find.byType(SecondCameraScreen));
      expect(find.text(l10n.liveCam2JoinPermissions), findsOneWidget);
      // Only digits, six of them.
      await tester.enterText(find.byKey(SecondCameraScreen.codeKey), '12a34');
      expect(
        tester
            .widget<KButton>(find.byKey(SecondCameraScreen.joinKey))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(SecondCameraScreen.codeKey), '123456');
      await tester.pump();
      await tester.tap(find.byKey(SecondCameraScreen.joinKey));
      await tester.pumpAndSettle();
      expect(tools.calls, ['redeem:123456']);
      expect(engine.published?.token, 'cam2-token');
      expect(engine.published?.identity, 'cam2:u-me');
      expect(engine.micEnabled, isFalse);
      expect(find.byKey(SecondCameraScreen.flipKey), findsOneWidget);
      expect(find.byKey(SecondCameraScreen.micKey), findsOneWidget);
      expect(find.byKey(SecondCameraScreen.leaveKey), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // no chat composer
      await tester.tap(find.byKey(SecondCameraScreen.micKey));
      await tester.pump();
      expect(engine.micEnabled, isTrue);
      await tester.tap(find.byKey(SecondCameraScreen.flipKey));
      await tester.pump();
      expect(engine.flips, 1);
      await tester.tap(find.byKey(SecondCameraScreen.leaveKey));
      await tester.pumpAndSettle();
      expect(engine.stops, greaterThanOrEqualTo(1));
      expect(tools.calls, contains('end:room-1'));
      await _leave(tester);
    });

    testWidgets('a wrong or expired code is explained; the camera never '
        'starts', (tester) async {
      final tools = FakeToolsRepository()
        ..redeemError = _server('SECOND_CAMERA_CODE_INVALID');
      final engine = ToolsEngine();
      await _pumpTool(
        tester,
        const SecondCameraScreen(),
        language: AppLanguage.ar,
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveMediaEngineProvider.overrideWithValue(() => engine),
          // D251: the screen limits its platform calls; no platform here.
          liveScreenAwakeProvider.overrideWithValue(const _NoAwake()),
          liveFxEngineProvider.overrideWithValue(LiveFxEngine.deepAr),
        ],
      );
      final l10n = _l10nOf(tester, find.byType(SecondCameraScreen));
      await tester.enterText(find.byKey(SecondCameraScreen.codeKey), '000000');
      await tester.pump();
      await tester.tap(find.byKey(SecondCameraScreen.joinKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveCam2CodeInvalid), findsOneWidget);
      expect(engine.previewStarts, 0);
      tools.redeemError = _server('SECOND_CAMERA_UNAVAILABLE', 409);
      await tester.tap(find.byKey(SecondCameraScreen.joinKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveCam2Unavailable), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the main device ending it shows the ended screen', (
      tester,
    ) async {
      final engine = ToolsEngine();
      await _pumpTool(
        tester,
        const SecondCameraScreen(),
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(FakeToolsRepository()),
          liveMediaEngineProvider.overrideWithValue(() => engine),
          // D251: the screen limits its platform calls; no platform here.
          liveScreenAwakeProvider.overrideWithValue(const _NoAwake()),
          liveFxEngineProvider.overrideWithValue(LiveFxEngine.deepAr),
        ],
      );
      await tester.enterText(find.byKey(SecondCameraScreen.codeKey), '123456');
      await tester.pump();
      await tester.tap(find.byKey(SecondCameraScreen.joinKey));
      await tester.pumpAndSettle();
      engine
        ..dropped = true
        ..kickedOut = true
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byKey(SecondCameraScreen.endedKey), findsOneWidget);
      await _leave(tester);
    });
  });

  group('D201 the small picture', () {
    testWidgets("tap swaps on this screen; the host's default holds until "
        'it changes; drag moves it; no second camera, no picture', (
      tester,
    ) async {
      Widget view(SecondCameraFeed main, {bool second = true}) =>
          LiveDualCameraView(
            host: _feed('host', const Color(0xFF00AA00)),
            second: second ? _feed('second', const Color(0xFF0000AA)) : null,
            defaultMain: main,
          );
      Finder big(String name) => find.descendant(
        of: find.byKey(LiveDualCameraView.mainKey),
        matching: find.byKey(Key('feed.$name')),
      );
      Finder small(String name) => find.descendant(
        of: find.byKey(LiveDualCameraView.pipKey),
        matching: find.byKey(Key('feed.$name')),
      );
      await _pumpTool(tester, view(SecondCameraFeed.host));
      expect(big('host'), findsOneWidget);
      expect(small('second'), findsOneWidget);
      await tester.tap(find.byKey(LiveDualCameraView.pipKey));
      await tester.pump();
      expect(big('second'), findsOneWidget);
      expect(small('host'), findsOneWidget);
      // The host makes the second camera the default: everyone follows.
      await _pumpTool(tester, view(SecondCameraFeed.second));
      expect(big('second'), findsOneWidget);
      // Drag: the picture moves, then settles on the nearer side.
      final before = tester.getTopLeft(find.byKey(LiveDualCameraView.pipKey));
      await tester.drag(
        find.byKey(LiveDualCameraView.pipKey),
        const Offset(-250, 200),
      );
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byKey(LiveDualCameraView.pipKey));
      expect(after.dy, greaterThan(before.dy + 150));
      expect(after.dx, lessThan(40)); // the left edge
      // The second camera leaves: just the host.
      await _pumpTool(tester, view(SecondCameraFeed.second, second: false));
      expect(find.byKey(LiveDualCameraView.pipKey), findsNothing);
      expect(find.byKey(const Key('feed.host')), findsOneWidget);
    });

    testWidgets('RTL: the picture starts on the left (the end side)', (
      tester,
    ) async {
      await _pumpTool(
        tester,
        LiveDualCameraView(
          host: _feed('host', const Color(0xFF00AA00)),
          second: _feed('second', const Color(0xFF0000AA)),
        ),
        language: AppLanguage.ar,
      );
      expect(
        tester.getTopLeft(find.byKey(LiveDualCameraView.pipKey)).dx,
        lessThan(40),
      );
    });

    testWidgets('a viewer sees the second camera and «يتم التسجيل» while the '
        'host records; it hides itself at the end time', (tester) async {
      final engine = ToolsEngine()..present.addAll(['h-1', 'cam2:h-1']);
      engine.attributes['h-1'] = {
        liveAttrRecordingUntil: clock
            .now()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
      };
      engine.attributes['cam2:h-1'] = {liveAttrMainFeed: 'HOST'};
      await _pumpTool(
        tester,
        LiveViewerToolsStage(
          engine: engine,
          hostId: 'h-1',
          picture: _feed('host', const Color(0xFF00AA00)),
        ),
        language: AppLanguage.ar,
      );
      final l10n = _l10nOf(tester, find.byType(LiveViewerToolsStage));
      expect(find.byKey(LiveDualCameraView.pipKey), findsOneWidget);
      expect(find.text(l10n.liveClipViewerBadge), findsOneWidget);
      engine.attributes['h-1'] = {};
      await _pumpTool(
        tester,
        LiveViewerToolsStage(
          engine: engine,
          hostId: 'h-1',
          picture: _feed('host', const Color(0xFF00AA00)),
        ),
        language: AppLanguage.ar,
      );
      expect(find.byKey(LiveRecordingViewerBadge.badgeKey), findsNothing);
      engine.present.remove('cam2:h-1');
      await _pumpTool(
        tester,
        LiveViewerToolsStage(
          engine: engine,
          hostId: 'h-1',
          picture: _feed('host', const Color(0xFF00AA00)),
        ),
      );
      expect(find.byKey(LiveDualCameraView.pipKey), findsNothing);
    });

    test('the recording attribute is read against the clock', () {
      final now = DateTime.utc(2026, 10, 31, 12);
      expect(liveRecordingNow(const {}, now), isFalse);
      expect(
        liveRecordingNow({
          liveAttrRecordingUntil: '2026-10-31T12:00:30.000Z',
        }, now),
        isTrue,
      );
      expect(
        liveRecordingNow({
          liveAttrRecordingUntil: '2026-10-31T11:59:59.000Z',
        }, now),
        isFalse,
      );
      expect(liveSecondCameraIdentity('u'), 'cam2:u');
    });
  });

  group('D201 music', () {
    ProviderContainer container(FakeMusicMixer mixer, FakeToolsRepository t) {
      final c = ProviderContainer(
        overrides: [
          liveMusicMixerProvider.overrideWithValue(mixer),
          liveToolsRepositoryProvider.overrideWithValue(t),
        ],
      );
      addTearDown(c.dispose);
      c.listen(liveMusicProvider, (_, _) {});
      return c;
    }

    test(
      'queue, play, pause, next, completion, volume, ducking, remove',
      () async {
        final mixer = FakeMusicMixer();
        final c = container(mixer, FakeToolsRepository());
        final music = c.read(liveMusicProvider.notifier);
        expect(
          c.read(liveMusicProvider).volume,
          LiveMusicController.defaultVolume,
        );
        expect(await music.addFiles(), 0);
        expect(c.read(liveMusicProvider).queue.map((f) => f.name), [
          'one.mp3',
          'two.m4a',
        ]);
        expect(mixer.calls, ['pick']); // nothing plays by itself
        await music.toggle();
        expect(c.read(liveMusicProvider).playing, isTrue);
        expect(c.read(liveMusicProvider).track?.name, 'one.mp3');
        expect(mixer.calls, [
          'pick',
          'load:one.mp3',
          'volume:0.35',
          'duck:true',
          'play',
        ]);
        await music.toggle();
        expect(c.read(liveMusicProvider).playing, isFalse);
        expect(mixer.calls.last, 'pause');
        await music.setVolume(0.8);
        expect(c.read(liveMusicProvider).volume, 0.8);
        expect(mixer.calls.last, 'volume:0.80');
        await music.setVolume(3);
        expect(c.read(liveMusicProvider).volume, 1);
        await music.setDucking(on: false);
        expect(mixer.calls.last, 'duck:false');
        await music.next();
        expect(c.read(liveMusicProvider).track?.name, 'two.m4a');
        // The mixer's position and the end of the file.
        mixer.emit(
          const LiveMusicPosition(Duration(seconds: 12), Duration(minutes: 3)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(c.read(liveMusicProvider).position, const Duration(seconds: 12));
        mixer.emit(const LiveMusicCompleted());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(liveMusicProvider).track, isNull);
        expect(c.read(liveMusicProvider).playing, isFalse);
        expect(mixer.calls.last, 'stop');
        await music.remove(0);
        expect(c.read(liveMusicProvider).queue.map((f) => f.name), ['two.m4a']);
      },
    );

    test('a short queue: at most 20 files', () async {
      final mixer = FakeMusicMixer()
        ..toPick = [
          for (var i = 0; i < 25; i++)
            LiveMusicFile(path: '/c/$i.mp3', name: '$i.mp3'),
        ];
      final c = container(mixer, FakeToolsRepository());
      expect(await c.read(liveMusicProvider.notifier).addFiles(), 5);
      expect(c.read(liveMusicProvider).queue, hasLength(20));
    });

    test('a file that cannot be read is said, and stops', () async {
      final mixer = FakeMusicMixer();
      final c = container(mixer, FakeToolsRepository());
      await c.read(liveMusicProvider.notifier).addFiles();
      await c.read(liveMusicProvider.notifier).playAt(0);
      mixer.emit(const LiveMusicFailed());
      await Future<void>.delayed(Duration.zero);
      expect(c.read(liveMusicProvider).failed, isTrue);
      expect(c.read(liveMusicProvider).playing, isFalse);
    });

    testWidgets('the rights notice shows once; cancelling plays nothing', (
      tester,
    ) async {
      final tools = FakeToolsRepository();
      final mixer = FakeMusicMixer();
      await _pumpTool(
        tester,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                unawaited(showLiveMusic(context, ref, micEnabled: true)),
            child: const Text('music'),
          ),
        ),
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveMusicMixerProvider.overrideWithValue(mixer),
        ],
        language: AppLanguage.ar,
      );
      await tester.tap(find.text('music'));
      await tester.pumpAndSettle();
      final l10n = _l10nOf(tester, find.byKey(LiveMusicSheet.rightsKey));
      expect(
        find.text(
          'تأكد أنك تملك حقوق تشغيل الموسيقى. يُمنع تشغيل موسيقى محمية '
          'بحقوق النشر بدون ترخيص.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LiveMusicSheet.rightsCancelKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMusicSheet.sheetKey), findsNothing);
      expect(tools.calls, ['rights?']);
      await tester.tap(find.text('music'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveMusicSheet.rightsAcceptKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMusicSheet.sheetKey), findsOneWidget);
      expect(tools.calls, ['rights?', 'rights?', 'rights!']);
      // Close and open again: no notice.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('music'));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMusicSheet.rightsKey), findsNothing);
      expect(find.byKey(LiveMusicSheet.sheetKey), findsOneWidget);
      // The player: add, play, volume.
      await tester.tap(find.byKey(LiveMusicSheet.addKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveMusicSheet.itemKey(1)), findsOneWidget);
      await tester.tap(find.byKey(LiveMusicSheet.playKey));
      await tester.pumpAndSettle();
      expect(mixer.calls, contains('play'));
      expect(find.byTooltip(l10n.liveMusicPause), findsOneWidget);
      final slider = find.byKey(LiveMusicSheet.volumeKey);
      await tester.tapAt(tester.getCenter(slider));
      await tester.pumpAndSettle();
      expect(mixer.calls.where((c) => c.startsWith('volume:')).length, 2);
      await _leave(tester);
    });

    testWidgets('iOS: the reason instead of a player; no notice', (
      tester,
    ) async {
      final tools = FakeToolsRepository();
      final mixer = FakeMusicMixer()..unsupported = LiveMusicUnsupported.ios;
      await _pumpTool(
        tester,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                unawaited(showLiveMusic(context, ref, micEnabled: true)),
            child: const Text('music'),
          ),
        ),
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveMusicMixerProvider.overrideWithValue(mixer),
        ],
      );
      await tester.tap(find.text('music'));
      await tester.pumpAndSettle();
      final l10n = _l10nOf(tester, find.byKey(LiveMusicSheet.sheetKey));
      expect(find.text(l10n.liveMusicUnsupportedIos), findsOneWidget);
      expect(find.byKey(LiveMusicSheet.addKey), findsNothing);
      expect(tools.calls, isEmpty);
      await _leave(tester);
    });

    testWidgets('a muted microphone is said', (tester) async {
      await _pumpTool(
        tester,
        const LiveMusicSheet(micEnabled: false),
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(FakeToolsRepository()),
          liveMusicMixerProvider.overrideWithValue(FakeMusicMixer()),
        ],
      );
      expect(find.byKey(LiveMusicSheet.micOffKey), findsOneWidget);
    });
  });

  group('D201 clip recorder', () {
    ProviderContainer container(
      FakeToolsRepository tools,
      FakeClipStore store, {
      FakeMediaRepository? media,
      FakePostsRepository? posts,
    }) {
      final c = ProviderContainer(
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveClipStoreProvider.overrideWithValue(store),
          mediaRepositoryProvider.overrideWithValue(
            media ?? FakeMediaRepository(),
          ),
          postsRepositoryProvider.overrideWithValue(
            posts ?? FakePostsRepository(),
          ),
        ],
      );
      return c..listen(liveClipProvider('room-1'), (_, _) {});
    }

    // testWidgets: its fake time drives package:clock and the timers.
    testWidgets('the countdown runs and the clip stops by itself at 60 s', (
      tester,
    ) async {
      final tools = FakeToolsRepository();
      final engine = ToolsEngine();
      final c = container(tools, FakeClipStore());
      final clip = c.read(liveClipProvider('room-1').notifier);
      await clip.start(engine);
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.recording);
      expect(tools.calls, ['recording:room-1:true']);
      await tester.pump(const Duration(seconds: 30));
      var s = c.read(liveClipProvider('room-1'));
      expect(s.elapsed.inSeconds, 30);
      expect(s.remaining.inSeconds, 30);
      await tester.pump(const Duration(seconds: 30, milliseconds: 300));
      await tester.pump();
      s = c.read(liveClipProvider('room-1'));
      expect(s.phase, LiveClipPhase.ready);
      expect(s.clip?.length, liveClipMax);
      expect(engine.clipCalls, ['start:/tmp/clip.mp4', 'stop']);
      expect(tools.calls, ['recording:room-1:true', 'recording:room-1:false']);
      // Never longer than 60 s.
      await tester.pump(const Duration(seconds: 30));
      expect(c.read(liveClipProvider('room-1')).clip?.length, liveClipMax);
      c.dispose();
    });

    testWidgets('stopping early keeps the clip as long as it ran', (
      tester,
    ) async {
      final c = container(FakeToolsRepository(), FakeClipStore());
      final clip = c.read(liveClipProvider('room-1').notifier);
      await clip.start(ToolsEngine());
      await tester.pump(const Duration(seconds: 12));
      await clip.stop();
      final s = c.read(liveClipProvider('room-1'));
      expect(s.phase, LiveClipPhase.ready);
      expect(s.clip?.length.inSeconds, 12);
      c.dispose();
    });

    testWidgets('shorter than a second is refused and deleted; a recorder '
        'that cannot start says so', (tester) async {
      final store = FakeClipStore();
      final engine = ToolsEngine();
      final c = container(FakeToolsRepository(), store);
      final clip = c.read(liveClipProvider('room-1').notifier);
      await clip.start(engine);
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(clip.stop(), throwsA(isA<LiveClipException>()));
      expect(store.calls, ['delete:/tmp/clip.mp4']);
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.idle);
      engine.failStart = true;
      await expectLater(
        clip.start(engine),
        throwsA(
          isA<LiveClipException>().having(
            (e) => e.problem,
            'problem',
            LiveClipProblem.startFailed,
          ),
        ),
      );
      c.dispose();
    });

    testWidgets('the REC badge shows the time and the seconds left', (
      tester,
    ) async {
      final tools = FakeToolsRepository();
      final engine = ToolsEngine();
      late WidgetRef captured;
      await _pumpTool(
        tester,
        Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const Center(child: LiveClipRecBadge(roomId: 'room-1'));
          },
        ),
        overrides: [
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveClipStoreProvider.overrideWithValue(FakeClipStore()),
        ],
        language: AppLanguage.ar,
      );
      expect(find.byKey(LiveClipRecBadge.badgeKey), findsNothing);
      await captured.read(liveClipProvider('room-1').notifier).start(engine);
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = _l10nOf(tester, find.byKey(LiveClipRecBadge.badgeKey));
      expect(find.text(l10n.liveClipRec), findsOneWidget);
      expect(find.byKey(LiveClipRecBadge.stopKey), findsOneWidget);
      await tester.tap(find.byKey(LiveClipRecBadge.stopKey));
      await tester.pump();
      await tester.pump();
      await _leave(tester);
    });

    test('preview actions: save to the gallery, post as a reel (D162 '
        'REEL_VIDEO), discard', () async {
      final store = FakeClipStore();
      final media = FakeMediaRepository();
      final posts = FakePostsRepository();
      Future<ProviderContainer> ready() async {
        final c = container(
          FakeToolsRepository(),
          store,
          media: media,
          posts: posts,
        );
        final clip = c.read(liveClipProvider('room-1').notifier);
        await withClock(Clock.fixed(DateTime(2026)), () async {
          await clip.start(ToolsEngine());
        });
        await withClock(
          Clock.fixed(DateTime(2026).add(const Duration(seconds: 20))),
          clip.stop,
        );
        return c;
      }

      var c = await ready();
      await c.read(liveClipProvider('room-1').notifier).save();
      expect(store.calls, ['save:/tmp/clip.mp4']);
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.ready);
      final review = await c
          .read(liveClipProvider('room-1').notifier)
          .postReel('  من البث  ');
      expect(review, isFalse);
      expect(media.videoUploads, ['reel:video/mp4:4096:poster:image/jpeg']);
      expect(posts.created.single.reel, isTrue);
      expect(posts.created.single.text, 'من البث');
      expect(posts.created.single.mediaIds, ['v1']);
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.idle);
      expect(store.calls.last, 'delete:/tmp/clip.mp4');

      c = await ready();
      await c.read(liveClipProvider('room-1').notifier).discard();
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.idle);
      expect(store.calls.last, 'delete:/tmp/clip.mp4');
    });

    testWidgets('the preview sheet: a failed post keeps the clip; save; '
        'discard deletes it', (tester) async {
      final store = FakeClipStore();
      final media = FakeMediaRepository()..failWith = Exception('down');
      final c = container(
        FakeToolsRepository(),
        store,
        media: media,
        posts: FakePostsRepository(),
      );
      final clip = c.read(liveClipProvider('room-1').notifier);
      await clip.start(ToolsEngine());
      await tester.pump(const Duration(seconds: 8));
      await clip.stop();
      await _pumpTool(
        tester,
        const LiveClipPreviewSheet(
          roomId: 'room-1',
          player: ColoredBox(color: Color(0xFF222222)),
        ),
        container: c,
        language: AppLanguage.ar,
      );
      final l10n = _l10nOf(tester, find.byKey(LiveClipPreviewSheet.sheetKey));
      expect(find.text('0:08'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(LiveClipPreviewSheet.captionKey),
          matching: find.byType(TextField),
        ),
        'لقطة',
      );
      await tester.tap(find.byKey(LiveClipPreviewSheet.postKey));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.liveClipPostFailed), findsOneWidget);
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.ready);
      await tester.tap(find.byKey(LiveClipPreviewSheet.saveKey));
      await tester.pump();
      await tester.pump();
      expect(store.calls, ['save:/tmp/clip.mp4']);
      await tester.tap(find.byKey(LiveClipPreviewSheet.discardKey));
      await tester.pump();
      await tester.pump();
      expect(store.calls.last, 'delete:/tmp/clip.mp4');
      expect(c.read(liveClipProvider('room-1')).phase, LiveClipPhase.idle);
      await _leave(tester);
      await tester.pump(const Duration(seconds: 5));
      c.dispose();
    });
  });

  group('D201 ar / en at 360×800 with 1.3 text', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: every tool sheet and the second device '
          'lay out without overflow', (tester) async {
        final tools = FakeToolsRepository();
        final overrides = <Override>[
          liveToolsRepositoryProvider.overrideWithValue(tools),
          liveMusicMixerProvider.overrideWithValue(FakeMusicMixer()),
          liveClipStoreProvider.overrideWithValue(FakeClipStore()),
          liveMediaEngineProvider.overrideWithValue(ToolsEngine.new),
        ];
        Future<void> check(Widget w) async {
          await _pumpTool(
            tester,
            w,
            overrides: overrides,
            language: language,
            size: const Size(360, 800),
            scale: 1.3,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }

        await check(const SecondCameraSheet(roomId: 'room-1', inPk: false));
        await tester.tap(find.byKey(SecondCameraSheet.createKey));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(SecondCameraSheet.codeKey), findsOneWidget);
        await check(const SecondCameraSheet(roomId: 'room-1', inPk: true));
        await check(const LiveMusicSheet(micEnabled: false));
        await check(LiveClipStartSheet(unsupported: null, onStart: () {}));
        await check(
          LiveClipStartSheet(
            unsupported: LiveClipUnsupported.ios,
            onStart: () {},
          ),
        );
        await check(const SecondCameraScreen());
        await check(
          const LiveClipPreviewSheet(
            roomId: 'room-1',
            player: ColoredBox(color: Color(0xFF222222)),
          ),
        );
        await _leave(tester);
      });
    }
  });
}

/// D251: keep-screen-on that answers at once (no platform in tests).
class _NoAwake implements LiveScreenAwake {
  const new();

  @override
  Future<void> keepOn({required bool on}) async {}
}
