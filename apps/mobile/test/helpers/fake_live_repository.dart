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
