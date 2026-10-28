import 'package:kabso_camera_fx/kabso_camera_fx.dart';

/// D144 (Magic → Effects, beta): an AR effect on the published camera
/// picture, run by DeepAR on the device before the encoder.
///
/// Phase 1 ships one effect, DeepAR's built-in background blur: DeepAR's free
/// effects pack carries no licence that clearly allows redistributing its
/// files in a public repository, and the blur ships inside the SDK itself.
enum LiveArEffect {
  none,
  backgroundBlur;

  /// What the native processor loads; `null` for [none].
  String? get source => switch (this) {
    LiveArEffect.none => null,
    LiveArEffect.backgroundBlur => KabsoCameraFxEffects.backgroundBlur,
  };
}

/// Whether AR effects can run here.
enum LiveArSupport {
  /// This platform has no camera processor (web; iOS until phase 3): the
  /// Effects section is not shown.
  unsupported,

  /// The processor exists but this build has no DeepAR licence key: the
  /// section is shown greyed with why.
  unlicensed,

  ready,
}
