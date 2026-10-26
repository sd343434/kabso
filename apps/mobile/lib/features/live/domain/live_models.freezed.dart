// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveConfig {

 bool get hostingEnabled; int get heartbeatIntervalSeconds; int get heartbeatStaleAfterSeconds;/// CP-011: room themes the server accepts (the first is the default).
 List<String> get themes;/// CP-011: allowed seat counts per mode, the host's tile included.
 LiveSeatCounts get seatCounts;
/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveConfigCopyWith<LiveConfig> get copyWith => _$LiveConfigCopyWithImpl<LiveConfig>(this as LiveConfig, _$identity);

  /// Serializes this LiveConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveConfig&&(identical(other.hostingEnabled, _this.hostingEnabled) || other.hostingEnabled == _this.hostingEnabled)&&(identical(other.heartbeatIntervalSeconds, _this.heartbeatIntervalSeconds) || other.heartbeatIntervalSeconds == _this.heartbeatIntervalSeconds)&&(identical(other.heartbeatStaleAfterSeconds, _this.heartbeatStaleAfterSeconds) || other.heartbeatStaleAfterSeconds == _this.heartbeatStaleAfterSeconds)&&const DeepCollectionEquality().equals(other.themes, _this.themes)&&(identical(other.seatCounts, _this.seatCounts) || other.seatCounts == _this.seatCounts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveConfig;
  return Object.hash(runtimeType,_this.hostingEnabled,_this.heartbeatIntervalSeconds,_this.heartbeatStaleAfterSeconds,const DeepCollectionEquality().hash(_this.themes),_this.seatCounts);
}

@override
String toString() {
  final _this = this as LiveConfig;
  return 'LiveConfig(hostingEnabled: ${_this.hostingEnabled}, heartbeatIntervalSeconds: ${_this.heartbeatIntervalSeconds}, heartbeatStaleAfterSeconds: ${_this.heartbeatStaleAfterSeconds}, themes: ${_this.themes}, seatCounts: ${_this.seatCounts})';
}


}

/// @nodoc
abstract mixin class $LiveConfigCopyWith<$Res>  {
  factory $LiveConfigCopyWith(LiveConfig value, $Res Function(LiveConfig) _then) = _$LiveConfigCopyWithImpl;
@useResult
$Res call({
 bool hostingEnabled, int heartbeatIntervalSeconds, int heartbeatStaleAfterSeconds, List<String> themes, LiveSeatCounts seatCounts
});


$LiveSeatCountsCopyWith<$Res> get seatCounts;

}
/// @nodoc
class _$LiveConfigCopyWithImpl<$Res>
    implements $LiveConfigCopyWith<$Res> {
  _$LiveConfigCopyWithImpl(this._self, this._then);

  final LiveConfig _self;
  final $Res Function(LiveConfig) _then;

/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostingEnabled = null,Object? heartbeatIntervalSeconds = null,Object? heartbeatStaleAfterSeconds = null,Object? themes = null,Object? seatCounts = null,}) {
  return _then(LiveConfig(
hostingEnabled: null == hostingEnabled ? _self.hostingEnabled : hostingEnabled // ignore: cast_nullable_to_non_nullable
as bool,heartbeatIntervalSeconds: null == heartbeatIntervalSeconds ? _self.heartbeatIntervalSeconds : heartbeatIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,heartbeatStaleAfterSeconds: null == heartbeatStaleAfterSeconds ? _self.heartbeatStaleAfterSeconds : heartbeatStaleAfterSeconds // ignore: cast_nullable_to_non_nullable
as int,themes: null == themes ? _self.themes : themes // ignore: cast_nullable_to_non_nullable
as List<String>,seatCounts: null == seatCounts ? _self.seatCounts : seatCounts // ignore: cast_nullable_to_non_nullable
as LiveSeatCounts,
  ));
}
/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatCountsCopyWith<$Res> get seatCounts {
  
  return $LiveSeatCountsCopyWith<$Res>(_self.seatCounts, (value) {
    return _then(_self.copyWith(seatCounts: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveConfig].
extension LiveConfigPatterns on LiveConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveConfig value)  $default,){
final _that = this;
switch (_that) {
case _LiveConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveConfig value)?  $default,){
final _that = this;
switch (_that) {
case _LiveConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hostingEnabled,  int heartbeatIntervalSeconds,  int heartbeatStaleAfterSeconds,  List<String> themes,  LiveSeatCounts seatCounts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveConfig() when $default != null:
return $default(_that.hostingEnabled,_that.heartbeatIntervalSeconds,_that.heartbeatStaleAfterSeconds,_that.themes,_that.seatCounts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hostingEnabled,  int heartbeatIntervalSeconds,  int heartbeatStaleAfterSeconds,  List<String> themes,  LiveSeatCounts seatCounts)  $default,) {final _that = this;
switch (_that) {
case _LiveConfig():
return $default(_that.hostingEnabled,_that.heartbeatIntervalSeconds,_that.heartbeatStaleAfterSeconds,_that.themes,_that.seatCounts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hostingEnabled,  int heartbeatIntervalSeconds,  int heartbeatStaleAfterSeconds,  List<String> themes,  LiveSeatCounts seatCounts)?  $default,) {final _that = this;
switch (_that) {
case _LiveConfig() when $default != null:
return $default(_that.hostingEnabled,_that.heartbeatIntervalSeconds,_that.heartbeatStaleAfterSeconds,_that.themes,_that.seatCounts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveConfig implements LiveConfig {
  const _LiveConfig({required this.hostingEnabled, required this.heartbeatIntervalSeconds, required this.heartbeatStaleAfterSeconds,  List<String> themes = const <String>[LiveThemes.classic], this.seatCounts = const LiveSeatCounts()}): _themes = themes;
  factory _LiveConfig.fromJson(Map<String, dynamic> json) => _$LiveConfigFromJson(json);

@override final  bool hostingEnabled;
@override final  int heartbeatIntervalSeconds;
@override final  int heartbeatStaleAfterSeconds;
/// CP-011: room themes the server accepts (the first is the default).
 final  List<String> _themes;
/// CP-011: room themes the server accepts (the first is the default).
@override@JsonKey() List<String> get themes {
  if (_themes is EqualUnmodifiableListView) return _themes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_themes);
}

/// CP-011: allowed seat counts per mode, the host's tile included.
@override@JsonKey() final  LiveSeatCounts seatCounts;

/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveConfigCopyWith<_LiveConfig> get copyWith => __$LiveConfigCopyWithImpl<_LiveConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveConfig&&(identical(other.hostingEnabled, hostingEnabled) || other.hostingEnabled == hostingEnabled)&&(identical(other.heartbeatIntervalSeconds, heartbeatIntervalSeconds) || other.heartbeatIntervalSeconds == heartbeatIntervalSeconds)&&(identical(other.heartbeatStaleAfterSeconds, heartbeatStaleAfterSeconds) || other.heartbeatStaleAfterSeconds == heartbeatStaleAfterSeconds)&&const DeepCollectionEquality().equals(other.themes, _themes)&&(identical(other.seatCounts, seatCounts) || other.seatCounts == seatCounts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hostingEnabled,heartbeatIntervalSeconds,heartbeatStaleAfterSeconds,const DeepCollectionEquality().hash(_themes),seatCounts);
}

@override
String toString() {
    return 'LiveConfig(hostingEnabled: $hostingEnabled, heartbeatIntervalSeconds: $heartbeatIntervalSeconds, heartbeatStaleAfterSeconds: $heartbeatStaleAfterSeconds, themes: $themes, seatCounts: $seatCounts)';
}


}

/// @nodoc
abstract mixin class _$LiveConfigCopyWith<$Res> implements $LiveConfigCopyWith<$Res> {
  factory _$LiveConfigCopyWith(_LiveConfig value, $Res Function(_LiveConfig) _then) = __$LiveConfigCopyWithImpl;
@override @useResult
$Res call({
 bool hostingEnabled, int heartbeatIntervalSeconds, int heartbeatStaleAfterSeconds, List<String> themes, LiveSeatCounts seatCounts
});


@override $LiveSeatCountsCopyWith<$Res> get seatCounts;

}
/// @nodoc
class __$LiveConfigCopyWithImpl<$Res>
    implements _$LiveConfigCopyWith<$Res> {
  __$LiveConfigCopyWithImpl(this._self, this._then);

  final _LiveConfig _self;
  final $Res Function(_LiveConfig) _then;

/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostingEnabled = null,Object? heartbeatIntervalSeconds = null,Object? heartbeatStaleAfterSeconds = null,Object? themes = null,Object? seatCounts = null,}) {
  return _then(_LiveConfig(
hostingEnabled: null == hostingEnabled ? _self.hostingEnabled : hostingEnabled // ignore: cast_nullable_to_non_nullable
as bool,heartbeatIntervalSeconds: null == heartbeatIntervalSeconds ? _self.heartbeatIntervalSeconds : heartbeatIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,heartbeatStaleAfterSeconds: null == heartbeatStaleAfterSeconds ? _self.heartbeatStaleAfterSeconds : heartbeatStaleAfterSeconds // ignore: cast_nullable_to_non_nullable
as int,themes: null == themes ? _self._themes : themes // ignore: cast_nullable_to_non_nullable
as List<String>,seatCounts: null == seatCounts ? _self.seatCounts : seatCounts // ignore: cast_nullable_to_non_nullable
as LiveSeatCounts,
  ));
}

/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatCountsCopyWith<$Res> get seatCounts {
  
  return $LiveSeatCountsCopyWith<$Res>(_self.seatCounts, (value) {
    return _then(_self.copyWith(seatCounts: value));
  });
}
}


/// @nodoc
mixin _$LiveSeatCounts {

@JsonKey(name: 'MULTI') List<int> get multi;@JsonKey(name: 'AUDIO') List<int> get audio;
/// Create a copy of LiveSeatCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSeatCountsCopyWith<LiveSeatCounts> get copyWith => _$LiveSeatCountsCopyWithImpl<LiveSeatCounts>(this as LiveSeatCounts, _$identity);

  /// Serializes this LiveSeatCounts to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSeatCounts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSeatCounts&&const DeepCollectionEquality().equals(other.multi, _this.multi)&&const DeepCollectionEquality().equals(other.audio, _this.audio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSeatCounts;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.multi),const DeepCollectionEquality().hash(_this.audio));
}

@override
String toString() {
  final _this = this as LiveSeatCounts;
  return 'LiveSeatCounts(multi: ${_this.multi}, audio: ${_this.audio})';
}


}

/// @nodoc
abstract mixin class $LiveSeatCountsCopyWith<$Res>  {
  factory $LiveSeatCountsCopyWith(LiveSeatCounts value, $Res Function(LiveSeatCounts) _then) = _$LiveSeatCountsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'MULTI') List<int> multi,@JsonKey(name: 'AUDIO') List<int> audio
});




}
/// @nodoc
class _$LiveSeatCountsCopyWithImpl<$Res>
    implements $LiveSeatCountsCopyWith<$Res> {
  _$LiveSeatCountsCopyWithImpl(this._self, this._then);

  final LiveSeatCounts _self;
  final $Res Function(LiveSeatCounts) _then;

/// Create a copy of LiveSeatCounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? multi = null,Object? audio = null,}) {
  return _then(LiveSeatCounts(
multi: null == multi ? _self.multi : multi // ignore: cast_nullable_to_non_nullable
as List<int>,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveSeatCounts].
extension LiveSeatCountsPatterns on LiveSeatCounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSeatCounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSeatCounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSeatCounts value)  $default,){
final _that = this;
switch (_that) {
case _LiveSeatCounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSeatCounts value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSeatCounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'MULTI')  List<int> multi, @JsonKey(name: 'AUDIO')  List<int> audio)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSeatCounts() when $default != null:
return $default(_that.multi,_that.audio);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'MULTI')  List<int> multi, @JsonKey(name: 'AUDIO')  List<int> audio)  $default,) {final _that = this;
switch (_that) {
case _LiveSeatCounts():
return $default(_that.multi,_that.audio);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'MULTI')  List<int> multi, @JsonKey(name: 'AUDIO')  List<int> audio)?  $default,) {final _that = this;
switch (_that) {
case _LiveSeatCounts() when $default != null:
return $default(_that.multi,_that.audio);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSeatCounts implements LiveSeatCounts {
  const _LiveSeatCounts({@JsonKey(name: 'MULTI')  List<int> multi = const <int>[4, 6, 9, 12], @JsonKey(name: 'AUDIO')  List<int> audio = const <int>[5, 10, 15, 20, 25]}): _multi = multi,_audio = audio;
  factory _LiveSeatCounts.fromJson(Map<String, dynamic> json) => _$LiveSeatCountsFromJson(json);

 final  List<int> _multi;
@override@JsonKey(name: 'MULTI') List<int> get multi {
  if (_multi is EqualUnmodifiableListView) return _multi;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_multi);
}

 final  List<int> _audio;
@override@JsonKey(name: 'AUDIO') List<int> get audio {
  if (_audio is EqualUnmodifiableListView) return _audio;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audio);
}


/// Create a copy of LiveSeatCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSeatCountsCopyWith<_LiveSeatCounts> get copyWith => __$LiveSeatCountsCopyWithImpl<_LiveSeatCounts>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSeatCountsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSeatCounts&&const DeepCollectionEquality().equals(other.multi, _multi)&&const DeepCollectionEquality().equals(other.audio, _audio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_multi),const DeepCollectionEquality().hash(_audio));
}

