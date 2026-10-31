import 'package:flutter/foundation.dart' show immutable;
import 'package:kabso_live/core/models/shared_models.dart';

/// v1.43-live (D195, CONVENTIONS §10.58): PK 1 v 1 between two SOLO video
/// lives. Parsed by hand (no codegen): the shapes are small and the data
/// messages carry the same [PkMatch] as the snapshot.

/// The four boosters «دبل» ×2, «دبل تيربو» ×3, «تربل» ×5, «تربل تيربو» ×10.
enum PkBoosterKind {
  double('DOUBLE'),
  doubleTurbo('DOUBLE_TURBO'),
  triple('TRIPLE'),
  tripleTurbo('TRIPLE_TURBO');

  new(this.wire);

  final String wire;

  static PkBoosterKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

enum PkMatchStatus {
  battle,
  result,
  closed;

  static PkMatchStatus fromWire(Object? wire) => switch (wire) {
    'BATTLE' => battle,
    'RESULT' => result,
    _ => closed,
  };
}

enum PkEndReason {
  time,
  forfeit,
  disconnect,
  away,
  admin,
  unknown;

  static PkEndReason? fromWire(Object? wire) => switch (wire) {
    null => null,
    'TIME' => time,
    'FORFEIT' => forfeit,
    'DISCONNECT' => disconnect,
    'AWAY' => away,
    'ADMIN' => admin,
    _ => unknown,
  };
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

UserSummary _user(Object? v) =>
    UserSummary.fromJson(v! as Map<String, dynamic>);

/// `PkBoosterRule`: a booster's rule and the gift that activates it.
@immutable
class PkBoosterRule {
  const new({
    required this.kind,
    required this.multiplier,
    required this.durationSeconds,
    required this.lastSeconds,
    required this.limitPerMatch,
    required this.giftCode,
  });

  factory fromJson(Map<String, dynamic> j) => PkBoosterRule(
    kind: PkBoosterKind.fromWire(j['kind']) ?? PkBoosterKind.double,
    multiplier: _int(j['multiplier']),
    durationSeconds: _int(j['durationSeconds']),
    lastSeconds: _int(j['lastSeconds']),
    limitPerMatch: _int(j['limitPerMatch']),
    giftCode: j['giftCode'] as String?,
  );

  final PkBoosterKind kind;
  final int multiplier;
  final int durationSeconds;

  /// 0: any time; otherwise only in the battle's last N seconds.
  final int lastSeconds;
  final int limitPerMatch;
  final String? giftCode;
}

/// `PkActiveBoost`: the booster running on a side.
@immutable
class PkActiveBoost {
  const new({
    required this.id,
    required this.kind,
    required this.multiplier,
    required this.endsAt,
    this.sender,
  });

  factory fromJson(Map<String, dynamic> j) => PkActiveBoost(
    id: j['id']! as String,
    kind: PkBoosterKind.fromWire(j['kind']) ?? PkBoosterKind.double,
    multiplier: _int(j['multiplier']),
    endsAt: _date(j['endsAt']) ?? DateTime.now(),
    sender: j['sender'] == null ? null : _user(j['sender']),
  );

  final String id;
  final PkBoosterKind kind;
  final int multiplier;
  final DateTime endsAt;
  final UserSummary? sender;
}

/// `PkSupporter`.
@immutable
class PkSupporter {
  const new({required this.user, required this.points});

  factory fromJson(Map<String, dynamic> j) =>
      PkSupporter(user: _user(j['user']), points: _int(j['points']));

  final UserSummary user;
  final int points;
}

/// `PkGuest`: a guest seated in that side's live (a small circle).
@immutable
class PkGuest {
  const new({
    required this.user,
    required this.seatIndex,
    this.mutedByHost = false,
  });

  factory fromJson(Map<String, dynamic> j) => PkGuest(
    user: _user(j['user']),
    seatIndex: _int(j['seatIndex']),
    mutedByHost: j['mutedByHost'] == true,
  );

  final UserSummary user;
  final int seatIndex;
  final bool mutedByHost;
}

/// `PkSideState`.
@immutable
class PkSide {
  const new({
    required this.roomId,
    required this.host,
    required this.score,
    this.boost,
    this.boosterUses = const {},
    this.supporters = const [],
    this.guests = const [],
    this.mutesOpponent = false,
  });

