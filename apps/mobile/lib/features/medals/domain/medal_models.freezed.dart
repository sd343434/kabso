// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medal_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MedalLevelRequirement {

 String get metric; int get threshold;
/// Create a copy of MedalLevelRequirement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalLevelRequirementCopyWith<MedalLevelRequirement> get copyWith => _$MedalLevelRequirementCopyWithImpl<MedalLevelRequirement>(this as MedalLevelRequirement, _$identity);

  /// Serializes this MedalLevelRequirement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MedalLevelRequirement;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedalLevelRequirement&&(identical(other.metric, _this.metric) || other.metric == _this.metric)&&(identical(other.threshold, _this.threshold) || other.threshold == _this.threshold));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MedalLevelRequirement;
  return Object.hash(runtimeType,_this.metric,_this.threshold);
}

@override
String toString() {
  final _this = this as MedalLevelRequirement;
  return 'MedalLevelRequirement(metric: ${_this.metric}, threshold: ${_this.threshold})';
}


}

/// @nodoc
abstract mixin class $MedalLevelRequirementCopyWith<$Res>  {
  factory $MedalLevelRequirementCopyWith(MedalLevelRequirement value, $Res Function(MedalLevelRequirement) _then) = _$MedalLevelRequirementCopyWithImpl;
@useResult
$Res call({
 String metric, int threshold
});




}
/// @nodoc
class _$MedalLevelRequirementCopyWithImpl<$Res>
    implements $MedalLevelRequirementCopyWith<$Res> {
  _$MedalLevelRequirementCopyWithImpl(this._self, this._then);

  final MedalLevelRequirement _self;
  final $Res Function(MedalLevelRequirement) _then;

/// Create a copy of MedalLevelRequirement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metric = null,Object? threshold = null,}) {
  return _then(MedalLevelRequirement(
metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as String,threshold: null == threshold ? _self.threshold : threshold // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MedalLevelRequirement].
extension MedalLevelRequirementPatterns on MedalLevelRequirement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedalLevelRequirement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedalLevelRequirement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedalLevelRequirement value)  $default,){
final _that = this;
switch (_that) {
case _MedalLevelRequirement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedalLevelRequirement value)?  $default,){
final _that = this;
switch (_that) {
case _MedalLevelRequirement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String metric,  int threshold)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedalLevelRequirement() when $default != null:
return $default(_that.metric,_that.threshold);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String metric,  int threshold)  $default,) {final _that = this;
switch (_that) {
case _MedalLevelRequirement():
return $default(_that.metric,_that.threshold);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String metric,  int threshold)?  $default,) {final _that = this;
switch (_that) {
case _MedalLevelRequirement() when $default != null:
return $default(_that.metric,_that.threshold);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedalLevelRequirement implements MedalLevelRequirement {
  const _MedalLevelRequirement({required this.metric, required this.threshold});
  factory _MedalLevelRequirement.fromJson(Map<String, dynamic> json) => _$MedalLevelRequirementFromJson(json);

@override final  String metric;
@override final  int threshold;

/// Create a copy of MedalLevelRequirement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalLevelRequirementCopyWith<_MedalLevelRequirement> get copyWith => __$MedalLevelRequirementCopyWithImpl<_MedalLevelRequirement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalLevelRequirementToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedalLevelRequirement&&(identical(other.metric, metric) || other.metric == metric)&&(identical(other.threshold, threshold) || other.threshold == threshold));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,metric,threshold);
}

@override
String toString() {
    return 'MedalLevelRequirement(metric: $metric, threshold: $threshold)';
}


}

/// @nodoc
abstract mixin class _$MedalLevelRequirementCopyWith<$Res> implements $MedalLevelRequirementCopyWith<$Res> {
  factory _$MedalLevelRequirementCopyWith(_MedalLevelRequirement value, $Res Function(_MedalLevelRequirement) _then) = __$MedalLevelRequirementCopyWithImpl;
@override @useResult
$Res call({
 String metric, int threshold
});




}
/// @nodoc
class __$MedalLevelRequirementCopyWithImpl<$Res>
    implements _$MedalLevelRequirementCopyWith<$Res> {
  __$MedalLevelRequirementCopyWithImpl(this._self, this._then);

  final _MedalLevelRequirement _self;
  final $Res Function(_MedalLevelRequirement) _then;

/// Create a copy of MedalLevelRequirement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metric = null,Object? threshold = null,}) {
  return _then(_MedalLevelRequirement(
metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as String,threshold: null == threshold ? _self.threshold : threshold // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$MedalRequirementProgress {

 String get metric; int get value; int? get next;
/// Create a copy of MedalRequirementProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalRequirementProgressCopyWith<MedalRequirementProgress> get copyWith => _$MedalRequirementProgressCopyWithImpl<MedalRequirementProgress>(this as MedalRequirementProgress, _$identity);

  /// Serializes this MedalRequirementProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MedalRequirementProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedalRequirementProgress&&(identical(other.metric, _this.metric) || other.metric == _this.metric)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.next, _this.next) || other.next == _this.next));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MedalRequirementProgress;
  return Object.hash(runtimeType,_this.metric,_this.value,_this.next);
}

@override
String toString() {
  final _this = this as MedalRequirementProgress;
  return 'MedalRequirementProgress(metric: ${_this.metric}, value: ${_this.value}, next: ${_this.next})';
}


}

/// @nodoc
abstract mixin class $MedalRequirementProgressCopyWith<$Res>  {
  factory $MedalRequirementProgressCopyWith(MedalRequirementProgress value, $Res Function(MedalRequirementProgress) _then) = _$MedalRequirementProgressCopyWithImpl;
@useResult
$Res call({
 String metric, int value, int? next
});




}
/// @nodoc
class _$MedalRequirementProgressCopyWithImpl<$Res>
    implements $MedalRequirementProgressCopyWith<$Res> {
  _$MedalRequirementProgressCopyWithImpl(this._self, this._then);

  final MedalRequirementProgress _self;
  final $Res Function(MedalRequirementProgress) _then;

/// Create a copy of MedalRequirementProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? metric = null,Object? value = null,Object? next = freezed,}) {
  return _then(MedalRequirementProgress(
metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,next: freezed == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MedalRequirementProgress].
extension MedalRequirementProgressPatterns on MedalRequirementProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedalRequirementProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedalRequirementProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedalRequirementProgress value)  $default,){
final _that = this;
switch (_that) {
case _MedalRequirementProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedalRequirementProgress value)?  $default,){
final _that = this;
switch (_that) {
case _MedalRequirementProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String metric,  int value,  int? next)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedalRequirementProgress() when $default != null:
return $default(_that.metric,_that.value,_that.next);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String metric,  int value,  int? next)  $default,) {final _that = this;
switch (_that) {
case _MedalRequirementProgress():
return $default(_that.metric,_that.value,_that.next);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String metric,  int value,  int? next)?  $default,) {final _that = this;
switch (_that) {
case _MedalRequirementProgress() when $default != null:
return $default(_that.metric,_that.value,_that.next);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedalRequirementProgress implements MedalRequirementProgress {
  const _MedalRequirementProgress({required this.metric, this.value = 0, this.next});
  factory _MedalRequirementProgress.fromJson(Map<String, dynamic> json) => _$MedalRequirementProgressFromJson(json);

@override final  String metric;
@override@JsonKey() final  int value;
@override final  int? next;

/// Create a copy of MedalRequirementProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalRequirementProgressCopyWith<_MedalRequirementProgress> get copyWith => __$MedalRequirementProgressCopyWithImpl<_MedalRequirementProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalRequirementProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedalRequirementProgress&&(identical(other.metric, metric) || other.metric == metric)&&(identical(other.value, value) || other.value == value)&&(identical(other.next, next) || other.next == next));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,metric,value,next);
}

@override
String toString() {
    return 'MedalRequirementProgress(metric: $metric, value: $value, next: $next)';
}


}

/// @nodoc
abstract mixin class _$MedalRequirementProgressCopyWith<$Res> implements $MedalRequirementProgressCopyWith<$Res> {
  factory _$MedalRequirementProgressCopyWith(_MedalRequirementProgress value, $Res Function(_MedalRequirementProgress) _then) = __$MedalRequirementProgressCopyWithImpl;
@override @useResult
$Res call({
 String metric, int value, int? next
});




}
/// @nodoc
class __$MedalRequirementProgressCopyWithImpl<$Res>
    implements _$MedalRequirementProgressCopyWith<$Res> {
  __$MedalRequirementProgressCopyWithImpl(this._self, this._then);

  final _MedalRequirementProgress _self;
  final $Res Function(_MedalRequirementProgress) _then;

/// Create a copy of MedalRequirementProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? metric = null,Object? value = null,Object? next = freezed,}) {
  return _then(_MedalRequirementProgress(
metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,next: freezed == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$MedalLevel {

 int get level; int get threshold; String? get name; String? get iconUrl;/// D291: this level's art bundled in the app (e.g. `medal_wealth_l1`).
 String? get iconAsset;/// D300: a multi-requirement level's thresholds (empty otherwise).
 List<MedalLevelRequirement> get requirements;
/// Create a copy of MedalLevel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalLevelCopyWith<MedalLevel> get copyWith => _$MedalLevelCopyWithImpl<MedalLevel>(this as MedalLevel, _$identity);

  /// Serializes this MedalLevel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MedalLevel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedalLevel&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.threshold, _this.threshold) || other.threshold == _this.threshold)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.iconAsset, _this.iconAsset) || other.iconAsset == _this.iconAsset)&&const DeepCollectionEquality().equals(other.requirements, _this.requirements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MedalLevel;
  return Object.hash(runtimeType,_this.level,_this.threshold,_this.name,_this.iconUrl,_this.iconAsset,const DeepCollectionEquality().hash(_this.requirements));
}

@override
String toString() {
  final _this = this as MedalLevel;
  return 'MedalLevel(level: ${_this.level}, threshold: ${_this.threshold}, name: ${_this.name}, iconUrl: ${_this.iconUrl}, iconAsset: ${_this.iconAsset}, requirements: ${_this.requirements})';
}


}

/// @nodoc
abstract mixin class $MedalLevelCopyWith<$Res>  {
  factory $MedalLevelCopyWith(MedalLevel value, $Res Function(MedalLevel) _then) = _$MedalLevelCopyWithImpl;
@useResult
$Res call({
 int level, int threshold, String? name, String? iconUrl, String? iconAsset, List<MedalLevelRequirement> requirements
});




}
/// @nodoc
class _$MedalLevelCopyWithImpl<$Res>
    implements $MedalLevelCopyWith<$Res> {
  _$MedalLevelCopyWithImpl(this._self, this._then);

  final MedalLevel _self;
  final $Res Function(MedalLevel) _then;

/// Create a copy of MedalLevel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? threshold = null,Object? name = freezed,Object? iconUrl = freezed,Object? iconAsset = freezed,Object? requirements = null,}) {
  return _then(MedalLevel(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,threshold: null == threshold ? _self.threshold : threshold // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,requirements: null == requirements ? _self.requirements : requirements // ignore: cast_nullable_to_non_nullable
as List<MedalLevelRequirement>,
  ));
}

}


/// Adds pattern-matching-related methods to [MedalLevel].
extension MedalLevelPatterns on MedalLevel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedalLevel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedalLevel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedalLevel value)  $default,){
final _that = this;
switch (_that) {
case _MedalLevel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedalLevel value)?  $default,){
final _that = this;
switch (_that) {
case _MedalLevel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int level,  int threshold,  String? name,  String? iconUrl,  String? iconAsset,  List<MedalLevelRequirement> requirements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedalLevel() when $default != null:
return $default(_that.level,_that.threshold,_that.name,_that.iconUrl,_that.iconAsset,_that.requirements);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int level,  int threshold,  String? name,  String? iconUrl,  String? iconAsset,  List<MedalLevelRequirement> requirements)  $default,) {final _that = this;
switch (_that) {
case _MedalLevel():
return $default(_that.level,_that.threshold,_that.name,_that.iconUrl,_that.iconAsset,_that.requirements);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int level,  int threshold,  String? name,  String? iconUrl,  String? iconAsset,  List<MedalLevelRequirement> requirements)?  $default,) {final _that = this;
switch (_that) {
case _MedalLevel() when $default != null:
return $default(_that.level,_that.threshold,_that.name,_that.iconUrl,_that.iconAsset,_that.requirements);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedalLevel implements MedalLevel {
  const _MedalLevel({required this.level, required this.threshold, this.name, this.iconUrl, this.iconAsset,  List<MedalLevelRequirement> requirements = const <MedalLevelRequirement>[]}): _requirements = requirements;
  factory _MedalLevel.fromJson(Map<String, dynamic> json) => _$MedalLevelFromJson(json);

@override final  int level;
@override final  int threshold;
@override final  String? name;
@override final  String? iconUrl;
/// D291: this level's art bundled in the app (e.g. `medal_wealth_l1`).
@override final  String? iconAsset;
/// D300: a multi-requirement level's thresholds (empty otherwise).
 final  List<MedalLevelRequirement> _requirements;
/// D300: a multi-requirement level's thresholds (empty otherwise).
@override@JsonKey() List<MedalLevelRequirement> get requirements {
  if (_requirements is EqualUnmodifiableListView) return _requirements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requirements);
}


/// Create a copy of MedalLevel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalLevelCopyWith<_MedalLevel> get copyWith => __$MedalLevelCopyWithImpl<_MedalLevel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalLevelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedalLevel&&(identical(other.level, level) || other.level == level)&&(identical(other.threshold, threshold) || other.threshold == threshold)&&(identical(other.name, name) || other.name == name)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.iconAsset, iconAsset) || other.iconAsset == iconAsset)&&const DeepCollectionEquality().equals(other.requirements, _requirements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,level,threshold,name,iconUrl,iconAsset,const DeepCollectionEquality().hash(_requirements));
}

@override
String toString() {
    return 'MedalLevel(level: $level, threshold: $threshold, name: $name, iconUrl: $iconUrl, iconAsset: $iconAsset, requirements: $requirements)';
}


}

/// @nodoc
abstract mixin class _$MedalLevelCopyWith<$Res> implements $MedalLevelCopyWith<$Res> {
  factory _$MedalLevelCopyWith(_MedalLevel value, $Res Function(_MedalLevel) _then) = __$MedalLevelCopyWithImpl;
@override @useResult
$Res call({
 int level, int threshold, String? name, String? iconUrl, String? iconAsset, List<MedalLevelRequirement> requirements
});




}
/// @nodoc
class __$MedalLevelCopyWithImpl<$Res>
    implements _$MedalLevelCopyWith<$Res> {
  __$MedalLevelCopyWithImpl(this._self, this._then);

  final _MedalLevel _self;
  final $Res Function(_MedalLevel) _then;

/// Create a copy of MedalLevel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? threshold = null,Object? name = freezed,Object? iconUrl = freezed,Object? iconAsset = freezed,Object? requirements = null,}) {
  return _then(_MedalLevel(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,threshold: null == threshold ? _self.threshold : threshold // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,requirements: null == requirements ? _self._requirements : requirements // ignore: cast_nullable_to_non_nullable
as List<MedalLevelRequirement>,
  ));
}


}


