// CP-018 payloads shaped exactly like docs/contracts/openapi.yaml
// v1.21-live (tags `families`, `cp`, `medals`; the examples where given).

Map<String, Object?> bondUserJson({
  String id = '0192f1d0-5555-7000-8000-000000000006',
  String username = 'sara',
  String displayName = 'سارة',
}) => {
  'id': id,
  'username': username,
  'displayName': displayName,
  'avatarUrl': null,
};

Map<String, Object?> familyConfigJson({int createCost = 500}) => {
  'createCost': createCost,
  'capacity': 500,
  'requestTtlDays': 7,
  'levels': [
    {'level': 1, 'minPoints': 0},
    {'level': 2, 'minPoints': 1000},
    {'level': 3, 'minPoints': 5000},
  ],
};

Map<String, Object?> familyCardJson({
  String id = '0192f1d0-8888-7000-8000-000000000002',
  String name = 'عائلة النجوم',
  int number = 48213907,
  int level = 1,
  int points = 500,
  int memberCount = 1,
}) => {
  'id': id,
  'number': number,
  'name': name,
  'emblemUrl': null,
  'level': level,
  'points': points,
  'memberCount': memberCount,
  'capacity': 500,
};

/// The `createFamily` 201 example's family.
Map<String, Object?> familyJson({
  String id = '0192f1d0-8888-7000-8000-000000000002',
  String name = 'عائلة النجوم',
  String? myRole = 'LEADER',
  String? myRequestId,
  int memberCount = 1,
  int points = 500,
  int? nextLevelPoints = 1000,
}) => {
  ...familyCardJson(id: id, name: name, memberCount: memberCount),
  'points': points,
  'nextLevelPoints': nextLevelPoints,
  'leader': bondUserJson(),
  'createdAt': '2026-10-26T18:30:00.000Z',
  'myRole': myRole,
  'myRequestId': myRequestId,
};

Map<String, Object?> familyMemberJson({
  Map<String, Object?>? user,
  String role = 'MEMBER',
  int points = 0,
}) => {
  'user': user ?? bondUserJson(),
  'role': role,
  'joinedAt': '2026-10-26T18:30:00.000Z',
  'points': points,
};

Map<String, Object?> familyJoinRequestJson({
  String id = '0192f1d0-8888-7000-8000-000000000010',
  Map<String, Object?>? user,
}) => {
  'id': id,
  'family': familyCardJson(),
  'user': user ?? bondUserJson(username: 'omar', displayName: 'Omar'),
  'status': 'PENDING',
  'createdAt': '2026-10-26T18:30:00.000Z',
  'expiresAt': '2026-11-02T18:30:00.000Z',
};

Map<String, Object?> pageJson(
  List<Map<String, Object?>> data, {
  String? nextCursor,
}) => {
  'data': data,
  'page': {'nextCursor': nextCursor, 'hasMore': nextCursor != null},
};

/// The `getCpConfig` example (all six tiers; the sixth since D113).
Map<String, Object?> cpConfigJson({int requestCost = 99}) => {
  'requestCost': requestCost,
  'requestTtlDays': 7,
  'giftAmounts': [10, 52, 99, 520, 1314],
  'tiers': [
    {'level': 1, 'minPoints': 0, 'name': 'Eager couple'},
    {'level': 2, 'minPoints': 520, 'name': 'Silver couple'},
    {'level': 3, 'minPoints': 1314, 'name': 'Gold couple'},
    {'level': 4, 'minPoints': 5200, 'name': 'Diamond couple'},
    {'level': 5, 'minPoints': 13140, 'name': 'Legendary couple'},
    {'level': 6, 'minPoints': 52000, 'name': 'Eternal couple'},
  ],
  // v1.24-live (CP-021): the named gift cards.
  'gifts': [
    for (final (code, amount, name) in [
      ('rose_love', 10, 'Rose Love'),
      ('angel_heart', 52, 'Angel Heart'),
      ('love_carriage', 99, 'Love Carriage'),
      ('swan_love', 520, 'Swan Love'),
      ('eternal_heart', 1314, 'Eternal Heart'),
    ])
      {
        'code': code,
        'amount': amount,
        'name': name,
        'assetKey': 'cp_gift_$code',
      },
  ],
};

