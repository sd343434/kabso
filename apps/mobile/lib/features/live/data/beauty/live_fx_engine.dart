import 'package:flutter/foundation.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';

/// D228: which effects engine runs Magic's effects on the host's published
/// camera (Android). The owner compares the two on a real phone; DeepAR is
/// not replaced.
///
/// - [deepAr]: D144's DeepAR (licence key; background blur).
/// - [free]: Google ML Kit selfie segmentation + MediaPipe Face Landmarker
///   with GLSL on the GPU (no key, on the device): background blur and four
///   beauty sliders ([LiveFreeBeauty]).
///
/// Chosen by the server (`LiveConfig.cameraFxEngine`, the OWNER's toggle in
/// the admin panel) and, in debug/profile builds only, overridden on this
/// phone (`liveFxEngineOverrideProvider`). Removing the free engine removes
/// this file's [free] value and [LiveFreeBeauty] (docs/KNOWN_LIMITATIONS.md,
/// D228).
enum LiveFxEngine {
  deepAr('DEEPAR', KabsoCameraFxEngine.deepAr),
  free('FREE', KabsoCameraFxEngine.free);

  new(this.wire, this.native);

  /// The contract's value (`LiveConfig.cameraFxEngine`).
  final String wire;

  /// The native processor's engine.
  final KabsoCameraFxEngine native;

  /// The server's value; anything unknown (an older or newer server) is
  /// DeepAR, the default.
  static LiveFxEngine parse(Object? value) =>
      value == free.wire ? free : deepAr;
}

/// D228: the free engine's beauty, each strength 0 … 100 (Magic's sliders;
/// default 40). [on] false: no beauty at all (the face model is not even
/// downloaded).
@immutable
class LiveFreeBeauty {
  const new({
    this.on = false,
    this.smooth = defaultStrength,
    this.brighten = defaultStrength,
    this.slim = defaultStrength,
    this.eyes = defaultStrength,
  });

  static const int defaultStrength = 40;

  final bool on;
  final int smooth;
  final int brighten;
  final int slim;
  final int eyes;

  /// What the native free engine gets, with [backgroundBlur] beside it.
  KabsoFreeFx toNative({required bool backgroundBlur}) => KabsoFreeFx(
    backgroundBlur: backgroundBlur,
    smooth: on ? smooth / 100 : 0,
    brighten: on ? brighten / 100 : 0,
    slim: on ? slim / 100 : 0,
    eyes: on ? eyes / 100 : 0,
  );

  LiveFreeBeauty copyWith({
    bool? on,
    int? smooth,
    int? brighten,
    int? slim,
    int? eyes,
  }) => LiveFreeBeauty(
    on: on ?? this.on,
    smooth: _clamp(smooth ?? this.smooth),
    brighten: _clamp(brighten ?? this.brighten),
    slim: _clamp(slim ?? this.slim),
    eyes: _clamp(eyes ?? this.eyes),
  );

  static int _clamp(int v) => v.clamp(0, 100);

  @override
  bool operator ==(Object other) =>
      other is LiveFreeBeauty &&
      other.on == on &&
      other.smooth == smooth &&
      other.brighten == brighten &&
      other.slim == slim &&
      other.eyes == eyes;

  @override
  int get hashCode => Object.hash(on, smooth, brighten, slim, eyes);

  @override
  String toString() =>
      'LiveFreeBeauty(${on ? 'on' : 'off'}, $smooth, $brighten, $slim, $eyes)';
}
