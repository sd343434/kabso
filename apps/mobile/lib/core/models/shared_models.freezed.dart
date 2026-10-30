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
@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? get rechargeAgentCode;/// v1.56-social (D187, §10.50): the daily recharge badge while it shows
/// (never for a recharge agent): next to the name in live rooms like the
/// level badge. Null otherwise (also on older servers).
@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? get rechargeBadge;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.premiumTier, _this.premiumTier) || other.premiumTier == _this.premiumTier)&&(identical(other.rechargeAgentCode, _this.rechargeAgentCode) || other.rechargeAgentCode == _this.rechargeAgentCode)&&(identical(other.rechargeBadge, _this.rechargeBadge) || other.rechargeBadge == _this.rechargeBadge));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserSummary;
  return Object.hash(runtimeType,_this.id,_this.username,_this.displayName,_this.avatarUrl,_this.premiumTier,_this.rechargeAgentCode,_this.rechargeBadge);
}

@override
String toString() {
  final _this = this as UserSummary;
  return 'UserSummary(id: ${_this.id}, username: ${_this.username}, displayName: ${_this.displayName}, avatarUrl: ${_this.avatarUrl}, premiumTier: ${_this.premiumTier}, rechargeAgentCode: ${_this.rechargeAgentCode}, rechargeBadge: ${_this.rechargeBadge})';
}


}

/// @nodoc
abstract mixin class $UserSummaryCopyWith<$Res>  {
  factory $UserSummaryCopyWith(UserSummary value, $Res Function(UserSummary) _then) = _$UserSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? premiumTier = freezed,Object? rechargeAgentCode = freezed,Object? rechargeBadge = freezed,}) {
  return _then(UserSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.premiumTier,_that.rechargeAgentCode,_that.rechargeBadge);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge)  $default,) {final _that = this;
switch (_that) {
case _UserSummary():
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.premiumTier,_that.rechargeAgentCode,_that.rechargeBadge);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayName,  String? avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson)  PremiumTier? premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson)  String? rechargeAgentCode, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson)  RechargeBadge? rechargeBadge)?  $default,) {final _that = this;
switch (_that) {
case _UserSummary() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.avatarUrl,_that.premiumTier,_that.rechargeAgentCode,_that.rechargeBadge);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserSummary implements UserSummary {
  const _UserSummary({required this.id, required this.username, required this.displayName, required this.avatarUrl, @JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) this.premiumTier, @JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) this.rechargeAgentCode, @JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) this.rechargeBadge});
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
/// v1.56-social (D187, §10.50): the daily recharge badge while it shows
/// (never for a recharge agent): next to the name in live rooms like the
/// level badge. Null otherwise (also on older servers).
@override@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) final  RechargeBadge? rechargeBadge;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.premiumTier, premiumTier) || other.premiumTier == premiumTier)&&(identical(other.rechargeAgentCode, rechargeAgentCode) || other.rechargeAgentCode == rechargeAgentCode)&&(identical(other.rechargeBadge, rechargeBadge) || other.rechargeBadge == rechargeBadge));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,username,displayName,avatarUrl,premiumTier,rechargeAgentCode,rechargeBadge);
}

@override
String toString() {
    return 'UserSummary(id: $id, username: $username, displayName: $displayName, avatarUrl: $avatarUrl, premiumTier: $premiumTier, rechargeAgentCode: $rechargeAgentCode, rechargeBadge: $rechargeBadge)';
}


}

/// @nodoc
abstract mixin class _$UserSummaryCopyWith<$Res> implements $UserSummaryCopyWith<$Res> {
  factory _$UserSummaryCopyWith(_UserSummary value, $Res Function(_UserSummary) _then) = __$UserSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayName, String? avatarUrl,@JsonKey(fromJson: premiumTierFromJson, toJson: premiumTierToJson) PremiumTier? premiumTier,@JsonKey(name: 'rechargeAgent', includeIfNull: false, fromJson: rechargeAgentCodeFromJson, toJson: rechargeAgentCodeToJson) String? rechargeAgentCode,@JsonKey(includeIfNull: false, fromJson: rechargeBadgeFromJson, toJson: rechargeBadgeToJson) RechargeBadge? rechargeBadge
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? avatarUrl = freezed,Object? premiumTier = freezed,Object? rechargeAgentCode = freezed,Object? rechargeBadge = freezed,}) {
  return _then(_UserSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,premiumTier: freezed == premiumTier ? _self.premiumTier : premiumTier // ignore: cast_nullable_to_non_nullable
as PremiumTier?,rechargeAgentCode: freezed == rechargeAgentCode ? _self.rechargeAgentCode : rechargeAgentCode // ignore: cast_nullable_to_non_nullable
as String?,rechargeBadge: freezed == rechargeBadge ? _self.rechargeBadge : rechargeBadge // ignore: cast_nullable_to_non_nullable
as RechargeBadge?,
  ));
}


}

// dart format on
