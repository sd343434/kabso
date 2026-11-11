import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';

/// v1.116-social (D355, CONVENTIONS §10.151): «واتساب» for the staff's own
/// app account (`/staff/whatsapp/*`, bearer). The server checks the role and
/// the capability `support.whatsapp` on every request. Throws an
/// `AppFailure`.
abstract interface class WaRepository {
  /// `GET …/summary` — the badge (`enabled` false when WhatsApp is off).
  Future<WaSummary> summary();

  /// D366: [department] keeps one department's conversations.
  Future<List<WaConversation>> conversations(
    WaFilter filter, {
    String? q,
    WaDepartment? department,
  });

  Future<WaConversation> conversation(String id);

  /// Newest first (one page of 50).
  Future<List<WaMessage>> messages(String id);

  Future<List<WaNote>> notes(String id);

  Future<WaMessage> sendText(String id, String text);

  Future<WaMessage> sendTemplate(
    String id,
    WaTemplate template,
    List<String> parameters,
  );

  Future<WaMessage> sendMedia(
    String id,
    Uint8List bytes, {
    required String mime,
    required String filename,
  });

  /// The stored media bytes (private; never a public URL).
  Future<Uint8List> media(String messageId);

  Future<WaConversation> markRead(String id);

  /// `claim` / `release` / `close` / `reopen`.
  Future<WaConversation> act(String id, String action);

  /// D366 (§10.159.2): to [department] — [toUserId] in it, or (null) its
  /// first available agent / its queue — with an optional internal [note].
  Future<WaConversation> transfer(
    String id, {
    required WaDepartment department,
    String? toUserId,
    String? note,
  });

  Future<WaNote> addNote(String id, String body);

  Future<WaConversation> link(String id, String username);

  Future<WaConversation> unlink(String id);

  Future<List<WaTemplate>> templates();

  Future<List<WaQuickReply>> quickReplies();

  /// D366: [department] keeps its members (on shift first, then the least
  /// busy).
  Future<List<WaAgent>> agents({WaDepartment? department});

  Future<bool> pushMuted();

  Future<bool> setPushMuted({required bool muted});
}

class WaRepositoryImpl implements WaRepository {
  new(this._dio);

  final Dio _dio;

  static const _base = '/staff/whatsapp';
  String _c(String id) => '$_base/conversations/${pathSegment(id)}';

  List<T> _list<T>(
    Response<Map<String, dynamic>> res,
    T Function(Map<String, dynamic>) f,
  ) => [
    for (final x in res.data!['data']! as List<dynamic>)
      f(x as Map<String, dynamic>),
  ];

  @override
  Future<WaSummary> summary() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('$_base/summary');
    return WaSummary.fromJson(res.data!);
  });

  @override
  Future<List<WaConversation>> conversations(
    WaFilter filter, {
    String? q,
    WaDepartment? department,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_base/conversations',
      queryParameters: {
        'filter': filter.wire,
        'limit': 50,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (department != null) 'department': department.wire,
      },
    );
    return _list(res, WaConversation.fromJson);
  });

  @override
  Future<WaConversation> conversation(String id) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_c(id));
    return WaConversation.fromJson(res.data!);
  });

  @override
  Future<List<WaMessage>> messages(String id) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${_c(id)}/messages',
      queryParameters: {'limit': 50},
    );
    return _list(res, WaMessage.fromJson);
  });

  @override
  Future<List<WaNote>> notes(String id) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('${_c(id)}/notes');
    return _list(res, WaNote.fromJson);
  });

  @override
  Future<WaMessage> sendText(String id, String text) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_c(id)}/messages',
      data: {'type': 'TEXT', 'text': text},
    );
    return WaMessage.fromJson(res.data!);
  });

  @override
  Future<WaMessage> sendTemplate(
    String id,
    WaTemplate template,
    List<String> parameters,
  ) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_c(id)}/messages',
      data: {
        'type': 'TEMPLATE',
        'template': {
          'name': template.name,
          'language': template.language,
          'parameters': parameters,
        },
      },
    );
    return WaMessage.fromJson(res.data!);
  });

  @override
  Future<WaMessage> sendMedia(
    String id,
    Uint8List bytes, {
    required String mime,
    required String filename,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_c(id)}/media',
      queryParameters: {'mime': mime, 'filename': filename},
      data: Stream.fromIterable([bytes]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
    return WaMessage.fromJson(res.data!);
  });

  @override
  Future<Uint8List> media(String messageId) => guardApiCall(() async {
    final res = await _dio.get<List<int>>(
      '$_base/messages/${pathSegment(messageId)}/media',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  });

  @override
  Future<WaConversation> markRead(String id) => act(id, 'read');

  @override
  Future<WaConversation> act(String id, String action) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>('${_c(id)}/$action');
        return WaConversation.fromJson(res.data!);
      });

  @override
  Future<WaConversation> transfer(
    String id, {
    required WaDepartment department,
    String? toUserId,
    String? note,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_c(id)}/transfer',
      data: {
        'department': department.wire,
        'toUserId': ?toUserId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return WaConversation.fromJson(res.data!);
  });

  @override
  Future<WaNote> addNote(String id, String body) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '${_c(id)}/notes',
      data: {'body': body},
    );
    return WaNote.fromJson(res.data!);
  });

  @override
  Future<WaConversation> link(String id, String username) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_c(id)}/link',
          data: {'username': username},
        );
        return WaConversation.fromJson(res.data!);
      });

  @override
  Future<WaConversation> unlink(String id) => guardApiCall(() async {
    final res = await _dio.delete<Map<String, dynamic>>('${_c(id)}/link');
    return WaConversation.fromJson(res.data!);
  });

  @override
  Future<List<WaTemplate>> templates() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('$_base/templates');
    return _list(res, WaTemplate.fromJson);
  });

  @override
  Future<List<WaQuickReply>> quickReplies() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('$_base/quick-replies');
    return _list(res, WaQuickReply.fromJson);
  });

  @override
  Future<List<WaAgent>> agents({WaDepartment? department}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '$_base/agents',
          queryParameters: {'department': ?department?.wire},
        );
        return _list(res, WaAgent.fromJson);
      });

  @override
  Future<bool> pushMuted() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('$_base/me/settings');
    return res.data!['pushMuted'] as bool? ?? false;
  });

  @override
  Future<bool> setPushMuted({required bool muted}) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '$_base/me/settings',
      data: {'pushMuted': muted},
    );
    return res.data!['pushMuted'] as bool? ?? muted;
  });
}

final waRepositoryProvider = Provider<WaRepository>(
  (ref) => WaRepositoryImpl(ref.watch(apiDioProvider)),
);
