// Live discovery models matching docs/contracts/openapi.yaml v1.3 (tag
// `live`, CONVENTIONS §10).

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_podcast_video.dart';
import 'package:kabso_live/features/live/domain/live_streamer.dart';

export 'package:kabso_live/features/live/domain/live_podcast_video.dart';
export 'package:kabso_live/features/live/domain/live_streamer.dart';

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

    /// v1.47-live (D212): the podcast setup's choices (defaults from an
    /// older server).
    @Default(LivePodcastConfig()) LivePodcastConfig podcast,

    /// v1.49-live (D228): the camera effects engine on Android — `DEEPAR`
    /// (default; also for an older server) or `FREE` (ML Kit + MediaPipe).
    /// Read through `LiveFxEngine.parse`.
    @Default('DEEPAR') String cameraFxEngine,

    /// v1.88-live (D315, §10.120): at least one game is on — the ranking
    /// page's «مجنون اللعب» tab shows only then (false from an older server).
    @Default(false) bool gamesEnabled,
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

/// `LiveConfig.podcast` (v1.47-live, D212).
@freezed
abstract class LivePodcastConfig with _$LivePodcastConfig {
  const factory({
    /// Speakers including the host.
    @Default(4) int speakers,
    @Default(PodcastTopic.values) List<PodcastTopic> topics,

    /// A question's speaking time in seconds (null = no limit is always
    /// offered too).
    @Default(<int>[60, 120, 180, 300]) List<int> questionSeconds,
    @Default(120) int defaultQuestionSeconds,
  }) = _LivePodcastConfig;

  factory fromJson(Map<String, dynamic> json) =>
      _$LivePodcastConfigFromJson(json);
}

/// `StartLiveRoomRequest.podcast` (v1.47-live, D212).
@immutable
class PodcastSetup {
  const new({
    required this.topic,
    this.questionsOpen = true,
    this.questionSeconds = 120,
    this.video = false,
    this.segments = const [],
  });

  final PodcastTopic topic;
  final bool questionsOpen;

  /// null = no limit.
  final int? questionSeconds;

  /// v1.114-live (D363, §10.157): «صوت / فيديو» — a video podcast.
  final bool video;

  /// v1.114-live (D363 scope extension): the episode's segments «فقرات»
  /// (a video podcast's; at most [LivePodcastSegment.max]).
  final List<LivePodcastSegment> segments;

  PodcastSetup copyWith({
    PodcastTopic? topic,
    bool? questionsOpen,
    int? Function()? questionSeconds,
    bool? video,
    List<LivePodcastSegment>? segments,
  }) => PodcastSetup(
    topic: topic ?? this.topic,
    questionsOpen: questionsOpen ?? this.questionsOpen,
    questionSeconds: questionSeconds == null
        ? this.questionSeconds
        : questionSeconds(),
    video: video ?? this.video,
    segments: segments ?? this.segments,
  );

  Map<String, dynamic> toJson() => {
    'topic': topic.wire,
    'questionsOpen': questionsOpen,
    'questionSeconds': questionSeconds,
    // Sent only when on, so an audio podcast's request is exactly D212's.
    if (video) 'video': true,
    if (video && segments.isNotEmpty)
      'segments': [for (final g in segments) g.toJson()],
  };
}

/// `PodcastTopic` (v1.47-live, D212): the setup's topic chips.
enum PodcastTopic {
  @JsonValue('business')
  business,
  @JsonValue('tech')
  tech,
  @JsonValue('sports')
  sports,
  @JsonValue('religion')
  religion,
  @JsonValue('society')
  society,
  @JsonValue('entertainment')
  entertainment,
  @JsonValue('other')
  other;

  String get wire => name;
}

/// `LivePodcastSpeaker` (v1.47-live, D212): a speaker on a hub card.
@freezed
abstract class LivePodcastSpeaker with _$LivePodcastSpeaker {
  const factory({
    required String id,
    required String username,
    required String displayName,
    String? avatarUrl,
  }) = _LivePodcastSpeaker;

