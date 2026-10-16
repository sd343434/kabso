import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// Live discovery (docs/contracts/openapi.yaml v1.3, tag `live`).
///
/// Every method throws an `AppFailure`. Requests go through the
/// authenticated Dio (bearer token, single-flight refresh, `Accept-Language`
/// from the app language, `X-Request-Id`).
abstract interface class LiveRepository {
  /// `GET /live/config`.
  Future<LiveConfig> getConfig();

  /// `GET /live/categories`: active categories in server order (bounded,
  /// not paginated; empty until categories are created).
  Future<List<LiveCategory>> listCategories();

  /// `GET /live/rooms?tab&category&cursor&limit`.
  Future<LiveRoomPage> listRooms({
    required LiveRoomsTab tab,
    String? category,
    String? cursor,
    int limit = defaultPageSize,
  });

  /// `GET /live/rooms/{roomId}` (also returns ended rooms).
  Future<LiveRoom> getRoom(String roomId);

  /// CONVENTIONS §5 / HL-H5.
  static const defaultPageSize = 20;
}

class LiveRepositoryImpl implements LiveRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<LiveConfig> getConfig() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/live/config');
    return LiveConfig.fromJson(res.data!);
  });

  @override
  Future<List<LiveCategory>> listCategories() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/live/categories');
    final data = res.data!['data']! as List<dynamic>;
    return [
      for (final item in data)
        LiveCategory.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<LiveRoomPage> listRooms({
    required LiveRoomsTab tab,
    String? category,
    String? cursor,
    int limit = LiveRepository.defaultPageSize,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/rooms',
      queryParameters: {
        'tab': tab.wire,
        'category': ?category,
        'cursor': ?cursor,
        'limit': limit,
      },
    );
    return LiveRoomPage.fromJson(res.data!);
  });

  @override
  Future<LiveRoom> getRoom(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/rooms/${pathSegment(roomId)}',
    );
    return LiveRoom.fromJson(res.data!);
  });
}

final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => LiveRepositoryImpl(ref.watch(apiDioProvider)),
);
