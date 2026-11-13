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
  coverUrl: json['coverUrl'] as String?,
  tagline: json['tagline'] as String?,
  pendingRequestCount: (json['pendingRequestCount'] as num?)?.toInt(),
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
  'coverUrl': instance.coverUrl,
  'tagline': instance.tagline,
  'pendingRequestCount': instance.pendingRequestCount,
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
      monthPoints: (json['monthPoints'] as num?)?.toInt() ?? 0,
      presence: json['presence'] == null
          ? null
          : FamilyPresence.fromJson(json['presence'] as Map<String, dynamic>),
      chatMuted: json['chatMuted'] as bool?,
      rank: (json['rank'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FamilyMemberToJson(_FamilyMember instance) =>
    <String, dynamic>{
      'user': instance.user,
      'role': _$FamilyRoleEnumMap[instance.role]!,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'points': instance.points,
      'monthPoints': instance.monthPoints,
      'presence': instance.presence,
      'chatMuted': instance.chatMuted,
      'rank': instance.rank,
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

_FamilyPresence _$FamilyPresenceFromJson(Map<String, dynamic> json) =>
    _FamilyPresence(
      online: json['online'] as bool,
      lastActiveAt: json['lastActiveAt'] == null
          ? null
          : DateTime.parse(json['lastActiveAt'] as String),
    );

Map<String, dynamic> _$FamilyPresenceToJson(_FamilyPresence instance) =>
    <String, dynamic>{
      'online': instance.online,
      'lastActiveAt': instance.lastActiveAt?.toIso8601String(),
    };

_FamilyRankingEntry _$FamilyRankingEntryFromJson(Map<String, dynamic> json) =>
    _FamilyRankingEntry(
      rank: (json['rank'] as num).toInt(),
      family: FamilyCard.fromJson(json['family'] as Map<String, dynamic>),
      score: (json['score'] as num).toInt(),
    );

Map<String, dynamic> _$FamilyRankingEntryToJson(_FamilyRankingEntry instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'family': instance.family,
      'score': instance.score,
    };

_FamilyRankingMe _$FamilyRankingMeFromJson(Map<String, dynamic> json) =>
    _FamilyRankingMe(
      family: FamilyCard.fromJson(json['family'] as Map<String, dynamic>),
      rank: (json['rank'] as num?)?.toInt(),
      score: (json['score'] as num).toInt(),
    );

Map<String, dynamic> _$FamilyRankingMeToJson(_FamilyRankingMe instance) =>
    <String, dynamic>{
      'family': instance.family,
      'rank': instance.rank,
      'score': instance.score,
    };

_FamilyRankings _$FamilyRankingsFromJson(Map<String, dynamic> json) =>
    _FamilyRankings(
      board: $enumDecode(_$FamilyRankingBoardEnumMap, json['board']),
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      data: (json['data'] as List<dynamic>)
          .map((e) => FamilyRankingEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
      me: json['me'] == null
          ? null
          : FamilyRankingMe.fromJson(json['me'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FamilyRankingsToJson(_FamilyRankings instance) =>
    <String, dynamic>{
      'board': _$FamilyRankingBoardEnumMap[instance.board]!,
      'startsAt': instance.startsAt.toIso8601String(),
      'endsAt': instance.endsAt.toIso8601String(),
      'data': instance.data,
      'page': instance.page,
      'me': instance.me,
    };

const _$FamilyRankingBoardEnumMap = {
  FamilyRankingBoard.prestige: 'PRESTIGE',
  FamilyRankingBoard.active: 'ACTIVE',
};

_FamilyBoardStanding _$FamilyBoardStandingFromJson(Map<String, dynamic> json) =>
    _FamilyBoardStanding(
      rank: (json['rank'] as num?)?.toInt(),
      score: (json['score'] as num).toInt(),
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
    );

Map<String, dynamic> _$FamilyBoardStandingToJson(
  _FamilyBoardStanding instance,
) => <String, dynamic>{
  'rank': instance.rank,
  'score': instance.score,
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt.toIso8601String(),
};

_FamilyStanding _$FamilyStandingFromJson(Map<String, dynamic> json) =>
    _FamilyStanding(
      familyId: json['familyId'] as String,
      prestige: FamilyBoardStanding.fromJson(
        json['prestige'] as Map<String, dynamic>,
      ),
      active: FamilyBoardStanding.fromJson(
        json['active'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$FamilyStandingToJson(_FamilyStanding instance) =>
    <String, dynamic>{
      'familyId': instance.familyId,
      'prestige': instance.prestige,
      'active': instance.active,
    };

_FamilyContribution _$FamilyContributionFromJson(Map<String, dynamic> json) =>
    _FamilyContribution(
      rank: (json['rank'] as num).toInt(),
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      role: $enumDecode(_$FamilyRoleEnumMap, json['role']),
      points: (json['points'] as num).toInt(),
    );

Map<String, dynamic> _$FamilyContributionToJson(_FamilyContribution instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'user': instance.user,
      'role': _$FamilyRoleEnumMap[instance.role]!,
      'points': instance.points,
    };

_FamilyContributions _$FamilyContributionsFromJson(Map<String, dynamic> json) =>
    _FamilyContributions(
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      data: (json['data'] as List<dynamic>)
          .map((e) => FamilyContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FamilyContributionsToJson(
  _FamilyContributions instance,
) => <String, dynamic>{
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt.toIso8601String(),
  'data': instance.data,
  'page': instance.page,
};

_FamilyChatMessage _$FamilyChatMessageFromJson(Map<String, dynamic> json) =>
    _FamilyChatMessage(
      id: json['id'] as String,
      familyId: json['familyId'] as String,
      author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
      authorRole: $enumDecodeNullable(_$FamilyRoleEnumMap, json['authorRole']),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$FamilyChatMessageToJson(_FamilyChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'familyId': instance.familyId,
      'author': instance.author,
      'authorRole': _$FamilyRoleEnumMap[instance.authorRole],
      'text': instance.text,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_FamilyChatPage _$FamilyChatPageFromJson(Map<String, dynamic> json) =>
    _FamilyChatPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => FamilyChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
      muted: json['muted'] as bool,
      canModerate: json['canModerate'] as bool,
    );

Map<String, dynamic> _$FamilyChatPageToJson(_FamilyChatPage instance) =>
    <String, dynamic>{
      'data': instance.data,
      'page': instance.page,
      'muted': instance.muted,
      'canModerate': instance.canModerate,
    };
