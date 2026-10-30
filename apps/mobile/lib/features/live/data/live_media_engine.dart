import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_camera_fx.dart';
import 'package:kabso_live/features/live/data/live_camera_gate.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// Thrown by [LiveMediaEngine.startPreview].
class LiveCaptureException implements Exception {
  const new(this.problem);

  final LiveCaptureProblem problem;

  @override
  String toString() => 'LiveCaptureException(${problem.name})';
}

/// D160: the camera delivered less than 1080p after switching to
/// [LiveVideoQuality.high] (the quality went back to what it was).
class LiveHdUnsupportedException implements Exception {
  const new();

  @override
  String toString() => 'LiveHdUnsupportedException()';
}

/// Why the camera or microphone could not start.
enum LiveCaptureProblem {
  /// The person refused access (or the system blocks it).
  denied,

  /// No camera or microphone was found, or it is in use.
  unavailable,

  /// D144a: refused for good — only the app's settings can allow it (the
  /// system will not ask again).
  blocked,
}

/// D154g «الجودة»: the host's published picture. [normal] is LiveKit's
/// default (720p, simulcast); [smooth] captures 480p at 15 fps for a weak
/// connection. D160: [high] captures 1080p at 30 fps with simulcast layers
/// 1080 / 720 / 360 — offered only where this camera captures 1080p
/// ([LiveMediaEngine.hdCapture]) and the uplink is not measured too slow
/// ([LiveMediaEngine.uplink]). No 2K (owner: not recommended).
enum LiveVideoQuality { smooth, normal, high }

/// D154g: this phone's connection to the media server, as LiveKit rates it.
enum LiveConnectionQuality { unknown, excellent, good, poor, lost }

/// D160: the host's uplink as the publisher measures it (WebRTC's available
/// outgoing bitrate on the media connection), sustained over
/// [UplinkMeter.window].
enum LiveUplink {
  /// Not measured yet (the preview, the first seconds, or no such stat on
  /// this platform): 1080p may be tried; it falls back by itself.
  unmeasured,

  /// At least [UplinkMeter.enoughBps] for the whole window.
  sufficient,

  /// Below it for the whole window: 1080p is not offered now.
  insufficient,
}

/// D160: turns available-outgoing-bitrate samples into a [LiveUplink]: a
/// verdict needs [window] in a row on one side of [enoughBps]; mixed samples
/// keep the last verdict.
class UplinkMeter {
  static const enoughBps = 4000000;
  static const window = Duration(seconds: 10);

  LiveUplink _state = LiveUplink.unmeasured;
  DateTime? _aboveSince;
  DateTime? _belowSince;
  int? _lastBps;

  LiveUplink get state => _state;

  /// The last sample, in bits per second.
  int? get lastBps => _lastBps;

  /// A sample at [now]; null (no stat) changes nothing.
  LiveUplink feed(int? bps, DateTime now) {
    if (bps == null) return _state;
    _lastBps = bps;
    if (bps >= enoughBps) {
      _belowSince = null;
      _aboveSince ??= now;
      if (now.difference(_aboveSince!) >= window) {
        _state = LiveUplink.sufficient;
      }
    } else {
      _aboveSince = null;
      _belowSince ??= now;
      if (now.difference(_belowSince!) >= window) {
        _state = LiveUplink.insufficient;
      }
    }
    return _state;
  }

  void reset() {
    _state = LiveUplink.unmeasured;
    _aboveSince = null;
    _belowSince = null;
    _lastBps = null;
  }
}

/// D160: whether a camera track's settings (flutter_webrtc: the capture
/// format the phone picked; the web: what the browser reports) are 1080p
/// or more, in either orientation.
bool liveCaptures1080(Map<String, dynamic> settings) {
  final w = settings['width'];
  final h = settings['height'];
  if (w is! num || h is! num) return false;
  final long = w > h ? w : h;
  final short = w > h ? h : w;
  return long >= 1920 && short >= 1080;
}

/// D160: one simulcast layer's encoding: how much smaller than the capture,
/// its bitrate cap and frame rate.
typedef LiveLayerEncoding = ({
  double scaleDown,
  int maxBitrate,
  int maxFramerate,
});

