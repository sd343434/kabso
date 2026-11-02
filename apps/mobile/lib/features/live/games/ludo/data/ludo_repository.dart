import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_game.dart';

/// Ludo inside a live room (v1.45-live, D168, CONVENTIONS §10.42). Every
/// call is an intent; the server answers the whole game. Throws an
/// `AppFailure`.
abstract interface class LudoRepository {
  /// The room's game in its lobby or playing, or null.
  Future<LudoGame?> get(String roomId);

  /// The host opens a game: [quick] (2 pieces) or classic, 2 or 4 players.
  Future<LudoGame> create(
    String roomId, {
    required bool quick,
    required int players,
  });

  Future<LudoGame> takeSeat(String roomId, int seat);

  /// The seat's player leaves, or the host removes them.
  Future<LudoGame> leaveSeat(String roomId, int seat);

  Future<LudoGame> start(String roomId, int version);

  Future<LudoGame> roll(String roomId, int version);

  Future<LudoGame> move(String roomId, int version, int piece);

  Future<LudoGame> end(String roomId);
}

class LudoRepositoryImpl implements LudoRepository {
  new(this._dio);

  final Dio _dio;

  String _path(String roomId, [String rest = '']) =>
      '/live/rooms/${pathSegment(roomId)}/ludo$rest';

  Future<LudoGame> _post(String path, [Object? data]) => guardApiCall(
    () async {
      final res = await _dio.post<Map<String, dynamic>>(path, data: data);
      return LudoGame.fromJson(res.data!);
    },
  );

  @override
  Future<LudoGame?> get(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_path(roomId));
    return switch (res.data!['game']) {
      final Map<String, dynamic> game => LudoGame.fromJson(game),
      _ => null,
    };
  });

  @override
  Future<LudoGame> create(
    String roomId, {
    required bool quick,
    required int players,
  }) => _post(_path(roomId), {
    'mode': quick ? 'QUICK' : 'CLASSIC',
    'players': players,
  });

  @override
  Future<LudoGame> takeSeat(String roomId, int seat) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          _path(roomId, '/seats/$seat'),
        );
        return LudoGame.fromJson(res.data!);
      });

  @override
  Future<LudoGame> leaveSeat(String roomId, int seat) =>
      guardApiCall(() async {
        final res = await _dio.delete<Map<String, dynamic>>(
          _path(roomId, '/seats/$seat'),
        );
        return LudoGame.fromJson(res.data!);
      });

  @override
  Future<LudoGame> start(String roomId, int version) =>
      _post(_path(roomId, '/start'), {'version': version});

  @override
  Future<LudoGame> roll(String roomId, int version) =>
      _post(_path(roomId, '/roll'), {'version': version});

  @override
  Future<LudoGame> move(String roomId, int version, int piece) =>
      _post(_path(roomId, '/move'), {'version': version, 'piece': piece});

  @override
  Future<LudoGame> end(String roomId) => _post(_path(roomId, '/end'));
}

final ludoRepositoryProvider = Provider<LudoRepository>(
  (ref) => LudoRepositoryImpl(ref.watch(apiDioProvider)),
);
