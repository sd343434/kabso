// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'family_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FamilyLevelStep {

 int get level; int get minPoints;
/// Create a copy of FamilyLevelStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyLevelStepCopyWith<FamilyLevelStep> get copyWith => _$FamilyLevelStepCopyWithImpl<FamilyLevelStep>(this as FamilyLevelStep, _$identity);

  /// Serializes this FamilyLevelStep to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyLevelStep;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyLevelStep&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.minPoints, _this.minPoints) || other.minPoints == _this.minPoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyLevelStep;
  return Object.hash(runtimeType,_this.level,_this.minPoints);
}

@override
String toString() {
  final _this = this as FamilyLevelStep;
  return 'FamilyLevelStep(level: ${_this.level}, minPoints: ${_this.minPoints})';
}


}

/// @nodoc
abstract mixin class $FamilyLevelStepCopyWith<$Res>  {
  factory $FamilyLevelStepCopyWith(FamilyLevelStep value, $Res Function(FamilyLevelStep) _then) = _$FamilyLevelStepCopyWithImpl;
@useResult
$Res call({
 int level, int minPoints
});




}
/// @nodoc
class _$FamilyLevelStepCopyWithImpl<$Res>
    implements $FamilyLevelStepCopyWith<$Res> {
  _$FamilyLevelStepCopyWithImpl(this._self, this._then);

  final FamilyLevelStep _self;
  final $Res Function(FamilyLevelStep) _then;

/// Create a copy of FamilyLevelStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? minPoints = null,}) {
  return _then(FamilyLevelStep(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,minPoints: null == minPoints ? _self.minPoints : minPoints // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FamilyLevelStep].
extension FamilyLevelStepPatterns on FamilyLevelStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyLevelStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyLevelStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyLevelStep value)  $default,){
final _that = this;
switch (_that) {
case _FamilyLevelStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyLevelStep value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyLevelStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int level,  int minPoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyLevelStep() when $default != null:
return $default(_that.level,_that.minPoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int level,  int minPoints)  $default,) {final _that = this;
switch (_that) {
case _FamilyLevelStep():
return $default(_that.level,_that.minPoints);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int level,  int minPoints)?  $default,) {final _that = this;
switch (_that) {
case _FamilyLevelStep() when $default != null:
return $default(_that.level,_that.minPoints);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyLevelStep implements FamilyLevelStep {
  const _FamilyLevelStep({required this.level, required this.minPoints});
  factory _FamilyLevelStep.fromJson(Map<String, dynamic> json) => _$FamilyLevelStepFromJson(json);

@override final  int level;
@override final  int minPoints;

/// Create a copy of FamilyLevelStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyLevelStepCopyWith<_FamilyLevelStep> get copyWith => __$FamilyLevelStepCopyWithImpl<_FamilyLevelStep>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyLevelStepToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyLevelStep&&(identical(other.level, level) || other.level == level)&&(identical(other.minPoints, minPoints) || other.minPoints == minPoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,level,minPoints);
}

@override
String toString() {
    return 'FamilyLevelStep(level: $level, minPoints: $minPoints)';
}


}

/// @nodoc
abstract mixin class _$FamilyLevelStepCopyWith<$Res> implements $FamilyLevelStepCopyWith<$Res> {
  factory _$FamilyLevelStepCopyWith(_FamilyLevelStep value, $Res Function(_FamilyLevelStep) _then) = __$FamilyLevelStepCopyWithImpl;
@override @useResult
$Res call({
 int level, int minPoints
});




}
/// @nodoc
class __$FamilyLevelStepCopyWithImpl<$Res>
    implements _$FamilyLevelStepCopyWith<$Res> {
  __$FamilyLevelStepCopyWithImpl(this._self, this._then);

  final _FamilyLevelStep _self;
  final $Res Function(_FamilyLevelStep) _then;

/// Create a copy of FamilyLevelStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? minPoints = null,}) {
  return _then(_FamilyLevelStep(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,minPoints: null == minPoints ? _self.minPoints : minPoints // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FamilyConfig {

 int get createCost; int get capacity; int get requestTtlDays; List<FamilyLevelStep> get levels;
/// Create a copy of FamilyConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyConfigCopyWith<FamilyConfig> get copyWith => _$FamilyConfigCopyWithImpl<FamilyConfig>(this as FamilyConfig, _$identity);

  /// Serializes this FamilyConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyConfig&&(identical(other.createCost, _this.createCost) || other.createCost == _this.createCost)&&(identical(other.capacity, _this.capacity) || other.capacity == _this.capacity)&&(identical(other.requestTtlDays, _this.requestTtlDays) || other.requestTtlDays == _this.requestTtlDays)&&const DeepCollectionEquality().equals(other.levels, _this.levels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyConfig;
  return Object.hash(runtimeType,_this.createCost,_this.capacity,_this.requestTtlDays,const DeepCollectionEquality().hash(_this.levels));
}

@override
String toString() {
  final _this = this as FamilyConfig;
  return 'FamilyConfig(createCost: ${_this.createCost}, capacity: ${_this.capacity}, requestTtlDays: ${_this.requestTtlDays}, levels: ${_this.levels})';
}


}

/// @nodoc
abstract mixin class $FamilyConfigCopyWith<$Res>  {
  factory $FamilyConfigCopyWith(FamilyConfig value, $Res Function(FamilyConfig) _then) = _$FamilyConfigCopyWithImpl;
@useResult
$Res call({
 int createCost, int capacity, int requestTtlDays, List<FamilyLevelStep> levels
});




}
/// @nodoc
class _$FamilyConfigCopyWithImpl<$Res>
    implements $FamilyConfigCopyWith<$Res> {
  _$FamilyConfigCopyWithImpl(this._self, this._then);

  final FamilyConfig _self;
  final $Res Function(FamilyConfig) _then;

/// Create a copy of FamilyConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? createCost = null,Object? capacity = null,Object? requestTtlDays = null,Object? levels = null,}) {
  return _then(FamilyConfig(
createCost: null == createCost ? _self.createCost : createCost // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,requestTtlDays: null == requestTtlDays ? _self.requestTtlDays : requestTtlDays // ignore: cast_nullable_to_non_nullable
as int,levels: null == levels ? _self.levels : levels // ignore: cast_nullable_to_non_nullable
as List<FamilyLevelStep>,
  ));
}

}


/// Adds pattern-matching-related methods to [FamilyConfig].
extension FamilyConfigPatterns on FamilyConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyConfig value)  $default,){
final _that = this;
switch (_that) {
case _FamilyConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyConfig value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int createCost,  int capacity,  int requestTtlDays,  List<FamilyLevelStep> levels)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyConfig() when $default != null:
return $default(_that.createCost,_that.capacity,_that.requestTtlDays,_that.levels);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int createCost,  int capacity,  int requestTtlDays,  List<FamilyLevelStep> levels)  $default,) {final _that = this;
switch (_that) {
case _FamilyConfig():
return $default(_that.createCost,_that.capacity,_that.requestTtlDays,_that.levels);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int createCost,  int capacity,  int requestTtlDays,  List<FamilyLevelStep> levels)?  $default,) {final _that = this;
switch (_that) {
case _FamilyConfig() when $default != null:
return $default(_that.createCost,_that.capacity,_that.requestTtlDays,_that.levels);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyConfig implements FamilyConfig {
  const _FamilyConfig({required this.createCost, required this.capacity, required this.requestTtlDays, required  List<FamilyLevelStep> levels}): _levels = levels;
  factory _FamilyConfig.fromJson(Map<String, dynamic> json) => _$FamilyConfigFromJson(json);

@override final  int createCost;
@override final  int capacity;
@override final  int requestTtlDays;
 final  List<FamilyLevelStep> _levels;
@override List<FamilyLevelStep> get levels {
  if (_levels is EqualUnmodifiableListView) return _levels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levels);
}


/// Create a copy of FamilyConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyConfigCopyWith<_FamilyConfig> get copyWith => __$FamilyConfigCopyWithImpl<_FamilyConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyConfig&&(identical(other.createCost, createCost) || other.createCost == createCost)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.requestTtlDays, requestTtlDays) || other.requestTtlDays == requestTtlDays)&&const DeepCollectionEquality().equals(other.levels, _levels));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,createCost,capacity,requestTtlDays,const DeepCollectionEquality().hash(_levels));
}

@override
String toString() {
    return 'FamilyConfig(createCost: $createCost, capacity: $capacity, requestTtlDays: $requestTtlDays, levels: $levels)';
}


}

