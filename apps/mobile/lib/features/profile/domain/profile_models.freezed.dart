// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicProfile {

 String get id; String get username; String get displayName; String? get avatarUrl; String? get bio; bool get isPrivate; int get followerCount; int get followingCount; bool get isFollowing; bool get isSelf; String? get liveRoomId;/// v1.70-live (D279, §10.5.1): the «في بث الآن» card — the facts of the
/// [liveRoomId] room; null when not live, across a block, and from
/// older servers.
 ProfileLive? get live;/// CP-007: the caller muted this user (never shown to them). Defaults
/// to false for previews built without it.
 bool get isMuted;/// v1.28-live (D146): the tier of the user's premium username (the
/// badge), or null for a regular username. Only the server decides it.
@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? get premiumTier;/// v1.21-live (CP-018): the user's family and role, or null.
 ProfileFamily? get family;/// v1.21-live (CP-018): the user's couple, or null.
 ProfileCp? get cp;/// v1.21-live (CP-018): medals owned, the newest and the chosen
/// showcase (empty for previews built without it).
 ProfileMedals get medals;/// v1.22-live (CP-019): the profile card the user wears, or null.
 ProfileCard? get profileCard;/// v1.47-social (D175): the caller has a pending request to follow
/// this private account.
 bool get followRequested;/// v1.47-social (D175): the gender, only when the user shows it.
@JsonKey(fromJson: genderFromJson, toJson: genderToJson) Gender? get gender;/// v1.47-social (D175): the account category under the name.
@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) AccountCategory? get category;/// v1.138-social (D386, §10.175): the Kabso Team verified [category] —
/// only then the page takes the category's look and featured section
/// (absent from an older server: false, the default look).
 bool get categoryVerified;/// v1.47-social (D175): the profile links (also on a private profile).
@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> get links;/// v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10, in
/// order; also on a private profile), chips on the cover.
 List<String> get tags;/// v1.91-social (D292, §10.106): the icon of each tag (`ProfileTagIcon`
/// keys, one per tag; empty from an older server — read as `default`).
 List<String> get tagIcons;/// v1.54-social (D185, §10.48): the user's code while they are an
/// ACTIVE recharge agent — the agent frame (with the code in its
/// plate) and the badge. Null otherwise (also on older servers).
@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get rechargeAgentCode;/// v1.58-social (D189, §10.52): the user's code while they are a host
/// agent (agency not suspended) — the host-agent frame (no name) and
/// badge. Null otherwise (also on older servers).
@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get hostAgentCode;/// v1.90-social (D293, §10.105): the automatic verification badge
/// «شارة التوثيق» right after the name — only its type. Null when none,
/// for unknown values and from older servers.
@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) VerificationBadge? get verification;/// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
/// the photo (`<pack>.<emoji>`), or null (also from older servers).
@JsonKey(includeIfNull: false) String? get statusEmojiId;/// v1.55-social (D186, §10.49): the avatar frame the user wears (e.g.
/// the active-host frame), drawn around the profile photo. Null when
/// none (also on older servers).
@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? get avatarFrame;/// v1.56-social (D187, §10.50): the daily recharge badge while it shows;
/// beside the name on the profile like the level badge. Null otherwise.
@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? get rechargeBadge;/// v1.83-social (D258, §10.94): the active VIP (badge, animated frame,
/// card). Null otherwise. D270: with the store items worn (`wear`).
@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) UserVip? get vip;/// v1.76-social (D218, §10.73.3): the profile cover across the top, or
/// null (the Kabso gradient).
 String? get coverUrl;/// v1.76-social (D218): the country the user chose (ISO alpha-2), or
/// null.
 String? get country;/// v1.76-social (D218): the month the account was created,
/// `YYYY-MM` (UTC), or null on older servers.
 String? get joinedMonth;/// v1.76-social (D218): the caller blocked this user — «إلغاء الحظر»
/// instead of Follow, and no posts.
 bool get blockedByMe;/// v1.77-social (D220, §10.74): the lifetime cherries received from
/// gifts. Null when the user hides it from the caller (the server does
/// not send it) or the server is older; never null on your own profile.
@JsonKey(includeIfNull: false) int? get cherriesReceived;/// v1.77-social (D220, §10.74): the lifetime coins sent on gifts; null
/// like [cherriesReceived].
@JsonKey(includeIfNull: false) int? get coinsSent;/// v1.68-live (D273, §10.96.7): the account holds a panel role — «فريق
/// كابسو». The person card hides the actions against it (kick, mute,
/// seat); the server refuses them anyway (`STAFF_PROTECTED`).
 bool get kabsoTeam;/// v1.72-live (D283, §10.96.10–11): a limited Kabso Team account
/// (MODERATION / SUPPORT / FINANCE, not OWNER): the team badge, the
/// locked frame, picture and region cover, the region line, no levels.
/// Null for everyone else (the OWNER too) and from older servers.
@JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false) KabsoStaffIdentity? get staff;/// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
/// the account holds a panel role (the OWNER too): the profile and the
/// person card show «ID: Kabso01» instead of the @username. Null for
/// everyone else and from older servers.
@JsonKey(includeIfNull: false) String? get staffId;/// v1.131-social (D378, §10.168.4): the golden ID «آيدي ذهبي» held now —
/// the gold «ID 8888» chip on the profile. Null otherwise.
@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) UserGoldenId? get goldenId;/// v1.95-social (D301, §10.112): the app owner (an ACTIVE account
/// holding the OWNER panel role) — the owner's profile layout. False for
/// everyone else and from older servers.
 bool get kabsoOwner;/// v1.95-social (D301, §10.112.1): the owner's cover videos (Arabic,
