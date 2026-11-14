// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$User {

 String get id; String get email; bool get emailVerified; String get username; String get displayName; String get locale; UserRole get role; bool get isPrivate; DateTime get createdAt; String? get bio; String? get avatarUrl;/// CP-010: holds the hosting permission (may go live).
 bool get canHost;/// CP-015: the host's live cover, reused by every live; null → the
/// avatar is shown.
 String? get liveCoverUrl;/// v1.27.1-live (D133): the person's own country (ISO 3166-1 alpha-2,
/// upper case), or null. It decides the live hub's Nearby.
 String? get country;/// v1.28-live (D146): the tier of the person's premium username, or
/// null for a regular one.
 PremiumTier? get premiumTier;/// v1.47-social (D175): the person's gender (null until chosen) and
/// whether others see it (private by default).
 Gender? get gender; bool get showGender;/// v1.47-social (D175): the account category shown under the name.
 AccountCategory? get category;/// v1.138-social (D386, §10.175): the Kabso Team verified [category]
/// (the profile's own look) / locked it (Edit profile shows it
/// read-only).
 bool get categoryVerified; bool get categoryLocked;/// v1.47-social (D175): up to 3 profile links, in order.
 List<ProfileLink> get links;/// v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10).
 List<String> get tags;/// v1.91-social (D292, §10.106): the icon of each tag (`ProfileTagIcon`
/// keys, one per tag; empty from an older server — read as `default`).
 List<String> get tagIcons;/// v1.54-social (D185, §10.48.1): the active special username (the
/// shown [username] while set) and the person's own base username.
 SpecialUsername? get specialUsername;/// v1.76-social (D218, §10.73.3): the profile cover, or null.
 String? get coverUrl;/// v1.68-live (D273, §10.96.6): «فريق كابسو» (OWNER, MODERATION or
/// SUPPORT) — the Me tab's staff entry and the staff tools in lives.
 bool get kabsoTeam;/// v1.72-live (D283, §10.96.10): a limited Kabso Team account
/// (MODERATION / SUPPORT / FINANCE, not OWNER) — the staff-only Me tab,
/// no go-live, levels, VIP, family, store, wallet or bag. Null otherwise.
 KabsoStaffIdentity? get staff;/// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
/// a panel role is held (the OWNER too) — the Me tab shows it instead of
/// the @username. Null otherwise.
 String? get staffId;/// v1.90-social (D293, §10.105): the automatic verification badge
/// «شارة التوثيق» beside the name, or null.
 VerificationBadge? get verification;/// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
/// the picture (`<pack>.<emoji>`), or null.
 String? get statusEmojiId;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as User;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.emailVerified, _this.emailVerified) || other.emailVerified == _this.emailVerified)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.locale, _this.locale) || other.locale == _this.locale)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.isPrivate, _this.isPrivate) || other.isPrivate == _this.isPrivate)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.bio, _this.bio) || other.bio == _this.bio)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.canHost, _this.canHost) || other.canHost == _this.canHost)&&(identical(other.liveCoverUrl, _this.liveCoverUrl) || other.liveCoverUrl == _this.liveCoverUrl)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.premiumTier, _this.premiumTier) || other.premiumTier == _this.premiumTier)&&(identical(other.gender, _this.gender) || other.gender == _this.gender)&&(identical(other.showGender, _this.showGender) || other.showGender == _this.showGender)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.categoryVerified, _this.categoryVerified) || other.categoryVerified == _this.categoryVerified)&&(identical(other.categoryLocked, _this.categoryLocked) || other.categoryLocked == _this.categoryLocked)&&const DeepCollectionEquality().equals(other.links, _this.links)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&const DeepCollectionEquality().equals(other.tagIcons, _this.tagIcons)&&(identical(other.specialUsername, _this.specialUsername) || other.specialUsername == _this.specialUsername)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.kabsoTeam, _this.kabsoTeam) || other.kabsoTeam == _this.kabsoTeam)&&(identical(other.staff, _this.staff) || other.staff == _this.staff)&&(identical(other.staffId, _this.staffId) || other.staffId == _this.staffId)&&(identical(other.verification, _this.verification) || other.verification == _this.verification)&&(identical(other.statusEmojiId, _this.statusEmojiId) || other.statusEmojiId == _this.statusEmojiId));
}


