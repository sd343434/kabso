import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';

/// CP couples (docs/contracts/openapi.yaml v1.21-live DRAFT, tag `cp`,
/// CP-018; CONVENTIONS §10.21). A request costs coins (refunded unless
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
}

final cpRepositoryProvider = Provider<CpRepository>(
  (ref) => CpRepositoryImpl(ref.watch(apiDioProvider)),
);
