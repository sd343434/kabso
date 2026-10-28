import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
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

  /// Profile grids per username, and the caller's saved posts.
  final Map<String, List<Post>> profilePosts = {};
  List<Post> savedPosts = [];

  /// Usernames whose grid answers 404 (private and not followed, block).
  final Set<String> hiddenProfiles = {};

  @override
  Future<Post> getPost(String postId) async {
    await _step('getPost:$postId');
    if (answers[postId] case final p?) return p;
    for (final p in [
      ...feeds.values.expand((l) => l),
      ...profilePosts.values.expand((l) => l),
      ...savedPosts,
      ...myPostLists.values.expand((l) => l),
    ]) {
      if (p.id == postId) return p;
    }
    throw const ServerFailure(
      code: ErrorCode.notFound,
      rawCode: 'NOT_FOUND',
      debugMessage: 'No post',
      statusCode: 404,
    );
  }

  @override
  Future<PageOf<Post>> userPosts(String username, {String? cursor}) async {
    await _step('userPosts:$username:${cursor ?? ''}');
    if (hiddenProfiles.contains(username)) {
      throw const ServerFailure(
        code: ErrorCode.notFound,
        rawCode: 'NOT_FOUND',
        debugMessage: 'Not visible',
        statusCode: 404,
      );
    }
    return _slice(profilePosts[username] ?? const [], cursor);
  }

  @override
  Future<PageOf<Post>> saved({String? cursor}) async {
    await _step('saved:${cursor ?? ''}');
    return _slice(savedPosts, cursor);
  }

  /// Reposts per username, and likers per post.
  final Map<String, List<Post>> userRepostLists = {};
  final Map<String, List<UserSummary>> postLikers = {};

  /// Post ids whose likers answer 403 (like count hidden from others).
  final Set<String> hiddenLikers = {};

  /// Repost counts the server answers with (post id → count).
  final Map<String, int> repostCounts = {};

  @override
  Future<PageOf<Post>> userReposts(String username, {String? cursor}) async {
    await _step('userReposts:$username:${cursor ?? ''}');
    if (hiddenProfiles.contains(username)) throw _notFound;
    return _slice(userRepostLists[username] ?? const [], cursor);
  }

  @override
  Future<RepostState> setReposted(
    String postId, {
    required bool reposted,
  }) async {
    await _step('repost:$postId:$reposted');
    final n = (repostCounts[postId] ?? 0) + (reposted ? 1 : -1);
    repostCounts[postId] = n < 0 ? 0 : n;
    return (reposted: reposted, repostCount: repostCounts[postId]!);
  }

  @override
  Future<PageOf<UserSummary>> likers(String postId, {String? cursor}) async {
    await _step('likers:$postId:${cursor ?? ''}');
    if (hiddenLikers.contains(postId)) {
      throw const ServerFailure(
        code: ErrorCode.authForbidden,
        rawCode: 'AUTH_FORBIDDEN',
        debugMessage: 'Hidden',
        statusCode: 403,
      );
    }
    return _slicePage(postLikers[postId] ?? const [], cursor);
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
  Future<void> deletePost(String postId) async {
    await _step('delete:$postId');
    for (final l in myPostLists.values) {
      l.removeWhere((p) => p.id == postId);
    }
  }

  /// Bodies of `updatePost` calls.
  final List<(String, Map<String, Object?>)> updates = [];

  /// What `updatePost` and `setPinned` answer with (post id → post); else
  /// the post from [getPost] with the change applied.
  final Map<String, Post> answers = {};

  /// Pinned post ids; a fourth pin is refused (409).
  final Set<String> pins = {};

  Future<Post> _current(String postId) async {
    if (answers[postId] case final p?) return p;
    for (final p in [
      ...feeds.values.expand((l) => l),
      ...profilePosts.values.expand((l) => l),
      ...myPostLists.values.expand((l) => l),
    ]) {
      if (p.id == postId) return p;
    }
    throw _notFound;
  }

  @override
  Future<Post> updatePost(String postId, PostUpdate update) async {
    await _step('update:$postId');
    updates.add((postId, update.toJson()));
    final p = await _current(postId);
    final json = update.toJson();
    final next = answers[postId] = p.copyWithForTest(
      text: update.text,
      location: json.containsKey('location')
          ? () => json['location'] as String?
          : null,
      editedAt: update.text != null && update.text != p.text
          ? DateTime.utc(2026, 10, 21, 12)
          : null,
      commentsEnabled: update.commentsEnabled,
      whoCanComment: update.whoCanComment,
      hideLikeCount: update.hideLikeCount,
      status: update.status,
      publishAt: update.publishAt,
    );
    if (update.status case final s?) {
      for (final l in myPostLists.values) {
        l.removeWhere((x) => x.id == postId);
      }
      if (s != 'PUBLISHED') (myPostLists[s] ??= []).insert(0, next);
    }
    return next;
  }

  @override
  Future<Post> setPinned(String postId, {required bool pinned}) async {
    await _step('pin:$postId:$pinned');
    if (pinned && !pins.contains(postId) && pins.length >= 3) {
      throw const ServerFailure(
        code: ErrorCode.pinLimitReached,
        rawCode: 'PIN_LIMIT_REACHED',
        debugMessage: 'Three pins',
        statusCode: 409,
      );
    }
    pinned ? pins.add(postId) : pins.remove(postId);
    final p = await _current(postId);
    return answers[postId] = p.copyWithForTest(pinned: pinned);
  }

  /// The caller's drafts and scheduled posts (`GET /me/posts?status=`).
  final Map<String, List<Post>> myPostLists = {};

  /// Bodies of `createPost` calls, with their keys.
  final List<
    ({
      String key,
      String? text,
      List<String> mediaIds,
      String? location,
      PostSettingsDraft settings,
      String status,
      DateTime? publishAt,
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
    String status = 'PUBLISHED',
    DateTime? publishAt,
  }) async {
    await _step('create:$idempotencyKey');
    created.add((
      key: idempotencyKey,
      text: text,
      mediaIds: mediaIds,
      location: location,
      settings: settings,
      status: status,
      publishAt: publishAt,
    ));
    final post = testPost(
      'new-${created.length}',
      text: text ?? '',
      isSelf: true,
      pending: mediaIds.isNotEmpty,
    ).copyWithForTest(status: status, publishAt: publishAt);
    if (status != 'PUBLISHED') (myPostLists[status] ??= []).insert(0, post);
    return post;
  }

  /// Batches sent to `recordViews`.
  final List<List<PostView>> viewBatches = [];

  @override
  Future<void> recordViews(List<PostView> views) async {
    await _step('views:${views.length}');
    viewBatches.add(views);
  }

  @override
  Future<PageOf<Post>> myPosts(String status, {String? cursor}) async {
    await _step('myPosts:$status:${cursor ?? ''}');
    return _slice(myPostLists[status] ?? const [], cursor);
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

  /// Hashtags `searchHashtags` finds and `hashtag` knows (by tag prefix),
  /// and their posts.
  List<Hashtag> tags = const [];
  final Map<String, List<Post>> tagPosts = {};

  /// Posts `searchPosts` finds (caption word prefix).
  List<Post> searchable = const [];

  static const _notFound = ServerFailure(
    code: ErrorCode.notFound,
    rawCode: 'NOT_FOUND',
    debugMessage: 'Not found',
    statusCode: 404,
  );

  PageOf<T> _slicePage<T>(List<T> all, String? cursor) {
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
  }

  @override
  Future<PageOf<UserSummary>> searchPeople(
    String query, {
    String? cursor,
  }) async {
    await _step('search:users:$query:${cursor ?? ''}');
    final q = query.toLowerCase();
    return _slicePage([
      for (final u in people)
        if (u.username.startsWith(q) ||
            u.displayName.toLowerCase().startsWith(q))
          u,
    ], cursor);
  }

  @override
  Future<PageOf<Hashtag>> searchHashtags(String query, {String? cursor}) async {
    await _step('search:hashtags:$query:${cursor ?? ''}');
    final q = query.toLowerCase();
    return _slicePage([
      for (final t in tags)
        if (t.tag.startsWith(q)) t,
    ], cursor);
  }

  @override
  Future<PageOf<Post>> searchPosts(String query, {String? cursor}) async {
    await _step('search:posts:$query:${cursor ?? ''}');
    final q = query.toLowerCase();
    return _slicePage([
      for (final p in searchable)
        if (p.text
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .any((w) => w.startsWith(q)))
          p,
    ], cursor);
  }

  /// D147: what `trendingSearches` and `trendingHashtags` return, and the
  /// searches `recordSearch` received.
  List<TrendingSearch> trending = const [];
  List<Hashtag> trendingTags = const [];
  final List<String> recorded = [];

  @override
  Future<List<TrendingSearch>> trendingSearches() async {
    await _step('trending');
    return trending;
  }

  @override
  Future<List<Hashtag>> trendingHashtags({int limit = 20}) async {
    await _step('trendingTags:$limit');
    return trendingTags.take(limit).toList();
  }

  @override
  Future<void> recordSearch(String query) async {
    recorded.add(query);
  }

  @override
  Future<Hashtag> hashtag(String tag) async {
    await _step('hashtag:$tag');
    for (final t in tags) {
      if (t.tag == tag) return t;
    }
    throw _notFound;
  }

  @override
  Future<PageOf<Post>> hashtagPosts(
    String tag, {
    HashtagSort sort = HashtagSort.recent,
    String? cursor,
  }) async {
    await _step('hashtagPosts:$tag:${sort.name}:${cursor ?? ''}');
    final all = tagPosts[tag] ?? const <Post>[];
    return _slicePage(
      sort == HashtagSort.top ? all.reversed.toList() : all,
      cursor,
    );
  }

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
  bool reposted = false,
  int reposts = 0,
  bool isSelf = false,
  bool pending = false,
  int? likeCount,
  bool hideLikeCount = false,
  int commentCount = 2,
  int photos = 0,
  bool pinned = false,
  String? location,
  DateTime? editedAt,
  List<String> hashtags = const [],
  List<UserSummary> mentions = const [],
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
  media: [
    for (var i = 0; i < photos; i++)
      MediaAsset(
        id: '$id-m$i',
        url: 'https://media.example.test/media/$id-m$i/1080.webp',
        thumbUrl: 'https://media.example.test/media/$id-m$i/320.webp',
        width: 1080,
        height: 1080,
      ),
  ],
  location: location,
  editedAt: editedAt,
  hashtags: hashtags,
  mentions: mentions,
  status: 'PUBLISHED',
  createdAt: DateTime.utc(2026, 10, 20, 9),
  publishedAt: DateTime.utc(2026, 10, 20, 9),
  likeCount: hideLikeCount ? likeCount : (likeCount ?? likes),
  commentCount: commentCount,
  shareCount: 1,
  repostCount: reposts,
  viewCount: 10,
  viewerHasLiked: liked,
  viewerHasSaved: saved,
  viewerHasReposted: reposted,
  isSelf: isSelf,
  pinned: pinned,
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

/// A changed copy of a fixture post, as the server would answer (tests
/// only). [location] is a getter so `null` can clear the place.
extension PostTestCopy on Post {
  Post copyWithForTest({
    String? text,
    String? Function()? location,
    DateTime? editedAt,
    bool? pinned,
    bool? commentsEnabled,
    WhoCanComment? whoCanComment,
    bool? hideLikeCount,
    String? status,
    DateTime? publishAt,
  }) {
    final next = status ?? this.status;
    return Post(
      id: id,
      author: author,
      text: text ?? this.text,
      media: media,
      location: location == null ? this.location : location(),
      hashtags: hashtags,
      mentions: mentions,
      status: next,
      createdAt: createdAt,
      publishAt: next == 'SCHEDULED' ? (publishAt ?? this.publishAt) : null,
      publishedAt: next == 'PUBLISHED'
          ? (publishedAt ?? DateTime.utc(2026, 10, 21, 12))
          : null,
      editedAt: editedAt ?? this.editedAt,
      pinned: pinned ?? this.pinned,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      repostCount: repostCount,
      viewCount: viewCount,
      viewerHasLiked: viewerHasLiked,
      viewerHasSaved: viewerHasSaved,
      viewerHasReposted: viewerHasReposted,
      isSelf: isSelf,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      whoCanComment: whoCanComment ?? this.whoCanComment,
      hideLikeCount: hideLikeCount ?? this.hideLikeCount,
      pendingModeration: pendingModeration,
      repostedBy: repostedBy,
    );
  }
}
