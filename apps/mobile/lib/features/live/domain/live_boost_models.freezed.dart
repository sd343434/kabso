// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_boost_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveBoost {

 String get id; String get roomId; UserSummary get host; UserSummary get buyer; int get minutes;@JsonKey(unknownEnumValue: LiveBoostSource.coins) LiveBoostSource get source; int get coinsCharged;@JsonKey(unknownEnumValue: LiveBoostState.done) LiveBoostState get state; DateTime get startsAt; DateTime get endsAt; DateTime get createdAt;
/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBoostCopyWith<LiveBoost> get copyWith => _$LiveBoostCopyWithImpl<LiveBoost>(this as LiveBoost, _$identity);

  /// Serializes this LiveBoost to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBoost;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBoost&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.buyer, _this.buyer) || other.buyer == _this.buyer)&&(identical(other.minutes, _this.minutes) || other.minutes == _this.minutes)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.coinsCharged, _this.coinsCharged) || other.coinsCharged == _this.coinsCharged)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBoost;
  return Object.hash(runtimeType,_this.id,_this.roomId,_this.host,_this.buyer,_this.minutes,_this.source,_this.coinsCharged,_this.state,_this.startsAt,_this.endsAt,_this.createdAt);
}

@override
String toString() {
  final _this = this as LiveBoost;
  return 'LiveBoost(id: ${_this.id}, roomId: ${_this.roomId}, host: ${_this.host}, buyer: ${_this.buyer}, minutes: ${_this.minutes}, source: ${_this.source}, coinsCharged: ${_this.coinsCharged}, state: ${_this.state}, startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LiveBoostCopyWith<$Res>  {
  factory $LiveBoostCopyWith(LiveBoost value, $Res Function(LiveBoost) _then) = _$LiveBoostCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, UserSummary host, UserSummary buyer, int minutes,@JsonKey(unknownEnumValue: LiveBoostSource.coins) LiveBoostSource source, int coinsCharged,@JsonKey(unknownEnumValue: LiveBoostState.done) LiveBoostState state, DateTime startsAt, DateTime endsAt, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get host;$UserSummaryCopyWith<$Res> get buyer;

}
/// @nodoc
class _$LiveBoostCopyWithImpl<$Res>
    implements $LiveBoostCopyWith<$Res> {
  _$LiveBoostCopyWithImpl(this._self, this._then);

  final LiveBoost _self;
  final $Res Function(LiveBoost) _then;

/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? host = null,Object? buyer = null,Object? minutes = null,Object? source = null,Object? coinsCharged = null,Object? state = null,Object? startsAt = null,Object? endsAt = null,Object? createdAt = null,}) {
  return _then(LiveBoost(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,buyer: null == buyer ? _self.buyer : buyer // ignore: cast_nullable_to_non_nullable
as UserSummary,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveBoostSource,coinsCharged: null == coinsCharged ? _self.coinsCharged : coinsCharged // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveBoostState,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get buyer {
  
  return $UserSummaryCopyWith<$Res>(_self.buyer, (value) {
    return _then(_self.copyWith(buyer: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveBoost].
extension LiveBoostPatterns on LiveBoost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBoost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBoost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBoost value)  $default,){
final _that = this;
switch (_that) {
case _LiveBoost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBoost value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBoost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  UserSummary host,  UserSummary buyer,  int minutes, @JsonKey(unknownEnumValue: LiveBoostSource.coins)  LiveBoostSource source,  int coinsCharged, @JsonKey(unknownEnumValue: LiveBoostState.done)  LiveBoostState state,  DateTime startsAt,  DateTime endsAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBoost() when $default != null:
return $default(_that.id,_that.roomId,_that.host,_that.buyer,_that.minutes,_that.source,_that.coinsCharged,_that.state,_that.startsAt,_that.endsAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  UserSummary host,  UserSummary buyer,  int minutes, @JsonKey(unknownEnumValue: LiveBoostSource.coins)  LiveBoostSource source,  int coinsCharged, @JsonKey(unknownEnumValue: LiveBoostState.done)  LiveBoostState state,  DateTime startsAt,  DateTime endsAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LiveBoost():
return $default(_that.id,_that.roomId,_that.host,_that.buyer,_that.minutes,_that.source,_that.coinsCharged,_that.state,_that.startsAt,_that.endsAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  UserSummary host,  UserSummary buyer,  int minutes, @JsonKey(unknownEnumValue: LiveBoostSource.coins)  LiveBoostSource source,  int coinsCharged, @JsonKey(unknownEnumValue: LiveBoostState.done)  LiveBoostState state,  DateTime startsAt,  DateTime endsAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveBoost() when $default != null:
return $default(_that.id,_that.roomId,_that.host,_that.buyer,_that.minutes,_that.source,_that.coinsCharged,_that.state,_that.startsAt,_that.endsAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBoost implements LiveBoost {
  const _LiveBoost({required this.id, required this.roomId, required this.host, required this.buyer, required this.minutes, @JsonKey(unknownEnumValue: LiveBoostSource.coins) required this.source, required this.coinsCharged, @JsonKey(unknownEnumValue: LiveBoostState.done) required this.state, required this.startsAt, required this.endsAt, required this.createdAt});
  factory _LiveBoost.fromJson(Map<String, dynamic> json) => _$LiveBoostFromJson(json);

@override final  String id;
@override final  String roomId;
@override final  UserSummary host;
@override final  UserSummary buyer;
@override final  int minutes;
@override@JsonKey(unknownEnumValue: LiveBoostSource.coins) final  LiveBoostSource source;
@override final  int coinsCharged;
@override@JsonKey(unknownEnumValue: LiveBoostState.done) final  LiveBoostState state;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  DateTime createdAt;

/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBoostCopyWith<_LiveBoost> get copyWith => __$LiveBoostCopyWithImpl<_LiveBoost>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBoostToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBoost&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.host, host) || other.host == host)&&(identical(other.buyer, buyer) || other.buyer == buyer)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.source, source) || other.source == source)&&(identical(other.coinsCharged, coinsCharged) || other.coinsCharged == coinsCharged)&&(identical(other.state, state) || other.state == state)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,roomId,host,buyer,minutes,source,coinsCharged,state,startsAt,endsAt,createdAt);
}

@override
String toString() {
    return 'LiveBoost(id: $id, roomId: $roomId, host: $host, buyer: $buyer, minutes: $minutes, source: $source, coinsCharged: $coinsCharged, state: $state, startsAt: $startsAt, endsAt: $endsAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LiveBoostCopyWith<$Res> implements $LiveBoostCopyWith<$Res> {
  factory _$LiveBoostCopyWith(_LiveBoost value, $Res Function(_LiveBoost) _then) = __$LiveBoostCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, UserSummary host, UserSummary buyer, int minutes,@JsonKey(unknownEnumValue: LiveBoostSource.coins) LiveBoostSource source, int coinsCharged,@JsonKey(unknownEnumValue: LiveBoostState.done) LiveBoostState state, DateTime startsAt, DateTime endsAt, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get host;@override $UserSummaryCopyWith<$Res> get buyer;

}
/// @nodoc
class __$LiveBoostCopyWithImpl<$Res>
    implements _$LiveBoostCopyWith<$Res> {
  __$LiveBoostCopyWithImpl(this._self, this._then);

  final _LiveBoost _self;
  final $Res Function(_LiveBoost) _then;

/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? host = null,Object? buyer = null,Object? minutes = null,Object? source = null,Object? coinsCharged = null,Object? state = null,Object? startsAt = null,Object? endsAt = null,Object? createdAt = null,}) {
  return _then(_LiveBoost(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,buyer: null == buyer ? _self.buyer : buyer // ignore: cast_nullable_to_non_nullable
as UserSummary,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveBoostSource,coinsCharged: null == coinsCharged ? _self.coinsCharged : coinsCharged // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveBoostState,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of LiveBoost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get buyer {
  
  return $UserSummaryCopyWith<$Res>(_self.buyer, (value) {
    return _then(_self.copyWith(buyer: value));
  });
}
}


/// @nodoc
mixin _$LiveBoostOption {

 int get minutes; int get priceCoins; int get savePercent;
/// Create a copy of LiveBoostOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBoostOptionCopyWith<LiveBoostOption> get copyWith => _$LiveBoostOptionCopyWithImpl<LiveBoostOption>(this as LiveBoostOption, _$identity);

  /// Serializes this LiveBoostOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBoostOption;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBoostOption&&(identical(other.minutes, _this.minutes) || other.minutes == _this.minutes)&&(identical(other.priceCoins, _this.priceCoins) || other.priceCoins == _this.priceCoins)&&(identical(other.savePercent, _this.savePercent) || other.savePercent == _this.savePercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBoostOption;
  return Object.hash(runtimeType,_this.minutes,_this.priceCoins,_this.savePercent);
}

@override
String toString() {
  final _this = this as LiveBoostOption;
  return 'LiveBoostOption(minutes: ${_this.minutes}, priceCoins: ${_this.priceCoins}, savePercent: ${_this.savePercent})';
}


}

/// @nodoc
abstract mixin class $LiveBoostOptionCopyWith<$Res>  {
  factory $LiveBoostOptionCopyWith(LiveBoostOption value, $Res Function(LiveBoostOption) _then) = _$LiveBoostOptionCopyWithImpl;
@useResult
$Res call({
 int minutes, int priceCoins, int savePercent
});




}
/// @nodoc
class _$LiveBoostOptionCopyWithImpl<$Res>
    implements $LiveBoostOptionCopyWith<$Res> {
  _$LiveBoostOptionCopyWithImpl(this._self, this._then);

  final LiveBoostOption _self;
  final $Res Function(LiveBoostOption) _then;

/// Create a copy of LiveBoostOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minutes = null,Object? priceCoins = null,Object? savePercent = null,}) {
  return _then(LiveBoostOption(
minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,priceCoins: null == priceCoins ? _self.priceCoins : priceCoins // ignore: cast_nullable_to_non_nullable
as int,savePercent: null == savePercent ? _self.savePercent : savePercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveBoostOption].
extension LiveBoostOptionPatterns on LiveBoostOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBoostOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBoostOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBoostOption value)  $default,){
final _that = this;
switch (_that) {
case _LiveBoostOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBoostOption value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBoostOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int minutes,  int priceCoins,  int savePercent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBoostOption() when $default != null:
return $default(_that.minutes,_that.priceCoins,_that.savePercent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int minutes,  int priceCoins,  int savePercent)  $default,) {final _that = this;
switch (_that) {
case _LiveBoostOption():
return $default(_that.minutes,_that.priceCoins,_that.savePercent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int minutes,  int priceCoins,  int savePercent)?  $default,) {final _that = this;
switch (_that) {
case _LiveBoostOption() when $default != null:
return $default(_that.minutes,_that.priceCoins,_that.savePercent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBoostOption implements LiveBoostOption {
  const _LiveBoostOption({required this.minutes, required this.priceCoins, required this.savePercent});
  factory _LiveBoostOption.fromJson(Map<String, dynamic> json) => _$LiveBoostOptionFromJson(json);

@override final  int minutes;
@override final  int priceCoins;
@override final  int savePercent;

/// Create a copy of LiveBoostOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBoostOptionCopyWith<_LiveBoostOption> get copyWith => __$LiveBoostOptionCopyWithImpl<_LiveBoostOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBoostOptionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBoostOption&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.priceCoins, priceCoins) || other.priceCoins == priceCoins)&&(identical(other.savePercent, savePercent) || other.savePercent == savePercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,minutes,priceCoins,savePercent);
}

@override
String toString() {
    return 'LiveBoostOption(minutes: $minutes, priceCoins: $priceCoins, savePercent: $savePercent)';
}


}

/// @nodoc
abstract mixin class _$LiveBoostOptionCopyWith<$Res> implements $LiveBoostOptionCopyWith<$Res> {
  factory _$LiveBoostOptionCopyWith(_LiveBoostOption value, $Res Function(_LiveBoostOption) _then) = __$LiveBoostOptionCopyWithImpl;
@override @useResult
$Res call({
 int minutes, int priceCoins, int savePercent
});




}
/// @nodoc
class __$LiveBoostOptionCopyWithImpl<$Res>
    implements _$LiveBoostOptionCopyWith<$Res> {
  __$LiveBoostOptionCopyWithImpl(this._self, this._then);

  final _LiveBoostOption _self;
  final $Res Function(_LiveBoostOption) _then;

/// Create a copy of LiveBoostOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minutes = null,Object? priceCoins = null,Object? savePercent = null,}) {
  return _then(_LiveBoostOption(
minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,priceCoins: null == priceCoins ? _self.priceCoins : priceCoins // ignore: cast_nullable_to_non_nullable
as int,savePercent: null == savePercent ? _self.savePercent : savePercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LiveBoostCardStock {

 int get minutes; int get quantity;
/// Create a copy of LiveBoostCardStock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBoostCardStockCopyWith<LiveBoostCardStock> get copyWith => _$LiveBoostCardStockCopyWithImpl<LiveBoostCardStock>(this as LiveBoostCardStock, _$identity);

  /// Serializes this LiveBoostCardStock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBoostCardStock;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBoostCardStock&&(identical(other.minutes, _this.minutes) || other.minutes == _this.minutes)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBoostCardStock;
  return Object.hash(runtimeType,_this.minutes,_this.quantity);
}

@override
String toString() {
  final _this = this as LiveBoostCardStock;
  return 'LiveBoostCardStock(minutes: ${_this.minutes}, quantity: ${_this.quantity})';
}


}

/// @nodoc
abstract mixin class $LiveBoostCardStockCopyWith<$Res>  {
  factory $LiveBoostCardStockCopyWith(LiveBoostCardStock value, $Res Function(LiveBoostCardStock) _then) = _$LiveBoostCardStockCopyWithImpl;
@useResult
$Res call({
 int minutes, int quantity
});




}
/// @nodoc
class _$LiveBoostCardStockCopyWithImpl<$Res>
    implements $LiveBoostCardStockCopyWith<$Res> {
  _$LiveBoostCardStockCopyWithImpl(this._self, this._then);

  final LiveBoostCardStock _self;
  final $Res Function(LiveBoostCardStock) _then;

/// Create a copy of LiveBoostCardStock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minutes = null,Object? quantity = null,}) {
  return _then(LiveBoostCardStock(
minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveBoostCardStock].
extension LiveBoostCardStockPatterns on LiveBoostCardStock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBoostCardStock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBoostCardStock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBoostCardStock value)  $default,){
final _that = this;
switch (_that) {
case _LiveBoostCardStock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBoostCardStock value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBoostCardStock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int minutes,  int quantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBoostCardStock() when $default != null:
return $default(_that.minutes,_that.quantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int minutes,  int quantity)  $default,) {final _that = this;
switch (_that) {
case _LiveBoostCardStock():
return $default(_that.minutes,_that.quantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int minutes,  int quantity)?  $default,) {final _that = this;
switch (_that) {
case _LiveBoostCardStock() when $default != null:
return $default(_that.minutes,_that.quantity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBoostCardStock implements LiveBoostCardStock {
  const _LiveBoostCardStock({required this.minutes, required this.quantity});
  factory _LiveBoostCardStock.fromJson(Map<String, dynamic> json) => _$LiveBoostCardStockFromJson(json);

@override final  int minutes;
@override final  int quantity;

/// Create a copy of LiveBoostCardStock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBoostCardStockCopyWith<_LiveBoostCardStock> get copyWith => __$LiveBoostCardStockCopyWithImpl<_LiveBoostCardStock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBoostCardStockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBoostCardStock&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,minutes,quantity);
}

@override
String toString() {
    return 'LiveBoostCardStock(minutes: $minutes, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class _$LiveBoostCardStockCopyWith<$Res> implements $LiveBoostCardStockCopyWith<$Res> {
  factory _$LiveBoostCardStockCopyWith(_LiveBoostCardStock value, $Res Function(_LiveBoostCardStock) _then) = __$LiveBoostCardStockCopyWithImpl;
@override @useResult
$Res call({
 int minutes, int quantity
});




}
/// @nodoc
class __$LiveBoostCardStockCopyWithImpl<$Res>
    implements _$LiveBoostCardStockCopyWith<$Res> {
  __$LiveBoostCardStockCopyWithImpl(this._self, this._then);

  final _LiveBoostCardStock _self;
  final $Res Function(_LiveBoostCardStock) _then;

/// Create a copy of LiveBoostCardStock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minutes = null,Object? quantity = null,}) {
  return _then(_LiveBoostCardStock(
minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LiveBoostOffers {

 int get slots; int get maxWaitMinutes; List<LiveBoostOption> get options; List<LiveBoostCardStock> get cards; DateTime get nextStartAt; LiveBoost? get roomBoost;
/// Create a copy of LiveBoostOffers
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBoostOffersCopyWith<LiveBoostOffers> get copyWith => _$LiveBoostOffersCopyWithImpl<LiveBoostOffers>(this as LiveBoostOffers, _$identity);

  /// Serializes this LiveBoostOffers to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBoostOffers;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBoostOffers&&(identical(other.slots, _this.slots) || other.slots == _this.slots)&&(identical(other.maxWaitMinutes, _this.maxWaitMinutes) || other.maxWaitMinutes == _this.maxWaitMinutes)&&const DeepCollectionEquality().equals(other.options, _this.options)&&const DeepCollectionEquality().equals(other.cards, _this.cards)&&(identical(other.nextStartAt, _this.nextStartAt) || other.nextStartAt == _this.nextStartAt)&&(identical(other.roomBoost, _this.roomBoost) || other.roomBoost == _this.roomBoost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBoostOffers;
  return Object.hash(runtimeType,_this.slots,_this.maxWaitMinutes,const DeepCollectionEquality().hash(_this.options),const DeepCollectionEquality().hash(_this.cards),_this.nextStartAt,_this.roomBoost);
}

@override
String toString() {
  final _this = this as LiveBoostOffers;
  return 'LiveBoostOffers(slots: ${_this.slots}, maxWaitMinutes: ${_this.maxWaitMinutes}, options: ${_this.options}, cards: ${_this.cards}, nextStartAt: ${_this.nextStartAt}, roomBoost: ${_this.roomBoost})';
}


}

/// @nodoc
abstract mixin class $LiveBoostOffersCopyWith<$Res>  {
  factory $LiveBoostOffersCopyWith(LiveBoostOffers value, $Res Function(LiveBoostOffers) _then) = _$LiveBoostOffersCopyWithImpl;
@useResult
$Res call({
 int slots, int maxWaitMinutes, List<LiveBoostOption> options, List<LiveBoostCardStock> cards, DateTime nextStartAt, LiveBoost? roomBoost
});


$LiveBoostCopyWith<$Res>? get roomBoost;

}
/// @nodoc
class _$LiveBoostOffersCopyWithImpl<$Res>
    implements $LiveBoostOffersCopyWith<$Res> {
  _$LiveBoostOffersCopyWithImpl(this._self, this._then);

  final LiveBoostOffers _self;
  final $Res Function(LiveBoostOffers) _then;

/// Create a copy of LiveBoostOffers
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slots = null,Object? maxWaitMinutes = null,Object? options = null,Object? cards = null,Object? nextStartAt = null,Object? roomBoost = freezed,}) {
  return _then(LiveBoostOffers(
slots: null == slots ? _self.slots : slots // ignore: cast_nullable_to_non_nullable
as int,maxWaitMinutes: null == maxWaitMinutes ? _self.maxWaitMinutes : maxWaitMinutes // ignore: cast_nullable_to_non_nullable
as int,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<LiveBoostOption>,cards: null == cards ? _self.cards : cards // ignore: cast_nullable_to_non_nullable
as List<LiveBoostCardStock>,nextStartAt: null == nextStartAt ? _self.nextStartAt : nextStartAt // ignore: cast_nullable_to_non_nullable
as DateTime,roomBoost: freezed == roomBoost ? _self.roomBoost : roomBoost // ignore: cast_nullable_to_non_nullable
as LiveBoost?,
  ));
}
/// Create a copy of LiveBoostOffers
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveBoostCopyWith<$Res>? get roomBoost {
    if (_self.roomBoost == null) {
    return null;
  }

  return $LiveBoostCopyWith<$Res>(_self.roomBoost!, (value) {
    return _then(_self.copyWith(roomBoost: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveBoostOffers].
extension LiveBoostOffersPatterns on LiveBoostOffers {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBoostOffers value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBoostOffers() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBoostOffers value)  $default,){
final _that = this;
switch (_that) {
case _LiveBoostOffers():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBoostOffers value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBoostOffers() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int slots,  int maxWaitMinutes,  List<LiveBoostOption> options,  List<LiveBoostCardStock> cards,  DateTime nextStartAt,  LiveBoost? roomBoost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBoostOffers() when $default != null:
return $default(_that.slots,_that.maxWaitMinutes,_that.options,_that.cards,_that.nextStartAt,_that.roomBoost);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int slots,  int maxWaitMinutes,  List<LiveBoostOption> options,  List<LiveBoostCardStock> cards,  DateTime nextStartAt,  LiveBoost? roomBoost)  $default,) {final _that = this;
switch (_that) {
case _LiveBoostOffers():
return $default(_that.slots,_that.maxWaitMinutes,_that.options,_that.cards,_that.nextStartAt,_that.roomBoost);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int slots,  int maxWaitMinutes,  List<LiveBoostOption> options,  List<LiveBoostCardStock> cards,  DateTime nextStartAt,  LiveBoost? roomBoost)?  $default,) {final _that = this;
switch (_that) {
case _LiveBoostOffers() when $default != null:
return $default(_that.slots,_that.maxWaitMinutes,_that.options,_that.cards,_that.nextStartAt,_that.roomBoost);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBoostOffers implements LiveBoostOffers {
  const _LiveBoostOffers({required this.slots, required this.maxWaitMinutes, required  List<LiveBoostOption> options, required  List<LiveBoostCardStock> cards, required this.nextStartAt, this.roomBoost}): _options = options,_cards = cards;
  factory _LiveBoostOffers.fromJson(Map<String, dynamic> json) => _$LiveBoostOffersFromJson(json);

@override final  int slots;
@override final  int maxWaitMinutes;
 final  List<LiveBoostOption> _options;
@override List<LiveBoostOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

 final  List<LiveBoostCardStock> _cards;
@override List<LiveBoostCardStock> get cards {
  if (_cards is EqualUnmodifiableListView) return _cards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cards);
}

@override final  DateTime nextStartAt;
@override final  LiveBoost? roomBoost;

/// Create a copy of LiveBoostOffers
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBoostOffersCopyWith<_LiveBoostOffers> get copyWith => __$LiveBoostOffersCopyWithImpl<_LiveBoostOffers>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBoostOffersToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBoostOffers&&(identical(other.slots, slots) || other.slots == slots)&&(identical(other.maxWaitMinutes, maxWaitMinutes) || other.maxWaitMinutes == maxWaitMinutes)&&const DeepCollectionEquality().equals(other.options, _options)&&const DeepCollectionEquality().equals(other.cards, _cards)&&(identical(other.nextStartAt, nextStartAt) || other.nextStartAt == nextStartAt)&&(identical(other.roomBoost, roomBoost) || other.roomBoost == roomBoost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,slots,maxWaitMinutes,const DeepCollectionEquality().hash(_options),const DeepCollectionEquality().hash(_cards),nextStartAt,roomBoost);
}

@override
String toString() {
    return 'LiveBoostOffers(slots: $slots, maxWaitMinutes: $maxWaitMinutes, options: $options, cards: $cards, nextStartAt: $nextStartAt, roomBoost: $roomBoost)';
}


}

/// @nodoc
abstract mixin class _$LiveBoostOffersCopyWith<$Res> implements $LiveBoostOffersCopyWith<$Res> {
  factory _$LiveBoostOffersCopyWith(_LiveBoostOffers value, $Res Function(_LiveBoostOffers) _then) = __$LiveBoostOffersCopyWithImpl;
@override @useResult
$Res call({
 int slots, int maxWaitMinutes, List<LiveBoostOption> options, List<LiveBoostCardStock> cards, DateTime nextStartAt, LiveBoost? roomBoost
});


@override $LiveBoostCopyWith<$Res>? get roomBoost;

}
/// @nodoc
class __$LiveBoostOffersCopyWithImpl<$Res>
    implements _$LiveBoostOffersCopyWith<$Res> {
  __$LiveBoostOffersCopyWithImpl(this._self, this._then);

  final _LiveBoostOffers _self;
  final $Res Function(_LiveBoostOffers) _then;

/// Create a copy of LiveBoostOffers
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slots = null,Object? maxWaitMinutes = null,Object? options = null,Object? cards = null,Object? nextStartAt = null,Object? roomBoost = freezed,}) {
  return _then(_LiveBoostOffers(
slots: null == slots ? _self.slots : slots // ignore: cast_nullable_to_non_nullable
as int,maxWaitMinutes: null == maxWaitMinutes ? _self.maxWaitMinutes : maxWaitMinutes // ignore: cast_nullable_to_non_nullable
as int,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<LiveBoostOption>,cards: null == cards ? _self._cards : cards // ignore: cast_nullable_to_non_nullable
as List<LiveBoostCardStock>,nextStartAt: null == nextStartAt ? _self.nextStartAt : nextStartAt // ignore: cast_nullable_to_non_nullable
as DateTime,roomBoost: freezed == roomBoost ? _self.roomBoost : roomBoost // ignore: cast_nullable_to_non_nullable
as LiveBoost?,
  ));
}

/// Create a copy of LiveBoostOffers
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveBoostCopyWith<$Res>? get roomBoost {
    if (_self.roomBoost == null) {
    return null;
  }

  return $LiveBoostCopyWith<$Res>(_self.roomBoost!, (value) {
    return _then(_self.copyWith(roomBoost: value));
  });
}
}


/// @nodoc
mixin _$LiveBoostResult {

 LiveBoost get boost; int get coins; List<LiveBoostCardStock> get cards;
/// Create a copy of LiveBoostResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBoostResultCopyWith<LiveBoostResult> get copyWith => _$LiveBoostResultCopyWithImpl<LiveBoostResult>(this as LiveBoostResult, _$identity);

  /// Serializes this LiveBoostResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBoostResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBoostResult&&(identical(other.boost, _this.boost) || other.boost == _this.boost)&&(identical(other.coins, _this.coins) || other.coins == _this.coins)&&const DeepCollectionEquality().equals(other.cards, _this.cards));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBoostResult;
  return Object.hash(runtimeType,_this.boost,_this.coins,const DeepCollectionEquality().hash(_this.cards));
}

@override
String toString() {
  final _this = this as LiveBoostResult;
  return 'LiveBoostResult(boost: ${_this.boost}, coins: ${_this.coins}, cards: ${_this.cards})';
}


}

/// @nodoc
abstract mixin class $LiveBoostResultCopyWith<$Res>  {
  factory $LiveBoostResultCopyWith(LiveBoostResult value, $Res Function(LiveBoostResult) _then) = _$LiveBoostResultCopyWithImpl;
@useResult
$Res call({
 LiveBoost boost, int coins, List<LiveBoostCardStock> cards
});


$LiveBoostCopyWith<$Res> get boost;

}
/// @nodoc
class _$LiveBoostResultCopyWithImpl<$Res>
    implements $LiveBoostResultCopyWith<$Res> {
  _$LiveBoostResultCopyWithImpl(this._self, this._then);

  final LiveBoostResult _self;
  final $Res Function(LiveBoostResult) _then;

/// Create a copy of LiveBoostResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? boost = null,Object? coins = null,Object? cards = null,}) {
  return _then(LiveBoostResult(
boost: null == boost ? _self.boost : boost // ignore: cast_nullable_to_non_nullable
as LiveBoost,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,cards: null == cards ? _self.cards : cards // ignore: cast_nullable_to_non_nullable
as List<LiveBoostCardStock>,
  ));
}
/// Create a copy of LiveBoostResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveBoostCopyWith<$Res> get boost {
  
  return $LiveBoostCopyWith<$Res>(_self.boost, (value) {
    return _then(_self.copyWith(boost: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveBoostResult].
extension LiveBoostResultPatterns on LiveBoostResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBoostResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBoostResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBoostResult value)  $default,){
final _that = this;
switch (_that) {
case _LiveBoostResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBoostResult value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBoostResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveBoost boost,  int coins,  List<LiveBoostCardStock> cards)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBoostResult() when $default != null:
return $default(_that.boost,_that.coins,_that.cards);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveBoost boost,  int coins,  List<LiveBoostCardStock> cards)  $default,) {final _that = this;
switch (_that) {
case _LiveBoostResult():
return $default(_that.boost,_that.coins,_that.cards);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveBoost boost,  int coins,  List<LiveBoostCardStock> cards)?  $default,) {final _that = this;
switch (_that) {
case _LiveBoostResult() when $default != null:
return $default(_that.boost,_that.coins,_that.cards);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBoostResult implements LiveBoostResult {
  const _LiveBoostResult({required this.boost, required this.coins, required  List<LiveBoostCardStock> cards}): _cards = cards;
  factory _LiveBoostResult.fromJson(Map<String, dynamic> json) => _$LiveBoostResultFromJson(json);

@override final  LiveBoost boost;
@override final  int coins;
 final  List<LiveBoostCardStock> _cards;
@override List<LiveBoostCardStock> get cards {
  if (_cards is EqualUnmodifiableListView) return _cards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cards);
}


/// Create a copy of LiveBoostResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBoostResultCopyWith<_LiveBoostResult> get copyWith => __$LiveBoostResultCopyWithImpl<_LiveBoostResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBoostResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBoostResult&&(identical(other.boost, boost) || other.boost == boost)&&(identical(other.coins, coins) || other.coins == coins)&&const DeepCollectionEquality().equals(other.cards, _cards));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,boost,coins,const DeepCollectionEquality().hash(_cards));
}

@override
String toString() {
    return 'LiveBoostResult(boost: $boost, coins: $coins, cards: $cards)';
}


}

/// @nodoc
abstract mixin class _$LiveBoostResultCopyWith<$Res> implements $LiveBoostResultCopyWith<$Res> {
  factory _$LiveBoostResultCopyWith(_LiveBoostResult value, $Res Function(_LiveBoostResult) _then) = __$LiveBoostResultCopyWithImpl;
@override @useResult
$Res call({
 LiveBoost boost, int coins, List<LiveBoostCardStock> cards
});


@override $LiveBoostCopyWith<$Res> get boost;

}
/// @nodoc
class __$LiveBoostResultCopyWithImpl<$Res>
    implements _$LiveBoostResultCopyWith<$Res> {
  __$LiveBoostResultCopyWithImpl(this._self, this._then);

  final _LiveBoostResult _self;
  final $Res Function(_LiveBoostResult) _then;

/// Create a copy of LiveBoostResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? boost = null,Object? coins = null,Object? cards = null,}) {
  return _then(_LiveBoostResult(
boost: null == boost ? _self.boost : boost // ignore: cast_nullable_to_non_nullable
as LiveBoost,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,cards: null == cards ? _self._cards : cards // ignore: cast_nullable_to_non_nullable
as List<LiveBoostCardStock>,
  ));
}

/// Create a copy of LiveBoostResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveBoostCopyWith<$Res> get boost {
  
  return $LiveBoostCopyWith<$Res>(_self.boost, (value) {
    return _then(_self.copyWith(boost: value));
  });
}
}


/// @nodoc
mixin _$LiveBoostedRoom {

 LiveRoomSummary get room; DateTime get endsAt;
/// Create a copy of LiveBoostedRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBoostedRoomCopyWith<LiveBoostedRoom> get copyWith => _$LiveBoostedRoomCopyWithImpl<LiveBoostedRoom>(this as LiveBoostedRoom, _$identity);

  /// Serializes this LiveBoostedRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBoostedRoom;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBoostedRoom&&(identical(other.room, _this.room) || other.room == _this.room)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBoostedRoom;
  return Object.hash(runtimeType,_this.room,_this.endsAt);
}

@override
String toString() {
  final _this = this as LiveBoostedRoom;
  return 'LiveBoostedRoom(room: ${_this.room}, endsAt: ${_this.endsAt})';
}


}

/// @nodoc
abstract mixin class $LiveBoostedRoomCopyWith<$Res>  {
  factory $LiveBoostedRoomCopyWith(LiveBoostedRoom value, $Res Function(LiveBoostedRoom) _then) = _$LiveBoostedRoomCopyWithImpl;
@useResult
$Res call({
 LiveRoomSummary room, DateTime endsAt
});


$LiveRoomSummaryCopyWith<$Res> get room;

}
/// @nodoc
class _$LiveBoostedRoomCopyWithImpl<$Res>
    implements $LiveBoostedRoomCopyWith<$Res> {
  _$LiveBoostedRoomCopyWithImpl(this._self, this._then);

  final LiveBoostedRoom _self;
  final $Res Function(LiveBoostedRoom) _then;

/// Create a copy of LiveBoostedRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? room = null,Object? endsAt = null,}) {
  return _then(LiveBoostedRoom(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoomSummary,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveBoostedRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomSummaryCopyWith<$Res> get room {
  
  return $LiveRoomSummaryCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveBoostedRoom].
extension LiveBoostedRoomPatterns on LiveBoostedRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBoostedRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBoostedRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBoostedRoom value)  $default,){
final _that = this;
switch (_that) {
case _LiveBoostedRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBoostedRoom value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBoostedRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveRoomSummary room,  DateTime endsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBoostedRoom() when $default != null:
return $default(_that.room,_that.endsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveRoomSummary room,  DateTime endsAt)  $default,) {final _that = this;
switch (_that) {
case _LiveBoostedRoom():
return $default(_that.room,_that.endsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveRoomSummary room,  DateTime endsAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveBoostedRoom() when $default != null:
return $default(_that.room,_that.endsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBoostedRoom implements LiveBoostedRoom {
  const _LiveBoostedRoom({required this.room, required this.endsAt});
  factory _LiveBoostedRoom.fromJson(Map<String, dynamic> json) => _$LiveBoostedRoomFromJson(json);

@override final  LiveRoomSummary room;
@override final  DateTime endsAt;

/// Create a copy of LiveBoostedRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBoostedRoomCopyWith<_LiveBoostedRoom> get copyWith => __$LiveBoostedRoomCopyWithImpl<_LiveBoostedRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBoostedRoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBoostedRoom&&(identical(other.room, room) || other.room == room)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,room,endsAt);
}

@override
String toString() {
    return 'LiveBoostedRoom(room: $room, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class _$LiveBoostedRoomCopyWith<$Res> implements $LiveBoostedRoomCopyWith<$Res> {
  factory _$LiveBoostedRoomCopyWith(_LiveBoostedRoom value, $Res Function(_LiveBoostedRoom) _then) = __$LiveBoostedRoomCopyWithImpl;
@override @useResult
$Res call({
 LiveRoomSummary room, DateTime endsAt
});


@override $LiveRoomSummaryCopyWith<$Res> get room;

}
/// @nodoc
class __$LiveBoostedRoomCopyWithImpl<$Res>
    implements _$LiveBoostedRoomCopyWith<$Res> {
  __$LiveBoostedRoomCopyWithImpl(this._self, this._then);

  final _LiveBoostedRoom _self;
  final $Res Function(_LiveBoostedRoom) _then;

/// Create a copy of LiveBoostedRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? room = null,Object? endsAt = null,}) {
  return _then(_LiveBoostedRoom(
room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LiveRoomSummary,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveBoostedRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveRoomSummaryCopyWith<$Res> get room {
  
  return $LiveRoomSummaryCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}

// dart format on
