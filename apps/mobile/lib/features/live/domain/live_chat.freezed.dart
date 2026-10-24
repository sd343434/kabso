// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveChatEntry {

 String get id; String get roomId; UserSummary get author;@JsonKey(unknownEnumValue: LiveChatRole.viewer) LiveChatRole get authorRole; String get text; DateTime get createdAt;
/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveChatEntryCopyWith<LiveChatEntry> get copyWith => _$LiveChatEntryCopyWithImpl<LiveChatEntry>(this as LiveChatEntry, _$identity);

  /// Serializes this LiveChatEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveChatEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveChatEntry&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.authorRole, _this.authorRole) || other.authorRole == _this.authorRole)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveChatEntry;
  return Object.hash(runtimeType,_this.id,_this.roomId,_this.author,_this.authorRole,_this.text,_this.createdAt);
}

@override
String toString() {
  final _this = this as LiveChatEntry;
  return 'LiveChatEntry(id: ${_this.id}, roomId: ${_this.roomId}, author: ${_this.author}, authorRole: ${_this.authorRole}, text: ${_this.text}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LiveChatEntryCopyWith<$Res>  {
  factory $LiveChatEntryCopyWith(LiveChatEntry value, $Res Function(LiveChatEntry) _then) = _$LiveChatEntryCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, UserSummary author,@JsonKey(unknownEnumValue: LiveChatRole.viewer) LiveChatRole authorRole, String text, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get author;

}
/// @nodoc
class _$LiveChatEntryCopyWithImpl<$Res>
    implements $LiveChatEntryCopyWith<$Res> {
  _$LiveChatEntryCopyWithImpl(this._self, this._then);

  final LiveChatEntry _self;
  final $Res Function(LiveChatEntry) _then;

/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? author = null,Object? authorRole = null,Object? text = null,Object? createdAt = null,}) {
  return _then(LiveChatEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,authorRole: null == authorRole ? _self.authorRole : authorRole // ignore: cast_nullable_to_non_nullable
as LiveChatRole,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get author {
  
  return $UserSummaryCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveChatEntry].
extension LiveChatEntryPatterns on LiveChatEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveChatEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveChatEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveChatEntry value)  $default,){
final _that = this;
switch (_that) {
case _LiveChatEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveChatEntry value)?  $default,){
final _that = this;
switch (_that) {
case _LiveChatEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  UserSummary author, @JsonKey(unknownEnumValue: LiveChatRole.viewer)  LiveChatRole authorRole,  String text,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveChatEntry() when $default != null:
return $default(_that.id,_that.roomId,_that.author,_that.authorRole,_that.text,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  UserSummary author, @JsonKey(unknownEnumValue: LiveChatRole.viewer)  LiveChatRole authorRole,  String text,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LiveChatEntry():
return $default(_that.id,_that.roomId,_that.author,_that.authorRole,_that.text,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  UserSummary author, @JsonKey(unknownEnumValue: LiveChatRole.viewer)  LiveChatRole authorRole,  String text,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveChatEntry() when $default != null:
return $default(_that.id,_that.roomId,_that.author,_that.authorRole,_that.text,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveChatEntry implements LiveChatEntry {
  const _LiveChatEntry({required this.id, required this.roomId, required this.author, @JsonKey(unknownEnumValue: LiveChatRole.viewer) required this.authorRole, required this.text, required this.createdAt});
  factory _LiveChatEntry.fromJson(Map<String, dynamic> json) => _$LiveChatEntryFromJson(json);

@override final  String id;
@override final  String roomId;
@override final  UserSummary author;
@override@JsonKey(unknownEnumValue: LiveChatRole.viewer) final  LiveChatRole authorRole;
@override final  String text;
@override final  DateTime createdAt;

/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveChatEntryCopyWith<_LiveChatEntry> get copyWith => __$LiveChatEntryCopyWithImpl<_LiveChatEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveChatEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveChatEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.author, author) || other.author == author)&&(identical(other.authorRole, authorRole) || other.authorRole == authorRole)&&(identical(other.text, text) || other.text == text)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,roomId,author,authorRole,text,createdAt);
}

@override
String toString() {
    return 'LiveChatEntry(id: $id, roomId: $roomId, author: $author, authorRole: $authorRole, text: $text, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LiveChatEntryCopyWith<$Res> implements $LiveChatEntryCopyWith<$Res> {
  factory _$LiveChatEntryCopyWith(_LiveChatEntry value, $Res Function(_LiveChatEntry) _then) = __$LiveChatEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, UserSummary author,@JsonKey(unknownEnumValue: LiveChatRole.viewer) LiveChatRole authorRole, String text, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get author;

}
/// @nodoc
class __$LiveChatEntryCopyWithImpl<$Res>
    implements _$LiveChatEntryCopyWith<$Res> {
  __$LiveChatEntryCopyWithImpl(this._self, this._then);

  final _LiveChatEntry _self;
  final $Res Function(_LiveChatEntry) _then;

/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? author = null,Object? authorRole = null,Object? text = null,Object? createdAt = null,}) {
  return _then(_LiveChatEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,authorRole: null == authorRole ? _self.authorRole : authorRole // ignore: cast_nullable_to_non_nullable
as LiveChatRole,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveChatEntry
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
mixin _$LiveChatMute {

 UserSummary get user; DateTime get mutedAt;
/// Create a copy of LiveChatMute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveChatMuteCopyWith<LiveChatMute> get copyWith => _$LiveChatMuteCopyWithImpl<LiveChatMute>(this as LiveChatMute, _$identity);

  /// Serializes this LiveChatMute to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveChatMute;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveChatMute&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.mutedAt, _this.mutedAt) || other.mutedAt == _this.mutedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveChatMute;
  return Object.hash(runtimeType,_this.user,_this.mutedAt);
}

@override
String toString() {
  final _this = this as LiveChatMute;
  return 'LiveChatMute(user: ${_this.user}, mutedAt: ${_this.mutedAt})';
}


}

/// @nodoc
abstract mixin class $LiveChatMuteCopyWith<$Res>  {
  factory $LiveChatMuteCopyWith(LiveChatMute value, $Res Function(LiveChatMute) _then) = _$LiveChatMuteCopyWithImpl;
@useResult
$Res call({
 UserSummary user, DateTime mutedAt
});


$UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class _$LiveChatMuteCopyWithImpl<$Res>
    implements $LiveChatMuteCopyWith<$Res> {
  _$LiveChatMuteCopyWithImpl(this._self, this._then);

  final LiveChatMute _self;
  final $Res Function(LiveChatMute) _then;

/// Create a copy of LiveChatMute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? mutedAt = null,}) {
  return _then(LiveChatMute(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,mutedAt: null == mutedAt ? _self.mutedAt : mutedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveChatMute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveChatMute].
extension LiveChatMutePatterns on LiveChatMute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveChatMute value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveChatMute() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveChatMute value)  $default,){
final _that = this;
switch (_that) {
case _LiveChatMute():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveChatMute value)?  $default,){
final _that = this;
switch (_that) {
case _LiveChatMute() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserSummary user,  DateTime mutedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveChatMute() when $default != null:
return $default(_that.user,_that.mutedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserSummary user,  DateTime mutedAt)  $default,) {final _that = this;
switch (_that) {
case _LiveChatMute():
return $default(_that.user,_that.mutedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserSummary user,  DateTime mutedAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveChatMute() when $default != null:
return $default(_that.user,_that.mutedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveChatMute implements LiveChatMute {
  const _LiveChatMute({required this.user, required this.mutedAt});
  factory _LiveChatMute.fromJson(Map<String, dynamic> json) => _$LiveChatMuteFromJson(json);

@override final  UserSummary user;
@override final  DateTime mutedAt;

/// Create a copy of LiveChatMute
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveChatMuteCopyWith<_LiveChatMute> get copyWith => __$LiveChatMuteCopyWithImpl<_LiveChatMute>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveChatMuteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveChatMute&&(identical(other.user, user) || other.user == user)&&(identical(other.mutedAt, mutedAt) || other.mutedAt == mutedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,user,mutedAt);
}

@override
String toString() {
    return 'LiveChatMute(user: $user, mutedAt: $mutedAt)';
}


}

/// @nodoc
abstract mixin class _$LiveChatMuteCopyWith<$Res> implements $LiveChatMuteCopyWith<$Res> {
  factory _$LiveChatMuteCopyWith(_LiveChatMute value, $Res Function(_LiveChatMute) _then) = __$LiveChatMuteCopyWithImpl;
@override @useResult
$Res call({
 UserSummary user, DateTime mutedAt
});


@override $UserSummaryCopyWith<$Res> get user;

}
/// @nodoc
class __$LiveChatMuteCopyWithImpl<$Res>
    implements _$LiveChatMuteCopyWith<$Res> {
  __$LiveChatMuteCopyWithImpl(this._self, this._then);

  final _LiveChatMute _self;
  final $Res Function(_LiveChatMute) _then;

/// Create a copy of LiveChatMute
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? mutedAt = null,}) {
  return _then(_LiveChatMute(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummary,mutedAt: null == mutedAt ? _self.mutedAt : mutedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveChatMute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get user {
  
  return $UserSummaryCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