/// D160: the sender's layer [rid] (`f` full, `h` half, `q` quarter — or
/// null: one layer) at [quality]. [LiveVideoQuality.high] publishes
/// 1080p / 720p / 360p; the others LiveKit's 720p defaults (720 / 360 /
/// 180, as D154g published them).
LiveLayerEncoding liveLayerEncoding(LiveVideoQuality quality, String? rid) =>
    switch ((quality, rid)) {
      (LiveVideoQuality.high, 'q') => (
        scaleDown: 3,
        maxBitrate: 450000,
        maxFramerate: 20,
      ),
      (LiveVideoQuality.high, 'h') => (
        scaleDown: 1.5,
        maxBitrate: 1700000,
        maxFramerate: 30,
      ),
      (LiveVideoQuality.high, _) => (
        scaleDown: 1,
        maxBitrate: 3000000,
        maxFramerate: 30,
      ),
      (_, 'q') => (scaleDown: 4, maxBitrate: 160000, maxFramerate: 15),
      (_, 'h') => (scaleDown: 2, maxBitrate: 450000, maxFramerate: 20),
      (_, _) => (scaleDown: 1, maxBitrate: 1700000, maxFramerate: 30),
    };

/// The camera, microphone and media session of the person going live
/// (CP-010, LiveKit, D3), behind an interface so screens and tests do not
/// depend on the device or the media server. As a [LiveVoiceMic] it frees
/// the published microphone while a chat voice clip records (CP-017).
abstract interface class LiveMediaEngine implements LiveVoiceMic {
  /// Starts the camera (front by default, unless [video] is false: audio
  /// rooms) and the microphone for the preview. Throws a
  /// [LiveCaptureException] when they cannot start. Calling it again with
  /// another [video] switches.
  Future<void> startPreview({bool video = true});

  /// Whether the camera is part of the preview.
  bool get videoEnabled;

  /// D154g: the camera's quality now ([LiveVideoQuality.normal] at first).
  LiveVideoQuality get videoQuality;

  /// D154g: captures the camera at [quality] (the published track too).
  /// Throws a [LiveCaptureException] when the camera cannot restart (the
  /// quality stays as it was).
  Future<void> setVideoQuality(LiveVideoQuality quality);

  /// D154g: this phone's connection, as the media server rates it.
  LiveConnectionQuality get connectionQuality;

  /// D160: whether the camera on now captures 1080p (checked when the
  /// camera first starts; false until then and for a camera not checked).
  bool get hdCapture;

  /// D160: the uplink while publishing ([LiveUplink.unmeasured] before).
  LiveUplink get uplink;

  /// Whether beauty (skin smoothing, brightening) works on this device
  /// (D94).
  bool get beautySupported;

  /// Whether Magic's colour filters reach the published picture here (D143;
  /// D144: Android too).
  bool get filtersSupported;

  /// Whether Magic's AR effects can run here (D144).
  LiveArSupport get arEffects;

  /// D144a: the picked AR effect's state on the device — DeepAR switches
  /// it off by itself (and says why) rather than freeze the picture.
  ValueListenable<LiveArStatus> get arStatus;

  /// D144a: the camera processor's state and counters for the non-release
  /// diagnostics overlay; null where there is no processor.
  Future<KabsoCameraFxDiagnostics?> arDiagnostics();

  /// Beauty on the camera picture, before and while live: what of it this
  /// device supports (skin, colour filter, AR effect).
  Future<void> setBeauty(LiveBeauty beauty);

  /// Voice processing on the microphone (D94 audio settings): noise
  /// reduction, and enhancement (echo cancelling and level balancing).
  Future<void> setVoice({required bool noiseReduction, required bool enhance});

  /// The camera picture (cover-fit, mirrored for the front camera), or
  /// `null` before [startPreview] succeeded.
  Widget? preview();

  bool get frontCamera;

  Future<void> flipCamera();

  /// D143 fill light with the back camera: whether the running camera has
  /// a torch (phones' back cameras; never on the web). `false` before
  /// [startPreview] or when the platform cannot tell.
  Future<bool> hasTorch();

  /// Turns the running camera's torch on or off (WebRTC's capture track,
  /// Android Camera2 / iOS AVCaptureDevice). Throws where there is none.
  /// The camera turns it off when it stops or flips.
  Future<void> setTorch({required bool on});

  bool get micEnabled;

  Future<void> setMicEnabled({required bool enabled});

