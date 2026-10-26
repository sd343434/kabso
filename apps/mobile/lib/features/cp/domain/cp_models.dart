// Wire models of the CP (couple) API (docs/contracts/openapi.yaml
// v1.21-live DRAFT, tag `cp`, CP-018; CONVENTIONS §10.21). The CP space
// (v1.24-live, CP-021, §10.24) adds the named gift cards and the profile's
// couple id and privileges here; its own models are in cp_space_models.dart.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';

part 'cp_models.freezed.dart';
part 'cp_models.g.dart';

/// One CP tier (`CpConfig.tiers`); [name] follows the app language.
@freezed
abstract class CpTier with _$CpTier {
  const factory({
    required int level,
    required int minPoints,
    required String name,
  }) = _CpTier;

  factory fromJson(Map<String, dynamic> json) => _$CpTierFromJson(json);
}

/// `CpGiftPreset` (v1.24-live, CP-021): a named CP gift card. [code] is
/// one of `rose_love`, `angel_heart`, `love_carriage`, `swan_love`,
/// `eternal_heart`; [name] follows the app language; sending still takes
/// [amount].
@freezed
abstract class CpGiftPreset with _$CpGiftPreset {
  const factory({
    required String code,
    required int amount,
    required String name,
    required String assetKey,
  }) = _CpGiftPreset;

  factory fromJson(Map<String, dynamic> json) => _$CpGiftPresetFromJson(json);
}

/// `CpConfig` (`GET /cp/config`): what a request costs (99 coins,
/// refunded unless accepted), the gift amounts and the tiers; v1.24-live
/// adds the named [gifts] (empty from an older server).
@freezed
abstract class CpConfig with _$CpConfig {
  const factory({
    required int requestCost,
    required int requestTtlDays,
    required List<int> giftAmounts,
    required List<CpTier> tiers,
    @Default(<CpGiftPreset>[]) List<CpGiftPreset> gifts,
  }) = _CpConfig;

  factory fromJson(Map<String, dynamic> json) => _$CpConfigFromJson(json);
}

/// `CpRequest`: a pending (or answered) CP request.
@freezed
abstract class CpRequest with _$CpRequest {
  const factory({
    required String id,
    required UserSummary sender,
    required UserSummary receiver,
    required BondRequestStatus status,
    required int cost,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) = _CpRequest;

  factory fromJson(Map<String, dynamic> json) => _$CpRequestFromJson(json);
}

/// `CpRequestPage`.
@freezed
abstract class CpRequestPage with _$CpRequestPage {
  const factory({required List<CpRequest> data, required PageInfo page}) =
      _CpRequestPage;

  factory fromJson(Map<String, dynamic> json) => _$CpRequestPageFromJson(json);
}

/// `CpCouple`: the caller and their partner.
@freezed
abstract class CpCouple with _$CpCouple {
  const factory({
    required String id,
    required UserSummary partner,
    required DateTime since,

    /// Days together; the day it was formed is day 1.
    required int days,
    required int points,
    required int level,
    required String levelName,
    required String? nextLevelName,
    required int? pointsToNext,
  }) = _CpCouple;

  factory fromJson(Map<String, dynamic> json) => _$CpCoupleFromJson(json);
}

/// `CpGiftResult.gift`.
@freezed
abstract class CpGift with _$CpGift {
  const factory({
    required String id,
    required int amount,
    required DateTime createdAt,
  }) = _CpGift;

  factory fromJson(Map<String, dynamic> json) => _$CpGiftFromJson(json);
}

/// `ProfileCp`: a user's couple on their public profile. v1.24-live
/// (CP-021): [id] opens the couple's CP space (null from an older server)
/// and [privileges] are the `CpPrivilegeCode`s its level unlocked.
@freezed
abstract class ProfileCp with _$ProfileCp {
  const factory({
    required UserSummary partner,
    required DateTime since,
    required int level,
    required String levelName,
    required int points,
    String? id,
    @Default(<String>[]) List<String> privileges,
  }) = _ProfileCp;

  factory fromJson(Map<String, dynamic> json) => _$ProfileCpFromJson(json);
}

/// Which CP requests to list (`GET /cp/requests?direction=`).
enum CpDirection { incoming, outgoing }