/// English); null when none (the cover picture shows).
@JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false) OwnerCoverVideo? get coverVideo;/// v1.98-social (D307, §10.112.11): the founder's bilingual bio; null
/// when none (the app's default founder text shows).
@JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false) OwnerBio? get ownerBio;/// v1.118-social (D357, §10.153): how many «اقترح ميزة / أبلغ»
/// submissions the founder has received (one combined number, cached by
/// the server); null on anyone else's profile and from older servers
/// (the founder's page then shows «–», never a made-up 0).
@JsonKey(includeIfNull: false) int? get founderFeedbackCount;/// v1.136-social (D384, §10.173.4): the VIP animated picture «صورة
/// متحركة» — only while the person holds the ANIMATED_AVATAR perk and has
/// a clip, never across a block; null otherwise and from older servers
/// (the round photo shows).
@JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false) AnimatedAvatar? get animatedAvatar;/// v1.141-social (D390 follow-up, §10.179.9): the exclusive ambassador
/// badge's level (`PublicProfile.ambassador.level`) — only while the
/// programme is on and the membership is ACTIVE; null otherwise and from
/// older servers.
@JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false) String? get ambassadorLevel;
/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicProfileCopyWith<PublicProfile> get copyWith => _$PublicProfileCopyWithImpl<PublicProfile>(this as PublicProfile, _$identity);

  /// Serializes this PublicProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PublicProfile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfile&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.bio, _this.bio) || other.bio == _this.bio)&&(identical(other.isPrivate, _this.isPrivate) || other.isPrivate == _this.isPrivate)&&(identical(other.followerCount, _this.followerCount) || other.followerCount == _this.followerCount)&&(identical(other.followingCount, _this.followingCount) || other.followingCount == _this.followingCount)&&(identical(other.isFollowing, _this.isFollowing) || other.isFollowing == _this.isFollowing)&&(identical(other.isSelf, _this.isSelf) || other.isSelf == _this.isSelf)&&(identical(other.liveRoomId, _this.liveRoomId) || other.liveRoomId == _this.liveRoomId)&&(identical(other.live, _this.live) || other.live == _this.live)&&(identical(other.isMuted, _this.isMuted) || other.isMuted == _this.isMuted)&&(identical(other.premiumTier, _this.premiumTier) || other.premiumTier == _this.premiumTier)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.cp, _this.cp) || other.cp == _this.cp)&&(identical(other.medals, _this.medals) || other.medals == _this.medals)&&(identical(other.profileCard, _this.profileCard) || other.profileCard == _this.profileCard)&&(identical(other.followRequested, _this.followRequested) || other.followRequested == _this.followRequested)&&(identical(other.gender, _this.gender) || other.gender == _this.gender)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.categoryVerified, _this.categoryVerified) || other.categoryVerified == _this.categoryVerified)&&const DeepCollectionEquality().equals(other.links, _this.links)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.tagIcons, _this.tagIcons)&&(identical(other.rechargeAgentCode, _this.rechargeAgentCode) || other.rechargeAgentCode == _this.rechargeAgentCode)&&(identical(other.hostAgentCode, _this.hostAgentCode) || other.hostAgentCode == _this.hostAgentCode)&&(identical(other.verification, _this.verification) || other.verification == _this.verification)&&(identical(other.statusEmojiId, _this.statusEmojiId) || other.statusEmojiId == _this.statusEmojiId)&&(identical(other.avatarFrame, _this.avatarFrame) || other.avatarFrame == _this.avatarFrame)&&(identical(other.rechargeBadge, _this.rechargeBadge) || other.rechargeBadge == _this.rechargeBadge)&&(identical(other.vip, _this.vip) || other.vip == _this.vip)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.joinedMonth, _this.joinedMonth) || other.joinedMonth == _this.joinedMonth)&&(identical(other.blockedByMe, _this.blockedByMe) || other.blockedByMe == _this.blockedByMe)&&(identical(other.cherriesReceived, _this.cherriesReceived) || other.cherriesReceived == _this.cherriesReceived)&&(identical(other.coinsSent, _this.coinsSent) || other.coinsSent == _this.coinsSent)&&(identical(other.kabsoTeam, _this.kabsoTeam) || other.kabsoTeam == _this.kabsoTeam)&&(identical(other.staff, _this.staff) || other.staff == _this.staff)&&(identical(other.staffId, _this.staffId) || other.staffId == _this.staffId)&&(identical(other.goldenId, _this.goldenId) || other.goldenId == _this.goldenId)&&(identical(other.kabsoOwner, _this.kabsoOwner) || other.kabsoOwner == _this.kabsoOwner)&&(identical(other.coverVideo, _this.coverVideo) || other.coverVideo == _this.coverVideo)&&(identical(other.ownerBio, _this.ownerBio) || other.ownerBio == _this.ownerBio)&&(identical(other.founderFeedbackCount, _this.founderFeedbackCount) || other.founderFeedbackCount == _this.founderFeedbackCount)&&(identical(other.animatedAvatar, _this.animatedAvatar) || other.animatedAvatar == _this.animatedAvatar)&&(identical(other.ambassadorLevel, _this.ambassadorLevel) || other.ambassadorLevel == _this.ambassadorLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublicProfile;
  return Object.hashAll([runtimeType,_this.id,_this.username,_this.displayName,_this.avatarUrl,_this.bio,_this.isPrivate,_this.followerCount,_this.followingCount,_this.isFollowing,_this.isSelf,_this.liveRoomId,_this.live,_this.isMuted,_this.premiumTier,_this.family,_this.cp,_this.medals,_this.profileCard,_this.followRequested,_this.gender,_this.category,_this.categoryVerified,const DeepCollectionEquality().hash(_this.links),const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.tagIcons),_this.rechargeAgentCode,_this.hostAgentCode,_this.verification,_this.statusEmojiId,_this.avatarFrame,_this.rechargeBadge,_this.vip,_this.coverUrl,_this.country,_this.joinedMonth,_this.blockedByMe,_this.cherriesReceived,_this.coinsSent,_this.kabsoTeam,_this.staff,_this.staffId,_this.goldenId,_this.kabsoOwner,_this.coverVideo,_this.ownerBio,_this.founderFeedbackCount,_this.animatedAvatar,_this.ambassadorLevel]);
}

@override
String toString() {
  final _this = this as PublicProfile;
  return 'PublicProfile(id: ${_this.id}, username: ${_this.username}, displayName: ${_this.displayName}, avatarUrl: ${_this.avatarUrl}, bio: ${_this.bio}, isPrivate: ${_this.isPrivate}, followerCount: ${_this.followerCount}, followingCount: ${_this.followingCount}, isFollowing: ${_this.isFollowing}, isSelf: ${_this.isSelf}, liveRoomId: ${_this.liveRoomId}, live: ${_this.live}, isMuted: ${_this.isMuted}, premiumTier: ${_this.premiumTier}, family: ${_this.family}, cp: ${_this.cp}, medals: ${_this.medals}, profileCard: ${_this.profileCard}, followRequested: ${_this.followRequested}, gender: ${_this.gender}, category: ${_this.category}, categoryVerified: ${_this.categoryVerified}, links: ${_this.links}, tags: ${_this.tags}, tagIcons: ${_this.tagIcons}, rechargeAgentCode: ${_this.rechargeAgentCode}, hostAgentCode: ${_this.hostAgentCode}, verification: ${_this.verification}, statusEmojiId: ${_this.statusEmojiId}, avatarFrame: ${_this.avatarFrame}, rechargeBadge: ${_this.rechargeBadge}, vip: ${_this.vip}, coverUrl: ${_this.coverUrl}, country: ${_this.country}, joinedMonth: ${_this.joinedMonth}, blockedByMe: ${_this.blockedByMe}, cherriesReceived: ${_this.cherriesReceived}, coinsSent: ${_this.coinsSent}, kabsoTeam: ${_this.kabsoTeam}, staff: ${_this.staff}, staffId: ${_this.staffId}, goldenId: ${_this.goldenId}, kabsoOwner: ${_this.kabsoOwner}, coverVideo: ${_this.coverVideo}, ownerBio: ${_this.ownerBio}, founderFeedbackCount: ${_this.founderFeedbackCount}, animatedAvatar: ${_this.animatedAvatar}, ambassadorLevel: ${_this.ambassadorLevel})';
}


}

/// @nodoc
abstract mixin class $PublicProfileCopyWith<$Res>  {
  factory $PublicProfileCopyWith(PublicProfile value, $Res Function(PublicProfile) _then) = _$PublicProfileCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl, String? bio, bool isPrivate, int followerCount, int followingCount, bool isFollowing, bool isSelf, String? liveRoomId, ProfileLive? live, bool isMuted,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier, ProfileFamily? family, ProfileCp? cp, ProfileMedals medals, ProfileCard? profileCard, bool followRequested,@JsonKey(fromJson: genderFromJson, toJson: genderToJson) Gender? gender,@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) AccountCategory? category, bool categoryVerified,@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> links, List<String> tags, List<String> tagIcons,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? hostAgentCode,@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) VerificationBadge? verification,@JsonKey(includeIfNull: false) String? statusEmojiId,@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? avatarFrame,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge,@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) UserVip? vip, String? coverUrl, String? country, String? joinedMonth, bool blockedByMe,@JsonKey(includeIfNull: false) int? cherriesReceived,@JsonKey(includeIfNull: false) int? coinsSent, bool kabsoTeam,@JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false) KabsoStaffIdentity? staff,@JsonKey(includeIfNull: false) String? staffId,@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) UserGoldenId? goldenId, bool kabsoOwner,@JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false) OwnerCoverVideo? coverVideo,@JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false) OwnerBio? ownerBio,@JsonKey(includeIfNull: false) int? founderFeedbackCount,@JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false) AnimatedAvatar? animatedAvatar,@JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false) String? ambassadorLevel
});


