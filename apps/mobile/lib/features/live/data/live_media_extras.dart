import 'package:flutter/foundation.dart';

/// D201 (v1.45-live, CONVENTIONS §10.63): what the live tools read from the
/// media session beyond `LiveMediaEngine` — kept apart so engines and test
/// fakes that do not know the tools keep working (a screen checks
/// `engine is LiveParticipantAttributes`).
abstract interface class LiveParticipantAttributes {
  /// The participant attributes of the remote participant [identity] (empty
  /// when it is not in the session). They change with the engine's
  /// `changes`.
  Map<String, String> attributesOf(String identity);
}

/// D243: whether the media session is over for good. `connected` alone is
/// false while LiveKit reconnects (a Wi-Fi / mobile handover, a resumed ICE
/// connection), which is not an end: the second camera's screen ended itself
/// on such a blip and left the live. Kept apart like the other extras (a
/// screen checks `engine is LiveSessionLink`).
abstract interface class LiveSessionLink {
  /// The session closed and will not come back (LiveKit gave up
  /// reconnecting, the server closed the room or removed this participant,
  /// or this phone left). False while connecting or reconnecting.
  bool get sessionClosed;
}

/// D251 (owner: «الكاميرا الثانية … أوّل ما تفتح تعلق»): pauses the
/// published camera while the app is away WITHOUT stopping or reopening the
/// capture.
///
/// `LiveMediaEngine.setVideoPaused` mutes the LiveKit way: the camera track
/// is disposed (`trackDispose`) and unmuting opens a new one
/// (`getUserMedia`). On Android, flutter_webrtc 1.6.2 does both on the
/// platform (main) thread with unbounded busy-waits —
/// `CameraEventsHandler.waitForCameraClosed()` (until CLOSED or ERROR) and
/// `waitForCameraOpen()` (until the first frame or ERROR). A camera that ends
/// DISCONNECTED (evicted, or handed back late after a system dialog / the
/// app returning) never reaches either state, so the main thread spins for
/// ever: input and vsync stop and the whole app hangs (ANR).
///
/// Here the others are told the camera is off (LiveKit's muted signal, the
/// track disabled), the capture is left as it is, and the native track stays
/// enabled so flutter_webrtc's own resume hook (`reStartCamera`, an
/// asynchronous `startCapture` on the same capturer) restarts the camera if
/// Android stopped it in the background. Same track, same id: the camera
/// processor (filters) stays attached.
abstract interface class LiveSoftVideoPause {
  /// Tells the others the camera is away ([away]) or back.
  Future<void> setVideoAway({required bool away});
}

/// D201: records the published camera and microphone of this phone to a
/// file (the host's clip, ≤ 60 s). Android only: flutter_webrtc's recorder
/// there takes the camera track and the microphone's samples; on iOS it
/// records no microphone for LiveKit's separate audio track, on the web it is
/// not offered.
abstract interface class LiveClipCapture {
  /// Why clips cannot be recorded here, or null when they can.
  LiveClipUnsupported? get clipUnsupported;

  /// Starts recording the camera on now (and the microphone) to [path], an
  /// `.mp4` file. Throws when it cannot start.
  Future<void> startClip(String path);

  /// Stops the recording (the file is complete when this returns).
  Future<void> stopClip();

  /// A still of the camera now (PNG / JPEG bytes), for the clip's poster, or
  /// null when the platform gives none.
  Future<Uint8List?> cameraStill();
}

/// D201: why the recorder is not offered (the tile says so).
enum LiveClipUnsupported {
  /// iOS: flutter_webrtc's recorder records no sound from LiveKit's
  /// microphone track.
  ios,

  /// The web build.
  web,

  /// No camera is on (an audio live, or the camera is off).
  noCamera,
}

/// D201 participant attribute on a second camera: `HOST` / `SECOND`, the
/// default main feed (§10.63).
const String liveAttrMainFeed = 'kabso.mainFeed';

/// D201 participant attribute on the host: when the clip recording ends
/// (ISO 8601); absent while not recording.
const String liveAttrRecordingUntil = 'kabso.recordingUntil';

/// The media identity of [hostUserId]'s second camera.
String liveSecondCameraIdentity(String hostUserId) => 'cam2:$hostUserId';

/// Whether [attributes] say the host records now (at [now]).
bool liveRecordingNow(Map<String, String> attributes, DateTime now) {
  final until = DateTime.tryParse(attributes[liveAttrRecordingUntil] ?? '');
  return until != null && until.isAfter(now);
}

/// D225 (owner, «إعدادات المشاهدة»): what a viewer changes on this phone only
/// — the live's sound and its video. Nothing is sent: the others hear and
/// see the live as before. Kept apart from `LiveMediaEngine` like the other
/// extras (a screen checks `engine is LivePlaybackControls`).
abstract interface class LivePlaybackControls {
  /// The live's sound here: 0 (muted) to 1 (as sent). It applies to the
  /// tracks playing now and to the ones that start later in this session.
  Future<void> setPlaybackVolume(double volume);

  /// Data saver: the other participants' video is not received (sound
  /// only); off receives it again.
  Future<void> setReceiveVideo({required bool receive});
}
