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
/// `listUserFollowers`, `listUserFollowing`; v1.26.1-live, D125: the search
/// `q`, the `order` and `removeMyFollower`; CONVENTIONS §10.6). Following
/// and unfollowing a row go through `ProfileRepository`.
///
/// Every method throws an `AppFailure`: `NOT_FOUND` for an unknown,
/// suspended or deleted user or across a block; `AUTH_FORBIDDEN` for a
/// private account the reader does not follow.
abstract interface class FollowListsRepository {
  /// One page of [username]'s [kind] list in [order] (newest follow first
  /// by default); [query] keeps the names starting with it (D125).
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
    String? query,
    FollowListOrder order = FollowListOrder.newest,
  });

  /// D125 `DELETE /me/followers/{username}`: [username] no longer follows
  /// the caller. Returns the caller's follower count after.
  Future<int> removeFollower(String username);
}

class FollowListsRepositoryImpl implements FollowListsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
    String? query,
    FollowListOrder order = FollowListOrder.newest,
  }) => guardApiCall(() async {
    final q = query?.trim();
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/${kind.path}',
      queryParameters: {
        'cursor': ?cursor,
        if (q != null && q.isNotEmpty) 'q': q,
        if (order != FollowListOrder.newest) 'order': order.wire,
      },
    );
    final json = res.data!;
    return PageOf([
      for (final item in json['data']! as List<Object?>)
        FollowListItem.fromJson(item! as Map<String, dynamic>),
    ], PageInfo.fromJson(json['page']! as Map<String, dynamic>));
  });

  @override
  Future<int> removeFollower(String username) => guardApiCall(() async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/me/followers/${pathSegment(username)}',
    );
    return res.data!['followerCount']! as int;
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
    String? query,
    FollowListOrder order = FollowListOrder.newest,
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
    final q = query?.trim().toLowerCase() ?? '';
    final rows = [
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
    ];
    return PageOf([
      for (final u in order == FollowListOrder.newest ? rows : rows.reversed)
        if (u.username.startsWith(q) ||
            u.displayName.toLowerCase().startsWith(q))
          u,
    ], const PageInfo(nextCursor: null, hasMore: false));
  }

  @override
  Future<int> removeFollower(String username) async => 5;
}

final followListsRepositoryProvider = Provider<FollowListsRepository>((ref) {
  if (watchDemo(ref)) {
    return DemoFollowListsRepository(ar: DemoData.arabic(ref));
  }
  return FollowListsRepositoryImpl(ref.watch(apiDioProvider));
});