/// @nodoc
abstract mixin class _$FamilyConfigCopyWith<$Res> implements $FamilyConfigCopyWith<$Res> {
  factory _$FamilyConfigCopyWith(_FamilyConfig value, $Res Function(_FamilyConfig) _then) = __$FamilyConfigCopyWithImpl;
@override @useResult
$Res call({
 int createCost, int capacity, int requestTtlDays, List<FamilyLevelStep> levels
});




}
/// @nodoc
class __$FamilyConfigCopyWithImpl<$Res>
    implements _$FamilyConfigCopyWith<$Res> {
  __$FamilyConfigCopyWithImpl(this._self, this._then);

  final _FamilyConfig _self;
  final $Res Function(_FamilyConfig) _then;

/// Create a copy of FamilyConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? createCost = null,Object? capacity = null,Object? requestTtlDays = null,Object? levels = null,}) {
  return _then(_FamilyConfig(
createCost: null == createCost ? _self.createCost : createCost // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,requestTtlDays: null == requestTtlDays ? _self.requestTtlDays : requestTtlDays // ignore: cast_nullable_to_non_nullable
as int,levels: null == levels ? _self._levels : levels // ignore: cast_nullable_to_non_nullable
as List<FamilyLevelStep>,
  ));
}


}


/// @nodoc
mixin _$FamilyCard {

 String get id; int get number; String get name; String? get emblemUrl; int get level; int get points; int get memberCount; int get capacity;
/// Create a copy of FamilyCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<FamilyCard> get copyWith => _$FamilyCardCopyWithImpl<FamilyCard>(this as FamilyCard, _$identity);

  /// Serializes this FamilyCard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyCard;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyCard&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.emblemUrl, _this.emblemUrl) || other.emblemUrl == _this.emblemUrl)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.points, _this.points) || other.points == _this.points)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.capacity, _this.capacity) || other.capacity == _this.capacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyCard;
  return Object.hash(runtimeType,_this.id,_this.number,_this.name,_this.emblemUrl,_this.level,_this.points,_this.memberCount,_this.capacity);
}

@override
String toString() {
  final _this = this as FamilyCard;
  return 'FamilyCard(id: ${_this.id}, number: ${_this.number}, name: ${_this.name}, emblemUrl: ${_this.emblemUrl}, level: ${_this.level}, points: ${_this.points}, memberCount: ${_this.memberCount}, capacity: ${_this.capacity})';
}


}

