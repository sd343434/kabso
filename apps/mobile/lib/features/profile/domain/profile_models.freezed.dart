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

 String get id; String get username; String get displayName; String? get avatarUrl; String? get bio; bool get isPrivate; int get followerCount; int get followingCount; bool get isFollowing; bool get isSelf; String? get liveRoomId;/// CP-007: the caller muted this user (never shown to them). Defaults
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
@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) AccountCategory? get category;/// v1.47-social (D175): the profile links (also on a private profile).
@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> get links;/// v1.54-social (D185, §10.48): the user's code while they are an
/// ACTIVE recharge agent — the agent frame (with the code in its
/// plate) and the badge. Null otherwise (also on older servers).
@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get rechargeAgentCode;/// v1.58-social (D189, §10.52): the user's code while they are a host
/// agent (agency not suspended) — the host-agent frame (no name) and
/// badge. Null otherwise (also on older servers).
@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get hostAgentCode;/// v1.55-social (D186, §10.49): the avatar frame the user wears (e.g.
/// the active-host frame), drawn around the profile photo. Null when
/// none (also on older servers).
@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? get avatarFrame;/// v1.56-social (D187, §10.50): the daily recharge badge while it shows;
/// beside the name on the profile like the level badge. Null otherwise.
@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? get rechargeBadge;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfile&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.bio, _this.bio) || other.bio == _this.bio)&&(identical(other.isPrivate, _this.isPrivate) || other.isPrivate == _this.isPrivate)&&(identical(other.followerCount, _this.followerCount) || other.followerCount == _this.followerCount)&&(identical(other.followingCount, _this.followingCount) || other.followingCount == _this.followingCount)&&(identical(other.isFollowing, _this.isFollowing) || other.isFollowing == _this.isFollowing)&&(identical(other.isSelf, _this.isSelf) || other.isSelf == _this.isSelf)&&(identical(other.liveRoomId, _this.liveRoomId) || other.liveRoomId == _this.liveRoomId)&&(identical(other.isMuted, _this.isMuted) || other.isMuted == _this.isMuted)&&(identical(other.premiumTier, _this.premiumTier) || other.premiumTier == _this.premiumTier)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.cp, _this.cp) || other.cp == _this.cp)&&(identical(other.medals, _this.medals) || other.medals == _this.medals)&&(identical(other.profileCard, _this.profileCard) || other.profileCard == _this.profileCard)&&(identical(other.followRequested, _this.followRequested) || other.followRequested == _this.followRequested)&&(identical(other.gender, _this.gender) || other.gender == _this.gender)&&(identical(other.category, _this.category) || other.category == _this.category)&&const DeepCollectionEquality().equals(other.links, _this.links)&&(identical(other.rechargeAgentCode, _this.rechargeAgentCode) || other.rechargeAgentCode == _this.rechargeAgentCode)&&(identical(other.hostAgentCode, _this.hostAgentCode) || other.hostAgentCode == _this.hostAgentCode)&&(identical(other.avatarFrame, _this.avatarFrame) || other.avatarFrame == _this.avatarFrame)&&(identical(other.rechargeBadge, _this.rechargeBadge) || other.rechargeBadge == _this.rechargeBadge));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublicProfile;
  return Object.hashAll([runtimeType,_this.id,_this.username,_this.displayName,_this.avatarUrl,_this.bio,_this.isPrivate,_this.followerCount,_this.followingCount,_this.isFollowing,_this.isSelf,_this.liveRoomId,_this.isMuted,_this.premiumTier,_this.family,_this.cp,_this.medals,_this.profileCard,_this.followRequested,_this.gender,_this.category,const DeepCollectionEquality().hash(_this.links),_this.rechargeAgentCode,_this.hostAgentCode,_this.avatarFrame,_this.rechargeBadge]);
}

@override
String toString() {
  final _this = this as PublicProfile;
  return 'PublicProfile(id: ${_this.id}, username: ${_this.username}, displayName: ${_this.displayName}, avatarUrl: ${_this.avatarUrl}, bio: ${_this.bio}, isPrivate: ${_this.isPrivate}, followerCount: ${_this.followerCount}, followingCount: ${_this.followingCount}, isFollowing: ${_this.isFollowing}, isSelf: ${_this.isSelf}, liveRoomId: ${_this.liveRoomId}, isMuted: ${_this.isMuted}, premiumTier: ${_this.premiumTier}, family: ${_this.family}, cp: ${_this.cp}, medals: ${_this.medals}, profileCard: ${_this.profileCard}, followRequested: ${_this.followRequested}, gender: ${_this.gender}, category: ${_this.category}, links: ${_this.links}, rechargeAgentCode: ${_this.rechargeAgentCode}, hostAgentCode: ${_this.hostAgentCode}, avatarFrame: ${_this.avatarFrame}, rechargeBadge: ${_this.rechargeBadge})';
}


}

