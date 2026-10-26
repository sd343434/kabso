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
mixin _$LiveChatMedia {

 String get id; String get url; String get thumbUrl; int get width; int get height; int? get durationMs;
/// Create a copy of LiveChatMedia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveChatMediaCopyWith<LiveChatMedia> get copyWith => _$LiveChatMediaCopyWithImpl<LiveChatMedia>(this as LiveChatMedia, _$identity);

  /// Serializes this LiveChatMedia to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveChatMedia;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveChatMedia&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.thumbUrl, _this.thumbUrl) || other.thumbUrl == _this.thumbUrl)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveChatMedia;
  return Object.hash(runtimeType,_this.id,_this.url,_this.thumbUrl,_this.width,_this.height,_this.durationMs);
}

@override
String toString() {
  final _this = this as LiveChatMedia;
  return 'LiveChatMedia(id: ${_this.id}, url: ${_this.url}, thumbUrl: ${_this.thumbUrl}, width: ${_this.width}, height: ${_this.height}, durationMs: ${_this.durationMs})';
}


}

/// @nodoc
abstract mixin class $LiveChatMediaCopyWith<$Res>  {
  factory $LiveChatMediaCopyWith(LiveChatMedia value, $Res Function(LiveChatMedia) _then) = _$LiveChatMediaCopyWithImpl;
@useResult
$Res call({
 String id, String url, String thumbUrl, int width, int height, int? durationMs
});




}
/// @nodoc
class _$LiveChatMediaCopyWithImpl<$Res>
    implements $LiveChatMediaCopyWith<$Res> {
  _$LiveChatMediaCopyWithImpl(this._self, this._then);

  final LiveChatMedia _self;
  final $Res Function(LiveChatMedia) _then;

/// Create a copy of LiveChatMedia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? thumbUrl = null,Object? width = null,Object? height = null,Object? durationMs = freezed,}) {
  return _then(LiveChatMedia(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumbUrl: null == thumbUrl ? _self.thumbUrl : thumbUrl // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveChatMedia].
extension LiveChatMediaPatterns on LiveChatMedia {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveChatMedia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveChatMedia() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveChatMedia value)  $default,){
final _that = this;
switch (_that) {
case _LiveChatMedia():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveChatMedia value)?  $default,){
final _that = this;
switch (_that) {
case _LiveChatMedia() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String thumbUrl,  int width,  int height,  int? durationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveChatMedia() when $default != null:
return $default(_that.id,_that.url,_that.thumbUrl,_that.width,_that.height,_that.durationMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String thumbUrl,  int width,  int height,  int? durationMs)  $default,) {final _that = this;
switch (_that) {
case _LiveChatMedia():
return $default(_that.id,_that.url,_that.thumbUrl,_that.width,_that.height,_that.durationMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String thumbUrl,  int width,  int height,  int? durationMs)?  $default,) {final _that = this;
switch (_that) {
case _LiveChatMedia() when $default != null:
return $default(_that.id,_that.url,_that.thumbUrl,_that.width,_that.height,_that.durationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveChatMedia implements LiveChatMedia {
  const _LiveChatMedia({required this.id, required this.url, required this.thumbUrl, this.width = 0, this.height = 0, this.durationMs});
  factory _LiveChatMedia.fromJson(Map<String, dynamic> json) => _$LiveChatMediaFromJson(json);

@override final  String id;
@override final  String url;
@override final  String thumbUrl;
@override@JsonKey() final  int width;
@override@JsonKey() final  int height;
@override final  int? durationMs;

/// Create a copy of LiveChatMedia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveChatMediaCopyWith<_LiveChatMedia> get copyWith => __$LiveChatMediaCopyWithImpl<_LiveChatMedia>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveChatMediaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveChatMedia&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumbUrl, thumbUrl) || other.thumbUrl == thumbUrl)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,url,thumbUrl,width,height,durationMs);
}

@override
String toString() {
    return 'LiveChatMedia(id: $id, url: $url, thumbUrl: $thumbUrl, width: $width, height: $height, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class _$LiveChatMediaCopyWith<$Res> implements $LiveChatMediaCopyWith<$Res> {
  factory _$LiveChatMediaCopyWith(_LiveChatMedia value, $Res Function(_LiveChatMedia) _then) = __$LiveChatMediaCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String thumbUrl, int width, int height, int? durationMs
});




}
/// @nodoc
class __$LiveChatMediaCopyWithImpl<$Res>
    implements _$LiveChatMediaCopyWith<$Res> {
  __$LiveChatMediaCopyWithImpl(this._self, this._then);

  final _LiveChatMedia _self;
  final $Res Function(_LiveChatMedia) _then;

/// Create a copy of LiveChatMedia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? thumbUrl = null,Object? width = null,Object? height = null,Object? durationMs = freezed,}) {
  return _then(_LiveChatMedia(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumbUrl: null == thumbUrl ? _self.thumbUrl : thumbUrl // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LiveChatEntry {

 String get id; String get roomId; UserSummary get author;@JsonKey(unknownEnumValue: LiveChatRole.viewer) LiveChatRole get authorRole; String get text; DateTime get createdAt;@JsonKey(unknownEnumValue: LiveChatKind.text) LiveChatKind get kind;/// The clip or picture of a VOICE / IMAGE message; null for TEXT and
/// once it expired.
 LiveChatMedia? get media;/// VOICE and IMAGE: sent + 60 s, when the app hides it (§10.19).
 DateTime? get expiresAt;/// v1.24-live (CP-021, §10.24): the author's couple had the Exclusive
/// Chat Bubble (`CHAT_BUBBLE`) when it was sent; the line is drawn in
/// the CP bubble. Older servers send nothing (false).
 bool get cpBubble;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveChatEntry&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.authorRole, _this.authorRole) || other.authorRole == _this.authorRole)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.cpBubble, _this.cpBubble) || other.cpBubble == _this.cpBubble));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveChatEntry;
  return Object.hash(runtimeType,_this.id,_this.roomId,_this.author,_this.authorRole,_this.text,_this.createdAt,_this.kind,_this.media,_this.expiresAt,_this.cpBubble);
}

@override
String toString() {
  final _this = this as LiveChatEntry;
  return 'LiveChatEntry(id: ${_this.id}, roomId: ${_this.roomId}, author: ${_this.author}, authorRole: ${_this.authorRole}, text: ${_this.text}, createdAt: ${_this.createdAt}, kind: ${_this.kind}, media: ${_this.media}, expiresAt: ${_this.expiresAt}, cpBubble: ${_this.cpBubble})';
}


}

/// @nodoc
abstract mixin class $LiveChatEntryCopyWith<$Res>  {
  factory $LiveChatEntryCopyWith(LiveChatEntry value, $Res Function(LiveChatEntry) _then) = _$LiveChatEntryCopyWithImpl;
@useResult
$Res call({
 String id, String roomId, UserSummary author,@JsonKey(unknownEnumValue: LiveChatRole.viewer) LiveChatRole authorRole, String text, DateTime createdAt,@JsonKey(unknownEnumValue: LiveChatKind.text) LiveChatKind kind, LiveChatMedia? media, DateTime? expiresAt, bool cpBubble
});


$UserSummaryCopyWith<$Res> get author;$LiveChatMediaCopyWith<$Res>? get media;

}
/// @nodoc
class _$LiveChatEntryCopyWithImpl<$Res>
    implements $LiveChatEntryCopyWith<$Res> {
  _$LiveChatEntryCopyWithImpl(this._self, this._then);

  final LiveChatEntry _self;
  final $Res Function(LiveChatEntry) _then;

/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomId = null,Object? author = null,Object? authorRole = null,Object? text = null,Object? createdAt = null,Object? kind = null,Object? media = freezed,Object? expiresAt = freezed,Object? cpBubble = null,}) {
  return _then(LiveChatEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,authorRole: null == authorRole ? _self.authorRole : authorRole // ignore: cast_nullable_to_non_nullable
as LiveChatRole,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveChatKind,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as LiveChatMedia?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cpBubble: null == cpBubble ? _self.cpBubble : cpBubble // ignore: cast_nullable_to_non_nullable
as bool,
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
}/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveChatMediaCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $LiveChatMediaCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomId,  UserSummary author, @JsonKey(unknownEnumValue: LiveChatRole.viewer)  LiveChatRole authorRole,  String text,  DateTime createdAt, @JsonKey(unknownEnumValue: LiveChatKind.text)  LiveChatKind kind,  LiveChatMedia? media,  DateTime? expiresAt,  bool cpBubble)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveChatEntry() when $default != null:
return $default(_that.id,_that.roomId,_that.author,_that.authorRole,_that.text,_that.createdAt,_that.kind,_that.media,_that.expiresAt,_that.cpBubble);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomId,  UserSummary author, @JsonKey(unknownEnumValue: LiveChatRole.viewer)  LiveChatRole authorRole,  String text,  DateTime createdAt, @JsonKey(unknownEnumValue: LiveChatKind.text)  LiveChatKind kind,  LiveChatMedia? media,  DateTime? expiresAt,  bool cpBubble)  $default,) {final _that = this;
switch (_that) {
case _LiveChatEntry():
return $default(_that.id,_that.roomId,_that.author,_that.authorRole,_that.text,_that.createdAt,_that.kind,_that.media,_that.expiresAt,_that.cpBubble);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomId,  UserSummary author, @JsonKey(unknownEnumValue: LiveChatRole.viewer)  LiveChatRole authorRole,  String text,  DateTime createdAt, @JsonKey(unknownEnumValue: LiveChatKind.text)  LiveChatKind kind,  LiveChatMedia? media,  DateTime? expiresAt,  bool cpBubble)?  $default,) {final _that = this;
switch (_that) {
case _LiveChatEntry() when $default != null:
return $default(_that.id,_that.roomId,_that.author,_that.authorRole,_that.text,_that.createdAt,_that.kind,_that.media,_that.expiresAt,_that.cpBubble);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveChatEntry implements LiveChatEntry {
  const _LiveChatEntry({required this.id, required this.roomId, required this.author, @JsonKey(unknownEnumValue: LiveChatRole.viewer) required this.authorRole, required this.text, required this.createdAt, @JsonKey(unknownEnumValue: LiveChatKind.text) this.kind = LiveChatKind.text, this.media, this.expiresAt, this.cpBubble = false});
  factory _LiveChatEntry.fromJson(Map<String, dynamic> json) => _$LiveChatEntryFromJson(json);

@override final  String id;
@override final  String roomId;
@override final  UserSummary author;
@override@JsonKey(unknownEnumValue: LiveChatRole.viewer) final  LiveChatRole authorRole;
@override final  String text;
@override final  DateTime createdAt;
@override@JsonKey(unknownEnumValue: LiveChatKind.text) final  LiveChatKind kind;
/// The clip or picture of a VOICE / IMAGE message; null for TEXT and
/// once it expired.
@override final  LiveChatMedia? media;
/// VOICE and IMAGE: sent + 60 s, when the app hides it (§10.19).
@override final  DateTime? expiresAt;
/// v1.24-live (CP-021, §10.24): the author's couple had the Exclusive
/// Chat Bubble (`CHAT_BUBBLE`) when it was sent; the line is drawn in
/// the CP bubble. Older servers send nothing (false).
@override@JsonKey() final  bool cpBubble;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveChatEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.author, author) || other.author == author)&&(identical(other.authorRole, authorRole) || other.authorRole == authorRole)&&(identical(other.text, text) || other.text == text)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.media, media) || other.media == media)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.cpBubble, cpBubble) || other.cpBubble == cpBubble));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,roomId,author,authorRole,text,createdAt,kind,media,expiresAt,cpBubble);
}

