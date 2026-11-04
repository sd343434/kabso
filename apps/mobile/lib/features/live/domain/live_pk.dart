import 'dart:ui' show Locale;

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
    this.pkPoints,
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
      pkPoints: j['pkPoints'] is num ? (j['pkPoints']! as num).toInt() : null,
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

  /// v1.67-live (D276) «نقاط PK»: this side's host's PK points
  /// (`PkHostRecord.points`; may be below 0) — null from an older server.
  final int? pkPoints;

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
    this.type = PkType.normal,
    this.dare,
    this.rematch,
    this.rematchOf,
    this.rematchCount = 0,
    this.rematchesLeft,
    this.forfeitPoints,
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
      type: PkType.fromWire(j['type']),
      dare: j['dare'] is Map<String, dynamic>
          ? PkDare.fromJson(j['dare']! as Map<String, dynamic>)
          : null,
      rematch: j['rematch'] is Map<String, dynamic>
          ? PkRematchOffer.fromJson(j['rematch']! as Map<String, dynamic>)
          : null,
      rematchOf: j['rematchOf'] as String?,
      rematchCount: j['rematchCount'] == null ? 0 : _int(j['rematchCount']),
      rematchesLeft: j['rematchesLeft'] == null
          ? null
          : _int(j['rematchesLeft']),
      forfeitPoints: j['forfeitPoints'] is num
          ? (j['forfeitPoints']! as num).toInt()
          : null,
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

  /// v1.50-live (D229): «PK عادي» or «PK أحكام».
  final PkType type;

  /// v1.50-live (D229): the dare of a DARES match with a winner (else null).
  final PkDare? dare;

  /// v1.55-live (D242) «جولة أخرى»: the open offer of a RESULT match.
  final PkRematchOffer? rematch;

  /// v1.55-live (D242): the battle this one is a rematch of (null: the
  /// first) and how many rematches came before it.
  final String? rematchOf;
  final int rematchCount;

  /// v1.55-live (D242): rematches still allowed in a row (null: unlimited;
  /// older servers: unknown — the app then offers it and the server says).
  final int? rematchesLeft;

  /// v1.67-live (D276, owner: «انسحاب = −٣»): what withdrawing from the
  /// battle counts now (−3; null from an older server): the «إنهاء التحدي»
  /// confirm says it.
  final int? forfeitPoints;

  /// D242: «جولة أخرى» may be offered now from the hosts' side — the result
  /// is showing, its dare (if any) is over, no offer is open and the limit
  /// is not reached. The server checks the rest (both lives present …).
  bool get canOfferRematch =>
      status == PkMatchStatus.result &&
      rematch == null &&
      (dare == null || dare!.finishedAt != null) &&
      (rematchesLeft == null || rematchesLeft! > 0);

  /// CONNECTED: no timer, no points until a host starts it.
  bool get connected => status == PkMatchStatus.connected;

  bool get open => status != PkMatchStatus.closed;

  /// This room's side (the reading start), then the other one.
  (PkSide own, PkSide other) of(String roomId) =>
      sides.$2.roomId == roomId ? (sides.$2, sides.$1) : (sides.$1, sides.$2);

  PkBoosterRule? rule(PkBoosterKind kind) =>
      boosters.where((b) => b.kind == kind).firstOrNull;
}

/// v1.55-live (D242) `PkRematchOffer`: who asked for «جولة أخرى», until when.
@immutable
class PkRematchOffer {
  const new({required this.byRoomId, required this.expiresAt});

  factory fromJson(Map<String, dynamic> j) => PkRematchOffer(
    byRoomId: j['byRoomId']! as String,
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
  );

  final String byRoomId;
  final DateTime expiresAt;
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
    this.type = PkType.normal,
  });

  factory fromJson(Map<String, dynamic> j) => PkInvite(
    id: j['id']! as String,
    status: j['status'] as String? ?? 'PENDING',
    fromRoomId: j['fromRoomId']! as String,
    toRoomId: j['toRoomId']! as String,
    from: _user(j['from']),
    to: _user(j['to']),
    expiresAt: _date(j['expiresAt']) ?? DateTime.now(),
    type: PkType.fromWire(j['type']),
  );

  final String id;
  final String status;
  final String fromRoomId;
  final String toRoomId;
  final UserSummary from;
  final UserSummary to;
  final DateTime expiresAt;

  /// v1.50-live (D229): the type offered («PK أحكام» is shown on the card).
  final PkType type;

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
  const new({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    this.daresDone = 0,
    this.daresRefused = 0,
  });

  factory fromJson(Map<String, dynamic> j) => PkRecord(
    wins: _int(j['wins']),
    losses: _int(j['losses']),
    draws: _int(j['draws']),
    points: _signed(j['points']),
    daresDone: _int(j['daresDone']),
    daresRefused: _int(j['daresRefused']),
  );

  final int wins;
  final int losses;
  final int draws;

  /// v1.50-live (D229): PK points (win +3, draw +1, loss 0, refused −3; may
  /// be below 0) and the dares done / refused.
  final int points;
  final int daresDone;
  final int daresRefused;

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
    this.dares = false,
    this.dareStatus,
    this.dareMine = false,
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
    dares: j['type'] == 'DARES',
    dareStatus: j['dare'] is Map
        ? (j['dare']! as Map<String, dynamic>)['status'] as String?
        : null,
    dareMine:
        j['dare'] is Map &&
        (j['dare']! as Map<String, dynamic>)['mine'] == true,
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

  /// v1.50-live (D229): a «PK أحكام» match, its dare's end (DONE, REFUSED …)
  /// and whether this host was the one doing it.
  final bool dares;
  final String? dareStatus;
  final bool dareMine;
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

  /// started, score, boost, ended, closed, mute, dare; D242: rematch-offer,
  /// rematch-cancelled, rematch-declined, rematch-expired, rematch.
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

