/// Kabso Live's camera processing on the published track (D144, phase 1:
/// Android).
///
/// One native processor runs on the camera track itself, inside
/// flutter_webrtc's pre-encoder frame processing, so the host's preview and
/// every viewer see the same picture. It has two stages, each a no-op until
/// asked for:
///
/// - **Colour** ([KabsoCameraFx.setColorMatrix]): an affine colour transform
///   on the GPU (D143 Magic's colour filters). Needs no licence.
/// - **DeepAR** ([KabsoCameraFx.setEffect]): face and background effects.
///   Needs the licence key ([KabsoCameraFx.setLicenseKey]); DeepAR is only
///   initialized when an effect is first picked (DeepAR bills monthly active
///   users by initialization, so a host who never picks one costs nothing).
///
/// [KabsoCameraFx.attach] installs the processor on a native camera track;
/// [KabsoCameraFx.release] takes it off and frees everything (the live
/// ended).
///
/// On every platform but Android [KabsoCameraFx.isSupported] is false and
/// every call is a no-op (iOS is phase 3).
///
/// D144a: DeepAR reports its state back ([KabsoCameraFx.statusChanges]) —
/// it switches an effect off by itself rather than freeze the picture — and
/// [KabsoCameraFx.diagnostics] feeds the non-release overlay.
/// [KabsoPermissions] checks and asks for the camera and microphone.
///
/// D228: a second, **free** effects engine ([KabsoCameraFxEngine.free]:
/// Google ML Kit selfie segmentation + MediaPipe Face Landmarker, GLSL on the
/// GPU, no licence key) runs instead of DeepAR when picked with
/// [KabsoCameraFx.setEngine]; its blur and beauty go through
/// [KabsoCameraFx.setFreeFx]. One engine at a time; DeepAR is unchanged.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Effects that need no effect file: they ship inside the DeepAR SDK.
abstract final class KabsoCameraFxEffects {
  /// DeepAR's built-in background blur (its `backgroundBlur` API).
  static const String backgroundBlur = 'builtin:background_blur';
}

/// D228: which effects engine the processor runs.
enum KabsoCameraFxEngine {
  /// DeepAR (D144; licence key, monthly active users).
  deepAr('deepar'),

  /// The free engine: ML Kit + MediaPipe + GLSL, on the device.
  free('free');

  const KabsoCameraFxEngine(this.wire);

  /// The channel's value.
  final String wire;
}

/// D228: what the free engine applies. Strengths are 0 … 1 (Magic's
/// sliders are 0 … 100); out-of-range values are clamped.
@immutable
class KabsoFreeFx {
  const KabsoFreeFx({
    this.backgroundBlur = false,
    this.smooth = 0,
    this.brighten = 0,
    this.slim = 0,
    this.eyes = 0,
  });

  static const KabsoFreeFx none = KabsoFreeFx();

  final bool backgroundBlur;

  /// Skin smoothing (bilateral, on the face skin only).
  final double smooth;

  /// Brighten / whiten.
  final double brighten;

  /// Face slimming (a subtle jaw warp).
  final double slim;

  /// Eye enlargement (subtle).
  final double eyes;

  bool get isNone =>
      !backgroundBlur && smooth <= 0 && brighten <= 0 && slim <= 0 && eyes <= 0;

