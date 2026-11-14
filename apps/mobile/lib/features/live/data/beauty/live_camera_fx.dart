import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/core/config/deepar_config.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';

/// D144: the native camera processor (`kabso_camera_fx`) on the host's
/// published camera, Android only in phase 1: D143's colour filters and
/// DeepAR effects, on the frames the encoder sends — what the host sees is
/// what the viewers get.
///
/// [attach] is cheap: with no filter and no effect the processor passes
/// frames untouched. DeepAR is only initialized (and a monthly active user
/// counted) when an effect is first picked.
///
/// D144a: [status] follows DeepAR on the device — the native side switches an
/// effect off by itself (and says why) instead of freezing the picture; the
/// non-release overlay reads [diagnostics].
///
/// D144b: an effect that is still starting [startTimeout] after it was picked
/// is reported unavailable here too ([LiveArProblem.failed], `start_timeout`)
/// — a backstop behind the native 10 s start watch, so Magic can never say
/// «جارٍ تشغيل المؤثر…» for ever even if the native side goes quiet. And
/// [release] names this camera's track, so a camera stopping late (the last
/// go-live screen) never frees the processor the next camera now has.
///
/// D228: [setEngine] picks the effects engine. With [LiveFxEngine.free] the
/// effect and [LiveBeauty.free] go to the native free engine (no licence
/// key; DeepAR is never initialized), so [effects] is ready wherever the
/// processor exists; with [LiveFxEngine.deepAr] everything is as in D144.
class LiveCameraFx {
  new({KabsoCameraFx? bridge, String? licenseKey})
    : _bridge = bridge ?? KabsoCameraFx(),
      _licenseKey = licenseKey ?? DeepArConfig.licenseAndroid;

  final KabsoCameraFx _bridge;
  final String _licenseKey;
  final ValueNotifier<LiveArStatus> _status = ValueNotifier(LiveArStatus.off);
  StreamSubscription<KabsoCameraFxStatus>? _statusSub;

  /// The picked effect's state on the device (D144a).
  ValueListenable<LiveArStatus> get status => _status;

  /// The processor's counters for the non-release overlay (D144a); null
  /// where there is no processor.
  Future<KabsoCameraFxDiagnostics?> diagnostics() => _bridge.diagnostics();

  void _listen() {
    if (_statusSub != null || !_bridge.isSupported) return;
    _statusSub = _bridge.statusChanges.listen(_onNative);
  }

  void _onNative(KabsoCameraFxStatus native) {
    final next = LiveArStatus.from(native);
    if (next.state != LiveArState.starting) _startTimer?.cancel();
    // After the backstop fired, the native side going off (the effect set
    // back to None) must not hide why.
    if (_timedOut && next.state == LiveArState.off) return;
    _status.value = next;
  }

  /// D144b: how long an effect may stay starting before the app gives up on
  /// it (the native start watch gives up at 10 s; this only matters when it
  /// stays silent).
  static const Duration startTimeout = Duration(seconds: 12);

  /// D228: the free engine's backstop — its native start watch allows 20 s
  /// (the face model's first download included).
  static const Duration freeStartTimeout = Duration(seconds: 25);

  /// The code [status] carries when the backstop fired.
  static const String startTimeoutCode = 'start_timeout';

  Timer? _startTimer;
  bool _timedOut = false;

  void _armStart() {
    _startTimer?.cancel();
    _timedOut = false;
    _startTimer = Timer(
      _engine == LiveFxEngine.free ? freeStartTimeout : startTimeout,
      () {
        if (_status.value.state == LiveArState.running ||
            _status.value.state == LiveArState.unavailable) {
          return;
        }
        _timedOut = true;
        _status.value = const LiveArStatus(
          LiveArState.unavailable,
          problem: LiveArProblem.failed,
          code: startTimeoutCode,
        );
      },
    );
  }

  LiveBeauty _wanted = const LiveBeauty();
  String? _trackId;

  // What the native side was last told (null: nothing since a release).
  List<double>? _sentMatrix;
  LiveArEffect? _sentEffect;
  bool _keySent = false;

  // D228: the engine wanted, and what the native side was last told.
  LiveFxEngine _engine = LiveFxEngine.deepAr;
  LiveFxEngine? _sentEngine;
  KabsoFreeFx? _sentFree;

  /// D228: the effects engine in use.
  LiveFxEngine get engine => _engine;

