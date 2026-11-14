import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/domain/live_seat_emoji.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;

import '../fixtures/live/live_api_fixtures.dart';

/// One `GET /live/rooms` call.
typedef RoomsRequest = ({
  LiveRoomsTab tab,
  String? category,
  LiveRoomsKind? kind,
  bool nearby,
  String? country,
  bool featured,
  String? cursor,
  int limit,
});

typedef RoomsHandler = FutureOr<LiveRoomPage> Function(RoomsRequest request);

/// `GET /live/rooms/{roomId}`.
typedef RoomHandler = FutureOr<LiveRoom> Function(String roomId);

/// The 404 every unknown room gets (contract v1.3.1).
const roomNotFound = ServerFailure(
  code: ErrorCode.notFound,
  rawCode: 'NOT_FOUND',
  debugMessage: 'Room not found',
  statusCode: 404,
);

/// Configurable in-memory [LiveRepository]: `GET /live/config`,
/// `/live/categories` and `/live/rooms` answered from fields; failures are
/// thrown as given. Every call is recorded.
class FakeLiveRepository implements LiveRepository {
  new({
    this.hostingEnabled = true,
    this.categories = const [],
    RoomsHandler? rooms,
    this.configGate,
    this.room,
  }) : rooms = rooms ?? ((_) => apiPage(const []));

  /// Answers `getRoom`; `null` → 404 `NOT_FOUND`.
  RoomHandler? room;

  /// Every `getRoom` call, in order.
  final List<String> roomRequests = [];

  bool hostingEnabled;
  List<LiveCategory> categories;

  /// `LiveConfig.themes` (CP-011).
  List<String> themes = const [
    LiveThemes.classic,
    'ice-palace',
    'desert-night',
    'rose-garden',
    'sunset-sky',
    'moon-palace',
    'ocean-depths',
    'golden-hall',
    'game-arena',
    'heart-garden',
    'galaxy',
  ];
  RoomsHandler rooms;

  /// When set, `getConfig` waits for it (loading states).
  Completer<void>? configGate;

  /// Thrown by the next `getConfig` calls while set.
  AppFailure? configFailure;

  /// D228: `LiveConfig.cameraFxEngine` (`DEEPAR` / `FREE`).
  String cameraFxEngine = 'DEEPAR';

  /// D315: `LiveConfig.gamesEnabled` (the «مجنون اللعب» board's tab).
  bool gamesEnabled = false;

  int configCalls = 0;
  int categoryCalls = 0;
  final List<RoomsRequest> requests = [];

  @override
  Future<LiveConfig> getConfig() async {
    configCalls++;
    await configGate?.future;
    if (configFailure case final failure?) throw failure;
    return LiveConfig(
      hostingEnabled: hostingEnabled,
      heartbeatIntervalSeconds: 15,
      heartbeatStaleAfterSeconds: 45,
      themes: themes,
      cameraFxEngine: cameraFxEngine,
      gamesEnabled: gamesEnabled,
    );
  }

  @override
  Future<List<LiveCategory>> listCategories() async {
    categoryCalls++;
    return categories;
  }

  @override
  Future<LiveRoomPage> listRooms({
    required LiveRoomsTab tab,
    String? category,
    LiveRoomsKind? kind,
    bool nearby = false,
    String? country,
    bool featured = false,
    String? cursor,
    int limit = LiveRepository.defaultPageSize,
  }) async {
    final request = (
      tab: tab,
      category: category,
      kind: kind,
      nearby: nearby,
      country: country,
      featured: featured,
      cursor: cursor,
      limit: limit,
    );
    requests.add(request);
    return await rooms(request);
  }

  @override
  Future<LiveRoom> getRoom(String roomId) async {
    roomRequests.add(roomId);
    final handler = room;
    // The host's own room, as the server would answer it.
    final own = hostRoom;
    if (handler == null && own != null && own.id == roomId) return own;
    if (handler == null) throw roomNotFound;
    return await handler(roomId);
  }
  // CP-010: going live, recorded in memory.

  /// Every `startRoom` call.
  final List<
    ({
      String title,
      String? categorySlug,
      bool allowGuests,
      LiveRoomMode mode,
      int? seatCount,
      String? theme,
      PodcastSetup? podcast,
      LiveStreamer? streamer,
    })
  >
  startRequests = [];

  /// D213: every `updateStreamer` call (the values sent).
  final List<
    ({
      String roomId,
      StreamerOrientation? orientation,
      bool? cameraVisible,
      StreamerCorner? corner,
    })
  >
  streamerUpdates = [];

  /// D213: thrown by `updateStreamer` while set.
  AppFailure? streamerFailure;

