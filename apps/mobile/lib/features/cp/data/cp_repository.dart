import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// CP couples (docs/contracts/openapi.yaml v1.21-live DRAFT, tag `cp`,
/// CP-018; CONVENTIONS §10.21) and the CP space (v1.24-live, CP-021,
/// §10.24). A request costs coins (refunded unless
/// accepted) and gifts cost coins; both carry a `clientId` (§3).
///
/// Every method throws an `AppFailure`.
abstract interface class CpRepository {
  /// `GET /cp/config`.
  Future<CpConfig> config();

  /// `POST /cp/requests` (99 coins). Returns the request and the balance.
  Future<({CpRequest request, int coins})> sendRequest({
    required String username,
    required String clientId,
  });

  /// `GET /cp/requests?direction=` (pending, newest first).
  Future<CpRequestPage> requests(CpDirection direction, {String? cursor});

  /// `DELETE /cp/requests/{requestId}` (the sender; refunded).
  Future<void> cancelRequest(String requestId);

  /// `POST /cp/requests/{requestId}/accept` (the receiver).
  Future<CpCouple> acceptRequest(String requestId);

  /// `POST /cp/requests/{requestId}/decline` (the receiver).
  Future<void> declineRequest(String requestId);

  /// `GET /cp/me`: the caller's couple, or null.
  Future<CpCouple?> mine();

  /// `DELETE /cp/me` (no refund).
  Future<void> end();

  /// `POST /cp/me/gifts`. Returns the gift, the couple after it and the
  /// balance.
  Future<({CpGift gift, CpCouple cp, int coins})> sendGift({
    required int amount,
    required String clientId,
  });

  // ---- CP-021 the CP space (v1.24-live, §10.24) --------------------------

  /// `GET /cp/me/tasks`: today's tasks (409 `CP_NOT_PAIRED`).
  Future<CpTasks> tasks();

  /// `POST /cp/me/check-in` (201 now, 200 already today): today's tasks.
  Future<CpTasks> checkIn();

  /// `POST /cp/me/tasks/{code}/claim` (201, or 200 when either partner
  /// claimed it today); 409 `CP_TASK_NOT_COMPLETED` when not done.
  Future<CpTaskClaim> claimTask(String code);

  /// `GET /cp/me/privileges`.
  Future<CpPrivileges> privileges();

  /// `GET /cp/me/confessions` (newest first; 409 when not paired).
  Future<CpConfessionPage> myConfessions({String? cursor});

  /// `POST /cp/me/confessions` (a retry with [clientId] answers the first).
  Future<CpConfession> createConfession({
    required String text,
    required String clientId,
  });

  /// `DELETE /cp/me/confessions/{confessionId}` (either partner).
  Future<void> deleteConfession(String confessionId);

  /// `POST /reports` with `targetType: CP_CONFESSION`.
  Future<void> reportConfession(String confessionId, ReportReason reason);

  /// `GET /cp/rankings?period=`.
  Future<CpRankings> rankings(CpRankingPeriod period, {String? cursor});

  /// `GET /cp/couples/{coupleId}` (404 when it cannot be shown).
  Future<CpCouplePublic> publicCouple(String coupleId);

  /// `GET /cp/couples/{coupleId}/gift-wall` (403 `CP_PRIVILEGE_LOCKED` for
  /// others before `GIFT_WALL`).
  Future<CpGiftWall> giftWall(String coupleId, {String? cursor});

  /// `GET /cp/couples/{coupleId}/confessions`.
  Future<CpConfessionPage> coupleConfessions(String coupleId, {String? cursor});
}

