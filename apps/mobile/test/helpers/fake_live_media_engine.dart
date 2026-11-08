import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/data/streamer/live_screen_share.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:material_ui/material_ui.dart';

/// In-memory [LiveMediaEngine]: no camera, no media server. Records every
/// call; [previewProblem] / [publishFailure] make them fail.
class FakeLiveMediaEngine
    implements LiveMediaEngine, LivePlaybackControls, LiveScreenShare {
  static const previewKey = Key('fakeCamera');

  LiveCaptureProblem? previewProblem;
  Exception? publishFailure;

  int previewStarts = 0;
  int flips = 0;
  int stops = 0;
  bool running = false;
  LiveMediaAccess? published;
  bool _front = true;
  bool _mic = true;

  /// The `video` flag of every `startPreview` call.
  final List<bool> previewModes = [];
  bool _video = true;

  /// What [beautySupported] answers.
  bool supportsBeauty = true;

  /// What [filtersSupported] answers (D143/D144); null: as [supportsBeauty].
  bool? supportsFilters;

  /// What [arEffects] answers (D144).
  LiveArSupport arSupport = LiveArSupport.unsupported;
  LiveBeauty beauty = const LiveBeauty();

  /// While set, `startPreview` waits for it (a camera that is slow to
  /// start), then applies its `video` flag.
  Completer<void>? previewGate;

  /// Whether a camera was running when [publish] was called.
  bool? publishedWithVideo;

  @override
  Future<void> startPreview({bool video = true}) async {
    previewStarts++;
    previewModes.add(video);
    if (previewGate case final gate?) await gate.future;
    if (previewProblem case final problem?) {
      throw LiveCaptureException(problem);
    }
    running = true;
    _video = video;
  }

  @override
  bool get videoEnabled => running && _video;

  @override
  bool get beautySupported => supportsBeauty;

  @override
  bool get filtersSupported => supportsFilters ?? supportsBeauty;

  @override
  LiveArSupport get arEffects => arSupport;

  /// D228: the engine the app picked last ([setFxEngine]) and every pick.
  LiveFxEngine engineValue = LiveFxEngine.deepAr;
  final List<LiveFxEngine> enginePicks = [];

  @override
  LiveFxEngine get fxEngine => engineValue;

  @override
  Future<void> setFxEngine(LiveFxEngine engine) async {
    enginePicks.add(engine);
    engineValue = engine;
  }

  /// What [arStatus] holds (D144a): set its value to play DeepAR's reports.
  final ValueNotifier<LiveArStatus> arStatusValue = ValueNotifier(
    LiveArStatus.off,
  );

  @override
  ValueListenable<LiveArStatus> get arStatus => arStatusValue;

  /// What [arDiagnostics] answers (D144a).
  KabsoCameraFxDiagnostics? diagnostics;

  @override
  Future<KabsoCameraFxDiagnostics?> arDiagnostics() async => diagnostics;

  @override
  Future<void> setBeauty(LiveBeauty beauty) async => this.beauty = beauty;

  /// The last `setVoice`.
  ({bool noiseReduction, bool enhance}) voice = (
    noiseReduction: true,
    enhance: true,
  );

  @override
  Future<void> setVoice({
    required bool noiseReduction,
    required bool enhance,
  }) async => voice = (noiseReduction: noiseReduction, enhance: enhance);

  @override
  Widget? preview() => videoEnabled
      ? ColoredBox(
          key: previewKey,
          color: _front ? const Color(0xFF203040) : const Color(0xFF402030),
        )
      : null;

  @override
  bool get frontCamera => _front;

  @override
  Future<void> flipCamera() async {
    flips++;
    _front = !_front;
  }

  /// D143: whether the back camera has a torch (the front never has).
  bool backTorch = true;

  /// Every `setTorch` call, in order.
  final List<bool> torchCalls = [];

  @override
  Future<bool> hasTorch() async => running && _video && !_front && backTorch;

  @override
  Future<void> setTorch({required bool on}) async {
    if (on && !await hasTorch()) throw StateError('no torch');
    torchCalls.add(on);
  }

  @override
  bool get micEnabled => _mic;

  @override
  Future<void> setMicEnabled({required bool enabled}) async => _mic = enabled;

  /// Every `setVideoPaused` call (D123).
  final List<bool> videoPauses = [];

  @override
  Future<void> setVideoPaused({required bool paused}) async {
    videoPauses.add(paused);
    _changes.notifyListeners();
  }

  @override
  bool get videoPaused => videoPauses.isNotEmpty && videoPauses.last;

  // ---- CP-017: the live microphone around a voice clip -------------------

  /// Whether the live microphone is paused for a voice clip now.
  bool micPausedForClip = false;

  /// When set, `pauseForClip` throws (the microphone cannot be freed).
  bool micPauseFails = false;

  /// `pause` / `resume` in order (only the calls that changed something).
  final List<String> clipMicLog = [];

  /// Whether a microphone is published (the host after `publish`, a seated
  /// guest after `publishLocal`).
  bool get micPublished => published != null || publishingLocal;

  @override
  Future<bool> pauseForClip() async {
    if (!micPublished || micPausedForClip) return false;
    if (micPauseFails) {
      throw const LiveCaptureException(LiveCaptureProblem.unavailable);
    }
    micPausedForClip = true;
    clipMicLog.add('pause');
    return true;
  }

  @override
  Future<void> resumeAfterClip() async {
    if (!micPausedForClip) return;
    micPausedForClip = false;
    clipMicLog.add('resume');
  }

  @override
  Future<void> publish(LiveMediaAccess access) async {
    if (publishFailure case final failure?) throw failure;
    publishedWithVideo = videoEnabled;
    published = access;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
    published = null;
  }

  // ---- session --------------------------------------------------------

  /// What `join` received.
  LiveMediaAccess? joined;

  /// The identities present in the session (their video is a coloured box
  /// keyed `remote.<identity>`).
  final Set<String> present = {};
  bool publishAllowed = false;
  bool publishingLocal = false;
  final List<bool> publishLocalCalls = [];
  int unpublishLocalCalls = 0;
  Set<String> speakingNow = {};
  int? version;
  final _invites = StreamController<String>.broadcast();
  final _changes = ChangeNotifier();

  /// Tells listeners the session changed (tests).
  void ping() => _changes.notifyListeners();

  void invite(String roomId) => _invites.add(roomId);

  @override
  Future<void> join(LiveMediaAccess access) async => joined = access;

  @override
  bool get canPublish => publishAllowed;

  @override
  Future<void> publishLocal({required bool video}) async {
    publishLocalCalls.add(video);
    await startPreview(video: video);
    publishingLocal = true;
  }

  @override
  Future<void> unpublishLocal() async {
    unpublishLocalCalls++;
    publishingLocal = false;
    running = false;
  }

  /// D170: identities whose camera track is muted (a host in the
  /// background): present, but no picture.
  final Set<String> videoMutedIds = {};

  /// D225: the viewer's playback volume and data saver, as last set.
  double playbackVolume = 1;
  bool receiveVideo = true;
  final List<double> volumeCalls = [];

  @override
  Future<void> setPlaybackVolume(double volume) async {
    volumeCalls.add(volume);
    playbackVolume = volume;
  }

  @override
  Future<void> setReceiveVideo({required bool receive}) async {
    receiveVideo = receive;
    _changes.notifyListeners();
  }

  @override
  Widget? remoteVideo(String identity) => !receiveVideo
      ? null
      : present.contains(identity) && !videoMutedIds.contains(identity)
      ? ColoredBox(key: Key('remote.$identity'), color: const Color(0xFF304050))
      : null;

  @override
  bool videoMuted(String identity) =>
      present.contains(identity) && videoMutedIds.contains(identity);

  @override
  bool isPresent(String identity) => present.contains(identity);

  @override
  Set<String> get speaking => speakingNow;

  @override
  int? get seatsVersion => version;

  /// The room score the media room's metadata carries (CP-012).
  int? scoreNow;

  @override
  int? get score => scoreNow;

  /// D259: the host cherries the media room's metadata carries.
  int? hostCherriesNow;

  @override
  int? get hostCherries => hostCherriesNow;

  /// D310: the room cherries the media room's metadata carries.
  int? roomCherriesNow;

  @override
  int? get roomCherries => roomCherriesNow;

  /// `roomInfoVersion` the media room's metadata carries (CP-014).
  int? infoVersion;

  @override
  int? get roomInfoVersion => infoVersion;

  @override
  Stream<String> get seatInvites => _invites.stream;

  /// D154g: the camera's quality (tests read it) and the connection (tests
  /// set it, then [ping]).
  LiveVideoQuality quality = LiveVideoQuality.normal;
  LiveConnectionQuality connection = LiveConnectionQuality.unknown;

  /// D154g: a camera that cannot restart.
  bool qualityFails = false;

  @override
  LiveVideoQuality get videoQuality => quality;

  @override
  Future<void> setVideoQuality(LiveVideoQuality value) async {
    if (qualityFails) {
      throw const LiveCaptureException(LiveCaptureProblem.unavailable);
    }
    if (value == LiveVideoQuality.high && !hd) {
      throw const LiveHdUnsupportedException();
    }
    quality = value;
    ping();
  }

  @override
  LiveConnectionQuality get connectionQuality => connection;

  /// D160: a camera that captures 1080p, and the measured uplink (tests set
  /// them, then [ping]).
  bool hd = false;
  LiveUplink uplinkState = LiveUplink.unmeasured;

  @override
  bool get hdCapture => hd;

  @override
  LiveUplink get uplink => uplinkState;

  /// CP-013: what the media room delivers to [chatEvents]; tests add to it.
  final chat = StreamController<LiveChatEvent>.broadcast();

  @override
  Stream<LiveChatEvent> get chatEvents => chat.stream;

  /// v1.43-live (D195): what the media room delivers to [pkEvents].
  final pk = StreamController<PkEvent>.broadcast();

  @override
  Stream<PkEvent> get pkEvents => pk.stream;

  @override
  Listenable get changes => _changes;

  /// The media server closed the session (the room was deleted).
  bool dropped = false;

  @override
  bool get connected => !dropped && (joined != null || published != null);

  /// v1.20-live: the media server removed this participant (a kick); set
  /// with [dropped] and [ping].
  bool kickedOut = false;

  @override
  bool get removed => kickedOut;

  // ---- D213: the streamer's screen ----------------------------------------

  static const screenKey = Key('fakeScreen');

  /// Thrown by [publishScreen] while set.
  Exception? screenFailure;
  bool _screen = false;
  bool _screenPaused = false;

  /// Every [setScreenPaused] value, in order.
  final List<bool> screenPauses = [];
  int screenPublishes = 0;
  int screenUnpublishes = 0;

  @override
  Future<void> publishScreen() async {
    screenPublishes++;
    if (screenFailure case final f?) throw f;
    _screen = true;
    _changes.notifyListeners();
  }

  @override
  Future<void> unpublishScreen() async {
    screenUnpublishes++;
    _screen = false;
    _screenPaused = false;
    _changes.notifyListeners();
  }

  @override
  bool get screenPublished => _screen;

  @override
  bool get screenPaused => _screenPaused;

  @override
  Future<void> setScreenPaused({required bool paused}) async {
    screenPauses.add(paused);
    _screenPaused = paused;
    _changes.notifyListeners();
  }

  /// Viewers: identities sharing a screen, and the paused ones.
  final Set<String> screenIds = {};
  final Set<String> screenPausedIds = {};

  /// The picture a viewer's screen box shows: a portrait or landscape box
  /// (the fake has no real frames), keyed for tests.
  Size screenFrame = const Size(9, 19.5);

  @override
  Widget? remoteScreen(String identity) =>
      !receiveVideo ||
          !screenIds.contains(identity) ||
          screenPausedIds.contains(identity)
      ? null
      : Center(
          child: AspectRatio(
            aspectRatio: screenFrame.width / screenFrame.height,
            child: const ColoredBox(key: screenKey, color: Color(0xFF1E6B3A)),
          ),
        );

  @override
  bool hasRemoteScreen(String identity) => screenIds.contains(identity);

  @override
  bool remoteScreenPaused(String identity) =>
      screenIds.contains(identity) && screenPausedIds.contains(identity);

  @override
  Widget? remoteCamera(String identity) => remoteVideo(identity);

  /// D247: the camera as the whole picture (`main: CAMERA`), keyed for tests.
  static const cameraPictureKey = Key('fake.cameraPicture');

  @override
  Widget? remoteCameraPicture(String identity) =>
      !receiveVideo ||
          !present.contains(identity) ||
          videoMutedIds.contains(identity)
      ? null
      : Center(
          child: AspectRatio(
            aspectRatio: screenFrame.width / screenFrame.height,
            child: const ColoredBox(
              key: cameraPictureKey,
              color: Color(0xFF6B1E3A),
            ),
          ),
        );

  @override
  bool remoteCameraPaused(String identity) =>
      present.contains(identity) && videoMutedIds.contains(identity);

  /// What the media room delivers to [streamerEvents]; tests add to it.
  final streamer = StreamController<LiveStreamerEvent>.broadcast();

  @override
  Stream<LiveStreamerEvent> get streamerEvents => streamer.stream;

  /// `streamerVersion` of the media room's metadata.
  int? streamerVersionNow;

  @override
  int? get streamerVersion => streamerVersionNow;
}