  factory fromJson(Map<String, dynamic> j) {
    final uses = j['boosterUses'];
    return PkSide(
      roomId: j['roomId']! as String,
      host: _user(j['host']),
      score: _int(j['score']),
      boost: j['boost'] == null
          ? null
          : PkActiveBoost.fromJson(j['boost']! as Map<String, dynamic>),
      boosterUses: {
        if (uses is Map)
          for (final k in PkBoosterKind.values) k: _int(uses[k.wire]),
      },
      supporters: [
        for (final s in (j['supporters'] as List<dynamic>? ?? const []))
          PkSupporter.fromJson(s as Map<String, dynamic>),
      ],
      guests: [
        for (final g in (j['guests'] as List<dynamic>? ?? const []))
          PkGuest.fromJson(g as Map<String, dynamic>),
      ],
      mutesOpponent: j['mutesOpponent'] == true,
    );
  }

  final String roomId;
  final UserSummary host;
  final int score;
  final PkActiveBoost? boost;
  final Map<PkBoosterKind, int> boosterUses;
  final List<PkSupporter> supporters;
  final List<PkGuest> guests;
  final bool mutesOpponent;

  /// The booster still running at [now], or null.
  PkActiveBoost? boostAt(DateTime now) {
    final b = boost;
    return b != null && b.endsAt.isAfter(now) ? b : null;
  }
}

/// `PkMatch`: the server's whole match (snapshot and data messages).
@immutable
class PkMatch {
  const new({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.battleEndsAt,
    required this.sides,
    required this.seq,
    required this.serverTime,
    this.resultEndsAt,
    this.endReason,
    this.winnerRoomId,
    this.loserCauseRoomId,
    this.boosters = const [],
    this.random = false,
  });

  factory fromJson(Map<String, dynamic> j) {
    final sides = [
      for (final s in (j['sides']! as List<dynamic>))
        PkSide.fromJson(s as Map<String, dynamic>),
    ];
    if (sides.length != 2) throw const FormatException('PK sides');
    return PkMatch(
      id: j['id']! as String,
      status: PkMatchStatus.fromWire(j['status']),
      startedAt: _date(j['startedAt']) ?? DateTime.now(),
      battleEndsAt: _date(j['battleEndsAt']) ?? DateTime.now(),
      resultEndsAt: _date(j['resultEndsAt']),
      endReason: PkEndReason.fromWire(j['endReason']),
      winnerRoomId: j['winnerRoomId'] as String?,
      loserCauseRoomId: j['loserCauseRoomId'] as String?,
      seq: _int(j['seq']),
      serverTime: _date(j['serverTime']) ?? DateTime.now(),
      sides: (sides[0], sides[1]),
      boosters: [
        for (final b in (j['boosters'] as List<dynamic>? ?? const []))
          PkBoosterRule.fromJson(b as Map<String, dynamic>),
      ],
      random: j['source'] == 'RANDOM',
    );
  }

  final String id;
  final PkMatchStatus status;
  final DateTime startedAt;
  final DateTime battleEndsAt;
  final DateTime? resultEndsAt;
  final PkEndReason? endReason;
  final String? winnerRoomId;
  final String? loserCauseRoomId;
  final int seq;

  /// The server clock when this was built (the countdown's offset).
  final DateTime serverTime;
  final (PkSide, PkSide) sides;
  final List<PkBoosterRule> boosters;
  final bool random;

  bool get open => status != PkMatchStatus.closed;

  /// This room's side (the reading start), then the other one.
  (PkSide own, PkSide other) of(String roomId) =>
      sides.$2.roomId == roomId ? (sides.$2, sides.$1) : (sides.$1, sides.$2);

  PkBoosterRule? rule(PkBoosterKind kind) =>
      boosters.where((b) => b.kind == kind).firstOrNull;
}

/// `PkInvite`.
@immutable
class PkInvite {
  const new({
    required this.id,
    required this.status,
    required this.fromRoomId,
    required this.toRoomId,
    required this.from,
    required this.to,
    required this.expiresAt,
  });

  factory fromJson(Map<String, dynamic> j) => PkInvite(
    id: j['id']! as String,
    status: j['status'] as String? ?? 'PENDING',
    fromRoomId: j['fromRoomId']! as String,
    toRoomId: j['toRoomId']! as String,
    from: _user(j['from']),
    to: _user(j['to']),
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
  );

