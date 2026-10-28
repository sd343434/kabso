import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';

/// Premium usernames (docs/contracts/openapi.yaml v1.28-live DRAFT, tag
/// `premium-usernames`, D146; CONVENTIONS §10.32) and the username change.
///
/// Every method throws an `AppFailure`.
abstract interface class PremiumRepository {
  /// `GET /premium-usernames[?tier=]`.
  Future<PremiumStore> store({PremiumTier? tier});

  /// `GET /premium-usernames/{username}`: what [username] is for the
  /// caller (never 404).
  Future<PremiumNameStatus> status(String username);

  /// `GET /me/premium-username`: the caller's premium username, or null.
  Future<MyPremiumUsername?> mine();

  /// `POST /me/premium-username/rentals`: rent [username] (or renew one's
  /// own) at [priceCoins], the price the person agreed to. [idempotencyKey]
  /// is one UUID per tap (a retry sends the same one).
  Future<PremiumRental> rent({
    required String username,
    required int priceCoins,
    required String idempotencyKey,
  });

  /// `DELETE /me/premium-username`: give it back now (no refund).
  Future<void> release();

  /// `PUT /me/username`: a new regular username; the updated `Me`.
  Future<User> changeUsername(String username);
}

class PremiumRepositoryImpl implements PremiumRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<PremiumStore> store({PremiumTier? tier}) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/premium-usernames',
      queryParameters: tier == null ? null : {'tier': tier.wire},
    );
    return PremiumStore.fromJson(res.data!);
  });

  @override
  Future<PremiumNameStatus> status(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/premium-usernames/${pathSegment(username)}',
    );
    return PremiumNameStatus.fromJson(res.data!);
  });

  @override
  Future<MyPremiumUsername?> mine() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/premium-username');
    final premium = res.data!['premium'];
    return premium == null
        ? null
        : MyPremiumUsername.fromJson(premium as Map<String, dynamic>);
  });

  @override
  Future<PremiumRental> rent({
    required String username,
    required int priceCoins,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/premium-username/rentals',
      data: {'username': username, 'priceCoins': priceCoins},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final body = res.data!;
    return (
      premium: MyPremiumUsername.fromJson(
        body['premium']! as Map<String, dynamic>,
      ),
      coins: (body['coins']! as num).toInt(),
    );
  });

  @override
  Future<void> release() =>
      guardApiCall(() => _dio.delete<void>('/me/premium-username'));

  @override
  Future<User> changeUsername(String username) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/me/username',
      data: {'username': username},
    );
    return MeDto.fromJson(res.data!).toEntity();
  });
}

final premiumRepositoryProvider = Provider<PremiumRepository>(
  (ref) => PremiumRepositoryImpl(ref.watch(apiDioProvider)),
);
