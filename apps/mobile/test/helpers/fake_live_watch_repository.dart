// In-memory watch-together (D154i, tests only), answering as the server
// does (a link becomes its id; a refused id fails).

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_watch_repository.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';

class FakeLiveWatchRepository implements LiveWatchRepository {
  new({this.searchEnabled = false, DateTime Function()? now})
    : now = now ?? DateTime.now;

  bool searchEnabled;
  final DateTime Function() now;
  final watches = <String, LiveWatch>{};
  final pending = <String, List<LiveWatchSuggestion>>{};
  final calls = <String>[];

  /// Ids YouTube refuses (YOUTUBE_VIDEO_UNAVAILABLE).
  final refused = <String>{};

  static LiveWatchVideo videoOf(String id) => LiveWatchVideo(
    videoId: id,
    title: 'Video $id',
    thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  );

  static const _unavailable = ServerFailure(
    code: ErrorCode.youtubeVideoUnavailable,
    rawCode: 'YOUTUBE_VIDEO_UNAVAILABLE',
    debugMessage: 'x',
    statusCode: 422,
  );

  LiveWatch _state(String roomId) =>
      watches[roomId] ??
      LiveWatch(
        roomId: roomId,
        playing: false,
        positionMs: 0,
        serverTime: now(),
        searchEnabled: searchEnabled,
      );

  @override
  Future<LiveWatch> get(String roomId) async => _state(roomId);

  @override
  Future<LiveWatch> set(
    String roomId, {
    required bool playing,
    required int positionMs,
    String? video,
    bool stop = false,
  }) async {
    calls.add('set:${stop ? 'stop' : video ?? '-'}:$playing:$positionMs');
    final before = _state(roomId);
    var v = before.video;
    if (stop) {
      v = null;
    } else if (video != null) {
      final id = youtubeVideoId(video)!;
      if (refused.contains(id)) throw _unavailable;
      v = videoOf(id);
    }
    final t = now();
    return watches[roomId] = LiveWatch(
      roomId: roomId,
      video: v,
      playing: v != null && playing,
      positionMs: positionMs,
      updatedAt: t,
      serverTime: t,
      searchEnabled: searchEnabled,
    );
  }

  @override
  Future<List<LiveWatchSuggestion>> suggestions(String roomId) async =>
      pending[roomId] ?? const [];

  @override
  Future<LiveWatchSuggestion> suggest(String roomId, String video) async {
    calls.add('suggest:$video');
    final id = youtubeVideoId(video)!;
    if (refused.contains(id)) throw _unavailable;
    return LiveWatchSuggestion(
      id: 'sg-$id',
      roomId: roomId,
      video: videoOf(id),
      suggester: const UserSummary(
        id: 'u',
        username: 'fan',
        displayName: 'Fan',
        avatarUrl: null,
      ),
      status: 'PENDING',
    );
  }

  @override
  Future<LiveWatch> decide(
    String roomId,
    String suggestionId, {
    required bool approve,
  }) async {
    calls.add('decide:$suggestionId:$approve');
    final list = pending[roomId] ?? [];
    final s = list.firstWhere((x) => x.id == suggestionId);
    list.remove(s);
    if (!approve) return _state(roomId);
    return await set(
      roomId,
      video: s.video.videoId,
      playing: true,
      positionMs: 0,
    );
  }

  @override
  Future<List<LiveWatchVideo>> search(String query) async {
    calls.add('search:$query');
    if (!searchEnabled) {
      throw const ServerFailure(
        code: ErrorCode.youtubeSearchUnavailable,
        rawCode: 'YOUTUBE_SEARCH_UNAVAILABLE',
        debugMessage: 'x',
        statusCode: 503,
      );
    }
    return [videoOf('srchsrchsrc')];
  }
}
