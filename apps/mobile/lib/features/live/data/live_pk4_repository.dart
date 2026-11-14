import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';

/// «PK رباعي» (v1.118-live, D391, CONVENTIONS §10.180). Every method throws an
/// `AppFailure` (the PK codes are read from `ServerFailure.rawCode`).
abstract interface class LivePk4Repository {
  /// `GET /live/rooms/{roomId}/pk4`: the match; the host's lobby and invitation.
  Future<Pk4State> state(String roomId);

  /// `GET /live/rooms/{roomId}/pk4/candidates?q&friends`.
  Future<List<PkCandidate>> candidates(
    String roomId, {
    String? query,
    bool friends = false,
  });

  /// `POST /live/rooms/{roomId}/pk4/lobby` `{format, type}` (v1.119-live:
  /// FREE_FOR_ALL and «PK أحكام» too).
  Future<Pk4Lobby> openLobby(
    String roomId, {
    Pk4Format format = Pk4Format.teams,
    PkType type = PkType.normal,
  });

  /// v1.119-live (D395) `POST /live/rooms/{roomId}/pk4/lobby/start`
  /// «ابدأ الآن»: the organiser starts with the hosts in.
  Future<Pk4State> startLobby(String roomId);

  /// v1.119-live (D395) `POST /live/rooms/{roomId}/pk4/random` (four only).
  Future<Pk4RandomResult> joinRandom(
    String roomId, {
    required Pk4Format format,
    PkType type = PkType.normal,
  });

  /// v1.119-live (D395) `DELETE /live/rooms/{roomId}/pk4/random`.
  Future<void> leaveRandom(String roomId);

  /// v1.119-live (D395) «PK أحكام» for four.
  Future<Pk4Match> acceptDare(String roomId);
  Future<Pk4Match> refuseDare(String roomId);
  Future<Pk4Match> judgeDare(String roomId, {required bool done});
  Future<void> reportDare(String roomId, String dareId);

  /// v1.119-live (D395) «جولة أخرى» for four.
  Future<Pk4Match> offerRematch(String roomId);
  Future<Pk4Match> acceptRematch(String roomId);
  Future<void> declineRematch(String roomId);
  Future<Pk4Match> cancelRematch(String roomId);

  /// `DELETE /live/rooms/{roomId}/pk4/lobby`: cancel (organiser) or leave.
  Future<void> closeLobby(String roomId);

  /// `POST /live/rooms/{roomId}/pk4/lobby/invites` `{toRoomId, seat}`.
  Future<Pk4Lobby> invite(
    String roomId, {
    required String toRoomId,
    required int seat,
  });

  /// `DELETE /live/rooms/{roomId}/pk4/lobby/invites/{inviteId}`.
  Future<void> cancelInvite(String roomId, String inviteId);

  /// `POST /live/rooms/{roomId}/pk4/invites/{inviteId}/accept`.
  Future<Pk4State> accept(String roomId, String inviteId);

  /// `POST /live/rooms/{roomId}/pk4/invites/{inviteId}/decline`.
  Future<void> decline(String roomId, String inviteId);

  /// `POST /live/rooms/{roomId}/pk4/start`.
  Future<Pk4Match> start(String roomId);

  /// `POST /live/rooms/{roomId}/pk4/end`.
  Future<Pk4Match> end(String roomId);

  /// `POST /live/rooms/{roomId}/pk4/mute` `{roomId, muted}`.
  Future<Pk4Match> mute(
    String roomId, {
    required String otherRoomId,
    required bool muted,
  });

  /// `POST /live/rooms/{roomId}/pk4/media-token`: the three other rooms.
  Future<Pk4MediaAccess> mediaToken(String roomId, {String? guestId});
}

class LivePk4RepositoryImpl implements LivePk4Repository {
  new(this._dio);

  final Dio _dio;

  String _room(String roomId) => '/live/rooms/${pathSegment(roomId)}/pk4';

