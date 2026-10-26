import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// The follower and following lists of a user (openapi v1.25.2-live, D121:
/// `listUserFollowers`, `listUserFollowing`; CONVENTIONS §10.6). Following
/// and unfollowing a row go through `ProfileRepository`.
///
/// Every method throws an `AppFailure`: `NOT_FOUND` for an unknown,
/// suspended or deleted user or across a block; `AUTH_FORBIDDEN` for a
/// private account the reader does not follow.
abstract interface class FollowListsRepository {
  /// One page of [username]'s [kind] list, newest follow first.
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
  });
}

class FollowListsRepositoryImpl implements FollowListsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/${kind.path}',
      queryParameters: {'cursor': ?cursor},
    );
    final json = res.data!;
    return PageOf([
      for (final item in json['data']! as List<Object?>)
        FollowListItem.fromJson(item! as Map<String, dynamic>),
    ], PageInfo.fromJson(json['page']! as Map<String, dynamic>));
  });
}

/// Demo builds (D86): a few invented people, one page.
class DemoFollowListsRepository implements FollowListsRepository {
  const new({required this.ar});

  final bool ar;

  @override
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
  }) async {
    final names = ar
        ? ['سارة', 'عمر', 'ليان', 'يوسف', 'مريم', 'خالد']
        : ['Sara', 'Omar', 'Layan', 'Yusuf', 'Maryam', 'Khaled'];
    final handles = [
      'sara_k',
      'omar.live',
      'layan',
      'yusuf_9',
      'maryam',
      'khaled',
    ];
    return PageOf([
      for (var i = 0; i < names.length; i++)
        FollowListItem(
          id: 'demo-${kind.path}-$i',
          username: handles[i],
          displayName: names[i],
          avatarUrl: null,
          isSelf: false,
          isPrivate: false,
          followedByMe: kind == FollowListKind.following || i.isEven,
          followsMe: kind == FollowListKind.followers,
        ),
    ], const PageInfo(nextCursor: null, hasMore: false));
  }
}

final followListsRepositoryProvider = Provider<FollowListsRepository>((ref) {
  if (watchDemo(ref)) {
    return DemoFollowListsRepository(ar: DemoData.arabic(ref));
  }
  return FollowListsRepositoryImpl(ref.watch(apiDioProvider));
});
