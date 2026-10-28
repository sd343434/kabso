// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_gift_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GiftTag {

 String get code; String get name;
/// Create a copy of GiftTag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GiftTagCopyWith<GiftTag> get copyWith => _$GiftTagCopyWithImpl<GiftTag>(this as GiftTag, _$identity);

  /// Serializes this GiftTag to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GiftTag;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GiftTag&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GiftTag;
  return Object.hash(runtimeType,_this.code,_this.name);
}

@override
String toString() {
  final _this = this as GiftTag;
  return 'GiftTag(code: ${_this.code}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $GiftTagCopyWith<$Res>  {
  factory $GiftTagCopyWith(GiftTag value, $Res Function(GiftTag) _then) = _$GiftTagCopyWithImpl;
@useResult
$Res call({
 String code, String name
});




}
/// @nodoc
class _$GiftTagCopyWithImpl<$Res>
    implements $GiftTagCopyWith<$Res> {
  _$GiftTagCopyWithImpl(this._self, this._then);

  final GiftTag _self;
  final $Res Function(GiftTag) _then;

/// Create a copy of GiftTag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,}) {
  return _then(GiftTag(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GiftTag].
extension GiftTagPatterns on GiftTag {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GiftTag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GiftTag() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GiftTag value)  $default,){
final _that = this;
switch (_that) {
case _GiftTag():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GiftTag value)?  $default,){
final _that = this;
switch (_that) {
case _GiftTag() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GiftTag() when $default != null:
return $default(_that.code,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name)  $default,) {final _that = this;
switch (_that) {
case _GiftTag():
return $default(_that.code,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name)?  $default,) {final _that = this;
switch (_that) {
case _GiftTag() when $default != null:
return $default(_that.code,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GiftTag implements GiftTag {
  const _GiftTag({required this.code, required this.name});
  factory _GiftTag.fromJson(Map<String, dynamic> json) => _$GiftTagFromJson(json);

@override final  String code;
@override final  String name;

/// Create a copy of GiftTag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GiftTagCopyWith<_GiftTag> get copyWith => __$GiftTagCopyWithImpl<_GiftTag>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GiftTagToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GiftTag&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name);
}

@override
String toString() {
    return 'GiftTag(code: $code, name: $name)';
}


}

/// @nodoc
abstract mixin class _$GiftTagCopyWith<$Res> implements $GiftTagCopyWith<$Res> {
  factory _$GiftTagCopyWith(_GiftTag value, $Res Function(_GiftTag) _then) = __$GiftTagCopyWithImpl;
@override @useResult
$Res call({
 String code, String name
});




}
/// @nodoc
class __$GiftTagCopyWithImpl<$Res>
    implements _$GiftTagCopyWith<$Res> {
  __$GiftTagCopyWithImpl(this._self, this._then);

  final _GiftTag _self;
  final $Res Function(_GiftTag) _then;

/// Create a copy of GiftTag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,}) {
  return _then(_GiftTag(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$GiftQuip {

 String get soundKey; int get durationMs; String? get text;
/// Create a copy of GiftQuip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GiftQuipCopyWith<GiftQuip> get copyWith => _$GiftQuipCopyWithImpl<GiftQuip>(this as GiftQuip, _$identity);

  /// Serializes this GiftQuip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GiftQuip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GiftQuip&&(identical(other.soundKey, _this.soundKey) || other.soundKey == _this.soundKey)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GiftQuip;
  return Object.hash(runtimeType,_this.soundKey,_this.durationMs,_this.text);
}

@override
String toString() {
  final _this = this as GiftQuip;
  return 'GiftQuip(soundKey: ${_this.soundKey}, durationMs: ${_this.durationMs}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $GiftQuipCopyWith<$Res>  {
  factory $GiftQuipCopyWith(GiftQuip value, $Res Function(GiftQuip) _then) = _$GiftQuipCopyWithImpl;
@useResult
$Res call({
 String soundKey, int durationMs, String? text
});




}
/// @nodoc
class _$GiftQuipCopyWithImpl<$Res>
    implements $GiftQuipCopyWith<$Res> {
  _$GiftQuipCopyWithImpl(this._self, this._then);

  final GiftQuip _self;
  final $Res Function(GiftQuip) _then;

/// Create a copy of GiftQuip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? soundKey = null,Object? durationMs = null,Object? text = freezed,}) {
  return _then(GiftQuip(
soundKey: null == soundKey ? _self.soundKey : soundKey // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GiftQuip].
extension GiftQuipPatterns on GiftQuip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GiftQuip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GiftQuip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GiftQuip value)  $default,){
final _that = this;
switch (_that) {
case _GiftQuip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GiftQuip value)?  $default,){
final _that = this;
switch (_that) {
case _GiftQuip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String soundKey,  int durationMs,  String? text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GiftQuip() when $default != null:
return $default(_that.soundKey,_that.durationMs,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String soundKey,  int durationMs,  String? text)  $default,) {final _that = this;
switch (_that) {
case _GiftQuip():
return $default(_that.soundKey,_that.durationMs,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String soundKey,  int durationMs,  String? text)?  $default,) {final _that = this;
switch (_that) {
case _GiftQuip() when $default != null:
return $default(_that.soundKey,_that.durationMs,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GiftQuip implements GiftQuip {
  const _GiftQuip({required this.soundKey, required this.durationMs, this.text});
  factory _GiftQuip.fromJson(Map<String, dynamic> json) => _$GiftQuipFromJson(json);

@override final  String soundKey;
@override final  int durationMs;
@override final  String? text;

/// Create a copy of GiftQuip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GiftQuipCopyWith<_GiftQuip> get copyWith => __$GiftQuipCopyWithImpl<_GiftQuip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GiftQuipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GiftQuip&&(identical(other.soundKey, soundKey) || other.soundKey == soundKey)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,soundKey,durationMs,text);
}

@override
String toString() {
    return 'GiftQuip(soundKey: $soundKey, durationMs: $durationMs, text: $text)';
}


}

/// @nodoc
abstract mixin class _$GiftQuipCopyWith<$Res> implements $GiftQuipCopyWith<$Res> {
  factory _$GiftQuipCopyWith(_GiftQuip value, $Res Function(_GiftQuip) _then) = __$GiftQuipCopyWithImpl;
@override @useResult
$Res call({
 String soundKey, int durationMs, String? text
});




}
/// @nodoc
class __$GiftQuipCopyWithImpl<$Res>
    implements _$GiftQuipCopyWith<$Res> {
  __$GiftQuipCopyWithImpl(this._self, this._then);

  final _GiftQuip _self;
  final $Res Function(_GiftQuip) _then;

/// Create a copy of GiftQuip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? soundKey = null,Object? durationMs = null,Object? text = freezed,}) {
  return _then(_GiftQuip(
soundKey: null == soundKey ? _self.soundKey : soundKey // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Gift {

 String get code; GiftCategory get category; String get name; int get priceCoins; String get assetKey; String? get animationKey; int get sortOrder;@JsonKey(unknownEnumValue: GiftBadge.none) GiftBadge get badge;/// The sub-category (v1.24.3-live), or null: none, or an older API.
 GiftTag? get tag;/// The hosted static image (v1.26.2-live), or null: the bundled one.
 String? get imageUrl;/// The hosted SVGA effect (v1.26.2-live), or null: the bundled one.
 String? get animationUrl;/// [animationUrl]'s size in bytes (whether to prefetch it), or null.
 int? get animationBytes;/// v1.32-live (D154): a quip's sound and words; null for other gifts.
 GiftQuip? get quip;
/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GiftCopyWith<Gift> get copyWith => _$GiftCopyWithImpl<Gift>(this as Gift, _$identity);

  /// Serializes this Gift to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Gift;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Gift&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.priceCoins, _this.priceCoins) || other.priceCoins == _this.priceCoins)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey)&&(identical(other.animationKey, _this.animationKey) || other.animationKey == _this.animationKey)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.badge, _this.badge) || other.badge == _this.badge)&&(identical(other.tag, _this.tag) || other.tag == _this.tag)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.animationUrl, _this.animationUrl) || other.animationUrl == _this.animationUrl)&&(identical(other.animationBytes, _this.animationBytes) || other.animationBytes == _this.animationBytes)&&(identical(other.quip, _this.quip) || other.quip == _this.quip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Gift;
  return Object.hash(runtimeType,_this.code,_this.category,_this.name,_this.priceCoins,_this.assetKey,_this.animationKey,_this.sortOrder,_this.badge,_this.tag,_this.imageUrl,_this.animationUrl,_this.animationBytes,_this.quip);
}

@override
String toString() {
  final _this = this as Gift;
  return 'Gift(code: ${_this.code}, category: ${_this.category}, name: ${_this.name}, priceCoins: ${_this.priceCoins}, assetKey: ${_this.assetKey}, animationKey: ${_this.animationKey}, sortOrder: ${_this.sortOrder}, badge: ${_this.badge}, tag: ${_this.tag}, imageUrl: ${_this.imageUrl}, animationUrl: ${_this.animationUrl}, animationBytes: ${_this.animationBytes}, quip: ${_this.quip})';
}


}

/// @nodoc
abstract mixin class $GiftCopyWith<$Res>  {
  factory $GiftCopyWith(Gift value, $Res Function(Gift) _then) = _$GiftCopyWithImpl;
@useResult
$Res call({
 String code, GiftCategory category, String name, int priceCoins, String assetKey, String? animationKey, int sortOrder,@JsonKey(unknownEnumValue: GiftBadge.none) GiftBadge badge, GiftTag? tag, String? imageUrl, String? animationUrl, int? animationBytes, GiftQuip? quip
});


$GiftTagCopyWith<$Res>? get tag;$GiftQuipCopyWith<$Res>? get quip;

}
/// @nodoc
class _$GiftCopyWithImpl<$Res>
    implements $GiftCopyWith<$Res> {
  _$GiftCopyWithImpl(this._self, this._then);

  final Gift _self;
  final $Res Function(Gift) _then;

/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? category = null,Object? name = null,Object? priceCoins = null,Object? assetKey = null,Object? animationKey = freezed,Object? sortOrder = null,Object? badge = null,Object? tag = freezed,Object? imageUrl = freezed,Object? animationUrl = freezed,Object? animationBytes = freezed,Object? quip = freezed,}) {
  return _then(Gift(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as GiftCategory,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priceCoins: null == priceCoins ? _self.priceCoins : priceCoins // ignore: cast_nullable_to_non_nullable
as int,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,animationKey: freezed == animationKey ? _self.animationKey : animationKey // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,badge: null == badge ? _self.badge : badge // ignore: cast_nullable_to_non_nullable
as GiftBadge,tag: freezed == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as GiftTag?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,animationUrl: freezed == animationUrl ? _self.animationUrl : animationUrl // ignore: cast_nullable_to_non_nullable
as String?,animationBytes: freezed == animationBytes ? _self.animationBytes : animationBytes // ignore: cast_nullable_to_non_nullable
as int?,quip: freezed == quip ? _self.quip : quip // ignore: cast_nullable_to_non_nullable
as GiftQuip?,
  ));
}
/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GiftTagCopyWith<$Res>? get tag {
    if (_self.tag == null) {
    return null;
  }

  return $GiftTagCopyWith<$Res>(_self.tag!, (value) {
    return _then(_self.copyWith(tag: value));
  });
}/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GiftQuipCopyWith<$Res>? get quip {
    if (_self.quip == null) {
    return null;
  }

  return $GiftQuipCopyWith<$Res>(_self.quip!, (value) {
    return _then(_self.copyWith(quip: value));
  });
}
}


/// Adds pattern-matching-related methods to [Gift].
extension GiftPatterns on Gift {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Gift value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Gift() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Gift value)  $default,){
final _that = this;
switch (_that) {
case _Gift():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Gift value)?  $default,){
final _that = this;
switch (_that) {
case _Gift() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  GiftCategory category,  String name,  int priceCoins,  String assetKey,  String? animationKey,  int sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none)  GiftBadge badge,  GiftTag? tag,  String? imageUrl,  String? animationUrl,  int? animationBytes,  GiftQuip? quip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Gift() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.priceCoins,_that.assetKey,_that.animationKey,_that.sortOrder,_that.badge,_that.tag,_that.imageUrl,_that.animationUrl,_that.animationBytes,_that.quip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  GiftCategory category,  String name,  int priceCoins,  String assetKey,  String? animationKey,  int sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none)  GiftBadge badge,  GiftTag? tag,  String? imageUrl,  String? animationUrl,  int? animationBytes,  GiftQuip? quip)  $default,) {final _that = this;
switch (_that) {
case _Gift():
return $default(_that.code,_that.category,_that.name,_that.priceCoins,_that.assetKey,_that.animationKey,_that.sortOrder,_that.badge,_that.tag,_that.imageUrl,_that.animationUrl,_that.animationBytes,_that.quip);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  GiftCategory category,  String name,  int priceCoins,  String assetKey,  String? animationKey,  int sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none)  GiftBadge badge,  GiftTag? tag,  String? imageUrl,  String? animationUrl,  int? animationBytes,  GiftQuip? quip)?  $default,) {final _that = this;
switch (_that) {
case _Gift() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.priceCoins,_that.assetKey,_that.animationKey,_that.sortOrder,_that.badge,_that.tag,_that.imageUrl,_that.animationUrl,_that.animationBytes,_that.quip);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Gift implements Gift {
  const _Gift({required this.code, required this.category, required this.name, required this.priceCoins, required this.assetKey, required this.animationKey, required this.sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none) required this.badge, this.tag, this.imageUrl, this.animationUrl, this.animationBytes, this.quip});
  factory _Gift.fromJson(Map<String, dynamic> json) => _$GiftFromJson(json);

@override final  String code;
@override final  GiftCategory category;
@override final  String name;
@override final  int priceCoins;
@override final  String assetKey;
@override final  String? animationKey;
@override final  int sortOrder;
@override@JsonKey(unknownEnumValue: GiftBadge.none) final  GiftBadge badge;
/// The sub-category (v1.24.3-live), or null: none, or an older API.
@override final  GiftTag? tag;
/// The hosted static image (v1.26.2-live), or null: the bundled one.
@override final  String? imageUrl;
/// The hosted SVGA effect (v1.26.2-live), or null: the bundled one.
@override final  String? animationUrl;
/// [animationUrl]'s size in bytes (whether to prefetch it), or null.
@override final  int? animationBytes;
/// v1.32-live (D154): a quip's sound and words; null for other gifts.
@override final  GiftQuip? quip;

/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GiftCopyWith<_Gift> get copyWith => __$GiftCopyWithImpl<_Gift>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GiftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Gift&&(identical(other.code, code) || other.code == code)&&(identical(other.category, category) || other.category == category)&&(identical(other.name, name) || other.name == name)&&(identical(other.priceCoins, priceCoins) || other.priceCoins == priceCoins)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey)&&(identical(other.animationKey, animationKey) || other.animationKey == animationKey)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.badge, badge) || other.badge == badge)&&(identical(other.tag, tag) || other.tag == tag)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.animationUrl, animationUrl) || other.animationUrl == animationUrl)&&(identical(other.animationBytes, animationBytes) || other.animationBytes == animationBytes)&&(identical(other.quip, quip) || other.quip == quip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,category,name,priceCoins,assetKey,animationKey,sortOrder,badge,tag,imageUrl,animationUrl,animationBytes,quip);
}

@override
String toString() {
    return 'Gift(code: $code, category: $category, name: $name, priceCoins: $priceCoins, assetKey: $assetKey, animationKey: $animationKey, sortOrder: $sortOrder, badge: $badge, tag: $tag, imageUrl: $imageUrl, animationUrl: $animationUrl, animationBytes: $animationBytes, quip: $quip)';
}


}

/// @nodoc
abstract mixin class _$GiftCopyWith<$Res> implements $GiftCopyWith<$Res> {
  factory _$GiftCopyWith(_Gift value, $Res Function(_Gift) _then) = __$GiftCopyWithImpl;
@override @useResult
$Res call({
 String code, GiftCategory category, String name, int priceCoins, String assetKey, String? animationKey, int sortOrder,@JsonKey(unknownEnumValue: GiftBadge.none) GiftBadge badge, GiftTag? tag, String? imageUrl, String? animationUrl, int? animationBytes, GiftQuip? quip
});


@override $GiftTagCopyWith<$Res>? get tag;@override $GiftQuipCopyWith<$Res>? get quip;

}
/// @nodoc
class __$GiftCopyWithImpl<$Res>
    implements _$GiftCopyWith<$Res> {
  __$GiftCopyWithImpl(this._self, this._then);

  final _Gift _self;
  final $Res Function(_Gift) _then;

/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? category = null,Object? name = null,Object? priceCoins = null,Object? assetKey = null,Object? animationKey = freezed,Object? sortOrder = null,Object? badge = null,Object? tag = freezed,Object? imageUrl = freezed,Object? animationUrl = freezed,Object? animationBytes = freezed,Object? quip = freezed,}) {
  return _then(_Gift(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as GiftCategory,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priceCoins: null == priceCoins ? _self.priceCoins : priceCoins // ignore: cast_nullable_to_non_nullable
as int,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,animationKey: freezed == animationKey ? _self.animationKey : animationKey // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,badge: null == badge ? _self.badge : badge // ignore: cast_nullable_to_non_nullable
as GiftBadge,tag: freezed == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as GiftTag?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,animationUrl: freezed == animationUrl ? _self.animationUrl : animationUrl // ignore: cast_nullable_to_non_nullable
as String?,animationBytes: freezed == animationBytes ? _self.animationBytes : animationBytes // ignore: cast_nullable_to_non_nullable
as int?,quip: freezed == quip ? _self.quip : quip // ignore: cast_nullable_to_non_nullable
as GiftQuip?,
  ));
}

/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GiftTagCopyWith<$Res>? get tag {
    if (_self.tag == null) {
    return null;
  }

  return $GiftTagCopyWith<$Res>(_self.tag!, (value) {
    return _then(_self.copyWith(tag: value));
  });
}/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GiftQuipCopyWith<$Res>? get quip {
    if (_self.quip == null) {
    return null;
  }

  return $GiftQuipCopyWith<$Res>(_self.quip!, (value) {
    return _then(_self.copyWith(quip: value));
  });
}
}


