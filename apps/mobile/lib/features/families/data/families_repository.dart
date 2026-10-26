import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;

/// Families (docs/contracts/openapi.yaml v1.21-live DRAFT, tag `families`,
/// CP-018; CONVENTIONS §10.21; v1.25-live, CP-022, §10.25). Creating one
/// costs coins (`clientId` idempotency, §3); the rest is membership, the
/// boards and the family chat.
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

  /// `GET /families/{familyId}/members`: leader, deputies, members; with
  /// [byPoints] (v1.25-live `sort=POINTS`) by points with `rank`; [query]
  /// keeps members whose username or name contains it.
  Future<FamilyMemberPage> members(
    String familyId, {
    String? cursor,
    bool byPoints = false,
    String? query,
  });

  /// `PATCH /families/{familyId}` (leader, v1.25-live): the cover
  /// ([coverMediaId], [removeCover]) and the tagline ([tagline]; `""`
  /// removes it). Only what is given changes.
  Future<Family> updateLook(
    String familyId, {
    String? coverMediaId,
    bool removeCover = false,
    String? tagline,
  });

  /// `GET /families/rankings?board=` (v1.25-live, top 100, paged).
  Future<FamilyRankings> rankings(FamilyRankingBoard board, {String? cursor});

  /// `GET /families/{familyId}/rankings`: the family on both boards.
  Future<FamilyStanding> standing(String familyId);

  /// `GET /families/{familyId}/contributions`: this month, most first.
  Future<FamilyContributions> contributions(String familyId, {String? cursor});

  /// `GET /families/{familyId}/chat`: newest first (members only).
  Future<FamilyChatPage> chat(String familyId, {String? cursor});

  /// `POST /families/{familyId}/chat` (201, or 200 for a retry).
  Future<FamilyChatMessage> sendChat(
    String familyId, {
    required String text,
    required String clientId,
  });

  /// `DELETE /families/{familyId}/chat/{messageId}`.
  Future<void> deleteChat(String familyId, String messageId);

  /// `PUT` / `DELETE /families/{familyId}/chat/mutes/{username}`.
  Future<void> setChatMuted(
    String familyId,
    String username, {
    required bool muted,
  });

  /// `POST /reports` for a family chat message.
  Future<void> reportChat(String messageId, ReportReason reason);

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
  Future<FamilyMemberPage> members(
    String familyId, {
    String? cursor,
    bool byPoints = false,
    String? query,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_family(familyId)}/members',
      queryParameters: {
        'cursor': ?cursor,
        if (byPoints) 'sort': 'POINTS',
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return FamilyMemberPage.fromJson(res.data!);
  });

  @override
  Future<Family> updateLook(
    String familyId, {
    String? coverMediaId,
    bool removeCover = false,
    String? tagline,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      _family(familyId),
      data: {
        if (removeCover)
          'coverMediaId': null
        else
          'coverMediaId': ?coverMediaId,
        'tagline': ?tagline,
      },
    );
    return Family.fromJson(res.data!);
  });

  @override
  Future<FamilyRankings> rankings(FamilyRankingBoard board, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/families/rankings',
          queryParameters: {'board': board.wire, 'cursor': ?cursor},
        );
        return FamilyRankings.fromJson(res.data!);
      });

  @override
  Future<FamilyStanding> standing(String familyId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_family(familyId)}/rankings',
    );
    return FamilyStanding.fromJson(res.data!);
  });

  @override
  Future<FamilyContributions> contributions(
    String familyId, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_family(familyId)}/contributions',
      queryParameters: {'cursor': ?cursor},
    );
    return FamilyContributions.fromJson(res.data!);
  });

  @override
  Future<FamilyChatPage> chat(String familyId, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_family(familyId)}/chat',
          queryParameters: {'cursor': ?cursor},
        );
        return FamilyChatPage.fromJson(res.data!);
      });

  @override
  Future<FamilyChatMessage> sendChat(
    String familyId, {
    required String text,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_family(familyId)}/chat',
      data: {'text': text, 'clientId': clientId},
    );
    return FamilyChatMessage.fromJson(res.data!);
  });

  @override
  Future<void> deleteChat(String familyId, String messageId) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_family(familyId)}/chat/${pathSegment(messageId)}',
        );
      });

  @override
  Future<void> setChatMuted(
    String familyId,
    String username, {
    required bool muted,
  }) => guardApiCall(() async {
    final path = '${_family(familyId)}/chat/mutes/${pathSegment(username)}';
    if (muted) {
      await _dio.put<void>(path);
    } else {
      await _dio.delete<void>(path);
    }
  });

  @override
  Future<void> reportChat(String messageId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'FAMILY_CHAT_MESSAGE',
            'targetId': messageId,
            'reason': reason.wire,
          },
        );
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