$ProfileLiveCopyWith<$Res>? get live;$ProfileFamilyCopyWith<$Res>? get family;$ProfileCpCopyWith<$Res>? get cp;$ProfileMedalsCopyWith<$Res> get medals;$ProfileCardCopyWith<$Res>? get profileCard;

}
/// @nodoc
class _$PublicProfileCopyWithImpl<$Res>
    implements $PublicProfileCopyWith<$Res> {
  _$PublicProfileCopyWithImpl(this._self, this._then);

  final PublicProfile _self;
  final $Res Function(PublicProfile) _then;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? isPrivate = null,Object? followerCount = null,Object? followingCount = null,Object? isFollowing = null,Object? isSelf = null,Object? liveRoomId = freezed,Object? live = freezed,Object? isMuted = null,Object? premiumTier = freezed,Object? family = freezed,Object? cp = freezed,Object? medals = null,Object? profileCard = freezed,Object? followRequested = null,Object? gender = freezed,Object? category = freezed,Object? categoryVerified = null,Object? links = null,Object? tags = null,Object? tagIcons = null,Object? rechargeAgentCode = freezed,Object? hostAgentCode = freezed,Object? verification = freezed,Object? statusEmojiId = freezed,Object? avatarFrame = freezed,Object? rechargeBadge = freezed,Object? vip = freezed,Object? coverUrl = freezed,Object? country = freezed,Object? joinedMonth = freezed,Object? blockedByMe = null,Object? cherriesReceived = freezed,Object? coinsSent = freezed,Object? kabsoTeam = null,Object? staff = freezed,Object? staffId = freezed,Object? goldenId = freezed,Object? kabsoOwner = null,Object? coverVideo = freezed,Object? ownerBio = freezed,Object? founderFeedbackCount = freezed,Object? animatedAvatar = freezed,Object? ambassadorLevel = freezed,}) {
  return _then(PublicProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,isSelf: null == isSelf ? _self.isSelf : isSelf // ignore: cast_nullable_to_non_nullable
as bool,liveRoomId: freezed == liveRoomId ? _self.liveRoomId : liveRoomId // ignore: cast_nullable_to_non_nullable
as String?,live: freezed == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as ProfileLive?,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as ProfileFamily?,cp: freezed == cp ? _self.cp : cp // ignore: cast_nullable_to_non_nullable
as ProfileCp?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as ProfileMedals,profileCard: freezed == profileCard ? _self.profileCard : profileCard // ignore: cast_nullable_to_non_nullable
as ProfileCard?,followRequested: null == followRequested ? _self.followRequested : followRequested // ignore: cast_nullable_to_non_nullable
as bool,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as AccountCategory?,categoryVerified: null == categoryVerified ? _self.categoryVerified : categoryVerified // ignore: cast_nullable_to_non_nullable
as bool,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as List<ProfileLink>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,tagIcons: null == tagIcons ? _self.tagIcons : tagIcons // ignore: cast_nullable_to_non_nullable
as List<String>,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,hostAgentCode: freezed == hostAgentCode ? _self.hostAgentCode : hostAgentCode // ignore: cast_nullable_to_non_nullable
as String?,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as VerificationBadge?,statusEmojiId: freezed == statusEmojiId ? _self.statusEmojiId : statusEmojiId // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as AvatarFrame?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,vip: freezed == vip ? _self.vip : vip // ignore: cast_nullable_to_non_nullable
as UserVip?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,joinedMonth: freezed == joinedMonth ? _self.joinedMonth : joinedMonth // ignore: cast_nullable_to_non_nullable
as String?,blockedByMe: null == blockedByMe ? _self.blockedByMe : blockedByMe // ignore: cast_nullable_to_non_nullable
as bool,cherriesReceived: freezed == cherriesReceived ? _self.cherriesReceived : cherriesReceived // ignore: cast_nullable_to_non_nullable
as int?,coinsSent: freezed == coinsSent ? _self.coinsSent : coinsSent // ignore: cast_nullable_to_non_nullable
as int?,kabsoTeam: null == kabsoTeam ? _self.kabsoTeam : kabsoTeam // ignore: cast_nullable_to_non_nullable
as bool,staff: freezed == staff ? _self.staff : staff // ignore: cast_nullable_to_non_nullable
as KabsoStaffIdentity?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,goldenId: freezed == goldenId ? _self.goldenId : goldenId // ignore: cast_nullable_to_non_nullable
as UserGoldenId?,kabsoOwner: null == kabsoOwner ? _self.kabsoOwner : kabsoOwner // ignore: cast_nullable_to_non_nullable
as bool,coverVideo: freezed == coverVideo ? _self.coverVideo : coverVideo // ignore: cast_nullable_to_non_nullable
as OwnerCoverVideo?,ownerBio: freezed == ownerBio ? _self.ownerBio : ownerBio // ignore: cast_nullable_to_non_nullable
as OwnerBio?,founderFeedbackCount: freezed == founderFeedbackCount ? _self.founderFeedbackCount : founderFeedbackCount // ignore: cast_nullable_to_non_nullable
as int?,animatedAvatar: freezed == animatedAvatar ? _self.animatedAvatar : animatedAvatar // ignore: cast_nullable_to_non_nullable
as AnimatedAvatar?,ambassadorLevel: freezed == ambassadorLevel ? _self.ambassadorLevel : ambassadorLevel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileLiveCopyWith<$Res>? get live {
    if (_self.live == null) {
    return null;
  }

  return $ProfileLiveCopyWith<$Res>(_self.live!, (value) {
    return _then(_self.copyWith(live: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileFamilyCopyWith<$Res>? get family {
    if (_self.family == null) {
    return null;
  }

  return $ProfileFamilyCopyWith<$Res>(_self.family!, (value) {
    return _then(_self.copyWith(family: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCpCopyWith<$Res>? get cp {
    if (_self.cp == null) {
    return null;
  }

  return $ProfileCpCopyWith<$Res>(_self.cp!, (value) {
    return _then(_self.copyWith(cp: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileMedalsCopyWith<$Res> get medals {
  
  return $ProfileMedalsCopyWith<$Res>(_self.medals, (value) {
    return _then(_self.copyWith(medals: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCardCopyWith<$Res>? get profileCard {
    if (_self.profileCard == null) {
    return null;
  }

  return $ProfileCardCopyWith<$Res>(_self.profileCard!, (value) {
    return _then(_self.copyWith(profileCard: value));
  });
}
}


/// Adds pattern-matching-related methods to [PublicProfile].
extension PublicProfilePatterns on PublicProfile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicProfile value)  $default,){
final _that = this;
switch (_that) {
case _PublicProfile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicProfile value)?  $default,){
final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  ProfileLive? live,  bool isMuted, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard,  bool followRequested, @JsonKey(fromJson: genderFromJson, toJson: genderToJson)  Gender? gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)  AccountCategory? category,  bool categoryVerified, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links,  List<String> tags,  List<String> tagIcons, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson)  VerificationBadge? verification, @JsonKey(includeIfNull: false)  String? statusEmojiId, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson)  UserVip? vip,  String? coverUrl,  String? country,  String? joinedMonth,  bool blockedByMe, @JsonKey(includeIfNull: false)  int? cherriesReceived, @JsonKey(includeIfNull: false)  int? coinsSent,  bool kabsoTeam, @JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false)  KabsoStaffIdentity? staff, @JsonKey(includeIfNull: false)  String? staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson)  UserGoldenId? goldenId,  bool kabsoOwner, @JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false)  OwnerCoverVideo? coverVideo, @JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false)  OwnerBio? ownerBio, @JsonKey(includeIfNull: false)  int? founderFeedbackCount, @JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false)  AnimatedAvatar? animatedAvatar, @JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false)  String? ambassadorLevel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.live,_that.isMuted,_that.premiumTier,_that.family,_that.cp,_that.medals,_that.profileCard,_that.followRequested,_that.gender,_that.category,_that.categoryVerified,_that.links,_that.tags,_that.tagIcons,_that.rechargeAgentCode,_that.hostAgentCode,_that.verification,_that.statusEmojiId,_that.avatarFrame,_that.rechargeBadge,_that.vip,_that.coverUrl,_that.country,_that.joinedMonth,_that.blockedByMe,_that.cherriesReceived,_that.coinsSent,_that.kabsoTeam,_that.staff,_that.staffId,_that.goldenId,_that.kabsoOwner,_that.coverVideo,_that.ownerBio,_that.founderFeedbackCount,_that.animatedAvatar,_that.ambassadorLevel);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  ProfileLive? live,  bool isMuted, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard,  bool followRequested, @JsonKey(fromJson: genderFromJson, toJson: genderToJson)  Gender? gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)  AccountCategory? category,  bool categoryVerified, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links,  List<String> tags,  List<String> tagIcons, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson)  VerificationBadge? verification, @JsonKey(includeIfNull: false)  String? statusEmojiId, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson)  UserVip? vip,  String? coverUrl,  String? country,  String? joinedMonth,  bool blockedByMe, @JsonKey(includeIfNull: false)  int? cherriesReceived, @JsonKey(includeIfNull: false)  int? coinsSent,  bool kabsoTeam, @JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false)  KabsoStaffIdentity? staff, @JsonKey(includeIfNull: false)  String? staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson)  UserGoldenId? goldenId,  bool kabsoOwner, @JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false)  OwnerCoverVideo? coverVideo, @JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false)  OwnerBio? ownerBio, @JsonKey(includeIfNull: false)  int? founderFeedbackCount, @JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false)  AnimatedAvatar? animatedAvatar, @JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false)  String? ambassadorLevel)  $default,) {final _that = this;
switch (_that) {
case _PublicProfile():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.live,_that.isMuted,_that.premiumTier,_that.family,_that.cp,_that.medals,_that.profileCard,_that.followRequested,_that.gender,_that.category,_that.categoryVerified,_that.links,_that.tags,_that.tagIcons,_that.rechargeAgentCode,_that.hostAgentCode,_that.verification,_that.statusEmojiId,_that.avatarFrame,_that.rechargeBadge,_that.vip,_that.coverUrl,_that.country,_that.joinedMonth,_that.blockedByMe,_that.cherriesReceived,_that.coinsSent,_that.kabsoTeam,_that.staff,_that.staffId,_that.goldenId,_that.kabsoOwner,_that.coverVideo,_that.ownerBio,_that.founderFeedbackCount,_that.animatedAvatar,_that.ambassadorLevel);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  ProfileLive? live,  bool isMuted, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard,  bool followRequested, @JsonKey(fromJson: genderFromJson, toJson: genderToJson)  Gender? gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)  AccountCategory? category,  bool categoryVerified, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links,  List<String> tags,  List<String> tagIcons, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson)  VerificationBadge? verification, @JsonKey(includeIfNull: false)  String? statusEmojiId, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson)  UserVip? vip,  String? coverUrl,  String? country,  String? joinedMonth,  bool blockedByMe, @JsonKey(includeIfNull: false)  int? cherriesReceived, @JsonKey(includeIfNull: false)  int? coinsSent,  bool kabsoTeam, @JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false)  KabsoStaffIdentity? staff, @JsonKey(includeIfNull: false)  String? staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson)  UserGoldenId? goldenId,  bool kabsoOwner, @JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false)  OwnerCoverVideo? coverVideo, @JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false)  OwnerBio? ownerBio, @JsonKey(includeIfNull: false)  int? founderFeedbackCount, @JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false)  AnimatedAvatar? animatedAvatar, @JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false)  String? ambassadorLevel)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.live,_that.isMuted,_that.premiumTier,_that.family,_that.cp,_that.medals,_that.profileCard,_that.followRequested,_that.gender,_that.category,_that.categoryVerified,_that.links,_that.tags,_that.tagIcons,_that.rechargeAgentCode,_that.hostAgentCode,_that.verification,_that.statusEmojiId,_that.avatarFrame,_that.rechargeBadge,_that.vip,_that.coverUrl,_that.country,_that.joinedMonth,_that.blockedByMe,_that.cherriesReceived,_that.coinsSent,_that.kabsoTeam,_that.staff,_that.staffId,_that.goldenId,_that.kabsoOwner,_that.coverVideo,_that.ownerBio,_that.founderFeedbackCount,_that.animatedAvatar,_that.ambassadorLevel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicProfile extends PublicProfile {
  const _PublicProfile({required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.bio, required this.isPrivate, required this.followerCount, required this.followingCount, required this.isFollowing, required this.isSelf, required this.liveRoomId, this.live, this.isMuted = false, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) this.premiumTier, this.family, this.cp, this.medals = const ProfileMedals(), this.profileCard, this.followRequested = false, @JsonKey(fromJson: genderFromJson, toJson: genderToJson) this.gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) this.category, this.categoryVerified = false, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links = const <ProfileLink>[],  List<String> tags = const <String>[],  List<String> tagIcons = const <String>[], @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.hostAgentCode, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) this.verification, @JsonKey(includeIfNull: false) this.statusEmojiId, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) this.avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) this.rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) this.vip, this.coverUrl, this.country, this.joinedMonth, this.blockedByMe = false, @JsonKey(includeIfNull: false) this.cherriesReceived, @JsonKey(includeIfNull: false) this.coinsSent, this.kabsoTeam = false, @JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false) this.staff, @JsonKey(includeIfNull: false) this.staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) this.goldenId, this.kabsoOwner = false, @JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false) this.coverVideo, @JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false) this.ownerBio, @JsonKey(includeIfNull: false) this.founderFeedbackCount, @JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false) this.animatedAvatar, @JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false) this.ambassadorLevel}): _links = links,_tags = tags,_tagIcons = tagIcons,super._();
  factory _PublicProfile.fromJson(Map<String, dynamic> json) => _$PublicProfileFromJson(json);

