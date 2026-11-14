import 'dart:async';

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

/// A recorded voice clip: its bytes, and the loudest level heard while
/// recording (dBFS; `null` where the recorder cannot tell).
@immutable
class LiveVoiceClip {
  const new(this.bytes, {this.peakDb});

  final Uint8List bytes;

  /// The loudest level sampled while recording, in dBFS (0 is full scale;
  /// a microphone that delivered nothing reads about -160).
  final double? peakDb;

  /// Below this the clip is taken as silence and not sent: a microphone
  /// held by something else (e.g. the live's own capture on Android)
  /// delivers digital silence (about -160 dBFS), while a quiet room reads
  /// around -60…-50 and speech well above -40.
  static const silenceDb = -60.0;

  /// Whether the clip is known to be silent ([peakDb] stayed under
  /// [silenceDb]). Unknown levels are not refused.
  bool get silent => (peakDb ?? 0) < silenceDb;
}

/// The live's own microphone, as a voice clip needs it (CP-017): on Android
/// the live's capture (LiveKit/WebRTC) and the clip recorder cannot both
/// hear the microphone, so the live's microphone is paused for the clip and
/// restored after.
abstract interface class LiveVoiceMic {
  /// Frees the microphone for a clip. Returns whether anything was paused
  /// (false when this person publishes no microphone). Throws when the
  /// microphone could not be freed.
  Future<bool> pauseForClip();

  /// Restores what [pauseForClip] paused. Safe to call more than once.
  Future<void> resumeAfterClip();
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

  /// Stops and returns the clip, or `null` when nothing was recorded.
  Future<LiveVoiceClip?> stop();

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
  StreamSubscription<Amplitude>? _levels;
  double? _peakDb;

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
    // The loudest level heard, to refuse a silent clip (CP-017).
    _peakDb = null;
    try {
      _levels = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen(_onLevel, onError: (Object _) {});
    } on Object {
      _levels = null;
    }
  }

  void _onLevel(Amplitude level) {
    final db = level.current;
    if (db.isNaN) return;
    final peak = _peakDb;
    if (peak == null || db > peak) _peakDb = db;
  }

  Future<void> _stopLevels() async {
    await _levels?.cancel();
    _levels = null;
  }

  @override
  Future<LiveVoiceClip?> stop() async {
    final recorder = _recorder;
    final path = _path;
    _path = null;
    if (recorder == null || path == null) return null;
    await _stopLevels();
    final written = await recorder.stop();
    final bytes = await takeVoiceBytes(written ?? path);
    if (bytes == null) return null;
    return LiveVoiceClip(bytes, peakDb: _peakDb);
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    await _stopLevels();
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
