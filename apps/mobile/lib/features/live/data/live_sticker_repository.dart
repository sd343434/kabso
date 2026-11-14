import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_sticker.dart';

/// Stickers on a live (v1.37-live, D154h, CONVENTIONS §10.38): the art
/// catalogue (`GET /live/stickers`), a live's stickers (`GET
/// /live/rooms/{roomId}/stickers`) and the host's whole list (`PUT`).
/// Throws an `AppFailure`.
abstract interface class LiveStickerRepository {
  /// The art keys a host may place (`<pack>_<id>`), in order.
  Future<List<String>> catalogue();

  Future<LiveStickers> get(String roomId);

  Future<LiveStickers> set(String roomId, List<LiveSticker> items);
}

class LiveStickerRepositoryImpl implements LiveStickerRepository {
  new(this._dio);

  final Dio _dio;

  String _path(String roomId) => '/live/rooms/${pathSegment(roomId)}/stickers';

  @override
  Future<List<String>> catalogue() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/live/stickers');
    return [
      for (final a in res.data!['items']! as List<dynamic>)
        (a as Map<String, dynamic>)['key']! as String,
    ];
  });

  @override
  Future<LiveStickers> get(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_path(roomId));
    return LiveStickers.fromJson(res.data!);
  });

  @override
  Future<LiveStickers> set(String roomId, List<LiveSticker> items) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          _path(roomId),
          data: {
            'items': [for (final i in items) i.toRequest()],
          },
        );
        return LiveStickers.fromJson(res.data!);
      });
}

final liveStickerRepositoryProvider = Provider<LiveStickerRepository>(
  (ref) => LiveStickerRepositoryImpl(ref.watch(apiDioProvider)),
);
