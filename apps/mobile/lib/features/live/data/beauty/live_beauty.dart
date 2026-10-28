import 'package:kabso_live/features/live/data/beauty/beauty_pipeline_stub.dart'
    if (dart.library.js_interop) 'package:kabso_live/features/live/data/beauty/beauty_pipeline_web.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// Beauty for the camera picture (owner D94), applied on the device before
/// publishing: skin smoothing and brightening, each 0 … 1 — and, D143
/// (Magic), a colour [filter], applied whether beauty is on or not — and,
/// D144 (Magic → Effects, beta), an AR [effect] where the device runs one —
/// and, D157, the front camera's fill [light] (an exposure lift with a warm
/// tint, in the colour stage before the filter: [colorMatrix]).
@immutable
class LiveBeauty {
  const new({
    this.enabled = false,
    this.smooth = 0.5,
    this.brighten = 0.3,
    this.filter = LiveColorFilter.natural,
    this.effect = LiveArEffect.none,
    this.light = LiveFillLight.off,
  });

  final bool enabled;
  final double smooth;
  final double brighten;
  final LiveColorFilter filter;
  final LiveArEffect effect;
  final LiveFillLight light;

  /// The colour stage's transform (row-major 3 × 4): the fill [light], then
  /// the [filter]; `null` when neither changes the picture.
  List<double>? get colorMatrix => liveColorMatrix(filter, light);

  LiveBeauty copyWith({
    bool? enabled,
    double? smooth,
    double? brighten,
    LiveColorFilter? filter,
    LiveArEffect? effect,
    LiveFillLight? light,
  }) => LiveBeauty(
    enabled: enabled ?? this.enabled,
    smooth: smooth ?? this.smooth,
    brighten: brighten ?? this.brighten,
    filter: filter ?? this.filter,
    effect: effect ?? this.effect,
    light: light ?? this.light,
  );

  @override
  bool operator ==(Object other) =>
      other is LiveBeauty &&
      other.enabled == enabled &&
      other.smooth == smooth &&
      other.brighten == brighten &&
      other.filter == filter &&
      other.effect == effect &&
      other.light == light;

  @override
  int get hashCode =>
      Object.hash(enabled, smooth, brighten, filter, effect, light);
}

/// Processes the camera track: what is published and what the host sees.
abstract interface class BeautyPipeline {
  /// `null` where this platform has no pipeline yet.
  static BeautyPipeline? create() => createBeautyPipeline();

  /// Installs the processor on [track]; call before publishing. Every
  /// frame it publishes carries [update]'s beauty and colour filter.
  Future<void> attach(lk.LocalVideoTrack track);

  void update(LiveBeauty beauty);

  /// The processed picture (the host's preview), or `null` before [attach].
  Widget? preview({required bool mirror});

  Future<void> dispose();
}