  factory fromJson(Map<String, dynamic> json) =>
      _$LivePodcastSpeakerFromJson(json);
}

/// `LivePodcast` (v1.47-live, D212): a podcast live's episode facts.
@freezed
abstract class LivePodcast with _$LivePodcast {
  const factory({
    required int episodeNumber,
    @JsonKey(unknownEnumValue: PodcastTopic.other) required PodcastTopic topic,
    @Default(true) bool questionsOpen,

    /// An accepted hand's speaking time; null = no limit.
    int? questionSeconds,
    @Default(<LivePodcastSpeaker>[]) List<LivePodcastSpeaker> speakers,

    /// v1.114-live (D363, §10.157): a video podcast (false from older
    /// servers: audio).
    @Default(false) bool video,
  }) = _LivePodcast;

  factory fromJson(Map<String, dynamic> json) => _$LivePodcastFromJson(json);
}

/// v1.114-live (D363, §10.157): the video podcast on a room.
extension LiveRoomVideoPodcast on LiveRoom {
  /// A podcast whose host and speakers are on camera.
  bool get videoPodcast =>
      mode == LiveRoomMode.podcast && (podcast?.video ?? false);

  /// No camera for anyone: AUDIO and an audio podcast. The layout and the
  /// camera follow this; a video podcast is drawn as a video live.
  bool get voiceOnly => mode.isVoice && !videoPodcast;
}

/// `LivePodcastHotSeat` (v1.114-live, D363): the hand seated «في الكرسي
/// الساخن».
@freezed
abstract class LivePodcastHotSeat with _$LivePodcastHotSeat {
  const factory({
    required String requestId,
    required String question,
    @Default(0) int votes,
  }) = _LivePodcastHotSeat;

  factory fromJson(Map<String, dynamic> json) =>
      _$LivePodcastHotSeatFromJson(json);
}

/// `LivePodcastQuestion` (v1.114-live, D363): a raised hand with a
/// question, as every listener sees it.
@freezed
abstract class LivePodcastQuestion with _$LivePodcastQuestion {
  const factory({
    required String requestId,
    required UserSummary user,
    required String question,
    @Default(0) int votes,
    @Default(false) bool votedByMe,
    @Default(false) bool deferred,
  }) = _LivePodcastQuestion;

  factory fromJson(Map<String, dynamic> json) =>
      _$LivePodcastQuestionFromJson(json);
}

/// `LiveScheduledPodcast` (v1.47-live, D212): an announced episode in the
/// hub's podcast tab (a dashed card with «ذكّرني»).
@freezed
abstract class LiveScheduledPodcast with _$LiveScheduledPodcast {
  const factory({
    required String id,
    required String title,
    required DateTime startsAt,
    @JsonKey(unknownEnumValue: PodcastTopic.other)
    required PodcastTopic podcastTopic,
    required UserSummary host,

    /// The person will be reminded (they follow the host).
    @Default(false) bool reminder,

    /// v1.114-live (D363): a video episode (the card's video badge).
    @Default(false) bool video,
  }) = _LiveScheduledPodcast;

  factory fromJson(Map<String, dynamic> json) =>
      _$LiveScheduledPodcastFromJson(json);
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
/// future value is rendered as SOLO (contract). v1.116-live (D369): MULTI is
/// retired — it is never started or listed any more, but a room started
/// before can still be read (a viewer opening it gets the legacy seats; a
/// card draws it as a camera live).
enum LiveRoomMode {
  @JsonValue('SOLO')
  solo,
  @JsonValue('PK')
  pk,
  @JsonValue('MULTI')
  multi,
  @JsonValue('AUDIO')
  audio,

  /// v1.47-live (D212): an audio-only podcast — the host and up to 3
  /// speakers; listeners raise a hand.
  @JsonValue('PODCAST')
  podcast,

