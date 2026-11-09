import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;

/// A page of people the caller may add to a group.
typedef DmCandidatePage = ({List<UserSummary> data, String? nextCursor});

/// Group messages «رسائل جماعية» (docs/contracts/openapi.yaml v1.103-social
/// DRAFT, tag `messages`, D339; CONVENTIONS §10.133). Every method throws an
/// `AppFailure`.
abstract interface class DmGroupsRepository {
  /// `GET /dm/group-candidates`: mutual follows who accept messages;
  /// [groupId] leaves out that group's members.
  Future<DmCandidatePage> candidates({
    String? query,
    String? groupId,
    String? cursor,
  });

  /// `POST /dm/groups` (201, or 200 for a retry with the same [clientId]).
  Future<DmGroupDetail> create({
    required String name,
    required List<String> members,
    required String clientId,
    String? photoMediaId,
  });

  /// `GET /dm/groups/{id}`.
  Future<DmGroupDetail> detail(String groupId);

  /// `PATCH /dm/groups/{id}` (admins): [name], a new photo or
  /// [removePhoto].
  Future<DmGroupDetail> update(
    String groupId, {
    String? name,
    String? photoMediaId,
    bool removePhoto = false,
  });

  /// `POST /dm/groups/{id}/members` (admins).
  Future<DmGroupDetail> addMembers(String groupId, List<String> usernames);

  /// `DELETE /dm/groups/{id}/members/{username}` (admins).
  Future<void> removeMember(String groupId, String username);

  /// `PUT /dm/groups/{id}/members/{username}/role` (admins).
  Future<void> setRole(String groupId, String username, DmGroupRole role);

  /// `POST /dm/groups/{id}/leave`.
  Future<void> leave(String groupId);

  /// `GET /dm/groups/{id}/messages`, newest first.
  Future<DmGroupMessagePage> messages(String groupId, {String? cursor});

  /// `POST /dm/groups/{id}/messages` (201, or 200 for a retry).
  Future<DmGroupSendResult> send(
    String groupId,
    DmOutgoing message, {
    required String clientId,
  });

  /// `POST /dm/groups/{id}/read`.
  Future<void> markRead(String groupId, String lastMessageId);

  /// `DELETE /dm/groups/{id}/messages/{messageId}?scope=everyone`.
  Future<void> deleteMessage(String groupId, String messageId);

  /// `PUT` / `DELETE /dm/groups/{id}/mute`.
  Future<void> setMuted(String groupId, {required bool muted});

  /// `PUT` / `DELETE /dm/groups/{id}/archive`.
  Future<void> setArchived(String groupId, {required bool archived});

  /// `POST /reports` (`DM_GROUP`).
  Future<void> report(String groupId, ReportReason reason);
}

class ApiDmGroupsRepository implements DmGroupsRepository {
  new(this._dio);

  final Dio _dio;

  static String _group(String id) => '/dm/groups/${pathSegment(id)}';

  @override
  Future<DmCandidatePage> candidates({
    String? query,
    String? groupId,
    String? cursor,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dm/group-candidates',
      queryParameters: {'q': ?query, 'groupId': ?groupId, 'cursor': ?cursor},
    );
    final body = res.data!;
    return (
      data: [
        for (final u in body['data']! as List<dynamic>)
          UserSummary.fromJson(u as Map<String, dynamic>),
      ],
      nextCursor:
          (body['page']! as Map<String, dynamic>)['nextCursor'] as String?,
    );
  });

  @override
  Future<DmGroupDetail> create({
    required String name,
    required List<String> members,
    required String clientId,
    String? photoMediaId,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/dm/groups',
      data: {
        'name': name,
        'members': members,
        'photoMediaId': ?photoMediaId,
        'clientId': clientId,
      },
    );
    return DmGroupDetail.fromJson(res.data!);
  });

  @override
  Future<DmGroupDetail> detail(String groupId) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(_group(groupId));
    return DmGroupDetail.fromJson(res.data!);
  });

  @override
  Future<DmGroupDetail> update(
    String groupId, {
    String? name,
    String? photoMediaId,
    bool removePhoto = false,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      _group(groupId),
      data: {
        'name': ?name,
        if (removePhoto)
          'photoMediaId': null
        else
          'photoMediaId': ?photoMediaId,
      },
    );
    return DmGroupDetail.fromJson(res.data!);
  });

  @override
  Future<DmGroupDetail> addMembers(String groupId, List<String> usernames) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '${_group(groupId)}/members',
          data: {'members': usernames},
        );
        return DmGroupDetail.fromJson(res.data!);
      });

  @override
  Future<void> removeMember(String groupId, String username) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_group(groupId)}/members/${pathSegment(username)}',
        );
      });

  @override
  Future<void> setRole(String groupId, String username, DmGroupRole role) =>
      guardApiCall(() async {
        await _dio.put<void>(
          '${_group(groupId)}/members/${pathSegment(username)}/role',
          data: {'role': role.wire},
        );
      });

  @override
  Future<void> leave(String groupId) => guardApiCall(() async {
    await _dio.post<void>('${_group(groupId)}/leave');
  });

  @override
  Future<DmGroupMessagePage> messages(String groupId, {String? cursor}) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '${_group(groupId)}/messages',
          queryParameters: {'cursor': ?cursor},
        );
        return DmGroupMessagePage.fromJson(res.data!);
      });

  @override
  Future<DmGroupSendResult> send(
    String groupId,
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
      '${_group(groupId)}/messages',
      data: {...body, 'clientId': clientId},
    );
    return DmGroupSendResult.fromJson(res.data!);
  });

  @override
  Future<void> markRead(String groupId, String lastMessageId) =>
      guardApiCall(() async {
        await _dio.post<void>(
          '${_group(groupId)}/read',
          data: {'lastMessageId': lastMessageId},
        );
      });

  @override
  Future<void> deleteMessage(String groupId, String messageId) =>
      guardApiCall(() async {
        await _dio.delete<void>(
          '${_group(groupId)}/messages/${pathSegment(messageId)}',
          queryParameters: {'scope': 'everyone'},
        );
      });

  @override
  Future<void> setMuted(String groupId, {required bool muted}) =>
      guardApiCall(() async {
        final path = '${_group(groupId)}/mute';
        if (muted) {
          await _dio.put<void>(path);
        } else {
          await _dio.delete<void>(path);
        }
      });

  @override
  Future<void> setArchived(String groupId, {required bool archived}) =>
      guardApiCall(() async {
        final path = '${_group(groupId)}/archive';
        if (archived) {
          await _dio.put<void>(path);
        } else {
          await _dio.delete<void>(path);
        }
      });

  @override
  Future<void> report(String groupId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'DM_GROUP',
            'targetId': groupId,
            'reason': reason.wire,
          },
        );
      });
}

final dmGroupsRepositoryProvider = Provider<DmGroupsRepository>(
  (ref) => ApiDmGroupsRepository(ref.watch(apiDioProvider)),
);
