import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// Which feed (`GET /feed/posts?tab=`).
enum PostsFeedTab { following, trending }

/// Posts, feeds and interactions (docs/contracts/openapi.yaml v1.5-social
/// DRAFT, tags `posts`, `feed` and `safety`; CONVENTIONS §11).
///
/// Every method throws an `AppFailure`.
abstract interface class PostsRepository {
  /// `GET /feed/posts`: one page; [cursor] from the previous page.
  Future<PageOf<Post>> feed(PostsFeedTab tab, {String? cursor, int? limit});

  /// `GET /posts/{postId}`: one post the caller may see (else 404).
  Future<Post> getPost(String postId);

  /// `GET /users/{username}/posts` (pinned first on the first page).
  Future<PageOf<Post>> userPosts(String username, {String? cursor});

  /// `GET /me/saved`.
  Future<PageOf<Post>> saved({String? cursor});

  /// `PUT`/`DELETE /posts/{postId}/like`.
  Future<LikeState> setLiked(String postId, {required bool liked});

  /// `PUT`/`DELETE /posts/{postId}/save`.
  Future<bool> setSaved(String postId, {required bool saved});

  /// `PUT`/`DELETE /posts/{postId}/hide`: leaves the caller's feeds.
  Future<void> setHidden(String postId, {required bool hidden});

  /// `POST /reports` for a post.
  Future<void> reportPost(String postId, ReportReason reason);

  /// `DELETE /posts/{postId}` (author only).
  Future<void> deletePost(String postId);

  /// `POST /posts` with [idempotencyKey] (a UUID kept for every retry of
  /// the same draft, CONVENTIONS §11.2): a text post, or photos [mediaIds]
  /// with an optional caption.
  Future<Post> createPost({
    required String idempotencyKey,
    String? text,
    List<String> mediaIds = const [],
    String? location,
    PostSettingsDraft settings = const PostSettingsDraft(),
  });

  /// `GET /search?type=users`: people to mention (blocked users never
  /// appear); [query] without the leading `@`.
  Future<List<UserSummary>> searchUsers(String query);

  /// `GET /search?type=users`, paged.
  Future<PageOf<UserSummary>> searchPeople(String query, {String? cursor});

  /// `GET /search?type=hashtags`, paged.
  Future<PageOf<Hashtag>> searchHashtags(String query, {String? cursor});

  /// `GET /search?type=posts` (caption words; visible posts only), paged.
  Future<PageOf<Post>> searchPosts(String query, {String? cursor});

  /// `GET /hashtags/{tag}`: the tag and its visible post count (404 when
  /// unused).
  Future<Hashtag> hashtag(String tag);

  /// `GET /hashtags/{tag}/posts`: recent, or top (trending score over 30
  /// days).
  Future<PageOf<Post>> hashtagPosts(
    String tag, {
    HashtagSort sort = HashtagSort.recent,
    String? cursor,
  });

  /// `GET /posts/{postId}/comments`: top level, the pinned one first, then
  /// by likes, then newest.
  Future<PageOf<Comment>> comments(String postId, {String? cursor});

  /// `GET /comments/{commentId}/replies`: oldest first.
  Future<PageOf<Comment>> replies(String commentId, {String? cursor});

  /// `POST /posts/{postId}/comments`: a comment, or a reply to [parentId]
  /// (a reply to a reply attaches to its top-level comment).
  Future<Comment> createComment(String postId, String text, {String? parentId});

  /// `DELETE /comments/{commentId}` (its author or the post's author);
  /// replies go with it.
  Future<void> deleteComment(String commentId);

  /// `PUT`/`DELETE /comments/{commentId}/like`.
  Future<LikeState> setCommentLiked(String commentId, {required bool liked});

  /// `PUT`/`DELETE /comments/{commentId}/pin` (post author, top level; a
  /// new pin replaces the previous one).
  Future<Comment> setCommentPinned(String commentId, {required bool pinned});

  /// `POST /reports` for a comment.
  Future<void> reportComment(String commentId, ReportReason reason);
}

PageOf<Comment> _commentPage(Map<String, dynamic> json) => PageOf([
  for (final c in json['data']! as List<dynamic>)
    Comment.fromJson(c as Map<String, dynamic>),
], PageInfo.fromJson(json['page']! as Map<String, dynamic>));

PageOf<Post> _postPage(Map<String, dynamic> json) => PageOf([
  for (final p in json['data']! as List<dynamic>)
    Post.fromJson(p as Map<String, dynamic>),
], PageInfo.fromJson(json['page']! as Map<String, dynamic>));

class PostsRepositoryImpl implements PostsRepository {
  new(this._dio);

  final Dio _dio;

