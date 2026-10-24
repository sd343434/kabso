import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;

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

  /// `POST /live/rooms` (CP-010: needs the hosting permission). CP-011:
  /// [mode] SOLO, MULTI or AUDIO; [seatCount] for MULTI and AUDIO only.
  Future<LiveRoom> startRoom({
    required String title,
    String? categorySlug,
    bool allowGuests = true,
    LiveRoomMode mode = LiveRoomMode.solo,
    int? seatCount,
    String? theme,
  });

  /// `POST /live/rooms/{roomId}/heartbeat` (host).
  Future<void> heartbeat(String roomId);

  /// `POST /live/rooms/{roomId}/end` (host; idempotent).
  Future<LiveRoom> endRoom(String roomId);

  /// `PATCH /live/rooms/{roomId}` (host): the guests switch.
  Future<LiveRoom> setAllowGuests(String roomId, {required bool allow});

  /// `PATCH /live/rooms/{roomId}` (host, CP-011): seat count and theme.
  Future<LiveRoom> updateRoom(String roomId, {int? seatCount, String? theme});

  // ---- CP-011 seats ----------------------------------------------------

  /// `GET /live/rooms/{roomId}/seats`.
  Future<LiveSeats> seats(String roomId);

  /// `POST /live/rooms/{roomId}/seat-requests`.
  Future<LiveSeatRequest> requestSeat(String roomId, {int? seatIndex});

  /// `DELETE /live/rooms/{roomId}/seat-requests/me`.
  Future<void> cancelSeatRequest(String roomId);

  /// `GET /live/rooms/{roomId}/seat-requests` (host, moderators).
  Future<({List<LiveSeatRequest> items, String? next})> seatRequests(
    String roomId, {
    String? cursor,
  });

  /// `POST …/seat-requests/{requestId}/accept`.
  Future<LiveSeats> acceptSeatRequest(
    String roomId,
    String requestId, {
    int? seatIndex,
  });

  /// `POST …/seat-requests/{requestId}/decline`.
  Future<void> declineSeatRequest(String roomId, String requestId);

  /// `POST /live/rooms/{roomId}/seat-invites`.
  Future<LiveSeatInvite> inviteToSeat(
    String roomId,
    String username, {
    int? seatIndex,
  });

  /// `POST …/seat-invites/me/accept`.
  Future<LiveSeats> acceptSeatInvite(String roomId);

  /// `POST …/seat-invites/me/decline`.
  Future<void> declineSeatInvite(String roomId);

  /// `POST …/seats/me/leave`.
  Future<void> leaveSeat(String roomId);

  /// `POST …/seats/{index}/mute`.
  Future<LiveSeats> muteSeat(String roomId, int index, {required bool muted});

  /// `POST …/seats/{index}/remove`.
  Future<LiveSeats> removeFromSeat(String roomId, int index);

  /// `POST …/seats/{index}/lock` (host).
  Future<LiveSeats> lockSeat(String roomId, int index, {required bool locked});

  /// `PUT /live/rooms/{roomId}/moderators/{username}` (host).
  Future<LiveSeats> addModerator(String roomId, String username);

  /// `DELETE /live/rooms/{roomId}/moderators/{username}` (host).
  Future<LiveSeats> removeModerator(String roomId, String username);

  /// `POST /live/rooms/{roomId}/media-token`; [guestId] only without an
  /// account.
  Future<LiveMediaAccess> mediaToken(String roomId, {String? guestId});

  /// `GET /live/rooms/{roomId}/viewers` (host): who is watching now.
  Future<({List<LiveViewer> items, String? next})> viewers(
    String roomId, {
    String? cursor,
  });

  /// `POST /live/rooms/{roomId}/taps` (CP-012): a batch of 1–50 taps.
  Future<LiveTapsResult> tap(String roomId, int count);

  /// `PATCH /live/rooms/{roomId}` (host, CP-014): the title, the category
  /// (`null`: none) and the topic (`null`: none), all three sent.
  Future<LiveRoom> editRoom(
    String roomId, {
    required String title,
    required String? categorySlug,
    required String? topic,
  });

  /// `GET /live/rooms/{roomId}/contributors` (CP-014): the top 50.
  Future<List<LiveContributor>> contributors(String roomId);

  // ---- CP-013 chat (CONVENTIONS §10.11) ---------------------------------

  /// `GET /live/rooms/{roomId}/chat`: the last 50 messages, oldest first.
  Future<List<LiveChatEntry>> chatMessages(String roomId);

  /// `POST /live/rooms/{roomId}/chat`; a retry with the same [clientId]
  /// returns the first message.
  Future<LiveChatEntry> sendChat(
    String roomId, {
    required String text,
    required String clientId,
  });

  /// `DELETE /live/rooms/{roomId}/chat/{messageId}` (the author, the host or
  /// a moderator; idempotent).
  Future<void> deleteChat(String roomId, String messageId);

  /// `GET /live/rooms/{roomId}/chat/mutes` (host, moderator).
  Future<List<LiveChatMute>> chatMutes(String roomId);

  /// `PUT` / `DELETE /live/rooms/{roomId}/chat/mutes/{username}`.
  Future<void> setChatMuted(
    String roomId,
    String username, {
    required bool muted,
  });

  /// `PATCH /live/rooms/{roomId}` `chatEnabled` (host).
  Future<LiveRoom> setChatEnabled(String roomId, {required bool enabled});

  /// `POST /reports` with `targetType: LIVE_CHAT_MESSAGE`.
  Future<void> reportChatMessage(String messageId, ReportReason reason);

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

  @override
  Future<LiveRoom> startRoom({
    required String title,
    String? categorySlug,
    bool allowGuests = true,
    LiveRoomMode mode = LiveRoomMode.solo,
    int? seatCount,
    String? theme,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/live/rooms',
      data: {
        'title': title,
        'categorySlug': ?categorySlug,
        'allowGuests': allowGuests,
        if (mode != LiveRoomMode.solo) 'mode': mode.wire,
        'seatCount': ?seatCount,
        'theme': ?theme,
      },
    );
    return LiveRoom.fromJson(res.data!);
  });

  @override
  Future<void> heartbeat(String roomId) => guardApiCall(() async {
    await _dio.post<void>('/live/rooms/${pathSegment(roomId)}/heartbeat');
  });

  @override
  Future<LiveRoom> endRoom(String roomId) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/live/rooms/${pathSegment(roomId)}/end',
    );
    return LiveRoom.fromJson(res.data!);
  });

  @override
  Future<LiveRoom> setAllowGuests(String roomId, {required bool allow}) =>
      guardApiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/live/rooms/${pathSegment(roomId)}',
          data: {'allowGuests': allow},
        );
        return LiveRoom.fromJson(res.data!);
      });

  @override
  Future<LiveMediaAccess> mediaToken(String roomId, {String? guestId}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/live/rooms/${pathSegment(roomId)}/media-token',
          data: {'guestId': ?guestId},
        );
        return LiveMediaAccess.fromJson(res.data!);
      });

  @override
  Future<LiveRoom> editRoom(
    String roomId, {
    required String title,
    required String? categorySlug,
    required String? topic,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      _room(roomId),
      data: {'title': title, 'categorySlug': categorySlug, 'topic': topic},
    );
    return LiveRoom.fromJson(res.data!);
  });

  @override
  Future<List<LiveContributor>> contributors(String roomId) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_room(roomId)}/contributors',
        );
        return [
          for (final c in res.data!['data']! as List<dynamic>)
            LiveContributor.fromJson(c as Map<String, dynamic>),
        ];
      });

  @override
  Future<({List<LiveViewer> items, String? next})> viewers(
    String roomId, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/live/rooms/${pathSegment(roomId)}/viewers',
      queryParameters: {'cursor': ?cursor},
    );
    final body = res.data!;
    final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
    return (
      items: [
        for (final v in body['data']! as List<dynamic>)
          LiveViewer.fromJson(v as Map<String, dynamic>),
      ],
      next: page.hasMore ? page.nextCursor : null,
    );
  });

  @override
  Future<LiveTapsResult> tap(String roomId, int count) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/live/rooms/${pathSegment(roomId)}/taps',
          data: {'count': count},
        );
        return LiveTapsResult.fromJson(res.data!);
      });

  @override
  Future<LiveRoom> updateRoom(String roomId, {int? seatCount, String? theme}) =>
      guardApiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/live/rooms/${pathSegment(roomId)}',
          data: {'seatCount': ?seatCount, 'theme': ?theme},
        );
        return LiveRoom.fromJson(res.data!);
      });

  String _room(String roomId) => '/live/rooms/${pathSegment(roomId)}';

  Future<LiveSeats> _seatsCall(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) => guardApiCall(() async => LiveSeats.fromJson((await call()).data!));

  @override
  Future<LiveSeats> seats(String roomId) =>
      _seatsCall(() => _dio.get('${_room(roomId)}/seats'));

  @override
  Future<LiveSeatRequest> requestSeat(String roomId, {int? seatIndex}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_room(roomId)}/seat-requests',
          data: {'seatIndex': ?seatIndex},
        );
        return LiveSeatRequest.fromJson(res.data!);
      });

  @override
  Future<void> cancelSeatRequest(String roomId) => guardApiCall(() async {
    await _dio.delete<void>('${_room(roomId)}/seat-requests/me');
  });

  @override
  Future<({List<LiveSeatRequest> items, String? next})> seatRequests(
    String roomId, {
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_room(roomId)}/seat-requests',
      queryParameters: {'cursor': ?cursor},
    );
    final body = res.data!;
    final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
    return (
      items: [
        for (final r in body['data']! as List<dynamic>)
          LiveSeatRequest.fromJson(r as Map<String, dynamic>),
      ],
      next: page.hasMore ? page.nextCursor : null,
    );
  });

  @override
  Future<LiveSeats> acceptSeatRequest(
    String roomId,
    String requestId, {
    int? seatIndex,
  }) => _seatsCall(
    () => _dio.post(
      '${_room(roomId)}/seat-requests/${pathSegment(requestId)}/accept',
      data: {'seatIndex': ?seatIndex},
    ),
  );

  @override
  Future<void> declineSeatRequest(String roomId, String requestId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_room(roomId)}/seat-requests/${pathSegment(requestId)}/decline',
        );
      });

  @override
  Future<LiveSeatInvite> inviteToSeat(
    String roomId,
    String username, {
    int? seatIndex,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/seat-invites',
      data: {'username': username, 'seatIndex': ?seatIndex},
    );
    return LiveSeatInvite.fromJson(res.data!);
  });

  @override
  Future<LiveSeats> acceptSeatInvite(String roomId) =>
      _seatsCall(() => _dio.post('${_room(roomId)}/seat-invites/me/accept'));

  @override
  Future<void> declineSeatInvite(String roomId) => guardApiCall(() async {
    await _dio.post<void>('${_room(roomId)}/seat-invites/me/decline');
  });

  @override
  Future<void> leaveSeat(String roomId) => guardApiCall(() async {
    await _dio.post<void>('${_room(roomId)}/seats/me/leave');
  });

  @override
  Future<LiveSeats> muteSeat(String roomId, int index, {required bool muted}) =>
      _seatsCall(
        () => _dio.post(
          '${_room(roomId)}/seats/$index/mute',
          data: {'muted': muted},
        ),
      );

  @override
  Future<LiveSeats> removeFromSeat(String roomId, int index) =>
      _seatsCall(() => _dio.post('${_room(roomId)}/seats/$index/remove'));

  @override
  Future<LiveSeats> lockSeat(
    String roomId,
    int index, {
    required bool locked,
  }) => _seatsCall(
    () => _dio.post(
      '${_room(roomId)}/seats/$index/lock',
      data: {'locked': locked},
    ),
  );

  @override
  Future<LiveSeats> addModerator(String roomId, String username) => _seatsCall(
    () => _dio.put('${_room(roomId)}/moderators/${pathSegment(username)}'),
  );

  @override
  Future<LiveSeats> removeModerator(String roomId, String username) =>
      _seatsCall(
        () =>
            _dio.delete('${_room(roomId)}/moderators/${pathSegment(username)}'),
      );

  @override
  Future<List<LiveChatEntry>> chatMessages(String roomId) => guardApiCall(
    () async {
      final res = await _dio.get<Map<String, dynamic>>('${_room(roomId)}/chat');
      return [
        for (final m in res.data!['data']! as List<dynamic>)
          LiveChatEntry.fromJson(m as Map<String, dynamic>),
      ];
    },
  );

  @override
  Future<LiveChatEntry> sendChat(
    String roomId, {
    required String text,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_room(roomId)}/chat',
      data: {'text': text, 'clientId': clientId},
    );
    return LiveChatEntry.fromJson(res.data!);
  });

  @override
  Future<void> deleteChat(String roomId, String messageId) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_room(roomId)}/chat/${pathSegment(messageId)}',
        );
      });

  @override
  Future<List<LiveChatMute>> chatMutes(String roomId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_room(roomId)}/chat/mutes',
    );
    return [
      for (final m in res.data!['data']! as List<dynamic>)
        LiveChatMute.fromJson(m as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> setChatMuted(
    String roomId,
    String username, {
    required bool muted,
  }) => guardApiCall(() async {
    final path = '${_room(roomId)}/chat/mutes/${pathSegment(username)}';
    if (muted) {
      await _dio.put<void>(path);
    } else {
      await _dio.delete<void>(path);
    }
  });

  @override
  Future<LiveRoom> setChatEnabled(String roomId, {required bool enabled}) =>
      guardApiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          _room(roomId),
          data: {'chatEnabled': enabled},
        );
        return LiveRoom.fromJson(res.data!);
      });

  @override
  Future<void> reportChatMessage(String messageId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'LIVE_CHAT_MESSAGE',
            'targetId': messageId,
            'reason': reason.wire,
          },
        );
      });
}

/// D86: test builds with Demo data on get the demo hub (no server).
final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => watchDemo(ref)
      ? DemoLiveRepository(ar: DemoData.arabic(ref))
      : LiveRepositoryImpl(ref.watch(apiDioProvider)),
);