  Map<String, Object?> toMap() {
    double unit(double v) => v.isNaN ? 0 : v.clamp(0, 1).toDouble();
    return {
      'blur': backgroundBlur,
      'smooth': unit(smooth),
      'brighten': unit(brighten),
      'slim': unit(slim),
      'eyes': unit(eyes),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is KabsoFreeFx &&
      other.backgroundBlur == backgroundBlur &&
      other.smooth == smooth &&
      other.brighten == brighten &&
      other.slim == slim &&
      other.eyes == eyes;

  @override
  int get hashCode => Object.hash(backgroundBlur, smooth, brighten, slim, eyes);
}

/// DeepAR's state on the native side (D144a). D228: the free engine reports
/// the same states (its reasons: `gl_failed`, `init_failed`,
/// `model_unavailable`, `too_slow`, `no_frames`, `init_timeout`, `no_output`;
/// `ready` with `beauty_unavailable` when the face model could not be
/// loaded but the blur runs).
enum KabsoCameraFxState {
  /// No effect picked.
  off,

  /// An effect was picked; DeepAR is starting (raw camera meanwhile).
  initializing,

  /// The effect is on the published picture.
  ready,

  /// DeepAR refused the licence key (or the build has none).
  licenceFailed,

  /// DeepAR failed to start or to take frames ([KabsoCameraFxStatus.reason]:
  /// `init_timeout`, `start_failed`, `surface_failed`, `feed_failed`,
  /// `effect_failed`; D144b: `no_frames` — no camera frame reached the effect
  /// within 10 s of the pick; D144c: `engine_busy` — the app's previous
  /// DeepAR engine was not released within 10 s).
  error,

  /// The effect switched itself off: DeepAR stopped giving new pictures
  /// (`no_output`), its thread hung (`stalled`), or (D145e) its picture was
  /// black while the camera's was not (`black_output`). The raw camera goes
  /// on.
  disabled;

  /// Whether the effect is off because something went wrong.
  bool get isFailure =>
      this == licenceFailed || this == error || this == disabled;

  static KabsoCameraFxState parse(Object? value) => switch (value) {
    'initializing' => initializing,
    'ready' => ready,
    'licence_failed' => licenceFailed,
    'error' => error,
    'disabled' => disabled,
    _ => off,
  };
}

/// A DeepAR state change from the native side.
@immutable
class KabsoCameraFxStatus {
  const KabsoCameraFxStatus(this.state, [this.reason]);

  /// From the channel's `{state, reason}`.
  factory KabsoCameraFxStatus.fromMap(Object? map) {
    if (map is! Map) return off;
    final reason = map['reason'];
    return KabsoCameraFxStatus(
      KabsoCameraFxState.parse(map['state']),
      reason is String ? reason : null,
    );
  }

  static const KabsoCameraFxStatus off = KabsoCameraFxStatus(
    KabsoCameraFxState.off,
  );

  final KabsoCameraFxState state;

  /// A short code for why (never free text from DeepAR), or null.
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is KabsoCameraFxStatus &&
      other.state == state &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(state, reason);

  @override
  String toString() =>
      'KabsoCameraFxStatus(${state.name}${reason == null ? '' : ', $reason'})';
}

/// The processor's counters for the non-release diagnostics overlay
/// (D144a). Never contains the licence key: only whether one is present.
@immutable
class KabsoCameraFxDiagnostics {
  const KabsoCameraFxDiagnostics({
    required this.status,
    required this.licencePresent,
    this.attached = false,
    this.initialized = false,
    this.framesIn = 0,
    this.fed = 0,
    this.busySkips = 0,
    this.delivered = 0,
    this.staleDropped = 0,
    this.framesOut = 0,
    this.timeouts = 0,
    this.consecutiveMisses = 0,
    this.avgWaitMs = 0,
    this.avgPackMs = 0,
    this.inFlightMs = 0,
    this.instances = 0,
    this.input,
    this.sdkVersion,
    this.lastError,
    this.inputLuma = -1,
    this.outputLuma = -1,
    this.blackMs = 0,
    this.probe,
    this.cameraFrames = 0,
    this.framePath,
    this.litMs = -1,
    this.heldBlack = 0,
    this.engine = -1,
    this.lastWarning,
    this.fxEngine,
    this.frameMs = 0,
    this.lastFrameMs = 0,
    this.budgetMs = 0,
    this.slowFrames = 0,
    this.skippedFrames = 0,
    this.backoffs = 0,
    this.analysisMs = 0,
    this.segmentMs = 0,
    this.landmarkMs = 0,
    this.analyses = 0,
    this.facePresent = false,
    this.faceModel,
  });

  factory KabsoCameraFxDiagnostics.fromMap(Map<Object?, Object?> map) {
    int count(String key) => switch (map[key]) {
      final int v => v,
      final num v => v.toInt(),
      _ => 0,
    };
    double ms(String key) => switch (map[key]) {
      final num v => v.toDouble(),
      _ => 0,
    };
    String? text(String key) => switch (map[key]) {
      final String v => v,
      _ => null,
    };
    return KabsoCameraFxDiagnostics(
      status: KabsoCameraFxStatus.fromMap(map),
      licencePresent: map['licencePresent'] == true,
      attached: map['attached'] == true,
      initialized: map['initialized'] == true,
      framesIn: count('framesIn'),
      fed: count('fed'),
      busySkips: count('busySkips'),
      delivered: count('delivered'),
      staleDropped: count('staleDropped'),
      framesOut: count('framesOut'),
      timeouts: count('timeouts'),
      consecutiveMisses: count('consecutiveMisses'),
      avgWaitMs: ms('avgWaitMs'),
      avgPackMs: ms('avgPackMs'),
      inFlightMs: count('inFlightMs'),
      instances: count('instances'),
      input: text('input'),
      sdkVersion: text('sdkVersion'),
      lastError: text('lastError'),
      inputLuma: map['inputLuma'] is num ? count('inputLuma') : -1,
      outputLuma: map['outputLuma'] is num ? count('outputLuma') : -1,
      blackMs: count('blackMs'),
      probe: text('probe'),
      cameraFrames: count('cameraFrames'),
      framePath: text('framePath'),
      litMs: map['litMs'] is num ? count('litMs') : -1,
      heldBlack: count('heldBlack'),
      engine: map['engine'] is num ? count('engine') : -1,
      lastWarning: text('lastWarning'),
      fxEngine: text('fxEngine'),
      frameMs: ms('frameMs'),
      lastFrameMs: ms('lastFrameMs'),
      budgetMs: count('budgetMs'),
      slowFrames: count('slowFrames'),
      skippedFrames: count('skippedFrames'),
      backoffs: count('backoffs'),
      analysisMs: ms('analysisMs'),
      segmentMs: ms('segmentMs'),
      landmarkMs: ms('landmarkMs'),
      analyses: count('analyses'),
      facePresent: map['facePresent'] == true,
      faceModel: text('faceModel'),
    );
  }

  final KabsoCameraFxStatus status;

  /// A DeepAR licence key reached the native side (the key itself never
  /// does leave it).
  final bool licencePresent;

  /// The processor is on a camera track.
  final bool attached;

  /// DeepAR said `initialized()`.
  final bool initialized;

  /// Camera frames seen while an effect was on.
  final int framesIn;

  /// Frames DeepAR took (`receiveFrame` returned).
  final int fed;

  /// Frames not fed because DeepAR was still busy with the previous one.
  final int busySkips;

  /// Renders that reached the processor.
  final int delivered;

  /// Renders dropped as re-draws of a picture already published.
  final int staleDropped;

  /// Frames published with the effect.
  final int framesOut;

  /// Frames that passed raw (no fresh render in time, or still starting).
  final int timeouts;

  final int consecutiveMisses;

  /// Average wait for DeepAR per frame, and the input readback, last second.
  final double avgWaitMs;
  final double avgPackMs;

  /// How long the frame now with DeepAR has been there (0: none).
  final int inFlightMs;

  /// DeepAR instances created (a new one per camera rotation change).
  final int instances;

  /// DeepAR's latched input, `WxH@rotation`.
  final String? input;
  final String? sdkVersion;

  /// DeepAR's or the stage's last error (a type and message, no key).
  final String? lastError;

  /// D145e: mean brightness (0–255, video black is 16) of the last frame fed
  /// to DeepAR, and of the last DeepAR picture read back; -1: no sample.
  /// Input lit and output black means DeepAR's output is black, not its
  /// camera input.
  final int inputLuma;
  final int outputLuma;

  /// How long DeepAR's picture has been black against a lit camera (ms).
  final int blackMs;

  /// After `black_output`: what DeepAR showed without the effect —
  /// `passthrough_ok` (the camera: the effect's render is black),
  /// `passthrough_black` (nothing of the camera), `no_samples`, or `running`.
  final String? probe;

  /// D144b: every camera frame the track handed to the processor, effect or
  /// not. 0 while attached means the processor is not on the camera's frame
  /// path — the effect cannot get a picture.
  final int cameraFrames;

  /// D144b: how the last attach found its track: `source` (the camera's own
  /// frame path), `rebound` (a shared camera track, moved onto the path),
  /// `unknown` (could not tell).
  final String? framePath;

  /// D144c: ms from the pick to DeepAR's first lit picture; -1: none yet
  /// (its renders so far were black, or there were none).
  final int litMs;

  /// D144c: DeepAR renders held back because they were black (the camera
  /// went out instead).
  final int heldBlack;

  /// D144c: DeepAR's own engine state — 0 none, 1 initializing, 2 running,
  /// 3 shutting down, 4 surface lost; -1 no DeepAR.
  final int engine;

  /// D144c: DeepAR's last warning (its errors stay in [lastError]).
  final String? lastWarning;

  /// D228: the engine these counters are from: `deepar` or `free`.
  final String? fxEngine;

  /// D228 (free engine): the GPU time per frame — the last second's average
  /// and the last frame — against the budget (a frame over it goes raw).
  final double frameMs;
  final double lastFrameMs;
  final int budgetMs;

  /// D228: frames over the budget, frames passed raw while backing off,
  /// and how many back-offs are running (3 in a row → `too_slow`).
  final int slowFrames;
  final int skippedFrames;
  final int backoffs;

  /// D228: the last analysis (segmentation + landmarks, on a 256-px copy)
  /// and its two parts, in ms; analyses done.
  final double analysisMs;
  final double segmentMs;
  final double landmarkMs;
  final int analyses;

  /// D228: a face is tracked now.
  final bool facePresent;

  /// D228: the face model: `absent`, `downloading`, `ready`, `failed`.
  final String? faceModel;

  /// D228: these counters are the free engine's.
  bool get isFree => fxEngine == KabsoCameraFxEngine.free.wire;
}

/// Steers the native processor. The native side keeps a single processor;
/// the methods are safe to call in any order, and every failure (no plugin,
/// a platform error) reads as "did not happen" rather than throwing.
class KabsoCameraFx {
  /// [channel] and [supported] are seams for tests.
  KabsoCameraFx({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel(channelName),
      _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// The method channel the Android plugin listens on.
  static const String channelName = 'com.kabso/camera_fx';

  final MethodChannel _channel;
  final bool _supported;
  StreamController<KabsoCameraFxStatus>? _status;

  /// Whether this platform has the processor (Android only, phase 1).
  bool get isSupported => _supported;

  /// D144a: DeepAR's state changes, as the native side reports them
  /// (nothing where unsupported).
  Stream<KabsoCameraFxStatus> get statusChanges {
    final existing = _status;
    if (existing != null) return existing.stream;
    final created = StreamController<KabsoCameraFxStatus>.broadcast();
    _status = created;
    if (_supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'status') {
          created.add(KabsoCameraFxStatus.fromMap(call.arguments));
        }
        return null;
      });
    }
    return created.stream;
  }

  /// D144a: the processor's state and counters for the diagnostics overlay;
  /// null where unsupported or when the plugin does not answer.
  Future<KabsoCameraFxDiagnostics?> diagnostics() async {
    if (!_supported) return null;
    final map = await _call<Map<Object?, Object?>>('diagnostics', null);
    return map == null ? null : KabsoCameraFxDiagnostics.fromMap(map);
  }

  /// Installs the processor on the native camera track [trackId]
  /// (`MediaStreamTrack.id`; for LiveKit `track.mediaStreamTrack.id`),
  /// moving it off the previous track if any. Call again after the track was
  /// restarted (a new id). The colour and effect carry over.
  Future<bool> attach(String trackId) async {
    if (!_supported || trackId.isEmpty) return false;
    return await _call<bool>('attach', {'trackId': trackId}) ?? false;
  }

  /// The colour transform, row-major 3 × 4 on RGB in 0 … 1
  /// (`[r0 r1 r2 o, g0 g1 g2 o, b0 b1 b2 o]`); `null` for none.
  Future<void> setColorMatrix(List<double>? matrix) async {
    if (!_supported) return;
    if (matrix != null && matrix.length != 12) {
      throw ArgumentError.value(matrix.length, 'matrix', 'needs 12 values');
    }
    await _call<void>('setColorMatrix', {'matrix': matrix});
  }

  /// Gives the native side the DeepAR licence key. Does not start DeepAR.
  /// False when unsupported or [licenseKey] is empty. The key is never logged
  /// on either side.
  Future<bool> setLicenseKey(String licenseKey) async {
    if (!_supported || licenseKey.isEmpty) return false;
    return await _call<bool>('setLicenseKey', {'licenseKey': licenseKey}) ??
        false;
  }

  /// Picks the DeepAR effect: a Flutter asset key of a `.deepar` file, one
  /// of [KabsoCameraFxEffects], or `null` for none (DeepAR paused). The
  /// first effect initializes DeepAR ([setLicenseKey] first).
  Future<void> setEffect(String? effect) async {
    if (!_supported) return;
    await _call<void>('setEffect', {'effect': effect});
  }

  /// D228: picks the effects engine. Switching turns the other one off
  /// (DeepAR is released and never initialized while [KabsoCameraFxEngine.free]
  /// runs). Forgotten by [release] (back to DeepAR).
  Future<void> setEngine(KabsoCameraFxEngine engine) async {
    if (!_supported) return;
    await _call<void>('setEngine', {'engine': engine.wire});
  }

  /// D228: the free engine's blur and beauty ([KabsoFreeFx.none]: off).
  /// Only applied while the free engine is picked.
  Future<void> setFreeFx(KabsoFreeFx fx) async {
    if (!_supported) return;
    await _call<void>('setFreeFx', fx.toMap());
  }

  /// Takes the processor off its track and releases DeepAR and the GPU
  /// stage; colour and effect are forgotten.
  ///
  /// D144b: with [trackId], only if the processor is still on that track —
  /// a camera that stops late never takes the next camera's processor away.
  Future<void> release({String? trackId}) async {
    if (!_supported) return;
    await _call<void>('release', trackId == null ? null : {'trackId': trackId});
  }

  Future<T?> _call<T>(String method, Map<String, Object?>? arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('kabso_camera_fx $method failed: ${e.code}');
      return null;
    }
  }
}