/// @nodoc
abstract mixin class $FamilyCardCopyWith<$Res>  {
  factory $FamilyCardCopyWith(FamilyCard value, $Res Function(FamilyCard) _then) = _$FamilyCardCopyWithImpl;
@useResult
$Res call({
 String id, int number, String name, String? emblemUrl, int level, int points, int memberCount, int capacity
});




}
/// @nodoc
class _$FamilyCardCopyWithImpl<$Res>
    implements $FamilyCardCopyWith<$Res> {
  _$FamilyCardCopyWithImpl(this._self, this._then);

  final FamilyCard _self;
  final $Res Function(FamilyCard) _then;

/// Create a copy of FamilyCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? name = null,Object? emblemUrl = freezed,Object? level = null,Object? points = null,Object? memberCount = null,Object? capacity = null,}) {
  return _then(FamilyCard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FamilyCard].
extension FamilyCardPatterns on FamilyCard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyCard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyCard value)  $default,){
final _that = this;
switch (_that) {
case _FamilyCard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyCard value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyCard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyCard() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity)  $default,) {final _that = this;
switch (_that) {
case _FamilyCard():
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity)?  $default,) {final _that = this;
switch (_that) {
case _FamilyCard() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyCard implements FamilyCard {
  const _FamilyCard({required this.id, required this.number, required this.name, required this.emblemUrl, required this.level, required this.points, required this.memberCount, required this.capacity});
  factory _FamilyCard.fromJson(Map<String, dynamic> json) => _$FamilyCardFromJson(json);

@override final  String id;
@override final  int number;
@override final  String name;
@override final  String? emblemUrl;
@override final  int level;
@override final  int points;
@override final  int memberCount;
@override final  int capacity;

/// Create a copy of FamilyCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyCardCopyWith<_FamilyCard> get copyWith => __$FamilyCardCopyWithImpl<_FamilyCard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyCardToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyCard&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.emblemUrl, emblemUrl) || other.emblemUrl == emblemUrl)&&(identical(other.level, level) || other.level == level)&&(identical(other.points, points) || other.points == points)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,number,name,emblemUrl,level,points,memberCount,capacity);
}

@override
String toString() {
    return 'FamilyCard(id: $id, number: $number, name: $name, emblemUrl: $emblemUrl, level: $level, points: $points, memberCount: $memberCount, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class _$FamilyCardCopyWith<$Res> implements $FamilyCardCopyWith<$Res> {
  factory _$FamilyCardCopyWith(_FamilyCard value, $Res Function(_FamilyCard) _then) = __$FamilyCardCopyWithImpl;
@override @useResult
$Res call({
 String id, int number, String name, String? emblemUrl, int level, int points, int memberCount, int capacity
});




}
/// @nodoc
class __$FamilyCardCopyWithImpl<$Res>
    implements _$FamilyCardCopyWith<$Res> {
  __$FamilyCardCopyWithImpl(this._self, this._then);

  final _FamilyCard _self;
  final $Res Function(_FamilyCard) _then;

/// Create a copy of FamilyCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? name = null,Object? emblemUrl = freezed,Object? level = null,Object? points = null,Object? memberCount = null,Object? capacity = null,}) {
  return _then(_FamilyCard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Family {

 String get id; int get number; String get name; String? get emblemUrl; int get level; int get points; int get memberCount; int get capacity;/// Points the next level needs; null at the top level.
 int? get nextLevelPoints; UserSummary? get leader; DateTime get createdAt;/// The caller's role here, or null when they are not a member.
 FamilyRole? get myRole;/// The caller's pending join request to this family.
 String? get myRequestId;
/// Create a copy of Family
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyCopyWith<Family> get copyWith => _$FamilyCopyWithImpl<Family>(this as Family, _$identity);

  /// Serializes this Family to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Family;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Family&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.emblemUrl, _this.emblemUrl) || other.emblemUrl == _this.emblemUrl)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.points, _this.points) || other.points == _this.points)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.capacity, _this.capacity) || other.capacity == _this.capacity)&&(identical(other.nextLevelPoints, _this.nextLevelPoints) || other.nextLevelPoints == _this.nextLevelPoints)&&(identical(other.leader, _this.leader) || other.leader == _this.leader)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.myRole, _this.myRole) || other.myRole == _this.myRole)&&(identical(other.myRequestId, _this.myRequestId) || other.myRequestId == _this.myRequestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Family;
  return Object.hash(runtimeType,_this.id,_this.number,_this.name,_this.emblemUrl,_this.level,_this.points,_this.memberCount,_this.capacity,_this.nextLevelPoints,_this.leader,_this.createdAt,_this.myRole,_this.myRequestId);
}

@override
String toString() {
  final _this = this as Family;
  return 'Family(id: ${_this.id}, number: ${_this.number}, name: ${_this.name}, emblemUrl: ${_this.emblemUrl}, level: ${_this.level}, points: ${_this.points}, memberCount: ${_this.memberCount}, capacity: ${_this.capacity}, nextLevelPoints: ${_this.nextLevelPoints}, leader: ${_this.leader}, createdAt: ${_this.createdAt}, myRole: ${_this.myRole}, myRequestId: ${_this.myRequestId})';
}


}

/// @nodoc
abstract mixin class $FamilyCopyWith<$Res>  {
  factory $FamilyCopyWith(Family value, $Res Function(Family) _then) = _$FamilyCopyWithImpl;
@useResult
$Res call({
 String id, int number, String name, String? emblemUrl, int level, int points, int memberCount, int capacity, int? nextLevelPoints, UserSummary? leader, DateTime createdAt, FamilyRole? myRole, String? myRequestId
});


$UserSummaryCopyWith<$Res>? get leader;

}
/// @nodoc
class _$FamilyCopyWithImpl<$Res>
    implements $FamilyCopyWith<$Res> {
  _$FamilyCopyWithImpl(this._self, this._then);

  final Family _self;
  final $Res Function(Family) _then;

/// Create a copy of Family
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? name = null,Object? emblemUrl = freezed,Object? level = null,Object? points = null,Object? memberCount = null,Object? capacity = null,Object? nextLevelPoints = freezed,Object? leader = freezed,Object? createdAt = null,Object? myRole = freezed,Object? myRequestId = freezed,}) {
  return _then(Family(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,nextLevelPoints: freezed == nextLevelPoints ? _self.nextLevelPoints : nextLevelPoints // ignore: cast_nullable_to_non_nullable
as int?,leader: freezed == leader ? _self.leader : leader // ignore: cast_nullable_to_non_nullable
as UserSummary?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: freezed == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as FamilyRole?,myRequestId: freezed == myRequestId ? _self.myRequestId : myRequestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Family
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get leader {
    if (_self.leader == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.leader!, (value) {
    return _then(_self.copyWith(leader: value));
  });
}
}


/// Adds pattern-matching-related methods to [Family].
extension FamilyPatterns on Family {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Family value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Family() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Family value)  $default,){
final _that = this;
switch (_that) {
case _Family():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Family value)?  $default,){
final _that = this;
switch (_that) {
case _Family() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity,  int? nextLevelPoints,  UserSummary? leader,  DateTime createdAt,  FamilyRole? myRole,  String? myRequestId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Family() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity,_that.nextLevelPoints,_that.leader,_that.createdAt,_that.myRole,_that.myRequestId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity,  int? nextLevelPoints,  UserSummary? leader,  DateTime createdAt,  FamilyRole? myRole,  String? myRequestId)  $default,) {final _that = this;
switch (_that) {
case _Family():
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity,_that.nextLevelPoints,_that.leader,_that.createdAt,_that.myRole,_that.myRequestId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity,  int? nextLevelPoints,  UserSummary? leader,  DateTime createdAt,  FamilyRole? myRole,  String? myRequestId)?  $default,) {final _that = this;
switch (_that) {
case _Family() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity,_that.nextLevelPoints,_that.leader,_that.createdAt,_that.myRole,_that.myRequestId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Family extends Family {
  const _Family({required this.id, required this.number, required this.name, required this.emblemUrl, required this.level, required this.points, required this.memberCount, required this.capacity, required this.nextLevelPoints, required this.leader, required this.createdAt, required this.myRole, required this.myRequestId}): super._();
  factory _Family.fromJson(Map<String, dynamic> json) => _$FamilyFromJson(json);

@override final  String id;
@override final  int number;
@override final  String name;
@override final  String? emblemUrl;
@override final  int level;
@override final  int points;
@override final  int memberCount;
@override final  int capacity;
/// Points the next level needs; null at the top level.
@override final  int? nextLevelPoints;
@override final  UserSummary? leader;
@override final  DateTime createdAt;
/// The caller's role here, or null when they are not a member.
@override final  FamilyRole? myRole;
/// The caller's pending join request to this family.
@override final  String? myRequestId;

/// Create a copy of Family
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyCopyWith<_Family> get copyWith => __$FamilyCopyWithImpl<_Family>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Family&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.emblemUrl, emblemUrl) || other.emblemUrl == emblemUrl)&&(identical(other.level, level) || other.level == level)&&(identical(other.points, points) || other.points == points)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.nextLevelPoints, nextLevelPoints) || other.nextLevelPoints == nextLevelPoints)&&(identical(other.leader, leader) || other.leader == leader)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.myRequestId, myRequestId) || other.myRequestId == myRequestId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,number,name,emblemUrl,level,points,memberCount,capacity,nextLevelPoints,leader,createdAt,myRole,myRequestId);
}

