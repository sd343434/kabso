import 'dart:typed_data';

import 'package:kabso_live/features/live/data/live_voice_recorder.dart';

/// An in-memory [LiveVoiceRecorder] (tests only): no microphone. [problem]
/// makes `start` fail; `stop` returns [clip] at [peakDb] (speech by
/// default; set it under [LiveVoiceClip.silenceDb] for a silent clip).
class FakeLiveVoiceRecorder implements LiveVoiceRecorder {
  /// What [supported] answers (false: the web).
  bool canRecord = true;
  LiveVoiceProblem? problem;
  Uint8List clip = Uint8List(2048);
  double? peakDb = -20;

  /// When set, `stop` throws it.
  Exception? stopFailure;
  bool recording = false;
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  /// Calls in order (`start`, `stop`, `cancel`), to check what happened
  /// around the live microphone.
  final List<String> log = [];

  @override
  bool get supported => canRecord;

  @override
  Future<void> start() async {
    starts++;
    log.add('start');
    if (problem case final p?) throw LiveVoiceException(p);
    recording = true;
  }

  @override
  Future<LiveVoiceClip?> stop() async {
    stops++;
    log.add('stop');
    recording = false;
    if (stopFailure case final failure?) throw failure;
    return LiveVoiceClip(clip, peakDb: peakDb);
  }

  @override
  Future<void> cancel() async {
    if (recording) {
      cancels++;
      log.add('cancel');
    }
    recording = false;
  }

  @override
  Future<void> dispose() => cancel();
}
