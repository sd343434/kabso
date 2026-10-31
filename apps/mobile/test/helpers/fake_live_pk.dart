import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_pk_media.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:material_ui/material_ui.dart';

/// v1.43-live (D195): a [LivePkRepository] for tests — a settable snapshot,
/// candidates, and every call recorded.
class FakeLivePkRepository implements LivePkRepository {
  new({this.snapshot = const PkState(), this.list = const []});

  PkState snapshot;
  List<PkCandidate> list;
  PkMatch? matchOnAccept;
  PkMatch? matchOnRandom;
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
    return snapshot;
  }

  @override
  Future<List<PkCandidate>> candidates(String roomId, {String? query}) async {
    _call('candidates:${query ?? ''}');
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
  Future<PkInvite> invite(String roomId, {required String toRoomId}) async {
    _call('invite:$toRoomId');
    final to = list.firstWhere((c) => c.roomId == toRoomId).host;
    return PkInvite(
      id: 'invite-1',
      status: 'PENDING',
      fromRoomId: roomId,
      toRoomId: toRoomId,
      from: pkUser('host-a', 'سارة'),
      to: to,
      expiresAt: DateTime.now().add(const Duration(seconds: 15)),
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
    String roomId,
  ) async {
    _call('random');
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
    sides: (
      PkSide(
        roomId: ownRoom,
        host: pkUser(ownHostId, n('سارة', 'Sara')),
        score: ownScore,
        boost: boost(ownBoost, 'boost-a'),
        supporters: [
          PkSupporter(user: pkUser('fan-1', names[0]), points: 6000),
          PkSupporter(user: pkUser('fan-2', names[1]), points: 4200),
          PkSupporter(user: pkUser('fan-3', names[2]), points: 1300),
        ],
        guests: guests('a', ownGuests),
        mutesOpponent: mutesOpponent,
      ),
      PkSide(
        roomId: 'room-b',
        host: pkUser('host-b', n('كريم', 'Karim')),
        score: otherScore,
        boost: boost(otherBoost, 'boost-b'),
        supporters: [
          PkSupporter(user: pkUser('fan-4', names[3]), points: 5000),
          PkSupporter(user: pkUser('fan-5', names[4]), points: 3100),
        ],
        guests: guests('b', otherGuests),
      ),
    ),
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
  ];
}

/// v1.43-live (D195): what every live-screen test needs so the PK never
/// reaches the network (no PK in the room unless a test sets one).
List<Override> pkTestOverrides() => pkOverrides(FakeLivePkRepository());