@override
String toString() {
    return 'Family(id: $id, number: $number, name: $name, emblemUrl: $emblemUrl, level: $level, points: $points, memberCount: $memberCount, capacity: $capacity, nextLevelPoints: $nextLevelPoints, leader: $leader, createdAt: $createdAt, myRole: $myRole, myRequestId: $myRequestId)';
}


}

/// @nodoc
abstract mixin class _$FamilyCopyWith<$Res> implements $FamilyCopyWith<$Res> {
  factory _$FamilyCopyWith(_Family value, $Res Function(_Family) _then) = __$FamilyCopyWithImpl;
@override @useResult
$Res call({
 String id, int number, String name, String? emblemUrl, int level, int points, int memberCount, int capacity, int? nextLevelPoints, UserSummary? leader, DateTime createdAt, FamilyRole? myRole, String? myRequestId
});


@override $UserSummaryCopyWith<$Res>? get leader;

}
/// @nodoc
class __$FamilyCopyWithImpl<$Res>
    implements _$FamilyCopyWith<$Res> {
  __$FamilyCopyWithImpl(this._self, this._then);

  final _Family _self;
  final $Res Function(_Family) _then;

/// Create a copy of Family
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? name = null,Object? emblemUrl = freezed,Object? level = null,Object? points = null,Object? memberCount = null,Object? capacity = null,Object? nextLevelPoints = freezed,Object? leader = freezed,Object? createdAt = null,Object? myRole = freezed,Object? myRequestId = freezed,}) {
  return _then(_Family(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,nextLevelPoints: freezed == nextLevelPoints ? _self.nextLevelPoints : nextLevelPoints // ignore: cast_nullable_to_non_nullable
as int?,leader: freezed == leader ? _self.leader : leader // ignore: cast_nullable_to_non_nullable
as UserSummary?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,myRole: freezed == myRole ? _self.myRole : myRole // ignore: cast_nullable_to_non_nullable
as FamilyRole?,myRequestId: freezed == myRequestId ? _self.myRequestId : myRequestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Family
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get leader {
    if (_self.leader == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.leader!, (value) {
    return _then(_self.copyWith(leader: value));
  });
}
}


/// @nodoc
mixin _$FamilyMember {

 UserSummary get user; FamilyRole get role; DateTime get joinedAt; int get points;
/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyMemberCopyWith<FamilyMember> get copyWith => _$FamilyMemberCopyWithImpl<FamilyMember>(this as FamilyMember, _$identity);

  /// Serializes this FamilyMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyMember;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyMember&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.joinedAt, _this.joinedAt) || other.joinedAt == _this.joinedAt)&&(identical(other.points, _this.points) || other.points == _this.points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyMember;
  return Object.hash(runtimeType,_this.user,_this.role,_this.joinedAt,_this.points);
}

@override
String toString() {
  final _this = this as FamilyMember;
  return 'FamilyMember(user: ${_this.user}, role: ${_this.role}, joinedAt: ${_this.joinedAt}, points: ${_this.points})';
}


}

/// @nodoc
abstract mixin class $FamilyMemberCopyWith<$Res>  {
  factory $FamilyMemberCopyWith(FamilyMember value, $Res Function(FamilyMember) _then) = _$FamilyMemberCopyWithImpl;
@useResult
$Res call({
 UserSummary user, FamilyRole role, DateTime joinedAt, int points
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$FamilyMemberCopyWithImpl<$Res>
    implements $FamilyMemberCopyWith<$Res> {
  _$FamilyMemberCopyWithImpl(this._self, this._then);

  final FamilyMember _self;
  final $Res Function(FamilyMember) _then;

/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? role = null,Object? joinedAt = null,Object? points = null,}) {
  return _then(FamilyMember(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyMember].
extension FamilyMemberPatterns on FamilyMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyMember value)  $default,){
final _that = this;
switch (_that) {
case _FamilyMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyMember value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  FamilyRole role,  DateTime joinedAt,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyMember() when $default != null:
return $default(_that.user,_that.role,_that.joinedAt,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  FamilyRole role,  DateTime joinedAt,  int points)  $default,) {final _that = this;
switch (_that) {
case _FamilyMember():
return $default(_that.user,_that.role,_that.joinedAt,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  FamilyRole role,  DateTime joinedAt,  int points)?  $default,) {final _that = this;
switch (_that) {
case _FamilyMember() when $default != null:
return $default(_that.user,_that.role,_that.joinedAt,_that.points);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyMember implements FamilyMember {
  const _FamilyMember({required this.user, required this.role, required this.joinedAt, required this.points});
  factory _FamilyMember.fromJson(Map<String, dynamic> json) => _$FamilyMemberFromJson(json);

@override final  UserSummary user;
@override final  FamilyRole role;
@override final  DateTime joinedAt;
@override final  int points;

/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyMemberCopyWith<_FamilyMember> get copyWith => __$FamilyMemberCopyWithImpl<_FamilyMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyMemberToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyMember&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.points, points) || other.points == points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,user,role,joinedAt,points);
}

@override
String toString() {
    return 'FamilyMember(user: $user, role: $role, joinedAt: $joinedAt, points: $points)';
}


}

/// @nodoc
abstract mixin class _$FamilyMemberCopyWith<$Res> implements $FamilyMemberCopyWith<$Res> {
  factory _$FamilyMemberCopyWith(_FamilyMember value, $Res Function(_FamilyMember) _then) = __$FamilyMemberCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, FamilyRole role, DateTime joinedAt, int points
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$FamilyMemberCopyWithImpl<$Res>
    implements _$FamilyMemberCopyWith<$Res> {
  __$FamilyMemberCopyWithImpl(this._self, this._then);

  final _FamilyMember _self;
  final $Res Function(_FamilyMember) _then;

/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? role = null,Object? joinedAt = null,Object? points = null,}) {
  return _then(_FamilyMember(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$FamilyJoinRequest {

 String get id; FamilyCard get family; UserSummary get user; BondRequestStatus get status; DateTime get createdAt; DateTime get expiresAt;
/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyJoinRequestCopyWith<FamilyJoinRequest> get copyWith => _$FamilyJoinRequestCopyWithImpl<FamilyJoinRequest>(this as FamilyJoinRequest, _$identity);

  /// Serializes this FamilyJoinRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyJoinRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyJoinRequest&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyJoinRequest;
  return Object.hash(runtimeType,_this.id,_this.family,_this.user,_this.status,_this.createdAt,_this.expiresAt);
}

@override
String toString() {
  final _this = this as FamilyJoinRequest;
  return 'FamilyJoinRequest(id: ${_this.id}, family: ${_this.family}, user: ${_this.user}, status: ${_this.status}, createdAt: ${_this.createdAt}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $FamilyJoinRequestCopyWith<$Res>  {
  factory $FamilyJoinRequestCopyWith(FamilyJoinRequest value, $Res Function(FamilyJoinRequest) _then) = _$FamilyJoinRequestCopyWithImpl;
@useResult
$Res call({
 String id, FamilyCard family, UserSummary user, BondRequestStatus status, DateTime createdAt, DateTime expiresAt
});


$FamilyCardCopyWith<$Res> get family;$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$FamilyJoinRequestCopyWithImpl<$Res>
    implements $FamilyJoinRequestCopyWith<$Res> {
  _$FamilyJoinRequestCopyWithImpl(this._self, this._then);

  final FamilyJoinRequest _self;
  final $Res Function(FamilyJoinRequest) _then;

/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? family = null,Object? user = null,Object? status = null,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(FamilyJoinRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as FamilyCard,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BondRequestStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<$Res> get family {
  
  return $FamilyCardCopyWith<$Res>(_self.family, (value) {
    return _then(_self.copyWith(family: value));
  });
}/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyJoinRequest].
extension FamilyJoinRequestPatterns on FamilyJoinRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyJoinRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyJoinRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyJoinRequest value)  $default,){
final _that = this;
switch (_that) {
case _FamilyJoinRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyJoinRequest value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyJoinRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  FamilyCard family,  UserSummary user,  BondRequestStatus status,  DateTime createdAt,  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyJoinRequest() when $default != null:
return $default(_that.id,_that.family,_that.user,_that.status,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  FamilyCard family,  UserSummary user,  BondRequestStatus status,  DateTime createdAt,  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _FamilyJoinRequest():
return $default(_that.id,_that.family,_that.user,_that.status,_that.createdAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  FamilyCard family,  UserSummary user,  BondRequestStatus status,  DateTime createdAt,  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _FamilyJoinRequest() when $default != null:
return $default(_that.id,_that.family,_that.user,_that.status,_that.createdAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyJoinRequest implements FamilyJoinRequest {
  const _FamilyJoinRequest({required this.id, required this.family, required this.user, required this.status, required this.createdAt, required this.expiresAt});
  factory _FamilyJoinRequest.fromJson(Map<String, dynamic> json) => _$FamilyJoinRequestFromJson(json);

@override final  String id;
@override final  FamilyCard family;
@override final  UserSummary user;
@override final  BondRequestStatus status;
@override final  DateTime createdAt;
@override final  DateTime expiresAt;

/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyJoinRequestCopyWith<_FamilyJoinRequest> get copyWith => __$FamilyJoinRequestCopyWithImpl<_FamilyJoinRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyJoinRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyJoinRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.family, family) || other.family == family)&&(identical(other.user, user) || other.user == user)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,family,user,status,createdAt,expiresAt);
}

@override
String toString() {
    return 'FamilyJoinRequest(id: $id, family: $family, user: $user, status: $status, createdAt: $createdAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$FamilyJoinRequestCopyWith<$Res> implements $FamilyJoinRequestCopyWith<$Res> {
  factory _$FamilyJoinRequestCopyWith(_FamilyJoinRequest value, $Res Function(_FamilyJoinRequest) _then) = __$FamilyJoinRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, FamilyCard family, UserSummary user, BondRequestStatus status, DateTime createdAt, DateTime expiresAt
});


@override $FamilyCardCopyWith<$Res> get family;@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$FamilyJoinRequestCopyWithImpl<$Res>
    implements _$FamilyJoinRequestCopyWith<$Res> {
  __$FamilyJoinRequestCopyWithImpl(this._self, this._then);

  final _FamilyJoinRequest _self;
  final $Res Function(_FamilyJoinRequest) _then;

/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? family = null,Object? user = null,Object? status = null,Object? createdAt = null,Object? expiresAt = null,}) {
  return _then(_FamilyJoinRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as FamilyCard,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BondRequestStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<$Res> get family {
  
  return $FamilyCardCopyWith<$Res>(_self.family, (value) {
    return _then(_self.copyWith(family: value));
  });
}/// Create a copy of FamilyJoinRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$FamilyCardPage {

 List<FamilyCard> get data; PageInfo get page;
/// Create a copy of FamilyCardPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyCardPageCopyWith<FamilyCardPage> get copyWith => _$FamilyCardPageCopyWithImpl<FamilyCardPage>(this as FamilyCardPage, _$identity);

  /// Serializes this FamilyCardPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyCardPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyCardPage&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyCardPage;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.page);
}

@override
String toString() {
  final _this = this as FamilyCardPage;
  return 'FamilyCardPage(data: ${_this.data}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $FamilyCardPageCopyWith<$Res>  {
  factory $FamilyCardPageCopyWith(FamilyCardPage value, $Res Function(FamilyCardPage) _then) = _$FamilyCardPageCopyWithImpl;
@useResult
$Res call({
 List<FamilyCard> data, PageInfo page
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$FamilyCardPageCopyWithImpl<$Res>
    implements $FamilyCardPageCopyWith<$Res> {
  _$FamilyCardPageCopyWithImpl(this._self, this._then);

  final FamilyCardPage _self;
  final $Res Function(FamilyCardPage) _then;

/// Create a copy of FamilyCardPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,}) {
  return _then(FamilyCardPage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyCard>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}
/// Create a copy of FamilyCardPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyCardPage].
extension FamilyCardPagePatterns on FamilyCardPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyCardPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyCardPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyCardPage value)  $default,){
final _that = this;
switch (_that) {
case _FamilyCardPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyCardPage value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyCardPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FamilyCard> data,  PageInfo page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyCardPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FamilyCard> data,  PageInfo page)  $default,) {final _that = this;
switch (_that) {
case _FamilyCardPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FamilyCard> data,  PageInfo page)?  $default,) {final _that = this;
switch (_that) {
case _FamilyCardPage() when $default != null:
return $default(_that.data,_that.page);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyCardPage implements FamilyCardPage {
  const _FamilyCardPage({required  List<FamilyCard> data, required this.page}): _data = data;
  factory _FamilyCardPage.fromJson(Map<String, dynamic> json) => _$FamilyCardPageFromJson(json);

 final  List<FamilyCard> _data;
@override List<FamilyCard> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;

/// Create a copy of FamilyCardPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyCardPageCopyWith<_FamilyCardPage> get copyWith => __$FamilyCardPageCopyWithImpl<_FamilyCardPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyCardPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyCardPage&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page);
}

@override
String toString() {
    return 'FamilyCardPage(data: $data, page: $page)';
}


}

/// @nodoc
abstract mixin class _$FamilyCardPageCopyWith<$Res> implements $FamilyCardPageCopyWith<$Res> {
  factory _$FamilyCardPageCopyWith(_FamilyCardPage value, $Res Function(_FamilyCardPage) _then) = __$FamilyCardPageCopyWithImpl;
@override @useResult
$Res call({
 List<FamilyCard> data, PageInfo page
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$FamilyCardPageCopyWithImpl<$Res>
    implements _$FamilyCardPageCopyWith<$Res> {
  __$FamilyCardPageCopyWithImpl(this._self, this._then);

  final _FamilyCardPage _self;
  final $Res Function(_FamilyCardPage) _then;

/// Create a copy of FamilyCardPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,}) {
  return _then(_FamilyCardPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyCard>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}

/// Create a copy of FamilyCardPage
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
mixin _$FamilyMemberPage {

 List<FamilyMember> get data; PageInfo get page;
/// Create a copy of FamilyMemberPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyMemberPageCopyWith<FamilyMemberPage> get copyWith => _$FamilyMemberPageCopyWithImpl<FamilyMemberPage>(this as FamilyMemberPage, _$identity);

  /// Serializes this FamilyMemberPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyMemberPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyMemberPage&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyMemberPage;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.page);
}

@override
String toString() {
  final _this = this as FamilyMemberPage;
  return 'FamilyMemberPage(data: ${_this.data}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $FamilyMemberPageCopyWith<$Res>  {
  factory $FamilyMemberPageCopyWith(FamilyMemberPage value, $Res Function(FamilyMemberPage) _then) = _$FamilyMemberPageCopyWithImpl;
@useResult
$Res call({
 List<FamilyMember> data, PageInfo page
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$FamilyMemberPageCopyWithImpl<$Res>
    implements $FamilyMemberPageCopyWith<$Res> {
  _$FamilyMemberPageCopyWithImpl(this._self, this._then);

  final FamilyMemberPage _self;
  final $Res Function(FamilyMemberPage) _then;

/// Create a copy of FamilyMemberPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,}) {
  return _then(FamilyMemberPage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyMember>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}
/// Create a copy of FamilyMemberPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyMemberPage].
extension FamilyMemberPagePatterns on FamilyMemberPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyMemberPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyMemberPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyMemberPage value)  $default,){
final _that = this;
switch (_that) {
case _FamilyMemberPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyMemberPage value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyMemberPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FamilyMember> data,  PageInfo page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyMemberPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FamilyMember> data,  PageInfo page)  $default,) {final _that = this;
switch (_that) {
case _FamilyMemberPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FamilyMember> data,  PageInfo page)?  $default,) {final _that = this;
switch (_that) {
case _FamilyMemberPage() when $default != null:
return $default(_that.data,_that.page);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyMemberPage implements FamilyMemberPage {
  const _FamilyMemberPage({required  List<FamilyMember> data, required this.page}): _data = data;
  factory _FamilyMemberPage.fromJson(Map<String, dynamic> json) => _$FamilyMemberPageFromJson(json);

 final  List<FamilyMember> _data;
@override List<FamilyMember> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;

/// Create a copy of FamilyMemberPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyMemberPageCopyWith<_FamilyMemberPage> get copyWith => __$FamilyMemberPageCopyWithImpl<_FamilyMemberPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyMemberPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyMemberPage&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page);
}

@override
String toString() {
    return 'FamilyMemberPage(data: $data, page: $page)';
}


}

/// @nodoc
abstract mixin class _$FamilyMemberPageCopyWith<$Res> implements $FamilyMemberPageCopyWith<$Res> {
  factory _$FamilyMemberPageCopyWith(_FamilyMemberPage value, $Res Function(_FamilyMemberPage) _then) = __$FamilyMemberPageCopyWithImpl;
@override @useResult
$Res call({
 List<FamilyMember> data, PageInfo page
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$FamilyMemberPageCopyWithImpl<$Res>
    implements _$FamilyMemberPageCopyWith<$Res> {
  __$FamilyMemberPageCopyWithImpl(this._self, this._then);

  final _FamilyMemberPage _self;
  final $Res Function(_FamilyMemberPage) _then;

/// Create a copy of FamilyMemberPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,}) {
  return _then(_FamilyMemberPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyMember>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}

/// Create a copy of FamilyMemberPage
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
mixin _$FamilyJoinRequestPage {

 List<FamilyJoinRequest> get data; PageInfo get page;
/// Create a copy of FamilyJoinRequestPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyJoinRequestPageCopyWith<FamilyJoinRequestPage> get copyWith => _$FamilyJoinRequestPageCopyWithImpl<FamilyJoinRequestPage>(this as FamilyJoinRequestPage, _$identity);

  /// Serializes this FamilyJoinRequestPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyJoinRequestPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyJoinRequestPage&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyJoinRequestPage;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.page);
}

@override
String toString() {
  final _this = this as FamilyJoinRequestPage;
  return 'FamilyJoinRequestPage(data: ${_this.data}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $FamilyJoinRequestPageCopyWith<$Res>  {
  factory $FamilyJoinRequestPageCopyWith(FamilyJoinRequestPage value, $Res Function(FamilyJoinRequestPage) _then) = _$FamilyJoinRequestPageCopyWithImpl;
@useResult
$Res call({
 List<FamilyJoinRequest> data, PageInfo page
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$FamilyJoinRequestPageCopyWithImpl<$Res>
    implements $FamilyJoinRequestPageCopyWith<$Res> {
  _$FamilyJoinRequestPageCopyWithImpl(this._self, this._then);

  final FamilyJoinRequestPage _self;
  final $Res Function(FamilyJoinRequestPage) _then;

/// Create a copy of FamilyJoinRequestPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,}) {
  return _then(FamilyJoinRequestPage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyJoinRequest>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}
/// Create a copy of FamilyJoinRequestPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyJoinRequestPage].
extension FamilyJoinRequestPagePatterns on FamilyJoinRequestPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyJoinRequestPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyJoinRequestPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyJoinRequestPage value)  $default,){
final _that = this;
switch (_that) {
case _FamilyJoinRequestPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyJoinRequestPage value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyJoinRequestPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FamilyJoinRequest> data,  PageInfo page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyJoinRequestPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FamilyJoinRequest> data,  PageInfo page)  $default,) {final _that = this;
switch (_that) {
case _FamilyJoinRequestPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FamilyJoinRequest> data,  PageInfo page)?  $default,) {final _that = this;
switch (_that) {
case _FamilyJoinRequestPage() when $default != null:
return $default(_that.data,_that.page);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyJoinRequestPage implements FamilyJoinRequestPage {
  const _FamilyJoinRequestPage({required  List<FamilyJoinRequest> data, required this.page}): _data = data;
  factory _FamilyJoinRequestPage.fromJson(Map<String, dynamic> json) => _$FamilyJoinRequestPageFromJson(json);

 final  List<FamilyJoinRequest> _data;
@override List<FamilyJoinRequest> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;

/// Create a copy of FamilyJoinRequestPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyJoinRequestPageCopyWith<_FamilyJoinRequestPage> get copyWith => __$FamilyJoinRequestPageCopyWithImpl<_FamilyJoinRequestPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyJoinRequestPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyJoinRequestPage&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page);
}

@override
String toString() {
    return 'FamilyJoinRequestPage(data: $data, page: $page)';
}


}

/// @nodoc
abstract mixin class _$FamilyJoinRequestPageCopyWith<$Res> implements $FamilyJoinRequestPageCopyWith<$Res> {
  factory _$FamilyJoinRequestPageCopyWith(_FamilyJoinRequestPage value, $Res Function(_FamilyJoinRequestPage) _then) = __$FamilyJoinRequestPageCopyWithImpl;
@override @useResult
$Res call({
 List<FamilyJoinRequest> data, PageInfo page
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$FamilyJoinRequestPageCopyWithImpl<$Res>
    implements _$FamilyJoinRequestPageCopyWith<$Res> {
  __$FamilyJoinRequestPageCopyWithImpl(this._self, this._then);

  final _FamilyJoinRequestPage _self;
  final $Res Function(_FamilyJoinRequestPage) _then;

/// Create a copy of FamilyJoinRequestPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,}) {
  return _then(_FamilyJoinRequestPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyJoinRequest>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}

/// Create a copy of FamilyJoinRequestPage
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
mixin _$ProfileFamily {

 String get id; int get number; String get name; int get level; String? get emblemUrl; FamilyRole get role;
/// Create a copy of ProfileFamily
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileFamilyCopyWith<ProfileFamily> get copyWith => _$ProfileFamilyCopyWithImpl<ProfileFamily>(this as ProfileFamily, _$identity);

  /// Serializes this ProfileFamily to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileFamily;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileFamily&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.emblemUrl, _this.emblemUrl) || other.emblemUrl == _this.emblemUrl)&&(identical(other.role, _this.role) || other.role == _this.role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileFamily;
  return Object.hash(runtimeType,_this.id,_this.number,_this.name,_this.level,_this.emblemUrl,_this.role);
}

@override
String toString() {
  final _this = this as ProfileFamily;
  return 'ProfileFamily(id: ${_this.id}, number: ${_this.number}, name: ${_this.name}, level: ${_this.level}, emblemUrl: ${_this.emblemUrl}, role: ${_this.role})';
}


}

/// @nodoc
abstract mixin class $ProfileFamilyCopyWith<$Res>  {
  factory $ProfileFamilyCopyWith(ProfileFamily value, $Res Function(ProfileFamily) _then) = _$ProfileFamilyCopyWithImpl;
@useResult
$Res call({
 String id, int number, String name, int level, String? emblemUrl, FamilyRole role
});




}
/// @nodoc
class _$ProfileFamilyCopyWithImpl<$Res>
    implements $ProfileFamilyCopyWith<$Res> {
  _$ProfileFamilyCopyWithImpl(this._self, this._then);

  final ProfileFamily _self;
  final $Res Function(ProfileFamily) _then;

/// Create a copy of ProfileFamily
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? name = null,Object? level = null,Object? emblemUrl = freezed,Object? role = null,}) {
  return _then(ProfileFamily(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileFamily].
extension ProfileFamilyPatterns on ProfileFamily {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileFamily value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileFamily() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileFamily value)  $default,){
final _that = this;
switch (_that) {
case _ProfileFamily():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileFamily value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileFamily() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int number,  String name,  int level,  String? emblemUrl,  FamilyRole role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileFamily() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.level,_that.emblemUrl,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int number,  String name,  int level,  String? emblemUrl,  FamilyRole role)  $default,) {final _that = this;
switch (_that) {
case _ProfileFamily():
return $default(_that.id,_that.number,_that.name,_that.level,_that.emblemUrl,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int number,  String name,  int level,  String? emblemUrl,  FamilyRole role)?  $default,) {final _that = this;
switch (_that) {
case _ProfileFamily() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.level,_that.emblemUrl,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileFamily implements ProfileFamily {
  const _ProfileFamily({required this.id, required this.number, required this.name, required this.level, required this.emblemUrl, required this.role});
  factory _ProfileFamily.fromJson(Map<String, dynamic> json) => _$ProfileFamilyFromJson(json);

@override final  String id;
@override final  int number;
@override final  String name;
@override final  int level;
@override final  String? emblemUrl;
@override final  FamilyRole role;

/// Create a copy of ProfileFamily
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileFamilyCopyWith<_ProfileFamily> get copyWith => __$ProfileFamilyCopyWithImpl<_ProfileFamily>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileFamilyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileFamily&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.level, level) || other.level == level)&&(identical(other.emblemUrl, emblemUrl) || other.emblemUrl == emblemUrl)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,number,name,level,emblemUrl,role);
}

@override
String toString() {
    return 'ProfileFamily(id: $id, number: $number, name: $name, level: $level, emblemUrl: $emblemUrl, role: $role)';
}


}

/// @nodoc
abstract mixin class _$ProfileFamilyCopyWith<$Res> implements $ProfileFamilyCopyWith<$Res> {
  factory _$ProfileFamilyCopyWith(_ProfileFamily value, $Res Function(_ProfileFamily) _then) = __$ProfileFamilyCopyWithImpl;
@override @useResult
$Res call({
 String id, int number, String name, int level, String? emblemUrl, FamilyRole role
});




}
/// @nodoc
class __$ProfileFamilyCopyWithImpl<$Res>
    implements _$ProfileFamilyCopyWith<$Res> {
  __$ProfileFamilyCopyWithImpl(this._self, this._then);

  final _ProfileFamily _self;
  final $Res Function(_ProfileFamily) _then;

/// Create a copy of ProfileFamily
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? name = null,Object? level = null,Object? emblemUrl = freezed,Object? role = null,}) {
  return _then(_ProfileFamily(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,emblemUrl: freezed == emblemUrl ? _self.emblemUrl : emblemUrl // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,
  ));
}


}

// dart format on
