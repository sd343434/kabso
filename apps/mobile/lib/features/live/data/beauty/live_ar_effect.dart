import 'package:flutter/foundation.dart';
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

/// D144a: where the picked effect stands on the device (DeepAR's state as
/// the native processor reports it).
enum LiveArState {
  /// No effect picked.
  off,

  /// Starting: the camera goes out without the effect meanwhile.
  starting,

  /// On the published picture.
  running,

  /// Switched off because it could not run: [LiveArStatus.problem] says why.
  /// The camera goes on without it — never a frozen picture.
  unavailable,
}

/// Why an effect is [LiveArState.unavailable].
enum LiveArProblem {
  /// DeepAR refused the licence key.
  licence,

  /// DeepAR stopped giving new pictures, or hung.
  stopped,

  /// DeepAR did not start (or failed otherwise).
  failed,
}

/// D144a: the effect's state, for Magic's honest message and the
/// diagnostics overlay.
@immutable
class LiveArStatus {
  const new(this.state, {this.problem, this.code});

  /// From the native processor's status.
  factory from(KabsoCameraFxStatus status) => switch (status.state) {
    KabsoCameraFxState.off => off,
    KabsoCameraFxState.initializing => const LiveArStatus(LiveArState.starting),
    KabsoCameraFxState.ready => const LiveArStatus(LiveArState.running),
    KabsoCameraFxState.licenceFailed => LiveArStatus(
      LiveArState.unavailable,
      problem: LiveArProblem.licence,
      code: status.reason,
    ),
    KabsoCameraFxState.disabled => LiveArStatus(
      LiveArState.unavailable,
      problem: LiveArProblem.stopped,
      code: status.reason,
    ),
    KabsoCameraFxState.error => LiveArStatus(
      LiveArState.unavailable,
      problem: LiveArProblem.failed,
      code: status.reason,
    ),
  };

  static const LiveArStatus off = LiveArStatus(LiveArState.off);

  final LiveArState state;
  final LiveArProblem? problem;

  /// The native reason code (`no_output`, `stalled`, `init_timeout`, …), for
  /// the diagnostics overlay; never shown as the message itself.
  final String? code;

  @override
  bool operator ==(Object other) =>
      other is LiveArStatus &&
      other.state == state &&
      other.problem == problem &&
      other.code == code;

  @override
  int get hashCode => Object.hash(state, problem, code);

  @override
  String toString() => 'LiveArStatus(${state.name}, $problem, $code)';
}
