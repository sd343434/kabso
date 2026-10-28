import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/core/config/deepar_config.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';

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
    _statusSub = _bridge.statusChanges.listen(
      (s) => _status.value = LiveArStatus.from(s),
    );
  }

  LiveBeauty _wanted = const LiveBeauty();
  String? _trackId;

  // What the native side was last told (null: nothing since a release).
  List<double>? _sentMatrix;
  LiveArEffect? _sentEffect;
  bool _keySent = false;

  /// Colour filters run here.
  bool get filtersSupported => _bridge.isSupported;

  LiveArSupport get effects {
    if (!_bridge.isSupported) return LiveArSupport.unsupported;
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
    final filter = _wanted.filter;
    final matrix = filter.isNatural ? null : filter.matrix;
    if (!_sameMatrix(matrix, _sentMatrix) || _sentEffect == null) {
      await _bridge.setColorMatrix(matrix);
      _sentMatrix = matrix;
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
  }

  /// The camera stopped (the live ended, off the seat): processor off,
  /// DeepAR released. What was picked is kept for the next [attach].
  Future<void> release() async {
    if (!_bridge.isSupported) return;
    final wasInUse = _trackId != null || _keySent;
    _trackId = null;
    _sentMatrix = null;
    _sentEffect = null;
    _keySent = false;
    _status.value = LiveArStatus.off;
    await _statusSub?.cancel();
    _statusSub = null;
    if (wasInUse) await _bridge.release();
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
