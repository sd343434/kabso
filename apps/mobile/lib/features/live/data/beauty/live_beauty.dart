import 'package:kabso_live/features/live/data/beauty/beauty_pipeline_stub.dart'
    if (dart.library.js_interop) 'package:kabso_live/features/live/data/beauty/beauty_pipeline_web.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// Beauty for the camera picture (owner D94), applied on the device before
/// publishing: skin smoothing and brightening, each 0 … 1.
@immutable
class LiveBeauty {
  const new({this.enabled = false, this.smooth = 0.5, this.brighten = 0.3});

  final bool enabled;
  final double smooth;
  final double brighten;

  LiveBeauty copyWith({bool? enabled, double? smooth, double? brighten}) =>
      LiveBeauty(
        enabled: enabled ?? this.enabled,
        smooth: smooth ?? this.smooth,
        brighten: brighten ?? this.brighten,
      );

  @override
  bool operator ==(Object other) =>
      other is LiveBeauty &&
      other.enabled == enabled &&
      other.smooth == smooth &&
      other.brighten == brighten;

  @override
  int get hashCode => Object.hash(enabled, smooth, brighten);
}

/// Processes the camera track: what is published and what the host sees.
abstract interface class BeautyPipeline {
  /// `null` where this platform has no pipeline yet.
  static BeautyPipeline? create() => createBeautyPipeline();

  /// Installs the processor on [track]; call before publishing.
  Future<void> attach(lk.LocalVideoTrack track);

  void update(LiveBeauty beauty);

  /// The processed picture (the host's preview), or `null` before [attach].
  Widget? preview({required bool mirror});

  Future<void> dispose();
}