/// @nodoc
mixin _$MedalProgress {

 int get value; int? get next;/// D300: each requirement now against the next level's target (empty
/// for a single-metric medal).
 List<MedalRequirementProgress> get requirements;
/// Create a copy of MedalProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalProgressCopyWith<MedalProgress> get copyWith => _$MedalProgressCopyWithImpl<MedalProgress>(this as MedalProgress, _$identity);

  /// Serializes this MedalProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MedalProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedalProgress&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.next, _this.next) || other.next == _this.next)&&const DeepCollectionEquality().equals(other.requirements, _this.requirements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MedalProgress;
  return Object.hash(runtimeType,_this.value,_this.next,const DeepCollectionEquality().hash(_this.requirements));
}

@override
String toString() {
  final _this = this as MedalProgress;
  return 'MedalProgress(value: ${_this.value}, next: ${_this.next}, requirements: ${_this.requirements})';
}


}

/// @nodoc
abstract mixin class $MedalProgressCopyWith<$Res>  {
  factory $MedalProgressCopyWith(MedalProgress value, $Res Function(MedalProgress) _then) = _$MedalProgressCopyWithImpl;
@useResult
$Res call({
 int value, int? next, List<MedalRequirementProgress> requirements
});




}
/// @nodoc
class _$MedalProgressCopyWithImpl<$Res>
    implements $MedalProgressCopyWith<$Res> {
  _$MedalProgressCopyWithImpl(this._self, this._then);

  final MedalProgress _self;
  final $Res Function(MedalProgress) _then;

/// Create a copy of MedalProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? next = freezed,Object? requirements = null,}) {
  return _then(MedalProgress(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,next: freezed == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as int?,requirements: null == requirements ? _self.requirements : requirements // ignore: cast_nullable_to_non_nullable
as List<MedalRequirementProgress>,
  ));
}

}


