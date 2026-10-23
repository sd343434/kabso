import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

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
    if (handler == null) throw roomNotFound;
    return await handler(roomId);
  }
  // CP-010: going live, recorded in memory.

  /// Every `startRoom` call.
  final List<({String title, String? categorySlug, bool allowGuests})>
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

  /// Answers `viewers`.
  List<LiveViewer> viewerList = [];

  @override
  Future<LiveRoom> startRoom({
    required String title,
    String? categorySlug,
    bool allowGuests = true,
  }) async {
    startRequests.add((
      title: title,
      categorySlug: categorySlug,
      allowGuests: allowGuests,
    ));
    if (startFailure case final failure?) throw failure;
    final room = apiRoom(id: 'room-host')
        .copyWith(title: title, allowGuests: allowGuests);
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

  @override
  Future<({List<LiveViewer> items, String? next})> viewers(
    String roomId, {
    String? cursor,
  }) async => (items: viewerList, next: null);
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
