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
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Effects that need no effect file: they ship inside the DeepAR SDK.
abstract final class KabsoCameraFxEffects {
  /// DeepAR's built-in background blur (its `backgroundBlur` API).
  static const String backgroundBlur = 'builtin:background_blur';
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

  /// Whether this platform has the processor (Android only, phase 1).
  bool get isSupported => _supported;

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

  /// Takes the processor off its track and releases DeepAR and the GPU
  /// stage; colour and effect are forgotten.
  Future<void> release() async {
    if (!_supported) return;
    await _call<void>('release', null);
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
