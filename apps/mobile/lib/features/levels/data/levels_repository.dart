import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';

/// The caller's levels (docs/contracts/openapi.yaml v1.4-levels DRAFT,
/// tag `levels`, CP-005). Read-only: points and levels change only on the
/// server, from verified gifts and game spending.
///
/// Every method throws an `AppFailure`.
abstract interface class LevelsRepository {
  /// `GET /levels/me`: always the four categories, in display order.
  Future<List<LevelSummary>> getMyLevels();

  /// `GET /levels/me/{category}`: one category with its ladder.
  Future<LevelDetail> getMyLevel(LevelCategory category);

  /// `GET /users/{username}/levels`: another user's levels for their
  /// profile (no points).
  Future<List<PublicLevel>> getUserLevels(String username);
}

class LevelsRepositoryImpl implements LevelsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<List<LevelSummary>> getMyLevels() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/levels/me');
    return [
      for (final item in res.data!['data']! as List<dynamic>)
        LevelSummary.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<LevelDetail> getMyLevel(LevelCategory category) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/levels/me/${pathSegment(category.slug)}',
        );
        return LevelDetail.fromJson(res.data!);
      });

  @override
  Future<List<PublicLevel>> getUserLevels(String username) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/users/${pathSegment(username)}/levels',
        );
        return [
          for (final item in res.data!['data']! as List<dynamic>)
            PublicLevel.fromJson(item as Map<String, dynamic>),
        ];
      });
}

final levelsRepositoryProvider = Provider<LevelsRepository>(
  (ref) => LevelsRepositoryImpl(ref.watch(apiDioProvider)),
);
