import 'dart:async';

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// An in-memory [PostsRepository] (tests only). By default every feed is
/// empty: a server with the posts API and no posts yet. [feeds] serves one
/// list per feed, split by [pageSize] with cursors `"<n>"`; [failWith]
/// makes the next call throw; every call is recorded in [calls].
class FakePostsRepository implements PostsRepository {
  new({Map<PostsFeedTab, List<Post>>? feeds, this.pageSize = 20})
    : feeds = feeds ?? {};

  final Map<PostsFeedTab, List<Post>> feeds;
  final int pageSize;
  final List<String> calls = [];

  /// Thrown (once) by the next call.
  Exception? failWith;

  /// Completes a pending call (set to make calls wait).
  Completer<void>? gate;

  /// Like states the server answers with (post id → like count).
  final Map<String, int> likeCounts = {};

  Future<void> _step(String call) async {
    calls.add(call);
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
  }

  PageOf<Post> _slice(List<Post> all, String? cursor) {
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
  }

  @override
  Future<PageOf<Post>> feed(
    PostsFeedTab tab, {
    String? cursor,
    int? limit,
  }) async {
    await _step('feed:${tab.name}:${cursor ?? ''}');
    return _slice(feeds[tab] ?? const [], cursor);
  }

  @override
  Future<PageOf<Post>> userPosts(String username, {String? cursor}) async {
    await _step('userPosts:$username');
    return _slice(const [], cursor);
  }

  @override
  Future<PageOf<Post>> saved({String? cursor}) async {
    await _step('saved');
    return _slice(const [], cursor);
  }

  @override
  Future<LikeState> setLiked(String postId, {required bool liked}) async {
    await _step('like:$postId:$liked');
    final n = (likeCounts[postId] ?? 0) + (liked ? 1 : -1);
    likeCounts[postId] = n < 0 ? 0 : n;
    return (liked: liked, likeCount: likeCounts[postId]);
  }

  @override
  Future<bool> setSaved(String postId, {required bool saved}) async {
    await _step('save:$postId:$saved');
    return saved;
  }

  @override
  Future<void> setHidden(String postId, {required bool hidden}) =>
      _step('hide:$postId:$hidden');

  @override
  Future<void> reportPost(String postId, ReportReason reason) =>
      _step('report:$postId:${reason.wire}');

  @override
  Future<void> deletePost(String postId) => _step('delete:$postId');
}

/// A published post of [username] (fixture).
Post testPost(
  String id, {
  String username = 'sara',
  String displayName = 'Sara',
  String text = 'Hello',
  int likes = 0,
  bool liked = false,
  bool saved = false,
  bool isSelf = false,
  bool pending = false,
  int? likeCount,
  bool hideLikeCount = false,
}) => Post(
  id: id,
  author: UserSummary(
    id: 'u-$username',
    username: username,
    displayName: displayName,
    avatarUrl: null,
  ),
  text: text,
  media: const [],
  hashtags: const [],
  mentions: const [],
  status: 'PUBLISHED',
  createdAt: DateTime.utc(2026, 10, 20, 9),
  publishedAt: DateTime.utc(2026, 10, 20, 9),
  likeCount: hideLikeCount ? likeCount : (likeCount ?? likes),
  commentCount: 2,
  shareCount: 1,
  repostCount: 0,
  viewCount: 10,
  viewerHasLiked: liked,
  viewerHasSaved: saved,
  viewerHasReposted: false,
  isSelf: isSelf,
  pinned: false,
  commentsEnabled: true,
  whoCanComment: WhoCanComment.everyone,
  hideLikeCount: hideLikeCount,
  pendingModeration: pending,
);
