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
mixin _$Gift {

 String get code; GiftCategory get category; String get name; int get priceCoins; String get assetKey; String? get animationKey; int get sortOrder;@JsonKey(unknownEnumValue: GiftBadge.none) GiftBadge get badge;/// The sub-category (v1.24.3-live), or null: none, or an older API.
 GiftTag? get tag;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Gift&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.priceCoins, _this.priceCoins) || other.priceCoins == _this.priceCoins)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey)&&(identical(other.animationKey, _this.animationKey) || other.animationKey == _this.animationKey)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.badge, _this.badge) || other.badge == _this.badge)&&(identical(other.tag, _this.tag) || other.tag == _this.tag));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Gift;
  return Object.hash(runtimeType,_this.code,_this.category,_this.name,_this.priceCoins,_this.assetKey,_this.animationKey,_this.sortOrder,_this.badge,_this.tag);
}

@override
String toString() {
  final _this = this as Gift;
  return 'Gift(code: ${_this.code}, category: ${_this.category}, name: ${_this.name}, priceCoins: ${_this.priceCoins}, assetKey: ${_this.assetKey}, animationKey: ${_this.animationKey}, sortOrder: ${_this.sortOrder}, badge: ${_this.badge}, tag: ${_this.tag})';
}


}

/// @nodoc
abstract mixin class $GiftCopyWith<$Res>  {
  factory $GiftCopyWith(Gift value, $Res Function(Gift) _then) = _$GiftCopyWithImpl;
@useResult
$Res call({
 String code, GiftCategory category, String name, int priceCoins, String assetKey, String? animationKey, int sortOrder,@JsonKey(unknownEnumValue: GiftBadge.none) GiftBadge badge, GiftTag? tag
});


$GiftTagCopyWith<$Res>? get tag;

}
/// @nodoc
class _$GiftCopyWithImpl<$Res>
    implements $GiftCopyWith<$Res> {
  _$GiftCopyWithImpl(this._self, this._then);

  final Gift _self;
  final $Res Function(Gift) _then;

/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? category = null,Object? name = null,Object? priceCoins = null,Object? assetKey = null,Object? animationKey = freezed,Object? sortOrder = null,Object? badge = null,Object? tag = freezed,}) {
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
as GiftTag?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  GiftCategory category,  String name,  int priceCoins,  String assetKey,  String? animationKey,  int sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none)  GiftBadge badge,  GiftTag? tag)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Gift() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.priceCoins,_that.assetKey,_that.animationKey,_that.sortOrder,_that.badge,_that.tag);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  GiftCategory category,  String name,  int priceCoins,  String assetKey,  String? animationKey,  int sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none)  GiftBadge badge,  GiftTag? tag)  $default,) {final _that = this;
switch (_that) {
case _Gift():
return $default(_that.code,_that.category,_that.name,_that.priceCoins,_that.assetKey,_that.animationKey,_that.sortOrder,_that.badge,_that.tag);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  GiftCategory category,  String name,  int priceCoins,  String assetKey,  String? animationKey,  int sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none)  GiftBadge badge,  GiftTag? tag)?  $default,) {final _that = this;
switch (_that) {
case _Gift() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.priceCoins,_that.assetKey,_that.animationKey,_that.sortOrder,_that.badge,_that.tag);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Gift implements Gift {
  const _Gift({required this.code, required this.category, required this.name, required this.priceCoins, required this.assetKey, required this.animationKey, required this.sortOrder, @JsonKey(unknownEnumValue: GiftBadge.none) required this.badge, this.tag});
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Gift&&(identical(other.code, code) || other.code == code)&&(identical(other.category, category) || other.category == category)&&(identical(other.name, name) || other.name == name)&&(identical(other.priceCoins, priceCoins) || other.priceCoins == priceCoins)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey)&&(identical(other.animationKey, animationKey) || other.animationKey == animationKey)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.badge, badge) || other.badge == badge)&&(identical(other.tag, tag) || other.tag == tag));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,category,name,priceCoins,assetKey,animationKey,sortOrder,badge,tag);
}

