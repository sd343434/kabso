// Live discovery models matching docs/contracts/openapi.yaml v1.3 (tag
// `live`, CONVENTIONS §10).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';

part 'live_models.freezed.dart';
part 'live_models.g.dart';

/// `GET /live/config`: the live feature switch and server-driven timings.
@freezed
abstract class LiveConfig with _$LiveConfig {
  const factory({
    required bool hostingEnabled,
    required int heartbeatIntervalSeconds,
    required int heartbeatStaleAfterSeconds,
  }) = _LiveConfig;

  factory fromJson(Map<String, dynamic> json) => _$LiveConfigFromJson(json);
}

/// `LiveCategory`; [name] is already localized by `Accept-Language`.
@freezed
abstract class LiveCategory with _$LiveCategory {
  const factory({required String slug, required String name}) = _LiveCategory;

  factory fromJson(Map<String, dynamic> json) => _$LiveCategoryFromJson(json);
}

/// `LiveRoomMode`. Only SOLO exists in v1.3; an unrecognised future value is
/// rendered as SOLO (contract).
enum LiveRoomMode {
  @JsonValue('SOLO')
  solo,
  @JsonValue('PK')
  pk,
  @JsonValue('MULTI')
  multi,
}

enum LiveRoomStatus {
  @JsonValue('LIVE')
  live,
  @JsonValue('ENDED')
  ended,
}

enum LiveRoomEndReason {
  @JsonValue('HOST_ENDED')
  hostEnded,
  @JsonValue('HEARTBEAT_TIMEOUT')
  heartbeatTimeout,
  @JsonValue('HOST_SUSPENDED')
  hostSuspended,
  @JsonValue('ADMIN')
  admin,

  /// A reason this build does not know yet.
  unknown,
}

/// `LiveRoomSummary`: one room in a discovery list.
@freezed
abstract class LiveRoomSummary with _$LiveRoomSummary {
  const factory({
    required String id,
    required String title,
    @JsonKey(unknownEnumValue: LiveRoomMode.solo) required LiveRoomMode mode,
    required int viewerCount,
    required DateTime startedAt,
    required String? coverUrl,
    required LiveCategory? category,
    required UserSummary host,
  }) = _LiveRoomSummary;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveRoomSummaryFromJson(json);
}

/// `LiveRoom`: a [LiveRoomSummary] plus its lifecycle (`GET
/// /live/rooms/{roomId}` also returns ended rooms).
@freezed
abstract class LiveRoom with _$LiveRoom {
  const factory({
    required String id,
    required String title,
    @JsonKey(unknownEnumValue: LiveRoomMode.solo) required LiveRoomMode mode,
    required int viewerCount,
    required DateTime startedAt,
    required String? coverUrl,
    required LiveCategory? category,
    required UserSummary host,
    required LiveRoomStatus status,
    required DateTime? endedAt,
    @JsonKey(unknownEnumValue: LiveRoomEndReason.unknown)
    required LiveRoomEndReason? endReason,

    /// CP-010: people without an account may watch.
    @Default(true) bool allowGuests,
  }) = _LiveRoom;

  factory fromJson(Map<String, dynamic> json) => _$LiveRoomFromJson(json);
}

/// `LiveRoomPage`: one cursor page of `GET /live/rooms`.
@freezed
abstract class LiveRoomPage with _$LiveRoomPage {
  const factory({required List<LiveRoomSummary> data, required PageInfo page}) =
      _LiveRoomPage;

  factory fromJson(Map<String, dynamic> json) => _$LiveRoomPageFromJson(json);
}

/// The `tab` query value of `GET /live/rooms`.
enum LiveRoomsTab {
  popular('popular'),
  latest('new'),
  following('following');

  new(this.wire);

  final String wire;
}

/// `LiveMediaAccess` (CP-010): what joining a room's video needs.
@freezed
abstract class LiveMediaAccess with _$LiveMediaAccess {
  const factory({
    required String url,
    required String token,
    required DateTime expiresAt,
    @JsonKey(unknownEnumValue: LiveMediaRole.viewer)
    required LiveMediaRole role,
    required String identity,
    int? guestNumber,
  }) = _LiveMediaAccess;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveMediaAccessFromJson(json);
}

enum LiveMediaRole {
  @JsonValue('HOST')
  host,
  @JsonValue('VIEWER')
  viewer,
}

/// `LiveViewer` (CP-010): someone watching now; a guest has a number only.
@freezed
abstract class LiveViewer with _$LiveViewer {
  const factory({
    @JsonKey(unknownEnumValue: LiveViewerKind.user)
    required LiveViewerKind kind,
    required UserSummary? user,
    required int? guestNumber,
    required DateTime joinedAt,
  }) = _LiveViewer;

  factory fromJson(Map<String, dynamic> json) => _$LiveViewerFromJson(json);
}

enum LiveViewerKind {
  @JsonValue('USER')
  user,
  @JsonValue('GUEST')
  guest,
}
