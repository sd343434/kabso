import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// Thrown by [LiveMediaEngine.startPreview].
class LiveCaptureException implements Exception {
  const new(this.problem);

  final LiveCaptureProblem problem;

  @override
  String toString() => 'LiveCaptureException(${problem.name})';
}

/// Why the camera or microphone could not start.
enum LiveCaptureProblem {
  /// The person refused access (or the system blocks it).
  denied,

  /// No camera or microphone was found, or it is in use.
  unavailable,
}

/// The camera, microphone and media session of the person going live
/// (CP-010, LiveKit, D3), behind an interface so screens and tests do not
/// depend on the device or the media server.
abstract interface class LiveMediaEngine {
  /// Starts the camera (front by default) and microphone for the preview.
  /// Throws a [LiveCaptureException] when they cannot start.
  Future<void> startPreview();

  /// The camera picture (cover-fit, mirrored for the front camera), or
  /// `null` before [startPreview] succeeded.
  Widget? preview();

  bool get frontCamera;

  Future<void> flipCamera();

  bool get micEnabled;

  Future<void> setMicEnabled({required bool enabled});

  /// Joins the room's media session with [access] and publishes the camera
  /// and microphone already running.
  Future<void> publish(LiveMediaAccess access);

  /// Leaves the session (if any) and turns the camera and microphone off.
  Future<void> stop();
}

/// [LiveMediaEngine] on `livekit_client` (its defaults: 720p, simulcast).
class LiveKitMediaEngine implements LiveMediaEngine {
  lk.LocalVideoTrack? _video;
  lk.LocalAudioTrack? _audio;
  lk.Room? _room;
  bool _front = true;
  bool _mic = true;

  @override
  Future<void> startPreview() async {
    if (_video != null) return;
    try {
      _video = await lk.LocalVideoTrack.createCameraTrack(
        lk.CameraCaptureOptions(
          cameraPosition: _front
              ? lk.CameraPosition.front
              : lk.CameraPosition.back,
        ),
      );
      await _video!.start();
      _audio = await lk.LocalAudioTrack.create(const lk.AudioCaptureOptions());
      if (!_mic) await _audio!.mute();
    } on Object catch (e) {
      await stop();
      final text = e.toString().toLowerCase();
      throw LiveCaptureException(
        text.contains('notallowed') ||
                text.contains('permission') ||
                text.contains('denied')
            ? LiveCaptureProblem.denied
            : LiveCaptureProblem.unavailable,
      );
    }
  }

  @override
  Widget? preview() {
    final video = _video;
    if (video == null) return null;
    return lk.VideoTrackRenderer(
      video,
      fit: lk.VideoViewFit.cover,
      mirrorMode: _front
          ? lk.VideoViewMirrorMode.mirror
          : lk.VideoViewMirrorMode.off,
    );
  }

  @override
  bool get frontCamera => _front;

  @override
  Future<void> flipCamera() async {
    _front = !_front;
    await _video?.setCameraPosition(
      _front ? lk.CameraPosition.front : lk.CameraPosition.back,
    );
  }

  @override
  bool get micEnabled => _mic;

  @override
  Future<void> setMicEnabled({required bool enabled}) async {
    _mic = enabled;
    final audio = _audio;
    if (audio == null) return;
    if (enabled) {
      await audio.unmute();
    } else {
      await audio.mute();
    }
  }

  @override
  Future<void> publish(LiveMediaAccess access) async {
    final video = _video;
    final audio = _audio;
    if (video == null || audio == null) {
      throw StateError('startPreview() first');
    }
    final room = lk.Room();
    _room = room;
    await room.connect(access.url, access.token);
    await room.localParticipant!.publishVideoTrack(video);
    await room.localParticipant!.publishAudioTrack(audio);
  }

  @override
  Future<void> stop() async {
    final room = _room;
    _room = null;
    final video = _video;
    final audio = _audio;
    _video = null;
    _audio = null;
    await room?.disconnect();
    await room?.dispose();
    await video?.stop();
    await audio?.stop();
    await video?.dispose();
    await audio?.dispose();
  }
}

/// A fresh engine per go-live (the screen and the host session share it).
final Provider<LiveMediaEngine Function()> liveMediaEngineProvider =
    Provider<LiveMediaEngine Function()>((_) => LiveKitMediaEngine.new);
