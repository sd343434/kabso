import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:material_ui/material_ui.dart';

/// Who may mention the caller (`whoCanMention`).
enum MentionPolicy {
  everyone('EVERYONE'),
  following('FOLLOWING'),
  nobody('NOBODY');

  new(this.wire);

  final String wire;

  static MentionPolicy fromWire(Object? v) => values.firstWhere(
    (p) => p.wire == v,
    orElse: () => throw const FormatException('whoCanMention'),
  );
}

/// `PrivacySettings` (CONVENTIONS §11.7).
@immutable
class PrivacySettings {
  const new({
    required this.whoCanMention,
    required this.defaultWhoCanComment,
    this.showActivityStatus = true,
    this.whoCanMessage = MentionPolicy.everyone,
    this.isPrivate = false,
    this.hideCherriesReceived,
    this.hideCoinsSent,
  });

  factory fromJson(Map<String, dynamic> json) => PrivacySettings(
    whoCanMention: MentionPolicy.fromWire(json['whoCanMention']),
    defaultWhoCanComment: WhoCanComment.fromWire(json['defaultWhoCanComment']),
    showActivityStatus: json['showActivityStatus'] as bool? ?? true,
    // v1.40-social (D155); absent from older servers: everyone.
    whoCanMessage: json['whoCanMessage'] == null
        ? MentionPolicy.everyone
        : MentionPolicy.fromWire(json['whoCanMessage']),
    // v1.47-social (D175); absent from older servers: public.
    isPrivate: json['isPrivate'] as bool? ?? false,
    // v1.77-social (D220); absent from older servers: no switch shown.
    hideCherriesReceived: json['hideCherriesReceived'] as bool?,
    hideCoinsSent: json['hideCoinsSent'] as bool?,
  );

  final MentionPolicy whoCanMention;

  /// Who may comment on the caller's new posts unless the post says
  /// otherwise.
  final WhoCanComment defaultWhoCanComment;

  /// v1.25-live (CP-022, §10.25): family members may see when the caller was
  /// last active.
  final bool showActivityStatus;

  /// v1.40-social (D155, §11.13): who may send the caller direct messages
  /// («من يستطيع مراسلتك»): everyone (default), people the caller follows,
  /// or no one. Same three values as [whoCanMention].
  final MentionPolicy whoCanMessage;

  /// v1.47-social (D175, §10.47): a private account — following it is a
  /// request; posts, reels and stories are for followers only.
  final bool isPrivate;

  /// v1.77-social (D220, §10.74): «إخفاء الكرز المستلم» — others do not
  /// see the lifetime cherries received on the caller's card. Null: the
  /// server does not have the switch (older API), so it is not shown.
  final bool? hideCherriesReceived;

  /// v1.77-social (D220, §10.74): «إخفاء الكوينز المرسلة»; null like
  /// [hideCherriesReceived].
  final bool? hideCoinsSent;
}

/// Block, mute, reports of users and privacy (docs/contracts/openapi.yaml
/// v1.5-social, tag `safety`; CONVENTIONS §11.7). Every method throws an
/// `AppFailure`.
abstract interface class SafetyRepository {
  /// `PUT`/`DELETE /users/{username}/block`: blocked afterwards or not.
  Future<bool> setBlocked(String username, {required bool blocked});

  /// `PUT`/`DELETE /users/{username}/mute`: muted afterwards or not.
  Future<bool> setMuted(String username, {required bool muted});

  /// `GET /me/blocks`: the accounts the caller blocked, newest first.
  Future<PageOf<UserSummary>> blocks({String? cursor});

  /// `GET /me/mutes` (CP-007): the accounts the caller muted, newest first.
  Future<PageOf<UserSummary>> mutes({String? cursor});

  /// `POST /reports` for a user (`targetId` the user's id — accepted since
  /// v1.93-social, D296). [dmConversationId]: reported from that direct
  /// conversation, so the report keeps the whole conversation for the staff.
  Future<void> reportUser(
    String userId,
    ReportReason reason, {
    String? dmConversationId,
  });

