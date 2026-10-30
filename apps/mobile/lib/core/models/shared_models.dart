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

/// v1.56-social (D187, §10.50): `RechargeBadge` — the daily recharge badge
/// «شارة الشحن اليومي», tier 1–5 until [until] (the moment the tier was
/// reached + 24 h). The server sends it only while it shows; the app hides
/// it itself once [until] passes ([isActiveAt]).
@immutable
class RechargeBadge {
  const new({required this.tier, required this.until});

  /// 1 … 5.
  final int tier;
  final DateTime until;

  /// Whether the badge still shows at [now].
  bool isActiveAt(DateTime now) => now.isBefore(until);

  @override
  bool operator ==(Object other) =>
      other is RechargeBadge && other.tier == tier && other.until == until;

  @override
  int get hashCode => Object.hash(tier, until);

  @override
  String toString() => 'RechargeBadge($tier, $until)';
}

/// Reads `RechargeBadge` (`{tier, until}`); anything else (absent, null,
/// malformed, a tier outside 1–5) is no badge.
RechargeBadge? rechargeBadgeFromJson(Object? json) => switch (json) {
  {'tier': final int tier, 'until': final String until}
      when tier >= 1 && tier <= 5 =>
    switch (DateTime.tryParse(until)) {
      final DateTime at => RechargeBadge(tier: tier, until: at.toUtc()),
      null => null,
    },
  _ => null,
};

/// The wire shape of [rechargeBadgeFromJson].
Map<String, dynamic>? rechargeBadgeToJson(RechargeBadge? badge) => badge == null
    ? null
    : {'tier': badge.tier, 'until': badge.until.toUtc().toIso8601String()};

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

    /// v1.56-social (D187, §10.50): the daily recharge badge while it shows
    /// (never for a recharge agent): next to the name in live rooms like the
    /// level badge. Null otherwise (also on older servers).
    @JsonKey(
      includeIfNull: false,
      fromJson: rechargeBadgeFromJson,
      toJson: rechargeBadgeToJson,
    )
    RechargeBadge? rechargeBadge,
  }) = _UserSummary;

  factory fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);
}
