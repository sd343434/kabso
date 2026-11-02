import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';

/// PK 1 v 1 (v1.43-live, D195, CONVENTIONS §10.58). Every method throws an
/// `AppFailure` (the PK codes are read from `ServerFailure.rawCode`).
abstract interface class LivePkRepository {
  /// `GET /live/rooms/{roomId}/pk`: the snapshot (host: invitation and queue).
  Future<PkState> state(String roomId);

  /// `GET /live/rooms/{roomId}/pk/candidates?q&friends`: hosts to invite
  /// (D199: [friends] keeps only mutual follows).
  Future<List<PkCandidate>> candidates(
    String roomId, {
    String? query,
    bool friends = false,
  });

  /// `POST /live/rooms/{roomId}/pk/invites`.
  /// v1.50-live (D229): [type] «PK أحكام» or the normal PK.
  Future<PkInvite> invite(
    String roomId, {
    required String toRoomId,
    PkType type = PkType.normal,
  });

  /// `DELETE /live/rooms/{roomId}/pk/invites/{inviteId}`.
  Future<void> cancelInvite(String roomId, String inviteId);

  /// `POST …/invites/{inviteId}/accept`: the battle starts.
  Future<PkMatch> accept(String roomId, String inviteId);

  /// `POST …/invites/{inviteId}/decline`.
  Future<void> decline(String roomId, String inviteId);

  /// `POST /live/rooms/{roomId}/pk/random`: waiting until, or the match.
  Future<({DateTime? waitingUntil, PkMatch? match})> joinRandom(
    String roomId, {
    PkType type = PkType.normal,
  });

  /// `DELETE /live/rooms/{roomId}/pk/random`.
  Future<void> leaveRandom(String roomId);

  /// `POST /live/rooms/{roomId}/pk/end`: a forfeit during the battle.
  Future<PkMatch> end(String roomId);

  /// `POST /live/rooms/{roomId}/pk/mute-opponent`.
  Future<PkMatch> muteOpponent(String roomId, {required bool muted});

  /// `POST /live/rooms/{roomId}/pk/media-token`: the other room, watch-only.
  Future<PkMediaAccess> mediaToken(String roomId, {String? guestId});

  /// `GET /live/pk/hosts/{username}`: the host's record.
  Future<PkRecord> record(String username);

  /// `PUT /me/live-pk`: invitations on / off.
  Future<bool> setInvitesEnabled({required bool enabled});

  /// v1.44-live (D199) `GET /me/live-pk`: the PK Setting page.
  Future<PkSettings> settings();

  /// v1.44-live (D199) `PUT /me/live-pk`: any of the page's fields.
  Future<PkSettings> saveSettings(Map<String, Object> changes);

  /// v1.44-live (D199) `POST /live/rooms/{roomId}/pk/start`.
  Future<PkMatch> start(String roomId);

  /// v1.44-live (D199) `GET /live/pk/hosts/{username}`: record and history.
  Future<PkHistory> history(String username);

  /// v1.50-live (D229): the losing host accepts / refuses the drawn dare.
  Future<PkMatch> acceptDare(String roomId);

  Future<PkMatch> refuseDare(String roomId);

  /// The winning host's verdict during the timer.
  Future<PkMatch> judgeDare(String roomId, {required bool done});

  /// A viewer's (or host's) report of one of the room's dares.
  Future<void> reportDare(String roomId, String dareId);
}

class LivePkRepositoryImpl implements LivePkRepository {
  new(this._dio);

  final Dio _dio;

  String _room(String roomId) => '/live/rooms/${pathSegment(roomId)}/pk';

