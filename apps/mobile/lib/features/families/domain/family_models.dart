// Wire models of the families API (docs/contracts/openapi.yaml v1.21-live
// DRAFT, tag `families`, CP-018; CONVENTIONS §10.21; v1.25-live, CP-022,
// §10.25: boards, contributions, presence, cover, tagline and chat).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';

part 'family_models.freezed.dart';
part 'family_models.g.dart';

/// `FamilyRole`: one LEADER (the creator, or whom they handed it to),
/// DEPUTY (accepts and declines join requests) and MEMBER.
enum FamilyRole {
  @JsonValue('LEADER')
  leader,
  @JsonValue('DEPUTY')
  deputy,
  @JsonValue('MEMBER')
  member;

  /// The wire value (`SetFamilyRoleRequest.role`).
  String get wire => switch (this) {
    leader => 'LEADER',
    deputy => 'DEPUTY',
    member => 'MEMBER',
  };

  /// The leader and deputies answer join requests (§10.21).
  bool get answersRequests => this == leader || this == deputy;
}

/// `BondRequestStatus` of a family join request or a CP request.
enum BondRequestStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('ACCEPTED')
  accepted,
  @JsonValue('DECLINED')
  declined,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('EXPIRED')
  expired,
}

/// One step of the family level ladder (`FamilyConfig.levels`).
@freezed
abstract class FamilyLevelStep with _$FamilyLevelStep {
  const factory({required int level, required int minPoints}) =
      _FamilyLevelStep;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyLevelStepFromJson(json);
}

/// `FamilyConfig` (`GET /families/config`): what a family costs (500
/// coins), how many people it holds and the level ladder.
@freezed
abstract class FamilyConfig with _$FamilyConfig {
  const factory({
    required int createCost,
    required int capacity,
    required int requestTtlDays,
    required List<FamilyLevelStep> levels,
  }) = _FamilyConfig;

  factory fromJson(Map<String, dynamic> json) => _$FamilyConfigFromJson(json);
}

/// `FamilyCard`: one family in a list.
@freezed
abstract class FamilyCard with _$FamilyCard {
  const factory({
    required String id,
    required int number,
    required String name,
    required String? emblemUrl,
    required int level,
    required int points,
    required int memberCount,
    required int capacity,
  }) = _FamilyCard;

  factory fromJson(Map<String, dynamic> json) => _$FamilyCardFromJson(json);
}

/// `Family`: one family with the caller's role and pending request.
@freezed
abstract class Family with _$Family {
  const factory({
    required String id,
    required int number,
    required String name,
    required String? emblemUrl,
    required int level,
    required int points,
    required int memberCount,
    required int capacity,

    /// Points the next level needs; null at the top level.
    required int? nextLevelPoints,
    required UserSummary? leader,
    required DateTime createdAt,

    /// The caller's role here, or null when they are not a member.
    required FamilyRole? myRole,

    /// The caller's pending join request to this family.
    required String? myRequestId,

    /// v1.25-live: the cover picture, or null (the page draws its own).
    String? coverUrl,

    /// v1.25-live: the short line under the name, or null.
    String? tagline,

    /// v1.25-live: pending join requests (leader and deputies only).
    int? pendingRequestCount,
  }) = _Family;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$FamilyFromJson(json);

  bool get isFull => memberCount >= capacity;
}

/// `FamilyMember`: a member, their role and the points they gave.
@freezed
abstract class FamilyMember with _$FamilyMember {
  const factory({
    required UserSummary user,
    required FamilyRole role,
    required DateTime joinedAt,
    required int points,

    /// v1.25-live: the points given in the current month.
    @Default(0) int monthPoints,

    /// v1.25-live: online / last active, when the caller may see it.
    FamilyPresence? presence,

    /// v1.25-live: muted in the family chat (leader and deputies see it).
    bool? chatMuted,

    /// v1.25-live: the place by points (with `sort=POINTS`).
    int? rank,
  }) = _FamilyMember;

  factory fromJson(Map<String, dynamic> json) => _$FamilyMemberFromJson(json);
}

/// `FamilyJoinRequest`: someone asked to join a family.
@freezed
abstract class FamilyJoinRequest with _$FamilyJoinRequest {
  const factory({
    required String id,
    required FamilyCard family,
    required UserSummary user,
    required BondRequestStatus status,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) = _FamilyJoinRequest;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyJoinRequestFromJson(json);
}

/// `FamilyCardPage`.
@freezed
abstract class FamilyCardPage with _$FamilyCardPage {
  const factory({required List<FamilyCard> data, required PageInfo page}) =
      _FamilyCardPage;

