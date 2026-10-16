// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveConfig _$LiveConfigFromJson(Map<String, dynamic> json) => _LiveConfig(
  hostingEnabled: json['hostingEnabled'] as bool,
  heartbeatIntervalSeconds: (json['heartbeatIntervalSeconds'] as num).toInt(),
  heartbeatStaleAfterSeconds: (json['heartbeatStaleAfterSeconds'] as num)
      .toInt(),
);

Map<String, dynamic> _$LiveConfigToJson(_LiveConfig instance) =>
    <String, dynamic>{
      'hostingEnabled': instance.hostingEnabled,
      'heartbeatIntervalSeconds': instance.heartbeatIntervalSeconds,
      'heartbeatStaleAfterSeconds': instance.heartbeatStaleAfterSeconds,
    };

_LiveCategory _$LiveCategoryFromJson(Map<String, dynamic> json) =>
    _LiveCategory(slug: json['slug'] as String, name: json['name'] as String);

Map<String, dynamic> _$LiveCategoryToJson(_LiveCategory instance) =>
    <String, dynamic>{'slug': instance.slug, 'name': instance.name};

_LiveRoomSummary _$LiveRoomSummaryFromJson(Map<String, dynamic> json) =>
    _LiveRoomSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      mode: $enumDecode(
        _$LiveRoomModeEnumMap,
        json['mode'],
        unknownValue: LiveRoomMode.solo,
      ),
      viewerCount: (json['viewerCount'] as num).toInt(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      coverUrl: json['coverUrl'] as String?,
      category: json['category'] == null
          ? null
          : LiveCategory.fromJson(json['category'] as Map<String, dynamic>),
      host: UserSummary.fromJson(json['host'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LiveRoomSummaryToJson(_LiveRoomSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'mode': _$LiveRoomModeEnumMap[instance.mode]!,
      'viewerCount': instance.viewerCount,
      'startedAt': instance.startedAt.toIso8601String(),
      'coverUrl': instance.coverUrl,
      'category': instance.category,
      'host': instance.host,
    };

const _$LiveRoomModeEnumMap = {
  LiveRoomMode.solo: 'SOLO',
  LiveRoomMode.pk: 'PK',
  LiveRoomMode.multi: 'MULTI',
};

_LiveRoom _$LiveRoomFromJson(Map<String, dynamic> json) => _LiveRoom(
  id: json['id'] as String,
  title: json['title'] as String,
  mode: $enumDecode(
    _$LiveRoomModeEnumMap,
    json['mode'],
    unknownValue: LiveRoomMode.solo,
  ),
  viewerCount: (json['viewerCount'] as num).toInt(),
  startedAt: DateTime.parse(json['startedAt'] as String),
  coverUrl: json['coverUrl'] as String?,
  category: json['category'] == null
      ? null
      : LiveCategory.fromJson(json['category'] as Map<String, dynamic>),
  host: UserSummary.fromJson(json['host'] as Map<String, dynamic>),
  status: $enumDecode(_$LiveRoomStatusEnumMap, json['status']),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  endReason: $enumDecodeNullable(
    _$LiveRoomEndReasonEnumMap,
    json['endReason'],
    unknownValue: LiveRoomEndReason.unknown,
  ),
);

Map<String, dynamic> _$LiveRoomToJson(_LiveRoom instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'mode': _$LiveRoomModeEnumMap[instance.mode]!,
  'viewerCount': instance.viewerCount,
  'startedAt': instance.startedAt.toIso8601String(),
  'coverUrl': instance.coverUrl,
  'category': instance.category,
  'host': instance.host,
  'status': _$LiveRoomStatusEnumMap[instance.status]!,
  'endedAt': instance.endedAt?.toIso8601String(),
  'endReason': _$LiveRoomEndReasonEnumMap[instance.endReason],
};

const _$LiveRoomStatusEnumMap = {
  LiveRoomStatus.live: 'LIVE',
  LiveRoomStatus.ended: 'ENDED',
};

const _$LiveRoomEndReasonEnumMap = {
  LiveRoomEndReason.hostEnded: 'HOST_ENDED',
  LiveRoomEndReason.heartbeatTimeout: 'HEARTBEAT_TIMEOUT',
  LiveRoomEndReason.hostSuspended: 'HOST_SUSPENDED',
  LiveRoomEndReason.admin: 'ADMIN',
  LiveRoomEndReason.unknown: 'unknown',
};

_LiveRoomPage _$LiveRoomPageFromJson(Map<String, dynamic> json) =>
    _LiveRoomPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => LiveRoomSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LiveRoomPageToJson(_LiveRoomPage instance) =>
    <String, dynamic>{'data': instance.data, 'page': instance.page};