  /// v1.47-social (D175): `POST /reports` for a profile link
  /// (`targetType: PROFILE_LINK`, the link's id).
  Future<void> reportProfileLink(String linkId, ReportReason reason);

  /// v1.60-live (D250, §10.91.3): «الإبلاغ عن البث» — `POST /reports` for a
  /// live (`targetType: LIVE_ROOM`, the room's id) with an optional [note]
  /// (≤ 500). A repeat while the first is open is accepted (200).
  Future<void> reportLive(String roomId, ReportReason reason, {String? note});

  /// `GET /me/privacy`.
  Future<PrivacySettings> privacy();

  /// `PATCH /me/privacy` with only what changes.
  Future<PrivacySettings> updatePrivacy({
    MentionPolicy? whoCanMention,
    WhoCanComment? defaultWhoCanComment,
    bool? showActivityStatus,
    MentionPolicy? whoCanMessage,
    bool? isPrivate,
    bool? hideCherriesReceived,
    bool? hideCoinsSent,
  });
}

class SafetyRepositoryImpl implements SafetyRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<bool> setBlocked(String username, {required bool blocked}) =>
      guardApiCall(() async {
        final path = '/users/${pathSegment(username)}/block';
        final res = blocked
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return res.data!['blocked']! as bool;
      });

  @override
  Future<bool> setMuted(String username, {required bool muted}) =>
      guardApiCall(() async {
        final path = '/users/${pathSegment(username)}/mute';
        final res = muted
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return res.data!['muted']! as bool;
      });

  Future<PageOf<UserSummary>> _users(String path, String? cursor) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: {'cursor': ?cursor},
        );
        final body = res.data!;
        return PageOf([
          for (final u in body['data']! as List<dynamic>)
            UserSummary.fromJson(u as Map<String, dynamic>),
        ], PageInfo.fromJson(body['page']! as Map<String, dynamic>));
      });

  @override
  Future<PageOf<UserSummary>> blocks({String? cursor}) =>
      _users('/me/blocks', cursor);

  @override
  Future<PageOf<UserSummary>> mutes({String? cursor}) =>
      _users('/me/mutes', cursor);

  @override
  Future<void> reportUser(
    String userId,
    ReportReason reason, {
    String? dmConversationId,
  }) => guardApiCall(() async {
    await _dio.post<Map<String, dynamic>>(
      '/reports',
      data: {
        'targetType': 'USER',
        'targetId': userId,
        'reason': reason.wire,
        'dmConversationId': ?dmConversationId,
      },
    );
  });

  @override
  Future<void> reportProfileLink(String linkId, ReportReason reason) =>
      guardApiCall(() async {
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'PROFILE_LINK',
            'targetId': linkId,
            'reason': reason.wire,
          },
        );
      });

  @override
  Future<void> reportLive(String roomId, ReportReason reason, {String? note}) =>
      guardApiCall(() async {
        final text = note?.trim();
        await _dio.post<Map<String, dynamic>>(
          '/reports',
          data: {
            'targetType': 'LIVE_ROOM',
            'targetId': roomId,
            'reason': reason.wire,
            if (text != null && text.isNotEmpty) 'note': text,
          },
        );
      });

  @override
  Future<PrivacySettings> privacy() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/privacy');
    return PrivacySettings.fromJson(res.data!);
  });

  @override
  Future<PrivacySettings> updatePrivacy({
    MentionPolicy? whoCanMention,
    WhoCanComment? defaultWhoCanComment,
    bool? showActivityStatus,
    MentionPolicy? whoCanMessage,
    bool? isPrivate,
    bool? hideCherriesReceived,
    bool? hideCoinsSent,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/me/privacy',
      data: {
        'whoCanMention': ?whoCanMention?.wire,
        'defaultWhoCanComment': ?defaultWhoCanComment?.wire,
        'showActivityStatus': ?showActivityStatus,
        'whoCanMessage': ?whoCanMessage?.wire,
        'isPrivate': ?isPrivate,
        'hideCherriesReceived': ?hideCherriesReceived,
        'hideCoinsSent': ?hideCoinsSent,
      },
    );
    return PrivacySettings.fromJson(res.data!);
  });
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepositoryImpl(ref.watch(apiDioProvider)),
);
