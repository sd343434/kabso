// Wire models of the CP (couple) API (docs/contracts/openapi.yaml
// v1.21-live DRAFT, tag `cp`, CP-018; CONVENTIONS §10.21).

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

/// `CpConfig` (`GET /cp/config`): what a request costs (99 coins,
/// refunded unless accepted), the gift amounts and the tiers.
@freezed
abstract class CpConfig with _$CpConfig {
  const factory({
    required int requestCost,
    required int requestTtlDays,
    required List<int> giftAmounts,
    required List<CpTier> tiers,
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

/// `ProfileCp`: a user's couple on their public profile.
@freezed
abstract class ProfileCp with _$ProfileCp {
  const factory({
    required UserSummary partner,
    required DateTime since,
    required int level,
    required String levelName,
    required int points,
  }) = _ProfileCp;

  factory fromJson(Map<String, dynamic> json) => _$ProfileCpFromJson(json);
}

/// Which CP requests to list (`GET /cp/requests?direction=`).
enum CpDirection { incoming, outgoing }