  /// D228: picks the effects engine; what was picked moves to it (DeepAR's
  /// effect off when the free engine takes over, and back).
  Future<void> setEngine(LiveFxEngine engine) async {
    if (engine == _engine) return;
    _engine = engine;
    _startTimer?.cancel();
    if (!_bridge.isSupported) return;
    await _sync();
  }

  /// Colour filters (and D157's fill light) run here.
  bool get filtersSupported => _bridge.isSupported;

  LiveArSupport get effects {
    if (!_bridge.isSupported) return LiveArSupport.unsupported;
    // D228: the free engine needs no key.
    if (_engine == LiveFxEngine.free) return LiveArSupport.ready;
    if (_licenseKey.isEmpty) return LiveArSupport.unlicensed;
    return LiveArSupport.ready;
  }

  /// The native track the processor is on, or null.
  String? get trackId => _trackId;

  /// Installs (or moves) the processor on the camera track [trackId] — again
  /// after the track was restarted (a new id). What was picked carries over.
  Future<void> attach(String trackId) async {
    if (!_bridge.isSupported || trackId == _trackId) return;
    _listen();
    final ok = await _bridge.attach(trackId);
    _trackId = ok ? trackId : null;
    if (ok) await _sync();
  }

  /// Applies [beauty]'s colour filter and effect (skin smoothing is the web's
  /// alone for now).
  Future<void> update(LiveBeauty beauty) async {
    _wanted = beauty;
    if (!_bridge.isSupported) return;
    await _sync();
  }

  Future<void> _sync() async {
    // D143 colour filter with D157's fill light before it, in one stage.
    final matrix = _wanted.colorMatrix;
    if (!_sameMatrix(matrix, _sentMatrix) || _sentEffect == null) {
      await _bridge.setColorMatrix(matrix);
      _sentMatrix = matrix;
    }
    if (_engine == LiveFxEngine.free) {
      await _syncFree();
      return;
    }
    if (_sentEngine == LiveFxEngine.free) {
      // Back to DeepAR: the native side turns the free engine off.
      await _bridge.setEngine(KabsoCameraFxEngine.deepAr);
      _sentEngine = LiveFxEngine.deepAr;
      _sentFree = null;
    }
    final effect = effects == LiveArSupport.ready
        ? _wanted.effect
        : LiveArEffect.none;
    if (effect == _sentEffect) return;
    if (effect != LiveArEffect.none && !_keySent) {
      _listen();
      _keySent = await _bridge.setLicenseKey(_licenseKey);
      if (!_keySent) return;
    }
    await _bridge.setEffect(effect.source);
    _sentEffect = effect;
    if (effect == LiveArEffect.none) {
      _startTimer?.cancel();
    } else {
      _armStart();
    }
  }

  /// D228: the free engine gets the blur and the beauty sliders; DeepAR is
  /// switched off by the native side (never initialized).
  Future<void> _syncFree() async {
    if (_sentEngine != LiveFxEngine.free) {
      await _bridge.setEngine(KabsoCameraFxEngine.free);
      _sentEngine = LiveFxEngine.free;
      _sentEffect = LiveArEffect.none;
      _sentFree = null;
    }
    final want = _wanted.free.toNative(
      backgroundBlur: _wanted.effect == LiveArEffect.backgroundBlur,
    );
    if (want == _sentFree) return;
    _listen();
    final starting = (_sentFree?.isNone ?? true) && !want.isNone;
    await _bridge.setFreeFx(want);
    _sentFree = want;
    if (want.isNone) {
      _startTimer?.cancel();
    } else if (starting) {
      _armStart();
    }
  }

  /// The camera stopped (the live ended, off the seat): processor off,
  /// DeepAR released. What was picked is kept for the next [attach].
  Future<void> release() async {
    if (!_bridge.isSupported) return;
    final wasInUse = _trackId != null || _keySent || _sentFree != null;
    final trackId = _trackId;
    _startTimer?.cancel();
    _timedOut = false;
    _trackId = null;
    _sentMatrix = null;
    _sentEffect = null;
    _keySent = false;
    // D228: the native release forgets the engine (back to DeepAR); the
    // wanted one is sent again on the next attach.
    _sentEngine = null;
    _sentFree = null;
    _status.value = LiveArStatus.off;
    await _statusSub?.cancel();
    _statusSub = null;
    if (wasInUse) await _bridge.release(trackId: trackId);
  }

  static bool _sameMatrix(List<double>? a, List<double>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
