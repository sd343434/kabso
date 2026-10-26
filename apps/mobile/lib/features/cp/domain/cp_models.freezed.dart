// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cp_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CpTier {

 int get level; int get minPoints; String get name;
/// Create a copy of CpTier
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpTierCopyWith<CpTier> get copyWith => _$CpTierCopyWithImpl<CpTier>(this as CpTier, _$identity);

  /// Serializes this CpTier to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CpTier;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpTier&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.minPoints, _this.minPoints) || other.minPoints == _this.minPoints)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CpTier;
  return Object.hash(runtimeType,_this.level,_this.minPoints,_this.name);
}

@override
String toString() {
  final _this = this as CpTier;
  return 'CpTier(level: ${_this.level}, minPoints: ${_this.minPoints}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $CpTierCopyWith<$Res>  {
  factory $CpTierCopyWith(CpTier value, $Res Function(CpTier) _then) = _$CpTierCopyWithImpl;
@useResult
$Res call({
 int level, int minPoints, String name
});




}
/// @nodoc
class _$CpTierCopyWithImpl<$Res>
    implements $CpTierCopyWith<$Res> {
  _$CpTierCopyWithImpl(this._self, this._then);

  final CpTier _self;
  final $Res Function(CpTier) _then;

/// Create a copy of CpTier
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? minPoints = null,Object? name = null,}) {
  return _then(CpTier(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,minPoints: null == minPoints ? _self.minPoints : minPoints // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CpTier].
extension CpTierPatterns on CpTier {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpTier value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpTier() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpTier value)  $default,){
final _that = this;
switch (_that) {
case _CpTier():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpTier value)?  $default,){
final _that = this;
switch (_that) {
case _CpTier() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int level,  int minPoints,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpTier() when $default != null:
return $default(_that.level,_that.minPoints,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int level,  int minPoints,  String name)  $default,) {final _that = this;
switch (_that) {
case _CpTier():
return $default(_that.level,_that.minPoints,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int level,  int minPoints,  String name)?  $default,) {final _that = this;
switch (_that) {
case _CpTier() when $default != null:
return $default(_that.level,_that.minPoints,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpTier implements CpTier {
  const _CpTier({required this.level, required this.minPoints, required this.name});
  factory _CpTier.fromJson(Map<String, dynamic> json) => _$CpTierFromJson(json);

@override final  int level;
@override final  int minPoints;
@override final  String name;

/// Create a copy of CpTier
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpTierCopyWith<_CpTier> get copyWith => __$CpTierCopyWithImpl<_CpTier>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpTierToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpTier&&(identical(other.level, level) || other.level == level)&&(identical(other.minPoints, minPoints) || other.minPoints == minPoints)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,level,minPoints,name);
}

@override
String toString() {
    return 'CpTier(level: $level, minPoints: $minPoints, name: $name)';
}


}

/// @nodoc
abstract mixin class _$CpTierCopyWith<$Res> implements $CpTierCopyWith<$Res> {
  factory _$CpTierCopyWith(_CpTier value, $Res Function(_CpTier) _then) = __$CpTierCopyWithImpl;
@override @useResult
$Res call({
 int level, int minPoints, String name
});




}
/// @nodoc
class __$CpTierCopyWithImpl<$Res>
    implements _$CpTierCopyWith<$Res> {
  __$CpTierCopyWithImpl(this._self, this._then);

  final _CpTier _self;
  final $Res Function(_CpTier) _then;

/// Create a copy of CpTier
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? minPoints = null,Object? name = null,}) {
  return _then(_CpTier(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,minPoints: null == minPoints ? _self.minPoints : minPoints // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CpConfig {

 int get requestCost; int get requestTtlDays; List<int> get giftAmounts; List<CpTier> get tiers;
/// Create a copy of CpConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpConfigCopyWith<CpConfig> get copyWith => _$CpConfigCopyWithImpl<CpConfig>(this as CpConfig, _$identity);

  /// Serializes this CpConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CpConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpConfig&&(identical(other.requestCost, _this.requestCost) || other.requestCost == _this.requestCost)&&(identical(other.requestTtlDays, _this.requestTtlDays) || other.requestTtlDays == _this.requestTtlDays)&&const DeepCollectionEquality().equals(other.giftAmounts, _this.giftAmounts)&&const DeepCollectionEquality().equals(other.tiers, _this.tiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CpConfig;
  return Object.hash(runtimeType,_this.requestCost,_this.requestTtlDays,const DeepCollectionEquality().hash(_this.giftAmounts),const DeepCollectionEquality().hash(_this.tiers));
}

@override
String toString() {
  final _this = this as CpConfig;
  return 'CpConfig(requestCost: ${_this.requestCost}, requestTtlDays: ${_this.requestTtlDays}, giftAmounts: ${_this.giftAmounts}, tiers: ${_this.tiers})';
}


}

/// @nodoc
abstract mixin class $CpConfigCopyWith<$Res>  {
  factory $CpConfigCopyWith(CpConfig value, $Res Function(CpConfig) _then) = _$CpConfigCopyWithImpl;
@useResult
$Res call({
 int requestCost, int requestTtlDays, List<int> giftAmounts, List<CpTier> tiers
});




}
/// @nodoc
class _$CpConfigCopyWithImpl<$Res>
    implements $CpConfigCopyWith<$Res> {
  _$CpConfigCopyWithImpl(this._self, this._then);

  final CpConfig _self;
  final $Res Function(CpConfig) _then;

/// Create a copy of CpConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestCost = null,Object? requestTtlDays = null,Object? giftAmounts = null,Object? tiers = null,}) {
  return _then(CpConfig(
requestCost: null == requestCost ? _self.requestCost : requestCost // ignore: cast_nullable_to_non_nullable
as int,requestTtlDays: null == requestTtlDays ? _self.requestTtlDays : requestTtlDays // ignore: cast_nullable_to_non_nullable
as int,giftAmounts: null == giftAmounts ? _self.giftAmounts : giftAmounts // ignore: cast_nullable_to_non_nullable
as List<int>,tiers: null == tiers ? _self.tiers : tiers // ignore: cast_nullable_to_non_nullable
as List<CpTier>,
  ));
}

}


/// Adds pattern-matching-related methods to [CpConfig].
extension CpConfigPatterns on CpConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpConfig value)  $default,){
final _that = this;
switch (_that) {
case _CpConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CpConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int requestCost,  int requestTtlDays,  List<int> giftAmounts,  List<CpTier> tiers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpConfig() when $default != null:
return $default(_that.requestCost,_that.requestTtlDays,_that.giftAmounts,_that.tiers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int requestCost,  int requestTtlDays,  List<int> giftAmounts,  List<CpTier> tiers)  $default,) {final _that = this;
switch (_that) {
case _CpConfig():
return $default(_that.requestCost,_that.requestTtlDays,_that.giftAmounts,_that.tiers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int requestCost,  int requestTtlDays,  List<int> giftAmounts,  List<CpTier> tiers)?  $default,) {final _that = this;
switch (_that) {
case _CpConfig() when $default != null:
return $default(_that.requestCost,_that.requestTtlDays,_that.giftAmounts,_that.tiers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpConfig implements CpConfig {
  const _CpConfig({required this.requestCost, required this.requestTtlDays, required  List<int> giftAmounts, required  List<CpTier> tiers}): _giftAmounts = giftAmounts,_tiers = tiers;
  factory _CpConfig.fromJson(Map<String, dynamic> json) => _$CpConfigFromJson(json);

@override final  int requestCost;
@override final  int requestTtlDays;
 final  List<int> _giftAmounts;
@override List<int> get giftAmounts {
  if (_giftAmounts is EqualUnmodifiableListView) return _giftAmounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_giftAmounts);
}

 final  List<CpTier> _tiers;
@override List<CpTier> get tiers {
  if (_tiers is EqualUnmodifiableListView) return _tiers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiers);
}


/// Create a copy of CpConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpConfigCopyWith<_CpConfig> get copyWith => __$CpConfigCopyWithImpl<_CpConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpConfig&&(identical(other.requestCost, requestCost) || other.requestCost == requestCost)&&(identical(other.requestTtlDays, requestTtlDays) || other.requestTtlDays == requestTtlDays)&&const DeepCollectionEquality().equals(other.giftAmounts, _giftAmounts)&&const DeepCollectionEquality().equals(other.tiers, _tiers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestCost,requestTtlDays,const DeepCollectionEquality().hash(_giftAmounts),const DeepCollectionEquality().hash(_tiers));
}

@override
String toString() {
    return 'CpConfig(requestCost: $requestCost, requestTtlDays: $requestTtlDays, giftAmounts: $giftAmounts, tiers: $tiers)';
}


}

/// @nodoc
abstract mixin class _$CpConfigCopyWith<$Res> implements $CpConfigCopyWith<$Res> {
  factory _$CpConfigCopyWith(_CpConfig value, $Res Function(_CpConfig) _then) = __$CpConfigCopyWithImpl;
@override @useResult
$Res call({
 int requestCost, int requestTtlDays, List<int> giftAmounts, List<CpTier> tiers
});




}
/// @nodoc
class __$CpConfigCopyWithImpl<$Res>
    implements _$CpConfigCopyWith<$Res> {
  __$CpConfigCopyWithImpl(this._self, this._then);

  final _CpConfig _self;
  final $Res Function(_CpConfig) _then;

/// Create a copy of CpConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestCost = null,Object? requestTtlDays = null,Object? giftAmounts = null,Object? tiers = null,}) {
  return _then(_CpConfig(
requestCost: null == requestCost ? _self.requestCost : requestCost // ignore: cast_nullable_to_non_nullable
as int,requestTtlDays: null == requestTtlDays ? _self.requestTtlDays : requestTtlDays // ignore: cast_nullable_to_non_nullable
as int,giftAmounts: null == giftAmounts ? _self._giftAmounts : giftAmounts // ignore: cast_nullable_to_non_nullable
as List<int>,tiers: null == tiers ? _self._tiers : tiers // ignore: cast_nullable_to_non_nullable
as List<CpTier>,
  ));
}


}


/// @nodoc
mixin _$CpRequest {

 String get id; UserSummary get sender; UserSummary get receiver; BondRequestStatus get status; int get cost; DateTime get createdAt; DateTime get expiresAt;
/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpRequestCopyWith<CpRequest> get copyWith => _$CpRequestCopyWithImpl<CpRequest>(this as CpRequest, _$identity);

  /// Serializes this CpRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CpRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpRequest&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&(identical(other.receiver, _this.receiver) || other.receiver == _this.receiver)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.cost, _this.cost) || other.cost == _this.cost)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CpRequest;
  return Object.hash(runtimeType,_this.id,_this.sender,_this.receiver,_this.status,_this.cost,_this.createdAt,_this.expiresAt);
}

@override
String toString() {
  final _this = this as CpRequest;
  return 'CpRequest(id: ${_this.id}, sender: ${_this.sender}, receiver: ${_this.receiver}, status: ${_this.status}, cost: ${_this.cost}, createdAt: ${_this.createdAt}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $CpRequestCopyWith<$Res>  {
  factory $CpRequestCopyWith(CpRequest value, $Res Function(CpRequest) _then) = _$CpRequestCopyWithImpl;
@useResult
$Res call({
 String id, UserSummary sender, UserSummary receiver, BondRequestStatus status, int cost, DateTime createdAt, DateTime expiresAt
});


$UserSummaryCopyWith<$Res> get sender;$UserSummaryCopyWith<$Res> get receiver;

}
/// @nodoc
class _$CpRequestCopyWithImpl<$Res>
    implements $CpRequestCopyWith<$Res> {
  _$CpRequestCopyWithImpl(this._self, this._then);

  final CpRequest _self;
  final $Res Function(CpRequest) _then;

/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sender = null,Object? receiver = null,Object? status = null,Object? cost = null,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(CpRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,receiver: null == receiver ? _self.receiver : receiver // ignore: cast_nullable_to_non_nullable
as UserSummary,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BondRequestStatus,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get receiver {
  
  return $UserSummaryCopyWith<$Res>(_self.receiver, (value) {
    return _then(_self.copyWith(receiver: value));
  });
}
}


/// Adds pattern-matching-related methods to [CpRequest].
extension CpRequestPatterns on CpRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpRequest value)  $default,){
final _that = this;
switch (_that) {
case _CpRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CpRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  UserSummary sender,  UserSummary receiver,  BondRequestStatus status,  int cost,  DateTime createdAt,  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpRequest() when $default != null:
return $default(_that.id,_that.sender,_that.receiver,_that.status,_that.cost,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  UserSummary sender,  UserSummary receiver,  BondRequestStatus status,  int cost,  DateTime createdAt,  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _CpRequest():
return $default(_that.id,_that.sender,_that.receiver,_that.status,_that.cost,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  UserSummary sender,  UserSummary receiver,  BondRequestStatus status,  int cost,  DateTime createdAt,  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _CpRequest() when $default != null:
return $default(_that.id,_that.sender,_that.receiver,_that.status,_that.cost,_that.createdAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpRequest implements CpRequest {
  const _CpRequest({required this.id, required this.sender, required this.receiver, required this.status, required this.cost, required this.createdAt, required this.expiresAt});
  factory _CpRequest.fromJson(Map<String, dynamic> json) => _$CpRequestFromJson(json);

@override final  String id;
@override final  UserSummary sender;
@override final  UserSummary receiver;
@override final  BondRequestStatus status;
@override final  int cost;
@override final  DateTime createdAt;
@override final  DateTime expiresAt;

/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpRequestCopyWith<_CpRequest> get copyWith => __$CpRequestCopyWithImpl<_CpRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.receiver, receiver) || other.receiver == receiver)&&(identical(other.status, status) || other.status == status)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sender,receiver,status,cost,createdAt,expiresAt);
}

@override
String toString() {
    return 'CpRequest(id: $id, sender: $sender, receiver: $receiver, status: $status, cost: $cost, createdAt: $createdAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$CpRequestCopyWith<$Res> implements $CpRequestCopyWith<$Res> {
  factory _$CpRequestCopyWith(_CpRequest value, $Res Function(_CpRequest) _then) = __$CpRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, UserSummary sender, UserSummary receiver, BondRequestStatus status, int cost, DateTime createdAt, DateTime expiresAt
});


@override $UserSummaryCopyWith<$Res> get sender;@override $UserSummaryCopyWith<$Res> get receiver;

}
/// @nodoc
class __$CpRequestCopyWithImpl<$Res>
    implements _$CpRequestCopyWith<$Res> {
  __$CpRequestCopyWithImpl(this._self, this._then);

  final _CpRequest _self;
  final $Res Function(_CpRequest) _then;

/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sender = null,Object? receiver = null,Object? status = null,Object? cost = null,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(_CpRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,receiver: null == receiver ? _self.receiver : receiver // ignore: cast_nullable_to_non_nullable
as UserSummary,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BondRequestStatus,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of CpRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get receiver {
  
  return $UserSummaryCopyWith<$Res>(_self.receiver, (value) {
    return _then(_self.copyWith(receiver: value));
  });
}
}


/// @nodoc
mixin _$CpRequestPage {

 List<CpRequest> get data; PageInfo get page;
/// Create a copy of CpRequestPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpRequestPageCopyWith<CpRequestPage> get copyWith => _$CpRequestPageCopyWithImpl<CpRequestPage>(this as CpRequestPage, _$identity);

  /// Serializes this CpRequestPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CpRequestPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpRequestPage&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CpRequestPage;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.page);
}

@override
String toString() {
  final _this = this as CpRequestPage;
  return 'CpRequestPage(data: ${_this.data}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $CpRequestPageCopyWith<$Res>  {
  factory $CpRequestPageCopyWith(CpRequestPage value, $Res Function(CpRequestPage) _then) = _$CpRequestPageCopyWithImpl;
@useResult
$Res call({
 List<CpRequest> data, PageInfo page
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$CpRequestPageCopyWithImpl<$Res>
    implements $CpRequestPageCopyWith<$Res> {
  _$CpRequestPageCopyWithImpl(this._self, this._then);

  final CpRequestPage _self;
  final $Res Function(CpRequestPage) _then;

/// Create a copy of CpRequestPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,}) {
  return _then(CpRequestPage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CpRequest>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}
/// Create a copy of CpRequestPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [CpRequestPage].
extension CpRequestPagePatterns on CpRequestPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpRequestPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpRequestPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpRequestPage value)  $default,){
final _that = this;
switch (_that) {
case _CpRequestPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpRequestPage value)?  $default,){
final _that = this;
switch (_that) {
case _CpRequestPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CpRequest> data,  PageInfo page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpRequestPage() when $default != null:
return $default(_that.data,_that.page);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CpRequest> data,  PageInfo page)  $default,) {final _that = this;
switch (_that) {
case _CpRequestPage():
return $default(_that.data,_that.page);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CpRequest> data,  PageInfo page)?  $default,) {final _that = this;
switch (_that) {
case _CpRequestPage() when $default != null:
return $default(_that.data,_that.page);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpRequestPage implements CpRequestPage {
  const _CpRequestPage({required  List<CpRequest> data, required this.page}): _data = data;
  factory _CpRequestPage.fromJson(Map<String, dynamic> json) => _$CpRequestPageFromJson(json);

 final  List<CpRequest> _data;
@override List<CpRequest> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;

/// Create a copy of CpRequestPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpRequestPageCopyWith<_CpRequestPage> get copyWith => __$CpRequestPageCopyWithImpl<_CpRequestPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpRequestPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpRequestPage&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page);
}

@override
String toString() {
    return 'CpRequestPage(data: $data, page: $page)';
}


}

/// @nodoc
abstract mixin class _$CpRequestPageCopyWith<$Res> implements $CpRequestPageCopyWith<$Res> {
  factory _$CpRequestPageCopyWith(_CpRequestPage value, $Res Function(_CpRequestPage) _then) = __$CpRequestPageCopyWithImpl;
@override @useResult
$Res call({
 List<CpRequest> data, PageInfo page
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$CpRequestPageCopyWithImpl<$Res>
    implements _$CpRequestPageCopyWith<$Res> {
  __$CpRequestPageCopyWithImpl(this._self, this._then);

  final _CpRequestPage _self;
  final $Res Function(_CpRequestPage) _then;

/// Create a copy of CpRequestPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,}) {
  return _then(_CpRequestPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<CpRequest>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}

/// Create a copy of CpRequestPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// @nodoc
mixin _$CpCouple {

 String get id; UserSummary get partner; DateTime get since;/// Days together; the day it was formed is day 1.
 int get days; int get points; int get level; String get levelName; String? get nextLevelName; int? get pointsToNext;
/// Create a copy of CpCouple
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpCoupleCopyWith<CpCouple> get copyWith => _$CpCoupleCopyWithImpl<CpCouple>(this as CpCouple, _$identity);

  /// Serializes this CpCouple to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CpCouple;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpCouple&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.partner, _this.partner) || other.partner == _this.partner)&&(identical(other.since, _this.since) || other.since == _this.since)&&(identical(other.days, _this.days) || other.days == _this.days)&&(identical(other.points, _this.points) || other.points == _this.points)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.levelName, _this.levelName) || other.levelName == _this.levelName)&&(identical(other.nextLevelName, _this.nextLevelName) || other.nextLevelName == _this.nextLevelName)&&(identical(other.pointsToNext, _this.pointsToNext) || other.pointsToNext == _this.pointsToNext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CpCouple;
  return Object.hash(runtimeType,_this.id,_this.partner,_this.since,_this.days,_this.points,_this.level,_this.levelName,_this.nextLevelName,_this.pointsToNext);
}

@override
String toString() {
  final _this = this as CpCouple;
  return 'CpCouple(id: ${_this.id}, partner: ${_this.partner}, since: ${_this.since}, days: ${_this.days}, points: ${_this.points}, level: ${_this.level}, levelName: ${_this.levelName}, nextLevelName: ${_this.nextLevelName}, pointsToNext: ${_this.pointsToNext})';
}


}

/// @nodoc
abstract mixin class $CpCoupleCopyWith<$Res>  {
  factory $CpCoupleCopyWith(CpCouple value, $Res Function(CpCouple) _then) = _$CpCoupleCopyWithImpl;
@useResult
$Res call({
 String id, UserSummary partner, DateTime since, int days, int points, int level, String levelName, String? nextLevelName, int? pointsToNext
});


$UserSummaryCopyWith<$Res> get partner;

}
/// @nodoc
class _$CpCoupleCopyWithImpl<$Res>
    implements $CpCoupleCopyWith<$Res> {
  _$CpCoupleCopyWithImpl(this._self, this._then);

  final CpCouple _self;
  final $Res Function(CpCouple) _then;

/// Create a copy of CpCouple
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? partner = null,Object? since = null,Object? days = null,Object? points = null,Object? level = null,Object? levelName = null,Object? nextLevelName = freezed,Object? pointsToNext = freezed,}) {
  return _then(CpCouple(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,partner: null == partner ? _self.partner : partner // ignore: cast_nullable_to_non_nullable
as UserSummary,since: null == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,nextLevelName: freezed == nextLevelName ? _self.nextLevelName : nextLevelName // ignore: cast_nullable_to_non_nullable
as String?,pointsToNext: freezed == pointsToNext ? _self.pointsToNext : pointsToNext // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of CpCouple
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get partner {
  
  return $UserSummaryCopyWith<$Res>(_self.partner, (value) {
    return _then(_self.copyWith(partner: value));
  });
}
}


/// Adds pattern-matching-related methods to [CpCouple].
extension CpCouplePatterns on CpCouple {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpCouple value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpCouple() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpCouple value)  $default,){
final _that = this;
switch (_that) {
case _CpCouple():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpCouple value)?  $default,){
final _that = this;
switch (_that) {
case _CpCouple() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  UserSummary partner,  DateTime since,  int days,  int points,  int level,  String levelName,  String? nextLevelName,  int? pointsToNext)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpCouple() when $default != null:
return $default(_that.id,_that.partner,_that.since,_that.days,_that.points,_that.level,_that.levelName,_that.nextLevelName,_that.pointsToNext);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  UserSummary partner,  DateTime since,  int days,  int points,  int level,  String levelName,  String? nextLevelName,  int? pointsToNext)  $default,) {final _that = this;
switch (_that) {
case _CpCouple():
return $default(_that.id,_that.partner,_that.since,_that.days,_that.points,_that.level,_that.levelName,_that.nextLevelName,_that.pointsToNext);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  UserSummary partner,  DateTime since,  int days,  int points,  int level,  String levelName,  String? nextLevelName,  int? pointsToNext)?  $default,) {final _that = this;
switch (_that) {
case _CpCouple() when $default != null:
return $default(_that.id,_that.partner,_that.since,_that.days,_that.points,_that.level,_that.levelName,_that.nextLevelName,_that.pointsToNext);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpCouple implements CpCouple {
  const _CpCouple({required this.id, required this.partner, required this.since, required this.days, required this.points, required this.level, required this.levelName, required this.nextLevelName, required this.pointsToNext});
  factory _CpCouple.fromJson(Map<String, dynamic> json) => _$CpCoupleFromJson(json);

@override final  String id;
@override final  UserSummary partner;
@override final  DateTime since;
/// Days together; the day it was formed is day 1.
@override final  int days;
@override final  int points;
@override final  int level;
@override final  String levelName;
@override final  String? nextLevelName;
@override final  int? pointsToNext;

/// Create a copy of CpCouple
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpCoupleCopyWith<_CpCouple> get copyWith => __$CpCoupleCopyWithImpl<_CpCouple>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpCoupleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpCouple&&(identical(other.id, id) || other.id == id)&&(identical(other.partner, partner) || other.partner == partner)&&(identical(other.since, since) || other.since == since)&&(identical(other.days, days) || other.days == days)&&(identical(other.points, points) || other.points == points)&&(identical(other.level, level) || other.level == level)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.nextLevelName, nextLevelName) || other.nextLevelName == nextLevelName)&&(identical(other.pointsToNext, pointsToNext) || other.pointsToNext == pointsToNext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,partner,since,days,points,level,levelName,nextLevelName,pointsToNext);
}

@override
String toString() {
    return 'CpCouple(id: $id, partner: $partner, since: $since, days: $days, points: $points, level: $level, levelName: $levelName, nextLevelName: $nextLevelName, pointsToNext: $pointsToNext)';
}


}

/// @nodoc
abstract mixin class _$CpCoupleCopyWith<$Res> implements $CpCoupleCopyWith<$Res> {
  factory _$CpCoupleCopyWith(_CpCouple value, $Res Function(_CpCouple) _then) = __$CpCoupleCopyWithImpl;
@override @useResult
$Res call({
 String id, UserSummary partner, DateTime since, int days, int points, int level, String levelName, String? nextLevelName, int? pointsToNext
});


@override $UserSummaryCopyWith<$Res> get partner;

}
/// @nodoc
class __$CpCoupleCopyWithImpl<$Res>
    implements _$CpCoupleCopyWith<$Res> {
  __$CpCoupleCopyWithImpl(this._self, this._then);

  final _CpCouple _self;
  final $Res Function(_CpCouple) _then;

/// Create a copy of CpCouple
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? partner = null,Object? since = null,Object? days = null,Object? points = null,Object? level = null,Object? levelName = null,Object? nextLevelName = freezed,Object? pointsToNext = freezed,}) {
  return _then(_CpCouple(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,partner: null == partner ? _self.partner : partner // ignore: cast_nullable_to_non_nullable
as UserSummary,since: null == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,nextLevelName: freezed == nextLevelName ? _self.nextLevelName : nextLevelName // ignore: cast_nullable_to_non_nullable
as String?,pointsToNext: freezed == pointsToNext ? _self.pointsToNext : pointsToNext // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of CpCouple
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get partner {
  
  return $UserSummaryCopyWith<$Res>(_self.partner, (value) {
    return _then(_self.copyWith(partner: value));
  });
}
}


/// @nodoc
mixin _$CpGift {

 String get id; int get amount; DateTime get createdAt;
/// Create a copy of CpGift
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CpGiftCopyWith<CpGift> get copyWith => _$CpGiftCopyWithImpl<CpGift>(this as CpGift, _$identity);

  /// Serializes this CpGift to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CpGift;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CpGift&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CpGift;
  return Object.hash(runtimeType,_this.id,_this.amount,_this.createdAt);
}

@override
String toString() {
  final _this = this as CpGift;
  return 'CpGift(id: ${_this.id}, amount: ${_this.amount}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $CpGiftCopyWith<$Res>  {
  factory $CpGiftCopyWith(CpGift value, $Res Function(CpGift) _then) = _$CpGiftCopyWithImpl;
@useResult
$Res call({
 String id, int amount, DateTime createdAt
});




}
/// @nodoc
class _$CpGiftCopyWithImpl<$Res>
    implements $CpGiftCopyWith<$Res> {
  _$CpGiftCopyWithImpl(this._self, this._then);

  final CpGift _self;
  final $Res Function(CpGift) _then;

/// Create a copy of CpGift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? amount = null,Object? createdAt = null,}) {
  return _then(CpGift(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [CpGift].
extension CpGiftPatterns on CpGift {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CpGift value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CpGift() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CpGift value)  $default,){
final _that = this;
switch (_that) {
case _CpGift():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CpGift value)?  $default,){
final _that = this;
switch (_that) {
case _CpGift() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int amount,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CpGift() when $default != null:
return $default(_that.id,_that.amount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int amount,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _CpGift():
return $default(_that.id,_that.amount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int amount,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _CpGift() when $default != null:
return $default(_that.id,_that.amount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CpGift implements CpGift {
  const _CpGift({required this.id, required this.amount, required this.createdAt});
  factory _CpGift.fromJson(Map<String, dynamic> json) => _$CpGiftFromJson(json);

@override final  String id;
@override final  int amount;
@override final  DateTime createdAt;

/// Create a copy of CpGift
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CpGiftCopyWith<_CpGift> get copyWith => __$CpGiftCopyWithImpl<_CpGift>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CpGiftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CpGift&&(identical(other.id, id) || other.id == id)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,amount,createdAt);
}

@override
String toString() {
    return 'CpGift(id: $id, amount: $amount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CpGiftCopyWith<$Res> implements $CpGiftCopyWith<$Res> {
  factory _$CpGiftCopyWith(_CpGift value, $Res Function(_CpGift) _then) = __$CpGiftCopyWithImpl;
@override @useResult
$Res call({
 String id, int amount, DateTime createdAt
});




}
/// @nodoc
class __$CpGiftCopyWithImpl<$Res>
    implements _$CpGiftCopyWith<$Res> {
  __$CpGiftCopyWithImpl(this._self, this._then);

  final _CpGift _self;
  final $Res Function(_CpGift) _then;

/// Create a copy of CpGift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? amount = null,Object? createdAt = null,}) {
  return _then(_CpGift(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$ProfileCp {

 UserSummary get partner; DateTime get since; int get level; String get levelName; int get points;
/// Create a copy of ProfileCp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCpCopyWith<ProfileCp> get copyWith => _$ProfileCpCopyWithImpl<ProfileCp>(this as ProfileCp, _$identity);

  /// Serializes this ProfileCp to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileCp;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileCp&&(identical(other.partner, _this.partner) || other.partner == _this.partner)&&(identical(other.since, _this.since) || other.since == _this.since)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.levelName, _this.levelName) || other.levelName == _this.levelName)&&(identical(other.points, _this.points) || other.points == _this.points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileCp;
  return Object.hash(runtimeType,_this.partner,_this.since,_this.level,_this.levelName,_this.points);
}

@override
String toString() {
  final _this = this as ProfileCp;
  return 'ProfileCp(partner: ${_this.partner}, since: ${_this.since}, level: ${_this.level}, levelName: ${_this.levelName}, points: ${_this.points})';
}


}

/// @nodoc
abstract mixin class $ProfileCpCopyWith<$Res>  {
  factory $ProfileCpCopyWith(ProfileCp value, $Res Function(ProfileCp) _then) = _$ProfileCpCopyWithImpl;
@useResult
$Res call({
 UserSummary partner, DateTime since, int level, String levelName, int points
});


$UserSummaryCopyWith<$Res> get partner;

}
/// @nodoc
class _$ProfileCpCopyWithImpl<$Res>
    implements $ProfileCpCopyWith<$Res> {
  _$ProfileCpCopyWithImpl(this._self, this._then);

  final ProfileCp _self;
  final $Res Function(ProfileCp) _then;

/// Create a copy of ProfileCp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? partner = null,Object? since = null,Object? level = null,Object? levelName = null,Object? points = null,}) {
  return _then(ProfileCp(
partner: null == partner ? _self.partner : partner // ignore: cast_nullable_to_non_nullable
as UserSummary,since: null == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ProfileCp
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get partner {
  
  return $UserSummaryCopyWith<$Res>(_self.partner, (value) {
    return _then(_self.copyWith(partner: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileCp].
extension ProfileCpPatterns on ProfileCp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileCp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileCp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileCp value)  $default,){
final _that = this;
switch (_that) {
case _ProfileCp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileCp value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileCp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary partner,  DateTime since,  int level,  String levelName,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileCp() when $default != null:
return $default(_that.partner,_that.since,_that.level,_that.levelName,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary partner,  DateTime since,  int level,  String levelName,  int points)  $default,) {final _that = this;
switch (_that) {
case _ProfileCp():
return $default(_that.partner,_that.since,_that.level,_that.levelName,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary partner,  DateTime since,  int level,  String levelName,  int points)?  $default,) {final _that = this;
switch (_that) {
case _ProfileCp() when $default != null:
return $default(_that.partner,_that.since,_that.level,_that.levelName,_that.points);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileCp implements ProfileCp {
  const _ProfileCp({required this.partner, required this.since, required this.level, required this.levelName, required this.points});
  factory _ProfileCp.fromJson(Map<String, dynamic> json) => _$ProfileCpFromJson(json);

@override final  UserSummary partner;
@override final  DateTime since;
@override final  int level;
@override final  String levelName;
@override final  int points;

/// Create a copy of ProfileCp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCpCopyWith<_ProfileCp> get copyWith => __$ProfileCpCopyWithImpl<_ProfileCp>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileCpToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileCp&&(identical(other.partner, partner) || other.partner == partner)&&(identical(other.since, since) || other.since == since)&&(identical(other.level, level) || other.level == level)&&(identical(other.levelName, levelName) || other.levelName == levelName)&&(identical(other.points, points) || other.points == points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,partner,since,level,levelName,points);
}

@override
String toString() {
    return 'ProfileCp(partner: $partner, since: $since, level: $level, levelName: $levelName, points: $points)';
}


}

/// @nodoc
abstract mixin class _$ProfileCpCopyWith<$Res> implements $ProfileCpCopyWith<$Res> {
  factory _$ProfileCpCopyWith(_ProfileCp value, $Res Function(_ProfileCp) _then) = __$ProfileCpCopyWithImpl;
@override @useResult
$Res call({
 UserSummary partner, DateTime since, int level, String levelName, int points
});


@override $UserSummaryCopyWith<$Res> get partner;

}
/// @nodoc
class __$ProfileCpCopyWithImpl<$Res>
    implements _$ProfileCpCopyWith<$Res> {
  __$ProfileCpCopyWithImpl(this._self, this._then);

  final _ProfileCp _self;
  final $Res Function(_ProfileCp) _then;

/// Create a copy of ProfileCp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? partner = null,Object? since = null,Object? level = null,Object? levelName = null,Object? points = null,}) {
  return _then(_ProfileCp(
partner: null == partner ? _self.partner : partner // ignore: cast_nullable_to_non_nullable
as UserSummary,since: null == since ? _self.since : since // ignore: cast_nullable_to_non_nullable
as DateTime,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,levelName: null == levelName ? _self.levelName : levelName // ignore: cast_nullable_to_non_nullable
as String,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ProfileCp
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get partner {
  
  return $UserSummaryCopyWith<$Res>(_self.partner, (value) {
    return _then(_self.copyWith(partner: value));
  });
}
}

// dart format on
