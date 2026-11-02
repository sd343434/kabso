import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/data/live_pk_media.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';

/// A booster that just started: «فعّل فريق X تربل ×5!» in both rooms.
class PkAnnouncement {
  const new({
    required this.roomId,
    required this.teamName,
    required this.kind,
    required this.multiplier,
    required this.serial,
  });

  /// The side's room (own side or the opponent's).
  final String roomId;

  /// The side's host name (the team).
  final String teamName;
  final PkBoosterKind kind;
  final int multiplier;

  /// Grows with every announcement (a new one restarts the banner).
  final int serial;
}

/// What a room's screen knows about its PK (v1.43-live, D195, §10.58).
class LivePkState {
  const new({
    this.match,
    this.incoming,
    this.outgoing,
    this.queueUntil,
    this.announcement,
    this.notice,
    this.offset = Duration.zero,
    this.opponentJoined = false,
  });

  /// The room's BATTLE or RESULT match (null: no PK; the solo live).
  final PkMatch? match;

  /// Host only: an invitation for this room, waiting for an answer.
  final PkInvite? incoming;

  /// Host only: this room's open invitation to another host.
  final PkInvite? outgoing;

  /// Host only: waiting in the random queue until.
  final DateTime? queueUntil;

  /// The booster line on the screen now.
  final PkAnnouncement? announcement;

  /// Host only: what happened to an invitation or the queue (declined,
  /// expired …) — shown once by the screen, then cleared.
  final PkNotice? notice;

  /// Server clock − device clock (countdowns follow the server).
  final Duration offset;

  /// The other room's connection is up.
  final bool opponentJoined;

  DateTime now() => DateTime.now().add(offset);

  LivePkState copyWith({
    PkMatch? match,
    bool clearMatch = false,
    PkInvite? incoming,
    bool clearIncoming = false,
    PkInvite? outgoing,
    bool clearOutgoing = false,
    DateTime? queueUntil,
    bool clearQueue = false,
    PkAnnouncement? announcement,
    bool clearAnnouncement = false,
    PkNotice? notice,
    bool clearNotice = false,
    Duration? offset,
    bool? opponentJoined,
  }) => LivePkState(
    match: clearMatch ? null : match ?? this.match,
    incoming: clearIncoming ? null : incoming ?? this.incoming,
    outgoing: clearOutgoing ? null : outgoing ?? this.outgoing,
    queueUntil: clearQueue ? null : queueUntil ?? this.queueUntil,
    announcement: clearAnnouncement ? null : announcement ?? this.announcement,
    notice: clearNotice ? null : notice ?? this.notice,
    offset: offset ?? this.offset,
    opponentJoined: opponentJoined ?? this.opponentJoined,
  );
}

/// A host's one-time PK message.
enum PkNotice { declined, expired, cancelled, queueExpired, unavailable }

/// The PK of one room: the server's match from the snapshot and the `pk`
/// data messages (the highest `seq` wins; a gap or a reconnect reads the
/// snapshot again), the other room's watch-only connection while a match
/// is open, the booster announcements, and the host's actions (invite,
/// accept / decline, random, end, mute). Server-authoritative: nothing is
/// counted here.
class LivePkController extends Notifier<LivePkState> {
  new(this.roomId);

  final String roomId;

  StreamSubscription<PkEvent>? _events;
  Timer? _refresh;
  Timer? _announcementTimer;
  LivePkOpponentMedia? _opponent;
  bool _isHost = false;
  int _serial = 0;
  bool _joining = false;

  LivePkRepository get _repo => ref.read(livePkRepositoryProvider);

  /// The other room's connection (null: no PK).
  LivePkOpponentMedia? get opponent => _opponent;

