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

    /// CP-011: room themes the server accepts (the first is the default).
    @Default(<String>[LiveThemes.classic]) List<String> themes,

    /// CP-011: allowed seat counts per mode, the host's tile included.
    @Default(LiveSeatCounts()) LiveSeatCounts seatCounts,
  }) = _LiveConfig;

  factory fromJson(Map<String, dynamic> json) => _$LiveConfigFromJson(json);
}

/// `LiveConfig.seatCounts` (CP-011).
@freezed
abstract class LiveSeatCounts with _$LiveSeatCounts {
  const factory({
    @JsonKey(name: 'MULTI') @Default(<int>[4, 6, 9, 12]) List<int> multi,
    @JsonKey(name: 'AUDIO') @Default(<int>[5, 10, 15, 20]) List<int> audio,
  }) = _LiveSeatCounts;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatCountsFromJson(json);
}

/// Theme slugs (CP-011). The server's list is in `LiveConfig.themes`.
abstract final class LiveThemes {
  static const classic = 'classic';
}

/// `LiveCategory`; [name] is already localized by `Accept-Language`.
@freezed
abstract class LiveCategory with _$LiveCategory {
  const factory({required String slug, required String name}) = _LiveCategory;

  factory fromJson(Map<String, dynamic> json) => _$LiveCategoryFromJson(json);
}

/// `LiveRoomMode`: SOLO, PK (L5), MULTI and AUDIO (CP-011). An unrecognised
/// future value is rendered as SOLO (contract).
enum LiveRoomMode {
  @JsonValue('SOLO')
  solo,
  @JsonValue('PK')
  pk,
  @JsonValue('MULTI')
  multi,
  @JsonValue('AUDIO')
  audio;

  /// The wire value (requests).
  String get wire => switch (this) {
    solo => 'SOLO',
    pk => 'PK',
    multi => 'MULTI',
    audio => 'AUDIO',
  };

  /// MULTI and AUDIO rooms have seats.
  bool get hasSeats => this == multi || this == audio;
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

    /// CP-011: tiles (host included) in a MULTI or AUDIO room.
    int? seatCount,

    /// CP-011: guests seated now.
    @Default(0) int occupiedSeats,
    @Default(LiveThemes.classic) String theme,

    /// CP-012: the live's points (taps + support); `popular` orders by it.
    @Default(0) int score,

    /// CP-014: the host's one-line topic, or null.
    String? topic,
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

    /// CP-011 (see [LiveRoomSummary]).
    int? seatCount,
    @Default(0) int occupiedSeats,
    @Default(LiveThemes.classic) String theme,

    /// CP-012 (see [LiveRoomSummary]) and its parts.
    @Default(0) int score,
    LiveScore? scoreParts,

    /// CP-013: the host has not turned the chat off.
    @Default(true) bool chatEnabled,

    /// CP-013: the caller is muted in this live's chat.
    @Default(false) bool chatMuted,

    /// CP-014 (see [LiveRoomSummary]).
    String? topic,

    /// CP-016 G: the host's public room number ("ID: …"); null when the
    /// host no longer has the hosting permission.
    int? roomNumber,

    /// CP-016 D (D101): the host's charm level, shown next to the room name;
    /// null while the charm levels are unavailable.
    int? roomLevel,

    /// v1.20-live (D105, §10.20): the host or a moderator kicked the caller
    /// out of this live; the app shows why instead of the room.
    @Default(false) bool kicked,
  }) = _LiveRoom;

  factory fromJson(Map<String, dynamic> json) => _$LiveRoomFromJson(json);
}

/// `LiveScore` (CP-012): a live's points. One counted tap is 1 point; one
/// support coin is 100 (L3; 0 until then).
@freezed
abstract class LiveScore with _$LiveScore {
  const factory({
    required int total,
    required int tapPoints,
    required int supportPoints,
  }) = _LiveScore;

  factory fromJson(Map<String, dynamic> json) => _$LiveScoreFromJson(json);
}

/// `LiveTapsResult` (CP-012): the taps counted from a batch and the score.
@freezed
abstract class LiveTapsResult with _$LiveTapsResult {
  const factory({required int accepted, required LiveScore score}) =
      _LiveTapsResult;

  factory fromJson(Map<String, dynamic> json) => _$LiveTapsResultFromJson(json);
}

