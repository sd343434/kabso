import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart'
    show ReportReason;

import '../fixtures/live/live_api_fixtures.dart';

/// One `GET /live/rooms` call.
typedef RoomsRequest = ({
  LiveRoomsTab tab,
  String? category,
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
    String? cursor,
    int limit = LiveRepository.defaultPageSize,
  }) async {
    final request = (
      tab: tab,
      category: category,
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
    })
  >
  startRequests = [];
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

  /// Answers `viewers`.
  List<LiveViewer> viewerList = [];

  @override
  Future<LiveRoom> startRoom({
    required String title,
    String? categorySlug,
    bool allowGuests = true,
    LiveRoomMode mode = LiveRoomMode.solo,
    int? seatCount,
    String? theme,
  }) async {
    startRequests.add((
      title: title,
      categorySlug: categorySlug,
      allowGuests: allowGuests,
      mode: mode,
      seatCount: seatCount,
      theme: theme,
    ));
    if (startFailure case final failure?) throw failure;
    final room = apiRoom(id: 'room-host').copyWith(
      title: title,
      allowGuests: allowGuests,
      mode: mode,
      seatCount: seatCount,
      theme: theme ?? LiveThemes.classic,
      roomLevel: startRoomLevel,
    );
    if (mode.hasSeats) {
      seatState = LiveSeats(
        roomId: room.id,
        mode: mode,
        version: 0,
        seatCount: seatCount!,
        seats: [
          for (var i = 1; i < seatCount; i++)
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
    hostRoom = room;
    return room;
  }

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
  Future<LiveMediaAccess> mediaToken(String roomId, {String? guestId}) async {
    tokenRequests.add((roomId: roomId, guestId: guestId));
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
    );
  }

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
  Future<LiveSeatRequest> requestSeat(String roomId, {int? seatIndex}) async {
    _seats('requestSeat:${seatIndex ?? ''}');
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
  }) async {
    final s = _seats('acceptSeatRequest:$requestId:${seatIndex ?? ''}');
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
  }) async {
    _seats('inviteToSeat:$username:${seatIndex ?? ''}');
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
  Future<({List<LiveViewer> items, String? next})> viewers(
    String roomId, {
    String? cursor,
  }) async => (items: viewerList, next: null);

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
}

/// Overrides that point live discovery at [repo] with a fixed scope (no
/// session or preferences needed).
List<Override> liveOverrides(
  FakeLiveRepository repo, {
  AppLanguage language = AppLanguage.en,
  String? userId = 'user-me',
}) => [
  liveRepositoryProvider.overrideWithValue(repo),
  liveScopeProvider.overrideWithValue((userId: userId, language: language)),
];
