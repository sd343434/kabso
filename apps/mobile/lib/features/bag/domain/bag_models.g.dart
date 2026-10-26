// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bag_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileCard _$ProfileCardFromJson(Map<String, dynamic> json) => _ProfileCard(
  code: json['code'] as String,
  assetKey: json['assetKey'] as String,
);

Map<String, dynamic> _$ProfileCardToJson(_ProfileCard instance) =>
    <String, dynamic>{'code': instance.code, 'assetKey': instance.assetKey};

_BagCatalogueItem _$BagCatalogueItemFromJson(Map<String, dynamic> json) =>
    _BagCatalogueItem(
      code: json['code'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      assetKey: json['assetKey'] as String,
      sortOrder: (json['sortOrder'] as num).toInt(),
      free: json['free'] as bool,
    );

Map<String, dynamic> _$BagCatalogueItemToJson(_BagCatalogueItem instance) =>
    <String, dynamic>{
      'code': instance.code,
      'category': instance.category,
      'name': instance.name,
      'assetKey': instance.assetKey,
      'sortOrder': instance.sortOrder,
      'free': instance.free,
    };

_BagItem _$BagItemFromJson(Map<String, dynamic> json) => _BagItem(
  code: json['code'] as String,
  category: json['category'] as String,
  name: json['name'] as String,
  assetKey: json['assetKey'] as String,
  acquiredAt: DateTime.parse(json['acquiredAt'] as String),
  source: json['source'] as String,
  equipped: json['equipped'] as bool,
);

Map<String, dynamic> _$BagItemToJson(_BagItem instance) => <String, dynamic>{
  'code': instance.code,
  'category': instance.category,
  'name': instance.name,
  'assetKey': instance.assetKey,
  'acquiredAt': instance.acquiredAt.toIso8601String(),
  'source': instance.source,
  'equipped': instance.equipped,
};

_BagEquippedItem _$BagEquippedItemFromJson(Map<String, dynamic> json) =>
    _BagEquippedItem(
      code: json['code'] as String,
      name: json['name'] as String,
      assetKey: json['assetKey'] as String,
    );

Map<String, dynamic> _$BagEquippedItemToJson(_BagEquippedItem instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'assetKey': instance.assetKey,
    };

_BagEquipped _$BagEquippedFromJson(Map<String, dynamic> json) => _BagEquipped(
  category: json['category'] as String,
  equipped: json['equipped'] == null
      ? null
      : BagEquippedItem.fromJson(json['equipped'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BagEquippedToJson(_BagEquipped instance) =>
    <String, dynamic>{
      'category': instance.category,
      'equipped': instance.equipped,
    };