/// @nodoc
mixin _$GiftCatalogue {

 String get version; List<GiftCategory> get categories; List<int> get quantities; int get maxRecipients; int get comboWindowSeconds; List<Gift> get data;
/// Create a copy of GiftCatalogue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GiftCatalogueCopyWith<GiftCatalogue> get copyWith => _$GiftCatalogueCopyWithImpl<GiftCatalogue>(this as GiftCatalogue, _$identity);

  /// Serializes this GiftCatalogue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GiftCatalogue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GiftCatalogue&&(identical(other.version, _this.version) || other.version == _this.version)&&const DeepCollectionEquality().equals(other.categories, _this.categories)&&const DeepCollectionEquality().equals(other.quantities, _this.quantities)&&(identical(other.maxRecipients, _this.maxRecipients) || other.maxRecipients == _this.maxRecipients)&&(identical(other.comboWindowSeconds, _this.comboWindowSeconds) || other.comboWindowSeconds == _this.comboWindowSeconds)&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GiftCatalogue;
  return Object.hash(runtimeType,_this.version,const DeepCollectionEquality().hash(_this.categories),const DeepCollectionEquality().hash(_this.quantities),_this.maxRecipients,_this.comboWindowSeconds,const DeepCollectionEquality().hash(_this.data));
}

@override
String toString() {
  final _this = this as GiftCatalogue;
  return 'GiftCatalogue(version: ${_this.version}, categories: ${_this.categories}, quantities: ${_this.quantities}, maxRecipients: ${_this.maxRecipients}, comboWindowSeconds: ${_this.comboWindowSeconds}, data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $GiftCatalogueCopyWith<$Res>  {
  factory $GiftCatalogueCopyWith(GiftCatalogue value, $Res Function(GiftCatalogue) _then) = _$GiftCatalogueCopyWithImpl;
@useResult
$Res call({
 String version, List<GiftCategory> categories, List<int> quantities, int maxRecipients, int comboWindowSeconds, List<Gift> data
});




}
/// @nodoc
class _$GiftCatalogueCopyWithImpl<$Res>
    implements $GiftCatalogueCopyWith<$Res> {
  _$GiftCatalogueCopyWithImpl(this._self, this._then);

  final GiftCatalogue _self;
  final $Res Function(GiftCatalogue) _then;

/// Create a copy of GiftCatalogue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? categories = null,Object? quantities = null,Object? maxRecipients = null,Object? comboWindowSeconds = null,Object? data = null,}) {
  return _then(GiftCatalogue(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<GiftCategory>,quantities: null == quantities ? _self.quantities : quantities // ignore: cast_nullable_to_non_nullable
as List<int>,maxRecipients: null == maxRecipients ? _self.maxRecipients : maxRecipients // ignore: cast_nullable_to_non_nullable
as int,comboWindowSeconds: null == comboWindowSeconds ? _self.comboWindowSeconds : comboWindowSeconds // ignore: cast_nullable_to_non_nullable
as int,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<Gift>,
  ));
}

}


/// Adds pattern-matching-related methods to [GiftCatalogue].
extension GiftCataloguePatterns on GiftCatalogue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GiftCatalogue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GiftCatalogue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GiftCatalogue value)  $default,){
final _that = this;
switch (_that) {
case _GiftCatalogue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GiftCatalogue value)?  $default,){
final _that = this;
switch (_that) {
case _GiftCatalogue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version,  List<GiftCategory> categories,  List<int> quantities,  int maxRecipients,  int comboWindowSeconds,  List<Gift> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GiftCatalogue() when $default != null:
return $default(_that.version,_that.categories,_that.quantities,_that.maxRecipients,_that.comboWindowSeconds,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version,  List<GiftCategory> categories,  List<int> quantities,  int maxRecipients,  int comboWindowSeconds,  List<Gift> data)  $default,) {final _that = this;
switch (_that) {
case _GiftCatalogue():
return $default(_that.version,_that.categories,_that.quantities,_that.maxRecipients,_that.comboWindowSeconds,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version,  List<GiftCategory> categories,  List<int> quantities,  int maxRecipients,  int comboWindowSeconds,  List<Gift> data)?  $default,) {final _that = this;
switch (_that) {
case _GiftCatalogue() when $default != null:
return $default(_that.version,_that.categories,_that.quantities,_that.maxRecipients,_that.comboWindowSeconds,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GiftCatalogue implements GiftCatalogue {
  const _GiftCatalogue({required this.version, required  List<GiftCategory> categories, required  List<int> quantities, required this.maxRecipients, required this.comboWindowSeconds, required  List<Gift> data}): _categories = categories,_quantities = quantities,_data = data;
  factory _GiftCatalogue.fromJson(Map<String, dynamic> json) => _$GiftCatalogueFromJson(json);

@override final  String version;
 final  List<GiftCategory> _categories;
@override List<GiftCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

 final  List<int> _quantities;
@override List<int> get quantities {
  if (_quantities is EqualUnmodifiableListView) return _quantities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_quantities);
}

@override final  int maxRecipients;
@override final  int comboWindowSeconds;
 final  List<Gift> _data;
@override List<Gift> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of GiftCatalogue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GiftCatalogueCopyWith<_GiftCatalogue> get copyWith => __$GiftCatalogueCopyWithImpl<_GiftCatalogue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GiftCatalogueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GiftCatalogue&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.categories, _categories)&&const DeepCollectionEquality().equals(other.quantities, _quantities)&&(identical(other.maxRecipients, maxRecipients) || other.maxRecipients == maxRecipients)&&(identical(other.comboWindowSeconds, comboWindowSeconds) || other.comboWindowSeconds == comboWindowSeconds)&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_quantities),maxRecipients,comboWindowSeconds,const DeepCollectionEquality().hash(_data));
}

@override
String toString() {
    return 'GiftCatalogue(version: $version, categories: $categories, quantities: $quantities, maxRecipients: $maxRecipients, comboWindowSeconds: $comboWindowSeconds, data: $data)';
}


}

/// @nodoc
abstract mixin class _$GiftCatalogueCopyWith<$Res> implements $GiftCatalogueCopyWith<$Res> {
  factory _$GiftCatalogueCopyWith(_GiftCatalogue value, $Res Function(_GiftCatalogue) _then) = __$GiftCatalogueCopyWithImpl;
@override @useResult
$Res call({
 String version, List<GiftCategory> categories, List<int> quantities, int maxRecipients, int comboWindowSeconds, List<Gift> data
});




}
/// @nodoc
class __$GiftCatalogueCopyWithImpl<$Res>
    implements _$GiftCatalogueCopyWith<$Res> {
  __$GiftCatalogueCopyWithImpl(this._self, this._then);

  final _GiftCatalogue _self;
  final $Res Function(_GiftCatalogue) _then;

/// Create a copy of GiftCatalogue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? categories = null,Object? quantities = null,Object? maxRecipients = null,Object? comboWindowSeconds = null,Object? data = null,}) {
  return _then(_GiftCatalogue(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<GiftCategory>,quantities: null == quantities ? _self._quantities : quantities // ignore: cast_nullable_to_non_nullable
as List<int>,maxRecipients: null == maxRecipients ? _self.maxRecipients : maxRecipients // ignore: cast_nullable_to_non_nullable
as int,comboWindowSeconds: null == comboWindowSeconds ? _self.comboWindowSeconds : comboWindowSeconds // ignore: cast_nullable_to_non_nullable
as int,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<Gift>,
  ));
}


}


/// @nodoc
mixin _$GiftBagItem {

 Gift get gift; int get quantity;
/// Create a copy of GiftBagItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GiftBagItemCopyWith<GiftBagItem> get copyWith => _$GiftBagItemCopyWithImpl<GiftBagItem>(this as GiftBagItem, _$identity);

  /// Serializes this GiftBagItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GiftBagItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GiftBagItem&&(identical(other.gift, _this.gift) || other.gift == _this.gift)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GiftBagItem;
  return Object.hash(runtimeType,_this.gift,_this.quantity);
}

@override
String toString() {
  final _this = this as GiftBagItem;
  return 'GiftBagItem(gift: ${_this.gift}, quantity: ${_this.quantity})';
}


}

