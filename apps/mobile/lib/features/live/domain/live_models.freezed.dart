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

 bool get hostingEnabled; int get heartbeatIntervalSeconds; int get heartbeatStaleAfterSeconds;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveConfig&&(identical(other.hostingEnabled, _this.hostingEnabled) || other.hostingEnabled == _this.hostingEnabled)&&(identical(other.heartbeatIntervalSeconds, _this.heartbeatIntervalSeconds) || other.heartbeatIntervalSeconds == _this.heartbeatIntervalSeconds)&&(identical(other.heartbeatStaleAfterSeconds, _this.heartbeatStaleAfterSeconds) || other.heartbeatStaleAfterSeconds == _this.heartbeatStaleAfterSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveConfig;
  return Object.hash(runtimeType,_this.hostingEnabled,_this.heartbeatIntervalSeconds,_this.heartbeatStaleAfterSeconds);
}

@override
String toString() {
  final _this = this as LiveConfig;
  return 'LiveConfig(hostingEnabled: ${_this.hostingEnabled}, heartbeatIntervalSeconds: ${_this.heartbeatIntervalSeconds}, heartbeatStaleAfterSeconds: ${_this.heartbeatStaleAfterSeconds})';
}


}

/// @nodoc
abstract mixin class $LiveConfigCopyWith<$Res>  {
  factory $LiveConfigCopyWith(LiveConfig value, $Res Function(LiveConfig) _then) = _$LiveConfigCopyWithImpl;
@useResult
$Res call({
 bool hostingEnabled, int heartbeatIntervalSeconds, int heartbeatStaleAfterSeconds
});




}
/// @nodoc
class _$LiveConfigCopyWithImpl<$Res>
    implements $LiveConfigCopyWith<$Res> {
  _$LiveConfigCopyWithImpl(this._self, this._then);

  final LiveConfig _self;
  final $Res Function(LiveConfig) _then;

/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostingEnabled = null,Object? heartbeatIntervalSeconds = null,Object? heartbeatStaleAfterSeconds = null,}) {
  return _then(LiveConfig(
hostingEnabled: null == hostingEnabled ? _self.hostingEnabled : hostingEnabled // ignore: cast_nullable_to_non_nullable
as bool,heartbeatIntervalSeconds: null == heartbeatIntervalSeconds ? _self.heartbeatIntervalSeconds : heartbeatIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,heartbeatStaleAfterSeconds: null == heartbeatStaleAfterSeconds ? _self.heartbeatStaleAfterSeconds : heartbeatStaleAfterSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hostingEnabled,  int heartbeatIntervalSeconds,  int heartbeatStaleAfterSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveConfig() when $default != null:
return $default(_that.hostingEnabled,_that.heartbeatIntervalSeconds,_that.heartbeatStaleAfterSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hostingEnabled,  int heartbeatIntervalSeconds,  int heartbeatStaleAfterSeconds)  $default,) {final _that = this;
switch (_that) {
case _LiveConfig():
return $default(_that.hostingEnabled,_that.heartbeatIntervalSeconds,_that.heartbeatStaleAfterSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hostingEnabled,  int heartbeatIntervalSeconds,  int heartbeatStaleAfterSeconds)?  $default,) {final _that = this;
switch (_that) {
case _LiveConfig() when $default != null:
return $default(_that.hostingEnabled,_that.heartbeatIntervalSeconds,_that.heartbeatStaleAfterSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveConfig implements LiveConfig {
  const _LiveConfig({required this.hostingEnabled, required this.heartbeatIntervalSeconds, required this.heartbeatStaleAfterSeconds});
  factory _LiveConfig.fromJson(Map<String, dynamic> json) => _$LiveConfigFromJson(json);

@override final  bool hostingEnabled;
@override final  int heartbeatIntervalSeconds;
@override final  int heartbeatStaleAfterSeconds;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveConfig&&(identical(other.hostingEnabled, hostingEnabled) || other.hostingEnabled == hostingEnabled)&&(identical(other.heartbeatIntervalSeconds, heartbeatIntervalSeconds) || other.heartbeatIntervalSeconds == heartbeatIntervalSeconds)&&(identical(other.heartbeatStaleAfterSeconds, heartbeatStaleAfterSeconds) || other.heartbeatStaleAfterSeconds == heartbeatStaleAfterSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hostingEnabled,heartbeatIntervalSeconds,heartbeatStaleAfterSeconds);
}

@override
String toString() {
    return 'LiveConfig(hostingEnabled: $hostingEnabled, heartbeatIntervalSeconds: $heartbeatIntervalSeconds, heartbeatStaleAfterSeconds: $heartbeatStaleAfterSeconds)';
}


}

/// @nodoc
abstract mixin class _$LiveConfigCopyWith<$Res> implements $LiveConfigCopyWith<$Res> {
  factory _$LiveConfigCopyWith(_LiveConfig value, $Res Function(_LiveConfig) _then) = __$LiveConfigCopyWithImpl;
@override @useResult
$Res call({
 bool hostingEnabled, int heartbeatIntervalSeconds, int heartbeatStaleAfterSeconds
});




}
/// @nodoc
class __$LiveConfigCopyWithImpl<$Res>
    implements _$LiveConfigCopyWith<$Res> {
  __$LiveConfigCopyWithImpl(this._self, this._then);

  final _LiveConfig _self;
  final $Res Function(_LiveConfig) _then;

/// Create a copy of LiveConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostingEnabled = null,Object? heartbeatIntervalSeconds = null,Object? heartbeatStaleAfterSeconds = null,}) {
  return _then(_LiveConfig(
hostingEnabled: null == hostingEnabled ? _self.hostingEnabled : hostingEnabled // ignore: cast_nullable_to_non_nullable
as bool,heartbeatIntervalSeconds: null == heartbeatIntervalSeconds ? _self.heartbeatIntervalSeconds : heartbeatIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,heartbeatStaleAfterSeconds: null == heartbeatStaleAfterSeconds ? _self.heartbeatStaleAfterSeconds : heartbeatStaleAfterSeconds // ignore: cast_nullable_to_non_nullable
as int,
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

 String get id; String get title;@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode get mode; int get viewerCount; DateTime get startedAt; String? get coverUrl; LiveCategory? get category; UserSummary get host;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoomSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.viewerCount, _this.viewerCount) || other.viewerCount == _this.viewerCount)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.host, _this.host) || other.host == _this.host));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoomSummary;
  return Object.hash(runtimeType,_this.id,_this.title,_this.mode,_this.viewerCount,_this.startedAt,_this.coverUrl,_this.category,_this.host);
}

@override
String toString() {
  final _this = this as LiveRoomSummary;
  return 'LiveRoomSummary(id: ${_this.id}, title: ${_this.title}, mode: ${_this.mode}, viewerCount: ${_this.viewerCount}, startedAt: ${_this.startedAt}, coverUrl: ${_this.coverUrl}, category: ${_this.category}, host: ${_this.host})';
}


}

/// @nodoc
abstract mixin class $LiveRoomSummaryCopyWith<$Res>  {
  factory $LiveRoomSummaryCopyWith(LiveRoomSummary value, $Res Function(LiveRoomSummary) _then) = _$LiveRoomSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,}) {
  return _then(LiveRoomSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LiveCategory?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoomSummary() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host)  $default,) {final _that = this;
switch (_that) {
case _LiveRoomSummary():
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoomSummary() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoomSummary implements LiveRoomSummary {
  const _LiveRoomSummary({required this.id, required this.title, @JsonKey(unknownEnumValue: LiveRoomMode.solo) required this.mode, required this.viewerCount, required this.startedAt, required this.coverUrl, required this.category, required this.host});
  factory _LiveRoomSummary.fromJson(Map<String, dynamic> json) => _$LiveRoomSummaryFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey(unknownEnumValue: LiveRoomMode.solo) final  LiveRoomMode mode;
@override final  int viewerCount;
@override final  DateTime startedAt;
@override final  String? coverUrl;
@override final  LiveCategory? category;
@override final  UserSummary host;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoomSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.host, host) || other.host == host));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,mode,viewerCount,startedAt,coverUrl,category,host);
}

