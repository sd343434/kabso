import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';

/// YouTube watch-together (v1.38-live, D154i, CONVENTIONS §10.39). Throws
/// an `AppFailure`.
abstract interface class LiveWatchRepository {
  Future<LiveWatch> get(String roomId);

  /// The host's player state; [video] an id or link to change it, [stop]
  /// to stop watching.
  Future<LiveWatch> set(
    String roomId, {
    required bool playing,
    required int positionMs,
    String? video,
    bool stop = false,
  });

  Future<List<LiveWatchSuggestion>> suggestions(String roomId);

  Future<LiveWatchSuggestion> suggest(String roomId, String video);

  Future<LiveWatch> decide(
    String roomId,
    String suggestionId, {
    required bool approve,
  });

  Future<List<LiveWatchVideo>> search(String query);
}

class LiveWatchRepositoryImpl implements LiveWatchRepository {
  new(this._dio);

  final Dio _dio;

  String _path(String roomId) => '/live/rooms/${pathSegment(roomId)}/watch';

  @override
  Future<LiveWatch> get(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_path(roomId));
    return LiveWatch.fromJson(res.data!);
  });

  @override
  Future<LiveWatch> set(
    String roomId, {
    required bool playing,
    required int positionMs,
    String? video,
    bool stop = false,
  }) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      _path(roomId),
      data: {
        if (stop) 'video': null else 'video': ?video,
        'playing': playing,
        'positionMs': positionMs,
      },
    );
    return LiveWatch.fromJson(res.data!);
  });

  @override
  Future<List<LiveWatchSuggestion>> suggestions(String roomId) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_path(roomId)}/suggestions',
        );
        return [
          for (final s in res.data!['data']! as List<dynamic>)
            LiveWatchSuggestion.fromJson(s as Map<String, dynamic>),
        ];
      });

  @override
  Future<LiveWatchSuggestion> suggest(String roomId, String video) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_path(roomId)}/suggestions',
          data: {'video': video},
        );
        return LiveWatchSuggestion.fromJson(res.data!);
      });

  @override
  Future<LiveWatch> decide(
    String roomId,
    String suggestionId, {
    required bool approve,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_path(roomId)}/suggestions/${pathSegment(suggestionId)}/decision',
      data: {'approve': approve},
    );
    return LiveWatch.fromJson(res.data!);
  });

  @override
  Future<List<LiveWatchVideo>> search(String query) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/youtube/search',
      queryParameters: {'q': query},
    );
    return [
      for (final v in res.data!['items']! as List<dynamic>)
        LiveWatchVideo.fromJson(v as Map<String, dynamic>),
    ];
  });
}

final liveWatchRepositoryProvider = Provider<LiveWatchRepository>(
  (ref) => LiveWatchRepositoryImpl(ref.watch(apiDioProvider)),
);
