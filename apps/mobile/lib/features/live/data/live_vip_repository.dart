import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_vip.dart';

/// v1.132-social (D379, CONVENTIONS §10.169): the live-room VIP operations
/// — the pinned message (PINNED_MESSAGE) and the kept seat (SEAT_RESERVE).
/// The server checks every rule (the perk, its value, one pin at a time,
/// the host); the app shows what it answers.
abstract class LiveVipRepository {
  /// `GET /live/rooms/{roomId}/chat`'s `pin`: the pin showing now, or null.
  Future<LiveChatPin?> currentPin(String roomId);

  /// `POST /live/rooms/{roomId}/chat-pin` — the caller's own message.
  Future<LiveChatPin> pin(String roomId, String messageId);

  /// `DELETE /live/rooms/{roomId}/chat-pin` (the author, the host or a
  /// moderator; idempotent).
  Future<void> unpin(String roomId);

  /// `PUT /live/rooms/{roomId}/seats/{index}/reservation` (the host).
  Future<LiveSeats> reserveSeat(String roomId, int index, String username);

  /// `DELETE /live/rooms/{roomId}/seats/{index}/reservation` (the host).
  Future<LiveSeats> releaseSeat(String roomId, int index);
}

class LiveVipRepositoryImpl implements LiveVipRepository {
  const new(this._dio);

  final Dio _dio;

  String _room(String roomId) => '/live/rooms/${pathSegment(roomId)}';

  @override
  Future<LiveChatPin?> currentPin(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('${_room(roomId)}/chat');
    return LiveChatPin.tryParse(res.data?['pin']);
  });

  @override
  Future<LiveChatPin> pin(String roomId, String messageId) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/chat-pin',
          data: {'messageId': messageId},
        );
        return LiveChatPin.fromJson(res.data!);
      });

  @override
  Future<void> unpin(String roomId) => guardApiCall(() async {
    await _dio.delete<void>('${_room(roomId)}/chat-pin');
  });

  @override
  Future<LiveSeats> reserveSeat(String roomId, int index, String username) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '${_room(roomId)}/seats/$index/reservation',
          data: {'username': username},
        );
        return LiveSeats.fromJson(res.data!);
      });

  @override
  Future<LiveSeats> releaseSeat(String roomId, int index) =>
      guardApiCall(() async {
        final res = await _dio.delete<Map<String, dynamic>>(
          '${_room(roomId)}/seats/$index/reservation',
        );
        return LiveSeats.fromJson(res.data!);
      });
}

final Provider<LiveVipRepository> liveVipRepositoryProvider =
    Provider<LiveVipRepository>(
      (ref) => LiveVipRepositoryImpl(ref.watch(apiDioProvider)),
    );