  /// v1.56-live (D213): the host's phone screen with a round camera bubble
  /// (Android hosts; any viewer). No guest seats, no PK.
  @JsonValue('STREAMER')
  streamer;

  /// The wire value (requests).
  String get wire => switch (this) {
    solo => 'SOLO',
    pk => 'PK',
    multi => 'MULTI',
    audio => 'AUDIO',
    podcast => 'PODCAST',
    streamer => 'STREAMER',
  };

  /// MULTI, AUDIO and (D212) PODCAST rooms have seats.
  bool get hasSeats => this == multi || this == audio || this == podcast;

  /// D212: voice only (no camera for anyone): AUDIO rooms and podcasts.
  bool get isVoice => this == audio || this == podcast;

  /// D174: rooms with guest seats — MULTI and AUDIO, and a SOLO live's 3
  /// guests (v1.40-live).
  bool get hasGuestSeats => hasSeats || this == solo;
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

  /// v1.42-live (D170): a video live whose host stayed away (the app in
  /// the background, the camera off) for 5 minutes.
  @JsonValue('HOST_AWAY_TIMEOUT')
  hostAwayTimeout,

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

    /// CP-012: the live's points (taps + support). D310 (v1.86-live): points
    /// only — `popular` orders by [cherries].
    @Default(0) int score,

    /// D310 (v1.86-live, §10.116): the room's cherries — what the host AND
    /// the seated guests were credited for this live's gifts; `popular`
    /// orders by it and the hub card shows it with the cherry. Null from an
    /// older server (the card then shows no number).
    int? cherries,

    /// CP-014: the host's one-line topic, or null.
    String? topic,

    /// v1.47-live (D212): a podcast's episode facts; null otherwise.
    LivePodcast? podcast,

    /// v1.54-live (D241): the room is in a PK now (an open D195 match —
    /// the rooms stay SOLO — or the legacy mode PK). Older servers: false.
    @Default(false) bool inPk,

    /// v1.56-live (D213): a streamer's layout; null otherwise.
    LiveStreamer? streamer,

    /// v1.58-live (D246): the host's charm level (CP-016 D, the room
    /// level) — the party cards' level pill. Null while unavailable or from
    /// older servers.
    int? roomLevel,

    /// v1.58-live (D246): «رائج» — among the first `LIVE_POPULAR_TOP_N`
    /// lives of its kind in the popular order. Older servers: false.
    @Default(false) bool popular,

    /// v1.58-live (D246): the host's profile country (ISO alpha-2), or null
    /// when the host set none.
    String? hostCountry,

    /// v1.82-live (D295): the host is a content creator «صانع محتوى» (the
    /// purple badge). Older servers: false.
    @Default(false) bool hostIsCreator,
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

    /// D310 (see [LiveRoomSummary.cherries]).
    int? cherries,

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

    /// v1.27.3-live (D136, §10.29): the host's wish list, as shown (older
    /// servers send none).
    @Default(<LiveWishGift>[]) List<LiveWishGift> wishGifts,

    /// v1.47-live (D212): a podcast's episode facts; null otherwise.
    LivePodcast? podcast,

    /// v1.56-live (D213): a streamer's layout; null otherwise.
    LiveStreamer? streamer,

    /// v1.82-live (D295): the host is a content creator (the purple badge next
    /// to the host's name in the room). Older servers: false.
    @Default(false) bool hostIsCreator,
  }) = _LiveRoom;

  factory fromJson(Map<String, dynamic> json) => _$LiveRoomFromJson(json);
}

/// `LiveWishGift` (v1.27.3-live, D136): one gift of the host's wish list
/// and how many of it the host received in this live.
@freezed
abstract class LiveWishGift with _$LiveWishGift {
  const factory({
    required String giftCode,
    required String name,
    required int priceCoins,
    required String assetKey,
    String? imageUrl,
    @Default(0) int received,
  }) = _LiveWishGift;

