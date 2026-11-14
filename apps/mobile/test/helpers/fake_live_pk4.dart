import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_pk4_media.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:material_ui/material_ui.dart';

/// v1.118-live (D391): a [LivePk4Repository] for tests — a settable snapshot,
/// candidates, and every call recorded.
class FakeLivePk4Repository implements LivePk4Repository {
  new({this.snapshot = const Pk4State(), this.list = const []});

  Pk4State snapshot;
  List<PkCandidate> list;
  Pk4Lobby? lobbyOnOpen;
  Pk4Lobby? lobbyOnInvite;
  Pk4State stateOnAccept = const Pk4State();
  Pk4Match? matchOnEnd;
  Pk4MediaAccess access = const Pk4MediaAccess(url: 'ws://media', rooms: []);
  final List<String> calls = [];
  Exception? failWith;

  void _call(String name) {
    calls.add(name);
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<Pk4State> state(String roomId) async {
    calls.add('state');
    return snapshot;
  }

  @override
  Future<List<PkCandidate>> candidates(
    String roomId, {
    String? query,
    bool friends = false,
  }) async {
    _call('candidates:${friends ? 'friends:' : ''}${query ?? ''}');
    return list;
  }

  @override
  Future<Pk4Lobby> openLobby(
    String roomId, {
    Pk4Format format = Pk4Format.teams,
    PkType type = PkType.normal,
  }) async {
    _call(
      format == Pk4Format.teams && type == PkType.normal
          ? 'open'
          : 'open:${format.wire}:${type.wire}',
    );
    return lobbyOnOpen!;
  }

  /// v1.119-live (D395).
  Pk4State stateOnStartLobby = const Pk4State();
  Pk4RandomResult randomResult = const Pk4RandomResult();
  Pk4Match? matchOnAction;

  @override
  Future<Pk4State> startLobby(String roomId) async {
    _call('startLobby');
    return stateOnStartLobby;
  }

  @override
  Future<Pk4RandomResult> joinRandom(
    String roomId, {
    required Pk4Format format,
    PkType type = PkType.normal,
  }) async {
    _call('random:${format.wire}:${type.wire}');
    return randomResult;
  }

  @override
  Future<void> leaveRandom(String roomId) async => _call('leaveRandom');

  Pk4Match _action(String name) {
    _call(name);
    return matchOnAction ?? snapshot.match!;
  }

  @override
  Future<Pk4Match> acceptDare(String roomId) async => _action('dare:accept');

  @override
  Future<Pk4Match> refuseDare(String roomId) async => _action('dare:refuse');

  @override
  Future<Pk4Match> judgeDare(String roomId, {required bool done}) async =>
      _action('dare:verdict:$done');

  @override
  Future<void> reportDare(String roomId, String dareId) async =>
      _call('dare:report:$dareId');

  @override
  Future<Pk4Match> offerRematch(String roomId) async =>
      _action('rematch:offer');

  @override
  Future<Pk4Match> acceptRematch(String roomId) async =>
      _action('rematch:accept');

  @override
  Future<void> declineRematch(String roomId) async => _call('rematch:decline');

  @override
  Future<Pk4Match> cancelRematch(String roomId) async =>
      _action('rematch:cancel');

  @override
  Future<void> closeLobby(String roomId) async => _call('close');

  @override
  Future<Pk4Lobby> invite(
    String roomId, {
    required String toRoomId,
    required int seat,
  }) async {
    _call('invite:$toRoomId:$seat');
    return lobbyOnInvite!;
  }

  @override
  Future<void> cancelInvite(String roomId, String inviteId) async =>
      _call('cancel:$inviteId');

  @override
  Future<Pk4State> accept(String roomId, String inviteId) async {
    _call('accept:$inviteId');
    return stateOnAccept;
  }

  @override
  Future<void> decline(String roomId, String inviteId) async =>
      _call('decline:$inviteId');

  @override
  Future<Pk4Match> start(String roomId) async {
    _call('start');
    return snapshot.match!;
  }

  @override
  Future<Pk4Match> end(String roomId) async {
    _call('end');
    return matchOnEnd ?? snapshot.match!;
  }

  @override
  Future<Pk4Match> mute(
    String roomId, {
    required String otherRoomId,
    required bool muted,
  }) async {
    _call('mute:$otherRoomId:$muted');
    return snapshot.match!;
  }

  @override
  Future<Pk4MediaAccess> mediaToken(String roomId, {String? guestId}) async {
    _call('media');
    return access;
  }
}

class _Ping extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// One other room's connection in tests: [present] people show a video.
class FakePk4RoomMedia implements LivePk4RoomMedia {
  final Set<String> present = {};
  Set<String> speakingNow = {};
  bool joined = false;
  bool? low;
  bool muted = false;
  bool paused = false;
  final _changes = _Ping();

