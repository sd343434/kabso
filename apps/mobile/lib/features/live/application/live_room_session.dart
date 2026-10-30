import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_tap_batcher.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// What a viewer's room session knows (CP-010 video, CP-011 seats).
class LiveRoomSessionState {
  const new({
    this.joined = false,
    this.joinFailure,
    this.seats,
    this.publishing = false,
    this.captureFailed = false,
    this.score,
    this.scoreParts,
    this.disconnected = false,
    this.room,
    this.kicked = false,
  });

  /// v1.20-live (D105, §10.20): the host or a moderator kicked this person
  /// out of the live (`LiveRoom.kicked`, the kick data message naming them,
  /// the media server's "participant removed", or `LIVE_KICKED`). The
  /// session has left; the screen says why.
  final bool kicked;

  /// CP-014: the room read again after its title, category or topic
  /// changed (`roomInfoVersion`); the screen shows it over the one it
  /// opened with.
  final LiveRoom? room;

  /// The media session dropped after joining (the host ended the live,
  /// or the network): the screen re-reads the room to show why.
  final bool disconnected;

  /// CP-012: the room score from this viewer's last counted tap batch.
  final int? score;

  /// D131: the parts of that score (its `tapPoints` is the live's taps).
  final LiveScore? scoreParts;

  /// Connected to the room's media session.
  final bool joined;

  /// Why joining failed (ended room, guests off, network …).
  final AppFailure? joinFailure;

  /// The seats of a MULTI or AUDIO room (refetched when they move).
  final LiveSeats? seats;

  /// Publishing the local camera / microphone (seated).
  final bool publishing;

  /// Seated, but the camera or microphone could not start.
  final bool captureFailed;

  LiveSeatsMine? get mine => seats?.mine;

  bool get seated => mine?.seatIndex != null;

  bool get canModerate =>
      mine?.role == LiveSeatRole.host || mine?.role == LiveSeatRole.moderator;

  LiveRoomSessionState copyWith({
    bool? joined,
    AppFailure? joinFailure,
    LiveSeats? seats,
    bool? publishing,
    bool? captureFailed,
    int? score,
    LiveScore? scoreParts,
    bool? disconnected,
    LiveRoom? room,
    bool? kicked,
  }) => LiveRoomSessionState(
    joined: joined ?? this.joined,
    joinFailure: joinFailure ?? this.joinFailure,
    seats: seats ?? this.seats,
    publishing: publishing ?? this.publishing,
    captureFailed: captureFailed ?? this.captureFailed,
    score: score ?? this.score,
    scoreParts: scoreParts ?? this.scoreParts,
    disconnected: disconnected ?? this.disconnected,
    room: room ?? this.room,
    kicked: kicked ?? this.kicked,
  );
}

/// A random id for this app run: guests (no account) watch with it, so the
/// host sees the same "Guest 1234" while they stay (CP-010).
final Provider<String> liveGuestIdProvider = Provider<String>((_) {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  // A version-4 UUID.
  final variant = (8 + r.nextInt(4)).toRadixString(16);
  return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
});

/// The viewer's side of a LIVE room: joins its media session, keeps the
/// seats of MULTI and AUDIO rooms up to date (the media room's
/// `seatsVersion`, then a 10-second fallback), handles asking for a seat,
/// invitations and leaving, and publishes the camera / microphone while
/// seated (CP-011). Leaving the room screen disconnects and turns them off.
class LiveRoomSession extends Notifier<LiveRoomSessionState> {
  new(this.roomId);

  final String roomId;

  late LiveMediaEngine _engine;
  late LiveRepository _repo;
  LiveRoomMode _mode = LiveRoomMode.solo;
  Timer? _poll;
  LiveTapBatcher? _taps;
  StreamSubscription<String>? _invites;
  StreamSubscription<LiveChatEvent>? _kicks;
  bool _refreshing = false;
  bool _syncing = false;
  int? _infoSeen;
  late LiveBackgroundKeeper _keeper;
  LiveBackgroundTexts? _background;
  VoidCallback? _onLeave;

  LiveMediaEngine get engine => _engine;

