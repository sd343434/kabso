import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

/// v1.43-live (D195, CONVENTIONS §10.58 media design): the OTHER room of a PK
/// — a second, subscribe-only, hidden connection to the opponent's media
/// session (`createLivePkMediaToken`). Viewers and the host of this room see
/// and hear the opponent host (and their guests) through it; nothing is
/// published and the other room's data messages are ignored (each room keeps
/// its own chat, gifts and seats).
abstract interface class LivePkOpponentMedia {
  /// Connects with the watch-only [access] (once; a second call is ignored).
  Future<void> join(PkMediaAccess access);

  /// Disconnects (idempotent).
  Future<void> leave();

  /// The video of [identity] in the other room (the host or a guest), or
  /// null while there is none (not connected, camera off).
  Widget? video(String identity);

  bool isPresent(String identity);

  /// The identities speaking now in the other room.
  Set<String> get speaking;

  /// The host's «mute opponent» in this room: the other room's sound off.
  Future<void> setAudioMuted({required bool muted});

  bool get audioMuted;

  Listenable get changes;

  bool get connected;
}

class _Changes extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// [LivePkOpponentMedia] on `livekit_client`.
class LiveKitPkOpponentMedia implements LivePkOpponentMedia {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final _changes = _Changes();
  Set<String> _speaking = const {};
  bool _audioMuted = false;

  @override
  Future<void> join(PkMediaAccess access) async {
    if (_room != null) return;
    final room = lk.Room();
    _room = room;
    _listener = room.createListener()
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        _speaking = {for (final p in e.speakers) p.identity};
        _changes.ping();
      })
      ..on<lk.TrackSubscribedEvent>((e) {
        if (e.track is lk.RemoteAudioTrack && _audioMuted) {
          unawaited(
            e.track.disable().catchError((Object err, StackTrace stack) {
              AppLogger.error('live: PK opponent sound not muted', err, stack);
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
      await room.connect(access.url, access.token);
    } on Object {
      // D215: a connection that failed is released at once (the caller
      // logs it and tries again later with a new one).
      await leave();
      rethrow;
    }
    _changes.ping();
  }

  @override
  Future<void> leave() async {
    final room = _room;
    _room = null;
    await _listener?.dispose();
    _listener = null;
    _speaking = const {};
    if (room != null) {
      // D215: LiveKit stops Android's audio session (mode, focus, routing)
      // whenever ANY room disconnects — also this hidden one, while the
      // live's own room still sends the host's voice. The session is held
      // while this room goes and handed back to LiveKit after, which
      // applies it again for the live's room.
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
      AppLogger.error('live: PK audio session not held', e, stack);
    }
  }

  @override
  Widget? video(String identity) {
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
  Listenable get changes => _changes;

  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;
}

/// Makes the other room's connection (tests override it with a fake).
final livePkOpponentMediaFactoryProvider =
    Provider<LivePkOpponentMedia Function()>(
      (ref) => LiveKitPkOpponentMedia.new,
    );