  @override
  Future<void> join({
    required String url,
    required String token,
    required bool lowLayer,
  }) async {
    joined = true;
    low = lowLayer;
    _changes.ping();
  }

  @override
  Future<void> leave() async => joined = false;

  @override
  Widget? video(String identity) => present.contains(identity) && !paused
      ? ColoredBox(
          key: Key('pk4.video.$identity'),
          color: const Color(0xFF503040),
        )
      : null;

  @override
  Set<String> get speaking => speakingNow;

  @override
  Future<void> setAudioMuted({required bool muted}) async => this.muted = muted;

  @override
  bool get audioMuted => muted;

  @override
  Future<void> setVideoPaused({required bool paused}) async =>
      this.paused = paused;

  @override
  bool get videoPaused => paused;

  @override
  Listenable get changes => _changes;

  @override
  bool get connected => joined;
}

UserSummary pk4User(String id, String name) => UserSummary(
  id: id,
  username: id.replaceAll('-', '_'),
  displayName: name,
  avatarUrl: null,
);

/// A 4-way match fixture: room-0 (place 1, team A, «this room») with room-1
/// as its teammate against room-2 and room-3.
Pk4Match pk4MatchFixture({
  required DateTime now,
  bool ar = true,
  PkMatchStatus status = PkMatchStatus.battle,
  Duration remaining = const Duration(minutes: 2, seconds: 45),
  List<int> scores = const [53200, 12400, 50300, 13000],
  PkBoosterKind? boostA,
  PkBoosterKind? boostB,
  Pk4Team? winner,
  PkEndReason? endReason,
  List<int> out = const [],
  List<String> mutedByMe = const [],
  int seq = 5,
}) {
  String n(String a, String e) => ar ? a : e;
  final names = [
    n('سارة', 'Sara'),
    n('ليلى', 'Layla'),
    n('كريم', 'Karim'),
    n('زياد', 'Ziad'),
  ];
  final ended = status == PkMatchStatus.result;
  PkActiveBoost? boost(PkBoosterKind? kind, String id) => kind == null
      ? null
      : PkActiveBoost(
          id: id,
          kind: kind,
          multiplier: switch (kind) {
            PkBoosterKind.double => 2,
            PkBoosterKind.doubleTurbo => 3,
            PkBoosterKind.triple => 5,
            PkBoosterKind.tripleTurbo => 10,
          },
          endsAt: now.add(const Duration(seconds: 14, milliseconds: 500)),
        );
  String? result(Pk4Team t) => !ended
      ? null
      : winner == null
      ? 'DRAW'
      : winner == t
      ? 'WIN'
      : 'LOSS';
  List<PkSupporter> fans(List<String> list) => [
    for (final (i, name) in list.indexed)
      PkSupporter(user: pk4User('fan-$name', name), points: 9000 - i * 2000),
  ];
  return Pk4Match(
    id: 'pk4-match-1',
    status: status,
    startedAt: now.subtract(const Duration(minutes: 2, seconds: 15)),
    battleEndsAt: now.add(remaining),
    resultEndsAt: ended ? now.add(const Duration(seconds: 50)) : null,
    endReason: endReason ?? (ended ? PkEndReason.time : null),
    winnerTeam: ended ? winner : null,
    seq: seq,
    serverTime: now,
    organiserRoomId: 'room-0',
    teams: (
      Pk4TeamState(
        team: Pk4Team.a,
        score: scores[0] + scores[1],
        result: result(Pk4Team.a),
        boost: boost(boostA, 'boost-a'),
        boosterUses: {?boostA: 1},
        supporters: fans([
          n('هند', 'Hind'),
          n('نور', 'Nour'),
          n('سامي', 'Sami'),
        ]),
      ),
      Pk4TeamState(
        team: Pk4Team.b,
        score: scores[2] + scores[3],
        result: result(Pk4Team.b),
        boost: boost(boostB, 'boost-b'),
        boosterUses: {?boostB: 1},
        supporters: fans([
          n('عمر', 'Omar'),
          n('رنا', 'Rana'),
          n('خالد', 'Khalid'),
        ]),
      ),
    ),
    seats: [
      for (var i = 0; i < 4; i++)
        Pk4Seat(
          seat: i + 1,
          roomId: 'room-$i',
          host: pk4User('user-$i', names[i]),
          score: scores[i],
          out: out.contains(i + 1),
          outReason: out.contains(i + 1) ? PkEndReason.forfeit : null,
          mutedRoomIds: i == 0 ? mutedByMe : const [],
          pkPoints: 12,
        ),
    ],
    boosters: [
      for (final k in PkBoosterKind.values)
        PkBoosterRule(
          kind: k,
          multiplier: 2,
          durationSeconds: 20,
          lastSeconds: 0,
          limitPerMatch: 2,
          giftCode: 'pk_${k.wire.toLowerCase()}',
        ),
    ],
  );
}

/// A lobby fixture organised by room-0: [states] for places 2–4.
Pk4Lobby pk4LobbyFixture({
  required DateTime now,
  bool ar = true,
  List<Pk4SeatState> states = const [
    Pk4SeatState.accepted,
    Pk4SeatState.invited,
    Pk4SeatState.empty,
  ],
}) {
  String n(String a, String e) => ar ? a : e;
  final names = [n('ليلى', 'Layla'), n('كريم', 'Karim'), n('زياد', 'Ziad')];
  Pk4Invite invite(int seat) => Pk4Invite(
    id: 'invite-$seat',
    lobbyId: 'lobby-1',
    seat: seat,
    status: states[seat - 2] == Pk4SeatState.accepted ? 'ACCEPTED' : 'PENDING',
    fromRoomId: 'room-0',
    toRoomId: 'room-${seat - 1}',
    from: pk4User('user-0', n('سارة', 'Sara')),
    to: pk4User('user-${seat - 1}', names[seat - 2]),
    expiresAt: now.add(const Duration(seconds: 21)),
    lobbyExpiresAt: now.add(const Duration(seconds: 95)),
  );
  return Pk4Lobby(
    id: 'lobby-1',
    status: 'OPEN',
    organiserRoomId: 'room-0',
    expiresAt: now.add(const Duration(seconds: 95)),
    serverTime: now,
    seats: [
      Pk4LobbySeat(
        seat: 1,
        state: Pk4SeatState.accepted,
        roomId: 'room-0',
        host: pk4User('user-0', n('سارة', 'Sara')),
      ),
      for (var seat = 2; seat <= 4; seat++)
        if (states[seat - 2] == Pk4SeatState.empty)
          Pk4LobbySeat(seat: seat, state: Pk4SeatState.empty)
        else
          Pk4LobbySeat(
            seat: seat,
            state: states[seat - 2],
            roomId: 'room-${seat - 1}',
            host: pk4User('user-${seat - 1}', names[seat - 2]),
            invite: invite(seat),
          ),
    ],
  );
}

/// v1.119-live (D395): a match of [players] hosts (2–4), TEAMS or
/// FREE_FOR_ALL, placed as the server's seat plan does — TEAMS: 2 → places 1
/// and 3, 3 → 1, 2 (team A) and 3 (team B); FREE_FOR_ALL: 2 → 1 and 3, 3 →
/// 1, 2, 3, 4 → 1–4. room-N is the host at index N (room-0 «this room»).
/// [results]: the hosts' results at the end (with [places] for FFA).
Pk4Match pk4PlayersFixture({
  required DateTime now,
  required int players,
  bool ffa = false,
  bool ar = true,
  PkMatchStatus status = PkMatchStatus.battle,
  List<int> scores = const [53200, 12400, 50300, 13000],
  List<Pk4Result?> results = const [],
  List<int?> places = const [],
  Pk4Team? winner,
  PkType type = PkType.normal,
  Pk4Dare? dare,
  Pk4Rematch? rematch,
  List<int> out = const [],
}) {
  String n(String a, String e) => ar ? a : e;
  final names = [
    n('سارة', 'Sara'),
    n('ليلى', 'Layla'),
    n('كريم', 'Karim'),
    n('زياد', 'Ziad'),
  ];
  final seatNumbers = switch (players) {
    2 => [1, 3],
    3 => [1, 2, 3],
    _ => [1, 2, 3, 4],
  };
  final ended = status == PkMatchStatus.result;
  final seats = [
    for (final (i, seat) in seatNumbers.indexed)
      Pk4Seat(
        seat: seat,
        roomId: 'room-$i',
        host: pk4User('user-$i', names[i]),
        score: scores[i],
        out: out.contains(i),
        outReason: out.contains(i) ? PkEndReason.forfeit : null,
        pkPoints: 12,
        place: ended && i < places.length ? places[i] : null,
        result: ended && i < results.length ? results[i] : null,
        supporters: ffa
            ? [
                PkSupporter(
                  user: pk4User('fan-$i', n('نور', 'Nour')),
                  points: 900 - i * 100,
                ),
              ]
            : const [],
      ),
  ];
  String? teamResult(Pk4Team t) => !ended || ffa
      ? null
      : winner == null
      ? 'DRAW'
      : winner == t
      ? 'WIN'
      : 'LOSS';
  int sum(Pk4Team t) =>
      seats.where((s) => s.team == t).fold(0, (a, s) => a + s.score);
  return Pk4Match(
    id: 'pk4-match-$players-${ffa ? 'ffa' : 'teams'}',
    status: status,
    startedAt: now.subtract(const Duration(minutes: 2, seconds: 15)),
    battleEndsAt: now.add(const Duration(minutes: 2, seconds: 45)),
    resultEndsAt: ended ? now.add(const Duration(seconds: 50)) : null,
    endReason: ended ? PkEndReason.time : null,
    winnerTeam: ended && !ffa ? winner : null,
    seq: 5,
    serverTime: now,
    organiserRoomId: 'room-0',
    format: ffa ? Pk4Format.freeForAll : Pk4Format.teams,
    type: type,
    teams: (
      Pk4TeamState(
        team: Pk4Team.a,
        score: sum(Pk4Team.a),
        result: teamResult(Pk4Team.a),
        supporters: ffa
            ? const []
            : [
                PkSupporter(
                  user: pk4User('fan-a', n('هند', 'Hind')),
                  points: 9000,
                ),
              ],
      ),
      Pk4TeamState(
        team: Pk4Team.b,
        score: sum(Pk4Team.b),
        result: teamResult(Pk4Team.b),
        supporters: ffa
            ? const []
            : [
                PkSupporter(
                  user: pk4User('fan-b', n('عمر', 'Omar')),
                  points: 7000,
                ),
              ],
      ),
    ),
    seats: seats,
    dare: dare,
    rematch: rematch,
  );
}

/// v1.119-live (D395): a lobby of [format] organised by room-0 with places
/// 2–4 in [states].
Pk4Lobby pk4LobbyFormatFixture({
  required DateTime now,
  Pk4Format format = Pk4Format.teams,
  bool ar = true,
  List<Pk4SeatState> states = const [
    Pk4SeatState.accepted,
    Pk4SeatState.invited,
    Pk4SeatState.empty,
  ],
}) {
  final base = pk4LobbyFixture(now: now, ar: ar, states: states);
  return Pk4Lobby(
    id: base.id,
    status: base.status,
    organiserRoomId: base.organiserRoomId,
    expiresAt: base.expiresAt,
    serverTime: base.serverTime,
    seats: base.seats,
    format: format,
  );
}
