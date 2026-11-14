import 'package:flutter/foundation.dart' show immutable;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';

/// v1.118-live (D391, CONVENTIONS §10.180, CP-041 phase 2) «PK رباعي»: PK 2 v 2
/// (`TEAMS`) started by invitation; v1.119-live (D395, §10.181, phases 3–4):
/// two to four hosts, `FREE_FOR_ALL` «الكل ضد الكل», the organiser's «ابدأ
/// الآن», the 4-way random queue, «PK أحكام» and «جولة أخرى» for four. Parsed
/// by hand like PK 1 v 1; the data messages (`pk4-match`, `pk4-lobby`,
/// `pk4-invite`, `pk4-queue` on the `pk` topic) carry the same shapes as the
/// snapshot.

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

UserSummary _user(Object? v) =>
    UserSummary.fromJson(v! as Map<String, dynamic>);

Map<PkBoosterKind, int> _uses(Object? uses) => {
  if (uses is Map)
    for (final k in PkBoosterKind.values) k: _int(uses[k.wire]),
};

List<PkSupporter> _supporters(Object? list) => [
  for (final s in (list as List<dynamic>? ?? const []))
    PkSupporter.fromJson(s as Map<String, dynamic>),
];

/// A team: A is the organiser's (places 1 and 2), B the opponents (3 and 4).
/// v1.119-live: in FREE_FOR_ALL it is only the side of the screen.
enum Pk4Team {
  a('A'),
  b('B');

  new(this.wire);

  final String wire;

  static Pk4Team fromWire(Object? v) => v == 'B' ? b : a;

  Pk4Team get other => this == a ? b : a;
}

/// v1.119-live (D395): «٢ ضد ٢» (two teams) or «الكل ضد الكل» (each alone).
/// An unknown value reads as TEAMS (a generic 4-way PK).
enum Pk4Format {
  teams('TEAMS'),
  freeForAll('FREE_FOR_ALL');

  new(this.wire);

  final String wire;

  static Pk4Format fromWire(Object? v) =>
      v == 'FREE_FOR_ALL' ? freeForAll : teams;
}

/// v1.119-live (D395): a host's result (WIN, LOSS, DRAW).
enum Pk4Result {
  win,
  loss,
  draw;

  static Pk4Result? fromWire(Object? v) => switch (v) {
    'WIN' => win,
    'LOSS' => loss,
    'DRAW' => draw,
    _ => null,
  };
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
    this.format = Pk4Format.teams,
    this.type = PkType.normal,
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
    format: Pk4Format.fromWire(j['format']),
    type: PkType.fromWire(j['type']),
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

  /// v1.119-live (D395).
  final Pk4Format format;
  final PkType type;

  Pk4Team get team => pk4TeamOfSeat(seat);

  /// Place 2 is the teammate; 3 and 4 the opponents (TEAMS).
  bool get asTeammate => format == Pk4Format.teams && seat == 2;

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
    this.format = Pk4Format.teams,
    this.type = PkType.normal,
    this.canStartFlag,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Lobby(
    id: j['id']! as String,
    status: j['status'] as String? ?? 'OPEN',
    organiserRoomId: j['organiserRoomId']! as String,
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
    serverTime: _date(j['serverTime']) ?? DateTime.now(),
    matchId: j['matchId'] as String?,
    format: Pk4Format.fromWire(j['format']),
    type: PkType.fromWire(j['type']),
    canStartFlag: j['canStart'] as bool?,
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

  /// v1.119-live (D395): the format and the type of the lobby.
  final Pk4Format format;
  final PkType type;

  /// v1.119-live (D395): the server's `canStart` (null from an older server).
  final bool? canStartFlag;

  bool get open => status == 'OPEN';

  Pk4LobbySeat seat(int n) => seats.firstWhere(
    (s) => s.seat == n,
    orElse: () => Pk4LobbySeat(seat: n, state: Pk4SeatState.empty),
  );

  int get accepted =>
      seats.where((s) => s.state == Pk4SeatState.accepted).length;

  /// v1.119-live (D395, owner «أ»): «ابدأ الآن» — at least one invited host
  /// has joined the organiser.
  bool get canStart => open && (canStartFlag ?? accepted >= 2);
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

  factory fromJson(Map<String, dynamic> j) => Pk4TeamState(
    team: Pk4Team.fromWire(j['team']),
    score: _int(j['score']),
    result: j['result'] as String?,
    boost: j['boost'] is Map<String, dynamic>
        ? PkActiveBoost.fromJson(j['boost']! as Map<String, dynamic>)
        : null,
    boosterUses: _uses(j['boosterUses']),
    supporters: _supporters(j['supporters']),
  );

  final Pk4Team team;

  /// The sum of the team's hosts' PK points.
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

/// `Pk4SeatState`: one of the hosts.
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
    this.place,
    this.result,
    this.boost,
    this.boosterUses = const {},
    this.supporters = const [],
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
    pkPoints: _intOrNull(j['pkPoints']),
    place: _intOrNull(j['place']),
    result: Pk4Result.fromWire(j['result']),
    boost: j['boost'] is Map<String, dynamic>
        ? PkActiveBoost.fromJson(j['boost']! as Map<String, dynamic>)
        : null,
    boosterUses: _uses(j['boosterUses']),
    supporters: _supporters(j['supporters']),
  );

