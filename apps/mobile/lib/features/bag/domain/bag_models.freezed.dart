// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bag_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BagTransfer {

 String get id; String get code; String get category; String get name; UserSummary get recipient; bool get whole; int? get durationSeconds; BagItem? get remaining;
/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BagTransferCopyWith<BagTransfer> get copyWith => _$BagTransferCopyWithImpl<BagTransfer>(this as BagTransfer, _$identity);

  /// Serializes this BagTransfer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BagTransfer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BagTransfer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.recipient, _this.recipient) || other.recipient == _this.recipient)&&(identical(other.whole, _this.whole) || other.whole == _this.whole)&&(identical(other.durationSeconds, _this.durationSeconds) || other.durationSeconds == _this.durationSeconds)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BagTransfer;
  return Object.hash(runtimeType,_this.id,_this.code,_this.category,_this.name,_this.recipient,_this.whole,_this.durationSeconds,_this.remaining);
}

@override
String toString() {
  final _this = this as BagTransfer;
  return 'BagTransfer(id: ${_this.id}, code: ${_this.code}, category: ${_this.category}, name: ${_this.name}, recipient: ${_this.recipient}, whole: ${_this.whole}, durationSeconds: ${_this.durationSeconds}, remaining: ${_this.remaining})';
}


}

/// @nodoc
abstract mixin class $BagTransferCopyWith<$Res>  {
  factory $BagTransferCopyWith(BagTransfer value, $Res Function(BagTransfer) _then) = _$BagTransferCopyWithImpl;
@useResult
$Res call({
 String id, String code, String category, String name, UserSummary recipient, bool whole, int? durationSeconds, BagItem? remaining
});


$UserSummaryCopyWith<$Res> get recipient;$BagItemCopyWith<$Res>? get remaining;

}
/// @nodoc
class _$BagTransferCopyWithImpl<$Res>
    implements $BagTransferCopyWith<$Res> {
  _$BagTransferCopyWithImpl(this._self, this._then);

  final BagTransfer _self;
  final $Res Function(BagTransfer) _then;

/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? category = null,Object? name = null,Object? recipient = null,Object? whole = null,Object? durationSeconds = freezed,Object? remaining = freezed,}) {
  return _then(BagTransfer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as UserSummary,whole: null == whole ? _self.whole : whole // ignore: cast_nullable_to_non_nullable
as bool,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as BagItem?,
  ));
}
/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get recipient {
  
  return $UserSummaryCopyWith<$Res>(_self.recipient, (value) {
    return _then(_self.copyWith(recipient: value));
  });
}/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BagItemCopyWith<$Res>? get remaining {
    if (_self.remaining == null) {
    return null;
  }

  return $BagItemCopyWith<$Res>(_self.remaining!, (value) {
    return _then(_self.copyWith(remaining: value));
  });
}
}


/// Adds pattern-matching-related methods to [BagTransfer].
extension BagTransferPatterns on BagTransfer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BagTransfer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BagTransfer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BagTransfer value)  $default,){
final _that = this;
switch (_that) {
case _BagTransfer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BagTransfer value)?  $default,){
final _that = this;
switch (_that) {
case _BagTransfer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  String category,  String name,  UserSummary recipient,  bool whole,  int? durationSeconds,  BagItem? remaining)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BagTransfer() when $default != null:
return $default(_that.id,_that.code,_that.category,_that.name,_that.recipient,_that.whole,_that.durationSeconds,_that.remaining);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  String category,  String name,  UserSummary recipient,  bool whole,  int? durationSeconds,  BagItem? remaining)  $default,) {final _that = this;
switch (_that) {
case _BagTransfer():
return $default(_that.id,_that.code,_that.category,_that.name,_that.recipient,_that.whole,_that.durationSeconds,_that.remaining);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  String category,  String name,  UserSummary recipient,  bool whole,  int? durationSeconds,  BagItem? remaining)?  $default,) {final _that = this;
switch (_that) {
case _BagTransfer() when $default != null:
return $default(_that.id,_that.code,_that.category,_that.name,_that.recipient,_that.whole,_that.durationSeconds,_that.remaining);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BagTransfer implements BagTransfer {
  const _BagTransfer({required this.id, required this.code, required this.category, required this.name, required this.recipient, required this.whole, this.durationSeconds, this.remaining});
  factory _BagTransfer.fromJson(Map<String, dynamic> json) => _$BagTransferFromJson(json);

@override final  String id;
@override final  String code;
@override final  String category;
@override final  String name;
@override final  UserSummary recipient;
@override final  bool whole;
@override final  int? durationSeconds;
@override final  BagItem? remaining;

/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BagTransferCopyWith<_BagTransfer> get copyWith => __$BagTransferCopyWithImpl<_BagTransfer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BagTransferToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BagTransfer&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.category, category) || other.category == category)&&(identical(other.name, name) || other.name == name)&&(identical(other.recipient, recipient) || other.recipient == recipient)&&(identical(other.whole, whole) || other.whole == whole)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.remaining, remaining) || other.remaining == remaining));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,code,category,name,recipient,whole,durationSeconds,remaining);
}