@override final  String id;
@override final  String username;
@override final  String displayName;
@override final  String? avatarUrl;
@override final  String? bio;
@override final  bool isPrivate;
@override final  int followerCount;
@override final  int followingCount;
@override final  bool isFollowing;
@override final  bool isSelf;
@override final  String? liveRoomId;
/// v1.70-live (D279, §10.5.1): the «في بث الآن» card — the facts of the
/// [liveRoomId] room; null when not live, across a block, and from
/// older servers.
@override final  ProfileLive? live;
/// CP-007: the caller muted this user (never shown to them). Defaults
/// to false for previews built without it.
@override@JsonKey() final  bool isMuted;
/// v1.28-live (D146): the tier of the user's premium username (the
/// badge), or null for a regular username. Only the server decides it.
@override@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) final  PremiumTier? premiumTier;
/// v1.21-live (CP-018): the user's family and role, or null.
@override final  ProfileFamily? family;
/// v1.21-live (CP-018): the user's couple, or null.
@override final  ProfileCp? cp;
/// v1.21-live (CP-018): medals owned, the newest and the chosen
/// showcase (empty for previews built without it).
@override@JsonKey() final  ProfileMedals medals;
/// v1.22-live (CP-019): the profile card the user wears, or null.
@override final  ProfileCard? profileCard;
/// v1.47-social (D175): the caller has a pending request to follow
/// this private account.
@override@JsonKey() final  bool followRequested;
/// v1.47-social (D175): the gender, only when the user shows it.
@override@JsonKey(fromJson: genderFromJson, toJson: genderToJson) final  Gender? gender;
/// v1.47-social (D175): the account category under the name.
@override@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) final  AccountCategory? category;
/// v1.138-social (D386, §10.175): the Kabso Team verified [category] —
/// only then the page takes the category's look and featured section
/// (absent from an older server: false, the default look).
@override@JsonKey() final  bool categoryVerified;
/// v1.47-social (D175): the profile links (also on a private profile).
 final  List<ProfileLink> _links;
