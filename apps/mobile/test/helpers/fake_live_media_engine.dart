import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:material_ui/material_ui.dart';

/// In-memory [LiveMediaEngine]: no camera, no media server. Records every
/// call; [previewProblem] / [publishFailure] make them fail.
class FakeLiveMediaEngine implements LiveMediaEngine {
  static const previewKey = Key('fakeCamera');

  LiveCaptureProblem? previewProblem;
  Exception? publishFailure;

  int previewStarts = 0;
  int flips = 0;
  int stops = 0;
  bool running = false;
  LiveMediaAccess? published;
  bool _front = true;
  bool _mic = true;

  @override
  Future<void> startPreview() async {
    previewStarts++;
    if (previewProblem case final problem?) {
      throw LiveCaptureException(problem);
    }
    running = true;
  }

  @override
  Widget? preview() => running
      ? ColoredBox(
          key: previewKey,
          color: _front ? const Color(0xFF203040) : const Color(0xFF402030),
        )
      : null;

  @override
  bool get frontCamera => _front;

  @override
  Future<void> flipCamera() async {
    flips++;
    _front = !_front;
  }

  @override
  bool get micEnabled => _mic;

  @override
  Future<void> setMicEnabled({required bool enabled}) async => _mic = enabled;

  @override
  Future<void> publish(LiveMediaAccess access) async {
    if (publishFailure case final failure?) throw failure;
    published = access;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
    published = null;
  }
}