/// D251c: flips a native camera track to the other camera (same channel as
/// [KabsoCameraFx]).
class KabsoCameraFlipper {
  /// [channel] and [supported] are seams for tests.
  KabsoCameraFlipper({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel(KabsoCameraFx.channelName),
      _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final MethodChannel _channel;
  final bool _supported;

  /// Whether this platform has the native flip (Android only).
  bool get isSupported => _supported;

  /// Flips the camera of the native track [trackId] to the other side,
  /// judged from the camera that track really has (not flutter_webrtc's
  /// shared facing flag). A running camera switches in place; a camera whose
  /// session is gone is restarted on the other side without being stopped.
  ///
  /// Null where unsupported or when the plugin does not answer (the caller
  /// falls back to its own switch). A refusal THROWS the
  /// [PlatformException] (code `cameraFlip`, message
  /// `why=<no-capturer|no-device|switch-busy|switch-error> [state=<state>]`).
  Future<KabsoCameraFlip?> flip(String trackId) async {
    if (!_supported || trackId.isEmpty) return null;
    final Map<Object?, Object?>? map;
    try {
      map = await _channel.invokeMethod<Map<Object?, Object?>>('flipCamera', {
        'trackId': trackId,
      });
    } on MissingPluginException {
      return null;
    }
    return map == null ? null : KabsoCameraFlip.fromMap(map);
  }
}

/// D251c: how [KabsoCameraFlipper.flip] flipped the camera.
@immutable
class KabsoCameraFlip {
  const KabsoCameraFlip({required this.front, required this.path, this.state});

  /// Reads the native answer; unknown words become `other` / null.
  factory KabsoCameraFlip.fromMap(Map<Object?, Object?> map) {
    final path = map['path'];
    final state = map['state'];
    return KabsoCameraFlip(
      front: map['front'] == true,
      path: path == 'switch' || path == 'restart' ? path as String : 'other',
      state: state is String && cameraStates.contains(state) ? state : null,
    );
  }

  /// The camera states the native side may report; nothing else is kept.
  static const Set<String> cameraStates = {
    'NEW',
    'OPENING',
    'OPENED',
    'CLOSED',
    'DISCONNECTED',
    'ERROR',
    'FREEZED',
  };

  /// Whether the camera now on is the front one.
  final bool front;

  /// `switch` (the running session switched) or `restart` (no session: the
  /// other camera was opened).
  final String path;

  /// The camera's state before the flip, if known.
  final String? state;
}

/// One permission's state (D144a), from [KabsoPermissions].
enum KabsoPermissionStatus {
  granted,

  /// Never asked by this app: the system prompt will show.
  notAsked,

  /// Refused; the system will still ask again.
  denied,

  /// Refused for good: only the app's settings can change it.
  blocked,

  /// This platform cannot tell (not Android): the capture asks itself.
  unknown;

  static KabsoPermissionStatus parse(Object? value) => switch (value) {
    'granted' => granted,
    'notAsked' => notAsked,
    'denied' => denied,
    'blocked' => blocked,
    _ => unknown,
  };
}

/// What [KabsoPermissions] covers. D152: [notifications] is Android 13+'s
/// POST_NOTIFICATIONS (pushes); before 13 it is granted unless the app's
/// notifications are off in the system settings (then blocked).
enum KabsoPermission { camera, microphone, notifications }

/// D144a: camera and microphone permissions for going live (Android): check,
/// ask the system once, open the app's settings. Elsewhere everything is
/// [KabsoPermissionStatus.unknown] and [openSettings] is false.
class KabsoPermissions {
  /// [channel] and [supported] are seams for tests.
  KabsoPermissions({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel(channelName),
      _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// The method channel the Android plugin listens on.
  static const String channelName = 'com.kabso/permissions';

  final MethodChannel _channel;
  final bool _supported;

  bool get isSupported => _supported;

  /// The state of each of [permissions], without asking.
  Future<Map<KabsoPermission, KabsoPermissionStatus>> status(
    Set<KabsoPermission> permissions,
  ) => _ask('status', permissions);

  /// Shows the system prompt for those of [permissions] not granted (once),
  /// and answers the state of each afterwards.
  Future<Map<KabsoPermission, KabsoPermissionStatus>> request(
    Set<KabsoPermission> permissions,
  ) => _ask('request', permissions);

  /// Opens this app's page in the system settings; false when it could not.
  Future<bool> openSettings() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<Map<KabsoPermission, KabsoPermissionStatus>> _ask(
    String method,
    Set<KabsoPermission> permissions,
  ) async {
    final unknown = {
      for (final p in permissions) p: KabsoPermissionStatus.unknown,
    };
    if (!_supported || permissions.isEmpty) return unknown;
    try {
      final answer = await _channel.invokeMethod<Map<Object?, Object?>>(
        method,
        {
          'kinds': [for (final p in permissions) p.name],
        },
      );
      if (answer == null) return unknown;
      return {
        for (final p in permissions)
          p: KabsoPermissionStatus.parse(answer[p.name]),
      };
    } on MissingPluginException {
      return unknown;
    } on PlatformException catch (e) {
      debugPrint('kabso_permissions $method failed: ${e.code}');
      return unknown;
    }
  }
}