/// Adds pattern-matching-related methods to [MedalProgress].
extension MedalProgressPatterns on MedalProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedalProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedalProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedalProgress value)  $default,){
final _that = this;
switch (_that) {
case _MedalProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedalProgress value)?  $default,){
final _that = this;
switch (_that) {
case _MedalProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int value,  int? next,  List<MedalRequirementProgress> requirements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedalProgress() when $default != null:
return $default(_that.value,_that.next,_that.requirements);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int value,  int? next,  List<MedalRequirementProgress> requirements)  $default,) {final _that = this;
switch (_that) {
case _MedalProgress():
return $default(_that.value,_that.next,_that.requirements);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int value,  int? next,  List<MedalRequirementProgress> requirements)?  $default,) {final _that = this;
switch (_that) {
case _MedalProgress() when $default != null:
return $default(_that.value,_that.next,_that.requirements);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedalProgress implements MedalProgress {
  const _MedalProgress({this.value = 0, this.next,  List<MedalRequirementProgress> requirements = const <MedalRequirementProgress>[]}): _requirements = requirements;
  factory _MedalProgress.fromJson(Map<String, dynamic> json) => _$MedalProgressFromJson(json);

@override@JsonKey() final  int value;
@override final  int? next;
/// D300: each requirement now against the next level's target (empty
/// for a single-metric medal).
 final  List<MedalRequirementProgress> _requirements;
/// D300: each requirement now against the next level's target (empty
/// for a single-metric medal).
@override@JsonKey() List<MedalRequirementProgress> get requirements {
  if (_requirements is EqualUnmodifiableListView) return _requirements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requirements);
}


/// Create a copy of MedalProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalProgressCopyWith<_MedalProgress> get copyWith => __$MedalProgressCopyWithImpl<_MedalProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedalProgress&&(identical(other.value, value) || other.value == value)&&(identical(other.next, next) || other.next == next)&&const DeepCollectionEquality().equals(other.requirements, _requirements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,value,next,const DeepCollectionEquality().hash(_requirements));
}

@override
String toString() {
    return 'MedalProgress(value: $value, next: $next, requirements: $requirements)';
}


}

/// @nodoc
abstract mixin class _$MedalProgressCopyWith<$Res> implements $MedalProgressCopyWith<$Res> {
  factory _$MedalProgressCopyWith(_MedalProgress value, $Res Function(_MedalProgress) _then) = __$MedalProgressCopyWithImpl;
@override @useResult
$Res call({
 int value, int? next, List<MedalRequirementProgress> requirements
});




}
/// @nodoc
class __$MedalProgressCopyWithImpl<$Res>
    implements _$MedalProgressCopyWith<$Res> {
  __$MedalProgressCopyWithImpl(this._self, this._then);

  final _MedalProgress _self;
  final $Res Function(_MedalProgress) _then;

/// Create a copy of MedalProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? next = freezed,Object? requirements = null,}) {
  return _then(_MedalProgress(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,next: freezed == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as int?,requirements: null == requirements ? _self._requirements : requirements // ignore: cast_nullable_to_non_nullable
as List<MedalRequirementProgress>,
  ));
}


}


