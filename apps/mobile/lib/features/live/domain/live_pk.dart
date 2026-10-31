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
  /// v1.44-live (D199): the hosts are connected and wait for a start.
  connected,
  battle,
  result,
  closed;

  static PkMatchStatus fromWire(Object? wire) => switch (wire) {
    'CONNECTED' => connected,
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

  /// v1.44-live (D199): a connected PK that never started.
  cancelled,
  unknown;

  static PkEndReason? fromWire(Object? wire) => switch (wire) {
    null => null,
    'TIME' => time,
    'FORFEIT' => forfeit,
    'DISCONNECT' => disconnect,
    'AWAY' => away,
    'ADMIN' => admin,
    'CANCELLED' => cancelled,
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
    this.totalScore,
    this.roundsWon = 0,
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
      totalScore: j['totalScore'] == null ? null : _int(j['totalScore']),
      roundsWon: _int(j['roundsWon']),
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

  /// The running round's PK points (the only round of a single PK).
  final int score;

  /// v1.44-live (D199): every round's points (null from an older server).
  final int? totalScore;

  /// v1.44-live (D199): rounds won (best of three).
  final int roundsWon;
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
    this.bestOfThree = false,
    this.round = 1,
    this.roundSeconds = 300,
    this.settingsFromRoomId,
    this.effective,
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
      bestOfThree: j['mode'] == 'BEST_OF_THREE',
      round: j['round'] == null ? 1 : _int(j['round']),
      roundSeconds: j['roundSeconds'] == null ? 300 : _int(j['roundSeconds']),
      settingsFromRoomId: j['settingsFromRoomId'] as String?,
      effective: j['effective'] as bool?,
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

  /// v1.44-live (D199): best of three (the first to win two rounds).
  final bool bestOfThree;

  /// The running (or last) round, 1–3.
  final int round;
  final int roundSeconds;

  /// The room whose host's settings were used, when the two hosts' differed.
  final String? settingsFromRoomId;

  /// Whether the finished match counts in the records (null while open).
  final bool? effective;

  /// CONNECTED: no timer, no points until a host starts it.
  bool get connected => status == PkMatchStatus.connected;

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

/// v1.44-live (D199): «Single Round PK» / «Best of three PK».
enum PkMode {
  single('SINGLE'),
  bestOfThree('BEST_OF_THREE');

  new(this.wire);

  final String wire;

  static PkMode fromWire(Object? w) =>
      w == 'BEST_OF_THREE' ? bestOfThree : single;
}

/// v1.44-live (D199): the random queue's gender preference.
enum PkGenderPref {
  both('BOTH'),
  male('MALE'),
  female('FEMALE');

  new(this.wire);

  final String wire;

  static PkGenderPref fromWire(Object? w) =>
      values.where((v) => v.wire == w).firstOrNull ?? both;
}

/// v1.44-live (D199): the random queue's region preference.
enum PkRegionPref {
  global('GLOBAL'),
  sameCountry('SAME_COUNTRY');

  new(this.wire);

  final String wire;

  static PkRegionPref fromWire(Object? w) =>
      w == 'SAME_COUNTRY' ? sameCountry : global;
}

/// v1.44-live (D199) `MyLivePk`: the PK Setting page (1 v 1) and record.
@immutable
class PkSettings {
  const new({
    this.invitesEnabled = true,
    this.mode = PkMode.single,
    this.roundMinutes,
    this.roundSeconds = 300,
    this.autoStart = true,
    this.randomGender = PkGenderPref.both,
    this.randomRegion = PkRegionPref.global,
    this.autoMatch = false,
    this.recommendable = true,
    this.effectiveMinPoints = 3000,
    this.record = const PkRecord(),
  });

  factory fromJson(Map<String, dynamic> j) => PkSettings(
    invitesEnabled: j['invitesEnabled'] != false,
    mode: PkMode.fromWire(j['mode']),
    roundMinutes: j['roundMinutes'] == null ? null : _int(j['roundMinutes']),
    roundSeconds: j['roundSeconds'] == null ? 300 : _int(j['roundSeconds']),
    autoStart: j['autoStart'] != false,
    randomGender: PkGenderPref.fromWire(j['randomGender']),
    randomRegion: PkRegionPref.fromWire(j['randomRegion']),
    autoMatch: j['autoMatch'] == true,
    recommendable: j['recommendable'] != false,
    effectiveMinPoints: j['effectiveMinPoints'] == null
        ? 3000
        : _int(j['effectiveMinPoints']),
    record: j['record'] is Map<String, dynamic>
        ? PkRecord.fromJson(j['record']! as Map<String, dynamic>)
        : const PkRecord(),
  );

  final bool invitesEnabled;
  final PkMode mode;

  /// 3, 5 or 10; null: the server's default ([roundSeconds]).
  final int? roundMinutes;
  final int roundSeconds;
  final bool autoStart;
  final PkGenderPref randomGender;
  final PkRegionPref randomRegion;
  final bool autoMatch;
  final bool recommendable;

  /// Both sides' PK points together from which a PK counts («PK فعّال»).
  final int effectiveMinPoints;
  final PkRecord record;

  /// The round time shown («5 دقائق»).
  int get minutes => roundMinutes ?? (roundSeconds / 60).round();
}

/// v1.44-live (D199) `PkHistoryItem`: one finished PK from the host's side.
@immutable
class PkHistoryItem {
  const new({
    required this.id,
    required this.result,
    required this.score,
    required this.opponentScore,
    required this.opponent,
    required this.startedAt,
    this.effective = true,
    this.bestOfThree = false,
    this.roundsWon = 0,
    this.opponentRoundsWon = 0,
  });

  factory fromJson(Map<String, dynamic> j) => PkHistoryItem(
    id: j['id']! as String,
    result: j['result'] as String? ?? 'VOID',
    score: _int(j['score']),
    opponentScore: _int(j['opponentScore']),
    opponent: _user(j['opponent']),
    startedAt: _date(j['startedAt']) ?? DateTime.now(),
    effective: j['effective'] != false,
    bestOfThree: j['mode'] == 'BEST_OF_THREE',
    roundsWon: _int(j['roundsWon']),
    opponentRoundsWon: _int(j['opponentRoundsWon']),
  );

  final String id;

  /// WIN, LOSS, DRAW or VOID.
  final String result;
  final int score;
  final int opponentScore;
  final UserSummary opponent;
  final DateTime startedAt;
  final bool effective;
  final bool bestOfThree;
  final int roundsWon;
  final int opponentRoundsWon;
}

/// v1.44-live (D199): a host's record and last matches.
@immutable
class PkHistory {
  const new({this.record = const PkRecord(), this.recent = const []});

  factory fromJson(Map<String, dynamic> j) => PkHistory(
    record: PkRecord.fromJson(j['record']! as Map<String, dynamic>),
    recent: [
      for (final r in (j['recent'] as List<dynamic>? ?? const []))
        PkHistoryItem.fromJson(r as Map<String, dynamic>),
    ],
  );

  final PkRecord record;
  final List<PkHistoryItem> recent;
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
