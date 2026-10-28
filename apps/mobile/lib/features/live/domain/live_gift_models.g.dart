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
  GiftCategory.lucky: 'LUCKY',
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
      luckyResult: json['luckyResult'] == null
          ? null
          : LuckyGiftResult.fromJson(
              json['luckyResult'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$LiveGiftResultToJson(_LiveGiftResult instance) =>
    <String, dynamic>{
      'gift': instance.gift,
      'coins': instance.coins,
      'bagQuantity': instance.bagQuantity,
      'luckyResult': instance.luckyResult,
    };

_LuckyGiftWin _$LuckyGiftWinFromJson(Map<String, dynamic> json) =>
    _LuckyGiftWin(
      multiplier: (json['multiplier'] as num).toInt(),
      count: (json['count'] as num).toInt(),
      coins: (json['coins'] as num).toInt(),
    );

Map<String, dynamic> _$LuckyGiftWinToJson(_LuckyGiftWin instance) =>
    <String, dynamic>{
      'multiplier': instance.multiplier,
      'count': instance.count,
      'coins': instance.coins,
    };

_LuckyGiftResult _$LuckyGiftResultFromJson(Map<String, dynamic> json) =>
    _LuckyGiftResult(
      draws: (json['draws'] as num).toInt(),
      wins: (json['wins'] as List<dynamic>)
          .map((e) => LuckyGiftWin.fromJson(e as Map<String, dynamic>))
          .toList(),
      coinsWon: (json['coinsWon'] as num).toInt(),
      topMultiplier: (json['topMultiplier'] as num?)?.toInt(),
      downgraded: (json['downgraded'] as num).toInt(),
      guaranteed: json['guaranteed'] as bool? ?? false,
    );

Map<String, dynamic> _$LuckyGiftResultToJson(_LuckyGiftResult instance) =>
    <String, dynamic>{
      'draws': instance.draws,
      'wins': instance.wins,
      'coinsWon': instance.coinsWon,
      'topMultiplier': instance.topMultiplier,
      'downgraded': instance.downgraded,
      'guaranteed': instance.guaranteed,
    };

_LuckyGiftOutcome _$LuckyGiftOutcomeFromJson(Map<String, dynamic> json) =>
    _LuckyGiftOutcome(
      multiplier: (json['multiplier'] as num).toInt(),
      chancePerMillion: (json['chancePerMillion'] as num).toInt(),
      probability: (json['probability'] as num).toDouble(),
    );

Map<String, dynamic> _$LuckyGiftOutcomeToJson(_LuckyGiftOutcome instance) =>
    <String, dynamic>{
      'multiplier': instance.multiplier,
      'chancePerMillion': instance.chancePerMillion,
      'probability': instance.probability,
    };

_LuckyGiftEligibility _$LuckyGiftEligibilityFromJson(
  Map<String, dynamic> json,
) => _LuckyGiftEligibility(
  eligible: json['eligible'] as bool,
  reason: $enumDecodeNullable(
    _$LuckyGiftIneligibilityEnumMap,
    json['reason'],
    unknownValue: LuckyGiftIneligibility.unknown,
  ),
  ageConfirmed: json['ageConfirmed'] as bool,
);

Map<String, dynamic> _$LuckyGiftEligibilityToJson(
  _LuckyGiftEligibility instance,
) => <String, dynamic>{
  'eligible': instance.eligible,
  'reason': _$LuckyGiftIneligibilityEnumMap[instance.reason],
  'ageConfirmed': instance.ageConfirmed,
};

const _$LuckyGiftIneligibilityEnumMap = {
  LuckyGiftIneligibility.disabled: 'DISABLED',
  LuckyGiftIneligibility.regionUnavailable: 'REGION_UNAVAILABLE',
  LuckyGiftIneligibility.ageUnconfirmed: 'AGE_UNCONFIRMED',
  LuckyGiftIneligibility.unknown: 'unknown',
};

_LuckyGiftOdds _$LuckyGiftOddsFromJson(Map<String, dynamic> json) =>
    _LuckyGiftOdds(
      enabled: json['enabled'] as bool,
      drawsPerGift: (json['drawsPerGift'] as num).toInt(),
      returnPercent: (json['returnPercent'] as num).toDouble(),
      hostSharePercent: (json['hostSharePercent'] as num).toDouble(),
      outcomes: (json['outcomes'] as List<dynamic>)
          .map((e) => LuckyGiftOutcome.fromJson(e as Map<String, dynamic>))
          .toList(),
      noWinChancePerMillion: (json['noWinChancePerMillion'] as num).toInt(),
      noWinProbability: (json['noWinProbability'] as num).toDouble(),
      bigWinMultiplier: (json['bigWinMultiplier'] as num).toInt(),
      dailyProtection: json['dailyProtection'] as bool,
      dayTimeZone: json['dayTimeZone'] as String,
      minimumAge: (json['minimumAge'] as num).toInt(),
      caller: json['caller'] == null
          ? null
          : LuckyGiftEligibility.fromJson(
              json['caller'] as Map<String, dynamic>,
            ),
      pity: json['pity'] == null
          ? null
          : LuckyGiftPity.fromJson(json['pity'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LuckyGiftOddsToJson(_LuckyGiftOdds instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'drawsPerGift': instance.drawsPerGift,
      'returnPercent': instance.returnPercent,
      'hostSharePercent': instance.hostSharePercent,
      'outcomes': instance.outcomes,
      'noWinChancePerMillion': instance.noWinChancePerMillion,
      'noWinProbability': instance.noWinProbability,
      'bigWinMultiplier': instance.bigWinMultiplier,
      'dailyProtection': instance.dailyProtection,
      'dayTimeZone': instance.dayTimeZone,
      'minimumAge': instance.minimumAge,
      'caller': instance.caller,
      'pity': instance.pity,
    };

_LuckyGiftPity _$LuckyGiftPityFromJson(Map<String, dynamic> json) =>
    _LuckyGiftPity(
      after: (json['after'] as num).toInt(),
      multiplier: (json['multiplier'] as num).toInt(),
    );

Map<String, dynamic> _$LuckyGiftPityToJson(_LuckyGiftPity instance) =>
    <String, dynamic>{
      'after': instance.after,
      'multiplier': instance.multiplier,
    };

_LuckyTickerRoom _$LuckyTickerRoomFromJson(Map<String, dynamic> json) =>
    _LuckyTickerRoom(
      id: json['id'] as String,
      title: json['title'] as String,
      host: UserSummary.fromJson(json['host'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LuckyTickerRoomToJson(_LuckyTickerRoom instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'host': instance.host,
    };

_LuckyTicker _$LuckyTickerFromJson(Map<String, dynamic> json) => _LuckyTicker(
  win: LuckyWin.fromJson(json['win'] as Map<String, dynamic>),
  room: LuckyTickerRoom.fromJson(json['room'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LuckyTickerToJson(_LuckyTicker instance) =>
    <String, dynamic>{'win': instance.win, 'room': instance.room};

_LuckyWin _$LuckyWinFromJson(Map<String, dynamic> json) => _LuckyWin(
  giftId: json['giftId'] as String,
  roomId: json['roomId'] as String,
  giftCode: json['giftCode'] as String,
  sender: UserSummary.fromJson(json['sender'] as Map<String, dynamic>),
  multiplier: (json['multiplier'] as num).toInt(),
  coinsWon: (json['coinsWon'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$LuckyWinToJson(_LuckyWin instance) => <String, dynamic>{
  'giftId': instance.giftId,
  'roomId': instance.roomId,
  'giftCode': instance.giftCode,
  'sender': instance.sender,
  'multiplier': instance.multiplier,
  'coinsWon': instance.coinsWon,
  'createdAt': instance.createdAt.toIso8601String(),
};