/// @nodoc
abstract mixin class $GiftBagItemCopyWith<$Res>  {
  factory $GiftBagItemCopyWith(GiftBagItem value, $Res Function(GiftBagItem) _then) = _$GiftBagItemCopyWithImpl;
@useResult
$Res call({
 Gift gift, int quantity
});


$GiftCopyWith<$Res> get gift;

}
/// @nodoc
class _$GiftBagItemCopyWithImpl<$Res>
    implements $GiftBagItemCopyWith<$Res> {
  _$GiftBagItemCopyWithImpl(this._self, this._then);

  final GiftBagItem _self;
  final $Res Function(GiftBagItem) _then;

/// Create a copy of GiftBagItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gift = null,Object? quantity = null,}) {
  return _then(GiftBagItem(
gift: null == gift ? _self.gift : gift // ignore: cast_nullable_to_non_nullable
as Gift,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of GiftBagItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GiftCopyWith<$Res> get gift {
  
  return $GiftCopyWith<$Res>(_self.gift, (value) {
    return _then(_self.copyWith(gift: value));
  });
}
}


/// Adds pattern-matching-related methods to [GiftBagItem].
extension GiftBagItemPatterns on GiftBagItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GiftBagItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GiftBagItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GiftBagItem value)  $default,){
final _that = this;
switch (_that) {
case _GiftBagItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GiftBagItem value)?  $default,){
final _that = this;
switch (_that) {
case _GiftBagItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Gift gift,  int quantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GiftBagItem() when $default != null:
return $default(_that.gift,_that.quantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Gift gift,  int quantity)  $default,) {final _that = this;
switch (_that) {
case _GiftBagItem():
return $default(_that.gift,_that.quantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Gift gift,  int quantity)?  $default,) {final _that = this;
switch (_that) {
case _GiftBagItem() when $default != null:
return $default(_that.gift,_that.quantity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GiftBagItem implements GiftBagItem {
  const _GiftBagItem({required this.gift, required this.quantity});
  factory _GiftBagItem.fromJson(Map<String, dynamic> json) => _$GiftBagItemFromJson(json);

@override final  Gift gift;
@override final  int quantity;

/// Create a copy of GiftBagItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GiftBagItemCopyWith<_GiftBagItem> get copyWith => __$GiftBagItemCopyWithImpl<_GiftBagItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GiftBagItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GiftBagItem&&(identical(other.gift, gift) || other.gift == gift)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gift,quantity);
}

@override
String toString() {
    return 'GiftBagItem(gift: $gift, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class _$GiftBagItemCopyWith<$Res> implements $GiftBagItemCopyWith<$Res> {
  factory _$GiftBagItemCopyWith(_GiftBagItem value, $Res Function(_GiftBagItem) _then) = __$GiftBagItemCopyWithImpl;
@override @useResult
$Res call({
 Gift gift, int quantity
});


@override $GiftCopyWith<$Res> get gift;

}
/// @nodoc
class __$GiftBagItemCopyWithImpl<$Res>
    implements _$GiftBagItemCopyWith<$Res> {
  __$GiftBagItemCopyWithImpl(this._self, this._then);

  final _GiftBagItem _self;
  final $Res Function(_GiftBagItem) _then;

/// Create a copy of GiftBagItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gift = null,Object? quantity = null,}) {
  return _then(_GiftBagItem(
gift: null == gift ? _self.gift : gift // ignore: cast_nullable_to_non_nullable
as Gift,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of GiftBagItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GiftCopyWith<$Res> get gift {
  
  return $GiftCopyWith<$Res>(_self.gift, (value) {
    return _then(_self.copyWith(gift: value));
  });
}
}


/// @nodoc
mixin _$LiveGiftCombo {

 String get id; int get count; int get quantity;
/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveGiftComboCopyWith<LiveGiftCombo> get copyWith => _$LiveGiftComboCopyWithImpl<LiveGiftCombo>(this as LiveGiftCombo, _$identity);

  /// Serializes this LiveGiftCombo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveGiftCombo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGiftCombo&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGiftCombo;
  return Object.hash(runtimeType,_this.id,_this.count,_this.quantity);
}

@override
String toString() {
  final _this = this as LiveGiftCombo;
  return 'LiveGiftCombo(id: ${_this.id}, count: ${_this.count}, quantity: ${_this.quantity})';
}


}

/// @nodoc
abstract mixin class $LiveGiftComboCopyWith<$Res>  {
  factory $LiveGiftComboCopyWith(LiveGiftCombo value, $Res Function(LiveGiftCombo) _then) = _$LiveGiftComboCopyWithImpl;
@useResult
$Res call({
 String id, int count, int quantity
});




}
/// @nodoc
class _$LiveGiftComboCopyWithImpl<$Res>
    implements $LiveGiftComboCopyWith<$Res> {
  _$LiveGiftComboCopyWithImpl(this._self, this._then);

  final LiveGiftCombo _self;
  final $Res Function(LiveGiftCombo) _then;

/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? count = null,Object? quantity = null,}) {
  return _then(LiveGiftCombo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveGiftCombo].
extension LiveGiftComboPatterns on LiveGiftCombo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveGiftCombo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveGiftCombo value)  $default,){
final _that = this;
switch (_that) {
case _LiveGiftCombo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveGiftCombo value)?  $default,){
final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int count,  int quantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
return $default(_that.id,_that.count,_that.quantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int count,  int quantity)  $default,) {final _that = this;
switch (_that) {
case _LiveGiftCombo():
return $default(_that.id,_that.count,_that.quantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int count,  int quantity)?  $default,) {final _that = this;
switch (_that) {
case _LiveGiftCombo() when $default != null:
return $default(_that.id,_that.count,_that.quantity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGiftCombo implements LiveGiftCombo {
  const _LiveGiftCombo({required this.id, required this.count, required this.quantity});
  factory _LiveGiftCombo.fromJson(Map<String, dynamic> json) => _$LiveGiftComboFromJson(json);

@override final  String id;
@override final  int count;
@override final  int quantity;

/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveGiftComboCopyWith<_LiveGiftCombo> get copyWith => __$LiveGiftComboCopyWithImpl<_LiveGiftCombo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveGiftComboToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGiftCombo&&(identical(other.id, id) || other.id == id)&&(identical(other.count, count) || other.count == count)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,count,quantity);
}

@override
String toString() {
    return 'LiveGiftCombo(id: $id, count: $count, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftComboCopyWith<$Res> implements $LiveGiftComboCopyWith<$Res> {
  factory _$LiveGiftComboCopyWith(_LiveGiftCombo value, $Res Function(_LiveGiftCombo) _then) = __$LiveGiftComboCopyWithImpl;
@override @useResult
$Res call({
 String id, int count, int quantity
});




}
/// @nodoc
class __$LiveGiftComboCopyWithImpl<$Res>
    implements _$LiveGiftComboCopyWith<$Res> {
  __$LiveGiftComboCopyWithImpl(this._self, this._then);

  final _LiveGiftCombo _self;
  final $Res Function(_LiveGiftCombo) _then;

/// Create a copy of LiveGiftCombo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? count = null,Object? quantity = null,}) {
  return _then(_LiveGiftCombo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LiveGift {

 String get id; String get roomId; String get giftCode; String get assetKey; String? get animationKey; int get unitPrice; int get quantity;@JsonKey(unknownEnumValue: LiveGiftSource.coins) LiveGiftSource get source; int get totalCoins; UserSummary get sender; List<UserSummary> get recipients; LiveGiftCombo get combo; DateTime get createdAt;/// The gift's hosted art now (v1.26.2-live, D126), as in [Gift].
 String? get imageUrl; String? get animationUrl; int? get animationBytes;
/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveGiftCopyWith<LiveGift> get copyWith => _$LiveGiftCopyWithImpl<LiveGift>(this as LiveGift, _$identity);

  /// Serializes this LiveGift to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveGift;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGift&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.giftCode, _this.giftCode) || other.giftCode == _this.giftCode)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey)&&(identical(other.animationKey, _this.animationKey) || other.animationKey == _this.animationKey)&&(identical(other.unitPrice, _this.unitPrice) || other.unitPrice == _this.unitPrice)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.totalCoins, _this.totalCoins) || other.totalCoins == _this.totalCoins)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&const DeepCollectionEquality().equals(other.recipients, _this.recipients)&&(identical(other.combo, _this.combo) || other.combo == _this.combo)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.animationUrl, _this.animationUrl) || other.animationUrl == _this.animationUrl)&&(identical(other.animationBytes, _this.animationBytes) || other.animationBytes == _this.animationBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGift;
  return Object.hash(runtimeType,_this.id,_this.roomId,_this.giftCode,_this.assetKey,_this.animationKey,_this.unitPrice,_this.quantity,_this.source,_this.totalCoins,_this.sender,const DeepCollectionEquality().hash(_this.recipients),_this.combo,_this.createdAt,_this.imageUrl,_this.animationUrl,_this.animationBytes);
}

@override
String toString() {
  final _this = this as LiveGift;
  return 'LiveGift(id: ${_this.id}, roomId: ${_this.roomId}, giftCode: ${_this.giftCode}, assetKey: ${_this.assetKey}, animationKey: ${_this.animationKey}, unitPrice: ${_this.unitPrice}, quantity: ${_this.quantity}, source: ${_this.source}, totalCoins: ${_this.totalCoins}, sender: ${_this.sender}, recipients: ${_this.recipients}, combo: ${_this.combo}, createdAt: ${_this.createdAt}, imageUrl: ${_this.imageUrl}, animationUrl: ${_this.animationUrl}, animationBytes: ${_this.animationBytes})';
}


}

/// @nodoc
abstract mixin class $LiveGiftCopyWith<$Res>  {
  factory $LiveGiftCopyWith(LiveGift value, $Res Function(LiveGift) _then) = _$LiveGiftCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String giftCode, String assetKey, String? animationKey, int unitPrice, int quantity,@JsonKey(unknownEnumValue: LiveGiftSource.coins) LiveGiftSource source, int totalCoins, UserSummary sender, List<UserSummary> recipients, LiveGiftCombo combo, DateTime createdAt, String? imageUrl, String? animationUrl, int? animationBytes
});


$UserSummaryCopyWith<$Res> get sender;$LiveGiftComboCopyWith<$Res> get combo;

}
/// @nodoc
class _$LiveGiftCopyWithImpl<$Res>
    implements $LiveGiftCopyWith<$Res> {
  _$LiveGiftCopyWithImpl(this._self, this._then);

  final LiveGift _self;
  final $Res Function(LiveGift) _then;

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? giftCode = null,Object? assetKey = null,Object? animationKey = freezed,Object? unitPrice = null,Object? quantity = null,Object? source = null,Object? totalCoins = null,Object? sender = null,Object? recipients = null,Object? combo = null,Object? createdAt = null,Object? imageUrl = freezed,Object? animationUrl = freezed,Object? animationBytes = freezed,}) {
  return _then(LiveGift(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,giftCode: null == giftCode ? _self.giftCode : giftCode // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,animationKey: freezed == animationKey ? _self.animationKey : animationKey // ignore: cast_nullable_to_non_nullable
as String?,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveGiftSource,totalCoins: null == totalCoins ? _self.totalCoins : totalCoins // ignore: cast_nullable_to_non_nullable
as int,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as List<UserSummary>,combo: null == combo ? _self.combo : combo // ignore: cast_nullable_to_non_nullable
as LiveGiftCombo,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,animationUrl: freezed == animationUrl ? _self.animationUrl : animationUrl // ignore: cast_nullable_to_non_nullable
as String?,animationBytes: freezed == animationBytes ? _self.animationBytes : animationBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftComboCopyWith<$Res> get combo {
  
  return $LiveGiftComboCopyWith<$Res>(_self.combo, (value) {
    return _then(_self.copyWith(combo: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveGift].
extension LiveGiftPatterns on LiveGift {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveGift value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveGift value)  $default,){
final _that = this;
switch (_that) {
case _LiveGift():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveGift value)?  $default,){
final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String giftCode,  String assetKey,  String? animationKey,  int unitPrice,  int quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins)  LiveGiftSource source,  int totalCoins,  UserSummary sender,  List<UserSummary> recipients,  LiveGiftCombo combo,  DateTime createdAt,  String? imageUrl,  String? animationUrl,  int? animationBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
return $default(_that.id,_that.roomId,_that.giftCode,_that.assetKey,_that.animationKey,_that.unitPrice,_that.quantity,_that.source,_that.totalCoins,_that.sender,_that.recipients,_that.combo,_that.createdAt,_that.imageUrl,_that.animationUrl,_that.animationBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String giftCode,  String assetKey,  String? animationKey,  int unitPrice,  int quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins)  LiveGiftSource source,  int totalCoins,  UserSummary sender,  List<UserSummary> recipients,  LiveGiftCombo combo,  DateTime createdAt,  String? imageUrl,  String? animationUrl,  int? animationBytes)  $default,) {final _that = this;
switch (_that) {
case _LiveGift():
return $default(_that.id,_that.roomId,_that.giftCode,_that.assetKey,_that.animationKey,_that.unitPrice,_that.quantity,_that.source,_that.totalCoins,_that.sender,_that.recipients,_that.combo,_that.createdAt,_that.imageUrl,_that.animationUrl,_that.animationBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String giftCode,  String assetKey,  String? animationKey,  int unitPrice,  int quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins)  LiveGiftSource source,  int totalCoins,  UserSummary sender,  List<UserSummary> recipients,  LiveGiftCombo combo,  DateTime createdAt,  String? imageUrl,  String? animationUrl,  int? animationBytes)?  $default,) {final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
return $default(_that.id,_that.roomId,_that.giftCode,_that.assetKey,_that.animationKey,_that.unitPrice,_that.quantity,_that.source,_that.totalCoins,_that.sender,_that.recipients,_that.combo,_that.createdAt,_that.imageUrl,_that.animationUrl,_that.animationBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGift implements LiveGift {
  const _LiveGift({required this.id, required this.roomId, required this.giftCode, required this.assetKey, required this.animationKey, required this.unitPrice, required this.quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins) required this.source, required this.totalCoins, required this.sender, required  List<UserSummary> recipients, required this.combo, required this.createdAt, this.imageUrl, this.animationUrl, this.animationBytes}): _recipients = recipients;
  factory _LiveGift.fromJson(Map<String, dynamic> json) => _$LiveGiftFromJson(json);

@override final  String id;
@override final  String roomId;
@override final  String giftCode;
@override final  String assetKey;
@override final  String? animationKey;
@override final  int unitPrice;
@override final  int quantity;
@override@JsonKey(unknownEnumValue: LiveGiftSource.coins) final  LiveGiftSource source;
@override final  int totalCoins;
@override final  UserSummary sender;
 final  List<UserSummary> _recipients;
@override List<UserSummary> get recipients {
  if (_recipients is EqualUnmodifiableListView) return _recipients;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recipients);
}

@override final  LiveGiftCombo combo;
@override final  DateTime createdAt;
/// The gift's hosted art now (v1.26.2-live, D126), as in [Gift].
@override final  String? imageUrl;
@override final  String? animationUrl;
@override final  int? animationBytes;

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveGiftCopyWith<_LiveGift> get copyWith => __$LiveGiftCopyWithImpl<_LiveGift>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveGiftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGift&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.giftCode, giftCode) || other.giftCode == giftCode)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey)&&(identical(other.animationKey, animationKey) || other.animationKey == animationKey)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.source, source) || other.source == source)&&(identical(other.totalCoins, totalCoins) || other.totalCoins == totalCoins)&&(identical(other.sender, sender) || other.sender == sender)&&const DeepCollectionEquality().equals(other.recipients, _recipients)&&(identical(other.combo, combo) || other.combo == combo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.animationUrl, animationUrl) || other.animationUrl == animationUrl)&&(identical(other.animationBytes, animationBytes) || other.animationBytes == animationBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,roomId,giftCode,assetKey,animationKey,unitPrice,quantity,source,totalCoins,sender,const DeepCollectionEquality().hash(_recipients),combo,createdAt,imageUrl,animationUrl,animationBytes);
}

@override
String toString() {
    return 'LiveGift(id: $id, roomId: $roomId, giftCode: $giftCode, assetKey: $assetKey, animationKey: $animationKey, unitPrice: $unitPrice, quantity: $quantity, source: $source, totalCoins: $totalCoins, sender: $sender, recipients: $recipients, combo: $combo, createdAt: $createdAt, imageUrl: $imageUrl, animationUrl: $animationUrl, animationBytes: $animationBytes)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftCopyWith<$Res> implements $LiveGiftCopyWith<$Res> {
  factory _$LiveGiftCopyWith(_LiveGift value, $Res Function(_LiveGift) _then) = __$LiveGiftCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String giftCode, String assetKey, String? animationKey, int unitPrice, int quantity,@JsonKey(unknownEnumValue: LiveGiftSource.coins) LiveGiftSource source, int totalCoins, UserSummary sender, List<UserSummary> recipients, LiveGiftCombo combo, DateTime createdAt, String? imageUrl, String? animationUrl, int? animationBytes
});


@override $UserSummaryCopyWith<$Res> get sender;@override $LiveGiftComboCopyWith<$Res> get combo;

}
/// @nodoc
class __$LiveGiftCopyWithImpl<$Res>
    implements _$LiveGiftCopyWith<$Res> {
  __$LiveGiftCopyWithImpl(this._self, this._then);

  final _LiveGift _self;
  final $Res Function(_LiveGift) _then;

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? giftCode = null,Object? assetKey = null,Object? animationKey = freezed,Object? unitPrice = null,Object? quantity = null,Object? source = null,Object? totalCoins = null,Object? sender = null,Object? recipients = null,Object? combo = null,Object? createdAt = null,Object? imageUrl = freezed,Object? animationUrl = freezed,Object? animationBytes = freezed,}) {
  return _then(_LiveGift(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,giftCode: null == giftCode ? _self.giftCode : giftCode // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,animationKey: freezed == animationKey ? _self.animationKey : animationKey // ignore: cast_nullable_to_non_nullable
as String?,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveGiftSource,totalCoins: null == totalCoins ? _self.totalCoins : totalCoins // ignore: cast_nullable_to_non_nullable
as int,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,recipients: null == recipients ? _self._recipients : recipients // ignore: cast_nullable_to_non_nullable
as List<UserSummary>,combo: null == combo ? _self.combo : combo // ignore: cast_nullable_to_non_nullable
as LiveGiftCombo,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,animationUrl: freezed == animationUrl ? _self.animationUrl : animationUrl // ignore: cast_nullable_to_non_nullable
as String?,animationBytes: freezed == animationBytes ? _self.animationBytes : animationBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of LiveGift
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftComboCopyWith<$Res> get combo {
  
  return $LiveGiftComboCopyWith<$Res>(_self.combo, (value) {
    return _then(_self.copyWith(combo: value));
  });
}
}


/// @nodoc
mixin _$LiveGiftResult {

 LiveGift get gift; int get coins; int get bagQuantity;/// v1.27-live (D132): the draws of a LUCKY send (absent otherwise).
 LuckyGiftResult? get luckyResult;/// v1.32-live (D154): a quip's place in the room's queue (absent
/// otherwise, and for a retry).
 LiveQuip? get quip;
/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveGiftResultCopyWith<LiveGiftResult> get copyWith => _$LiveGiftResultCopyWithImpl<LiveGiftResult>(this as LiveGiftResult, _$identity);

  /// Serializes this LiveGiftResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveGiftResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGiftResult&&(identical(other.gift, _this.gift) || other.gift == _this.gift)&&(identical(other.coins, _this.coins) || other.coins == _this.coins)&&(identical(other.bagQuantity, _this.bagQuantity) || other.bagQuantity == _this.bagQuantity)&&(identical(other.luckyResult, _this.luckyResult) || other.luckyResult == _this.luckyResult)&&(identical(other.quip, _this.quip) || other.quip == _this.quip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGiftResult;
  return Object.hash(runtimeType,_this.gift,_this.coins,_this.bagQuantity,_this.luckyResult,_this.quip);
}

@override
String toString() {
  final _this = this as LiveGiftResult;
  return 'LiveGiftResult(gift: ${_this.gift}, coins: ${_this.coins}, bagQuantity: ${_this.bagQuantity}, luckyResult: ${_this.luckyResult}, quip: ${_this.quip})';
}


}

/// @nodoc
abstract mixin class $LiveGiftResultCopyWith<$Res>  {
  factory $LiveGiftResultCopyWith(LiveGiftResult value, $Res Function(LiveGiftResult) _then) = _$LiveGiftResultCopyWithImpl;
@useResult
$Res call({
 LiveGift gift, int coins, int bagQuantity, LuckyGiftResult? luckyResult, LiveQuip? quip
});


$LiveGiftCopyWith<$Res> get gift;$LuckyGiftResultCopyWith<$Res>? get luckyResult;$LiveQuipCopyWith<$Res>? get quip;

}
/// @nodoc
class _$LiveGiftResultCopyWithImpl<$Res>
    implements $LiveGiftResultCopyWith<$Res> {
  _$LiveGiftResultCopyWithImpl(this._self, this._then);

  final LiveGiftResult _self;
  final $Res Function(LiveGiftResult) _then;

/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gift = null,Object? coins = null,Object? bagQuantity = null,Object? luckyResult = freezed,Object? quip = freezed,}) {
  return _then(LiveGiftResult(
gift: null == gift ? _self.gift : gift // ignore: cast_nullable_to_non_nullable
as LiveGift,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,bagQuantity: null == bagQuantity ? _self.bagQuantity : bagQuantity // ignore: cast_nullable_to_non_nullable
as int,luckyResult: freezed == luckyResult ? _self.luckyResult : luckyResult // ignore: cast_nullable_to_non_nullable
as LuckyGiftResult?,quip: freezed == quip ? _self.quip : quip // ignore: cast_nullable_to_non_nullable
as LiveQuip?,
  ));
}
/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftCopyWith<$Res> get gift {
  
  return $LiveGiftCopyWith<$Res>(_self.gift, (value) {
    return _then(_self.copyWith(gift: value));
  });
}/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyGiftResultCopyWith<$Res>? get luckyResult {
    if (_self.luckyResult == null) {
    return null;
  }

  return $LuckyGiftResultCopyWith<$Res>(_self.luckyResult!, (value) {
    return _then(_self.copyWith(luckyResult: value));
  });
}/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveQuipCopyWith<$Res>? get quip {
    if (_self.quip == null) {
    return null;
  }

  return $LiveQuipCopyWith<$Res>(_self.quip!, (value) {
    return _then(_self.copyWith(quip: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveGiftResult].
extension LiveGiftResultPatterns on LiveGiftResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveGiftResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveGiftResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveGiftResult value)  $default,){
final _that = this;
switch (_that) {
case _LiveGiftResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveGiftResult value)?  $default,){
final _that = this;
switch (_that) {
case _LiveGiftResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveGift gift,  int coins,  int bagQuantity,  LuckyGiftResult? luckyResult,  LiveQuip? quip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGiftResult() when $default != null:
return $default(_that.gift,_that.coins,_that.bagQuantity,_that.luckyResult,_that.quip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveGift gift,  int coins,  int bagQuantity,  LuckyGiftResult? luckyResult,  LiveQuip? quip)  $default,) {final _that = this;
switch (_that) {
case _LiveGiftResult():
return $default(_that.gift,_that.coins,_that.bagQuantity,_that.luckyResult,_that.quip);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveGift gift,  int coins,  int bagQuantity,  LuckyGiftResult? luckyResult,  LiveQuip? quip)?  $default,) {final _that = this;
switch (_that) {
case _LiveGiftResult() when $default != null:
return $default(_that.gift,_that.coins,_that.bagQuantity,_that.luckyResult,_that.quip);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGiftResult implements LiveGiftResult {
  const _LiveGiftResult({required this.gift, required this.coins, required this.bagQuantity, this.luckyResult, this.quip});
  factory _LiveGiftResult.fromJson(Map<String, dynamic> json) => _$LiveGiftResultFromJson(json);

@override final  LiveGift gift;
@override final  int coins;
@override final  int bagQuantity;
/// v1.27-live (D132): the draws of a LUCKY send (absent otherwise).
@override final  LuckyGiftResult? luckyResult;
/// v1.32-live (D154): a quip's place in the room's queue (absent
/// otherwise, and for a retry).
@override final  LiveQuip? quip;

/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveGiftResultCopyWith<_LiveGiftResult> get copyWith => __$LiveGiftResultCopyWithImpl<_LiveGiftResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveGiftResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGiftResult&&(identical(other.gift, gift) || other.gift == gift)&&(identical(other.coins, coins) || other.coins == coins)&&(identical(other.bagQuantity, bagQuantity) || other.bagQuantity == bagQuantity)&&(identical(other.luckyResult, luckyResult) || other.luckyResult == luckyResult)&&(identical(other.quip, quip) || other.quip == quip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gift,coins,bagQuantity,luckyResult,quip);
}

@override
String toString() {
    return 'LiveGiftResult(gift: $gift, coins: $coins, bagQuantity: $bagQuantity, luckyResult: $luckyResult, quip: $quip)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftResultCopyWith<$Res> implements $LiveGiftResultCopyWith<$Res> {
  factory _$LiveGiftResultCopyWith(_LiveGiftResult value, $Res Function(_LiveGiftResult) _then) = __$LiveGiftResultCopyWithImpl;
@override @useResult
$Res call({
 LiveGift gift, int coins, int bagQuantity, LuckyGiftResult? luckyResult, LiveQuip? quip
});


@override $LiveGiftCopyWith<$Res> get gift;@override $LuckyGiftResultCopyWith<$Res>? get luckyResult;@override $LiveQuipCopyWith<$Res>? get quip;

}
/// @nodoc
class __$LiveGiftResultCopyWithImpl<$Res>
    implements _$LiveGiftResultCopyWith<$Res> {
  __$LiveGiftResultCopyWithImpl(this._self, this._then);

  final _LiveGiftResult _self;
  final $Res Function(_LiveGiftResult) _then;

/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gift = null,Object? coins = null,Object? bagQuantity = null,Object? luckyResult = freezed,Object? quip = freezed,}) {
  return _then(_LiveGiftResult(
gift: null == gift ? _self.gift : gift // ignore: cast_nullable_to_non_nullable
as LiveGift,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,bagQuantity: null == bagQuantity ? _self.bagQuantity : bagQuantity // ignore: cast_nullable_to_non_nullable
as int,luckyResult: freezed == luckyResult ? _self.luckyResult : luckyResult // ignore: cast_nullable_to_non_nullable
as LuckyGiftResult?,quip: freezed == quip ? _self.quip : quip // ignore: cast_nullable_to_non_nullable
as LiveQuip?,
  ));
}

/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveGiftCopyWith<$Res> get gift {
  
  return $LiveGiftCopyWith<$Res>(_self.gift, (value) {
    return _then(_self.copyWith(gift: value));
  });
}/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyGiftResultCopyWith<$Res>? get luckyResult {
    if (_self.luckyResult == null) {
    return null;
  }

  return $LuckyGiftResultCopyWith<$Res>(_self.luckyResult!, (value) {
    return _then(_self.copyWith(luckyResult: value));
  });
}/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveQuipCopyWith<$Res>? get quip {
    if (_self.quip == null) {
    return null;
  }

  return $LiveQuipCopyWith<$Res>(_self.quip!, (value) {
    return _then(_self.copyWith(quip: value));
  });
}
}


/// @nodoc
mixin _$LiveQuip {

 String get id; String get roomId;@JsonKey(unknownEnumValue: LiveQuipKind.gift) LiveQuipKind get kind; String get giftCode; String get soundKey; int get durationMs; bool get free; UserSummary get sender; int get delayMs; DateTime get createdAt; String? get text;
/// Create a copy of LiveQuip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveQuipCopyWith<LiveQuip> get copyWith => _$LiveQuipCopyWithImpl<LiveQuip>(this as LiveQuip, _$identity);

  /// Serializes this LiveQuip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveQuip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveQuip&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.giftCode, _this.giftCode) || other.giftCode == _this.giftCode)&&(identical(other.soundKey, _this.soundKey) || other.soundKey == _this.soundKey)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.free, _this.free) || other.free == _this.free)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&(identical(other.delayMs, _this.delayMs) || other.delayMs == _this.delayMs)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveQuip;
  return Object.hash(runtimeType,_this.id,_this.roomId,_this.kind,_this.giftCode,_this.soundKey,_this.durationMs,_this.free,_this.sender,_this.delayMs,_this.createdAt,_this.text);
}

@override
String toString() {
  final _this = this as LiveQuip;
  return 'LiveQuip(id: ${_this.id}, roomId: ${_this.roomId}, kind: ${_this.kind}, giftCode: ${_this.giftCode}, soundKey: ${_this.soundKey}, durationMs: ${_this.durationMs}, free: ${_this.free}, sender: ${_this.sender}, delayMs: ${_this.delayMs}, createdAt: ${_this.createdAt}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $LiveQuipCopyWith<$Res>  {
  factory $LiveQuipCopyWith(LiveQuip value, $Res Function(LiveQuip) _then) = _$LiveQuipCopyWithImpl;
@useResult
$Res call({
 String id, String roomId,@JsonKey(unknownEnumValue: LiveQuipKind.gift) LiveQuipKind kind, String giftCode, String soundKey, int durationMs, bool free, UserSummary sender, int delayMs, DateTime createdAt, String? text
});


$UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class _$LiveQuipCopyWithImpl<$Res>
    implements $LiveQuipCopyWith<$Res> {
  _$LiveQuipCopyWithImpl(this._self, this._then);

  final LiveQuip _self;
  final $Res Function(LiveQuip) _then;

/// Create a copy of LiveQuip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? kind = null,Object? giftCode = null,Object? soundKey = null,Object? durationMs = null,Object? free = null,Object? sender = null,Object? delayMs = null,Object? createdAt = null,Object? text = freezed,}) {
  return _then(LiveQuip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveQuipKind,giftCode: null == giftCode ? _self.giftCode : giftCode // ignore: cast_nullable_to_non_nullable
as String,soundKey: null == soundKey ? _self.soundKey : soundKey // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,free: null == free ? _self.free : free // ignore: cast_nullable_to_non_nullable
as bool,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,delayMs: null == delayMs ? _self.delayMs : delayMs // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of LiveQuip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveQuip].
extension LiveQuipPatterns on LiveQuip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveQuip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveQuip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveQuip value)  $default,){
final _that = this;
switch (_that) {
case _LiveQuip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveQuip value)?  $default,){
final _that = this;
switch (_that) {
case _LiveQuip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId, @JsonKey(unknownEnumValue: LiveQuipKind.gift)  LiveQuipKind kind,  String giftCode,  String soundKey,  int durationMs,  bool free,  UserSummary sender,  int delayMs,  DateTime createdAt,  String? text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveQuip() when $default != null:
return $default(_that.id,_that.roomId,_that.kind,_that.giftCode,_that.soundKey,_that.durationMs,_that.free,_that.sender,_that.delayMs,_that.createdAt,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId, @JsonKey(unknownEnumValue: LiveQuipKind.gift)  LiveQuipKind kind,  String giftCode,  String soundKey,  int durationMs,  bool free,  UserSummary sender,  int delayMs,  DateTime createdAt,  String? text)  $default,) {final _that = this;
switch (_that) {
case _LiveQuip():
return $default(_that.id,_that.roomId,_that.kind,_that.giftCode,_that.soundKey,_that.durationMs,_that.free,_that.sender,_that.delayMs,_that.createdAt,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId, @JsonKey(unknownEnumValue: LiveQuipKind.gift)  LiveQuipKind kind,  String giftCode,  String soundKey,  int durationMs,  bool free,  UserSummary sender,  int delayMs,  DateTime createdAt,  String? text)?  $default,) {final _that = this;
switch (_that) {
case _LiveQuip() when $default != null:
return $default(_that.id,_that.roomId,_that.kind,_that.giftCode,_that.soundKey,_that.durationMs,_that.free,_that.sender,_that.delayMs,_that.createdAt,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveQuip implements LiveQuip {
  const _LiveQuip({required this.id, required this.roomId, @JsonKey(unknownEnumValue: LiveQuipKind.gift) required this.kind, required this.giftCode, required this.soundKey, required this.durationMs, required this.free, required this.sender, required this.delayMs, required this.createdAt, this.text});
  factory _LiveQuip.fromJson(Map<String, dynamic> json) => _$LiveQuipFromJson(json);

@override final  String id;
@override final  String roomId;
@override@JsonKey(unknownEnumValue: LiveQuipKind.gift) final  LiveQuipKind kind;
@override final  String giftCode;
@override final  String soundKey;
@override final  int durationMs;
@override final  bool free;
@override final  UserSummary sender;
@override final  int delayMs;
@override final  DateTime createdAt;
@override final  String? text;

/// Create a copy of LiveQuip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveQuipCopyWith<_LiveQuip> get copyWith => __$LiveQuipCopyWithImpl<_LiveQuip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveQuipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveQuip&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.giftCode, giftCode) || other.giftCode == giftCode)&&(identical(other.soundKey, soundKey) || other.soundKey == soundKey)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.free, free) || other.free == free)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.delayMs, delayMs) || other.delayMs == delayMs)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,roomId,kind,giftCode,soundKey,durationMs,free,sender,delayMs,createdAt,text);
}

@override
String toString() {
    return 'LiveQuip(id: $id, roomId: $roomId, kind: $kind, giftCode: $giftCode, soundKey: $soundKey, durationMs: $durationMs, free: $free, sender: $sender, delayMs: $delayMs, createdAt: $createdAt, text: $text)';
}


}

/// @nodoc
abstract mixin class _$LiveQuipCopyWith<$Res> implements $LiveQuipCopyWith<$Res> {
  factory _$LiveQuipCopyWith(_LiveQuip value, $Res Function(_LiveQuip) _then) = __$LiveQuipCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId,@JsonKey(unknownEnumValue: LiveQuipKind.gift) LiveQuipKind kind, String giftCode, String soundKey, int durationMs, bool free, UserSummary sender, int delayMs, DateTime createdAt, String? text
});


@override $UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class __$LiveQuipCopyWithImpl<$Res>
    implements _$LiveQuipCopyWith<$Res> {
  __$LiveQuipCopyWithImpl(this._self, this._then);

  final _LiveQuip _self;
  final $Res Function(_LiveQuip) _then;

/// Create a copy of LiveQuip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? kind = null,Object? giftCode = null,Object? soundKey = null,Object? durationMs = null,Object? free = null,Object? sender = null,Object? delayMs = null,Object? createdAt = null,Object? text = freezed,}) {
  return _then(_LiveQuip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveQuipKind,giftCode: null == giftCode ? _self.giftCode : giftCode // ignore: cast_nullable_to_non_nullable
as String,soundKey: null == soundKey ? _self.soundKey : soundKey // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,free: null == free ? _self.free : free // ignore: cast_nullable_to_non_nullable
as bool,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,delayMs: null == delayMs ? _self.delayMs : delayMs // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of LiveQuip
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}


/// @nodoc
mixin _$LuckyGiftWin {

 int get multiplier; int get count; int get coins;
/// Create a copy of LuckyGiftWin
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyGiftWinCopyWith<LuckyGiftWin> get copyWith => _$LuckyGiftWinCopyWithImpl<LuckyGiftWin>(this as LuckyGiftWin, _$identity);

  /// Serializes this LuckyGiftWin to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyGiftWin;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyGiftWin&&(identical(other.multiplier, _this.multiplier) || other.multiplier == _this.multiplier)&&(identical(other.count, _this.count) || other.count == _this.count)&&(identical(other.coins, _this.coins) || other.coins == _this.coins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyGiftWin;
  return Object.hash(runtimeType,_this.multiplier,_this.count,_this.coins);
}

@override
String toString() {
  final _this = this as LuckyGiftWin;
  return 'LuckyGiftWin(multiplier: ${_this.multiplier}, count: ${_this.count}, coins: ${_this.coins})';
}


}

/// @nodoc
abstract mixin class $LuckyGiftWinCopyWith<$Res>  {
  factory $LuckyGiftWinCopyWith(LuckyGiftWin value, $Res Function(LuckyGiftWin) _then) = _$LuckyGiftWinCopyWithImpl;
@useResult
$Res call({
 int multiplier, int count, int coins
});




}
/// @nodoc
class _$LuckyGiftWinCopyWithImpl<$Res>
    implements $LuckyGiftWinCopyWith<$Res> {
  _$LuckyGiftWinCopyWithImpl(this._self, this._then);

  final LuckyGiftWin _self;
  final $Res Function(LuckyGiftWin) _then;

/// Create a copy of LuckyGiftWin
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? multiplier = null,Object? count = null,Object? coins = null,}) {
  return _then(LuckyGiftWin(
multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LuckyGiftWin].
extension LuckyGiftWinPatterns on LuckyGiftWin {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyGiftWin value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyGiftWin() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyGiftWin value)  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftWin():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyGiftWin value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftWin() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int multiplier,  int count,  int coins)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyGiftWin() when $default != null:
return $default(_that.multiplier,_that.count,_that.coins);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int multiplier,  int count,  int coins)  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftWin():
return $default(_that.multiplier,_that.count,_that.coins);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int multiplier,  int count,  int coins)?  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftWin() when $default != null:
return $default(_that.multiplier,_that.count,_that.coins);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyGiftWin implements LuckyGiftWin {
  const _LuckyGiftWin({required this.multiplier, required this.count, required this.coins});
  factory _LuckyGiftWin.fromJson(Map<String, dynamic> json) => _$LuckyGiftWinFromJson(json);

@override final  int multiplier;
@override final  int count;
@override final  int coins;

/// Create a copy of LuckyGiftWin
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyGiftWinCopyWith<_LuckyGiftWin> get copyWith => __$LuckyGiftWinCopyWithImpl<_LuckyGiftWin>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyGiftWinToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyGiftWin&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.count, count) || other.count == count)&&(identical(other.coins, coins) || other.coins == coins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,multiplier,count,coins);
}

@override
String toString() {
    return 'LuckyGiftWin(multiplier: $multiplier, count: $count, coins: $coins)';
}


}

/// @nodoc
abstract mixin class _$LuckyGiftWinCopyWith<$Res> implements $LuckyGiftWinCopyWith<$Res> {
  factory _$LuckyGiftWinCopyWith(_LuckyGiftWin value, $Res Function(_LuckyGiftWin) _then) = __$LuckyGiftWinCopyWithImpl;
@override @useResult
$Res call({
 int multiplier, int count, int coins
});




}
/// @nodoc
class __$LuckyGiftWinCopyWithImpl<$Res>
    implements _$LuckyGiftWinCopyWith<$Res> {
  __$LuckyGiftWinCopyWithImpl(this._self, this._then);

  final _LuckyGiftWin _self;
  final $Res Function(_LuckyGiftWin) _then;

/// Create a copy of LuckyGiftWin
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? multiplier = null,Object? count = null,Object? coins = null,}) {
  return _then(_LuckyGiftWin(
multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LuckyGiftResult {

 int get draws; List<LuckyGiftWin> get wins; int get coinsWon; int? get topMultiplier; int get downgraded;/// v1.30-live (D148): a draw of this send was paid by the guarantee
/// (×5 after 15 losing draws in a row); the celebration says «ضمان».
/// Absent from older servers.
 bool get guaranteed;
/// Create a copy of LuckyGiftResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyGiftResultCopyWith<LuckyGiftResult> get copyWith => _$LuckyGiftResultCopyWithImpl<LuckyGiftResult>(this as LuckyGiftResult, _$identity);

  /// Serializes this LuckyGiftResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyGiftResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyGiftResult&&(identical(other.draws, _this.draws) || other.draws == _this.draws)&&const DeepCollectionEquality().equals(other.wins, _this.wins)&&(identical(other.coinsWon, _this.coinsWon) || other.coinsWon == _this.coinsWon)&&(identical(other.topMultiplier, _this.topMultiplier) || other.topMultiplier == _this.topMultiplier)&&(identical(other.downgraded, _this.downgraded) || other.downgraded == _this.downgraded)&&(identical(other.guaranteed, _this.guaranteed) || other.guaranteed == _this.guaranteed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyGiftResult;
  return Object.hash(runtimeType,_this.draws,const DeepCollectionEquality().hash(_this.wins),_this.coinsWon,_this.topMultiplier,_this.downgraded,_this.guaranteed);
}

@override
String toString() {
  final _this = this as LuckyGiftResult;
  return 'LuckyGiftResult(draws: ${_this.draws}, wins: ${_this.wins}, coinsWon: ${_this.coinsWon}, topMultiplier: ${_this.topMultiplier}, downgraded: ${_this.downgraded}, guaranteed: ${_this.guaranteed})';
}


}

/// @nodoc
abstract mixin class $LuckyGiftResultCopyWith<$Res>  {
  factory $LuckyGiftResultCopyWith(LuckyGiftResult value, $Res Function(LuckyGiftResult) _then) = _$LuckyGiftResultCopyWithImpl;
@useResult
$Res call({
 int draws, List<LuckyGiftWin> wins, int coinsWon, int? topMultiplier, int downgraded, bool guaranteed
});




}
/// @nodoc
class _$LuckyGiftResultCopyWithImpl<$Res>
    implements $LuckyGiftResultCopyWith<$Res> {
  _$LuckyGiftResultCopyWithImpl(this._self, this._then);

  final LuckyGiftResult _self;
  final $Res Function(LuckyGiftResult) _then;

/// Create a copy of LuckyGiftResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? draws = null,Object? wins = null,Object? coinsWon = null,Object? topMultiplier = freezed,Object? downgraded = null,Object? guaranteed = null,}) {
  return _then(LuckyGiftResult(
draws: null == draws ? _self.draws : draws // ignore: cast_nullable_to_non_nullable
as int,wins: null == wins ? _self.wins : wins // ignore: cast_nullable_to_non_nullable
as List<LuckyGiftWin>,coinsWon: null == coinsWon ? _self.coinsWon : coinsWon // ignore: cast_nullable_to_non_nullable
as int,topMultiplier: freezed == topMultiplier ? _self.topMultiplier : topMultiplier // ignore: cast_nullable_to_non_nullable
as int?,downgraded: null == downgraded ? _self.downgraded : downgraded // ignore: cast_nullable_to_non_nullable
as int,guaranteed: null == guaranteed ? _self.guaranteed : guaranteed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LuckyGiftResult].
extension LuckyGiftResultPatterns on LuckyGiftResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyGiftResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyGiftResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyGiftResult value)  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyGiftResult value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int draws,  List<LuckyGiftWin> wins,  int coinsWon,  int? topMultiplier,  int downgraded,  bool guaranteed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyGiftResult() when $default != null:
return $default(_that.draws,_that.wins,_that.coinsWon,_that.topMultiplier,_that.downgraded,_that.guaranteed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int draws,  List<LuckyGiftWin> wins,  int coinsWon,  int? topMultiplier,  int downgraded,  bool guaranteed)  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftResult():
return $default(_that.draws,_that.wins,_that.coinsWon,_that.topMultiplier,_that.downgraded,_that.guaranteed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int draws,  List<LuckyGiftWin> wins,  int coinsWon,  int? topMultiplier,  int downgraded,  bool guaranteed)?  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftResult() when $default != null:
return $default(_that.draws,_that.wins,_that.coinsWon,_that.topMultiplier,_that.downgraded,_that.guaranteed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyGiftResult implements LuckyGiftResult {
  const _LuckyGiftResult({required this.draws, required  List<LuckyGiftWin> wins, required this.coinsWon, required this.topMultiplier, required this.downgraded, this.guaranteed = false}): _wins = wins;
  factory _LuckyGiftResult.fromJson(Map<String, dynamic> json) => _$LuckyGiftResultFromJson(json);

@override final  int draws;
 final  List<LuckyGiftWin> _wins;
@override List<LuckyGiftWin> get wins {
  if (_wins is EqualUnmodifiableListView) return _wins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_wins);
}

@override final  int coinsWon;
@override final  int? topMultiplier;
@override final  int downgraded;
/// v1.30-live (D148): a draw of this send was paid by the guarantee
/// (×5 after 15 losing draws in a row); the celebration says «ضمان».
/// Absent from older servers.
@override@JsonKey() final  bool guaranteed;

/// Create a copy of LuckyGiftResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyGiftResultCopyWith<_LuckyGiftResult> get copyWith => __$LuckyGiftResultCopyWithImpl<_LuckyGiftResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyGiftResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyGiftResult&&(identical(other.draws, draws) || other.draws == draws)&&const DeepCollectionEquality().equals(other.wins, _wins)&&(identical(other.coinsWon, coinsWon) || other.coinsWon == coinsWon)&&(identical(other.topMultiplier, topMultiplier) || other.topMultiplier == topMultiplier)&&(identical(other.downgraded, downgraded) || other.downgraded == downgraded)&&(identical(other.guaranteed, guaranteed) || other.guaranteed == guaranteed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,draws,const DeepCollectionEquality().hash(_wins),coinsWon,topMultiplier,downgraded,guaranteed);
}

@override
String toString() {
    return 'LuckyGiftResult(draws: $draws, wins: $wins, coinsWon: $coinsWon, topMultiplier: $topMultiplier, downgraded: $downgraded, guaranteed: $guaranteed)';
}


}

/// @nodoc
abstract mixin class _$LuckyGiftResultCopyWith<$Res> implements $LuckyGiftResultCopyWith<$Res> {
  factory _$LuckyGiftResultCopyWith(_LuckyGiftResult value, $Res Function(_LuckyGiftResult) _then) = __$LuckyGiftResultCopyWithImpl;
@override @useResult
$Res call({
 int draws, List<LuckyGiftWin> wins, int coinsWon, int? topMultiplier, int downgraded, bool guaranteed
});




}
/// @nodoc
class __$LuckyGiftResultCopyWithImpl<$Res>
    implements _$LuckyGiftResultCopyWith<$Res> {
  __$LuckyGiftResultCopyWithImpl(this._self, this._then);

  final _LuckyGiftResult _self;
  final $Res Function(_LuckyGiftResult) _then;

/// Create a copy of LuckyGiftResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? draws = null,Object? wins = null,Object? coinsWon = null,Object? topMultiplier = freezed,Object? downgraded = null,Object? guaranteed = null,}) {
  return _then(_LuckyGiftResult(
draws: null == draws ? _self.draws : draws // ignore: cast_nullable_to_non_nullable
as int,wins: null == wins ? _self._wins : wins // ignore: cast_nullable_to_non_nullable
as List<LuckyGiftWin>,coinsWon: null == coinsWon ? _self.coinsWon : coinsWon // ignore: cast_nullable_to_non_nullable
as int,topMultiplier: freezed == topMultiplier ? _self.topMultiplier : topMultiplier // ignore: cast_nullable_to_non_nullable
as int?,downgraded: null == downgraded ? _self.downgraded : downgraded // ignore: cast_nullable_to_non_nullable
as int,guaranteed: null == guaranteed ? _self.guaranteed : guaranteed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LuckyGiftOutcome {

 int get multiplier; int get chancePerMillion; double get probability;
/// Create a copy of LuckyGiftOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyGiftOutcomeCopyWith<LuckyGiftOutcome> get copyWith => _$LuckyGiftOutcomeCopyWithImpl<LuckyGiftOutcome>(this as LuckyGiftOutcome, _$identity);

  /// Serializes this LuckyGiftOutcome to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyGiftOutcome;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyGiftOutcome&&(identical(other.multiplier, _this.multiplier) || other.multiplier == _this.multiplier)&&(identical(other.chancePerMillion, _this.chancePerMillion) || other.chancePerMillion == _this.chancePerMillion)&&(identical(other.probability, _this.probability) || other.probability == _this.probability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyGiftOutcome;
  return Object.hash(runtimeType,_this.multiplier,_this.chancePerMillion,_this.probability);
}

@override
String toString() {
  final _this = this as LuckyGiftOutcome;
  return 'LuckyGiftOutcome(multiplier: ${_this.multiplier}, chancePerMillion: ${_this.chancePerMillion}, probability: ${_this.probability})';
}


}

/// @nodoc
abstract mixin class $LuckyGiftOutcomeCopyWith<$Res>  {
  factory $LuckyGiftOutcomeCopyWith(LuckyGiftOutcome value, $Res Function(LuckyGiftOutcome) _then) = _$LuckyGiftOutcomeCopyWithImpl;
@useResult
$Res call({
 int multiplier, int chancePerMillion, double probability
});




}
/// @nodoc
class _$LuckyGiftOutcomeCopyWithImpl<$Res>
    implements $LuckyGiftOutcomeCopyWith<$Res> {
  _$LuckyGiftOutcomeCopyWithImpl(this._self, this._then);

  final LuckyGiftOutcome _self;
  final $Res Function(LuckyGiftOutcome) _then;

/// Create a copy of LuckyGiftOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? multiplier = null,Object? chancePerMillion = null,Object? probability = null,}) {
  return _then(LuckyGiftOutcome(
multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,chancePerMillion: null == chancePerMillion ? _self.chancePerMillion : chancePerMillion // ignore: cast_nullable_to_non_nullable
as int,probability: null == probability ? _self.probability : probability // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LuckyGiftOutcome].
extension LuckyGiftOutcomePatterns on LuckyGiftOutcome {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyGiftOutcome value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyGiftOutcome() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyGiftOutcome value)  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftOutcome():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyGiftOutcome value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftOutcome() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int multiplier,  int chancePerMillion,  double probability)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyGiftOutcome() when $default != null:
return $default(_that.multiplier,_that.chancePerMillion,_that.probability);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int multiplier,  int chancePerMillion,  double probability)  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftOutcome():
return $default(_that.multiplier,_that.chancePerMillion,_that.probability);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int multiplier,  int chancePerMillion,  double probability)?  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftOutcome() when $default != null:
return $default(_that.multiplier,_that.chancePerMillion,_that.probability);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyGiftOutcome implements LuckyGiftOutcome {
  const _LuckyGiftOutcome({required this.multiplier, required this.chancePerMillion, required this.probability});
  factory _LuckyGiftOutcome.fromJson(Map<String, dynamic> json) => _$LuckyGiftOutcomeFromJson(json);

@override final  int multiplier;
@override final  int chancePerMillion;
@override final  double probability;

/// Create a copy of LuckyGiftOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyGiftOutcomeCopyWith<_LuckyGiftOutcome> get copyWith => __$LuckyGiftOutcomeCopyWithImpl<_LuckyGiftOutcome>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyGiftOutcomeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyGiftOutcome&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.chancePerMillion, chancePerMillion) || other.chancePerMillion == chancePerMillion)&&(identical(other.probability, probability) || other.probability == probability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,multiplier,chancePerMillion,probability);
}

@override
String toString() {
    return 'LuckyGiftOutcome(multiplier: $multiplier, chancePerMillion: $chancePerMillion, probability: $probability)';
}


}

/// @nodoc
abstract mixin class _$LuckyGiftOutcomeCopyWith<$Res> implements $LuckyGiftOutcomeCopyWith<$Res> {
  factory _$LuckyGiftOutcomeCopyWith(_LuckyGiftOutcome value, $Res Function(_LuckyGiftOutcome) _then) = __$LuckyGiftOutcomeCopyWithImpl;
@override @useResult
$Res call({
 int multiplier, int chancePerMillion, double probability
});




}
/// @nodoc
class __$LuckyGiftOutcomeCopyWithImpl<$Res>
    implements _$LuckyGiftOutcomeCopyWith<$Res> {
  __$LuckyGiftOutcomeCopyWithImpl(this._self, this._then);

  final _LuckyGiftOutcome _self;
  final $Res Function(_LuckyGiftOutcome) _then;

/// Create a copy of LuckyGiftOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? multiplier = null,Object? chancePerMillion = null,Object? probability = null,}) {
  return _then(_LuckyGiftOutcome(
multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,chancePerMillion: null == chancePerMillion ? _self.chancePerMillion : chancePerMillion // ignore: cast_nullable_to_non_nullable
as int,probability: null == probability ? _self.probability : probability // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$LuckyGiftEligibility {

 bool get eligible;@JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown) LuckyGiftIneligibility? get reason; bool get ageConfirmed;
/// Create a copy of LuckyGiftEligibility
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyGiftEligibilityCopyWith<LuckyGiftEligibility> get copyWith => _$LuckyGiftEligibilityCopyWithImpl<LuckyGiftEligibility>(this as LuckyGiftEligibility, _$identity);

  /// Serializes this LuckyGiftEligibility to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyGiftEligibility;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyGiftEligibility&&(identical(other.eligible, _this.eligible) || other.eligible == _this.eligible)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.ageConfirmed, _this.ageConfirmed) || other.ageConfirmed == _this.ageConfirmed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyGiftEligibility;
  return Object.hash(runtimeType,_this.eligible,_this.reason,_this.ageConfirmed);
}

@override
String toString() {
  final _this = this as LuckyGiftEligibility;
  return 'LuckyGiftEligibility(eligible: ${_this.eligible}, reason: ${_this.reason}, ageConfirmed: ${_this.ageConfirmed})';
}


}

/// @nodoc
abstract mixin class $LuckyGiftEligibilityCopyWith<$Res>  {
  factory $LuckyGiftEligibilityCopyWith(LuckyGiftEligibility value, $Res Function(LuckyGiftEligibility) _then) = _$LuckyGiftEligibilityCopyWithImpl;
@useResult
$Res call({
 bool eligible,@JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown) LuckyGiftIneligibility? reason, bool ageConfirmed
});




}
/// @nodoc
class _$LuckyGiftEligibilityCopyWithImpl<$Res>
    implements $LuckyGiftEligibilityCopyWith<$Res> {
  _$LuckyGiftEligibilityCopyWithImpl(this._self, this._then);

  final LuckyGiftEligibility _self;
  final $Res Function(LuckyGiftEligibility) _then;

/// Create a copy of LuckyGiftEligibility
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eligible = null,Object? reason = freezed,Object? ageConfirmed = null,}) {
  return _then(LuckyGiftEligibility(
eligible: null == eligible ? _self.eligible : eligible // ignore: cast_nullable_to_non_nullable
as bool,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as LuckyGiftIneligibility?,ageConfirmed: null == ageConfirmed ? _self.ageConfirmed : ageConfirmed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LuckyGiftEligibility].
extension LuckyGiftEligibilityPatterns on LuckyGiftEligibility {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyGiftEligibility value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyGiftEligibility() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyGiftEligibility value)  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftEligibility():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyGiftEligibility value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftEligibility() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool eligible, @JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown)  LuckyGiftIneligibility? reason,  bool ageConfirmed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyGiftEligibility() when $default != null:
return $default(_that.eligible,_that.reason,_that.ageConfirmed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool eligible, @JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown)  LuckyGiftIneligibility? reason,  bool ageConfirmed)  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftEligibility():
return $default(_that.eligible,_that.reason,_that.ageConfirmed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool eligible, @JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown)  LuckyGiftIneligibility? reason,  bool ageConfirmed)?  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftEligibility() when $default != null:
return $default(_that.eligible,_that.reason,_that.ageConfirmed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyGiftEligibility implements LuckyGiftEligibility {
  const _LuckyGiftEligibility({required this.eligible, @JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown) required this.reason, required this.ageConfirmed});
  factory _LuckyGiftEligibility.fromJson(Map<String, dynamic> json) => _$LuckyGiftEligibilityFromJson(json);

@override final  bool eligible;
@override@JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown) final  LuckyGiftIneligibility? reason;
@override final  bool ageConfirmed;

/// Create a copy of LuckyGiftEligibility
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyGiftEligibilityCopyWith<_LuckyGiftEligibility> get copyWith => __$LuckyGiftEligibilityCopyWithImpl<_LuckyGiftEligibility>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyGiftEligibilityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyGiftEligibility&&(identical(other.eligible, eligible) || other.eligible == eligible)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.ageConfirmed, ageConfirmed) || other.ageConfirmed == ageConfirmed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,eligible,reason,ageConfirmed);
}

