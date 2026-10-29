import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart'
    show LiveGiftSource;
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;

/// Direct messages (docs/contracts/openapi.yaml v1.40-social DRAFT, tag
/// `messages`, D155; v1.43-social, D165; CONVENTIONS §11.13). Every method
/// throws an `AppFailure`.
abstract interface class DmRepository {
  /// `GET /dm/conversations?box=INBOX|REQUESTS`, newest message first;
  /// v1.43-social (D165): [query] keeps the conversations whose peer's
  /// username or display name starts with it.
  Future<DmConversationPage> conversations({
    bool requests = false,
    String? cursor,
    String? query,
  });

  /// `GET /dm/unread`: the Messages tab badge and the requests count.
  Future<DmUnread> unread();

  /// `GET /dm/peers/{username}`: the person, the conversation if any, and
  /// whether the caller may write.
  Future<DmPeer> peer(String username);

  /// `GET /dm/conversations/{id}/messages`, newest first.
  Future<DmMessagePage> messages(String conversationId, {String? cursor});

  /// `POST /dm/messages` (201, or 200 for a retry with the same
  /// [clientId]); the first message creates the conversation.
  Future<DmSendResult> send(
    String to,
    DmOutgoing message, {
    required String clientId,
  });

  /// `POST /dm/gifts`: a gift in the conversation (the live gift pipeline).
  Future<DmSendResult> sendGift(
    String to, {
    required String giftCode,
    required int quantity,
    required LiveGiftSource source,
    required String clientId,
  });

  /// `POST /dm/conversations/{id}/read`.
  Future<void> markRead(String conversationId, String lastMessageId);

  /// `POST /dm/conversations/{id}/accept`.
  Future<void> accept(String conversationId);

  /// `DELETE /dm/conversations/{id}`: for the caller only (also declines a
  /// request).
  Future<void> deleteConversation(String conversationId);

  /// `PUT` / `DELETE /dm/conversations/{id}/mute`.
  Future<void> setMuted(String conversationId, {required bool muted});

  /// v1.43-social (D165): `PUT` / `DELETE /dm/conversations/{id}/unread`.
  Future<void> setMarkedUnread(String conversationId, {required bool marked});

  /// `DELETE /dm/messages/{id}?scope=me|everyone`.
  Future<void> deleteMessage(String messageId, {required bool forEveryone});

  /// `POST /reports` for a message the caller received (`DM_MESSAGE`).
  Future<void> reportMessage(String messageId, ReportReason reason);
}

class ApiDmRepository implements DmRepository {
  new(this._dio);

  final Dio _dio;

  static String _conv(String id) => '/dm/conversations/${pathSegment(id)}';

  @override
  Future<DmConversationPage> conversations({
    bool requests = false,
    String? cursor,
    String? query,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dm/conversations',
      queryParameters: {
        'box': requests ? 'REQUESTS' : 'INBOX',
        'q': ?query,
        'cursor': ?cursor,
      },
    );
    final body = res.data!;
    return DmConversationPage([
      for (final c in body['data']! as List<dynamic>)
        DmConversation.fromJson(c as Map<String, dynamic>),
    ], (body['page']! as Map<String, dynamic>)['nextCursor'] as String?);
  });

  @override
  Future<DmUnread> unread() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/dm/unread');
    return DmUnread.fromJson(res.data!);
  });

  @override
  Future<DmPeer> peer(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dm/peers/${pathSegment(username)}',
    );
    return DmPeer.fromJson(res.data!);
  });

  @override
  Future<DmMessagePage> messages(String conversationId, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_conv(conversationId)}/messages',
          queryParameters: {'cursor': ?cursor},
        );
        return DmMessagePage.fromJson(res.data!);
      });

  @override
  Future<DmSendResult> send(
    String to,
    DmOutgoing message, {
    required String clientId,
  }) => guardApiCall(() async {
    final body = switch (message) {
      DmOutgoingText(:final text) => {'kind': 'TEXT', 'text': text},
      DmOutgoingEmoji(:final token) => {'kind': 'EMOJI', 'token': token},
      DmOutgoingMedia(:final mediaId, :final voice) => {
        'kind': voice ? 'VOICE' : 'IMAGE',
        'mediaId': mediaId,
      },
    };
    final res = await _dio.post<Map<String, dynamic>>(
      '/dm/messages',
      data: {'to': to, ...body, 'clientId': clientId},
    );
    return DmSendResult.fromJson(res.data!);
  });

  @override
  Future<DmSendResult> sendGift(
    String to, {
    required String giftCode,
    required int quantity,
    required LiveGiftSource source,
    required String clientId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/dm/gifts',
      data: {
        'to': to,
        'giftCode': giftCode,
        'quantity': quantity,
        'source': source == LiveGiftSource.bag ? 'BAG' : 'COINS',
        'clientId': clientId,
      },
    );
    return DmSendResult.fromJson(res.data!);
  });

  @override
  Future<void> markRead(String conversationId, String lastMessageId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_conv(conversationId)}/read',
          data: {'lastMessageId': lastMessageId},
        );
      });

  @override
  Future<void> accept(String conversationId) => guardApiCall(() async {
    await _dio.post<void>('${_conv(conversationId)}/accept');
  });

  @override
  Future<void> deleteConversation(String conversationId) =>
      guardApiCall(() async {
        await _dio.delete<void>(_conv(conversationId));
      });

  @override
  Future<void> setMuted(String conversationId, {required bool muted}) =>
      guardApiCall(() async {
        final path = '${_conv(conversationId)}/mute';
        if (muted) {
          await _dio.put<void>(path);
        } else {
          await _dio.delete<void>(path);
        }
      });

  @override
  Future<void> setMarkedUnread(String conversationId, {required bool marked}) =>
      guardApiCall(() async {
        final path = '${_conv(conversationId)}/unread';
        if (marked) {
          await _dio.put<void>(path);
        } else {
          await _dio.delete<void>(path);
        }
      });

  @override
  Future<void> deleteMessage(String messageId, {required bool forEveryone}) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '/dm/messages/${pathSegment(messageId)}',
          queryParameters: {'scope': forEveryone ? 'everyone' : 'me'},
        );
      });

  @override
  Future<void> reportMessage(String messageId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'DM_MESSAGE',
            'targetId': messageId,
            'reason': reason.wire,
          },
        );
      });
}

final dmRepositoryProvider = Provider<DmRepository>(
  (ref) => ApiDmRepository(ref.watch(apiDioProvider)),
);