/// @nodoc
mixin _$Medal {

 String get code; String get name; String get description; String get iconKey; int get sortOrder; DateTime? get awardedAt;@JsonKey(unknownEnumValue: MedalCategory.achievement) MedalCategory get category;/// What the levels count (`MedalMetric`: LIVES_HOSTED, LIVE_HOURS,
/// CHARM_LEVEL, FAMILY_JOINED, CP_FORMED, BULLETS_SENT); null = none or
/// unknown — the thresholds are then shown as bare numbers.
 String? get metric; int? get level; int get maxLevel; List<MedalLevel> get levels; MedalProgress get progress; String? get iconUrl;/// D291: the bundled art key of the level shown, or null.
 String? get iconAsset; int? get showcasePosition;/// D300: false when the medal is for content creators and the caller is
/// not one now (no progress; a level reached is kept). Older servers:
/// true.
 bool get eligible;
/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalCopyWith<Medal> get copyWith => _$MedalCopyWithImpl<Medal>(this as Medal, _$identity);

  /// Serializes this Medal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Medal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Medal&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.iconKey, _this.iconKey) || other.iconKey == _this.iconKey)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.awardedAt, _this.awardedAt) || other.awardedAt == _this.awardedAt)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.metric, _this.metric) || other.metric == _this.metric)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.maxLevel, _this.maxLevel) || other.maxLevel == _this.maxLevel)&&const DeepCollectionEquality().equals(other.levels, _this.levels)&&(identical(other.progress, _this.progress) || other.progress == _this.progress)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.iconAsset, _this.iconAsset) || other.iconAsset == _this.iconAsset)&&(identical(other.showcasePosition, _this.showcasePosition) || other.showcasePosition == _this.showcasePosition)&&(identical(other.eligible, _this.eligible) || other.eligible == _this.eligible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Medal;
  return Object.hash(runtimeType,_this.code,_this.name,_this.description,_this.iconKey,_this.sortOrder,_this.awardedAt,_this.category,_this.metric,_this.level,_this.maxLevel,const DeepCollectionEquality().hash(_this.levels),_this.progress,_this.iconUrl,_this.iconAsset,_this.showcasePosition,_this.eligible);
}

@override
String toString() {
  final _this = this as Medal;
  return 'Medal(code: ${_this.code}, name: ${_this.name}, description: ${_this.description}, iconKey: ${_this.iconKey}, sortOrder: ${_this.sortOrder}, awardedAt: ${_this.awardedAt}, category: ${_this.category}, metric: ${_this.metric}, level: ${_this.level}, maxLevel: ${_this.maxLevel}, levels: ${_this.levels}, progress: ${_this.progress}, iconUrl: ${_this.iconUrl}, iconAsset: ${_this.iconAsset}, showcasePosition: ${_this.showcasePosition}, eligible: ${_this.eligible})';
}


}

/// @nodoc
abstract mixin class $MedalCopyWith<$Res>  {
  factory $MedalCopyWith(Medal value, $Res Function(Medal) _then) = _$MedalCopyWithImpl;
@useResult
$Res call({
 String code, String name, String description, String iconKey, int sortOrder, DateTime? awardedAt,@JsonKey(unknownEnumValue: MedalCategory.achievement) MedalCategory category, String? metric, int? level, int maxLevel, List<MedalLevel> levels, MedalProgress progress, String? iconUrl, String? iconAsset, int? showcasePosition, bool eligible
});


$MedalProgressCopyWith<$Res> get progress;

}
/// @nodoc
class _$MedalCopyWithImpl<$Res>
    implements $MedalCopyWith<$Res> {
  _$MedalCopyWithImpl(this._self, this._then);

  final Medal _self;
  final $Res Function(Medal) _then;

/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? sortOrder = null,Object? awardedAt = freezed,Object? category = null,Object? metric = freezed,Object? level = freezed,Object? maxLevel = null,Object? levels = null,Object? progress = null,Object? iconUrl = freezed,Object? iconAsset = freezed,Object? showcasePosition = freezed,Object? eligible = null,}) {
  return _then(Medal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,awardedAt: freezed == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as MedalCategory,metric: freezed == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as String?,level: freezed == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int?,maxLevel: null == maxLevel ? _self.maxLevel : maxLevel // ignore: cast_nullable_to_non_nullable
as int,levels: null == levels ? _self.levels : levels // ignore: cast_nullable_to_non_nullable
as List<MedalLevel>,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as MedalProgress,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,showcasePosition: freezed == showcasePosition ? _self.showcasePosition : showcasePosition // ignore: cast_nullable_to_non_nullable
as int?,eligible: null == eligible ? _self.eligible : eligible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MedalProgressCopyWith<$Res> get progress {
  
  return $MedalProgressCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// Adds pattern-matching-related methods to [Medal].
extension MedalPatterns on Medal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Medal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Medal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Medal value)  $default,){
final _that = this;
switch (_that) {
case _Medal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Medal value)?  $default,){
final _that = this;
switch (_that) {
case _Medal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  int sortOrder,  DateTime? awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement)  MedalCategory category,  String? metric,  int? level,  int maxLevel,  List<MedalLevel> levels,  MedalProgress progress,  String? iconUrl,  String? iconAsset,  int? showcasePosition,  bool eligible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Medal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.sortOrder,_that.awardedAt,_that.category,_that.metric,_that.level,_that.maxLevel,_that.levels,_that.progress,_that.iconUrl,_that.iconAsset,_that.showcasePosition,_that.eligible);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  int sortOrder,  DateTime? awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement)  MedalCategory category,  String? metric,  int? level,  int maxLevel,  List<MedalLevel> levels,  MedalProgress progress,  String? iconUrl,  String? iconAsset,  int? showcasePosition,  bool eligible)  $default,) {final _that = this;
switch (_that) {
case _Medal():
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.sortOrder,_that.awardedAt,_that.category,_that.metric,_that.level,_that.maxLevel,_that.levels,_that.progress,_that.iconUrl,_that.iconAsset,_that.showcasePosition,_that.eligible);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String description,  String iconKey,  int sortOrder,  DateTime? awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement)  MedalCategory category,  String? metric,  int? level,  int maxLevel,  List<MedalLevel> levels,  MedalProgress progress,  String? iconUrl,  String? iconAsset,  int? showcasePosition,  bool eligible)?  $default,) {final _that = this;
switch (_that) {
case _Medal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.sortOrder,_that.awardedAt,_that.category,_that.metric,_that.level,_that.maxLevel,_that.levels,_that.progress,_that.iconUrl,_that.iconAsset,_that.showcasePosition,_that.eligible);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Medal extends Medal {
  const _Medal({required this.code, required this.name, required this.description, required this.iconKey, required this.sortOrder, required this.awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement) this.category = MedalCategory.achievement, this.metric, this.level, this.maxLevel = 1,  List<MedalLevel> levels = const <MedalLevel>[], this.progress = const MedalProgress(), this.iconUrl, this.iconAsset, this.showcasePosition, this.eligible = true}): _levels = levels,super._();
  factory _Medal.fromJson(Map<String, dynamic> json) => _$MedalFromJson(json);

@override final  String code;
@override final  String name;
@override final  String description;
@override final  String iconKey;
@override final  int sortOrder;
@override final  DateTime? awardedAt;
@override@JsonKey(unknownEnumValue: MedalCategory.achievement) final  MedalCategory category;
/// What the levels count (`MedalMetric`: LIVES_HOSTED, LIVE_HOURS,
/// CHARM_LEVEL, FAMILY_JOINED, CP_FORMED, BULLETS_SENT); null = none or
/// unknown — the thresholds are then shown as bare numbers.
@override final  String? metric;
@override final  int? level;
@override@JsonKey() final  int maxLevel;
 final  List<MedalLevel> _levels;
@override@JsonKey() List<MedalLevel> get levels {
  if (_levels is EqualUnmodifiableListView) return _levels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levels);
}

