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

/// The `getCpConfig` example (all five tiers).
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