class CpRepositoryImpl implements CpRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<CpConfig> config() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/cp/config');
    return CpConfig.fromJson(res.data!);
  });

  @override
  Future<({CpRequest request, int coins})> sendRequest({
    required String username,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cp/requests',
      data: {'username': username, 'clientId': clientId},
    );
    final body = res.data!;
    return (
      request: CpRequest.fromJson(body['request']! as Map<String, dynamic>),
      coins: (body['coins']! as num).toInt(),
    );
  });

  @override
  Future<CpRequestPage> requests(CpDirection direction, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/cp/requests',
          queryParameters: {'direction': direction.name, 'cursor': ?cursor},
        );
        return CpRequestPage.fromJson(res.data!);
      });

  @override
  Future<void> cancelRequest(String requestId) => guardApiCall(() async {
    await _dio.delete<void>('/cp/requests/${pathSegment(requestId)}');
  });

  @override
  Future<CpCouple> acceptRequest(String requestId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cp/requests/${pathSegment(requestId)}/accept',
    );
    return CpCouple.fromJson(res.data!);
  });

  @override
  Future<void> declineRequest(String requestId) => guardApiCall(() async {
    await _dio.post<void>('/cp/requests/${pathSegment(requestId)}/decline');
  });

  @override
  Future<CpCouple?> mine() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/cp/me');
    return switch (res.data!['cp']) {
      final Map<String, dynamic> cp => CpCouple.fromJson(cp),
      _ => null,
    };
  });

  @override
  Future<void> end() => guardApiCall(() async {
    await _dio.delete<void>('/cp/me');
  });

  @override
  Future<({CpGift gift, CpCouple cp, int coins})> sendGift({
    required int amount,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cp/me/gifts',
      data: {'amount': amount, 'clientId': clientId},
    );
    final body = res.data!;
    return (
      gift: CpGift.fromJson(body['gift']! as Map<String, dynamic>),
      cp: CpCouple.fromJson(body['cp']! as Map<String, dynamic>),
      coins: (body['coins']! as num).toInt(),
    );
  });

  @override
  Future<CpTasks> tasks() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/cp/me/tasks');
    return CpTasks.fromJson(res.data!);
  });

  @override
  Future<CpTasks> checkIn() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>('/cp/me/check-in');
    return CpTasks.fromJson(res.data!);
  });

  @override
  Future<CpTaskClaim> claimTask(String code) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cp/me/tasks/${pathSegment(code)}/claim',
    );
    final body = res.data!;
    return (
      task: CpTask.fromJson(body['task']! as Map<String, dynamic>),
      cp: CpCouple.fromJson(body['cp']! as Map<String, dynamic>),
      added: res.statusCode == 201,
    );
  });

  @override
  Future<CpPrivileges> privileges() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/cp/me/privileges');
    return CpPrivileges.fromJson(res.data!);
  });

  @override
  Future<CpConfessionPage> myConfessions({String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/cp/me/confessions',
          queryParameters: {'cursor': ?cursor},
        );
        return CpConfessionPage.fromJson(res.data!);
      });

  @override
  Future<CpConfession> createConfession({
    required String text,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/cp/me/confessions',
      data: {'text': text, 'clientId': clientId},
    );
    return CpConfession.fromJson(res.data!);
  });

  @override
  Future<void> deleteConfession(String confessionId) => guardApiCall(() async {
    await _dio.delete<void>('/cp/me/confessions/${pathSegment(confessionId)}');
  });

  @override
  Future<void> reportConfession(String confessionId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'CP_CONFESSION',
            'targetId': confessionId,
            'reason': reason.wire,
          },
        );
      });

  @override
  Future<CpRankings> rankings(CpRankingPeriod period, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/cp/rankings',
          queryParameters: {'period': period.wire, 'cursor': ?cursor},
        );
        return CpRankings.fromJson(res.data!);
      });

  @override
  Future<CpCouplePublic> publicCouple(String coupleId) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/cp/couples/${pathSegment(coupleId)}',
        );
        return CpCouplePublic.fromJson(res.data!);
      });

  @override
  Future<CpGiftWall> giftWall(String coupleId, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/cp/couples/${pathSegment(coupleId)}/gift-wall',
          queryParameters: {'cursor': ?cursor},
        );
        return CpGiftWall.fromJson(res.data!);
      });

  @override
  Future<CpConfessionPage> coupleConfessions(
    String coupleId, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cp/couples/${pathSegment(coupleId)}/confessions',
      queryParameters: {'cursor': ?cursor},
    );
    return CpConfessionPage.fromJson(res.data!);
  });
}

final cpRepositoryProvider = Provider<CpRepository>(
  (ref) => CpRepositoryImpl(ref.watch(apiDioProvider)),
);