@override
String toString() {
    return 'Gift(code: $code, category: $category, name: $name, priceCoins: $priceCoins, assetKey: $assetKey, animationKey: $animationKey, sortOrder: $sortOrder, badge: $badge, tag: $tag)';
}


}

/// @nodoc
abstract mixin class _$GiftCopyWith<$Res> implements $GiftCopyWith<$Res> {
  factory _$GiftCopyWith(_Gift value, $Res Function(_Gift) _then) = __$GiftCopyWithImpl;
@override @useResult
$Res call({
 String code, GiftCategory category, String name, int priceCoins, String assetKey, String? animationKey, int sortOrder,@JsonKey(unknownEnumValue: GiftBadge.none) GiftBadge badge, GiftTag? tag
});


@override $GiftTagCopyWith<$Res>? get tag;

}
/// @nodoc
class __$GiftCopyWithImpl<$Res>
    implements _$GiftCopyWith<$Res> {
  __$GiftCopyWithImpl(this._self, this._then);

  final _Gift _self;
  final $Res Function(_Gift) _then;

/// Create a copy of Gift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? category = null,Object? name = null,Object? priceCoins = null,Object? assetKey = null,Object? animationKey = freezed,Object? sortOrder = null,Object? badge = null,Object? tag = freezed,}) {
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
as GiftTag?,
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

 String get id; String get roomId; String get giftCode; String get assetKey; String? get animationKey; int get unitPrice; int get quantity;@JsonKey(unknownEnumValue: LiveGiftSource.coins) LiveGiftSource get source; int get totalCoins; UserSummary get sender; List<UserSummary> get recipients; LiveGiftCombo get combo; DateTime get createdAt;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGift&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.giftCode, _this.giftCode) || other.giftCode == _this.giftCode)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey)&&(identical(other.animationKey, _this.animationKey) || other.animationKey == _this.animationKey)&&(identical(other.unitPrice, _this.unitPrice) || other.unitPrice == _this.unitPrice)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.totalCoins, _this.totalCoins) || other.totalCoins == _this.totalCoins)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&const DeepCollectionEquality().equals(other.recipients, _this.recipients)&&(identical(other.combo, _this.combo) || other.combo == _this.combo)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGift;
  return Object.hash(runtimeType,_this.id,_this.roomId,_this.giftCode,_this.assetKey,_this.animationKey,_this.unitPrice,_this.quantity,_this.source,_this.totalCoins,_this.sender,const DeepCollectionEquality().hash(_this.recipients),_this.combo,_this.createdAt);
}