  @override
  LiveRoomSessionState build() {
    _engine = ref.read(liveMediaEngineProvider)();
    _repo = ref.read(liveRepositoryProvider);
    _keeper = ref.read(liveBackgroundKeeperProvider);
    listenSelf((_, _) => _syncBackground());
    _engine.changes.addListener(_onChanges);
    _invites = _engine.seatInvites.listen((id) {
      if (id == roomId) unawaited(refreshSeats());
    });
    _kicks = _engine.chatEvents.listen((event) {
      if (event is! LiveKickReceived) return;
      if (event.user.id == ref.read(currentUserProvider)?.id) {
        markKicked();
      } else {
        // Someone else left: their seat and lists change.
        unawaited(refreshSeats());
      }
    });
    ref.onDispose(() {
      _keeper.release(this);
      _poll?.cancel();
      _taps?.close();
      unawaited(_invites?.cancel());
      unawaited(_kicks?.cancel());
      _engine.changes.removeListener(_onChanges);
      unawaited(_engine.stop().then((_) {}, onError: (_) {}));
    });
    return const LiveRoomSessionState();
  }

  /// CP-012: one tap to cheer the host. Taps are sent in batches, at most
  /// one request a second and 50 taps a batch ([LiveTapBatcher]); the server
  /// counts at most 10 a second and 10 000 a live and answers with the
  /// room's score.
  void tap() => (_taps ??= LiveTapBatcher(
    send: (count) => _repo.tap(roomId, count),
    onScore: (score) {
      if (ref.mounted) {
        state = state.copyWith(score: score.total, scoreParts: score);
      }
    },
    // Best effort: a lost batch only loses points, never the room.
    onError: (e) {
      if (toAppFailure(e).code == ErrorCode.liveKicked) markKicked();
    },
  )).tap();

  /// Joins the media session of [room] (once).
  ///
  /// D123: with [background], a seated guest (and a listener of an audio
  /// room) keeps the live running while the app is in the background; the
  /// notification's Leave leaves the seat, or calls [onLeave] (the screen
  /// leaves the room) for a listener.
  Future<void> start(
    LiveRoom room, {
    LiveBackgroundTexts? background,
    VoidCallback? onLeave,
  }) async {
    _background = background;
    _onLeave = onLeave;
    if (state.joined || room.status != LiveRoomStatus.live) return;
    if (room.kicked || state.kicked) {
      if (!state.kicked) state = state.copyWith(kicked: true);
      return;
    }
    _mode = room.mode;
    try {
      final user = ref.read(currentUserProvider);
      final access = await _repo.mediaToken(
        roomId,
        guestId: user == null ? ref.read(liveGuestIdProvider) : null,
      );
      await _engine.join(access);
      if (!ref.mounted) return;
      state = state.copyWith(joined: true);
      if (_mode.hasGuestSeats) {
        await refreshSeats();
        _poll = Timer.periodic(
          const Duration(seconds: 10),
          (_) => unawaited(refreshSeats()),
        );
      }
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (failure.code == ErrorCode.liveKicked) {
        markKicked();
      } else if (ref.mounted) {
        state = state.copyWith(joinFailure: failure);
      }
    }
  }

  /// D123: who this session is for the background service — a seated
  /// guest publishing, a listener of an audio room, or nobody (released).
  void _syncBackground() {
    final texts = _background;
    if (!ref.mounted || texts == null) return;
    final s = state;
    final LiveBackgroundRole? role;
    if (!s.joined || s.kicked || s.disconnected) {
      role = null;
    } else if (s.seated && s.publishing) {
      role = LiveBackgroundRole.guest;
    } else if (_mode == LiveRoomMode.audio) {
      role = LiveBackgroundRole.listener;
    } else {
      role = null;
    }
    if (role == null) {
      _keeper.release(this);
      return;
    }
    final video =
        role == LiveBackgroundRole.guest && _mode == LiveRoomMode.multi;
    _keeper.hold(
      this,
      LiveBackgroundSpec.of(role, texts),
      onEnd: role == LiveBackgroundRole.guest
          ? () => unawaited(leaveSeat().then((_) {}, onError: (_) {}))
          : () => _onLeave?.call(),
      onBackground: video ? () => unawaited(_pauseVideo(paused: true)) : null,
      onForeground: video ? () => unawaited(_pauseVideo(paused: false)) : null,
    );
  }

  Future<void> _pauseVideo({required bool paused}) async {
    try {
      await _engine.setVideoPaused(paused: paused);
    } on Object {
      // Best effort.
    }
  }

  /// v1.20-live: this person was kicked out of the live. Leaves the media
  /// session (camera and microphone off) once; the screen says why.
  void markKicked() {
    if (!ref.mounted || state.kicked) return;
    state = state.copyWith(kicked: true, publishing: false);
    _poll?.cancel();
    _taps?.close();
    unawaited(_engine.stop().then((_) {}, onError: (_) {}));
  }