  @override
  Future<LiveStreamer> updateStreamer(
    String roomId, {
    StreamerOrientation? orientation,
    bool? cameraVisible,
    StreamerCorner? corner,
  }) async {
    streamerUpdates.add((
      roomId: roomId,
      orientation: orientation,
      cameraVisible: cameraVisible,
      corner: corner,
    ));
    if (streamerFailure case final f?) throw f;
    final base = hostRoom ?? apiRoom(id: roomId);
    final now = base.streamer ?? const LiveStreamer();
    final next = now.copyWith(
      orientation: orientation,
      cameraVisible: cameraVisible,
      corner: corner,
    );
    final changed = next != now;
    final out = changed ? next.copyWith(version: now.version + 1) : now;
    hostRoom = base.copyWith(streamer: out);
    return out;
  }

  final List<String> heartbeats = [];
  final List<String> endRequests = [];
  final List<({String roomId, bool allow})> guestUpdates = [];
  final List<({String roomId, String? guestId})> tokenRequests = [];

  /// Thrown by `startRoom` / `mediaToken` / `heartbeat` / `setAllowGuests`
  /// while set.
  AppFailure? startFailure;
  AppFailure? tokenFailure;
  AppFailure? heartbeatFailure;
  AppFailure? guestsFailure;

  /// The host's room once started.
  LiveRoom? hostRoom;

  /// CP-016 D: the room level `startRoom` answers with.
  int? startRoomLevel;

  /// CP-016 G: the room number `startRoom` answers with.
  int? startRoomNumber;

  /// Answers `viewers`.
  List<LiveViewer> viewerList = [];

  /// D212: the episode number a podcast `startRoom` answers with.
  int podcastEpisode = 1;

  /// D212: `deferSeatRequest` / `setPodcastSettings` calls.
  final List<String> deferred = [];
  final List<({bool? questionsOpen, bool setSeconds, int? seconds})>
  podcastSettings = [];

  /// D363: `acceptSeatRequest` hot seats, `voteQuestion` and
  /// `setPodcastDirector` calls, and the invitations' guest titles.
  final List<({String requestId, int? seconds})> hotSeats = [];
  final List<({String requestId, bool vote})> votes = [];
  final List<PodcastDirectorShot> directorShots = [];
  final List<String?> guestTitles = [];

  /// D363 scope extension: the studio the fake server holds (each change
  /// raises `seq`), its calls, and the backstage guests brought on air.
  LivePodcastStudio studio = const LivePodcastStudio();
  final List<String> studioCalls = [];
  final List<int> onAir = [];

  LivePodcastStudio _studio(String call, LivePodcastStudio next) {
    studioCalls.add(call);
    studio = LivePodcastStudio(
      seq: studio.seq + 1,
      pinUserId: next.pinUserId,
      layout: next.layout,
      segments: next.segments,
      segmentIndex: next.segmentIndex,
      segmentStartedAt: next.segmentStartedAt,
      closing: next.closing,
      onScreen: next.onScreen,
    );
    // A video podcast's seats carry it (`LiveSeats.studio`).
    if (seatState case final seats? when seats.studio != null) {
      seatState = seats.copyWith(studio: studio);
    }
    return studio;
  }

  /// D212: answers `scheduledPodcasts`.
  List<LiveScheduledPodcast> scheduled = [];
  AppFailure? scheduledFailure;

  /// D212: the last raised hand's question.
  String? lastQuestion;

  @override
  Future<LiveSeats> deferSeatRequest(String roomId, String requestId) async {
    final s = _seats('deferSeatRequest:$requestId');
    deferred.add(requestId);
    final request = pendingSeatRequests.firstWhere((r) => r.id == requestId);
    pendingSeatRequests = [
      for (final r in pendingSeatRequests)
        if (r.id != requestId) r,
      request.copyWith(deferred: true),
    ];
    return _bump(
      s.copyWith(handsUp: [for (final r in pendingSeatRequests) r.user.id]),
    );
  }

  @override
  Future<LiveRoom> setPodcastSettings(
    String roomId, {
    bool? questionsOpen,
    bool setQuestionSeconds = false,
    int? questionSeconds,
  }) async {
    podcastSettings.add((
      questionsOpen: questionsOpen,
      setSeconds: setQuestionSeconds,
      seconds: questionSeconds,
    ));
    final base = hostRoom ?? apiRoom(id: roomId);
    final podcast = base.podcast;
    final room = base.copyWith(
      podcast: podcast?.copyWith(
        questionsOpen: questionsOpen ?? podcast.questionsOpen,
        questionSeconds: setQuestionSeconds
            ? questionSeconds
            : podcast.questionSeconds,
      ),
    );
    hostRoom = room;
    return room;
  }

  @override
  Future<List<LiveScheduledPodcast>> scheduledPodcasts() async {
    if (scheduledFailure case final f?) throw f;
    return scheduled;
  }

