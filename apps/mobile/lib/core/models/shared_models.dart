// Wire models shared by several features (docs/contracts/openapi.yaml
// v1.3 `components.schemas`).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/premium_tier.dart';

part 'shared_models.freezed.dart';
part 'shared_models.g.dart';

/// `PageInfo` (CONVENTIONS §5). Cursors are opaque: never parsed or built.
@freezed
abstract class PageInfo with _$PageInfo {
  const factory({required String? nextCursor, required bool hasMore}) =
      _PageInfo;

  factory fromJson(Map<String, dynamic> json) => _$PageInfoFromJson(json);
}

/// v1.54-social (D185): reads `RechargeAgentTag` (`{code}`) to its code;
/// anything else (absent, null, malformed) is no agent.
String? rechargeAgentCodeFromJson(Object? json) => switch (json) {
  {'code': final String code} when code.isNotEmpty => code,
  _ => null,
};

/// The wire shape of [rechargeAgentCodeFromJson].
Map<String, dynamic>? rechargeAgentCodeToJson(String? code) =>
    code == null ? null : {'code': code};

/// `AvatarFrame` (v1.55-social, D186, CONVENTIONS §10.49): the avatar frame a
/// user wears (bag `AVATAR_FRAME`). The app draws the frames it has art for
/// (`AvatarFrameArt.of`) and ignores the others.
@immutable
final class AvatarFrame {
  const new({required this.code, required this.assetKey});

  final String code;
  final String assetKey;

  @override
  bool operator ==(Object other) =>
      other is AvatarFrame && other.code == code && other.assetKey == assetKey;

  @override
  int get hashCode => Object.hash(code, assetKey);

  @override
  String toString() => 'AvatarFrame($code, $assetKey)';
}

/// v1.55-social (D186): reads `AvatarFrame` (`{code, assetKey}`); anything
/// else (absent, null, malformed) is no frame.
AvatarFrame? avatarFrameFromJson(Object? json) => switch (json) {
  {'code': final String code, 'assetKey': final String assetKey}
      when code.isNotEmpty && assetKey.isNotEmpty =>
    AvatarFrame(code: code, assetKey: assetKey),
  _ => null,
};

/// The wire shape of [avatarFrameFromJson].
Map<String, dynamic>? avatarFrameToJson(AvatarFrame? frame) =>
    frame == null ? null : {'code': frame.code, 'assetKey': frame.assetKey};

/// `UserSummary`: minimal public identity of a user. Never has an email.
@freezed
abstract class UserSummary with _$UserSummary {
  const factory({
    required String id,
    required String username,
    required String displayName,
    required String? avatarUrl,

    /// v1.28-live (D146): the tier of the user's premium username (the
    /// badge), or null for a regular username. Only the server decides it.
    @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)
    PremiumTier? premiumTier,

    /// v1.54-social (D185, §10.48): the user's recharge-agent code while
    /// they are an ACTIVE agent (`UserSummary.rechargeAgent.code`): the
    /// small agent badge next to the name in live rooms. Null otherwise.
    @JsonKey(
      name: 'rechargeAgent',
      includeIfNull: false,
      fromJson: rechargeAgentCodeFromJson,
      toJson: rechargeAgentCodeToJson,
    )
    String? rechargeAgentCode,

    /// v1.55-social (D186, §10.49): the avatar frame the user wears
    /// (`UserSummary.avatarFrame`, present only while one is worn): drawn
    /// around the picture on the live seats. Null otherwise.
    @JsonKey(
      includeIfNull: false,
      fromJson: avatarFrameFromJson,
      toJson: avatarFrameToJson,
    )
    AvatarFrame? avatarFrame,
  }) = _UserSummary;

  factory fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);
}