  void _onChanges() {
    if (state.kicked) return;
    if (_engine.removed) {
      // The media server removed this participant: a kick (§10.20).
      markKicked();
      return;
    }
    if (state.joined && !state.disconnected && !_engine.connected) {
      state = state.copyWith(disconnected: true);
      return;
    }
    _watchRoomInfo();
    final version = _engine.seatsVersion;
    final seats = state.seats;
    if (_mode.hasGuestSeats &&
        version != null &&
        (seats == null || version > seats.version)) {
      unawaited(refreshSeats());
    } else {
      unawaited(_syncPublishing());
    }
  }

  /// Re-reads the room when the media room's `roomInfoVersion` moves (the
  /// first one seen too: the room may have changed since it was opened).
  void _watchRoomInfo() {
    final v = _engine.roomInfoVersion;
    final seen = _infoSeen;
    if (v == null || (seen != null && v <= seen)) return;
    _infoSeen = v;
    unawaited(_refreshRoom());
  }

  /// Failures keep the room as it is; the next version tries again.
  Future<void> _refreshRoom() async {
    try {
      final room = await _repo.getRoom(roomId);
      if (ref.mounted) state = state.copyWith(room: room);
    } on Object {
      // Kept.
    }
  }

  /// `GET /live/rooms/{roomId}/seats`; failures keep the last seats.
  Future<void> refreshSeats() async {
    if (_refreshing || !_mode.hasGuestSeats) return;
    _refreshing = true;
    try {
      final seats = await _repo.seats(roomId);
      if (!ref.mounted) return;
      _apply(seats);
    } on Object {
      // Kept; the next change or the fallback timer tries again.
    } finally {
      _refreshing = false;
    }
  }

  void _apply(LiveSeats seats) {
    state = state.copyWith(seats: seats);
    unawaited(_syncPublishing());
  }

  /// Publishes while seated and allowed by the media server; stops off the
  /// seat.
  Future<void> _syncPublishing() async {
    if (_syncing || !ref.mounted) return;
    _syncing = true;
    try {
      final want = state.seated && _engine.canPublish;
      if (want && !state.publishing && !state.captureFailed) {
        try {
          // D174: a SOLO live's guests are on camera too.
          await _engine.publishLocal(video: _mode != LiveRoomMode.audio);
          if (ref.mounted) state = state.copyWith(publishing: true);
        } on LiveCaptureException {
          if (ref.mounted) state = state.copyWith(captureFailed: true);
        }
      } else if (!state.seated && state.publishing) {
        await _engine.unpublishLocal();
        if (ref.mounted) {
          state = state.copyWith(publishing: false, captureFailed: false);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  // ---- the viewer's seat actions (each throws an AppFailure) ----------

  Future<void> requestSeat({int? seatIndex}) async {
    try {
      await _repo.requestSeat(roomId, seatIndex: seatIndex);
    } on AppFailure catch (e) {
      if (e.code == ErrorCode.liveKicked) markKicked();
      rethrow;
    }
    await refreshSeats();
  }

  Future<void> cancelRequest() async {
    await _repo.cancelSeatRequest(roomId);
    await refreshSeats();
  }

  Future<void> acceptInvite() async =>
      _apply(await _repo.acceptSeatInvite(roomId));

  Future<void> declineInvite() async {
    await _repo.declineSeatInvite(roomId);
    await refreshSeats();
  }

  Future<void> leaveSeat() async {
    await _repo.leaveSeat(roomId);
    await refreshSeats();
  }

  // ---- host and moderators ---------------------------------------------

  Future<void> accept(LiveSeatRequest request, {int? seatIndex}) async =>
      _apply(
        await _repo.acceptSeatRequest(roomId, request.id, seatIndex: seatIndex),
      );

  Future<void> decline(LiveSeatRequest request) async {
    await _repo.declineSeatRequest(roomId, request.id);
    await refreshSeats();
  }

  Future<void> invite(String username, {int? seatIndex}) async {
    await _repo.inviteToSeat(roomId, username, seatIndex: seatIndex);
    await refreshSeats();
  }

  Future<void> mute(int index, {required bool muted}) async =>
      _apply(await _repo.muteSeat(roomId, index, muted: muted));

  Future<void> remove(int index) async =>
      _apply(await _repo.removeFromSeat(roomId, index));

  Future<void> lock(int index, {required bool locked}) async =>
      _apply(await _repo.lockSeat(roomId, index, locked: locked));

  Future<void> addModerator(String username) async =>
      _apply(await _repo.addModerator(roomId, username));

  Future<void> removeModerator(String username) async =>
      _apply(await _repo.removeModerator(roomId, username));
}

final NotifierProviderFamily<LiveRoomSession, LiveRoomSessionState, String>
liveRoomSessionProvider = NotifierProvider.autoDispose
    .family<LiveRoomSession, LiveRoomSessionState, String>(LiveRoomSession.new);
