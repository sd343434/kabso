// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveChatMedia _$LiveChatMediaFromJson(Map<String, dynamic> json) =>
    _LiveChatMedia(
      id: json['id'] as String,
      url: json['url'] as String,
      thumbUrl: json['thumbUrl'] as String,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LiveChatMediaToJson(_LiveChatMedia instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'thumbUrl': instance.thumbUrl,
      'width': instance.width,
      'height': instance.height,
      'durationMs': instance.durationMs,
    };

_LiveChatAuthorFamily _$LiveChatAuthorFamilyFromJson(
  Map<String, dynamic> json,
) => _LiveChatAuthorFamily(
  name: json['name'] as String,
  level: (json['level'] as num).toInt(),
);

Map<String, dynamic> _$LiveChatAuthorFamilyToJson(
  _LiveChatAuthorFamily instance,
) => <String, dynamic>{'name': instance.name, 'level': instance.level};

_LiveChatAuthorBadges _$LiveChatAuthorBadgesFromJson(
  Map<String, dynamic> json,
) => _LiveChatAuthorBadges(
  charmLevel: (json['charmLevel'] as num?)?.toInt(),
  supportLevel: (json['supportLevel'] as num?)?.toInt(),
  family: json['family'] == null
      ? null
      : LiveChatAuthorFamily.fromJson(json['family'] as Map<String, dynamic>),
  newcomer: json['newcomer'] as bool? ?? false,
);

Map<String, dynamic> _$LiveChatAuthorBadgesToJson(
  _LiveChatAuthorBadges instance,
) => <String, dynamic>{
  'charmLevel': instance.charmLevel,
  'supportLevel': instance.supportLevel,
  'family': instance.family,
  'newcomer': instance.newcomer,
};

_LiveChatEntry _$LiveChatEntryFromJson(Map<String, dynamic> json) =>
    _LiveChatEntry(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
      authorRole: $enumDecode(
        _$LiveChatRoleEnumMap,
        json['authorRole'],
        unknownValue: LiveChatRole.viewer,
      ),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      kind:
          $enumDecodeNullable(
            _$LiveChatKindEnumMap,
            json['kind'],
            unknownValue: LiveChatKind.text,
          ) ??
          LiveChatKind.text,
      media: json['media'] == null
          ? null
          : LiveChatMedia.fromJson(json['media'] as Map<String, dynamic>),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      cpBubble: json['cpBubble'] as bool? ?? false,
      authorBadges: json['authorBadges'] == null
          ? null
          : LiveChatAuthorBadges.fromJson(
              json['authorBadges'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$LiveChatEntryToJson(_LiveChatEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'author': instance.author,
      'authorRole': _$LiveChatRoleEnumMap[instance.authorRole]!,
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
      'kind': _$LiveChatKindEnumMap[instance.kind]!,
      'media': instance.media,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'cpBubble': instance.cpBubble,
      'authorBadges': instance.authorBadges,
    };

const _$LiveChatRoleEnumMap = {
  LiveChatRole.host: 'HOST',
  LiveChatRole.moderator: 'MODERATOR',
  LiveChatRole.speaker: 'SPEAKER',
  LiveChatRole.viewer: 'VIEWER',
};

const _$LiveChatKindEnumMap = {
  LiveChatKind.text: 'TEXT',
  LiveChatKind.voice: 'VOICE',
  LiveChatKind.image: 'IMAGE',
};

_LiveChatMute _$LiveChatMuteFromJson(Map<String, dynamic> json) =>
    _LiveChatMute(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      mutedAt: DateTime.parse(json['mutedAt'] as String),
    );

Map<String, dynamic> _$LiveChatMuteToJson(_LiveChatMute instance) =>
    <String, dynamic>{
      'user': instance.user,
      'mutedAt': instance.mutedAt.toIso8601String(),
    };

_LiveBullet _$LiveBulletFromJson(Map<String, dynamic> json) => _LiveBullet(
  id: json['id'] as String,
  text: json['text'] as String,
  sender: UserSummary.fromJson(json['sender'] as Map<String, dynamic>),
  roomId: json['roomId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$LiveBulletToJson(_LiveBullet instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'sender': instance.sender,
      'roomId': instance.roomId,
      'createdAt': instance.createdAt.toIso8601String(),
    };