  /// D123: pauses the published camera while the app is in the background
  /// (Android blocks the camera there; the microphone goes on) and resumes
  /// it on return. Nothing without a camera.
  Future<void> setVideoPaused({required bool paused});

  /// D174a: whether the published camera is paused now (a seated guest
  /// turned it off, or the app is in the background).
  bool get videoPaused;

  /// Joins the room's media session with [access] and publishes what is
  /// running (camera and microphone, or the microphone alone).
  Future<void> publish(LiveMediaAccess access);

  /// Leaves the session (if any) and turns the camera and microphone off.
  Future<void> stop();

  // ---- the session (CP-010 viewers, CP-011 seats) -----------------------

  /// Joins the room's media session with [access] without publishing
  /// (viewers, guests). A seated guest then calls [publishLocal].
  Future<void> join(LiveMediaAccess access);

  /// Whether the media server lets this participant publish now (seated).
  bool get canPublish;

  /// Starts the camera ([video]) and microphone and publishes them (a
  /// seated guest, CP-011). Throws a [LiveCaptureException].
  Future<void> publishLocal({required bool video});

  /// Stops publishing and turns the camera and microphone off (off the
  /// seat); the session stays joined.
  Future<void> unpublishLocal();

  /// The video of the participant [identity] (a user id), or `null`.
  Widget? remoteVideo(String identity);

  /// Whether [identity] is in the session now.
  bool isPresent(String identity);

  /// D170: whether [identity] is in the session with a camera track that is
  /// muted — a host whose app is in the background (the phone stopped the
  /// camera). Viewers then see "the host will be right back".
  bool videoMuted(String identity);

  /// The identities speaking now (the local one included).
  Set<String> get speaking;

  /// `seatsVersion` from the media room's metadata (CP-011 §10.9).
  int? get seatsVersion;

  /// The room score from the media room's metadata (CP-012 §10.10).
  int? get score;

  /// `roomInfoVersion` from the media room's metadata (CP-014 §10.12): the
  /// title, category or topic changed.
  int? get roomInfoVersion;

  /// Room ids of seat invitations addressed to this participant.
  Stream<String> get seatInvites;

  /// CP-013: the server's chat data messages in the room (§10.11).
  Stream<LiveChatEvent> get chatEvents;

  /// Notifies on any session change: participants, tracks, speakers,
  /// metadata, permissions, connection.
  Listenable get changes;

  bool get connected;

  /// v1.20-live (§10.20): the media server removed this participant (the
  /// LiveKit disconnect reason "participant removed": a kick).
  bool get removed;
}

class _Changes extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// [LiveMediaEngine] on `livekit_client` (its defaults: 720p, simulcast).
class LiveKitMediaEngine implements LiveMediaEngine {
  lk.LocalVideoTrack? _video;
  lk.LocalAudioTrack? _audio;
  lk.Room? _room;
  BeautyPipeline? _beautyPipeline;

  /// D144: Android's native camera processor (colour filters, DeepAR).
  final LiveCameraFx _fx = LiveCameraFx();
  LiveBeauty _beauty = const LiveBeauty();
  bool _front = true;
  bool _mic = true;
  bool _noiseReduction = true;
  bool _enhance = true;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final _changes = _Changes();
  final _invites = StreamController<String>.broadcast();
  final _chat = StreamController<LiveChatEvent>.broadcast();
  Set<String> _speaking = const {};
  int? _seatsVersion;
  int? _score;
  int? _roomInfoVersion;
  bool _removed = false;

  /// CP-017: the published microphone is paused for a voice clip.
  bool _clipHold = false;

  @override
  bool get videoEnabled => _video != null;

  LiveVideoQuality _quality = LiveVideoQuality.normal;
  LiveConnectionQuality _connection = LiveConnectionQuality.unknown;

  @override
  LiveVideoQuality get videoQuality => _quality;

  @override
  LiveConnectionQuality get connectionQuality => _connection;

  /// D160: whether each camera (true: the front one) captures 1080p, once
  /// checked.
  final Map<bool, bool> _hd = {};
  final UplinkMeter _uplink = UplinkMeter();
  Timer? _uplinkTimer;
  bool _sampling = false;

  @override
  bool get hdCapture => _hd[_front] ?? false;

  @override
  LiveUplink get uplink => _uplink.state;