@override
String toString() {
    return 'LuckyGiftEligibility(eligible: $eligible, reason: $reason, ageConfirmed: $ageConfirmed)';
}


}

/// @nodoc
abstract mixin class _$LuckyGiftEligibilityCopyWith<$Res> implements $LuckyGiftEligibilityCopyWith<$Res> {
  factory _$LuckyGiftEligibilityCopyWith(_LuckyGiftEligibility value, $Res Function(_LuckyGiftEligibility) _then) = __$LuckyGiftEligibilityCopyWithImpl;
@override @useResult
$Res call({
 bool eligible,@JsonKey(unknownEnumValue: LuckyGiftIneligibility.unknown) LuckyGiftIneligibility? reason, bool ageConfirmed
});




}
/// @nodoc
class __$LuckyGiftEligibilityCopyWithImpl<$Res>
    implements _$LuckyGiftEligibilityCopyWith<$Res> {
  __$LuckyGiftEligibilityCopyWithImpl(this._self, this._then);

  final _LuckyGiftEligibility _self;
  final $Res Function(_LuckyGiftEligibility) _then;

/// Create a copy of LuckyGiftEligibility
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eligible = null,Object? reason = freezed,Object? ageConfirmed = null,}) {
  return _then(_LuckyGiftEligibility(
eligible: null == eligible ? _self.eligible : eligible // ignore: cast_nullable_to_non_nullable
as bool,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as LuckyGiftIneligibility?,ageConfirmed: null == ageConfirmed ? _self.ageConfirmed : ageConfirmed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LuckyGiftOdds {

 bool get enabled; int get drawsPerGift; double get returnPercent; double get hostSharePercent; List<LuckyGiftOutcome> get outcomes; int get noWinChancePerMillion; double get noWinProbability; int get bigWinMultiplier; bool get dailyProtection; String get dayTimeZone; int get minimumAge; LuckyGiftEligibility? get caller;/// v1.30-live (D148): the per-sender guarantee; null when it is off (or
/// from an older server).
 LuckyGiftPity? get pity;
/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyGiftOddsCopyWith<LuckyGiftOdds> get copyWith => _$LuckyGiftOddsCopyWithImpl<LuckyGiftOdds>(this as LuckyGiftOdds, _$identity);

  /// Serializes this LuckyGiftOdds to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyGiftOdds;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyGiftOdds&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.drawsPerGift, _this.drawsPerGift) || other.drawsPerGift == _this.drawsPerGift)&&(identical(other.returnPercent, _this.returnPercent) || other.returnPercent == _this.returnPercent)&&(identical(other.hostSharePercent, _this.hostSharePercent) || other.hostSharePercent == _this.hostSharePercent)&&const DeepCollectionEquality().equals(other.outcomes, _this.outcomes)&&(identical(other.noWinChancePerMillion, _this.noWinChancePerMillion) || other.noWinChancePerMillion == _this.noWinChancePerMillion)&&(identical(other.noWinProbability, _this.noWinProbability) || other.noWinProbability == _this.noWinProbability)&&(identical(other.bigWinMultiplier, _this.bigWinMultiplier) || other.bigWinMultiplier == _this.bigWinMultiplier)&&(identical(other.dailyProtection, _this.dailyProtection) || other.dailyProtection == _this.dailyProtection)&&(identical(other.dayTimeZone, _this.dayTimeZone) || other.dayTimeZone == _this.dayTimeZone)&&(identical(other.minimumAge, _this.minimumAge) || other.minimumAge == _this.minimumAge)&&(identical(other.caller, _this.caller) || other.caller == _this.caller)&&(identical(other.pity, _this.pity) || other.pity == _this.pity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyGiftOdds;
  return Object.hash(runtimeType,_this.enabled,_this.drawsPerGift,_this.returnPercent,_this.hostSharePercent,const DeepCollectionEquality().hash(_this.outcomes),_this.noWinChancePerMillion,_this.noWinProbability,_this.bigWinMultiplier,_this.dailyProtection,_this.dayTimeZone,_this.minimumAge,_this.caller,_this.pity);
}

@override
String toString() {
  final _this = this as LuckyGiftOdds;
  return 'LuckyGiftOdds(enabled: ${_this.enabled}, drawsPerGift: ${_this.drawsPerGift}, returnPercent: ${_this.returnPercent}, hostSharePercent: ${_this.hostSharePercent}, outcomes: ${_this.outcomes}, noWinChancePerMillion: ${_this.noWinChancePerMillion}, noWinProbability: ${_this.noWinProbability}, bigWinMultiplier: ${_this.bigWinMultiplier}, dailyProtection: ${_this.dailyProtection}, dayTimeZone: ${_this.dayTimeZone}, minimumAge: ${_this.minimumAge}, caller: ${_this.caller}, pity: ${_this.pity})';
}


}

/// @nodoc
abstract mixin class $LuckyGiftOddsCopyWith<$Res>  {
  factory $LuckyGiftOddsCopyWith(LuckyGiftOdds value, $Res Function(LuckyGiftOdds) _then) = _$LuckyGiftOddsCopyWithImpl;
@useResult
$Res call({
 bool enabled, int drawsPerGift, double returnPercent, double hostSharePercent, List<LuckyGiftOutcome> outcomes, int noWinChancePerMillion, double noWinProbability, int bigWinMultiplier, bool dailyProtection, String dayTimeZone, int minimumAge, LuckyGiftEligibility? caller, LuckyGiftPity? pity
});


$LuckyGiftEligibilityCopyWith<$Res>? get caller;$LuckyGiftPityCopyWith<$Res>? get pity;

}
/// @nodoc
class _$LuckyGiftOddsCopyWithImpl<$Res>
    implements $LuckyGiftOddsCopyWith<$Res> {
  _$LuckyGiftOddsCopyWithImpl(this._self, this._then);

  final LuckyGiftOdds _self;
  final $Res Function(LuckyGiftOdds) _then;

/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? drawsPerGift = null,Object? returnPercent = null,Object? hostSharePercent = null,Object? outcomes = null,Object? noWinChancePerMillion = null,Object? noWinProbability = null,Object? bigWinMultiplier = null,Object? dailyProtection = null,Object? dayTimeZone = null,Object? minimumAge = null,Object? caller = freezed,Object? pity = freezed,}) {
  return _then(LuckyGiftOdds(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,drawsPerGift: null == drawsPerGift ? _self.drawsPerGift : drawsPerGift // ignore: cast_nullable_to_non_nullable
as int,returnPercent: null == returnPercent ? _self.returnPercent : returnPercent // ignore: cast_nullable_to_non_nullable
as double,hostSharePercent: null == hostSharePercent ? _self.hostSharePercent : hostSharePercent // ignore: cast_nullable_to_non_nullable
as double,outcomes: null == outcomes ? _self.outcomes : outcomes // ignore: cast_nullable_to_non_nullable
as List<LuckyGiftOutcome>,noWinChancePerMillion: null == noWinChancePerMillion ? _self.noWinChancePerMillion : noWinChancePerMillion // ignore: cast_nullable_to_non_nullable
as int,noWinProbability: null == noWinProbability ? _self.noWinProbability : noWinProbability // ignore: cast_nullable_to_non_nullable
as double,bigWinMultiplier: null == bigWinMultiplier ? _self.bigWinMultiplier : bigWinMultiplier // ignore: cast_nullable_to_non_nullable
as int,dailyProtection: null == dailyProtection ? _self.dailyProtection : dailyProtection // ignore: cast_nullable_to_non_nullable
as bool,dayTimeZone: null == dayTimeZone ? _self.dayTimeZone : dayTimeZone // ignore: cast_nullable_to_non_nullable
as String,minimumAge: null == minimumAge ? _self.minimumAge : minimumAge // ignore: cast_nullable_to_non_nullable
as int,caller: freezed == caller ? _self.caller : caller // ignore: cast_nullable_to_non_nullable
as LuckyGiftEligibility?,pity: freezed == pity ? _self.pity : pity // ignore: cast_nullable_to_non_nullable
as LuckyGiftPity?,
  ));
}
/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyGiftEligibilityCopyWith<$Res>? get caller {
    if (_self.caller == null) {
    return null;
  }

  return $LuckyGiftEligibilityCopyWith<$Res>(_self.caller!, (value) {
    return _then(_self.copyWith(caller: value));
  });
}/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyGiftPityCopyWith<$Res>? get pity {
    if (_self.pity == null) {
    return null;
  }

  return $LuckyGiftPityCopyWith<$Res>(_self.pity!, (value) {
    return _then(_self.copyWith(pity: value));
  });
}
}


