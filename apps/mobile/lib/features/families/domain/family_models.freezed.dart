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
 String? get myRequestId;/// v1.25-live: the cover picture, or null (the page draws its own).
 String? get coverUrl;/// v1.25-live: the short line under the name, or null.
 String? get tagline;/// v1.25-live: pending join requests (leader and deputies only).
 int? get pendingRequestCount;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Family&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.emblemUrl, _this.emblemUrl) || other.emblemUrl == _this.emblemUrl)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.points, _this.points) || other.points == _this.points)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.capacity, _this.capacity) || other.capacity == _this.capacity)&&(identical(other.nextLevelPoints, _this.nextLevelPoints) || other.nextLevelPoints == _this.nextLevelPoints)&&(identical(other.leader, _this.leader) || other.leader == _this.leader)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.myRole, _this.myRole) || other.myRole == _this.myRole)&&(identical(other.myRequestId, _this.myRequestId) || other.myRequestId == _this.myRequestId)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.tagline, _this.tagline) || other.tagline == _this.tagline)&&(identical(other.pendingRequestCount, _this.pendingRequestCount) || other.pendingRequestCount == _this.pendingRequestCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Family;
  return Object.hash(runtimeType,_this.id,_this.number,_this.name,_this.emblemUrl,_this.level,_this.points,_this.memberCount,_this.capacity,_this.nextLevelPoints,_this.leader,_this.createdAt,_this.myRole,_this.myRequestId,_this.coverUrl,_this.tagline,_this.pendingRequestCount);
}

@override
String toString() {
  final _this = this as Family;
  return 'Family(id: ${_this.id}, number: ${_this.number}, name: ${_this.name}, emblemUrl: ${_this.emblemUrl}, level: ${_this.level}, points: ${_this.points}, memberCount: ${_this.memberCount}, capacity: ${_this.capacity}, nextLevelPoints: ${_this.nextLevelPoints}, leader: ${_this.leader}, createdAt: ${_this.createdAt}, myRole: ${_this.myRole}, myRequestId: ${_this.myRequestId}, coverUrl: ${_this.coverUrl}, tagline: ${_this.tagline}, pendingRequestCount: ${_this.pendingRequestCount})';
}


}

/// @nodoc
abstract mixin class $FamilyCopyWith<$Res>  {
  factory $FamilyCopyWith(Family value, $Res Function(Family) _then) = _$FamilyCopyWithImpl;
@useResult
$Res call({
 String id, int number, String name, String? emblemUrl, int level, int points, int memberCount, int capacity, int? nextLevelPoints, UserSummary? leader, DateTime createdAt, FamilyRole? myRole, String? myRequestId, String? coverUrl, String? tagline, int? pendingRequestCount
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? name = null,Object? emblemUrl = freezed,Object? level = null,Object? points = null,Object? memberCount = null,Object? capacity = null,Object? nextLevelPoints = freezed,Object? leader = freezed,Object? createdAt = null,Object? myRole = freezed,Object? myRequestId = freezed,Object? coverUrl = freezed,Object? tagline = freezed,Object? pendingRequestCount = freezed,}) {
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
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,tagline: freezed == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String?,pendingRequestCount: freezed == pendingRequestCount ? _self.pendingRequestCount : pendingRequestCount // ignore: cast_nullable_to_non_nullable
as int?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity,  int? nextLevelPoints,  UserSummary? leader,  DateTime createdAt,  FamilyRole? myRole,  String? myRequestId,  String? coverUrl,  String? tagline,  int? pendingRequestCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Family() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity,_that.nextLevelPoints,_that.leader,_that.createdAt,_that.myRole,_that.myRequestId,_that.coverUrl,_that.tagline,_that.pendingRequestCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity,  int? nextLevelPoints,  UserSummary? leader,  DateTime createdAt,  FamilyRole? myRole,  String? myRequestId,  String? coverUrl,  String? tagline,  int? pendingRequestCount)  $default,) {final _that = this;
switch (_that) {
case _Family():
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity,_that.nextLevelPoints,_that.leader,_that.createdAt,_that.myRole,_that.myRequestId,_that.coverUrl,_that.tagline,_that.pendingRequestCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int number,  String name,  String? emblemUrl,  int level,  int points,  int memberCount,  int capacity,  int? nextLevelPoints,  UserSummary? leader,  DateTime createdAt,  FamilyRole? myRole,  String? myRequestId,  String? coverUrl,  String? tagline,  int? pendingRequestCount)?  $default,) {final _that = this;
switch (_that) {
case _Family() when $default != null:
return $default(_that.id,_that.number,_that.name,_that.emblemUrl,_that.level,_that.points,_that.memberCount,_that.capacity,_that.nextLevelPoints,_that.leader,_that.createdAt,_that.myRole,_that.myRequestId,_that.coverUrl,_that.tagline,_that.pendingRequestCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Family extends Family {
  const _Family({required this.id, required this.number, required this.name, required this.emblemUrl, required this.level, required this.points, required this.memberCount, required this.capacity, required this.nextLevelPoints, required this.leader, required this.createdAt, required this.myRole, required this.myRequestId, this.coverUrl, this.tagline, this.pendingRequestCount}): super._();
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
/// v1.25-live: the cover picture, or null (the page draws its own).
@override final  String? coverUrl;
/// v1.25-live: the short line under the name, or null.
@override final  String? tagline;
/// v1.25-live: pending join requests (leader and deputies only).
@override final  int? pendingRequestCount;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Family&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.name, name) || other.name == name)&&(identical(other.emblemUrl, emblemUrl) || other.emblemUrl == emblemUrl)&&(identical(other.level, level) || other.level == level)&&(identical(other.points, points) || other.points == points)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.nextLevelPoints, nextLevelPoints) || other.nextLevelPoints == nextLevelPoints)&&(identical(other.leader, leader) || other.leader == leader)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.myRole, myRole) || other.myRole == myRole)&&(identical(other.myRequestId, myRequestId) || other.myRequestId == myRequestId)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.tagline, tagline) || other.tagline == tagline)&&(identical(other.pendingRequestCount, pendingRequestCount) || other.pendingRequestCount == pendingRequestCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,number,name,emblemUrl,level,points,memberCount,capacity,nextLevelPoints,leader,createdAt,myRole,myRequestId,coverUrl,tagline,pendingRequestCount);
}

@override
String toString() {
    return 'Family(id: $id, number: $number, name: $name, emblemUrl: $emblemUrl, level: $level, points: $points, memberCount: $memberCount, capacity: $capacity, nextLevelPoints: $nextLevelPoints, leader: $leader, createdAt: $createdAt, myRole: $myRole, myRequestId: $myRequestId, coverUrl: $coverUrl, tagline: $tagline, pendingRequestCount: $pendingRequestCount)';
}


}

/// @nodoc
abstract mixin class _$FamilyCopyWith<$Res> implements $FamilyCopyWith<$Res> {
  factory _$FamilyCopyWith(_Family value, $Res Function(_Family) _then) = __$FamilyCopyWithImpl;
@override @useResult
$Res call({
 String id, int number, String name, String? emblemUrl, int level, int points, int memberCount, int capacity, int? nextLevelPoints, UserSummary? leader, DateTime createdAt, FamilyRole? myRole, String? myRequestId, String? coverUrl, String? tagline, int? pendingRequestCount
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? name = null,Object? emblemUrl = freezed,Object? level = null,Object? points = null,Object? memberCount = null,Object? capacity = null,Object? nextLevelPoints = freezed,Object? leader = freezed,Object? createdAt = null,Object? myRole = freezed,Object? myRequestId = freezed,Object? coverUrl = freezed,Object? tagline = freezed,Object? pendingRequestCount = freezed,}) {
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
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,tagline: freezed == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String?,pendingRequestCount: freezed == pendingRequestCount ? _self.pendingRequestCount : pendingRequestCount // ignore: cast_nullable_to_non_nullable
as int?,
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

 UserSummary get user; FamilyRole get role; DateTime get joinedAt; int get points;/// v1.25-live: the points given in the current month.
 int get monthPoints;/// v1.25-live: online / last active, when the caller may see it.
 FamilyPresence? get presence;/// v1.25-live: muted in the family chat (leader and deputies see it).
 bool? get chatMuted;/// v1.25-live: the place by points (with `sort=POINTS`).
 int? get rank;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyMember&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.joinedAt, _this.joinedAt) || other.joinedAt == _this.joinedAt)&&(identical(other.points, _this.points) || other.points == _this.points)&&(identical(other.monthPoints, _this.monthPoints) || other.monthPoints == _this.monthPoints)&&(identical(other.presence, _this.presence) || other.presence == _this.presence)&&(identical(other.chatMuted, _this.chatMuted) || other.chatMuted == _this.chatMuted)&&(identical(other.rank, _this.rank) || other.rank == _this.rank));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyMember;
  return Object.hash(runtimeType,_this.user,_this.role,_this.joinedAt,_this.points,_this.monthPoints,_this.presence,_this.chatMuted,_this.rank);
}