  /// D160: asks one camera (`front` or the back one) for 1080p at 30 fps
  /// on its own (before the preview's track opens it) and reads the format
  /// it gets —
  /// flutter_webrtc reports the capture format the phone picked (Android
  /// Camera2's closest output size, iOS's selected format), the web what
  /// the browser delivers. Null: it could not tell. A seam for tests.
  @visibleForTesting
  static Future<bool?> Function({required bool front}) hdProbe = _probeHd;

  static Future<bool?> _probeHd({required bool front}) async {
    final stream = await rtc.navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'facingMode': front ? 'user' : 'environment',
        'width': 1920,
        'height': 1080,
        'frameRate': 30,
      },
    });
    try {
      final tracks = stream.getVideoTracks();
      if (tracks.isEmpty) return null;
      return liveCaptures1080(tracks.first.getSettings());
    } finally {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
  }

  Future<void> _checkHd() async {
    if (_hd.containsKey(_front)) return;
    try {
      final hd = await hdProbe(front: _front);
      if (hd != null) _hd[_front] = hd;
    } on Object {
      // Unknown: 1080p is not offered for this camera.
    }
  }

  /// The capture of [quality] (null: LiveKit's default, 720p).
  static lk.VideoParameters? _paramsOf(LiveVideoQuality quality) =>
      switch (quality) {
        LiveVideoQuality.smooth => const lk.VideoParameters(
          dimensions: lk.VideoDimensions(854, 480),
          encoding: lk.VideoEncoding(maxBitrate: 600000, maxFramerate: 15),
        ),
        LiveVideoQuality.normal => null,
        LiveVideoQuality.high => lk.VideoParametersPresets.h1080_169,
      };

  /// D160: publishing at 1080p — 1080 / 720 / 360 simulcast layers, 30 fps.
  static const _hdPublish = lk.VideoPublishOptions(
    videoEncoding: lk.VideoEncoding(maxBitrate: 3000000, maxFramerate: 30),
    videoSimulcastLayers: [
      lk.VideoParametersPresets.h360_169,
      lk.VideoParametersPresets.h720_169,
    ],
  );

  /// D160: the published layers follow the quality (LiveKit computes them
  /// once, at publish, for the capture of then): to and from 1080p each
  /// layer's scale, bitrate cap and frame rate are set on the sender (the
  /// viewers keep the same track: no republish, no gap).
  Future<void> _applyEncodings(lk.LocalVideoTrack video) async {
    final sender = video.sender;
    if (sender == null) return;
    final params = sender.parameters;
    final encodings = params.encodings;
    if (encodings == null || encodings.isEmpty) return;
    for (final e in encodings) {
      final layer = liveLayerEncoding(
        _quality,
        encodings.length == 1 ? null : e.rid,
      );
      e
        ..scaleResolutionDownBy = layer.scaleDown
        ..maxBitrate = layer.maxBitrate
        ..maxFramerate = layer.maxFramerate;
    }
    params.encodings = encodings;
    await sender.setParameters(params);
  }

  /// D160: the uplink every 2 s while publishing — WebRTC's
  /// `availableOutgoingBitrate` of the media connection's active candidate
  /// pair, from the camera sender's stats.
  void _startUplink() {
    _uplinkTimer?.cancel();
    _uplink.reset();
    _uplinkTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_sampleUplink()),
    );
  }

  Future<void> _sampleUplink() async {
    final sender = _video?.sender;
    if (sender == null || _sampling) return;
    _sampling = true;
    try {
      int? best;
      for (final report in await sender.getStats()) {
        if (report.type != 'candidate-pair') continue;
        final values = report.values;
        final active =
            values['nominated'] == true || values['state'] == 'succeeded';
        final raw = values['availableOutgoingBitrate'];
        final bps = raw is num ? raw : num.tryParse('$raw');
        if (!active || bps == null) continue;
        best = math.max(best ?? 0, bps.toInt());
      }
      final before = _uplink.state;
      if (_uplink.feed(best, clock.now()) != before) _changes.ping();
    } on Object {
      // No stats this time.
    } finally {
      _sampling = false;
    }
  }

  lk.CameraCaptureOptions _cameraOptions() {
    final params = _paramsOf(_quality);
    final position = _front ? lk.CameraPosition.front : lk.CameraPosition.back;
    return params == null
        ? lk.CameraCaptureOptions(cameraPosition: position)
        : lk.CameraCaptureOptions(
            cameraPosition: position,
            params: params,
            maxFrameRate: params.encoding?.maxFramerate.toDouble(),
          );
  }

  @override
  Future<void> setVideoQuality(LiveVideoQuality quality) async {
    if (quality == _quality) return;
    final before = _quality;
    if (quality == LiveVideoQuality.high && !hdCapture) {
      throw const LiveHdUnsupportedException();
    }
    try {
      await _capture(quality, before);
      // D160: what the camera really delivers (it may pick less).
      final video = _video;
      if (quality == LiveVideoQuality.high &&
          video != null &&
          !liveCaptures1080(video.mediaStreamTrack.getSettings())) {
        _hd[_front] = false;
        await _capture(before, quality);
        throw const LiveHdUnsupportedException();
      }
    } on LiveHdUnsupportedException {
      rethrow;
    } on Object {
      _quality = before;
      throw const LiveCaptureException(LiveCaptureProblem.unavailable);
    } finally {
      _changes.ping();
    }
  }

  /// Restarts the camera at [quality] (published: the same track and
  /// sender; previewing: a new track).
  Future<void> _capture(LiveVideoQuality quality, LiveVideoQuality from) async {
    _quality = quality;
    final video = _video;
    if (video != null && video.sender != null) {
      await video.restartTrack(_cameraOptions());
      if (quality == LiveVideoQuality.high || from == LiveVideoQuality.high) {
        await _applyEncodings(video);
      }
      await _attachFx();
    } else if (video != null) {
      // Previewing: a new camera track at the new quality.
      await _stopVideo();
      await startPreview();
    }
  }

  @override
  bool get beautySupported => kIsWeb;

  @override
  bool get filtersSupported => kIsWeb || _fx.filtersSupported;

  @override
  LiveArSupport get arEffects => _fx.effects;

  @override
  ValueListenable<LiveArStatus> get arStatus => _fx.status;

  @override
  Future<KabsoCameraFxDiagnostics?> arDiagnostics() =>
      kIsWeb ? Future.value() : _fx.diagnostics();

  @override
  Future<void> setBeauty(LiveBeauty beauty) async {
    _beauty = beauty;
    _beautyPipeline?.update(beauty);
    await _fx.update(beauty);
  }

  /// D144: the native processor follows the camera track; LiveKit gives the
  /// track a new native id whenever it restarts it (unmute after a pause).
  Future<void> _attachFx() async {
    final video = _video;
    if (video == null || kIsWeb) return;
    await _fx.attach(video.mediaStreamTrack.id ?? '');
  }

  /// Opens the camera; a seam for tests.
  @visibleForTesting
  static Future<lk.LocalVideoTrack> Function(lk.CameraCaptureOptions options)
  createCamera = lk.LocalVideoTrack.createCameraTrack;

  Future<void>? _previewing;

  /// D144b: one start at a time per engine. Two overlapping starts both saw
  /// no camera and both opened one: the second came back as a shared track
  /// the camera processor never sees ([LiveCameraGate]), the first leaked.
  @override
  Future<void> startPreview({bool video = true}) async {
    for (var running = _previewing; running != null; running = _previewing) {
      try {
        await running;
      } on Object {
        // Its own caller hears about it.
      }
    }
    final run = _startPreview(video: video);
    _previewing = run;
    try {
      await run;
    } finally {
      if (identical(_previewing, run)) _previewing = null;
    }
  }

  Future<void> _startPreview({required bool video}) async {
    try {
      if (video && _video == null) {
        // D144b: never while another camera (the last go-live's) is still
        // being stopped — it would make this one a shared track.
        await LiveCameraGate.idle();
        // D160: whether this camera captures 1080p, before it opens.
        await _checkHd();
        final camera = await createCamera(_cameraOptions());
        _video = camera;
        final pipeline = BeautyPipeline.create();
        if (pipeline != null) {
          pipeline.update(_beauty);
          await pipeline.attach(camera);
          _beautyPipeline = pipeline;
        }
        await camera.start();
        await _attachFx();
      } else if (!video && _video != null) {
        await _stopVideo();
      }
      if (_audio == null) {
        final audio = await lk.LocalAudioTrack.create(_audioOptions);
        _audio = audio;
        if (!_mic) await audio.mute();
      }
    } on Object catch (e) {
      await stop();
      final text = e.toString().toLowerCase();
      throw LiveCaptureException(
        text.contains('notallowed') ||
                text.contains('permission') ||
                text.contains('denied')
            ? LiveCaptureProblem.denied
            : LiveCaptureProblem.unavailable,
      );
    }
  }

  lk.AudioCaptureOptions get _audioOptions => lk.AudioCaptureOptions(
    noiseSuppression: _noiseReduction,
    echoCancellation: _enhance,
    autoGainControl: _enhance,
  );

  @override
  Future<void> setVoice({
    required bool noiseReduction,
    required bool enhance,
  }) async {
    _noiseReduction = noiseReduction;
    _enhance = enhance;
    final audio = _audio;
    if (audio == null) return;
    if (audio.sender != null) {
      // Published: restart in place with the new processing.
      await audio.restartTrack(_audioOptions);
      return;
    }
    // Preview only: a new microphone track with the new processing.
    _audio = null;
    await audio.stop();
    await audio.dispose();
    final fresh = await lk.LocalAudioTrack.create(_audioOptions);
    _audio = fresh;
    if (!_mic) await fresh.mute();
  }

  @override
  Widget? preview() {
    final video = _video;
    if (video == null) return null;
    final processed = _beautyPipeline?.preview(mirror: _front);
    if (processed != null) return processed;
    return lk.VideoTrackRenderer(
      video,
      fit: lk.VideoViewFit.cover,
      mirrorMode: _front
          ? lk.VideoViewMirrorMode.mirror
          : lk.VideoViewMirrorMode.off,
    );
  }

  @override
  bool get frontCamera => _front;

  /// D141 (owner's phone: Flip only mirrored the picture). On Android and
  /// iOS the capture itself switches between the front and back cameras in
  /// place (`Helper.switchCamera`: the same track, so the preview and — once
  /// published — the viewers follow without a new track); the answer says
  /// which camera is on, and the preview mirrors only the front one. The
  /// web restarts the track with the other camera (LiveKit). The capture
  /// options follow, so a later restart keeps the camera.
  @override
  Future<void> flipCamera() async {
    final video = _video;
    final want = !_front;
    if (video == null) {
      _front = want;
      _changes.ping();
      return;
    }
    final position = want ? lk.CameraPosition.front : lk.CameraPosition.back;
    if (kIsWeb) {
      await video.setCameraPosition(position);
      _front = want;
    } else {
      final front = await cameraSwitch(video.mediaStreamTrack);
      _front = front ?? want;
      final options = video.currentOptions;
      if (options is lk.CameraCaptureOptions) {
        video.currentOptions = options.copyWith(
          cameraPosition: _front
              ? lk.CameraPosition.front
              : lk.CameraPosition.back,
        );
      }
    }
    // D160: the other camera may not capture 1080p.
    if (_quality == LiveVideoQuality.high && !hdCapture) {
      try {
        await setVideoQuality(LiveVideoQuality.normal);
      } on Object {
        // The camera keeps what it has.
      }
    }
    _changes.ping();
  }

  /// Switches a native camera track to the other camera; the answer is
  /// whether the front camera is now on (null: unknown). A seam for tests.
  @visibleForTesting
  static Future<bool?> Function(rtc.MediaStreamTrack track) cameraSwitch =
      (track) async {
        final front = await rtc.Helper.switchCamera(track);
        return front;
      };

  @override
  Future<bool> hasTorch() async {
    final video = _video;
    if (video == null || kIsWeb) return false;
    try {
      return await video.mediaStreamTrack.hasTorch();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setTorch({required bool on}) async {
    final video = _video;
    if (video == null) return;
    await video.mediaStreamTrack.setTorch(on);
  }

  @override
  bool get micEnabled => _mic;

  @override
  Future<void> setMicEnabled({required bool enabled}) async {
    _mic = enabled;
    final audio = _audio;
    // While a voice clip records, the choice applies when it ends.
    if (audio == null || _clipHold) return;
    if (enabled) {
      await audio.unmute();
    } else {
      await audio.mute();
    }
  }

  @override
  bool get videoPaused => _video?.muted ?? false;

  @override
  Future<void> setVideoPaused({required bool paused}) async {
    final video = _video;
    if (video == null || video.muted == paused) return;
    // Muting stops the capture (the others see the camera off); unmuting
    // starts it again.
    if (paused) {
      await video.mute();
    } else {
      await video.unmute();
      await _attachFx();
    }
    _changes.ping();
  }

  @override
  /// CP-017: on Android, WebRTC's capture and the clip recorder cannot both
  /// hear the microphone (the clip came out silent). Muting the track tells
  /// the others (their usual muted state) and stops it; detaching it from
  /// the sender stops the send stream, so WebRTC closes its capture and the
  /// recorder gets the microphone. [resumeAfterClip] unmutes, which
  /// restarts the track and attaches it again.
  @override
  Future<bool> pauseForClip() async {
    final audio = _audio;
    final sender = audio?.sender;
    if (audio == null || sender == null || _clipHold) return false;
    _clipHold = true;
    try {
      if (!audio.muted) await audio.mute();
      await sender.replaceTrack(null);
    } on Object {
      await resumeAfterClip();
      throw const LiveCaptureException(LiveCaptureProblem.unavailable);
    }
    return true;
  }

  @override
  Future<void> resumeAfterClip() async {
    if (!_clipHold) return;
    _clipHold = false;
    final audio = _audio;
    if (audio == null || audio.sender == null) return;
    // Back as the person left it: on again only if it was on. A muted
    // track stays detached; turning the mic on restarts and attaches it.
    if (_mic) await audio.unmute();
    _changes.ping();
  }

  @override
  Future<void> publish(LiveMediaAccess access) async {
    final video = _video;
    final audio = _audio;
    if (audio == null) throw StateError('startPreview() first');
    final room = await _connect(access);
    if (video != null) {
      await room.localParticipant!.publishVideoTrack(
        video,
        publishOptions: _quality == LiveVideoQuality.high ? _hdPublish : null,
      );
      _startUplink();
    }
    await room.localParticipant!.publishAudioTrack(audio);
  }

  Future<lk.Room> _connect(LiveMediaAccess access) async {
    final room = lk.Room();
    _room = room;
    _removed = false;
    _listen(room);
    await room.connect(access.url, access.token);
    _readMetadata(room.metadata);
    _changes.ping();
    return room;
  }

  void _listen(lk.Room room) {
    _listener = room.createListener()
      ..on<lk.RoomMetadataChangedEvent>((e) {
        _readMetadata(e.metadata);
        _changes.ping();
      })
      // D154g: this phone's connection quality (the host's indicator).
      ..on<lk.ParticipantConnectionQualityUpdatedEvent>((e) {
        if (e.participant is! lk.LocalParticipant) return;
        _connection = switch (e.connectionQuality) {
          lk.ConnectionQuality.excellent => LiveConnectionQuality.excellent,
          lk.ConnectionQuality.good => LiveConnectionQuality.good,
          lk.ConnectionQuality.poor => LiveConnectionQuality.poor,
          lk.ConnectionQuality.lost => LiveConnectionQuality.lost,
          lk.ConnectionQuality.unknown => LiveConnectionQuality.unknown,
        };
        _changes.ping();
      })
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        _speaking = {for (final p in e.speakers) p.identity};
        _changes.ping();
      })
      ..on<lk.DataReceivedEvent>((e) {
        try {
          final message = jsonDecode(utf8.decode(e.data));
          if (message is Map && message['type'] == 'seat-invite') {
            final roomId = message['roomId'];
            if (roomId is String) _invites.add(roomId);
            return;
          }
          final chat = LiveChatEvent.parse(message);
          if (chat != null) _chat.add(chat);
        } on FormatException {
          // Not ours.
        }
      })
      ..on<lk.ParticipantConnectedEvent>((_) => _changes.ping())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _changes.ping())
      ..on<lk.TrackSubscribedEvent>((_) => _changes.ping())
      ..on<lk.TrackUnsubscribedEvent>((_) => _changes.ping())
      ..on<lk.TrackMutedEvent>((_) => _changes.ping())
      ..on<lk.TrackUnmutedEvent>((_) => _changes.ping())
      ..on<lk.ParticipantPermissionsUpdatedEvent>((_) => _changes.ping())
      ..on<lk.RoomDisconnectedEvent>((e) {
        if (e.reason == lk.DisconnectReason.participantRemoved) {
          _removed = true;
        }
        _changes.ping();
      });
  }

  void _readMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return;
    try {
      final value = jsonDecode(metadata);
      if (value is Map && value['seatsVersion'] is int) {
        _seatsVersion = value['seatsVersion'] as int;
      }
      if (value is Map && value['score'] is int) {
        _score = value['score'] as int;
      }
      if (value is Map && value['roomInfoVersion'] is int) {
        _roomInfoVersion = value['roomInfoVersion'] as int;
      }
    } on FormatException {
      // Not ours.
    }
  }

  @override
  Future<void> join(LiveMediaAccess access) async {
    if (_room != null) return;
    await _connect(access);
  }

  @override
  bool get canPublish =>
      _room?.localParticipant?.permissions.canPublish ?? false;

  @override
  Future<void> publishLocal({required bool video}) async {
    await startPreview(video: video);
    final local = _room?.localParticipant;
    if (local == null) return;
    final camera = _video;
    final audio = _audio;
    if (camera != null && local.videoTrackPublications.isEmpty) {
      await local.publishVideoTrack(camera);
    }
    if (audio != null && local.audioTrackPublications.isEmpty) {
      await local.publishAudioTrack(audio);
    }
    _changes.ping();
  }

  @override
  Future<void> unpublishLocal() async {
    _clipHold = false;
    await _room?.localParticipant?.unpublishAllTracks();
    await _stopVideo();
    final audio = _audio;
    _audio = null;
    await audio?.stop();
    await audio?.dispose();
    _changes.ping();
  }

  @override
  Widget? remoteVideo(String identity) {
    final participant = _room?.remoteParticipants[identity];
    if (participant == null) return null;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track != null && !publication.muted) {
        return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover);
      }
    }
    return null;
  }

  @override
  bool isPresent(String identity) =>
      _room?.remoteParticipants.containsKey(identity) ?? false;

  @override
  bool videoMuted(String identity) {
    final videos =
        _room?.remoteParticipants[identity]?.videoTrackPublications ?? const [];
    return videos.isNotEmpty && videos.every((p) => p.muted);
  }

  @override
  Set<String> get speaking => _speaking;

  @override
  int? get seatsVersion => _seatsVersion;

  @override
  int? get score => _score;

  @override
  int? get roomInfoVersion => _roomInfoVersion;

  @override
  Stream<String> get seatInvites => _invites.stream;

  @override
  Stream<LiveChatEvent> get chatEvents => _chat.stream;

  @override
  Listenable get changes => _changes;

  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;

  @override
  bool get removed => _removed;

  @override
  Future<void> stop() {
    // D144b: the camera's stop is known to [LiveCameraGate] at once, before
    // the room is left — the next go-live's camera waits for it.
    final camera = _video == null ? null : Completer<void>();
    if (camera != null) {
      unawaited(LiveCameraGate.stopping(() => camera.future));
    }
    return _stop(camera);
  }

  Future<void> _stop(Completer<void>? camera) async {
    _uplinkTimer?.cancel();
    _uplinkTimer = null;
    _uplink.reset();
    final listener = _listener;
    _listener = null;
    final room = _room;
    _room = null;
    final audio = _audio;
    _audio = null;
    _clipHold = false;
    try {
      await listener?.dispose();
      await room?.disconnect();
      await room?.dispose();
    } finally {
      // D144b: the camera always stops, also when leaving the room failed —
      // a leaked camera made every later one a shared track.
      try {
        await _stopVideo();
      } finally {
        camera?.complete();
      }
      await audio?.stop();
      await audio?.dispose();
    }
  }

  Future<void> _stopVideo() => LiveCameraGate.stopping(_stopVideoNow);

  Future<void> _stopVideoNow() async {
    final video = _video;
    final pipeline = _beautyPipeline;
    _video = null;
    _beautyPipeline = null;
    await pipeline?.dispose();
    await _fx.release();
    await video?.stop();
    await video?.dispose();
  }
}

/// A fresh engine per go-live (the screen and the host session share it).
final Provider<LiveMediaEngine Function()> liveMediaEngineProvider =
    Provider<LiveMediaEngine Function()>((_) => LiveKitMediaEngine.new);
