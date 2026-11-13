import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

/// Public profiles and the follow graph (docs/contracts/openapi.yaml v1.3:
/// `getPublicProfile`, `followUser`, `unfollowUser`; CONVENTIONS
/// §10.5–10.6).
///
/// Every method throws an `AppFailure`.
abstract interface class ProfileRepository {
  /// `GET /users/{username}`. Unknown, malformed, suspended and deleted
  /// usernames all fail with `NOT_FOUND`.
  Future<PublicProfile> getProfile(String username);

  /// `PUT /users/{username}/follow` (idempotent).
  Future<FollowState> follow(String username);

  /// `DELETE /users/{username}/follow` (idempotent).
  Future<FollowState> unfollow(String username);
}

class ProfileRepositoryImpl implements ProfileRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<PublicProfile> getProfile(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}',
    );
    return PublicProfile.fromJson(res.data!);
  });

  @override
  Future<FollowState> follow(String username) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/follow',
    );
    return FollowState.fromJson(res.data!);
  });

  @override
  Future<FollowState> unfollow(String username) => guardApiCall(() async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/follow',
    );
    return FollowState.fromJson(res.data!);
  });
}

/// D86: test builds with Demo data on get demo profiles (no server).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (watchDemo(ref)) {
    final ar = DemoData.arabic(ref);
    return DemoProfileRepository(
      ar: ar,
      self: DemoData.user(ar: ar),
    );
  }
  return ProfileRepositoryImpl(ref.watch(apiDioProvider));
});