/// Adds pattern-matching-related methods to [LuckyGiftOdds].
extension LuckyGiftOddsPatterns on LuckyGiftOdds {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyGiftOdds value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyGiftOdds() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyGiftOdds value)  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftOdds():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyGiftOdds value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftOdds() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  int drawsPerGift,  double returnPercent,  double hostSharePercent,  List<LuckyGiftOutcome> outcomes,  int noWinChancePerMillion,  double noWinProbability,  int bigWinMultiplier,  bool dailyProtection,  String dayTimeZone,  int minimumAge,  LuckyGiftEligibility? caller,  LuckyGiftPity? pity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyGiftOdds() when $default != null:
return $default(_that.enabled,_that.drawsPerGift,_that.returnPercent,_that.hostSharePercent,_that.outcomes,_that.noWinChancePerMillion,_that.noWinProbability,_that.bigWinMultiplier,_that.dailyProtection,_that.dayTimeZone,_that.minimumAge,_that.caller,_that.pity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  int drawsPerGift,  double returnPercent,  double hostSharePercent,  List<LuckyGiftOutcome> outcomes,  int noWinChancePerMillion,  double noWinProbability,  int bigWinMultiplier,  bool dailyProtection,  String dayTimeZone,  int minimumAge,  LuckyGiftEligibility? caller,  LuckyGiftPity? pity)  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftOdds():
return $default(_that.enabled,_that.drawsPerGift,_that.returnPercent,_that.hostSharePercent,_that.outcomes,_that.noWinChancePerMillion,_that.noWinProbability,_that.bigWinMultiplier,_that.dailyProtection,_that.dayTimeZone,_that.minimumAge,_that.caller,_that.pity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  int drawsPerGift,  double returnPercent,  double hostSharePercent,  List<LuckyGiftOutcome> outcomes,  int noWinChancePerMillion,  double noWinProbability,  int bigWinMultiplier,  bool dailyProtection,  String dayTimeZone,  int minimumAge,  LuckyGiftEligibility? caller,  LuckyGiftPity? pity)?  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftOdds() when $default != null:
return $default(_that.enabled,_that.drawsPerGift,_that.returnPercent,_that.hostSharePercent,_that.outcomes,_that.noWinChancePerMillion,_that.noWinProbability,_that.bigWinMultiplier,_that.dailyProtection,_that.dayTimeZone,_that.minimumAge,_that.caller,_that.pity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyGiftOdds implements LuckyGiftOdds {
  const _LuckyGiftOdds({required this.enabled, required this.drawsPerGift, required this.returnPercent, required this.hostSharePercent, required  List<LuckyGiftOutcome> outcomes, required this.noWinChancePerMillion, required this.noWinProbability, required this.bigWinMultiplier, required this.dailyProtection, required this.dayTimeZone, required this.minimumAge, required this.caller, this.pity}): _outcomes = outcomes;
  factory _LuckyGiftOdds.fromJson(Map<String, dynamic> json) => _$LuckyGiftOddsFromJson(json);

@override final  bool enabled;
@override final  int drawsPerGift;
@override final  double returnPercent;
@override final  double hostSharePercent;
 final  List<LuckyGiftOutcome> _outcomes;
@override List<LuckyGiftOutcome> get outcomes {
  if (_outcomes is EqualUnmodifiableListView) return _outcomes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_outcomes);
}

@override final  int noWinChancePerMillion;
@override final  double noWinProbability;
@override final  int bigWinMultiplier;
@override final  bool dailyProtection;
@override final  String dayTimeZone;
@override final  int minimumAge;
@override final  LuckyGiftEligibility? caller;
/// v1.30-live (D148): the per-sender guarantee; null when it is off (or
/// from an older server).
@override final  LuckyGiftPity? pity;

/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyGiftOddsCopyWith<_LuckyGiftOdds> get copyWith => __$LuckyGiftOddsCopyWithImpl<_LuckyGiftOdds>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyGiftOddsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyGiftOdds&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.drawsPerGift, drawsPerGift) || other.drawsPerGift == drawsPerGift)&&(identical(other.returnPercent, returnPercent) || other.returnPercent == returnPercent)&&(identical(other.hostSharePercent, hostSharePercent) || other.hostSharePercent == hostSharePercent)&&const DeepCollectionEquality().equals(other.outcomes, _outcomes)&&(identical(other.noWinChancePerMillion, noWinChancePerMillion) || other.noWinChancePerMillion == noWinChancePerMillion)&&(identical(other.noWinProbability, noWinProbability) || other.noWinProbability == noWinProbability)&&(identical(other.bigWinMultiplier, bigWinMultiplier) || other.bigWinMultiplier == bigWinMultiplier)&&(identical(other.dailyProtection, dailyProtection) || other.dailyProtection == dailyProtection)&&(identical(other.dayTimeZone, dayTimeZone) || other.dayTimeZone == dayTimeZone)&&(identical(other.minimumAge, minimumAge) || other.minimumAge == minimumAge)&&(identical(other.caller, caller) || other.caller == caller)&&(identical(other.pity, pity) || other.pity == pity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enabled,drawsPerGift,returnPercent,hostSharePercent,const DeepCollectionEquality().hash(_outcomes),noWinChancePerMillion,noWinProbability,bigWinMultiplier,dailyProtection,dayTimeZone,minimumAge,caller,pity);
}