  @override
  LivePkState build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _refresh?.cancel();
      _announcementTimer?.cancel();
      final opponent = _opponent;
      _opponent = null;
      unawaited(_leave(opponent));
    });
    return const LivePkState();
  }

  /// Starts listening to the room's `pk` data messages and reads the
  /// snapshot. [host]: this device is the room's host.
  void attach(Stream<PkEvent> events, {required bool host}) {
    _isHost = host;
    unawaited(_events?.cancel());
    _events = events.listen(_onEvent);
    _refresh?.cancel();
    // A missed message or a reconnect is repaired by the snapshot.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.match != null || state.outgoing != null || _isHost) {
        unawaited(refresh());
      }
    });
    unawaited(refresh());
  }

  /// Reads `GET /live/rooms/{roomId}/pk` (after joining, a reconnect, a gap).
  Future<void> refresh() async {
    try {
      final snapshot = await _repo.state(roomId);
      if (!ref.mounted) return;
      // An older snapshot never replaces a newer message of the same match.
      _applyMatch(snapshot.match);
      if (_isHost) {
        final invite = snapshot.invite;
        state = state.copyWith(
          incoming: invite != null && invite.toRoomId == roomId ? invite : null,
          clearIncoming: invite == null || invite.toRoomId != roomId,
          outgoing: invite != null && invite.fromRoomId == roomId
              ? invite
              : null,
          clearOutgoing: invite == null || invite.fromRoomId != roomId,
          queueUntil: snapshot.queueUntil,
          clearQueue: snapshot.queueUntil == null,
        );
      }
    } on Object {
      // Kept as it was; the next message or refresh repairs it.
    }
  }

  void _onEvent(PkEvent event) {
    switch (event) {
      case PkMatchEvent(:final match, :final event, :final boostKind):
        final current = state.match;
        if (current != null &&
            current.id == match.id &&
            match.seq < current.seq) {
          return;
        }
        if (current != null &&
            current.id == match.id &&
            match.seq > current.seq + 1 &&
            event == 'score') {
          // A gap: keep this one and read the snapshot too.
          unawaited(refresh());
        }
        _applyMatch(match.open ? match : null);
        if (event == 'boost' && boostKind != null && match.open) {
          _announce(
            match,
            event: (boostKind, roomId: _boostRoom(match, boostKind)),
          );
        }
      case PkInviteEvent(:final invite):
        if (!_isHost) return;
        if (invite.toRoomId == roomId) {
          state = invite.pending
              ? state.copyWith(incoming: invite)
              : state.copyWith(clearIncoming: true);
        } else if (invite.fromRoomId == roomId) {
          state = state.copyWith(
            outgoing: invite.pending ? invite : null,
            clearOutgoing: !invite.pending,
            notice: switch (invite.status) {
              'DECLINED' => PkNotice.declined,
              'EXPIRED' => PkNotice.expired,
              _ => null,
            },
          );
        }
      case PkQueueExpired():
        state = state.copyWith(clearQueue: true, notice: PkNotice.queueExpired);
    }
  }

  /// The room whose booster [kind] is the newest active one.
  String _boostRoom(PkMatch match, PkBoosterKind kind) {
    final (a, b) = match.sides;
    if (b.boost?.kind == kind && a.boost?.kind != kind) return b.roomId;
    if (a.boost?.kind == kind && b.boost?.kind != kind) return a.roomId;
    final at = a.boost?.endsAt;
    final bt = b.boost?.endsAt;
    if (at != null && bt != null) return bt.isAfter(at) ? b.roomId : a.roomId;
    return a.roomId;
  }

  void _announce(
    PkMatch match, {
    required (PkBoosterKind, {String roomId}) event,
  }) {
    final (kind, :roomId) = event;
    final side = match.sides.$1.roomId == roomId
        ? match.sides.$1
        : match.sides.$2;
    _serial += 1;
    state = state.copyWith(
      announcement: PkAnnouncement(
        roomId: roomId,
        teamName: side.host.displayName,
        kind: kind,
        multiplier: match.rule(kind)?.multiplier ?? side.boost?.multiplier ?? 2,
        serial: _serial,
      ),
    );
    _announcementTimer?.cancel();
    _announcementTimer = Timer(const Duration(milliseconds: 3200), () {
      if (ref.mounted) state = state.copyWith(clearAnnouncement: true);
    });
  }

  /// Shows a booster line (tests and the screens' previews use it too).
  void announceForTest(PkMatch match, PkBoosterKind kind, String sideRoomId) =>
      _announce(match, event: (kind, roomId: sideRoomId));

  void _applyMatch(PkMatch? match, {bool replace = false}) {
    final current = state.match;
    if (match != null &&
        !replace &&
        current != null &&
        current.id == match.id &&
        match.seq < current.seq) {
      return;
    }
    if (match == null) {
      state = state.copyWith(clearMatch: true, opponentJoined: false);
      final opponent = _opponent;
      _opponent = null;
      unawaited(_leave(opponent));
      return;
    }
    state = state.copyWith(
      match: match,
      offset: match.serverTime.difference(DateTime.now()),
      clearQueue: true,
      clearOutgoing: true,
      clearIncoming: true,
    );
    unawaited(_ensureOpponent(match));
  }

  /// The other room's watch-only connection (D195). D215 (owner: the app
  /// closed when a random PK started): every step is guarded — a failure is
  /// logged, the half-made connection is left (it was kept for ever before,
  /// so it was never tried again), the panes show the host's picture, and
  /// the next refresh (15 s) tries again. A match that ended (or another
  /// one that started) while connecting gets no connection.
  Future<void> _ensureOpponent(PkMatch match) async {
    final (own, _) = match.of(roomId);
    final opponent = _opponent;
    if (opponent != null) {
      if (opponent.audioMuted != own.mutesOpponent) {
        try {
          await opponent.setAudioMuted(muted: own.mutesOpponent);
        } on Object catch (e, stack) {
          AppLogger.error('live: PK opponent sound not switched', e, stack);
        }
      }
      return;
    }
    if (_joining) return;
    _joining = true;
    LivePkOpponentMedia? media;
    var step = 'token';
    try {
      final signedIn = ref.read(currentUserProvider) != null;
      final access = await _repo.mediaToken(
        roomId,
        guestId: signedIn ? null : ref.read(liveGuestIdProvider),
      );
      if (!ref.mounted || state.match?.id != match.id) return;
      step = 'join';
      media = ref.read(livePkOpponentMediaFactoryProvider)();
      await media.join(access);
      if (!ref.mounted || state.match?.id != match.id) {
        final late = media;
        media = null;
        await _leave(late);
        return;
      }
      step = 'sound';
      await media.setAudioMuted(muted: own.mutesOpponent);
      _opponent = media;
      media = null;
      state = state.copyWith(opponentJoined: true);
    } on Object catch (e, stack) {
      // The panes show the host's picture; the next refresh tries again.
      AppLogger.error('live: PK opponent media failed at $step', e, stack);
      final broken = media;
      media = null;
      await _leave(broken);
    } finally {
      _joining = false;
    }
  }

  /// Leaves the other room's connection; a failure is logged, never thrown
  /// into the room (D215).
  static Future<void> _leave(LivePkOpponentMedia? media) async {
    if (media == null) return;
    try {
      await media.leave();
    } on Object catch (e, stack) {
      AppLogger.error('live: PK opponent media not left', e, stack);
    }
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  // ---- Host actions (each throws an AppFailure for the screen) ----------

  Future<PkInvite> invite(
    String toRoomId, {
    PkType type = PkType.normal,
  }) async {
    final invite = await _repo.invite(roomId, toRoomId: toRoomId, type: type);
    state = state.copyWith(outgoing: invite);
    return invite;
  }

  Future<void> cancelInvite() async {
    final invite = state.outgoing;
    if (invite == null) return;
    state = state.copyWith(clearOutgoing: true);
    await _repo.cancelInvite(roomId, invite.id);
  }

  Future<void> accept() async {
    final invite = state.incoming;
    if (invite == null) return;
    state = state.copyWith(clearIncoming: true);
    _applyMatch(await _repo.accept(roomId, invite.id));
  }

  Future<void> decline() async {
    final invite = state.incoming;
    if (invite == null) return;
    state = state.copyWith(clearIncoming: true);
    await _repo.decline(roomId, invite.id);
  }

  Future<void> joinRandom({PkType type = PkType.normal}) async {
    final result = await _repo.joinRandom(roomId, type: type);
    if (result.match case final match?) {
      _applyMatch(match);
    } else {
      state = state.copyWith(queueUntil: result.waitingUntil);
    }
  }

  Future<void> leaveRandom() async {
    state = state.copyWith(clearQueue: true);
    await _repo.leaveRandom(roomId);
  }

  /// A forfeit during the battle; closes the result phase after it.
  Future<void> end() async {
    final match = await _repo.end(roomId);
    _applyMatch(match.open ? match : null, replace: true);
  }

  /// v1.44-live (D199): either host starts a CONNECTED PK.
  Future<void> start() async {
    _applyMatch(await _repo.start(roomId), replace: true);
  }

  Future<void> setMuteOpponent({required bool muted}) async {
    _applyMatch(await _repo.muteOpponent(roomId, muted: muted), replace: true);
  }

  Future<bool> setInvitesEnabled({required bool enabled}) =>
      _repo.setInvitesEnabled(enabled: enabled);

  // ---- v1.50-live (D229): «PK أحكام» ---------------------------------------

  /// The losing host accepts the drawn dare («قبول»): the 3-minute timer.
  Future<void> acceptDare() async {
    _applyMatch(await _repo.acceptDare(roomId), replace: true);
  }

  /// The losing host refuses it («رفض»: −3 PK points).
  Future<void> refuseDare() async {
    _applyMatch(await _repo.refuseDare(roomId), replace: true);
  }

  /// The winning host's verdict during the timer («نُفّذ» / «لم يُنفّذ»).
  Future<void> judgeDare({required bool done}) async {
    _applyMatch(await _repo.judgeDare(roomId, done: done), replace: true);
  }

  /// ⚠️ a dare on the banner (viewers and hosts).
  Future<void> reportDare(String dareId) => _repo.reportDare(roomId, dareId);

  /// Tests: puts a match in place as if the snapshot had it.
  void debugSetMatch(PkMatch? match) => _applyMatch(match, replace: true);
}

final NotifierProviderFamily<LivePkController, LivePkState, String>
livePkProvider = NotifierProvider.autoDispose
    .family<LivePkController, LivePkState, String>(LivePkController.new);
