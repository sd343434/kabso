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
 bool get isMuted;/// v1.21-live (CP-018): the user's family and role, or null.
 ProfileFamily? get family;/// v1.21-live (CP-018): the user's couple, or null.
 ProfileCp? get cp;/// v1.21-live (CP-018): medals owned, the newest and the chosen
/// showcase (empty for previews built without it).
 ProfileMedals get medals;/// v1.22-live (CP-019): the profile card the user wears, or null.
 ProfileCard? get profileCard;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfile&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.bio, _this.bio) || other.bio == _this.bio)&&(identical(other.isPrivate, _this.isPrivate) || other.isPrivate == _this.isPrivate)&&(identical(other.followerCount, _this.followerCount) || other.followerCount == _this.followerCount)&&(identical(other.followingCount, _this.followingCount) || other.followingCount == _this.followingCount)&&(identical(other.isFollowing, _this.isFollowing) || other.isFollowing == _this.isFollowing)&&(identical(other.isSelf, _this.isSelf) || other.isSelf == _this.isSelf)&&(identical(other.liveRoomId, _this.liveRoomId) || other.liveRoomId == _this.liveRoomId)&&(identical(other.isMuted, _this.isMuted) || other.isMuted == _this.isMuted)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.cp, _this.cp) || other.cp == _this.cp)&&(identical(other.medals, _this.medals) || other.medals == _this.medals)&&(identical(other.profileCard, _this.profileCard) || other.profileCard == _this.profileCard));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublicProfile;
  return Object.hash(runtimeType,_this.id,_this.username,_this.displayName,_this.avatarUrl,_this.bio,_this.isPrivate,_this.followerCount,_this.followingCount,_this.isFollowing,_this.isSelf,_this.liveRoomId,_this.isMuted,_this.family,_this.cp,_this.medals,_this.profileCard);
}

@override
String toString() {
  final _this = this as PublicProfile;
  return 'PublicProfile(id: ${_this.id}, username: ${_this.username}, displayName: ${_this.displayName}, avatarUrl: ${_this.avatarUrl}, bio: ${_this.bio}, isPrivate: ${_this.isPrivate}, followerCount: ${_this.followerCount}, followingCount: ${_this.followingCount}, isFollowing: ${_this.isFollowing}, isSelf: ${_this.isSelf}, liveRoomId: ${_this.liveRoomId}, isMuted: ${_this.isMuted}, family: ${_this.family}, cp: ${_this.cp}, medals: ${_this.medals}, profileCard: ${_this.profileCard})';
}


}

/// @nodoc
abstract mixin class $PublicProfileCopyWith<$Res>  {
  factory $PublicProfileCopyWith(PublicProfile value, $Res Function(PublicProfile) _then) = _$PublicProfileCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl, String? bio, bool isPrivate, int followerCount, int followingCount, bool isFollowing, bool isSelf, String? liveRoomId, bool isMuted, ProfileFamily? family, ProfileCp? cp, ProfileMedals medals, ProfileCard? profileCard
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? isPrivate = null,Object? followerCount = null,Object? followingCount = null,Object? isFollowing = null,Object? isSelf = null,Object? liveRoomId = freezed,Object? isMuted = null,Object? family = freezed,Object? cp = freezed,Object? medals = null,Object? profileCard = freezed,}) {
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
as bool,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as ProfileFamily?,cp: freezed == cp ? _self.cp : cp // ignore: cast_nullable_to_non_nullable
as ProfileCp?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as ProfileMedals,profileCard: freezed == profileCard ? _self.profileCard : profileCard // ignore: cast_nullable_to_non_nullable
as ProfileCard?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  bool isMuted,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.isMuted,_that.family,_that.cp,_that.medals,_that.profileCard);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  bool isMuted,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard)  $default,) {final _that = this;
switch (_that) {
case _PublicProfile():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.isMuted,_that.family,_that.cp,_that.medals,_that.profileCard);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayName,  String? avatarUrl,  String? bio,  bool isPrivate,  int followerCount,  int followingCount,  bool isFollowing,  bool isSelf,  String? liveRoomId,  bool isMuted,  ProfileFamily? family,  ProfileCp? cp,  ProfileMedals medals,  ProfileCard? profileCard)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfile() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.bio,_that.isPrivate,_that.followerCount,_that.followingCount,_that.isFollowing,_that.isSelf,_that.liveRoomId,_that.isMuted,_that.family,_that.cp,_that.medals,_that.profileCard);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicProfile extends PublicProfile {
  const _PublicProfile({required this.id, required this.username, required this.displayName, required this.avatarUrl, required this.bio, required this.isPrivate, required this.followerCount, required this.followingCount, required this.isFollowing, required this.isSelf, required this.liveRoomId, this.isMuted = false, this.family, this.cp, this.medals = const ProfileMedals(), this.profileCard}): super._();
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
/// v1.21-live (CP-018): the user's family and role, or null.
@override final  ProfileFamily? family;
/// v1.21-live (CP-018): the user's couple, or null.
@override final  ProfileCp? cp;
/// v1.21-live (CP-018): medals owned, the newest and the chosen
/// showcase (empty for previews built without it).
@override@JsonKey() final  ProfileMedals medals;
/// v1.22-live (CP-019): the profile card the user wears, or null.
@override final  ProfileCard? profileCard;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.isSelf, isSelf) || other.isSelf == isSelf)&&(identical(other.liveRoomId, liveRoomId) || other.liveRoomId == liveRoomId)&&(identical(other.isMuted, isMuted) || other.isMuted == isMuted)&&(identical(other.family, family) || other.family == family)&&(identical(other.cp, cp) || other.cp == cp)&&(identical(other.medals, medals) || other.medals == medals)&&(identical(other.profileCard, profileCard) || other.profileCard == profileCard));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,username,displayName,avatarUrl,bio,isPrivate,followerCount,followingCount,isFollowing,isSelf,liveRoomId,isMuted,family,cp,medals,profileCard);
}

