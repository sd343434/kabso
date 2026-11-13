import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';

/// Medals (docs/contracts/openapi.yaml v1.21-live DRAFT, tag `medals`,
/// CP-018; CONVENTIONS §10.21). Medals are awarded by the server; the app
/// reads them and chooses the profile showcase.
///
/// Every method throws an `AppFailure`.
abstract interface class MedalsRepository {
  /// `GET /medals`: the catalogue with the caller's `awardedAt`.
  Future<MedalCatalogue> catalogue();

  /// `GET /users/{username}/medals`: a user's medals, newest first.
  Future<UserMedalList> userMedals(String username);

  /// `GET /me/medals/showcase`.
  Future<List<ProfileMedal>> showcase();

  /// `PUT /me/medals/showcase`: up to 6 unlocked codes, in order.
  Future<List<ProfileMedal>> setShowcase(List<String> medalCodes);
}

class MedalsRepositoryImpl implements MedalsRepository {
  new(this._dio);

  final Dio _dio;

  static List<ProfileMedal> _list(Map<String, dynamic> body) => [
    for (final m in body['showcase']! as List<dynamic>)
      ProfileMedal.fromJson(m as Map<String, dynamic>),
  ];

  @override
  Future<MedalCatalogue> catalogue() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/medals');
    return MedalCatalogue.fromJson(res.data!);
  });

  @override
  Future<UserMedalList> userMedals(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/medals',
    );
    return UserMedalList.fromJson(res.data!);
  });

  @override
  Future<List<ProfileMedal>> showcase() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/medals/showcase');
    return _list(res.data!);
  });

  @override
  Future<List<ProfileMedal>> setShowcase(List<String> medalCodes) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/medals/showcase',
          data: {'medalCodes': medalCodes},
        );
        return _list(res.data!);
      });
}

final medalsRepositoryProvider = Provider<MedalsRepository>(
  (ref) => MedalsRepositoryImpl(ref.watch(apiDioProvider)),
);