@override
String toString() {
    return 'LiveRoomSummary(id: $id, title: $title, mode: $mode, viewerCount: $viewerCount, startedAt: $startedAt, coverUrl: $coverUrl, category: $category, host: $host)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomSummaryCopyWith<$Res> implements $LiveRoomSummaryCopyWith<$Res> {
  factory _$LiveRoomSummaryCopyWith(_LiveRoomSummary value, $Res Function(_LiveRoomSummary) _then) = __$LiveRoomSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,}) {
  return _then(_LiveRoomSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as LiveRoomMode,viewerCount: null == viewerCount ? _self.viewerCount : viewerCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as LiveCategory?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,
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

 String get id; String get title;@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode get mode; int get viewerCount; DateTime get startedAt; String? get coverUrl; LiveCategory? get category; UserSummary get host; LiveRoomStatus get status; DateTime? get endedAt;@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? get endReason;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoom&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.viewerCount, _this.viewerCount) || other.viewerCount == _this.viewerCount)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.endedAt, _this.endedAt) || other.endedAt == _this.endedAt)&&(identical(other.endReason, _this.endReason) || other.endReason == _this.endReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoom;
  return Object.hash(runtimeType,_this.id,_this.title,_this.mode,_this.viewerCount,_this.startedAt,_this.coverUrl,_this.category,_this.host,_this.status,_this.endedAt,_this.endReason);
}

