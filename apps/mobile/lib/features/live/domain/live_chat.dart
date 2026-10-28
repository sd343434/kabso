// Live room chat (CP-013, contract v1.9-live, CONVENTIONS §10.11).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_seat_emoji.dart';

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

/// `LiveChatAuthorFamily` (v1.24.4-live, D119): the author's family.
@freezed
abstract class LiveChatAuthorFamily with _$LiveChatAuthorFamily {
  const factory({required String name, required int level}) =
      _LiveChatAuthorFamily;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveChatAuthorFamilyFromJson(json);
}

/// `LiveChatAuthorBadges` (v1.24.4-live, D119, §10.11): the badges under
/// the author's name — the charm (`ATTRACTIVENESS`) and `SUPPORT` level
/// numbers (null while a category is unavailable) and the family (null when
/// none). The line shows only those present.
@freezed
abstract class LiveChatAuthorBadges with _$LiveChatAuthorBadges {
  const factory({
    int? charmLevel,
    int? supportLevel,
    LiveChatAuthorFamily? family,
  }) = _LiveChatAuthorBadges;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveChatAuthorBadgesFromJson(json);
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

    /// v1.24-live (CP-021, §10.24): the author's couple had the Exclusive
    /// Chat Bubble (`CHAT_BUBBLE`) when it was sent; the line is drawn in
    /// the CP bubble. Older servers send nothing (false).
    @Default(false) bool cpBubble,

    /// v1.24.4-live (D119): the author's level and family badges; older
    /// servers send none (null: no badges).
    LiveChatAuthorBadges? authorBadges,
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
          cp: LiveJoinCp.tryParse(json['cp']),
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
        'lucky-win' => LuckyWinReceived(
          LuckyWin.fromJson(json['win']! as Map<String, dynamic>),
        ),
        // v1.30-live (D148): a big win in another live («لحظة الحظ»).
        'lucky-ticker' => LuckyTickerReceived(LuckyTicker.fromJson(json)),
        // v1.27.5-live (D138): an emoji on someone's own seat.
        'seat-emoji' => LiveSeatEmojiReceived(LiveSeatEmoji.fromJson(json)),
        // v1.32-live (D154): a quip (or soundboard sound) for the room.
        'quip' => LiveQuipReceived(
          LiveQuip.fromJson(json['quip']! as Map<String, dynamic>),
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
  const new(this.user, {this.cp});

  final UserSummary user;

  /// v1.24-live (CP-021, §10.24): the joiner's couple, when it unlocked the
  /// Entrance Effect; null for a normal join.
  final LiveJoinCp? cp;
}

/// The `cp` of a live `join` data message (v1.24-live, CP-021, §10.24):
/// the joiner's couple, sent only when it unlocked `ENTRANCE_EFFECT`.
final class LiveJoinCp {
  const new({
    required this.coupleId,
    required this.partner,
    required this.level,
  });

  final String coupleId;
  final UserSummary partner;

  /// The CP level (1–6).
  final int level;

  /// Reads [json]; null when absent or malformed (the join still counts,
  /// as a normal one).
  static LiveJoinCp? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return LiveJoinCp(
        coupleId: json['coupleId']! as String,
        partner: UserSummary.fromJson(json['partner']! as Map<String, dynamic>),
        level: (json['level']! as num).toInt(),
      );
    } on Object {
      return null;
    }
  }
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

/// v1.27-live (D132, §10.27): a big lucky win in this live (topic `lucky`).
final class LuckyWinReceived extends LiveChatEvent {
  const new(this.win);

  final LuckyWin win;
}

/// v1.30-live (D148, §10.27): a big lucky win in another live (topic
/// `lucky`, `lucky-ticker`), shown as the global gold ticker.
final class LuckyTickerReceived extends LiveChatEvent {
  const new(this.ticker);

  final LuckyTicker ticker;
}

/// v1.27.5-live (D138, §10.30): someone played an emoji on their own seat.
final class LiveSeatEmojiReceived extends LiveChatEvent {
  const new(this.emoji);

  final LiveSeatEmoji emoji;
}

/// v1.32-live (D154, §10.33): a quip or a soundboard sound for the whole
/// room (topic `quip`), played after its `delayMs`, one at a time.
final class LiveQuipReceived extends LiveChatEvent {
  const new(this.quip);

  final LiveQuip quip;
}
