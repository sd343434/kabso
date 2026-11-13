import 'package:flutter/foundation.dart' show immutable;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';

/// v1.118-live (D391, CONVENTIONS §10.180, CP-041 phase 2) «PK رباعي»: PK 2 v 2
/// (`TEAMS`) started by invitation. Parsed by hand like PK 1 v 1; the data
/// messages (`pk4-match`, `pk4-lobby`, `pk4-invite` on the `pk` topic) carry
/// the same shapes as the snapshot.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

UserSummary _user(Object? v) =>
    UserSummary.fromJson(v! as Map<String, dynamic>);

/// A team: A is the organiser's (places 1 and 2), B the opponents (3 and 4).
enum Pk4Team {
  a('A'),
  b('B');

  new(this.wire);

  final String wire;

  static Pk4Team fromWire(Object? v) => v == 'B' ? b : a;

  Pk4Team get other => this == a ? b : a;
}

/// The place's team (1–2 A, 3–4 B).
Pk4Team pk4TeamOfSeat(int seat) => seat <= 2 ? Pk4Team.a : Pk4Team.b;

/// `Pk4Invite`: an invitation to a place of a lobby.
@immutable
class Pk4Invite {
  const new({
    required this.id,
    required this.lobbyId,
    required this.seat,
    required this.status,
    required this.fromRoomId,
    required this.toRoomId,
    required this.from,
    required this.to,
    required this.expiresAt,
    required this.lobbyExpiresAt,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Invite(
    id: j['id']! as String,
    lobbyId: j['lobbyId']! as String,
    seat: _int(j['seat']),
    status: j['status'] as String? ?? 'PENDING',
    fromRoomId: j['fromRoomId']! as String,
    toRoomId: j['toRoomId']! as String,
    from: _user(j['from']),
    to: _user(j['to']),
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
    lobbyExpiresAt: _date(j['lobbyExpiresAt']) ?? DateTime.now(),
  );

  final String id;
  final String lobbyId;
  final int seat;
  final String status;
  final String fromRoomId;
  final String toRoomId;
  final UserSummary from;
  final UserSummary to;
  final DateTime expiresAt;
  final DateTime lobbyExpiresAt;

  Pk4Team get team => pk4TeamOfSeat(seat);

  /// Place 2 is the teammate; 3 and 4 the opponents.
  bool get asTeammate => seat == 2;

  bool get pending => status == 'PENDING';
}

/// A place's state in the lobby.
enum Pk4SeatState { empty, invited, accepted }

/// `Pk4LobbySeat`.
@immutable
class Pk4LobbySeat {
  const new({
    required this.seat,
    required this.state,
    this.roomId,
    this.host,
    this.invite,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4LobbySeat(
    seat: _int(j['seat']),
    state: switch (j['state']) {
      'ACCEPTED' => Pk4SeatState.accepted,
      'INVITED' => Pk4SeatState.invited,
      _ => Pk4SeatState.empty,
    },
    roomId: j['roomId'] as String?,
    host: j['host'] == null ? null : _user(j['host']),
    invite: j['invite'] is Map<String, dynamic>
        ? Pk4Invite.fromJson(j['invite']! as Map<String, dynamic>)
        : null,
  );

  final int seat;
  final Pk4SeatState state;
  final String? roomId;
  final UserSummary? host;
  final Pk4Invite? invite;

  Pk4Team get team => pk4TeamOfSeat(seat);
}

/// `Pk4Lobby`: the organiser's lobby (OPEN for `PK4_LOBBY_SECONDS`).
@immutable
class Pk4Lobby {
  const new({
    required this.id,
    required this.status,
    required this.organiserRoomId,
    required this.expiresAt,
    required this.seats,
    required this.serverTime,
    this.matchId,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Lobby(
    id: j['id']! as String,
    status: j['status'] as String? ?? 'OPEN',
    organiserRoomId: j['organiserRoomId']! as String,
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
    serverTime: _date(j['serverTime']) ?? DateTime.now(),
    matchId: j['matchId'] as String?,
    seats: [
      for (final s in (j['seats'] as List<dynamic>? ?? const []))
        Pk4LobbySeat.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String id;

  /// OPEN, STARTED, CANCELLED or EXPIRED.
  final String status;
  final String organiserRoomId;
  final DateTime expiresAt;
  final DateTime serverTime;
  final String? matchId;
  final List<Pk4LobbySeat> seats;

  bool get open => status == 'OPEN';

  Pk4LobbySeat seat(int n) => seats.firstWhere(
    (s) => s.seat == n,
    orElse: () => Pk4LobbySeat(seat: n, state: Pk4SeatState.empty),
  );

  int get accepted =>
      seats.where((s) => s.state == Pk4SeatState.accepted).length;
}

/// `Pk4TeamState`.
@immutable
class Pk4TeamState {
  const new({
    required this.team,
    required this.score,
    this.result,
    this.boost,
    this.boosterUses = const {},
    this.supporters = const [],
  });

  factory fromJson(Map<String, dynamic> j) {
    final uses = j['boosterUses'];
    return Pk4TeamState(
      team: Pk4Team.fromWire(j['team']),
      score: _int(j['score']),
      result: j['result'] as String?,
      boost: j['boost'] is Map<String, dynamic>
          ? PkActiveBoost.fromJson(j['boost']! as Map<String, dynamic>)
          : null,
      boosterUses: {
        if (uses is Map)
          for (final k in PkBoosterKind.values) k: _int(uses[k.wire]),
      },
      supporters: [
        for (final s in (j['supporters'] as List<dynamic>? ?? const []))
          PkSupporter.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final Pk4Team team;

  /// The sum of the team's two hosts' PK points.
  final int score;

  /// WIN, LOSS, DRAW, or null (running, void).
  final String? result;
  final PkActiveBoost? boost;
  final Map<PkBoosterKind, int> boosterUses;
  final List<PkSupporter> supporters;

  PkActiveBoost? boostAt(DateTime now) {
    final b = boost;
    return b != null && b.endsAt.isAfter(now) ? b : null;
  }
}

/// `Pk4SeatState`: one of the four hosts.
@immutable
class Pk4Seat {
  const new({
    required this.seat,
    required this.roomId,
    required this.host,
    required this.score,
    this.out = false,
    this.outReason,
    this.mutedRoomIds = const [],
    this.pkPoints,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Seat(
    seat: _int(j['seat']),
    roomId: j['roomId']! as String,
    host: _user(j['host']),
    score: _int(j['score']),
    out: j['out'] == true,
    outReason: PkEndReason.fromWire(j['outReason']),
    mutedRoomIds: [
      for (final r in (j['mutedRoomIds'] as List<dynamic>? ?? const []))
        r as String,
    ],
    pkPoints: j['pkPoints'] is num ? (j['pkPoints']! as num).toInt() : null,
  );

  final int seat;
  final String roomId;
  final UserSummary host;

  /// This host's own PK points (under their pane).
  final int score;

  /// Left the battle (their points stay in the team's score).
  final bool out;
  final PkEndReason? outReason;

  /// The other rooms this host muted for their own room.
  final List<String> mutedRoomIds;
  final int? pkPoints;

  Pk4Team get team => pk4TeamOfSeat(seat);
}

/// `Pk4Match`: the server's whole 4-way match.
@immutable
class Pk4Match {
  const new({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.battleEndsAt,
    required this.seq,
    required this.serverTime,
    required this.organiserRoomId,
    required this.teams,
    required this.seats,
    this.resultEndsAt,
    this.endReason,
    this.winnerTeam,
    this.roundSeconds = 300,
    this.effective,
    this.boosters = const [],
  });

  factory fromJson(Map<String, dynamic> j) {
    final teams = [
      for (final t in (j['teams']! as List<dynamic>))
        Pk4TeamState.fromJson(t as Map<String, dynamic>),
    ];
    final seats = [
      for (final s in (j['seats']! as List<dynamic>))
        Pk4Seat.fromJson(s as Map<String, dynamic>),
    ];
    if (teams.length != 2 || seats.length != 4) {
      throw const FormatException('PK4 teams and seats');
    }
    return Pk4Match(
      id: j['id']! as String,
      status: PkMatchStatus.fromWire(j['status']),
      startedAt: _date(j['startedAt']) ?? DateTime.now(),
      battleEndsAt: _date(j['battleEndsAt']) ?? DateTime.now(),
      resultEndsAt: _date(j['resultEndsAt']),
      endReason: PkEndReason.fromWire(j['endReason']),
      winnerTeam: j['winnerTeam'] == null
          ? null
          : Pk4Team.fromWire(j['winnerTeam']),
      seq: _int(j['seq']),
      serverTime: _date(j['serverTime']) ?? DateTime.now(),
      roundSeconds: j['roundSeconds'] == null ? 300 : _int(j['roundSeconds']),
      effective: j['effective'] as bool?,
      organiserRoomId: j['organiserRoomId']! as String,
      teams: (
        teams.firstWhere((t) => t.team == Pk4Team.a),
        teams.firstWhere((t) => t.team == Pk4Team.b),
      ),
      seats: seats..sort((x, y) => x.seat.compareTo(y.seat)),
      boosters: [
        for (final b in (j['boosters'] as List<dynamic>? ?? const []))
          PkBoosterRule.fromJson(b as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final PkMatchStatus status;
  final DateTime startedAt;
  final DateTime battleEndsAt;
  final DateTime? resultEndsAt;
  final PkEndReason? endReason;
  final Pk4Team? winnerTeam;
  final int seq;
  final DateTime serverTime;
  final int roundSeconds;
  final bool? effective;
  final String organiserRoomId;

  /// Team A, team B.
  final (Pk4TeamState, Pk4TeamState) teams;

  /// Places 1–4 in order.
  final List<Pk4Seat> seats;
  final List<PkBoosterRule> boosters;

  Pk4Seat? seatOf(String roomId) =>
      seats.where((s) => s.roomId == roomId).firstOrNull;

  Pk4TeamState team(Pk4Team t) => t == Pk4Team.a ? teams.$1 : teams.$2;

  /// The team of [roomId] (a viewer's room), A when it is not in the match.
  Pk4Team teamOf(String roomId) => seatOf(roomId)?.team ?? Pk4Team.a;

  /// The two places of [t]: [first] (this room's when it is one of them)
  /// then the other.
  List<Pk4Seat> seatsOf(Pk4Team t, {String? first}) {
    final list = seats.where((s) => s.team == t).toList();
    if (first != null) {
      list.sort((x, y) => x.roomId == first ? -1 : (y.roomId == first ? 1 : 0));
    }
    return list;
  }

  PkBoosterRule? rule(PkBoosterKind kind) =>
      boosters.where((b) => b.kind == kind).firstOrNull;

  bool get open => status != PkMatchStatus.closed;

  /// The booster tab of the gift panel reads a [PkMatch] (PK 1 v 1): the
  /// battle with [roomId]'s team as its own side and the opponents as the
  /// other (the boosters are the team's).
  PkMatch boosterView(String roomId) {
    final mine = teamOf(roomId);
    PkSide side(Pk4Team t) {
      final s = seatsOf(t, first: roomId).first;
      final state = team(t);
      return PkSide(
        roomId: s.roomId,
        host: s.host,
        score: state.score,
        boost: state.boost,
        boosterUses: state.boosterUses,
        supporters: state.supporters,
      );
    }

    return PkMatch(
      id: id,
      status: status,
      startedAt: startedAt,
      battleEndsAt: battleEndsAt,
      seq: seq,
      serverTime: serverTime,
      sides: (side(mine), side(mine.other)),
      boosters: boosters,
      roundSeconds: roundSeconds,
    );
  }
}

/// `Pk4State`: the snapshot (`GET /live/rooms/{roomId}/pk4`).
@immutable
class Pk4State {
  const new({this.match, this.lobby, this.invite});

  factory fromJson(Map<String, dynamic> j) => Pk4State(
    match: j['match'] is Map<String, dynamic>
        ? Pk4Match.fromJson(j['match']! as Map<String, dynamic>)
        : null,
    lobby: j['lobby'] is Map<String, dynamic>
        ? Pk4Lobby.fromJson(j['lobby']! as Map<String, dynamic>)
        : null,
    invite: j['invite'] is Map<String, dynamic>
        ? Pk4Invite.fromJson(j['invite']! as Map<String, dynamic>)
        : null,
  );

  final Pk4Match? match;
  final Pk4Lobby? lobby;
  final Pk4Invite? invite;
}

/// One room of `Pk4MediaAccess`.
@immutable
class Pk4MediaRoom {
  const new({
    required this.roomId,
    required this.token,
    required this.identity,
    required this.hostIdentity,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4MediaRoom(
    roomId: j['roomId']! as String,
    token: j['token']! as String,
    identity: j['identity']! as String,
    hostIdentity: j['hostIdentity']! as String,
  );

  final String roomId;
  final String token;
  final String identity;
  final String hostIdentity;
}

/// `Pk4MediaAccess`: watch-only tokens for the three other rooms.
@immutable
class Pk4MediaAccess {
  const new({
    required this.url,
    required this.rooms,
    this.lowLayer = true,
    this.capped = false,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4MediaAccess(
    url: j['url']! as String,
    lowLayer: j['layer'] != 'MEDIUM',
    capped: j['capped'] == true,
    rooms: [
      for (final r in (j['rooms'] as List<dynamic>? ?? const []))
        Pk4MediaRoom.fromJson(r as Map<String, dynamic>),
    ],
  );

  final String url;

  /// LOW (viewers, a quarter screen) or MEDIUM (the room's host).
  final bool lowLayer;
  final bool capped;
  final List<Pk4MediaRoom> rooms;
}

/// A `pk4-*` data message on the `pk` topic (CONVENTIONS §10.180).
sealed class Pk4Event {
  const new();

  /// The message, or null when it is not a 4-way PK message.
  static Pk4Event? parse(Object? message) {
    if (message is! Map) return null;
    final json = message.cast<String, dynamic>();
    try {
      switch (json['type']) {
        case 'pk4-match':
          final boost = json['boost'];
          return Pk4MatchEvent(
            event: json['event'] as String? ?? 'score',
            match: Pk4Match.fromJson(json['match']! as Map<String, dynamic>),
            boostTeam: boost is Map ? Pk4Team.fromWire(boost['team']) : null,
            boostKind: boost is Map
                ? PkBoosterKind.fromWire(boost['kind'])
                : null,
          );
        case 'pk4-lobby':
          return Pk4LobbyEvent(
            event: json['event'] as String? ?? 'invited',
            lobby: Pk4Lobby.fromJson(json['lobby']! as Map<String, dynamic>),
          );
        case 'pk4-invite':
          return Pk4InviteEvent(
            Pk4Invite.fromJson(json['invite']! as Map<String, dynamic>),
          );
      }
    } on Object {
      return null;
    }
    return null;
  }
}

final class Pk4MatchEvent extends Pk4Event {
  const new({
    required this.event,
    required this.match,
    this.boostTeam,
    this.boostKind,
  });

  /// connected, started, score, boost, out, ended, closed, mute.
  final String event;
  final Pk4Match match;
  final Pk4Team? boostTeam;
  final PkBoosterKind? boostKind;
}

final class Pk4LobbyEvent extends Pk4Event {
  const new({required this.event, required this.lobby});

  /// opened, invited, accepted, declined, invite-expired, invite-cancelled,
  /// left, cancelled, expired, started.
  final String event;
  final Pk4Lobby lobby;
}

final class Pk4InviteEvent extends Pk4Event {
  const new(this.invite);

  final Pk4Invite invite;
}