  @override
  Future<Pk4State> state(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_room(roomId));
    return Pk4State.fromJson(res.data!);
  });

  @override
  Future<List<PkCandidate>> candidates(
    String roomId, {
    String? query,
    bool friends = false,
  }) => guardApiCall(() async {
    final q = query?.trim();
    final res = await _dio.get<Map<String, dynamic>>(
      '${_room(roomId)}/candidates',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (friends) 'friends': 'true',
      },
    );
    return [
      for (final c in res.data!['data']! as List<dynamic>)
        PkCandidate.fromJson(c as Map<String, dynamic>),
    ];
  });

  @override
  Future<Pk4Lobby> openLobby(
    String roomId, {
    Pk4Format format = Pk4Format.teams,
    PkType type = PkType.normal,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/lobby',
      data: {
        'format': format.wire,
        if (type != PkType.normal) 'type': type.wire,
      },
    );
    return Pk4Lobby.fromJson(res.data!);
  });

  @override
  Future<Pk4State> startLobby(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/lobby/start',
    );
    return Pk4State.fromJson(res.data!);
  });

  @override
  Future<Pk4RandomResult> joinRandom(
    String roomId, {
    required Pk4Format format,
    PkType type = PkType.normal,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/random',
      data: {
        'format': format.wire,
        if (type != PkType.normal) 'type': type.wire,
      },
    );
    return Pk4RandomResult.fromJson(res.data!);
  });

  @override
  Future<void> leaveRandom(String roomId) => guardApiCall(() async {
    await _dio.delete<void>('${_room(roomId)}/random');
  });

  Future<Pk4Match> _post(String roomId, String path, [Object? data]) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/$path',
          data: data,
        );
        return Pk4Match.fromJson(res.data!);
      });

  @override
  Future<Pk4Match> acceptDare(String roomId) => _post(roomId, 'dare/accept');

  @override
  Future<Pk4Match> refuseDare(String roomId) => _post(roomId, 'dare/refuse');

  @override
  Future<Pk4Match> judgeDare(String roomId, {required bool done}) =>
      _post(roomId, 'dare/verdict', {'done': done});

  @override
  Future<void> reportDare(String roomId, String dareId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_room(roomId)}/dare/report',
          data: {'dareId': dareId},
        );
      });

  @override
  Future<Pk4Match> offerRematch(String roomId) => _post(roomId, 'rematch');

  @override
  Future<Pk4Match> acceptRematch(String roomId) =>
      _post(roomId, 'rematch/accept');

  @override
  Future<void> declineRematch(String roomId) => guardApiCall(() async {
    await _dio.post<void>('${_room(roomId)}/rematch/decline');
  });

  @override
  Future<Pk4Match> cancelRematch(String roomId) => guardApiCall(() async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '${_room(roomId)}/rematch',
    );
    return Pk4Match.fromJson(res.data!);
  });

  @override
  Future<void> closeLobby(String roomId) => guardApiCall(() async {
    await _dio.delete<void>('${_room(roomId)}/lobby');
  });

  @override
  Future<Pk4Lobby> invite(
    String roomId, {
    required String toRoomId,
    required int seat,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/lobby/invites',
      data: {'toRoomId': toRoomId, 'seat': seat},
    );
    return Pk4Lobby.fromJson(res.data!);
  });

  @override
  Future<void> cancelInvite(String roomId, String inviteId) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_room(roomId)}/lobby/invites/${pathSegment(inviteId)}',
        );
      });

  @override
  Future<Pk4State> accept(String roomId, String inviteId) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/invites/${pathSegment(inviteId)}/accept',
        );
        return Pk4State.fromJson(res.data!);
      });

  @override
  Future<void> decline(String roomId, String inviteId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_room(roomId)}/invites/${pathSegment(inviteId)}/decline',
        );
      });

  @override
  Future<Pk4Match> start(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('${_room(roomId)}/start');
    return Pk4Match.fromJson(res.data!);
  });

  @override
  Future<Pk4Match> end(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('${_room(roomId)}/end');
    return Pk4Match.fromJson(res.data!);
  });

  @override
  Future<Pk4Match> mute(
    String roomId, {
    required String otherRoomId,
    required bool muted,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/mute',
      data: {'roomId': otherRoomId, 'muted': muted},
    );
    return Pk4Match.fromJson(res.data!);
  });

  @override
  Future<Pk4MediaAccess> mediaToken(String roomId, {String? guestId}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/media-token',
          data: {'guestId': ?guestId},
        );
        return Pk4MediaAccess.fromJson(res.data!);
      });
}

final livePk4RepositoryProvider = Provider<LivePk4Repository>(
  (ref) => LivePk4RepositoryImpl(ref.watch(apiDioProvider)),
);
