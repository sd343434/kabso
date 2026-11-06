// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medal_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MedalLevel _$MedalLevelFromJson(Map<String, dynamic> json) => _MedalLevel(
  level: (json['level'] as num).toInt(),
  threshold: (json['threshold'] as num).toInt(),
  name: json['name'] as String?,
  iconUrl: json['iconUrl'] as String?,
  iconAsset: json['iconAsset'] as String?,
);

Map<String, dynamic> _$MedalLevelToJson(_MedalLevel instance) =>
    <String, dynamic>{
      'level': instance.level,
      'threshold': instance.threshold,
      'name': instance.name,
      'iconUrl': instance.iconUrl,
      'iconAsset': instance.iconAsset,
    };

_MedalProgress _$MedalProgressFromJson(Map<String, dynamic> json) =>
    _MedalProgress(
      value: (json['value'] as num?)?.toInt() ?? 0,
      next: (json['next'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MedalProgressToJson(_MedalProgress instance) =>
    <String, dynamic>{'value': instance.value, 'next': instance.next};

_Medal _$MedalFromJson(Map<String, dynamic> json) => _Medal(
  code: json['code'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  iconKey: json['iconKey'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
  awardedAt: json['awardedAt'] == null
      ? null
      : DateTime.parse(json['awardedAt'] as String),
  category:
      $enumDecodeNullable(
        _$MedalCategoryEnumMap,
        json['category'],
        unknownValue: MedalCategory.achievement,
      ) ??
      MedalCategory.achievement,
  metric: json['metric'] as String?,
  level: (json['level'] as num?)?.toInt(),
  maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 1,
  levels:
      (json['levels'] as List<dynamic>?)
          ?.map((e) => MedalLevel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MedalLevel>[],
  progress: json['progress'] == null
      ? const MedalProgress()
      : MedalProgress.fromJson(json['progress'] as Map<String, dynamic>),
  iconUrl: json['iconUrl'] as String?,
  iconAsset: json['iconAsset'] as String?,
  showcasePosition: (json['showcasePosition'] as num?)?.toInt(),
);

Map<String, dynamic> _$MedalToJson(_Medal instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'description': instance.description,
  'iconKey': instance.iconKey,
  'sortOrder': instance.sortOrder,
  'awardedAt': instance.awardedAt?.toIso8601String(),
  'category': _$MedalCategoryEnumMap[instance.category]!,
  'metric': instance.metric,
  'level': instance.level,
  'maxLevel': instance.maxLevel,
  'levels': instance.levels,
  'progress': instance.progress,
  'iconUrl': instance.iconUrl,
  'iconAsset': instance.iconAsset,
  'showcasePosition': instance.showcasePosition,
};

const _$MedalCategoryEnumMap = {
  MedalCategory.achievement: 'ACHIEVEMENT',
  MedalCategory.activity: 'ACTIVITY',
};

_MedalCatalogue _$MedalCatalogueFromJson(Map<String, dynamic> json) =>
    _MedalCatalogue(
      data: (json['data'] as List<dynamic>)
          .map((e) => Medal.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      owned: (json['owned'] as num).toInt(),
    );

Map<String, dynamic> _$MedalCatalogueToJson(_MedalCatalogue instance) =>
    <String, dynamic>{
      'data': instance.data,
      'total': instance.total,
      'owned': instance.owned,
    };

_UserMedal _$UserMedalFromJson(Map<String, dynamic> json) => _UserMedal(
  code: json['code'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  iconKey: json['iconKey'] as String,
  awardedAt: DateTime.parse(json['awardedAt'] as String),
  category:
      $enumDecodeNullable(
        _$MedalCategoryEnumMap,
        json['category'],
        unknownValue: MedalCategory.achievement,
      ) ??
      MedalCategory.achievement,
  level: (json['level'] as num?)?.toInt() ?? 1,
  maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 1,
  iconUrl: json['iconUrl'] as String?,
  iconAsset: json['iconAsset'] as String?,
);

Map<String, dynamic> _$UserMedalToJson(_UserMedal instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'description': instance.description,
      'iconKey': instance.iconKey,
      'awardedAt': instance.awardedAt.toIso8601String(),
      'category': _$MedalCategoryEnumMap[instance.category]!,
      'level': instance.level,
      'maxLevel': instance.maxLevel,
      'iconUrl': instance.iconUrl,
      'iconAsset': instance.iconAsset,
    };

_UserMedalList _$UserMedalListFromJson(Map<String, dynamic> json) =>
    _UserMedalList(
      data: (json['data'] as List<dynamic>)
          .map((e) => UserMedal.fromJson(e as Map<String, dynamic>))
          .toList(),
      owned: (json['owned'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$UserMedalListToJson(_UserMedalList instance) =>
    <String, dynamic>{
      'data': instance.data,
      'owned': instance.owned,
      'total': instance.total,
    };

_ProfileMedal _$ProfileMedalFromJson(Map<String, dynamic> json) =>
    _ProfileMedal(
      code: json['code'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
      iconUrl: json['iconUrl'] as String?,
      iconAsset: json['iconAsset'] as String?,
    );

Map<String, dynamic> _$ProfileMedalToJson(_ProfileMedal instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'iconKey': instance.iconKey,
      'level': instance.level,
      'iconUrl': instance.iconUrl,
      'iconAsset': instance.iconAsset,
    };

_ProfileMedals _$ProfileMedalsFromJson(Map<String, dynamic> json) =>
    _ProfileMedals(
      owned: (json['owned'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      latest:
          (json['latest'] as List<dynamic>?)
              ?.map((e) => ProfileMedal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ProfileMedal>[],
      showcase:
          (json['showcase'] as List<dynamic>?)
              ?.map((e) => ProfileMedal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ProfileMedal>[],
    );

Map<String, dynamic> _$ProfileMedalsToJson(_ProfileMedals instance) =>
    <String, dynamic>{
      'owned': instance.owned,
      'total': instance.total,
      'latest': instance.latest,
      'showcase': instance.showcase,
    };
