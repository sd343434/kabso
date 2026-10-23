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

 String get id; String get title;@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode get mode; int get viewerCount; DateTime get startedAt; String? get coverUrl; LiveCategory? get category; UserSummary get host; LiveRoomStatus get status; DateTime? get endedAt;@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? get endReason;/// CP-010: people without an account may watch.
 bool get allowGuests;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveRoom&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.viewerCount, _this.viewerCount) || other.viewerCount == _this.viewerCount)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.endedAt, _this.endedAt) || other.endedAt == _this.endedAt)&&(identical(other.endReason, _this.endReason) || other.endReason == _this.endReason)&&(identical(other.allowGuests, _this.allowGuests) || other.allowGuests == _this.allowGuests));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveRoom;
  return Object.hash(runtimeType,_this.id,_this.title,_this.mode,_this.viewerCount,_this.startedAt,_this.coverUrl,_this.category,_this.host,_this.status,_this.endedAt,_this.endReason,_this.allowGuests);
}

@override
String toString() {
  final _this = this as LiveRoom;
  return 'LiveRoom(id: ${_this.id}, title: ${_this.title}, mode: ${_this.mode}, viewerCount: ${_this.viewerCount}, startedAt: ${_this.startedAt}, coverUrl: ${_this.coverUrl}, category: ${_this.category}, host: ${_this.host}, status: ${_this.status}, endedAt: ${_this.endedAt}, endReason: ${_this.endReason}, allowGuests: ${_this.allowGuests})';
}


}

/// @nodoc
abstract mixin class $LiveRoomCopyWith<$Res>  {
  factory $LiveRoomCopyWith(LiveRoom value, $Res Function(LiveRoom) _then) = _$LiveRoomCopyWithImpl;
@useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, LiveRoomStatus status, DateTime? endedAt,@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? endReason, bool allowGuests
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? status = null,Object? endedAt = freezed,Object? endReason = freezed,Object? allowGuests = null,}) {
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
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason,  bool allowGuests)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason,_that.allowGuests);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason,  bool allowGuests)  $default,) {final _that = this;
switch (_that) {
case _LiveRoom():
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason,_that.allowGuests);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title, @JsonKey(unknownEnumValue: LiveRoomMode.solo)  LiveRoomMode mode,  int viewerCount,  DateTime startedAt,  String? coverUrl,  LiveCategory? category,  UserSummary host,  LiveRoomStatus status,  DateTime? endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)  LiveRoomEndReason? endReason,  bool allowGuests)?  $default,) {final _that = this;
switch (_that) {
case _LiveRoom() when $default != null:
return $default(_that.id,_that.title,_that.mode,_that.viewerCount,_that.startedAt,_that.coverUrl,_that.category,_that.host,_that.status,_that.endedAt,_that.endReason,_that.allowGuests);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveRoom implements LiveRoom {
  const _LiveRoom({required this.id, required this.title, @JsonKey(unknownEnumValue: LiveRoomMode.solo) required this.mode, required this.viewerCount, required this.startedAt, required this.coverUrl, required this.category, required this.host, required this.status, required this.endedAt, @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) required this.endReason, this.allowGuests = true});
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.viewerCount, viewerCount) || other.viewerCount == viewerCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.category, category) || other.category == category)&&(identical(other.host, host) || other.host == host)&&(identical(other.status, status) || other.status == status)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.endReason, endReason) || other.endReason == endReason)&&(identical(other.allowGuests, allowGuests) || other.allowGuests == allowGuests));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,mode,viewerCount,startedAt,coverUrl,category,host,status,endedAt,endReason,allowGuests);
}

@override
String toString() {
    return 'LiveRoom(id: $id, title: $title, mode: $mode, viewerCount: $viewerCount, startedAt: $startedAt, coverUrl: $coverUrl, category: $category, host: $host, status: $status, endedAt: $endedAt, endReason: $endReason, allowGuests: $allowGuests)';
}


}

/// @nodoc
abstract mixin class _$LiveRoomCopyWith<$Res> implements $LiveRoomCopyWith<$Res> {
  factory _$LiveRoomCopyWith(_LiveRoom value, $Res Function(_LiveRoom) _then) = __$LiveRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String title,@JsonKey(unknownEnumValue: LiveRoomMode.solo) LiveRoomMode mode, int viewerCount, DateTime startedAt, String? coverUrl, LiveCategory? category, UserSummary host, LiveRoomStatus status, DateTime? endedAt,@JsonKey(unknownEnumValue: LiveRoomEndReason.unknown) LiveRoomEndReason? endReason, bool allowGuests
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? mode = null,Object? viewerCount = null,Object? startedAt = null,Object? coverUrl = freezed,Object? category = freezed,Object? host = null,Object? status = null,Object? endedAt = freezed,Object? endReason = freezed,Object? allowGuests = null,}) {
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
as bool,
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

// dart format on
