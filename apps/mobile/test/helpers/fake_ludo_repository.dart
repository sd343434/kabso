// In-memory Ludo (D168, tests only): no game unless a test sets one; every
// intent is recorded and answered with [next] when set.

import 'package:kabso_live/features/live/games/ludo/data/ludo_repository.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_game.dart';

class FakeLudoRepository implements LudoRepository {
  new({this.game});

  /// What `get` answers.
  LudoGame? game;

  /// What the next intent answers (else [game]).
  LudoGame? next;

  final calls = <String>[];

  Future<LudoGame> _answer(String call) async {
    calls.add(call);
    final answer = next ?? game;
    if (answer == null) throw StateError('no game');
    game = answer;
    return answer;
  }

  @override
  Future<LudoGame?> get(String roomId) async => game;

  @override
  Future<LudoGame> create(
    String roomId, {
    required bool quick,
    required int players,
  }) => _answer('create ${quick ? 'QUICK' : 'CLASSIC'} $players');

  @override
  Future<LudoGame> takeSeat(String roomId, int seat) => _answer('seat $seat');

  @override
  Future<LudoGame> leaveSeat(String roomId, int seat) => _answer('leave $seat');

  @override
  Future<LudoGame> start(String roomId, int version) =>
      _answer('start $version');

  @override
  Future<LudoGame> roll(String roomId, int version) => _answer('roll $version');

  @override
  Future<LudoGame> move(String roomId, int version, int piece) =>
      _answer('move $version $piece');

  @override
  Future<LudoGame> end(String roomId) => _answer('end');
}
