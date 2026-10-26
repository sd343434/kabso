// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cp_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CpTier _$CpTierFromJson(Map<String, dynamic> json) => _CpTier(
  level: (json['level'] as num).toInt(),
  minPoints: (json['minPoints'] as num).toInt(),
  name: json['name'] as String,
);

Map<String, dynamic> _$CpTierToJson(_CpTier instance) => <String, dynamic>{
  'level': instance.level,
  'minPoints': instance.minPoints,
  'name': instance.name,
};

_CpGiftPreset _$CpGiftPresetFromJson(Map<String, dynamic> json) =>
    _CpGiftPreset(
      code: json['code'] as String,
      amount: (json['amount'] as num).toInt(),
      name: json['name'] as String,
      assetKey: json['assetKey'] as String,
    );

Map<String, dynamic> _$CpGiftPresetToJson(_CpGiftPreset instance) =>
    <String, dynamic>{
      'code': instance.code,
      'amount': instance.amount,
      'name': instance.name,
      'assetKey': instance.assetKey,
    };

_CpConfig _$CpConfigFromJson(Map<String, dynamic> json) => _CpConfig(
  requestCost: (json['requestCost'] as num).toInt(),
  requestTtlDays: (json['requestTtlDays'] as num).toInt(),
  giftAmounts: (json['giftAmounts'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  tiers: (json['tiers'] as List<dynamic>)
      .map((e) => CpTier.fromJson(e as Map<String, dynamic>))
      .toList(),
  gifts:
      (json['gifts'] as List<dynamic>?)
          ?.map((e) => CpGiftPreset.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CpGiftPreset>[],
);

Map<String, dynamic> _$CpConfigToJson(_CpConfig instance) => <String, dynamic>{
  'requestCost': instance.requestCost,
  'requestTtlDays': instance.requestTtlDays,
  'giftAmounts': instance.giftAmounts,
  'tiers': instance.tiers,
  'gifts': instance.gifts,
};

_CpRequest _$CpRequestFromJson(Map<String, dynamic> json) => _CpRequest(
  id: json['id'] as String,
  sender: UserSummary.fromJson(json['sender'] as Map<String, dynamic>),
  receiver: UserSummary.fromJson(json['receiver'] as Map<String, dynamic>),
  status: $enumDecode(_$BondRequestStatusEnumMap, json['status']),
  cost: (json['cost'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$CpRequestToJson(_CpRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'receiver': instance.receiver,
      'status': _$BondRequestStatusEnumMap[instance.status]!,
      'cost': instance.cost,
      'createdAt': instance.createdAt.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
    };

const _$BondRequestStatusEnumMap = {
  BondRequestStatus.pending: 'PENDING',
  BondRequestStatus.accepted: 'ACCEPTED',
  BondRequestStatus.declined: 'DECLINED',
  BondRequestStatus.cancelled: 'CANCELLED',
  BondRequestStatus.expired: 'EXPIRED',
};

_CpRequestPage _$CpRequestPageFromJson(Map<String, dynamic> json) =>
    _CpRequestPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => CpRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CpRequestPageToJson(_CpRequestPage instance) =>
    <String, dynamic>{'data': instance.data, 'page': instance.page};

_CpCouple _$CpCoupleFromJson(Map<String, dynamic> json) => _CpCouple(
  id: json['id'] as String,
  partner: UserSummary.fromJson(json['partner'] as Map<String, dynamic>),
  since: DateTime.parse(json['since'] as String),
  days: (json['days'] as num).toInt(),
  points: (json['points'] as num).toInt(),
  level: (json['level'] as num).toInt(),
  levelName: json['levelName'] as String,
  nextLevelName: json['nextLevelName'] as String?,
  pointsToNext: (json['pointsToNext'] as num?)?.toInt(),
);

Map<String, dynamic> _$CpCoupleToJson(_CpCouple instance) => <String, dynamic>{
  'id': instance.id,
  'partner': instance.partner,
  'since': instance.since.toIso8601String(),
  'days': instance.days,
  'points': instance.points,
  'level': instance.level,
  'levelName': instance.levelName,
  'nextLevelName': instance.nextLevelName,
  'pointsToNext': instance.pointsToNext,
};

_CpGift _$CpGiftFromJson(Map<String, dynamic> json) => _CpGift(
  id: json['id'] as String,
  amount: (json['amount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CpGiftToJson(_CpGift instance) => <String, dynamic>{
  'id': instance.id,
  'amount': instance.amount,
  'createdAt': instance.createdAt.toIso8601String(),
};

_ProfileCp _$ProfileCpFromJson(Map<String, dynamic> json) => _ProfileCp(
  partner: UserSummary.fromJson(json['partner'] as Map<String, dynamic>),
  since: DateTime.parse(json['since'] as String),
  level: (json['level'] as num).toInt(),
  levelName: json['levelName'] as String,
  points: (json['points'] as num).toInt(),
  id: json['id'] as String?,
  privileges:
      (json['privileges'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$ProfileCpToJson(_ProfileCp instance) =>
    <String, dynamic>{
      'partner': instance.partner,
      'since': instance.since.toIso8601String(),
      'level': instance.level,
      'levelName': instance.levelName,
      'points': instance.points,
      'id': instance.id,
      'privileges': instance.privileges,
    };
