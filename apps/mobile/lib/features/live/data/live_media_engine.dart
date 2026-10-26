import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
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
/// depend on the device or the media server. As a [LiveVoiceMic] it frees
/// the published microphone while a chat voice clip records (CP-017).
abstract interface class LiveMediaEngine implements LiveVoiceMic {
  /// Starts the camera (front by default, unless [video] is false: audio
  /// rooms) and the microphone for the preview. Throws a
  /// [LiveCaptureException] when they cannot start. Calling it again with
  /// another [video] switches.
  Future<void> startPreview({bool video = true});

  /// Whether the camera is part of the preview.
  bool get videoEnabled;

  /// Whether beauty works on this device (D94).
  bool get beautySupported;

  /// Beauty on the camera picture, before and while live.
  Future<void> setBeauty(LiveBeauty beauty);

  /// Voice processing on the microphone (D94 audio settings): noise
  /// reduction, and enhancement (echo cancelling and level balancing).
  Future<void> setVoice({required bool noiseReduction, required bool enhance});

  /// The camera picture (cover-fit, mirrored for the front camera), or
  /// `null` before [startPreview] succeeded.
  Widget? preview();

  bool get frontCamera;

  Future<void> flipCamera();

  bool get micEnabled;

  Future<void> setMicEnabled({required bool enabled});

  /// Joins the room's media session with [access] and publishes what is
  /// running (camera and microphone, or the microphone alone).
  Future<void> publish(LiveMediaAccess access);

  /// Leaves the session (if any) and turns the camera and microphone off.
  Future<void> stop();

  // ---- the session (CP-010 viewers, CP-011 seats) -----------------------

  /// Joins the room's media session with [access] without publishing
  /// (viewers, guests). A seated guest then calls [publishLocal].
  Future<void> join(LiveMediaAccess access);

  /// Whether the media server lets this participant publish now (seated).
  bool get canPublish;

  /// Starts the camera ([video]) and microphone and publishes them (a
  /// seated guest, CP-011). Throws a [LiveCaptureException].
  Future<void> publishLocal({required bool video});

  /// Stops publishing and turns the camera and microphone off (off the
  /// seat); the session stays joined.
  Future<void> unpublishLocal();

  /// The video of the participant [identity] (a user id), or `null`.
  Widget? remoteVideo(String identity);

  /// Whether [identity] is in the session now.
  bool isPresent(String identity);

  /// The identities speaking now (the local one included).
  Set<String> get speaking;

  /// `seatsVersion` from the media room's metadata (CP-011 §10.9).
  int? get seatsVersion;

  /// The room score from the media room's metadata (CP-012 §10.10).
  int? get score;

  /// `roomInfoVersion` from the media room's metadata (CP-014 §10.12): the
  /// title, category or topic changed.
  int? get roomInfoVersion;

  /// Room ids of seat invitations addressed to this participant.
  Stream<String> get seatInvites;

  /// CP-013: the server's chat data messages in the room (§10.11).
  Stream<LiveChatEvent> get chatEvents;

  /// Notifies on any session change: participants, tracks, speakers,
  /// metadata, permissions, connection.
  Listenable get changes;

  bool get connected;

  /// v1.20-live (§10.20): the media server removed this participant (the
  /// LiveKit disconnect reason "participant removed": a kick).
  bool get removed;
}

class _Changes extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// [LiveMediaEngine] on `livekit_client` (its defaults: 720p, simulcast).
class LiveKitMediaEngine implements LiveMediaEngine {
  lk.LocalVideoTrack? _video;
  lk.LocalAudioTrack? _audio;
  lk.Room? _room;
  BeautyPipeline? _beautyPipeline;
  LiveBeauty _beauty = const LiveBeauty();
  bool _front = true;
  bool _mic = true;
  bool _noiseReduction = true;
  bool _enhance = true;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final _changes = _Changes();
  final _invites = StreamController<String>.broadcast();
  final _chat = StreamController<LiveChatEvent>.broadcast();
  Set<String> _speaking = const {};
  int? _seatsVersion;
  int? _score;
  int? _roomInfoVersion;
  bool _removed = false;

  /// CP-017: the published microphone is paused for a voice clip.
  bool _clipHold = false;

  @override
  bool get videoEnabled => _video != null;

  @override
  bool get beautySupported => kIsWeb;

