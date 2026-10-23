import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
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
    this.disconnected = false,
  });

  /// The media session dropped after joining (the host ended the live,
  /// or the network): the screen re-reads the room to show why.
  final bool disconnected;

  /// CP-012: the room score from this viewer's last counted tap batch.
  final int? score;

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
    bool? disconnected,
  }) => LiveRoomSessionState(
    joined: joined ?? this.joined,
    joinFailure: joinFailure ?? this.joinFailure,
    seats: seats ?? this.seats,
    publishing: publishing ?? this.publishing,
    captureFailed: captureFailed ?? this.captureFailed,
    score: score ?? this.score,
    disconnected: disconnected ?? this.disconnected,
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
  Timer? _tapFlush;
  int _pendingTaps = 0;
  StreamSubscription<String>? _invites;
  bool _refreshing = false;
  bool _syncing = false;

  LiveMediaEngine get engine => _engine;

  @override
  LiveRoomSessionState build() {
    _engine = ref.read(liveMediaEngineProvider)();
    _repo = ref.read(liveRepositoryProvider);
    _engine.changes.addListener(_onChanges);
    _invites = _engine.seatInvites.listen((id) {
      if (id == roomId) unawaited(refreshSeats());
    });
    ref.onDispose(() {
      _poll?.cancel();
      _tapFlush?.cancel();
      unawaited(_invites?.cancel());
      _engine.changes.removeListener(_onChanges);
      unawaited(_engine.stop().then((_) {}, onError: (_) {}));
    });
    return const LiveRoomSessionState();
  }

  /// CP-012: one tap to cheer the host. Taps are sent in batches, at most
  /// one request a second and 50 taps a batch; the server counts at most 10
  /// a second and 10 000 a live and answers with the room's score.
  void tap() {
    _pendingTaps++;
    _tapFlush ??= Timer(const Duration(seconds: 1), _flushTaps);
  }

  Future<void> _flushTaps() async {
    _tapFlush = null;
    final count = _pendingTaps < 50 ? _pendingTaps : 50;
    if (count == 0) return;
    _pendingTaps -= count;
    try {
      final result = await _repo.tap(roomId, count);
      if (ref.mounted) state = state.copyWith(score: result.score.total);
    } on Object {
      // Best effort: a lost batch only loses points, never the room.
    }
    if (ref.mounted && _pendingTaps > 0) {
      _tapFlush ??= Timer(const Duration(seconds: 1), _flushTaps);
    }
  }

  /// Joins the media session of [room] (once).
  Future<void> start(LiveRoom room) async {
    if (state.joined || room.status != LiveRoomStatus.live) return;
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
      if (_mode.hasSeats) {
        await refreshSeats();
        _poll = Timer.periodic(
          const Duration(seconds: 10),
          (_) => unawaited(refreshSeats()),
        );
      }
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(joinFailure: toAppFailure(e));
    }
  }

  void _onChanges() {
    if (state.joined && !state.disconnected && !_engine.connected) {
      state = state.copyWith(disconnected: true);
      return;
    }
    final version = _engine.seatsVersion;
    final seats = state.seats;
    if (_mode.hasSeats &&
        version != null &&
        (seats == null || version > seats.version)) {
      unawaited(refreshSeats());
    } else {
      unawaited(_syncPublishing());
    }
  }

  /// `GET /live/rooms/{roomId}/seats`; failures keep the last seats.
  Future<void> refreshSeats() async {
    if (_refreshing || !_mode.hasSeats) return;
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
          await _engine.publishLocal(video: _mode == LiveRoomMode.multi);
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
    await _repo.requestSeat(roomId, seatIndex: seatIndex);
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
