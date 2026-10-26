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
mixin _$Medal {

 String get code; String get name; String get description; String get iconKey; int get sortOrder; DateTime? get awardedAt;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Medal&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.iconKey, _this.iconKey) || other.iconKey == _this.iconKey)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.awardedAt, _this.awardedAt) || other.awardedAt == _this.awardedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Medal;
  return Object.hash(runtimeType,_this.code,_this.name,_this.description,_this.iconKey,_this.sortOrder,_this.awardedAt);
}

@override
String toString() {
  final _this = this as Medal;
  return 'Medal(code: ${_this.code}, name: ${_this.name}, description: ${_this.description}, iconKey: ${_this.iconKey}, sortOrder: ${_this.sortOrder}, awardedAt: ${_this.awardedAt})';
}


}

/// @nodoc
abstract mixin class $MedalCopyWith<$Res>  {
  factory $MedalCopyWith(Medal value, $Res Function(Medal) _then) = _$MedalCopyWithImpl;
@useResult
$Res call({
 String code, String name, String description, String iconKey, int sortOrder, DateTime? awardedAt
});




}
/// @nodoc
class _$MedalCopyWithImpl<$Res>
    implements $MedalCopyWith<$Res> {
  _$MedalCopyWithImpl(this._self, this._then);

  final Medal _self;
  final $Res Function(Medal) _then;

/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? sortOrder = null,Object? awardedAt = freezed,}) {
  return _then(Medal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,awardedAt: freezed == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  int sortOrder,  DateTime? awardedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Medal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.sortOrder,_that.awardedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  int sortOrder,  DateTime? awardedAt)  $default,) {final _that = this;
switch (_that) {
case _Medal():
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.sortOrder,_that.awardedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String description,  String iconKey,  int sortOrder,  DateTime? awardedAt)?  $default,) {final _that = this;
switch (_that) {
case _Medal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.sortOrder,_that.awardedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Medal extends Medal {
  const _Medal({required this.code, required this.name, required this.description, required this.iconKey, required this.sortOrder, required this.awardedAt}): super._();
  factory _Medal.fromJson(Map<String, dynamic> json) => _$MedalFromJson(json);

@override final  String code;
@override final  String name;
@override final  String description;
@override final  String iconKey;
@override final  int sortOrder;
@override final  DateTime? awardedAt;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Medal&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.awardedAt, awardedAt) || other.awardedAt == awardedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,description,iconKey,sortOrder,awardedAt);
}

@override
String toString() {
    return 'Medal(code: $code, name: $name, description: $description, iconKey: $iconKey, sortOrder: $sortOrder, awardedAt: $awardedAt)';
}


}

/// @nodoc
abstract mixin class _$MedalCopyWith<$Res> implements $MedalCopyWith<$Res> {
  factory _$MedalCopyWith(_Medal value, $Res Function(_Medal) _then) = __$MedalCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String description, String iconKey, int sortOrder, DateTime? awardedAt
});




}
/// @nodoc
class __$MedalCopyWithImpl<$Res>
    implements _$MedalCopyWith<$Res> {
  __$MedalCopyWithImpl(this._self, this._then);

  final _Medal _self;
  final $Res Function(_Medal) _then;

/// Create a copy of Medal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? sortOrder = null,Object? awardedAt = freezed,}) {
  return _then(_Medal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,awardedAt: freezed == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
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

 String get code; String get name; String get description; String get iconKey; DateTime get awardedAt;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserMedal&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.iconKey, _this.iconKey) || other.iconKey == _this.iconKey)&&(identical(other.awardedAt, _this.awardedAt) || other.awardedAt == _this.awardedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserMedal;
  return Object.hash(runtimeType,_this.code,_this.name,_this.description,_this.iconKey,_this.awardedAt);
}

@override
String toString() {
  final _this = this as UserMedal;
  return 'UserMedal(code: ${_this.code}, name: ${_this.name}, description: ${_this.description}, iconKey: ${_this.iconKey}, awardedAt: ${_this.awardedAt})';
}


}

