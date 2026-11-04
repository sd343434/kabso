import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_pk_media.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:material_ui/material_ui.dart';

/// v1.43-live (D195): a [LivePkRepository] for tests — a settable snapshot,
/// candidates, and every call recorded.
class FakeLivePkRepository implements LivePkRepository {
  new({this.snapshot = const PkState(), this.list = const []});

  PkState snapshot;

  /// D199: builds the snapshot when it is read (countdowns that start then,
  /// so a slow setup under load never moves a golden's seconds).
  PkState Function()? snapshotOf;
  List<PkCandidate> list;
  PkMatch? matchOnAccept;
  PkMatch? matchOnRandom;

  /// D199: the «Friends» list (null: the same as [list]).
  List<PkCandidate>? friendList;
  PkSettings current = const PkSettings();
  PkHistory pkHistory = const PkHistory();
  final List<Map<String, Object>> saved = [];
  final List<String> calls = [];
  Exception? failWith;

  void _call(String name) {
    calls.add(name);
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<PkState> state(String roomId) async {
    calls.add('state');
    return snapshotOf?.call() ?? snapshot;
  }

  @override
  Future<List<PkCandidate>> candidates(
    String roomId, {
    String? query,
    bool friends = false,
  }) async {
    _call('candidates:${friends ? 'friends:' : ''}${query ?? ''}');
    if (friends && friendList != null) return friendList!;
    return [
      for (final c in list)
        if (query == null ||
            query.isEmpty ||
            c.host.displayName.contains(query) ||
            c.host.username.startsWith(query))
          c,
    ];
  }

  @override
  Future<PkInvite> invite(
    String roomId, {
    required String toRoomId,
    PkType type = PkType.normal,
  }) async {
    _call(
      type == PkType.normal
          ? 'invite:$toRoomId'
          : 'invite:$toRoomId:${type.wire}',
    );
    final to = [
      ...list,
      ...?friendList,
    ].firstWhere((c) => c.roomId == toRoomId).host;
    return PkInvite(
      id: 'invite-1',
      status: 'PENDING',
      fromRoomId: roomId,
      toRoomId: toRoomId,
      from: pkUser('host-a', 'سارة'),
      to: to,
      expiresAt: DateTime.now().add(const Duration(seconds: 15)),
      type: type,
    );
  }

  @override
  Future<void> cancelInvite(String roomId, String inviteId) async =>
      _call('cancel:$inviteId');

  @override
  Future<PkMatch> accept(String roomId, String inviteId) async {
    _call('accept:$inviteId');
    return matchOnAccept!;
  }

  @override
  Future<void> decline(String roomId, String inviteId) async =>
      _call('decline:$inviteId');

  @override
  Future<({DateTime? waitingUntil, PkMatch? match})> joinRandom(
    String roomId, {
    PkType type = PkType.normal,
  }) async {
    _call(type == PkType.normal ? 'random' : 'random:${type.wire}');
    return (
      waitingUntil: matchOnRandom == null
          ? DateTime.now().add(const Duration(seconds: 60))
          : null,
      match: matchOnRandom,
    );
  }

  @override
  Future<void> leaveRandom(String roomId) async => _call('leaveRandom');

  @override
  Future<PkMatch> end(String roomId) async {
    _call('end');
    return snapshot.match!;
  }

  @override
  Future<PkMatch> muteOpponent(String roomId, {required bool muted}) async {
    _call('mute:$muted');
    return snapshot.match!;
  }

  @override
  Future<PkMediaAccess> mediaToken(String roomId, {String? guestId}) async {
    calls.add('token');
    return const PkMediaAccess(
      url: 'ws://media.test',
      token: 't',
      roomId: 'room-b',
      identity: 'pk:m:viewer',
      hostIdentity: 'host-b',
    );
  }

  @override
  Future<PkRecord> record(String username) async =>
      const PkRecord(wins: 3, losses: 1, draws: 1);

  @override
  Future<bool> setInvitesEnabled({required bool enabled}) async {
    _call('invites:$enabled');
    return enabled;
  }

  @override
  Future<PkSettings> settings() async {
    _call('settings');
    return current;
  }

  @override
  Future<PkSettings> saveSettings(Map<String, Object> changes) async {
    _call('save:${changes.keys.join(',')}');
    saved.add(changes);
    final c = current;
    return current = PkSettings(
      invitesEnabled: changes['invitesEnabled'] as bool? ?? c.invitesEnabled,
      mode: changes.containsKey('mode')
          ? PkMode.fromWire(changes['mode'])
          : c.mode,
      roundMinutes: changes['roundMinutes'] as int? ?? c.roundMinutes,
      roundSeconds: (changes['roundMinutes'] as int?) != null
          ? (changes['roundMinutes']! as int) * 60
          : c.roundSeconds,
      autoStart: changes['autoStart'] as bool? ?? c.autoStart,
      randomGender: changes.containsKey('randomGender')
          ? PkGenderPref.fromWire(changes['randomGender'])
          : c.randomGender,
      randomRegion: changes.containsKey('randomRegion')
          ? PkRegionPref.fromWire(changes['randomRegion'])
          : c.randomRegion,
      autoMatch: changes['autoMatch'] as bool? ?? c.autoMatch,
      recommendable: changes['recommendable'] as bool? ?? c.recommendable,
      record: c.record,
    );
  }

  @override
  Future<PkMatch> start(String roomId) async {
    _call('start');
    return snapshot.match!;
  }

  @override
  Future<PkHistory> history(String username) async {
    _call('history:$username');
    return pkHistory;
  }

  /// D229: the match answered by the dare calls (null: the snapshot's).
  PkMatch? matchOnDare;

  @override
  Future<PkMatch> acceptDare(String roomId) async {
    _call('dare:accept');
    return matchOnDare ?? snapshot.match!;
  }

  @override
  Future<PkMatch> refuseDare(String roomId) async {
    _call('dare:refuse');
    return matchOnDare ?? snapshot.match!;
  }

  @override
  Future<PkMatch> judgeDare(String roomId, {required bool done}) async {
    _call('dare:verdict:$done');
    return matchOnDare ?? snapshot.match!;
  }

  @override
  Future<void> reportDare(String roomId, String dareId) async =>
      _call('dare:report:$dareId');

  /// D242: the match answered by the rematch calls (null: the snapshot's).
  PkMatch? matchOnRematch;

  @override
  Future<PkMatch> offerRematch(String roomId) async {
    _call('rematch:offer');
    return matchOnRematch ?? snapshot.match!;
  }

  @override
  Future<PkMatch> acceptRematch(String roomId) async {
    _call('rematch:accept');
    return matchOnRematch ?? snapshot.match!;
  }

  @override
  Future<void> declineRematch(String roomId) async => _call('rematch:decline');

  @override
  Future<PkMatch> cancelRematch(String roomId) async {
    _call('rematch:cancel');
    return matchOnRematch ?? snapshot.match!;
  }
}

class _Ping extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The other room's connection in tests: [present] people show a video.
class FakePkOpponentMedia implements LivePkOpponentMedia {
  final Set<String> present = {};
  Set<String> speakingNow = {};
  bool joined = false;
  bool muted = false;
  final _changes = _Ping();