/// v1.47-social (D175): the profile links (also on a private profile).
@override@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> get links {
  if (_links is EqualUnmodifiableListView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_links);
}

/// v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10, in
/// order; also on a private profile), chips on the cover.
 final  List<String> _tags;
/// v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10, in
/// order; also on a private profile), chips on the cover.
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// v1.91-social (D292, §10.106): the icon of each tag (`ProfileTagIcon`
/// keys, one per tag; empty from an older server — read as `default`).
 final  List<String> _tagIcons;
/// v1.91-social (D292, §10.106): the icon of each tag (`ProfileTagIcon`
/// keys, one per tag; empty from an older server — read as `default`).
@override@JsonKey() List<String> get tagIcons {
  if (_tagIcons is EqualUnmodifiableListView) return _tagIcons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIcons);
}

/// v1.54-social (D185, §10.48): the user's code while they are an
/// ACTIVE recharge agent — the agent frame (with the code in its
/// plate) and the badge. Null otherwise (also on older servers).
@override@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) final  String? rechargeAgentCode;
/// v1.58-social (D189, §10.52): the user's code while they are a host
/// agent (agency not suspended) — the host-agent frame (no name) and
/// badge. Null otherwise (also on older servers).
@override@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) final  String? hostAgentCode;
/// v1.90-social (D293, §10.105): the automatic verification badge
/// «شارة التوثيق» right after the name — only its type. Null when none,
/// for unknown values and from older servers.
@override@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) final  VerificationBadge? verification;
/// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
/// the photo (`<pack>.<emoji>`), or null (also from older servers).
@override@JsonKey(includeIfNull: false) final  String? statusEmojiId;
/// v1.55-social (D186, §10.49): the avatar frame the user wears (e.g.
/// the active-host frame), drawn around the profile photo. Null when
/// none (also on older servers).
@override@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) final  AvatarFrame? avatarFrame;
/// v1.56-social (D187, §10.50): the daily recharge badge while it shows;
/// beside the name on the profile like the level badge. Null otherwise.
@override@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) final  RechargeBadge? rechargeBadge;
/// v1.83-social (D258, §10.94): the active VIP (badge, animated frame,
/// card). Null otherwise. D270: with the store items worn (`wear`).
@override@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) final  UserVip? vip;
/// v1.76-social (D218, §10.73.3): the profile cover across the top, or
/// null (the Kabso gradient).
@override final  String? coverUrl;
/// v1.76-social (D218): the country the user chose (ISO alpha-2), or
/// null.
@override final  String? country;
/// v1.76-social (D218): the month the account was created,
/// `YYYY-MM` (UTC), or null on older servers.
@override final  String? joinedMonth;
/// v1.76-social (D218): the caller blocked this user — «إلغاء الحظر»
/// instead of Follow, and no posts.
@override@JsonKey() final  bool blockedByMe;
/// v1.77-social (D220, §10.74): the lifetime cherries received from
/// gifts. Null when the user hides it from the caller (the server does
/// not send it) or the server is older; never null on your own profile.
@override@JsonKey(includeIfNull: false) final  int? cherriesReceived;
/// v1.77-social (D220, §10.74): the lifetime coins sent on gifts; null
/// like [cherriesReceived].
@override@JsonKey(includeIfNull: false) final  int? coinsSent;
/// v1.68-live (D273, §10.96.7): the account holds a panel role — «فريق
/// كابسو». The person card hides the actions against it (kick, mute,
/// seat); the server refuses them anyway (`STAFF_PROTECTED`).
@override@JsonKey() final  bool kabsoTeam;
/// v1.72-live (D283, §10.96.10–11): a limited Kabso Team account
/// (MODERATION / SUPPORT / FINANCE, not OWNER): the team badge, the
/// locked frame, picture and region cover, the region line, no levels.
/// Null for everyone else (the OWNER too) and from older servers.
@override@JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false) final  KabsoStaffIdentity? staff;
/// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
/// the account holds a panel role (the OWNER too): the profile and the
/// person card show «ID: Kabso01» instead of the @username. Null for
/// everyone else and from older servers.
@override@JsonKey(includeIfNull: false) final  String? staffId;
/// v1.131-social (D378, §10.168.4): the golden ID «آيدي ذهبي» held now —
/// the gold «ID 8888» chip on the profile. Null otherwise.
@override@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) final  UserGoldenId? goldenId;
/// v1.95-social (D301, §10.112): the app owner (an ACTIVE account
/// holding the OWNER panel role) — the owner's profile layout. False for
/// everyone else and from older servers.
@override@JsonKey() final  bool kabsoOwner;
/// v1.95-social (D301, §10.112.1): the owner's cover videos (Arabic,
/// English); null when none (the cover picture shows).
@override@JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false) final  OwnerCoverVideo? coverVideo;
/// v1.98-social (D307, §10.112.11): the founder's bilingual bio; null
/// when none (the app's default founder text shows).
@override@JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false) final  OwnerBio? ownerBio;
/// v1.118-social (D357, §10.153): how many «اقترح ميزة / أبلغ»
/// submissions the founder has received (one combined number, cached by
/// the server); null on anyone else's profile and from older servers
/// (the founder's page then shows «–», never a made-up 0).
@override@JsonKey(includeIfNull: false) final  int? founderFeedbackCount;
/// v1.136-social (D384, §10.173.4): the VIP animated picture «صورة
/// متحركة» — only while the person holds the ANIMATED_AVATAR perk and has
/// a clip, never across a block; null otherwise and from older servers
/// (the round photo shows).
@override@JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false) final  AnimatedAvatar? animatedAvatar;
/// v1.141-social (D390 follow-up, §10.179.9): the exclusive ambassador
/// badge's level (`PublicProfile.ambassador.level`) — only while the
/// programme is on and the membership is ACTIVE; null otherwise and from
/// older servers.
@override@JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false) final  String? ambassadorLevel;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicProfileCopyWith<_PublicProfile> get copyWith => __$PublicProfileCopyWithImpl<_PublicProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicProfileToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isSelf, isSelf) || other.isSelf == isSelf)&&(identical(other.liveRoomId, liveRoomId) || other.liveRoomId == liveRoomId)&&(identical(other.live, live) || other.live == live)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.premiumTier, premiumTier) || other.premiumTier == premiumTier)&&(identical(other.family, family) || other.family == family)&&(identical(other.cp, cp) || other.cp == cp)&&(identical(other.medals, medals) || other.medals == medals)&&(identical(other.profileCard, profileCard) || other.profileCard == profileCard)&&(identical(other.followRequested, followRequested) || other.followRequested == followRequested)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.category, category) || other.category == category)&&(identical(other.categoryVerified, categoryVerified) || other.categoryVerified == categoryVerified)&&const DeepCollectionEquality().equals(other.links, _links)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.tagIcons, _tagIcons)&&(identical(other.rechargeAgentCode, rechargeAgentCode) || other.rechargeAgentCode == rechargeAgentCode)&&(identical(other.hostAgentCode, hostAgentCode) || other.hostAgentCode == hostAgentCode)&&(identical(other.verification, verification) || other.verification == verification)&&(identical(other.statusEmojiId, statusEmojiId) || other.statusEmojiId == statusEmojiId)&&(identical(other.avatarFrame, avatarFrame) || other.avatarFrame == avatarFrame)&&(identical(other.rechargeBadge, rechargeBadge) || other.rechargeBadge == rechargeBadge)&&(identical(other.vip, vip) || other.vip == vip)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.country, country) || other.country == country)&&(identical(other.joinedMonth, joinedMonth) || other.joinedMonth == joinedMonth)&&(identical(other.blockedByMe, blockedByMe) || other.blockedByMe == blockedByMe)&&(identical(other.cherriesReceived, cherriesReceived) || other.cherriesReceived == cherriesReceived)&&(identical(other.coinsSent, coinsSent) || other.coinsSent == coinsSent)&&(identical(other.kabsoTeam, kabsoTeam) || other.kabsoTeam == kabsoTeam)&&(identical(other.staff, staff) || other.staff == staff)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.goldenId, goldenId) || other.goldenId == goldenId)&&(identical(other.kabsoOwner, kabsoOwner) || other.kabsoOwner == kabsoOwner)&&(identical(other.coverVideo, coverVideo) || other.coverVideo == coverVideo)&&(identical(other.ownerBio, ownerBio) || other.ownerBio == ownerBio)&&(identical(other.founderFeedbackCount, founderFeedbackCount) || other.founderFeedbackCount == founderFeedbackCount)&&(identical(other.animatedAvatar, animatedAvatar) || other.animatedAvatar == animatedAvatar)&&(identical(other.ambassadorLevel, ambassadorLevel) || other.ambassadorLevel == ambassadorLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,username,displayName,avatarUrl,bio,isPrivate,followerCount,followingCount,isFollowing,isSelf,liveRoomId,live,isMuted,premiumTier,family,cp,medals,profileCard,followRequested,gender,category,categoryVerified,const DeepCollectionEquality().hash(_links),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_tagIcons),rechargeAgentCode,hostAgentCode,verification,statusEmojiId,avatarFrame,rechargeBadge,vip,coverUrl,country,joinedMonth,blockedByMe,cherriesReceived,coinsSent,kabsoTeam,staff,staffId,goldenId,kabsoOwner,coverVideo,ownerBio,founderFeedbackCount,animatedAvatar,ambassadorLevel]);
}

