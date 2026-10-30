// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PageInfo _$PageInfoFromJson(Map<String, dynamic> json) => _PageInfo(
  nextCursor: json['nextCursor'] as String?,
  hasMore: json['hasMore'] as bool,
);

Map<String, dynamic> _$PageInfoToJson(_PageInfo instance) => <String, dynamic>{
  'nextCursor': instance.nextCursor,
  'hasMore': instance.hasMore,
};

_UserSummary _$UserSummaryFromJson(Map<String, dynamic> json) => _UserSummary(
  id: json['id'] as String,
  username: json['username'] as String,
  displayName: json['displayName'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  premiumTier: premiumTierFromJson(json['premiumTier']),
  rechargeAgentCode: rechargeAgentCodeFromJson(json['rechargeAgent']),
  hostAgentCode: rechargeAgentCodeFromJson(json['hostAgent']),
  avatarFrame: avatarFrameFromJson(json['avatarFrame']),
  rechargeBadge: rechargeBadgeFromJson(json['rechargeBadge']),
);

Map<String, dynamic> _$UserSummaryToJson(_UserSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'premiumTier': premiumTierToJson(instance.premiumTier),
      'rechargeAgent': ?rechargeAgentCodeToJson(instance.rechargeAgentCode),
      'hostAgent': ?rechargeAgentCodeToJson(instance.hostAgentCode),
      'avatarFrame': ?avatarFrameToJson(instance.avatarFrame),
      'rechargeBadge': ?rechargeBadgeToJson(instance.rechargeBadge),
    };
