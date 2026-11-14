import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// `FollowRequest` (v1.47-social, D175): who asked to follow the caller's
/// private account, and when.
@immutable
class FollowRequest {
  const new({required this.user, required this.requestedAt});

  factory fromJson(Map<String, dynamic> json) => FollowRequest(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    requestedAt: DateTime.parse(json['requestedAt']! as String),
  );

  final UserSummary user;
  final DateTime requestedAt;
}

/// `FollowRequestPage`: a page plus `total`, every pending request.
@immutable
class FollowRequestPage {
  const new(this.items, this.page, this.total);

  final List<FollowRequest> items;
  final PageInfo page;
  final int total;

  String? get next => page.hasMore ? page.nextCursor : null;
}

/// Follow requests to the caller's private account (contract v1.47-social,
/// `listFollowRequests`, `acceptFollowRequest`, `declineFollowRequest`;
/// CONVENTIONS §10.47). Every method throws an `AppFailure`.
abstract interface class FollowRequestsRepository {
  /// `GET /me/follow-requests`, newest first.
  Future<FollowRequestPage> list({String? cursor});

  /// `POST /me/follow-requests/{username}/accept`: they follow you now; the
  /// caller's follower count after.
  Future<int> accept(String username);

  /// `POST /me/follow-requests/{username}/decline` (idempotent).
  Future<void> decline(String username);
}

class FollowRequestsRepositoryImpl implements FollowRequestsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<FollowRequestPage> list({String? cursor}) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/follow-requests',
      queryParameters: {'cursor': ?cursor},
    );
    final body = res.data!;
    return FollowRequestPage(
      [
        for (final r in body['data']! as List<dynamic>)
          FollowRequest.fromJson(r as Map<String, dynamic>),
      ],
      PageInfo.fromJson(body['page']! as Map<String, dynamic>),
      body['total'] as int? ?? 0,
    );
  });

  @override
  Future<int> accept(String username) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/follow-requests/${pathSegment(username)}/accept',
    );
    return res.data!['followerCount']! as int;
  });

  @override
  Future<void> decline(String username) => guardApiCall(
    () =>
        _dio.post<void>('/me/follow-requests/${pathSegment(username)}/decline'),
  );
}

final followRequestsRepositoryProvider = Provider<FollowRequestsRepository>(
  (ref) => FollowRequestsRepositoryImpl(ref.watch(apiDioProvider)),
);
