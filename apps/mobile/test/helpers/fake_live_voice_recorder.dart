import 'dart:typed_data';

import 'package:kabso_live/features/live/data/live_voice_recorder.dart';

/// An in-memory [LiveVoiceRecorder] (tests only): no microphone. [problem]
/// makes `start` fail; `stop` returns [clip].
class FakeLiveVoiceRecorder implements LiveVoiceRecorder {
  /// What [supported] answers (false: the web).
  bool canRecord = true;
  LiveVoiceProblem? problem;
  Uint8List clip = Uint8List(2048);
  bool recording = false;
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  bool get supported => canRecord;

  @override
  Future<void> start() async {
    starts++;
    if (problem case final p?) throw LiveVoiceException(p);
    recording = true;
  }

  @override
  Future<Uint8List?> stop() async {
    stops++;
    recording = false;
    return clip;
  }

  @override
  Future<void> cancel() async {
    if (recording) cancels++;
    recording = false;
  }

  @override
  Future<void> dispose() => cancel();
}