@override
String toString() {
    return 'LiveSeatCounts(multi: $multi, audio: $audio)';
}


}

/// @nodoc
abstract mixin class _$LiveSeatCountsCopyWith<$Res> implements $LiveSeatCountsCopyWith<$Res> {
  factory _$LiveSeatCountsCopyWith(_LiveSeatCounts value, $Res Function(_LiveSeatCounts) _then) = __$LiveSeatCountsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'MULTI') List<int> multi,@JsonKey(name: 'AUDIO') List<int> audio
});




}
/// @nodoc
class __$LiveSeatCountsCopyWithImpl<$Res>
    implements _$LiveSeatCountsCopyWith<$Res> {
  __$LiveSeatCountsCopyWithImpl(this._self, this._then);

  final _LiveSeatCounts _self;
  final $Res Function(_LiveSeatCounts) _then;

/// Create a copy of LiveSeatCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? multi = null,Object? audio = null,}) {
  return _then(_LiveSeatCounts(
multi: null == multi ? _self._multi : multi // ignore: cast_nullable_to_non_nullable
as List<int>,audio: null == audio ? _self._audio : audio // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$LiveCategory {

 String get slug; String get name;
/// Create a copy of LiveCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveCategoryCopyWith<LiveCategory> get copyWith => _$LiveCategoryCopyWithImpl<LiveCategory>(this as LiveCategory, _$identity);

  /// Serializes this LiveCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveCategory&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveCategory;
  return Object.hash(runtimeType,_this.slug,_this.name);
}

@override
String toString() {
  final _this = this as LiveCategory;
  return 'LiveCategory(slug: ${_this.slug}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $LiveCategoryCopyWith<$Res>  {
  factory $LiveCategoryCopyWith(LiveCategory value, $Res Function(LiveCategory) _then) = _$LiveCategoryCopyWithImpl;
@useResult
$Res call({
 String slug, String name
});




}
/// @nodoc
class _$LiveCategoryCopyWithImpl<$Res>
    implements $LiveCategoryCopyWith<$Res> {
  _$LiveCategoryCopyWithImpl(this._self, this._then);

  final LiveCategory _self;
  final $Res Function(LiveCategory) _then;

/// Create a copy of LiveCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? name = null,}) {
  return _then(LiveCategory(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveCategory].
extension LiveCategoryPatterns on LiveCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveCategory value)  $default,){
final _that = this;
switch (_that) {
case _LiveCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveCategory value)?  $default,){
final _that = this;
switch (_that) {
case _LiveCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveCategory() when $default != null:
return $default(_that.slug,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  String name)  $default,) {final _that = this;
switch (_that) {
case _LiveCategory():
return $default(_that.slug,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  String name)?  $default,) {final _that = this;
switch (_that) {
case _LiveCategory() when $default != null:
return $default(_that.slug,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveCategory implements LiveCategory {
  const _LiveCategory({required this.slug, required this.name});
  factory _LiveCategory.fromJson(Map<String, dynamic> json) => _$LiveCategoryFromJson(json);

@override final  String slug;
@override final  String name;

/// Create a copy of LiveCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveCategoryCopyWith<_LiveCategory> get copyWith => __$LiveCategoryCopyWithImpl<_LiveCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveCategory&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,slug,name);
}

@override
String toString() {
    return 'LiveCategory(slug: $slug, name: $name)';
}


}

/// @nodoc
abstract mixin class _$LiveCategoryCopyWith<$Res> implements $LiveCategoryCopyWith<$Res> {
  factory _$LiveCategoryCopyWith(_LiveCategory value, $Res Function(_LiveCategory) _then) = __$LiveCategoryCopyWithImpl;
@override @useResult
$Res call({
 String slug, String name
});




}
/// @nodoc
class __$LiveCategoryCopyWithImpl<$Res>
    implements _$LiveCategoryCopyWith<$Res> {
  __$LiveCategoryCopyWithImpl(this._self, this._then);

  final _LiveCategory _self;
  final $Res Function(_LiveCategory) _then;

/// Create a copy of LiveCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? name = null,}) {
  return _then(_LiveCategory(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LiveRoomSummary {

 String get id; String get title;@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode get mode; int get viewerCount; DateTime get startedAt; String? get coverUrl; LiveCategory? get category; UserSummary get host;/// CP-011: tiles (host included) in a MULTI or AUDIO room.
 int? get seatCount;/// CP-011: guests seated now.
 int get occupiedSeats; String get theme;/// CP-012: the live's points (taps + support); `popular` orders by it.
 int get score;/// CP-014: the host's one-line topic, or null.
 String? get topic;
/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomSummaryCopyWith<LiveRoomSummary> get copyWith => _$LiveRoomSummaryCopyWithImpl<LiveRoomSummary>(this as LiveRoomSummary, _$identity);

  /// Serializes this LiveRoomSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoomSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoomSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.viewerCount, _this.viewerCount) || other.viewerCount == _this.viewerCount)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.seatCount, _this.seatCount) || other.seatCount == _this.seatCount)&&(identical(other.occupiedSeats, _this.occupiedSeats) || other.occupiedSeats == _this.occupiedSeats)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.topic, _this.topic) || other.topic == _this.topic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoomSummary;
  return Object.hash(runtimeType,_this.id,_this.title,_this.mode,_this.viewerCount,_this.startedAt,_this.coverUrl,_this.category,_this.host,_this.seatCount,_this.occupiedSeats,_this.theme,_this.score,_this.topic);
}

@override
String toString() {
  final _this = this as LiveRoomSummary;
  return 'LiveRoomSummary(id: ${_this.id}, title: ${_this.title}, mode: ${_this.mode}, viewerCount: ${_this.viewerCount}, startedAt: ${_this.startedAt}, coverUrl: ${_this.coverUrl}, category: ${_this.category}, host: ${_this.host}, seatCount: ${_this.seatCount}, occupiedSeats: ${_this.occupiedSeats}, theme: ${_this.theme}, score: ${_this.score}, topic: ${_this.topic})';
}


}

/// @nodoc
abstract mixin class $LiveRoomSummaryCopyWith<$Res>  {
  factory $LiveRoomSummaryCopyWith(LiveRoomSummary value, $Res Function(LiveRoomSummary) _then) = _$LiveRoomSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, int? seatCount, int occupiedSeats, String theme, int score, String? topic
});


$LiveCategoryCopyWith<$Res>? get category;$UserSummaryCopyWith<$Res> get host;

}
/// @nodoc
class _$LiveRoomSummaryCopyWithImpl<$Res>
    implements $LiveRoomSummaryCopyWith<$Res> {
  _$LiveRoomSummaryCopyWithImpl(this._self, this._then);

  final LiveRoomSummary _self;
  final $Res Function(LiveRoomSummary) _then;

/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? seatCount = freezed,Object? occupiedSeats = null,Object? theme = null,Object? score = null,Object? topic = freezed,}) {
  return _then(LiveRoomSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LiveCategory?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,seatCount: freezed == seatCount ? _self.seatCount : seatCount // ignore: cast_nullable_to_non_nullable
as int?,occupiedSeats: null == occupiedSeats ? _self.occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as int,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveCategoryCopyWith<$Res>? get category {
    if (_self.category == null) {
    return null;
  }

  return $LiveCategoryCopyWith<$Res>(_self.category!, (value) {
    return _then(_self.copyWith(category: value));
  });
}/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveRoomSummary].
extension LiveRoomSummaryPatterns on LiveRoomSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoomSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoomSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoomSummary value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoomSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoomSummary value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoomSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  int? seatCount,  int occupiedSeats,  String theme,  int score,  String? topic)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoomSummary() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.seatCount,_that.occupiedSeats,_that.theme,_that.score,_that.topic);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  int? seatCount,  int occupiedSeats,  String theme,  int score,  String? topic)  $default,) {final _that = this;
switch (_that) {
case _LiveRoomSummary():
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.seatCount,_that.occupiedSeats,_that.theme,_that.score,_that.topic);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  int? seatCount,  int occupiedSeats,  String theme,  int score,  String? topic)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoomSummary() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.seatCount,_that.occupiedSeats,_that.theme,_that.score,_that.topic);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoomSummary implements LiveRoomSummary {
  const _LiveRoomSummary({required this.id, required this.title, @JsonKey(unknownEnumValue: LiveRoomMode.solo) required this.mode, required this.viewerCount, required this.startedAt, required this.coverUrl, required this.category, required this.host, this.seatCount, this.occupiedSeats = 0, this.theme = LiveThemes.classic, this.score = 0, this.topic});
  factory _LiveRoomSummary.fromJson(Map<String, dynamic> json) => _$LiveRoomSummaryFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey(unknownEnumValue: LiveRoomMode.solo) final  LiveRoomMode mode;
@override final  int viewerCount;
@override final  DateTime startedAt;
@override final  String? coverUrl;
@override final  LiveCategory? category;
@override final  UserSummary host;
/// CP-011: tiles (host included) in a MULTI or AUDIO room.
@override final  int? seatCount;
/// CP-011: guests seated now.
@override@JsonKey() final  int occupiedSeats;
@override@JsonKey() final  String theme;
/// CP-012: the live's points (taps + support); `popular` orders by it.
@override@JsonKey() final  int score;
/// CP-014: the host's one-line topic, or null.
@override final  String? topic;

/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomSummaryCopyWith<_LiveRoomSummary> get copyWith => __$LiveRoomSummaryCopyWithImpl<_LiveRoomSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoomSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.host, host) || other.host == host)&&(identical(other.seatCount, seatCount) || other.seatCount == seatCount)&&(identical(other.occupiedSeats, occupiedSeats) || other.occupiedSeats == occupiedSeats)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.score, score) || other.score == score)&&(identical(other.topic, topic) || other.topic == topic));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,mode,viewerCount,startedAt,coverUrl,category,host,seatCount,occupiedSeats,theme,score,topic);
}

@override
String toString() {
    return 'LiveRoomSummary(id: $id, title: $title, mode: $mode, viewerCount: $viewerCount, startedAt: $startedAt, coverUrl: $coverUrl, category: $category, host: $host, seatCount: $seatCount, occupiedSeats: $occupiedSeats, theme: $theme, score: $score, topic: $topic)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomSummaryCopyWith<$Res> implements $LiveRoomSummaryCopyWith<$Res> {
  factory _$LiveRoomSummaryCopyWith(_LiveRoomSummary value, $Res Function(_LiveRoomSummary) _then) = __$LiveRoomSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, int? seatCount, int occupiedSeats, String theme, int score, String? topic
});