/// @nodoc
abstract mixin class $UserMedalCopyWith<$Res>  {
  factory $UserMedalCopyWith(UserMedal value, $Res Function(UserMedal) _then) = _$UserMedalCopyWithImpl;
@useResult
$Res call({
 String code, String name, String description, String iconKey, DateTime awardedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? awardedAt = null,}) {
  return _then(UserMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,awardedAt: null == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  DateTime awardedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserMedal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.awardedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String description,  String iconKey,  DateTime awardedAt)  $default,) {final _that = this;
switch (_that) {
case _UserMedal():
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.awardedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String description,  String iconKey,  DateTime awardedAt)?  $default,) {final _that = this;
switch (_that) {
case _UserMedal() when $default != null:
return $default(_that.code,_that.name,_that.description,_that.iconKey,_that.awardedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserMedal implements UserMedal {
  const _UserMedal({required this.code, required this.name, required this.description, required this.iconKey, required this.awardedAt});
  factory _UserMedal.fromJson(Map<String, dynamic> json) => _$UserMedalFromJson(json);

@override final  String code;
@override final  String name;
@override final  String description;
@override final  String iconKey;
@override final  DateTime awardedAt;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserMedal&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey)&&(identical(other.awardedAt, awardedAt) || other.awardedAt == awardedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,description,iconKey,awardedAt);
}

@override
String toString() {
    return 'UserMedal(code: $code, name: $name, description: $description, iconKey: $iconKey, awardedAt: $awardedAt)';
}


}

/// @nodoc
abstract mixin class _$UserMedalCopyWith<$Res> implements $UserMedalCopyWith<$Res> {
  factory _$UserMedalCopyWith(_UserMedal value, $Res Function(_UserMedal) _then) = __$UserMedalCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String description, String iconKey, DateTime awardedAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? description = null,Object? iconKey = null,Object? awardedAt = null,}) {
  return _then(_UserMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,awardedAt: null == awardedAt ? _self.awardedAt : awardedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
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

 String get code; String get name; String get iconKey;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileMedal&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.iconKey, _this.iconKey) || other.iconKey == _this.iconKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileMedal;
  return Object.hash(runtimeType,_this.code,_this.name,_this.iconKey);
}

@override
String toString() {
  final _this = this as ProfileMedal;
  return 'ProfileMedal(code: ${_this.code}, name: ${_this.name}, iconKey: ${_this.iconKey})';
}


}

/// @nodoc
abstract mixin class $ProfileMedalCopyWith<$Res>  {
  factory $ProfileMedalCopyWith(ProfileMedal value, $Res Function(ProfileMedal) _then) = _$ProfileMedalCopyWithImpl;
@useResult
$Res call({
 String code, String name, String iconKey
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
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? iconKey = null,}) {
  return _then(ProfileMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String iconKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileMedal() when $default != null:
return $default(_that.code,_that.name,_that.iconKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String iconKey)  $default,) {final _that = this;
switch (_that) {
case _ProfileMedal():
return $default(_that.code,_that.name,_that.iconKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String iconKey)?  $default,) {final _that = this;
switch (_that) {
case _ProfileMedal() when $default != null:
return $default(_that.code,_that.name,_that.iconKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileMedal implements ProfileMedal {
  const _ProfileMedal({required this.code, required this.name, required this.iconKey});
  factory _ProfileMedal.fromJson(Map<String, dynamic> json) => _$ProfileMedalFromJson(json);

@override final  String code;
@override final  String name;
@override final  String iconKey;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileMedal&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.iconKey, iconKey) || other.iconKey == iconKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,iconKey);
}

@override
String toString() {
    return 'ProfileMedal(code: $code, name: $name, iconKey: $iconKey)';
}


}

/// @nodoc
abstract mixin class _$ProfileMedalCopyWith<$Res> implements $ProfileMedalCopyWith<$Res> {
  factory _$ProfileMedalCopyWith(_ProfileMedal value, $Res Function(_ProfileMedal) _then) = __$ProfileMedalCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String iconKey
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
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? iconKey = null,}) {
  return _then(_ProfileMedal(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconKey: null == iconKey ? _self.iconKey : iconKey // ignore: cast_nullable_to_non_nullable
as String,
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