/// @nodoc
abstract mixin class $PublicProfileCopyWith<$Res>  {
  factory $PublicProfileCopyWith(PublicProfile value, $Res Function(PublicProfile) _then) = _$PublicProfileCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl, String? bio, bool isPrivate, int followerCount, int followingCount, bool isFollowing, bool isSelf, String? liveRoomId, bool isMuted,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier, ProfileFamily? family, ProfileCp? cp, ProfileMedals medals, ProfileCard? profileCard, bool followRequested,@JsonKey(fromJson: genderFromJson, toJson: genderToJson) Gender? gender,@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) AccountCategory? category,@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> links,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? hostAgentCode,@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? avatarFrame,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge
});


$ProfileFamilyCopyWith<$Res>? get family;$ProfileCpCopyWith<$Res>? get cp;$ProfileMedalsCopyWith<$Res> get medals;$ProfileCardCopyWith<$Res>? get profileCard;

}
/// @nodoc
class _$PublicProfileCopyWithImpl<$Res>
    implements $PublicProfileCopyWith<$Res> {
  _$PublicProfileCopyWithImpl(this._self, this._then);

  final PublicProfile _self;
  final $Res Function(PublicProfile) _then;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? isPrivate = null,Object? followerCount = null,Object? followingCount = null,Object? isFollowing = null,Object? isSelf = null,Object? liveRoomId = freezed,Object? isMuted = null,Object? premiumTier = freezed,Object? family = freezed,Object? cp = freezed,Object? medals = null,Object? profileCard = freezed,Object? followRequested = null,Object? gender = freezed,Object? category = freezed,Object? links = null,Object? rechargeAgentCode = freezed,Object? hostAgentCode = freezed,Object? avatarFrame = freezed,Object? rechargeBadge = freezed,}) {
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
as String?,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as ProfileFamily?,cp: freezed == cp ? _self.cp : cp // ignore: cast_nullable_to_non_nullable
as ProfileCp?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as ProfileMedals,profileCard: freezed == profileCard ? _self.profileCard : profileCard // ignore: cast_nullable_to_non_nullable
as ProfileCard?,followRequested: null == followRequested ? _self.followRequested : followRequested // ignore: cast_nullable_to_non_nullable
as bool,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as AccountCategory?,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as List<ProfileLink>,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,hostAgentCode: freezed == hostAgentCode ? _self.hostAgentCode : hostAgentCode // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as AvatarFrame?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,
  ));
}
/// Create a copy of PublicProfile
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  bool isMuted, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard,  bool followRequested, @JsonKey(fromJson: genderFromJson, toJson: genderToJson)  Gender? gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)  AccountCategory? category, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.isMuted,_that.premiumTier,_that.family,_that.cp,_that.medals,_that.profileCard,_that.followRequested,_that.gender,_that.category,_that.links,_that.rechargeAgentCode,_that.hostAgentCode,_that.avatarFrame,_that.rechargeBadge);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  bool isMuted, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard,  bool followRequested, @JsonKey(fromJson: genderFromJson, toJson: genderToJson)  Gender? gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)  AccountCategory? category, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge)  $default,) {final _that = this;
switch (_that) {
case _PublicProfile():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.isMuted,_that.premiumTier,_that.family,_that.cp,_that.medals,_that.profileCard,_that.followRequested,_that.gender,_that.category,_that.links,_that.rechargeAgentCode,_that.hostAgentCode,_that.avatarFrame,_that.rechargeBadge);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  bool isMuted, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard,  bool followRequested, @JsonKey(fromJson: genderFromJson, toJson: genderToJson)  Gender? gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson)  AccountCategory? category, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.isMuted,_that.premiumTier,_that.family,_that.cp,_that.medals,_that.profileCard,_that.followRequested,_that.gender,_that.category,_that.links,_that.rechargeAgentCode,_that.hostAgentCode,_that.avatarFrame,_that.rechargeBadge);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicProfile extends PublicProfile {
  const _PublicProfile({required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.bio, required this.isPrivate, required this.followerCount, required this.followingCount, required this.isFollowing, required this.isSelf, required this.liveRoomId, this.isMuted = false, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) this.premiumTier, this.family, this.cp, this.medals = const ProfileMedals(), this.profileCard, this.followRequested = false, @JsonKey(fromJson: genderFromJson, toJson: genderToJson) this.gender, @JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) this.category, @JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson)  List<ProfileLink> links = const <ProfileLink>[], @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) this.avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) this.rechargeBadge}): _links = links,super._();
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
/// v1.47-social (D175): the profile links (also on a private profile).
 final  List<ProfileLink> _links;
/// v1.47-social (D175): the profile links (also on a private profile).
@override@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> get links {
  if (_links is EqualUnmodifiableListView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_links);
}