@override
int get hashCode {
  final _this = this as User;
  return Object.hashAll([runtimeType,_this.id,_this.email,_this.emailVerified,_this.username,_this.displayName,_this.locale,_this.role,_this.isPrivate,_this.createdAt,_this.bio,_this.avatarUrl,_this.canHost,_this.liveCoverUrl,_this.country,_this.premiumTier,_this.gender,_this.showGender,_this.category,_this.categoryVerified,_this.categoryLocked,const DeepCollectionEquality().hash(_this.links),const DeepCollectionEquality().hash(_this.tags),const DeepCollectionEquality().hash(_this.tagIcons),_this.specialUsername,_this.coverUrl,_this.kabsoTeam,_this.staff,_this.staffId,_this.verification,_this.statusEmojiId]);
}

@override
String toString() {
  final _this = this as User;
  return 'User(id: ${_this.id}, email: ${_this.email}, emailVerified: ${_this.emailVerified}, username: ${_this.username}, displayName: ${_this.displayName}, locale: ${_this.locale}, role: ${_this.role}, isPrivate: ${_this.isPrivate}, createdAt: ${_this.createdAt}, bio: ${_this.bio}, avatarUrl: ${_this.avatarUrl}, canHost: ${_this.canHost}, liveCoverUrl: ${_this.liveCoverUrl}, country: ${_this.country}, premiumTier: ${_this.premiumTier}, gender: ${_this.gender}, showGender: ${_this.showGender}, category: ${_this.category}, categoryVerified: ${_this.categoryVerified}, categoryLocked: ${_this.categoryLocked}, links: ${_this.links}, tags: ${_this.tags}, tagIcons: ${_this.tagIcons}, specialUsername: ${_this.specialUsername}, coverUrl: ${_this.coverUrl}, kabsoTeam: ${_this.kabsoTeam}, staff: ${_this.staff}, staffId: ${_this.staffId}, verification: ${_this.verification}, statusEmojiId: ${_this.statusEmojiId})';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String email, bool emailVerified, String username, String displayName, String locale, UserRole role, bool isPrivate, DateTime createdAt, String? bio, String? avatarUrl, bool canHost, String? liveCoverUrl, String? country, PremiumTier? premiumTier, Gender? gender, bool showGender, AccountCategory? category, bool categoryVerified, bool categoryLocked, List<ProfileLink> links, List<String> tags, List<String> tagIcons, SpecialUsername? specialUsername, String? coverUrl, bool kabsoTeam, KabsoStaffIdentity? staff, String? staffId, VerificationBadge? verification, String? statusEmojiId
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? emailVerified = null,Object? username = null,Object? displayName = null,Object? locale = null,Object? role = null,Object? isPrivate = null,Object? createdAt = null,Object? bio = freezed,Object? avatarUrl = freezed,Object? canHost = null,Object? liveCoverUrl = freezed,Object? country = freezed,Object? premiumTier = freezed,Object? gender = freezed,Object? showGender = null,Object? category = freezed,Object? categoryVerified = null,Object? categoryLocked = null,Object? links = null,Object? tags = null,Object? tagIcons = null,Object? specialUsername = freezed,Object? coverUrl = freezed,Object? kabsoTeam = null,Object? staff = freezed,Object? staffId = freezed,Object? verification = freezed,Object? statusEmojiId = freezed,}) {
  return _then(User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,canHost: null == canHost ? _self.canHost : canHost // ignore: cast_nullable_to_non_nullable
as bool,liveCoverUrl: freezed == liveCoverUrl ? _self.liveCoverUrl : liveCoverUrl // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender?,showGender: null == showGender ? _self.showGender : showGender // ignore: cast_nullable_to_non_nullable
as bool,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as AccountCategory?,categoryVerified: null == categoryVerified ? _self.categoryVerified : categoryVerified // ignore: cast_nullable_to_non_nullable
as bool,categoryLocked: null == categoryLocked ? _self.categoryLocked : categoryLocked // ignore: cast_nullable_to_non_nullable
as bool,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as List<ProfileLink>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,tagIcons: null == tagIcons ? _self.tagIcons : tagIcons // ignore: cast_nullable_to_non_nullable
as List<String>,specialUsername: freezed == specialUsername ? _self.specialUsername : specialUsername // ignore: cast_nullable_to_non_nullable
as SpecialUsername?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,kabsoTeam: null == kabsoTeam ? _self.kabsoTeam : kabsoTeam // ignore: cast_nullable_to_non_nullable
as bool,staff: freezed == staff ? _self.staff : staff // ignore: cast_nullable_to_non_nullable
as KabsoStaffIdentity?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as VerificationBadge?,statusEmojiId: freezed == statusEmojiId ? _self.statusEmojiId : statusEmojiId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  bool emailVerified,  String username,  String displayName,  String locale,  UserRole role,  bool isPrivate,  DateTime createdAt,  String? bio,  String? avatarUrl,  bool canHost,  String? liveCoverUrl,  String? country,  PremiumTier? premiumTier,  Gender? gender,  bool showGender,  AccountCategory? category,  bool categoryVerified,  bool categoryLocked,  List<ProfileLink> links,  List<String> tags,  List<String> tagIcons,  SpecialUsername? specialUsername,  String? coverUrl,  bool kabsoTeam,  KabsoStaffIdentity? staff,  String? staffId,  VerificationBadge? verification,  String? statusEmojiId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.emailVerified,_that.username,_that.displayName,_that.locale,_that.role,_that.isPrivate,_that.createdAt,_that.bio,_that.avatarUrl,_that.canHost,_that.liveCoverUrl,_that.country,_that.premiumTier,_that.gender,_that.showGender,_that.category,_that.categoryVerified,_that.categoryLocked,_that.links,_that.tags,_that.tagIcons,_that.specialUsername,_that.coverUrl,_that.kabsoTeam,_that.staff,_that.staffId,_that.verification,_that.statusEmojiId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  bool emailVerified,  String username,  String displayName,  String locale,  UserRole role,  bool isPrivate,  DateTime createdAt,  String? bio,  String? avatarUrl,  bool canHost,  String? liveCoverUrl,  String? country,  PremiumTier? premiumTier,  Gender? gender,  bool showGender,  AccountCategory? category,  bool categoryVerified,  bool categoryLocked,  List<ProfileLink> links,  List<String> tags,  List<String> tagIcons,  SpecialUsername? specialUsername,  String? coverUrl,  bool kabsoTeam,  KabsoStaffIdentity? staff,  String? staffId,  VerificationBadge? verification,  String? statusEmojiId)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.email,_that.emailVerified,_that.username,_that.displayName,_that.locale,_that.role,_that.isPrivate,_that.createdAt,_that.bio,_that.avatarUrl,_that.canHost,_that.liveCoverUrl,_that.country,_that.premiumTier,_that.gender,_that.showGender,_that.category,_that.categoryVerified,_that.categoryLocked,_that.links,_that.tags,_that.tagIcons,_that.specialUsername,_that.coverUrl,_that.kabsoTeam,_that.staff,_that.staffId,_that.verification,_that.statusEmojiId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  bool emailVerified,  String username,  String displayName,  String locale,  UserRole role,  bool isPrivate,  DateTime createdAt,  String? bio,  String? avatarUrl,  bool canHost,  String? liveCoverUrl,  String? country,  PremiumTier? premiumTier,  Gender? gender,  bool showGender,  AccountCategory? category,  bool categoryVerified,  bool categoryLocked,  List<ProfileLink> links,  List<String> tags,  List<String> tagIcons,  SpecialUsername? specialUsername,  String? coverUrl,  bool kabsoTeam,  KabsoStaffIdentity? staff,  String? staffId,  VerificationBadge? verification,  String? statusEmojiId)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.emailVerified,_that.username,_that.displayName,_that.locale,_that.role,_that.isPrivate,_that.createdAt,_that.bio,_that.avatarUrl,_that.canHost,_that.liveCoverUrl,_that.country,_that.premiumTier,_that.gender,_that.showGender,_that.category,_that.categoryVerified,_that.categoryLocked,_that.links,_that.tags,_that.tagIcons,_that.specialUsername,_that.coverUrl,_that.kabsoTeam,_that.staff,_that.staffId,_that.verification,_that.statusEmojiId);case _:
  return null;

}
}

}

