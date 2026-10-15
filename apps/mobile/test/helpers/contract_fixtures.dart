// JSON payloads shaped exactly like docs/contracts/openapi.yaml.

Map<String, Object?> meJson({
  String id = '0192f1c2-7c3a-7b2e-9a51-1d2c3b4a5e6f',
  String email = 'layla@example.com',
  bool emailVerified = false,
  String username = 'layla.k',
  String displayName = 'ليلى',
  String? bio,
  String? avatarUrl,
  String locale = 'ar',
  String role = 'USER',
  bool isPrivate = false,
  String createdAt = '2026-10-15T13:00:00.000Z',
}) => {
  'id': id,
  'email': email,
  'emailVerified': emailVerified,
  'username': username,
  'displayName': displayName,
  'bio': bio,
  'avatarUrl': avatarUrl,
  'locale': locale,
  'role': role,
  'isPrivate': isPrivate,
  'createdAt': createdAt,
};

Map<String, Object?> tokenPairJson({
  String accessToken = 'access-1',
  String refreshToken = 'sid-1.secret-1',
}) => {
  'accessToken': accessToken,
  'accessTokenExpiresAt': '2026-10-15T13:15:00.000Z',
  'refreshToken': refreshToken,
  'refreshTokenExpiresAt': '2026-11-14T13:00:00.000Z',
};

Map<String, Object?> authResponseJson({
  Map<String, Object?>? user,
  Map<String, Object?>? tokens,
}) => {'user': user ?? meJson(), 'tokens': tokens ?? tokenPairJson()};

Map<String, Object?> sessionJson({
  required String id,
  bool current = false,
  String? deviceName,
  String? platform,
  String? appVersion,
}) => {
  'id': id,
  'current': current,
  'deviceName': deviceName,
  'platform': platform,
  'appVersion': appVersion,
  'ipCountry': null,
  'createdAt': '2026-10-01T08:00:00.000Z',
  'lastUsedAt': '2026-10-15T12:30:00.000Z',
};