@override $LiveCategoryCopyWith<$Res>? get category;@override $UserSummaryCopyWith<$Res> get host;

}
/// @nodoc
class __$LiveRoomSummaryCopyWithImpl<$Res>
    implements _$LiveRoomSummaryCopyWith<$Res> {
  __$LiveRoomSummaryCopyWithImpl(this._self, this._then);

  final _LiveRoomSummary _self;
  final $Res Function(_LiveRoomSummary) _then;

/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? seatCount = freezed,Object? occupiedSeats = null,Object? theme = null,Object? score = null,Object? topic = freezed,}) {
  return _then(_LiveRoomSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LiveCategory?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,seatCount: freezed == seatCount ? _self.seatCount : seatCount // ignore: cast_nullable_to_non_nullable
as int?,occupiedSeats: null == occupiedSeats ? _self.occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as int,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveCategoryCopyWith<$Res>? get category {
    if (_self.category == null) {
    return null;
  }

  return $LiveCategoryCopyWith<$Res>(_self.category!, (value) {
    return _then(_self.copyWith(category: value));
  });
}/// Create a copy of LiveRoomSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}
}


/// @nodoc
mixin _$LiveRoom {

 String get id; String get title;@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode get mode; int get viewerCount; DateTime get startedAt; String? get coverUrl; LiveCategory? get category; UserSummary get host; LiveRoomStatus get status; DateTime? get endedAt;@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? get endReason;/// CP-010: people without an account may watch.
 bool get allowGuests;/// CP-011 (see [LiveRoomSummary]).
 int? get seatCount; int get occupiedSeats; String get theme;/// CP-012 (see [LiveRoomSummary]) and its parts.
 int get score; LiveScore? get scoreParts;/// CP-013: the host has not turned the chat off.
 bool get chatEnabled;/// CP-013: the caller is muted in this live's chat.
 bool get chatMuted;/// CP-014 (see [LiveRoomSummary]).
 String? get topic;/// CP-016 G: the host's public room number ("ID: …"); null when the
/// host no longer has the hosting permission.
 int? get roomNumber;/// CP-016 D (D101): the host's charm level, shown next to the room name;
/// null while the charm levels are unavailable.
 int? get roomLevel;
/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomCopyWith<LiveRoom> get copyWith => _$LiveRoomCopyWithImpl<LiveRoom>(this as LiveRoom, _$identity);

  /// Serializes this LiveRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoom;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoom&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.viewerCount, _this.viewerCount) || other.viewerCount == _this.viewerCount)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.endedAt, _this.endedAt) || other.endedAt == _this.endedAt)&&(identical(other.endReason, _this.endReason) || other.endReason == _this.endReason)&&(identical(other.allowGuests, _this.allowGuests) || other.allowGuests == _this.allowGuests)&&(identical(other.seatCount, _this.seatCount) || other.seatCount == _this.seatCount)&&(identical(other.occupiedSeats, _this.occupiedSeats) || other.occupiedSeats == _this.occupiedSeats)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.score, _this.score) || other.score == _this.score)&&(identical(other.scoreParts, _this.scoreParts) || other.scoreParts == _this.scoreParts)&&(identical(other.chatEnabled, _this.chatEnabled) || other.chatEnabled == _this.chatEnabled)&&(identical(other.chatMuted, _this.chatMuted) || other.chatMuted == _this.chatMuted)&&(identical(other.topic, _this.topic) || other.topic == _this.topic)&&(identical(other.roomNumber, _this.roomNumber) || other.roomNumber == _this.roomNumber)&&(identical(other.roomLevel, _this.roomLevel) || other.roomLevel == _this.roomLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoom;
  return Object.hashAll([runtimeType,_this.id,_this.title,_this.mode,_this.viewerCount,_this.startedAt,_this.coverUrl,_this.category,_this.host,_this.status,_this.endedAt,_this.endReason,_this.allowGuests,_this.seatCount,_this.occupiedSeats,_this.theme,_this.score,_this.scoreParts,_this.chatEnabled,_this.chatMuted,_this.topic,_this.roomNumber,_this.roomLevel]);
}

@override
String toString() {
  final _this = this as LiveRoom;
  return 'LiveRoom(id: ${_this.id}, title: ${_this.title}, mode: ${_this.mode}, viewerCount: ${_this.viewerCount}, startedAt: ${_this.startedAt}, coverUrl: ${_this.coverUrl}, category: ${_this.category}, host: ${_this.host}, status: ${_this.status}, endedAt: ${_this.endedAt}, endReason: ${_this.endReason}, allowGuests: ${_this.allowGuests}, seatCount: ${_this.seatCount}, occupiedSeats: ${_this.occupiedSeats}, theme: ${_this.theme}, score: ${_this.score}, scoreParts: ${_this.scoreParts}, chatEnabled: ${_this.chatEnabled}, chatMuted: ${_this.chatMuted}, topic: ${_this.topic}, roomNumber: ${_this.roomNumber}, roomLevel: ${_this.roomLevel})';
}


}

/// @nodoc
abstract mixin class $LiveRoomCopyWith<$Res>  {
  factory $LiveRoomCopyWith(LiveRoom value, $Res Function(LiveRoom) _then) = _$LiveRoomCopyWithImpl;
@useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, LiveRoomStatus status, DateTime? endedAt,@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? endReason, bool allowGuests, int? seatCount, int occupiedSeats, String theme, int score, LiveScore? scoreParts, bool chatEnabled, bool chatMuted, String? topic, int? roomNumber, int? roomLevel
});


$LiveCategoryCopyWith<$Res>? get category;$UserSummaryCopyWith<$Res> get host;$LiveScoreCopyWith<$Res>? get scoreParts;

}
/// @nodoc
class _$LiveRoomCopyWithImpl<$Res>
    implements $LiveRoomCopyWith<$Res> {
  _$LiveRoomCopyWithImpl(this._self, this._then);

  final LiveRoom _self;
  final $Res Function(LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? status = null,Object? endedAt = freezed,Object? endReason = freezed,Object? allowGuests = null,Object? seatCount = freezed,Object? occupiedSeats = null,Object? theme = null,Object? score = null,Object? scoreParts = freezed,Object? chatEnabled = null,Object? chatMuted = null,Object? topic = freezed,Object? roomNumber = freezed,Object? roomLevel = freezed,}) {
  return _then(LiveRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LiveCategory?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LiveRoomStatus,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endReason: freezed == endReason ? _self.endReason : endReason // ignore: cast_nullable_to_non_nullable
as LiveRoomEndReason?,allowGuests: null == allowGuests ? _self.allowGuests : allowGuests // ignore: cast_nullable_to_non_nullable
as bool,seatCount: freezed == seatCount ? _self.seatCount : seatCount // ignore: cast_nullable_to_non_nullable
as int?,occupiedSeats: null == occupiedSeats ? _self.occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as int,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,scoreParts: freezed == scoreParts ? _self.scoreParts : scoreParts // ignore: cast_nullable_to_non_nullable
as LiveScore?,chatEnabled: null == chatEnabled ? _self.chatEnabled : chatEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatMuted: null == chatMuted ? _self.chatMuted : chatMuted // ignore: cast_nullable_to_non_nullable
as bool,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,roomNumber: freezed == roomNumber ? _self.roomNumber : roomNumber // ignore: cast_nullable_to_non_nullable
as int?,roomLevel: freezed == roomLevel ? _self.roomLevel : roomLevel // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveCategoryCopyWith<$Res>? get category {
    if (_self.category == null) {
    return null;
  }

  return $LiveCategoryCopyWith<$Res>(_self.category!, (value) {
    return _then(_self.copyWith(category: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveScoreCopyWith<$Res>? get scoreParts {
    if (_self.scoreParts == null) {
    return null;
  }

  return $LiveScoreCopyWith<$Res>(_self.scoreParts!, (value) {
    return _then(_self.copyWith(scoreParts: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveRoom].
extension LiveRoomPatterns on LiveRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoom value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoom value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason,  bool allowGuests,  int? seatCount,  int occupiedSeats,  String theme,  int score,  LiveScore? scoreParts,  bool chatEnabled,  bool chatMuted,  String? topic,  int? roomNumber,  int? roomLevel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason,_that.allowGuests,_that.seatCount,_that.occupiedSeats,_that.theme,_that.score,_that.scoreParts,_that.chatEnabled,_that.chatMuted,_that.topic,_that.roomNumber,_that.roomLevel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason,  bool allowGuests,  int? seatCount,  int occupiedSeats,  String theme,  int score,  LiveScore? scoreParts,  bool chatEnabled,  bool chatMuted,  String? topic,  int? roomNumber,  int? roomLevel)  $default,) {final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason,_that.allowGuests,_that.seatCount,_that.occupiedSeats,_that.theme,_that.score,_that.scoreParts,_that.chatEnabled,_that.chatMuted,_that.topic,_that.roomNumber,_that.roomLevel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason,  bool allowGuests,  int? seatCount,  int occupiedSeats,  String theme,  int score,  LiveScore? scoreParts,  bool chatEnabled,  bool chatMuted,  String? topic,  int? roomNumber,  int? roomLevel)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason,_that.allowGuests,_that.seatCount,_that.occupiedSeats,_that.theme,_that.score,_that.scoreParts,_that.chatEnabled,_that.chatMuted,_that.topic,_that.roomNumber,_that.roomLevel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoom implements LiveRoom {
  const _LiveRoom({required this.id, required this.title, @JsonKey(unknownEnumValue: LiveRoomMode.solo) required this.mode, required this.viewerCount, required this.startedAt, required this.coverUrl, required this.category, required this.host, required this.status, required this.endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) required this.endReason, this.allowGuests = true, this.seatCount, this.occupiedSeats = 0, this.theme = LiveThemes.classic, this.score = 0, this.scoreParts, this.chatEnabled = true, this.chatMuted = false, this.topic, this.roomNumber, this.roomLevel});
  factory _LiveRoom.fromJson(Map<String, dynamic> json) => _$LiveRoomFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey(unknownEnumValue: LiveRoomMode.solo) final  LiveRoomMode mode;
@override final  int viewerCount;
@override final  DateTime startedAt;
@override final  String? coverUrl;
@override final  LiveCategory? category;
@override final  UserSummary host;
@override final  LiveRoomStatus status;
@override final  DateTime? endedAt;
@override@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) final  LiveRoomEndReason? endReason;
/// CP-010: people without an account may watch.
@override@JsonKey() final  bool allowGuests;
/// CP-011 (see [LiveRoomSummary]).
@override final  int? seatCount;
@override@JsonKey() final  int occupiedSeats;
@override@JsonKey() final  String theme;
/// CP-012 (see [LiveRoomSummary]) and its parts.
@override@JsonKey() final  int score;
@override final  LiveScore? scoreParts;
/// CP-013: the host has not turned the chat off.
@override@JsonKey() final  bool chatEnabled;
/// CP-013: the caller is muted in this live's chat.
@override@JsonKey() final  bool chatMuted;
/// CP-014 (see [LiveRoomSummary]).
@override final  String? topic;
/// CP-016 G: the host's public room number ("ID: …"); null when the
/// host no longer has the hosting permission.
@override final  int? roomNumber;
/// CP-016 D (D101): the host's charm level, shown next to the room name;
/// null while the charm levels are unavailable.
@override final  int? roomLevel;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomCopyWith<_LiveRoom> get copyWith => __$LiveRoomCopyWithImpl<_LiveRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.host, host) || other.host == host)&&(identical(other.status, status) || other.status == status)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.endReason, endReason) || other.endReason == endReason)&&(identical(other.allowGuests, allowGuests) || other.allowGuests == allowGuests)&&(identical(other.seatCount, seatCount) || other.seatCount == seatCount)&&(identical(other.occupiedSeats, occupiedSeats) || other.occupiedSeats == occupiedSeats)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.score, score) || other.score == score)&&(identical(other.scoreParts, scoreParts) || other.scoreParts == scoreParts)&&(identical(other.chatEnabled, chatEnabled) || other.chatEnabled == chatEnabled)&&(identical(other.chatMuted, chatMuted) || other.chatMuted == chatMuted)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.roomNumber, roomNumber) || other.roomNumber == roomNumber)&&(identical(other.roomLevel, roomLevel) || other.roomLevel == roomLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,title,mode,viewerCount,startedAt,coverUrl,category,host,status,endedAt,endReason,allowGuests,seatCount,occupiedSeats,theme,score,scoreParts,chatEnabled,chatMuted,topic,roomNumber,roomLevel]);
}