/// @nodoc


class _User implements User {
  const _User({required this.id, required this.email, required this.emailVerified, required this.username, required this.displayName, required this.locale, required this.role, required this.isPrivate, required this.createdAt, this.bio, this.avatarUrl, this.canHost = false, this.liveCoverUrl, this.country, this.premiumTier, this.gender, this.showGender = false, this.category, this.categoryVerified = false, this.categoryLocked = false,  List<ProfileLink> links = const <ProfileLink>[],  List<String> tags = const <String>[],  List<String> tagIcons = const <String>[], this.specialUsername, this.coverUrl, this.kabsoTeam = false, this.staff, this.staffId, this.verification, this.statusEmojiId}): _links = links,_tags = tags,_tagIcons = tagIcons;
  

@override final  String id;
@override final  String email;
@override final  bool emailVerified;
@override final  String username;
@override final  String displayName;
@override final  String locale;
@override final  UserRole role;
@override final  bool isPrivate;
@override final  DateTime createdAt;
@override final  String? bio;
@override final  String? avatarUrl;
/// CP-010: holds the hosting permission (may go live).
@override@JsonKey() final  bool canHost;
/// CP-015: the host's live cover, reused by every live; null → the
/// avatar is shown.
@override final  String? liveCoverUrl;
/// v1.27.1-live (D133): the person's own country (ISO 3166-1 alpha-2,
/// upper case), or null. It decides the live hub's Nearby.
@override final  String? country;
/// v1.28-live (D146): the tier of the person's premium username, or
/// null for a regular one.
@override final  PremiumTier? premiumTier;
/// v1.47-social (D175): the person's gender (null until chosen) and
/// whether others see it (private by default).
@override final  Gender? gender;
@override@JsonKey() final  bool showGender;
/// v1.47-social (D175): the account category shown under the name.
@override final  AccountCategory? category;
/// v1.138-social (D386, §10.175): the Kabso Team verified [category]
/// (the profile's own look) / locked it (Edit profile shows it
/// read-only).
@override@JsonKey() final  bool categoryVerified;
@override@JsonKey() final  bool categoryLocked;
/// v1.47-social (D175): up to 3 profile links, in order.
 final  List<ProfileLink> _links;
/// v1.47-social (D175): up to 3 profile links, in order.
@override@JsonKey() List<ProfileLink> get links {
  if (_links is EqualUnmodifiableListView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_links);
}

/// v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10).
 final  List<String> _tags;
/// v1.85-social (D278b, §10.99): the profile tags «منشنات» (0–10).
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

/// v1.54-social (D185, §10.48.1): the active special username (the
/// shown [username] while set) and the person's own base username.
@override final  SpecialUsername? specialUsername;
/// v1.76-social (D218, §10.73.3): the profile cover, or null.
@override final  String? coverUrl;
/// v1.68-live (D273, §10.96.6): «فريق كابسو» (OWNER, MODERATION or
/// SUPPORT) — the Me tab's staff entry and the staff tools in lives.
@override@JsonKey() final  bool kabsoTeam;
/// v1.72-live (D283, §10.96.10): a limited Kabso Team account
/// (MODERATION / SUPPORT / FINANCE, not OWNER) — the staff-only Me tab,
/// no go-live, levels, VIP, family, store, wallet or bag. Null otherwise.
@override final  KabsoStaffIdentity? staff;
/// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
/// a panel role is held (the OWNER too) — the Me tab shows it instead of
/// the @username. Null otherwise.
@override final  String? staffId;
/// v1.90-social (D293, §10.105): the automatic verification badge
/// «شارة التوثيق» beside the name, or null.
@override final  VerificationBadge? verification;
/// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
/// the picture (`<pack>.<emoji>`), or null.
@override final  String? statusEmojiId;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.role, role) || other.role == role)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.canHost, canHost) || other.canHost == canHost)&&(identical(other.liveCoverUrl, liveCoverUrl) || other.liveCoverUrl == liveCoverUrl)&&(identical(other.country, country) || other.country == country)&&(identical(other.premiumTier, premiumTier) || other.premiumTier == premiumTier)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.showGender, showGender) || other.showGender == showGender)&&(identical(other.category, category) || other.category == category)&&(identical(other.categoryVerified, categoryVerified) || other.categoryVerified == categoryVerified)&&(identical(other.categoryLocked, categoryLocked) || other.categoryLocked == categoryLocked)&&const DeepCollectionEquality().equals(other.links, _links)&&const DeepCollectionEquality().equals(other.tags, _tags)&&const DeepCollectionEquality().equals(other.tagIcons, _tagIcons)&&(identical(other.specialUsername, specialUsername) || other.specialUsername == specialUsername)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.kabsoTeam, kabsoTeam) || other.kabsoTeam == kabsoTeam)&&(identical(other.staff, staff) || other.staff == staff)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.verification, verification) || other.verification == verification)&&(identical(other.statusEmojiId, statusEmojiId) || other.statusEmojiId == statusEmojiId));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,email,emailVerified,username,displayName,locale,role,isPrivate,createdAt,bio,avatarUrl,canHost,liveCoverUrl,country,premiumTier,gender,showGender,category,categoryVerified,categoryLocked,const DeepCollectionEquality().hash(_links),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_tagIcons),specialUsername,coverUrl,kabsoTeam,staff,staffId,verification,statusEmojiId]);
}

