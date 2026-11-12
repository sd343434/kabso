// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shared_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PageInfo {

 String? get nextCursor; bool get hasMore;
/// Create a copy of PageInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PageInfoCopyWith<PageInfo> get copyWith => _$PageInfoCopyWithImpl<PageInfo>(this as PageInfo, _$identity);

  /// Serializes this PageInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PageInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PageInfo&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor)&&(identical(other.hasMore, _this.hasMore) || other.hasMore == _this.hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PageInfo;
  return Object.hash(runtimeType,_this.nextCursor,_this.hasMore);
}

@override
String toString() {
  final _this = this as PageInfo;
  return 'PageInfo(nextCursor: ${_this.nextCursor}, hasMore: ${_this.hasMore})';
}


}

/// @nodoc
abstract mixin class $PageInfoCopyWith<$Res>  {
  factory $PageInfoCopyWith(PageInfo value, $Res Function(PageInfo) _then) = _$PageInfoCopyWithImpl;
@useResult
$Res call({
 String? nextCursor, bool hasMore
});




}
/// @nodoc
class _$PageInfoCopyWithImpl<$Res>
    implements $PageInfoCopyWith<$Res> {
  _$PageInfoCopyWithImpl(this._self, this._then);

  final PageInfo _self;
  final $Res Function(PageInfo) _then;

/// Create a copy of PageInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nextCursor = freezed,Object? hasMore = null,}) {
  return _then(PageInfo(
nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PageInfo].
extension PageInfoPatterns on PageInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PageInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PageInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PageInfo value)  $default,){
final _that = this;
switch (_that) {
case _PageInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PageInfo value)?  $default,){
final _that = this;
switch (_that) {
case _PageInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? nextCursor,  bool hasMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PageInfo() when $default != null:
return $default(_that.nextCursor,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? nextCursor,  bool hasMore)  $default,) {final _that = this;
switch (_that) {
case _PageInfo():
return $default(_that.nextCursor,_that.hasMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? nextCursor,  bool hasMore)?  $default,) {final _that = this;
switch (_that) {
case _PageInfo() when $default != null:
return $default(_that.nextCursor,_that.hasMore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PageInfo implements PageInfo {
  const _PageInfo({required this.nextCursor, required this.hasMore});
  factory _PageInfo.fromJson(Map<String, dynamic> json) => _$PageInfoFromJson(json);

@override final  String? nextCursor;
@override final  bool hasMore;

/// Create a copy of PageInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PageInfoCopyWith<_PageInfo> get copyWith => __$PageInfoCopyWithImpl<_PageInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PageInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PageInfo&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,nextCursor,hasMore);
}

@override
String toString() {
    return 'PageInfo(nextCursor: $nextCursor, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class _$PageInfoCopyWith<$Res> implements $PageInfoCopyWith<$Res> {
  factory _$PageInfoCopyWith(_PageInfo value, $Res Function(_PageInfo) _then) = __$PageInfoCopyWithImpl;
@override @useResult
$Res call({
 String? nextCursor, bool hasMore
});




}
/// @nodoc
class __$PageInfoCopyWithImpl<$Res>
    implements _$PageInfoCopyWith<$Res> {
  __$PageInfoCopyWithImpl(this._self, this._then);

  final _PageInfo _self;
  final $Res Function(_PageInfo) _then;

/// Create a copy of PageInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nextCursor = freezed,Object? hasMore = null,}) {
  return _then(_PageInfo(
nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$UserSummary {

 String get id; String get username; String get displayName; String? get avatarUrl;/// v1.28-live (D146): the tier of the user's premium username (the
/// badge), or null for a regular username. Only the server decides it.
@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? get premiumTier;/// v1.54-social (D185, §10.48): the user's recharge-agent code while
/// they are an ACTIVE agent (`UserSummary.rechargeAgent.code`): the
/// small agent badge next to the name in live rooms. Null otherwise.
@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get rechargeAgentCode;/// v1.58-social (D189, §10.52): the user's host-agent code «وكيل مضيفين»
/// while their agency is not suspended (`UserSummary.hostAgent.code`,
/// the same `{code}` shape): the host-agent badge next to the name and
/// the entrance. Null otherwise.
@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get hostAgentCode;/// v1.55-social (D186, §10.49): the avatar frame the user wears
/// (`UserSummary.avatarFrame`, present only while one is worn): drawn
/// around the picture on the live seats. Null otherwise.
@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? get avatarFrame;/// v1.56-social (D187, §10.50): the daily recharge badge while it shows
/// (never for a recharge agent): next to the name in live rooms like the
/// level badge. Null otherwise (also on older servers).
@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? get rechargeBadge;/// v1.83-social (D258, §10.94): the active VIP (badge, frame, name colour,
/// bubble, card…, by the catalogue). Null otherwise (also older servers).
/// D270 (§10.98.4): with the store items worn (`UserSummary.wear`) — a
/// store-only look when the person holds no VIP ([UserVip.member]).
@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) UserVip? get vip;/// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
/// the user holds a panel role (the OWNER too): shown where the
/// @username is (live viewers and chat, search, lists). Null otherwise.
@JsonKey(includeIfNull: false) String? get staffId;/// v1.131-social (D378, §10.168.4): the golden ID «آيدي ذهبي» held now
/// (the gold «ID 8888» chip). Null otherwise (also older servers).
@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) UserGoldenId? get goldenId;/// v1.90-social (D293, §10.105.5; owner «نعم»): the automatic
/// verification badge «شارة التوثيق» — the seal right after the name
/// wherever the name is shown. Null when none, for unknown values and
/// from older servers.
@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) VerificationBadge? get verification;/// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
/// the picture (`<pack>.<emoji>`); the app shows nothing for an id it
/// does not know. Null when none and from older servers.
@JsonKey(includeIfNull: false) String? get statusEmojiId;/// v1.133-social (D380, §10.170): the stand-in «مجهول» the server shows
/// instead of a VIP member (RANKING_ANONYMOUS on a public board, the
/// sender of an ANONYMOUS_GIFT): a random id, no picture, no badges. The
/// app shows its own «مجهول» with the generic avatar and opens nothing.
@JsonKey(includeIfNull: false, toJson: trueOrNull) bool get anonymous;
/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<UserSummary> get copyWith => _$UserSummaryCopyWithImpl<UserSummary>(this as UserSummary, _$identity);

  /// Serializes this UserSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.premiumTier, _this.premiumTier) || other.premiumTier == _this.premiumTier)&&(identical(other.rechargeAgentCode, _this.rechargeAgentCode) || other.rechargeAgentCode == _this.rechargeAgentCode)&&(identical(other.hostAgentCode, _this.hostAgentCode) || other.hostAgentCode == _this.hostAgentCode)&&(identical(other.avatarFrame, _this.avatarFrame) || other.avatarFrame == _this.avatarFrame)&&(identical(other.rechargeBadge, _this.rechargeBadge) || other.rechargeBadge == _this.rechargeBadge)&&(identical(other.vip, _this.vip) || other.vip == _this.vip)&&(identical(other.staffId, _this.staffId) || other.staffId == _this.staffId)&&(identical(other.goldenId, _this.goldenId) || other.goldenId == _this.goldenId)&&(identical(other.verification, _this.verification) || other.verification == _this.verification)&&(identical(other.statusEmojiId, _this.statusEmojiId) || other.statusEmojiId == _this.statusEmojiId)&&(identical(other.anonymous, _this.anonymous) || other.anonymous == _this.anonymous));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserSummary;
  return Object.hash(runtimeType,_this.id,_this.username,_this.displayName,_this.avatarUrl,_this.premiumTier,_this.rechargeAgentCode,_this.hostAgentCode,_this.avatarFrame,_this.rechargeBadge,_this.vip,_this.staffId,_this.goldenId,_this.verification,_this.statusEmojiId,_this.anonymous);
}

@override
String toString() {
  final _this = this as UserSummary;
  return 'UserSummary(id: ${_this.id}, username: ${_this.username}, displayName: ${_this.displayName}, avatarUrl: ${_this.avatarUrl}, premiumTier: ${_this.premiumTier}, rechargeAgentCode: ${_this.rechargeAgentCode}, hostAgentCode: ${_this.hostAgentCode}, avatarFrame: ${_this.avatarFrame}, rechargeBadge: ${_this.rechargeBadge}, vip: ${_this.vip}, staffId: ${_this.staffId}, goldenId: ${_this.goldenId}, verification: ${_this.verification}, statusEmojiId: ${_this.statusEmojiId}, anonymous: ${_this.anonymous})';
}


}

/// @nodoc
abstract mixin class $UserSummaryCopyWith<$Res>  {
  factory $UserSummaryCopyWith(UserSummary value, $Res Function(UserSummary) _then) = _$UserSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? hostAgentCode,@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? avatarFrame,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge,@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) UserVip? vip,@JsonKey(includeIfNull: false) String? staffId,@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) UserGoldenId? goldenId,@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) VerificationBadge? verification,@JsonKey(includeIfNull: false) String? statusEmojiId,@JsonKey(includeIfNull: false, toJson: trueOrNull) bool anonymous
});




}
/// @nodoc
class _$UserSummaryCopyWithImpl<$Res>
    implements $UserSummaryCopyWith<$Res> {
  _$UserSummaryCopyWithImpl(this._self, this._then);

  final UserSummary _self;
  final $Res Function(UserSummary) _then;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? premiumTier = freezed,Object? rechargeAgentCode = freezed,Object? hostAgentCode = freezed,Object? avatarFrame = freezed,Object? rechargeBadge = freezed,Object? vip = freezed,Object? staffId = freezed,Object? goldenId = freezed,Object? verification = freezed,Object? statusEmojiId = freezed,Object? anonymous = null,}) {
  return _then(UserSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,hostAgentCode: freezed == hostAgentCode ? _self.hostAgentCode : hostAgentCode // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as AvatarFrame?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,vip: freezed == vip ? _self.vip : vip // ignore: cast_nullable_to_non_nullable
as UserVip?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,goldenId: freezed == goldenId ? _self.goldenId : goldenId // ignore: cast_nullable_to_non_nullable
as UserGoldenId?,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as VerificationBadge?,statusEmojiId: freezed == statusEmojiId ? _self.statusEmojiId : statusEmojiId // ignore: cast_nullable_to_non_nullable
as String?,anonymous: null == anonymous ? _self.anonymous : anonymous // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSummary].
extension UserSummaryPatterns on UserSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSummary value)  $default,){
final _that = this;
switch (_that) {
case _UserSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSummary value)?  $default,){
final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson)  UserVip? vip, @JsonKey(includeIfNull: false)  String? staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson)  UserGoldenId? goldenId, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson)  VerificationBadge? verification, @JsonKey(includeIfNull: false)  String? statusEmojiId, @JsonKey(includeIfNull: false, toJson: trueOrNull)  bool anonymous)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.premiumTier,_that.rechargeAgentCode,_that.hostAgentCode,_that.avatarFrame,_that.rechargeBadge,_that.vip,_that.staffId,_that.goldenId,_that.verification,_that.statusEmojiId,_that.anonymous);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson)  UserVip? vip, @JsonKey(includeIfNull: false)  String? staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson)  UserGoldenId? goldenId, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson)  VerificationBadge? verification, @JsonKey(includeIfNull: false)  String? statusEmojiId, @JsonKey(includeIfNull: false, toJson: trueOrNull)  bool anonymous)  $default,) {final _that = this;
switch (_that) {
case _UserSummary():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.premiumTier,_that.rechargeAgentCode,_that.hostAgentCode,_that.avatarFrame,_that.rechargeBadge,_that.vip,_that.staffId,_that.goldenId,_that.verification,_that.statusEmojiId,_that.anonymous);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayName,  String? avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson)  AvatarFrame? avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson)  UserVip? vip, @JsonKey(includeIfNull: false)  String? staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson)  UserGoldenId? goldenId, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson)  VerificationBadge? verification, @JsonKey(includeIfNull: false)  String? statusEmojiId, @JsonKey(includeIfNull: false, toJson: trueOrNull)  bool anonymous)?  $default,) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.premiumTier,_that.rechargeAgentCode,_that.hostAgentCode,_that.avatarFrame,_that.rechargeBadge,_that.vip,_that.staffId,_that.goldenId,_that.verification,_that.statusEmojiId,_that.anonymous);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserSummary implements UserSummary {
  const _UserSummary({required this.id, required this.username, required this.displayName, required this.avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) this.premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.rechargeAgentCode, @JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.hostAgentCode, @JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) this.avatarFrame, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) this.rechargeBadge, @JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) this.vip, @JsonKey(includeIfNull: false) this.staffId, @JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) this.goldenId, @JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) this.verification, @JsonKey(includeIfNull: false) this.statusEmojiId, @JsonKey(includeIfNull: false, toJson: trueOrNull) this.anonymous = false});
  factory _UserSummary.fromJson(Map<String, dynamic> json) => _$UserSummaryFromJson(json);

