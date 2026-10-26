import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';

/// Families (docs/contracts/openapi.yaml v1.21-live DRAFT, tag `families`,
/// CP-018; CONVENTIONS §10.21). Creating one costs coins (`clientId`
/// idempotency, §3); the rest is membership.
///
/// Every method throws an `AppFailure`.
abstract interface class FamiliesRepository {
  /// `GET /families/config`.
  Future<FamilyConfig> config();

  /// `GET /families?q=`: by points, highest first; [query] a name
  /// fragment or digits that also match the number.
  Future<FamilyCardPage> search({String? query, String? cursor});

  /// `POST /families` (500 coins). Returns the family and the balance.
  Future<({Family family, int coins})> create({
    required String name,
    required String clientId,
    String? emblemMediaId,
  });

  /// `GET /families/me`: the caller's family, or null.
  Future<Family?> mine();

  /// `GET /families/{familyId}`.
  Future<Family> get(String familyId);

  /// `GET /family-numbers/{number}`.
  Future<Family> byNumber(String number);

  /// `PATCH /families/{familyId}` (leader): set or remove the emblem.
  Future<Family> setEmblem(String familyId, String? emblemMediaId);

  /// `DELETE /families/{familyId}` (leader, only them left).
  Future<void> disband(String familyId);

  /// `GET /families/{familyId}/members`: leader, deputies, members.
  Future<FamilyMemberPage> members(String familyId, {String? cursor});

  /// `DELETE /families/{familyId}/members/{username}` (leader).
  Future<void> removeMember(String familyId, String username);

  /// `PUT /families/{familyId}/members/{username}/role` (leader).
  Future<FamilyMember> setRole(
    String familyId,
    String username,
    FamilyRole role,
  );

  /// `POST /families/{familyId}/transfer` (leader).
  Future<Family> transfer(String familyId, String username);

  /// `POST /families/{familyId}/leave` (not the leader).
  Future<void> leave(String familyId);

  /// `POST /families/{familyId}/join-requests` (201, or 200 when the
  /// caller already asked this family).
  Future<FamilyJoinRequest> requestToJoin(String familyId);

  /// `GET /families/{familyId}/join-requests` (leader and deputies).
  Future<FamilyJoinRequestPage> joinRequests(String familyId, {String? cursor});

  /// `POST …/join-requests/{requestId}/accept`.
  Future<FamilyMember> acceptRequest(String familyId, String requestId);

  /// `POST …/join-requests/{requestId}/decline`.
  Future<void> declineRequest(String familyId, String requestId);

  /// `GET /me/family-join-request`: the caller's pending request, or null.
  Future<FamilyJoinRequest?> myRequest();

  /// `DELETE /me/family-join-request` (idempotent).
  Future<void> cancelMyRequest();
}

class FamiliesRepositoryImpl implements FamiliesRepository {
  new(this._dio);

  final Dio _dio;

  static String _family(String id) => '/families/${pathSegment(id)}';

  @override
  Future<FamilyConfig> config() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/families/config');
    return FamilyConfig.fromJson(res.data!);
  });

  @override
  Future<FamilyCardPage> search({String? query, String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/families',
          queryParameters: {
            if (query != null && query.isNotEmpty) 'q': query,
            'cursor': ?cursor,
          },
        );
        return FamilyCardPage.fromJson(res.data!);
      });

  @override
  Future<({Family family, int coins})> create({
    required String name,
    required String clientId,
    String? emblemMediaId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/families',
      data: {
        'name': name,
        'clientId': clientId,
        'emblemMediaId': ?emblemMediaId,
      },
    );
    final body = res.data!;
    return (
      family: Family.fromJson(body['family']! as Map<String, dynamic>),
      coins: (body['coins']! as num).toInt(),
    );
  });

  @override
  Future<Family?> mine() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/families/me');
    return switch (res.data!['family']) {
      final Map<String, dynamic> f => Family.fromJson(f),
      _ => null,
    };
  });

  @override
  Future<Family> get(String familyId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_family(familyId));
    return Family.fromJson(res.data!);
  });

  @override
  Future<Family> byNumber(String number) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/family-numbers/${pathSegment(number)}',
    );
    return Family.fromJson(res.data!);
  });

  @override
  Future<Family> setEmblem(String familyId, String? emblemMediaId) =>
      guardApiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          _family(familyId),
          data: {'emblemMediaId': emblemMediaId},
        );
        return Family.fromJson(res.data!);
      });

  @override
  Future<void> disband(String familyId) => guardApiCall(() async {
    await _dio.delete<void>(_family(familyId));
  });

  @override
  Future<FamilyMemberPage> members(String familyId, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_family(familyId)}/members',
          queryParameters: {'cursor': ?cursor},
        );
        return FamilyMemberPage.fromJson(res.data!);
      });

  @override
  Future<void> removeMember(String familyId, String username) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_family(familyId)}/members/${pathSegment(username)}',
        );
      });

  @override
  Future<FamilyMember> setRole(
    String familyId,
    String username,
    FamilyRole role,
  ) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '${_family(familyId)}/members/${pathSegment(username)}/role',
      data: {'role': role.wire},
    );
    return FamilyMember.fromJson(res.data!);
  });

  @override
  Future<Family> transfer(String familyId, String username) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_family(familyId)}/transfer',
          data: {'username': username},
        );
        return Family.fromJson(res.data!);
      });

  @override
  Future<void> leave(String familyId) => guardApiCall(() async {
    await _dio.post<void>('${_family(familyId)}/leave');
  });

  @override
  Future<FamilyJoinRequest> requestToJoin(String familyId) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_family(familyId)}/join-requests',
        );
        return FamilyJoinRequest.fromJson(res.data!);
      });

  @override
  Future<FamilyJoinRequestPage> joinRequests(
    String familyId, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_family(familyId)}/join-requests',
      queryParameters: {'cursor': ?cursor},
    );
    return FamilyJoinRequestPage.fromJson(res.data!);
  });

  @override
  Future<FamilyMember> acceptRequest(String familyId, String requestId) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_family(familyId)}/join-requests/${pathSegment(requestId)}/accept',
        );
        return FamilyMember.fromJson(res.data!);
      });

  @override
  Future<void> declineRequest(
    String familyId,
    String requestId,
  ) => guardApiCall(() async {
    await _dio.post<void>(
      '${_family(familyId)}/join-requests/${pathSegment(requestId)}/decline',
    );
  });

  @override
  Future<FamilyJoinRequest?> myRequest() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/family-join-request');
    return switch (res.data!['request']) {
      final Map<String, dynamic> r => FamilyJoinRequest.fromJson(r),
      _ => null,
    };
  });

  @override
  Future<void> cancelMyRequest() => guardApiCall(() async {
    await _dio.delete<void>('/me/family-join-request');
  });
}

final familiesRepositoryProvider = Provider<FamiliesRepository>(
  (ref) => FamiliesRepositoryImpl(ref.watch(apiDioProvider)),
);