@override
String toString() {
    return 'User(id: $id, email: $email, emailVerified: $emailVerified, username: $username, displayName: $displayName, locale: $locale, role: $role, isPrivate: $isPrivate, createdAt: $createdAt, bio: $bio, avatarUrl: $avatarUrl, canHost: $canHost, liveCoverUrl: $liveCoverUrl, country: $country, premiumTier: $premiumTier, gender: $gender, showGender: $showGender, category: $category, categoryVerified: $categoryVerified, categoryLocked: $categoryLocked, links: $links, tags: $tags, tagIcons: $tagIcons, specialUsername: $specialUsername, coverUrl: $coverUrl, kabsoTeam: $kabsoTeam, staff: $staff, staffId: $staffId, verification: $verification, statusEmojiId: $statusEmojiId)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, bool emailVerified, String username, String displayName, String locale, UserRole role, bool isPrivate, DateTime createdAt, String? bio, String? avatarUrl, bool canHost, String? liveCoverUrl, String? country, PremiumTier? premiumTier, Gender? gender, bool showGender, AccountCategory? category, bool categoryVerified, bool categoryLocked, List<ProfileLink> links, List<String> tags, List<String> tagIcons, SpecialUsername? specialUsername, String? coverUrl, bool kabsoTeam, KabsoStaffIdentity? staff, String? staffId, VerificationBadge? verification, String? statusEmojiId
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? emailVerified = null,Object? username = null,Object? displayName = null,Object? locale = null,Object? role = null,Object? isPrivate = null,Object? createdAt = null,Object? bio = freezed,Object? avatarUrl = freezed,Object? canHost = null,Object? liveCoverUrl = freezed,Object? country = freezed,Object? premiumTier = freezed,Object? gender = freezed,Object? showGender = null,Object? category = freezed,Object? categoryVerified = null,Object? categoryLocked = null,Object? links = null,Object? tags = null,Object? tagIcons = null,Object? specialUsername = freezed,Object? coverUrl = freezed,Object? kabsoTeam = null,Object? staff = freezed,Object? staffId = freezed,Object? verification = freezed,Object? statusEmojiId = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,canHost: null == canHost ? _self.canHost : canHost // ignore: cast_nullable_to_non_nullable
as bool,liveCoverUrl: freezed == liveCoverUrl ? _self.liveCoverUrl : liveCoverUrl // ignore: cast_nullable_to_non_nullable
as String?,country: freezed == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String?,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as Gender?,showGender: null == showGender ? _self.showGender : showGender // ignore: cast_nullable_to_non_nullable
as bool,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as AccountCategory?,categoryVerified: null == categoryVerified ? _self.categoryVerified : categoryVerified // ignore: cast_nullable_to_non_nullable
as bool,categoryLocked: null == categoryLocked ? _self.categoryLocked : categoryLocked // ignore: cast_nullable_to_non_nullable
as bool,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as List<ProfileLink>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,tagIcons: null == tagIcons ? _self._tagIcons : tagIcons // ignore: cast_nullable_to_non_nullable
as List<String>,specialUsername: freezed == specialUsername ? _self.specialUsername : specialUsername // ignore: cast_nullable_to_non_nullable
as SpecialUsername?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,kabsoTeam: null == kabsoTeam ? _self.kabsoTeam : kabsoTeam // ignore: cast_nullable_to_non_nullable
as bool,staff: freezed == staff ? _self.staff : staff // ignore: cast_nullable_to_non_nullable
as KabsoStaffIdentity?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as VerificationBadge?,statusEmojiId: freezed == statusEmojiId ? _self.statusEmojiId : statusEmojiId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$Session {

 String get id; bool get current; DateTime get createdAt; DateTime get lastUsedAt; String? get deviceName; SessionPlatform? get platform; String? get appVersion;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Session;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.current, _this.current) || other.current == _this.current)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.lastUsedAt, _this.lastUsedAt) || other.lastUsedAt == _this.lastUsedAt)&&(identical(other.deviceName, _this.deviceName) || other.deviceName == _this.deviceName)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion));
}


