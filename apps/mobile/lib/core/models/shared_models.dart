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
  }) = _UserSummary;

  factory fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);
}
