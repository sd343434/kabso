import 'package:json_annotation/json_annotation.dart';

part 'auth_tokens.g.dart';

/// `TokenPair` from openapi.yaml.
@JsonSerializable()
class AuthTokens {
  const new({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  factory fromJson(Map<String, dynamic> json) => _$AuthTokensFromJson(json);

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  Map<String, dynamic> toJson() => _$AuthTokensToJson(this);

  /// Never print token values.
  @override
  String toString() =>
      'AuthTokens(accessTokenExpiresAt: $accessTokenExpiresAt, '
      'refreshTokenExpiresAt: $refreshTokenExpiresAt)';
}
