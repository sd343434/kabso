import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/data/live_pk4_media.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';

/// A host's one-time 4-way PK message.
enum Pk4Notice {
  /// The lobby ran out before all four accepted («لم يكتمل العدد»).
  lobbyExpired,

  /// The organiser cancelled the lobby.
  lobbyCancelled,

  /// An invited host declined, or the invitation ran out.
  declined,
  inviteExpired,

  /// An accepted host left before the start.
  left,

  /// v1.119-live (D395): the 4-way random wait ran out
  /// («لم نجد مضيفين كافيين»).
  queueExpired,
}

/// What a room's screen knows about its 4-way PK (v1.118-live, D391, §10.180).
class LivePk4State {
  const new({
    this.match,
    this.lobby,
    this.incoming,
    this.notice,
    this.announcement,
    this.offset = Duration.zero,
    this.joined = 0,
    this.capped = false,
    this.queue,
  });

  /// The room's open match (CONNECTED, BATTLE or RESULT); null: none.
  final Pk4Match? match;

  /// Host only: the OPEN lobby this host organises or accepted a place in.
  final Pk4Lobby? lobby;

  /// Host only: an invitation to this room, waiting for an answer.
  final Pk4Invite? incoming;

  /// Host only: shown once by the screen, then cleared.
  final Pk4Notice? notice;

  /// «فعّل فريق X تربل ×5!» on the screen now.
  final PkAnnouncement? announcement;

  /// Server clock − device clock.
  final Duration offset;

  /// How many of the other rooms' connections are up.
  final int joined;

  /// PK4_MAX_WATCHERS_PER_ROOM left a room out (its pane shows no video).
  final bool capped;

  /// v1.119-live (D395) host only: the 4-way random wait.
  final Pk4Queue? queue;

  /// Waiting for a 4-way random match now.
  bool get searching {
    final q = queue;
    return q != null && q.expiresAt.isAfter(now());
  }

  DateTime now() => DateTime.now().add(offset);

  LivePk4State copyWith({
    Pk4Match? match,
    bool clearMatch = false,
    Pk4Lobby? lobby,
    bool clearLobby = false,
    Pk4Invite? incoming,
    bool clearIncoming = false,
    Pk4Notice? notice,
    bool clearNotice = false,
    PkAnnouncement? announcement,
    bool clearAnnouncement = false,
    Duration? offset,
    int? joined,
    bool? capped,
    Pk4Queue? queue,
    bool clearQueue = false,
  }) => LivePk4State(
    match: clearMatch ? null : match ?? this.match,
    lobby: clearLobby ? null : lobby ?? this.lobby,
    incoming: clearIncoming ? null : incoming ?? this.incoming,
    notice: clearNotice ? null : notice ?? this.notice,
    announcement: clearAnnouncement ? null : announcement ?? this.announcement,
    offset: offset ?? this.offset,
    joined: joined ?? this.joined,
    capped: capped ?? this.capped,
    queue: clearQueue ? null : queue ?? this.queue,
  );
}

/// The 4-way PK of one room: the snapshot and the `pk4-*` messages (the
/// highest `seq` wins; a gap or a reconnect reads the snapshot again), the
/// three other rooms' watch-only connections while a match is open (lowest
/// layer for viewers, paused while the app is in the background), the team
/// booster announcements, and the host's lobby and actions.
/// Server-authoritative: nothing is counted here.
class LivePk4Controller extends Notifier<LivePk4State> {
  new(this.roomId);

  final String roomId;

  StreamSubscription<Pk4Event>? _events;
  Timer? _refresh;
  Timer? _announcementTimer;
  AppLifecycleListener? _lifecycle;
  final Map<String, LivePk4RoomMedia> _rooms = {};
  bool _isHost = false;
  bool _joining = false;
  bool _paused = false;
  int _serial = 0;

  LivePk4Repository get _repo => ref.read(livePk4RepositoryProvider);

  /// The other rooms' connections (room id → connection).
  Map<String, LivePk4RoomMedia> get rooms => Map.unmodifiable(_rooms);