  @override
  Future<PkState> state(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_room(roomId));
    return PkState.fromJson(res.data!);
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
  Future<PkInvite> invite(
    String roomId, {
    required String toRoomId,
    PkType type = PkType.normal,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/invites',
      data: {
        'toRoomId': toRoomId,
        if (type != PkType.normal) 'type': type.wire,
      },
    );
    return PkInvite.fromJson(res.data!);
  });

  @override
  Future<void> cancelInvite(String roomId, String inviteId) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_room(roomId)}/invites/${pathSegment(inviteId)}',
        );
      });

  @override
  Future<PkMatch> accept(String roomId, String inviteId) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/invites/${pathSegment(inviteId)}/accept',
        );
        return PkMatch.fromJson(res.data!);
      });

  @override
  Future<void> decline(String roomId, String inviteId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_room(roomId)}/invites/${pathSegment(inviteId)}/decline',
        );
      });

  @override
  Future<({DateTime? waitingUntil, PkMatch? match})> joinRandom(
    String roomId, {
    PkType type = PkType.normal,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/random',
      data: {if (type != PkType.normal) 'type': type.wire},
    );
    final body = res.data!;
    final queue = body['queue'];
    return (
      waitingUntil: queue is Map
          ? DateTime.tryParse(queue['expiresAt'] as String? ?? '')
          : null,
      match: body['match'] == null
          ? null
          : PkMatch.fromJson(body['match']! as Map<String, dynamic>),
    );
  });

  @override
  Future<void> leaveRandom(String roomId) => guardApiCall(() async {
    await _dio.delete<void>('${_room(roomId)}/random');
  });

  @override
  Future<PkMatch> end(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('${_room(roomId)}/end');
    return PkMatch.fromJson(res.data!);
  });

  @override
  Future<PkMatch> muteOpponent(String roomId, {required bool muted}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/mute-opponent',
          data: {'muted': muted},
        );
        return PkMatch.fromJson(res.data!);
      });

  @override
  Future<PkMediaAccess> mediaToken(String roomId, {String? guestId}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/media-token',
          data: {'guestId': ?guestId},
        );
        return PkMediaAccess.fromJson(res.data!);
      });

  @override
  Future<PkRecord> record(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/pk/hosts/${pathSegment(username)}',
    );
    return PkRecord.fromJson(res.data!['record']! as Map<String, dynamic>);
  });

  @override
  Future<bool> setInvitesEnabled({required bool enabled}) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/live-pk',
          data: {'invitesEnabled': enabled},
        );
        return res.data!['invitesEnabled'] == true;
      });

  @override
  Future<PkSettings> settings() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/live-pk');
    return PkSettings.fromJson(res.data!);
  });

  @override
  Future<PkSettings> saveSettings(Map<String, Object> changes) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/live-pk',
          data: changes,
        );
        return PkSettings.fromJson(res.data!);
      });

  @override
  Future<PkMatch> start(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('${_room(roomId)}/start');
    return PkMatch.fromJson(res.data!);
  });

  @override
  Future<PkHistory> history(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/pk/hosts/${pathSegment(username)}',
    );
    return PkHistory.fromJson(res.data!);
  });

  @override
  Future<PkMatch> acceptDare(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/dare/accept',
    );
    return PkMatch.fromJson(res.data!);
  });

  @override
  Future<PkMatch> refuseDare(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/dare/refuse',
    );
    return PkMatch.fromJson(res.data!);
  });

  @override
  Future<PkMatch> judgeDare(String roomId, {required bool done}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/dare/verdict',
          data: {'done': done},
        );
        return PkMatch.fromJson(res.data!);
      });

  @override
  Future<void> reportDare(String roomId, String dareId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_room(roomId)}/dare/report',
          data: {'dareId': dareId},
        );
      });
}

final livePkRepositoryProvider = Provider<LivePkRepository>(
  (ref) => LivePkRepositoryImpl(ref.watch(apiDioProvider)),
);

/// A host's PK record (profile), or null while unknown / on failure.
final FutureProviderFamily<PkRecord?, String> livePkRecordProvider =
    FutureProvider.autoDispose.family<PkRecord?, String>((ref, username) async {
      try {
        return await ref.read(livePkRepositoryProvider).record(username);
      } on Object {
        return null;
      }
    });
