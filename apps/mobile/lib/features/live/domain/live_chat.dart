// Live room chat (CP-013, contract v1.9-live, CONVENTIONS §10.11).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';

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

/// The server's chat data messages in the media room (topic `chat`).
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