@override
String toString() {
    return 'LiveRoom(id: $id, title: $title, mode: $mode, viewerCount: $viewerCount, startedAt: $startedAt, coverUrl: $coverUrl, category: $category, host: $host, status: $status, endedAt: $endedAt, endReason: $endReason, allowGuests: $allowGuests, seatCount: $seatCount, occupiedSeats: $occupiedSeats, theme: $theme, score: $score, scoreParts: $scoreParts, chatEnabled: $chatEnabled, chatMuted: $chatMuted, topic: $topic, roomNumber: $roomNumber, roomLevel: $roomLevel)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomCopyWith<$Res> implements $LiveRoomCopyWith<$Res> {
  factory _$LiveRoomCopyWith(_LiveRoom value, $Res Function(_LiveRoom) _then) = __$LiveRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, LiveRoomStatus status, DateTime? endedAt,@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? endReason, bool allowGuests, int? seatCount, int occupiedSeats, String theme, int score, LiveScore? scoreParts, bool chatEnabled, bool chatMuted, String? topic, int? roomNumber, int? roomLevel
});


@override $LiveCategoryCopyWith<$Res>? get category;@override $UserSummaryCopyWith<$Res> get host;@override $LiveScoreCopyWith<$Res>? get scoreParts;

}
/// @nodoc
class __$LiveRoomCopyWithImpl<$Res>
    implements _$LiveRoomCopyWith<$Res> {
  __$LiveRoomCopyWithImpl(this._self, this._then);

  final _LiveRoom _self;
  final $Res Function(_LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? status = null,Object? endedAt = freezed,Object? endReason = freezed,Object? allowGuests = null,Object? seatCount = freezed,Object? occupiedSeats = null,Object? theme = null,Object? score = null,Object? scoreParts = freezed,Object? chatEnabled = null,Object? chatMuted = null,Object? topic = freezed,Object? roomNumber = freezed,Object? roomLevel = freezed,}) {
  return _then(_LiveRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LiveCategory?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LiveRoomStatus,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endReason: freezed == endReason ? _self.endReason : endReason // ignore: cast_nullable_to_non_nullable
as LiveRoomEndReason?,allowGuests: null == allowGuests ? _self.allowGuests : allowGuests // ignore: cast_nullable_to_non_nullable
as bool,seatCount: freezed == seatCount ? _self.seatCount : seatCount // ignore: cast_nullable_to_non_nullable
as int?,occupiedSeats: null == occupiedSeats ? _self.occupiedSeats : occupiedSeats // ignore: cast_nullable_to_non_nullable
as int,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,scoreParts: freezed == scoreParts ? _self.scoreParts : scoreParts // ignore: cast_nullable_to_non_nullable
as LiveScore?,chatEnabled: null == chatEnabled ? _self.chatEnabled : chatEnabled // ignore: cast_nullable_to_non_nullable
as bool,chatMuted: null == chatMuted ? _self.chatMuted : chatMuted // ignore: cast_nullable_to_non_nullable
as bool,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,roomNumber: freezed == roomNumber ? _self.roomNumber : roomNumber // ignore: cast_nullable_to_non_nullable
as int?,roomLevel: freezed == roomLevel ? _self.roomLevel : roomLevel // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveCategoryCopyWith<$Res>? get category {
    if (_self.category == null) {
    return null;
  }

  return $LiveCategoryCopyWith<$Res>(_self.category!, (value) {
    return _then(_self.copyWith(category: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveScoreCopyWith<$Res>? get scoreParts {
    if (_self.scoreParts == null) {
    return null;
  }

  return $LiveScoreCopyWith<$Res>(_self.scoreParts!, (value) {
    return _then(_self.copyWith(scoreParts: value));
  });
}
}


/// @nodoc
mixin _$LiveScore {

 int get total; int get tapPoints; int get supportPoints;
/// Create a copy of LiveScore
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveScoreCopyWith<LiveScore> get copyWith => _$LiveScoreCopyWithImpl<LiveScore>(this as LiveScore, _$identity);

  /// Serializes this LiveScore to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveScore;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveScore&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.tapPoints, _this.tapPoints) || other.tapPoints == _this.tapPoints)&&(identical(other.supportPoints, _this.supportPoints) || other.supportPoints == _this.supportPoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveScore;
  return Object.hash(runtimeType,_this.total,_this.tapPoints,_this.supportPoints);
}

@override
String toString() {
  final _this = this as LiveScore;
  return 'LiveScore(total: ${_this.total}, tapPoints: ${_this.tapPoints}, supportPoints: ${_this.supportPoints})';
}


}

/// @nodoc
abstract mixin class $LiveScoreCopyWith<$Res>  {
  factory $LiveScoreCopyWith(LiveScore value, $Res Function(LiveScore) _then) = _$LiveScoreCopyWithImpl;
@useResult
$Res call({
 int total, int tapPoints, int supportPoints
});




}
/// @nodoc
class _$LiveScoreCopyWithImpl<$Res>
    implements $LiveScoreCopyWith<$Res> {
  _$LiveScoreCopyWithImpl(this._self, this._then);

  final LiveScore _self;
  final $Res Function(LiveScore) _then;

/// Create a copy of LiveScore
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? tapPoints = null,Object? supportPoints = null,}) {
  return _then(LiveScore(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,tapPoints: null == tapPoints ? _self.tapPoints : tapPoints // ignore: cast_nullable_to_non_nullable
as int,supportPoints: null == supportPoints ? _self.supportPoints : supportPoints // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveScore].
extension LiveScorePatterns on LiveScore {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveScore value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveScore() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveScore value)  $default,){
final _that = this;
switch (_that) {
case _LiveScore():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveScore value)?  $default,){
final _that = this;
switch (_that) {
case _LiveScore() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int tapPoints,  int supportPoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveScore() when $default != null:
return $default(_that.total,_that.tapPoints,_that.supportPoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int tapPoints,  int supportPoints)  $default,) {final _that = this;
switch (_that) {
case _LiveScore():
return $default(_that.total,_that.tapPoints,_that.supportPoints);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int tapPoints,  int supportPoints)?  $default,) {final _that = this;
switch (_that) {
case _LiveScore() when $default != null:
return $default(_that.total,_that.tapPoints,_that.supportPoints);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveScore implements LiveScore {
  const _LiveScore({required this.total, required this.tapPoints, required this.supportPoints});
  factory _LiveScore.fromJson(Map<String, dynamic> json) => _$LiveScoreFromJson(json);

@override final  int total;
@override final  int tapPoints;
@override final  int supportPoints;

/// Create a copy of LiveScore
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveScoreCopyWith<_LiveScore> get copyWith => __$LiveScoreCopyWithImpl<_LiveScore>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveScoreToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveScore&&(identical(other.total, total) || other.total == total)&&(identical(other.tapPoints, tapPoints) || other.tapPoints == tapPoints)&&(identical(other.supportPoints, supportPoints) || other.supportPoints == supportPoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,total,tapPoints,supportPoints);
}

@override
String toString() {
    return 'LiveScore(total: $total, tapPoints: $tapPoints, supportPoints: $supportPoints)';
}


}

/// @nodoc
abstract mixin class _$LiveScoreCopyWith<$Res> implements $LiveScoreCopyWith<$Res> {
  factory _$LiveScoreCopyWith(_LiveScore value, $Res Function(_LiveScore) _then) = __$LiveScoreCopyWithImpl;
@override @useResult
$Res call({
 int total, int tapPoints, int supportPoints
});




}
/// @nodoc
class __$LiveScoreCopyWithImpl<$Res>
    implements _$LiveScoreCopyWith<$Res> {
  __$LiveScoreCopyWithImpl(this._self, this._then);

  final _LiveScore _self;
  final $Res Function(_LiveScore) _then;

/// Create a copy of LiveScore
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? tapPoints = null,Object? supportPoints = null,}) {
  return _then(_LiveScore(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,tapPoints: null == tapPoints ? _self.tapPoints : tapPoints // ignore: cast_nullable_to_non_nullable
as int,supportPoints: null == supportPoints ? _self.supportPoints : supportPoints // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LiveTapsResult {

 int get accepted; LiveScore get score;
/// Create a copy of LiveTapsResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveTapsResultCopyWith<LiveTapsResult> get copyWith => _$LiveTapsResultCopyWithImpl<LiveTapsResult>(this as LiveTapsResult, _$identity);

  /// Serializes this LiveTapsResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveTapsResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveTapsResult&&(identical(other.accepted, _this.accepted) || other.accepted == _this.accepted)&&(identical(other.score, _this.score) || other.score == _this.score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveTapsResult;
  return Object.hash(runtimeType,_this.accepted,_this.score);
}

@override
String toString() {
  final _this = this as LiveTapsResult;
  return 'LiveTapsResult(accepted: ${_this.accepted}, score: ${_this.score})';
}


}

/// @nodoc
abstract mixin class $LiveTapsResultCopyWith<$Res>  {
  factory $LiveTapsResultCopyWith(LiveTapsResult value, $Res Function(LiveTapsResult) _then) = _$LiveTapsResultCopyWithImpl;
@useResult
$Res call({
 int accepted, LiveScore score
});


$LiveScoreCopyWith<$Res> get score;

}
/// @nodoc
class _$LiveTapsResultCopyWithImpl<$Res>
    implements $LiveTapsResultCopyWith<$Res> {
  _$LiveTapsResultCopyWithImpl(this._self, this._then);

  final LiveTapsResult _self;
  final $Res Function(LiveTapsResult) _then;

/// Create a copy of LiveTapsResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accepted = null,Object? score = null,}) {
  return _then(LiveTapsResult(
accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as LiveScore,
  ));
}
/// Create a copy of LiveTapsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveScoreCopyWith<$Res> get score {
  
  return $LiveScoreCopyWith<$Res>(_self.score, (value) {
    return _then(_self.copyWith(score: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveTapsResult].
extension LiveTapsResultPatterns on LiveTapsResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveTapsResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveTapsResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveTapsResult value)  $default,){
final _that = this;
switch (_that) {
case _LiveTapsResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveTapsResult value)?  $default,){
final _that = this;
switch (_that) {
case _LiveTapsResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int accepted,  LiveScore score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveTapsResult() when $default != null:
return $default(_that.accepted,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int accepted,  LiveScore score)  $default,) {final _that = this;
switch (_that) {
case _LiveTapsResult():
return $default(_that.accepted,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int accepted,  LiveScore score)?  $default,) {final _that = this;
switch (_that) {
case _LiveTapsResult() when $default != null:
return $default(_that.accepted,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveTapsResult implements LiveTapsResult {
  const _LiveTapsResult({required this.accepted, required this.score});
  factory _LiveTapsResult.fromJson(Map<String, dynamic> json) => _$LiveTapsResultFromJson(json);

@override final  int accepted;
@override final  LiveScore score;

/// Create a copy of LiveTapsResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveTapsResultCopyWith<_LiveTapsResult> get copyWith => __$LiveTapsResultCopyWithImpl<_LiveTapsResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveTapsResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveTapsResult&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,accepted,score);
}

@override
String toString() {
    return 'LiveTapsResult(accepted: $accepted, score: $score)';
}


}

/// @nodoc
abstract mixin class _$LiveTapsResultCopyWith<$Res> implements $LiveTapsResultCopyWith<$Res> {
  factory _$LiveTapsResultCopyWith(_LiveTapsResult value, $Res Function(_LiveTapsResult) _then) = __$LiveTapsResultCopyWithImpl;
@override @useResult
$Res call({
 int accepted, LiveScore score
});


@override $LiveScoreCopyWith<$Res> get score;

}
/// @nodoc
class __$LiveTapsResultCopyWithImpl<$Res>
    implements _$LiveTapsResultCopyWith<$Res> {
  __$LiveTapsResultCopyWithImpl(this._self, this._then);

  final _LiveTapsResult _self;
  final $Res Function(_LiveTapsResult) _then;

/// Create a copy of LiveTapsResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accepted = null,Object? score = null,}) {
  return _then(_LiveTapsResult(
accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as LiveScore,
  ));
}

/// Create a copy of LiveTapsResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveScoreCopyWith<$Res> get score {
  
  return $LiveScoreCopyWith<$Res>(_self.score, (value) {
    return _then(_self.copyWith(score: value));
  });
}
}


/// @nodoc
mixin _$LiveContributor {

 UserSummary get user; int get points;
/// Create a copy of LiveContributor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveContributorCopyWith<LiveContributor> get copyWith => _$LiveContributorCopyWithImpl<LiveContributor>(this as LiveContributor, _$identity);

  /// Serializes this LiveContributor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveContributor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveContributor&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.points, _this.points) || other.points == _this.points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveContributor;
  return Object.hash(runtimeType,_this.user,_this.points);
}

@override
String toString() {
  final _this = this as LiveContributor;
  return 'LiveContributor(user: ${_this.user}, points: ${_this.points})';
}


}

/// @nodoc
abstract mixin class $LiveContributorCopyWith<$Res>  {
  factory $LiveContributorCopyWith(LiveContributor value, $Res Function(LiveContributor) _then) = _$LiveContributorCopyWithImpl;
@useResult
$Res call({
 UserSummary user, int points
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$LiveContributorCopyWithImpl<$Res>
    implements $LiveContributorCopyWith<$Res> {
  _$LiveContributorCopyWithImpl(this._self, this._then);

  final LiveContributor _self;
  final $Res Function(LiveContributor) _then;

/// Create a copy of LiveContributor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? points = null,}) {
  return _then(LiveContributor(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of LiveContributor
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveContributor].
extension LiveContributorPatterns on LiveContributor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveContributor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveContributor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveContributor value)  $default,){
final _that = this;
switch (_that) {
case _LiveContributor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveContributor value)?  $default,){
final _that = this;
switch (_that) {
case _LiveContributor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  int points)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveContributor() when $default != null:
return $default(_that.user,_that.points);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  int points)  $default,) {final _that = this;
switch (_that) {
case _LiveContributor():
return $default(_that.user,_that.points);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  int points)?  $default,) {final _that = this;
switch (_that) {
case _LiveContributor() when $default != null:
return $default(_that.user,_that.points);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveContributor implements LiveContributor {
  const _LiveContributor({required this.user, required this.points});
  factory _LiveContributor.fromJson(Map<String, dynamic> json) => _$LiveContributorFromJson(json);

@override final  UserSummary user;
@override final  int points;

/// Create a copy of LiveContributor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveContributorCopyWith<_LiveContributor> get copyWith => __$LiveContributorCopyWithImpl<_LiveContributor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveContributorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveContributor&&(identical(other.user, user) || other.user == user)&&(identical(other.points, points) || other.points == points));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,user,points);
}

@override
String toString() {
    return 'LiveContributor(user: $user, points: $points)';
}


}

/// @nodoc
abstract mixin class _$LiveContributorCopyWith<$Res> implements $LiveContributorCopyWith<$Res> {
  factory _$LiveContributorCopyWith(_LiveContributor value, $Res Function(_LiveContributor) _then) = __$LiveContributorCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, int points
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$LiveContributorCopyWithImpl<$Res>
    implements _$LiveContributorCopyWith<$Res> {
  __$LiveContributorCopyWithImpl(this._self, this._then);

  final _LiveContributor _self;
  final $Res Function(_LiveContributor) _then;

/// Create a copy of LiveContributor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? points = null,}) {
  return _then(_LiveContributor(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of LiveContributor
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
mixin _$LiveRoomPage {

 List<LiveRoomSummary> get data; PageInfo get page;
/// Create a copy of LiveRoomPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveRoomPageCopyWith<LiveRoomPage> get copyWith => _$LiveRoomPageCopyWithImpl<LiveRoomPage>(this as LiveRoomPage, _$identity);

  /// Serializes this LiveRoomPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveRoomPage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoomPage&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.page, _this.page) || other.page == _this.page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoomPage;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.page);
}

@override
String toString() {
  final _this = this as LiveRoomPage;
  return 'LiveRoomPage(data: ${_this.data}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $LiveRoomPageCopyWith<$Res>  {
  factory $LiveRoomPageCopyWith(LiveRoomPage value, $Res Function(LiveRoomPage) _then) = _$LiveRoomPageCopyWithImpl;
@useResult
$Res call({
 List<LiveRoomSummary> data, PageInfo page
});


$PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class _$LiveRoomPageCopyWithImpl<$Res>
    implements $LiveRoomPageCopyWith<$Res> {
  _$LiveRoomPageCopyWithImpl(this._self, this._then);

  final LiveRoomPage _self;
  final $Res Function(LiveRoomPage) _then;

/// Create a copy of LiveRoomPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? page = null,}) {
  return _then(LiveRoomPage(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<LiveRoomSummary>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}
/// Create a copy of LiveRoomPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PageInfoCopyWith<$Res> get page {
  
  return $PageInfoCopyWith<$Res>(_self.page, (value) {
    return _then(_self.copyWith(page: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveRoomPage].
extension LiveRoomPagePatterns on LiveRoomPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveRoomPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveRoomPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveRoomPage value)  $default,){
final _that = this;
switch (_that) {
case _LiveRoomPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveRoomPage value)?  $default,){
final _that = this;
switch (_that) {
case _LiveRoomPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LiveRoomSummary> data,  PageInfo page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoomPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LiveRoomSummary> data,  PageInfo page)  $default,) {final _that = this;
switch (_that) {
case _LiveRoomPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LiveRoomSummary> data,  PageInfo page)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoomPage() when $default != null:
return $default(_that.data,_that.page);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoomPage implements LiveRoomPage {
  const _LiveRoomPage({required  List<LiveRoomSummary> data, required this.page}): _data = data;
  factory _LiveRoomPage.fromJson(Map<String, dynamic> json) => _$LiveRoomPageFromJson(json);

 final  List<LiveRoomSummary> _data;
@override List<LiveRoomSummary> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PageInfo page;

/// Create a copy of LiveRoomPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveRoomPageCopyWith<_LiveRoomPage> get copyWith => __$LiveRoomPageCopyWithImpl<_LiveRoomPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveRoomPageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoomPage&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.page, page) || other.page == page));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),page);
}

@override
String toString() {
    return 'LiveRoomPage(data: $data, page: $page)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomPageCopyWith<$Res> implements $LiveRoomPageCopyWith<$Res> {
  factory _$LiveRoomPageCopyWith(_LiveRoomPage value, $Res Function(_LiveRoomPage) _then) = __$LiveRoomPageCopyWithImpl;
@override @useResult
$Res call({
 List<LiveRoomSummary> data, PageInfo page
});


@override $PageInfoCopyWith<$Res> get page;

}
/// @nodoc
class __$LiveRoomPageCopyWithImpl<$Res>
    implements _$LiveRoomPageCopyWith<$Res> {
  __$LiveRoomPageCopyWithImpl(this._self, this._then);

  final _LiveRoomPage _self;
  final $Res Function(_LiveRoomPage) _then;

/// Create a copy of LiveRoomPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? page = null,}) {
  return _then(_LiveRoomPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<LiveRoomSummary>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageInfo,
  ));
}

/// Create a copy of LiveRoomPage
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
mixin _$LiveMediaAccess {

 String get url; String get token; DateTime get expiresAt;@JsonKey(unknownEnumValue: LiveMediaRole.viewer) LiveMediaRole get role; String get identity; int? get guestNumber;
/// Create a copy of LiveMediaAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveMediaAccessCopyWith<LiveMediaAccess> get copyWith => _$LiveMediaAccessCopyWithImpl<LiveMediaAccess>(this as LiveMediaAccess, _$identity);

  /// Serializes this LiveMediaAccess to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveMediaAccess;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveMediaAccess&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.token, _this.token) || other.token == _this.token)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.identity, _this.identity) || other.identity == _this.identity)&&(identical(other.guestNumber, _this.guestNumber) || other.guestNumber == _this.guestNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveMediaAccess;
  return Object.hash(runtimeType,_this.url,_this.token,_this.expiresAt,_this.role,_this.identity,_this.guestNumber);
}

@override
String toString() {
  final _this = this as LiveMediaAccess;
  return 'LiveMediaAccess(url: ${_this.url}, token: ${_this.token}, expiresAt: ${_this.expiresAt}, role: ${_this.role}, identity: ${_this.identity}, guestNumber: ${_this.guestNumber})';
}


}

/// @nodoc
abstract mixin class $LiveMediaAccessCopyWith<$Res>  {
  factory $LiveMediaAccessCopyWith(LiveMediaAccess value, $Res Function(LiveMediaAccess) _then) = _$LiveMediaAccessCopyWithImpl;
@useResult
$Res call({
 String url, String token, DateTime expiresAt,@JsonKey(unknownEnumValue: LiveMediaRole.viewer) LiveMediaRole role, String identity, int? guestNumber
});




}
/// @nodoc
class _$LiveMediaAccessCopyWithImpl<$Res>
    implements $LiveMediaAccessCopyWith<$Res> {
  _$LiveMediaAccessCopyWithImpl(this._self, this._then);

  final LiveMediaAccess _self;
  final $Res Function(LiveMediaAccess) _then;

/// Create a copy of LiveMediaAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? token = null,Object? expiresAt = null,Object? role = null,Object? identity = null,Object? guestNumber = freezed,}) {
  return _then(LiveMediaAccess(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as LiveMediaRole,identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as String,guestNumber: freezed == guestNumber ? _self.guestNumber : guestNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveMediaAccess].
extension LiveMediaAccessPatterns on LiveMediaAccess {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveMediaAccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveMediaAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveMediaAccess value)  $default,){
final _that = this;
switch (_that) {
case _LiveMediaAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveMediaAccess value)?  $default,){
final _that = this;
switch (_that) {
case _LiveMediaAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String token,  DateTime expiresAt, @JsonKey(unknownEnumValue: LiveMediaRole.viewer)  LiveMediaRole role,  String identity,  int? guestNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveMediaAccess() when $default != null:
return $default(_that.url,_that.token,_that.expiresAt,_that.role,_that.identity,_that.guestNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String token,  DateTime expiresAt, @JsonKey(unknownEnumValue: LiveMediaRole.viewer)  LiveMediaRole role,  String identity,  int? guestNumber)  $default,) {final _that = this;
switch (_that) {
case _LiveMediaAccess():
return $default(_that.url,_that.token,_that.expiresAt,_that.role,_that.identity,_that.guestNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String token,  DateTime expiresAt, @JsonKey(unknownEnumValue: LiveMediaRole.viewer)  LiveMediaRole role,  String identity,  int? guestNumber)?  $default,) {final _that = this;
switch (_that) {
case _LiveMediaAccess() when $default != null:
return $default(_that.url,_that.token,_that.expiresAt,_that.role,_that.identity,_that.guestNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveMediaAccess implements LiveMediaAccess {
  const _LiveMediaAccess({required this.url, required this.token, required this.expiresAt, @JsonKey(unknownEnumValue: LiveMediaRole.viewer) required this.role, required this.identity, this.guestNumber});
  factory _LiveMediaAccess.fromJson(Map<String, dynamic> json) => _$LiveMediaAccessFromJson(json);

@override final  String url;
@override final  String token;
@override final  DateTime expiresAt;
@override@JsonKey(unknownEnumValue: LiveMediaRole.viewer) final  LiveMediaRole role;
@override final  String identity;
@override final  int? guestNumber;

/// Create a copy of LiveMediaAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveMediaAccessCopyWith<_LiveMediaAccess> get copyWith => __$LiveMediaAccessCopyWithImpl<_LiveMediaAccess>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveMediaAccessToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveMediaAccess&&(identical(other.url, url) || other.url == url)&&(identical(other.token, token) || other.token == token)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.role, role) || other.role == role)&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.guestNumber, guestNumber) || other.guestNumber == guestNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,token,expiresAt,role,identity,guestNumber);
}

@override
String toString() {
    return 'LiveMediaAccess(url: $url, token: $token, expiresAt: $expiresAt, role: $role, identity: $identity, guestNumber: $guestNumber)';
}


}

/// @nodoc
abstract mixin class _$LiveMediaAccessCopyWith<$Res> implements $LiveMediaAccessCopyWith<$Res> {
  factory _$LiveMediaAccessCopyWith(_LiveMediaAccess value, $Res Function(_LiveMediaAccess) _then) = __$LiveMediaAccessCopyWithImpl;
@override @useResult
$Res call({
 String url, String token, DateTime expiresAt,@JsonKey(unknownEnumValue: LiveMediaRole.viewer) LiveMediaRole role, String identity, int? guestNumber
});




}
/// @nodoc
class __$LiveMediaAccessCopyWithImpl<$Res>
    implements _$LiveMediaAccessCopyWith<$Res> {
  __$LiveMediaAccessCopyWithImpl(this._self, this._then);

  final _LiveMediaAccess _self;
  final $Res Function(_LiveMediaAccess) _then;

/// Create a copy of LiveMediaAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? token = null,Object? expiresAt = null,Object? role = null,Object? identity = null,Object? guestNumber = freezed,}) {
  return _then(_LiveMediaAccess(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as LiveMediaRole,identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as String,guestNumber: freezed == guestNumber ? _self.guestNumber : guestNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LiveViewer {

@JsonKey(unknownEnumValue: LiveViewerKind.user) LiveViewerKind get kind; UserSummary? get user; int? get guestNumber; DateTime get joinedAt;
/// Create a copy of LiveViewer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveViewerCopyWith<LiveViewer> get copyWith => _$LiveViewerCopyWithImpl<LiveViewer>(this as LiveViewer, _$identity);

  /// Serializes this LiveViewer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveViewer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveViewer&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.guestNumber, _this.guestNumber) || other.guestNumber == _this.guestNumber)&&(identical(other.joinedAt, _this.joinedAt) || other.joinedAt == _this.joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveViewer;
  return Object.hash(runtimeType,_this.kind,_this.user,_this.guestNumber,_this.joinedAt);
}

@override
String toString() {
  final _this = this as LiveViewer;
  return 'LiveViewer(kind: ${_this.kind}, user: ${_this.user}, guestNumber: ${_this.guestNumber}, joinedAt: ${_this.joinedAt})';
}


}

/// @nodoc
abstract mixin class $LiveViewerCopyWith<$Res>  {
  factory $LiveViewerCopyWith(LiveViewer value, $Res Function(LiveViewer) _then) = _$LiveViewerCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: LiveViewerKind.user) LiveViewerKind kind, UserSummary? user, int? guestNumber, DateTime joinedAt
});


$UserSummaryCopyWith<$Res>? get user;

}
/// @nodoc
class _$LiveViewerCopyWithImpl<$Res>
    implements $LiveViewerCopyWith<$Res> {
  _$LiveViewerCopyWithImpl(this._self, this._then);

  final LiveViewer _self;
  final $Res Function(LiveViewer) _then;

/// Create a copy of LiveViewer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? user = freezed,Object? guestNumber = freezed,Object? joinedAt = null,}) {
  return _then(LiveViewer(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveViewerKind,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary?,guestNumber: freezed == guestNumber ? _self.guestNumber : guestNumber // ignore: cast_nullable_to_non_nullable
as int?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveViewer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveViewer].
extension LiveViewerPatterns on LiveViewer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveViewer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveViewer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveViewer value)  $default,){
final _that = this;
switch (_that) {
case _LiveViewer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveViewer value)?  $default,){
final _that = this;
switch (_that) {
case _LiveViewer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: LiveViewerKind.user)  LiveViewerKind kind,  UserSummary? user,  int? guestNumber,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveViewer() when $default != null:
return $default(_that.kind,_that.user,_that.guestNumber,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: LiveViewerKind.user)  LiveViewerKind kind,  UserSummary? user,  int? guestNumber,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _LiveViewer():
return $default(_that.kind,_that.user,_that.guestNumber,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: LiveViewerKind.user)  LiveViewerKind kind,  UserSummary? user,  int? guestNumber,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveViewer() when $default != null:
return $default(_that.kind,_that.user,_that.guestNumber,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveViewer implements LiveViewer {
  const _LiveViewer({@JsonKey(unknownEnumValue: LiveViewerKind.user) required this.kind, required this.user, required this.guestNumber, required this.joinedAt});
  factory _LiveViewer.fromJson(Map<String, dynamic> json) => _$LiveViewerFromJson(json);

@override@JsonKey(unknownEnumValue: LiveViewerKind.user) final  LiveViewerKind kind;
@override final  UserSummary? user;
@override final  int? guestNumber;
@override final  DateTime joinedAt;

/// Create a copy of LiveViewer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveViewerCopyWith<_LiveViewer> get copyWith => __$LiveViewerCopyWithImpl<_LiveViewer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveViewerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveViewer&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.user, user) || other.user == user)&&(identical(other.guestNumber, guestNumber) || other.guestNumber == guestNumber)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,user,guestNumber,joinedAt);
}

@override
String toString() {
    return 'LiveViewer(kind: $kind, user: $user, guestNumber: $guestNumber, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$LiveViewerCopyWith<$Res> implements $LiveViewerCopyWith<$Res> {
  factory _$LiveViewerCopyWith(_LiveViewer value, $Res Function(_LiveViewer) _then) = __$LiveViewerCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: LiveViewerKind.user) LiveViewerKind kind, UserSummary? user, int? guestNumber, DateTime joinedAt
});


@override $UserSummaryCopyWith<$Res>? get user;

}
/// @nodoc
class __$LiveViewerCopyWithImpl<$Res>
    implements _$LiveViewerCopyWith<$Res> {
  __$LiveViewerCopyWithImpl(this._self, this._then);

  final _LiveViewer _self;
  final $Res Function(_LiveViewer) _then;

/// Create a copy of LiveViewer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? user = freezed,Object? guestNumber = freezed,Object? joinedAt = null,}) {
  return _then(_LiveViewer(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveViewerKind,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary?,guestNumber: freezed == guestNumber ? _self.guestNumber : guestNumber // ignore: cast_nullable_to_non_nullable
as int?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveViewer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$LiveSeat {

 int get index;@JsonKey(unknownEnumValue: LiveSeatState.empty) LiveSeatState get state; UserSummary? get user; bool get mutedByHost;
/// Create a copy of LiveSeat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSeatCopyWith<LiveSeat> get copyWith => _$LiveSeatCopyWithImpl<LiveSeat>(this as LiveSeat, _$identity);

  /// Serializes this LiveSeat to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSeat;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSeat&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.mutedByHost, _this.mutedByHost) || other.mutedByHost == _this.mutedByHost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSeat;
  return Object.hash(runtimeType,_this.index,_this.state,_this.user,_this.mutedByHost);
}

@override
String toString() {
  final _this = this as LiveSeat;
  return 'LiveSeat(index: ${_this.index}, state: ${_this.state}, user: ${_this.user}, mutedByHost: ${_this.mutedByHost})';
}


}

/// @nodoc
abstract mixin class $LiveSeatCopyWith<$Res>  {
  factory $LiveSeatCopyWith(LiveSeat value, $Res Function(LiveSeat) _then) = _$LiveSeatCopyWithImpl;
@useResult
$Res call({
 int index,@JsonKey(unknownEnumValue: LiveSeatState.empty) LiveSeatState state, UserSummary? user, bool mutedByHost
});


$UserSummaryCopyWith<$Res>? get user;

}
/// @nodoc
class _$LiveSeatCopyWithImpl<$Res>
    implements $LiveSeatCopyWith<$Res> {
  _$LiveSeatCopyWithImpl(this._self, this._then);

  final LiveSeat _self;
  final $Res Function(LiveSeat) _then;

/// Create a copy of LiveSeat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? state = null,Object? user = freezed,Object? mutedByHost = null,}) {
  return _then(LiveSeat(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveSeatState,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary?,mutedByHost: null == mutedByHost ? _self.mutedByHost : mutedByHost // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LiveSeat
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveSeat].
extension LiveSeatPatterns on LiveSeat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSeat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSeat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSeat value)  $default,){
final _that = this;
switch (_that) {
case _LiveSeat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSeat value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSeat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index, @JsonKey(unknownEnumValue: LiveSeatState.empty)  LiveSeatState state,  UserSummary? user,  bool mutedByHost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSeat() when $default != null:
return $default(_that.index,_that.state,_that.user,_that.mutedByHost);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index, @JsonKey(unknownEnumValue: LiveSeatState.empty)  LiveSeatState state,  UserSummary? user,  bool mutedByHost)  $default,) {final _that = this;
switch (_that) {
case _LiveSeat():
return $default(_that.index,_that.state,_that.user,_that.mutedByHost);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index, @JsonKey(unknownEnumValue: LiveSeatState.empty)  LiveSeatState state,  UserSummary? user,  bool mutedByHost)?  $default,) {final _that = this;
switch (_that) {
case _LiveSeat() when $default != null:
return $default(_that.index,_that.state,_that.user,_that.mutedByHost);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSeat implements LiveSeat {
  const _LiveSeat({required this.index, @JsonKey(unknownEnumValue: LiveSeatState.empty) required this.state, required this.user, this.mutedByHost = false});
  factory _LiveSeat.fromJson(Map<String, dynamic> json) => _$LiveSeatFromJson(json);

@override final  int index;
@override@JsonKey(unknownEnumValue: LiveSeatState.empty) final  LiveSeatState state;
@override final  UserSummary? user;
@override@JsonKey() final  bool mutedByHost;

/// Create a copy of LiveSeat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSeatCopyWith<_LiveSeat> get copyWith => __$LiveSeatCopyWithImpl<_LiveSeat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSeatToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSeat&&(identical(other.index, index) || other.index == index)&&(identical(other.state, state) || other.state == state)&&(identical(other.user, user) || other.user == user)&&(identical(other.mutedByHost, mutedByHost) || other.mutedByHost == mutedByHost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,index,state,user,mutedByHost);
}

@override
String toString() {
    return 'LiveSeat(index: $index, state: $state, user: $user, mutedByHost: $mutedByHost)';
}


}

/// @nodoc
abstract mixin class _$LiveSeatCopyWith<$Res> implements $LiveSeatCopyWith<$Res> {
  factory _$LiveSeatCopyWith(_LiveSeat value, $Res Function(_LiveSeat) _then) = __$LiveSeatCopyWithImpl;
@override @useResult
$Res call({
 int index,@JsonKey(unknownEnumValue: LiveSeatState.empty) LiveSeatState state, UserSummary? user, bool mutedByHost
});


@override $UserSummaryCopyWith<$Res>? get user;

}
/// @nodoc
class __$LiveSeatCopyWithImpl<$Res>
    implements _$LiveSeatCopyWith<$Res> {
  __$LiveSeatCopyWithImpl(this._self, this._then);

  final _LiveSeat _self;
  final $Res Function(_LiveSeat) _then;

/// Create a copy of LiveSeat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? state = null,Object? user = freezed,Object? mutedByHost = null,}) {
  return _then(_LiveSeat(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as LiveSeatState,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary?,mutedByHost: null == mutedByHost ? _self.mutedByHost : mutedByHost // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LiveSeat
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$LiveSeatRequest {

 String get id; UserSummary get user; int? get seatIndex; DateTime get createdAt;
/// Create a copy of LiveSeatRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSeatRequestCopyWith<LiveSeatRequest> get copyWith => _$LiveSeatRequestCopyWithImpl<LiveSeatRequest>(this as LiveSeatRequest, _$identity);

  /// Serializes this LiveSeatRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSeatRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSeatRequest&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.seatIndex, _this.seatIndex) || other.seatIndex == _this.seatIndex)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSeatRequest;
  return Object.hash(runtimeType,_this.id,_this.user,_this.seatIndex,_this.createdAt);
}

@override
String toString() {
  final _this = this as LiveSeatRequest;
  return 'LiveSeatRequest(id: ${_this.id}, user: ${_this.user}, seatIndex: ${_this.seatIndex}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LiveSeatRequestCopyWith<$Res>  {
  factory $LiveSeatRequestCopyWith(LiveSeatRequest value, $Res Function(LiveSeatRequest) _then) = _$LiveSeatRequestCopyWithImpl;
@useResult
$Res call({
 String id, UserSummary user, int? seatIndex, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$LiveSeatRequestCopyWithImpl<$Res>
    implements $LiveSeatRequestCopyWith<$Res> {
  _$LiveSeatRequestCopyWithImpl(this._self, this._then);

  final LiveSeatRequest _self;
  final $Res Function(LiveSeatRequest) _then;

/// Create a copy of LiveSeatRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? user = null,Object? seatIndex = freezed,Object? createdAt = null,}) {
  return _then(LiveSeatRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,seatIndex: freezed == seatIndex ? _self.seatIndex : seatIndex // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveSeatRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveSeatRequest].
extension LiveSeatRequestPatterns on LiveSeatRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSeatRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSeatRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSeatRequest value)  $default,){
final _that = this;
switch (_that) {
case _LiveSeatRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSeatRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSeatRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  UserSummary user,  int? seatIndex,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSeatRequest() when $default != null:
return $default(_that.id,_that.user,_that.seatIndex,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  UserSummary user,  int? seatIndex,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LiveSeatRequest():
return $default(_that.id,_that.user,_that.seatIndex,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  UserSummary user,  int? seatIndex,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveSeatRequest() when $default != null:
return $default(_that.id,_that.user,_that.seatIndex,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSeatRequest implements LiveSeatRequest {
  const _LiveSeatRequest({required this.id, required this.user, required this.seatIndex, required this.createdAt});
  factory _LiveSeatRequest.fromJson(Map<String, dynamic> json) => _$LiveSeatRequestFromJson(json);

@override final  String id;
@override final  UserSummary user;
@override final  int? seatIndex;
@override final  DateTime createdAt;

/// Create a copy of LiveSeatRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSeatRequestCopyWith<_LiveSeatRequest> get copyWith => __$LiveSeatRequestCopyWithImpl<_LiveSeatRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSeatRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSeatRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.seatIndex, seatIndex) || other.seatIndex == seatIndex)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,user,seatIndex,createdAt);
}

@override
String toString() {
    return 'LiveSeatRequest(id: $id, user: $user, seatIndex: $seatIndex, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LiveSeatRequestCopyWith<$Res> implements $LiveSeatRequestCopyWith<$Res> {
  factory _$LiveSeatRequestCopyWith(_LiveSeatRequest value, $Res Function(_LiveSeatRequest) _then) = __$LiveSeatRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, UserSummary user, int? seatIndex, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$LiveSeatRequestCopyWithImpl<$Res>
    implements _$LiveSeatRequestCopyWith<$Res> {
  __$LiveSeatRequestCopyWithImpl(this._self, this._then);

  final _LiveSeatRequest _self;
  final $Res Function(_LiveSeatRequest) _then;

/// Create a copy of LiveSeatRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? user = null,Object? seatIndex = freezed,Object? createdAt = null,}) {
  return _then(_LiveSeatRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,seatIndex: freezed == seatIndex ? _self.seatIndex : seatIndex // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveSeatRequest
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
mixin _$LiveSeatInvite {

 String get id; UserSummary get user; int? get seatIndex; UserSummary get invitedBy; DateTime get expiresAt;
/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSeatInviteCopyWith<LiveSeatInvite> get copyWith => _$LiveSeatInviteCopyWithImpl<LiveSeatInvite>(this as LiveSeatInvite, _$identity);

  /// Serializes this LiveSeatInvite to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSeatInvite;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSeatInvite&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.seatIndex, _this.seatIndex) || other.seatIndex == _this.seatIndex)&&(identical(other.invitedBy, _this.invitedBy) || other.invitedBy == _this.invitedBy)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSeatInvite;
  return Object.hash(runtimeType,_this.id,_this.user,_this.seatIndex,_this.invitedBy,_this.expiresAt);
}

@override
String toString() {
  final _this = this as LiveSeatInvite;
  return 'LiveSeatInvite(id: ${_this.id}, user: ${_this.user}, seatIndex: ${_this.seatIndex}, invitedBy: ${_this.invitedBy}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $LiveSeatInviteCopyWith<$Res>  {
  factory $LiveSeatInviteCopyWith(LiveSeatInvite value, $Res Function(LiveSeatInvite) _then) = _$LiveSeatInviteCopyWithImpl;
@useResult
$Res call({
 String id, UserSummary user, int? seatIndex, UserSummary invitedBy, DateTime expiresAt
});


$UserSummaryCopyWith<$Res> get user;$UserSummaryCopyWith<$Res> get invitedBy;

}
/// @nodoc
class _$LiveSeatInviteCopyWithImpl<$Res>
    implements $LiveSeatInviteCopyWith<$Res> {
  _$LiveSeatInviteCopyWithImpl(this._self, this._then);

  final LiveSeatInvite _self;
  final $Res Function(LiveSeatInvite) _then;

/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? user = null,Object? seatIndex = freezed,Object? invitedBy = null,Object? expiresAt = null,}) {
  return _then(LiveSeatInvite(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,seatIndex: freezed == seatIndex ? _self.seatIndex : seatIndex // ignore: cast_nullable_to_non_nullable
as int?,invitedBy: null == invitedBy ? _self.invitedBy : invitedBy // ignore: cast_nullable_to_non_nullable
as UserSummary,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get invitedBy {
  
  return $UserSummaryCopyWith<$Res>(_self.invitedBy, (value) {
    return _then(_self.copyWith(invitedBy: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveSeatInvite].
extension LiveSeatInvitePatterns on LiveSeatInvite {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSeatInvite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSeatInvite() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSeatInvite value)  $default,){
final _that = this;
switch (_that) {
case _LiveSeatInvite():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSeatInvite value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSeatInvite() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  UserSummary user,  int? seatIndex,  UserSummary invitedBy,  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSeatInvite() when $default != null:
return $default(_that.id,_that.user,_that.seatIndex,_that.invitedBy,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  UserSummary user,  int? seatIndex,  UserSummary invitedBy,  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _LiveSeatInvite():
return $default(_that.id,_that.user,_that.seatIndex,_that.invitedBy,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  UserSummary user,  int? seatIndex,  UserSummary invitedBy,  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveSeatInvite() when $default != null:
return $default(_that.id,_that.user,_that.seatIndex,_that.invitedBy,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSeatInvite implements LiveSeatInvite {
  const _LiveSeatInvite({required this.id, required this.user, required this.seatIndex, required this.invitedBy, required this.expiresAt});
  factory _LiveSeatInvite.fromJson(Map<String, dynamic> json) => _$LiveSeatInviteFromJson(json);

@override final  String id;
@override final  UserSummary user;
@override final  int? seatIndex;
@override final  UserSummary invitedBy;
@override final  DateTime expiresAt;

/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSeatInviteCopyWith<_LiveSeatInvite> get copyWith => __$LiveSeatInviteCopyWithImpl<_LiveSeatInvite>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSeatInviteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSeatInvite&&(identical(other.id, id) || other.id == id)&&(identical(other.user, user) || other.user == user)&&(identical(other.seatIndex, seatIndex) || other.seatIndex == seatIndex)&&(identical(other.invitedBy, invitedBy) || other.invitedBy == invitedBy)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,user,seatIndex,invitedBy,expiresAt);
}

@override
String toString() {
    return 'LiveSeatInvite(id: $id, user: $user, seatIndex: $seatIndex, invitedBy: $invitedBy, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$LiveSeatInviteCopyWith<$Res> implements $LiveSeatInviteCopyWith<$Res> {
  factory _$LiveSeatInviteCopyWith(_LiveSeatInvite value, $Res Function(_LiveSeatInvite) _then) = __$LiveSeatInviteCopyWithImpl;
@override @useResult
$Res call({
 String id, UserSummary user, int? seatIndex, UserSummary invitedBy, DateTime expiresAt
});


@override $UserSummaryCopyWith<$Res> get user;@override $UserSummaryCopyWith<$Res> get invitedBy;

}
/// @nodoc
class __$LiveSeatInviteCopyWithImpl<$Res>
    implements _$LiveSeatInviteCopyWith<$Res> {
  __$LiveSeatInviteCopyWithImpl(this._self, this._then);

  final _LiveSeatInvite _self;
  final $Res Function(_LiveSeatInvite) _then;

/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? user = null,Object? seatIndex = freezed,Object? invitedBy = null,Object? expiresAt = null,}) {
  return _then(_LiveSeatInvite(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,seatIndex: freezed == seatIndex ? _self.seatIndex : seatIndex // ignore: cast_nullable_to_non_nullable
as int?,invitedBy: null == invitedBy ? _self.invitedBy : invitedBy // ignore: cast_nullable_to_non_nullable
as UserSummary,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of LiveSeatInvite
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get invitedBy {
  
  return $UserSummaryCopyWith<$Res>(_self.invitedBy, (value) {
    return _then(_self.copyWith(invitedBy: value));
  });
}
}


/// @nodoc
mixin _$LiveSeatsMine {

@JsonKey(unknownEnumValue: LiveSeatRole.viewer) LiveSeatRole get role; int? get seatIndex; LiveSeatRequest? get request; LiveSeatInvite? get invite;
/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSeatsMineCopyWith<LiveSeatsMine> get copyWith => _$LiveSeatsMineCopyWithImpl<LiveSeatsMine>(this as LiveSeatsMine, _$identity);

  /// Serializes this LiveSeatsMine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSeatsMine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSeatsMine&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.seatIndex, _this.seatIndex) || other.seatIndex == _this.seatIndex)&&(identical(other.request, _this.request) || other.request == _this.request)&&(identical(other.invite, _this.invite) || other.invite == _this.invite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSeatsMine;
  return Object.hash(runtimeType,_this.role,_this.seatIndex,_this.request,_this.invite);
}

@override
String toString() {
  final _this = this as LiveSeatsMine;
  return 'LiveSeatsMine(role: ${_this.role}, seatIndex: ${_this.seatIndex}, request: ${_this.request}, invite: ${_this.invite})';
}


}

/// @nodoc
abstract mixin class $LiveSeatsMineCopyWith<$Res>  {
  factory $LiveSeatsMineCopyWith(LiveSeatsMine value, $Res Function(LiveSeatsMine) _then) = _$LiveSeatsMineCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: LiveSeatRole.viewer) LiveSeatRole role, int? seatIndex, LiveSeatRequest? request, LiveSeatInvite? invite
});


$LiveSeatRequestCopyWith<$Res>? get request;$LiveSeatInviteCopyWith<$Res>? get invite;

}
/// @nodoc
class _$LiveSeatsMineCopyWithImpl<$Res>
    implements $LiveSeatsMineCopyWith<$Res> {
  _$LiveSeatsMineCopyWithImpl(this._self, this._then);

  final LiveSeatsMine _self;
  final $Res Function(LiveSeatsMine) _then;

/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? seatIndex = freezed,Object? request = freezed,Object? invite = freezed,}) {
  return _then(LiveSeatsMine(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as LiveSeatRole,seatIndex: freezed == seatIndex ? _self.seatIndex : seatIndex // ignore: cast_nullable_to_non_nullable
as int?,request: freezed == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as LiveSeatRequest?,invite: freezed == invite ? _self.invite : invite // ignore: cast_nullable_to_non_nullable
as LiveSeatInvite?,
  ));
}
/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatRequestCopyWith<$Res>? get request {
    if (_self.request == null) {
    return null;
  }

  return $LiveSeatRequestCopyWith<$Res>(_self.request!, (value) {
    return _then(_self.copyWith(request: value));
  });
}/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatInviteCopyWith<$Res>? get invite {
    if (_self.invite == null) {
    return null;
  }

  return $LiveSeatInviteCopyWith<$Res>(_self.invite!, (value) {
    return _then(_self.copyWith(invite: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveSeatsMine].
extension LiveSeatsMinePatterns on LiveSeatsMine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSeatsMine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSeatsMine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSeatsMine value)  $default,){
final _that = this;
switch (_that) {
case _LiveSeatsMine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSeatsMine value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSeatsMine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: LiveSeatRole.viewer)  LiveSeatRole role,  int? seatIndex,  LiveSeatRequest? request,  LiveSeatInvite? invite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSeatsMine() when $default != null:
return $default(_that.role,_that.seatIndex,_that.request,_that.invite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: LiveSeatRole.viewer)  LiveSeatRole role,  int? seatIndex,  LiveSeatRequest? request,  LiveSeatInvite? invite)  $default,) {final _that = this;
switch (_that) {
case _LiveSeatsMine():
return $default(_that.role,_that.seatIndex,_that.request,_that.invite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: LiveSeatRole.viewer)  LiveSeatRole role,  int? seatIndex,  LiveSeatRequest? request,  LiveSeatInvite? invite)?  $default,) {final _that = this;
switch (_that) {
case _LiveSeatsMine() when $default != null:
return $default(_that.role,_that.seatIndex,_that.request,_that.invite);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSeatsMine implements LiveSeatsMine {
  const _LiveSeatsMine({@JsonKey(unknownEnumValue: LiveSeatRole.viewer) required this.role, required this.seatIndex, required this.request, required this.invite});
  factory _LiveSeatsMine.fromJson(Map<String, dynamic> json) => _$LiveSeatsMineFromJson(json);

@override@JsonKey(unknownEnumValue: LiveSeatRole.viewer) final  LiveSeatRole role;
@override final  int? seatIndex;
@override final  LiveSeatRequest? request;
@override final  LiveSeatInvite? invite;

/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSeatsMineCopyWith<_LiveSeatsMine> get copyWith => __$LiveSeatsMineCopyWithImpl<_LiveSeatsMine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSeatsMineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSeatsMine&&(identical(other.role, role) || other.role == role)&&(identical(other.seatIndex, seatIndex) || other.seatIndex == seatIndex)&&(identical(other.request, request) || other.request == request)&&(identical(other.invite, invite) || other.invite == invite));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,role,seatIndex,request,invite);
}

@override
String toString() {
    return 'LiveSeatsMine(role: $role, seatIndex: $seatIndex, request: $request, invite: $invite)';
}


}

/// @nodoc
abstract mixin class _$LiveSeatsMineCopyWith<$Res> implements $LiveSeatsMineCopyWith<$Res> {
  factory _$LiveSeatsMineCopyWith(_LiveSeatsMine value, $Res Function(_LiveSeatsMine) _then) = __$LiveSeatsMineCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: LiveSeatRole.viewer) LiveSeatRole role, int? seatIndex, LiveSeatRequest? request, LiveSeatInvite? invite
});


@override $LiveSeatRequestCopyWith<$Res>? get request;@override $LiveSeatInviteCopyWith<$Res>? get invite;

}
/// @nodoc
class __$LiveSeatsMineCopyWithImpl<$Res>
    implements _$LiveSeatsMineCopyWith<$Res> {
  __$LiveSeatsMineCopyWithImpl(this._self, this._then);

  final _LiveSeatsMine _self;
  final $Res Function(_LiveSeatsMine) _then;

/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? seatIndex = freezed,Object? request = freezed,Object? invite = freezed,}) {
  return _then(_LiveSeatsMine(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as LiveSeatRole,seatIndex: freezed == seatIndex ? _self.seatIndex : seatIndex // ignore: cast_nullable_to_non_nullable
as int?,request: freezed == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as LiveSeatRequest?,invite: freezed == invite ? _self.invite : invite // ignore: cast_nullable_to_non_nullable
as LiveSeatInvite?,
  ));
}

/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatRequestCopyWith<$Res>? get request {
    if (_self.request == null) {
    return null;
  }

  return $LiveSeatRequestCopyWith<$Res>(_self.request!, (value) {
    return _then(_self.copyWith(request: value));
  });
}/// Create a copy of LiveSeatsMine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatInviteCopyWith<$Res>? get invite {
    if (_self.invite == null) {
    return null;
  }

  return $LiveSeatInviteCopyWith<$Res>(_self.invite!, (value) {
    return _then(_self.copyWith(invite: value));
  });
}
}


/// @nodoc
mixin _$LiveSeats {

 String get roomId;@JsonKey(unknownEnumValue: LiveRoomMode.multi) LiveRoomMode get mode; int get version; int get seatCount; List<LiveSeat> get seats; List<UserSummary> get moderators;/// Host and moderators only.
 int? get pendingRequests;/// Signed-in callers only.
 LiveSeatsMine? get mine;
/// Create a copy of LiveSeats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveSeatsCopyWith<LiveSeats> get copyWith => _$LiveSeatsCopyWithImpl<LiveSeats>(this as LiveSeats, _$identity);

  /// Serializes this LiveSeats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveSeats;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveSeats&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.seatCount, _this.seatCount) || other.seatCount == _this.seatCount)&&const DeepCollectionEquality().equals(other.seats, _this.seats)&&const DeepCollectionEquality().equals(other.moderators, _this.moderators)&&(identical(other.pendingRequests, _this.pendingRequests) || other.pendingRequests == _this.pendingRequests)&&(identical(other.mine, _this.mine) || other.mine == _this.mine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveSeats;
  return Object.hash(runtimeType,_this.roomId,_this.mode,_this.version,_this.seatCount,const DeepCollectionEquality().hash(_this.seats),const DeepCollectionEquality().hash(_this.moderators),_this.pendingRequests,_this.mine);
}

@override
String toString() {
  final _this = this as LiveSeats;
  return 'LiveSeats(roomId: ${_this.roomId}, mode: ${_this.mode}, version: ${_this.version}, seatCount: ${_this.seatCount}, seats: ${_this.seats}, moderators: ${_this.moderators}, pendingRequests: ${_this.pendingRequests}, mine: ${_this.mine})';
}


}

/// @nodoc
abstract mixin class $LiveSeatsCopyWith<$Res>  {
  factory $LiveSeatsCopyWith(LiveSeats value, $Res Function(LiveSeats) _then) = _$LiveSeatsCopyWithImpl;
@useResult
$Res call({
 String roomId,@JsonKey(unknownEnumValue: LiveRoomMode.multi) LiveRoomMode mode, int version, int seatCount, List<LiveSeat> seats, List<UserSummary> moderators, int? pendingRequests, LiveSeatsMine? mine
});


$LiveSeatsMineCopyWith<$Res>? get mine;

}
/// @nodoc
class _$LiveSeatsCopyWithImpl<$Res>
    implements $LiveSeatsCopyWith<$Res> {
  _$LiveSeatsCopyWithImpl(this._self, this._then);

  final LiveSeats _self;
  final $Res Function(LiveSeats) _then;

/// Create a copy of LiveSeats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roomId = null,Object? mode = null,Object? version = null,Object? seatCount = null,Object? seats = null,Object? moderators = null,Object? pendingRequests = freezed,Object? mine = freezed,}) {
  return _then(LiveSeats(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,seatCount: null == seatCount ? _self.seatCount : seatCount // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self.seats : seats // ignore: cast_nullable_to_non_nullable
as List<LiveSeat>,moderators: null == moderators ? _self.moderators : moderators // ignore: cast_nullable_to_non_nullable
as List<UserSummary>,pendingRequests: freezed == pendingRequests ? _self.pendingRequests : pendingRequests // ignore: cast_nullable_to_non_nullable
as int?,mine: freezed == mine ? _self.mine : mine // ignore: cast_nullable_to_non_nullable
as LiveSeatsMine?,
  ));
}
/// Create a copy of LiveSeats
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatsMineCopyWith<$Res>? get mine {
    if (_self.mine == null) {
    return null;
  }

  return $LiveSeatsMineCopyWith<$Res>(_self.mine!, (value) {
    return _then(_self.copyWith(mine: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveSeats].
extension LiveSeatsPatterns on LiveSeats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveSeats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveSeats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveSeats value)  $default,){
final _that = this;
switch (_that) {
case _LiveSeats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveSeats value)?  $default,){
final _that = this;
switch (_that) {
case _LiveSeats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roomId, @JsonKey(unknownEnumValue: LiveRoomMode.multi)  LiveRoomMode mode,  int version,  int seatCount,  List<LiveSeat> seats,  List<UserSummary> moderators,  int? pendingRequests,  LiveSeatsMine? mine)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveSeats() when $default != null:
return $default(_that.roomId,_that.mode,_that.version,_that.seatCount,_that.seats,_that.moderators,_that.pendingRequests,_that.mine);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roomId, @JsonKey(unknownEnumValue: LiveRoomMode.multi)  LiveRoomMode mode,  int version,  int seatCount,  List<LiveSeat> seats,  List<UserSummary> moderators,  int? pendingRequests,  LiveSeatsMine? mine)  $default,) {final _that = this;
switch (_that) {
case _LiveSeats():
return $default(_that.roomId,_that.mode,_that.version,_that.seatCount,_that.seats,_that.moderators,_that.pendingRequests,_that.mine);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roomId, @JsonKey(unknownEnumValue: LiveRoomMode.multi)  LiveRoomMode mode,  int version,  int seatCount,  List<LiveSeat> seats,  List<UserSummary> moderators,  int? pendingRequests,  LiveSeatsMine? mine)?  $default,) {final _that = this;
switch (_that) {
case _LiveSeats() when $default != null:
return $default(_that.roomId,_that.mode,_that.version,_that.seatCount,_that.seats,_that.moderators,_that.pendingRequests,_that.mine);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveSeats implements LiveSeats {
  const _LiveSeats({required this.roomId, @JsonKey(unknownEnumValue: LiveRoomMode.multi) required this.mode, required this.version, required this.seatCount, required  List<LiveSeat> seats, required  List<UserSummary> moderators, this.pendingRequests, this.mine}): _seats = seats,_moderators = moderators;
  factory _LiveSeats.fromJson(Map<String, dynamic> json) => _$LiveSeatsFromJson(json);

@override final  String roomId;
@override@JsonKey(unknownEnumValue: LiveRoomMode.multi) final  LiveRoomMode mode;
@override final  int version;
@override final  int seatCount;
 final  List<LiveSeat> _seats;
@override List<LiveSeat> get seats {
  if (_seats is EqualUnmodifiableListView) return _seats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seats);
}

 final  List<UserSummary> _moderators;
@override List<UserSummary> get moderators {
  if (_moderators is EqualUnmodifiableListView) return _moderators;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_moderators);
}

/// Host and moderators only.
@override final  int? pendingRequests;
/// Signed-in callers only.
@override final  LiveSeatsMine? mine;

/// Create a copy of LiveSeats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveSeatsCopyWith<_LiveSeats> get copyWith => __$LiveSeatsCopyWithImpl<_LiveSeats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveSeatsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveSeats&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.version, version) || other.version == version)&&(identical(other.seatCount, seatCount) || other.seatCount == seatCount)&&const DeepCollectionEquality().equals(other.seats, _seats)&&const DeepCollectionEquality().equals(other.moderators, _moderators)&&(identical(other.pendingRequests, pendingRequests) || other.pendingRequests == pendingRequests)&&(identical(other.mine, mine) || other.mine == mine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,roomId,mode,version,seatCount,const DeepCollectionEquality().hash(_seats),const DeepCollectionEquality().hash(_moderators),pendingRequests,mine);
}

@override
String toString() {
    return 'LiveSeats(roomId: $roomId, mode: $mode, version: $version, seatCount: $seatCount, seats: $seats, moderators: $moderators, pendingRequests: $pendingRequests, mine: $mine)';
}


}

/// @nodoc
abstract mixin class _$LiveSeatsCopyWith<$Res> implements $LiveSeatsCopyWith<$Res> {
  factory _$LiveSeatsCopyWith(_LiveSeats value, $Res Function(_LiveSeats) _then) = __$LiveSeatsCopyWithImpl;
@override @useResult
$Res call({
 String roomId,@JsonKey(unknownEnumValue: LiveRoomMode.multi) LiveRoomMode mode, int version, int seatCount, List<LiveSeat> seats, List<UserSummary> moderators, int? pendingRequests, LiveSeatsMine? mine
});


@override $LiveSeatsMineCopyWith<$Res>? get mine;

}
/// @nodoc
class __$LiveSeatsCopyWithImpl<$Res>
    implements _$LiveSeatsCopyWith<$Res> {
  __$LiveSeatsCopyWithImpl(this._self, this._then);

  final _LiveSeats _self;
  final $Res Function(_LiveSeats) _then;

/// Create a copy of LiveSeats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roomId = null,Object? mode = null,Object? version = null,Object? seatCount = null,Object? seats = null,Object? moderators = null,Object? pendingRequests = freezed,Object? mine = freezed,}) {
  return _then(_LiveSeats(
roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,seatCount: null == seatCount ? _self.seatCount : seatCount // ignore: cast_nullable_to_non_nullable
as int,seats: null == seats ? _self._seats : seats // ignore: cast_nullable_to_non_nullable
as List<LiveSeat>,moderators: null == moderators ? _self._moderators : moderators // ignore: cast_nullable_to_non_nullable
as List<UserSummary>,pendingRequests: freezed == pendingRequests ? _self.pendingRequests : pendingRequests // ignore: cast_nullable_to_non_nullable
as int?,mine: freezed == mine ? _self.mine : mine // ignore: cast_nullable_to_non_nullable
as LiveSeatsMine?,
  ));
}

/// Create a copy of LiveSeats
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveSeatsMineCopyWith<$Res>? get mine {
    if (_self.mine == null) {
    return null;
  }

  return $LiveSeatsMineCopyWith<$Res>(_self.mine!, (value) {
    return _then(_self.copyWith(mine: value));
  });
}
}

// dart format on