  /// Paints a "video" (tests and captures).
  static Widget Function(String identity) painter = (identity) => ColoredBox(
    key: Key('pk.video.$identity'),
    color: const Color(0xFF503040),
  );

  @override
  Future<void> join(PkMediaAccess access) async {
    joined = true;
    _changes.ping();
  }

  @override
  Future<void> leave() async {
    joined = false;
  }

  @override
  Widget? video(String identity) =>
      present.contains(identity) ? painter(identity) : null;

  @override
  bool isPresent(String identity) => present.contains(identity);

  @override
  Set<String> get speaking => speakingNow;

  @override
  Future<void> setAudioMuted({required bool muted}) async => this.muted = muted;

  @override
  bool get audioMuted => muted;

  @override
  Listenable get changes => _changes;

  @override
  bool get connected => joined;
}

UserSummary pkUser(String id, String name) => UserSummary(
  id: id,
  username: id.replaceAll('-', '_'),
  displayName: name,
  avatarUrl: null,
);

/// A PK match fixture: [ownRoom] (side A, this room) against room-b.
PkMatch pkMatchFixture({
  required DateTime now,
  String ownRoom = 'room-0',
  String ownHostId = 'user-0',
  bool ar = true,
  PkMatchStatus status = PkMatchStatus.battle,
  Duration remaining = const Duration(
    minutes: 3,
    seconds: 12,
    milliseconds: 500,
  ),
  int ownScore = 12500,
  int otherScore = 9800,
  PkBoosterKind? ownBoost,
  PkBoosterKind? otherBoost,
  Duration boostLeft = const Duration(seconds: 14, milliseconds: 500),
  String? winner,
  PkEndReason? endReason,
  int ownGuests = 0,
  int otherGuests = 0,
  int seq = 5,
  bool mutesOpponent = false,
  bool bestOfThree = false,
  int round = 1,
  int ownRounds = 0,
  int otherRounds = 0,
  // D276: each host's «نقاط PK» (null: an older server, nothing shown).
  int? ownPkPoints,
  int? otherPkPoints,
  int? forfeitPoints,
}) {
  String n(String a, String e) => ar ? a : e;
  final multipliers = {
    PkBoosterKind.double: 2,
    PkBoosterKind.doubleTurbo: 3,
    PkBoosterKind.triple: 5,
    PkBoosterKind.tripleTurbo: 10,
  };
  PkActiveBoost? boost(PkBoosterKind? kind, String id) => kind == null
      ? null
      : PkActiveBoost(
          id: id,
          kind: kind,
          multiplier: multipliers[kind]!,
          endsAt: now.add(boostLeft),
        );
  final names = [
    n('هند', 'Hind'),
    n('نور', 'Nour'),
    n('سامي', 'Sami'),
    n('عمر', 'Omar'),
    n('رنا', 'Rana'),
    n('خالد', 'Khalid'),
  ];
  List<PkGuest> guests(String prefix, int count) => [
    for (var i = 0; i < count; i++)
      PkGuest(
        user: pkUser('$prefix-guest-$i', names[(i + 2) % names.length]),
        seatIndex: i + 1,
      ),
  ];
  final battleEnds = status == PkMatchStatus.battle
      ? now.add(remaining)
      : now.subtract(const Duration(seconds: 5));
  return PkMatch(
    id: 'match-1',
    status: status,
    startedAt: battleEnds.subtract(const Duration(minutes: 5)),
    battleEndsAt: battleEnds,
    resultEndsAt: status == PkMatchStatus.battle
        ? null
        : battleEnds.add(const Duration(seconds: 60)),
    endReason:
        endReason ?? (status == PkMatchStatus.battle ? null : PkEndReason.time),
    winnerRoomId: winner,
    seq: seq,
    serverTime: now,
    bestOfThree: bestOfThree,
    round: round,
    sides: (
      PkSide(
        roomId: ownRoom,
        host: pkUser(ownHostId, n('سارة', 'Sara')),
        score: ownScore,
        roundsWon: ownRounds,
        boost: boost(ownBoost, 'boost-a'),
        supporters: [
          PkSupporter(user: pkUser('fan-1', names[0]), points: 6000),
          PkSupporter(user: pkUser('fan-2', names[1]), points: 4200),
          PkSupporter(user: pkUser('fan-3', names[2]), points: 1300),
        ],
        guests: guests('a', ownGuests),
        mutesOpponent: mutesOpponent,
        pkPoints: ownPkPoints,
      ),
      PkSide(
        roomId: 'room-b',
        host: pkUser('host-b', n('كريم', 'Karim')),
        score: otherScore,
        roundsWon: otherRounds,
        boost: boost(otherBoost, 'boost-b'),
        supporters: [
          PkSupporter(user: pkUser('fan-4', names[3]), points: 5000),
          PkSupporter(user: pkUser('fan-5', names[4]), points: 3100),
        ],
        guests: guests('b', otherGuests),
        pkPoints: otherPkPoints,
      ),
    ),
    forfeitPoints: forfeitPoints,
    boosters: const [
      PkBoosterRule(
        kind: PkBoosterKind.double,
        multiplier: 2,
        durationSeconds: 30,
        lastSeconds: 0,
        limitPerMatch: 2,
        giftCode: 'pk_double',
      ),
      PkBoosterRule(
        kind: PkBoosterKind.doubleTurbo,
        multiplier: 3,
        durationSeconds: 20,
        lastSeconds: 120,
        limitPerMatch: 2,
        giftCode: 'pk_double_turbo',
      ),
      PkBoosterRule(
        kind: PkBoosterKind.triple,
        multiplier: 5,
        durationSeconds: 20,
        lastSeconds: 60,
        limitPerMatch: 2,
        giftCode: 'pk_triple',
      ),
      PkBoosterRule(
        kind: PkBoosterKind.tripleTurbo,
        multiplier: 10,
        durationSeconds: 10,
        lastSeconds: 60,
        limitPerMatch: 2,
        giftCode: 'pk_triple_turbo',
      ),
    ],
  );
}

/// The PK overrides of a test: [repo] and one [opponent] connection.
List<Override> pkOverrides(
  FakeLivePkRepository repo, [
  FakePkOpponentMedia? opponent,
]) {
  final media = opponent ?? FakePkOpponentMedia();
  return [
    livePkRepositoryProvider.overrideWithValue(repo),
    livePkOpponentMediaFactoryProvider.overrideWithValue(() => media),
    // D253: the host's «Host Tasks» card never reaches the network (no
    // weekly tasks: no card).
    myTasksProvider.overrideWith(
      (ref) => Future<MyTasks>.error(StateError('no tasks in live tests')),
    ),
  ];
}

/// v1.43-live (D195): what every live-screen test needs so the PK never
/// reaches the network (no PK in the room unless a test sets one).
List<Override> pkTestOverrides() => pkOverrides(FakeLivePkRepository());

/// D229: a «PK أحكام» dare — [status] at [now]; side A (room-0) lost unless
/// [loserRoom] says otherwise.
PkDare pkDareFixture({
  required DateTime now,
  PkDareStatus status = PkDareStatus.deciding,
  String loserRoom = 'room-0',
  String winnerRoom = 'room-b',
  int drawn = 1,
  String? cause,
  int points = 0,
  Duration decideLeft = const Duration(seconds: 21, milliseconds: 500),
  Duration dareLeft = const Duration(
    minutes: 2,
    seconds: 14,
    milliseconds: 500,
  ),
}) {
  const options = [
    PkDareOption(
      id: 'dare-easy',
      level: PkDareLevel.easy,
      category: 'IMITATION',
      textAr: 'تقليد بطريق أثناء غسل الصحون بالحركة البطيئة',
      textEn: 'Imitate a penguin washing the dishes, in slow motion',
    ),
    PkDareOption(
      id: 'dare-medium',
      level: PkDareLevel.medium,
      category: 'SINGING',
      textAr: 'غناء راب قصير عن الجوارب الضائعة بصوت أوبرالي',
      textEn: 'Sing a short rap about lost socks, in an opera voice',
    ),
    PkDareOption(
      id: 'dare-hard',
      level: PkDareLevel.hard,
      category: 'DRAWING',
      textAr: 'رسم وجه الفائز على شكل بطل خارق خلال دقيقتين ثم عرضه بفخر',
      textEn:
          "Draw the winner's face as a superhero within two minutes, "
          'then show it proudly',
    ),
  ];
  final revealAt = status == PkDareStatus.drawing
      ? now.add(const Duration(seconds: 3))
      : now.subtract(const Duration(seconds: 8));
  final decideBy = status == PkDareStatus.drawing
      ? revealAt.add(const Duration(seconds: 30))
      : now.add(decideLeft);
  final active = status == PkDareStatus.active;
  return PkDare(
    status: status,
    cause: cause,
    loserRoomId: loserRoom,
    winnerRoomId: winnerRoom,
    options: options,
    drawn: drawn,
    revealAt: revealAt,
    decideBy: decideBy,
    startedAt: active ? now.subtract(const Duration(seconds: 45)) : null,
    endsAt: active ? now.add(dareLeft) : null,
    finishedAt: status.open ? null : now,
    points: points,
  );
}

/// D229: a finished DARES match (B won) with [dare].
PkMatch pkDareMatchFixture({
  required DateTime now,
  required PkDare dare,
  bool ar = true,
  String ownRoom = 'room-0',
}) {
  final base = pkMatchFixture(
    now: now,
    ar: ar,
    ownRoom: ownRoom,
    status: PkMatchStatus.result,
    winner: dare.winnerRoomId,
    ownScore: 9800,
    otherScore: 12500,
  );
  return PkMatch(
    id: base.id,
    status: base.status,
    startedAt: base.startedAt,
    battleEndsAt: base.battleEndsAt,
    resultEndsAt: base.resultEndsAt,
    endReason: base.endReason,
    winnerRoomId: base.winnerRoomId,
    seq: base.seq,
    serverTime: now,
    sides: base.sides,
    boosters: base.boosters,
    type: PkType.dares,
    dare: dare,
  );
}

/// D242: a RESULT (normal) match — this room won — with «جولة أخرى»
/// offered by [offerBy] (null: no offer yet) until [now] + [left].
PkMatch pkRematchFixture({
  required DateTime now,
  bool ar = true,
  String ownRoom = 'room-0',
  String? offerBy,
  Duration left = const Duration(seconds: 12),
  int? rematchesLeft = 5,
  PkMatchStatus status = PkMatchStatus.result,
  String? rematchOf,
  int? ownPkPoints,
  int? otherPkPoints,
  PkDare? dare,
}) {
  final base = pkMatchFixture(
    now: now,
    ar: ar,
    ownRoom: ownRoom,
    status: status,
    winner: status == PkMatchStatus.result ? ownRoom : null,
    ownPkPoints: ownPkPoints,
    otherPkPoints: otherPkPoints,
  );
  return PkMatch(
    id: rematchOf == null ? base.id : '${base.id}-2',
    status: base.status,
    startedAt: base.startedAt,
    battleEndsAt: base.battleEndsAt,
    resultEndsAt: base.resultEndsAt,
    endReason: base.endReason,
    winnerRoomId: base.winnerRoomId,
    seq: base.seq,
    serverTime: now,
    sides: base.sides,
    boosters: base.boosters,
    rematch: offerBy == null
        ? null
        : PkRematchOffer(byRoomId: offerBy, expiresAt: now.add(left)),
    rematchOf: rematchOf,
    rematchCount: rematchOf == null ? 0 : 1,
    rematchesLeft: rematchesLeft,
    dare: dare,
  );
}