  final String id;
  final String status;
  final String fromRoomId;
  final String toRoomId;
  final UserSummary from;
  final UserSummary to;
  final DateTime expiresAt;

  bool get pending => status == 'PENDING';
}

/// `PkState`: the snapshot (`GET /live/rooms/{roomId}/pk`).
@immutable
class PkState {
  const new({this.match, this.invite, this.queueUntil, this.invitesEnabled});

  factory fromJson(Map<String, dynamic> j) => PkState(
    match: j['match'] == null
        ? null
        : PkMatch.fromJson(j['match']! as Map<String, dynamic>),
    invite: j['invite'] == null
        ? null
        : PkInvite.fromJson(j['invite']! as Map<String, dynamic>),
    queueUntil: j['queue'] is Map
        ? _date((j['queue']! as Map<String, dynamic>)['expiresAt'])
        : null,
    invitesEnabled: j['invitesEnabled'] as bool?,
  );

  final PkMatch? match;
  final PkInvite? invite;
  final DateTime? queueUntil;
  final bool? invitesEnabled;
}

/// `PkCandidate`: a live host who may be invited.
@immutable
class PkCandidate {
  const new({
    required this.roomId,
    required this.title,
    required this.viewerCount,
    required this.host,
  });

  factory fromJson(Map<String, dynamic> j) => PkCandidate(
    roomId: j['roomId']! as String,
    title: j['title'] as String? ?? '',
    viewerCount: _int(j['viewerCount']),
    host: _user(j['host']),
  );

  final String roomId;
  final String title;
  final int viewerCount;
  final UserSummary host;
}

/// `PkMediaAccess`: a watch-only token for the other room.
@immutable
class PkMediaAccess {
  const new({
    required this.url,
    required this.token,
    required this.roomId,
    required this.identity,
    required this.hostIdentity,
  });

  factory fromJson(Map<String, dynamic> j) => PkMediaAccess(
    url: j['url']! as String,
    token: j['token']! as String,
    roomId: j['roomId']! as String,
    identity: j['identity']! as String,
    hostIdentity: j['hostIdentity']! as String,
  );

  final String url;
  final String token;
  final String roomId;
  final String identity;
  final String hostIdentity;
}

/// `PkHostRecord`.
@immutable
class PkRecord {
  const new({this.wins = 0, this.losses = 0, this.draws = 0});

  factory fromJson(Map<String, dynamic> j) => PkRecord(
    wins: _int(j['wins']),
    losses: _int(j['losses']),
    draws: _int(j['draws']),
  );

  final int wins;
  final int losses;
  final int draws;

  int get total => wins + losses + draws;
}

/// A `pk` data message (CONVENTIONS §10.58).
sealed class PkEvent {
  const new();

  /// The message, or null when it is not a PK message.
  static PkEvent? parse(Object? message) {
    if (message is! Map) return null;
    final json = message.cast<String, dynamic>();
    try {
      switch (json['type']) {
        case 'pk-match':
          final boost = json['boost'];
          return PkMatchEvent(
            event: json['event'] as String? ?? 'score',
            match: PkMatch.fromJson(json['match']! as Map<String, dynamic>),
            boostRoomId: boost is Map ? boost['roomId'] as String? : null,
            boostKind: boost is Map
                ? PkBoosterKind.fromWire(boost['kind'])
                : null,
          );
        case 'pk-invite':
          return PkInviteEvent(
            PkInvite.fromJson(json['invite']! as Map<String, dynamic>),
          );
        case 'pk-queue':
          return const PkQueueExpired();
      }
    } on Object {
      return null;
    }
    return null;
  }
}

final class PkMatchEvent extends PkEvent {
  const new({
    required this.event,
    required this.match,
    this.boostRoomId,
    this.boostKind,
  });

  /// started, score, boost, ended, closed, mute.
  final String event;
  final PkMatch match;
  final String? boostRoomId;
  final PkBoosterKind? boostKind;
}

final class PkInviteEvent extends PkEvent {
  const new(this.invite);

  final PkInvite invite;
}

final class PkQueueExpired extends PkEvent {
  const new();
}