@override
int get hashCode {
  final _this = this as Session;
  return Object.hash(runtimeType,_this.id,_this.current,_this.createdAt,_this.lastUsedAt,_this.deviceName,_this.platform,_this.appVersion);
}

@override
String toString() {
  final _this = this as Session;
  return 'Session(id: ${_this.id}, current: ${_this.current}, createdAt: ${_this.createdAt}, lastUsedAt: ${_this.lastUsedAt}, deviceName: ${_this.deviceName}, platform: ${_this.platform}, appVersion: ${_this.appVersion})';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id, bool current, DateTime createdAt, DateTime lastUsedAt, String? deviceName, SessionPlatform? platform, String? appVersion
});




}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? current = null,Object? createdAt = null,Object? lastUsedAt = null,Object? deviceName = freezed,Object? platform = freezed,Object? appVersion = freezed,}) {
  return _then(Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastUsedAt: null == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as SessionPlatform?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool current,  DateTime createdAt,  DateTime lastUsedAt,  String? deviceName,  SessionPlatform? platform,  String? appVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.current,_that.createdAt,_that.lastUsedAt,_that.deviceName,_that.platform,_that.appVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool current,  DateTime createdAt,  DateTime lastUsedAt,  String? deviceName,  SessionPlatform? platform,  String? appVersion)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.current,_that.createdAt,_that.lastUsedAt,_that.deviceName,_that.platform,_that.appVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool current,  DateTime createdAt,  DateTime lastUsedAt,  String? deviceName,  SessionPlatform? platform,  String? appVersion)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.current,_that.createdAt,_that.lastUsedAt,_that.deviceName,_that.platform,_that.appVersion);case _:
  return null;

}
}

}