@override
String toString() {
  final _this = this as LiveGift;
  return 'LiveGift(id: ${_this.id}, roomId: ${_this.roomId}, giftCode: ${_this.giftCode}, assetKey: ${_this.assetKey}, animationKey: ${_this.animationKey}, unitPrice: ${_this.unitPrice}, quantity: ${_this.quantity}, source: ${_this.source}, totalCoins: ${_this.totalCoins}, sender: ${_this.sender}, recipients: ${_this.recipients}, combo: ${_this.combo}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LiveGiftCopyWith<$Res>  {
  factory $LiveGiftCopyWith(LiveGift value, $Res Function(LiveGift) _then) = _$LiveGiftCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, String giftCode, String assetKey, String? animationKey, int unitPrice, int quantity,@JsonKey(unknownEnumValue: LiveGiftSource.coins) LiveGiftSource source, int totalCoins, UserSummary sender, List<UserSummary> recipients, LiveGiftCombo combo, DateTime createdAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? giftCode = null,Object? assetKey = null,Object? animationKey = freezed,Object? unitPrice = null,Object? quantity = null,Object? source = null,Object? totalCoins = null,Object? sender = null,Object? recipients = null,Object? combo = null,Object? createdAt = null,}) {
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
as DateTime,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  String giftCode,  String assetKey,  String? animationKey,  int unitPrice,  int quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins)  LiveGiftSource source,  int totalCoins,  UserSummary sender,  List<UserSummary> recipients,  LiveGiftCombo combo,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
return $default(_that.id,_that.roomId,_that.giftCode,_that.assetKey,_that.animationKey,_that.unitPrice,_that.quantity,_that.source,_that.totalCoins,_that.sender,_that.recipients,_that.combo,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  String giftCode,  String assetKey,  String? animationKey,  int unitPrice,  int quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins)  LiveGiftSource source,  int totalCoins,  UserSummary sender,  List<UserSummary> recipients,  LiveGiftCombo combo,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LiveGift():
return $default(_that.id,_that.roomId,_that.giftCode,_that.assetKey,_that.animationKey,_that.unitPrice,_that.quantity,_that.source,_that.totalCoins,_that.sender,_that.recipients,_that.combo,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  String giftCode,  String assetKey,  String? animationKey,  int unitPrice,  int quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins)  LiveGiftSource source,  int totalCoins,  UserSummary sender,  List<UserSummary> recipients,  LiveGiftCombo combo,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveGift() when $default != null:
return $default(_that.id,_that.roomId,_that.giftCode,_that.assetKey,_that.animationKey,_that.unitPrice,_that.quantity,_that.source,_that.totalCoins,_that.sender,_that.recipients,_that.combo,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGift implements LiveGift {
  const _LiveGift({required this.id, required this.roomId, required this.giftCode, required this.assetKey, required this.animationKey, required this.unitPrice, required this.quantity, @JsonKey(unknownEnumValue: LiveGiftSource.coins) required this.source, required this.totalCoins, required this.sender, required  List<UserSummary> recipients, required this.combo, required this.createdAt}): _recipients = recipients;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGift&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.giftCode, giftCode) || other.giftCode == giftCode)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey)&&(identical(other.animationKey, animationKey) || other.animationKey == animationKey)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.source, source) || other.source == source)&&(identical(other.totalCoins, totalCoins) || other.totalCoins == totalCoins)&&(identical(other.sender, sender) || other.sender == sender)&&const DeepCollectionEquality().equals(other.recipients, _recipients)&&(identical(other.combo, combo) || other.combo == combo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,roomId,giftCode,assetKey,animationKey,unitPrice,quantity,source,totalCoins,sender,const DeepCollectionEquality().hash(_recipients),combo,createdAt);
}

@override
String toString() {
    return 'LiveGift(id: $id, roomId: $roomId, giftCode: $giftCode, assetKey: $assetKey, animationKey: $animationKey, unitPrice: $unitPrice, quantity: $quantity, source: $source, totalCoins: $totalCoins, sender: $sender, recipients: $recipients, combo: $combo, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftCopyWith<$Res> implements $LiveGiftCopyWith<$Res> {
  factory _$LiveGiftCopyWith(_LiveGift value, $Res Function(_LiveGift) _then) = __$LiveGiftCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, String giftCode, String assetKey, String? animationKey, int unitPrice, int quantity,@JsonKey(unknownEnumValue: LiveGiftSource.coins) LiveGiftSource source, int totalCoins, UserSummary sender, List<UserSummary> recipients, LiveGiftCombo combo, DateTime createdAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? giftCode = null,Object? assetKey = null,Object? animationKey = freezed,Object? unitPrice = null,Object? quantity = null,Object? source = null,Object? totalCoins = null,Object? sender = null,Object? recipients = null,Object? combo = null,Object? createdAt = null,}) {
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
as DateTime,
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

 LiveGift get gift; int get coins; int get bagQuantity;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveGiftResult&&(identical(other.gift, _this.gift) || other.gift == _this.gift)&&(identical(other.coins, _this.coins) || other.coins == _this.coins)&&(identical(other.bagQuantity, _this.bagQuantity) || other.bagQuantity == _this.bagQuantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveGiftResult;
  return Object.hash(runtimeType,_this.gift,_this.coins,_this.bagQuantity);
}

@override
String toString() {
  final _this = this as LiveGiftResult;
  return 'LiveGiftResult(gift: ${_this.gift}, coins: ${_this.coins}, bagQuantity: ${_this.bagQuantity})';
}


}