  factory fromJson(Map<String, dynamic> json) => _$FamilyCardPageFromJson(json);
}

/// `FamilyMemberPage`.
@freezed
abstract class FamilyMemberPage with _$FamilyMemberPage {
  const factory({required List<FamilyMember> data, required PageInfo page}) =
      _FamilyMemberPage;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyMemberPageFromJson(json);
}

/// `FamilyJoinRequestPage`.
@freezed
abstract class FamilyJoinRequestPage with _$FamilyJoinRequestPage {
  const factory({
    required List<FamilyJoinRequest> data,
    required PageInfo page,
  }) = _FamilyJoinRequestPage;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyJoinRequestPageFromJson(json);
}

/// `ProfileFamily`: a user's family and role on their public profile.
@freezed
abstract class ProfileFamily with _$ProfileFamily {
  const factory({
    required String id,
    required int number,
    required String name,
    required int level,
    required String? emblemUrl,
    required FamilyRole role,
  }) = _ProfileFamily;

  factory fromJson(Map<String, dynamic> json) => _$ProfileFamilyFromJson(json);
}

/// `FamilyPresence` (§10.25): online = active in the last 5 minutes.
@freezed
abstract class FamilyPresence with _$FamilyPresence {
  const factory({required bool online, required DateTime? lastActiveAt}) =
      _FamilyPresence;

  factory fromJson(Map<String, dynamic> json) => _$FamilyPresenceFromJson(json);
}

/// `FamilyRankingBoard`: هيبة العائلة (points this month) and الأكثر نشاطاً
/// (members active this week).
enum FamilyRankingBoard {
  @JsonValue('PRESTIGE')
  prestige,
  @JsonValue('ACTIVE')
  active;

  String get wire => switch (this) {
    prestige => 'PRESTIGE',
    active => 'ACTIVE',
  };
}

/// `FamilyRankingEntry`.
@freezed
abstract class FamilyRankingEntry with _$FamilyRankingEntry {
  const factory({
    required int rank,
    required FamilyCard family,
    required int score,
  }) = _FamilyRankingEntry;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyRankingEntryFromJson(json);
}

/// `FamilyRankings.me`: the caller's family (rank null with 0).
@freezed
abstract class FamilyRankingMe with _$FamilyRankingMe {
  const factory({
    required FamilyCard family,
    required int? rank,
    required int score,
  }) = _FamilyRankingMe;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyRankingMeFromJson(json);
}

/// `FamilyRankings` (`GET /families/rankings`).
@freezed
abstract class FamilyRankings with _$FamilyRankings {
  const factory({
    required FamilyRankingBoard board,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<FamilyRankingEntry> data,
    required PageInfo page,
    required FamilyRankingMe? me,
  }) = _FamilyRankings;

  factory fromJson(Map<String, dynamic> json) => _$FamilyRankingsFromJson(json);
}

/// One board's place (`FamilyBoardStanding`).
@freezed
abstract class FamilyBoardStanding with _$FamilyBoardStanding {
  const factory({
    required int? rank,
    required int score,
    required DateTime startsAt,
    required DateTime endsAt,
  }) = _FamilyBoardStanding;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyBoardStandingFromJson(json);
}

/// `FamilyStanding` (`GET /families/{familyId}/rankings`).
@freezed
abstract class FamilyStanding with _$FamilyStanding {
  const factory({
    required String familyId,
    required FamilyBoardStanding prestige,
    required FamilyBoardStanding active,
  }) = _FamilyStanding;

  factory fromJson(Map<String, dynamic> json) => _$FamilyStandingFromJson(json);
}

/// `FamilyContribution`: what a member gave this month.
@freezed
abstract class FamilyContribution with _$FamilyContribution {
  const factory({
    required int rank,
    required UserSummary user,
    required FamilyRole role,
    required int points,
  }) = _FamilyContribution;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyContributionFromJson(json);
}

/// `FamilyContributions`.
@freezed
abstract class FamilyContributions with _$FamilyContributions {
  const factory({
    required DateTime startsAt,
    required DateTime endsAt,
    required List<FamilyContribution> data,
    required PageInfo page,
  }) = _FamilyContributions;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyContributionsFromJson(json);
}

/// `FamilyChatMessage`.
@freezed
abstract class FamilyChatMessage with _$FamilyChatMessage {
  const factory({
    required String id,
    required String familyId,
    required UserSummary author,
    required FamilyRole? authorRole,
    required String text,
    required DateTime createdAt,
  }) = _FamilyChatMessage;

  factory fromJson(Map<String, dynamic> json) =>
      _$FamilyChatMessageFromJson(json);
}

/// `FamilyChatPage`: newest first, with the caller's state in the chat.
@freezed
abstract class FamilyChatPage with _$FamilyChatPage {
  const factory({
    required List<FamilyChatMessage> data,
    required PageInfo page,
    required bool muted,
    required bool canModerate,
  }) = _FamilyChatPage;

  factory fromJson(Map<String, dynamic> json) => _$FamilyChatPageFromJson(json);
}
