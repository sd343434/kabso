import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart'
    show WaDepartment;

/// v1.137-social (D385, CONVENTIONS §10.174): «دعم كابسو» (tag `support`).
/// Every method throws an `AppFailure`.
abstract interface class SupportRepository {
  /// `GET /support/thread` — always answers (NONE before the first
  /// message).
  Future<SupportThread> thread();

  /// `GET /support/thread/messages`, newest first.
  Future<SupportMessagePage> messages({String? cursor});

  /// `POST /support/thread/messages` (201, or 200 for a retry with the
  /// same [clientId]); [topic] opens a new ticket (required then).
  Future<SupportSendResult> send(
    SupportOutgoing message, {
    required String clientId,
    WaDepartment? topic,
  });

  /// `POST /support/thread/read`.
  Future<void> read();
}

/// v1.137-social (D385, §10.174.4): the pinned chats (tag `messages`).
abstract interface class DmPinsRepository {
  /// `GET /dm/pins`.
  Future<DmPinList> pins();

  /// `PUT` / `DELETE /dm/conversations/{id}/pin` or `/dm/groups/{id}/pin`
  /// (a 6th → 409 `DM_PIN_LIMIT`); the pins after the change.
  Future<DmPinList> setPinned(DmChat chat, {required bool pinned});
}

class ApiSupportRepository implements SupportRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<SupportThread> thread() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/support/thread');
    return SupportThread.fromJson(res.data!);
  });

  @override
  Future<SupportMessagePage> messages({String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/support/thread/messages',
          queryParameters: {'cursor': ?cursor},
        );
        return SupportMessagePage.fromJson(res.data!);
      });

  @override
  Future<SupportSendResult> send(
    SupportOutgoing message, {
    required String clientId,
    WaDepartment? topic,
  }) => guardApiCall(() async {
    final body = switch (message) {
      SupportOutgoingText(:final text) => {'kind': 'TEXT', 'text': text},
      SupportOutgoingMedia(:final mediaId, :final voice) => {
        'kind': voice ? 'VOICE' : 'IMAGE',
        'mediaId': mediaId,
      },
    };
    final res = await _dio.post<Map<String, dynamic>>(
      '/support/thread/messages',
      data: {...body, 'clientId': clientId, 'topic': ?topic?.wire},
    );
    return SupportSendResult.fromJson(res.data!);
  });

  @override
  Future<void> read() => guardApiCall(() async {
    await _dio.post<void>('/support/thread/read');
  });
}

class ApiDmPinsRepository implements DmPinsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<DmPinList> pins() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/dm/pins');
    return DmPinList.fromJson(res.data!);
  });

  @override
  Future<DmPinList> setPinned(DmChat chat, {required bool pinned}) =>
      guardApiCall(() async {
        final path = chat.isGroup
            ? '/dm/groups/${pathSegment(chat.id)}/pin'
            : '/dm/conversations/${pathSegment(chat.id)}/pin';
        final res = pinned
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return DmPinList.fromJson(res.data!);
      });
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => ApiSupportRepository(ref.watch(apiDioProvider)),
);

final dmPinsRepositoryProvider = Provider<DmPinsRepository>(
  (ref) => ApiDmPinsRepository(ref.watch(apiDioProvider)),
);