@override
String toString() {
  final _this = this as LiveRoom;
  return 'LiveRoom(id: ${_this.id}, title: ${_this.title}, mode: ${_this.mode}, viewerCount: ${_this.viewerCount}, startedAt: ${_this.startedAt}, coverUrl: ${_this.coverUrl}, category: ${_this.category}, host: ${_this.host}, status: ${_this.status}, endedAt: ${_this.endedAt}, endReason: ${_this.endReason})';
}


}

/// @nodoc
abstract mixin class $LiveRoomCopyWith<$Res>  {
  factory $LiveRoomCopyWith(LiveRoom value, $Res Function(LiveRoom) _then) = _$LiveRoomCopyWithImpl;
@useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, LiveRoomStatus status, DateTime? endedAt,@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? endReason
});


$LiveCategoryCopyWith<$Res>? get category;$UserSummaryCopyWith<$Res> get host;

}
/// @nodoc
class _$LiveRoomCopyWithImpl<$Res>
    implements $LiveRoomCopyWith<$Res> {
  _$LiveRoomCopyWithImpl(this._self, this._then);

  final LiveRoom _self;
  final $Res Function(LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? status = null,Object? endedAt = freezed,Object? endReason = freezed,}) {
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
as LiveRoomEndReason?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason)  $default,) {final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoom implements LiveRoom {
  const _LiveRoom({required this.id, required this.title, @JsonKey(unknownEnumValue: LiveRoomMode.solo) required this.mode, required this.viewerCount, required this.startedAt, required this.coverUrl, required this.category, required this.host, required this.status, required this.endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) required this.endReason});
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.host, host) || other.host == host)&&(identical(other.status, status) || other.status == status)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.endReason, endReason) || other.endReason == endReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,mode,viewerCount,startedAt,coverUrl,category,host,status,endedAt,endReason);
}

@override
String toString() {
    return 'LiveRoom(id: $id, title: $title, mode: $mode, viewerCount: $viewerCount, startedAt: $startedAt, coverUrl: $coverUrl, category: $category, host: $host, status: $status, endedAt: $endedAt, endReason: $endReason)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomCopyWith<$Res> implements $LiveRoomCopyWith<$Res> {
  factory _$LiveRoomCopyWith(_LiveRoom value, $Res Function(_LiveRoom) _then) = __$LiveRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, LiveRoomStatus status, DateTime? endedAt,@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? endReason
});


@override $LiveCategoryCopyWith<$Res>? get category;@override $UserSummaryCopyWith<$Res> get host;

}
/// @nodoc
class __$LiveRoomCopyWithImpl<$Res>
    implements _$LiveRoomCopyWith<$Res> {
  __$LiveRoomCopyWithImpl(this._self, this._then);

  final _LiveRoom _self;
  final $Res Function(_LiveRoom) _then;

/// Create a copy of LiveRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? status = null,Object? endedAt = freezed,Object? endReason = freezed,}) {
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
as LiveRoomEndReason?,
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

// dart format on