// ---- v1.50-live (D229, CONVENTIONS §10.80): «PK أحكام» -------------------

/// `PkType`: «PK عادي» / «PK أحكام» (an unknown value is a normal PK).
enum PkType {
  normal('NORMAL'),
  dares('DARES');

  new(this.wire);

  final String wire;

  static PkType fromWire(Object? v) => v == 'DARES' ? dares : normal;
}

/// `PkDareLevel`: «سهل» / «متوسط» / «صعب».
enum PkDareLevel {
  easy('EASY'),
  medium('MEDIUM'),
  hard('HARD');

  new(this.wire);

  final String wire;

  static PkDareLevel fromWire(Object? v) =>
      values.where((l) => l.wire == v).firstOrNull ?? easy;
}

/// `PkDareOption`: one of the three cards.
@immutable
class PkDareOption {
  const new({
    required this.id,
    required this.level,
    required this.category,
    required this.textAr,
    required this.textEn,
  });

  factory fromJson(Map<String, dynamic> j) => PkDareOption(
    id: j['id']! as String,
    level: PkDareLevel.fromWire(j['level']),
    category: j['category'] as String? ?? '',
    textAr: j['textAr'] as String? ?? '',
    textEn: j['textEn'] as String? ?? '',
  );

  final String id;
  final PkDareLevel level;
  final String category;
  final String textAr;
  final String textEn;

  /// The text of the app's language (Arabic, else English).
  String text(Locale locale) => locale.languageCode == 'ar' ? textAr : textEn;
}

/// `PkDare.status`.
enum PkDareStatus {
  drawing,
  deciding,
  active,
  done,
  refused,
  cancelled;

  static PkDareStatus fromWire(Object? v) => switch (v) {
    'DRAWING' => drawing,
    'DECIDING' => deciding,
    'ACTIVE' => active,
    'DONE' => done,
    'REFUSED' => refused,
    _ => cancelled,
  };

  bool get open => this == drawing || this == deciding || this == active;
}

/// `PkDare`: the server's draw and how it goes (both rooms see the same).
@immutable
class PkDare {
  const new({
    required this.status,
    required this.loserRoomId,
    required this.winnerRoomId,
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

  factory fromJson(Map<String, dynamic> j) => PkDare(
    status: PkDareStatus.fromWire(j['status']),
    cause: j['cause'] as String?,
    loserRoomId: j['loserRoomId']! as String,
    winnerRoomId: j['winnerRoomId']! as String,
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
    points: _signed(j['points']),
    refusePoints: j['refusePoints'] == null ? -3 : _signed(j['refusePoints']),
  );

  final PkDareStatus status;

  /// LOSER_REFUSED, DECIDE_TIMEOUT, LOSER_LEFT, WINNER_DONE, WINNER_NOT_DONE,
  /// TIMER, WINNER_LEFT, ADMIN (unknown values: a generic end).
  final String? cause;
  final String loserRoomId;
  final String winnerRoomId;

  /// EASY, MEDIUM, HARD in that order.
  final List<PkDareOption> options;

  /// The server's draw (0–2): the shuffle lands on it at [revealAt].
  final int drawn;
  final DateTime revealAt;
  final DateTime decideBy;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? finishedAt;

  /// The loser's PK points from the dare (the refusal's, else 0).
  final int points;

  /// What a refusal counts now (the panel's value, −3 by default).
  final int refusePoints;

  PkDareOption? get chosen =>
      drawn >= 0 && drawn < options.length ? options[drawn] : null;

  /// The status at the server time [now] (the reveal happens on its own).
  PkDareStatus statusAt(DateTime now) =>
      status == PkDareStatus.drawing && !now.isBefore(revealAt)
      ? PkDareStatus.deciding
      : status;

  /// «لم يُنفّذ الحكم»: the winner judged it not done.
  bool get notDone => cause == 'WINNER_NOT_DONE';
}

int _signed(Object? v) => switch (v) {
  final int n => n,
  final num n => n.toInt(),
  _ => 0,
};
