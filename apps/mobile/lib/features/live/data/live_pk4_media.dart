import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// v1.118-live (D391, CONVENTIONS §10.180, CP-041 §8): ONE of the three other
/// rooms of a 4-way PK — a subscribe-only, hidden connection to that room's
/// media session (`createLivePk4MediaToken`). The cost is kept low (owner:
/// «قللها»): viewers take the **lowest simulcast layer** (a quarter-screen
/// pane), the host the middle one; a hidden pane's video is **paused**
/// (unsubscribed on the server, the sound kept); the connection is closed as
/// the match closes. Nothing is published; that room's data messages are
/// ignored (each room keeps its chat, gifts and seats).
abstract interface class LivePk4RoomMedia {
  /// Connects with the watch-only token (once; a second call is ignored).
  /// [lowLayer]: LOW (viewers), else MEDIUM (the room's host).
  Future<void> join({
    required String url,
    required String token,
    required bool lowLayer,
  });

  /// Disconnects (idempotent).
  Future<void> leave();

  /// The video of [identity] in that room, or null (none, paused).
  Widget? video(String identity);

  /// The identities speaking now in that room.
  Set<String> get speaking;

  /// This room's host muted that room's host for this room.
  Future<void> setAudioMuted({required bool muted});

  bool get audioMuted;

  /// The pane is hidden (the app in the background, a full-screen sheet):
  /// the video is unsubscribed on the server, the sound kept.
  Future<void> setVideoPaused({required bool paused});

  bool get videoPaused;

  Listenable get changes;

  bool get connected;
}

class _Changes extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// [LivePk4RoomMedia] on `livekit_client`.
class LiveKitPk4RoomMedia implements LivePk4RoomMedia {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final _changes = _Changes();
  Set<String> _speaking = const {};
  bool _audioMuted = false;
  bool _videoPaused = false;
  lk.VideoQuality _quality = lk.VideoQuality.LOW;

  @override
  Future<void> join({
    required String url,
    required String token,
    required bool lowLayer,
  }) async {
    if (_room != null) return;
    _quality = lowLayer ? lk.VideoQuality.LOW : lk.VideoQuality.MEDIUM;
    final room = lk.Room(
      // The panes are small: LiveKit also lowers the layer to the view's size.
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    _listener = room.createListener()
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        _speaking = {for (final p in e.speakers) p.identity};
        _changes.ping();
      })
      ..on<lk.TrackPublishedEvent>((e) {
        unawaited(_shape(e.publication));
      })
      ..on<lk.TrackSubscribedEvent>((e) {
        unawaited(_shape(e.publication));
        if (e.track is lk.RemoteAudioTrack && _audioMuted) {
          unawaited(
            e.track.disable().catchError((Object err, StackTrace stack) {
              AppLogger.error('live: PK4 sound not muted', err, stack);
            }),
          );
        }
        _changes.ping();
      })
      ..on<lk.ParticipantConnectedEvent>((_) => _changes.ping())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _changes.ping())
      ..on<lk.TrackUnsubscribedEvent>((_) => _changes.ping())
      ..on<lk.TrackMutedEvent>((_) => _changes.ping())
      ..on<lk.TrackUnmutedEvent>((_) => _changes.ping())
      ..on<lk.RoomDisconnectedEvent>((_) => _changes.ping());
    try {
      await room.connect(url, token);
    } on Object {
      await leave();
      rethrow;
    }
    for (final p in room.remoteParticipants.values) {
      for (final publication in p.videoTrackPublications) {
        await _shape(publication);
      }
    }
    _changes.ping();
  }

  /// The layer and the pause of one video publication.
  Future<void> _shape(lk.RemoteTrackPublication publication) async {
    if (publication.kind != lk.TrackType.VIDEO) return;
    try {
      await publication.setVideoQuality(_quality);
      if (_videoPaused) {
        await publication.disable();
      } else {
        await publication.enable();
      }
    } on Object catch (e, stack) {
      AppLogger.error('live: PK4 video layer not set', e, stack);
    }
  }

  @override
  Future<void> leave() async {
    final room = _room;
    _room = null;
    await _listener?.dispose();
    _listener = null;
    _speaking = const {};
    if (room != null) {
      // D215: LiveKit stops Android's audio session whenever any room
      // disconnects; it is held while this hidden room goes.
      final hold = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
      if (hold) await _holdAudioSession(manual: true);
      try {
        await room.disconnect();
        await room.dispose();
      } finally {
        if (hold) await _holdAudioSession(manual: false);
      }
    }
    _changes.ping();
  }

  // LiveKit's audio session switch is its only public way to keep the
  // session (marked experimental in livekit_client 2.13.1; pinned).
  // ignore_for_file: experimental_member_use
  static Future<void> _holdAudioSession({required bool manual}) async {
    try {
      await lk.AudioManager.instance.setAudioSessionManagementMode(
        manual
            ? lk.AudioSessionManagementMode.manual
            : lk.AudioSessionManagementMode.automatic,
      );
    } on Object catch (e, stack) {
      AppLogger.error('live: PK4 audio session not held', e, stack);
    }
  }

  @override
  Widget? video(String identity) {
    if (_videoPaused) return null;
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
  Set<String> get speaking => _speaking;

  @override
  bool get audioMuted => _audioMuted;

  @override
  Future<void> setAudioMuted({required bool muted}) async {
    _audioMuted = muted;
    for (final p
        in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      for (final publication in p.audioTrackPublications) {
        final track = publication.track;
        if (track == null) continue;
        if (muted) {
          await track.disable();
        } else {
          await track.enable();
        }
      }
    }
    _changes.ping();
  }

  @override
  bool get videoPaused => _videoPaused;

  @override
  Future<void> setVideoPaused({required bool paused}) async {
    if (_videoPaused == paused) return;
    _videoPaused = paused;
    for (final p
        in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      for (final publication in p.videoTrackPublications) {
        await _shape(publication);
      }
    }
    _changes.ping();
  }

  @override
  Listenable get changes => _changes;

  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;
}

/// Makes one other room's connection (tests override it with a fake).
final livePk4RoomMediaFactoryProvider = Provider<LivePk4RoomMedia Function()>(
  (ref) => LiveKitPk4RoomMedia.new,
);