@override final  String id;
@override final  String username;
@override final  String displayName;
@override final  String? avatarUrl;
/// v1.28-live (D146): the tier of the user's premium username (the
/// badge), or null for a regular username. Only the server decides it.
@override@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) final  PremiumTier? premiumTier;
/// v1.54-social (D185, §10.48): the user's recharge-agent code while
/// they are an ACTIVE agent (`UserSummary.rechargeAgent.code`): the
/// small agent badge next to the name in live rooms. Null otherwise.
@override@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) final  String? rechargeAgentCode;
/// v1.58-social (D189, §10.52): the user's host-agent code «وكيل مضيفين»
/// while their agency is not suspended (`UserSummary.hostAgent.code`,
/// the same `{code}` shape): the host-agent badge next to the name and
/// the entrance. Null otherwise.
@override@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) final  String? hostAgentCode;
/// v1.55-social (D186, §10.49): the avatar frame the user wears
/// (`UserSummary.avatarFrame`, present only while one is worn): drawn
/// around the picture on the live seats. Null otherwise.
@override@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) final  AvatarFrame? avatarFrame;
/// v1.56-social (D187, §10.50): the daily recharge badge while it shows
/// (never for a recharge agent): next to the name in live rooms like the
/// level badge. Null otherwise (also on older servers).
@override@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) final  RechargeBadge? rechargeBadge;
/// v1.83-social (D258, §10.94): the active VIP (badge, frame, name colour,
/// bubble, card…, by the catalogue). Null otherwise (also older servers).
/// D270 (§10.98.4): with the store items worn (`UserSummary.wear`) — a
/// store-only look when the person holds no VIP ([UserVip.member]).
@override@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) final  UserVip? vip;
/// v1.73-live (D283c, §10.96.12): the official staff ID «Kabso01» while
/// the user holds a panel role (the OWNER too): shown where the
/// @username is (live viewers and chat, search, lists). Null otherwise.
@override@JsonKey(includeIfNull: false) final  String? staffId;
/// v1.131-social (D378, §10.168.4): the golden ID «آيدي ذهبي» held now
/// (the gold «ID 8888» chip). Null otherwise (also older servers).
@override@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) final  UserGoldenId? goldenId;
/// v1.90-social (D293, §10.105.5; owner «نعم»): the automatic
/// verification badge «شارة التوثيق» — the seal right after the name
/// wherever the name is shown. Null when none, for unknown values and
/// from older servers.
@override@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) final  VerificationBadge? verification;
/// v1.130-social (D376, §10.167): «الحالة» — the status emoji worn over
/// the picture (`<pack>.<emoji>`); the app shows nothing for an id it
/// does not know. Null when none and from older servers.
@override@JsonKey(includeIfNull: false) final  String? statusEmojiId;
/// v1.133-social (D380, §10.170): the stand-in «مجهول» the server shows
/// instead of a VIP member (RANKING_ANONYMOUS on a public board, the
/// sender of an ANONYMOUS_GIFT): a random id, no picture, no badges. The
/// app shows its own «مجهول» with the generic avatar and opens nothing.
@override@JsonKey(includeIfNull: false, toJson: trueOrNull) final  bool anonymous;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSummaryCopyWith<_UserSummary> get copyWith => __$UserSummaryCopyWithImpl<_UserSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.premiumTier, premiumTier) || other.premiumTier == premiumTier)&&(identical(other.rechargeAgentCode, rechargeAgentCode) || other.rechargeAgentCode == rechargeAgentCode)&&(identical(other.hostAgentCode, hostAgentCode) || other.hostAgentCode == hostAgentCode)&&(identical(other.avatarFrame, avatarFrame) || other.avatarFrame == avatarFrame)&&(identical(other.rechargeBadge, rechargeBadge) || other.rechargeBadge == rechargeBadge)&&(identical(other.vip, vip) || other.vip == vip)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.goldenId, goldenId) || other.goldenId == goldenId)&&(identical(other.verification, verification) || other.verification == verification)&&(identical(other.statusEmojiId, statusEmojiId) || other.statusEmojiId == statusEmojiId)&&(identical(other.anonymous, anonymous) || other.anonymous == anonymous));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,username,displayName,avatarUrl,premiumTier,rechargeAgentCode,hostAgentCode,avatarFrame,rechargeBadge,vip,staffId,goldenId,verification,statusEmojiId,anonymous);
}