@override
String toString() {
  final _this = this as FamilyMember;
  return 'FamilyMember(user: ${_this.user}, role: ${_this.role}, joinedAt: ${_this.joinedAt}, points: ${_this.points}, monthPoints: ${_this.monthPoints}, presence: ${_this.presence}, chatMuted: ${_this.chatMuted}, rank: ${_this.rank})';
}


}

/// @nodoc
abstract mixin class $FamilyMemberCopyWith<$Res>  {
  factory $FamilyMemberCopyWith(FamilyMember value, $Res Function(FamilyMember) _then) = _$FamilyMemberCopyWithImpl;
@useResult
$Res call({
 UserSummary user, FamilyRole role, DateTime joinedAt, int points, int monthPoints, FamilyPresence? presence, bool? chatMuted, int? rank
});


$UserSummaryCopyWith<$Res> get user;$FamilyPresenceCopyWith<$Res>? get presence;

}
/// @nodoc
class _$FamilyMemberCopyWithImpl<$Res>
    implements $FamilyMemberCopyWith<$Res> {
  _$FamilyMemberCopyWithImpl(this._self, this._then);

  final FamilyMember _self;
  final $Res Function(FamilyMember) _then;

/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? role = null,Object? joinedAt = null,Object? points = null,Object? monthPoints = null,Object? presence = freezed,Object? chatMuted = freezed,Object? rank = freezed,}) {
  return _then(FamilyMember(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,monthPoints: null == monthPoints ? _self.monthPoints : monthPoints // ignore: cast_nullable_to_non_nullable
as int,presence: freezed == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as FamilyPresence?,chatMuted: freezed == chatMuted ? _self.chatMuted : chatMuted // ignore: cast_nullable_to_non_nullable
as bool?,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,
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
}/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyPresenceCopyWith<$Res>? get presence {
    if (_self.presence == null) {
    return null;
  }

  return $FamilyPresenceCopyWith<$Res>(_self.presence!, (value) {
    return _then(_self.copyWith(presence: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  FamilyRole role,  DateTime joinedAt,  int points,  int monthPoints,  FamilyPresence? presence,  bool? chatMuted,  int? rank)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyMember() when $default != null:
return $default(_that.user,_that.role,_that.joinedAt,_that.points,_that.monthPoints,_that.presence,_that.chatMuted,_that.rank);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  FamilyRole role,  DateTime joinedAt,  int points,  int monthPoints,  FamilyPresence? presence,  bool? chatMuted,  int? rank)  $default,) {final _that = this;
switch (_that) {
case _FamilyMember():
return $default(_that.user,_that.role,_that.joinedAt,_that.points,_that.monthPoints,_that.presence,_that.chatMuted,_that.rank);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  FamilyRole role,  DateTime joinedAt,  int points,  int monthPoints,  FamilyPresence? presence,  bool? chatMuted,  int? rank)?  $default,) {final _that = this;
switch (_that) {
case _FamilyMember() when $default != null:
return $default(_that.user,_that.role,_that.joinedAt,_that.points,_that.monthPoints,_that.presence,_that.chatMuted,_that.rank);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyMember implements FamilyMember {
  const _FamilyMember({required this.user, required this.role, required this.joinedAt, required this.points, this.monthPoints = 0, this.presence, this.chatMuted, this.rank});
  factory _FamilyMember.fromJson(Map<String, dynamic> json) => _$FamilyMemberFromJson(json);

@override final  UserSummary user;
@override final  FamilyRole role;
@override final  DateTime joinedAt;
@override final  int points;
/// v1.25-live: the points given in the current month.
@override@JsonKey() final  int monthPoints;
/// v1.25-live: online / last active, when the caller may see it.
@override final  FamilyPresence? presence;
/// v1.25-live: muted in the family chat (leader and deputies see it).
@override final  bool? chatMuted;
/// v1.25-live: the place by points (with `sort=POINTS`).
@override final  int? rank;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyMember&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt)&&(identical(other.points, points) || other.points == points)&&(identical(other.monthPoints, monthPoints) || other.monthPoints == monthPoints)&&(identical(other.presence, presence) || other.presence == presence)&&(identical(other.chatMuted, chatMuted) || other.chatMuted == chatMuted)&&(identical(other.rank, rank) || other.rank == rank));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,user,role,joinedAt,points,monthPoints,presence,chatMuted,rank);
}

@override
String toString() {
    return 'FamilyMember(user: $user, role: $role, joinedAt: $joinedAt, points: $points, monthPoints: $monthPoints, presence: $presence, chatMuted: $chatMuted, rank: $rank)';
}


}

/// @nodoc
abstract mixin class _$FamilyMemberCopyWith<$Res> implements $FamilyMemberCopyWith<$Res> {
  factory _$FamilyMemberCopyWith(_FamilyMember value, $Res Function(_FamilyMember) _then) = __$FamilyMemberCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, FamilyRole role, DateTime joinedAt, int points, int monthPoints, FamilyPresence? presence, bool? chatMuted, int? rank
});


@override $UserSummaryCopyWith<$Res> get user;@override $FamilyPresenceCopyWith<$Res>? get presence;

}
/// @nodoc
class __$FamilyMemberCopyWithImpl<$Res>
    implements _$FamilyMemberCopyWith<$Res> {
  __$FamilyMemberCopyWithImpl(this._self, this._then);

  final _FamilyMember _self;
  final $Res Function(_FamilyMember) _then;

/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? role = null,Object? joinedAt = null,Object? points = null,Object? monthPoints = null,Object? presence = freezed,Object? chatMuted = freezed,Object? rank = freezed,}) {
  return _then(_FamilyMember(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,monthPoints: null == monthPoints ? _self.monthPoints : monthPoints // ignore: cast_nullable_to_non_nullable
as int,presence: freezed == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as FamilyPresence?,chatMuted: freezed == chatMuted ? _self.chatMuted : chatMuted // ignore: cast_nullable_to_non_nullable
as bool?,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,
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
}/// Create a copy of FamilyMember
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyPresenceCopyWith<$Res>? get presence {
    if (_self.presence == null) {
    return null;
  }

  return $FamilyPresenceCopyWith<$Res>(_self.presence!, (value) {
    return _then(_self.copyWith(presence: value));
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


/// @nodoc
mixin _$FamilyPresence {

 bool get online; DateTime? get lastActiveAt;
/// Create a copy of FamilyPresence
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyPresenceCopyWith<FamilyPresence> get copyWith => _$FamilyPresenceCopyWithImpl<FamilyPresence>(this as FamilyPresence, _$identity);

  /// Serializes this FamilyPresence to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyPresence;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyPresence&&(identical(other.online, _this.online) || other.online == _this.online)&&(identical(other.lastActiveAt, _this.lastActiveAt) || other.lastActiveAt == _this.lastActiveAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyPresence;
  return Object.hash(runtimeType,_this.online,_this.lastActiveAt);
}

@override
String toString() {
  final _this = this as FamilyPresence;
  return 'FamilyPresence(online: ${_this.online}, lastActiveAt: ${_this.lastActiveAt})';
}


}

/// @nodoc
abstract mixin class $FamilyPresenceCopyWith<$Res>  {
  factory $FamilyPresenceCopyWith(FamilyPresence value, $Res Function(FamilyPresence) _then) = _$FamilyPresenceCopyWithImpl;
@useResult
$Res call({
 bool online, DateTime? lastActiveAt
});




}
/// @nodoc
class _$FamilyPresenceCopyWithImpl<$Res>
    implements $FamilyPresenceCopyWith<$Res> {
  _$FamilyPresenceCopyWithImpl(this._self, this._then);

  final FamilyPresence _self;
  final $Res Function(FamilyPresence) _then;

/// Create a copy of FamilyPresence
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? online = null,Object? lastActiveAt = freezed,}) {
  return _then(FamilyPresence(
online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,lastActiveAt: freezed == lastActiveAt ? _self.lastActiveAt : lastActiveAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FamilyPresence].
extension FamilyPresencePatterns on FamilyPresence {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyPresence value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyPresence() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyPresence value)  $default,){
final _that = this;
switch (_that) {
case _FamilyPresence():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyPresence value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyPresence() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool online,  DateTime? lastActiveAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyPresence() when $default != null:
return $default(_that.online,_that.lastActiveAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool online,  DateTime? lastActiveAt)  $default,) {final _that = this;
switch (_that) {
case _FamilyPresence():
return $default(_that.online,_that.lastActiveAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool online,  DateTime? lastActiveAt)?  $default,) {final _that = this;
switch (_that) {
case _FamilyPresence() when $default != null:
return $default(_that.online,_that.lastActiveAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyPresence implements FamilyPresence {
  const _FamilyPresence({required this.online, required this.lastActiveAt});
  factory _FamilyPresence.fromJson(Map<String, dynamic> json) => _$FamilyPresenceFromJson(json);

@override final  bool online;
@override final  DateTime? lastActiveAt;

/// Create a copy of FamilyPresence
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyPresenceCopyWith<_FamilyPresence> get copyWith => __$FamilyPresenceCopyWithImpl<_FamilyPresence>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyPresenceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyPresence&&(identical(other.online, online) || other.online == online)&&(identical(other.lastActiveAt, lastActiveAt) || other.lastActiveAt == lastActiveAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,online,lastActiveAt);
}

@override
String toString() {
    return 'FamilyPresence(online: $online, lastActiveAt: $lastActiveAt)';
}


}

/// @nodoc
abstract mixin class _$FamilyPresenceCopyWith<$Res> implements $FamilyPresenceCopyWith<$Res> {
  factory _$FamilyPresenceCopyWith(_FamilyPresence value, $Res Function(_FamilyPresence) _then) = __$FamilyPresenceCopyWithImpl;
@override @useResult
$Res call({
 bool online, DateTime? lastActiveAt
});




}
/// @nodoc
class __$FamilyPresenceCopyWithImpl<$Res>
    implements _$FamilyPresenceCopyWith<$Res> {
  __$FamilyPresenceCopyWithImpl(this._self, this._then);

  final _FamilyPresence _self;
  final $Res Function(_FamilyPresence) _then;

/// Create a copy of FamilyPresence
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? online = null,Object? lastActiveAt = freezed,}) {
  return _then(_FamilyPresence(
online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,lastActiveAt: freezed == lastActiveAt ? _self.lastActiveAt : lastActiveAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$FamilyRankingEntry {

 int get rank; FamilyCard get family; int get score;
/// Create a copy of FamilyRankingEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyRankingEntryCopyWith<FamilyRankingEntry> get copyWith => _$FamilyRankingEntryCopyWithImpl<FamilyRankingEntry>(this as FamilyRankingEntry, _$identity);

  /// Serializes this FamilyRankingEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyRankingEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyRankingEntry&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.score, _this.score) || other.score == _this.score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyRankingEntry;
  return Object.hash(runtimeType,_this.rank,_this.family,_this.score);
}

@override
String toString() {
  final _this = this as FamilyRankingEntry;
  return 'FamilyRankingEntry(rank: ${_this.rank}, family: ${_this.family}, score: ${_this.score})';
}


}

/// @nodoc
abstract mixin class $FamilyRankingEntryCopyWith<$Res>  {
  factory $FamilyRankingEntryCopyWith(FamilyRankingEntry value, $Res Function(FamilyRankingEntry) _then) = _$FamilyRankingEntryCopyWithImpl;
@useResult
$Res call({
 int rank, FamilyCard family, int score
});


$FamilyCardCopyWith<$Res> get family;

}
/// @nodoc
class _$FamilyRankingEntryCopyWithImpl<$Res>
    implements $FamilyRankingEntryCopyWith<$Res> {
  _$FamilyRankingEntryCopyWithImpl(this._self, this._then);

  final FamilyRankingEntry _self;
  final $Res Function(FamilyRankingEntry) _then;

/// Create a copy of FamilyRankingEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = null,Object? family = null,Object? score = null,}) {
  return _then(FamilyRankingEntry(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as FamilyCard,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of FamilyRankingEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<$Res> get family {
  
  return $FamilyCardCopyWith<$Res>(_self.family, (value) {
    return _then(_self.copyWith(family: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyRankingEntry].
extension FamilyRankingEntryPatterns on FamilyRankingEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyRankingEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyRankingEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyRankingEntry value)  $default,){
final _that = this;
switch (_that) {
case _FamilyRankingEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyRankingEntry value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyRankingEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int rank,  FamilyCard family,  int score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyRankingEntry() when $default != null:
return $default(_that.rank,_that.family,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int rank,  FamilyCard family,  int score)  $default,) {final _that = this;
switch (_that) {
case _FamilyRankingEntry():
return $default(_that.rank,_that.family,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int rank,  FamilyCard family,  int score)?  $default,) {final _that = this;
switch (_that) {
case _FamilyRankingEntry() when $default != null:
return $default(_that.rank,_that.family,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyRankingEntry implements FamilyRankingEntry {
  const _FamilyRankingEntry({required this.rank, required this.family, required this.score});
  factory _FamilyRankingEntry.fromJson(Map<String, dynamic> json) => _$FamilyRankingEntryFromJson(json);

@override final  int rank;
@override final  FamilyCard family;
@override final  int score;

/// Create a copy of FamilyRankingEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyRankingEntryCopyWith<_FamilyRankingEntry> get copyWith => __$FamilyRankingEntryCopyWithImpl<_FamilyRankingEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyRankingEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyRankingEntry&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.family, family) || other.family == family)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,rank,family,score);
}

@override
String toString() {
    return 'FamilyRankingEntry(rank: $rank, family: $family, score: $score)';
}


}

/// @nodoc
abstract mixin class _$FamilyRankingEntryCopyWith<$Res> implements $FamilyRankingEntryCopyWith<$Res> {
  factory _$FamilyRankingEntryCopyWith(_FamilyRankingEntry value, $Res Function(_FamilyRankingEntry) _then) = __$FamilyRankingEntryCopyWithImpl;
@override @useResult
$Res call({
 int rank, FamilyCard family, int score
});


@override $FamilyCardCopyWith<$Res> get family;

}
/// @nodoc
class __$FamilyRankingEntryCopyWithImpl<$Res>
    implements _$FamilyRankingEntryCopyWith<$Res> {
  __$FamilyRankingEntryCopyWithImpl(this._self, this._then);

  final _FamilyRankingEntry _self;
  final $Res Function(_FamilyRankingEntry) _then;

/// Create a copy of FamilyRankingEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rank = null,Object? family = null,Object? score = null,}) {
  return _then(_FamilyRankingEntry(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as FamilyCard,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of FamilyRankingEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<$Res> get family {
  
  return $FamilyCardCopyWith<$Res>(_self.family, (value) {
    return _then(_self.copyWith(family: value));
  });
}
}


/// @nodoc
mixin _$FamilyRankingMe {

 FamilyCard get family; int? get rank; int get score;
/// Create a copy of FamilyRankingMe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyRankingMeCopyWith<FamilyRankingMe> get copyWith => _$FamilyRankingMeCopyWithImpl<FamilyRankingMe>(this as FamilyRankingMe, _$identity);

  /// Serializes this FamilyRankingMe to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyRankingMe;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyRankingMe&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.score, _this.score) || other.score == _this.score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyRankingMe;
  return Object.hash(runtimeType,_this.family,_this.rank,_this.score);
}

@override
String toString() {
  final _this = this as FamilyRankingMe;
  return 'FamilyRankingMe(family: ${_this.family}, rank: ${_this.rank}, score: ${_this.score})';
}


}

/// @nodoc
abstract mixin class $FamilyRankingMeCopyWith<$Res>  {
  factory $FamilyRankingMeCopyWith(FamilyRankingMe value, $Res Function(FamilyRankingMe) _then) = _$FamilyRankingMeCopyWithImpl;
@useResult
$Res call({
 FamilyCard family, int? rank, int score
});


$FamilyCardCopyWith<$Res> get family;

}
/// @nodoc
class _$FamilyRankingMeCopyWithImpl<$Res>
    implements $FamilyRankingMeCopyWith<$Res> {
  _$FamilyRankingMeCopyWithImpl(this._self, this._then);

  final FamilyRankingMe _self;
  final $Res Function(FamilyRankingMe) _then;

/// Create a copy of FamilyRankingMe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? family = null,Object? rank = freezed,Object? score = null,}) {
  return _then(FamilyRankingMe(
family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as FamilyCard,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of FamilyRankingMe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<$Res> get family {
  
  return $FamilyCardCopyWith<$Res>(_self.family, (value) {
    return _then(_self.copyWith(family: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyRankingMe].
extension FamilyRankingMePatterns on FamilyRankingMe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyRankingMe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyRankingMe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyRankingMe value)  $default,){
final _that = this;
switch (_that) {
case _FamilyRankingMe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyRankingMe value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyRankingMe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( FamilyCard family,  int? rank,  int score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyRankingMe() when $default != null:
return $default(_that.family,_that.rank,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( FamilyCard family,  int? rank,  int score)  $default,) {final _that = this;
switch (_that) {
case _FamilyRankingMe():
return $default(_that.family,_that.rank,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( FamilyCard family,  int? rank,  int score)?  $default,) {final _that = this;
switch (_that) {
case _FamilyRankingMe() when $default != null:
return $default(_that.family,_that.rank,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyRankingMe implements FamilyRankingMe {
  const _FamilyRankingMe({required this.family, required this.rank, required this.score});
  factory _FamilyRankingMe.fromJson(Map<String, dynamic> json) => _$FamilyRankingMeFromJson(json);

@override final  FamilyCard family;
@override final  int? rank;
@override final  int score;

/// Create a copy of FamilyRankingMe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyRankingMeCopyWith<_FamilyRankingMe> get copyWith => __$FamilyRankingMeCopyWithImpl<_FamilyRankingMe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyRankingMeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyRankingMe&&(identical(other.family, family) || other.family == family)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,family,rank,score);
}

@override
String toString() {
    return 'FamilyRankingMe(family: $family, rank: $rank, score: $score)';
}


}

/// @nodoc
abstract mixin class _$FamilyRankingMeCopyWith<$Res> implements $FamilyRankingMeCopyWith<$Res> {
  factory _$FamilyRankingMeCopyWith(_FamilyRankingMe value, $Res Function(_FamilyRankingMe) _then) = __$FamilyRankingMeCopyWithImpl;
@override @useResult
$Res call({
 FamilyCard family, int? rank, int score
});


@override $FamilyCardCopyWith<$Res> get family;

}
/// @nodoc
class __$FamilyRankingMeCopyWithImpl<$Res>
    implements _$FamilyRankingMeCopyWith<$Res> {
  __$FamilyRankingMeCopyWithImpl(this._self, this._then);

  final _FamilyRankingMe _self;
  final $Res Function(_FamilyRankingMe) _then;

/// Create a copy of FamilyRankingMe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? family = null,Object? rank = freezed,Object? score = null,}) {
  return _then(_FamilyRankingMe(
family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as FamilyCard,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of FamilyRankingMe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyCardCopyWith<$Res> get family {
  
  return $FamilyCardCopyWith<$Res>(_self.family, (value) {
    return _then(_self.copyWith(family: value));
  });
}
}


/// @nodoc
mixin _$FamilyRankings {

 FamilyRankingBoard get board; DateTime get startsAt; DateTime get endsAt; List<FamilyRankingEntry> get data; PageInfo get page; FamilyRankingMe? get me;
/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyRankingsCopyWith<FamilyRankings> get copyWith => _$FamilyRankingsCopyWithImpl<FamilyRankings>(this as FamilyRankings, _$identity);

  /// Serializes this FamilyRankings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyRankings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyRankings&&(identical(other.board, _this.board) || other.board == _this.board)&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt)&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.me, _this.me) || other.me == _this.me));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyRankings;
  return Object.hash(runtimeType,_this.board,_this.startsAt,_this.endsAt,const DeepCollectionEquality().hash(_this.data),_this.page,_this.me);
}

@override
String toString() {
  final _this = this as FamilyRankings;
  return 'FamilyRankings(board: ${_this.board}, startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt}, data: ${_this.data}, page: ${_this.page}, me: ${_this.me})';
}


}

/// @nodoc
abstract mixin class $FamilyRankingsCopyWith<$Res>  {
  factory $FamilyRankingsCopyWith(FamilyRankings value, $Res Function(FamilyRankings) _then) = _$FamilyRankingsCopyWithImpl;
@useResult
$Res call({
 FamilyRankingBoard board, DateTime startsAt, DateTime endsAt, List<FamilyRankingEntry> data, PageInfo page, FamilyRankingMe? me
});


$PageInfoCopyWith<$Res> get page;$FamilyRankingMeCopyWith<$Res>? get me;

}
/// @nodoc
class _$FamilyRankingsCopyWithImpl<$Res>
    implements $FamilyRankingsCopyWith<$Res> {
  _$FamilyRankingsCopyWithImpl(this._self, this._then);

  final FamilyRankings _self;
  final $Res Function(FamilyRankings) _then;

/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? board = null,Object? startsAt = null,Object? endsAt = null,Object? data = null,Object? page = null,Object? me = freezed,}) {
  return _then(FamilyRankings(
board: null == board ? _self.board : board // ignore: cast_nullable_to_non_nullable
as FamilyRankingBoard,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyRankingEntry>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,me: freezed == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as FamilyRankingMe?,
  ));
}
/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyRankingMeCopyWith<$Res>? get me {
    if (_self.me == null) {
    return null;
  }

  return $FamilyRankingMeCopyWith<$Res>(_self.me!, (value) {
    return _then(_self.copyWith(me: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyRankings].
extension FamilyRankingsPatterns on FamilyRankings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyRankings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyRankings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyRankings value)  $default,){
final _that = this;
switch (_that) {
case _FamilyRankings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyRankings value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyRankings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( FamilyRankingBoard board,  DateTime startsAt,  DateTime endsAt,  List<FamilyRankingEntry> data,  PageInfo page,  FamilyRankingMe? me)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyRankings() when $default != null:
return $default(_that.board,_that.startsAt,_that.endsAt,_that.data,_that.page,_that.me);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( FamilyRankingBoard board,  DateTime startsAt,  DateTime endsAt,  List<FamilyRankingEntry> data,  PageInfo page,  FamilyRankingMe? me)  $default,) {final _that = this;
switch (_that) {
case _FamilyRankings():
return $default(_that.board,_that.startsAt,_that.endsAt,_that.data,_that.page,_that.me);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( FamilyRankingBoard board,  DateTime startsAt,  DateTime endsAt,  List<FamilyRankingEntry> data,  PageInfo page,  FamilyRankingMe? me)?  $default,) {final _that = this;
switch (_that) {
case _FamilyRankings() when $default != null:
return $default(_that.board,_that.startsAt,_that.endsAt,_that.data,_that.page,_that.me);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyRankings implements FamilyRankings {
  const _FamilyRankings({required this.board, required this.startsAt, required this.endsAt, required  List<FamilyRankingEntry> data, required this.page, required this.me}): _data = data;
  factory _FamilyRankings.fromJson(Map<String, dynamic> json) => _$FamilyRankingsFromJson(json);

@override final  FamilyRankingBoard board;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
 final  List<FamilyRankingEntry> _data;
@override List<FamilyRankingEntry> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;
@override final  FamilyRankingMe? me;

/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyRankingsCopyWith<_FamilyRankings> get copyWith => __$FamilyRankingsCopyWithImpl<_FamilyRankings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyRankingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyRankings&&(identical(other.board, board) || other.board == board)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page)&&(identical(other.me, me) || other.me == me));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,board,startsAt,endsAt,const DeepCollectionEquality().hash(_data),page,me);
}

@override
String toString() {
    return 'FamilyRankings(board: $board, startsAt: $startsAt, endsAt: $endsAt, data: $data, page: $page, me: $me)';
}


}

/// @nodoc
abstract mixin class _$FamilyRankingsCopyWith<$Res> implements $FamilyRankingsCopyWith<$Res> {
  factory _$FamilyRankingsCopyWith(_FamilyRankings value, $Res Function(_FamilyRankings) _then) = __$FamilyRankingsCopyWithImpl;
@override @useResult
$Res call({
 FamilyRankingBoard board, DateTime startsAt, DateTime endsAt, List<FamilyRankingEntry> data, PageInfo page, FamilyRankingMe? me
});


@override $PageInfoCopyWith<$Res> get page;@override $FamilyRankingMeCopyWith<$Res>? get me;

}
/// @nodoc
class __$FamilyRankingsCopyWithImpl<$Res>
    implements _$FamilyRankingsCopyWith<$Res> {
  __$FamilyRankingsCopyWithImpl(this._self, this._then);

  final _FamilyRankings _self;
  final $Res Function(_FamilyRankings) _then;

/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? board = null,Object? startsAt = null,Object? endsAt = null,Object? data = null,Object? page = null,Object? me = freezed,}) {
  return _then(_FamilyRankings(
board: null == board ? _self.board : board // ignore: cast_nullable_to_non_nullable
as FamilyRankingBoard,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyRankingEntry>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,me: freezed == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as FamilyRankingMe?,
  ));
}

/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}/// Create a copy of FamilyRankings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyRankingMeCopyWith<$Res>? get me {
    if (_self.me == null) {
    return null;
  }

  return $FamilyRankingMeCopyWith<$Res>(_self.me!, (value) {
    return _then(_self.copyWith(me: value));
  });
}
}


/// @nodoc
mixin _$FamilyBoardStanding {

 int? get rank; int get score; DateTime get startsAt; DateTime get endsAt;
/// Create a copy of FamilyBoardStanding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyBoardStandingCopyWith<FamilyBoardStanding> get copyWith => _$FamilyBoardStandingCopyWithImpl<FamilyBoardStanding>(this as FamilyBoardStanding, _$identity);

  /// Serializes this FamilyBoardStanding to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyBoardStanding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyBoardStanding&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyBoardStanding;
  return Object.hash(runtimeType,_this.rank,_this.score,_this.startsAt,_this.endsAt);
}

@override
String toString() {
  final _this = this as FamilyBoardStanding;
  return 'FamilyBoardStanding(rank: ${_this.rank}, score: ${_this.score}, startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt})';
}


}

/// @nodoc
abstract mixin class $FamilyBoardStandingCopyWith<$Res>  {
  factory $FamilyBoardStandingCopyWith(FamilyBoardStanding value, $Res Function(FamilyBoardStanding) _then) = _$FamilyBoardStandingCopyWithImpl;
@useResult
$Res call({
 int? rank, int score, DateTime startsAt, DateTime endsAt
});




}
/// @nodoc
class _$FamilyBoardStandingCopyWithImpl<$Res>
    implements $FamilyBoardStandingCopyWith<$Res> {
  _$FamilyBoardStandingCopyWithImpl(this._self, this._then);

  final FamilyBoardStanding _self;
  final $Res Function(FamilyBoardStanding) _then;

/// Create a copy of FamilyBoardStanding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = freezed,Object? score = null,Object? startsAt = null,Object? endsAt = null,}) {
  return _then(FamilyBoardStanding(
rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FamilyBoardStanding].
extension FamilyBoardStandingPatterns on FamilyBoardStanding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyBoardStanding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyBoardStanding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyBoardStanding value)  $default,){
final _that = this;
switch (_that) {
case _FamilyBoardStanding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyBoardStanding value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyBoardStanding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? rank,  int score,  DateTime startsAt,  DateTime endsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyBoardStanding() when $default != null:
return $default(_that.rank,_that.score,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? rank,  int score,  DateTime startsAt,  DateTime endsAt)  $default,) {final _that = this;
switch (_that) {
case _FamilyBoardStanding():
return $default(_that.rank,_that.score,_that.startsAt,_that.endsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? rank,  int score,  DateTime startsAt,  DateTime endsAt)?  $default,) {final _that = this;
switch (_that) {
case _FamilyBoardStanding() when $default != null:
return $default(_that.rank,_that.score,_that.startsAt,_that.endsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyBoardStanding implements FamilyBoardStanding {
  const _FamilyBoardStanding({required this.rank, required this.score, required this.startsAt, required this.endsAt});
  factory _FamilyBoardStanding.fromJson(Map<String, dynamic> json) => _$FamilyBoardStandingFromJson(json);

@override final  int? rank;
@override final  int score;
@override final  DateTime startsAt;
@override final  DateTime endsAt;

/// Create a copy of FamilyBoardStanding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyBoardStandingCopyWith<_FamilyBoardStanding> get copyWith => __$FamilyBoardStandingCopyWithImpl<_FamilyBoardStanding>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyBoardStandingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyBoardStanding&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.score, score) || other.score == score)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,rank,score,startsAt,endsAt);
}

@override
String toString() {
    return 'FamilyBoardStanding(rank: $rank, score: $score, startsAt: $startsAt, endsAt: $endsAt)';
}


}

/// @nodoc
abstract mixin class _$FamilyBoardStandingCopyWith<$Res> implements $FamilyBoardStandingCopyWith<$Res> {
  factory _$FamilyBoardStandingCopyWith(_FamilyBoardStanding value, $Res Function(_FamilyBoardStanding) _then) = __$FamilyBoardStandingCopyWithImpl;
@override @useResult
$Res call({
 int? rank, int score, DateTime startsAt, DateTime endsAt
});




}
/// @nodoc
class __$FamilyBoardStandingCopyWithImpl<$Res>
    implements _$FamilyBoardStandingCopyWith<$Res> {
  __$FamilyBoardStandingCopyWithImpl(this._self, this._then);

  final _FamilyBoardStanding _self;
  final $Res Function(_FamilyBoardStanding) _then;

/// Create a copy of FamilyBoardStanding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rank = freezed,Object? score = null,Object? startsAt = null,Object? endsAt = null,}) {
  return _then(_FamilyBoardStanding(
rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FamilyStanding {

 String get familyId; FamilyBoardStanding get prestige; FamilyBoardStanding get active;
/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyStandingCopyWith<FamilyStanding> get copyWith => _$FamilyStandingCopyWithImpl<FamilyStanding>(this as FamilyStanding, _$identity);

  /// Serializes this FamilyStanding to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyStanding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyStanding&&(identical(other.familyId, _this.familyId) || other.familyId == _this.familyId)&&(identical(other.prestige, _this.prestige) || other.prestige == _this.prestige)&&(identical(other.active, _this.active) || other.active == _this.active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyStanding;
  return Object.hash(runtimeType,_this.familyId,_this.prestige,_this.active);
}

@override
String toString() {
  final _this = this as FamilyStanding;
  return 'FamilyStanding(familyId: ${_this.familyId}, prestige: ${_this.prestige}, active: ${_this.active})';
}


}

/// @nodoc
abstract mixin class $FamilyStandingCopyWith<$Res>  {
  factory $FamilyStandingCopyWith(FamilyStanding value, $Res Function(FamilyStanding) _then) = _$FamilyStandingCopyWithImpl;
@useResult
$Res call({
 String familyId, FamilyBoardStanding prestige, FamilyBoardStanding active
});


$FamilyBoardStandingCopyWith<$Res> get prestige;$FamilyBoardStandingCopyWith<$Res> get active;

}
/// @nodoc
class _$FamilyStandingCopyWithImpl<$Res>
    implements $FamilyStandingCopyWith<$Res> {
  _$FamilyStandingCopyWithImpl(this._self, this._then);

  final FamilyStanding _self;
  final $Res Function(FamilyStanding) _then;

/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? familyId = null,Object? prestige = null,Object? active = null,}) {
  return _then(FamilyStanding(
familyId: null == familyId ? _self.familyId : familyId // ignore: cast_nullable_to_non_nullable
as String,prestige: null == prestige ? _self.prestige : prestige // ignore: cast_nullable_to_non_nullable
as FamilyBoardStanding,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as FamilyBoardStanding,
  ));
}
/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyBoardStandingCopyWith<$Res> get prestige {
  
  return $FamilyBoardStandingCopyWith<$Res>(_self.prestige, (value) {
    return _then(_self.copyWith(prestige: value));
  });
}/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyBoardStandingCopyWith<$Res> get active {
  
  return $FamilyBoardStandingCopyWith<$Res>(_self.active, (value) {
    return _then(_self.copyWith(active: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyStanding].
extension FamilyStandingPatterns on FamilyStanding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyStanding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyStanding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyStanding value)  $default,){
final _that = this;
switch (_that) {
case _FamilyStanding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyStanding value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyStanding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String familyId,  FamilyBoardStanding prestige,  FamilyBoardStanding active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyStanding() when $default != null:
return $default(_that.familyId,_that.prestige,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String familyId,  FamilyBoardStanding prestige,  FamilyBoardStanding active)  $default,) {final _that = this;
switch (_that) {
case _FamilyStanding():
return $default(_that.familyId,_that.prestige,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String familyId,  FamilyBoardStanding prestige,  FamilyBoardStanding active)?  $default,) {final _that = this;
switch (_that) {
case _FamilyStanding() when $default != null:
return $default(_that.familyId,_that.prestige,_that.active);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyStanding implements FamilyStanding {
  const _FamilyStanding({required this.familyId, required this.prestige, required this.active});
  factory _FamilyStanding.fromJson(Map<String, dynamic> json) => _$FamilyStandingFromJson(json);

@override final  String familyId;
@override final  FamilyBoardStanding prestige;
@override final  FamilyBoardStanding active;

/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyStandingCopyWith<_FamilyStanding> get copyWith => __$FamilyStandingCopyWithImpl<_FamilyStanding>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyStandingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyStanding&&(identical(other.familyId, familyId) || other.familyId == familyId)&&(identical(other.prestige, prestige) || other.prestige == prestige)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,familyId,prestige,active);
}

@override
String toString() {
    return 'FamilyStanding(familyId: $familyId, prestige: $prestige, active: $active)';
}


}

/// @nodoc
abstract mixin class _$FamilyStandingCopyWith<$Res> implements $FamilyStandingCopyWith<$Res> {
  factory _$FamilyStandingCopyWith(_FamilyStanding value, $Res Function(_FamilyStanding) _then) = __$FamilyStandingCopyWithImpl;
@override @useResult
$Res call({
 String familyId, FamilyBoardStanding prestige, FamilyBoardStanding active
});


@override $FamilyBoardStandingCopyWith<$Res> get prestige;@override $FamilyBoardStandingCopyWith<$Res> get active;

}
/// @nodoc
class __$FamilyStandingCopyWithImpl<$Res>
    implements _$FamilyStandingCopyWith<$Res> {
  __$FamilyStandingCopyWithImpl(this._self, this._then);

  final _FamilyStanding _self;
  final $Res Function(_FamilyStanding) _then;

/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? familyId = null,Object? prestige = null,Object? active = null,}) {
  return _then(_FamilyStanding(
familyId: null == familyId ? _self.familyId : familyId // ignore: cast_nullable_to_non_nullable
as String,prestige: null == prestige ? _self.prestige : prestige // ignore: cast_nullable_to_non_nullable
as FamilyBoardStanding,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as FamilyBoardStanding,
  ));
}

/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyBoardStandingCopyWith<$Res> get prestige {
  
  return $FamilyBoardStandingCopyWith<$Res>(_self.prestige, (value) {
    return _then(_self.copyWith(prestige: value));
  });
}/// Create a copy of FamilyStanding
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FamilyBoardStandingCopyWith<$Res> get active {
  
  return $FamilyBoardStandingCopyWith<$Res>(_self.active, (value) {
    return _then(_self.copyWith(active: value));
  });
}
}


/// @nodoc
mixin _$FamilyContribution {

 int get rank; UserSummary get user; FamilyRole get role; int get points;
/// Create a copy of FamilyContribution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyContributionCopyWith<FamilyContribution> get copyWith => _$FamilyContributionCopyWithImpl<FamilyContribution>(this as FamilyContribution, _$identity);

  /// Serializes this FamilyContribution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyContribution;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyContribution&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.points, _this.points) || other.points == _this.points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyContribution;
  return Object.hash(runtimeType,_this.rank,_this.user,_this.role,_this.points);
}

@override
String toString() {
  final _this = this as FamilyContribution;
  return 'FamilyContribution(rank: ${_this.rank}, user: ${_this.user}, role: ${_this.role}, points: ${_this.points})';
}


}

/// @nodoc
abstract mixin class $FamilyContributionCopyWith<$Res>  {
  factory $FamilyContributionCopyWith(FamilyContribution value, $Res Function(FamilyContribution) _then) = _$FamilyContributionCopyWithImpl;
@useResult
$Res call({
 int rank, UserSummary user, FamilyRole role, int points
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$FamilyContributionCopyWithImpl<$Res>
    implements $FamilyContributionCopyWith<$Res> {
  _$FamilyContributionCopyWithImpl(this._self, this._then);

  final FamilyContribution _self;
  final $Res Function(FamilyContribution) _then;

/// Create a copy of FamilyContribution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rank = null,Object? user = null,Object? role = null,Object? points = null,}) {
  return _then(FamilyContribution(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of FamilyContribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyContribution].
extension FamilyContributionPatterns on FamilyContribution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyContribution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyContribution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyContribution value)  $default,){
final _that = this;
switch (_that) {
case _FamilyContribution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyContribution value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyContribution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int rank,  UserSummary user,  FamilyRole role,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyContribution() when $default != null:
return $default(_that.rank,_that.user,_that.role,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int rank,  UserSummary user,  FamilyRole role,  int points)  $default,) {final _that = this;
switch (_that) {
case _FamilyContribution():
return $default(_that.rank,_that.user,_that.role,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int rank,  UserSummary user,  FamilyRole role,  int points)?  $default,) {final _that = this;
switch (_that) {
case _FamilyContribution() when $default != null:
return $default(_that.rank,_that.user,_that.role,_that.points);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyContribution implements FamilyContribution {
  const _FamilyContribution({required this.rank, required this.user, required this.role, required this.points});
  factory _FamilyContribution.fromJson(Map<String, dynamic> json) => _$FamilyContributionFromJson(json);

@override final  int rank;
@override final  UserSummary user;
@override final  FamilyRole role;
@override final  int points;

/// Create a copy of FamilyContribution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyContributionCopyWith<_FamilyContribution> get copyWith => __$FamilyContributionCopyWithImpl<_FamilyContribution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyContributionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyContribution&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.user, user) || other.user == user)&&(identical(other.role, role) || other.role == role)&&(identical(other.points, points) || other.points == points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,rank,user,role,points);
}

@override
String toString() {
    return 'FamilyContribution(rank: $rank, user: $user, role: $role, points: $points)';
}


}

/// @nodoc
abstract mixin class _$FamilyContributionCopyWith<$Res> implements $FamilyContributionCopyWith<$Res> {
  factory _$FamilyContributionCopyWith(_FamilyContribution value, $Res Function(_FamilyContribution) _then) = __$FamilyContributionCopyWithImpl;
@override @useResult
$Res call({
 int rank, UserSummary user, FamilyRole role, int points
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$FamilyContributionCopyWithImpl<$Res>
    implements _$FamilyContributionCopyWith<$Res> {
  __$FamilyContributionCopyWithImpl(this._self, this._then);

  final _FamilyContribution _self;
  final $Res Function(_FamilyContribution) _then;

/// Create a copy of FamilyContribution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rank = null,Object? user = null,Object? role = null,Object? points = null,}) {
  return _then(_FamilyContribution(
rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as FamilyRole,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of FamilyContribution
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
mixin _$FamilyContributions {

 DateTime get startsAt; DateTime get endsAt; List<FamilyContribution> get data; PageInfo get page;
/// Create a copy of FamilyContributions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyContributionsCopyWith<FamilyContributions> get copyWith => _$FamilyContributionsCopyWithImpl<FamilyContributions>(this as FamilyContributions, _$identity);

  /// Serializes this FamilyContributions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyContributions;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyContributions&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt)&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyContributions;
  return Object.hash(runtimeType,_this.startsAt,_this.endsAt,const DeepCollectionEquality().hash(_this.data),_this.page);
}

@override
String toString() {
  final _this = this as FamilyContributions;
  return 'FamilyContributions(startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt}, data: ${_this.data}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $FamilyContributionsCopyWith<$Res>  {
  factory $FamilyContributionsCopyWith(FamilyContributions value, $Res Function(FamilyContributions) _then) = _$FamilyContributionsCopyWithImpl;
@useResult
$Res call({
 DateTime startsAt, DateTime endsAt, List<FamilyContribution> data, PageInfo page
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$FamilyContributionsCopyWithImpl<$Res>
    implements $FamilyContributionsCopyWith<$Res> {
  _$FamilyContributionsCopyWithImpl(this._self, this._then);

  final FamilyContributions _self;
  final $Res Function(FamilyContributions) _then;

/// Create a copy of FamilyContributions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startsAt = null,Object? endsAt = null,Object? data = null,Object? page = null,}) {
  return _then(FamilyContributions(
startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyContribution>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}
/// Create a copy of FamilyContributions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyContributions].
extension FamilyContributionsPatterns on FamilyContributions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyContributions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyContributions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyContributions value)  $default,){
final _that = this;
switch (_that) {
case _FamilyContributions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyContributions value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyContributions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime startsAt,  DateTime endsAt,  List<FamilyContribution> data,  PageInfo page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyContributions() when $default != null:
return $default(_that.startsAt,_that.endsAt,_that.data,_that.page);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime startsAt,  DateTime endsAt,  List<FamilyContribution> data,  PageInfo page)  $default,) {final _that = this;
switch (_that) {
case _FamilyContributions():
return $default(_that.startsAt,_that.endsAt,_that.data,_that.page);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime startsAt,  DateTime endsAt,  List<FamilyContribution> data,  PageInfo page)?  $default,) {final _that = this;
switch (_that) {
case _FamilyContributions() when $default != null:
return $default(_that.startsAt,_that.endsAt,_that.data,_that.page);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyContributions implements FamilyContributions {
  const _FamilyContributions({required this.startsAt, required this.endsAt, required  List<FamilyContribution> data, required this.page}): _data = data;
  factory _FamilyContributions.fromJson(Map<String, dynamic> json) => _$FamilyContributionsFromJson(json);

@override final  DateTime startsAt;
@override final  DateTime endsAt;
 final  List<FamilyContribution> _data;
@override List<FamilyContribution> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;

/// Create a copy of FamilyContributions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyContributionsCopyWith<_FamilyContributions> get copyWith => __$FamilyContributionsCopyWithImpl<_FamilyContributions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyContributionsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyContributions&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,startsAt,endsAt,const DeepCollectionEquality().hash(_data),page);
}

@override
String toString() {
    return 'FamilyContributions(startsAt: $startsAt, endsAt: $endsAt, data: $data, page: $page)';
}


}

/// @nodoc
abstract mixin class _$FamilyContributionsCopyWith<$Res> implements $FamilyContributionsCopyWith<$Res> {
  factory _$FamilyContributionsCopyWith(_FamilyContributions value, $Res Function(_FamilyContributions) _then) = __$FamilyContributionsCopyWithImpl;
@override @useResult
$Res call({
 DateTime startsAt, DateTime endsAt, List<FamilyContribution> data, PageInfo page
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$FamilyContributionsCopyWithImpl<$Res>
    implements _$FamilyContributionsCopyWith<$Res> {
  __$FamilyContributionsCopyWithImpl(this._self, this._then);

  final _FamilyContributions _self;
  final $Res Function(_FamilyContributions) _then;

/// Create a copy of FamilyContributions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startsAt = null,Object? endsAt = null,Object? data = null,Object? page = null,}) {
  return _then(_FamilyContributions(
startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyContribution>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}

/// Create a copy of FamilyContributions
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
mixin _$FamilyChatMessage {

 String get id; String get familyId; UserSummary get author; FamilyRole? get authorRole; String get text; DateTime get createdAt;
/// Create a copy of FamilyChatMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyChatMessageCopyWith<FamilyChatMessage> get copyWith => _$FamilyChatMessageCopyWithImpl<FamilyChatMessage>(this as FamilyChatMessage, _$identity);

  /// Serializes this FamilyChatMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyChatMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyChatMessage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.familyId, _this.familyId) || other.familyId == _this.familyId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.authorRole, _this.authorRole) || other.authorRole == _this.authorRole)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyChatMessage;
  return Object.hash(runtimeType,_this.id,_this.familyId,_this.author,_this.authorRole,_this.text,_this.createdAt);
}

@override
String toString() {
  final _this = this as FamilyChatMessage;
  return 'FamilyChatMessage(id: ${_this.id}, familyId: ${_this.familyId}, author: ${_this.author}, authorRole: ${_this.authorRole}, text: ${_this.text}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $FamilyChatMessageCopyWith<$Res>  {
  factory $FamilyChatMessageCopyWith(FamilyChatMessage value, $Res Function(FamilyChatMessage) _then) = _$FamilyChatMessageCopyWithImpl;
@useResult
$Res call({
 String id, String familyId, UserSummary author, FamilyRole? authorRole, String text, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get author;

}
/// @nodoc
class _$FamilyChatMessageCopyWithImpl<$Res>
    implements $FamilyChatMessageCopyWith<$Res> {
  _$FamilyChatMessageCopyWithImpl(this._self, this._then);

  final FamilyChatMessage _self;
  final $Res Function(FamilyChatMessage) _then;

/// Create a copy of FamilyChatMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? familyId = null,Object? author = null,Object? authorRole = freezed,Object? text = null,Object? createdAt = null,}) {
  return _then(FamilyChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,familyId: null == familyId ? _self.familyId : familyId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,authorRole: freezed == authorRole ? _self.authorRole : authorRole // ignore: cast_nullable_to_non_nullable
as FamilyRole?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of FamilyChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get author {
  
  return $UserSummaryCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyChatMessage].
extension FamilyChatMessagePatterns on FamilyChatMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyChatMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyChatMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyChatMessage value)  $default,){
final _that = this;
switch (_that) {
case _FamilyChatMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyChatMessage value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyChatMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String familyId,  UserSummary author,  FamilyRole? authorRole,  String text,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyChatMessage() when $default != null:
return $default(_that.id,_that.familyId,_that.author,_that.authorRole,_that.text,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String familyId,  UserSummary author,  FamilyRole? authorRole,  String text,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FamilyChatMessage():
return $default(_that.id,_that.familyId,_that.author,_that.authorRole,_that.text,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String familyId,  UserSummary author,  FamilyRole? authorRole,  String text,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FamilyChatMessage() when $default != null:
return $default(_that.id,_that.familyId,_that.author,_that.authorRole,_that.text,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyChatMessage implements FamilyChatMessage {
  const _FamilyChatMessage({required this.id, required this.familyId, required this.author, required this.authorRole, required this.text, required this.createdAt});
  factory _FamilyChatMessage.fromJson(Map<String, dynamic> json) => _$FamilyChatMessageFromJson(json);

@override final  String id;
@override final  String familyId;
@override final  UserSummary author;
@override final  FamilyRole? authorRole;
@override final  String text;
@override final  DateTime createdAt;

/// Create a copy of FamilyChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyChatMessageCopyWith<_FamilyChatMessage> get copyWith => __$FamilyChatMessageCopyWithImpl<_FamilyChatMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyChatMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyChatMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.familyId, familyId) || other.familyId == familyId)&&(identical(other.author, author) || other.author == author)&&(identical(other.authorRole, authorRole) || other.authorRole == authorRole)&&(identical(other.text, text) || other.text == text)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,familyId,author,authorRole,text,createdAt);
}

@override
String toString() {
    return 'FamilyChatMessage(id: $id, familyId: $familyId, author: $author, authorRole: $authorRole, text: $text, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FamilyChatMessageCopyWith<$Res> implements $FamilyChatMessageCopyWith<$Res> {
  factory _$FamilyChatMessageCopyWith(_FamilyChatMessage value, $Res Function(_FamilyChatMessage) _then) = __$FamilyChatMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String familyId, UserSummary author, FamilyRole? authorRole, String text, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get author;

}
/// @nodoc
class __$FamilyChatMessageCopyWithImpl<$Res>
    implements _$FamilyChatMessageCopyWith<$Res> {
  __$FamilyChatMessageCopyWithImpl(this._self, this._then);

  final _FamilyChatMessage _self;
  final $Res Function(_FamilyChatMessage) _then;

/// Create a copy of FamilyChatMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? familyId = null,Object? author = null,Object? authorRole = freezed,Object? text = null,Object? createdAt = null,}) {
  return _then(_FamilyChatMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,familyId: null == familyId ? _self.familyId : familyId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,authorRole: freezed == authorRole ? _self.authorRole : authorRole // ignore: cast_nullable_to_non_nullable
as FamilyRole?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of FamilyChatMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get author {
  
  return $UserSummaryCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// @nodoc
mixin _$FamilyChatPage {

 List<FamilyChatMessage> get data; PageInfo get page; bool get muted; bool get canModerate;
/// Create a copy of FamilyChatPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FamilyChatPageCopyWith<FamilyChatPage> get copyWith => _$FamilyChatPageCopyWithImpl<FamilyChatPage>(this as FamilyChatPage, _$identity);

  /// Serializes this FamilyChatPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FamilyChatPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FamilyChatPage&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.muted, _this.muted) || other.muted == _this.muted)&&(identical(other.canModerate, _this.canModerate) || other.canModerate == _this.canModerate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FamilyChatPage;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.page,_this.muted,_this.canModerate);
}

@override
String toString() {
  final _this = this as FamilyChatPage;
  return 'FamilyChatPage(data: ${_this.data}, page: ${_this.page}, muted: ${_this.muted}, canModerate: ${_this.canModerate})';
}


}

/// @nodoc
abstract mixin class $FamilyChatPageCopyWith<$Res>  {
  factory $FamilyChatPageCopyWith(FamilyChatPage value, $Res Function(FamilyChatPage) _then) = _$FamilyChatPageCopyWithImpl;
@useResult
$Res call({
 List<FamilyChatMessage> data, PageInfo page, bool muted, bool canModerate
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$FamilyChatPageCopyWithImpl<$Res>
    implements $FamilyChatPageCopyWith<$Res> {
  _$FamilyChatPageCopyWithImpl(this._self, this._then);

  final FamilyChatPage _self;
  final $Res Function(FamilyChatPage) _then;

/// Create a copy of FamilyChatPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,Object? muted = null,Object? canModerate = null,}) {
  return _then(FamilyChatPage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyChatMessage>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,canModerate: null == canModerate ? _self.canModerate : canModerate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of FamilyChatPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [FamilyChatPage].
extension FamilyChatPagePatterns on FamilyChatPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FamilyChatPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FamilyChatPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FamilyChatPage value)  $default,){
final _that = this;
switch (_that) {
case _FamilyChatPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FamilyChatPage value)?  $default,){
final _that = this;
switch (_that) {
case _FamilyChatPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FamilyChatMessage> data,  PageInfo page,  bool muted,  bool canModerate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FamilyChatPage() when $default != null:
return $default(_that.data,_that.page,_that.muted,_that.canModerate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FamilyChatMessage> data,  PageInfo page,  bool muted,  bool canModerate)  $default,) {final _that = this;
switch (_that) {
case _FamilyChatPage():
return $default(_that.data,_that.page,_that.muted,_that.canModerate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FamilyChatMessage> data,  PageInfo page,  bool muted,  bool canModerate)?  $default,) {final _that = this;
switch (_that) {
case _FamilyChatPage() when $default != null:
return $default(_that.data,_that.page,_that.muted,_that.canModerate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FamilyChatPage implements FamilyChatPage {
  const _FamilyChatPage({required  List<FamilyChatMessage> data, required this.page, required this.muted, required this.canModerate}): _data = data;
  factory _FamilyChatPage.fromJson(Map<String, dynamic> json) => _$FamilyChatPageFromJson(json);

 final  List<FamilyChatMessage> _data;
@override List<FamilyChatMessage> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;
@override final  bool muted;
@override final  bool canModerate;

/// Create a copy of FamilyChatPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FamilyChatPageCopyWith<_FamilyChatPage> get copyWith => __$FamilyChatPageCopyWithImpl<_FamilyChatPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FamilyChatPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FamilyChatPage&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.canModerate, canModerate) || other.canModerate == canModerate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page,muted,canModerate);
}

@override
String toString() {
    return 'FamilyChatPage(data: $data, page: $page, muted: $muted, canModerate: $canModerate)';
}


}

/// @nodoc
abstract mixin class _$FamilyChatPageCopyWith<$Res> implements $FamilyChatPageCopyWith<$Res> {
  factory _$FamilyChatPageCopyWith(_FamilyChatPage value, $Res Function(_FamilyChatPage) _then) = __$FamilyChatPageCopyWithImpl;
@override @useResult
$Res call({
 List<FamilyChatMessage> data, PageInfo page, bool muted, bool canModerate
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$FamilyChatPageCopyWithImpl<$Res>
    implements _$FamilyChatPageCopyWith<$Res> {
  __$FamilyChatPageCopyWithImpl(this._self, this._then);

  final _FamilyChatPage _self;
  final $Res Function(_FamilyChatPage) _then;

/// Create a copy of FamilyChatPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,Object? muted = null,Object? canModerate = null,}) {
  return _then(_FamilyChatPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FamilyChatMessage>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,canModerate: null == canModerate ? _self.canModerate : canModerate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of FamilyChatPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}

// dart format on
