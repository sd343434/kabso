import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/data/voice/voice_files_stub.dart'
    if (dart.library.io) 'package:kabso_live/features/live/data/voice/voice_files_io.dart';
import 'package:record/record.dart';

/// Why a voice clip could not be recorded.
enum LiveVoiceProblem {
  /// The person refused the microphone (or the system blocks it).
  denied,

  /// No microphone, or it is busy.
  unavailable,
}

/// Thrown by [LiveVoiceRecorder.start].
class LiveVoiceException implements Exception {
  const new(this.problem);

  final LiveVoiceProblem problem;

  @override
  String toString() => 'LiveVoiceException(${problem.name})';
}

/// The microphone for live chat voice clips (CP-017): AAC in an MPEG-4
/// container (`.m4a`, `audio/mp4`), behind an interface so tests need no
/// microphone.
abstract interface class LiveVoiceRecorder {
  /// Whether clips can be recorded here (not on the web).
  bool get supported;

  /// Asks for the microphone if needed and starts recording. Throws a
  /// [LiveVoiceException].
  Future<void> start();

  /// Stops and returns the clip's bytes, or `null` when nothing was
  /// recorded.
  Future<Uint8List?> stop();

  /// Stops and throws the clip away.
  Future<void> cancel();

  /// Releases the microphone.
  Future<void> dispose();
}

/// [LiveVoiceRecorder] on the `record` package: mono AAC-LC at 64 kbit/s,
/// so 30 s stay far under the server's 1 MiB.
class RecordVoiceRecorder implements LiveVoiceRecorder {
  AudioRecorder? _recorder;
  String? _path;

  @override
  bool get supported => !kIsWeb;

  @override
  Future<void> start() async {
    final recorder = _recorder ??= AudioRecorder();
    final bool allowed;
    try {
      allowed = await recorder.hasPermission();
    } on Object {
      throw const LiveVoiceException(LiveVoiceProblem.unavailable);
    }
    if (!allowed) throw const LiveVoiceException(LiveVoiceProblem.denied);
    final path = await newVoicePath();
    if (path == null) {
      throw const LiveVoiceException(LiveVoiceProblem.unavailable);
    }
    _path = path;
    try {
      await recorder.start(
        const RecordConfig(bitRate: 64000, numChannels: 1),
        path: path,
      );
    } on Object {
      _path = null;
      await deleteVoiceFile(path);
      throw const LiveVoiceException(LiveVoiceProblem.unavailable);
    }
  }

  @override
  Future<Uint8List?> stop() async {
    final recorder = _recorder;
    final path = _path;
    _path = null;
    if (recorder == null || path == null) return null;
    final written = await recorder.stop();
    final bytes = await takeVoiceBytes(written ?? path);
    return bytes;
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    await _recorder?.cancel();
    if (path != null) await deleteVoiceFile(path);
  }

  @override
  Future<void> dispose() async {
    final recorder = _recorder;
    if (_path != null) await cancel();
    _recorder = null;
    await recorder?.dispose();
  }
}

/// A fresh recorder per composer (tests override it).
final Provider<LiveVoiceRecorder Function()> liveVoiceRecorderProvider =
    Provider<LiveVoiceRecorder Function()>((_) => RecordVoiceRecorder.new);