/// The `sendCpRequest` 201 example's request.
Map<String, Object?> cpRequestJson({
  String id = '0192f1d0-9999-7000-8000-000000000002',
  Map<String, Object?>? sender,
  Map<String, Object?>? receiver,
}) => {
  'id': id,
  'sender': sender ?? bondUserJson(),
  'receiver':
      receiver ??
      bondUserJson(
        id: '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
        username: 'layla.k',
        displayName: 'ليلى',
      ),
  'status': 'PENDING',
  'cost': 99,
  'createdAt': '2026-10-26T18:30:00.000Z',
  'expiresAt': '2026-11-02T18:30:00.000Z',
};

/// The `getMyCp` example's couple.
Map<String, Object?> cpCoupleJson({int points = 620}) => {
  'id': '0192f1d0-9999-7000-8000-000000000003',
  'partner': bondUserJson(
    id: '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
    username: 'layla.k',
    displayName: 'ليلى',
  ),
  'since': '2026-10-20T18:30:00.000Z',
  'days': 7,
  'points': points,
  'level': 2,
  'levelName': 'Silver couple',
  'nextLevelName': 'Gold couple',
  'pointsToNext': 1314 - points,
};

Map<String, Object?> medalJson(
  String code, {
  String? name,
  String? awardedAt = '2026-10-26T18:30:00.000Z',
  int sortOrder = 1,
}) => {
  'code': code,
  'name': name ?? code,
  'description': 'About $code',
  'iconKey': 'medal_${code.toLowerCase()}',
  'sortOrder': sortOrder,
  'awardedAt': awardedAt,
};

Map<String, Object?> profileMedalJson(String code) => {
  'code': code,
  'name': code,
  'iconKey': 'medal_${code.toLowerCase()}',
};

// ---- CP-021 the CP space (v1.24-live, §10.24) ----------------------------

/// The partner of the `getMyCp` example (the caller is `testUser()`).
Map<String, Object?> cpPartnerJson() => bondUserJson(
  id: '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
  username: 'layla.k',
  displayName: 'ليلى',
);

/// The caller as a `UserSummary` (matches `testUser()`).
Map<String, Object?> cpMeJson() => bondUserJson(
  id: '0192f1c2-7c3a-7b2e-9a51-1d2c3b4a5e6f',
  username: 'layla.k',
  displayName: 'Layla',
);

Map<String, Object?> cpTaskJson(
  String code, {
  int reward = 10,
  int progress = 0,
  int target = 1,
  bool completed = false,
  bool claimed = false,
}) => {
  'code': code,
  'name': switch (code) {
    'CHECK_IN' => 'Check in together',
    'SEND_GIFT' => 'Send a CP gift',
    _ => 'Chat in the same live',
  },
  'description': 'About $code',
  'reward': reward,
  'progress': progress,
  'target': target,
  'completed': completed,
  'claimed': claimed,
};

/// The `getMyCpTasks` example: check-in half done, gift claimed, chat open.
Map<String, Object?> cpTasksJson({
  bool checkInDone = false,
  bool giftClaimed = true,
}) => {
  'day': '2026-10-26',
  'timeZone': 'UTC',
  'startsAt': '2026-10-26T00:00:00.000Z',
  'resetsAt': '2026-10-27T00:00:00.000Z',
  'checkedIn': {'me': true, 'partner': checkInDone},
  'tasks': [
    cpTaskJson(
      'CHECK_IN',
      progress: checkInDone ? 2 : 1,
      target: 2,
      completed: checkInDone,
    ),
    cpTaskJson(
      'SEND_GIFT',
      reward: 20,
      progress: 1,
      completed: true,
      claimed: giftClaimed,
    ),
    cpTaskJson('CHAT_TOGETHER', reward: 30),
  ],
};