  @override
  Future<void> setBeauty(LiveBeauty beauty) async {
    _beauty = beauty;
    _beautyPipeline?.update(beauty);
  }

  @override
  Future<void> startPreview({bool video = true}) async {
    try {
      if (video && _video == null) {
        final camera = await lk.LocalVideoTrack.createCameraTrack(
          lk.CameraCaptureOptions(
            cameraPosition: _front
                ? lk.CameraPosition.front
                : lk.CameraPosition.back,
          ),
        );
        _video = camera;
        final pipeline = BeautyPipeline.create();
        if (pipeline != null) {
          pipeline.update(_beauty);
          await pipeline.attach(camera);
          _beautyPipeline = pipeline;
        }
        await camera.start();
      } else if (!video && _video != null) {
        await _stopVideo();
      }
      if (_audio == null) {
        final audio = await lk.LocalAudioTrack.create(_audioOptions);
        _audio = audio;
        if (!_mic) await audio.mute();
      }
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

  lk.AudioCaptureOptions get _audioOptions => lk.AudioCaptureOptions(
    noiseSuppression: _noiseReduction,
    echoCancellation: _enhance,
    autoGainControl: _enhance,
  );

  @override
  Future<void> setVoice({
    required bool noiseReduction,
    required bool enhance,
  }) async {
    _noiseReduction = noiseReduction;
    _enhance = enhance;
    final audio = _audio;
    if (audio == null) return;
    if (audio.sender != null) {
      // Published: restart in place with the new processing.
      await audio.restartTrack(_audioOptions);
      return;
    }
    // Preview only: a new microphone track with the new processing.
    _audio = null;
    await audio.stop();
    await audio.dispose();
    final fresh = await lk.LocalAudioTrack.create(_audioOptions);
    _audio = fresh;
    if (!_mic) await fresh.mute();
  }

  @override
  Widget? preview() {
    final video = _video;
    if (video == null) return null;
    final processed = _beautyPipeline?.preview(mirror: _front);
    if (processed != null) return processed;
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
    // While a voice clip records, the choice applies when it ends.
    if (audio == null || _clipHold) return;
    if (enabled) {
      await audio.unmute();
    } else {
      await audio.mute();
    }
  }

  @override
  /// CP-017: on Android, WebRTC's capture and the clip recorder cannot both
  /// hear the microphone (the clip came out silent). Muting the track tells
  /// the others (their usual muted state) and stops it; detaching it from
  /// the sender stops the send stream, so WebRTC closes its capture and the
  /// recorder gets the microphone. [resumeAfterClip] unmutes, which
  /// restarts the track and attaches it again.
  @override
  Future<bool> pauseForClip() async {
    final audio = _audio;
    final sender = audio?.sender;
    if (audio == null || sender == null || _clipHold) return false;
    _clipHold = true;
    try {
      if (!audio.muted) await audio.mute();
      await sender.replaceTrack(null);
    } on Object {
      await resumeAfterClip();
      throw const LiveCaptureException(LiveCaptureProblem.unavailable);
    }
    return true;
  }

  @override
  Future<void> resumeAfterClip() async {
    if (!_clipHold) return;
    _clipHold = false;
    final audio = _audio;
    if (audio == null || audio.sender == null) return;
    // Back as the person left it: on again only if it was on. A muted
    // track stays detached; turning the mic on restarts and attaches it.
    if (_mic) await audio.unmute();
    _changes.ping();
  }

  @override
  Future<void> publish(LiveMediaAccess access) async {
    final video = _video;
    final audio = _audio;
    if (audio == null) throw StateError('startPreview() first');
    final room = await _connect(access);
    if (video != null) await room.localParticipant!.publishVideoTrack(video);
    await room.localParticipant!.publishAudioTrack(audio);
  }

  Future<lk.Room> _connect(LiveMediaAccess access) async {
    final room = lk.Room();
    _room = room;
    _removed = false;
    _listen(room);
    await room.connect(access.url, access.token);
    _readMetadata(room.metadata);
    _changes.ping();
    return room;
  }

  void _listen(lk.Room room) {
    _listener = room.createListener()
      ..on<lk.RoomMetadataChangedEvent>((e) {
        _readMetadata(e.metadata);
        _changes.ping();
      })
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        _speaking = {for (final p in e.speakers) p.identity};
        _changes.ping();
      })
      ..on<lk.DataReceivedEvent>((e) {
        try {
          final message = jsonDecode(utf8.decode(e.data));
          if (message is Map && message['type'] == 'seat-invite') {
            final roomId = message['roomId'];
            if (roomId is String) _invites.add(roomId);
            return;
          }
          final chat = LiveChatEvent.parse(message);
          if (chat != null) _chat.add(chat);
        } on FormatException {
          // Not ours.
        }
      })
      ..on<lk.ParticipantConnectedEvent>((_) => _changes.ping())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _changes.ping())
      ..on<lk.TrackSubscribedEvent>((_) => _changes.ping())
      ..on<lk.TrackUnsubscribedEvent>((_) => _changes.ping())
      ..on<lk.TrackMutedEvent>((_) => _changes.ping())
      ..on<lk.TrackUnmutedEvent>((_) => _changes.ping())
      ..on<lk.ParticipantPermissionsUpdatedEvent>((_) => _changes.ping())
      ..on<lk.RoomDisconnectedEvent>((e) {
        if (e.reason == lk.DisconnectReason.participantRemoved) {
          _removed = true;
        }
        _changes.ping();
      });
  }

  void _readMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return;
    try {
      final value = jsonDecode(metadata);
      if (value is Map && value['seatsVersion'] is int) {
        _seatsVersion = value['seatsVersion'] as int;
      }
      if (value is Map && value['score'] is int) {
        _score = value['score'] as int;
      }
      if (value is Map && value['roomInfoVersion'] is int) {
        _roomInfoVersion = value['roomInfoVersion'] as int;
      }
    } on FormatException {
      // Not ours.
    }
  }

  @override
  Future<void> join(LiveMediaAccess access) async {
    if (_room != null) return;
    await _connect(access);
  }

  @override
  bool get canPublish =>
      _room?.localParticipant?.permissions.canPublish ?? false;

  @override
  Future<void> publishLocal({required bool video}) async {
    await startPreview(video: video);
    final local = _room?.localParticipant;
    if (local == null) return;
    final camera = _video;
    final audio = _audio;
    if (camera != null && local.videoTrackPublications.isEmpty) {
      await local.publishVideoTrack(camera);
    }
    if (audio != null && local.audioTrackPublications.isEmpty) {
      await local.publishAudioTrack(audio);
    }
    _changes.ping();
  }

  @override
  Future<void> unpublishLocal() async {
    _clipHold = false;
    await _room?.localParticipant?.unpublishAllTracks();
    await _stopVideo();
    final audio = _audio;
    _audio = null;
    await audio?.stop();
    await audio?.dispose();
    _changes.ping();
  }

  @override
  Widget? remoteVideo(String identity) {
    final participant = _room?.remoteParticipants[identity];
    if (participant == null) return null;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track != null && !publication.muted) {
        return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover);
      }
    }
    return null;
  }

  @override
  bool isPresent(String identity) =>
      _room?.remoteParticipants.containsKey(identity) ?? false;

  @override
  Set<String> get speaking => _speaking;

  @override
  int? get seatsVersion => _seatsVersion;

  @override
  int? get score => _score;

  @override
  int? get roomInfoVersion => _roomInfoVersion;

  @override
  Stream<String> get seatInvites => _invites.stream;

  @override
  Stream<LiveChatEvent> get chatEvents => _chat.stream;

  @override
  Listenable get changes => _changes;

  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;

  @override
  bool get removed => _removed;

  @override
  Future<void> stop() async {
    final listener = _listener;
    _listener = null;
    await listener?.dispose();
    final room = _room;
    _room = null;
    final audio = _audio;
    _audio = null;
    _clipHold = false;
    await room?.disconnect();
    await room?.dispose();
    await _stopVideo();
    await audio?.stop();
    await audio?.dispose();
  }

  Future<void> _stopVideo() async {
    final video = _video;
    final pipeline = _beautyPipeline;
    _video = null;
    _beautyPipeline = null;
    await pipeline?.dispose();
    await video?.stop();
    await video?.dispose();
  }
}

/// A fresh engine per go-live (the screen and the host session share it).
final Provider<LiveMediaEngine Function()> liveMediaEngineProvider =
    Provider<LiveMediaEngine Function()>((_) => LiveKitMediaEngine.new);
