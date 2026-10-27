// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_rooms_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveHubState {

/// `GET /live/config` `hostingEnabled`. While `false` nobody can go live,
/// so the list shows the honest unavailable state and lists nothing.
 bool get hostingEnabled;/// When this state was loaded from the first page.
 DateTime get fetchedAt;/// Rooms in server order, deduplicated by id across pages.
 List<LiveRoomSummary> get rooms; String? get nextCursor; bool get hasMore;/// A next page is loading (footer skeletons).
 bool get loadingMore;/// The last next-page request failed (inline footer error + retry).
 AppFailure? get loadMoreError;/// D133: Nearby answered `COUNTRY_NOT_SET` (the person has no country:
/// the list asks them to set it).
 bool get countryNotSet;
/// Create a copy of LiveHubState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveHubStateCopyWith<LiveHubState> get copyWith => _$LiveHubStateCopyWithImpl<LiveHubState>(this as LiveHubState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveHubState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveHubState&&(identical(other.hostingEnabled, _this.hostingEnabled) || other.hostingEnabled == _this.hostingEnabled)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt)&&const DeepCollectionEquality().equals(other.rooms, _this.rooms)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor)&&(identical(other.hasMore, _this.hasMore) || other.hasMore == _this.hasMore)&&(identical(other.loadingMore, _this.loadingMore) || other.loadingMore == _this.loadingMore)&&(identical(other.loadMoreError, _this.loadMoreError) || other.loadMoreError == _this.loadMoreError)&&(identical(other.countryNotSet, _this.countryNotSet) || other.countryNotSet == _this.countryNotSet));
}


@override
int get hashCode {
  final _this = this as LiveHubState;
  return Object.hash(runtimeType,_this.hostingEnabled,_this.fetchedAt,const DeepCollectionEquality().hash(_this.rooms),_this.nextCursor,_this.hasMore,_this.loadingMore,_this.loadMoreError,_this.countryNotSet);
}

@override
String toString() {
  final _this = this as LiveHubState;
  return 'LiveHubState(hostingEnabled: ${_this.hostingEnabled}, fetchedAt: ${_this.fetchedAt}, rooms: ${_this.rooms}, nextCursor: ${_this.nextCursor}, hasMore: ${_this.hasMore}, loadingMore: ${_this.loadingMore}, loadMoreError: ${_this.loadMoreError}, countryNotSet: ${_this.countryNotSet})';
}


}

/// @nodoc
abstract mixin class $LiveHubStateCopyWith<$Res>  {
  factory $LiveHubStateCopyWith(LiveHubState value, $Res Function(LiveHubState) _then) = _$LiveHubStateCopyWithImpl;
@useResult
$Res call({
 bool hostingEnabled, DateTime fetchedAt, List<LiveRoomSummary> rooms, String? nextCursor, bool hasMore, bool loadingMore, AppFailure? loadMoreError, bool countryNotSet
});




}
/// @nodoc
class _$LiveHubStateCopyWithImpl<$Res>
    implements $LiveHubStateCopyWith<$Res> {
  _$LiveHubStateCopyWithImpl(this._self, this._then);

  final LiveHubState _self;
  final $Res Function(LiveHubState) _then;

/// Create a copy of LiveHubState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostingEnabled = null,Object? fetchedAt = null,Object? rooms = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? loadMoreError = freezed,Object? countryNotSet = null,}) {
  return _then(LiveHubState(
hostingEnabled: null == hostingEnabled ? _self.hostingEnabled : hostingEnabled // ignore: cast_nullable_to_non_nullable
as bool,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rooms: null == rooms ? _self.rooms : rooms // ignore: cast_nullable_to_non_nullable
as List<LiveRoomSummary>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,loadMoreError: freezed == loadMoreError ? _self.loadMoreError : loadMoreError // ignore: cast_nullable_to_non_nullable
as AppFailure?,countryNotSet: null == countryNotSet ? _self.countryNotSet : countryNotSet // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveHubState].
extension LiveHubStatePatterns on LiveHubState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveHubState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveHubState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveHubState value)  $default,){
final _that = this;
switch (_that) {
case _LiveHubState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveHubState value)?  $default,){
final _that = this;
switch (_that) {
case _LiveHubState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hostingEnabled,  DateTime fetchedAt,  List<LiveRoomSummary> rooms,  String? nextCursor,  bool hasMore,  bool loadingMore,  AppFailure? loadMoreError,  bool countryNotSet)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveHubState() when $default != null:
return $default(_that.hostingEnabled,_that.fetchedAt,_that.rooms,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.loadMoreError,_that.countryNotSet);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hostingEnabled,  DateTime fetchedAt,  List<LiveRoomSummary> rooms,  String? nextCursor,  bool hasMore,  bool loadingMore,  AppFailure? loadMoreError,  bool countryNotSet)  $default,) {final _that = this;
switch (_that) {
case _LiveHubState():
return $default(_that.hostingEnabled,_that.fetchedAt,_that.rooms,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.loadMoreError,_that.countryNotSet);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hostingEnabled,  DateTime fetchedAt,  List<LiveRoomSummary> rooms,  String? nextCursor,  bool hasMore,  bool loadingMore,  AppFailure? loadMoreError,  bool countryNotSet)?  $default,) {final _that = this;
switch (_that) {
case _LiveHubState() when $default != null:
return $default(_that.hostingEnabled,_that.fetchedAt,_that.rooms,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.loadMoreError,_that.countryNotSet);case _:
  return null;

}
}

}