@override
String toString() {
    return 'PublicProfile(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, isPrivate: $isPrivate, followerCount: $followerCount, followingCount: $followingCount, isFollowing: $isFollowing, isSelf: $isSelf, liveRoomId: $liveRoomId, live: $live, isMuted: $isMuted, premiumTier: $premiumTier, family: $family, cp: $cp, medals: $medals, profileCard: $profileCard, followRequested: $followRequested, gender: $gender, category: $category, categoryVerified: $categoryVerified, links: $links, tags: $tags, tagIcons: $tagIcons, rechargeAgentCode: $rechargeAgentCode, hostAgentCode: $hostAgentCode, verification: $verification, statusEmojiId: $statusEmojiId, avatarFrame: $avatarFrame, rechargeBadge: $rechargeBadge, vip: $vip, coverUrl: $coverUrl, country: $country, joinedMonth: $joinedMonth, blockedByMe: $blockedByMe, cherriesReceived: $cherriesReceived, coinsSent: $coinsSent, kabsoTeam: $kabsoTeam, staff: $staff, staffId: $staffId, goldenId: $goldenId, kabsoOwner: $kabsoOwner, coverVideo: $coverVideo, ownerBio: $ownerBio, founderFeedbackCount: $founderFeedbackCount, animatedAvatar: $animatedAvatar, ambassadorLevel: $ambassadorLevel)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileCopyWith<$Res> implements $PublicProfileCopyWith<$Res> {
  factory _$PublicProfileCopyWith(_PublicProfile value, $Res Function(_PublicProfile) _then) = __$PublicProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl, String? bio, bool isPrivate, int followerCount, int followingCount, bool isFollowing, bool isSelf, String? liveRoomId, ProfileLive? live, bool isMuted,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier, ProfileFamily? family, ProfileCp? cp, ProfileMedals medals, ProfileCard? profileCard, bool followRequested,@JsonKey(fromJson: genderFromJson, toJson: genderToJson) Gender? gender,@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) AccountCategory? category, bool categoryVerified,@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> links, List<String> tags, List<String> tagIcons,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? hostAgentCode,@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) VerificationBadge? verification,@JsonKey(includeIfNull: false) String? statusEmojiId,@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? avatarFrame,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge,@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) UserVip? vip, String? coverUrl, String? country, String? joinedMonth, bool blockedByMe,@JsonKey(includeIfNull: false) int? cherriesReceived,@JsonKey(includeIfNull: false) int? coinsSent, bool kabsoTeam,@JsonKey(fromJson: staffIdentityFromJson, toJson: staffIdentityToJson, includeIfNull: false) KabsoStaffIdentity? staff,@JsonKey(includeIfNull: false) String? staffId,@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) UserGoldenId? goldenId, bool kabsoOwner,@JsonKey(fromJson: ownerCoverVideoFromJson, toJson: ownerCoverVideoToJson, includeIfNull: false) OwnerCoverVideo? coverVideo,@JsonKey(fromJson: ownerBioFromJson, toJson: ownerBioToJson, includeIfNull: false) OwnerBio? ownerBio,@JsonKey(includeIfNull: false) int? founderFeedbackCount,@JsonKey(fromJson: animatedAvatarFromJson, toJson: animatedAvatarToJson, includeIfNull: false) AnimatedAvatar? animatedAvatar,@JsonKey(name: 'ambassador', fromJson: ambassadorLevelFromJson, toJson: ambassadorLevelToJson, includeIfNull: false) String? ambassadorLevel
});


