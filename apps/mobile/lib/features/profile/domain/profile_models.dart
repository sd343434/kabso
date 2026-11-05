// Public profile and follow models matching docs/contracts/openapi.yaml
// v1.3 (`getPublicProfile`, `followUser`, `unfollowUser`; CONVENTIONS
// §10.5–10.6), with the family, couple and medals of v1.21-live (CP-018,
// §10.21), the profile card of v1.22-live (CP-019, §10.22) and the
// «في بث الآن» card of v1.70-live (D279, §10.5.1).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';

part 'profile_models.freezed.dart';
part 'profile_models.g.dart';

/// `PublicProfile`. Never contains an email, role, status or locale.
@freezed
abstract class PublicProfile with _$PublicProfile {
  const factory({
    required String id,
    required String username,
    required String displayName,
    required String? avatarUrl,
    required String? bio,
    required bool isPrivate,
    required int followerCount,
    required int followingCount,
    required bool isFollowing,
    required bool isSelf,
    required String? liveRoomId,

    /// v1.70-live (D279, §10.5.1): the «في بث الآن» card — the facts of the
    /// [liveRoomId] room; null when not live, across a block, and from
    /// older servers.
    ProfileLive? live,

    /// CP-007: the caller muted this user (never shown to them). Defaults
    /// to false for previews built without it.
    @Default(false) bool isMuted,

    /// v1.28-live (D146): the tier of the user's premium username (the
    /// badge), or null for a regular username. Only the server decides it.
    @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)
    PremiumTier? premiumTier,

    /// v1.21-live (CP-018): the user's family and role, or null.
    ProfileFamily? family,

    /// v1.21-live (CP-018): the user's couple, or null.
    ProfileCp? cp,

    /// v1.21-live (CP-018): medals owned, the newest and the chosen
    /// showcase (empty for previews built without it).
    @Default(ProfileMedals()) ProfileMedals medals,

    /// v1.22-live (CP-019): the profile card the user wears, or null.
    ProfileCard? profileCard,

    /// v1.47-social (D175): the caller has a pending request to follow
    /// this private account.
    @Default(false) bool followRequested,

    /// v1.47-social (D175): the gender, only when the user shows it.
    @JsonKey(fromJson: genderFromJson, toJson: genderToJson) Gender? gender,

    /// v1.47-social (D175): the account category under the name.
    @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)
    AccountCategory? category,

    /// v1.47-social (D175): the profile links (also on a private profile).
    @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)
    @Default(<ProfileLink>[])
    List<ProfileLink> links,

    /// v1.54-social (D185, §10.48): the user's code while they are an
    /// ACTIVE recharge agent — the agent frame (with the code in its
    /// plate) and the badge. Null otherwise (also on older servers).
    @JsonKey(
      name: 'rechargeAgent',
      includeIfNull: false,
      fromJson: rechargeAgentCodeFromJson,
      toJson: rechargeAgentCodeToJson,
    )
    String? rechargeAgentCode,

    /// v1.58-social (D189, §10.52): the user's code while they are a host
    /// agent (agency not suspended) — the host-agent frame (no name) and
    /// badge. Null otherwise (also on older servers).
    @JsonKey(
      name: 'hostAgent',
      includeIfNull: false,
      fromJson: rechargeAgentCodeFromJson,
      toJson: rechargeAgentCodeToJson,
    )
    String? hostAgentCode,

    /// v1.55-social (D186, §10.49): the avatar frame the user wears (e.g.
    /// the active-host frame), drawn around the profile photo. Null when
    /// none (also on older servers).
    @JsonKey(
      includeIfNull: false,
      fromJson: avatarFrameFromJson,
      toJson: avatarFrameToJson,
    )
    AvatarFrame? avatarFrame,

    /// v1.56-social (D187, §10.50): the daily recharge badge while it shows;
    /// beside the name on the profile like the level badge. Null otherwise.
    @JsonKey(
      includeIfNull: false,
      fromJson: rechargeBadgeFromJson,
      toJson: rechargeBadgeToJson,
    )
    RechargeBadge? rechargeBadge,

    /// v1.83-social (D258, §10.94): the active VIP (badge, animated frame,
    /// card). Null otherwise. D270: with the store items worn (`wear`).
    @JsonKey(
      includeIfNull: false,
      readValue: userVipWithWear,
      fromJson: userVipFromJson,
      toJson: userVipToJson,
    )
    UserVip? vip,

    /// v1.76-social (D218, §10.73.3): the profile cover across the top, or
    /// null (the Kabso gradient).
    String? coverUrl,

    /// v1.76-social (D218): the country the user chose (ISO alpha-2), or
    /// null.
    String? country,

    /// v1.76-social (D218): the month the account was created,
    /// `YYYY-MM` (UTC), or null on older servers.
    String? joinedMonth,

    /// v1.76-social (D218): the caller blocked this user — «إلغاء الحظر»
    /// instead of Follow, and no posts.
    @Default(false) bool blockedByMe,

    /// v1.77-social (D220, §10.74): the lifetime cherries received from
    /// gifts. Null when the user hides it from the caller (the server does
    /// not send it) or the server is older; never null on your own profile.
    @JsonKey(includeIfNull: false) int? cherriesReceived,

    /// v1.77-social (D220, §10.74): the lifetime coins sent on gifts; null
    /// like [cherriesReceived].
    @JsonKey(includeIfNull: false) int? coinsSent,

    /// v1.68-live (D273, §10.96.7): the account holds a panel role — «فريق
    /// كابسو». The person card hides the actions against it (kick, mute,
    /// seat); the server refuses them anyway (`STAFF_PROTECTED`).
    @Default(false) bool kabsoTeam,
  }) = _PublicProfile;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$PublicProfileFromJson(json);

  /// Whether a plain follow (no request) is possible (§10.5/10.6): never
  /// for yourself, and not to start following a private account.
  bool get canFollow => !isSelf && (isFollowing || !isPrivate);

  /// v1.47-social (D175, §10.47): whether Follow may be offered (the profile
  /// page and, owner, the live room): everyone but yourself — on a private
  /// account it sends a request.
  bool get canFollowOrRequest => !isSelf;

  /// v1.47-social (D175): a private account the caller may not see the
  /// posts, reels and stories of («هذا الحساب خاص»).
  bool get locked => isPrivate && !isFollowing && !isSelf;
}

/// v1.70-live (D279, §10.5.1): `ProfileLive` — the profile's «في بث الآن»
/// card: the live's room, title, mode, start, viewers now and score.
@freezed
abstract class ProfileLive with _$ProfileLive {
  const factory({
    required String roomId,
    required DateTime startedAt,
    @Default('') String title,
    @JsonKey(unknownEnumValue: LiveRoomMode.solo)
    @Default(LiveRoomMode.solo)
    LiveRoomMode mode,
    @Default(0) int viewerCount,
    @Default(0) int score,
  }) = _ProfileLive;

  factory fromJson(Map<String, dynamic> json) => _$ProfileLiveFromJson(json);
}

/// `FollowState`: the result of follow / unfollow.
@freezed
abstract class FollowState with _$FollowState {
  const factory({
    required bool isFollowing,
    required int followerCount,

    /// v1.47-social (D175): a follow request is pending (private account).
    @Default(false) bool isRequested,
  }) = _FollowState;

  factory fromJson(Map<String, dynamic> json) => _$FollowStateFromJson(json);
}