  factory fromJson(Map<String, dynamic> json) => _$LiveWishGiftFromJson(json);
}

/// `LiveScore` (CP-012): a live's points. One counted tap is 1 point; one
/// support coin is 100 (L3; 0 until then).
@freezed
abstract class LiveScore with _$LiveScore {
  const factory({
    required int total,
    required int tapPoints,
    required int supportPoints,

    /// D259 (v1.63-live, §10.95): what the cherry ledger credited the host
    /// for gifts received in this live — the host pill's cherries (the
    /// score is points). 0 from an older server.
    @Default(0) int hostCherries,

    /// D310 (v1.86-live, §10.116): the room's cherries — the host's AND the
    /// seated guests' credits of this live; the host pill shows it. Null from
    /// an older server (the pill then falls back to [hostCherries]).
    int? roomCherries,
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
  const factory({
    required List<LiveRoomSummary> data,
    required PageInfo page,

    /// v1.27.1-live (D133), `scope=nearby` only: `COUNTRY_NOT_SET` when the
    /// caller has no country (the page is empty). Unknown values read as
    /// null.
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    LiveRoomsEmptyReason? emptyReason,
  }) = _LiveRoomPage;

  factory fromJson(Map<String, dynamic> json) => _$LiveRoomPageFromJson(json);
}

/// `LiveRoomPage.emptyReason` (v1.27.1-live, D133).
enum LiveRoomsEmptyReason {
  @JsonValue('COUNTRY_NOT_SET')
  countryNotSet,
}

/// The `tab` query value of `GET /live/rooms`.
enum LiveRoomsTab {
  popular('popular'),
  latest('new'),
  following('following');

  new(this.wire);

  final String wire;
}

/// The hub's room kind (`kind` of `GET /live/rooms`, v1.26.4-live, D129):
/// voice rooms (`AUDIO`) or video lives (`SOLO`, `PK`); D212 adds `podcast`
/// (`PODCAST`). v1.115-live (D368): a live VIDEO podcast is a camera live —
/// `video` and `solo` list it, `partyAll` does not. v1.116-live (D369): the
/// multi-guest live (`MULTI`) is retired — no kind lists it.
enum LiveRoomsKind {
  audio('audio'),
  video('video'),

  /// v1.27.1-live (D133): `SOLO` and `PK` (D213: `STREAMER`; D368: the
  /// live video podcasts).
  solo('solo'),

  /// v1.27.1-live (D133): `MULTI`. v1.116-live (D369): still a valid
  /// `kind`, and it lists nothing (the multi-guest live is retired).
  multi('multi'),

  /// v1.27.1-live (D133): `AUDIO` (and `MULTI` until D369).
  party('party'),

  /// v1.47-live (D212): `PODCAST` — every podcast, audio or video.
  podcast('podcast'),

  /// v1.56-live (D213): `STREAMER` (also in [video] and [solo]).
  streamer('streamer'),

  /// v1.107-live (D342): the party page's mixed list (its kind tabs are
  /// gone) — `AUDIO` and the AUDIO podcasts (D368, D369).
  partyAll('party_all');

  new(this.wire);

  final String wire;

  /// The kind a room of [mode] is listed under (audio, podcast or video;
  /// D368: a live video podcast ([podcastVideo]) is a video live).
  static LiveRoomsKind of(LiveRoomMode mode, {bool podcastVideo = false}) =>
      switch (mode) {
        LiveRoomMode.audio => audio,
        LiveRoomMode.podcast => podcastVideo ? video : podcast,
        _ => video,
      };

  /// Whether a room of [mode] is listed under this kind (the server's
  /// rule). [podcastVideo]: a PODCAST that is a live video podcast (D363
  /// `LivePodcast.video`).
  bool includes(LiveRoomMode mode, {bool podcastVideo = false}) {
    final videoPodcast = mode == LiveRoomMode.podcast && podcastVideo;
    final camera =
        mode == LiveRoomMode.solo ||
        mode == LiveRoomMode.pk ||
        mode == LiveRoomMode.streamer ||
        videoPodcast;
    return switch (this) {
      audio => mode == LiveRoomMode.audio,
      video || solo => camera,
      podcast => mode == LiveRoomMode.podcast,
      streamer => mode == LiveRoomMode.streamer,
      multi => false,
      party => mode == LiveRoomMode.audio,
      partyAll =>
        mode == LiveRoomMode.audio ||
            (mode == LiveRoomMode.podcast && !podcastVideo),
    };
  }

  /// Whether [room] is listed under this kind ([includes] with its video
  /// podcast flag).
  bool includesRoom(LiveRoomSummary room) =>
      includes(room.mode, podcastVideo: room.podcast?.video ?? false);

  /// [wire] back to a kind; anything else is `null`.
  static LiveRoomsKind? tryParse(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
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

    /// v1.68-live (D273, §10.96.6): `VISIBLE` / `HIDDEN` when this caller
    /// is «فريق كابسو» in the live (always a watch-only viewer); null for
    /// everyone else.
    String? staff,
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

/// `LiveStaffWatcher` (D260, v1.64-live): a Kabso staff member watching
/// this live (`LiveViewerPage.staff`) — shown with the «فريق كابسو» badge,
/// never counted, never ranked, no person card.
@immutable
class LiveStaffWatcher {
  const new({
    required this.displayName,
    required this.avatarUrl,
    required this.since,
  });

  factory fromJson(Map<String, dynamic> json) => LiveStaffWatcher(
    displayName: json['displayName'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    since:
        DateTime.tryParse(json['since'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final String displayName;
  final String? avatarUrl;
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is LiveStaffWatcher &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.since == since;

  @override
  int get hashCode => Object.hash(displayName, avatarUrl, since);
}

/// The viewers endpoint's page (`LiveViewerPage`): `staff` (D260) on the
/// first page only; empty from an older server.
typedef LiveViewersPage = ({
  List<LiveViewer> items,
  String? next,
  List<LiveStaffWatcher> staff,
});

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

    /// v1.27.2-live (D135): the gift points this seated person received in
    /// this live (0 for empty and locked seats, and from older servers).
    @Default(0) int points,

    /// v1.47-live (D212): a podcast speaker's question end (they go back
    /// to the listeners then); null = no limit.
    DateTime? demoteAt,

    /// v1.114-live (D363): the guest's lower-third title (video podcasts).
    String? guestTitle,

    /// v1.114-live (D363): seated «في الكرسي الساخن» — the question card.
    LivePodcastHotSeat? hotSeat,

    /// v1.114-live (D363 scope extension): waiting «خلف الكواليس» (an
    /// accepted guest of a video podcast, until the host brings them on
    /// air) — not on the stage, the director or the gift recipients.
    @Default(false) bool backstage,
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

    /// v1.47-live (D212): a podcast hand's short question.
    String? question,

    /// v1.47-live (D212): the host said «لاحقاً».
    @Default(false) bool deferred,

    /// v1.114-live (D363): the question's upvotes.
    @Default(0) int votes,
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

    /// v1.114-live (D363): the guest's lower-third title (video podcasts).
    String? guestTitle,
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

    /// v1.47-live (D212): a podcast's raised hands (user ids, queue order).
    @Default(<String>[]) List<String> handsUp,

    /// v1.114-live (D363): a video podcast's questions, most votes first.
    @Default(<LivePodcastQuestion>[]) List<LivePodcastQuestion> questions,

    /// v1.114-live (D363 scope extension): a video podcast's studio (manual
    /// control, segments, the question on screen); null otherwise.
    LivePodcastStudio? studio,

    /// Signed-in callers only.
    LiveSeatsMine? mine,
  }) = _LiveSeats;

  factory fromJson(Map<String, dynamic> json) => _$LiveSeatsFromJson(json);
}