@override
String toString() {
    return 'LiveChatEntry(id: $id, roomId: $roomId, author: $author, authorRole: $authorRole, text: $text, createdAt: $createdAt, kind: $kind, media: $media, expiresAt: $expiresAt, cpBubble: $cpBubble)';
}


}

/// @nodoc
abstract mixin class _$LiveChatEntryCopyWith<$Res> implements $LiveChatEntryCopyWith<$Res> {
  factory _$LiveChatEntryCopyWith(_LiveChatEntry value, $Res Function(_LiveChatEntry) _then) = __$LiveChatEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomId, UserSummary author,@JsonKey(unknownEnumValue: LiveChatRole.viewer) LiveChatRole authorRole, String text, DateTime createdAt,@JsonKey(unknownEnumValue: LiveChatKind.text) LiveChatKind kind, LiveChatMedia? media, DateTime? expiresAt, bool cpBubble
});


@override $UserSummaryCopyWith<$Res> get author;@override $LiveChatMediaCopyWith<$Res>? get media;

}
/// @nodoc
class __$LiveChatEntryCopyWithImpl<$Res>
    implements _$LiveChatEntryCopyWith<$Res> {
  __$LiveChatEntryCopyWithImpl(this._self, this._then);

  final _LiveChatEntry _self;
  final $Res Function(_LiveChatEntry) _then;

/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomId = null,Object? author = null,Object? authorRole = null,Object? text = null,Object? createdAt = null,Object? kind = null,Object? media = freezed,Object? expiresAt = freezed,Object? cpBubble = null,}) {
  return _then(_LiveChatEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as UserSummary,authorRole: null == authorRole ? _self.authorRole : authorRole // ignore: cast_nullable_to_non_nullable
as LiveChatRole,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LiveChatKind,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as LiveChatMedia?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cpBubble: null == cpBubble ? _self.cpBubble : cpBubble // ignore: cast_nullable_to_non_nullable
as bool,
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
}/// Create a copy of LiveChatEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveChatMediaCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $LiveChatMediaCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
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


/// @nodoc
mixin _$LiveBullet {

 String get id; String get text; UserSummary get sender; String get roomId; DateTime get createdAt;
/// Create a copy of LiveBullet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveBulletCopyWith<LiveBullet> get copyWith => _$LiveBulletCopyWithImpl<LiveBullet>(this as LiveBullet, _$identity);

  /// Serializes this LiveBullet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LiveBullet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveBullet&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&(identical(other.roomId, _this.roomId) || other.roomId == _this.roomId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LiveBullet;
  return Object.hash(runtimeType,_this.id,_this.text,_this.sender,_this.roomId,_this.createdAt);
}

@override
String toString() {
  final _this = this as LiveBullet;
  return 'LiveBullet(id: ${_this.id}, text: ${_this.text}, sender: ${_this.sender}, roomId: ${_this.roomId}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LiveBulletCopyWith<$Res>  {
  factory $LiveBulletCopyWith(LiveBullet value, $Res Function(LiveBullet) _then) = _$LiveBulletCopyWithImpl;
@useResult
$Res call({
 String id, String text, UserSummary sender, String roomId, DateTime createdAt
});


$UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class _$LiveBulletCopyWithImpl<$Res>
    implements $LiveBulletCopyWith<$Res> {
  _$LiveBulletCopyWithImpl(this._self, this._then);

  final LiveBullet _self;
  final $Res Function(LiveBullet) _then;

/// Create a copy of LiveBullet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? sender = null,Object? roomId = null,Object? createdAt = null,}) {
  return _then(LiveBullet(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of LiveBullet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryCopyWith<$Res> get sender {
  
  return $UserSummaryCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveBullet].
extension LiveBulletPatterns on LiveBullet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveBullet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveBullet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveBullet value)  $default,){
final _that = this;
switch (_that) {
case _LiveBullet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveBullet value)?  $default,){
final _that = this;
switch (_that) {
case _LiveBullet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  UserSummary sender,  String roomId,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveBullet() when $default != null:
return $default(_that.id,_that.text,_that.sender,_that.roomId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  UserSummary sender,  String roomId,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LiveBullet():
return $default(_that.id,_that.text,_that.sender,_that.roomId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  UserSummary sender,  String roomId,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LiveBullet() when $default != null:
return $default(_that.id,_that.text,_that.sender,_that.roomId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveBullet implements LiveBullet {
  const _LiveBullet({required this.id, required this.text, required this.sender, required this.roomId, required this.createdAt});
  factory _LiveBullet.fromJson(Map<String, dynamic> json) => _$LiveBulletFromJson(json);

@override final  String id;
@override final  String text;
@override final  UserSummary sender;
@override final  String roomId;
@override final  DateTime createdAt;

/// Create a copy of LiveBullet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveBulletCopyWith<_LiveBullet> get copyWith => __$LiveBulletCopyWithImpl<_LiveBullet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveBulletToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveBullet&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,sender,roomId,createdAt);
}

@override
String toString() {
    return 'LiveBullet(id: $id, text: $text, sender: $sender, roomId: $roomId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LiveBulletCopyWith<$Res> implements $LiveBulletCopyWith<$Res> {
  factory _$LiveBulletCopyWith(_LiveBullet value, $Res Function(_LiveBullet) _then) = __$LiveBulletCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, UserSummary sender, String roomId, DateTime createdAt
});


@override $UserSummaryCopyWith<$Res> get sender;

}
/// @nodoc
class __$LiveBulletCopyWithImpl<$Res>
    implements _$LiveBulletCopyWith<$Res> {
  __$LiveBulletCopyWithImpl(this._self, this._then);

  final _LiveBullet _self;
  final $Res Function(_LiveBullet) _then;

/// Create a copy of LiveBullet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? sender = null,Object? roomId = null,Object? createdAt = null,}) {
  return _then(_LiveBullet(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as UserSummary,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of LiveBullet
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
