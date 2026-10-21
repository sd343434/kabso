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

  /// Bodies of `createPost` calls, with their keys.
  final List<
    ({
      String key,
      String? text,
      List<String> mediaIds,
      String? location,
      PostSettingsDraft settings,
    })
  >
  created = [];

  /// People `searchUsers` finds (by username or display name prefix).
  List<UserSummary> people = const [];

  @override
  Future<Post> createPost({
    required String idempotencyKey,
    String? text,
    List<String> mediaIds = const [],
    String? location,
    PostSettingsDraft settings = const PostSettingsDraft(),
  }) async {
    await _step('create:$idempotencyKey');
    created.add((
      key: idempotencyKey,
      text: text,
      mediaIds: mediaIds,
      location: location,
      settings: settings,
    ));
    return testPost(
      'new-${created.length}',
      text: text ?? '',
      isSelf: true,
      pending: mediaIds.isNotEmpty,
    );
  }

  /// Top-level comments per post, in the server's order (pinned first,
  /// then as listed); replies per top-level comment, oldest first.
  final Map<String, List<Comment>> postComments = {};
  final Map<String, List<Comment>> commentReplies = {};

  /// Who `createComment` writes as.
  UserSummary commenter = const UserSummary(
    id: 'u-me',
    username: 'me',
    displayName: 'Me',
    avatarUrl: null,
  );
  int _nextComment = 0;

  PageOf<Comment> _commentSlice(List<Comment> all, String? cursor) {
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
  }

  void _updateComment(String id, Comment Function(Comment) f) {
    for (final list in [...postComments.values, ...commentReplies.values]) {
      final i = list.indexWhere((c) => c.id == id);
      if (i >= 0) list[i] = f(list[i]);
    }
  }

  Comment _find(String id) => [
    ...postComments.values,
    ...commentReplies.values,
  ].expand((l) => l).firstWhere((c) => c.id == id);

  @override
  Future<PageOf<Comment>> comments(String postId, {String? cursor}) async {
    await _step('comments:$postId:${cursor ?? ''}');
    final all = [...?postComments[postId]]
      ..sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
    return _commentSlice(all, cursor);
  }

  @override
  Future<PageOf<Comment>> replies(String commentId, {String? cursor}) async {
    await _step('replies:$commentId:${cursor ?? ''}');
    return _commentSlice(commentReplies[commentId] ?? const [], cursor);
  }

  @override
  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentId,
  }) async {
    await _step('createComment:$postId:${parentId ?? ''}:$text');
    final c = testComment(
      'c-new-${++_nextComment}',
      postId: postId,
      author: commenter,
      text: text,
      parentId: parentId,
      canDelete: true,
    );
    if (parentId == null) {
      (postComments[postId] ??= []).insert(0, c);
    } else {
      (commentReplies[parentId] ??= []).add(c);
      _updateComment(parentId, (p) => p.copyWith(replyCount: p.replyCount + 1));
    }
    return c;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _step('deleteComment:$commentId');
    for (final list in [...postComments.values, ...commentReplies.values]) {
      list.removeWhere((c) => c.id == commentId);
    }
  }

  @override
  Future<LikeState> setCommentLiked(
    String commentId, {
    required bool liked,
  }) async {
    await _step('likeComment:$commentId:$liked');
    final c = _find(commentId);
    final n = liked == c.viewerHasLiked
        ? c.likeCount
        : (c.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
    _updateComment(
      commentId,
      (x) => x.copyWith(viewerHasLiked: liked, likeCount: n),
    );
    return (liked: liked, likeCount: n);
  }

  @override
  Future<Comment> setCommentPinned(
    String commentId, {
    required bool pinned,
  }) async {
    await _step('pinComment:$commentId:$pinned');
    if (pinned) {
      for (final list in postComments.values) {
        for (var i = 0; i < list.length; i++) {
          if (list[i].pinned) list[i] = list[i].copyWith(pinned: false);
        }
      }
    }
    _updateComment(commentId, (c) => c.copyWith(pinned: pinned));
    return _find(commentId);
  }

  @override
  Future<void> reportComment(String commentId, ReportReason reason) =>
      _step('reportComment:$commentId:${reason.wire}');

  @override
  Future<List<UserSummary>> searchUsers(String query) async {
    await _step('searchUsers:$query');
    final q = query.toLowerCase();
    return [
      for (final u in people)
        if (u.username.startsWith(q) ||
            u.displayName.toLowerCase().startsWith(q))
          u,
    ];
  }
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
  int commentCount = 2,
  bool commentsEnabled = true,
  WhoCanComment whoCanComment = WhoCanComment.everyone,
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
  commentCount: commentCount,
  shareCount: 1,
  repostCount: 0,
  viewCount: 10,
  viewerHasLiked: liked,
  viewerHasSaved: saved,
  viewerHasReposted: false,
  isSelf: isSelf,
  pinned: false,
  commentsEnabled: commentsEnabled,
  whoCanComment: whoCanComment,
  hideLikeCount: hideLikeCount,
  pendingModeration: pending,
);

/// A contract-shaped `Post` body (tests only).
Map<String, Object?> postJson(String id, {String text = 'Hello'}) => {
  'id': id,
  'format': 'POST',
  'author': {
    'id': 'u1',
    'username': 'sara',
    'displayName': 'Sara',
    'avatarUrl': null,
  },
  'text': text,
  'media': <Object?>[],
  'location': null,
  'hashtags': <Object?>[],
  'mentions': <Object?>[],
  'status': 'PUBLISHED',
  'createdAt': '2026-10-20T09:00:00.000Z',
  'publishAt': null,
  'publishedAt': '2026-10-20T09:00:00.000Z',
  'editedAt': null,
  'pinned': false,
  'likeCount': 0,
  'commentCount': 0,
  'shareCount': 0,
  'repostCount': 0,
  'viewCount': 0,
  'viewerHasLiked': false,
  'viewerHasSaved': false,
  'viewerHasReposted': false,
  'isSelf': true,
  'settings': {
    'commentsEnabled': true,
    'whoCanComment': 'EVERYONE',
    'hideLikeCount': false,
  },
  'moderation': 'VISIBLE',
  'repostedBy': null,
};

/// A comment by [author] (default: `@omar`) on [postId] (fixture).
Comment testComment(
  String id, {
  String postId = 'p1',
  UserSummary author = const UserSummary(
    id: 'u-omar',
    username: 'omar',
    displayName: 'Omar',
    avatarUrl: null,
  ),
  String text = 'Nice',
  String? parentId,
  int likes = 0,
  bool liked = false,
  int replies = 0,
  bool pinned = false,
  bool canDelete = false,
}) => Comment(
  id: id,
  postId: postId,
  author: author,
  text: text,
  createdAt: DateTime.utc(2026, 10, 20, 10),
  likeCount: likes,
  viewerHasLiked: liked,
  replyCount: replies,
  parentId: parentId,
  mentions: const [],
  pinned: pinned,
  canDelete: canDelete,
);