/// @nodoc
abstract mixin class $LiveGiftResultCopyWith<$Res>  {
  factory $LiveGiftResultCopyWith(LiveGiftResult value, $Res Function(LiveGiftResult) _then) = _$LiveGiftResultCopyWithImpl;
@useResult
$Res call({
 LiveGift gift, int coins, int bagQuantity
});


$LiveGiftCopyWith<$Res> get gift;

}
/// @nodoc
class _$LiveGiftResultCopyWithImpl<$Res>
    implements $LiveGiftResultCopyWith<$Res> {
  _$LiveGiftResultCopyWithImpl(this._self, this._then);

  final LiveGiftResult _self;
  final $Res Function(LiveGiftResult) _then;

/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gift = null,Object? coins = null,Object? bagQuantity = null,}) {
  return _then(LiveGiftResult(
gift: null == gift ? _self.gift : gift // ignore: cast_nullable_to_non_nullable
as LiveGift,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,bagQuantity: null == bagQuantity ? _self.bagQuantity : bagQuantity // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveGift gift,  int coins,  int bagQuantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveGiftResult() when $default != null:
return $default(_that.gift,_that.coins,_that.bagQuantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveGift gift,  int coins,  int bagQuantity)  $default,) {final _that = this;
switch (_that) {
case _LiveGiftResult():
return $default(_that.gift,_that.coins,_that.bagQuantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveGift gift,  int coins,  int bagQuantity)?  $default,) {final _that = this;
switch (_that) {
case _LiveGiftResult() when $default != null:
return $default(_that.gift,_that.coins,_that.bagQuantity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveGiftResult implements LiveGiftResult {
  const _LiveGiftResult({required this.gift, required this.coins, required this.bagQuantity});
  factory _LiveGiftResult.fromJson(Map<String, dynamic> json) => _$LiveGiftResultFromJson(json);

@override final  LiveGift gift;
@override final  int coins;
@override final  int bagQuantity;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveGiftResult&&(identical(other.gift, gift) || other.gift == gift)&&(identical(other.coins, coins) || other.coins == coins)&&(identical(other.bagQuantity, bagQuantity) || other.bagQuantity == bagQuantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,gift,coins,bagQuantity);
}

@override
String toString() {
    return 'LiveGiftResult(gift: $gift, coins: $coins, bagQuantity: $bagQuantity)';
}


}

/// @nodoc
abstract mixin class _$LiveGiftResultCopyWith<$Res> implements $LiveGiftResultCopyWith<$Res> {
  factory _$LiveGiftResultCopyWith(_LiveGiftResult value, $Res Function(_LiveGiftResult) _then) = __$LiveGiftResultCopyWithImpl;
@override @useResult
$Res call({
 LiveGift gift, int coins, int bagQuantity
});


@override $LiveGiftCopyWith<$Res> get gift;

}
/// @nodoc
class __$LiveGiftResultCopyWithImpl<$Res>
    implements _$LiveGiftResultCopyWith<$Res> {
  __$LiveGiftResultCopyWithImpl(this._self, this._then);

  final _LiveGiftResult _self;
  final $Res Function(_LiveGiftResult) _then;

/// Create a copy of LiveGiftResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gift = null,Object? coins = null,Object? bagQuantity = null,}) {
  return _then(_LiveGiftResult(
gift: null == gift ? _self.gift : gift // ignore: cast_nullable_to_non_nullable
as LiveGift,coins: null == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int,bagQuantity: null == bagQuantity ? _self.bagQuantity : bagQuantity // ignore: cast_nullable_to_non_nullable
as int,
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
}
}

// dart format on
