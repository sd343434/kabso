// Wire DTOs matching docs/contracts/openapi.yaml exactly.

import 'package:json_annotation/json_annotation.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';

part 'dtos.g.dart';

/// `Me`
@JsonSerializable()
class MeDto {
  const new({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.username,
    required this.displayName,
    required this.locale,
    required this.role,
    required this.isPrivate,
    required this.createdAt,
    this.bio,
    this.avatarUrl,
  });

  factory fromJson(Map<String, dynamic> json) => _$MeDtoFromJson(json);

  final String id;
  final String email;
  final bool emailVerified;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String locale;
  final String role;
  final bool isPrivate;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$MeDtoToJson(this);

  User toEntity() => User(
    id: id,
    email: email,
    emailVerified: emailVerified,
    username: username,
    displayName: displayName,
    bio: bio,
    avatarUrl: avatarUrl,
    locale: locale,
    role: role == 'ADMIN' ? UserRole.admin : UserRole.user,
    isPrivate: isPrivate,
    createdAt: createdAt,
  );
}

/// `AuthResponse`
@JsonSerializable()
class AuthResponseDto {
  const new({required this.user, required this.tokens});

  factory fromJson(Map<String, dynamic> json) =>
      _$AuthResponseDtoFromJson(json);

  final MeDto user;
  final AuthTokens tokens;

  Map<String, dynamic> toJson() => _$AuthResponseDtoToJson(this);
}

/// `DeviceInfo`
@JsonSerializable(includeIfNull: false)
class DeviceInfoDto {
  const new({this.name, this.platform, this.appVersion});

  factory fromJson(Map<String, dynamic> json) => _$DeviceInfoDtoFromJson(json);

  final String? name;

  /// `android | ios | web | other`
  final String? platform;
  final String? appVersion;

  Map<String, dynamic> toJson() => _$DeviceInfoDtoToJson(this);
}

/// `LoginRequest`
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class LoginRequestDto {
  const new({required this.identifier, required this.password, this.device});

  factory fromJson(Map<String, dynamic> json) =>
      _$LoginRequestDtoFromJson(json);

  final String identifier;
  final String password;
  final DeviceInfoDto? device;

  Map<String, dynamic> toJson() => _$LoginRequestDtoToJson(this);
}

/// `RegisterRequest`
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class RegisterRequestDto {
  const new({
    required this.email,
    required this.password,
    required this.username,
    required this.displayName,
    this.locale,
    this.device,
  });

  factory fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestDtoFromJson(json);

  final String email;
  final String password;
  final String username;
  final String displayName;

  /// `ar | en`
  final String? locale;
  final DeviceInfoDto? device;

  Map<String, dynamic> toJson() => _$RegisterRequestDtoToJson(this);
}

/// `SessionInfo`
@JsonSerializable()
class SessionInfoDto {
  const new({
    required this.id,
    required this.current,
    required this.createdAt,
    required this.lastUsedAt,
    this.deviceName,
    this.platform,
    this.appVersion,
    this.ipCountry,
  });

  factory fromJson(Map<String, dynamic> json) => _$SessionInfoDtoFromJson(json);

  final String id;
  final bool current;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final String? ipCountry;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  Map<String, dynamic> toJson() => _$SessionInfoDtoToJson(this);

  Session toEntity() => Session(
    id: id,
    current: current,
    deviceName: deviceName,
    platform: switch (platform) {
      'android' => SessionPlatform.android,
      'ios' => SessionPlatform.ios,
      'web' => SessionPlatform.web,
      null => null,
      _ => SessionPlatform.other,
    },
    appVersion: appVersion,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt,
  );
}

/// `GET /auth/sessions` response.
@JsonSerializable()
class SessionListDto {
  const new({required this.data});

  factory fromJson(Map<String, dynamic> json) => _$SessionListDtoFromJson(json);

  final List<SessionInfoDto> data;

  Map<String, dynamic> toJson() => _$SessionListDtoToJson(this);
}

/// `GET /users/username-availability` response.
@JsonSerializable()
class UsernameAvailabilityDto {
  const new({required this.username, required this.available});

  factory fromJson(Map<String, dynamic> json) =>
      _$UsernameAvailabilityDtoFromJson(json);

  final String username;
  final bool available;

  Map<String, dynamic> toJson() => _$UsernameAvailabilityDtoToJson(this);
}

/// `VerificationPending` (v1.2): constant body of `register` / `registerResend`.
@JsonSerializable()
class VerificationPendingDto {
  const new({required this.status});

  factory fromJson(Map<String, dynamic> json) =>
      _$VerificationPendingDtoFromJson(json);

  /// Always `verification_pending`.
  final String status;

  Map<String, dynamic> toJson() => _$VerificationPendingDtoToJson(this);
}

/// `RegisterVerifyRequest` (v1.2).
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class RegisterVerifyRequestDto {
  const new({required this.email, required this.code, this.device});

  factory fromJson(Map<String, dynamic> json) =>
      _$RegisterVerifyRequestDtoFromJson(json);

  final String email;

  /// Exactly 8 Western digits (`^[0-9]{8}$`).
  final String code;
  final DeviceInfoDto? device;

  Map<String, dynamic> toJson() => _$RegisterVerifyRequestDtoToJson(this);
}
