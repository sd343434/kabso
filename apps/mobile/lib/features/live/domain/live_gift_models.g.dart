// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GiftTag _$GiftTagFromJson(Map<String, dynamic> json) =>
    _GiftTag(code: json['code'] as String, name: json['name'] as String);

Map<String, dynamic> _$GiftTagToJson(_GiftTag instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
};

_Gift _$GiftFromJson(Map<String, dynamic> json) => _Gift(
  code: json['code'] as String,
  category: $enumDecode(_$GiftCategoryEnumMap, json['category']),
  name: json['name'] as String,
  priceCoins: (json['priceCoins'] as num).toInt(),
  assetKey: json['assetKey'] as String,
  animationKey: json['animationKey'] as String?,
  sortOrder: (json['sortOrder'] as num).toInt(),
  badge: $enumDecode(
    _$GiftBadgeEnumMap,
    json['badge'],
    unknownValue: GiftBadge.none,
  ),
  tag: json['tag'] == null
      ? null
      : GiftTag.fromJson(json['tag'] as Map<String, dynamic>),
  imageUrl: json['imageUrl'] as String?,
  animationUrl: json['animationUrl'] as String?,
  animationBytes: (json['animationBytes'] as num?)?.toInt(),
);

Map<String, dynamic> _$GiftToJson(_Gift instance) => <String, dynamic>{
  'code': instance.code,
  'category': _$GiftCategoryEnumMap[instance.category]!,
  'name': instance.name,
  'priceCoins': instance.priceCoins,
  'assetKey': instance.assetKey,
  'animationKey': instance.animationKey,
  'sortOrder': instance.sortOrder,
  'badge': _$GiftBadgeEnumMap[instance.badge]!,
  'tag': instance.tag,
  'imageUrl': instance.imageUrl,
  'animationUrl': instance.animationUrl,
  'animationBytes': instance.animationBytes,
};

const _$GiftCategoryEnumMap = {
  GiftCategory.popular: 'POPULAR',
  GiftCategory.event: 'EVENT',
  GiftCategory.fun: 'FUN',
};

const _$GiftBadgeEnumMap = {
  GiftBadge.none: 'NONE',
  GiftBadge.isNew: 'NEW',
  GiftBadge.event: 'EVENT',
};

_GiftCatalogue _$GiftCatalogueFromJson(Map<String, dynamic> json) =>
    _GiftCatalogue(
      version: json['version'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => $enumDecode(_$GiftCategoryEnumMap, e))
          .toList(),
      quantities: (json['quantities'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      maxRecipients: (json['maxRecipients'] as num).toInt(),
      comboWindowSeconds: (json['comboWindowSeconds'] as num).toInt(),
      data: (json['data'] as List<dynamic>)
          .map((e) => Gift.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GiftCatalogueToJson(_GiftCatalogue instance) =>
    <String, dynamic>{
      'version': instance.version,
      'categories': instance.categories
          .map((e) => _$GiftCategoryEnumMap[e]!)
          .toList(),
      'quantities': instance.quantities,
      'maxRecipients': instance.maxRecipients,
      'comboWindowSeconds': instance.comboWindowSeconds,
      'data': instance.data,
    };

_GiftBagItem _$GiftBagItemFromJson(Map<String, dynamic> json) => _GiftBagItem(
  gift: Gift.fromJson(json['gift'] as Map<String, dynamic>),
  quantity: (json['quantity'] as num).toInt(),
);

Map<String, dynamic> _$GiftBagItemToJson(_GiftBagItem instance) =>
    <String, dynamic>{'gift': instance.gift, 'quantity': instance.quantity};

_LiveGiftCombo _$LiveGiftComboFromJson(Map<String, dynamic> json) =>
    _LiveGiftCombo(
      id: json['id'] as String,
      count: (json['count'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );

Map<String, dynamic> _$LiveGiftComboToJson(_LiveGiftCombo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'count': instance.count,
      'quantity': instance.quantity,
    };

_LiveGift _$LiveGiftFromJson(Map<String, dynamic> json) => _LiveGift(
  id: json['id'] as String,
  roomId: json['roomId'] as String,
  giftCode: json['giftCode'] as String,
  assetKey: json['assetKey'] as String,
  animationKey: json['animationKey'] as String?,
  unitPrice: (json['unitPrice'] as num).toInt(),
  quantity: (json['quantity'] as num).toInt(),
  source: $enumDecode(
    _$LiveGiftSourceEnumMap,
    json['source'],
    unknownValue: LiveGiftSource.coins,
  ),
  totalCoins: (json['totalCoins'] as num).toInt(),
  sender: UserSummary.fromJson(json['sender'] as Map<String, dynamic>),
  recipients: (json['recipients'] as List<dynamic>)
      .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  combo: LiveGiftCombo.fromJson(json['combo'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
  imageUrl: json['imageUrl'] as String?,
  animationUrl: json['animationUrl'] as String?,
  animationBytes: (json['animationBytes'] as num?)?.toInt(),
);

Map<String, dynamic> _$LiveGiftToJson(_LiveGift instance) => <String, dynamic>{
  'id': instance.id,
  'roomId': instance.roomId,
  'giftCode': instance.giftCode,
  'assetKey': instance.assetKey,
  'animationKey': instance.animationKey,
  'unitPrice': instance.unitPrice,
  'quantity': instance.quantity,
  'source': _$LiveGiftSourceEnumMap[instance.source]!,
  'totalCoins': instance.totalCoins,
  'sender': instance.sender,
  'recipients': instance.recipients,
  'combo': instance.combo,
  'createdAt': instance.createdAt.toIso8601String(),
  'imageUrl': instance.imageUrl,
  'animationUrl': instance.animationUrl,
  'animationBytes': instance.animationBytes,
};

const _$LiveGiftSourceEnumMap = {
  LiveGiftSource.coins: 'COINS',
  LiveGiftSource.bag: 'BAG',
};

_LiveGiftResult _$LiveGiftResultFromJson(Map<String, dynamic> json) =>
    _LiveGiftResult(
      gift: LiveGift.fromJson(json['gift'] as Map<String, dynamic>),
      coins: (json['coins'] as num).toInt(),
      bagQuantity: (json['bagQuantity'] as num).toInt(),
    );

Map<String, dynamic> _$LiveGiftResultToJson(_LiveGiftResult instance) =>
    <String, dynamic>{
      'gift': instance.gift,
      'coins': instance.coins,
      'bagQuantity': instance.bagQuantity,
    };
