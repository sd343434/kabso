// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FamilyLevelStep _$FamilyLevelStepFromJson(Map<String, dynamic> json) =>
    _FamilyLevelStep(
      level: (json['level'] as num).toInt(),
      minPoints: (json['minPoints'] as num).toInt(),
    );

Map<String, dynamic> _$FamilyLevelStepToJson(_FamilyLevelStep instance) =>
    <String, dynamic>{'level': instance.level, 'minPoints': instance.minPoints};

_FamilyConfig _$FamilyConfigFromJson(Map<String, dynamic> json) =>
    _FamilyConfig(
      createCost: (json['createCost'] as num).toInt(),
      capacity: (json['capacity'] as num).toInt(),
      requestTtlDays: (json['requestTtlDays'] as num).toInt(),
      levels: (json['levels'] as List<dynamic>)
          .map((e) => FamilyLevelStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FamilyConfigToJson(_FamilyConfig instance) =>
    <String, dynamic>{
      'createCost': instance.createCost,
      'capacity': instance.capacity,
      'requestTtlDays': instance.requestTtlDays,
      'levels': instance.levels,
    };

_FamilyCard _$FamilyCardFromJson(Map<String, dynamic> json) => _FamilyCard(
  id: json['id'] as String,
  number: (json['number'] as num).toInt(),
  name: json['name'] as String,
  emblemUrl: json['emblemUrl'] as String?,
  level: (json['level'] as num).toInt(),
  points: (json['points'] as num).toInt(),
  memberCount: (json['memberCount'] as num).toInt(),
  capacity: (json['capacity'] as num).toInt(),
);

Map<String, dynamic> _$FamilyCardToJson(_FamilyCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'name': instance.name,
      'emblemUrl': instance.emblemUrl,
      'level': instance.level,
      'points': instance.points,
      'memberCount': instance.memberCount,
      'capacity': instance.capacity,
    };

_Family _$FamilyFromJson(Map<String, dynamic> json) => _Family(
  id: json['id'] as String,
  number: (json['number'] as num).toInt(),
  name: json['name'] as String,
  emblemUrl: json['emblemUrl'] as String?,
  level: (json['level'] as num).toInt(),
  points: (json['points'] as num).toInt(),
  memberCount: (json['memberCount'] as num).toInt(),
  capacity: (json['capacity'] as num).toInt(),
  nextLevelPoints: (json['nextLevelPoints'] as num?)?.toInt(),
  leader: json['leader'] == null
      ? null
      : UserSummary.fromJson(json['leader'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
  myRole: $enumDecodeNullable(_$FamilyRoleEnumMap, json['myRole']),
  myRequestId: json['myRequestId'] as String?,
);

Map<String, dynamic> _$FamilyToJson(_Family instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'name': instance.name,
  'emblemUrl': instance.emblemUrl,
  'level': instance.level,
  'points': instance.points,
  'memberCount': instance.memberCount,
  'capacity': instance.capacity,
  'nextLevelPoints': instance.nextLevelPoints,
  'leader': instance.leader,
  'createdAt': instance.createdAt.toIso8601String(),
  'myRole': _$FamilyRoleEnumMap[instance.myRole],
  'myRequestId': instance.myRequestId,
};

const _$FamilyRoleEnumMap = {
  FamilyRole.leader: 'LEADER',
  FamilyRole.deputy: 'DEPUTY',
  FamilyRole.member: 'MEMBER',
};

_FamilyMember _$FamilyMemberFromJson(Map<String, dynamic> json) =>
    _FamilyMember(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      role: $enumDecode(_$FamilyRoleEnumMap, json['role']),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      points: (json['points'] as num).toInt(),
    );

Map<String, dynamic> _$FamilyMemberToJson(_FamilyMember instance) =>
    <String, dynamic>{
      'user': instance.user,
      'role': _$FamilyRoleEnumMap[instance.role]!,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'points': instance.points,
    };

_FamilyJoinRequest _$FamilyJoinRequestFromJson(Map<String, dynamic> json) =>
    _FamilyJoinRequest(
      id: json['id'] as String,
      family: FamilyCard.fromJson(json['family'] as Map<String, dynamic>),
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      status: $enumDecode(_$BondRequestStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$FamilyJoinRequestToJson(_FamilyJoinRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'family': instance.family,
      'user': instance.user,
      'status': _$BondRequestStatusEnumMap[instance.status]!,
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

_FamilyCardPage _$FamilyCardPageFromJson(Map<String, dynamic> json) =>
    _FamilyCardPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => FamilyCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FamilyCardPageToJson(_FamilyCardPage instance) =>
    <String, dynamic>{'data': instance.data, 'page': instance.page};

_FamilyMemberPage _$FamilyMemberPageFromJson(Map<String, dynamic> json) =>
    _FamilyMemberPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FamilyMemberPageToJson(_FamilyMemberPage instance) =>
    <String, dynamic>{'data': instance.data, 'page': instance.page};

_FamilyJoinRequestPage _$FamilyJoinRequestPageFromJson(
  Map<String, dynamic> json,
) => _FamilyJoinRequestPage(
  data: (json['data'] as List<dynamic>)
      .map((e) => FamilyJoinRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
);

Map<String, dynamic> _$FamilyJoinRequestPageToJson(
  _FamilyJoinRequestPage instance,
) => <String, dynamic>{'data': instance.data, 'page': instance.page};

_ProfileFamily _$ProfileFamilyFromJson(Map<String, dynamic> json) =>
    _ProfileFamily(
      id: json['id'] as String,
      number: (json['number'] as num).toInt(),
      name: json['name'] as String,
      level: (json['level'] as num).toInt(),
      emblemUrl: json['emblemUrl'] as String?,
      role: $enumDecode(_$FamilyRoleEnumMap, json['role']),
    );

Map<String, dynamic> _$ProfileFamilyToJson(_ProfileFamily instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'name': instance.name,
      'level': instance.level,
      'emblemUrl': instance.emblemUrl,
      'role': _$FamilyRoleEnumMap[instance.role]!,
    };