@override@JsonKey() final  MedalProgress progress;
@override final  String? iconUrl;
/// D291: the bundled art key of the level shown, or null.
@override final  String? iconAsset;
@override final  int? showcasePosition;
/// D300: false when the medal is for content creators and the caller is
/// not one now (no progress; a level reached is kept). Older servers:
/// true.
@override@JsonKey() final  bool eligible;

/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalCopyWith<_Medal> get copyWith => __$MedalCopyWithImpl<_Medal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Medal&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.awardedAt, awardedAt) || other.awardedAt == awardedAt)&&(identical(other.category, category) || other.category == category)&&(identical(other.metric, metric) || other.metric == metric)&&(identical(other.level, level) || other.level == level)&&(identical(other.maxLevel, maxLevel) || other.maxLevel == maxLevel)&&const DeepCollectionEquality().equals(other.levels, _levels)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.iconAsset, iconAsset) || other.iconAsset == iconAsset)&&(identical(other.showcasePosition, showcasePosition) || other.showcasePosition == showcasePosition)&&(identical(other.eligible, eligible) || other.eligible == eligible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,description,iconKey,sortOrder,awardedAt,category,metric,level,maxLevel,const DeepCollectionEquality().hash(_levels),progress,iconUrl,iconAsset,showcasePosition,eligible);
}

@override
String toString() {
    return 'Medal(code: $code, name: $name, description: $description, iconKey: $iconKey, sortOrder: $sortOrder, awardedAt: $awardedAt, category: $category, metric: $metric, level: $level, maxLevel: $maxLevel, levels: $levels, progress: $progress, iconUrl: $iconUrl, iconAsset: $iconAsset, showcasePosition: $showcasePosition, eligible: $eligible)';
}


}

/// @nodoc
abstract mixin class _$MedalCopyWith<$Res> implements $MedalCopyWith<$Res> {
  factory _$MedalCopyWith(_Medal value, $Res Function(_Medal) _then) = __$MedalCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String description, String iconKey, int sortOrder, DateTime? awardedAt,@JsonKey(unknownEnumValue: MedalCategory.achievement) MedalCategory category, String? metric, int? level, int maxLevel, List<MedalLevel> levels, MedalProgress progress, String? iconUrl, String? iconAsset, int? showcasePosition, bool eligible
});


