import 'package:kabso_live/features/live/data/beauty/beauty_pipeline_stub.dart'
    if (dart.library.js_interop) 'package:kabso_live/features/live/data/beauty/beauty_pipeline_web.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// Beauty for the camera picture (owner D94), applied on the device before
/// publishing: skin smoothing and brightening, each 0 … 1 — and, D143
/// (Magic), a colour [filter], applied whether beauty is on or not.
@immutable
class LiveBeauty {
  const new({
    this.enabled = false,
    this.smooth = 0.5,
    this.brighten = 0.3,
    this.filter = LiveColorFilter.natural,
  });

  final bool enabled;
  final double smooth;
  final double brighten;
  final LiveColorFilter filter;

  LiveBeauty copyWith({
    bool? enabled,
    double? smooth,
    double? brighten,
    LiveColorFilter? filter,
  }) => LiveBeauty(
    enabled: enabled ?? this.enabled,
    smooth: smooth ?? this.smooth,
    brighten: brighten ?? this.brighten,
    filter: filter ?? this.filter,
  );

  @override
  bool operator ==(Object other) =>
      other is LiveBeauty &&
      other.enabled == enabled &&
      other.smooth == smooth &&
      other.brighten == brighten &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(enabled, smooth, brighten, filter);
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