@override
String toString() {
    return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, premiumTier: $premiumTier, rechargeAgentCode: $rechargeAgentCode, hostAgentCode: $hostAgentCode, avatarFrame: $avatarFrame, rechargeBadge: $rechargeBadge, vip: $vip, staffId: $staffId, goldenId: $goldenId, verification: $verification, statusEmojiId: $statusEmojiId, anonymous: $anonymous)';
}


}

/// @nodoc
abstract mixin class _$UserSummaryCopyWith<$Res> implements $UserSummaryCopyWith<$Res> {
  factory _$UserSummaryCopyWith(_UserSummary value, $Res Function(_UserSummary) _then) = __$UserSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(name: 'hostAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? hostAgentCode,@JsonKey(includeIfNull: false, fromJson: avatarFrameFromJson, toJson: avatarFrameToJson) AvatarFrame? avatarFrame,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge,@JsonKey(includeIfNull: false, readValue: userVipWithWear, fromJson: userVipFromJson, toJson: userVipToJson) UserVip? vip,@JsonKey(includeIfNull: false) String? staffId,@JsonKey(includeIfNull: false, fromJson: userGoldenIdFromJson, toJson: userGoldenIdToJson) UserGoldenId? goldenId,@JsonKey(includeIfNull: false, fromJson: verificationBadgeFromJson, toJson: verificationBadgeToJson) VerificationBadge? verification,@JsonKey(includeIfNull: false) String? statusEmojiId,@JsonKey(includeIfNull: false, toJson: trueOrNull) bool anonymous
});




}
/// @nodoc
class __$UserSummaryCopyWithImpl<$Res>
    implements _$UserSummaryCopyWith<$Res> {
  __$UserSummaryCopyWithImpl(this._self, this._then);

  final _UserSummary _self;
  final $Res Function(_UserSummary) _then;

/// Create a copy of UserSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? premiumTier = freezed,Object? rechargeAgentCode = freezed,Object? hostAgentCode = freezed,Object? avatarFrame = freezed,Object? rechargeBadge = freezed,Object? vip = freezed,Object? staffId = freezed,Object? goldenId = freezed,Object? verification = freezed,Object? statusEmojiId = freezed,Object? anonymous = null,}) {
  return _then(_UserSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,hostAgentCode: freezed == hostAgentCode ? _self.hostAgentCode : hostAgentCode // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as AvatarFrame?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,vip: freezed == vip ? _self.vip : vip // ignore: cast_nullable_to_non_nullable
as UserVip?,staffId: freezed == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String?,goldenId: freezed == goldenId ? _self.goldenId : goldenId // ignore: cast_nullable_to_non_nullable
as UserGoldenId?,verification: freezed == verification ? _self.verification : verification // ignore: cast_nullable_to_non_nullable
as VerificationBadge?,statusEmojiId: freezed == statusEmojiId ? _self.statusEmojiId : statusEmojiId // ignore: cast_nullable_to_non_nullable
as String?,anonymous: null == anonymous ? _self.anonymous : anonymous // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
