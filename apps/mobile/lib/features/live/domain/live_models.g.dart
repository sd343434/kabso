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
  themes:
      (json['themes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[LiveThemes.classic],
  seatCounts: json['seatCounts'] == null
      ? const LiveSeatCounts()
      : LiveSeatCounts.fromJson(json['seatCounts'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LiveConfigToJson(_LiveConfig instance) =>
    <String, dynamic>{
      'hostingEnabled': instance.hostingEnabled,
      'heartbeatIntervalSeconds': instance.heartbeatIntervalSeconds,
      'heartbeatStaleAfterSeconds': instance.heartbeatStaleAfterSeconds,
      'themes': instance.themes,
      'seatCounts': instance.seatCounts,
    };

_LiveSeatCounts _$LiveSeatCountsFromJson(Map<String, dynamic> json) =>
    _LiveSeatCounts(
      multi:
          (json['MULTI'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[4, 6, 9, 12],
      audio:
          (json['AUDIO'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[5, 10, 15, 20],
    );

Map<String, dynamic> _$LiveSeatCountsToJson(_LiveSeatCounts instance) =>
    <String, dynamic>{'MULTI': instance.multi, 'AUDIO': instance.audio};

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
      seatCount: (json['seatCount'] as num?)?.toInt(),
      occupiedSeats: (json['occupiedSeats'] as num?)?.toInt() ?? 0,
      theme: json['theme'] as String? ?? LiveThemes.classic,
      score: (json['score'] as num?)?.toInt() ?? 0,
      topic: json['topic'] as String?,
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
      'seatCount': instance.seatCount,
      'occupiedSeats': instance.occupiedSeats,
      'theme': instance.theme,
      'score': instance.score,
      'topic': instance.topic,
    };

const _$LiveRoomModeEnumMap = {
  LiveRoomMode.solo: 'SOLO',
  LiveRoomMode.pk: 'PK',
  LiveRoomMode.multi: 'MULTI',
  LiveRoomMode.audio: 'AUDIO',
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
  allowGuests: json['allowGuests'] as bool? ?? true,
  seatCount: (json['seatCount'] as num?)?.toInt(),
  occupiedSeats: (json['occupiedSeats'] as num?)?.toInt() ?? 0,
  theme: json['theme'] as String? ?? LiveThemes.classic,
  score: (json['score'] as num?)?.toInt() ?? 0,
  scoreParts: json['scoreParts'] == null
      ? null
      : LiveScore.fromJson(json['scoreParts'] as Map<String, dynamic>),
  chatEnabled: json['chatEnabled'] as bool? ?? true,
  chatMuted: json['chatMuted'] as bool? ?? false,
  topic: json['topic'] as String?,
  roomNumber: (json['roomNumber'] as num?)?.toInt(),
  roomLevel: (json['roomLevel'] as num?)?.toInt(),
  kicked: json['kicked'] as bool? ?? false,
  wishGifts:
      (json['wishGifts'] as List<dynamic>?)
          ?.map((e) => LiveWishGift.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <LiveWishGift>[],
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
  'allowGuests': instance.allowGuests,
  'seatCount': instance.seatCount,
  'occupiedSeats': instance.occupiedSeats,
  'theme': instance.theme,
  'score': instance.score,
  'scoreParts': instance.scoreParts,
  'chatEnabled': instance.chatEnabled,
  'chatMuted': instance.chatMuted,
  'topic': instance.topic,
  'roomNumber': instance.roomNumber,
  'roomLevel': instance.roomLevel,
  'kicked': instance.kicked,
  'wishGifts': instance.wishGifts,
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
  LiveRoomEndReason.hostAwayTimeout: 'HOST_AWAY_TIMEOUT',
  LiveRoomEndReason.unknown: 'unknown',
};

_LiveWishGift _$LiveWishGiftFromJson(Map<String, dynamic> json) =>
    _LiveWishGift(
      giftCode: json['giftCode'] as String,
      name: json['name'] as String,
      priceCoins: (json['priceCoins'] as num).toInt(),
      assetKey: json['assetKey'] as String,
      imageUrl: json['imageUrl'] as String?,
      received: (json['received'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$LiveWishGiftToJson(_LiveWishGift instance) =>
    <String, dynamic>{
      'giftCode': instance.giftCode,
      'name': instance.name,
      'priceCoins': instance.priceCoins,
      'assetKey': instance.assetKey,
      'imageUrl': instance.imageUrl,
      'received': instance.received,
    };

_LiveScore _$LiveScoreFromJson(Map<String, dynamic> json) => _LiveScore(
  total: (json['total'] as num).toInt(),
  tapPoints: (json['tapPoints'] as num).toInt(),
  supportPoints: (json['supportPoints'] as num).toInt(),
);

Map<String, dynamic> _$LiveScoreToJson(_LiveScore instance) =>
    <String, dynamic>{
      'total': instance.total,
      'tapPoints': instance.tapPoints,
      'supportPoints': instance.supportPoints,
    };

_LiveTapsResult _$LiveTapsResultFromJson(Map<String, dynamic> json) =>
    _LiveTapsResult(
      accepted: (json['accepted'] as num).toInt(),
      score: LiveScore.fromJson(json['score'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LiveTapsResultToJson(_LiveTapsResult instance) =>
    <String, dynamic>{'accepted': instance.accepted, 'score': instance.score};

_LiveContributor _$LiveContributorFromJson(Map<String, dynamic> json) =>
    _LiveContributor(
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      points: (json['points'] as num).toInt(),
    );

Map<String, dynamic> _$LiveContributorToJson(_LiveContributor instance) =>
    <String, dynamic>{'user': instance.user, 'points': instance.points};

_LiveContributorStanding _$LiveContributorStandingFromJson(
  Map<String, dynamic> json,
) => _LiveContributorStanding(
  user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
  points: (json['points'] as num).toInt(),
  rank: (json['rank'] as num?)?.toInt(),
);

Map<String, dynamic> _$LiveContributorStandingToJson(
  _LiveContributorStanding instance,
) => <String, dynamic>{
  'user': instance.user,
  'points': instance.points,
  'rank': instance.rank,
};

_LiveKick _$LiveKickFromJson(Map<String, dynamic> json) => _LiveKick(
  user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
  kickedAt: DateTime.parse(json['kickedAt'] as String),
);

Map<String, dynamic> _$LiveKickToJson(_LiveKick instance) => <String, dynamic>{
  'user': instance.user,
  'kickedAt': instance.kickedAt.toIso8601String(),
};

_LiveRoomPage _$LiveRoomPageFromJson(Map<String, dynamic> json) =>
    _LiveRoomPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => LiveRoomSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: PageInfo.fromJson(json['page'] as Map<String, dynamic>),
      emptyReason: $enumDecodeNullable(
        _$LiveRoomsEmptyReasonEnumMap,
        json['emptyReason'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
    );

Map<String, dynamic> _$LiveRoomPageToJson(_LiveRoomPage instance) =>
    <String, dynamic>{
      'data': instance.data,
      'page': instance.page,
      'emptyReason': _$LiveRoomsEmptyReasonEnumMap[instance.emptyReason],
    };

const _$LiveRoomsEmptyReasonEnumMap = {
  LiveRoomsEmptyReason.countryNotSet: 'COUNTRY_NOT_SET',
};

_LiveMediaAccess _$LiveMediaAccessFromJson(Map<String, dynamic> json) =>
    _LiveMediaAccess(
      url: json['url'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      role: $enumDecode(
        _$LiveMediaRoleEnumMap,
        json['role'],
        unknownValue: LiveMediaRole.viewer,
      ),
      identity: json['identity'] as String,
      guestNumber: (json['guestNumber'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LiveMediaAccessToJson(_LiveMediaAccess instance) =>
    <String, dynamic>{
      'url': instance.url,
      'token': instance.token,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'role': _$LiveMediaRoleEnumMap[instance.role]!,
      'identity': instance.identity,
      'guestNumber': instance.guestNumber,
    };

const _$LiveMediaRoleEnumMap = {
  LiveMediaRole.host: 'HOST',
  LiveMediaRole.viewer: 'VIEWER',
  LiveMediaRole.speaker: 'SPEAKER',
};

_LiveViewer _$LiveViewerFromJson(Map<String, dynamic> json) => _LiveViewer(
  kind: $enumDecode(
    _$LiveViewerKindEnumMap,
    json['kind'],
    unknownValue: LiveViewerKind.user,
  ),
  user: json['user'] == null
      ? null
      : UserSummary.fromJson(json['user'] as Map<String, dynamic>),
  guestNumber: (json['guestNumber'] as num?)?.toInt(),
  joinedAt: DateTime.parse(json['joinedAt'] as String),
);

Map<String, dynamic> _$LiveViewerToJson(_LiveViewer instance) =>
    <String, dynamic>{
      'kind': _$LiveViewerKindEnumMap[instance.kind]!,
      'user': instance.user,
      'guestNumber': instance.guestNumber,
      'joinedAt': instance.joinedAt.toIso8601String(),
    };

const _$LiveViewerKindEnumMap = {
  LiveViewerKind.user: 'USER',
  LiveViewerKind.guest: 'GUEST',
};

_LiveSeat _$LiveSeatFromJson(Map<String, dynamic> json) => _LiveSeat(
  index: (json['index'] as num).toInt(),
  state: $enumDecode(
    _$LiveSeatStateEnumMap,
    json['state'],
    unknownValue: LiveSeatState.empty,
  ),
  user: json['user'] == null
      ? null
      : UserSummary.fromJson(json['user'] as Map<String, dynamic>),
  mutedByHost: json['mutedByHost'] as bool? ?? false,
  points: (json['points'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LiveSeatToJson(_LiveSeat instance) => <String, dynamic>{
  'index': instance.index,
  'state': _$LiveSeatStateEnumMap[instance.state]!,
  'user': instance.user,
  'mutedByHost': instance.mutedByHost,
  'points': instance.points,
};

const _$LiveSeatStateEnumMap = {
  LiveSeatState.empty: 'EMPTY',
  LiveSeatState.locked: 'LOCKED',
  LiveSeatState.taken: 'TAKEN',
};

_LiveSeatRequest _$LiveSeatRequestFromJson(Map<String, dynamic> json) =>
    _LiveSeatRequest(
      id: json['id'] as String,
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      seatIndex: (json['seatIndex'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$LiveSeatRequestToJson(_LiveSeatRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'seatIndex': instance.seatIndex,
      'createdAt': instance.createdAt.toIso8601String(),
    };

_LiveSeatInvite _$LiveSeatInviteFromJson(Map<String, dynamic> json) =>
    _LiveSeatInvite(
      id: json['id'] as String,
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      seatIndex: (json['seatIndex'] as num?)?.toInt(),
      invitedBy: UserSummary.fromJson(
        json['invitedBy'] as Map<String, dynamic>,
      ),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$LiveSeatInviteToJson(_LiveSeatInvite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'seatIndex': instance.seatIndex,
      'invitedBy': instance.invitedBy,
      'expiresAt': instance.expiresAt.toIso8601String(),
    };

_LiveSeatsMine _$LiveSeatsMineFromJson(Map<String, dynamic> json) =>
    _LiveSeatsMine(
      role: $enumDecode(
        _$LiveSeatRoleEnumMap,
        json['role'],
        unknownValue: LiveSeatRole.viewer,
      ),
      seatIndex: (json['seatIndex'] as num?)?.toInt(),
      request: json['request'] == null
          ? null
          : LiveSeatRequest.fromJson(json['request'] as Map<String, dynamic>),
      invite: json['invite'] == null
          ? null
          : LiveSeatInvite.fromJson(json['invite'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LiveSeatsMineToJson(_LiveSeatsMine instance) =>
    <String, dynamic>{
      'role': _$LiveSeatRoleEnumMap[instance.role]!,
      'seatIndex': instance.seatIndex,
      'request': instance.request,
      'invite': instance.invite,
    };

const _$LiveSeatRoleEnumMap = {
  LiveSeatRole.host: 'HOST',
  LiveSeatRole.moderator: 'MODERATOR',
  LiveSeatRole.seated: 'SEATED',
  LiveSeatRole.viewer: 'VIEWER',
};

_LiveSeatCouple _$LiveSeatCoupleFromJson(Map<String, dynamic> json) =>
    _LiveSeatCouple(
      userIds: (json['userIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      level: (json['level'] as num).toInt(),
      levelName: json['levelName'] as String? ?? '',
      privileges:
          (json['privileges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$LiveSeatCoupleToJson(_LiveSeatCouple instance) =>
    <String, dynamic>{
      'userIds': instance.userIds,
      'level': instance.level,
      'levelName': instance.levelName,
      'privileges': instance.privileges,
    };

_LiveSeats _$LiveSeatsFromJson(Map<String, dynamic> json) => _LiveSeats(
  roomId: json['roomId'] as String,
  mode: $enumDecode(
    _$LiveRoomModeEnumMap,
    json['mode'],
    unknownValue: LiveRoomMode.multi,
  ),
  version: (json['version'] as num).toInt(),
  seatCount: (json['seatCount'] as num).toInt(),
  seats: (json['seats'] as List<dynamic>)
      .map((e) => LiveSeat.fromJson(e as Map<String, dynamic>))
      .toList(),
  moderators: (json['moderators'] as List<dynamic>)
      .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  couples:
      (json['couples'] as List<dynamic>?)
          ?.map((e) => LiveSeatCouple.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <LiveSeatCouple>[],
  pendingRequests: (json['pendingRequests'] as num?)?.toInt(),
  mine: json['mine'] == null
      ? null
      : LiveSeatsMine.fromJson(json['mine'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LiveSeatsToJson(_LiveSeats instance) =>
    <String, dynamic>{
      'roomId': instance.roomId,
      'mode': _$LiveRoomModeEnumMap[instance.mode]!,
      'version': instance.version,
      'seatCount': instance.seatCount,
      'seats': instance.seats,
      'moderators': instance.moderators,
      'couples': instance.couples,
      'pendingRequests': instance.pendingRequests,
      'mine': instance.mine,
    };
