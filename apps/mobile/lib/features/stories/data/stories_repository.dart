import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';

/// Photo stories (docs/contracts/openapi.yaml v1.5-social DRAFT, tag
/// `stories`, CP-008, CONVENTIONS §11.9).
///
/// Every method throws an `AppFailure`.
abstract interface class StoriesRepository {
  /// `GET /feed/stories`: the caller first, then followed accounts.
  Future<PageOf<StoryTrayItem>> tray({String? cursor, int? limit});

  /// `GET /users/{username}/stories`: active, oldest first (404 when the
  /// account's content is not visible).
  Future<List<Story>> userStories(String username);

  /// `GET /stories/{storyId}`.
  Future<Story> getStory(String storyId);

  /// `POST /stories` with [idempotencyKey] (kept for every retry).
  Future<Story> createStory({
    required String idempotencyKey,
    required String mediaId,
    String text = '',
  });

  /// `DELETE /stories/{storyId}` (author).
  Future<void> deleteStory(String storyId);

  /// `PUT /stories/{storyId}/seen` (idempotent).
  Future<void> markSeen(String storyId);

  /// `GET /stories/{storyId}/viewers` (author, 48 hours).
  Future<PageOf<UserSummary>> viewers(String storyId, {String? cursor});

  /// `GET /me/stories/archive`: the caller's stories, newest first.
  Future<PageOf<Story>> archive({String? cursor});

  /// `POST /reports` for a story (`targetType: STORY`).
  Future<void> reportStory(String storyId, ReportReason reason);
}

PageOf<T> _page<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic>) item,
) => PageOf([
  for (final e in body['data']! as List<dynamic>)
    item(e as Map<String, dynamic>),
], PageInfo.fromJson(body['page']! as Map<String, dynamic>));

class StoriesRepositoryImpl implements StoriesRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<PageOf<StoryTrayItem>> tray({String? cursor, int? limit}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/feed/stories',
          queryParameters: {'cursor': ?cursor, 'limit': ?limit},
        );
        return _page(res.data!, StoryTrayItem.fromJson);
      });

  @override
  Future<List<Story>> userStories(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/stories',
    );
    return [
      for (final s in res.data!['data']! as List<dynamic>)
        Story.fromJson(s as Map<String, dynamic>),
    ];
  });

  @override
  Future<Story> getStory(String storyId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stories/${pathSegment(storyId)}',
    );
    return Story.fromJson(res.data!);
  });

  @override
  Future<Story> createStory({
    required String idempotencyKey,
    required String mediaId,
    String text = '',
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/stories',
      data: {'mediaId': mediaId, if (text.isNotEmpty) 'text': text},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Story.fromJson(res.data!);
  });

  @override
  Future<void> deleteStory(String storyId) => guardApiCall(() async {
    await _dio.delete<void>('/stories/${pathSegment(storyId)}');
  });

  @override
  Future<void> markSeen(String storyId) => guardApiCall(() async {
    await _dio.put<void>('/stories/${pathSegment(storyId)}/seen');
  });

  @override
  Future<PageOf<UserSummary>> viewers(String storyId, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/stories/${pathSegment(storyId)}/viewers',
          queryParameters: {'cursor': ?cursor},
        );
        return _page(res.data!, UserSummary.fromJson);
      });

  @override
  Future<PageOf<Story>> archive({String? cursor}) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/stories/archive',
      queryParameters: {'cursor': ?cursor},
    );
    return _page(res.data!, Story.fromJson);
  });

  @override
  Future<void> reportStory(String storyId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'STORY',
            'targetId': storyId,
            'reason': reason.wire,
          },
        );
      });
}

final storiesRepositoryProvider = Provider<StoriesRepository>(
  (ref) => StoriesRepositoryImpl(ref.watch(apiDioProvider)),
);