  @override
  LivePk4State build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _refresh?.cancel();
      _announcementTimer?.cancel();
      _lifecycle?.dispose();
      unawaited(_leaveAll());
    });
    return const LivePk4State();
  }

  /// Starts listening to the room's `pk4-*` messages and reads the snapshot.
  void attach(Stream<Pk4Event> events, {required bool host}) {
    _isHost = host;
    unawaited(_events?.cancel());
    _events = events.listen(_onEvent);
    _refresh?.cancel();
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.match != null || state.lobby != null || _isHost) {
        unawaited(refresh());
      }
    });
    // CP-041 §8: a hidden pane's video is paused (the app in the background).
    _lifecycle ??= AppLifecycleListener(
      onHide: () => unawaited(setVideoPaused(paused: true)),
      onShow: () => unawaited(setVideoPaused(paused: false)),
    );
    unawaited(refresh());
  }

  /// Reads `GET /live/rooms/{roomId}/pk4`.
  Future<void> refresh() async {
    try {
      final snapshot = await _repo.state(roomId);
      if (!ref.mounted) return;
      _applyMatch(snapshot.match);
      if (_isHost) {
        state = state.copyWith(
          lobby: snapshot.lobby,
          clearLobby: snapshot.lobby == null,
          incoming: snapshot.invite,
          clearIncoming: snapshot.invite == null,
          queue: snapshot.queue,
          clearQueue: snapshot.queue == null,
        );
      }
    } on Object {
      // Kept as it was; the next message or refresh repairs it.
    }
  }

  void _onEvent(Pk4Event event) {
    switch (event) {
      case Pk4MatchEvent(
        :final match,
        :final event,
        :final boostTeam,
        :final boostSeat,
      ):
        final current = state.match;
        if (current != null &&
            current.id == match.id &&
            match.seq < current.seq) {
          return;
        }
        // v1.119-live (D395): a «جولة أخرى» replaced the match — a late
        // message of the old one never clears the new battle.
        if (current != null &&
            current.id != match.id &&
            current.open &&
            !match.open) {
          return;
        }
        if (current != null &&
            current.id == match.id &&
            match.seq > current.seq + 1 &&
            event == 'score') {
          unawaited(refresh());
        }
        _applyMatch(match.open ? match : null);
        if (event == 'boost' && boostTeam != null && match.open) {
          _announce(match, boostTeam, seat: boostSeat);
        }
      case Pk4LobbyEvent(:final lobby, :final event):
        if (!_isHost) return;
        final mine =
            lobby.organiserRoomId == roomId ||
            lobby.seats.any(
              (s) => s.roomId == roomId && s.state == Pk4SeatState.accepted,
            );
        state = state.copyWith(
          lobby: lobby.open && mine ? lobby : null,
          clearLobby: !lobby.open || !mine,
          notice: switch (event) {
            'expired' => Pk4Notice.lobbyExpired,
            'cancelled' when lobby.organiserRoomId != roomId =>
              Pk4Notice.lobbyCancelled,
            'declined' when lobby.organiserRoomId == roomId =>
              Pk4Notice.declined,
            'invite-expired' when lobby.organiserRoomId == roomId =>
              Pk4Notice.inviteExpired,
            'left' when lobby.organiserRoomId == roomId => Pk4Notice.left,
            _ => null,
          },
        );
        if (event == 'started') unawaited(refresh());
      case Pk4InviteEvent(:final invite):
        if (!_isHost || invite.toRoomId != roomId) return;
        state = invite.pending
            ? state.copyWith(incoming: invite)
            : state.copyWith(clearIncoming: true);
      case Pk4QueueEvent(:final matched):
        if (!_isHost) return;
        state = state.copyWith(
          clearQueue: true,
          notice: matched ? null : Pk4Notice.queueExpired,
        );
        if (matched) unawaited(refresh());
    }
  }

  void _announce(Pk4Match match, Pk4Team team, {int? seat}) {
    // FREE_FOR_ALL: the host's own booster («فعّل @host …»).
    final own = seat == null
        ? null
        : match.seats.where((s) => s.seat == seat).firstOrNull;
    final boost = own?.boost ?? match.team(team).boost;
    if (boost == null) return;
    final names = own != null
        ? own.host.displayName
        : match.seatsOf(team).map((s) => s.host.displayName).join(' · ');
    _serial += 1;
    state = state.copyWith(
      announcement: PkAnnouncement(
        roomId: own?.roomId ?? match.seatsOf(team).first.roomId,
        teamName: names,
        kind: boost.kind,
        multiplier: boost.multiplier,
        serial: _serial,
      ),
    );
    _announcementTimer?.cancel();
    _announcementTimer = Timer(const Duration(milliseconds: 3200), () {
      if (ref.mounted) state = state.copyWith(clearAnnouncement: true);
    });
  }

  /// Tests and previews: a team booster line.
  void announceForTest(Pk4Match match, Pk4Team team) => _announce(match, team);

  void _applyMatch(Pk4Match? match, {bool replace = false}) {
    final current = state.match;
    if (match != null &&
        !replace &&
        current != null &&
        current.id == match.id &&
        match.seq < current.seq) {
      return;
    }
    if (match == null) {
      state = state.copyWith(clearMatch: true, joined: 0, capped: false);
      unawaited(_leaveAll());
      return;
    }
    state = state.copyWith(
      match: match,
      offset: match.serverTime.difference(DateTime.now()),
      clearLobby: true,
      clearIncoming: true,
      clearQueue: true,
    );
    unawaited(_ensureRooms(match));
  }

  /// The three other rooms' connections (CP-041 §8): opened for CONNECTED,
  /// BATTLE and RESULT; each step guarded (a failure is logged and the next
  /// refresh tries again); this host's mutes applied per room.
  Future<void> _ensureRooms(Pk4Match match) async {
    final mine = match.seatOf(roomId);
    // v1.119-live (D395): a rematch without a host — that room's connection
    // closes.
    for (final gone in [
      for (final r in _rooms.keys)
        if (!match.seats.any((s) => s.roomId == r)) r,
    ]) {
      final media = _rooms.remove(gone);
      if (media != null) await _leave(media);
      state = state.copyWith(joined: _rooms.length);
    }
    for (final entry in [..._rooms.entries]) {
      final muted = mine?.mutedRoomIds.contains(entry.key) ?? false;
      if (entry.value.audioMuted != muted) {
        try {
          await entry.value.setAudioMuted(muted: muted);
        } on Object catch (e, stack) {
          AppLogger.error('live: PK4 sound not switched', e, stack);
        }
      }
    }
    final others = match.seats.where((s) => s.roomId != roomId).length;
    if (_rooms.length >= others || _joining) return;
    _joining = true;
    try {
      final signedIn = ref.read(currentUserProvider) != null;
      final access = await _repo.mediaToken(
        roomId,
        guestId: signedIn ? null : ref.read(liveGuestIdProvider),
      );
      if (!ref.mounted || state.match?.id != match.id) return;
      state = state.copyWith(capped: access.capped);
      for (final room in access.rooms) {
        if (_rooms.containsKey(room.roomId)) continue;
        final media = ref.read(livePk4RoomMediaFactoryProvider)();
        try {
          await media.join(
            url: access.url,
            token: room.token,
            lowLayer: access.lowLayer,
          );
          if (!ref.mounted || state.match?.id != match.id) {
            await _leave(media);
            return;
          }
          await media.setAudioMuted(
            muted: mine?.mutedRoomIds.contains(room.roomId) ?? false,
          );
          if (_paused) await media.setVideoPaused(paused: true);
          _rooms[room.roomId] = media;
          state = state.copyWith(joined: _rooms.length);
        } on Object catch (e, stack) {
          AppLogger.error('live: PK4 room media failed', e, stack);
          await _leave(media);
        }
      }
    } on Object catch (e, stack) {
      AppLogger.error('live: PK4 media token failed', e, stack);
    } finally {
      _joining = false;
    }
  }

  /// Pauses (or resumes) the other rooms' video — a hidden stage.
  Future<void> setVideoPaused({required bool paused}) async {
    _paused = paused;
    for (final media in _rooms.values) {
      try {
        await media.setVideoPaused(paused: paused);
      } on Object catch (e, stack) {
        AppLogger.error('live: PK4 pause not applied', e, stack);
      }
    }
  }

  Future<void> _leaveAll() async {
    final all = [..._rooms.values];
    _rooms.clear();
    for (final media in all) {
      await _leave(media);
    }
  }

  static Future<void> _leave(LivePk4RoomMedia media) async {
    try {
      await media.leave();
    } on Object catch (e, stack) {
      AppLogger.error('live: PK4 room media not left', e, stack);
    }
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  // ---- Host actions (each throws an AppFailure for the screen) ----------

  Future<void> openLobby({
    Pk4Format format = Pk4Format.teams,
    PkType type = PkType.normal,
  }) async {
    state = state.copyWith(
      lobby: await _repo.openLobby(roomId, format: format, type: type),
    );
  }

  /// v1.119-live (D395) «ابدأ الآن»: the organiser starts with the hosts in.
  Future<void> startLobby() async {
    final after = await _repo.startLobby(roomId);
    state = state.copyWith(lobby: after.lobby, clearLobby: after.lobby == null);
    _applyMatch(after.match);
  }

  /// v1.119-live (D395): the 4-way random queue (four hosts only).
  Future<void> joinRandom({
    required Pk4Format format,
    PkType type = PkType.normal,
  }) async {
    final result = await _repo.joinRandom(roomId, format: format, type: type);
    if (result.match case final match?) {
      _applyMatch(match);
    } else {
      state = state.copyWith(
        queue: result.queue,
        clearQueue: result.queue == null,
      );
    }
  }

  Future<void> leaveRandom() async {
    state = state.copyWith(clearQueue: true);
    await _repo.leaveRandom(roomId);
  }

  // v1.119-live (D395) «PK أحكام» and «جولة أخرى» for four.
  Future<void> acceptDare() async =>
      _applyMatch(await _repo.acceptDare(roomId), replace: true);

  Future<void> refuseDare() async =>
      _applyMatch(await _repo.refuseDare(roomId), replace: true);

  Future<void> judgeDare({required bool done}) async =>
      _applyMatch(await _repo.judgeDare(roomId, done: done), replace: true);

  Future<void> reportDare(String dareId) => _repo.reportDare(roomId, dareId);

  Future<void> offerRematch() async =>
      _applyMatch(await _repo.offerRematch(roomId), replace: true);

  Future<void> acceptRematch() async =>
      _applyMatch(await _repo.acceptRematch(roomId), replace: true);

  Future<void> declineRematch() async {
    await _repo.declineRematch(roomId);
    await refresh();
  }

  Future<void> cancelRematch() async =>
      _applyMatch(await _repo.cancelRematch(roomId), replace: true);

  /// The organiser cancels the lobby, or an accepted host leaves it.
  Future<void> closeLobby() async {
    state = state.copyWith(clearLobby: true);
    await _repo.closeLobby(roomId);
  }

  Future<void> invite(String toRoomId, int seat) async {
    state = state.copyWith(
      lobby: await _repo.invite(roomId, toRoomId: toRoomId, seat: seat),
    );
  }

  Future<void> cancelInvite(String inviteId) async {
    await _repo.cancelInvite(roomId, inviteId);
    await refresh();
  }

  Future<void> accept() async {
    final invite = state.incoming;
    if (invite == null) return;
    state = state.copyWith(clearIncoming: true);
    final after = await _repo.accept(roomId, invite.id);
    state = state.copyWith(lobby: after.lobby, clearLobby: after.lobby == null);
    _applyMatch(after.match);
  }

  Future<void> decline() async {
    final invite = state.incoming;
    if (invite == null) return;
    state = state.copyWith(clearIncoming: true);
    await _repo.decline(roomId, invite.id);
  }

  Future<void> start() async {
    _applyMatch(await _repo.start(roomId), replace: true);
  }

  /// Leaves the battle (the teammate carries on); closes the result after it.
  Future<void> end() async {
    final match = await _repo.end(roomId);
    _applyMatch(match.open ? match : null, replace: true);
  }

  Future<void> setMuted(String otherRoomId, {required bool muted}) async {
    _applyMatch(
      await _repo.mute(roomId, otherRoomId: otherRoomId, muted: muted),
      replace: true,
    );
  }

  /// Tests: a match / a lobby / an invitation as if the snapshot had it.
  void debugSetMatch(Pk4Match? match) => _applyMatch(match, replace: true);

  void debugSetLobby(Pk4Lobby? lobby) =>
      state = state.copyWith(lobby: lobby, clearLobby: lobby == null);

  void debugSetIncoming(Pk4Invite? invite) =>
      state = state.copyWith(incoming: invite, clearIncoming: invite == null);

  void debugSetQueue(Pk4Queue? queue) =>
      state = state.copyWith(queue: queue, clearQueue: queue == null);
}

final NotifierProviderFamily<LivePk4Controller, LivePk4State, String>
livePk4Provider = NotifierProvider.autoDispose
    .family<LivePk4Controller, LivePk4State, String>(LivePk4Controller.new);

/// The gift panel's booster tab reads a [PkMatch]: the room's 1 v 1 match,
/// else its 4-way battle seen from its team (v1.118-live, D391).
PkMatch? pkMatchForGifts(WidgetRef ref, String roomId) =>
    ref.watch(livePkProvider(roomId)).match ??
    ref.watch(livePk4Provider(roomId)).match?.boosterView(roomId);
