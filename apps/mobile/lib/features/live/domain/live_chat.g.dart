// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
    );

Map<String, dynamic> _$LiveChatEntryToJson(_LiveChatEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'author': instance.author,
      'authorRole': _$LiveChatRoleEnumMap[instance.authorRole]!,
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$LiveChatRoleEnumMap = {
  LiveChatRole.host: 'HOST',
  LiveChatRole.moderator: 'MODERATOR',
  LiveChatRole.speaker: 'SPEAKER',
  LiveChatRole.viewer: 'VIEWER',
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