@override
String toString() {
    return 'BagTransfer(id: $id, code: $code, category: $category, name: $name, recipient: $recipient, whole: $whole, durationSeconds: $durationSeconds, remaining: $remaining)';
}


}

/// @nodoc
abstract mixin class _$BagTransferCopyWith<$Res> implements $BagTransferCopyWith<$Res> {
  factory _$BagTransferCopyWith(_BagTransfer value, $Res Function(_BagTransfer) _then) = __$BagTransferCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, String category, String name, UserSummary recipient, bool whole, int? durationSeconds, BagItem? remaining
});


@override $UserSummaryCopyWith<$Res> get recipient;@override $BagItemCopyWith<$Res>? get remaining;

}
/// @nodoc
class __$BagTransferCopyWithImpl<$Res>
    implements _$BagTransferCopyWith<$Res> {
  __$BagTransferCopyWithImpl(this._self, this._then);

  final _BagTransfer _self;
  final $Res Function(_BagTransfer) _then;

/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? category = null,Object? name = null,Object? recipient = null,Object? whole = null,Object? durationSeconds = freezed,Object? remaining = freezed,}) {
  return _then(_BagTransfer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as UserSummary,whole: null == whole ? _self.whole : whole // ignore: cast_nullable_to_non_nullable
as bool,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as BagItem?,
  ));
}

/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get recipient {
  
  return $UserSummaryCopyWith<$Res>(_self.recipient, (value) {
    return _then(_self.copyWith(recipient: value));
  });
}/// Create a copy of BagTransfer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BagItemCopyWith<$Res>? get remaining {
    if (_self.remaining == null) {
    return null;
  }

  return $BagItemCopyWith<$Res>(_self.remaining!, (value) {
    return _then(_self.copyWith(remaining: value));
  });
}
}


/// @nodoc
mixin _$ProfileCard {

 String get code; String get assetKey;
/// Create a copy of ProfileCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCardCopyWith<ProfileCard> get copyWith => _$ProfileCardCopyWithImpl<ProfileCard>(this as ProfileCard, _$identity);

  /// Serializes this ProfileCard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileCard;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileCard&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileCard;
  return Object.hash(runtimeType,_this.code,_this.assetKey);
}

@override
String toString() {
  final _this = this as ProfileCard;
  return 'ProfileCard(code: ${_this.code}, assetKey: ${_this.assetKey})';
}


}