@override
String toString() {
    return 'LuckyGiftOdds(enabled: $enabled, drawsPerGift: $drawsPerGift, returnPercent: $returnPercent, hostSharePercent: $hostSharePercent, outcomes: $outcomes, noWinChancePerMillion: $noWinChancePerMillion, noWinProbability: $noWinProbability, bigWinMultiplier: $bigWinMultiplier, dailyProtection: $dailyProtection, dayTimeZone: $dayTimeZone, minimumAge: $minimumAge, caller: $caller, pity: $pity)';
}


}

/// @nodoc
abstract mixin class _$LuckyGiftOddsCopyWith<$Res> implements $LuckyGiftOddsCopyWith<$Res> {
  factory _$LuckyGiftOddsCopyWith(_LuckyGiftOdds value, $Res Function(_LuckyGiftOdds) _then) = __$LuckyGiftOddsCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, int drawsPerGift, double returnPercent, double hostSharePercent, List<LuckyGiftOutcome> outcomes, int noWinChancePerMillion, double noWinProbability, int bigWinMultiplier, bool dailyProtection, String dayTimeZone, int minimumAge, LuckyGiftEligibility? caller, LuckyGiftPity? pity
});


@override $LuckyGiftEligibilityCopyWith<$Res>? get caller;@override $LuckyGiftPityCopyWith<$Res>? get pity;

}
/// @nodoc
class __$LuckyGiftOddsCopyWithImpl<$Res>
    implements _$LuckyGiftOddsCopyWith<$Res> {
  __$LuckyGiftOddsCopyWithImpl(this._self, this._then);

  final _LuckyGiftOdds _self;
  final $Res Function(_LuckyGiftOdds) _then;

/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? drawsPerGift = null,Object? returnPercent = null,Object? hostSharePercent = null,Object? outcomes = null,Object? noWinChancePerMillion = null,Object? noWinProbability = null,Object? bigWinMultiplier = null,Object? dailyProtection = null,Object? dayTimeZone = null,Object? minimumAge = null,Object? caller = freezed,Object? pity = freezed,}) {
  return _then(_LuckyGiftOdds(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,drawsPerGift: null == drawsPerGift ? _self.drawsPerGift : drawsPerGift // ignore: cast_nullable_to_non_nullable
as int,returnPercent: null == returnPercent ? _self.returnPercent : returnPercent // ignore: cast_nullable_to_non_nullable
as double,hostSharePercent: null == hostSharePercent ? _self.hostSharePercent : hostSharePercent // ignore: cast_nullable_to_non_nullable
as double,outcomes: null == outcomes ? _self._outcomes : outcomes // ignore: cast_nullable_to_non_nullable
as List<LuckyGiftOutcome>,noWinChancePerMillion: null == noWinChancePerMillion ? _self.noWinChancePerMillion : noWinChancePerMillion // ignore: cast_nullable_to_non_nullable
as int,noWinProbability: null == noWinProbability ? _self.noWinProbability : noWinProbability // ignore: cast_nullable_to_non_nullable
as double,bigWinMultiplier: null == bigWinMultiplier ? _self.bigWinMultiplier : bigWinMultiplier // ignore: cast_nullable_to_non_nullable
as int,dailyProtection: null == dailyProtection ? _self.dailyProtection : dailyProtection // ignore: cast_nullable_to_non_nullable
as bool,dayTimeZone: null == dayTimeZone ? _self.dayTimeZone : dayTimeZone // ignore: cast_nullable_to_non_nullable
as String,minimumAge: null == minimumAge ? _self.minimumAge : minimumAge // ignore: cast_nullable_to_non_nullable
as int,caller: freezed == caller ? _self.caller : caller // ignore: cast_nullable_to_non_nullable
as LuckyGiftEligibility?,pity: freezed == pity ? _self.pity : pity // ignore: cast_nullable_to_non_nullable
as LuckyGiftPity?,
  ));
}