/// The `getMyCpPrivileges` example at [level].
Map<String, Object?> cpPrivilegesJson({int? level = 2}) => {
  'level': level,
  'privileges': [
    for (final (i, (code, name, icon)) in [
      ('SPECIAL_FRAME', 'Special Frame', 'cp_priv_frame'),
      ('CHAT_BUBBLE', 'Exclusive Chat Bubble', 'cp_priv_bubble'),
      ('MIC_EFFECT', 'Couple Mic Effect', 'cp_priv_mic'),
      ('ENTRANCE_EFFECT', 'Entrance Effect', 'cp_priv_entrance'),
      ('GIFT_WALL', 'CP Gift Wall', 'cp_priv_gift_wall'),
    ].indexed)
      {
        'code': code,
        'name': name,
        'unlockLevel': i + 1,
        'unlocked': level != null && i + 1 <= level,
        'iconKey': icon,
      },
  ],
};

/// A `CpCouplePublic` of two other people.
Map<String, Object?> cpCouplePublicJson({
  String id = '0192f1d0-9999-7000-8000-000000000033',
  bool mine = false,
  int level = 3,
}) => {
  'id': id,
  'partners': [
    bondUserJson(id: 'u-1', username: 'omar', displayName: 'Omar'),
    bondUserJson(id: 'u-2'),
  ],
  'since': '2026-09-01T10:00:00.000Z',
  'days': 56,
  'points': 2000,
  'level': level,
  'levelName': 'Gold couple',
  'nextLevelName': 'Diamond couple',
  'pointsToNext': 3200,
  'privileges': ['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT'],
  'mine': mine,
};

Map<String, Object?> cpConfessionJson({
  String id = '0192f1d0-9999-7000-8000-000000000041',
  String coupleId = '0192f1d0-9999-7000-8000-000000000003',
  Map<String, Object?>? author,
  Map<String, Object?>? recipient,
  String text = 'أحبك أكثر كل يوم',
}) => {
  'id': id,
  'coupleId': coupleId,
  'author': author ?? cpPartnerJson(),
  'recipient': recipient ?? cpMeJson(),
  'text': text,
  'createdAt': '2026-10-26T18:30:00.000Z',
};

Map<String, Object?> cpRankingEntryJson(int rank, {String? coupleId}) => {
  'rank': rank,
  'coupleId': coupleId ?? 'couple-$rank',
  'partners': [
    bondUserJson(id: 'a$rank', username: 'a$rank', displayName: 'Ali $rank'),
    bondUserJson(id: 'b$rank', username: 'b$rank', displayName: 'Mona $rank'),
  ],
  'level': 2,
  'levelName': 'Silver couple',
  'points': 1000 - rank * 10,
};

Map<String, Object?> cpRankingsJson(
  String period, {
  int count = 3,
  Map<String, Object?>? me,
}) => {
  'period': period,
  'startsAt': period == 'WEEK' ? '2026-10-26T00:00:00.000Z' : null,
  'endsAt': period == 'WEEK' ? '2026-11-02T00:00:00.000Z' : null,
  'data': [for (var i = 1; i <= count; i++) cpRankingEntryJson(i)],
  'page': {'nextCursor': null, 'hasMore': false},
  'me': me,
};

Map<String, Object?> cpGiftWallJson({int count = 2}) => {
  'data': [
    for (var i = 0; i < count; i++)
      {
        'id': 'gw-$i',
        'amount': 52,
        'giftCode': 'angel_heart',
        'sender': cpMeJson(),
        'receiver': cpPartnerJson(),
        'createdAt': '2026-10-26T18:30:00.000Z',
      },
  ],
  'page': {'nextCursor': null, 'hasMore': false},
  'totals': {'gifts': count, 'coins': count * 52},
};