/// @nodoc
abstract mixin class $ProfileCardCopyWith<$Res>  {
  factory $ProfileCardCopyWith(ProfileCard value, $Res Function(ProfileCard) _then) = _$ProfileCardCopyWithImpl;
@useResult
$Res call({
 String code, String assetKey
});




}
/// @nodoc
class _$ProfileCardCopyWithImpl<$Res>
    implements $ProfileCardCopyWith<$Res> {
  _$ProfileCardCopyWithImpl(this._self, this._then);

  final ProfileCard _self;
  final $Res Function(ProfileCard) _then;

/// Create a copy of ProfileCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? assetKey = null,}) {
  return _then(ProfileCard(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileCard].
extension ProfileCardPatterns on ProfileCard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileCard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileCard value)  $default,){
final _that = this;
switch (_that) {
case _ProfileCard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileCard value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileCard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String assetKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileCard() when $default != null:
return $default(_that.code,_that.assetKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String assetKey)  $default,) {final _that = this;
switch (_that) {
case _ProfileCard():
return $default(_that.code,_that.assetKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String assetKey)?  $default,) {final _that = this;
switch (_that) {
case _ProfileCard() when $default != null:
return $default(_that.code,_that.assetKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileCard implements ProfileCard {
  const _ProfileCard({required this.code, required this.assetKey});
  factory _ProfileCard.fromJson(Map<String, dynamic> json) => _$ProfileCardFromJson(json);

@override final  String code;
@override final  String assetKey;

/// Create a copy of ProfileCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCardCopyWith<_ProfileCard> get copyWith => __$ProfileCardCopyWithImpl<_ProfileCard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileCardToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileCard&&(identical(other.code, code) || other.code == code)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,assetKey);
}

@override
String toString() {
    return 'ProfileCard(code: $code, assetKey: $assetKey)';
}


}

/// @nodoc
abstract mixin class _$ProfileCardCopyWith<$Res> implements $ProfileCardCopyWith<$Res> {
  factory _$ProfileCardCopyWith(_ProfileCard value, $Res Function(_ProfileCard) _then) = __$ProfileCardCopyWithImpl;
@override @useResult
$Res call({
 String code, String assetKey
});




}
/// @nodoc
class __$ProfileCardCopyWithImpl<$Res>
    implements _$ProfileCardCopyWith<$Res> {
  __$ProfileCardCopyWithImpl(this._self, this._then);

  final _ProfileCard _self;
  final $Res Function(_ProfileCard) _then;

/// Create a copy of ProfileCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? assetKey = null,}) {
  return _then(_ProfileCard(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$BagCatalogueItem {

 String get code; String get category; String get name; String get assetKey; int get sortOrder; bool get free;
/// Create a copy of BagCatalogueItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BagCatalogueItemCopyWith<BagCatalogueItem> get copyWith => _$BagCatalogueItemCopyWithImpl<BagCatalogueItem>(this as BagCatalogueItem, _$identity);

  /// Serializes this BagCatalogueItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BagCatalogueItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BagCatalogueItem&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.free, _this.free) || other.free == _this.free));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BagCatalogueItem;
  return Object.hash(runtimeType,_this.code,_this.category,_this.name,_this.assetKey,_this.sortOrder,_this.free);
}

@override
String toString() {
  final _this = this as BagCatalogueItem;
  return 'BagCatalogueItem(code: ${_this.code}, category: ${_this.category}, name: ${_this.name}, assetKey: ${_this.assetKey}, sortOrder: ${_this.sortOrder}, free: ${_this.free})';
}


}

/// @nodoc
abstract mixin class $BagCatalogueItemCopyWith<$Res>  {
  factory $BagCatalogueItemCopyWith(BagCatalogueItem value, $Res Function(BagCatalogueItem) _then) = _$BagCatalogueItemCopyWithImpl;
@useResult
$Res call({
 String code, String category, String name, String assetKey, int sortOrder, bool free
});




}
/// @nodoc
class _$BagCatalogueItemCopyWithImpl<$Res>
    implements $BagCatalogueItemCopyWith<$Res> {
  _$BagCatalogueItemCopyWithImpl(this._self, this._then);

  final BagCatalogueItem _self;
  final $Res Function(BagCatalogueItem) _then;

/// Create a copy of BagCatalogueItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? category = null,Object? name = null,Object? assetKey = null,Object? sortOrder = null,Object? free = null,}) {
  return _then(BagCatalogueItem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,free: null == free ? _self.free : free // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BagCatalogueItem].
extension BagCatalogueItemPatterns on BagCatalogueItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BagCatalogueItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BagCatalogueItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BagCatalogueItem value)  $default,){
final _that = this;
switch (_that) {
case _BagCatalogueItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BagCatalogueItem value)?  $default,){
final _that = this;
switch (_that) {
case _BagCatalogueItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String category,  String name,  String assetKey,  int sortOrder,  bool free)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BagCatalogueItem() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.assetKey,_that.sortOrder,_that.free);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String category,  String name,  String assetKey,  int sortOrder,  bool free)  $default,) {final _that = this;
switch (_that) {
case _BagCatalogueItem():
return $default(_that.code,_that.category,_that.name,_that.assetKey,_that.sortOrder,_that.free);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String category,  String name,  String assetKey,  int sortOrder,  bool free)?  $default,) {final _that = this;
switch (_that) {
case _BagCatalogueItem() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.assetKey,_that.sortOrder,_that.free);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BagCatalogueItem implements BagCatalogueItem {
  const _BagCatalogueItem({required this.code, required this.category, required this.name, required this.assetKey, required this.sortOrder, required this.free});
  factory _BagCatalogueItem.fromJson(Map<String, dynamic> json) => _$BagCatalogueItemFromJson(json);

@override final  String code;
@override final  String category;
@override final  String name;
@override final  String assetKey;
@override final  int sortOrder;
@override final  bool free;

/// Create a copy of BagCatalogueItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BagCatalogueItemCopyWith<_BagCatalogueItem> get copyWith => __$BagCatalogueItemCopyWithImpl<_BagCatalogueItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BagCatalogueItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BagCatalogueItem&&(identical(other.code, code) || other.code == code)&&(identical(other.category, category) || other.category == category)&&(identical(other.name, name) || other.name == name)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.free, free) || other.free == free));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,category,name,assetKey,sortOrder,free);
}

@override
String toString() {
    return 'BagCatalogueItem(code: $code, category: $category, name: $name, assetKey: $assetKey, sortOrder: $sortOrder, free: $free)';
}


}

/// @nodoc
abstract mixin class _$BagCatalogueItemCopyWith<$Res> implements $BagCatalogueItemCopyWith<$Res> {
  factory _$BagCatalogueItemCopyWith(_BagCatalogueItem value, $Res Function(_BagCatalogueItem) _then) = __$BagCatalogueItemCopyWithImpl;
@override @useResult
$Res call({
 String code, String category, String name, String assetKey, int sortOrder, bool free
});




}
/// @nodoc
class __$BagCatalogueItemCopyWithImpl<$Res>
    implements _$BagCatalogueItemCopyWith<$Res> {
  __$BagCatalogueItemCopyWithImpl(this._self, this._then);

  final _BagCatalogueItem _self;
  final $Res Function(_BagCatalogueItem) _then;

/// Create a copy of BagCatalogueItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? category = null,Object? name = null,Object? assetKey = null,Object? sortOrder = null,Object? free = null,}) {
  return _then(_BagCatalogueItem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,free: null == free ? _self.free : free // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$BagItem {

 String get code; String get category; String get name; String get assetKey; DateTime get acquiredAt; String get source; bool get equipped; DateTime? get expiresAt; UserSummary? get giftedBy; bool get transferable;
/// Create a copy of BagItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BagItemCopyWith<BagItem> get copyWith => _$BagItemCopyWithImpl<BagItem>(this as BagItem, _$identity);

  /// Serializes this BagItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BagItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BagItem&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey)&&(identical(other.acquiredAt, _this.acquiredAt) || other.acquiredAt == _this.acquiredAt)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.equipped, _this.equipped) || other.equipped == _this.equipped)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.giftedBy, _this.giftedBy) || other.giftedBy == _this.giftedBy)&&(identical(other.transferable, _this.transferable) || other.transferable == _this.transferable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BagItem;
  return Object.hash(runtimeType,_this.code,_this.category,_this.name,_this.assetKey,_this.acquiredAt,_this.source,_this.equipped,_this.expiresAt,_this.giftedBy,_this.transferable);
}

@override
String toString() {
  final _this = this as BagItem;
  return 'BagItem(code: ${_this.code}, category: ${_this.category}, name: ${_this.name}, assetKey: ${_this.assetKey}, acquiredAt: ${_this.acquiredAt}, source: ${_this.source}, equipped: ${_this.equipped}, expiresAt: ${_this.expiresAt}, giftedBy: ${_this.giftedBy}, transferable: ${_this.transferable})';
}


}

/// @nodoc
abstract mixin class $BagItemCopyWith<$Res>  {
  factory $BagItemCopyWith(BagItem value, $Res Function(BagItem) _then) = _$BagItemCopyWithImpl;
@useResult
$Res call({
 String code, String category, String name, String assetKey, DateTime acquiredAt, String source, bool equipped, DateTime? expiresAt, UserSummary? giftedBy, bool transferable
});


$UserSummaryCopyWith<$Res>? get giftedBy;

}
/// @nodoc
class _$BagItemCopyWithImpl<$Res>
    implements $BagItemCopyWith<$Res> {
  _$BagItemCopyWithImpl(this._self, this._then);

  final BagItem _self;
  final $Res Function(BagItem) _then;

/// Create a copy of BagItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? category = null,Object? name = null,Object? assetKey = null,Object? acquiredAt = null,Object? source = null,Object? equipped = null,Object? expiresAt = freezed,Object? giftedBy = freezed,Object? transferable = null,}) {
  return _then(BagItem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,acquiredAt: null == acquiredAt ? _self.acquiredAt : acquiredAt // ignore: cast_nullable_to_non_nullable
as DateTime,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,equipped: null == equipped ? _self.equipped : equipped // ignore: cast_nullable_to_non_nullable
as bool,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,giftedBy: freezed == giftedBy ? _self.giftedBy : giftedBy // ignore: cast_nullable_to_non_nullable
as UserSummary?,transferable: null == transferable ? _self.transferable : transferable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of BagItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get giftedBy {
    if (_self.giftedBy == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.giftedBy!, (value) {
    return _then(_self.copyWith(giftedBy: value));
  });
}
}


/// Adds pattern-matching-related methods to [BagItem].
extension BagItemPatterns on BagItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BagItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BagItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BagItem value)  $default,){
final _that = this;
switch (_that) {
case _BagItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BagItem value)?  $default,){
final _that = this;
switch (_that) {
case _BagItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String category,  String name,  String assetKey,  DateTime acquiredAt,  String source,  bool equipped,  DateTime? expiresAt,  UserSummary? giftedBy,  bool transferable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BagItem() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.assetKey,_that.acquiredAt,_that.source,_that.equipped,_that.expiresAt,_that.giftedBy,_that.transferable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String category,  String name,  String assetKey,  DateTime acquiredAt,  String source,  bool equipped,  DateTime? expiresAt,  UserSummary? giftedBy,  bool transferable)  $default,) {final _that = this;
switch (_that) {
case _BagItem():
return $default(_that.code,_that.category,_that.name,_that.assetKey,_that.acquiredAt,_that.source,_that.equipped,_that.expiresAt,_that.giftedBy,_that.transferable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String category,  String name,  String assetKey,  DateTime acquiredAt,  String source,  bool equipped,  DateTime? expiresAt,  UserSummary? giftedBy,  bool transferable)?  $default,) {final _that = this;
switch (_that) {
case _BagItem() when $default != null:
return $default(_that.code,_that.category,_that.name,_that.assetKey,_that.acquiredAt,_that.source,_that.equipped,_that.expiresAt,_that.giftedBy,_that.transferable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BagItem implements BagItem {
  const _BagItem({required this.code, required this.category, required this.name, required this.assetKey, required this.acquiredAt, required this.source, required this.equipped, this.expiresAt, this.giftedBy, this.transferable = false});
  factory _BagItem.fromJson(Map<String, dynamic> json) => _$BagItemFromJson(json);

@override final  String code;
@override final  String category;
@override final  String name;
@override final  String assetKey;
@override final  DateTime acquiredAt;
@override final  String source;
@override final  bool equipped;
@override final  DateTime? expiresAt;
@override final  UserSummary? giftedBy;
@override@JsonKey() final  bool transferable;

/// Create a copy of BagItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BagItemCopyWith<_BagItem> get copyWith => __$BagItemCopyWithImpl<_BagItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BagItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BagItem&&(identical(other.code, code) || other.code == code)&&(identical(other.category, category) || other.category == category)&&(identical(other.name, name) || other.name == name)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey)&&(identical(other.acquiredAt, acquiredAt) || other.acquiredAt == acquiredAt)&&(identical(other.source, source) || other.source == source)&&(identical(other.equipped, equipped) || other.equipped == equipped)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.giftedBy, giftedBy) || other.giftedBy == giftedBy)&&(identical(other.transferable, transferable) || other.transferable == transferable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,category,name,assetKey,acquiredAt,source,equipped,expiresAt,giftedBy,transferable);
}

@override
String toString() {
    return 'BagItem(code: $code, category: $category, name: $name, assetKey: $assetKey, acquiredAt: $acquiredAt, source: $source, equipped: $equipped, expiresAt: $expiresAt, giftedBy: $giftedBy, transferable: $transferable)';
}


}

/// @nodoc
abstract mixin class _$BagItemCopyWith<$Res> implements $BagItemCopyWith<$Res> {
  factory _$BagItemCopyWith(_BagItem value, $Res Function(_BagItem) _then) = __$BagItemCopyWithImpl;
@override @useResult
$Res call({
 String code, String category, String name, String assetKey, DateTime acquiredAt, String source, bool equipped, DateTime? expiresAt, UserSummary? giftedBy, bool transferable
});


@override $UserSummaryCopyWith<$Res>? get giftedBy;

}
/// @nodoc
class __$BagItemCopyWithImpl<$Res>
    implements _$BagItemCopyWith<$Res> {
  __$BagItemCopyWithImpl(this._self, this._then);

  final _BagItem _self;
  final $Res Function(_BagItem) _then;

/// Create a copy of BagItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? category = null,Object? name = null,Object? assetKey = null,Object? acquiredAt = null,Object? source = null,Object? equipped = null,Object? expiresAt = freezed,Object? giftedBy = freezed,Object? transferable = null,}) {
  return _then(_BagItem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,acquiredAt: null == acquiredAt ? _self.acquiredAt : acquiredAt // ignore: cast_nullable_to_non_nullable
as DateTime,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,equipped: null == equipped ? _self.equipped : equipped // ignore: cast_nullable_to_non_nullable
as bool,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,giftedBy: freezed == giftedBy ? _self.giftedBy : giftedBy // ignore: cast_nullable_to_non_nullable
as UserSummary?,transferable: null == transferable ? _self.transferable : transferable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of BagItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res>? get giftedBy {
    if (_self.giftedBy == null) {
    return null;
  }

  return $UserSummaryCopyWith<$Res>(_self.giftedBy!, (value) {
    return _then(_self.copyWith(giftedBy: value));
  });
}
}


/// @nodoc
mixin _$BagEquippedItem {

 String get code; String get name; String get assetKey;
/// Create a copy of BagEquippedItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BagEquippedItemCopyWith<BagEquippedItem> get copyWith => _$BagEquippedItemCopyWithImpl<BagEquippedItem>(this as BagEquippedItem, _$identity);

  /// Serializes this BagEquippedItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BagEquippedItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BagEquippedItem&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.assetKey, _this.assetKey) || other.assetKey == _this.assetKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BagEquippedItem;
  return Object.hash(runtimeType,_this.code,_this.name,_this.assetKey);
}

@override
String toString() {
  final _this = this as BagEquippedItem;
  return 'BagEquippedItem(code: ${_this.code}, name: ${_this.name}, assetKey: ${_this.assetKey})';
}


}

/// @nodoc
abstract mixin class $BagEquippedItemCopyWith<$Res>  {
  factory $BagEquippedItemCopyWith(BagEquippedItem value, $Res Function(BagEquippedItem) _then) = _$BagEquippedItemCopyWithImpl;
@useResult
$Res call({
 String code, String name, String assetKey
});




}
/// @nodoc
class _$BagEquippedItemCopyWithImpl<$Res>
    implements $BagEquippedItemCopyWith<$Res> {
  _$BagEquippedItemCopyWithImpl(this._self, this._then);

  final BagEquippedItem _self;
  final $Res Function(BagEquippedItem) _then;

/// Create a copy of BagEquippedItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? assetKey = null,}) {
  return _then(BagEquippedItem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BagEquippedItem].
extension BagEquippedItemPatterns on BagEquippedItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BagEquippedItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BagEquippedItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BagEquippedItem value)  $default,){
final _that = this;
switch (_that) {
case _BagEquippedItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BagEquippedItem value)?  $default,){
final _that = this;
switch (_that) {
case _BagEquippedItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String assetKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BagEquippedItem() when $default != null:
return $default(_that.code,_that.name,_that.assetKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String assetKey)  $default,) {final _that = this;
switch (_that) {
case _BagEquippedItem():
return $default(_that.code,_that.name,_that.assetKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String assetKey)?  $default,) {final _that = this;
switch (_that) {
case _BagEquippedItem() when $default != null:
return $default(_that.code,_that.name,_that.assetKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BagEquippedItem implements BagEquippedItem {
  const _BagEquippedItem({required this.code, required this.name, required this.assetKey});
  factory _BagEquippedItem.fromJson(Map<String, dynamic> json) => _$BagEquippedItemFromJson(json);

@override final  String code;
@override final  String name;
@override final  String assetKey;

/// Create a copy of BagEquippedItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BagEquippedItemCopyWith<_BagEquippedItem> get copyWith => __$BagEquippedItemCopyWithImpl<_BagEquippedItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BagEquippedItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BagEquippedItem&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.assetKey, assetKey) || other.assetKey == assetKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,name,assetKey);
}

@override
String toString() {
    return 'BagEquippedItem(code: $code, name: $name, assetKey: $assetKey)';
}


}

/// @nodoc
abstract mixin class _$BagEquippedItemCopyWith<$Res> implements $BagEquippedItemCopyWith<$Res> {
  factory _$BagEquippedItemCopyWith(_BagEquippedItem value, $Res Function(_BagEquippedItem) _then) = __$BagEquippedItemCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String assetKey
});




}
/// @nodoc
class __$BagEquippedItemCopyWithImpl<$Res>
    implements _$BagEquippedItemCopyWith<$Res> {
  __$BagEquippedItemCopyWithImpl(this._self, this._then);

  final _BagEquippedItem _self;
  final $Res Function(_BagEquippedItem) _then;

/// Create a copy of BagEquippedItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? assetKey = null,}) {
  return _then(_BagEquippedItem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,assetKey: null == assetKey ? _self.assetKey : assetKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$BagEquipped {

 String get category; BagEquippedItem? get equipped;
/// Create a copy of BagEquipped
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BagEquippedCopyWith<BagEquipped> get copyWith => _$BagEquippedCopyWithImpl<BagEquipped>(this as BagEquipped, _$identity);

  /// Serializes this BagEquipped to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BagEquipped;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BagEquipped&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.equipped, _this.equipped) || other.equipped == _this.equipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BagEquipped;
  return Object.hash(runtimeType,_this.category,_this.equipped);
}

@override
String toString() {
  final _this = this as BagEquipped;
  return 'BagEquipped(category: ${_this.category}, equipped: ${_this.equipped})';
}


}

/// @nodoc
abstract mixin class $BagEquippedCopyWith<$Res>  {
  factory $BagEquippedCopyWith(BagEquipped value, $Res Function(BagEquipped) _then) = _$BagEquippedCopyWithImpl;
@useResult
$Res call({
 String category, BagEquippedItem? equipped
});


$BagEquippedItemCopyWith<$Res>? get equipped;

}
/// @nodoc
class _$BagEquippedCopyWithImpl<$Res>
    implements $BagEquippedCopyWith<$Res> {
  _$BagEquippedCopyWithImpl(this._self, this._then);

  final BagEquipped _self;
  final $Res Function(BagEquipped) _then;

/// Create a copy of BagEquipped
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? category = null,Object? equipped = freezed,}) {
  return _then(BagEquipped(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,equipped: freezed == equipped ? _self.equipped : equipped // ignore: cast_nullable_to_non_nullable
as BagEquippedItem?,
  ));
}
/// Create a copy of BagEquipped
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BagEquippedItemCopyWith<$Res>? get equipped {
    if (_self.equipped == null) {
    return null;
  }

  return $BagEquippedItemCopyWith<$Res>(_self.equipped!, (value) {
    return _then(_self.copyWith(equipped: value));
  });
}
}


/// Adds pattern-matching-related methods to [BagEquipped].
extension BagEquippedPatterns on BagEquipped {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BagEquipped value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BagEquipped() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BagEquipped value)  $default,){
final _that = this;
switch (_that) {
case _BagEquipped():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BagEquipped value)?  $default,){
final _that = this;
switch (_that) {
case _BagEquipped() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String category,  BagEquippedItem? equipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BagEquipped() when $default != null:
return $default(_that.category,_that.equipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String category,  BagEquippedItem? equipped)  $default,) {final _that = this;
switch (_that) {
case _BagEquipped():
return $default(_that.category,_that.equipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String category,  BagEquippedItem? equipped)?  $default,) {final _that = this;
switch (_that) {
case _BagEquipped() when $default != null:
return $default(_that.category,_that.equipped);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BagEquipped implements BagEquipped {
  const _BagEquipped({required this.category, this.equipped});
  factory _BagEquipped.fromJson(Map<String, dynamic> json) => _$BagEquippedFromJson(json);

@override final  String category;
@override final  BagEquippedItem? equipped;

/// Create a copy of BagEquipped
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BagEquippedCopyWith<_BagEquipped> get copyWith => __$BagEquippedCopyWithImpl<_BagEquipped>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BagEquippedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BagEquipped&&(identical(other.category, category) || other.category == category)&&(identical(other.equipped, equipped) || other.equipped == equipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,category,equipped);
}

@override
String toString() {
    return 'BagEquipped(category: $category, equipped: $equipped)';
}


}

/// @nodoc
abstract mixin class _$BagEquippedCopyWith<$Res> implements $BagEquippedCopyWith<$Res> {
  factory _$BagEquippedCopyWith(_BagEquipped value, $Res Function(_BagEquipped) _then) = __$BagEquippedCopyWithImpl;
@override @useResult
$Res call({
 String category, BagEquippedItem? equipped
});


@override $BagEquippedItemCopyWith<$Res>? get equipped;

}
/// @nodoc
class __$BagEquippedCopyWithImpl<$Res>
    implements _$BagEquippedCopyWith<$Res> {
  __$BagEquippedCopyWithImpl(this._self, this._then);

  final _BagEquipped _self;
  final $Res Function(_BagEquipped) _then;

/// Create a copy of BagEquipped
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = null,Object? equipped = freezed,}) {
  return _then(_BagEquipped(
category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,equipped: freezed == equipped ? _self.equipped : equipped // ignore: cast_nullable_to_non_nullable
as BagEquippedItem?,
  ));
}

/// Create a copy of BagEquipped
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BagEquippedItemCopyWith<$Res>? get equipped {
    if (_self.equipped == null) {
    return null;
  }

  return $BagEquippedItemCopyWith<$Res>(_self.equipped!, (value) {
    return _then(_self.copyWith(equipped: value));
  });
}
}

// dart format on