/// @nodoc


class _Session implements Session {
  const _Session({required this.id, required this.current, required this.createdAt, required this.lastUsedAt, this.deviceName, this.platform, this.appVersion});
  

@override final  String id;
@override final  bool current;
@override final  DateTime createdAt;
@override final  DateTime lastUsedAt;
@override final  String? deviceName;
@override final  SessionPlatform? platform;
@override final  String? appVersion;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.current, current) || other.current == current)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,current,createdAt,lastUsedAt,deviceName,platform,appVersion);
}

@override
String toString() {
    return 'Session(id: $id, current: $current, createdAt: $createdAt, lastUsedAt: $lastUsedAt, deviceName: $deviceName, platform: $platform, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id, bool current, DateTime createdAt, DateTime lastUsedAt, String? deviceName, SessionPlatform? platform, String? appVersion
});




}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? current = null,Object? createdAt = null,Object? lastUsedAt = null,Object? deviceName = freezed,Object? platform = freezed,Object? appVersion = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastUsedAt: null == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deviceName: freezed == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as SessionPlatform?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$UsernameAvailability {

 String get username; bool get available;
/// Create a copy of UsernameAvailability
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsernameAvailabilityCopyWith<UsernameAvailability> get copyWith => _$UsernameAvailabilityCopyWithImpl<UsernameAvailability>(this as UsernameAvailability, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as UsernameAvailability;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsernameAvailability&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.available, _this.available) || other.available == _this.available));
}