/// v1.54-social (D185, §10.48): the user's code while they are an
/// ACTIVE recharge agent — the agent frame (with the code in its
/// plate) and the badge. Null otherwise (also on older servers).
@override@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) final  String? rechargeAgentCode;
/// v1.58-social (D189, §10.52): the user's code while they are a host
/// agent (agency not suspended) — the host-agent frame (no name) and
/// badge. Null otherwise (also on older servers).
@override@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) final  String? hostAgentCode;
/// v1.55-social (D186, §10.49): the avatar frame the user wears (e.g.
/// the active-host frame), drawn around the profile photo. Null when
/// none (also on older servers).
@override@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) final  AvatarFrame? avatarFrame;
/// v1.56-social (D187, §10.50): the daily recharge badge while it shows;
/// beside the name on the profile like the level badge. Null otherwise.
@override@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) final  RechargeBadge? rechargeBadge;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isSelf, isSelf) || other.isSelf == isSelf)&&(identical(other.liveRoomId, liveRoomId) || other.liveRoomId == liveRoomId)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.premiumTier, premiumTier) || other.premiumTier == premiumTier)&&(identical(other.family, family) || other.family == family)&&(identical(other.cp, cp) || other.cp == cp)&&(identical(other.medals, medals) || other.medals == medals)&&(identical(other.profileCard, profileCard) || other.profileCard == profileCard)&&(identical(other.followRequested, followRequested) || other.followRequested == followRequested)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.category, category) || other.category == category)&&const DeepCollectionEquality().equals(other.links, _links)&&(identical(other.rechargeAgentCode, rechargeAgentCode) || other.rechargeAgentCode == rechargeAgentCode)&&(identical(other.hostAgentCode, hostAgentCode) || other.hostAgentCode == hostAgentCode)&&(identical(other.avatarFrame, avatarFrame) || other.avatarFrame == avatarFrame)&&(identical(other.rechargeBadge, rechargeBadge) || other.rechargeBadge == rechargeBadge));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,username,displayName,avatarUrl,bio,isPrivate,followerCount,followingCount,isFollowing,isSelf,liveRoomId,isMuted,premiumTier,family,cp,medals,profileCard,followRequested,gender,category,const DeepCollectionEquality().hash(_links),rechargeAgentCode,hostAgentCode,avatarFrame,rechargeBadge]);
}

@override
String toString() {
    return 'PublicProfile(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, isPrivate: $isPrivate, followerCount: $followerCount, followingCount: $followingCount, isFollowing: $isFollowing, isSelf: $isSelf, liveRoomId: $liveRoomId, isMuted: $isMuted, premiumTier: $premiumTier, family: $family, cp: $cp, medals: $medals, profileCard: $profileCard, followRequested: $followRequested, gender: $gender, category: $category, links: $links, rechargeAgentCode: $rechargeAgentCode, hostAgentCode: $hostAgentCode, avatarFrame: $avatarFrame, rechargeBadge: $rechargeBadge)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileCopyWith<$Res> implements $PublicProfileCopyWith<$Res> {
  factory _$PublicProfileCopyWith(_PublicProfile value, $Res Function(_PublicProfile) _then) = __$PublicProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl, String? bio, bool isPrivate, int followerCount, int followingCount, bool isFollowing, bool isSelf, String? liveRoomId, bool isMuted,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier, ProfileFamily? family, ProfileCp? cp, ProfileMedals medals, ProfileCard? profileCard, bool followRequested,@JsonKey(fromJson: genderFromJson, toJson: genderToJson) Gender? gender,@JsonKey(fromJson: accountCategoryFromJson, toJson: accountCategoryToJson) AccountCategory? category,@JsonKey(fromJson: profileLinksFromJson, toJson: profileLinksToJson) List<ProfileLink> links,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? hostAgentCode,@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? avatarFrame,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge
});


@override $ProfileFamilyCopyWith<$Res>? get family;@override $ProfileCpCopyWith<$Res>? get cp;@override $ProfileMedalsCopyWith<$Res> get medals;@override $ProfileCardCopyWith<$Res>? get profileCard;

}
/// @nodoc
class __$PublicProfileCopyWithImpl<$Res>
    implements _$PublicProfileCopyWith<$Res> {
  __$PublicProfileCopyWithImpl(this._self, this._then);

  final _PublicProfile _self;
  final $Res Function(_PublicProfile) _then;

/// Create a copy of PublicProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? isPrivate = null,Object? followerCount = null,Object? followingCount = null,Object? isFollowing = null,Object? isSelf = null,Object? liveRoomId = freezed,Object? isMuted = null,Object? premiumTier = freezed,Object? family = freezed,Object? cp = freezed,Object? medals = null,Object? profileCard = freezed,Object? followRequested = null,Object? gender = freezed,Object? category = freezed,Object? links = null,Object? rechargeAgentCode = freezed,Object? hostAgentCode = freezed,Object? avatarFrame = freezed,Object? rechargeBadge = freezed,}) {
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
as String?,isMuted: null == isMuted ? _self.isMuted : isMuted // ignore: cast_nullable_to_non_nullable
as bool,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as ProfileFamily?,cp: freezed == cp ? _self.cp : cp // ignore: cast_nullable_to_non_nullable
as ProfileCp?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as ProfileMedals,profileCard: freezed == profileCard ? _self.profileCard : profileCard // ignore: cast_nullable_to_non_nullable
as ProfileCard?,followRequested: null == followRequested ? _self.followRequested : followRequested // ignore: cast_nullable_to_non_nullable
as bool,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as AccountCategory?,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as List<ProfileLink>,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,hostAgentCode: freezed == hostAgentCode ? _self.hostAgentCode : hostAgentCode // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as AvatarFrame?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,
  ));
}

/// Create a copy of PublicProfile
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