  @override
  Future<LiveRoom> startRoom({
    required String title,
    String? categorySlug,
    bool allowGuests = true,
    LiveRoomMode mode = LiveRoomMode.solo,
    int? seatCount,
    String? theme,
    PodcastSetup? podcast,
    LiveStreamer? streamer,
    String? vipMinTier,
  }) async {
    startRequests.add((
      title: title,
      categorySlug: categorySlug,
      allowGuests: allowGuests,
      mode: mode,
      seatCount: seatCount,
      theme: theme,
      podcast: podcast,
      streamer: streamer,
    ));
    if (startFailure case final failure?) throw failure;
    // Like the server (CONVENTIONS §10.9): a count the mode does not allow
    // is refused (the app's old audio default 9 was).
    const counts = LiveSeatCounts();
    final allowed = switch (mode) {
      LiveRoomMode.audio => counts.audio,
      LiveRoomMode.multi => counts.multi,
      LiveRoomMode.solo ||
      LiveRoomMode.pk ||
      LiveRoomMode.podcast ||
      LiveRoomMode.streamer => const <int>[],
    };
    if (seatCount != null && !allowed.contains(seatCount)) {
      throw const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'seatCount invalid_value',
        statusCode: 400,
      );
    }
    // D212: a podcast always has 4 tiles, the episode numbered by the server.
    final tiles = mode == LiveRoomMode.podcast ? 4 : seatCount;
    final room = apiRoom(id: 'room-host').copyWith(
      title: title,
      allowGuests: allowGuests,
      mode: mode,
      seatCount: tiles,
      podcast: podcast == null
          ? null
          : LivePodcast(
              episodeNumber: podcastEpisode,
              topic: podcast.topic,
              questionsOpen: podcast.questionsOpen,
              questionSeconds: podcast.questionSeconds,
              // D363: the setup's «صوت / فيديو».
              video: podcast.video,
            ),
      theme: theme ?? LiveThemes.classic,
      // D213: the server's starting layout (portrait, bubble top left).
      streamer: mode == LiveRoomMode.streamer
          ? (streamer ?? const LiveStreamer()).copyWith(version: 0)
          : null,
      roomLevel: startRoomLevel,
      roomNumber: startRoomNumber,
    );
    // D363 scope extension: the setup's segments are the episode's.
    if (podcast != null && podcast.video) {
      studio = LivePodcastStudio(segments: podcast.segments);
    }
    if (mode.hasSeats) {
      seatState = LiveSeats(
        roomId: room.id,
        mode: mode,
        version: 0,
        seatCount: tiles!,
        seats: [
          for (var i = 1; i < tiles; i++)
            LiveSeat(index: i, state: LiveSeatState.empty, user: null),
        ],
        moderators: const [],
        pendingRequests: 0,
        mine: const LiveSeatsMine(
          role: LiveSeatRole.host,
          seatIndex: null,
          request: null,
          invite: null,
        ),
      );
    }
    if (podcast != null && podcast.video) {
      seatState = seatState?.copyWith(studio: studio);
    }
    hostRoom = room;
    return room;
  }

  @override
  Future<void> setHostPresence(String roomId, {required bool away}) async {
    presenceCalls.add(away);
    if (presenceFailure case final failure?) throw failure;
  }

  /// D170: every `setHostPresence` call's `away`, and an error to throw.
  final List<bool> presenceCalls = [];
  AppFailure? presenceFailure;

  @override
  Future<void> heartbeat(String roomId) async {
    heartbeats.add(roomId);
    if (heartbeatFailure case final failure?) throw failure;
  }

  @override
  Future<LiveRoom> endRoom(String roomId) async {
    endRequests.add(roomId);
    final room = (hostRoom ?? apiRoom(id: roomId)).copyWith(
      status: LiveRoomStatus.ended,
      endReason: LiveRoomEndReason.hostEnded,
    );
    hostRoom = room;
    return room;
  }

  @override
  Future<LiveRoom> setAllowGuests(String roomId, {required bool allow}) async {
    guestUpdates.add((roomId: roomId, allow: allow));
    if (guestsFailure case final failure?) throw failure;
    final room = (hostRoom ?? apiRoom(id: roomId)).copyWith(allowGuests: allow);
    hostRoom = room;
    return room;
  }

  @override
  Future<LiveMediaAccess> mediaToken(
    String roomId, {
    String? guestId,
    String? staffVisibility,
  }) async {
    tokenRequests.add((roomId: roomId, guestId: guestId));
    staffVisibilities.add(staffVisibility);
    if (tokenFailure case final failure?) throw failure;
    return LiveMediaAccess(
      url: 'wss://media.test',
      token: 'token-$roomId',
      expiresAt: DateTime.utc(2030),
      role: guestId == null && hostRoom?.id == roomId
          ? LiveMediaRole.host
          : LiveMediaRole.viewer,
      identity: guestId == null ? 'user-me' : 'guest:$guestId',
      guestNumber: guestId == null ? null : 1234,
      // D273: the server's answer for «فريق كابسو».
      staff: staffAnswer ?? staffVisibility,
    );
  }

  /// D273: what each token request asked for (`staffVisibility`).
  final List<String?> staffVisibilities = [];

  /// D273: the `staff` the fake server answers (as a staff account would get).
  String? staffAnswer;

  // CP-011: seats, in memory. [seatState] answers reads; every call is
  // recorded in [seatCalls] as `name:args`.

  LiveSeats? seatState;
  final List<String> seatCalls = [];
  final List<({int? seatCount, String? theme})> roomUpdates = [];

  /// Answers `seatRequests`.
  List<LiveSeatRequest> pendingSeatRequests = [];

  /// Thrown by the next seat calls while set.
  AppFailure? seatFailure;

  LiveSeats _seats(String name) {
    seatCalls.add(name);
    if (seatFailure case final failure?) throw failure;
    final state = seatState;
    if (state == null) throw roomNotFound;
    return state;
  }

  LiveSeats _bump(LiveSeats next) =>
      seatState = next.copyWith(version: next.version + 1);

  LiveSeats _setSeat(LiveSeats s, int index, LiveSeat Function(LiveSeat) f) =>
      _bump(
        s.copyWith(
          seats: [
            for (final seat in s.seats)
              if (seat.index == index) f(seat) else seat,
          ],
        ),
      );

  static UserSummary _user(String username) => UserSummary(
    id: 'user-$username',
    username: username,
    displayName: username,
    avatarUrl: null,
  );

  /// Each `editRoom` call (CP-014); [editFailure] fails the next ones.
  final List<({String title, String? categorySlug, String? topic})> edits = [];
  AppFailure? editFailure;

  @override
  Future<LiveRoom> editRoom(
    String roomId, {
    required String title,
    required String? categorySlug,
    required String? topic,
  }) async {
    edits.add((title: title, categorySlug: categorySlug, topic: topic));
    if (editFailure case final failure?) throw failure;
    final base = hostRoom ?? apiRoom(id: roomId);
    final category = categorySlug == null
        ? null
        : categories.firstWhere((c) => c.slug == categorySlug);
    final room = base.copyWith(
      title: title,
      category: category,
      topic: (topic ?? '').trim().isEmpty ? null : topic!.trim(),
    );
    hostRoom = room;
    return room;
  }

  /// D140: the `roomStats` answer; `null` builds one from [hostRoom]'s score
  /// and [contributorList] (no viewers). [statsFailure] fails it, and a
  /// pending [statsGate] holds it (the loading state).
  LiveRoomStats? stats;
  AppFailure? statsFailure;
  Completer<void>? statsGate;
  int statsCalls = 0;

  @override
  Future<LiveRoomStats> roomStats(String roomId) async {
    statsCalls++;
    if (statsGate case final gate?) await gate.future;
    if (statsFailure case final failure?) throw failure;
    if (stats case final s?) return s;
    final room = hostRoom ?? apiRoom(id: roomId);
    final parts = room.scoreParts;
    return LiveRoomStats(
      roomId: roomId,
      ended: room.status == LiveRoomStatus.ended,
      startedAt: room.startedAt,
      endedAt: room.endedAt,
      duration: Duration.zero,
      total: parts?.total ?? room.score,
      tapPoints: parts?.tapPoints ?? 0,
      supportPoints: parts?.supportPoints ?? 0,
      hostCherries: parts?.hostCherries ?? 0,
      hostOwnPoints: 0,
      supporters: contributorList.length,
      topSupporters: [
        for (final c in contributorList.take(3))
          LiveStatsSupporter(user: c.user, points: c.points),
      ],
      giftCount: 0,
      chatMessages: 0,
      newFollowers: 0,
      viewers: const LiveViewerStats(
        unique: 0,
        guests: 0,
        peak: 0,
        atEnd: 0,
        averageWatch: Duration.zero,
      ),
      viewerCountries: const [],
    );
  }

  /// `contributors` answers (CP-014); [contributorsFailure] fails them.
  List<LiveContributor> contributorList = [];
  AppFailure? contributorsFailure;
  int contributorCalls = 0;

  @override
  Future<List<LiveContributor>> contributors(String roomId) async {
    contributorCalls++;
    if (contributorsFailure case final failure?) throw failure;
    return contributorList;
  }

  /// v1.20-live: one person's standing, by username; anyone else has 0
  /// points and no rank.
  Map<String, ({int points, int? rank})> standings = {};

  /// Every `contributor` call (usernames).
  final List<String> standingCalls = [];

  @override
  Future<LiveContributorStanding> contributor(
    String roomId,
    String username,
  ) async {
    standingCalls.add(username);
    if (contributorsFailure case final failure?) throw failure;
    final s = standings[username];
    return LiveContributorStanding(
      user: UserSummary(
        id: 'u-$username',
        username: username,
        displayName: username,
        avatarUrl: null,
      ),
      points: s?.points ?? 0,
      rank: s?.rank,
    );
  }

  // ---- v1.20-live kicks ----------------------------------------------------

  /// Every kick call: `kick:<username>`, `unkick:<username>`.
  final List<String> kickCalls = [];

  /// Thrown by the next `kick` (then cleared).
  AppFailure? kickFailure;

  @override
  Future<LiveKick> kick(String roomId, String username) async {
    kickCalls.add('kick:$username');
    if (kickFailure case final failure?) {
      kickFailure = null;
      throw failure;
    }
    return LiveKick(
      user: UserSummary(
        id: 'u-$username',
        username: username,
        displayName: username,
        avatarUrl: null,
      ),
      kickedAt: DateTime.utc(2026, 10, 26, 18, 30),
    );
  }

  /// What `kicks` returns.
  List<LiveKick> kickList = const [];

  @override
  Future<List<LiveKick>> kicks(String roomId) async => kickList;

  @override
  Future<void> unkick(String roomId, String username) async =>
      kickCalls.add('unkick:$username');

  /// D136: every wish list set (`setWishGifts`).
  final List<List<String>> wishUpdates = [];

  /// D136: the gifts `setWishGifts` answers with (code → shown gift).
  Map<String, LiveWishGift> wishCatalogue = {};

  @override
  Future<LiveRoom> setWishGifts(String roomId, List<String> codes) async {
    wishUpdates.add(codes);
    final base = hostRoom ?? apiRoom(id: roomId);
    final room = base.copyWith(
      wishGifts: [
        for (final c in codes)
          wishCatalogue[c] ??
              LiveWishGift(
                giftCode: c,
                name: c,
                priceCoins: 1,
                assetKey: 'gift_$c',
              ),
      ],
    );
    hostRoom = room;
    return room;
  }

  @override
  Future<LiveRoom> updateRoom(
    String roomId, {
    int? seatCount,
    String? theme,
  }) async {
    roomUpdates.add((seatCount: seatCount, theme: theme));
    final base = hostRoom ?? apiRoom(id: roomId);
    final room = base.copyWith(
      seatCount: seatCount ?? base.seatCount,
      theme: theme ?? base.theme,
    );
    hostRoom = room;
    final state = seatState;
    if (seatCount != null && state != null) {
      _bump(
        state.copyWith(
          seatCount: seatCount,
          seats: [
            for (var i = 1; i < seatCount; i++)
              state.seats.firstWhere(
                (s) => s.index == i,
                orElse: () =>
                    LiveSeat(index: i, state: LiveSeatState.empty, user: null),
              ),
          ],
        ),
      );
    }
    return room;
  }

  @override
  Future<LiveSeats> seats(String roomId) async => _seats('seats');

  @override
  Future<LiveSeatRequest> requestSeat(
    String roomId, {
    int? seatIndex,
    String? question,
  }) async {
    _seats('requestSeat:${seatIndex ?? ''}');
    lastQuestion = question;
    return LiveSeatRequest(
      id: 'req-me',
      user: _user('me'),
      seatIndex: seatIndex,
      createdAt: DateTime.utc(2026, 10, 23),
    );
  }

  @override
  Future<void> cancelSeatRequest(String roomId) async {
    _seats('cancelSeatRequest');
  }

  @override
  Future<({List<LiveSeatRequest> items, String? next})> seatRequests(
    String roomId, {
    String? cursor,
  }) async {
    _seats('seatRequests');
    return (items: pendingSeatRequests, next: null);
  }

  @override
  Future<LiveSeats> acceptSeatRequest(
    String roomId,
    String requestId, {
    int? seatIndex,
    bool hotSeat = false,
    int? hotSeatSeconds,
  }) async {
    final s = _seats('acceptSeatRequest:$requestId:${seatIndex ?? ''}');
    if (hotSeat) hotSeats.add((requestId: requestId, seconds: hotSeatSeconds));
    final request = pendingSeatRequests.firstWhere((r) => r.id == requestId);
    pendingSeatRequests = [
      for (final r in pendingSeatRequests)
        if (r.id != requestId) r,
    ];
    final index =
        seatIndex ??
        request.seatIndex ??
        s.seats.firstWhere((x) => x.state == LiveSeatState.empty).index;
    return _setSeat(
      s.copyWith(pendingRequests: pendingSeatRequests.length),
      index,
      (seat) => seat.copyWith(state: LiveSeatState.taken, user: request.user),
    );
  }

  @override
  Future<LivePodcastQuestionVotes> voteQuestion(
    String roomId,
    String requestId, {
    required bool vote,
  }) async {
    votes.add((requestId: requestId, vote: vote));
    final mine = votes.where((v) => v.requestId == requestId).last.vote;
    return LivePodcastQuestionVotes(
      requestId: requestId,
      votes: mine ? 1 : 0,
      votedByMe: mine,
    );
  }

  @override
  Future<void> setPodcastDirector(
    String roomId,
    PodcastDirectorShot shot,
  ) async {
    directorShots.add(shot);
  }

  @override
  Future<LivePodcastStudio> setPodcastControl(
    String roomId, {
    String? pinUserId,
    PodcastShotKind? layout,
  }) async => _studio(
    'control:${pinUserId ?? ''}:${layout?.wire ?? ''}',
    LivePodcastStudio(
      pinUserId: pinUserId,
      layout: layout,
      segments: studio.segments,
      segmentIndex: studio.segmentIndex,
      segmentStartedAt: studio.segmentStartedAt,
      closing: studio.closing,
      onScreen: studio.onScreen,
    ),
  );

  @override
  Future<LivePodcastStudio> setPodcastSegments(
    String roomId,
    List<LivePodcastSegment> segments,
  ) async {
    final index = studio.segmentIndex;
    return _studio(
      'segments:${segments.length}',
      LivePodcastStudio(
        pinUserId: studio.pinUserId,
        layout: studio.layout,
        segments: segments,
        segmentIndex: segments.isEmpty
            ? null
            : index != null && index >= segments.length
            ? segments.length - 1
            : index,
        segmentStartedAt: segments.isEmpty ? null : studio.segmentStartedAt,
        closing: segments.isNotEmpty && studio.closing,
        onScreen: studio.onScreen,
      ),
    );
  }

  @override
  Future<LivePodcastStudio> nextPodcastSegment(String roomId) async {
    final index = studio.segmentIndex;
    final last = studio.segments.length - 1;
    final closing = index != null && index >= last;
    return _studio(
      'next',
      LivePodcastStudio(
        pinUserId: studio.pinUserId,
        layout: studio.layout,
        segments: studio.segments,
        segmentIndex: closing ? index : (index ?? -1) + 1,
        segmentStartedAt: closing ? studio.segmentStartedAt : clock.now(),
        closing: closing,
        onScreen: studio.onScreen,
      ),
    );
  }

  @override
  Future<LivePodcastStudio> showPodcastQuestion(
    String roomId,
    String requestId, {
    String? answerUserId,
  }) async {
    final request = pendingSeatRequests.firstWhere((r) => r.id == requestId);
    return _studio(
      'show:$requestId:${answerUserId ?? ''}',
      LivePodcastStudio(
        pinUserId: studio.pinUserId,
        layout: studio.layout,
        segments: studio.segments,
        segmentIndex: studio.segmentIndex,
        segmentStartedAt: studio.segmentStartedAt,
        closing: studio.closing,
        onScreen: LivePodcastOnScreen(
          requestId: requestId,
          user: request.user,
          question: request.question ?? '',
          answerUserId: answerUserId,
        ),
      ),
    );
  }

  @override
  Future<LivePodcastStudio> hidePodcastQuestion(String roomId) async => _studio(
    'hide',
    LivePodcastStudio(
      pinUserId: studio.pinUserId,
      layout: studio.layout,
      segments: studio.segments,
      segmentIndex: studio.segmentIndex,
      segmentStartedAt: studio.segmentStartedAt,
      closing: studio.closing,
    ),
  );

  @override
  Future<LiveSeats> bringSeatOnAir(String roomId, int seatIndex) async {
    final s = _seats('bringSeatOnAir:$seatIndex');
    onAir.add(seatIndex);
    return _setSeat(s, seatIndex, (seat) => seat.copyWith(backstage: false));
  }

  @override
  Future<void> declineSeatRequest(String roomId, String requestId) async {
    _seats('declineSeatRequest:$requestId');
    pendingSeatRequests = [
      for (final r in pendingSeatRequests)
        if (r.id != requestId) r,
    ];
  }

  @override
  Future<LiveSeatInvite> inviteToSeat(
    String roomId,
    String username, {
    int? seatIndex,
    String? guestTitle,
  }) async {
    _seats('inviteToSeat:$username:${seatIndex ?? ''}');
    guestTitles.add(guestTitle);
    return LiveSeatInvite(
      id: 'inv-$username',
      user: _user(username),
      seatIndex: seatIndex,
      invitedBy: _user('host0'),
      expiresAt: DateTime.utc(2030),
    );
  }

  @override
  Future<LiveSeats> acceptSeatInvite(String roomId) async =>
      _seats('acceptSeatInvite');

  @override
  Future<void> declineSeatInvite(String roomId) async {
    _seats('declineSeatInvite');
  }

  @override
  Future<void> leaveSeat(String roomId) async {
    _seats('leaveSeat');
  }

  @override
  Future<LiveSeats> muteSeat(
    String roomId,
    int index, {
    required bool muted,
  }) async => _setSeat(
    _seats('muteSeat:$index:$muted'),
    index,
    (seat) => seat.copyWith(mutedByHost: muted),
  );

  @override
  Future<LiveSeats> removeFromSeat(String roomId, int index) async => _setSeat(
    _seats('removeFromSeat:$index'),
    index,
    (seat) => seat.copyWith(
      state: LiveSeatState.empty,
      user: null,
      mutedByHost: false,
    ),
  );

  @override
  Future<LiveSeats> lockSeat(
    String roomId,
    int index, {
    required bool locked,
  }) async => _setSeat(
    _seats('lockSeat:$index:$locked'),
    index,
    (seat) => seat.copyWith(
      state: locked ? LiveSeatState.locked : LiveSeatState.empty,
    ),
  );

  @override
  Future<LiveSeats> addModerator(String roomId, String username) async {
    final s = _seats('addModerator:$username');
    return _bump(s.copyWith(moderators: [...s.moderators, _user(username)]));
  }

  @override
  Future<LiveSeats> removeModerator(String roomId, String username) async {
    final s = _seats('removeModerator:$username');
    return _bump(
      s.copyWith(
        moderators: [
          for (final m in s.moderators)
            if (m.username != username) m,
        ],
      ),
    );
  }

  @override
  Future<LiveViewersPage> viewers(String roomId, {String? cursor}) async => (
    items: viewerList,
    next: null,
    staff: cursor == null ? staffList : const <LiveStaffWatcher>[],
  );

  /// D260: the Kabso staff watching (`LiveViewerPage.staff`, first page).
  List<LiveStaffWatcher> staffList = const [];

  /// Each `tap` batch sent (CP-012) and the room's tap points.
  final List<({String roomId, int count})> tapBatches = [];
  int tapPoints = 0;

  /// At most this many taps are counted per batch (the server's limits).
  int tapAllowance = 50;

  @override
  Future<LiveTapsResult> tap(String roomId, int count) async {
    tapBatches.add((roomId: roomId, count: count));
    final accepted = count < tapAllowance ? count : tapAllowance;
    tapPoints += accepted;
    return LiveTapsResult(
      accepted: accepted,
      score: LiveScore(
        total: tapPoints,
        tapPoints: tapPoints,
        supportPoints: 0,
      ),
    );
  }

  // ---- CP-013 chat -------------------------------------------------------

  /// What `GET …/chat` answers.
  List<LiveChatEntry> chat = [];

  /// A failure for the next `sendChat` (then cleared).
  AppFailure? chatFailure;

  /// D141: the next [chatFailureTimes] `sendChat` calls throw this.
  AppFailure? chatFailureRepeated;
  int chatFailureTimes = 0;

  /// Every chat call, e.g. `send:hello`, `delete:m-1`, `mute:huda`.
  final List<String> chatCalls = [];
  List<LiveChatMute> chatMuteList = [];
  int _chatSerial = 0;

  /// The author of sent messages (the signed-in test user by default).
  UserSummary chatAuthor = const UserSummary(
    id: 'user-1',
    username: 'layla.k',
    displayName: 'Layla',
    avatarUrl: null,
  );

  @override
  Future<List<LiveChatEntry>> chatMessages(String roomId) async {
    chatCalls.add('list');
    return chat;
  }

  @override
  Future<LiveChatEntry> sendChat(
    String roomId, {
    required String text,
    required String clientId,
  }) async {
    chatCalls.add('send:$text');
    final failure = chatFailure;
    if (failure != null) {
      chatFailure = null;
      throw failure;
    }
    if (chatFailureRepeated case final repeated? when chatFailureTimes > 0) {
      chatFailureTimes--;
      throw repeated;
    }
    return LiveChatEntry(
      id: 'sent-${_chatSerial++}',
      roomId: roomId,
      author: chatAuthor,
      authorRole: LiveChatRole.viewer,
      text: text,
      createdAt: DateTime.utc(2026, 10, 24, 20),
    );
  }

  @override
  Future<void> deleteChat(String roomId, String messageId) async =>
      chatCalls.add('delete:$messageId');

  @override
  Future<List<LiveChatMute>> chatMutes(String roomId) async => chatMuteList;

  @override
  Future<void> setChatMuted(
    String roomId,
    String username, {
    required bool muted,
  }) async => chatCalls.add('${muted ? 'mute' : 'unmute'}:$username');

  @override
  Future<LiveRoom> setChatEnabled(
    String roomId, {
    required bool enabled,
  }) async {
    chatCalls.add('enabled:$enabled');
    return apiRoom(id: roomId).copyWith(chatEnabled: enabled);
  }

  @override
  Future<void> reportChatMessage(String messageId, ReportReason reason) async =>
      chatCalls.add('report:$messageId:${reason.wire}');

  // ---- CP-017 clips, pictures, bullets and coins --------------------------

  /// The balance `GET /wallet/me` answers (and bullets charge).
  int coins = 100;

  /// How many times the wallet was read.
  int walletReads = 0;

  /// A failure for the next `sendBullet` (then cleared).
  AppFailure? bulletFailure;

  /// The body of every bullet sent.
  final List<({String text, String clientId})> bulletCalls = [];

  /// How long a sent VOICE / IMAGE message lives.
  Duration mediaLifetime = const Duration(seconds: 60);

  @override
  Future<LiveChatEntry> sendChatMedia(
    String roomId, {
    required LiveChatKind kind,
    required String mediaId,
    required String clientId,
  }) async {
    chatCalls.add('${kind.name}:$mediaId');
    final failure = chatFailure;
    if (failure != null) {
      chatFailure = null;
      throw failure;
    }
    final at = DateTime.utc(2026, 10, 24, 20);
    final voice = kind == LiveChatKind.voice;
    return LiveChatEntry(
      id: 'sent-${_chatSerial++}',
      roomId: roomId,
      author: chatAuthor,
      authorRole: LiveChatRole.viewer,
      text: '',
      createdAt: at,
      kind: kind,
      media: LiveChatMedia(
        id: mediaId,
        url: voice
            ? 'https://media.example.test/media/$mediaId/voice.m4a'
            : 'https://media.example.test/media/$mediaId/1080.webp',
        thumbUrl: voice
            ? 'https://media.example.test/media/$mediaId/voice.m4a'
            : 'https://media.example.test/media/$mediaId/320.webp',
        width: voice ? 0 : 1080,
        height: voice ? 0 : 1080,
        durationMs: voice ? 4000 : null,
      ),
      expiresAt: at.add(mediaLifetime),
    );
  }

  /// D258: answer bullets as free VIP ones with this many left (null: paid).
  int? bulletFreeLeft;

  @override
  Future<LiveBulletSent> sendBullet(
    String roomId, {
    required String text,
    required String clientId,
  }) async {
    bulletCalls.add((text: text, clientId: clientId));
    final failure = bulletFailure;
    if (failure != null) {
      bulletFailure = null;
      throw failure;
    }
    // D258: a free VIP bullet costs nothing.
    final freeLeft = bulletFreeLeft;
    if (freeLeft == null) coins -= liveBulletCostCoins;
    return (
      bullet: LiveBullet(
        id: 'bullet-${bulletCalls.length}',
        text: text,
        sender: chatAuthor,
        roomId: roomId,
        createdAt: DateTime.utc(2026, 10, 24, 20),
      ),
      coins: coins,
      free: freeLeft != null,
      freeLeft: freeLeft,
    );
  }

  @override
  Future<int> myCoins() async {
    walletReads++;
    return coins;
  }

  // ---- v1.27.5-live seat emoji (D138) ------------------------------------

  /// The token of every seat emoji sent.
  final List<String> seatEmojiCalls = [];

  /// A failure for the next `sendSeatEmoji` (then cleared).
  AppFailure? seatEmojiFailure;

  /// The tile the answer names.
  int seatEmojiSeat = 1;

  @override
  Future<LiveSeatEmoji> sendSeatEmoji(String roomId, String token) async {
    seatEmojiCalls.add(token);
    final failure = seatEmojiFailure;
    if (failure != null) {
      seatEmojiFailure = null;
      throw failure;
    }
    return LiveSeatEmoji(
      id: 'seat-emoji-${seatEmojiCalls.length}',
      seat: seatEmojiSeat,
      user: chatAuthor,
      token: token,
      createdAt: DateTime.utc(2026, 10, 27, 20),
    );
  }
}

/// Overrides that point live discovery at [repo] with a fixed scope (no
/// session or preferences needed).
List<Override> liveOverrides(
  FakeLiveRepository repo, {
  AppLanguage language = AppLanguage.en,
  String? userId = 'user-me',
  String? country,
}) => [
  liveRepositoryProvider.overrideWithValue(repo),
  liveScopeProvider.overrideWithValue((userId: userId, language: language)),
  // D240: the viewer's «القريبة» country (changeable, as in the app).
  liveNearbyChoiceProvider.overrideWith(() => FixedNearbyChoice(country)),
  liveCountryProvider.overrideWith(
    (ref) => ref.watch(liveNearbyChoiceProvider),
  ),
];

/// D240: [LiveNearbyChoice] starting at [initial] (no preferences read).
class FixedNearbyChoice extends LiveNearbyChoice {
  new(this.initial);

  final String? initial;

  @override
  String? build() => initial;

  @override
  void choose(String code) => state = code.toUpperCase();
}