@override $MedalProgressCopyWith<$Res> get progress;

}
/// @nodoc
class __$MedalCopyWithImpl<$Res>
    implements _$MedalCopyWith<$Res> {
  __$MedalCopyWithImpl(this._self, this._then);

  final _Medal _self;
  final $Res Function(_Medal) _then;

/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? sortOrder = null,Object? awardedAt = freezed,Object? category = null,Object? metric = freezed,Object? level = freezed,Object? maxLevel = null,Object? levels = null,Object? progress = null,Object? iconUrl = freezed,Object? iconAsset = freezed,Object? showcasePosition = freezed,Object? eligible = null,}) {
  return _then(_Medal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,awardedAt: freezed == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as MedalCategory,metric: freezed == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as String?,level: freezed == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int?,maxLevel: null == maxLevel ? _self.maxLevel : maxLevel // ignore: cast_nullable_to_non_nullable
as int,levels: null == levels ? _self._levels : levels // ignore: cast_nullable_to_non_nullable
as List<MedalLevel>,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as MedalProgress,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,showcasePosition: freezed == showcasePosition ? _self.showcasePosition : showcasePosition // ignore: cast_nullable_to_non_nullable
as int?,eligible: null == eligible ? _self.eligible : eligible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MedalProgressCopyWith<$Res> get progress {
  
  return $MedalProgressCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// @nodoc
mixin _$MedalCatalogue {

 List<Medal> get data; int get total; int get owned;
/// Create a copy of MedalCatalogue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalCatalogueCopyWith<MedalCatalogue> get copyWith => _$MedalCatalogueCopyWithImpl<MedalCatalogue>(this as MedalCatalogue, _$identity);

  /// Serializes this MedalCatalogue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MedalCatalogue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedalCatalogue&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.owned, _this.owned) || other.owned == _this.owned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MedalCatalogue;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.total,_this.owned);
}

@override
String toString() {
  final _this = this as MedalCatalogue;
  return 'MedalCatalogue(data: ${_this.data}, total: ${_this.total}, owned: ${_this.owned})';
}


}

/// @nodoc
abstract mixin class $MedalCatalogueCopyWith<$Res>  {
  factory $MedalCatalogueCopyWith(MedalCatalogue value, $Res Function(MedalCatalogue) _then) = _$MedalCatalogueCopyWithImpl;
@useResult
$Res call({
 List<Medal> data, int total, int owned
});




}
/// @nodoc
class _$MedalCatalogueCopyWithImpl<$Res>
    implements $MedalCatalogueCopyWith<$Res> {
  _$MedalCatalogueCopyWithImpl(this._self, this._then);

  final MedalCatalogue _self;
  final $Res Function(MedalCatalogue) _then;

/// Create a copy of MedalCatalogue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? total = null,Object? owned = null,}) {
  return _then(MedalCatalogue(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<Medal>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MedalCatalogue].
extension MedalCataloguePatterns on MedalCatalogue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedalCatalogue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedalCatalogue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedalCatalogue value)  $default,){
final _that = this;
switch (_that) {
case _MedalCatalogue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedalCatalogue value)?  $default,){
final _that = this;
switch (_that) {
case _MedalCatalogue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Medal> data,  int total,  int owned)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedalCatalogue() when $default != null:
return $default(_that.data,_that.total,_that.owned);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Medal> data,  int total,  int owned)  $default,) {final _that = this;
switch (_that) {
case _MedalCatalogue():
return $default(_that.data,_that.total,_that.owned);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Medal> data,  int total,  int owned)?  $default,) {final _that = this;
switch (_that) {
case _MedalCatalogue() when $default != null:
return $default(_that.data,_that.total,_that.owned);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedalCatalogue implements MedalCatalogue {
  const _MedalCatalogue({required  List<Medal> data, required this.total, required this.owned}): _data = data;
  factory _MedalCatalogue.fromJson(Map<String, dynamic> json) => _$MedalCatalogueFromJson(json);

 final  List<Medal> _data;
@override List<Medal> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  int total;
@override final  int owned;

/// Create a copy of MedalCatalogue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalCatalogueCopyWith<_MedalCatalogue> get copyWith => __$MedalCatalogueCopyWithImpl<_MedalCatalogue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalCatalogueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedalCatalogue&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.total, total) || other.total == total)&&(identical(other.owned, owned) || other.owned == owned));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),total,owned);
}

@override
String toString() {
    return 'MedalCatalogue(data: $data, total: $total, owned: $owned)';
}


}

/// @nodoc
abstract mixin class _$MedalCatalogueCopyWith<$Res> implements $MedalCatalogueCopyWith<$Res> {
  factory _$MedalCatalogueCopyWith(_MedalCatalogue value, $Res Function(_MedalCatalogue) _then) = __$MedalCatalogueCopyWithImpl;
@override @useResult
$Res call({
 List<Medal> data, int total, int owned
});




}
/// @nodoc
class __$MedalCatalogueCopyWithImpl<$Res>
    implements _$MedalCatalogueCopyWith<$Res> {
  __$MedalCatalogueCopyWithImpl(this._self, this._then);

  final _MedalCatalogue _self;
  final $Res Function(_MedalCatalogue) _then;

/// Create a copy of MedalCatalogue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? total = null,Object? owned = null,}) {
  return _then(_MedalCatalogue(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<Medal>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UserMedal {

 String get code; String get name; String get description; String get iconKey; DateTime get awardedAt;@JsonKey(unknownEnumValue: MedalCategory.achievement) MedalCategory get category;/// v1.81-live (D291): the user's level (older servers: 1).
 int get level; int get maxLevel; String? get iconUrl; String? get iconAsset;
/// Create a copy of UserMedal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserMedalCopyWith<UserMedal> get copyWith => _$UserMedalCopyWithImpl<UserMedal>(this as UserMedal, _$identity);

  /// Serializes this UserMedal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserMedal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserMedal&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.iconKey, _this.iconKey) || other.iconKey == _this.iconKey)&&(identical(other.awardedAt, _this.awardedAt) || other.awardedAt == _this.awardedAt)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.maxLevel, _this.maxLevel) || other.maxLevel == _this.maxLevel)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.iconAsset, _this.iconAsset) || other.iconAsset == _this.iconAsset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserMedal;
  return Object.hash(runtimeType,_this.code,_this.name,_this.description,_this.iconKey,_this.awardedAt,_this.category,_this.level,_this.maxLevel,_this.iconUrl,_this.iconAsset);
}

@override
String toString() {
  final _this = this as UserMedal;
  return 'UserMedal(code: ${_this.code}, name: ${_this.name}, description: ${_this.description}, iconKey: ${_this.iconKey}, awardedAt: ${_this.awardedAt}, category: ${_this.category}, level: ${_this.level}, maxLevel: ${_this.maxLevel}, iconUrl: ${_this.iconUrl}, iconAsset: ${_this.iconAsset})';
}


}

/// @nodoc
abstract mixin class $UserMedalCopyWith<$Res>  {
  factory $UserMedalCopyWith(UserMedal value, $Res Function(UserMedal) _then) = _$UserMedalCopyWithImpl;
@useResult
$Res call({
 String code, String name, String description, String iconKey, DateTime awardedAt,@JsonKey(unknownEnumValue: MedalCategory.achievement) MedalCategory category, int level, int maxLevel, String? iconUrl, String? iconAsset
});




}
/// @nodoc
class _$UserMedalCopyWithImpl<$Res>
    implements $UserMedalCopyWith<$Res> {
  _$UserMedalCopyWithImpl(this._self, this._then);

  final UserMedal _self;
  final $Res Function(UserMedal) _then;

/// Create a copy of UserMedal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? awardedAt = null,Object? category = null,Object? level = null,Object? maxLevel = null,Object? iconUrl = freezed,Object? iconAsset = freezed,}) {
  return _then(UserMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,awardedAt: null == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as MedalCategory,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,maxLevel: null == maxLevel ? _self.maxLevel : maxLevel // ignore: cast_nullable_to_non_nullable
as int,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserMedal].
extension UserMedalPatterns on UserMedal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserMedal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserMedal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserMedal value)  $default,){
final _that = this;
switch (_that) {
case _UserMedal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserMedal value)?  $default,){
final _that = this;
switch (_that) {
case _UserMedal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  DateTime awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement)  MedalCategory category,  int level,  int maxLevel,  String? iconUrl,  String? iconAsset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserMedal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.awardedAt,_that.category,_that.level,_that.maxLevel,_that.iconUrl,_that.iconAsset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  DateTime awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement)  MedalCategory category,  int level,  int maxLevel,  String? iconUrl,  String? iconAsset)  $default,) {final _that = this;
switch (_that) {
case _UserMedal():
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.awardedAt,_that.category,_that.level,_that.maxLevel,_that.iconUrl,_that.iconAsset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String description,  String iconKey,  DateTime awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement)  MedalCategory category,  int level,  int maxLevel,  String? iconUrl,  String? iconAsset)?  $default,) {final _that = this;
switch (_that) {
case _UserMedal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.awardedAt,_that.category,_that.level,_that.maxLevel,_that.iconUrl,_that.iconAsset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserMedal implements UserMedal {
  const _UserMedal({required this.code, required this.name, required this.description, required this.iconKey, required this.awardedAt, @JsonKey(unknownEnumValue: MedalCategory.achievement) this.category = MedalCategory.achievement, this.level = 1, this.maxLevel = 1, this.iconUrl, this.iconAsset});
  factory _UserMedal.fromJson(Map<String, dynamic> json) => _$UserMedalFromJson(json);

@override final  String code;
@override final  String name;
@override final  String description;
@override final  String iconKey;
@override final  DateTime awardedAt;
@override@JsonKey(unknownEnumValue: MedalCategory.achievement) final  MedalCategory category;
/// v1.81-live (D291): the user's level (older servers: 1).
@override@JsonKey() final  int level;
@override@JsonKey() final  int maxLevel;
@override final  String? iconUrl;
@override final  String? iconAsset;

/// Create a copy of UserMedal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserMedalCopyWith<_UserMedal> get copyWith => __$UserMedalCopyWithImpl<_UserMedal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserMedalToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserMedal&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.awardedAt, awardedAt) || other.awardedAt == awardedAt)&&(identical(other.category, category) || other.category == category)&&(identical(other.level, level) || other.level == level)&&(identical(other.maxLevel, maxLevel) || other.maxLevel == maxLevel)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.iconAsset, iconAsset) || other.iconAsset == iconAsset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,description,iconKey,awardedAt,category,level,maxLevel,iconUrl,iconAsset);
}

@override
String toString() {
    return 'UserMedal(code: $code, name: $name, description: $description, iconKey: $iconKey, awardedAt: $awardedAt, category: $category, level: $level, maxLevel: $maxLevel, iconUrl: $iconUrl, iconAsset: $iconAsset)';
}


}

/// @nodoc
abstract mixin class _$UserMedalCopyWith<$Res> implements $UserMedalCopyWith<$Res> {
  factory _$UserMedalCopyWith(_UserMedal value, $Res Function(_UserMedal) _then) = __$UserMedalCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String description, String iconKey, DateTime awardedAt,@JsonKey(unknownEnumValue: MedalCategory.achievement) MedalCategory category, int level, int maxLevel, String? iconUrl, String? iconAsset
});




}
/// @nodoc
class __$UserMedalCopyWithImpl<$Res>
    implements _$UserMedalCopyWith<$Res> {
  __$UserMedalCopyWithImpl(this._self, this._then);

  final _UserMedal _self;
  final $Res Function(_UserMedal) _then;

/// Create a copy of UserMedal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? awardedAt = null,Object? category = null,Object? level = null,Object? maxLevel = null,Object? iconUrl = freezed,Object? iconAsset = freezed,}) {
  return _then(_UserMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,awardedAt: null == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as MedalCategory,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,maxLevel: null == maxLevel ? _self.maxLevel : maxLevel // ignore: cast_nullable_to_non_nullable
as int,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$UserMedalList {

 List<UserMedal> get data; int get owned; int get total;
/// Create a copy of UserMedalList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserMedalListCopyWith<UserMedalList> get copyWith => _$UserMedalListCopyWithImpl<UserMedalList>(this as UserMedalList, _$identity);

  /// Serializes this UserMedalList to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserMedalList;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserMedalList&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.owned, _this.owned) || other.owned == _this.owned)&&(identical(other.total, _this.total) || other.total == _this.total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserMedalList;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.owned,_this.total);
}

@override
String toString() {
  final _this = this as UserMedalList;
  return 'UserMedalList(data: ${_this.data}, owned: ${_this.owned}, total: ${_this.total})';
}


}

/// @nodoc
abstract mixin class $UserMedalListCopyWith<$Res>  {
  factory $UserMedalListCopyWith(UserMedalList value, $Res Function(UserMedalList) _then) = _$UserMedalListCopyWithImpl;
@useResult
$Res call({
 List<UserMedal> data, int owned, int total
});




}
/// @nodoc
class _$UserMedalListCopyWithImpl<$Res>
    implements $UserMedalListCopyWith<$Res> {
  _$UserMedalListCopyWithImpl(this._self, this._then);

  final UserMedalList _self;
  final $Res Function(UserMedalList) _then;

/// Create a copy of UserMedalList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? owned = null,Object? total = null,}) {
  return _then(UserMedalList(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<UserMedal>,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserMedalList].
extension UserMedalListPatterns on UserMedalList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserMedalList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserMedalList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserMedalList value)  $default,){
final _that = this;
switch (_that) {
case _UserMedalList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserMedalList value)?  $default,){
final _that = this;
switch (_that) {
case _UserMedalList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UserMedal> data,  int owned,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserMedalList() when $default != null:
return $default(_that.data,_that.owned,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UserMedal> data,  int owned,  int total)  $default,) {final _that = this;
switch (_that) {
case _UserMedalList():
return $default(_that.data,_that.owned,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UserMedal> data,  int owned,  int total)?  $default,) {final _that = this;
switch (_that) {
case _UserMedalList() when $default != null:
return $default(_that.data,_that.owned,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserMedalList implements UserMedalList {
  const _UserMedalList({required  List<UserMedal> data, required this.owned, required this.total}): _data = data;
  factory _UserMedalList.fromJson(Map<String, dynamic> json) => _$UserMedalListFromJson(json);

 final  List<UserMedal> _data;
@override List<UserMedal> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  int owned;
@override final  int total;

/// Create a copy of UserMedalList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserMedalListCopyWith<_UserMedalList> get copyWith => __$UserMedalListCopyWithImpl<_UserMedalList>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserMedalListToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserMedalList&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.owned, owned) || other.owned == owned)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),owned,total);
}

@override
String toString() {
    return 'UserMedalList(data: $data, owned: $owned, total: $total)';
}


}

/// @nodoc
abstract mixin class _$UserMedalListCopyWith<$Res> implements $UserMedalListCopyWith<$Res> {
  factory _$UserMedalListCopyWith(_UserMedalList value, $Res Function(_UserMedalList) _then) = __$UserMedalListCopyWithImpl;
@override @useResult
$Res call({
 List<UserMedal> data, int owned, int total
});




}
/// @nodoc
class __$UserMedalListCopyWithImpl<$Res>
    implements _$UserMedalListCopyWith<$Res> {
  __$UserMedalListCopyWithImpl(this._self, this._then);

  final _UserMedalList _self;
  final $Res Function(_UserMedalList) _then;

/// Create a copy of UserMedalList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? owned = null,Object? total = null,}) {
  return _then(_UserMedalList(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<UserMedal>,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ProfileMedal {

 String get code; String get name; String get iconKey; int get level; String? get iconUrl; String? get iconAsset;
/// Create a copy of ProfileMedal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileMedalCopyWith<ProfileMedal> get copyWith => _$ProfileMedalCopyWithImpl<ProfileMedal>(this as ProfileMedal, _$identity);

  /// Serializes this ProfileMedal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileMedal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileMedal&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.iconKey, _this.iconKey) || other.iconKey == _this.iconKey)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.iconAsset, _this.iconAsset) || other.iconAsset == _this.iconAsset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileMedal;
  return Object.hash(runtimeType,_this.code,_this.name,_this.iconKey,_this.level,_this.iconUrl,_this.iconAsset);
}

@override
String toString() {
  final _this = this as ProfileMedal;
  return 'ProfileMedal(code: ${_this.code}, name: ${_this.name}, iconKey: ${_this.iconKey}, level: ${_this.level}, iconUrl: ${_this.iconUrl}, iconAsset: ${_this.iconAsset})';
}


}

/// @nodoc
abstract mixin class $ProfileMedalCopyWith<$Res>  {
  factory $ProfileMedalCopyWith(ProfileMedal value, $Res Function(ProfileMedal) _then) = _$ProfileMedalCopyWithImpl;
@useResult
$Res call({
 String code, String name, String iconKey, int level, String? iconUrl, String? iconAsset
});




}
/// @nodoc
class _$ProfileMedalCopyWithImpl<$Res>
    implements $ProfileMedalCopyWith<$Res> {
  _$ProfileMedalCopyWithImpl(this._self, this._then);

  final ProfileMedal _self;
  final $Res Function(ProfileMedal) _then;

/// Create a copy of ProfileMedal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? iconKey = null,Object? level = null,Object? iconUrl = freezed,Object? iconAsset = freezed,}) {
  return _then(ProfileMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileMedal].
extension ProfileMedalPatterns on ProfileMedal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileMedal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileMedal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileMedal value)  $default,){
final _that = this;
switch (_that) {
case _ProfileMedal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileMedal value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileMedal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String iconKey,  int level,  String? iconUrl,  String? iconAsset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileMedal() when $default != null:
return $default(_that.code,_that.name,_that.iconKey,_that.level,_that.iconUrl,_that.iconAsset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String iconKey,  int level,  String? iconUrl,  String? iconAsset)  $default,) {final _that = this;
switch (_that) {
case _ProfileMedal():
return $default(_that.code,_that.name,_that.iconKey,_that.level,_that.iconUrl,_that.iconAsset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String iconKey,  int level,  String? iconUrl,  String? iconAsset)?  $default,) {final _that = this;
switch (_that) {
case _ProfileMedal() when $default != null:
return $default(_that.code,_that.name,_that.iconKey,_that.level,_that.iconUrl,_that.iconAsset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileMedal implements ProfileMedal {
  const _ProfileMedal({required this.code, required this.name, required this.iconKey, this.level = 1, this.iconUrl, this.iconAsset});
  factory _ProfileMedal.fromJson(Map<String, dynamic> json) => _$ProfileMedalFromJson(json);

@override final  String code;
@override final  String name;
@override final  String iconKey;
@override@JsonKey() final  int level;
@override final  String? iconUrl;
@override final  String? iconAsset;

/// Create a copy of ProfileMedal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileMedalCopyWith<_ProfileMedal> get copyWith => __$ProfileMedalCopyWithImpl<_ProfileMedal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileMedalToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileMedal&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.level, level) || other.level == level)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.iconAsset, iconAsset) || other.iconAsset == iconAsset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,iconKey,level,iconUrl,iconAsset);
}

@override
String toString() {
    return 'ProfileMedal(code: $code, name: $name, iconKey: $iconKey, level: $level, iconUrl: $iconUrl, iconAsset: $iconAsset)';
}


}

/// @nodoc
abstract mixin class _$ProfileMedalCopyWith<$Res> implements $ProfileMedalCopyWith<$Res> {
  factory _$ProfileMedalCopyWith(_ProfileMedal value, $Res Function(_ProfileMedal) _then) = __$ProfileMedalCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String iconKey, int level, String? iconUrl, String? iconAsset
});




}
/// @nodoc
class __$ProfileMedalCopyWithImpl<$Res>
    implements _$ProfileMedalCopyWith<$Res> {
  __$ProfileMedalCopyWithImpl(this._self, this._then);

  final _ProfileMedal _self;
  final $Res Function(_ProfileMedal) _then;

/// Create a copy of ProfileMedal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? iconKey = null,Object? level = null,Object? iconUrl = freezed,Object? iconAsset = freezed,}) {
  return _then(_ProfileMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,iconAsset: freezed == iconAsset ? _self.iconAsset : iconAsset // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProfileMedals {

 int get owned; int get total; List<ProfileMedal> get latest; List<ProfileMedal> get showcase;
/// Create a copy of ProfileMedals
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileMedalsCopyWith<ProfileMedals> get copyWith => _$ProfileMedalsCopyWithImpl<ProfileMedals>(this as ProfileMedals, _$identity);

  /// Serializes this ProfileMedals to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileMedals;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileMedals&&(identical(other.owned, _this.owned) || other.owned == _this.owned)&&(identical(other.total, _this.total) || other.total == _this.total)&&const DeepCollectionEquality().equals(other.latest, _this.latest)&&const DeepCollectionEquality().equals(other.showcase, _this.showcase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileMedals;
  return Object.hash(runtimeType,_this.owned,_this.total,const DeepCollectionEquality().hash(_this.latest),const DeepCollectionEquality().hash(_this.showcase));
}

@override
String toString() {
  final _this = this as ProfileMedals;
  return 'ProfileMedals(owned: ${_this.owned}, total: ${_this.total}, latest: ${_this.latest}, showcase: ${_this.showcase})';
}


}

/// @nodoc
abstract mixin class $ProfileMedalsCopyWith<$Res>  {
  factory $ProfileMedalsCopyWith(ProfileMedals value, $Res Function(ProfileMedals) _then) = _$ProfileMedalsCopyWithImpl;
@useResult
$Res call({
 int owned, int total, List<ProfileMedal> latest, List<ProfileMedal> showcase
});




}
/// @nodoc
class _$ProfileMedalsCopyWithImpl<$Res>
    implements $ProfileMedalsCopyWith<$Res> {
  _$ProfileMedalsCopyWithImpl(this._self, this._then);

  final ProfileMedals _self;
  final $Res Function(ProfileMedals) _then;

/// Create a copy of ProfileMedals
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? owned = null,Object? total = null,Object? latest = null,Object? showcase = null,}) {
  return _then(ProfileMedals(
owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,latest: null == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as List<ProfileMedal>,showcase: null == showcase ? _self.showcase : showcase // ignore: cast_nullable_to_non_nullable
as List<ProfileMedal>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileMedals].
extension ProfileMedalsPatterns on ProfileMedals {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileMedals value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileMedals() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileMedals value)  $default,){
final _that = this;
switch (_that) {
case _ProfileMedals():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileMedals value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileMedals() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int owned,  int total,  List<ProfileMedal> latest,  List<ProfileMedal> showcase)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileMedals() when $default != null:
return $default(_that.owned,_that.total,_that.latest,_that.showcase);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int owned,  int total,  List<ProfileMedal> latest,  List<ProfileMedal> showcase)  $default,) {final _that = this;
switch (_that) {
case _ProfileMedals():
return $default(_that.owned,_that.total,_that.latest,_that.showcase);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int owned,  int total,  List<ProfileMedal> latest,  List<ProfileMedal> showcase)?  $default,) {final _that = this;
switch (_that) {
case _ProfileMedals() when $default != null:
return $default(_that.owned,_that.total,_that.latest,_that.showcase);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileMedals implements ProfileMedals {
  const _ProfileMedals({this.owned = 0, this.total = 0,  List<ProfileMedal> latest = const <ProfileMedal>[],  List<ProfileMedal> showcase = const <ProfileMedal>[]}): _latest = latest,_showcase = showcase;
  factory _ProfileMedals.fromJson(Map<String, dynamic> json) => _$ProfileMedalsFromJson(json);

@override@JsonKey() final  int owned;
@override@JsonKey() final  int total;
 final  List<ProfileMedal> _latest;
@override@JsonKey() List<ProfileMedal> get latest {
  if (_latest is EqualUnmodifiableListView) return _latest;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_latest);
}

 final  List<ProfileMedal> _showcase;
@override@JsonKey() List<ProfileMedal> get showcase {
  if (_showcase is EqualUnmodifiableListView) return _showcase;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_showcase);
}


/// Create a copy of ProfileMedals
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileMedalsCopyWith<_ProfileMedals> get copyWith => __$ProfileMedalsCopyWithImpl<_ProfileMedals>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileMedalsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileMedals&&(identical(other.owned, owned) || other.owned == owned)&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.latest, _latest)&&const DeepCollectionEquality().equals(other.showcase, _showcase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,owned,total,const DeepCollectionEquality().hash(_latest),const DeepCollectionEquality().hash(_showcase));
}

@override
String toString() {
    return 'ProfileMedals(owned: $owned, total: $total, latest: $latest, showcase: $showcase)';
}


}

/// @nodoc
abstract mixin class _$ProfileMedalsCopyWith<$Res> implements $ProfileMedalsCopyWith<$Res> {
  factory _$ProfileMedalsCopyWith(_ProfileMedals value, $Res Function(_ProfileMedals) _then) = __$ProfileMedalsCopyWithImpl;
@override @useResult
$Res call({
 int owned, int total, List<ProfileMedal> latest, List<ProfileMedal> showcase
});




}
/// @nodoc
class __$ProfileMedalsCopyWithImpl<$Res>
    implements _$ProfileMedalsCopyWith<$Res> {
  __$ProfileMedalsCopyWithImpl(this._self, this._then);

  final _ProfileMedals _self;
  final $Res Function(_ProfileMedals) _then;

/// Create a copy of ProfileMedals
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? owned = null,Object? total = null,Object? latest = null,Object? showcase = null,}) {
  return _then(_ProfileMedals(
owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,latest: null == latest ? _self._latest : latest // ignore: cast_nullable_to_non_nullable
as List<ProfileMedal>,showcase: null == showcase ? _self._showcase : showcase // ignore: cast_nullable_to_non_nullable
as List<ProfileMedal>,
  ));
}


}

// dart format on
