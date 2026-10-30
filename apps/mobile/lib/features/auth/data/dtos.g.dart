// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MeDto _$MeDtoFromJson(Map<String, dynamic> json) => MeDto(
  id: json['id'] as String,
  email: json['email'] as String,
  emailVerified: json['emailVerified'] as bool,
  username: json['username'] as String,
  displayName: json['displayName'] as String,
  locale: json['locale'] as String,
  role: json['role'] as String,
  isPrivate: json['isPrivate'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  bio: json['bio'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  canHost: json['canHost'] as bool? ?? false,
  liveCoverUrl: json['liveCoverUrl'] as String?,
  country: json['country'] as String?,
  premiumTier: premiumTierFromJson(json['premiumTier']),
  gender: genderFromJson(json['gender']),
  showGender: json['showGender'] as bool? ?? false,
  category: accountCategoryFromJson(json['category']),
  links: json['links'] == null ? const [] : profileLinksFromJson(json['links']),
);

Map<String, dynamic> _$MeDtoToJson(MeDto instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'emailVerified': instance.emailVerified,
  'username': instance.username,
  'displayName': instance.displayName,
  'bio': instance.bio,
  'avatarUrl': instance.avatarUrl,
  'locale': instance.locale,
  'role': instance.role,
  'isPrivate': instance.isPrivate,
  'createdAt': instance.createdAt.toIso8601String(),
  'canHost': instance.canHost,
  'liveCoverUrl': instance.liveCoverUrl,
  'country': instance.country,
  'premiumTier': premiumTierToJson(instance.premiumTier),
  'gender': genderToJson(instance.gender),
  'showGender': instance.showGender,
  'category': accountCategoryToJson(instance.category),
  'links': profileLinksToJson(instance.links),
};

AuthResponseDto _$AuthResponseDtoFromJson(Map<String, dynamic> json) =>
    AuthResponseDto(
      user: MeDto.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthResponseDtoToJson(AuthResponseDto instance) =>
    <String, dynamic>{'user': instance.user, 'tokens': instance.tokens};

DeviceInfoDto _$DeviceInfoDtoFromJson(Map<String, dynamic> json) =>
    DeviceInfoDto(
      name: json['name'] as String?,
      platform: json['platform'] as String?,
      appVersion: json['appVersion'] as String?,
    );

Map<String, dynamic> _$DeviceInfoDtoToJson(DeviceInfoDto instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'platform': ?instance.platform,
      'appVersion': ?instance.appVersion,
    };

LoginRequestDto _$LoginRequestDtoFromJson(Map<String, dynamic> json) =>
    LoginRequestDto(
      identifier: json['identifier'] as String,
      password: json['password'] as String,
      device: json['device'] == null
          ? null
          : DeviceInfoDto.fromJson(json['device'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LoginRequestDtoToJson(LoginRequestDto instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'password': instance.password,
      'device': ?instance.device?.toJson(),
    };

RegisterRequestDto _$RegisterRequestDtoFromJson(Map<String, dynamic> json) =>
    RegisterRequestDto(
      email: json['email'] as String,
      password: json['password'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      gender: json['gender'] as String,
      locale: json['locale'] as String?,
      device: json['device'] == null
          ? null
          : DeviceInfoDto.fromJson(json['device'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RegisterRequestDtoToJson(RegisterRequestDto instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
      'username': instance.username,
      'displayName': instance.displayName,
      'gender': instance.gender,
      'locale': ?instance.locale,
      'device': ?instance.device?.toJson(),
    };

SessionInfoDto _$SessionInfoDtoFromJson(Map<String, dynamic> json) =>
    SessionInfoDto(
      id: json['id'] as String,
      current: json['current'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
      appVersion: json['appVersion'] as String?,
      ipCountry: json['ipCountry'] as String?,
    );

Map<String, dynamic> _$SessionInfoDtoToJson(SessionInfoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'current': instance.current,
      'deviceName': instance.deviceName,
      'platform': instance.platform,
      'appVersion': instance.appVersion,
      'ipCountry': instance.ipCountry,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt.toIso8601String(),
    };

SessionListDto _$SessionListDtoFromJson(Map<String, dynamic> json) =>
    SessionListDto(
      data: (json['data'] as List<dynamic>)
          .map((e) => SessionInfoDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SessionListDtoToJson(SessionListDto instance) =>
    <String, dynamic>{'data': instance.data};

UsernameAvailabilityDto _$UsernameAvailabilityDtoFromJson(
  Map<String, dynamic> json,
) => UsernameAvailabilityDto(
  username: json['username'] as String,
  available: json['available'] as bool,
);

Map<String, dynamic> _$UsernameAvailabilityDtoToJson(
  UsernameAvailabilityDto instance,
) => <String, dynamic>{
  'username': instance.username,
  'available': instance.available,
};

VerificationPendingDto _$VerificationPendingDtoFromJson(
  Map<String, dynamic> json,
) => VerificationPendingDto(status: json['status'] as String);

Map<String, dynamic> _$VerificationPendingDtoToJson(
  VerificationPendingDto instance,
) => <String, dynamic>{'status': instance.status};

RegisterVerifyRequestDto _$RegisterVerifyRequestDtoFromJson(
  Map<String, dynamic> json,
) => RegisterVerifyRequestDto(
  email: json['email'] as String,
  code: json['code'] as String,
  device: json['device'] == null
      ? null
      : DeviceInfoDto.fromJson(json['device'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RegisterVerifyRequestDtoToJson(
  RegisterVerifyRequestDto instance,
) => <String, dynamic>{
  'email': instance.email,
  'code': instance.code,
  'device': ?instance.device?.toJson(),
};