@override
int get hashCode {
  final _this = this as UsernameAvailability;
  return Object.hash(runtimeType,_this.username,_this.available);
}

@override
String toString() {
  final _this = this as UsernameAvailability;
  return 'UsernameAvailability(username: ${_this.username}, available: ${_this.available})';
}


}

/// @nodoc
abstract mixin class $UsernameAvailabilityCopyWith<$Res>  {
  factory $UsernameAvailabilityCopyWith(UsernameAvailability value, $Res Function(UsernameAvailability) _then) = _$UsernameAvailabilityCopyWithImpl;
@useResult
$Res call({
 String username, bool available
});




}
/// @nodoc
class _$UsernameAvailabilityCopyWithImpl<$Res>
    implements $UsernameAvailabilityCopyWith<$Res> {
  _$UsernameAvailabilityCopyWithImpl(this._self, this._then);

  final UsernameAvailability _self;
  final $Res Function(UsernameAvailability) _then;

/// Create a copy of UsernameAvailability
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? username = null,Object? available = null,}) {
  return _then(UsernameAvailability(
username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UsernameAvailability].
extension UsernameAvailabilityPatterns on UsernameAvailability {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsernameAvailability value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsernameAvailability() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsernameAvailability value)  $default,){
final _that = this;
switch (_that) {
case _UsernameAvailability():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsernameAvailability value)?  $default,){
final _that = this;
switch (_that) {
case _UsernameAvailability() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String username,  bool available)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsernameAvailability() when $default != null:
return $default(_that.username,_that.available);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String username,  bool available)  $default,) {final _that = this;
switch (_that) {
case _UsernameAvailability():
return $default(_that.username,_that.available);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String username,  bool available)?  $default,) {final _that = this;
switch (_that) {
case _UsernameAvailability() when $default != null:
return $default(_that.username,_that.available);case _:
  return null;

}
}

}

/// @nodoc


class _UsernameAvailability implements UsernameAvailability {
  const _UsernameAvailability({required this.username, required this.available});
  

@override final  String username;
@override final  bool available;

/// Create a copy of UsernameAvailability
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsernameAvailabilityCopyWith<_UsernameAvailability> get copyWith => __$UsernameAvailabilityCopyWithImpl<_UsernameAvailability>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsernameAvailability&&(identical(other.username, username) || other.username == username)&&(identical(other.available, available) || other.available == available));
}


@override
int get hashCode {
    return Object.hash(runtimeType,username,available);
}

@override
String toString() {
    return 'UsernameAvailability(username: $username, available: $available)';
}


}

/// @nodoc
abstract mixin class _$UsernameAvailabilityCopyWith<$Res> implements $UsernameAvailabilityCopyWith<$Res> {
  factory _$UsernameAvailabilityCopyWith(_UsernameAvailability value, $Res Function(_UsernameAvailability) _then) = __$UsernameAvailabilityCopyWithImpl;
@override @useResult
$Res call({
 String username, bool available
});




}
/// @nodoc
class __$UsernameAvailabilityCopyWithImpl<$Res>
    implements _$UsernameAvailabilityCopyWith<$Res> {
  __$UsernameAvailabilityCopyWithImpl(this._self, this._then);

  final _UsernameAvailability _self;
  final $Res Function(_UsernameAvailability) _then;

/// Create a copy of UsernameAvailability
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? username = null,Object? available = null,}) {
  return _then(_UsernameAvailability(
username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