  final int seat;
  final String roomId;
  final UserSummary host;

  /// This host's own PK points (under their pane).
  final int score;

  /// Left the battle (their points stay).
  final bool out;
  final PkEndReason? outReason;

  /// The other rooms this host muted for their own room.
  final List<String> mutedRoomIds;
  final int? pkPoints;

  /// v1.119-live (D395): FREE_FOR_ALL's place once it ended (shared on equal
  /// scores); null in TEAMS and while it runs.
  final int? place;

  /// v1.119-live (D395): this host's result (TEAMS: the team's).
  final Pk4Result? result;

  /// v1.119-live (D395): FREE_FOR_ALL — the host's own booster, uses and
  /// supporters.
  final PkActiveBoost? boost;
  final Map<PkBoosterKind, int> boosterUses;
  final List<PkSupporter> supporters;

  /// The side of the screen (TEAMS: the team).
  Pk4Team get team => pk4TeamOfSeat(seat);

  PkActiveBoost? boostAt(DateTime now) {
    final b = boost;
    return b != null && b.endsAt.isAfter(now) ? b : null;
  }
}

/// v1.119-live (D395) `Pk4Dare`: one dare for the losing side, judged by the
/// winning side.
@immutable
class Pk4Dare {
  const new({
    required this.status,
    required this.loserRoomIds,
    required this.winnerRoomIds,
    required this.options,
    required this.drawn,
    required this.revealAt,
    required this.decideBy,
    this.cause,
    this.startedAt,
    this.endsAt,
    this.finishedAt,
    this.points = 0,
    this.refusePoints = -3,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Dare(
    status: PkDareStatus.fromWire(j['status']),
    cause: j['cause'] as String?,
    loserRoomIds: [
      for (final r in (j['loserRoomIds'] as List<dynamic>? ?? const []))
        r as String,
    ],
    winnerRoomIds: [
      for (final r in (j['winnerRoomIds'] as List<dynamic>? ?? const []))
        r as String,
    ],
    options: [
      for (final o in (j['options'] as List<dynamic>? ?? const []))
        PkDareOption.fromJson(o as Map<String, dynamic>),
    ],
    drawn: _int(j['drawn']),
    revealAt: _date(j['revealAt']) ?? DateTime.now(),
    decideBy: _date(j['decideBy']) ?? DateTime.now(),
    startedAt: _date(j['startedAt']),
    endsAt: _date(j['endsAt']),
    finishedAt: _date(j['finishedAt']),
    points: _intOrNull(j['points']) ?? 0,
    refusePoints: _intOrNull(j['refusePoints']) ?? -3,
  );

  final PkDareStatus status;
  final String? cause;
  final List<String> loserRoomIds;
  final List<String> winnerRoomIds;
  final List<PkDareOption> options;
  final int drawn;
  final DateTime revealAt;
  final DateTime decideBy;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? finishedAt;
  final int points;
  final int refusePoints;

  /// PK 1 v 1's [PkDare] as [roomId] sees it: this room's side when it is on
  /// one (a loser answers, a winner judges), else the first room of each.
  PkDare forRoom(String roomId) => PkDare(
    status: status,
    cause: cause,
    loserRoomId: loserRoomIds.contains(roomId) || loserRoomIds.isEmpty
        ? roomId
        : loserRoomIds.first,
    winnerRoomId: winnerRoomIds.contains(roomId) || winnerRoomIds.isEmpty
        ? roomId
        : winnerRoomIds.first,
    options: options,
    drawn: drawn,
    revealAt: revealAt,
    decideBy: decideBy,
    startedAt: startedAt,
    endsAt: endsAt,
    finishedAt: finishedAt,
    points: points,
    refusePoints: refusePoints,
  );
}

/// v1.119-live (D395) `Pk4Rematch`: an open «جولة أخرى» (every present host
/// must accept).
@immutable
class Pk4Rematch {
  const new({
    required this.byRoomId,
    required this.expiresAt,
    this.acceptedRoomIds = const [],
    this.waitingRoomIds = const [],
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Rematch(
    byRoomId: j['byRoomId']! as String,
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
    acceptedRoomIds: [
      for (final r in (j['acceptedRoomIds'] as List<dynamic>? ?? const []))
        r as String,
    ],
    waitingRoomIds: [
      for (final r in (j['waitingRoomIds'] as List<dynamic>? ?? const []))
        r as String,
    ],
  );

  final String byRoomId;
  final DateTime expiresAt;
  final List<String> acceptedRoomIds;
  final List<String> waitingRoomIds;
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
    this.format = Pk4Format.teams,
    this.type = PkType.normal,
    this.random = false,
    this.dare,
    this.rematch,
    this.rematchOf,
    this.rematchesLeft,
  });

  /// Two to four places; two teams or none (FREE_FOR_ALL). Anything else is
  /// refused (the message is ignored), so a future shape never half-draws.
  factory fromJson(Map<String, dynamic> j) {
    final teams = [
      for (final t in (j['teams'] as List<dynamic>? ?? const []))
        Pk4TeamState.fromJson(t as Map<String, dynamic>),
    ];
    final seats = [
      for (final s in (j['seats']! as List<dynamic>))
        Pk4Seat.fromJson(s as Map<String, dynamic>),
    ];
    if ((teams.length != 2 && teams.isNotEmpty) ||
        seats.length < 2 ||
        seats.length > 4) {
      throw const FormatException('PK4 teams and seats');
    }
    seats.sort((x, y) => x.seat.compareTo(y.seat));
    // FREE_FOR_ALL has no teams: each side's sum, for the parts of the app
    // that read a side (the gift panel's booster tab).
    Pk4TeamState side(Pk4Team t) =>
        teams.where((x) => x.team == t).firstOrNull ??
        Pk4TeamState(
          team: t,
          score: seats
              .where((s) => s.team == t)
              .fold(0, (sum, s) => sum + s.score),
        );
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
      teams: (side(Pk4Team.a), side(Pk4Team.b)),
      seats: seats,
      boosters: [
        for (final b in (j['boosters'] as List<dynamic>? ?? const []))
          PkBoosterRule.fromJson(b as Map<String, dynamic>),
      ],
      format: Pk4Format.fromWire(j['format']),
      type: PkType.fromWire(j['type']),
      random: j['source'] == 'RANDOM',
      dare: j['dare'] is Map<String, dynamic>
          ? Pk4Dare.fromJson(j['dare']! as Map<String, dynamic>)
          : null,
      rematch: j['rematch'] is Map<String, dynamic>
          ? Pk4Rematch.fromJson(j['rematch']! as Map<String, dynamic>)
          : null,
      rematchOf: j['rematchOf'] as String?,
      rematchesLeft: _intOrNull(j['rematchesLeft']),
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

  /// Team A, team B (FREE_FOR_ALL: each side's sum).
  final (Pk4TeamState, Pk4TeamState) teams;

  /// The places in order (two to four).
  final List<Pk4Seat> seats;
  final List<PkBoosterRule> boosters;

  /// v1.119-live (D395).
  final Pk4Format format;
  final PkType type;
  final bool random;
  final Pk4Dare? dare;
  final Pk4Rematch? rematch;
  final String? rematchOf;
  final int? rematchesLeft;

  bool get ffa => format == Pk4Format.freeForAll;

  /// The hosts playing (2–4).
  int get playerCount => seats.length;

  Pk4Seat? seatOf(String roomId) =>
      seats.where((s) => s.roomId == roomId).firstOrNull;

  Pk4TeamState team(Pk4Team t) => t == Pk4Team.a ? teams.$1 : teams.$2;

  /// The team of [roomId] (a viewer's room), A when it is not in the match.
  Pk4Team teamOf(String roomId) => seatOf(roomId)?.team ?? Pk4Team.a;

  /// The places of [t]: [first] (this room's when it is one of them) then
  /// the other.
  List<Pk4Seat> seatsOf(Pk4Team t, {String? first}) {
    final list = seats.where((s) => s.team == t).toList();
    if (first != null) {
      list.sort((x, y) => x.roomId == first ? -1 : (y.roomId == first ? 1 : 0));
    }
    return list;
  }

  /// FREE_FOR_ALL's leader first (the four-part bar), equal scores by place.
  List<Pk4Seat> get ranked => [...seats]
    ..sort((x, y) {
      final byScore = y.score.compareTo(x.score);
      return byScore != 0 ? byScore : x.seat.compareTo(y.seat);
    });

  /// The result [roomId]'s room sees (its host's; a viewer of a room in the
  /// match reads that room's), null while it runs or for a void match.
  Pk4Result? resultOf(String roomId) {
    final seat = seatOf(roomId);
    if (seat?.result case final r?) return r;
    if (ffa || status == PkMatchStatus.battle || seat == null) return null;
    if (endReason == PkEndReason.admin || endReason == PkEndReason.cancelled) {
      return null;
    }
    final t = team(seat.team).result;
    return Pk4Result.fromWire(t);
  }

  PkBoosterRule? rule(PkBoosterKind kind) =>
      boosters.where((b) => b.kind == kind).firstOrNull;

  bool get open => status != PkMatchStatus.closed;

  /// «جولة أخرى» may be offered now from the hosts' side (the server checks
  /// the rest: the hosts present, their lives …).
  bool get canOfferRematch =>
      status == PkMatchStatus.result &&
      rematch == null &&
      (dare == null || dare!.finishedAt != null) &&
      (rematchesLeft == null || rematchesLeft! > 0);

  /// The booster tab of the gift panel reads a [PkMatch] (PK 1 v 1): the
  /// battle with [roomId]'s team as its own side and the opponents as the
  /// other (TEAMS: the boosters are the team's; FREE_FOR_ALL: the host's
  /// own, the leader of the others as the other side).
  PkMatch boosterView(String roomId) {
    final mine = teamOf(roomId);
    PkSide teamSide(Pk4Team t) {
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

    PkSide seatSide(Pk4Seat s) => PkSide(
      roomId: s.roomId,
      host: s.host,
      score: s.score,
      boost: s.boost,
      boosterUses: s.boosterUses,
      supporters: s.supporters,
    );

    final (PkSide own, PkSide other) = ffa
        ? (
            seatSide(seatOf(roomId) ?? seats.first),
            seatSide(
              ranked.where((s) => s.roomId != roomId).firstOrNull ?? seats.last,
            ),
          )
        : (teamSide(mine), teamSide(mine.other));
    return PkMatch(
      id: id,
      status: status,
      startedAt: startedAt,
      battleEndsAt: battleEndsAt,
      seq: seq,
      serverTime: serverTime,
      sides: (own, other),
      boosters: boosters,
      roundSeconds: roundSeconds,
      type: type,
    );
  }

  /// v1.119-live (D395): PK 1 v 1's match for the «PK أحكام» card and draw
  /// as [roomId] sees it — the losing side's hosts on one side (their names
  /// joined), the judges on the other, and the dare from this room's side.
  PkMatch? dareView(String roomId) {
    final d = dare;
    if (d == null) return null;
    final view = d.forRoom(roomId);
    UserSummary names(List<String> rooms, String first) {
      final hosts = [for (final r in rooms) ?seatOf(r)?.host];
      final lead = seatOf(first)?.host ?? hosts.firstOrNull ?? seats.first.host;
      return lead.copyWith(
        displayName: hosts.isEmpty
            ? lead.displayName
            : hosts.map((h) => h.displayName).join(' · '),
      );
    }

    return PkMatch(
      id: id,
      status: status,
      startedAt: startedAt,
      battleEndsAt: battleEndsAt,
      resultEndsAt: resultEndsAt,
      endReason: endReason,
      seq: seq,
      serverTime: serverTime,
      sides: (
        PkSide(
          roomId: view.loserRoomId,
          host: names(d.loserRoomIds, view.loserRoomId),
          score: 0,
        ),
        PkSide(
          roomId: view.winnerRoomId,
          host: names(d.winnerRoomIds, view.winnerRoomId),
          score: 0,
        ),
      ),
      winnerRoomId: view.winnerRoomId,
      type: type,
      dare: view,
    );
  }
}

/// v1.119-live (D395) `Pk4Queue`: the host's wait in the 4-way random queue.
@immutable
class Pk4Queue {
  const new({
    required this.format,
    required this.expiresAt,
    this.type = PkType.normal,
  });

  factory fromJson(Map<String, dynamic> j) => Pk4Queue(
    format: Pk4Format.fromWire(j['format']),
    type: PkType.fromWire(j['type']),
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
  );

  final Pk4Format format;
  final PkType type;
  final DateTime expiresAt;
}

/// `Pk4State`: the snapshot (`GET /live/rooms/{roomId}/pk4`).
@immutable
class Pk4State {
  const new({this.match, this.lobby, this.invite, this.queue});

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
    queue: j['queue'] is Map<String, dynamic>
        ? Pk4Queue.fromJson(j['queue']! as Map<String, dynamic>)
        : null,
  );

  final Pk4Match? match;
  final Pk4Lobby? lobby;
  final Pk4Invite? invite;

  /// v1.119-live (D395): the host's 4-way random wait.
  final Pk4Queue? queue;
}

/// v1.119-live (D395) `Pk4RandomResult`.
@immutable
class Pk4RandomResult {
  const new({this.match, this.queue});

  factory fromJson(Map<String, dynamic> j) => Pk4RandomResult(
    match: j['match'] is Map<String, dynamic>
        ? Pk4Match.fromJson(j['match']! as Map<String, dynamic>)
        : null,
    queue: j['queue'] is Map<String, dynamic>
        ? Pk4Queue.fromJson(j['queue']! as Map<String, dynamic>)
        : null,
  );

  final Pk4Match? match;
  final Pk4Queue? queue;
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

/// `Pk4MediaAccess`: watch-only tokens for the other rooms (one to three).
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

/// A `pk4-*` data message on the `pk` topic (CONVENTIONS §10.180, §10.181).
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
            boostSeat: boost is Map ? _intOrNull(boost['seat']) : null,
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
        case 'pk4-queue':
          return Pk4QueueEvent(
            matched: json['status'] == 'MATCHED',
            matchId: json['matchId'] as String?,
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
    this.boostSeat,
  });

  /// connected, started, score, boost, out, ended, closed, mute; v1.119-live:
  /// dare, rematch-offer, rematch-accepted, rematch, rematch-declined,
  /// rematch-cancelled, rematch-expired.
  final String event;
  final Pk4Match match;
  final Pk4Team? boostTeam;
  final PkBoosterKind? boostKind;

  /// FREE_FOR_ALL: the place whose own booster started.
  final int? boostSeat;
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

/// v1.119-live (D395) `pk4-queue`: the host's random wait matched, or ran out.
final class Pk4QueueEvent extends Pk4Event {
  const new({required this.matched, this.matchId});

  final bool matched;
  final String? matchId;
}