@override $ProfileLiveCopyWith<$Res>? get live;@override $ProfileFamilyCopyWith<$Res>? get family;@override $ProfileCpCopyWith<$Res>? get cp;@override $ProfileMedalsCopyWith<$Res> get medals;@override $ProfileCardCopyWith<$Res>? get profileCard;

}
/// @nodoc
class __$PublicProfileCopyWithImpl<$Res>
    implements _$PublicProfileCopyWith<$Res> {
  __$PublicProfileCopyWithImpl(this._self, this._then);

  final _PublicProfile _self;
  final $Res Function(_PublicProfile) _then;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? isPrivate = null,Object? followerCount = null,Object? followingCount = null,Object? isFollowing = null,Object? isSelf = null,Object? liveRoomId = freezed,Object? live = freezed,Object? isMuted = null,Object? premiumTier = freezed,Object? family = freezed,Object? cp = freezed,Object? medals = null,Object? profileCard = freezed,Object? followRequested = null,Object? gender = freezed,Object? category = freezed,Object? categoryVerified = null,Object? links = null,Object? tags = null,Object? tagIcons = null,Object? rechargeAgentCode = freezed,Object? hostAgentCode = freezed,Object? verification = freezed,Object? statusEmojiId = freezed,Object? avatarFrame = freezed,Object? rechargeBadge = freezed,Object? vip = freezed,Object? coverUrl = freezed,Object? country = freezed,Object? joinedMonth = freezed,Object? blockedByMe = null,Object? cherriesReceived = freezed,Object? coinsSent = freezed,Object? kabsoTeam = null,Object? staff = freezed,Object? staffId = freezed,Object? goldenId = freezed,Object? kabsoOwner = null,Object? coverVideo = freezed,Object? ownerBio = freezed,Object? founderFeedbackCount = freezed,Object? animatedAvatar = freezed,Object? ambassadorLevel = freezed,}) {
  return _then(_PublicProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,isSelf: null == isSelf ? _self.isSelf : isSelf // ignore: cast_nullable_to_non_nullable
as bool,liveRoomId: freezed == liveRoomId ? _self.liveRoomId : liveRoomId // ignore: cast_nullable_to_non_nullable
as String?,live: freezed == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as ProfileLive?,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as ProfileFamily?,cp: freezed == cp ? _self.cp : cp // ignore: cast_nullable_to_non_nullable
as ProfileCp?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as ProfileMedals,profileCard: freezed == profileCard ? _self.profileCard : profileCard // ignore: cast_nullable_to_non_nullable
as ProfileCard?,followRequested: null == followRequested ? _self.followRequested : followRequested // ignore: cast_nullable_to_non_nullable
as bool,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as AccountCategory?,categoryVerified: null == categoryVerified ? _self.categoryVerified : categoryVerified // ignore: cast_nullable_to_non_nullable
as bool,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as List<ProfileLink>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,tagIcons: null == tagIcons ? _self._tagIcons : tagIcons // ignore: cast_nullable_to_non_nullable
as List<String>,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,hostAgentCode: freezed == hostAgentCode ? _self.hostAgentCode : hostAgentCode // ignore: cast_nullable_to_non_nullable
as String?,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as VerificationBadge?,statusEmojiId: freezed == statusEmojiId ? _self.statusEmojiId : statusEmojiId // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as AvatarFrame?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,vip: freezed == vip ? _self.vip : vip // ignore: cast_nullable_to_non_nullable
as UserVip?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,joinedMonth: freezed == joinedMonth ? _self.joinedMonth : joinedMonth // ignore: cast_nullable_to_non_nullable
as String?,blockedByMe: null == blockedByMe ? _self.blockedByMe : blockedByMe // ignore: cast_nullable_to_non_nullable
as bool,cherriesReceived: freezed == cherriesReceived ? _self.cherriesReceived : cherriesReceived // ignore: cast_nullable_to_non_nullable
as int?,coinsSent: freezed == coinsSent ? _self.coinsSent : coinsSent // ignore: cast_nullable_to_non_nullable
as int?,kabsoTeam: null == kabsoTeam ? _self.kabsoTeam : kabsoTeam // ignore: cast_nullable_to_non_nullable
as bool,staff: freezed == staff ? _self.staff : staff // ignore: cast_nullable_to_non_nullable
as KabsoStaffIdentity?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,goldenId: freezed == goldenId ? _self.goldenId : goldenId // ignore: cast_nullable_to_non_nullable
as UserGoldenId?,kabsoOwner: null == kabsoOwner ? _self.kabsoOwner : kabsoOwner // ignore: cast_nullable_to_non_nullable
as bool,coverVideo: freezed == coverVideo ? _self.coverVideo : coverVideo // ignore: cast_nullable_to_non_nullable
as OwnerCoverVideo?,ownerBio: freezed == ownerBio ? _self.ownerBio : ownerBio // ignore: cast_nullable_to_non_nullable
as OwnerBio?,founderFeedbackCount: freezed == founderFeedbackCount ? _self.founderFeedbackCount : founderFeedbackCount // ignore: cast_nullable_to_non_nullable
as int?,animatedAvatar: freezed == animatedAvatar ? _self.animatedAvatar : animatedAvatar // ignore: cast_nullable_to_non_nullable
as AnimatedAvatar?,ambassadorLevel: freezed == ambassadorLevel ? _self.ambassadorLevel : ambassadorLevel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileLiveCopyWith<$Res>? get live {
    if (_self.live == null) {
    return null;
  }

  return $ProfileLiveCopyWith<$Res>(_self.live!, (value) {
    return _then(_self.copyWith(live: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileFamilyCopyWith<$Res>? get family {
    if (_self.family == null) {
    return null;
  }

  return $ProfileFamilyCopyWith<$Res>(_self.family!, (value) {
    return _then(_self.copyWith(family: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCpCopyWith<$Res>? get cp {
    if (_self.cp == null) {
    return null;
  }

  return $ProfileCpCopyWith<$Res>(_self.cp!, (value) {
    return _then(_self.copyWith(cp: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileMedalsCopyWith<$Res> get medals {
  
  return $ProfileMedalsCopyWith<$Res>(_self.medals, (value) {
    return _then(_self.copyWith(medals: value));
  });
}/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileCardCopyWith<$Res>? get profileCard {
    if (_self.profileCard == null) {
    return null;
  }

  return $ProfileCardCopyWith<$Res>(_self.profileCard!, (value) {
    return _then(_self.copyWith(profileCard: value));
  });
}
}


/// @nodoc
mixin _$ProfileLive {

 String get roomId; DateTime get startedAt; String get title;@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode get mode; int get viewerCount; int get score;
/// Create a copy of ProfileLive
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileLiveCopyWith<ProfileLive> get copyWith => _$ProfileLiveCopyWithImpl<ProfileLive>(this as ProfileLive, _$identity);

  /// Serializes this ProfileLive to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileLive;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileLive&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.viewerCount, _this.viewerCount) || other.viewerCount == _this.viewerCount)&&(identical(other.score, _this.score) || other.score == _this.score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileLive;
  return Object.hash(runtimeType,_this.roomId,_this.startedAt,_this.title,_this.mode,_this.viewerCount,_this.score);
}

@override
String toString() {
  final _this = this as ProfileLive;
  return 'ProfileLive(roomId: ${_this.roomId}, startedAt: ${_this.startedAt}, title: ${_this.title}, mode: ${_this.mode}, viewerCount: ${_this.viewerCount}, score: ${_this.score})';
}


}

/// @nodoc
abstract mixin class $ProfileLiveCopyWith<$Res>  {
  factory $ProfileLiveCopyWith(ProfileLive value, $Res Function(ProfileLive) _then) = _$ProfileLiveCopyWithImpl;
@useResult
$Res call({
 String roomId, DateTime startedAt, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, int score
});




}
/// @nodoc
class _$ProfileLiveCopyWithImpl<$Res>
    implements $ProfileLiveCopyWith<$Res> {
  _$ProfileLiveCopyWithImpl(this._self, this._then);

  final ProfileLive _self;
  final $Res Function(ProfileLive) _then;

/// Create a copy of ProfileLive
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = null,Object? startedAt = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? score = null,}) {
  return _then(ProfileLive(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileLive].
extension ProfileLivePatterns on ProfileLive {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileLive value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileLive() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileLive value)  $default,){
final _that = this;
switch (_that) {
case _ProfileLive():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileLive value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileLive() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roomId,  DateTime startedAt,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  int score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileLive() when $default != null:
return $default(_that.roomId,_that.startedAt,_that.title,_that.mode,_that.viewerCount,_that.score);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roomId,  DateTime startedAt,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  int score)  $default,) {final _that = this;
switch (_that) {
case _ProfileLive():
return $default(_that.roomId,_that.startedAt,_that.title,_that.mode,_that.viewerCount,_that.score);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roomId,  DateTime startedAt,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  int score)?  $default,) {final _that = this;
switch (_that) {
case _ProfileLive() when $default != null:
return $default(_that.roomId,_that.startedAt,_that.title,_that.mode,_that.viewerCount,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileLive implements ProfileLive {
  const _ProfileLive({required this.roomId, required this.startedAt, this.title = '', @JsonKey(unknownEnumValue: LiveRoomMode.solo) this.mode = LiveRoomMode.solo, this.viewerCount = 0, this.score = 0});
  factory _ProfileLive.fromJson(Map<String, dynamic> json) => _$ProfileLiveFromJson(json);

@override final  String roomId;
@override final  DateTime startedAt;
@override@JsonKey() final  String title;
@override@JsonKey(unknownEnumValue: LiveRoomMode.solo) final  LiveRoomMode mode;
@override@JsonKey() final  int viewerCount;
@override@JsonKey() final  int score;

/// Create a copy of ProfileLive
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileLiveCopyWith<_ProfileLive> get copyWith => __$ProfileLiveCopyWithImpl<_ProfileLive>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileLiveToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileLive&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.title, title) || other.title == title)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,roomId,startedAt,title,mode,viewerCount,score);
}

@override
String toString() {
    return 'ProfileLive(roomId: $roomId, startedAt: $startedAt, title: $title, mode: $mode, viewerCount: $viewerCount, score: $score)';
}


}

/// @nodoc
abstract mixin class _$ProfileLiveCopyWith<$Res> implements $ProfileLiveCopyWith<$Res> {
  factory _$ProfileLiveCopyWith(_ProfileLive value, $Res Function(_ProfileLive) _then) = __$ProfileLiveCopyWithImpl;
@override @useResult
$Res call({
 String roomId, DateTime startedAt, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, int score
});




}
/// @nodoc
class __$ProfileLiveCopyWithImpl<$Res>
    implements _$ProfileLiveCopyWith<$Res> {
  __$ProfileLiveCopyWithImpl(this._self, this._then);

  final _ProfileLive _self;
  final $Res Function(_ProfileLive) _then;

/// Create a copy of ProfileLive
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = null,Object? startedAt = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? score = null,}) {
  return _then(_ProfileLive(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FollowState {

 bool get isFollowing; int get followerCount;/// v1.47-social (D175): a follow request is pending (private account).
 bool get isRequested;
/// Create a copy of FollowState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowStateCopyWith<FollowState> get copyWith => _$FollowStateCopyWithImpl<FollowState>(this as FollowState, _$identity);

  /// Serializes this FollowState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FollowState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowState&&(identical(other.isFollowing, _this.isFollowing) || other.isFollowing == _this.isFollowing)&&(identical(other.followerCount, _this.followerCount) || other.followerCount == _this.followerCount)&&(identical(other.isRequested, _this.isRequested) || other.isRequested == _this.isRequested));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FollowState;
  return Object.hash(runtimeType,_this.isFollowing,_this.followerCount,_this.isRequested);
}

@override
String toString() {
  final _this = this as FollowState;
  return 'FollowState(isFollowing: ${_this.isFollowing}, followerCount: ${_this.followerCount}, isRequested: ${_this.isRequested})';
}


}

/// @nodoc
abstract mixin class $FollowStateCopyWith<$Res>  {
  factory $FollowStateCopyWith(FollowState value, $Res Function(FollowState) _then) = _$FollowStateCopyWithImpl;
@useResult
$Res call({
 bool isFollowing, int followerCount, bool isRequested
});




}
/// @nodoc
class _$FollowStateCopyWithImpl<$Res>
    implements $FollowStateCopyWith<$Res> {
  _$FollowStateCopyWithImpl(this._self, this._then);

  final FollowState _self;
  final $Res Function(FollowState) _then;

/// Create a copy of FollowState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isFollowing = null,Object? followerCount = null,Object? isRequested = null,}) {
  return _then(FollowState(
isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,isRequested: null == isRequested ? _self.isRequested : isRequested // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowState].
extension FollowStatePatterns on FollowState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowState value)  $default,){
final _that = this;
switch (_that) {
case _FollowState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowState value)?  $default,){
final _that = this;
switch (_that) {
case _FollowState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isFollowing,  int followerCount,  bool isRequested)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowState() when $default != null:
return $default(_that.isFollowing,_that.followerCount,_that.isRequested);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isFollowing,  int followerCount,  bool isRequested)  $default,) {final _that = this;
switch (_that) {
case _FollowState():
return $default(_that.isFollowing,_that.followerCount,_that.isRequested);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isFollowing,  int followerCount,  bool isRequested)?  $default,) {final _that = this;
switch (_that) {
case _FollowState() when $default != null:
return $default(_that.isFollowing,_that.followerCount,_that.isRequested);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FollowState implements FollowState {
  const _FollowState({required this.isFollowing, required this.followerCount, this.isRequested = false});
  factory _FollowState.fromJson(Map<String, dynamic> json) => _$FollowStateFromJson(json);

@override final  bool isFollowing;
@override final  int followerCount;
/// v1.47-social (D175): a follow request is pending (private account).
@override@JsonKey() final  bool isRequested;

/// Create a copy of FollowState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowStateCopyWith<_FollowState> get copyWith => __$FollowStateCopyWithImpl<_FollowState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FollowStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowState&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.isRequested, isRequested) || other.isRequested == isRequested));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isFollowing,followerCount,isRequested);
}

@override
String toString() {
    return 'FollowState(isFollowing: $isFollowing, followerCount: $followerCount, isRequested: $isRequested)';
}


}

/// @nodoc
abstract mixin class _$FollowStateCopyWith<$Res> implements $FollowStateCopyWith<$Res> {
  factory _$FollowStateCopyWith(_FollowState value, $Res Function(_FollowState) _then) = __$FollowStateCopyWithImpl;
@override @useResult
$Res call({
 bool isFollowing, int followerCount, bool isRequested
});




}
/// @nodoc
class __$FollowStateCopyWithImpl<$Res>
    implements _$FollowStateCopyWith<$Res> {
  __$FollowStateCopyWithImpl(this._self, this._then);

  final _FollowState _self;
  final $Res Function(_FollowState) _then;

/// Create a copy of FollowState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isFollowing = null,Object? followerCount = null,Object? isRequested = null,}) {
  return _then(_FollowState(
isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,isRequested: null == isRequested ? _self.isRequested : isRequested // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