/// @nodoc


class _LiveHubState extends LiveHubState {
  const _LiveHubState({required this.hostingEnabled, required this.fetchedAt,  List<LiveRoomSummary> rooms = const <LiveRoomSummary>[], this.nextCursor, this.hasMore = false, this.loadingMore = false, this.loadMoreError, this.countryNotSet = false}): _rooms = rooms,super._();
  

/// `GET /live/config` `hostingEnabled`. While `false` nobody can go live,
/// so the list shows the honest unavailable state and lists nothing.
@override final  bool hostingEnabled;
/// When this state was loaded from the first page.
@override final  DateTime fetchedAt;
/// Rooms in server order, deduplicated by id across pages.
 final  List<LiveRoomSummary> _rooms;
/// Rooms in server order, deduplicated by id across pages.
@override@JsonKey() List<LiveRoomSummary> get rooms {
  if (_rooms is EqualUnmodifiableListView) return _rooms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rooms);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
/// A next page is loading (footer skeletons).
@override@JsonKey() final  bool loadingMore;
/// The last next-page request failed (inline footer error + retry).
@override final  AppFailure? loadMoreError;
/// D133: Nearby answered `COUNTRY_NOT_SET` (the person has no country:
/// the list asks them to set it).
@override@JsonKey() final  bool countryNotSet;

/// Create a copy of LiveHubState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveHubStateCopyWith<_LiveHubState> get copyWith => __$LiveHubStateCopyWithImpl<_LiveHubState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveHubState&&(identical(other.hostingEnabled, hostingEnabled) || other.hostingEnabled == hostingEnabled)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&const DeepCollectionEquality().equals(other.rooms, _rooms)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.loadMoreError, loadMoreError) || other.loadMoreError == loadMoreError)&&(identical(other.countryNotSet, countryNotSet) || other.countryNotSet == countryNotSet));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hostingEnabled,fetchedAt,const DeepCollectionEquality().hash(_rooms),nextCursor,hasMore,loadingMore,loadMoreError,countryNotSet);
}

@override
String toString() {
    return 'LiveHubState(hostingEnabled: $hostingEnabled, fetchedAt: $fetchedAt, rooms: $rooms, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, loadMoreError: $loadMoreError, countryNotSet: $countryNotSet)';
}


}

/// @nodoc
abstract mixin class _$LiveHubStateCopyWith<$Res> implements $LiveHubStateCopyWith<$Res> {
  factory _$LiveHubStateCopyWith(_LiveHubState value, $Res Function(_LiveHubState) _then) = __$LiveHubStateCopyWithImpl;
@override @useResult
$Res call({
 bool hostingEnabled, DateTime fetchedAt, List<LiveRoomSummary> rooms, String? nextCursor, bool hasMore, bool loadingMore, AppFailure? loadMoreError, bool countryNotSet
});




}
/// @nodoc
class __$LiveHubStateCopyWithImpl<$Res>
    implements _$LiveHubStateCopyWith<$Res> {
  __$LiveHubStateCopyWithImpl(this._self, this._then);

  final _LiveHubState _self;
  final $Res Function(_LiveHubState) _then;

/// Create a copy of LiveHubState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostingEnabled = null,Object? fetchedAt = null,Object? rooms = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? loadMoreError = freezed,Object? countryNotSet = null,}) {
  return _then(_LiveHubState(
hostingEnabled: null == hostingEnabled ? _self.hostingEnabled : hostingEnabled // ignore: cast_nullable_to_non_nullable
as bool,fetchedAt: null == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rooms: null == rooms ? _self._rooms : rooms // ignore: cast_nullable_to_non_nullable
as List<LiveRoomSummary>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,loadMoreError: freezed == loadMoreError ? _self.loadMoreError : loadMoreError // ignore: cast_nullable_to_non_nullable
as AppFailure?,countryNotSet: null == countryNotSet ? _self.countryNotSet : countryNotSet // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
