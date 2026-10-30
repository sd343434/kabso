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

    /// v1.55-social (D186, §10.49): the avatar frame the user wears
    /// (`UserSummary.avatarFrame`, present only while one is worn): drawn
    /// around the picture on the live seats. Null otherwise.
    @JsonKey(
      includeIfNull: false,
      fromJson: avatarFrameFromJson,
      toJson: avatarFrameToJson,
    )
    AvatarFrame? avatarFrame,

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