/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyGiftEligibilityCopyWith<$Res>? get caller {
    if (_self.caller == null) {
    return null;
  }

  return $LuckyGiftEligibilityCopyWith<$Res>(_self.caller!, (value) {
    return _then(_self.copyWith(caller: value));
  });
}/// Create a copy of LuckyGiftOdds
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyGiftPityCopyWith<$Res>? get pity {
    if (_self.pity == null) {
    return null;
  }

  return $LuckyGiftPityCopyWith<$Res>(_self.pity!, (value) {
    return _then(_self.copyWith(pity: value));
  });
}
}


/// @nodoc
mixin _$LuckyGiftPity {

 int get after; int get multiplier;
/// Create a copy of LuckyGiftPity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyGiftPityCopyWith<LuckyGiftPity> get copyWith => _$LuckyGiftPityCopyWithImpl<LuckyGiftPity>(this as LuckyGiftPity, _$identity);

  /// Serializes this LuckyGiftPity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyGiftPity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyGiftPity&&(identical(other.after, _this.after) || other.after == _this.after)&&(identical(other.multiplier, _this.multiplier) || other.multiplier == _this.multiplier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyGiftPity;
  return Object.hash(runtimeType,_this.after,_this.multiplier);
}

@override
String toString() {
  final _this = this as LuckyGiftPity;
  return 'LuckyGiftPity(after: ${_this.after}, multiplier: ${_this.multiplier})';
}


}

