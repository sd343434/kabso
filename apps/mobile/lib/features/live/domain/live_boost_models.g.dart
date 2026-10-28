// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_boost_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveBoost _$LiveBoostFromJson(Map<String, dynamic> json) => _LiveBoost(
  id: json['id'] as String,
  roomId: json['roomId'] as String,
  host: UserSummary.fromJson(json['host'] as Map<String, dynamic>),
  buyer: UserSummary.fromJson(json['buyer'] as Map<String, dynamic>),
  minutes: (json['minutes'] as num).toInt(),
  source: $enumDecode(
    _$LiveBoostSourceEnumMap,
    json['source'],
    unknownValue: LiveBoostSource.coins,
  ),
  coinsCharged: (json['coinsCharged'] as num).toInt(),
  state: $enumDecode(
    _$LiveBoostStateEnumMap,
    json['state'],
    unknownValue: LiveBoostState.done,
  ),
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: DateTime.parse(json['endsAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$LiveBoostToJson(_LiveBoost instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'host': instance.host,
      'buyer': instance.buyer,
      'minutes': instance.minutes,
      'source': _$LiveBoostSourceEnumMap[instance.source]!,
      'coinsCharged': instance.coinsCharged,
      'state': _$LiveBoostStateEnumMap[instance.state]!,
      'startsAt': instance.startsAt.toIso8601String(),
      'endsAt': instance.endsAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$LiveBoostSourceEnumMap = {
  LiveBoostSource.coins: 'COINS',
  LiveBoostSource.card: 'CARD',
};

const _$LiveBoostStateEnumMap = {
  LiveBoostState.waiting: 'WAITING',
  LiveBoostState.running: 'RUNNING',
  LiveBoostState.done: 'DONE',
  LiveBoostState.cancelled: 'CANCELLED',
};

_LiveBoostOption _$LiveBoostOptionFromJson(Map<String, dynamic> json) =>
    _LiveBoostOption(
      minutes: (json['minutes'] as num).toInt(),
      priceCoins: (json['priceCoins'] as num).toInt(),
      savePercent: (json['savePercent'] as num).toInt(),
    );

Map<String, dynamic> _$LiveBoostOptionToJson(_LiveBoostOption instance) =>
    <String, dynamic>{
      'minutes': instance.minutes,
      'priceCoins': instance.priceCoins,
      'savePercent': instance.savePercent,
    };

_LiveBoostCardStock _$LiveBoostCardStockFromJson(Map<String, dynamic> json) =>
    _LiveBoostCardStock(
      minutes: (json['minutes'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );

Map<String, dynamic> _$LiveBoostCardStockToJson(_LiveBoostCardStock instance) =>
    <String, dynamic>{
      'minutes': instance.minutes,
      'quantity': instance.quantity,
    };

_LiveBoostOffers _$LiveBoostOffersFromJson(Map<String, dynamic> json) =>
    _LiveBoostOffers(
      slots: (json['slots'] as num).toInt(),
      maxWaitMinutes: (json['maxWaitMinutes'] as num).toInt(),
      options: (json['options'] as List<dynamic>)
          .map((e) => LiveBoostOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      cards: (json['cards'] as List<dynamic>)
          .map((e) => LiveBoostCardStock.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextStartAt: DateTime.parse(json['nextStartAt'] as String),
      roomBoost: json['roomBoost'] == null
          ? null
          : LiveBoost.fromJson(json['roomBoost'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LiveBoostOffersToJson(_LiveBoostOffers instance) =>
    <String, dynamic>{
      'slots': instance.slots,
      'maxWaitMinutes': instance.maxWaitMinutes,
      'options': instance.options,
      'cards': instance.cards,
      'nextStartAt': instance.nextStartAt.toIso8601String(),
      'roomBoost': instance.roomBoost,
    };

_LiveBoostResult _$LiveBoostResultFromJson(Map<String, dynamic> json) =>
    _LiveBoostResult(
      boost: LiveBoost.fromJson(json['boost'] as Map<String, dynamic>),
      coins: (json['coins'] as num).toInt(),
      cards: (json['cards'] as List<dynamic>)
          .map((e) => LiveBoostCardStock.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LiveBoostResultToJson(_LiveBoostResult instance) =>
    <String, dynamic>{
      'boost': instance.boost,
      'coins': instance.coins,
      'cards': instance.cards,
    };

_LiveBoostedRoom _$LiveBoostedRoomFromJson(Map<String, dynamic> json) =>
    _LiveBoostedRoom(
      room: LiveRoomSummary.fromJson(json['room'] as Map<String, dynamic>),
      endsAt: DateTime.parse(json['endsAt'] as String),
    );

Map<String, dynamic> _$LiveBoostedRoomToJson(_LiveBoostedRoom instance) =>
    <String, dynamic>{
      'room': instance.room,
      'endsAt': instance.endsAt.toIso8601String(),
    };