  Future<PageOf<Post>> _page(String path, Map<String, Object?> query) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: {
            for (final e in query.entries)
              if (e.value != null) e.key: e.value,
          },
        );
        return _postPage(res.data!);
      });

  @override
  Future<PageOf<Post>> feed(PostsFeedTab tab, {String? cursor, int? limit}) =>
      _page('/feed/posts', {'tab': tab.name, 'cursor': cursor, 'limit': limit});

  @override
  Future<Post> getPost(String postId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/posts/${pathSegment(postId)}',
    );
    return Post.fromJson(res.data!);
  });

  @override
  Future<PageOf<Post>> userPosts(String username, {String? cursor}) =>
      _page('/users/${pathSegment(username)}/posts', {'cursor': cursor});

  @override
  Future<PageOf<Post>> saved({String? cursor}) =>
      _page('/me/saved', {'cursor': cursor});

  @override
  Future<LikeState> setLiked(String postId, {required bool liked}) =>
      guardApiCall(() async {
        final path = '/posts/${pathSegment(postId)}/like';
        final res = liked
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        final body = res.data!;
        return (
          liked: body['liked']! as bool,
          likeCount: body['likeCount'] as int?,
        );
      });

  @override
  Future<bool> setSaved(String postId, {required bool saved}) =>
      guardApiCall(() async {
        final path = '/posts/${pathSegment(postId)}/save';
        final res = saved
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return res.data!['saved']! as bool;
      });

  @override
  Future<void> setHidden(String postId, {required bool hidden}) =>
      guardApiCall(() async {
        final path = '/posts/${pathSegment(postId)}/hide';
        await (hidden ? _dio.put<void>(path) : _dio.delete<void>(path));
      });

  Future<void> _report(String type, String id, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {'targetType': type, 'targetId': id, 'reason': reason.wire},
        );
      });

  @override
  Future<void> reportPost(String postId, ReportReason reason) =>
      _report('POST', postId, reason);

  @override
  Future<void> reportComment(String commentId, ReportReason reason) =>
      _report('COMMENT', commentId, reason);

  @override
  Future<void> deletePost(String postId) => guardApiCall(() async {
    await _dio.delete<void>('/posts/${pathSegment(postId)}');
  });

  @override
  Future<Post> createPost({
    required String idempotencyKey,
    String? text,
    List<String> mediaIds = const [],
    String? location,
    PostSettingsDraft settings = const PostSettingsDraft(),
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/posts',
      data: {
        if (text != null && text.isNotEmpty) 'text': text,
        if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
        if (location != null && location.isNotEmpty) 'location': location,
        if (!settings.isDefault) 'settings': settings.toJson(),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Post.fromJson(res.data!);
  });

  @override
  Future<List<UserSummary>> searchUsers(String query) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': query, 'type': 'users', 'limit': 20},
    );
    return [
      for (final u in res.data!['data']! as List<dynamic>)
        UserSummary.fromJson(u as Map<String, dynamic>),
    ];
  });

  Future<PageOf<T>> _search<T>(
    String query,
    SearchType type,
    String? cursor,
    T Function(Map<String, dynamic>) item,
  ) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {'q': query, 'type': type.name, 'cursor': ?cursor},
    );
    final body = res.data!;
    return PageOf([
      for (final e in body['data']! as List<dynamic>)
        item(e as Map<String, dynamic>),
    ], PageInfo.fromJson(body['page']! as Map<String, dynamic>));
  });

  @override
  Future<PageOf<UserSummary>> searchPeople(String query, {String? cursor}) =>
      _search(query, SearchType.users, cursor, UserSummary.fromJson);

  @override
  Future<PageOf<Hashtag>> searchHashtags(String query, {String? cursor}) =>
      _search(query, SearchType.hashtags, cursor, Hashtag.fromJson);

  @override
  Future<PageOf<Post>> searchPosts(String query, {String? cursor}) =>
      _search(query, SearchType.posts, cursor, Post.fromJson);

  @override
  Future<Hashtag> hashtag(String tag) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/hashtags/${pathSegment(tag)}',
    );
    return Hashtag.fromJson(res.data!);
  });

  @override
  Future<PageOf<Post>> hashtagPosts(
    String tag, {
    HashtagSort sort = HashtagSort.recent,
    String? cursor,
  }) => _page('/hashtags/${pathSegment(tag)}/posts', {
    'sort': sort.name,
    'cursor': cursor,
  });

  Future<PageOf<Comment>> _comments(String path, String? cursor) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: {'cursor': ?cursor},
        );
        return _commentPage(res.data!);
      });

  @override
  Future<PageOf<Comment>> comments(String postId, {String? cursor}) =>
      _comments('/posts/${pathSegment(postId)}/comments', cursor);

  @override
  Future<PageOf<Comment>> replies(String commentId, {String? cursor}) =>
      _comments('/comments/${pathSegment(commentId)}/replies', cursor);

  @override
  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/posts/${pathSegment(postId)}/comments',
      data: {'text': text, 'parentId': ?parentId},
    );
    return Comment.fromJson(res.data!);
  });

  @override
  Future<void> deleteComment(String commentId) => guardApiCall(() async {
    await _dio.delete<void>('/comments/${pathSegment(commentId)}');
  });

  @override
  Future<LikeState> setCommentLiked(String commentId, {required bool liked}) =>
      guardApiCall(() async {
        final path = '/comments/${pathSegment(commentId)}/like';
        final res = liked
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        final body = res.data!;
        return (
          liked: body['liked']! as bool,
          likeCount: body['likeCount'] as int?,
        );
      });

  @override
  Future<Comment> setCommentPinned(String commentId, {required bool pinned}) =>
      guardApiCall(() async {
        final path = '/comments/${pathSegment(commentId)}/pin';
        final res = pinned
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return Comment.fromJson(res.data!);
      });
}

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => PostsRepositoryImpl(ref.watch(apiDioProvider)),
);