/// @nodoc
abstract mixin class $LuckyGiftPityCopyWith<$Res>  {
  factory $LuckyGiftPityCopyWith(LuckyGiftPity value, $Res Function(LuckyGiftPity) _then) = _$LuckyGiftPityCopyWithImpl;
@useResult
$Res call({
 int after, int multiplier
});




}
/// @nodoc
class _$LuckyGiftPityCopyWithImpl<$Res>
    implements $LuckyGiftPityCopyWith<$Res> {
  _$LuckyGiftPityCopyWithImpl(this._self, this._then);

  final LuckyGiftPity _self;
  final $Res Function(LuckyGiftPity) _then;

/// Create a copy of LuckyGiftPity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? after = null,Object? multiplier = null,}) {
  return _then(LuckyGiftPity(
after: null == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as int,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LuckyGiftPity].
extension LuckyGiftPityPatterns on LuckyGiftPity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyGiftPity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyGiftPity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyGiftPity value)  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftPity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyGiftPity value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyGiftPity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int after,  int multiplier)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyGiftPity() when $default != null:
return $default(_that.after,_that.multiplier);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int after,  int multiplier)  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftPity():
return $default(_that.after,_that.multiplier);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int after,  int multiplier)?  $default,) {final _that = this;
switch (_that) {
case _LuckyGiftPity() when $default != null:
return $default(_that.after,_that.multiplier);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyGiftPity implements LuckyGiftPity {
  const _LuckyGiftPity({required this.after, required this.multiplier});
  factory _LuckyGiftPity.fromJson(Map<String, dynamic> json) => _$LuckyGiftPityFromJson(json);

@override final  int after;
@override final  int multiplier;

/// Create a copy of LuckyGiftPity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyGiftPityCopyWith<_LuckyGiftPity> get copyWith => __$LuckyGiftPityCopyWithImpl<_LuckyGiftPity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyGiftPityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyGiftPity&&(identical(other.after, after) || other.after == after)&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,after,multiplier);
}

@override
String toString() {
    return 'LuckyGiftPity(after: $after, multiplier: $multiplier)';
}


}

/// @nodoc
abstract mixin class _$LuckyGiftPityCopyWith<$Res> implements $LuckyGiftPityCopyWith<$Res> {
  factory _$LuckyGiftPityCopyWith(_LuckyGiftPity value, $Res Function(_LuckyGiftPity) _then) = __$LuckyGiftPityCopyWithImpl;
@override @useResult
$Res call({
 int after, int multiplier
});




}
/// @nodoc
class __$LuckyGiftPityCopyWithImpl<$Res>
    implements _$LuckyGiftPityCopyWith<$Res> {
  __$LuckyGiftPityCopyWithImpl(this._self, this._then);

  final _LuckyGiftPity _self;
  final $Res Function(_LuckyGiftPity) _then;

/// Create a copy of LuckyGiftPity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? after = null,Object? multiplier = null,}) {
  return _then(_LuckyGiftPity(
after: null == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as int,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LuckyTickerRoom {

 String get id; String get title; UserSummary get host;
/// Create a copy of LuckyTickerRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyTickerRoomCopyWith<LuckyTickerRoom> get copyWith => _$LuckyTickerRoomCopyWithImpl<LuckyTickerRoom>(this as LuckyTickerRoom, _$identity);

  /// Serializes this LuckyTickerRoom to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyTickerRoom;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyTickerRoom&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.host, _this.host) || other.host == _this.host));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyTickerRoom;
  return Object.hash(runtimeType,_this.id,_this.title,_this.host);
}

@override
String toString() {
  final _this = this as LuckyTickerRoom;
  return 'LuckyTickerRoom(id: ${_this.id}, title: ${_this.title}, host: ${_this.host})';
}


}

/// @nodoc
abstract mixin class $LuckyTickerRoomCopyWith<$Res>  {
  factory $LuckyTickerRoomCopyWith(LuckyTickerRoom value, $Res Function(LuckyTickerRoom) _then) = _$LuckyTickerRoomCopyWithImpl;
@useResult
$Res call({
 String id, String title, UserSummary host
});


$UserSummaryCopyWith<$Res> get host;

}
/// @nodoc
class _$LuckyTickerRoomCopyWithImpl<$Res>
    implements $LuckyTickerRoomCopyWith<$Res> {
  _$LuckyTickerRoomCopyWithImpl(this._self, this._then);

  final LuckyTickerRoom _self;
  final $Res Function(LuckyTickerRoom) _then;

/// Create a copy of LuckyTickerRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? host = null,}) {
  return _then(LuckyTickerRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,
  ));
}
/// Create a copy of LuckyTickerRoom
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get host {
  
  return $UserSummaryCopyWith<$Res>(_self.host, (value) {
    return _then(_self.copyWith(host: value));
  });
}
}


/// Adds pattern-matching-related methods to [LuckyTickerRoom].
extension LuckyTickerRoomPatterns on LuckyTickerRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyTickerRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyTickerRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyTickerRoom value)  $default,){
final _that = this;
switch (_that) {
case _LuckyTickerRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyTickerRoom value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyTickerRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  UserSummary host)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyTickerRoom() when $default != null:
return $default(_that.id,_that.title,_that.host);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  UserSummary host)  $default,) {final _that = this;
switch (_that) {
case _LuckyTickerRoom():
return $default(_that.id,_that.title,_that.host);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  UserSummary host)?  $default,) {final _that = this;
switch (_that) {
case _LuckyTickerRoom() when $default != null:
return $default(_that.id,_that.title,_that.host);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyTickerRoom implements LuckyTickerRoom {
  const _LuckyTickerRoom({required this.id, required this.title, required this.host});
  factory _LuckyTickerRoom.fromJson(Map<String, dynamic> json) => _$LuckyTickerRoomFromJson(json);

@override final  String id;
@override final  String title;
@override final  UserSummary host;

/// Create a copy of LuckyTickerRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyTickerRoomCopyWith<_LuckyTickerRoom> get copyWith => __$LuckyTickerRoomCopyWithImpl<_LuckyTickerRoom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyTickerRoomToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyTickerRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.host, host) || other.host == host));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,host);
}

@override
String toString() {
    return 'LuckyTickerRoom(id: $id, title: $title, host: $host)';
}


}

/// @nodoc
abstract mixin class _$LuckyTickerRoomCopyWith<$Res> implements $LuckyTickerRoomCopyWith<$Res> {
  factory _$LuckyTickerRoomCopyWith(_LuckyTickerRoom value, $Res Function(_LuckyTickerRoom) _then) = __$LuckyTickerRoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, UserSummary host
});


@override $UserSummaryCopyWith<$Res> get host;

}
/// @nodoc
class __$LuckyTickerRoomCopyWithImpl<$Res>
    implements _$LuckyTickerRoomCopyWith<$Res> {
  __$LuckyTickerRoomCopyWithImpl(this._self, this._then);

  final _LuckyTickerRoom _self;
  final $Res Function(_LuckyTickerRoom) _then;

/// Create a copy of LuckyTickerRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? host = null,}) {
  return _then(_LuckyTickerRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as UserSummary,
  ));
}

/// Create a copy of LuckyTickerRoom
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
mixin _$LuckyTicker {

 LuckyWin get win; LuckyTickerRoom get room;
/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyTickerCopyWith<LuckyTicker> get copyWith => _$LuckyTickerCopyWithImpl<LuckyTicker>(this as LuckyTicker, _$identity);

  /// Serializes this LuckyTicker to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyTicker;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyTicker&&(identical(other.win, _this.win) || other.win == _this.win)&&(identical(other.room, _this.room) || other.room == _this.room));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyTicker;
  return Object.hash(runtimeType,_this.win,_this.room);
}

@override
String toString() {
  final _this = this as LuckyTicker;
  return 'LuckyTicker(win: ${_this.win}, room: ${_this.room})';
}


}

/// @nodoc
abstract mixin class $LuckyTickerCopyWith<$Res>  {
  factory $LuckyTickerCopyWith(LuckyTicker value, $Res Function(LuckyTicker) _then) = _$LuckyTickerCopyWithImpl;
@useResult
$Res call({
 LuckyWin win, LuckyTickerRoom room
});


$LuckyWinCopyWith<$Res> get win;$LuckyTickerRoomCopyWith<$Res> get room;

}
/// @nodoc
class _$LuckyTickerCopyWithImpl<$Res>
    implements $LuckyTickerCopyWith<$Res> {
  _$LuckyTickerCopyWithImpl(this._self, this._then);

  final LuckyTicker _self;
  final $Res Function(LuckyTicker) _then;

/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? win = null,Object? room = null,}) {
  return _then(LuckyTicker(
win: null == win ? _self.win : win // ignore: cast_nullable_to_non_nullable
as LuckyWin,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LuckyTickerRoom,
  ));
}
/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyWinCopyWith<$Res> get win {
  
  return $LuckyWinCopyWith<$Res>(_self.win, (value) {
    return _then(_self.copyWith(win: value));
  });
}/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyTickerRoomCopyWith<$Res> get room {
  
  return $LuckyTickerRoomCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}


/// Adds pattern-matching-related methods to [LuckyTicker].
extension LuckyTickerPatterns on LuckyTicker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyTicker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyTicker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyTicker value)  $default,){
final _that = this;
switch (_that) {
case _LuckyTicker():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyTicker value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyTicker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LuckyWin win,  LuckyTickerRoom room)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyTicker() when $default != null:
return $default(_that.win,_that.room);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LuckyWin win,  LuckyTickerRoom room)  $default,) {final _that = this;
switch (_that) {
case _LuckyTicker():
return $default(_that.win,_that.room);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LuckyWin win,  LuckyTickerRoom room)?  $default,) {final _that = this;
switch (_that) {
case _LuckyTicker() when $default != null:
return $default(_that.win,_that.room);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyTicker implements LuckyTicker {
  const _LuckyTicker({required this.win, required this.room});
  factory _LuckyTicker.fromJson(Map<String, dynamic> json) => _$LuckyTickerFromJson(json);

@override final  LuckyWin win;
@override final  LuckyTickerRoom room;

/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyTickerCopyWith<_LuckyTicker> get copyWith => __$LuckyTickerCopyWithImpl<_LuckyTicker>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyTickerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyTicker&&(identical(other.win, win) || other.win == win)&&(identical(other.room, room) || other.room == room));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,win,room);
}

@override
String toString() {
    return 'LuckyTicker(win: $win, room: $room)';
}


}

/// @nodoc
abstract mixin class _$LuckyTickerCopyWith<$Res> implements $LuckyTickerCopyWith<$Res> {
  factory _$LuckyTickerCopyWith(_LuckyTicker value, $Res Function(_LuckyTicker) _then) = __$LuckyTickerCopyWithImpl;
@override @useResult
$Res call({
 LuckyWin win, LuckyTickerRoom room
});


@override $LuckyWinCopyWith<$Res> get win;@override $LuckyTickerRoomCopyWith<$Res> get room;

}
/// @nodoc
class __$LuckyTickerCopyWithImpl<$Res>
    implements _$LuckyTickerCopyWith<$Res> {
  __$LuckyTickerCopyWithImpl(this._self, this._then);

  final _LuckyTicker _self;
  final $Res Function(_LuckyTicker) _then;

/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? win = null,Object? room = null,}) {
  return _then(_LuckyTicker(
win: null == win ? _self.win : win // ignore: cast_nullable_to_non_nullable
as LuckyWin,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as LuckyTickerRoom,
  ));
}

/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyWinCopyWith<$Res> get win {
  
  return $LuckyWinCopyWith<$Res>(_self.win, (value) {
    return _then(_self.copyWith(win: value));
  });
}/// Create a copy of LuckyTicker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LuckyTickerRoomCopyWith<$Res> get room {
  
  return $LuckyTickerRoomCopyWith<$Res>(_self.room, (value) {
    return _then(_self.copyWith(room: value));
  });
}
}


/// @nodoc
mixin _$LuckyWin {

 String get giftId; String get roomId; String get giftCode; UserSummary get sender; int get multiplier; int get coinsWon; DateTime get createdAt;
/// Create a copy of LuckyWin
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LuckyWinCopyWith<LuckyWin> get copyWith => _$LuckyWinCopyWithImpl<LuckyWin>(this as LuckyWin, _$identity);

  /// Serializes this LuckyWin to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LuckyWin;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LuckyWin&&(identical(other.giftId, _this.giftId) || other.giftId == _this.giftId)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.giftCode, _this.giftCode) || other.giftCode == _this.giftCode)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&(identical(other.multiplier, _this.multiplier) || other.multiplier == _this.multiplier)&&(identical(other.coinsWon, _this.coinsWon) || other.coinsWon == _this.coinsWon)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LuckyWin;
  return Object.hash(runtimeType,_this.giftId,_this.roomId,_this.giftCode,_this.sender,_this.multiplier,_this.coinsWon,_this.createdAt);
}

@override
String toString() {
  final _this = this as LuckyWin;
  return 'LuckyWin(giftId: ${_this.giftId}, roomId: ${_this.roomId}, giftCode: ${_this.giftCode}, sender: ${_this.sender}, multiplier: ${_this.multiplier}, coinsWon: ${_this.coinsWon}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LuckyWinCopyWith<$Res>  {
  factory $LuckyWinCopyWith(LuckyWin value, $Res Function(LuckyWin) _then) = _$LuckyWinCopyWithImpl;
@useResult
$Res call({
 String giftId, String roomId, String giftCode, UserSummary sender, int multiplier, int coinsWon, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class _$LuckyWinCopyWithImpl<$Res>
    implements $LuckyWinCopyWith<$Res> {
  _$LuckyWinCopyWithImpl(this._self, this._then);

  final LuckyWin _self;
  final $Res Function(LuckyWin) _then;

/// Create a copy of LuckyWin
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? giftId = null,Object? roomId = null,Object? giftCode = null,Object? sender = null,Object? multiplier = null,Object? coinsWon = null,Object? createdAt = null,}) {
  return _then(LuckyWin(
giftId: null == giftId ? _self.giftId : giftId // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,giftCode: null == giftCode ? _self.giftCode : giftCode // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,coinsWon: null == coinsWon ? _self.coinsWon : coinsWon // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LuckyWin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}


/// Adds pattern-matching-related methods to [LuckyWin].
extension LuckyWinPatterns on LuckyWin {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LuckyWin value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LuckyWin() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LuckyWin value)  $default,){
final _that = this;
switch (_that) {
case _LuckyWin():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LuckyWin value)?  $default,){
final _that = this;
switch (_that) {
case _LuckyWin() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String giftId,  String roomId,  String giftCode,  UserSummary sender,  int multiplier,  int coinsWon,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LuckyWin() when $default != null:
return $default(_that.giftId,_that.roomId,_that.giftCode,_that.sender,_that.multiplier,_that.coinsWon,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String giftId,  String roomId,  String giftCode,  UserSummary sender,  int multiplier,  int coinsWon,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LuckyWin():
return $default(_that.giftId,_that.roomId,_that.giftCode,_that.sender,_that.multiplier,_that.coinsWon,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String giftId,  String roomId,  String giftCode,  UserSummary sender,  int multiplier,  int coinsWon,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LuckyWin() when $default != null:
return $default(_that.giftId,_that.roomId,_that.giftCode,_that.sender,_that.multiplier,_that.coinsWon,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LuckyWin implements LuckyWin {
  const _LuckyWin({required this.giftId, required this.roomId, required this.giftCode, required this.sender, required this.multiplier, required this.coinsWon, required this.createdAt});
  factory _LuckyWin.fromJson(Map<String, dynamic> json) => _$LuckyWinFromJson(json);

@override final  String giftId;
@override final  String roomId;
@override final  String giftCode;
@override final  UserSummary sender;
@override final  int multiplier;
@override final  int coinsWon;
@override final  DateTime createdAt;

/// Create a copy of LuckyWin
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LuckyWinCopyWith<_LuckyWin> get copyWith => __$LuckyWinCopyWithImpl<_LuckyWin>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LuckyWinToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LuckyWin&&(identical(other.giftId, giftId) || other.giftId == giftId)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.giftCode, giftCode) || other.giftCode == giftCode)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.coinsWon, coinsWon) || other.coinsWon == coinsWon)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,giftId,roomId,giftCode,sender,multiplier,coinsWon,createdAt);
}

@override
String toString() {
    return 'LuckyWin(giftId: $giftId, roomId: $roomId, giftCode: $giftCode, sender: $sender, multiplier: $multiplier, coinsWon: $coinsWon, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LuckyWinCopyWith<$Res> implements $LuckyWinCopyWith<$Res> {
  factory _$LuckyWinCopyWith(_LuckyWin value, $Res Function(_LuckyWin) _then) = __$LuckyWinCopyWithImpl;
@override @useResult
$Res call({
 String giftId, String roomId, String giftCode, UserSummary sender, int multiplier, int coinsWon, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class __$LuckyWinCopyWithImpl<$Res>
    implements _$LuckyWinCopyWith<$Res> {
  __$LuckyWinCopyWithImpl(this._self, this._then);

  final _LuckyWin _self;
  final $Res Function(_LuckyWin) _then;

/// Create a copy of LuckyWin
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? giftId = null,Object? roomId = null,Object? giftCode = null,Object? sender = null,Object? multiplier = null,Object? coinsWon = null,Object? createdAt = null,}) {
  return _then(_LuckyWin(
giftId: null == giftId ? _self.giftId : giftId // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,giftCode: null == giftCode ? _self.giftCode : giftCode // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as int,coinsWon: null == coinsWon ? _self.coinsWon : coinsWon // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LuckyWin
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}

// dart format on