/// `LiveContributor` (CP-014): someone who gave this live points.
@freezed
abstract class LiveContributor with _$LiveContributor {
  const factory({required UserSummary user, required int points}) =
      _LiveContributor;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveContributorFromJson(json);
}

/// `LiveContributorStanding` (v1.20-live, D105, §10.12): one person's
/// points in a live and their place in the Contribution list (`rank` is
/// null when `points` is 0).
@freezed
abstract class LiveContributorStanding with _$LiveContributorStanding {
  const factory({
    required UserSummary user,
    required int points,
    required int? rank,
  }) = _LiveContributorStanding;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveContributorStandingFromJson(json);
}

/// `LiveKick` (v1.20-live, D105, §10.20): someone kicked out of a live.
@freezed
abstract class LiveKick with _$LiveKick {
  const factory({required UserSummary user, required DateTime kickedAt}) =
      _LiveKick;

  factory fromJson(Map<String, dynamic> json) => _$LiveKickFromJson(json);
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

  /// CP-011: a seated guest (publishes while seated).
  @JsonValue('SPEAKER')
  speaker,
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

/// `LiveSeat` (CP-011): seat [index] 1 … seatCount-1 (the host is 0).
@freezed
abstract class LiveSeat with _$LiveSeat {
  const factory({
    required int index,
    @JsonKey(unknownEnumValue: LiveSeatState.empty)
    required LiveSeatState state,
    required UserSummary? user,
    @Default(false) bool mutedByHost,
  }) = _LiveSeat;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatFromJson(json);
}

enum LiveSeatState {
  @JsonValue('EMPTY')
  empty,
  @JsonValue('LOCKED')
  locked,
  @JsonValue('TAKEN')
  taken,
}

/// `LiveSeatRequest` (CP-011).
@freezed
abstract class LiveSeatRequest with _$LiveSeatRequest {
  const factory({
    required String id,
    required UserSummary user,
    required int? seatIndex,
    required DateTime createdAt,
  }) = _LiveSeatRequest;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveSeatRequestFromJson(json);
}

/// `LiveSeatInvite` (CP-011): expires 60 s after it was sent.
@freezed
abstract class LiveSeatInvite with _$LiveSeatInvite {
  const factory({
    required String id,
    required UserSummary user,
    required int? seatIndex,
    required UserSummary invitedBy,
    required DateTime expiresAt,
  }) = _LiveSeatInvite;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatInviteFromJson(json);
}

enum LiveSeatRole {
  @JsonValue('HOST')
  host,
  @JsonValue('MODERATOR')
  moderator,
  @JsonValue('SEATED')
  seated,
  @JsonValue('VIEWER')
  viewer,
}

/// `LiveSeatsMine` (CP-011): the caller's place in the room.
@freezed
abstract class LiveSeatsMine with _$LiveSeatsMine {
  const factory({
    @JsonKey(unknownEnumValue: LiveSeatRole.viewer) required LiveSeatRole role,
    required int? seatIndex,
    required LiveSeatRequest? request,
    required LiveSeatInvite? invite,
  }) = _LiveSeatsMine;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatsMineFromJson(json);
}

/// `LiveSeatCouple` (v1.23.3-live, D111): two CP partners who both sit in
/// the room now (the host's seat included), [userIds] in seat order.
/// v1.24.2-live (D115): [privileges] are the CP privilege codes the level
/// unlocked (empty from an older API).
@freezed
abstract class LiveSeatCouple with _$LiveSeatCouple {
  const factory({
    required List<String> userIds,
    required int level,
    @Default('') String levelName,
    @Default(<String>[]) List<String> privileges,
  }) = _LiveSeatCouple;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatCoupleFromJson(json);
}

/// `LiveSeats` (CP-011): who is on which seat; [version] moves on every
/// change.
@freezed
abstract class LiveSeats with _$LiveSeats {
  const factory({
    required String roomId,
    @JsonKey(unknownEnumValue: LiveRoomMode.multi) required LiveRoomMode mode,
    required int version,
    required int seatCount,
    required List<LiveSeat> seats,
    required List<UserSummary> moderators,

    /// v1.23.3-live (D111): CP couples whose partners both sit now; empty
    /// from an older API.
    @Default(<LiveSeatCouple>[]) List<LiveSeatCouple> couples,

    /// Host and moderators only.
    int? pendingRequests,

    /// Signed-in callers only.
    LiveSeatsMine? mine,
  }) = _LiveSeats;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatsFromJson(json);
}