@override
String toString() {
    return 'PublicProfile(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, bio: $bio, isPrivate: $isPrivate, followerCount: $followerCount, followingCount: $followingCount, isFollowing: $isFollowing, isSelf: $isSelf, liveRoomId: $liveRoomId, isMuted: $isMuted, family: $family, cp: $cp, medals: $medals, profileCard: $profileCard)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileCopyWith<$Res> implements $PublicProfileCopyWith<$Res> {
  factory _$PublicProfileCopyWith(_PublicProfile value, $Res Function(_PublicProfile) _then) = __$PublicProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl, String? bio, bool isPrivate, int followerCount, int followingCount, bool isFollowing, bool isSelf, String? liveRoomId, bool isMuted, ProfileFamily? family, ProfileCp? cp, ProfileMedals medals, ProfileCard? profileCard
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? bio = freezed,Object? isPrivate = null,Object? followerCount = null,Object? followingCount = null,Object? isFollowing = null,Object? isSelf = null,Object? liveRoomId = freezed,Object? isMuted = null,Object? family = freezed,Object? cp = freezed,Object? medals = null,Object? profileCard = freezed,}) {
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
as bool,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as ProfileFamily?,cp: freezed == cp ? _self.cp : cp // ignore: cast_nullable_to_non_nullable
as ProfileCp?,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as ProfileMedals,profileCard: freezed == profileCard ? _self.profileCard : profileCard // ignore: cast_nullable_to_non_nullable
as ProfileCard?,
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

 bool get isFollowing; int get followerCount;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowState&&(identical(other.isFollowing, _this.isFollowing) || other.isFollowing == _this.isFollowing)&&(identical(other.followerCount, _this.followerCount) || other.followerCount == _this.followerCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FollowState;
  return Object.hash(runtimeType,_this.isFollowing,_this.followerCount);
}

@override
String toString() {
  final _this = this as FollowState;
  return 'FollowState(isFollowing: ${_this.isFollowing}, followerCount: ${_this.followerCount})';
}


}

/// @nodoc
abstract mixin class $FollowStateCopyWith<$Res>  {
  factory $FollowStateCopyWith(FollowState value, $Res Function(FollowState) _then) = _$FollowStateCopyWithImpl;
@useResult
$Res call({
 bool isFollowing, int followerCount
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
@pragma('vm:prefer-inline') @override $Res call({Object? isFollowing = null,Object? followerCount = null,}) {
  return _then(FollowState(
isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isFollowing,  int followerCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowState() when $default != null:
return $default(_that.isFollowing,_that.followerCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isFollowing,  int followerCount)  $default,) {final _that = this;
switch (_that) {
case _FollowState():
return $default(_that.isFollowing,_that.followerCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isFollowing,  int followerCount)?  $default,) {final _that = this;
switch (_that) {
case _FollowState() when $default != null:
return $default(_that.isFollowing,_that.followerCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FollowState implements FollowState {
  const _FollowState({required this.isFollowing, required this.followerCount});
  factory _FollowState.fromJson(Map<String, dynamic> json) => _$FollowStateFromJson(json);

@override final  bool isFollowing;
@override final  int followerCount;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowState&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isFollowing,followerCount);
}

@override
String toString() {
    return 'FollowState(isFollowing: $isFollowing, followerCount: $followerCount)';
}


}

/// @nodoc
abstract mixin class _$FollowStateCopyWith<$Res> implements $FollowStateCopyWith<$Res> {
  factory _$FollowStateCopyWith(_FollowState value, $Res Function(_FollowState) _then) = __$FollowStateCopyWithImpl;
@override @useResult
$Res call({
 bool isFollowing, int followerCount
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
@override @pragma('vm:prefer-inline') $Res call({Object? isFollowing = null,Object? followerCount = null,}) {
  return _then(_FollowState(
isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
