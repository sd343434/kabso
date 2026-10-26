// Live room chat (CP-013, contract v1.9-live, CONVENTIONS §10.11).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

part 'live_chat.freezed.dart';
part 'live_chat.g.dart';

/// The author's role in the room when they sent the message.
enum LiveChatRole {
  @JsonValue('HOST')
  host,
  @JsonValue('MODERATOR')
  moderator,
  @JsonValue('SPEAKER')
  speaker,
  @JsonValue('VIEWER')
  viewer,
}

/// `LiveChatMessageKind` (CP-017): a text line, a voice clip or a picture.
enum LiveChatKind {
  @JsonValue('TEXT')
  text,
  @JsonValue('VOICE')
  voice,
  @JsonValue('IMAGE')
  image,
}

/// The `MediaAsset` of a VOICE or IMAGE message (CP-017, §11.1): a voice
/// clip (`type: AUDIO`, with [durationMs]) or a picture.
@freezed
abstract class LiveChatMedia with _$LiveChatMedia {
  const factory({
    required String id,
    required String url,
    required String thumbUrl,
    @Default(0) int width,
    @Default(0) int height,
    int? durationMs,
  }) = _LiveChatMedia;

  factory fromJson(Map<String, dynamic> json) => _$LiveChatMediaFromJson(json);
}

/// `LiveChatMessage`: one stored chat message.
@freezed
abstract class LiveChatEntry with _$LiveChatEntry {
  const factory({
    required String id,
    required String roomId,
    required UserSummary author,
    @JsonKey(unknownEnumValue: LiveChatRole.viewer)
    required LiveChatRole authorRole,
    required String text,
    required DateTime createdAt,
    // CP-017: older servers send no kind (a text line).
    @JsonKey(unknownEnumValue: LiveChatKind.text)
    @Default(LiveChatKind.text)
    LiveChatKind kind,

    /// The clip or picture of a VOICE / IMAGE message; null for TEXT and
    /// once it expired.
    LiveChatMedia? media,

    /// VOICE and IMAGE: sent + 60 s, when the app hides it (§10.19).
    DateTime? expiresAt,
  }) = _LiveChatEntry;

  factory fromJson(Map<String, dynamic> json) => _$LiveChatEntryFromJson(json);
}

/// `LiveChatMute`: someone muted in this live's chat.
@freezed
abstract class LiveChatMute with _$LiveChatMute {
  const factory({required UserSummary user, required DateTime mutedAt}) =
      _LiveChatMute;

  factory fromJson(Map<String, dynamic> json) => _$LiveChatMuteFromJson(json);
}

/// `LiveBullet` (CP-017, §10.19): a paid line shown over every live.
@freezed
abstract class LiveBullet with _$LiveBullet {
  const factory({
    required String id,
    required String text,
    required UserSummary sender,
    required String roomId,
    required DateTime createdAt,
  }) = _LiveBullet;

  factory fromJson(Map<String, dynamic> json) => _$LiveBulletFromJson(json);
}

/// The server's chat data messages in the media room (topic `chat`),
/// bullets (topic `bullet`, CP-017), kicks (topic `kick`, v1.20-live) and
/// gifts (topic `gift`, CP-020).
sealed class LiveChatEvent {
  const new();

  /// Reads one data message; `null` for anything else (other types, other
  /// features' messages, malformed ones).
  static LiveChatEvent? parse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return switch (json['type']) {
        'chat' => LiveChatReceived(
          LiveChatEntry.fromJson(json['message']! as Map<String, dynamic>),
        ),
        'chat-delete' => LiveChatDeleted(json['id']! as String),
        'join' => LiveChatJoined(
          UserSummary.fromJson(json['user']! as Map<String, dynamic>),
        ),
        'chat-state' => LiveChatStateChanged(enabled: json['enabled']! as bool),
        'bullet' => LiveBulletReceived(
          LiveBullet.fromJson(json['bullet']! as Map<String, dynamic>),
        ),
        'kick' => LiveKickReceived(
          UserSummary.fromJson(json['user']! as Map<String, dynamic>),
        ),
        'gift' => LiveGiftReceived(
          LiveGift.fromJson(json['gift']! as Map<String, dynamic>),
        ),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

final class LiveChatReceived extends LiveChatEvent {
  const new(this.message);

  final LiveChatEntry message;
}

final class LiveChatDeleted extends LiveChatEvent {
  const new(this.id);

  final String id;
}

final class LiveChatJoined extends LiveChatEvent {
  const new(this.user);

  final UserSummary user;
}

final class LiveChatStateChanged extends LiveChatEvent {
  const new({required this.enabled});

  final bool enabled;
}

/// v1.20-live (D105, §10.20): the host or a moderator kicked [user] out of
/// this live (topic `kick`). The kicked person's app leaves; the others
/// drop them from their lists.
final class LiveKickReceived extends LiveChatEvent {
  const new(this.user);

  final UserSummary user;
}

/// CP-017: a bullet sent in any live (topic `bullet`).
final class LiveBulletReceived extends LiveChatEvent {
  const new(this.bullet);

  final LiveBullet bullet;
}

/// CP-020 (§10.23): a gift sent in this live (topic `gift`); every viewer
/// plays its effect.
final class LiveGiftReceived extends LiveChatEvent {
  const new(this.gift);

  final LiveGift gift;
}
