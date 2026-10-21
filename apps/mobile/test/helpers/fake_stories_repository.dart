import 'dart:async';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';

/// An in-memory [StoriesRepository] (tests only). By default the tray is
/// empty. [stories] holds each account's active stories (oldest first);
/// [tray] is served as is; [failWith] makes the next call throw; every call
/// is recorded in [calls].
class FakeStoriesRepository implements StoriesRepository {
  new({this.pageSize = 20});

  final int pageSize;
  final List<String> calls = [];
  Exception? failWith;
  Completer<void>? gate;

  List<StoryTrayItem> trayItems = [];
  final Map<String, List<Story>> stories = {};
  final Map<String, List<UserSummary>> viewerLists = {};
  List<Story> archived = [];

  /// Usernames whose stories answer 404.
  final Set<String> hidden = {};

  /// Bodies of `createStory` calls.
  final List<({String key, String mediaId, String text})> created = [];

  static const _notFound = ServerFailure(
    code: ErrorCode.notFound,
    rawCode: 'NOT_FOUND',
    debugMessage: 'Not found',
    statusCode: 404,
  );

  Future<void> _step(String call) async {
    calls.add(call);
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
  }

  PageOf<T> _slice<T>(List<T> all, String? cursor) {
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
  }

  @override
  Future<PageOf<StoryTrayItem>> tray({String? cursor, int? limit}) async {
    await _step('tray:${cursor ?? ''}');
    return _slice(trayItems, cursor);
  }

  @override
  Future<List<Story>> userStories(String username) async {
    await _step('userStories:$username');
    if (hidden.contains(username)) throw _notFound;
    return [...?stories[username]];
  }

  @override
  Future<Story> getStory(String storyId) async {
    await _step('getStory:$storyId');
    for (final s in stories.values.expand((l) => l)) {
      if (s.id == storyId) return s;
    }
    throw _notFound;
  }

  @override
  Future<Story> createStory({
    required String idempotencyKey,
    required String mediaId,
    String text = '',
  }) async {
    await _step('createStory:$mediaId');
    created.add((key: idempotencyKey, mediaId: mediaId, text: text));
    return testStory('s-new-${created.length}', text: text, isSelf: true);
  }

  @override
  Future<void> deleteStory(String storyId) async {
    await _step('deleteStory:$storyId');
    for (final l in stories.values) {
      l.removeWhere((s) => s.id == storyId);
    }
    archived.removeWhere((s) => s.id == storyId);
  }

  @override
  Future<void> markSeen(String storyId) => _step('seen:$storyId');

  @override
  Future<PageOf<UserSummary>> viewers(String storyId, {String? cursor}) async {
    await _step('viewers:$storyId:${cursor ?? ''}');
    return _slice(viewerLists[storyId] ?? const [], cursor);
  }

  @override
  Future<PageOf<Story>> archive({String? cursor}) async {
    await _step('archive:${cursor ?? ''}');
    return _slice(archived, cursor);
  }

  @override
  Future<void> reportStory(String storyId, ReportReason reason) =>
      _step('report:$storyId:${reason.wire}');
}

/// An account in the tray (fixture).
StoryTrayItem testTrayItem(
  String username, {
  String? id,
  bool unseen = true,
  int count = 1,
}) => StoryTrayItem(
  user: UserSummary(
    id: id ?? 'u-$username',
    username: username,
    displayName: username[0].toUpperCase() + username.substring(1),
    avatarUrl: null,
  ),
  storyCount: count,
  hasUnseen: unseen,
  latestAt: DateTime.utc(2026, 10, 21, 9),
);

/// A story of [username] (fixture).
Story testStory(
  String id, {
  String username = 'sara',
  String text = '',
  bool seen = false,
  bool isSelf = false,
  int views = 0,
}) => Story(
  id: id,
  author: UserSummary(
    id: 'u-$username',
    username: username,
    displayName: username[0].toUpperCase() + username.substring(1),
    avatarUrl: null,
  ),
  media: MediaAsset(
    id: '$id-m',
    url: 'https://media.example.test/media/$id-m/1920.webp',
    thumbUrl: 'https://media.example.test/media/$id-m/320.webp',
    width: 1080,
    height: 1920,
  ),
  text: text,
  mentions: const [],
  createdAt: DateTime.utc(2026, 10, 21, 9),
  expiresAt: DateTime.utc(2026, 10, 22, 9),
  viewerHasSeen: seen || isSelf,
  isSelf: isSelf,
  viewCount: isSelf ? views : null,
);
