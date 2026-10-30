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
/// anything else (absent, null, malformed) is no agent. v1.58-social
/// (D189): also `HostAgentTag` (the same shape).
String? rechargeAgentCodeFromJson(Object? json) => switch (json) {
  {'code': final String code} when code.isNotEmpty => code,
  _ => null,
};

/// The wire shape of [rechargeAgentCodeFromJson].
Map<String, dynamic>? rechargeAgentCodeToJson(String? code) =>
    code == null ? null : {'code': code};

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

    /// v1.58-social (D189, §10.52): the user's host-agent code «وكيل مضيفين»
    /// while their agency is not suspended (`UserSummary.hostAgent.code`,
    /// the same `{code}` shape): the host-agent badge next to the name and
    /// the entrance. Null otherwise.
    @JsonKey(
      name: 'hostAgent',
      includeIfNull: false,
      fromJson: rechargeAgentCodeFromJson,
      toJson: rechargeAgentCodeToJson,
    )
    String? hostAgentCode,
  }) = _UserSummary;

  factory fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);
}
